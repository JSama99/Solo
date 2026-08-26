import SwiftUI

struct FounderDeskWorkspace: View {
  var store: GameStore
  var presentation: PresentationCoordinator

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(AchievementStore.self) private var achievements
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var navigation = FounderDeskNavigationState()
  @State private var computerRequest: FounderComputerWorkspaceRequest?
  @State private var selectionFeedback = 0
  @AccessibilityFocusState private var focusedDevice: FounderDeskDevice?
  @AccessibilityFocusState private var deskIsFocused: Bool

  var body: some View {
    GeometryReader { geometry in
      let projection = environmentProjection
      let camera = overviewCamera
      let motion = FounderGarageMotionPresentation.derive(
        environment: projection,
        camera: camera,
        reduceMotion: reduceMotion,
        sceneActive: scenePhase == .active
      )

      ZStack {
        FounderEnvironmentRendererView(
          projection: projection,
          camera: camera,
          motion: motion,
          increasedContrast: contrast == .increased
        )
        .allowsHitTesting(false)
        .accessibilityHidden(navigation.selection != .overview)
        .scaleEffect(environmentScale)
        .brightness(navigation.selection == .overview ? 0 : -0.16)

        if navigation.selection == .overview {
          deskOverview(size: geometry.size)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        }

        persistentFocusedDevices(size: geometry.size)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
      .animation(reduceMotion ? .easeOut(duration: 0.14) : .smooth(duration: 0.38), value: navigation.selection)
      .sensoryFeedback(.selection, trigger: selectionFeedback)
      .onChange(of: store.stats.trackRecord, initial: true) { _, value in
        progression.observe(trackRecord: value)
      }
      .accessibilityAction(named: Text("Return to Desk Overview")) { returnToDesk() }
    }
  }

  private var environmentScale: CGFloat {
    switch navigation.selection {
    case .overview: 1
    case .device: horizontalSizeClass == .regular ? 1.035 : 1.075
    }
  }

  private var overviewCamera: FounderEnvironmentCameraState {
    var camera = FounderEnvironmentCameraState()
    camera.mode = .freeLook
    camera.verticalLook = horizontalSizeClass == .regular ? -0.05 : -0.11
    return camera
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
    return FounderEnvironmentProjection(
      facility: progression.currentFacility,
      atmosphere: CompanyAtmosphere.derive(
        stats: store.stats,
        facility: progression.currentFacility,
        venture: store.venture
      ),
      infrastructure: InfrastructureVisual.map(
        purchased: progression.purchasedUpgrades,
        facility: progression.currentFacility,
        agents: agents,
        sprint: store.sprint
      ),
      agents: agents,
      visibleEvent: visibleGarageEvent
    )
  }

  private var visibleGarageEvent: FounderGarageVisibleEvent? {
    switch presentation.latestEvent {
    case .assignment(let id, _, let agentID, _): .assignment(id: id, agentID: agentID)
    case .review(let id, _, let agentID, _, _): .review(id: id, agentID: agentID)
    case .sprint(let id, _): .sprint(id: id)
    case nil: nil
    }
  }

  private var previewInput: FounderDeskPreviewInput {
    let venture = VentureScreenPresentation(store: store)
    return FounderDeskPreviewInput(
      sprint: store.sprint,
      venture: store.venture,
      sprintPhase: store.sprintPhase,
      visibleWorkCount: store.tasks.filter { $0.assignedAgentID != nil && !$0.isReviewed }.count,
      visibleReviewCount: store.sprintPhase == .reviewAndResolve
        ? store.tasks.filter { $0.assignedAgentID != nil && !$0.isReviewed }.count
        : 0,
      evidenceCount: store.evidence.count,
      canCommit: store.canCommitSprint,
      latestPublishedHeadline: store.techComHeadlines.first?.text,
      marketRank: store.rivalStandings.firstIndex(where: \.isPlayer).map { $0 + 1 },
      ventureObjective: venture.objective.title,
      ventureObjectiveComplete: venture.objective.isComplete,
      facilityName: progression.currentFacility.name,
      achievementCount: achievements.unlockedCount,
      ownedFacilityCount: progression.ownedFacilities.count
    )
  }

  @ViewBuilder
  private func deskOverview(size: CGSize) -> some View {
    if FounderDeskLayoutPolicy.layout(
      regularWidth: horizontalSizeClass == .regular,
      accessibilityText: dynamicTypeSize.isAccessibilitySize,
      height: size.height
    ) == .accessibleList {
      accessibleOverview
    } else {
      spatialOverview(size: size)
    }
  }

  private var accessibleOverview: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        overviewAccessibilityMarker
        deskHeading
        deviceButton(.computer, style: .wide)
        deviceButton(.phone, style: .wide)
        deviceButton(.tablet, style: .wide)
        deviceButton(.server, style: .wide)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.black.opacity(0.32))
    .accessibilityFocused($deskIsFocused)
  }

  private func spatialOverview(size: CGSize) -> some View {
    ZStack {
      overviewAccessibilityMarker

      LinearGradient(
        colors: [.clear, .black.opacity(0.08), .black.opacity(0.52)],
        startPoint: .top,
        endPoint: .bottom
      )
      .allowsHitTesting(false)

      deskHeading
        .position(x: size.width / 2, y: max(54, size.height * 0.09))

      deviceButton(.computer, style: .computer)
        .frame(width: min(size.width * (horizontalSizeClass == .regular ? 0.54 : 0.66), 560))
        .position(x: size.width * 0.50, y: size.height * 0.39)

      deviceButton(.phone, style: .phone)
        .frame(width: horizontalSizeClass == .regular ? 150 : 112)
        .rotationEffect(.degrees(-7))
        .position(x: size.width * (horizontalSizeClass == .regular ? 0.24 : 0.18), y: size.height * 0.73)

      deviceButton(.tablet, style: .tablet)
        .frame(width: min(size.width * (horizontalSizeClass == .regular ? 0.32 : 0.38), 310))
        .rotationEffect(.degrees(3))
        .position(x: size.width * (horizontalSizeClass == .regular ? 0.74 : 0.77), y: size.height * 0.68)

      deviceButton(.server, style: .server)
        .frame(width: horizontalSizeClass == .regular ? 168 : 118)
        .position(x: size.width * (horizontalSizeClass == .regular ? 0.89 : 0.88), y: size.height * 0.37)

      Text("Select equipment to focus")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.52), in: .capsule)
        .position(x: size.width / 2, y: size.height - 24)
        .accessibilityHidden(true)
    }
    .accessibilityFocused($deskIsFocused)
  }

  private var deskHeading: some View {
    VStack(spacing: 3) {
      Text("\(progression.currentFacility.name.uppercased()) · FOUNDER DESK")
        .font(.caption2.weight(.black))
        .tracking(1.6)
        .foregroundStyle(SoloTheme.cyan)
      Text("Company workspace")
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
        .accessibilityIdentifier("founder-desk-overview")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.black.opacity(0.58), in: .capsule)
    .accessibilityElement(children: .combine)
  }

  private var overviewAccessibilityMarker: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .accessibilityElement()
      .accessibilityLabel("Founder Desk Overview")
      .accessibilityIdentifier("founder-desk-overview")
  }

  private func deviceButton(_ device: FounderDeskDevice, style: DeskDeviceStyle) -> some View {
    let preview = FounderDeskPreviewPolicy.preview(for: device, input: previewInput)
    return Button {
      select(device)
    } label: {
      FounderDeskDeviceObject(device: device, preview: preview, style: style, increasedContrast: contrast == .increased)
        .contentShape(.rect)
    }
    .buttonStyle(SoloPressStyle())
    .accessibilityLabel(preview.accessibilityLabel)
    .accessibilityHint("Focuses this physical device. Close returns to the same Founder Desk.")
    .accessibilityIdentifier("founder-desk-device-\(device.rawValue)")
    .accessibilityFocused($focusedDevice, equals: device)
  }

  private func persistentFocusedDevices(size: CGSize) -> some View {
    ZStack {
      focusedDevice(.computer, size: size) {
        FounderComputerScreen(
          store: store,
          presentation: presentation,
          workspaceRequest: computerRequest
        )
      }
      focusedDevice(.phone, size: size) { TechComScreen(store: store) }
      focusedDevice(.tablet, size: size) { VentureScreen(store: store) }
      focusedDevice(.server, size: size) {
        CompanyServerScreen(store: store) { target in
          computerRequest = FounderComputerWorkspaceRequest(target: target)
          select(.computer)
        }
      }
    }
  }

  private func focusedDevice<Content: View>(
    _ device: FounderDeskDevice,
    size: CGSize,
    @ViewBuilder content: () -> Content
  ) -> some View {
    let selected = navigation.selection == .device(device)
    let frame = FounderFocusedDeviceFrame(
      device: device,
      availableSize: size,
      regularWidth: horizontalSizeClass == .regular,
      increasedContrast: contrast == .increased,
      isFocused: selected,
      onClose: returnToDesk,
      content: content
    )
    return frame
      .opacity(selected ? 1 : 0)
      .scaleEffect(selected || reduceMotion ? 1 : 0.90)
      .allowsHitTesting(selected)
      .accessibilityHidden(!selected)
      .zIndex(selected ? 10 : -1)
  }

  private func select(_ device: FounderDeskDevice) {
    withAnimation(navigation.transitionStyle(reduceMotion: reduceMotion) == .crossfade ? .easeOut(duration: 0.14) : .smooth(duration: 0.38)) {
      navigation.select(device)
    }
    selectionFeedback += 1
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(360)) }
      focusedDevice = device
    }
  }

  private func returnToDesk() {
    withAnimation(navigation.transitionStyle(reduceMotion: reduceMotion) == .crossfade ? .easeOut(duration: 0.14) : .smooth(duration: 0.34)) {
      navigation.returnToDesk()
    }
    selectionFeedback += 1
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(300)) }
      deskIsFocused = true
    }
  }
}

