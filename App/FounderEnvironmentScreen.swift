import SwiftUI

/// Presentation-only ownership for the room surrounding the canonical Founder
/// Computer. This type deliberately has no reference to saves, RNG, or actions.
enum FounderEnvironmentMode: CaseIterable, Equatable, Sendable {
  case computerFocused
  case transitioningToComputerFocus
  case freeLook
  case transitioningToFreeLook

  var isTransitioning: Bool {
    switch self {
    case .transitioningToComputerFocus, .transitioningToFreeLook: true
    case .computerFocused, .freeLook: false
    }
  }

  var targetsComputerFocus: Bool {
    switch self {
    case .computerFocused, .transitioningToComputerFocus: true
    case .freeLook, .transitioningToFreeLook: false
    }
  }
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
  var lookOutControlAvailable: Bool { mode == .computerFocused }
  var interactionLocked: Bool { mode.isTransitioning }

  @discardableResult
  mutating func beginComputerFocusTransition() -> Bool {
    guard mode == .freeLook else { return false }
    mode = .transitioningToComputerFocus
    return true
  }

  mutating func completeComputerFocusTransition() {
    guard mode == .transitioningToComputerFocus else { return }
    mode = .computerFocused
  }

  @discardableResult
  mutating func beginFreeLookTransition() -> Bool {
    guard mode == .computerFocused else { return false }
    mode = .transitioningToFreeLook
    return true
  }

  mutating func completeFreeLookTransition() {
    guard mode == .transitioningToFreeLook else { return }
    mode = .freeLook
  }

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
  @Environment(\.scenePhase) private var scenePhase
  @State private var camera = FounderEnvironmentCameraState()
  @State private var dragStartCamera: FounderEnvironmentCameraState?
  @State private var transitionID = UUID()
  @State private var selectedEnvironmentalAction: FounderEnvironmentalAction?
  @AccessibilityFocusState private var environmentIsFocused: Bool
  @AccessibilityFocusState private var computerIsFocused: Bool

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let environment = environmentProjection
        let garageMotion = FounderGarageMotionPresentation.derive(
          environment: environment,
          camera: camera,
          reduceMotion: reduceMotion,
          sceneActive: scenePhase == .active
        )
        let targetsComputerFocus = camera.mode.targetsComputerFocus
        let monitorSize = FounderCommandFocusLayout.monitorSize(
          viewport: geometry.size,
          mode: camera.mode,
          accessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
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
            motion: garageMotion,
            increasedContrast: contrast == .increased
          )
          .opacity(garageMotion.camera.environmentOpacity)
          .allowsHitTesting(false)
          .clipped()

          FounderPhysicalMonitorView(
            focused: targetsComputerFocus,
            width: monitorSize.width,
            height: monitorSize.height,
            commandViewportSize: geometry.size,
            camera: camera,
            worldOffset: targetsComputerFocus ? .zero : monitorOffset,
            increasedContrast: contrast == .increased,
            monitorGlowIntensity: garageMotion.lighting.founderMonitorGlow,
            notificationIntensity: garageMotion.lighting.founderNotificationIntensity,
            eventToken: garageMotion.event.token,
            reduceMotion: reduceMotion
          ) {
            FounderComputerScreen(store: store, presentation: presentation)
              .allowsHitTesting(camera.computerAllowsHitTesting)
              .accessibilityHidden(!camera.computerAllowsHitTesting)
              .accessibilityFocused($computerIsFocused)
          }
          .opacity(garageMotion.camera.computerOpacity)

