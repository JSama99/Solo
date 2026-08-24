import SwiftUI

/// Presentation-only ownership for the room surrounding the canonical Founder
/// Computer. This type deliberately has no reference to saves, RNG, or actions.
enum FounderEnvironmentMode: Equatable, Sendable {
  case computerFocused
  case freeLook
}

struct FounderEnvironmentCameraState: Equatable, Sendable {
  static let horizontalRange = -1.0...1.0
  static let verticalRange = -0.30...0.30

  var horizontalLook = 0.0
  var verticalLook = 0.0
  var mode: FounderEnvironmentMode = .computerFocused

  var computerAllowsHitTesting: Bool { mode == .computerFocused }
  var environmentAllowsCameraGestures: Bool { mode == .freeLook }
  var freeLookDragPolicyActive: Bool { mode == .freeLook }
  var monitorReturnInteractionEnabled: Bool { mode == .freeLook }

  mutating func look(horizontal: Double = 0, vertical: Double = 0, reduceMotion: Bool = false) {
    guard mode == .freeLook else { return }
    horizontalLook = min(max(horizontalLook + horizontal, Self.horizontalRange.lowerBound), Self.horizontalRange.upperBound)
    verticalLook = min(max(verticalLook + vertical, Self.verticalRange.lowerBound), Self.verticalRange.upperBound)
    if reduceMotion {
      horizontalLook = horizontalLook < -0.34 ? -1 : horizontalLook > 0.34 ? 1 : 0
      verticalLook = verticalLook < -0.12 ? -0.30 : verticalLook > 0.12 ? 0.30 : 0
    }
  }

  mutating func center() {
    horizontalLook = 0
    verticalLook = 0
  }

  mutating func setLook(horizontal: Double, vertical: Double, reduceMotion: Bool = false) {
    guard mode == .freeLook else { return }
    horizontalLook = min(max(horizontal, Self.horizontalRange.lowerBound), Self.horizontalRange.upperBound)
    verticalLook = min(max(vertical, Self.verticalRange.lowerBound), Self.verticalRange.upperBound)
    if reduceMotion {
      horizontalLook = horizontalLook < -0.34 ? -1 : horizontalLook > 0.34 ? 1 : 0
      verticalLook = verticalLook < -0.12 ? -0.30 : verticalLook > 0.12 ? 0.30 : 0
    }
  }
}

enum FounderEnvironmentRendererKind: Equatable, Sendable {
  case native2D
}

/// One stable root: the room owns only camera presentation; the embedded
/// `FounderComputerScreen` remains the sole gameplay and scrolling surface.
struct FounderEnvironmentScreen: View {
  var store: GameStore
  var presentation: PresentationCoordinator

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var camera = FounderEnvironmentCameraState()
  @State private var dragStartCamera: FounderEnvironmentCameraState?
  @AccessibilityFocusState private var environmentIsFocused: Bool
  @AccessibilityFocusState private var computerIsFocused: Bool

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let environment = environmentProjection
        let focused = camera.mode == .computerFocused
        let monitorWidth = monitorWidth(for: geometry.size, focused: focused)
        let monitorHeight = monitorHeight(for: geometry.size, focused: focused)
        let layout = FounderEnvironmentLayout(viewportSize: geometry.size)
        let monitorPosition = layout.viewportPosition(for: .founderMonitor, camera: camera, layer: .foreground)
        let monitorOffset = CGSize(
          width: monitorPosition.x - geometry.size.width / 2,
          height: monitorPosition.y - geometry.size.height / 2
        )

