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
  @AccessibilityFocusState private var environmentIsFocused: Bool
  @AccessibilityFocusState private var computerIsFocused: Bool

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let environment = environmentProjection
        let focused = camera.mode == .computerFocused
        let monitorWidth = monitorWidth(for: geometry.size, focused: focused)
        let monitorHeight = monitorHeight(for: geometry.size, focused: focused)

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
            increasedContrast: contrast == .increased
          ) {
            FounderComputerScreen(store: store, presentation: presentation)
              .allowsHitTesting(camera.computerAllowsHitTesting)
              .accessibilityHidden(!camera.computerAllowsHitTesting)
              .accessibilityFocused($computerIsFocused)
          }
          .onTapGesture {
            guard camera.mode == .freeLook else { return }
            focusComputer()
          }
          .accessibilityAddTraits(camera.mode == .freeLook ? .isButton : [])
          .accessibilityLabel(camera.mode == .freeLook ? "Founder Computer" : "Founder Computer, interactive")
          .accessibilityHint(camera.mode == .freeLook ? "Double tap to return to the Founder Computer." : "Company Command is ready.")

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
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .contentShape(.rect)
        .gesture(environmentDragGesture)
        .animation(reduceMotion ? nil : .smooth(duration: 0.34), value: camera.mode)
        .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: camera.horizontalLook)
        .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: camera.verticalLook)
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

  private var environmentDragGesture: some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        guard camera.environmentAllowsCameraGestures else { return }
        camera.setLook(
          horizontal: Double(value.translation.width / 180),
          vertical: Double(-value.translation.height / 520),
          reduceMotion: reduceMotion
        )
      }
  }

  private func monitorWidth(for size: CGSize, focused: Bool) -> CGFloat {
    let margin: CGFloat = dynamicTypeSize.isAccessibilitySize ? 4 : 12
    return focused ? size.width - margin * 2 : min(size.width * 0.72, 420)
  }

  private func monitorHeight(for size: CGSize, focused: Bool) -> CGFloat {
    focused ? min(size.height * 0.82, 780) : min(size.height * 0.54, 500)
  }

  private func enterFreeLook() {
    guard camera.mode != .freeLook else { return }
    camera.mode = .freeLook
    environmentIsFocused = true
  }

  private func focusComputer() {
    guard camera.mode != .computerFocused else { return }
    camera.mode = .computerFocused
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
      ZStack {
        roomBackground(size: size)
        structure(size: size)
        stationLayer(size: size)
        atmosphere(size: size)
        deskForeground(size: size)
      }
      .frame(width: size.width, height: size.height)
      .clipped()
    }
    .accessibilityLabel("Founder environment. \(projection.accessibilitySummary)")
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
      station("aurora", role: "Research", symbol: "microscope", x: -0.31, y: -0.04, size: size)
      station("stacks", role: "Engineering", symbol: "wrench.and.screwdriver.fill", x: 0.30, y: -0.02, size: size)
      station("brio", role: "Campaign", symbol: "megaphone.fill", x: 0.39, y: 0.20, size: size)
      infrastructure(size: size)
    }
  }

  private func station(_ id: String, role: String, symbol: String, x: CGFloat, y: CGFloat, size: CGSize) -> some View {
    let agent = projection.agents.first { $0.agentID == id }
    let isAttention = agent?.needsFounderAttention == true
    return VStack(spacing: 3) {
      RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.65)).frame(width: 58, height: 35)
        .overlay(Image(systemName: symbol).foregroundStyle(isAttention ? .yellow : .cyan).font(.caption))
      Capsule().fill(.black.opacity(0.55)).frame(width: 75, height: 8)
      Text(role).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.82))
    }
    .offset(x: x * size.width + CGFloat(camera.horizontalLook) * 28, y: y * size.height + CGFloat(camera.verticalLook) * 16)
    .accessibilityHidden(true)
  }

  private func infrastructure(size: CGSize) -> some View {
    ZStack {
      ForEach(projection.infrastructure) { item in
        let position = infrastructurePosition(for: item.physicalLocation, size: size)
        Image(systemName: item.symbol)
          .font(.caption.weight(.bold))
          .foregroundStyle(item.state == .active ? .green : item.state == .uninstalled ? .gray : .white.opacity(0.78))
          .frame(width: 26, height: 26)
          .background(.black.opacity(item.state == .uninstalled ? 0.22 : 0.58), in: .rect(cornerRadius: 6))
          .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(increasedContrast ? 0.78 : 0.24), lineWidth: 1) }
          .offset(x: position.x + CGFloat(camera.horizontalLook) * 22, y: position.y + CGFloat(camera.verticalLook) * 14)
      }
    }
    .accessibilityHidden(true)
  }

  private func infrastructurePosition(for location: InfrastructurePhysicalLocation, size: CGSize) -> CGPoint {
    switch location {
    case .stacksBuildRail: CGPoint(x: size.width * 0.28, y: -size.height * 0.10)
    case .auroraFounderVerificationBridge: CGPoint(x: -size.width * 0.28, y: -size.height * 0.10)
    case .brioBroadcastRail: CGPoint(x: size.width * 0.38, y: size.height * 0.12)
    case .recoverySideBay: CGPoint(x: -size.width * 0.39, y: size.height * 0.18)
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
    .scaleEffect(focused ? 1 : 0.95)
    .offset(x: focused ? 0 : CGFloat(camera.horizontalLook) * -46, y: focused ? -6 : CGFloat(camera.verticalLook) * -28)
  }
}

struct FounderEnvironmentControlLayer: View {
  var mode: FounderEnvironmentMode
  var reduceMotion: Bool
  var onLookAround: () -> Void
  var onFocusComputer: () -> Void
  var onLook: (Double, Double) -> Void
  var onCenter: () -> Void

  var body: some View {
    VStack {
      HStack {
        Spacer()
        if mode == .computerFocused {
          Button("Look Around", systemImage: "view.3d") { onLookAround() }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.72))
            .accessibilityHint("Recedes the monitor and enables room camera controls.")
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      Spacer()
      if mode == .freeLook {
        HStack(spacing: 10) {
          Button("Look Left", systemImage: "chevron.left") { onLook(-1, 0) }.labelStyle(.iconOnly)
          Button("Center", systemImage: "viewfinder") { onCenter() }.labelStyle(.iconOnly)
          Button("Look Right", systemImage: "chevron.right") { onLook(1, 0) }.labelStyle(.iconOnly)
          Button("Look Up", systemImage: "chevron.up") { onLook(0, 0.30) }.labelStyle(.iconOnly)
          Button("Look Down", systemImage: "chevron.down") { onLook(0, -0.30) }.labelStyle(.iconOnly)
          Button("Return to Founder Computer", systemImage: "desktopcomputer") { onFocusComputer() }.labelStyle(.iconOnly)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black.opacity(0.78))
        .padding(12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 18)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(true)
  }
}