          if garageMotion.camera.showsDeskHardware {
            FounderGarageForegroundFramingView(
              camera: camera,
              monitorOffset: monitorOffset,
              monitorSize: monitorSize,
              increasedContrast: contrast == .increased
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(0.5)
          }

          if camera.mode == .freeLook {
            Color.clear
              .contentShape(.rect)
              .gesture(freeLookDragGesture(in: geometry.size))
              .accessibilityHidden(true)
              .zIndex(1)

            Button(action: focusComputer) {
              Color.clear
                .frame(width: monitorSize.width, height: monitorSize.height)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .offset(monitorOffset)
            .accessibilityLabel("Founder Computer")
            .accessibilityHint("Double tap to return to the Founder Computer.")
            .zIndex(2)

            environmentalHotspots(in: geometry.size)
              .zIndex(2.5)
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

          if camera.interactionLocked {
            Color.clear
              .contentShape(.rect)
              .accessibilityHidden(true)
              .zIndex(4)
          }
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
      .toolbar(.hidden, for: .navigationBar)
      .onChange(of: store.stats.trackRecord, initial: true) { _, value in
        progression.observe(trackRecord: value)
      }
      .sheet(item: $selectedEnvironmentalAction) { action in
        FounderEnvironmentalActionCard(store: store, action: action) {
          selectedEnvironmentalAction = nil
        }
        .presentationDetents([.height(310)])
        .presentationDragIndicator(.visible)
      }
    }
  }

  @ViewBuilder
  private func environmentalHotspots(in size: CGSize) -> some View {
    let layout = FounderEnvironmentLayout(viewportSize: size)
    ForEach([FounderEnvironmentalAction.rest, .train]) { action in
      let anchor: FounderEnvironmentWorldAnchor = action == .rest ? .founderCouch : .workoutBench
      let point = layout.viewportPosition(for: anchor, camera: camera, layer: .middleGround)
      Button {
        selectedEnvironmentalAction = action
      } label: {
        Label(action.object.title, systemImage: action.object.symbol)
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(.black.opacity(0.78), in: .capsule)
          .overlay { Capsule().stroke(action == .rest ? .orange.opacity(0.72) : .cyan.opacity(0.72), lineWidth: 1) }
      }
      .buttonStyle(.plain)
      .position(x: point.x, y: min(size.height - 98, point.y + 85))
      .accessibilityLabel(action.object.title)
      .accessibilityHint("Preview the cost, benefit, duration, and availability before confirming.")
      .accessibilityIdentifier("garage-\(action.object.rawValue)-hotspot")
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
      agents: agents,
      visibleEvent: visibleGarageEvent,
      signalTVEvents: SignalTVProgramming.ambientEvents(
        publicEvents: store.publicMediaEvents,
        techComHeadlines: store.techComHeadlines,
        rivals: store.techComRivals,
        coverage: store.stats.coverage,
        venture: store.venture,
        sprint: store.sprint
      )
    )
  }

  private var visibleGarageEvent: FounderGarageVisibleEvent? {
    switch presentation.latestEvent {
    case .assignment(let id, _, let agentID, _):
      .assignment(id: id, agentID: agentID)
    case .review(let id, _, let agentID, _, _):
      .review(id: id, agentID: agentID)
    case .sprint(let id, _):
      .sprint(id: id)
    case nil:
      nil
    }
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

  private func enterFreeLook() {
    guard camera.beginFreeLookTransition() else { return }
    dragStartCamera = nil
    beginTransition(completing: .freeLook)
  }

  private func focusComputer() {
    guard camera.beginComputerFocusTransition() else { return }
    dragStartCamera = nil
    beginTransition(completing: .computerFocused)
  }

  private func moveCamera(horizontal: Double, vertical: Double) {
    guard camera.mode == .freeLook else { return }
    camera.look(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
  }

  private func centerCamera() {
    guard camera.mode == .freeLook else { return }
    camera.center()
  }

  private func beginTransition(completing destination: FounderEnvironmentMode) {
    let id = UUID()
    transitionID = id
    Task { @MainActor in
      if !reduceMotion {
        try? await Task.sleep(for: .milliseconds(520))
      }
      guard transitionID == id else { return }
      switch destination {
      case .computerFocused:
        camera.completeComputerFocusTransition()
        computerIsFocused = true
      case .freeLook:
        camera.completeFreeLookTransition()
        environmentIsFocused = true
      case .transitioningToComputerFocus, .transitioningToFreeLook:
        break
      }
    }
  }
}

/// Pure geometry policy for one physical monitor moving between observation
/// and an edge-to-edge command surface. It owns no navigation or game state.
struct FounderCommandFocusLayout: Equatable, Sendable {
  static func monitorSize(
    viewport: CGSize,
    mode: FounderEnvironmentMode,
    accessibilitySize: Bool
  ) -> CGSize {
    if mode.targetsComputerFocus {
      return CGSize(width: viewport.width + 6, height: viewport.height + 6)
    }
    let width = min(viewport.width * (accessibilitySize ? 0.64 : 0.58), accessibilitySize ? 320 : 300)
    return CGSize(width: width, height: min(viewport.height * 0.34, 330))
  }

  static func commandCoverage(viewport: CGSize, mode: FounderEnvironmentMode) -> Double {
    let size = monitorSize(viewport: viewport, mode: mode, accessibilitySize: false)
    guard viewport.width > 0, viewport.height > 0 else { return 0 }
    return min(1, (size.width * size.height) / (viewport.width * viewport.height))
  }

  static func contentScale(
    commandViewport: CGSize,
    monitorSize: CGSize,
    focused: Bool,
    screenInset: CGFloat
  ) -> CGFloat {
    guard !focused, commandViewport.width > 0, commandViewport.height > 0 else { return 1 }
    return max(
      max(0, monitorSize.width - screenInset * 2) / commandViewport.width,
      max(0, monitorSize.height - screenInset * 2) / commandViewport.height
    )
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
  case founderPhone
  case founderTablet
  case companyServer
  case founderCouch
  case workoutBench
  case founderDeskLeftEdge
  case founderDeskRightEdge
  case founderDeskSurface
  case founderDeskFloorSide
  case founderCommandDesk
  case signalTV
}

enum FounderEnvironmentParallaxLayer: Double, Sendable {
  case background = 0.52
  case middleGround = 0.80
  case foreground = 1.12
}

enum FounderEnvironmentComposition: String, Equatable, Sendable {
  case compactCockpit
  case regularEstablishing

  static func resolve(viewportWidth: CGFloat) -> Self {
    viewportWidth >= 700 ? .regularEstablishing : .compactCockpit
  }
}

/// Pure panoramic world projection. It owns no gameplay or persistence input.
struct FounderEnvironmentLayout: Equatable, Sendable {
  static let worldSize = CGSize(width: 1_360, height: 760)
  static let cameraHorizontalRange = -1.0...1.0
  static let cameraVerticalRange = -0.30...0.30

  var viewportSize: CGSize

  var composition: FounderEnvironmentComposition {
    .resolve(viewportWidth: viewportSize.width)
  }

  var anchors: [FounderEnvironmentWorldAnchor: CGPoint] {
    var result: [FounderEnvironmentWorldAnchor: CGPoint] = [
      .garageEntrance: CGPoint(x: 82, y: 350),
      .storage: CGPoint(x: 225, y: 320),
      .auroraStation: CGPoint(x: 325, y: 300),
      .verificationArray: CGPoint(x: 188, y: 505),
      .stacksStation: CGPoint(x: 540, y: 220),
      .developmentRig: CGPoint(x: 760, y: 455),
      .brioStation: CGPoint(x: 1_035, y: 300),
      .campaignStudio: CGPoint(x: 1_185, y: 485),
      .recoveryCorner: CGPoint(x: 1_285, y: 565),
      .founderDesk: CGPoint(x: 680, y: 650),
      .founderMonitor: CGPoint(x: 680, y: 480),
      .founderPhone: CGPoint(x: 525, y: 605),
      .founderTablet: CGPoint(x: 765, y: 600),
      .companyServer: CGPoint(x: 870, y: 660),
      .founderCouch: CGPoint(x: 1_095, y: 585),
      .workoutBench: CGPoint(x: 285, y: 585),
      .founderDeskLeftEdge: CGPoint(x: 470, y: 650),
      .founderDeskRightEdge: CGPoint(x: 840, y: 650),
      .founderDeskSurface: CGPoint(x: 680, y: 590),
      .founderDeskFloorSide: CGPoint(x: 870, y: 710),
      .founderCommandDesk: CGPoint(x: 535, y: 635),
      .signalTV: CGPoint(x: 835, y: 205)
    ]
    if composition == .compactCockpit {
      result[.auroraStation] = CGPoint(x: 245, y: 315)
      // Keep Stacks readable beside the taller foreground monitor. The compact
      // camera is centered on the Founder workstation, not on the character.
      result[.stacksStation] = CGPoint(x: 575, y: 225)
      result[.brioStation] = CGPoint(x: 1_105, y: 315)
      result[.founderDesk] = CGPoint(x: 680, y: 660)
      result[.founderMonitor] = CGPoint(x: 680, y: 455)
      result[.founderPhone] = CGPoint(x: 500, y: 620)
      result[.founderTablet] = CGPoint(x: 830, y: 615)
      result[.companyServer] = CGPoint(x: 900, y: 675)
      result[.founderDeskLeftEdge] = CGPoint(x: 455, y: 660)
      result[.founderDeskRightEdge] = CGPoint(x: 855, y: 660)
      result[.founderDeskSurface] = CGPoint(x: 680, y: 600)
      result[.founderDeskFloorSide] = CGPoint(x: 900, y: 720)
      result[.signalTV] = CGPoint(x: 840, y: 205)
      result[.founderCouch] = CGPoint(x: 1_140, y: 585)
      result[.workoutBench] = CGPoint(x: 250, y: 585)
    }
    return result
  }

  var cameraCenterX: CGFloat { Self.worldSize.width / 2 }
  var cameraTravel: CGFloat { composition == .compactCockpit ? 410 : 390 }
  var scale: CGFloat {
    switch composition {
    case .compactCockpit:
      return max(viewportSize.width / 430, 0.86)
    case .regularEstablishing:
      return max(viewportSize.width / 760, 0.90)
    }
  }
  var floorHorizonY: CGFloat {
    viewportSize.height * (composition == .compactCockpit ? 0.58 : 0.55)
  }

  func depthScale(for anchor: FounderEnvironmentWorldAnchor) -> CGFloat {
    switch anchor {
    case .garageEntrance, .storage, .signalTV: 0.78
    case .auroraStation: 0.90
    case .stacksStation: 0.84
    case .brioStation: 0.91
    case .verificationArray, .developmentRig, .campaignStudio: 0.88
    case .founderCouch, .workoutBench: 0.98
    case .recoveryCorner: 0.94
    case .founderCommandDesk: 1.03
    case .founderPhone, .founderTablet, .companyServer,
         .founderDeskLeftEdge, .founderDeskRightEdge, .founderDeskSurface,
         .founderDeskFloorSide, .founderDesk, .founderMonitor: 1.12
    }
  }

  func contactShadowScale(for anchor: FounderEnvironmentWorldAnchor) -> CGFloat {
    depthScale(for: anchor) * scale
  }

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

/// Projects the four Founder Desk devices from the same world anchors as the
/// room renderer. Visual bodies and interactive regions therefore travel as a
/// single physical object when the Founder looks around.
struct FounderDeskEquipmentLayout: Equatable, Sendable {
  var viewportSize: CGSize
  var regularWidth: Bool

  func worldAnchor(for device: FounderDeskDevice) -> FounderEnvironmentWorldAnchor {
    switch device {
    case .computer: .founderMonitor
    case .phone: .founderPhone
    case .tablet: .founderTablet
    case .server: .companyServer
    }
  }

  func viewportPosition(for device: FounderDeskDevice, camera: FounderEnvironmentCameraState) -> CGPoint {
    FounderEnvironmentLayout(viewportSize: viewportSize).viewportPosition(
      for: worldAnchor(for: device),
      camera: camera,
      layer: .foreground
    )
  }

  func deviceSize(for device: FounderDeskDevice) -> CGSize {
    switch (device, regularWidth) {
    case (.computer, false): CGSize(width: min(viewportSize.width * 0.62, 250), height: 158)
    case (.computer, true): CGSize(width: min(viewportSize.width * 0.38, 390), height: 244)
    case (.phone, false): CGSize(width: 68, height: 112)
    case (.phone, true): CGSize(width: 98, height: 146)
    case (.tablet, false): CGSize(width: 116, height: 88)
    case (.tablet, true): CGSize(width: 214, height: 142)
    case (.server, false): CGSize(width: 68, height: 154)
    case (.server, true): CGSize(width: 96, height: 206)
    }
  }

  func hitRegion(for device: FounderDeskDevice, camera: FounderEnvironmentCameraState) -> CGRect {
    let position = viewportPosition(for: device, camera: camera)
    let size = deviceSize(for: device)
    return CGRect(
      x: position.x - max(size.width, 44) / 2,
      y: position.y - max(size.height, 44) / 2,
      width: max(size.width, 44),
      height: max(size.height, 44)
    )
  }

  func isVisible(_ device: FounderDeskDevice, camera: FounderEnvironmentCameraState) -> Bool {
    let intersection = hitRegion(for: device, camera: camera)
      .intersection(CGRect(origin: .zero, size: viewportSize))
    return intersection.width >= 44 && intersection.height >= 44
  }
}

/// Keeps the tappable Free Look target registered to the same world-space
/// anchor and depth transform as the rendered television chassis.
struct SignalTVHotspotLayout: Equatable, Sendable {
  var viewportSize: CGSize

  func frame(camera: FounderEnvironmentCameraState) -> CGRect {
    let layout = FounderEnvironmentLayout(viewportSize: viewportSize)
    let scale = layout.depthScale(for: .signalTV) * layout.scale
    let size = CGSize(width: 292 * scale, height: 191 * scale)
    let position = layout.viewportPosition(for: .signalTV, camera: camera, layer: .background)
    return CGRect(
      x: position.x - size.width / 2,
      y: position.y - size.height / 2,
      width: size.width,
      height: size.height
    )
  }

  func isSelectable(camera: FounderEnvironmentCameraState) -> Bool {
    let intersection = frame(camera: camera).intersection(CGRect(origin: .zero, size: viewportSize))
    return intersection.width >= 44 && intersection.height >= 44
  }
}

struct FounderEnvironmentProjection: Equatable, Sendable {
  var facility: FacilityTier
  var atmosphere: CompanyAtmosphere
  var infrastructure: [InfrastructureVisual]
  var agents: [LivingAgentProjection]
  var visibleEvent: FounderGarageVisibleEvent? = nil
  var signalTVEvents: [PublicMediaEvent] = []

  var spatialPresentation: CompanySpatialPresentation { .map(facility) }
  var accessibilitySummary: String {
    let signal = signalTVEvents.first.map { "Signal TV is airing \($0.program.rawValue): \($0.headline)." } ?? "Signal TV is airing Market Pulse."
    return "\(facility.accessibilityDescription) \(atmosphere.accessibilitySummary) \(signal) Environment agents show only visible work state."
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
  var motion: FounderGarageMotionPresentation
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
    .accessibilityLabel("Founder environment. \(projection.accessibilitySummary) Signal TV and Founder equipment are physical; AI agents operate inside Company Command.")
  }

  private func panoramicScene(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      panoramicBackground(size: size, layout: layout)
      cinematicValueShaping(size: size)
      practicalLighting(size: size, layout: layout)
      livingElectricalLayer(size: size, layout: layout)
      garageArchitecture(size: size, layout: layout)
      signalTVLayer(layout: layout)
      groundingShadows(size: size, layout: layout)
      founderRecoveryZone(size: size, layout: layout)
      taskArtifactLayer(size: size, layout: layout)
      panoramicInfrastructure(size: size, layout: layout)
      founderDesk(size: size, layout: layout)
      ambientEquipmentLayer(size: size, layout: layout)
      atmosphere(size: size)
    }
    .background(Color.black)
  }

  private func signalTVLayer(layout: FounderEnvironmentLayout) -> some View {
    SignalTVView(
      events: projection.signalTVEvents,
      reduceMotion: !motion.ambient.continuousMotionEnabled,
      increasedContrast: increasedContrast,
      continuousMotionEnabled: motion.ambient.continuousMotionEnabled
    )
    .scaleEffect(layout.depthScale(for: .signalTV) * layout.scale)
    .position(layout.viewportPosition(for: .signalTV, camera: camera, layer: .background))
    .allowsHitTesting(false)
  }

  private func founderRecoveryZone(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      couchView
        .scaleEffect(layout.depthScale(for: .founderCouch) * layout.scale)
        .position(layout.viewportPosition(for: .founderCouch, camera: camera, layer: .middleGround))
      workoutBenchView
        .scaleEffect(layout.depthScale(for: .workoutBench) * layout.scale)
        .position(layout.viewportPosition(for: .workoutBench, camera: camera, layer: .middleGround))
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var couchView: some View {
    ZStack {
      Ellipse().fill(.black.opacity(0.48)).frame(width: 250, height: 26).offset(y: 74)
      RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [.brown.opacity(0.85), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)).frame(width: 230, height: 82).offset(y: 22)
      RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.20, green: 0.13, blue: 0.11)).frame(width: 218, height: 68).offset(y: -16)
      HStack(spacing: 7) {
        RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.28, green: 0.18, blue: 0.15)).frame(width: 98, height: 57)
        RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.28, green: 0.18, blue: 0.15)).frame(width: 98, height: 57)
      }.offset(y: -11)
      HStack(spacing: 187) { Capsule().fill(.black.opacity(0.8)).frame(width: 10, height: 48); Capsule().fill(.black.opacity(0.8)).frame(width: 10, height: 48) }.offset(y: 55)
    }.frame(width: 260, height: 160)
  }

  private var workoutBenchView: some View {
    ZStack {
      Ellipse().fill(.black.opacity(0.48)).frame(width: 230, height: 22).offset(y: 68)
      RoundedRectangle(cornerRadius: 8).fill(FounderGarageMaterial.powderCoat).frame(width: 150, height: 29).rotationEffect(.degrees(-5)).offset(x: 8, y: 6)
      RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.18, green: 0.19, blue: 0.20)).frame(width: 102, height: 24).rotationEffect(.degrees(-5)).offset(x: 12, y: -5)
      HStack(spacing: 98) { Capsule().fill(FounderGarageMaterial.satinMetal).frame(width: 8, height: 68); Capsule().fill(FounderGarageMaterial.satinMetal).frame(width: 8, height: 68) }.offset(y: 38)
      Capsule().fill(.black.opacity(0.86)).frame(width: 170, height: 8).offset(y: -49)
      ForEach([-1, 1], id: \.self) { side in
        VStack(spacing: 2) { Circle().fill(.black).frame(width: 27, height: 27); Circle().fill(.black).frame(width: 20, height: 20) }.offset(x: CGFloat(side) * 93, y: -49)
      }
      Text("TRAIN").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.orange.opacity(0.8)).offset(y: 18)
    }.frame(width: 245, height: 150)
  }

  private func cinematicValueShaping(size: CGSize) -> some View {
    ZStack {
      RadialGradient(
        colors: [.clear, .clear, .black.opacity(increasedContrast ? 0.38 : 0.28)],
        center: UnitPoint(x: 0.5 - camera.horizontalLook * 0.10, y: 0.48),
        startRadius: size.width * 0.14,
        endRadius: size.width * 0.78
      )
      LinearGradient(
        colors: [.black.opacity(0.20), .clear, .clear, .black.opacity(0.20)],
        startPoint: .leading,
        endPoint: .trailing
      )
      LinearGradient(
        colors: [.black.opacity(0.16), .clear, .black.opacity(0.12)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
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
        colors: [
          Color(red: 0.075, green: 0.077, blue: 0.074),
          Color(red: 0.20, green: 0.185, blue: 0.16),
          Color(red: 0.12, green: 0.105, blue: 0.09)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      garageWallMaterial(size: size)
      .frame(width: size.width * 2.35, height: size.height * 0.62)
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 230), camera: camera, layer: .background))
    }

    garageFloorPlane(size: size, layout: layout)
  }

  private func garageWallMaterial(size: CGSize) -> some View {
    Canvas { context, canvasSize in
      let panelWidth = canvasSize.width / 9
      for index in 0..<10 {
        let rect = CGRect(x: CGFloat(index) * panelWidth, y: 0, width: panelWidth - 2, height: canvasSize.height)
        context.fill(Path(rect), with: .color(index.isMultiple(of: 3) ? .white.opacity(0.025) : .black.opacity(0.035)))
        context.stroke(Path(CGRect(x: rect.minX, y: 0, width: 1, height: rect.height)), with: .color(.black.opacity(0.36)), lineWidth: 2)
      }
      for row in 1..<6 {
        let y = CGFloat(row) / 6 * canvasSize.height
        var seam = Path()
        seam.move(to: CGPoint(x: 0, y: y))
        seam.addLine(to: CGPoint(x: canvasSize.width, y: y))
        context.stroke(seam, with: .color(.black.opacity(0.30)), lineWidth: row.isMultiple(of: 2) ? 3 : 1)
      }
      for index in 0..<18 {
        let x = CGFloat((index * 83) % 997) / 997 * canvasSize.width
        let y = CGFloat((index * 47) % 311) / 311 * canvasSize.height
        let scuff = CGRect(x: x, y: y, width: CGFloat(12 + index % 4 * 7), height: 2)
        context.fill(Path(roundedRect: scuff, cornerRadius: 1), with: .color(.white.opacity(0.038)))
      }
      for index in 0..<12 {
        let x = CGFloat((index * 137 + 23) % 991) / 991 * canvasSize.width
        let y = CGFloat((index * 71 + 19) % 307) / 307 * canvasSize.height
        let radius = CGFloat(5 + index % 4 * 3)
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius * 0.42)),
          with: .color(.black.opacity(0.050))
        )
      }
      for index in 0..<8 {
        let x = CGFloat((index * 191 + 41) % 983) / 983 * canvasSize.width
        let y = CGFloat((index * 101 + 17) % 293) / 293 * canvasSize.height
        let patch = CGRect(x: x, y: y, width: CGFloat(46 + index % 3 * 22), height: CGFloat(22 + index % 4 * 8))
        context.fill(
          Path(roundedRect: patch, cornerRadius: 12),
          with: .radialGradient(
            Gradient(colors: [.white.opacity(0.022), .clear]),
            center: CGPoint(x: patch.midX, y: patch.midY),
            startRadius: 2,
            endRadius: patch.width * 0.62
          )
        )
      }
    }
    .opacity(motion.environment.rearContrast)
  }

  private func garageFloorPlane(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    let horizon = layout.floorHorizonY
    let vanishingX = size.width / 2 - CGFloat(camera.horizontalLook) * size.width * 0.08
    return Canvas { context, canvasSize in
      var floor = Path()
      floor.move(to: CGPoint(x: 0, y: horizon))
      floor.addLine(to: CGPoint(x: canvasSize.width, y: horizon))
      floor.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
      floor.addLine(to: CGPoint(x: 0, y: canvasSize.height))
      floor.closeSubpath()
      context.fill(
        floor,
        with: .linearGradient(
          Gradient(colors: [Color(red: 0.145, green: 0.135, blue: 0.12), Color(red: 0.035, green: 0.032, blue: 0.03)]),
          startPoint: CGPoint(x: canvasSize.width / 2, y: horizon),
          endPoint: CGPoint(x: canvasSize.width / 2, y: canvasSize.height)
        )
      )
      for index in 0...8 {
        var seam = Path()
        seam.move(to: CGPoint(x: vanishingX, y: horizon))
        seam.addLine(to: CGPoint(x: CGFloat(index) / 8 * canvasSize.width, y: canvasSize.height))
        context.stroke(seam, with: .color(.white.opacity(0.055)), lineWidth: 1)
      }
      for row in 1...5 {
        let progress = CGFloat(row) / 5
        let y = horizon + (canvasSize.height - horizon) * progress * progress
        var seam = Path()
        seam.move(to: CGPoint(x: 0, y: y))
        seam.addLine(to: CGPoint(x: canvasSize.width, y: y))
        context.stroke(seam, with: .color(.black.opacity(0.34)), lineWidth: 1.5)
      }
      for index in 0..<9 {
        let x = CGFloat((index * 61) % 263) / 263 * canvasSize.width
        let y = horizon + CGFloat((index * 43) % 137) / 137 * (canvasSize.height - horizon)
        let scuff = CGRect(x: x, y: y, width: CGFloat(16 + index % 3 * 9), height: 2)
        context.fill(Path(roundedRect: scuff, cornerRadius: 1), with: .color(.white.opacity(0.035)))
      }
      for index in 0..<22 {
        let x = CGFloat((index * 67 + 19) % 257) / 257 * canvasSize.width
        let y = horizon + CGFloat((index * 37 + 13) % 131) / 131 * (canvasSize.height - horizon)
        let radius = CGFloat(1 + index % 3)
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: radius * 1.8, height: radius)),
          with: .color(index.isMultiple(of: 4) ? .white.opacity(0.045) : .black.opacity(0.075))
        )
      }
    }
  }

  private func garageArchitecture(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      ForEach(0..<7, id: \.self) { index in
        RoundedRectangle(cornerRadius: 2)
          .fill(LinearGradient(
            colors: projection.spatialPresentation == .elevatedLoft
              ? [.white.opacity(0.22), .black.opacity(0.38)]
              : [FounderGarageMaterial.satinMetal.opacity(0.72), .black.opacity(0.78)],
            startPoint: .leading,
            endPoint: .trailing
          ))
          .frame(width: projection.spatialPresentation == .elevatedLoft ? 7 : 12, height: size.height * 0.72)
          .overlay(alignment: .top) {
            VStack(spacing: 74) {
              ForEach(0..<5, id: \.self) { _ in
                Circle().fill(.white.opacity(0.16)).frame(width: 2.5, height: 2.5)
              }
            }
            .padding(.top, 18)
          }
          .position(layout.viewportPosition(worldPoint: CGPoint(x: CGFloat(index) * 220 + 20, y: 280), camera: camera, layer: .background))
      }

      Rectangle()
        .fill(.black.opacity(0.78))
        .frame(width: size.width * 2.5, height: 13)
        .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 78), camera: camera, layer: .background))

      HStack(spacing: 80) {
        ForEach(0..<4, id: \.self) { _ in
          ZStack {
            RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.86)).frame(width: 86, height: 15)
            Capsule().fill(Color(red: 1, green: 0.78, blue: 0.48).opacity(0.82)).frame(width: 72, height: 6)
          }
          .shadow(color: .orange.opacity(0.24), radius: 9, y: 5)
        }
      }
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 105), camera: camera, layer: .background))

      wallUtilityDetails(layout: layout)

      garageEntrance
        .position(layout.viewportPosition(for: .garageEntrance, camera: camera, layer: .middleGround))
      storageShelves
        .position(layout.viewportPosition(for: .storage, camera: camera, layer: .middleGround))

      Path { path in
        let utility = layout.viewportPosition(worldPoint: CGPoint(x: 112, y: 250), camera: camera, layer: .middleGround)
        let desk = layout.viewportPosition(for: .founderDesk, camera: camera, layer: .middleGround)
        path.move(to: utility)
        path.addLine(to: CGPoint(x: desk.x - 120, y: desk.y - 190))
      }
      .stroke(.orange.opacity(0.42), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 5]))
    }
    .allowsHitTesting(false)
  }

  private func wallUtilityDetails(layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      HStack(spacing: 5) {
        ForEach(0..<8, id: \.self) { index in
          Circle().fill(index.isMultiple(of: 3) ? Color.orange.opacity(0.30) : Color.white.opacity(0.10))
            .frame(width: 4, height: 4)
        }
      }
      .padding(9)
      .frame(width: 96, height: 70)
      .background(Color.black.opacity(0.34), in: .rect(cornerRadius: 3))
      .overlay { RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.12), lineWidth: 1) }
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 410, y: 205), camera: camera, layer: .background))

      HStack(spacing: 8) {
        ForEach(0..<3, id: \.self) { index in
          RoundedRectangle(cornerRadius: 2)
            .fill(index == 1 ? Color.orange.opacity(0.20) : Color.white.opacity(0.08))
            .frame(width: 42, height: 31)
        }
      }
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 980, y: 165), camera: camera, layer: .background))

      Capsule().fill(.black.opacity(0.72)).frame(width: 250, height: 9)
        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.08)).frame(height: 2) }
        .position(layout.viewportPosition(worldPoint: CGPoint(x: 890, y: 250), camera: camera, layer: .background))

      if motion.environment.detail != .improvised {
        HStack(spacing: 6) {
          ForEach(0..<5, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2)
              .fill(index.isMultiple(of: 2) ? Color.gray.opacity(0.36) : Color.orange.opacity(0.24))
              .frame(width: 34, height: CGFloat(20 + index % 3 * 7))
          }
        }
        .position(layout.viewportPosition(worldPoint: CGPoint(x: 730, y: 190), camera: camera, layer: .background))
      }
    }
    .opacity(motion.environment.rearContrast)
  }

  private func groundingShadows(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      contactShadow(anchor: .founderCouch, width: 225, layout: layout)
      contactShadow(anchor: .workoutBench, width: 205, layout: layout)
      contactShadow(anchor: .verificationArray, width: 105, layout: layout)
      contactShadow(anchor: .developmentRig, width: 105, layout: layout)
      contactShadow(anchor: .campaignStudio, width: 105, layout: layout)
      contactShadow(anchor: .founderDesk, width: 390, layout: layout)
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
  }

  private func contactShadow(
    anchor: FounderEnvironmentWorldAnchor,
    width: CGFloat,
    layout: FounderEnvironmentLayout
  ) -> some View {
    let position = layout.viewportPosition(for: anchor, camera: camera, layer: anchor == .founderDesk ? .foreground : .middleGround)
    let scale = layout.contactShadowScale(for: anchor)
    return Ellipse()
      .fill(.black.opacity(0.48))
      .frame(width: width * scale, height: 18 * scale)
      .position(x: position.x + 8 * scale, y: position.y + 122 * scale)
  }

  private var garageEntrance: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5)
        .fill(.black.opacity(0.68))
        .frame(width: 174, height: 238)
        .shadow(color: .black.opacity(0.56), radius: 8, x: 5, y: 5)
      RoundedRectangle(cornerRadius: 4)
        .fill(LinearGradient(
          colors: [Color(red: 0.27, green: 0.28, blue: 0.27), Color(red: 0.13, green: 0.14, blue: 0.14)],
          startPoint: .top,
          endPoint: .bottom
        ))
        .frame(width: 154, height: 222)
      VStack(spacing: 0) {
        ForEach(0..<5, id: \.self) { row in
          HStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                  colors: [.white.opacity(0.10), .black.opacity(0.16)],
                  startPoint: .top,
                  endPoint: .bottom
                ))
                .overlay {
                  RoundedRectangle(cornerRadius: 2)
                    .stroke(.black.opacity(0.34), lineWidth: 1)
                }
            }
          }
          .padding(.horizontal, 7)
          .padding(.vertical, 5)
          .frame(height: 43)
          if row < 4 {
            Rectangle().fill(.black.opacity(0.72)).frame(height: 2)
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
          }
        }
      }
      .frame(width: 154, height: 222)
      HStack(spacing: 150) {
        Capsule().fill(FounderGarageMaterial.satinMetal).frame(width: 6, height: 234)
        Capsule().fill(FounderGarageMaterial.satinMetal).frame(width: 6, height: 234)
      }
      HStack(spacing: 136) {
        VStack(spacing: 34) { ForEach(0..<6, id: \.self) { _ in Circle().fill(.white.opacity(0.28)).frame(width: 5, height: 5) } }
        VStack(spacing: 34) { ForEach(0..<6, id: \.self) { _ in Circle().fill(.white.opacity(0.28)).frame(width: 5, height: 5) } }
      }
      Capsule().fill(.black.opacity(0.96)).frame(width: 158, height: 7).offset(y: 112)
      Capsule().fill(.white.opacity(0.30)).frame(width: 24, height: 5).offset(y: 61)
    }
    .accessibilityHidden(true)
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
      if layout.zoneIsVisible(.auroraStation, camera: camera, margin: 190) {
        stationView(agentID: "aurora", role: "RESEARCH / EVIDENCE", tone: .cyan, kind: .research)
          .scaleEffect(layout.depthScale(for: .auroraStation) * layout.scale)
          .position(layout.viewportPosition(for: .auroraStation, camera: camera, layer: .middleGround))
      }
      if layout.zoneIsVisible(.stacksStation, camera: camera, margin: 190) {
        stationView(agentID: "stacks", role: "ENGINEERING / BUILD", tone: .orange, kind: .engineering)
          .scaleEffect(layout.depthScale(for: .stacksStation) * layout.scale)
          .position(layout.viewportPosition(for: .stacksStation, camera: camera, layer: .middleGround))
      }
      if layout.zoneIsVisible(.brioStation, camera: camera, margin: 190) {
        stationView(agentID: "brio", role: "CAMPAIGN / SIGNAL", tone: .pink, kind: .campaign)
          .scaleEffect(layout.depthScale(for: .brioStation) * layout.scale)
          .position(layout.viewportPosition(for: .brioStation, camera: camera, layer: .middleGround))
      }
    }
    .allowsHitTesting(false)
  }

  private func stationView(agentID: String, role: String, tone: Color, kind: FounderGarageStationKind) -> some View {
    let agent = projection.agents.first { $0.agentID == agentID }
    let stationMotion = motion.station(for: agentID)
    return FounderGaragePhysicalStationView(
      agent: agent,
      motion: stationMotion,
      role: role,
      tone: tone,
      kind: kind,
      increasedContrast: increasedContrast
    )
  }

  private func taskArtifactLayer(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    let founder = layout.viewportPosition(for: .founderMonitor, camera: camera, layer: .foreground)
    return ZStack {
      ForEach(motion.stations, id: \.agentID) { station in
        if [.inboundTask, .returnedForReview].contains(station.physical.artifactState) {
          let destination = artifactDestination(for: station.agentID, layout: layout)
          let returning = station.physical.artifactState == .returnedForReview
          let origin = returning ? destination : founder
          let destinationPosition = returning ? founder : destination
          ZStack {
            RoundedRectangle(cornerRadius: 4)
              .fill(FounderGarageMaterial.powderCoat.opacity(0.96))
              .frame(width: 45, height: 28)
              .overlay(alignment: .bottom) {
                Capsule()
                  .fill(stationTone(for: station.agentID).opacity(0.62))
                  .frame(width: 29, height: 2)
                  .offset(y: 3)
              }
              .shadow(color: .black.opacity(0.62), radius: 3, y: 3)
            FounderGarageTaskArtifactView(
              tone: stationTone(for: station.agentID),
              state: station.physical.artifactState,
              progress: station.physical.artifactProgress,
              reduceMotion: !station.physical.reactionMotionEnabled,
              eventToken: station.eventToken
            )
          }
          .phaseAnimator(
            station.physical.reactionMotionEnabled ? [0.0, 1.0] : [1.0],
            trigger: station.eventToken
          ) { content, progress in
            content
              .position(
                x: origin.x + (destinationPosition.x - origin.x) * progress,
                y: origin.y + (destinationPosition.y - origin.y) * progress
              )
              .opacity(0.58 + progress * 0.42)
              .scaleEffect(0.92 + progress * 0.08)
          } animation: { _ in
            .smooth(duration: 0.46)
          }
        }
      }
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
  }

  private func artifactDestination(
    for agentID: String,
    layout: FounderEnvironmentLayout
  ) -> CGPoint {
    let anchor: FounderEnvironmentWorldAnchor
    switch agentID {
    case "aurora": anchor = .auroraStation
    case "brio": anchor = .brioStation
    default: anchor = .stacksStation
    }
    let station = layout.viewportPosition(for: anchor, camera: camera, layer: .middleGround)
    return CGPoint(x: station.x, y: station.y + 75)
  }

  private func stationTone(for agentID: String) -> Color {
    switch agentID {
    case "aurora": .cyan
    case "brio": .pink
    default: .orange
    }
  }

  @ViewBuilder
  private func stationWorkflowOverlay(
    _ stationMotion: FounderGarageStationMotion,
    tone: Color
  ) -> some View {
    let activity = stationMotion.continuousMotionEnabled
    switch stationMotion.workflow {
    case .researchScan:
      ZStack {
        HStack(spacing: 11) {
          ForEach(0..<3, id: \.self) { index in
            Circle()
              .stroke(tone.opacity(0.34 + Double(index) * 0.14), lineWidth: 2)
              .frame(width: 25 + CGFloat(index) * 8, height: 25 + CGFloat(index) * 8)
          }
        }
        Capsule().fill(tone.opacity(0.85)).frame(width: 92, height: 2)
          .phaseAnimator(activity ? [-18.0, 18.0] : [0.0]) { content, offset in
            content.offset(y: offset)
          } animation: { _ in .linear(duration: 1.8) }
      }
    case .engineeringBuild:
      HStack(spacing: 5) {
        ForEach(0..<5, id: \.self) { index in
          RoundedRectangle(cornerRadius: 3)
            .fill(index <= Int(stationMotion.visibleProgress * 4) ? tone : .white.opacity(0.16))
            .frame(width: 22, height: 8 + CGFloat(index.isMultiple(of: 2) ? 8 : 0))
            .phaseAnimator(activity ? [0.55, 1.0] : [0.82]) { content, opacity in
              content.opacity(index.isMultiple(of: 2) ? opacity : 0.82)
            } animation: { _ in .easeInOut(duration: 0.72) }
        }
      }
    case .campaignDistribution:
      HStack(spacing: 9) {
        ForEach(0..<3, id: \.self) { index in
          Image(systemName: index == 1 ? "person.3.sequence.fill" : "antenna.radiowaves.left.and.right")
            .font(.caption)
            .foregroundStyle(tone.opacity(0.72 + Double(index) * 0.08))
            .phaseAnimator(activity ? [0.86, 1.08, 0.86] : [1.0]) { content, scale in
              content.scaleEffect(scale)
            } animation: { _ in .smooth(duration: 1.05) }
        }
      }
    case .assignmentArrival:
      Image(systemName: "arrow.down.doc.fill")
        .foregroundStyle(tone)
        .symbolEffect(.bounce, value: stationMotion.eventToken)
    case .artifactReady:
      Label("READY", systemImage: "tray.and.arrow.down.fill")
        .font(.system(size: 7, weight: .black))
        .foregroundStyle(tone)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.86), in: Capsule())
    case .reviewing:
      Image(systemName: "doc.text.magnifyingglass").foregroundStyle(tone)
    case .resolutionDispatch:
      Image(systemName: "arrow.triangle.branch").foregroundStyle(tone)
        .symbolEffect(.pulse, value: stationMotion.eventToken)
    case .resting:
      Image(systemName: "moon.zzz.fill").foregroundStyle(.white.opacity(0.52))
    case .idle, .reviewed, .resolved:
      EmptyView()
    }
  }

  @ViewBuilder
  private func stationBackboard(kind: FounderGarageStationKind, tone: Color) -> some View {
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

  private func stationConsole(kind: FounderGarageStationKind, tone: Color) -> some View {
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
          .scaleEffect(layout.depthScale(for: worldAnchor(for: item.id)) * layout.scale)
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
    .background(alignment: .bottom) {
      Ellipse().fill(.black.opacity(0.46)).frame(width: 104, height: 12).offset(y: 3)
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
      .phaseAnimator(
        motion.environment.atmosphericMotionEnabled ? [-0.28, 0.24, -0.12] : [0.0]
      ) { content, angle in
        content.rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.50, y: 0.28))
      } animation: { _ in
        .easeInOut(duration: FounderGarageAmbientRhythm.profile(for: .cableAirflow).duration)
      }
      Capsule().fill(.black.opacity(0.92)).frame(width: 132, height: 13)
        .position(x: monitorPosition.x, y: monitorPosition.y + 130)
      RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.90)).frame(width: 17, height: 118)
        .position(x: monitorPosition.x, y: monitorPosition.y + 88)
      ZStack {
        Ellipse()
          .fill(.black.opacity(0.64))
          .frame(width: 486, height: 28)
          .offset(x: 10, y: 91)
        HStack(spacing: 326) {
          RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: [.black, FounderGarageMaterial.deskFront], startPoint: .top, endPoint: .bottom))
            .frame(width: 23, height: 104)
            .rotationEffect(.degrees(4))
          RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: [.black, FounderGarageMaterial.deskFront], startPoint: .top, endPoint: .bottom))
            .frame(width: 23, height: 104)
            .rotationEffect(.degrees(-4))
        }
        .offset(y: 67)
        Path { path in
          path.move(to: CGPoint(x: -8, y: 3))
          path.addLine(to: CGPoint(x: 426, y: 3))
          path.addLine(to: CGPoint(x: 460, y: 118))
          path.addLine(to: CGPoint(x: -38, y: 118))
          path.closeSubpath()
        }
        .fill(LinearGradient(
          colors: [FounderGarageMaterial.deskTop, Color(red: 0.16, green: 0.09, blue: 0.05), FounderGarageMaterial.deskFront],
          startPoint: .top,
          endPoint: .bottom
        ))
        .overlay(alignment: .top) {
          Rectangle()
            .fill(FounderGarageMaterial.materialEdge)
            .frame(width: 438, height: 3)
            .offset(y: 3)
        }
        .overlay {
          FounderGarageSurfaceTexture(kind: .laminate, strength: 0.9)
            .clipShape(.rect(cornerRadius: 4))
        }
        LinearGradient(
          colors: [.clear, Color.cyan.opacity(0.10 * motion.lighting.founderMonitorGlow), .clear],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: 230, height: 4)
        .offset(x: 5, y: -44)
        RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.82)).frame(width: 184, height: 43).offset(x: -22, y: 11)
          .overlay {
            VStack(spacing: 5) {
              ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 7) {
                  ForEach(0..<9, id: \.self) { column in
                    RoundedRectangle(cornerRadius: 1)
                      .fill(Color.cyan.opacity(0.12 + motion.lighting.founderMonitorGlow * 0.24 + ((row + column).isMultiple(of: 7) ? 0.08 : 0)))
                      .frame(width: 9, height: 3)
                  }
                }
              }
            }
            .offset(x: -22, y: 11)
          }
          .shadow(color: .cyan.opacity(motion.lighting.founderMonitorGlow * 0.10), radius: 4)
        RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.72)).frame(width: 52, height: 38).offset(x: 108, y: 13)
        RoundedRectangle(cornerRadius: 5)
          .stroke(.orange.opacity(0.30 + motion.lighting.founderNotificationIntensity * 0.58), lineWidth: 2)
          .frame(width: 66, height: 44)
          .offset(x: 180, y: -16)
          .overlay {
            Text("REVIEW")
              .font(.system(size: 8, weight: .black))
              .foregroundStyle(.orange.opacity(0.42 + motion.lighting.founderNotificationIntensity * 0.58))
              .offset(x: 180, y: -16)
          }
          .shadow(color: .orange.opacity(motion.lighting.founderNotificationIntensity * 0.26), radius: 6)
          .phaseAnimator(
            motion.lighting.founderNotificationIntensity > 0 && motion.ambient.continuousMotionEnabled ? [0.82, 1.0, 0.88] : [1.0],
            trigger: motion.event.token
          ) { content, opacity in
            content.opacity(opacity)
          } animation: { _ in .easeInOut(duration: 0.72) }
        FounderCoffeeCupView(steamActive: motion.environment.atmosphericMotionEnabled)
        .offset(x: -196, y: -6)
        RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.78, green: 0.70, blue: 0.48)).frame(width: 44, height: 31)
          .overlay { VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(.black.opacity(0.28)).frame(width: 30, height: 1) } } }
          .phaseAnimator(
            motion.environment.atmosphericMotionEnabled ? [-7.0, -6.55, -7.15] : [-7.0]
          ) { content, angle in
            content.rotationEffect(.degrees(angle), anchor: .topLeading)
          } animation: { _ in
            .easeInOut(duration: FounderGarageAmbientRhythm.profile(for: .cableAirflow).duration + 2.3)
          }
          .offset(x: 148, y: 42)
        ZStack {
          RoundedRectangle(cornerRadius: 3)
            .fill(FounderGarageMaterial.industrialPlastic)
            .frame(width: 48, height: 27)
          HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
              Circle()
                .fill(index == 1 ? Color.cyan.opacity(0.68) : .green.opacity(0.40))
                .frame(width: 3, height: 3)
            }
          }
        }
        .rotationEffect(.degrees(4))
        .offset(x: -152, y: 41)
        Path { path in
          path.move(to: CGPoint(x: 39, y: 69))
          path.addCurve(
            to: CGPoint(x: 92, y: 92),
            control1: CGPoint(x: 51, y: 84),
            control2: CGPoint(x: 78, y: 75)
          )
        }
        .stroke(.black.opacity(0.84), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      }
      .frame(width: 470, height: 170)
      .scaleEffect(layout.depthScale(for: .founderDesk) * layout.scale)
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

  private func practicalLighting(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      ForEach([
        CGPoint(x: 325, y: 145),
        CGPoint(x: 680, y: 130),
        CGPoint(x: 1_035, y: 145)
      ], id: \.x) { point in
        RadialGradient(
          colors: [
            .orange.opacity(0.16 * motion.lighting.practicalLightIntensity),
            .clear
          ],
          center: .center,
          startRadius: 4,
          endRadius: 120
        )
        .frame(width: 240, height: 210)
        .position(layout.viewportPosition(worldPoint: point, camera: camera, layer: .background))
      }

      ForEach([325.0, 680.0, 1_035.0], id: \.self) { worldX in
        Path { path in
          let source = layout.viewportPosition(
            worldPoint: CGPoint(x: worldX, y: 108),
            camera: camera,
            layer: .background
          )
          path.move(to: CGPoint(x: source.x - 26, y: source.y + 4))
          path.addLine(to: CGPoint(x: source.x - 94, y: size.height * 0.58))
          path.addLine(to: CGPoint(x: source.x + 94, y: size.height * 0.58))
          path.addLine(to: CGPoint(x: source.x + 26, y: source.y + 4))
          path.closeSubpath()
        }
        .fill(LinearGradient(
          colors: [Color.orange.opacity(0.055 * motion.lighting.practicalLightIntensity), .clear],
          startPoint: .top,
          endPoint: .bottom
        ))
      }

      stationLightSpill(
        agentID: "aurora",
        tone: .cyan,
        worldPoint: CGPoint(x: 325, y: 315),
        layout: layout
      )

      RadialGradient(
        colors: [Color.cyan.opacity(0.075 + motion.ambient.screenLife * 0.065), .clear],
        center: .center,
        startRadius: 8,
        endRadius: 150
      )
      .frame(width: 310, height: 205)
      .position(layout.viewportPosition(for: .signalTV, camera: camera, layer: .background))

      RadialGradient(
        colors: [Color.cyan.opacity(0.10 * motion.lighting.founderMonitorGlow), .clear],
        center: .center,
        startRadius: 8,
        endRadius: 150
      )
      .frame(width: 300, height: 170)
      .position(layout.viewportPosition(worldPoint: CGPoint(x: 680, y: 545), camera: camera, layer: .foreground))
      stationLightSpill(
        agentID: "stacks",
        tone: .orange,
        worldPoint: CGPoint(x: 680, y: 300),
        layout: layout
      )
      stationLightSpill(
        agentID: "brio",
        tone: .pink,
        worldPoint: CGPoint(x: 1_035, y: 315),
        layout: layout
      )

      floorLightReflection(agentID: "aurora", tone: .cyan, worldX: 325, layout: layout)
      floorLightReflection(agentID: "stacks", tone: .orange, worldX: 680, layout: layout)
      floorLightReflection(agentID: "brio", tone: .pink, worldX: 1_035, layout: layout)

      if motion.lighting.warningIntensity > 0 {
        Capsule()
          .fill(.orange.opacity(0.35 + motion.lighting.warningIntensity * 0.35))
          .frame(width: 54, height: 5)
          .position(
            layout.viewportPosition(
              worldPoint: CGPoint(x: 560, y: 590),
              camera: camera,
              layer: .foreground
            )
          )
      }
    }
    .allowsHitTesting(false)
  }

  private func livingElectricalLayer(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    let active = motion.ambient.continuousMotionEnabled
    let lighting = FounderGarageAmbientRhythm.profile(for: .environmentalLight)
    let display = FounderGarageAmbientRhythm.profile(for: .founderDisplay)
    return ZStack {
      Path { path in
        let source = layout.viewportPosition(
          worldPoint: CGPoint(x: 680, y: 104),
          camera: camera,
          layer: .background
        )
        path.move(to: CGPoint(x: source.x - 22, y: source.y + 4))
        path.addLine(to: CGPoint(x: source.x - 78, y: size.height * 0.60))
        path.addLine(to: CGPoint(x: source.x + 88, y: size.height * 0.60))
        path.addLine(to: CGPoint(x: source.x + 22, y: source.y + 4))
        path.closeSubpath()
      }
      .fill(LinearGradient(
        colors: [Color.orange.opacity(0.060), Color.cyan.opacity(0.025), .clear],
        startPoint: .top,
        endPoint: .bottom
      ))
      .phaseAnimator(active ? [0.74, 1.0, 0.82] : [0.80]) { content, opacity in
        content.opacity(opacity)
          .offset(x: active ? (opacity - 0.86) * 16 : 0)
      } animation: { _ in .easeInOut(duration: lighting.duration) }

      FounderGarageVentilationFanView(
        mechanical: motion.mechanical,
        increasedContrast: increasedContrast
      )
      .position(layout.viewportPosition(
        worldPoint: CGPoint(x: 680, y: 180),
        camera: camera,
        layer: .background
      ))

      Ellipse()
        .fill(.black.opacity(0.075))
        .frame(width: 155, height: 42)
        .phaseAnimator(
          motion.mechanical.continuousRotationEnabled ? [-3.0, 3.0, -3.0] : [0.0]
        ) { content, angle in
          content.rotationEffect(.degrees(angle))
            .offset(x: angle * 0.7)
        } animation: { _ in
          .easeInOut(duration: FounderGarageAmbientRhythm.profile(for: .ventilationShadow).duration)
        }
        .position(layout.viewportPosition(
          worldPoint: CGPoint(x: 700, y: 272),
          camera: camera,
          layer: .background
        ))

      RadialGradient(
        colors: [Color.cyan.opacity(0.035 + motion.ambient.screenLife * 0.055), .clear],
        center: .center,
        startRadius: 4,
        endRadius: 115
      )
      .frame(width: 230, height: 110)
      .phaseAnimator(active ? [0.96, 1.03, 0.98] : [1.0]) { content, scale in
        content.scaleEffect(scale)
      } animation: { _ in .easeInOut(duration: display.duration) }
      .position(layout.viewportPosition(
        worldPoint: CGPoint(x: 680, y: 520),
        camera: camera,
        layer: .foreground
      ))
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func stationLightSpill(
    agentID: String,
    tone: Color,
    worldPoint: CGPoint,
    layout: FounderEnvironmentLayout
  ) -> some View {
    let station = motion.station(for: agentID)
    let intensity = station?.physical.keyLightIntensity ?? 0.20
    let focal = station?.physical.focalEmphasis ?? 0.35
    let rhythm: FounderGarageAmbientRhythm = switch agentID {
    case "aurora": .profile(for: .auroraPresence)
    case "stacks": .profile(for: .stacksPresence)
    default: .profile(for: .brioPresence)
    }
    return RadialGradient(
      colors: [tone.opacity(0.035 + intensity * 0.12 + focal * 0.035), tone.opacity(intensity * 0.032), .clear],
      center: .center,
      startRadius: 8,
      endRadius: 145
    )
    .frame(width: 290, height: 230)
    .phaseAnimator(motion.ambient.continuousMotionEnabled ? [0.92, 1.05, 0.97] : [0.96]) { content, luminance in
      content.opacity(luminance)
    } animation: { _ in .easeInOut(duration: rhythm.duration) }
    .position(layout.viewportPosition(worldPoint: worldPoint, camera: camera, layer: .middleGround))
  }

  private func floorLightReflection(
    agentID: String,
    tone: Color,
    worldX: CGFloat,
    layout: FounderEnvironmentLayout
  ) -> some View {
    let intensity = motion.station(for: agentID)?.physical.deskLightIntensity ?? 0.18
    return Ellipse()
      .fill(RadialGradient(
        colors: [tone.opacity(intensity * 0.08), .clear],
        center: .center,
        startRadius: 2,
        endRadius: 74
      ))
      .frame(width: 150, height: 31)
      .position(layout.viewportPosition(
        worldPoint: CGPoint(x: worldX, y: 555),
        camera: camera,
        layer: .middleGround
      ))
  }

  private func ambientEquipmentLayer(size: CGSize, layout: FounderEnvironmentLayout) -> some View {
    ZStack {
      ambientFan(
        station: motion.station(for: "aurora"),
        tone: .cyan,
        active: motion.ambient.continuousMotionEnabled
      )
      .position(
        layout.viewportPosition(
          worldPoint: CGPoint(x: 245, y: 385),
          camera: camera,
          layer: .middleGround
        )
      )

      networkHardware
        .position(
          layout.viewportPosition(
            worldPoint: CGPoint(x: 540, y: 365),
            camera: camera,
            layer: .middleGround
          )
        )

      powerStrip
        .position(
          layout.viewportPosition(
            worldPoint: CGPoint(x: 690, y: 575),
            camera: camera,
            layer: .foreground
          )
        )

      ambientFan(
        station: motion.station(for: "stacks"),
        tone: .orange,
        active: motion.ambient.continuousMotionEnabled
      )
      .position(
        layout.viewportPosition(
          worldPoint: CGPoint(x: 790, y: 365),
          camera: camera,
          layer: .middleGround
        )
      )

      ambientFan(
        station: motion.station(for: "brio"),
        tone: .pink,
        active: motion.ambient.continuousMotionEnabled
      )
      .opacity(motion.lighting.brioPublicSignalStability)
      .position(
        layout.viewportPosition(
          worldPoint: CGPoint(x: 1_145, y: 385),
          camera: camera,
          layer: .middleGround
        )
      )
    }
    .allowsHitTesting(false)
  }

  private var networkHardware: some View {
    let active = motion.infrastructure.continuousMotionEnabled
    let activity = motion.infrastructure.routerActivity
    return ZStack {
      RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.92)).frame(width: 74, height: 32)
      HStack(spacing: 5) {
        ForEach(0..<7, id: \.self) { index in
          Circle()
            .fill(index.isMultiple(of: 3) ? Color.green : Color.cyan)
            .frame(width: 4, height: 4)
            .phaseAnimator(active ? [0.25, 0.95, 0.42] : [0.35]) { content, opacity in
              content.opacity(index.isMultiple(of: 2) ? opacity * (0.55 + activity * 0.45) : 0.40 + activity * 0.38)
            } animation: { _ in
              .easeInOut(duration: max(0.72, FounderGarageAmbientRhythm.profile(for: .router).duration - activity * 0.44 + Double(index % 3) * 0.21))
            }
        }
      }
      Capsule().fill(.white.opacity(0.14)).frame(width: 48, height: 2).offset(y: 10)
    }
    .overlay { RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.18), lineWidth: 1) }
  }

  private var powerStrip: some View {
    HStack(spacing: 8) {
      ForEach(0..<4, id: \.self) { index in
        Circle().stroke(.white.opacity(0.28), lineWidth: 1).frame(width: 11, height: 11)
        if index < 3 { Circle().fill(.green.opacity(0.66)).frame(width: 3, height: 3) }
      }
    }
    .padding(.horizontal, 9)
    .frame(height: 22)
    .background(.black.opacity(0.88), in: Capsule())
  }

  private func ambientFan(
    station: FounderGarageStationMotion?,
    tone: Color,
    active: Bool
  ) -> some View {
    let cooling = station?.physical.coolingActivity ?? 0
    let rotates = active && cooling > 0.08
    return ZStack {
      Circle().stroke(.white.opacity(0.18), lineWidth: 2).frame(width: 30, height: 30)
      Image(systemName: "fanblades.fill")
        .font(.system(size: 16))
        .foregroundStyle(tone.opacity(0.34 + (station?.equipmentActivity ?? 0) * 0.54))
        .phaseAnimator(rotates ? [0.0, 360.0] : [0.0]) { content, angle in
          content.rotationEffect(.degrees(angle))
        } animation: { _ in
          .linear(duration: max(3.0, 7.8 - (station?.equipmentActivity ?? 0) * 4.2))
        }
    }
  }

  private func atmosphere(size: CGSize) -> some View {
    ZStack {
      LinearGradient(
        colors: [.clear, Color(red: 0.13, green: 0.15, blue: 0.16).opacity(0.08), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: size.height * 0.62)
      .offset(y: -size.height * 0.08)

      ForEach(0..<motion.environment.atmosphericParticleCount, id: \.self) { index in
        Circle()
          .fill(.white.opacity(index.isMultiple(of: 3) ? 0.13 : 0.065))
          .frame(width: CGFloat(1 + index % 2), height: CGFloat(1 + index % 2))
          .position(
            x: size.width * (0.39 + CGFloat((index * 37 + 11) % 97) / 97 * 0.22),
            y: size.height * (0.18 + CGFloat((index * 41) % 47) / 100)
          )
          .phaseAnimator(motion.environment.atmosphericMotionEnabled ? [0.0, 1.0, 0.15] : [0.0]) { content, phase in
            content
              .offset(x: CGFloat(index % 3 - 1) * 6 * phase, y: -12 * phase)
              .opacity(0.42 + phase * 0.58)
          } animation: { _ in
            .easeInOut(duration: FounderGarageAmbientRhythm.profile(for: .atmosphericDust).duration + Double(index % 4) * 1.1)
          }
      }
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

private struct FounderCoffeeCupView: View {
  var steamActive: Bool

  var body: some View {
    ZStack {
      Image(systemName: "mug.fill")
        .foregroundStyle(.orange.opacity(0.78))
        .font(.title2)
      steamWisp(index: 0)
      steamWisp(index: 1)
    }
    .accessibilityHidden(true)
  }

  private func steamWisp(index: Int) -> some View {
    let restingX = CGFloat(index * 7 - 3)
    let driftX: CGFloat = index == 0 ? -3 : 3
    let opacity = 0.10 - Double(index) * 0.025
    let duration = 5.8 + Double(index) * 1.2
    return Capsule()
      .fill(.white.opacity(opacity))
      .frame(width: 3, height: 17)
      .blur(radius: 1.2)
      .offset(x: restingX, y: -17)
      .phaseAnimator(steamActive ? [0.0, 1.0, 0.0] : [0.0]) { content, phase in
        content
          .offset(x: phase * driftX, y: -phase * 8)
          .opacity(0.32 + phase * 0.42)
      } animation: { _ in
        .easeInOut(duration: duration)
      }
  }
}

struct FounderGarageForegroundFramingView: View {
  var camera: FounderEnvironmentCameraState
  var monitorOffset: CGSize
  var monitorSize: CGSize
  var increasedContrast: Bool

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack {
        Path { path in
          path.move(to: CGPoint(x: -18, y: size.height * 0.91))
          path.addLine(to: CGPoint(x: size.width + 18, y: size.height * 0.91))
          path.addLine(to: CGPoint(x: size.width + 34, y: size.height + 8))
          path.addLine(to: CGPoint(x: -34, y: size.height + 8))
          path.closeSubpath()
        }
        .fill(LinearGradient(
          colors: [Color(red: 0.19, green: 0.115, blue: 0.065), Color(red: 0.055, green: 0.035, blue: 0.025)],
          startPoint: .top,
          endPoint: .bottom
        ))
        .overlay(alignment: .top) {
          Rectangle().fill(.white.opacity(increasedContrast ? 0.22 : 0.10)).frame(height: 2)
            .offset(y: size.height * 0.91)
        }

        RoundedRectangle(cornerRadius: 18)
          .stroke(.black.opacity(0.88), lineWidth: 13)
          .frame(width: 74, height: 160)
          .rotationEffect(.degrees(-8))
          .position(x: -4 - CGFloat(camera.horizontalLook) * 22, y: size.height * 0.78)

        RoundedRectangle(cornerRadius: 5)
          .fill(LinearGradient(colors: [.black, Color(red: 0.09, green: 0.10, blue: 0.105)], startPoint: .leading, endPoint: .trailing))
          .frame(width: 43, height: size.height * 0.47)
          .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.08)).frame(width: 2) }
          .overlay(alignment: .center) {
            VStack(spacing: 9) {
              ForEach(0..<7, id: \.self) { index in
                HStack(spacing: 4) {
                  Circle().fill(index.isMultiple(of: 3) ? Color.green.opacity(0.72) : Color.cyan.opacity(0.45)).frame(width: 3, height: 3)
                  Capsule().fill(.white.opacity(0.10)).frame(width: 21, height: 2)
                }
              }
            }
          }
          .position(x: size.width + 13 - CGFloat(camera.horizontalLook) * 34, y: size.height * 0.66)

        Path { path in
          let start = CGPoint(
            x: size.width / 2 + monitorOffset.width + monitorSize.width * 0.20,
            y: size.height / 2 + monitorOffset.height + monitorSize.height * 0.47
          )
          path.move(to: start)
          path.addCurve(
            to: CGPoint(x: size.width * 0.71, y: size.height * 0.96),
            control1: CGPoint(x: start.x + 15, y: start.y + 42),
            control2: CGPoint(x: size.width * 0.63, y: size.height * 0.88)
          )
        }
        .stroke(.black.opacity(0.88), style: StrokeStyle(lineWidth: 5, lineCap: .round))
      }
      .frame(width: size.width, height: size.height)
    }
  }
}