        ZStack {
          FounderEnvironmentRendererView(
            projection: environment,
            camera: camera,
            increasedContrast: contrast == .increased
          )
          .allowsHitTesting(false)
          .clipped()

          FounderPhysicalMonitorView(
            focused: focused,
            width: monitorWidth,
            height: monitorHeight,
            camera: camera,
            worldOffset: focused ? .zero : monitorOffset,
            increasedContrast: contrast == .increased
          ) {
            FounderComputerScreen(store: store, presentation: presentation)
              .allowsHitTesting(camera.computerAllowsHitTesting)
              .accessibilityHidden(!camera.computerAllowsHitTesting)
              .accessibilityFocused($computerIsFocused)
          }

          if camera.mode == .freeLook {
            Color.clear
              .contentShape(.rect)
              .gesture(freeLookDragGesture(in: geometry.size))
              .accessibilityHidden(true)
              .zIndex(1)

            Button(action: focusComputer) {
              Color.clear
                .frame(width: monitorWidth, height: monitorHeight)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .offset(monitorOffset)
            .accessibilityLabel("Founder Computer")
            .accessibilityHint("Double tap to return to the Founder Computer.")
            .zIndex(2)
          }

          FounderEnvironmentControlLayer(
            mode: camera.mode,
            reduceMotion: reduceMotion,
            onLookAround: enterFreeLook,
            onFocusComputer: focusComputer,
            onLook: { horizontal, vertical in
              moveCamera(horizontal: horizontal, vertical: vertical)
            },
            onCenter: centerCamera
          )
          .accessibilityFocused($environmentIsFocused)
          .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
          .zIndex(3)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .animation(reduceMotion ? nil : .smooth(duration: 0.34), value: camera.mode)
        .accessibilityAction(named: Text("Look Around")) { enterFreeLook() }
        .accessibilityAction(named: Text("Look Left")) { moveCamera(horizontal: -1, vertical: 0) }
        .accessibilityAction(named: Text("Look Center")) { centerCamera() }
        .accessibilityAction(named: Text("Look Right")) { moveCamera(horizontal: 1, vertical: 0) }
        .accessibilityAction(named: Text("Look Up")) { moveCamera(horizontal: 0, vertical: 0.30) }
        .accessibilityAction(named: Text("Look Down")) { moveCamera(horizontal: 0, vertical: -0.30) }
        .accessibilityAction(named: Text("Return to Founder Computer")) { focusComputer() }
        .accessibilityAction(named: Text("Focus Founder Computer")) { focusComputer() }
      }
      .navigationTitle("SOLO")
      .onChange(of: store.stats.trackRecord, initial: true) { _, value in
        progression.observe(trackRecord: value)
      }
    }
  }

  private var environmentProjection: FounderEnvironmentProjection {
    let agents = store.agents.compactMap { agent -> LivingAgentProjection? in
      let task = store.tasks.first { $0.assignedAgentID == agent.id && !$0.resolutionLocked }
      return LivingAgentProjection.derive(
        agent: agent,
        task: task,
        presentation: presentation.presentation(for: agent.id),
        isResting: store.restingAgentIDs.contains(agent.id),
        isSelected: false,
        founderStats: store.stats
      )
    }
    let atmosphere = CompanyAtmosphere.derive(stats: store.stats, facility: progression.currentFacility, venture: store.venture)
    return FounderEnvironmentProjection(
      facility: progression.currentFacility,
      atmosphere: atmosphere,
      infrastructure: InfrastructureVisual.map(purchased: progression.purchasedUpgrades, facility: progression.currentFacility, agents: agents, sprint: store.sprint),
      agents: agents
    )
  }

  private func freeLookDragGesture(in size: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        if dragStartCamera == nil { dragStartCamera = camera }
        guard let start = dragStartCamera else { return }
        let horizontal = start.horizontalLook + Double(value.translation.width / max(size.width * 0.42, 1))
        let vertical = start.verticalLook + Double(-value.translation.height / max(size.height * 0.72, 1))
        var updated = camera
        updated.setLook(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
        camera = updated
      }
      .onEnded { _ in
        dragStartCamera = nil
      }
  }

  private func monitorWidth(for size: CGSize, focused: Bool) -> CGFloat {
    let margin: CGFloat = dynamicTypeSize.isAccessibilitySize ? 4 : 12
    return focused ? size.width - margin * 2 : min(size.width * 0.58, 300)
  }

  private func monitorHeight(for size: CGSize, focused: Bool) -> CGFloat {
    focused ? min(size.height * 0.82, 780) : min(size.height * 0.34, 330)
  }

  private func enterFreeLook() {
    guard camera.mode != .freeLook else { return }
    camera.mode = .freeLook
    dragStartCamera = nil
    environmentIsFocused = true
  }

  private func focusComputer() {
    guard camera.mode != .computerFocused else { return }
    camera.mode = .computerFocused
    dragStartCamera = nil
    computerIsFocused = true
  }

  private func moveCamera(horizontal: Double, vertical: Double) {
    if camera.mode != .freeLook { enterFreeLook() }
    camera.look(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
  }

  private func centerCamera() {
    if camera.mode != .freeLook { enterFreeLook() }
    camera.center()
  }
}

enum FounderEnvironmentWorldAnchor: String, CaseIterable, Sendable {
  case garageEntrance
  case storage
  case auroraStation
  case verificationArray
  case stacksStation
  case developmentRig
  case brioStation
  case campaignStudio
  case recoveryCorner
  case founderDesk
  case founderMonitor
  case founderCommandDesk
}

enum FounderEnvironmentParallaxLayer: Double, Sendable {
  case background = 0.72
  case middleGround = 0.90
  case foreground = 1.0
}

/// Pure panoramic world projection. It owns no gameplay or persistence input.
struct FounderEnvironmentLayout: Equatable, Sendable {
  static let worldSize = CGSize(width: 1_360, height: 760)
  static let cameraHorizontalRange = -1.0...1.0
  static let cameraVerticalRange = -0.30...0.30

  var viewportSize: CGSize

  var anchors: [FounderEnvironmentWorldAnchor: CGPoint] {
    [
      .garageEntrance: CGPoint(x: 82, y: 350),
      .storage: CGPoint(x: 225, y: 320),
      .auroraStation: CGPoint(x: 325, y: 300),
      .verificationArray: CGPoint(x: 188, y: 505),
      .stacksStation: CGPoint(x: 680, y: 220),
      .developmentRig: CGPoint(x: 820, y: 455),
      .brioStation: CGPoint(x: 1_035, y: 300),
      .campaignStudio: CGPoint(x: 1_185, y: 485),
      .recoveryCorner: CGPoint(x: 1_285, y: 565),
      .founderDesk: CGPoint(x: 680, y: 650),
      .founderMonitor: CGPoint(x: 680, y: 455),
      .founderCommandDesk: CGPoint(x: 535, y: 635)
    ]
  }

