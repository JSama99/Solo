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
  @State private var dragStartCamera: FounderEnvironmentCameraState?
  @State private var transitionID = UUID()
  @State private var computerRequest: FounderComputerWorkspaceRequest?
  @State private var selectionFeedback = 0
  @State private var hasUsedFreeLook = false
  @State private var showsSignalTVViewer = false
  @State private var selectedEnvironmentalAction: FounderEnvironmentalAction?
  @State private var deviceStates = Dictionary(
    uniqueKeysWithValues: FounderDeskDevice.allCases.map { ($0, FounderPhysicalDeviceState.idle) }
  )
  @State private var deviceActivationID = UUID()
  @AccessibilityFocusState private var focusedDevice: FounderDeskDevice?
  @AccessibilityFocusState private var deskIsFocused: Bool

  var body: some View {
    GeometryReader { geometry in
      let projection = environmentProjection
      let motion = FounderGarageMotionPresentation.derive(
        environment: projection,
        camera: navigation.camera,
        reduceMotion: reduceMotion,
        sceneActive: scenePhase == .active
      )

      ZStack {
        FounderEnvironmentRendererView(
          projection: projection,
          camera: navigation.camera,
          motion: motion,
          increasedContrast: contrast == .increased
        )
        .allowsHitTesting(false)
        .accessibilityHidden(navigation.selection != .overview)
        .brightness(navigation.selection == .overview ? 0 : -0.16)

        if navigation.selection == .overview {
          deskOverview(size: geometry.size, motion: motion)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        }

        persistentFocusedDevices(size: geometry.size)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
      .animation(reduceMotion ? .easeOut(duration: 0.14) : .smooth(duration: 0.38), value: navigation.selection)
      .animation(reduceMotion ? nil : .smooth(duration: 0.34), value: navigation.camera)
      .sensoryFeedback(.selection, trigger: selectionFeedback)
      .onChange(of: store.stats.trackRecord, initial: true) { _, value in
        progression.observe(trackRecord: value)
      }
      .accessibilityAction(named: Text("Look Left")) { moveCamera(horizontal: -1, vertical: 0) }
      .accessibilityAction(named: Text("Look Center")) { centerCamera() }
      .accessibilityAction(named: Text("Look Right")) { moveCamera(horizontal: 1, vertical: 0) }
      .accessibilityAction(named: Text("Look Up")) { moveCamera(horizontal: 0, vertical: 0.30) }
      .accessibilityAction(named: Text("Look Down")) { moveCamera(horizontal: 0, vertical: -0.30) }
      .accessibilityAction(named: Text("Return to Founder Computer")) { select(.computer) }
    }
    .sheet(isPresented: $showsSignalTVViewer) {
      SignalTVViewer(events: environmentProjection.signalTVEvents, coverage: store.stats.coverage)
    }
    .sheet(item: $selectedEnvironmentalAction) { action in
      FounderEnvironmentalActionCard(store: store, action: action) {
        selectedEnvironmentalAction = nil
      }
      .presentationDetents([.height(310)])
      .presentationDragIndicator(.visible)
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
  private func deskOverview(size: CGSize, motion: FounderGarageMotionPresentation) -> some View {
    if FounderDeskLayoutPolicy.layout(
      regularWidth: horizontalSizeClass == .regular,
      accessibilityText: dynamicTypeSize.isAccessibilitySize,
      height: size.height
    ) == .accessibleList {
      accessibleOverview(motion: motion)
    } else {
      spatialOverview(size: size, motion: motion)
    }
  }

  private func accessibleOverview(motion: FounderGarageMotionPresentation) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        overviewAccessibilityMarker
        deskHeading
        Button("Return to Founder Computer", systemImage: "desktopcomputer") { select(.computer) }
          .buttonStyle(.borderedProminent)
          .tint(SoloTheme.cyan)
        HStack {
          Button("Look Left", systemImage: "chevron.left") { moveCamera(horizontal: -1, vertical: 0) }
          Button("Center", systemImage: "viewfinder") { centerCamera() }
          Button("Look Right", systemImage: "chevron.right") { moveCamera(horizontal: 1, vertical: 0) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)
        deviceButton(.computer, style: .wide, visible: true, motion: motion)
        deviceButton(.phone, style: .wide, visible: true, motion: motion)
        deviceButton(.tablet, style: .wide, visible: true, motion: motion)
        deviceButton(.server, style: .wide, visible: true, motion: motion)
        Button("Open Signal TV", systemImage: "tv") { showsSignalTVViewer = true }
          .buttonStyle(.bordered)
        environmentalButton(.rest)
        environmentalButton(.train)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.black.opacity(0.32))
    .accessibilityFocused($deskIsFocused)
  }

  private func spatialOverview(size: CGSize, motion: FounderGarageMotionPresentation) -> some View {
    let equipment = FounderDeskEquipmentLayout(
      viewportSize: size,
      regularWidth: horizontalSizeClass == .regular
    )
    return ZStack {
      overviewAccessibilityMarker

      LinearGradient(
        colors: [.clear, .black.opacity(0.08), .black.opacity(0.52)],
        startPoint: .top,
        endPoint: .bottom
      )
      .allowsHitTesting(false)

      Color.clear
        .contentShape(.rect)
        .gesture(freeLookDragGesture(in: size))
        .accessibilityHidden(true)

      deskHeading
        .position(x: size.width / 2, y: max(54, size.height * 0.09))

      ForEach(FounderDeskDevice.allCases) { device in
        let visible = equipment.isVisible(device, camera: navigation.camera)
        let deviceSize = equipment.deviceSize(for: device)
        deviceButton(device, style: spatialStyle(for: device), visible: visible, motion: motion)
          .frame(width: deviceSize.width, height: deviceSize.height)
          .rotationEffect(rotation(for: device))
          .position(equipment.viewportPosition(for: device, camera: navigation.camera))
          .opacity(visible ? 1 : 0)
          .allowsHitTesting(visible && navigation.lookOutActive)
          .accessibilityHidden(!visible || !navigation.lookOutActive)
      }

      signalTVHotspot(size: size)

      environmentalHotspots(size: size)

      FounderEnvironmentControlLayer(
        mode: navigation.camera.mode,
        reduceMotion: reduceMotion,
        onLookAround: {},
        onFocusComputer: { select(.computer) },
        onLook: { horizontal, vertical in
          hasUsedFreeLook = true
          moveCamera(horizontal: horizontal, vertical: vertical)
        },
        onCenter: centerCamera
      )
      .frame(width: size.width, height: size.height)
      .accessibilityFocused($deskIsFocused)

      if FounderDeskCameraChromePolicy.showsInstruction(hasUsedFreeLook: hasUsedFreeLook) {
        Text("Drag to look · tap equipment to focus")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white.opacity(0.66))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(.black.opacity(0.42), in: .capsule)
          .position(x: size.width / 2, y: size.height - 72)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
          .transition(.opacity)
      }
    }
  }

  private func environmentalButton(_ action: FounderEnvironmentalAction) -> some View {
    Button(action.object.title, systemImage: action.object.symbol) {
      selectionFeedback += 1
      selectedEnvironmentalAction = action
    }
    .buttonStyle(.bordered)
    .accessibilityHint("Preview the cost, benefit, duration, and availability before confirming.")
    .accessibilityIdentifier("garage-\(action.object.rawValue)-hotspot")
  }

  private func environmentalHotspots(size: CGSize) -> some View {
    let layout = FounderEnvironmentLayout(viewportSize: size)
    return ForEach([FounderEnvironmentalAction.rest, .train]) { action in
      let anchor: FounderEnvironmentWorldAnchor = action == .rest ? .founderCouch : .workoutBench
      let point = layout.viewportPosition(for: anchor, camera: navigation.camera, layer: .middleGround)
      environmentalButton(action)
        .position(x: point.x, y: min(size.height - 98, point.y + 85))
        .opacity(layout.zoneIsVisible(anchor, camera: navigation.camera, margin: 80) ? 1 : 0)
        .allowsHitTesting(layout.zoneIsVisible(anchor, camera: navigation.camera, margin: 80))
        .accessibilityHidden(!layout.zoneIsVisible(anchor, camera: navigation.camera, margin: 80))
    }
  }

  private func signalTVHotspot(size: CGSize) -> some View {
    let hotspot = SignalTVHotspotLayout(viewportSize: size)
    let frame = hotspot.frame(camera: navigation.camera)
    let visible = hotspot.isSelectable(camera: navigation.camera)
    return Button {
      selectionFeedback += 1
      showsSignalTVViewer = true
    } label: {
      Color.clear
        .contentShape(.rect(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
          Label("Tune in", systemImage: "tv")
            .font(.caption2.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(.black.opacity(0.72), in: .capsule)
            .overlay { Capsule().stroke(.white.opacity(0.30), lineWidth: 1) }
            .offset(x: -6, y: -6)
        }
    }
    .buttonStyle(SignalTVHotspotButtonStyle(reduceMotion: reduceMotion))
    .frame(width: frame.width, height: frame.height)
    .position(x: frame.midX, y: frame.midY)
    .opacity(visible ? 1 : 0)
    .allowsHitTesting(visible && navigation.lookOutActive)
    .accessibilityHidden(!visible || !navigation.lookOutActive)
    .accessibilityLabel("Signal TV")
    .accessibilityValue(environmentProjection.signalTVEvents.first.map { "\($0.program.rawValue). \($0.headline)" } ?? "Market Pulse")
    .accessibilityHint("Opens the current broadcast, Market Pulse, Rival Watch, and recent public headlines.")
    .accessibilityIdentifier("signal-tv-hotspot")
  }

  private func spatialStyle(for device: FounderDeskDevice) -> DeskDeviceStyle {
    switch device {
    case .computer: .computer
    case .phone: .phone
    case .tablet: .tablet
    case .server: .server
    }
  }

  private func rotation(for device: FounderDeskDevice) -> Angle {
    switch device {
    case .computer, .server: .zero
    case .phone: .degrees(-7)
    case .tablet: .degrees(3)
    }
  }

  private var deskHeading: some View {
    VStack(spacing: 2) {
      Text("\(progression.currentFacility.name.uppercased()) · FOUNDER DESK")
        .font(.caption2.weight(.black))
        .tracking(1.5)
      Label("Day \(store.operatingCalendar.totalDays) · Sprint \(store.sprint), Day \(store.operatingCalendar.dayOfSprint) of 7 · \(store.operatingCalendar.period.title)", systemImage: store.operatingCalendar.period.symbol)
        .font(.caption2.weight(.semibold))
    }
      .foregroundStyle(.white.opacity(0.70))
      .padding(.horizontal, 11)
      .padding(.vertical, 5)
      .background(.black.opacity(0.38), in: .capsule)
      .accessibilityIdentifier("founder-desk-overview")
    .accessibilityElement(children: .combine)
  }

  private var overviewAccessibilityMarker: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .accessibilityElement()
      .accessibilityLabel("Founder Desk Overview")
      .accessibilityIdentifier("founder-desk-overview")
  }

  private func deviceButton(
    _ device: FounderDeskDevice,
    style: DeskDeviceStyle,
    visible: Bool,
    motion: FounderGarageMotionPresentation
  ) -> some View {
    let preview = FounderDeskPreviewPolicy.preview(for: device, input: previewInput)
    let physical = FounderDevicePresentation.derive(
      device: device,
      state: deviceStates[device] ?? .idle,
      safePending: preview.signal != nil,
      reduceMotion: reduceMotion,
      sceneActive: scenePhase == .active,
      visible: visible
    )
    return Button {
      select(device)
    } label: {
      FounderDeskDeviceObject(
        device: device,
        preview: preview,
        style: style,
        increasedContrast: contrast == .increased,
        presentation: physical,
        infrastructure: motion.infrastructure
      )
        .contentShape(.rect)
    }
    .buttonStyle(FounderEquipmentPressStyle(device: device, reduceMotion: reduceMotion))
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
      onClose: { close(device) },
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
    guard navigation.lookOutActive else { return }
    guard deviceStates[device] != .waking else { return }
    let activationID = UUID()
    deviceActivationID = activationID
    withAnimation(reduceMotion ? .easeOut(duration: 0.10) : .snappy(duration: 0.18)) {
      deviceStates[device] = .waking
    }
    selectionFeedback += 1
    Task { @MainActor in
      let delay = FounderDeviceTransitionPolicy.wakeDelayMilliseconds(for: device, reduceMotion: reduceMotion)
      if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) }
      guard deviceActivationID == activationID else { return }
      performSelection(device)
    }
  }

  private func performSelection(_ device: FounderDeskDevice) {
    var transition: FounderEnvironmentMode?
    withAnimation(workspaceAnimation) {
      transition = navigation.select(device)
      deviceStates[device] = .active
    }
    if let transition {
      beginTransition(completing: transition)
      return
    }
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(360)) }
      focusedDevice = device
    }
  }

  private func close(_ device: FounderDeskDevice) {
    deviceActivationID = UUID()
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
      deviceStates[device] = .settling
    }
    if device == .computer {
      var transition: FounderEnvironmentMode?
      withAnimation(workspaceAnimation) {
        transition = navigation.lookOut()
      }
      if let transition { beginTransition(completing: transition) }
      return
    }
    withAnimation(workspaceAnimation) {
      navigation.closeSecondaryDevice()
    }
    selectionFeedback += 1
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(260)) }
      withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
        deviceStates[device] = FounderDeviceTransitionPolicy.restingState(afterClosing: device)
      }
      deskIsFocused = true
    }
  }

  private var workspaceAnimation: Animation {
    navigation.transitionStyle(reduceMotion: reduceMotion) == .crossfade
      ? .easeOut(duration: 0.14)
      : .smooth(duration: 0.38)
  }

  private func freeLookDragGesture(in size: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        guard navigation.cameraControlsActive else { return }
        if dragStartCamera == nil { dragStartCamera = navigation.camera }
        guard let start = dragStartCamera else { return }
        let horizontal = start.horizontalLook + Double(value.translation.width / max(size.width * 0.42, 1))
        let vertical = start.verticalLook + Double(-value.translation.height / max(size.height * 0.72, 1))
        navigation.setLook(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
      }
      .onEnded { value in
        if abs(value.translation.width) > 8 || abs(value.translation.height) > 8 {
          hasUsedFreeLook = true
        }
        dragStartCamera = nil
      }
  }

  private func moveCamera(horizontal: Double, vertical: Double) {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) {
      navigation.look(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
    }
  }

  private func centerCamera() {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) {
      navigation.centerCamera()
    }
  }

  private func beginTransition(completing destination: FounderEnvironmentMode) {
    let id = UUID()
    transitionID = id
    dragStartCamera = nil
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(520)) }
      guard transitionID == id else { return }
      withAnimation(workspaceAnimation) {
        navigation.completeCameraTransition(to: destination)
      }
      switch destination {
      case .computerFocused:
        focusedDevice = .computer
      case .freeLook:
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) {
          deviceStates[.computer] = FounderDeviceTransitionPolicy.restingState(afterClosing: .computer)
        }
        deskIsFocused = true
      case .transitioningToComputerFocus, .transitioningToFreeLook:
        break
      }
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
  var presentation: FounderDevicePresentation
  var infrastructure: FounderInfrastructureReactionPresentation

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @ViewBuilder
  var body: some View {
    switch style {
    case .computer:
      FounderMonitorHardware(
        preview: preview,
        increasedContrast: increasedContrast,
        reduceMotion: reduceMotion,
        presentation: presentation
      )
    case .phone:
      FounderPhoneHardware(
        preview: preview,
        increasedContrast: increasedContrast,
        reduceMotion: reduceMotion,
        presentation: presentation
      )
    case .tablet:
      FounderTabletHardware(
        preview: preview,
        increasedContrast: increasedContrast,
        reduceMotion: reduceMotion,
        presentation: presentation
      )
    case .server:
      FounderServerHardware(
        preview: preview,
        increasedContrast: increasedContrast,
        reduceMotion: reduceMotion,
        presentation: presentation,
        infrastructure: infrastructure
      )
    case .compact, .wide:
      accessibleCard
    }
  }

  private var accessibleCard: some View {
    HStack(spacing: 12) {
      Image(systemName: device.symbol)
        .font(.title2.weight(.semibold))
        .foregroundStyle(deviceTone)
        .frame(width: 44, height: 44)
        .background(deviceTone.opacity(0.10), in: .rect(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 4) {
        Text(preview.title).font(.headline.weight(.bold))
        Text(preview.primary).font(.subheadline.weight(.semibold)).lineLimit(2)
        Text(preview.secondary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: style == .compact ? 92 : 104, alignment: .leading)
    .background(FounderDeskHardwareMaterial.chassis, in: .rect(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(increasedContrast ? .white : .white.opacity(0.16), lineWidth: increasedContrast ? 2 : 1)
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
}

private struct FounderMonitorHardware: View {
  var preview: FounderDeskPreview
  var increasedContrast: Bool
  var reduceMotion: Bool
  var presentation: FounderDevicePresentation

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(.black.opacity(0.80))
          .offset(x: 5, y: 5)
        RoundedRectangle(cornerRadius: 10)
          .fill(FounderDeskHardwareMaterial.chassis)
          .overlay {
            RoundedRectangle(cornerRadius: 10)
              .stroke(increasedContrast ? .white : .white.opacity(0.20), lineWidth: increasedContrast ? 2 : 1)
          }
        FounderGarageSurfaceTexture(kind: .powderCoat, strength: 0.70)
          .clipShape(.rect(cornerRadius: 10))
        FounderHardwareScreen(
          tone: SoloTheme.cyan,
          preview: preview,
          layout: .monitor,
          presentation: presentation,
          reduceMotion: reduceMotion
        )
          .phaseAnimator(reduceMotion ? [1.0] : [0.97, 1.0, 0.985]) { content, luminance in
            content.brightness((luminance - 1) * 0.42)
          } animation: { _ in
            .easeInOut(duration: FounderGarageAmbientRhythm.profile(for: .founderDisplay).duration)
          }
          .brightness((presentation.screenLuminance - 1) * 0.30)
          .padding(7)
        FounderDeskGlassReflection(
          cornerRadius: 6,
          reflectionOffset: presentation.reflectionOffset,
          reduceMotion: reduceMotion
        )
          .padding(7)
      }
      .shadow(color: SoloTheme.cyan.opacity(preview.signal == nil ? 0.10 : 0.20), radius: 9, y: 4)
      Rectangle()
        .fill(FounderDeskHardwareMaterial.metalEdge)
        .frame(width: 22, height: 17)
      ZStack {
        Capsule().fill(.black.opacity(0.48)).frame(width: 92, height: 9).offset(y: 4)
        Capsule().fill(FounderDeskHardwareMaterial.metalEdge).frame(width: 78, height: 7)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      Circle()
        .fill(presentation.safePendingIndicatorVisible ? SoloTheme.amber : .green)
        .opacity(presentation.powerIndicatorIntensity)
        .frame(width: 5, height: 5)
        .padding(.trailing, 11)
        .padding(.bottom, 18)
    }
    .overlay(alignment: .bottom) {
      FounderKeyboardPeripheral(
        intensity: presentation.peripheralBacklightIntensity,
        reviewPending: presentation.safePendingIndicatorVisible
      )
      .offset(y: 8)
    }
    .background {
      RadialGradient(
        colors: [SoloTheme.cyan.opacity(presentation.localGlowIntensity * 0.12), .clear],
        center: .bottom,
        startRadius: 2,
        endRadius: 92
      )
      .scaleEffect(1.15)
    }
    .scaleEffect(presentation.physicalResponseEnabled ? 1.012 : 1)
    .accessibilityHidden(true)
  }
}

private struct FounderPhoneHardware: View {
  var preview: FounderDeskPreview
  var increasedContrast: Bool
  var reduceMotion: Bool
  var presentation: FounderDevicePresentation

  var body: some View {
    ZStack {
      Ellipse().fill(.black.opacity(0.48)).frame(width: 64, height: 14).offset(y: 47)
      RoundedRectangle(cornerRadius: 18)
        .fill(.black.opacity(0.72))
        .offset(x: 4, y: 5)
      RoundedRectangle(cornerRadius: 18)
        .fill(FounderDeskHardwareMaterial.chassis)
        .overlay {
          RoundedRectangle(cornerRadius: 18)
            .stroke(increasedContrast ? .white : FounderDeskHardwareMaterial.metalHighlight, lineWidth: increasedContrast ? 2 : 1)
        }
      LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        .clipShape(.rect(cornerRadius: 18))
      FounderHardwareScreen(
        tone: .white,
        preview: preview,
        layout: .phone,
        presentation: presentation,
        reduceMotion: reduceMotion
      )
        .phaseAnimator(reduceMotion ? [1.0] : [0.985, 1.0, 0.99]) { content, luminance in
          content.brightness((luminance - 1) * 0.34)
        } animation: { _ in .easeInOut(duration: 7.7) }
        .brightness((presentation.screenLuminance - 1) * 0.44)
        .clipShape(.rect(cornerRadius: 14))
        .padding(5)
      FounderDeskGlassReflection(
        cornerRadius: 14,
        reflectionOffset: presentation.reflectionOffset,
        reduceMotion: reduceMotion
      )
        .padding(5)
      Capsule().fill(.black.opacity(0.92)).frame(width: 24, height: 6).offset(y: -43)
      Circle()
        .fill(presentation.safePendingIndicatorVisible ? SoloTheme.amber : .green)
        .opacity(presentation.powerIndicatorIntensity)
        .frame(width: 4, height: 4)
        .offset(x: 23, y: 40)
    }
    .overlay(alignment: .trailing) {
      Capsule().fill(.white.opacity(0.28)).frame(width: 2, height: 18).offset(x: 2, y: -13)
    }
    .shadow(color: .white.opacity(preview.signal == nil ? 0.04 : 0.12), radius: 7, y: 4)
    .background {
      Ellipse()
        .fill(.white.opacity(presentation.localGlowIntensity * 0.08))
        .frame(width: 78, height: 31)
        .offset(y: 39)
    }
    .scaleEffect(presentation.physicalResponseEnabled ? 0.975 : 1)
    .rotationEffect(.degrees(presentation.state == .settling && !reduceMotion ? 0.8 : 0))
    .accessibilityHidden(true)
  }
}

private struct FounderTabletHardware: View {
  var preview: FounderDeskPreview
  var increasedContrast: Bool
  var reduceMotion: Bool
  var presentation: FounderDevicePresentation

  var body: some View {
    ZStack(alignment: .bottom) {
      Ellipse().fill(.black.opacity(0.50)).frame(width: 104, height: 15).offset(y: 8)
      VStack(spacing: -1) {
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(.black.opacity(0.78))
            .offset(x: 5, y: 5)
          RoundedRectangle(cornerRadius: 10)
            .fill(FounderDeskHardwareMaterial.chassis)
            .overlay {
              RoundedRectangle(cornerRadius: 10)
                .stroke(increasedContrast ? .white : FounderDeskHardwareMaterial.metalHighlight, lineWidth: increasedContrast ? 2 : 1)
            }
          FounderGarageSurfaceTexture(kind: .powderCoat, strength: 0.45)
            .clipShape(.rect(cornerRadius: 10))
          FounderHardwareScreen(
            tone: SoloTheme.amber,
            preview: preview,
            layout: .tablet,
            presentation: presentation,
            reduceMotion: reduceMotion
          )
            .phaseAnimator(reduceMotion ? [1.0] : [0.98, 1.0, 0.988]) { content, luminance in
              content.brightness((luminance - 1) * 0.36)
            } animation: { _ in .easeInOut(duration: 8.9) }
            .brightness((presentation.screenLuminance - 1) * 0.40)
            .clipShape(.rect(cornerRadius: 7))
            .padding(5)
          FounderDeskGlassReflection(
            cornerRadius: 7,
            reflectionOffset: presentation.reflectionOffset,
            reduceMotion: reduceMotion
          )
            .padding(5)
          Circle()
            .fill(.green.opacity(presentation.powerIndicatorIntensity))
            .frame(width: 4, height: 4)
            .offset(x: 45)
        }
        ZStack {
          Path { path in
            path.move(to: CGPoint(x: 13, y: 0))
            path.addLine(to: CGPoint(x: 29, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 12))
            path.closeSubpath()
          }
          .fill(FounderDeskHardwareMaterial.metalEdge)
          Capsule().fill(.black.opacity(0.75)).frame(width: 44, height: 5).offset(y: 10)
        }
        .frame(width: 30, height: 12)
      }
    }
    .shadow(color: SoloTheme.amber.opacity(preview.signal == nil ? 0.07 : 0.15), radius: 7, y: 4)
    .background {
      Ellipse()
        .fill(SoloTheme.amber.opacity(presentation.localGlowIntensity * 0.10))
        .frame(width: 130, height: 32)
        .offset(y: 26)
    }
    .scaleEffect(presentation.physicalResponseEnabled ? 0.988 : 1)
    .rotationEffect(.degrees(presentation.state == .settling && !reduceMotion ? -0.45 : 0))
    .accessibilityHidden(true)
  }
}

private struct FounderServerHardware: View {
  var preview: FounderDeskPreview
  var increasedContrast: Bool
  var reduceMotion: Bool
  var presentation: FounderDevicePresentation
  var infrastructure: FounderInfrastructureReactionPresentation

  var body: some View {
    ZStack(alignment: .bottom) {
      Ellipse().fill(.black.opacity(0.62)).frame(width: 78, height: 17).offset(y: 8)
      RoundedRectangle(cornerRadius: 7)
        .fill(.black.opacity(0.72))
        .offset(x: 7, y: 5)
      RoundedRectangle(cornerRadius: 7)
        .fill(FounderDeskHardwareMaterial.serverChassis)
        .overlay {
          RoundedRectangle(cornerRadius: 7)
            .stroke(increasedContrast ? .white : .white.opacity(0.18), lineWidth: increasedContrast ? 2 : 1)
        }
      FounderGarageSurfaceTexture(kind: .powderCoat, strength: 1.30)
        .clipShape(.rect(cornerRadius: 7))
      VStack(spacing: 6) {
        HStack(spacing: 5) {
          Circle().fill(SoloTheme.mint.opacity(0.82)).frame(width: 6, height: 6)
          FounderHardwareScreen(
            tone: SoloTheme.mint,
            preview: preview,
            layout: .server,
            presentation: presentation,
            reduceMotion: reduceMotion
          )
            .phaseAnimator(reduceMotion ? [1.0] : [0.96, 1.0, 0.98]) { content, luminance in
              content.brightness((luminance - 1) * 0.42)
            } animation: { _ in .easeInOut(duration: 6.3) }
            .brightness((presentation.screenLuminance - 1) * 0.36)
            .frame(height: 25)
        }
        .padding(.horizontal, 6)
        VStack(spacing: 5) {
          ForEach(0..<5, id: \.self) { index in
            HStack(spacing: 5) {
              Circle()
                .fill(serverLight(index: index))
                .frame(width: 4, height: 4)
                .phaseAnimator(
                  serverLightPhases(index: index)
                ) { content, phase in
                  content.opacity(phase)
                } animation: { _ in
                  .easeInOut(duration: serverLightDuration(index: index))
                }
              RoundedRectangle(cornerRadius: 2)
                .fill(.black.opacity(0.72))
                .overlay(alignment: .trailing) {
                  HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                      Capsule().fill(.white.opacity(0.14)).frame(width: 7, height: 2)
                    }
                  }
                  .padding(.trailing, 5)
                }
                .frame(height: 14)
            }
          }
        }
        .padding(.horizontal, 7)
        HStack(spacing: 3) {
          ForEach(0..<5, id: \.self) { _ in
            Capsule().fill(.white.opacity(0.12)).frame(width: 3, height: 12)
          }
          ZStack {
            Circle().fill(.black.opacity(0.72)).frame(width: 25, height: 25)
            Image(systemName: "fanblades.fill")
              .font(.system(size: 17))
              .foregroundStyle(.white.opacity(preview.signal == nil ? 0.34 : 0.52))
              .phaseAnimator(infrastructure.continuousMotionEnabled ? [0.0, 360.0] : [22.0]) { content, angle in
                content.rotationEffect(.degrees(angle))
              } animation: { _ in
                .linear(duration: infrastructure.serverFanRotationDuration)
              }
            Circle().stroke(.white.opacity(0.22), lineWidth: 1).frame(width: 25, height: 25)
            Capsule().fill(.white.opacity(0.13)).frame(width: 25, height: 1)
            Capsule().fill(.white.opacity(0.13)).frame(width: 25, height: 1).rotationEffect(.degrees(90))
          }
        }
      }
      .padding(.vertical, 8)
    }
    .overlay(alignment: .bottomLeading) {
      Path { path in
        path.move(to: CGPoint(x: 8, y: 0))
        path.addCurve(
          to: CGPoint(x: -17, y: 17),
          control1: CGPoint(x: -2, y: 2),
          control2: CGPoint(x: -7, y: 13)
        )
      }
      .stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
    .shadow(color: SoloTheme.mint.opacity(preview.signal == nil ? 0.05 : 0.14), radius: 8, y: 5)
    .background {
      RadialGradient(
        colors: [SoloTheme.mint.opacity(presentation.localGlowIntensity * 0.09), .clear],
        center: .center,
        startRadius: 2,
        endRadius: 74
      )
    }
    .accessibilityHidden(true)
  }

  private func serverLight(index: Int) -> Color {
    if index == 0 { return SoloTheme.mint.opacity(0.82) }
    if index == 2 && preview.signal != nil { return SoloTheme.amber.opacity(reduceMotion ? 0.62 : 0.90) }
    if index == 1 { return .cyan.opacity(0.62) }
    if index == 3 { return SoloTheme.mint.opacity(0.54) }
    return .white.opacity(0.20)
  }

  private func serverLightPhases(index: Int) -> [Double] {
    guard !reduceMotion else { return [1.0] }
    if index == 1 { return [0.30, 0.46 + infrastructure.networkActivity * 0.54, 0.42] }
    if index == 3 { return [0.44, 0.34, 0.46 + infrastructure.storageActivity * 0.48] }
    if index == 2 && preview.signal != nil { return [0.52, 1.0, 0.70] }
    return [1.0]
  }

  private func serverLightDuration(index: Int) -> Double {
    if index == 1 { return FounderGarageAmbientRhythm.profile(for: .serverNetwork).duration }
    if index == 3 { return FounderGarageAmbientRhythm.profile(for: .serverNetwork).duration + 0.73 }
    return 0.65
  }
}

private enum FounderHardwareScreenLayout {
  case monitor
  case phone
  case tablet
  case server
}

private struct FounderHardwareScreen: View {
  var tone: Color
  var preview: FounderDeskPreview
  var layout: FounderHardwareScreenLayout
  var presentation: FounderDevicePresentation
  var reduceMotion: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: screenSpacing) {
      if layout != .server {
        HStack(spacing: 4) {
          Circle().fill(tone.opacity(preview.signal == nil ? 0.50 : 0.90)).frame(width: 4, height: 4)
          Text(screenTitle)
            .font(.system(size: titleSize, weight: .black, design: .rounded))
            .tracking(0.5)
            .lineLimit(1)
        }
        .foregroundStyle(tone.opacity(0.92))
      }
      Text(preview.primary)
        .font(.system(size: primarySize, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(layout == .phone ? 2 : 1)
        .minimumScaleFactor(0.60)
      if layout != .server {
        Text(preview.secondary)
          .font(.system(size: secondarySize, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.50))
          .lineLimit(layout == .monitor ? 1 : 2)
          .minimumScaleFactor(0.60)
      }
    }
    .padding(screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      LinearGradient(
        colors: [tone.opacity(0.11), Color(red: 0.015, green: 0.025, blue: 0.035), .black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(alignment: .bottom) {
      LinearGradient(colors: [.clear, tone.opacity(0.07)], startPoint: .top, endPoint: .bottom)
        .frame(height: 12)
    }
    .overlay {
      if layout == .tablet {
        FounderNeutralTrace(
          tone: tone,
          active: presentation.screenLifeEnabled,
          reduceMotion: reduceMotion
        )
        .padding(5)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      if layout == .server {
        HStack(alignment: .bottom, spacing: 1) {
          ForEach(0..<4, id: \.self) { index in
            Capsule()
              .fill(tone.opacity(0.28 + Double(index) * 0.08))
              .frame(width: 2, height: CGFloat(3 + index * 2))
          }
        }
        .padding(3)
        .phaseAnimator(presentation.screenLifeEnabled ? [0.62, 1.0, 0.76] : [0.72]) { content, opacity in
          content.opacity(opacity)
        } animation: { _ in .easeInOut(duration: 4.7) }
      }
    }
  }

  private var screenTitle: String {
    switch layout {
    case .monitor: "COMMAND"
    case .phone: "TECH.COM"
    case .tablet: "VENTURE"
    case .server: "SYS"
    }
  }

  private var titleSize: CGFloat { layout == .monitor ? 8 : 6 }
  private var primarySize: CGFloat {
    switch layout {
    case .monitor: 11
    case .phone: 8
    case .tablet: 8
    case .server: 5
    }
  }
  private var secondarySize: CGFloat { layout == .monitor ? 7 : 6 }
  private var screenSpacing: CGFloat { layout == .monitor ? 4 : 2 }
  private var screenPadding: CGFloat { layout == .monitor ? 9 : layout == .server ? 3 : 5 }
}

private struct FounderDeskGlassReflection: View {
  var cornerRadius: CGFloat
  var reflectionOffset: Double
  var reduceMotion: Bool

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(
        LinearGradient(
          colors: [.white.opacity(0.14), .clear, .white.opacity(0.025)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .mask {
        LinearGradient(colors: [.white, .clear, .white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      .offset(x: reduceMotion ? 0 : reflectionOffset, y: reduceMotion ? 0 : -reflectionOffset * 0.35)
      .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: reflectionOffset)
      .allowsHitTesting(false)
  }
}

private struct FounderNeutralTrace: View {
  var tone: Color
  var active: Bool
  var reduceMotion: Bool

  var body: some View {
    GeometryReader { proxy in
      Path { path in
        path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.72))
        path.addCurve(
          to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.48),
          control1: CGPoint(x: proxy.size.width * 0.26, y: proxy.size.height * 0.58),
          control2: CGPoint(x: proxy.size.width * 0.66, y: proxy.size.height * 0.80)
        )
      }
      .trim(from: 0, to: active ? 1 : 0.78)
      .stroke(tone.opacity(0.28), style: StrokeStyle(lineWidth: 1, lineCap: .round))
      .phaseAnimator(active && !reduceMotion ? [0.72, 1.0, 0.84] : [0.82]) { content, opacity in
        content.opacity(opacity)
      } animation: { _ in
        .easeInOut(duration: 8.6)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct FounderKeyboardPeripheral: View {
  var intensity: Double
  var reviewPending: Bool

  var body: some View {
    HStack(spacing: 2) {
      ForEach(0..<9, id: \.self) { index in
        RoundedRectangle(cornerRadius: 0.8)
          .fill((reviewPending && index == 8 ? SoloTheme.amber : SoloTheme.cyan).opacity(0.16 + intensity * 0.42))
          .frame(width: 5, height: 2)
      }
    }
    .padding(.horizontal, 6)
    .frame(height: 9)
    .background(.black.opacity(0.82), in: .rect(cornerRadius: 2))
    .shadow(color: SoloTheme.cyan.opacity(intensity * 0.18), radius: 3)
    .accessibilityHidden(true)
  }
}

private enum FounderDeskHardwareMaterial {
  static var chassis: LinearGradient {
    LinearGradient(
      colors: [Color(red: 0.20, green: 0.21, blue: 0.23), Color(red: 0.055, green: 0.06, blue: 0.07), .black],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static var serverChassis: LinearGradient {
    LinearGradient(
      colors: [Color(red: 0.13, green: 0.15, blue: 0.16), Color(red: 0.035, green: 0.04, blue: 0.045), .black],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static var metalEdge: LinearGradient {
    LinearGradient(colors: [.white.opacity(0.30), Color(red: 0.10, green: 0.11, blue: 0.12), .black], startPoint: .leading, endPoint: .trailing)
  }

  static var metalHighlight: Color { .white.opacity(0.24) }
}

private struct FounderEquipmentPressStyle: ButtonStyle {
  var device: FounderDeskDevice
  var reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
      .brightness(configuration.isPressed ? 0.10 : 0)
      .shadow(color: .white.opacity(configuration.isPressed ? 0.08 : 0), radius: 5)
      .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
  }

  private var pressedScale: CGFloat {
    switch device {
    case .computer: 0.982
    case .phone: 0.948
    case .tablet: 0.976
    case .server: 0.986
    }
  }
}

private struct SignalTVHotspotButtonStyle: ButtonStyle {
  var reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.cyan.opacity(configuration.isPressed ? 0.92 : 0), lineWidth: 2)
      }
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
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
        if device == .computer {
          Button { onClose() } label: {
            Label("LOOK OUT", systemImage: "binoculars.fill")
              .font(.caption2.weight(.black))
              .frame(minWidth: 112, minHeight: 60)
              .background(.white.opacity(0.09), in: .capsule)
              .contentShape(.capsule)
          }
            .buttonStyle(.plain)
            .accessibilityIdentifier("founder-computer-look-out")
            .accessibilityHidden(!isFocused)
            .accessibilityHint("Pulls away from the Founder Computer into the physical Founder environment")
        } else {
          Button { onClose() } label: {
            Image(systemName: "xmark")
              .frame(width: 60, height: 60)
              .background(.white.opacity(0.09), in: .circle)
              .contentShape(.circle)
          }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to Founder Desk")
            .accessibilityIdentifier("return-to-founder-desk-\(device.rawValue)")
            .accessibilityHidden(!isFocused)
            .accessibilityHint("Returns to Look Out at the previous camera orientation")
        }
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
      .frame(height: 64)
      .background(.black.opacity(0.94))
      .accessibilityHidden(!isFocused)
      .zIndex(2)

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