struct FounderPhysicalMonitorView<Content: View>: View {
  var focused: Bool
  var width: CGFloat
  var height: CGFloat
  var commandViewportSize: CGSize
  var camera: FounderEnvironmentCameraState
  var worldOffset: CGSize
  var increasedContrast: Bool
  var monitorGlowIntensity: Double
  var notificationIntensity: Double
  var eventToken: UUID?
  var reduceMotion: Bool
  @ViewBuilder var content: Content

  var body: some View {
    let focusedCornerRadius: CGFloat = focused ? 0 : 13
    let screenInset: CGFloat = focused ? 0 : 7
    let contentScale = FounderCommandFocusLayout.contentScale(
      commandViewport: commandViewportSize,
      monitorSize: CGSize(width: width, height: height),
      focused: focused,
      screenInset: screenInset
    )
    ZStack {
      RoundedRectangle(cornerRadius: focusedCornerRadius)
        .fill(Color(red: 0.025, green: 0.028, blue: 0.032))
        .offset(x: focused ? 3 : 5, y: focused ? 5 : 7)
        .shadow(color: .black.opacity(0.78), radius: focused ? 14 : 8, y: 8)
        .allowsHitTesting(false)
      RoundedRectangle(cornerRadius: focusedCornerRadius)
        .fill(LinearGradient(
          colors: [Color(red: 0.12, green: 0.13, blue: 0.14), .black],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
        .overlay { RoundedRectangle(cornerRadius: focusedCornerRadius).stroke(.white.opacity(focused ? 0.08 : increasedContrast ? 0.94 : 0.38), lineWidth: focused ? 1 : 2) }
        .shadow(
          color: .cyan.opacity((focused ? 0.20 : 0.08) * monitorGlowIntensity),
          radius: focused ? 18 : 8
        )
      content
        .frame(width: commandViewportSize.width, height: commandViewportSize.height, alignment: .topLeading)
        .scaleEffect(contentScale, anchor: .topLeading)
        .frame(
          width: max(0, width - screenInset * 2),
          height: max(0, height - screenInset * 2),
          alignment: .topLeading
        )
        .clipShape(.rect(cornerRadius: focused ? 0 : 8))
        .padding(screenInset)
      LinearGradient(colors: [.white.opacity(0.11), .clear], startPoint: .topLeading, endPoint: .center)
        .clipShape(.rect(cornerRadius: focused ? 0 : 8))
        .padding(screenInset)
        .allowsHitTesting(false)
      Rectangle()
        .fill(
          LinearGradient(
            colors: [.clear, .white.opacity(0.055), .clear],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(height: max(18, height * 0.11))
        .phaseAnimator(reduceMotion ? [0.0] : [-0.38, 0.38]) { content, phase in
          content.offset(y: height * phase)
        } animation: { _ in .linear(duration: 4.8) }
        .clipShape(.rect(cornerRadius: focused ? 0 : 8))
        .padding(screenInset)
        .allowsHitTesting(false)
      if !focused {
        HStack(spacing: 4) {
          ForEach(0..<5, id: \.self) { _ in
            Capsule().fill(.white.opacity(0.16)).frame(width: 5, height: 2)
          }
        }
        .position(x: width / 2, y: height - 4)
        .allowsHitTesting(false)
      }
      Circle()
        .fill(notificationIntensity > 0 ? Color.orange : Color.white.opacity(0.24))
        .frame(width: 7, height: 7)
        .position(x: width - (focused ? 10 : 18), y: height - (focused ? 10 : 12))
        .phaseAnimator([0.72, 1.0, 0.72], trigger: eventToken) { content, phase in
          content
            .opacity(reduceMotion ? max(0.45, notificationIntensity) : notificationIntensity * phase)
            .scaleEffect(reduceMotion ? 1 : phase)
        } animation: { _ in
          .smooth(duration: 0.24)
        }
        .allowsHitTesting(false)
    }
    .frame(width: width, height: height)
    .scaleEffect(focused ? 1 : 0.98)
    .offset(x: worldOffset.width, y: focused ? 0 : worldOffset.height)
    .overlay(alignment: .trailing) {
      RoundedRectangle(cornerRadius: 2)
        .fill(.black.opacity(0.88))
        .frame(width: focused ? 1 : 5, height: height * 0.68)
        .offset(x: focused ? 0 : 4)
        .allowsHitTesting(false)
    }
  }
}

struct FounderEnvironmentControlLayer: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var cameraAlternativesExpanded = false

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
          Label("LOOK OUT", systemImage: "binoculars.fill")
            .font(.caption2.weight(.black))
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(.black.opacity(0.78), in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.30), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel("Look Out")
        .accessibilityHint("Pulls away from Company Command to observe the Founder Garage.")
        .position(x: proxy.size.width / 2, y: 24)
      } else if mode == .freeLook {
        Text("FOUNDER GARAGE · FREE LOOK")
          .font(.caption2.monospaced().weight(.black))
          .foregroundStyle(.white.opacity(0.82))
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(.black.opacity(0.62), in: Capsule())
          .position(x: 112, y: 20)
          .accessibilityAddTraits(.isHeader)

        HStack(spacing: 6) {
          if FounderDeskCameraChromePolicy.exposesManualControls(
            expanded: cameraAlternativesExpanded,
            accessibilityText: dynamicTypeSize.isAccessibilitySize
          ) {
            Button("Look Left", systemImage: "chevron.left") {
              onLook(-1, 0)
              cameraAlternativesExpanded = false
            }
            .labelStyle(.iconOnly)
            Button("Center", systemImage: "viewfinder") {
              onCenter()
              cameraAlternativesExpanded = false
            }
            .labelStyle(.iconOnly)
            Button("Look Right", systemImage: "chevron.right") {
              onLook(1, 0)
              cameraAlternativesExpanded = false
            }
            .labelStyle(.iconOnly)
          } else {
            Button("Camera controls", systemImage: "move.3d") {
              withAnimation(reduceMotion ? nil : .snappy(duration: 0.20)) {
                cameraAlternativesExpanded = true
              }
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("free-look-camera-controls")
            .accessibilityHint("Shows Look Left, Center, and Look Right controls")
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.white)
        .padding(5)
        .background(.black.opacity(0.58), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
        .position(
          x: proxy.size.width / 2,
          y: proxy.size.height - 34
        )

        Button("Return to Founder Computer", systemImage: "desktopcomputer") { onFocusComputer() }
          .labelStyle(.iconOnly)
          .buttonStyle(.bordered)
          .controlSize(.large)
          .tint(.white)
          .frame(minWidth: 44, minHeight: 44)
          .background(.black.opacity(0.54), in: .circle)
          .accessibilityIdentifier("free-look-return-computer")
          .position(x: proxy.size.width - 29, y: 24)
      }
    }
  }
}