  var cameraCenterX: CGFloat { Self.worldSize.width / 2 }
  var cameraTravel: CGFloat { 390 }
  var scale: CGFloat { max(viewportSize.width / 430, 0.72) }

  func clampedCamera(_ camera: FounderEnvironmentCameraState) -> FounderEnvironmentCameraState {
    var result = camera
    result.horizontalLook = min(max(result.horizontalLook, Self.cameraHorizontalRange.lowerBound), Self.cameraHorizontalRange.upperBound)
    result.verticalLook = min(max(result.verticalLook, Self.cameraVerticalRange.lowerBound), Self.cameraVerticalRange.upperBound)
    return result
  }

  func visibleWorldBounds(camera: FounderEnvironmentCameraState, layer: FounderEnvironmentParallaxLayer = .middleGround) -> CGRect {
    let safe = clampedCamera(camera)
    let centerX = cameraCenterX + CGFloat(safe.horizontalLook) * cameraTravel * CGFloat(layer.rawValue)
    let worldWidth = viewportSize.width / scale
    return CGRect(x: centerX - worldWidth / 2, y: 0, width: worldWidth, height: Self.worldSize.height)
  }

  func viewportPosition(
    for anchor: FounderEnvironmentWorldAnchor,
    camera: FounderEnvironmentCameraState,
    layer: FounderEnvironmentParallaxLayer
  ) -> CGPoint {
    viewportPosition(worldPoint: anchors[anchor] ?? .zero, camera: camera, layer: layer)
  }

  func viewportPosition(
    worldPoint: CGPoint,
    camera: FounderEnvironmentCameraState,
    layer: FounderEnvironmentParallaxLayer
  ) -> CGPoint {
    let safe = clampedCamera(camera)
    let cameraX = cameraCenterX + CGFloat(safe.horizontalLook) * cameraTravel * CGFloat(layer.rawValue)
    let verticalShift = CGFloat(safe.verticalLook) * viewportSize.height * 0.34 * CGFloat(layer.rawValue)
    return CGPoint(
      x: viewportSize.width / 2 + (worldPoint.x - cameraX) * scale,
      y: worldPoint.y / Self.worldSize.height * viewportSize.height + verticalShift
    )
  }

  func zoneIsVisible(_ anchor: FounderEnvironmentWorldAnchor, camera: FounderEnvironmentCameraState, margin: CGFloat = 92) -> Bool {
    let point = viewportPosition(for: anchor, camera: camera, layer: .middleGround)
    return point.x >= -margin && point.x <= viewportSize.width + margin
  }
}

struct FounderEnvironmentProjection: Equatable, Sendable {
  var facility: FacilityTier
  var atmosphere: CompanyAtmosphere
  var infrastructure: [InfrastructureVisual]
  var agents: [LivingAgentProjection]

  var spatialPresentation: CompanySpatialPresentation { .map(facility) }
  var accessibilitySummary: String {
    "\(facility.accessibilityDescription) \(atmosphere.accessibilitySummary) Environment agents show only visible work state."
  }

  var agentAccessibilitySummary: String {
    agents.map { agent in
      let visibleConditions = agent.conditions.intersection([.focused, .stressed, .overloaded])
        .sorted { $0.rawValue < $1.rawValue }
        .map(\.label)
        .joined(separator: ", ")
      return "\(agent.name): \(agent.activity.label). \(visibleConditions)"
    }.joined(separator: " ")
  }

  static func physicalLocation(for upgrade: FacilityUpgradeID) -> InfrastructurePhysicalLocation {
    InfrastructurePhysicalLocation.map(upgrade)
  }
}