private enum DeskDeviceStyle {
  case computer
  case phone
  case tablet
  case server
  case compact
  case wide
}

private struct FounderDeskDeviceObject: View {
  var device: FounderDeskDevice
  var preview: FounderDeskPreview
  var style: DeskDeviceStyle
  var increasedContrast: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Image(systemName: device.symbol)
        Text(preview.title)
          .lineLimit(1)
        Spacer(minLength: 2)
        if preview.signal != nil {
          signalLanguage
        }
      }
      .font(.caption2.weight(.black))
      .foregroundStyle(deviceTone)

      Text(preview.primary)
        .font(primaryFont)
        .foregroundStyle(.white)
        .lineLimit(style == .phone ? 3 : 2)
        .minimumScaleFactor(0.72)
      Text(preview.secondary)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.68))
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
    .padding(contentPadding)
    .background(deviceBody)
    .overlay { deviceHardware }
    .shadow(color: .black.opacity(0.72), radius: 9, y: 7)
    .overlay(alignment: .bottom) {
      if style == .computer {
        monitorStand
      }
    }
  }

  private var deviceTone: Color {
    switch device {
    case .computer: SoloTheme.cyan
    case .phone: .white
    case .tablet: SoloTheme.amber
    case .server: SoloTheme.mint
    }
  }

  private var primaryFont: Font { style == .computer || style == .wide ? .subheadline.weight(.bold) : .caption.weight(.bold) }
  private var minimumHeight: CGFloat {
    switch style {
    case .computer: 116
    case .phone: 150
    case .tablet: 112
    case .server: 162
    case .compact: 110
    case .wide: 96
    }
  }
  private var contentPadding: CGFloat { style == .phone ? 11 : 13 }

  private var deviceBody: some ShapeStyle {
    LinearGradient(
      colors: [Color(red: 0.08, green: 0.10, blue: 0.12), Color.black.opacity(0.94)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var deviceHardware: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .stroke(increasedContrast ? .white : deviceTone.opacity(0.72), lineWidth: increasedContrast ? 3 : 1.5)
      .overlay(alignment: style == .server ? .leading : .top) {
        hardwareDetail
      }
  }

  @ViewBuilder
  private var hardwareDetail: some View {
    if style == .phone {
      Capsule().fill(.black).frame(width: 34, height: 8).padding(.top, 5)
    } else if style == .server {
      VStack(spacing: 8) {
        ForEach(0..<4, id: \.self) { index in
          HStack(spacing: 4) {
            Circle().fill(index == 0 && preview.signal != nil ? SoloTheme.mint : .white.opacity(0.25)).frame(width: 5, height: 5)
            Capsule().fill(.white.opacity(0.14)).frame(width: 28, height: 3)
          }
        }
      }
      .padding(8)
    }
  }

  private var signalLanguage: some View {
    Group {
      switch device {
      case .computer: Image(systemName: "tray.full.fill")
      case .phone: Image(systemName: "wave.3.right")
      case .tablet: Image(systemName: "scope")
      case .server: Image(systemName: "lightspectrum.horizontal")
      }
    }
    .accessibilityHidden(true)
  }

  private var monitorStand: some View {
    VStack(spacing: 0) {
      Rectangle().fill(.black.opacity(0.86)).frame(width: 28, height: 13)
      Capsule().fill(.black.opacity(0.92)).frame(width: 72, height: 7)
    }
    .offset(y: 18)
    .accessibilityHidden(true)
  }

  private var cornerRadius: CGFloat {
    switch style {
    case .phone: 22
    case .tablet: 14
    case .server: 8
    default: 12
    }
  }
}

private struct FounderFocusedDeviceFrame<Content: View>: View {
  var device: FounderDeskDevice
  var availableSize: CGSize
  var regularWidth: Bool
  var increasedContrast: Bool
  var isFocused: Bool
  var onClose: () -> Void
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Button("Return to Founder Desk", systemImage: "xmark") { onClose() }
          .labelStyle(.iconOnly)
          .buttonStyle(.bordered)
          .accessibilityIdentifier("return-to-founder-desk-\(device.rawValue)")
          .accessibilityHidden(!isFocused)
          .accessibilityHint("Returns to the spatial desk overview without resetting this device")
        Label(device.title, systemImage: device.symbol)
          .font(.caption.weight(.black))
          .lineLimit(1)
        Spacer()
        Text("FOCUSED")
          .font(.caption2.weight(.black))
          .tracking(1.2)
          .foregroundStyle(SoloTheme.cyan)
      }
      .padding(.horizontal, 12)
      .frame(height: 48)
      .background(.black.opacity(0.94))
      .accessibilityHidden(!isFocused)

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SoloTheme.background)
        .clipShape(.rect(cornerRadius: contentCornerRadius))
        .padding(device == .computer ? 0 : frameInset)
        .accessibilityHidden(!isFocused)
    }
    .frame(width: frameWidth, height: frameHeight)
    .background(
      LinearGradient(colors: [Color(red: 0.14, green: 0.15, blue: 0.17), .black], startPoint: .top, endPoint: .bottom)
    )
    .clipShape(.rect(cornerRadius: outerCornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: outerCornerRadius)
        .stroke(increasedContrast ? .white : .white.opacity(0.24), lineWidth: increasedContrast ? 3 : 1)
    }
    .shadow(color: .black.opacity(0.84), radius: 24, y: 14)
    .accessibilityElement(children: isFocused ? .contain : .ignore)
  }

  private var frameWidth: CGFloat {
    if device == .computer { return availableSize.width }
    return min(availableSize.width - (regularWidth ? 64 : 18), regularWidth ? 980 : availableSize.width)
  }

  private var frameHeight: CGFloat {
    if device == .computer { return availableSize.height }
    return max(320, availableSize.height - (regularWidth ? 52 : 12))
  }

  private var frameInset: CGFloat {
    switch device {
    case .phone: regularWidth ? 18 : 5
    case .tablet: regularWidth ? 14 : 5
    case .server: regularWidth ? 12 : 4
    case .computer: 0
    }
  }

  private var outerCornerRadius: CGFloat {
    switch device {
    case .phone: 32
    case .tablet: 24
    case .server: 12
    case .computer: 0
    }
  }

  private var contentCornerRadius: CGFloat { device == .computer ? 0 : max(8, outerCornerRadius - 8) }
}
