import RealityKit
import SwiftUI

@MainActor
struct FounderGarageRealityView: View {
  var presentation: FounderWorldPresentationModel
  var isActive: Bool = true
  var onOpenFounderComputer: () -> Void
  var onOpenFounderPhone: () -> Void = {}
  var onOpenFounderTablet: () -> Void = {}
  var onOpenFounderServer: () -> Void = {}
  var onOpenFundingBoard: () -> Void = {}
  var onCameraIntent: (FounderGarageCameraState) -> Void = { _ in }
  var onExitToAtlantis: (FounderAtlantisTraversalHandoff) -> Void = { _ in }
  var atlantisSignals: AtlantisWorldSignalSnapshot? = nil
  var atlantisInteractionReturnID = UUID()
  var onAtlantisInteraction: (AtlantisInteractionIntent) -> Void = { _ in }

  // This reference owns one RealityKit world for this active Garage view session.
  // SwiftUI body updates and Computer focus round trips retain the same instance.
  @State private var world = FounderGarageRealityWorld()
  @State private var displayedCamera: FounderGarageCameraState = .founderPOV
  @State private var cameraOpacity: Double = 1
  @State private var cameraRequest = 0
  @State private var lookOrientation = FounderLookOrientation.neutral
  @State private var dragStartLook: FounderLookOrientation?
  @State private var walkingEnabled = false
  @State private var garageLoadAttemptComplete = false
  @State private var atlantisWorld = try? AtlantisRealityWorld(manifest: .load())
  @State private var atlantisReady = false
  @State private var isTraversingAtlantis = false
  @State private var atlantisSupportTask: Task<Void, Never>?
  @State private var viewportWidth: CGFloat = 390
  @State private var computerActivationStartedAt: TimeInterval?
  @State private var computerActivationGeneration = 0
  @State private var computerActivationResetTask: Task<Void, Never>?
  @State private var chairActivationStartedAt: TimeInterval?
  @State private var chairActivationGeneration = 0
  @State private var chairActivationResetTask: Task<Void, Never>?
  @State private var whiteboardActivationStartedAt: TimeInterval?
  @State private var whiteboardActivationGeneration = 0
  @State private var whiteboardActivationResetTask: Task<Void, Never>?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      environmentBackground

      RealityView { content in
        world.attachRoot { content.add($0) }
        world.subscribeToCameraUpdates { handler in content.subscribe(to: SceneEvents.Update.self, on: nil, handler) }
        if let atlantisWorld {
          configureAtlantisComposition(atlantisWorld)
          content.add(atlantisWorld.root)
          atlantisWorld.subscribe { handler in
            content.subscribe(to: SceneEvents.Update.self, on: nil, handler)
          }
        }
        world.apply(
          displayedPresentation,
          interactionFeedback: founderComputerFeedbackState,
          chairInteractionFeedback: chairFeedbackState,
          whiteboardInteractionFeedback: whiteboardFeedbackState,
          reduceMotion: reduceMotion
        )
        world.replaceAccessibilityActivationSubscription(
          content.subscribe(to: AccessibilityEvents.Activate.self, componentType: nil) { event in
            activate(world.interaction(for: event.entity))
          }
        )
      } update: { _ in
        world.apply(
          displayedPresentation,
          interactionFeedback: founderComputerFeedbackState,
          chairInteractionFeedback: chairFeedbackState,
          whiteboardInteractionFeedback: whiteboardFeedbackState,
          reduceMotion: reduceMotion
        )
      }
      .opacity(cameraOpacity)
      .allowsHitTesting(cameraOpacity == 1 && displayedCamera == presentation.cameraState)
      .gesture(
        TapGesture()
          .targetedToAnyEntity()
          .onEnded { value in
            guard !isTraversingAtlantis else { return }
            activate(world.interaction(for: value.entity))
          }
      )
      .simultaneousGesture(freeLookDragGesture)
      .accessibilityHidden(true)