/// Native 2.5D boundary. Future RealityKit can replace this view without
/// receiving simulation state or computer action closures.
struct FounderEnvironmentRendererView: View {
  var projection: FounderEnvironmentProjection
  var camera: FounderEnvironmentCameraState
  var increasedContrast: Bool

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let layout = FounderEnvironmentLayout(viewportSize: size)
      panoramicScene(size: size, layout: layout)
      .frame(width: size.width, height: size.height)
      .clipped()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Founder environment. \(projection.accessibilitySummary) \(projection.agentAccessibilitySummary)")
  }

  private func panoramicScene(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      panoramicBackground(size: size, layout: layout)
      garageArchitecture(size: size, layout: layout)
      panoramicStations(size: size, layout: layout)
      panoramicInfrastructure(size: size, layout: layout)
      founderDesk(size: size, layout: layout)
      atmosphere(size: size)
    }
    .background(Color.black)
  }

  @ViewBuilder
  private func panoramicBackground(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    if projection.spatialPresentation == .elevatedLoft {
      LinearGradient(
        colors: [Color(red: 0.05, green: 0.09, blue: 0.15), Color(red: 0.20, green: 0.19, blue: 0.18)],
        startPoint: .top,
        endPoint: .bottom
      )
      HStack(spacing: 12) {
        ForEach(0..<5, id: \.self) { index in
          RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(colors: [.blue.opacity(0.30), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { loftSkyline(seed: index).padding(5) }
            .frame(width: 126, height: size.height * 0.44)
        }
      }
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 235), camera: camera, layer: .background))
    } else {
      LinearGradient(
        colors: [Color(red: 0.10, green: 0.10, blue: 0.095), Color(red: 0.28, green: 0.26, blue: 0.22)],
        startPoint: .top,
        endPoint: .bottom
      )
      VStack(spacing: 0) {
        ForEach(0..<6, id: \.self) { _ in
          Rectangle().fill(.black.opacity(0.28)).frame(height: 3)
          Rectangle().fill(.white.opacity(0.025)).frame(height: size.height * 0.095)
        }
      }
      .frame(width: size.width * 2.35, height: size.height * 0.62)
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 230), camera: camera, layer: .background))
    }

    Path { path in
      path.move(to: CGPoint(x: 0, y: size.height * 0.57))
      path.addLine(to: CGPoint(x: size.width, y: size.height * 0.57))
      path.addLine(to: CGPoint(x: size.width, y: size.height))
      path.addLine(to: CGPoint(x: 0, y: size.height))
      path.closeSubpath()
    }
    .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.16, blue: 0.13), .black], startPoint: .top, endPoint: .bottom))

    ForEach(0..<7, id: \.self) { index in
      Path { path in
        let horizon = size.height * 0.57
        let x = CGFloat(index) / 6 * size.width
        path.move(to: CGPoint(x: size.width / 2, y: horizon))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }
      .stroke(.white.opacity(0.07), lineWidth: 1)
    }
  }

  private func garageArchitecture(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      ForEach(0..<7, id: \.self) { index in
        Rectangle()
          .fill(projection.spatialPresentation == .elevatedLoft ? .white.opacity(0.18) : .black.opacity(0.58))
          .frame(width: projection.spatialPresentation == .elevatedLoft ? 7 : 12, height: size.height * 0.72)
          .position(layout.viewportPosition(worldPoint: CGPoint(x: CGFloat(index) * 220 + 20, y: 280), camera: camera, layer: .background))
      }

      Rectangle()
        .fill(.black.opacity(0.78))
        .frame(width: size.width * 2.5, height: 13)
        .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 78), camera: camera, layer: .background))

      HStack(spacing: 80) {
        ForEach(0..<4, id: \.self) { _ in
          Capsule().fill(.orange.opacity(0.72)).frame(width: 72, height: 9)
            .shadow(color: .orange.opacity(0.35), radius: 12)
        }
      }
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 105), camera: camera, layer: .background))

      garageEntrance
        .position(layout.viewportPosition(for: .garageEntrance, camera: camera, layer: .middleGround))
      storageShelves
        .position(layout.viewportPosition(for: .storage, camera: camera, layer: .middleGround))

      Path { path in
        let utility = layout.viewportPosition(worldPoint: CGPoint(x: 112, y: 250), camera: camera, layer: .middleGround)
        let research = layout.viewportPosition(for: .auroraStation, camera: camera, layer: .middleGround)
        path.move(to: utility)
        path.addLine(to: CGPoint(x: research.x - 72, y: research.y - 55))
      }
      .stroke(.orange.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 5]))
    }
    .allowsHitTesting(false)
  }

  private var garageEntrance: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.62)).frame(width: 128, height: 230)
      RoundedRectangle(cornerRadius: 6).stroke(.orange.opacity(0.55), lineWidth: 5).frame(width: 128, height: 230)
      VStack(spacing: 28) { ForEach(0..<5, id: \.self) { _ in Rectangle().fill(.white.opacity(0.13)).frame(width: 112, height: 3) } }
      Image(systemName: "arrow.up.square.fill").foregroundStyle(.orange.opacity(0.8)).offset(y: 80)
    }
  }

  private var storageShelves: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.28), lineWidth: 5).frame(width: 150, height: 188)
      VStack(spacing: 37) { ForEach(0..<4, id: \.self) { _ in Rectangle().fill(.black.opacity(0.78)).frame(width: 150, height: 7) } }
      VStack(spacing: 26) {
        HStack { equipmentCase(.orange); equipmentCase(.gray) }
        HStack { equipmentCase(.cyan); equipmentCase(.orange) }
        HStack { equipmentCase(.gray); equipmentCase(.gray) }
      }
    }
  }

  private func equipmentCase(_ color: Color) -> some View {
    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.55)).frame(width: 48, height: 25)
      .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.65), lineWidth: 2) }
  }

  private func panoramicStations(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      stationView(agentID: "aurora", role: "RESEARCH / EVIDENCE", tone: .cyan, kind: .research)
        .position(layout.viewportPosition(for: .auroraStation, camera: camera, layer: .middleGround))
      stationView(agentID: "stacks", role: "ENGINEERING / BUILD", tone: .orange, kind: .engineering)
        .position(layout.viewportPosition(for: .stacksStation, camera: camera, layer: .middleGround))
      stationView(agentID: "brio", role: "CAMPAIGN / SIGNAL", tone: .pink, kind: .campaign)
        .position(layout.viewportPosition(for: .brioStation, camera: camera, layer: .middleGround))
    }
    .allowsHitTesting(false)
  }

  private enum EnvironmentStationKind { case research, engineering, campaign }

  private func stationView(agentID: String, role: String, tone: Color, kind: EnvironmentStationKind) -> some View {
    let agent = projection.agents.first { $0.agentID == agentID }
    return ZStack(alignment: .bottom) {
      stationBackboard(kind: kind, tone: tone)
      if let portrait = AgentPortraitAsset.name(for: agentID) {
        Image(portrait)
          .resizable()
          .scaledToFill()
          .frame(width: 92, height: 116)
          .clipShape(.rect(cornerRadius: 18))
          .overlay { RoundedRectangle(cornerRadius: 18).stroke(tone.opacity(0.86), lineWidth: 3) }
          .shadow(color: tone.opacity(0.38), radius: 10)
          .offset(y: -60)
      }
      RoundedRectangle(cornerRadius: 12)
        .fill(.black.opacity(0.88))
        .frame(width: 190, height: 72)
        .overlay(alignment: .top) {
          VStack(spacing: 4) {
            Text(role).font(.caption2.weight(.black)).tracking(0.8).foregroundStyle(tone)
            HStack(spacing: 5) {
              Circle().fill(tone).frame(width: 7, height: 7)
              Text(agent?.activity.label ?? "Ready").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.82))
            }
          }.padding(.top, 9)
        }
      stationConsole(kind: kind, tone: tone).offset(y: 18)
    }
    .frame(width: 220, height: 238)
  }

  @ViewBuilder
  private func stationBackboard(kind: EnvironmentStationKind, tone: Color) -> some View {
    switch kind {
    case .research:
      HStack(spacing: 8) {
        ForEach(0..<2, id: \.self) { _ in Circle().stroke(tone.opacity(0.68), lineWidth: 3).frame(width: 46, height: 46) }
      }.offset(y: -110)
    case .engineering:
      HStack(spacing: 8) {
        ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.82)).frame(width: 38, height: 82).overlay(alignment: .top) { Capsule().fill(tone).frame(width: 20, height: 4).padding(.top, 8) } }
      }.offset(y: -93)
    case .campaign:
      HStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { index in RoundedRectangle(cornerRadius: 6).fill(tone.opacity(0.16)).frame(width: 54, height: 64).overlay { Image(systemName: index == 1 ? "waveform" : "antenna.radiowaves.left.and.right").foregroundStyle(tone) } }
      }.offset(y: -105)
    }
  }

  private func stationConsole(kind: EnvironmentStationKind, tone: Color) -> some View {
    HStack(spacing: 6) {
      ForEach(0..<5, id: \.self) { index in
        RoundedRectangle(cornerRadius: kind == .research ? 8 : 3)
        .fill(index.isMultiple(of: 2) ? tone : .white.opacity(0.28))
        .frame(width: kind == .campaign ? 22 : 16, height: kind == .research ? 16 : 10)
      }
    }
    .frame(width: 174, height: 34)
    .background(.black, in: .rect(cornerRadius: 8))
  }

  private func panoramicInfrastructure(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      ForEach(projection.infrastructure) { item in
        largeEquipment(item)
          .position(layout.viewportPosition(for: worldAnchor(for: item.id), camera: camera, layer: .middleGround))
      }
    }
    .allowsHitTesting(false)
  }

  private func worldAnchor(for id: FacilityUpgradeID) -> FounderEnvironmentWorldAnchor {
    switch id {
    case .developmentRig: .developmentRig
    case .verificationArray: .verificationArray
    case .campaignStudio: .campaignStudio
    case .recoveryCorner: .recoveryCorner
    case .founderCommandDesk: .founderCommandDesk
    }
  }

  private func largeEquipment(_ item: InfrastructureVisual) -> some View {
    let tone: Color = item.state == .active ? .green : item.state == .uninstalled ? .gray : .cyan
    return VStack(spacing: 4) {
      ZStack {
        RoundedRectangle(cornerRadius: 12).fill(.black.opacity(item.state == .uninstalled ? 0.54 : 0.90)).frame(width: 108, height: 76)
        equipmentGlyph(item.id, tone: tone)
        if item.state == .uninstalled { Image(systemName: "shippingbox.fill").foregroundStyle(.white.opacity(0.54)).font(.title3) }
      }
      Text(item.title.uppercased()).font(.system(size: 8, weight: .black, design: .rounded)).tracking(0.5).foregroundStyle(tone)
    }
    .overlay(alignment: .topTrailing) {
      Circle().fill(tone).frame(width: 9, height: 9).padding(8)
    }
  }

  @ViewBuilder
  private func equipmentGlyph(_ id: FacilityUpgradeID, tone: Color) -> some View {
    switch id {
    case .developmentRig:
      HStack(spacing: 5) { ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).stroke(tone, lineWidth: 2).frame(width: 22, height: 49).overlay { VStack { ForEach(0..<4, id: \.self) { _ in Capsule().fill(tone).frame(width: 11, height: 2) } } } } }
    case .verificationArray:
      HStack(spacing: 7) { Circle().stroke(tone, lineWidth: 4).frame(width: 45, height: 45); VStack { ForEach(0..<4, id: \.self) { _ in Capsule().fill(tone).frame(width: 28, height: 3) } } }
    case .campaignStudio:
      HStack(alignment: .bottom, spacing: 5) { ForEach(0..<6, id: \.self) { index in Capsule().fill(tone).frame(width: 6, height: CGFloat(16 + index * 6)) } }
    case .recoveryCorner:
      ZStack { RoundedRectangle(cornerRadius: 16).fill(tone.opacity(0.24)).frame(width: 76, height: 39); RoundedRectangle(cornerRadius: 8).stroke(tone, lineWidth: 3).frame(width: 56, height: 25).offset(y: 10) }
    case .founderCommandDesk:
      HStack(spacing: 7) { ForEach(0..<4, id: \.self) { _ in Circle().stroke(tone, lineWidth: 3).frame(width: 14, height: 14) } }
    }
  }

  private func founderDesk(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    let deskPosition = layout.viewportPosition(for: .founderDesk, camera: camera, layer: .foreground)
    let monitorPosition = layout.viewportPosition(for: .founderMonitor, camera: camera, layer: .foreground)
    return ZStack {
      Path { path in
        path.move(to: CGPoint(x: monitorPosition.x, y: monitorPosition.y + 75))
        path.addCurve(to: CGPoint(x: deskPosition.x + 120, y: deskPosition.y + 28), control1: CGPoint(x: monitorPosition.x + 15, y: monitorPosition.y + 135), control2: CGPoint(x: deskPosition.x + 80, y: deskPosition.y - 5))
      }
      .stroke(.black.opacity(0.92), style: StrokeStyle(lineWidth: 7, lineCap: .round))
      Capsule().fill(.black.opacity(0.92)).frame(width: 132, height: 13)
        .position(x: monitorPosition.x, y: monitorPosition.y + 130)
      RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.90)).frame(width: 17, height: 118)
        .position(x: monitorPosition.x, y: monitorPosition.y + 88)
      ZStack {
        RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.16, green: 0.10, blue: 0.06)).frame(width: 390, height: 118)
        RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.82)).frame(width: 164, height: 42).offset(x: -46, y: 5)
          .overlay { VStack(spacing: 5) { ForEach(0..<3, id: \.self) { _ in HStack(spacing: 7) { ForEach(0..<8, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.25)).frame(width: 9, height: 3) } } } }.offset(x: -46, y: 5) }
        RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.72)).frame(width: 52, height: 38).offset(x: 92, y: 7)
        RoundedRectangle(cornerRadius: 5).stroke(.orange.opacity(0.70), lineWidth: 2).frame(width: 66, height: 44).offset(x: 153, y: -19)
          .overlay { Text("REVIEW").font(.system(size: 8, weight: .black)).foregroundStyle(.orange).offset(x: 153, y: -19) }
        Image(systemName: "mug.fill").foregroundStyle(.orange.opacity(0.78)).font(.title2).offset(x: -158, y: -9)
      }
      .position(deskPosition)
    }
    .allowsHitTesting(false)
  }

  private func loftSkyline(seed: Int) -> some View {
    HStack(alignment: .bottom, spacing: 3) {
      ForEach(0..<7, id: \.self) { index in
        Rectangle().fill(.black.opacity(0.74)).frame(width: 10, height: CGFloat(14 + ((index + seed) % 4) * 9))
      }
    }
  }

  @ViewBuilder private func roomBackground(size: CGSize) -> some View {
    if projection.spatialPresentation == .elevatedLoft {
      LinearGradient(colors: [Color(red: 0.08, green: 0.11, blue: 0.16), Color(red: 0.24, green: 0.27, blue: 0.31)], startPoint: .top, endPoint: .bottom)
      HStack(spacing: 5) {
        ForEach(0..<4, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [.blue.opacity(0.26), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.18)).frame(height: 2) }
        }
      }
      .frame(width: size.width * 0.84, height: size.height * 0.31)
      .offset(x: CGFloat(camera.horizontalLook) * -12, y: -size.height * 0.25 + CGFloat(camera.verticalLook) * 18)
    } else {
      LinearGradient(colors: [Color(red: 0.14, green: 0.15, blue: 0.15), Color(red: 0.29, green: 0.28, blue: 0.25)], startPoint: .top, endPoint: .bottom)
      VStack(spacing: 0) {
        ForEach(0..<5, id: \.self) { _ in
          Rectangle().fill(.black.opacity(0.18)).frame(height: 2)
          Spacer(minLength: 0)
        }
      }
      .padding(.vertical, 30)
      .offset(y: CGFloat(camera.verticalLook) * 12)
    }
  }

  private func structure(size: CGSize) -> some View {
    ZStack {
      ForEach(0..<4, id: \.self) { index in
        Rectangle()
          .fill(projection.spatialPresentation == .elevatedLoft ? .white.opacity(0.16) : .black.opacity(0.36))
          .frame(width: projection.spatialPresentation == .elevatedLoft ? 5 : 8, height: size.height * 0.85)
          .rotationEffect(.degrees(projection.spatialPresentation == .elevatedLoft ? -7 : 0))
          .offset(x: (CGFloat(index) - 1.5) * size.width * 0.36 + CGFloat(camera.horizontalLook) * -18, y: -size.height * 0.08)
      }
      Rectangle().fill(.black.opacity(0.3)).frame(height: 8).offset(y: -size.height * 0.36 + CGFloat(camera.verticalLook) * 24)
      HStack(spacing: 18) {
        Capsule().fill(.orange.opacity(0.55)).frame(width: 52, height: 8)
        Capsule().fill(.orange.opacity(0.38)).frame(width: 32, height: 8)
      }
      .offset(y: -size.height * 0.37)
      RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.35)).frame(width: 42, height: 64)
        .overlay(Image(systemName: "bolt.fill").foregroundStyle(.yellow).font(.caption))
        .offset(x: -size.width * 0.39 + CGFloat(camera.horizontalLook) * -12, y: -size.height * 0.08)
    }
  }

  private func stationLayer(size: CGSize) -> some View {
    ZStack {
      station("aurora", role: "Research", symbol: "microscope", x: -0.62, y: -0.02, size: size)
      station("stacks", role: "Engineering", symbol: "wrench.and.screwdriver.fill", x: 0, y: -0.04, size: size)
      station("brio", role: "Campaign", symbol: "megaphone.fill", x: 0.62, y: -0.02, size: size)
      infrastructure(size: size)
    }
  }

  private func station(_ id: String, role: String, symbol: String, x: CGFloat, y: CGFloat, size: CGSize) -> some View {
    let agent = projection.agents.first { $0.agentID == id }
    let isAttention = agent?.needsFounderAttention == true
    return VStack(spacing: 2) {
      ZStack(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.72)).frame(width: 92, height: 50)
          .overlay(alignment: .topTrailing) {
            Image(systemName: symbol).font(.caption2.weight(.bold)).foregroundStyle(isAttention ? .yellow : .cyan).padding(5)
          }
        if let portrait = AgentPortraitAsset.name(for: id) {
          Image(portrait)
            .resizable()
            .scaledToFill()
            .frame(width: 44, height: 48)
            .clipShape(.rect(cornerRadius: 5))
            .offset(x: -15, y: 2)
        }
        RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.92)).frame(width: 78, height: 13)
          .overlay(Rectangle().fill(isAttention ? .yellow.opacity(0.75) : .cyan.opacity(0.48)).frame(width: 34, height: 2))
          .offset(y: 2)
      }
      Capsule().fill(.black.opacity(0.72)).frame(width: 112, height: 10)
      Text(role.uppercased()).font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.white.opacity(0.86))
    }
    .offset(x: x * size.width - CGFloat(camera.horizontalLook) * size.width * 0.46, y: y * size.height + CGFloat(camera.verticalLook) * 18)
    .accessibilityHidden(true)
  }

  private func infrastructure(size: CGSize) -> some View {
    ZStack {
      ForEach(projection.infrastructure) { item in
        let position = infrastructurePosition(for: item.physicalLocation, size: size)
        equipment(item)
          .offset(x: position.x - CGFloat(camera.horizontalLook) * size.width * 0.42, y: position.y + CGFloat(camera.verticalLook) * 14)
      }
    }
    .accessibilityHidden(true)
  }

  private func equipment(_ item: InfrastructureVisual) -> some View {
    let tone: Color = item.state == .active ? .green : item.state == .uninstalled ? .gray : .cyan
    return ZStack {
      switch item.id {
      case .developmentRig:
        HStack(spacing: 3) { RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.85)).frame(width: 18, height: 38); VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Capsule().fill(tone.opacity(0.8)).frame(width: 20, height: 3) } } }
      case .verificationArray:
        RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.84)).frame(width: 42, height: 25)
          .overlay(Circle().stroke(tone, lineWidth: 2).frame(width: 13, height: 13))
      case .campaignStudio:
        RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.84)).frame(width: 44, height: 25)
          .overlay(HStack(spacing: 3) { ForEach(0..<5, id: \.self) { _ in Rectangle().fill(tone.opacity(0.75)).frame(width: 3, height: 12) } })
      case .recoveryCorner:
        RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.78)).frame(width: 46, height: 21)
          .overlay(Rectangle().fill(tone.opacity(0.50)).frame(width: 25, height: 5).offset(y: 4))
      case .founderCommandDesk:
        RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.86)).frame(width: 48, height: 18)
          .overlay(HStack(spacing: 4) { ForEach(0..<4, id: \.self) { _ in Circle().fill(tone.opacity(0.8)).frame(width: 4, height: 4) } })
      }
      if item.state == .uninstalled { Image(systemName: "shippingbox.fill").font(.caption2).foregroundStyle(.white.opacity(0.55)) }
    }
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(increasedContrast ? 0.78 : 0.25), lineWidth: 1) }
  }

  private func infrastructurePosition(for location: InfrastructurePhysicalLocation, size: CGSize) -> CGPoint {
    switch location {
    case .stacksBuildRail: CGPoint(x: 0, y: -size.height * 0.13)
    case .auroraFounderVerificationBridge: CGPoint(x: -size.width * 0.58, y: -size.height * 0.13)
    case .brioBroadcastRail: CGPoint(x: size.width * 0.58, y: -size.height * 0.13)
    case .recoverySideBay: CGPoint(x: -size.width * 0.72, y: size.height * 0.16)
    case .founderForegroundDesk: CGPoint(x: -size.width * 0.17, y: size.height * 0.31)
    }
  }

  private func atmosphere(size: CGSize) -> some View {
    ZStack {
      if projection.atmosphere.isLowEnergy { Rectangle().fill(.black.opacity(0.20)) }
      if projection.atmosphere.isLowRunway {
        Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange).font(.title3)
          .offset(x: -size.width * 0.37, y: size.height * 0.24)
      }
      if projection.atmosphere.isLowTrust {
        Image(systemName: "antenna.radiowaves.left.and.right.slash").foregroundStyle(.yellow).font(.caption)
          .offset(x: size.width * 0.39, y: size.height * 0.16)
      }
      if projection.atmosphere.isHighMomentum {
        Path { path in
          path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.43))
          path.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.52))
        }
        .stroke(.green.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
      }
    }
    .allowsHitTesting(false)
  }

  private func deskForeground(size: CGSize) -> some View {
    ZStack(alignment: .bottom) {
      Rectangle().fill(projection.spatialPresentation == .elevatedLoft ? Color(red: 0.23, green: 0.17, blue: 0.12) : Color(red: 0.12, green: 0.09, blue: 0.07))
        .frame(height: size.height * 0.19)
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.7)).frame(width: 120, height: 33)
          .overlay { VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(.white.opacity(0.16)).frame(height: 1) } }.padding(6) }
        Circle().fill(.black.opacity(0.7)).frame(width: 33, height: 33)
      }
      .offset(x: CGFloat(camera.horizontalLook) * 18, y: -size.height * 0.035)
      Capsule().fill(.black.opacity(0.8)).frame(width: 140, height: 10).offset(y: -size.height * 0.16)
      Rectangle().fill(.black.opacity(0.78)).frame(width: 13, height: 78).offset(y: -size.height * 0.11)
      Image(systemName: "mug.fill").foregroundStyle(.orange.opacity(0.75)).offset(x: -size.width * 0.34, y: -size.height * 0.10)
    }
    .allowsHitTesting(false)
  }
}