      Group {
        if isTraversingAtlantis, let atlantisWorld {
          atlantisHUD(atlantisWorld)
        } else {
          prototypeHUD
        }
      }
        // Own foreground touch routing explicitly. RealityKit's targeted tap can
        // otherwise win the same event when the monitor sits behind a HUD control.
        .contentShape(.rect)
        .background(.black.opacity(0.001))
        .simultaneousGesture(freeLookDragGesture)
    }
    .task {
      garageLoadAttemptComplete = false
      world.configureAtlantisTraversal { handoff in enterAtlantis(handoff) }
      _ = try? world.requestProductionFounder()
      let source = FounderGarageArchitectureSource.bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName)
      let garageLoad = world.requestGarageArchitecture(
        source,
        descriptor: .facilityTier0V8
      )
      async let exteriorReady = prepareAtlantisExterior()
      await garageLoad?.value
      guard !Task.isCancelled else { return }
      garageLoadAttemptComplete = true
      if ProcessInfo.processInfo.arguments.contains("--garage-chair-feedback-review"),
         !walkingEnabled {
        toggleWalking()
      }
      if ProcessInfo.processInfo.arguments.contains("--garage-whiteboard-feedback-review") {
        if !walkingEnabled { toggleWalking() }
        if let target = world.spatialSpecification.facilityTier0InteractionSpace?
          .founderInteractionTarget(for: .whiteboard) {
          _ = world.cameraController.beginInteractionStanding(
            at: target.approach,
            reduceMotion: true
          )
        }
      }
      atlantisReady = await exteriorReady
      if atlantisReady, let atlantisWorld {
        atlantisSupportTask = Task { await atlantisWorld.prepareTraversalSupport() }
      }
    }
    .onChange(of: presentation.cameraState) { _, target in selectCamera(target) }
    .onChange(of: world.interactionCoordinator.phase) { _, phase in
      if phase == .seated { walkingEnabled = false }
      if phase == .idle {
        walkingEnabled = world.cameraController.playerSpatialState.navigationMode == .walking
      }
    }
    .onChange(of: isActive) { _, active in
      if active && presentation.cameraState == .founderPOV { recenterFounderView() }
    }
    .onChange(of: reduceMotion) { _, reduced in
      if reduced { selectCamera(presentation.cameraState) }
    }
    .onChange(of: atlantisSignals) { _, signals in
      if let signals { atlantisWorld?.livingDirector.receive(signals) }
    }
    .onChange(of: atlantisInteractionReturnID) { _, _ in
      _ = atlantisWorld?.returnFromInteraction()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { atlantisWorld?.setMovementIntent(forward: 0, turn: 0) }
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      viewportWidth = max(width, 1)
    }
    .onDisappear {
      cameraRequest += 1
      world.stopCameraUpdates()
      atlantisSupportTask?.cancel()
      computerActivationResetTask?.cancel()
      chairActivationResetTask?.cancel()
      whiteboardActivationResetTask?.cancel()
      atlantisWorld?.stop()
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("founder-garage-realitykit")
    .accessibilityValue(garageAccessibilityValue)
  }

  private var garageAccessibilityValue: String {
    switch world.architectureLoadState {
    case .ready(.bundledProductionAsset): presentation.cameraState.title
    case .failed: "\(presentation.cameraState.title). Simplified Garage"
    default: "Loading Garage"
    }
  }

  private var displayedPresentation: FounderWorldPresentationModel {
    var model = presentation
    model.cameraState = displayedCamera
    return model
  }

  private var environmentBackground: LinearGradient {
    let preset = FounderEnvironmentLightingConfiguration.preset(for: world.environmentTimeState)
    return LinearGradient(
      colors: [color(preset.backgroundTop), color(preset.backgroundBottom)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private func color(_ components: SIMD3<Float>) -> Color {
    Color(
      red: Double(components.x),
      green: Double(components.y),
      blue: Double(components.z)
    )
  }

  private func configureAtlantisComposition(_ atlantis: AtlantisRealityWorld) {
    atlantis.root.position = [
      -AtlantisSpatialContract.founderGarage.x,
      -AtlantisSpatialContract.founderGarageFloorY,
      -AtlantisSpatialContract.founderGarage.z
    ]
    atlantis.camera.isEnabled = false
  }

  private func prepareAtlantisExterior() async -> Bool {
    guard let atlantisWorld else { return false }
    if let atlantisSignals { atlantisWorld.livingDirector.receive(atlantisSignals) }
    return await atlantisWorld.prepareFounderGarageExterior()
  }

  private func enterAtlantis(_ handoff: FounderAtlantisTraversalHandoff) {
    guard atlantisReady, let atlantisWorld else { return }
    world.cameraController.setMovementIntent(.idle)
    atlantisWorld.enterFromFounderGarage(handoff)
    world.transferFounderPresentation(to: atlantisWorld, reduceMotion: reduceMotion)
    world.entities.camera.isEnabled = false
    atlantisWorld.camera.isEnabled = true
    walkingEnabled = false
    isTraversingAtlantis = true
    onExitToAtlantis(handoff)
  }

  private func returnFromAtlantis() {
    atlantisWorld?.setMovementIntent(forward: 0, turn: 0)
    _ = atlantisWorld?.returnFromInteraction()
    atlantisWorld?.camera.isEnabled = false
    if let atlantisWorld {
      world.restoreFounderPresentation(from: atlantisWorld)
    } else {
      world.restoreFromAtlantis()
    }
    world.entities.camera.isEnabled = true
    walkingEnabled = true
    isTraversingAtlantis = false
  }

  @ViewBuilder
  private func atlantisHUD(_ atlantis: AtlantisRealityWorld) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("ATLANTIS")
            .font(.caption.bold())
          Text(atlantis.streaming.current.title)
            .font(.headline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.68), in: .rect(cornerRadius: 12))
        Spacer()
      }

      Spacer()

      HStack(alignment: .bottom) {
        AtlantisMovementPad { lateral, forward in
          atlantis.setMovementIntent(forward: forward, turn: -lateral)
        }

        Spacer()

        Button {
          guard let intent = atlantis.beginInteraction() else { return }
          switch intent {
          case .enterFounderGarage:
            returnFromAtlantis()
          case .talkNamedNPC:
            break
          default:
            onAtlantisInteraction(intent)
          }
        } label: {
          Label(atlantis.interactionPrompt, systemImage: "hand.tap.fill")
            .font(.caption.bold())
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(.black.opacity(0.72), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(atlantis.activeInteractionID == nil)
        .opacity(atlantis.activeInteractionID == nil ? 0.45 : 1)
        .accessibilityIdentifier("atlantis.traversal.interact")
      }
    }
    .foregroundStyle(.white)
    .padding(18)
    .overlay {
      Color.clear
        .frame(width: 1, height: 1)
        .accessibilityElement()
        .accessibilityLabel("Atlantis traversal")
        .accessibilityIdentifier("atlantis.traversal.root")
    }
  }

  // Separated viewpoints have no safe straight-line path through the furniture.
  // Fade the render surface, install one exact world-up pose, then reveal it.
  // Animation completion tokens ensure rapid retargets cannot reveal an older pose.
  private func selectCamera(_ target: FounderGarageCameraState) {
    cameraRequest += 1
    let request = cameraRequest
    dragStartLook = nil
    lookOrientation = .neutral
    if walkingEnabled { world.cameraController.endWalking(reduceMotion: true); walkingEnabled = false }
    if reduceMotion {
      withAnimation(nil) { displayedCamera = target; cameraOpacity = 1 }
      return
    }
    let kind = FounderGarageCameraConfiguration(spatial: world.spatialSpecification).transitionClass(from: displayedCamera, to: target)
    if kind != .largeFade { displayedCamera = target; cameraOpacity = 1; return }
    withAnimation(.easeInOut(duration: FounderGarageCameraConfiguration.transitionDuration / 2), completionCriteria: .removed) {
      cameraOpacity = 0
    } completion: {
      guard request == cameraRequest else { return }
      displayedCamera = target
      withAnimation(.easeInOut(duration: FounderGarageCameraConfiguration.transitionDuration / 2)) {
        cameraOpacity = 1
      }
    }
  }

  private func openFounderComputer() {
    guard presentation.founderComputerAvailable,
          !walkingEnabled,
          world.cameraController.state.allowsComputer,
          world.cameraController.playerSpatialState.navigationMode == .seated
    else { return }
    presentComputerActivationConfirmation()
    onOpenFounderComputer()
  }

  private func activate(_ interaction: FounderWorldInteraction?) {
    switch interaction {
    case .openFounderComputer:
      deferSpatialComputerActivation()
    case .openFounderPhone:
      onOpenFounderPhone()
    case .openFounderTablet:
      onOpenFounderTablet()
    case nil:
      break
    }
  }

  private var founderComputerFeedbackConfiguration: GarageInteractionFeedbackConfiguration? {
    world.spatialSpecification.facilityTier0InteractionSpace?
      .zone(for: .founderComputer)
      .map { .founderComputer(targetID: $0.id) }
  }

  private var founderComputerFeedbackSnapshot: GarageInteractionFeedbackSnapshot? {
    guard let configuration = founderComputerFeedbackConfiguration else { return nil }
    let available = presentation.founderComputerAvailable
      && !isTraversingAtlantis
      && world.founderComputerInteractionAvailable
    let focused = available
      && abs(lookOrientation.yaw) <= 0.22
      && abs(lookOrientation.pitch) <= 0.18
    let elapsed = computerActivationStartedAt.map {
      max(0, ProcessInfo.processInfo.systemUptime - $0)
    }
    return .init(
      configuration: configuration,
      state: GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: available,
        isFocused: focused,
        activationElapsed: elapsed,
        reduceMotion: reduceMotion
      )
    )
  }

  private var founderComputerFeedbackState: GarageInteractionFeedbackState {
    founderComputerFeedbackSnapshot?.state ?? .unavailable
  }

  private func presentComputerActivationConfirmation() {
    guard let configuration = founderComputerFeedbackConfiguration else { return }
    computerActivationGeneration += 1
    let generation = computerActivationGeneration
    computerActivationStartedAt = ProcessInfo.processInfo.systemUptime
    computerActivationResetTask?.cancel()
    computerActivationResetTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(configuration.duration(reduceMotion: reduceMotion)))
      guard !Task.isCancelled, generation == computerActivationGeneration else { return }
      computerActivationStartedAt = nil
    }
  }

  private var chairFeedbackConfiguration: GarageInteractionFeedbackConfiguration? {
    world.spatialSpecification.facilityTier0InteractionSpace?
      .zone(for: .chair)
      .map { .chair(targetID: $0.id) }
  }

  private var chairFeedbackSnapshot: GarageInteractionFeedbackSnapshot? {
    guard let configuration = chairFeedbackConfiguration else { return nil }
    let elapsed = chairActivationStartedAt.map {
      max(0, ProcessInfo.processInfo.systemUptime - $0)
    }
    let activationActive = elapsed.map {
      $0 < configuration.duration(reduceMotion: reduceMotion)
    } ?? false
    let available = !isTraversingAtlantis
      && walkingEnabled
      && world.chairInteractionAvailable
    let focused = available && !world.whiteboardInteractionFocused
    return .init(
      configuration: configuration,
      state: GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: available || activationActive,
        isFocused: focused,
        activationElapsed: elapsed,
        reduceMotion: reduceMotion
      )
    )
  }

  private var chairFeedbackState: GarageInteractionFeedbackState {
    chairFeedbackSnapshot?.state ?? .unavailable
  }

  private func requestChairReturn() {
    guard walkingEnabled,
          world.chairInteractionAvailable,
          world.requestChairInteraction(reduceMotion: reduceMotion)
    else { return }
    presentChairActivationConfirmation()
  }

  private func presentChairActivationConfirmation() {
    guard let configuration = chairFeedbackConfiguration else { return }
    chairActivationGeneration += 1
    let generation = chairActivationGeneration
    chairActivationStartedAt = ProcessInfo.processInfo.systemUptime
    chairActivationResetTask?.cancel()
    chairActivationResetTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(configuration.duration(reduceMotion: reduceMotion)))
      guard !Task.isCancelled, generation == chairActivationGeneration else { return }
      chairActivationStartedAt = nil
    }
  }

  private var whiteboardFeedbackConfiguration: GarageInteractionFeedbackConfiguration? {
    world.spatialSpecification.facilityTier0InteractionSpace?
      .zone(for: .whiteboard)
      .map { .whiteboard(targetID: $0.id) }
  }

  private var whiteboardFeedbackSnapshot: GarageInteractionFeedbackSnapshot? {
    guard let configuration = whiteboardFeedbackConfiguration else { return nil }
    let elapsed = whiteboardActivationStartedAt.map {
      max(0, ProcessInfo.processInfo.systemUptime - $0)
    }
    let activationActive = elapsed.map {
      $0 < configuration.duration(reduceMotion: reduceMotion)
    } ?? false
    let available = !isTraversingAtlantis
      && walkingEnabled
      && world.whiteboardObservationAvailable
    return .init(
      configuration: configuration,
      state: GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: available || activationActive,
        isFocused: available && world.whiteboardInteractionFocused,
        activationElapsed: elapsed,
        reduceMotion: reduceMotion
      )
    )
  }

  private var whiteboardFeedbackState: GarageInteractionFeedbackState {
    whiteboardFeedbackSnapshot?.state ?? .unavailable
  }

  private func requestWhiteboardObservation() {
    guard walkingEnabled,
          world.requestWhiteboardObservation()
    else { return }
    presentWhiteboardActivationConfirmation()
    onCameraIntent(.whiteboard)
  }

  private func presentWhiteboardActivationConfirmation() {
    guard let configuration = whiteboardFeedbackConfiguration else { return }
    whiteboardActivationGeneration += 1
    let generation = whiteboardActivationGeneration
    whiteboardActivationStartedAt = ProcessInfo.processInfo.systemUptime
    whiteboardActivationResetTask?.cancel()
    whiteboardActivationResetTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(configuration.duration(reduceMotion: reduceMotion)))
      guard !Task.isCancelled, generation == whiteboardActivationGeneration else { return }
      whiteboardActivationStartedAt = nil
    }
  }

  // A RealityKit entity can sit directly behind a SwiftUI HUD control. Defer its
  // spatial tap by one main-actor turn so the foreground control owns that tap;
  // entering walking mode then rejects the coincident computer activation.
  private func deferSpatialComputerActivation() {
    Task { @MainActor in
      await Task.yield()
      openFounderComputer()
    }
  }

  private var freeLookDragGesture: some Gesture {
    DragGesture(minimumDistance: 8, coordinateSpace: .local)
      .onChanged { value in
        guard presentation.cameraState == .founderPOV,
              displayedCamera == .founderPOV,
              cameraOpacity == 1,
              !isTraversingAtlantis
        else { return }
        if dragStartLook == nil { dragStartLook = lookOrientation }
        guard let start = dragStartLook else { return }
        let sensitivity = FounderGarageCameraConfiguration.dragSensitivityRadiansPerPoint(
          viewportWidth: Float(viewportWidth)
        )
        let requested = FounderLookOrientation(
          yaw: start.yaw - Float(value.translation.width) * sensitivity,
          pitch: start.pitch - Float(value.translation.height) * sensitivity
        )
        let clamped = FounderGarageCameraConfiguration(spatial: world.spatialSpecification).clamped(requested)
        lookOrientation = clamped
        world.cameraController.setLookOrientation(clamped)
      }
      .onEnded { _ in dragStartLook = nil }
  }

  private func recenterFounderView() {
    dragStartLook = nil
    lookOrientation = .neutral
    world.cameraController.recenterFounderPOV(reduceMotion: reduceMotion)
  }

  private func toggleWalking() {
    switch world.interactionCoordinator.phase {
    case .seated:
      if world.requestChairExit(reduceMotion: reduceMotion) { walkingEnabled = true }
    case .idle where walkingEnabled:
      requestChairReturn()
    case .idle:
      world.cameraController.beginWalking(reduceMotion: reduceMotion)
      walkingEnabled = true
    default:
      break
    }
  }

  private var walkingControlTitle: String {
    switch world.interactionCoordinator.phase {
    case .idle: walkingEnabled ? "RETURN TO DESK" : "EXPLORE"
    case .seated: "EXPLORE"
    case .approaching, .stopping, .aligning: "RETURNING"
    case .sitting: "SITTING"
    case .standing, .departing: "STANDING"
    case .recovering: "RECOVERING"
    }
  }

  private func cameraControlLabel(_ title: String) -> some View {
    Text(title)
      .padding(.horizontal, 12)
      .frame(minWidth: 44, minHeight: 44)
      .background(.black.opacity(0.65), in: .capsule)
      .contentShape(.capsule)
  }

  private var prototypeHUD: some View {
    VStack(alignment: .leading) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("FOUNDER’S GARAGE")
            .font(.caption2.weight(.black))
            .tracking(1.1)
          Text(presentation.statusLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.76))
            .lineLimit(2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        Spacer()
#if DEBUG
        Menu {
          ForEach(FounderEnvironmentTimeState.allCases, id: \.self) { state in
            Button(state.accessibilityLabel) {
              world.setEnvironmentTimeState(state, reduceMotion: reduceMotion)
            }
            .accessibilityIdentifier(FounderGarageAccessibilityID.environmentTime(state))
            .accessibilityAddTraits(state == world.environmentTimeState ? [.isSelected] : [])
          }
        } label: {
          Label(world.environmentTimeState.title.uppercased(), systemImage: "sun.max.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(.black.opacity(0.65), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Garage Environment Time")
        .accessibilityValue(world.environmentTimeState.title)
        .accessibilityIdentifier(FounderGarageAccessibilityID.environmentTimeMenu)
#endif
      }
      Text(presentation.cameraState.title)
        .font(.caption.weight(.semibold))
        .padding(8)
        .background(.black.opacity(0.65), in: .capsule)
        .accessibilityIdentifier("founderGarage.currentView")
        .accessibilityValue(garageAccessibilityValue)
      Spacer()
      if presentation.cameraState == .founderPOV {
        HStack(spacing: 8) {
          Button { onCameraIntent(.garageOverview) } label: {
            cameraControlLabel("LOOK OUT")
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("founderGarage.lookOut")
          Button(action: recenterFounderView) {
            cameraControlLabel("RECENTER")
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Recenter Founder View")
          .accessibilityHint("Returns your seated view to the Founder Computer.")
          .accessibilityIdentifier("founderGarage.recenter")
          .accessibilityValue(lookOrientation.isNeutral ? "Centered" : "Free look active")
        }
        if founderModeAllowsDeviceAccess {
          HStack(spacing: 8) {
            Button(action: openFounderComputer) {
              cameraControlLabel("OPEN COMPUTER")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("founderGarage.openComputer")
            Menu {
              Button("Open iPhone", systemImage: "iphone", action: onOpenFounderPhone)
              Button("Open iPad", systemImage: "ipad.landscape", action: onOpenFounderTablet)
              Button("Open Server", systemImage: "server.rack", action: onOpenFounderServer)
              Button("Open Funding Board", systemImage: "pin.fill", action: onOpenFundingBoard)
            } label: {
              cameraControlLabel("WORKSTATION")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Founder workstation device")
            .accessibilityIdentifier("founderGarage.workstationMenu")
          }
        }
        HStack(alignment: .bottom, spacing: 10) {
          if garageLoadAttemptComplete {
            if !(walkingEnabled && world.interactionCoordinator.phase == .idle) {
              Button(action: toggleWalking) { cameraControlLabel(walkingControlTitle) }
                .buttonStyle(.plain)
                .accessibilityLabel(walkingEnabled ? "Return to Founder desk" : "Explore the Garage")
                .accessibilityIdentifier("founderGarage.camera.toggleWalking")
                .accessibilityValue(walkingEnabled ? "Walking" : "Seated")
                .disabled(![.idle, .seated].contains(world.interactionCoordinator.phase))
                .zIndex(10)
            }
          } else {
            cameraControlLabel("LOADING GARAGE")
              .accessibilityLabel("Loading Garage")
          }
          if walkingEnabled && world.interactionCoordinator.phase == .idle {
            FounderGarageMovementPad(
              onIntent: world.cameraController.setMovementIntent,
              onNudge: { lateral, forward in world.cameraController.nudge(lateral: lateral, forward: forward, reduceMotion: reduceMotion) }
            )
          }
        }
      } else {
        Menu {
          ForEach(FounderGarageCameraState.allCases.filter { $0 != .founderPOV }, id: \.self) { target in
            Button(target.title) { onCameraIntent(target) }
              .accessibilityIdentifier("founderGarage.focus.\(target.rawValue)")
              .accessibilityAddTraits(presentation.cameraState == target ? [.isSelected] : [])
          }
        } label: {
          cameraControlLabel("LOOK OUT")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("founderGarage.focusMenu")
        .accessibilityValue(presentation.cameraState.title)
        Button { onCameraIntent(.founderPOV) } label: {
          cameraControlLabel("Return to Founder View")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("founderGarage.returnWorkstation")
      }
      if let snapshot = primaryInteractionPrompt {
        GarageInteractionPrompt(
          snapshot: snapshot,
          reduceMotion: reduceMotion,
          accessibilityValue: presentation.accessibilitySummary,
          action: { activatePrompt(snapshot) }
        )
      }
#if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--founder-camera-diagnostics") {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
          let snapshot = world.cameraController.snapshot
          let locomotion = world.founderAvatarController.locomotion.diagnostics
          Text(String(format: "%@ · p %.2f %.2f %.2f\nv %.2f %.2f · ω %.2f %.2f\n%@ · %@ · drift %.4f · focus %@\nanim %@ ← %@ · speed %.2f · blend %.2f\nfacing %.2f → %.2f · root %.4f · seat %.4f", snapshot.mode, snapshot.position.x, snapshot.position.y, snapshot.position.z, snapshot.velocity.x, snapshot.velocity.z, snapshot.angularVelocity.x, snapshot.angularVelocity.y, snapshot.collision, snapshot.transition?.rawValue ?? "idle", snapshot.founderPOVDriftError, snapshot.interactionFocus?.rawValue ?? "none", locomotion.state.rawValue, locomotion.previousState.rawValue, locomotion.playbackSpeed, locomotion.blendProgress, locomotion.avatarFacing, locomotion.targetFacing, locomotion.positionalError, locomotion.seatedAnchorError))
            .font(.caption2.monospacedDigit()).padding(7).background(.black.opacity(0.72), in: .rect(cornerRadius: 7))
            .accessibilityIdentifier("founderGarage.camera.diagnostics")
        }
      }
#endif
      if atlantisReady && (walkingEnabled || presentation.cameraState == .garageDoor || presentation.cameraState == .front) {
        Button {
          world.toggleGarageDoor(reduceMotion: reduceMotion)
        } label: {
          Label(
            world.garageDoorState.controlTitle,
            systemImage: world.garageDoorState.isOpen ? "door.garage.closed" : "door.garage.open"
          )
          .font(.caption.weight(.bold))
          .padding(.horizontal, 12)
          .frame(minWidth: 44, minHeight: 44)
          .background(.black.opacity(0.65), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!world.garageDoorControlAvailable)
        .accessibilityLabel(world.garageDoorState.isOpen ? "Close Garage Door" : "Open Garage Door")
        .accessibilityValue(world.garageDoorState.accessibilityValue)
        .accessibilityHint("Moves the sectional garage door along its overhead tracks.")
        .accessibilityIdentifier(FounderGarageAccessibilityID.garageDoorToggle)
      }
    }
    .foregroundStyle(.white)
    .padding(18)
  }

  private var founderModeAllowsDeviceAccess: Bool {
    !walkingEnabled
      && world.cameraController.playerSpatialState.navigationMode == .seated
  }

  private var primaryInteractionPrompt: GarageInteractionFeedbackSnapshot? {
    GarageInteractionFeedbackResolver.primaryPrompt(
      from: [
        founderComputerFeedbackSnapshot,
        chairFeedbackSnapshot,
        whiteboardFeedbackSnapshot
      ].compactMap { $0 }
    )
  }

  private func activatePrompt(_ snapshot: GarageInteractionFeedbackSnapshot) {
    if snapshot.configuration.targetID == chairFeedbackConfiguration?.targetID {
      requestChairReturn()
    } else if snapshot.configuration.targetID == whiteboardFeedbackConfiguration?.targetID {
      requestWhiteboardObservation()
    } else if snapshot.configuration.targetID == founderComputerFeedbackConfiguration?.targetID {
      openFounderComputer()
    }
  }
}

private struct GarageInteractionPrompt: View {
  let snapshot: GarageInteractionFeedbackSnapshot
  let reduceMotion: Bool
  let accessibilityValue: String
  let action: () -> Void

  var body: some View {
    let emphasis = GarageInteractionVisualEmphasis.resolve(
      state: snapshot.state,
      reduceMotion: reduceMotion
    )
    Button(action: action) {
      Label(
        snapshot.configuration.promptText,
        systemImage: snapshot.state == .activated
          ? "checkmark.circle.fill"
          : snapshot.configuration.systemImage
      )
      .font(.caption.weight(.bold))
      .tracking(0.35)
      .padding(.horizontal, 14)
      .frame(minWidth: 44, minHeight: 44)
      .background(.black.opacity(0.68), in: .capsule)
      .overlay {
        Capsule()
          .stroke(.cyan.opacity(emphasis.promptBorderOpacity), lineWidth: 1)
      }
      .scaleEffect(emphasis.promptScale)
    }
    .buttonStyle(.plain)
    .animation(
      reduceMotion ? nil : .easeOut(duration: snapshot.configuration.activationDuration),
      value: snapshot.state
    )
    .accessibilityLabel(snapshot.configuration.accessibilityLabel)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint(snapshot.configuration.accessibilityHint)
    .accessibilityIdentifier(snapshot.configuration.accessibilityIdentifier)
  }
}

#if DEBUG
/// Deterministic visual-review route only. It uses the production Garage view,
/// target identity, availability resolver, prompt, and activation callback path.
struct FounderGarageInteractionFeedbackReviewHost: View {
  private let presentation = FounderWorldPresentationModel(
    cameraState: .founderPOV,
    founderState: .seatedIdle,
    facility: .founderGarage,
    operatingPeriod: .morning,
    activeWorkCount: 0,
    reviewAttentionCount: 0,
    energyLevel: 1,
    roomLightIntensity: 0.78,
    computerGlowIntensity: 0.62,
    founderComputerAvailable: true,
    statusLabel: "Review Founder Computer feedback"
  )

  var body: some View {
    FounderGarageRealityView(
      presentation: presentation,
      onOpenFounderComputer: {}
    )
  }
}

struct FounderGarageChairFeedbackReviewHost: View {
  private let presentation = FounderWorldPresentationModel(
    cameraState: .founderPOV,
    founderState: .seatedIdle,
    facility: .founderGarage,
    operatingPeriod: .morning,
    activeWorkCount: 0,
    reviewAttentionCount: 0,
    energyLevel: 1,
    roomLightIntensity: 0.78,
    computerGlowIntensity: 0.62,
    founderComputerAvailable: true,
    statusLabel: "Review Chair feedback"
  )

  var body: some View {
    FounderGarageRealityView(
      presentation: presentation,
      onOpenFounderComputer: {}
    )
  }
}

struct FounderGarageWhiteboardFeedbackReviewHost: View {
  @State private var cameraState = FounderGarageCameraState.founderPOV

  private var presentation: FounderWorldPresentationModel {
    FounderWorldPresentationModel(
      cameraState: cameraState,
      founderState: .seatedIdle,
      facility: .founderGarage,
      operatingPeriod: .morning,
      activeWorkCount: 0,
      reviewAttentionCount: 0,
      energyLevel: 1,
      roomLightIntensity: 0.78,
      computerGlowIntensity: 0.62,
      founderComputerAvailable: true,
      statusLabel: "Review Whiteboard feedback"
    )
  }

  var body: some View {
    FounderGarageRealityView(
      presentation: presentation,
      onOpenFounderComputer: {},
      onCameraIntent: { cameraState = $0 }
    )
  }
}
#endif

private struct FounderGarageMovementPad: View {
  var onIntent: (FounderGarageMovementIntent) -> Void
  var onNudge: (Float, Float) -> Void
  var body: some View {
    GeometryReader { geometry in
      let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
      ZStack { Circle().fill(.black.opacity(0.68)); Circle().stroke(.white.opacity(0.28)); Image(systemName: "move.3d") }
        .contentShape(.circle)
        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { value in
          let radius = max(min(geometry.size.width, geometry.size.height) / 2, 1)
          onIntent(.init(lateral: Float((value.location.x - center.x) / radius), forward: Float((center.y - value.location.y) / radius)))
        }.onEnded { _ in onIntent(.idle) })
    }
    .frame(width: 72, height: 72)
    .accessibilityElement().accessibilityLabel("Garage movement")
    .accessibilityIdentifier("founderGarage.camera.movementPad")
    .accessibilityAction(named: "Walk Forward") { onNudge(0, 1) }
    .accessibilityAction(named: "Walk Backward") { onNudge(0, -1) }
    .accessibilityAction(named: "Step Left") { onNudge(-1, 0) }
    .accessibilityAction(named: "Step Right") { onNudge(1, 0) }
  }
}