struct FounderPhysicalMonitorView<Content: View>: View {
  var focused: Bool
  var width: CGFloat
  var height: CGFloat
  var camera: FounderEnvironmentCameraState
  var worldOffset: CGSize
  var increasedContrast: Bool
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: focused ? 18 : 12)
        .fill(.black)
        .overlay { RoundedRectangle(cornerRadius: focused ? 18 : 12).stroke(.white.opacity(increasedContrast ? 0.94 : 0.38), lineWidth: focused ? 3 : 2) }
        .shadow(color: .cyan.opacity(focused ? 0.20 : 0.08), radius: focused ? 18 : 8)
      content
        .clipShape(.rect(cornerRadius: focused ? 12 : 8))
        .padding(focused ? 9 : 7)
      LinearGradient(colors: [.white.opacity(0.11), .clear], startPoint: .topLeading, endPoint: .center)
        .clipShape(.rect(cornerRadius: focused ? 12 : 8))
        .padding(focused ? 9 : 7)
        .allowsHitTesting(false)
    }
    .frame(width: width, height: height)
    .scaleEffect(focused ? 1 : 0.98)
    .offset(x: worldOffset.width, y: focused ? -6 : worldOffset.height)
  }
}

struct FounderEnvironmentControlLayer: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var mode: FounderEnvironmentMode
  var reduceMotion: Bool
  var onLookAround: () -> Void
  var onFocusComputer: () -> Void
  var onLook: (Double, Double) -> Void
  var onCenter: () -> Void

  var body: some View {
    GeometryReader { proxy in
      if mode == .computerFocused {
        Button {
          onLookAround()
        } label: {
          if dynamicTypeSize.isAccessibilitySize {
            Image(systemName: "binoculars.fill")
              .frame(width: 44, height: 44)
          } else {
            Label("Look Around", systemImage: "binoculars.fill")
          }
        }
          .buttonStyle(.borderedProminent)
          .tint(.black.opacity(0.72))
          .accessibilityLabel("Look Around")
          .accessibilityHint("Recedes the monitor and enables room camera controls.")
          .position(x: proxy.size.width - (dynamicTypeSize.isAccessibilitySize ? 30 : 82), y: 25)
      } else {
        HStack(spacing: 8) {
          Button("Look Left", systemImage: "chevron.left") { onLook(-1, 0) }.labelStyle(.iconOnly)
          Button("Center", systemImage: "viewfinder") { onCenter() }.labelStyle(.iconOnly)
          Button("Look Right", systemImage: "chevron.right") { onLook(1, 0) }.labelStyle(.iconOnly)
          Button("Return to Founder Computer", systemImage: "desktopcomputer") { onFocusComputer() }.labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.white)
        .padding(7)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.22), lineWidth: 1) }
        .position(x: proxy.size.width / 2, y: proxy.size.height - 34)
      }
    }
  }
}
