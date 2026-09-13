import XCTest
@testable import Solo_Unicorn_Run

final class FounderDeskWorkspaceTests: XCTestCase {
  func testPhysicalDeviceWakeStateMappingHasClearLuminanceHierarchy() {
    for device in FounderDeskDevice.allCases {
      let asleep = devicePresentation(device: device, state: .asleep)
      let idle = devicePresentation(device: device, state: .idle)
      let waking = devicePresentation(device: device, state: .waking)
      let active = devicePresentation(device: device, state: .active)
      XCTAssertLessThan(asleep.screenLuminance, idle.screenLuminance)
      XCTAssertLessThan(idle.screenLuminance, waking.screenLuminance)
      XCTAssertLessThanOrEqual(waking.screenLuminance, active.screenLuminance)
      XCTAssertTrue(waking.physicalResponseEnabled)
      XCTAssertTrue(active.screenLifeEnabled)
    }
  }

  func testDevicePresentationUsesOnlySafePendingBoolean() {
    let quiet = devicePresentation(device: .phone, state: .idle, safePending: false)
    let pending = devicePresentation(device: .phone, state: .idle, safePending: true)
    XCTAssertFalse(quiet.safePendingIndicatorVisible)
    XCTAssertTrue(pending.safePendingIndicatorVisible)
    XCTAssertGreaterThan(pending.powerIndicatorIntensity, quiet.powerIndicatorIntensity)
    XCTAssertEqual(pending.screenLuminance, quiet.screenLuminance)
  }

  func testVisibleOperatingActivityStrengthensEquipmentWithoutInventingState() {
    let quiet = devicePresentation(device: .computer, state: .idle, visibleOperatingIntensity: 0)
    let operating = devicePresentation(device: .computer, state: .idle, visibleOperatingIntensity: 1)
    let reduced = devicePresentation(device: .computer, state: .idle, visibleOperatingIntensity: 1, reduceMotion: true)
    XCTAssertEqual(quiet.state, operating.state)
    XCTAssertGreaterThan(operating.screenLuminance, quiet.screenLuminance)
    XCTAssertGreaterThan(operating.localGlowIntensity, quiet.localGlowIntensity)
    XCTAssertGreaterThan(operating.peripheralBacklightIntensity, quiet.peripheralBacklightIntensity)
    XCTAssertGreaterThan(operating.operatingIndicatorIntensity, quiet.operatingIndicatorIntensity)
    XCTAssertEqual(reduced.screenLuminance, operating.screenLuminance)
    XCTAssertEqual(reduced.localGlowIntensity, operating.localGlowIntensity)
    XCTAssertFalse(reduced.screenLifeEnabled)
  }

  func testReduceMotionKeepsDeviceStateAndLightingButRemovesPhysicalTravel() {
    let standard = devicePresentation(device: .tablet, state: .waking)
    let reduced = devicePresentation(device: .tablet, state: .waking, reduceMotion: true)
    XCTAssertEqual(reduced.state, standard.state)
    XCTAssertEqual(reduced.screenLuminance, standard.screenLuminance)
    XCTAssertEqual(reduced.powerIndicatorIntensity, standard.powerIndicatorIntensity)
    XCTAssertFalse(reduced.physicalResponseEnabled)
    XCTAssertFalse(reduced.screenLifeEnabled)
    XCTAssertEqual(reduced.reflectionOffset, 0)
  }

  func testOffscreenDeviceThrottlesDecorativeWorkWithoutChangingState() {
    let visible = devicePresentation(device: .phone, state: .idle, visible: true)
    let offscreen = devicePresentation(device: .phone, state: .idle, visible: false)
    XCTAssertEqual(offscreen.state, visible.state)
    XCTAssertEqual(offscreen.screenLuminance, visible.screenLuminance)
    XCTAssertFalse(offscreen.screenLifeEnabled)
    XCTAssertFalse(offscreen.physicalResponseEnabled)
  }

  func testFounderComputerRemainsActiveAfterLookOutWhileOtherDevicesIdle() {
    XCTAssertEqual(FounderDeviceTransitionPolicy.restingState(afterClosing: .computer), .active)
    XCTAssertEqual(FounderDeviceTransitionPolicy.restingState(afterClosing: .phone), .idle)
    XCTAssertEqual(FounderDeviceTransitionPolicy.restingState(afterClosing: .tablet), .idle)
    XCTAssertEqual(FounderDeviceTransitionPolicy.restingState(afterClosing: .server), .idle)
  }

  func testWakeDelayIsResponsiveAndReduceMotionIsImmediate() {
    for device in FounderDeskDevice.allCases {
      let delay = FounderDeviceTransitionPolicy.wakeDelayMilliseconds(for: device, reduceMotion: false)
      XCTAssertGreaterThan(delay, 0)
      XCTAssertLessThanOrEqual(delay, 155)
      XCTAssertEqual(FounderDeviceTransitionPolicy.wakeDelayMilliseconds(for: device, reduceMotion: true), 0)
    }
  }

  func testInfrastructureReactionIsDeterministicAndEventDriven() {
    let event = FounderGarageEventEmphasis(kind: .assignmentArrived, agentID: "aurora", token: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"), priority: 2, duration: 0.58)
    let first = FounderInfrastructureReactionPresentation.derive(stations: [], event: event, reduceMotion: false, sceneActive: true)
    let second = FounderInfrastructureReactionPresentation.derive(stations: [], event: event, reduceMotion: false, sceneActive: true)
    let idle = FounderInfrastructureReactionPresentation.derive(stations: [], event: .none, reduceMotion: false, sceneActive: true)
    XCTAssertEqual(first, second)
    XCTAssertGreaterThan(first.networkActivity, idle.networkActivity)
    XCTAssertGreaterThan(first.storageActivity, idle.storageActivity)
    XCTAssertGreaterThan(first.routerActivity, idle.routerActivity)
    XCTAssertEqual(first.eventToken, event.token)
  }

  func testInfrastructureReduceMotionKeepsStatusAndStopsRotation() {
    let standard = FounderInfrastructureReactionPresentation.derive(stations: [], event: .none, reduceMotion: false, sceneActive: true)
    let reduced = FounderInfrastructureReactionPresentation.derive(stations: [], event: .none, reduceMotion: true, sceneActive: true)
    XCTAssertEqual(reduced.serverFanActivity, standard.serverFanActivity)
    XCTAssertEqual(reduced.storageActivity, standard.storageActivity)
    XCTAssertEqual(reduced.networkActivity, standard.networkActivity)
    XCTAssertFalse(reduced.continuousMotionEnabled)
  }

  func testDefaultSelectionIsDeskOverview() {
    let state = FounderDeskNavigationState()
    XCTAssertEqual(state.selection, .overview)
    XCTAssertEqual(state.camera.mode, .freeLook)
    XCTAssertTrue(state.lookOutActive)
  }

  func testEveryPhysicalDeviceCanBeSelectedAndClosed() {
    for device in FounderDeskDevice.allCases where device != .computer {
      var state = FounderDeskNavigationState()
      XCTAssertNil(state.select(device))
      XCTAssertEqual(state.selection, .device(device))
      state.closeSecondaryDevice()
      XCTAssertEqual(state.selection, .overview)
    }

    var computer = FounderDeskNavigationState()
    XCTAssertEqual(computer.select(.computer), .computerFocused)
    XCTAssertEqual(computer.camera.mode, .transitioningToComputerFocus)
    computer.completeCameraTransition(to: .computerFocused)
    XCTAssertEqual(computer.selection, .device(.computer))
  }

  func testSwitchingDevicesUsesOneExclusiveSelection() {
    var state = FounderDeskNavigationState()
    state.select(.phone)
    state.select(.tablet)
    XCTAssertEqual(state.selection, .device(.phone))
    state.closeSecondaryDevice()
    state.select(.tablet)
    XCTAssertEqual(state.selection, .device(.tablet))
  }

  func testLookOutBeginsAndCompletesEstablishedFreeLookTransition() {
    var state = focusedComputerState()
    XCTAssertEqual(state.lookOut(), .freeLook)
    XCTAssertEqual(state.camera.mode, .transitioningToFreeLook)
    XCTAssertEqual(state.selection, .overview)
    XCTAssertFalse(state.cameraControlsActive)
    state.completeCameraTransition(to: .freeLook)
    XCTAssertEqual(state.camera.mode, .freeLook)
    XCTAssertTrue(state.cameraControlsActive)
  }

  func testCameraGesturesAndManualControlsWorkOnlyInLookOut() {
    var state = FounderDeskNavigationState()
    state.look(horizontal: 0.4, vertical: 0.1, reduceMotion: false)
    XCTAssertEqual(state.camera.horizontalLook, 0.4)
    XCTAssertEqual(state.camera.verticalLook, 0.1)
    state.centerCamera()
    XCTAssertEqual(state.camera.horizontalLook, 0)
    state.select(.phone)
    state.look(horizontal: 1, vertical: 0.3, reduceMotion: false)
    XCTAssertEqual(state.camera.horizontalLook, 0)
    XCTAssertEqual(state.camera.verticalLook, 0)
  }

  func testSelectingMonitorReturnsToComputerFocus() {
    var state = FounderDeskNavigationState()
    XCTAssertEqual(state.select(.computer), .computerFocused)
    XCTAssertEqual(state.camera.mode, .transitioningToComputerFocus)
    state.completeCameraTransition(to: .computerFocused)
    XCTAssertEqual(state.selection, .device(.computer))
    XCTAssertEqual(state.camera.mode, .computerFocused)
  }

  func testSecondaryDevicesOpenOnlyFromLookOutAndCloseBackToLookOut() {
    for device in [FounderDeskDevice.phone, .tablet, .server] {
      var state = FounderDeskNavigationState()
      XCTAssertNil(state.select(device))
      XCTAssertEqual(state.selection, .device(device))
      XCTAssertFalse(state.cameraControlsActive)
      state.closeSecondaryDevice()
      XCTAssertTrue(state.lookOutActive)
    }
  }

  func testServerHandoffUsesExistingCloseAndComputerFocusSequence() {
    var state = FounderDeskNavigationState()
    state.select(.server)
    state.closeSecondaryDevice()
    XCTAssertEqual(state.select(.computer), .computerFocused)
    XCTAssertEqual(state.selection, .overview)
    XCTAssertEqual(state.camera.mode, .transitioningToComputerFocus)
    state.completeCameraTransition(to: .computerFocused)
    XCTAssertEqual(state.selection, .device(.computer))

    XCTAssertEqual(state.lookOut(), .freeLook)
    state.completeCameraTransition(to: .freeLook)
    XCTAssertNil(state.select(.server))
    XCTAssertEqual(state.selection, .device(.server))
  }

  func testSecondaryDeviceRoundTripRetainsCameraOrientation() {
    var state = FounderDeskNavigationState()
    state.setLook(horizontal: 0.55, vertical: -0.12, reduceMotion: false)
    let orientation = state.camera
    state.select(.tablet)
    state.closeSecondaryDevice()
    XCTAssertEqual(state.camera, orientation)
  }

  func testProjectedHitRegionsFollowPhysicalWorldAnchors() {
    let equipment = FounderDeskEquipmentLayout(viewportSize: CGSize(width: 402, height: 874), regularWidth: false)
    let center = FounderEnvironmentCameraState(mode: .freeLook)
    let right = FounderEnvironmentCameraState(horizontalLook: 0.6, mode: .freeLook)
    for device in FounderDeskDevice.allCases {
      let centerRegion = equipment.hitRegion(for: device, camera: center)
      let rightRegion = equipment.hitRegion(for: device, camera: right)
      XCTAssertEqual(centerRegion.midX, equipment.viewportPosition(for: device, camera: center).x, accuracy: 0.001)
      XCTAssertNotEqual(centerRegion.midX, rightRegion.midX)
      XCTAssertGreaterThanOrEqual(centerRegion.width, 44)
      XCTAssertGreaterThanOrEqual(centerRegion.height, 44)
    }
  }

  func testDeskAnchorsGroundServerBesideDeskOnFloor() throws {
    let anchors = FounderEnvironmentLayout(viewportSize: CGSize(width: 402, height: 874)).anchors
    let server = try XCTUnwrap(anchors[.companyServer])
    let deskRight = try XCTUnwrap(anchors[.founderDeskRightEdge])
    let surface = try XCTUnwrap(anchors[.founderDeskSurface])
    let floorSide = try XCTUnwrap(anchors[.founderDeskFloorSide])
    XCTAssertGreaterThan(server.x, deskRight.x)
    XCTAssertGreaterThan(floorSide.y, surface.y)
    XCTAssertEqual(server.x, floorSide.x)
  }

  func testCompactAndRegularEquipmentGeometryIsDistinct() {
    let compact = FounderDeskEquipmentLayout(viewportSize: CGSize(width: 402, height: 874), regularWidth: false)
    let regular = FounderDeskEquipmentLayout(viewportSize: CGSize(width: 1_024, height: 1_366), regularWidth: true)
    XCTAssertLessThan(compact.deviceSize(for: .tablet).width, regular.deviceSize(for: .tablet).width)
    XCTAssertLessThan(compact.deviceSize(for: .server).height, regular.deviceSize(for: .server).height)
  }

  func testCompactAndRegularUseIntentionalCameraCompositions() {
    let compact = FounderEnvironmentLayout(viewportSize: CGSize(width: 402, height: 874))
    let regular = FounderEnvironmentLayout(viewportSize: CGSize(width: 1_024, height: 1_366))
    XCTAssertEqual(compact.composition, .compactCockpit)
    XCTAssertEqual(regular.composition, .regularEstablishing)
    XCTAssertLessThan(
      compact.visibleWorldBounds(camera: .init(mode: .freeLook)).width,
      regular.visibleWorldBounds(camera: .init(mode: .freeLook)).width
    )
    XCTAssertNotEqual(compact.anchors[.stacksStation], regular.anchors[.stacksStation])
    XCTAssertNotEqual(compact.floorHorizonY / compact.viewportSize.height, regular.floorHorizonY / regular.viewportSize.height)
  }

  func testCompactCockpitCentersFounderComputerAndUsesPanningForServer() {
    let layout = FounderDeskEquipmentLayout(viewportSize: CGSize(width: 402, height: 874), regularWidth: false)
    let center = FounderEnvironmentCameraState(mode: .freeLook)
    let right = FounderEnvironmentCameraState(horizontalLook: 0.62, mode: .freeLook)
    XCTAssertTrue(layout.isVisible(.computer, camera: center))
    XCTAssertTrue(layout.isVisible(.phone, camera: center))
    XCTAssertTrue(layout.isVisible(.tablet, camera: center))
    XCTAssertFalse(layout.isVisible(.server, camera: center))
    XCTAssertTrue(layout.isVisible(.server, camera: right))
  }

  func testFounderMonitorUsesSubstantialWorkstationProportion() {
    let compact = FounderDeskEquipmentLayout(viewportSize: CGSize(width: 402, height: 874), regularWidth: false)
    let regular = FounderDeskEquipmentLayout(viewportSize: CGSize(width: 1_024, height: 1_366), regularWidth: true)
    for layout in [compact, regular] {
      let size = layout.deviceSize(for: .computer)
      let ratio = size.width / size.height
      XCTAssertGreaterThan(ratio, 1.5)
      XCTAssertLessThan(ratio, 1.65)
    }
    XCTAssertGreaterThan(compact.deviceSize(for: .computer).height, 112)
    XCTAssertGreaterThan(regular.deviceSize(for: .computer).height, 170)
  }

  func testAmbientGarageHasIndependentIdleBaselineWithoutGameplayRNG() {
    let first = FounderGarageAmbientMotion.derive(agents: [], reduceMotion: false, sceneActive: true)
    let second = FounderGarageAmbientMotion.derive(agents: [], reduceMotion: false, sceneActive: true)
    XCTAssertEqual(first, second)
    XCTAssertTrue(first.continuousMotionEnabled)
    XCTAssertGreaterThanOrEqual(first.perceptibleChannelCount, 8)
    XCTAssertGreaterThan(first.fanActivity, 0)
    XCTAssertGreaterThan(first.screenLife, 0)
    XCTAssertGreaterThan(first.serverActivity, 0)
    XCTAssertGreaterThan(first.lightingDrift, 0)
  }

  func testAmbientRhythmsAreFixedAndUnsynchronized() {
    let profiles = FounderGarageAmbientChannel.allCases.map(FounderGarageAmbientRhythm.profile)
    XCTAssertEqual(profiles.count, 12)
    XCTAssertEqual(Set(profiles.map(\.channel)).count, profiles.count)
    XCTAssertEqual(Set(profiles.map(\.duration)).count, profiles.count)
    XCTAssertTrue(profiles.allSatisfy { $0.amplitude <= 0.05 })
    XCTAssertEqual(
      FounderGarageAmbientRhythm.profile(for: .serverCooling),
      FounderGarageAmbientRhythm.profile(for: .serverCooling)
    )
  }

  func testMechanicalEquipmentUsesVisibleWorkloadAndNoRandomInput() {
    let idle = FounderGarageMechanicalPresentation.derive(
      agents: [],
      reduceMotion: false,
      sceneActive: true
    )
    let repeated = FounderGarageMechanicalPresentation.derive(
      agents: [],
      reduceMotion: false,
      sceneActive: true
    )
    XCTAssertEqual(idle, repeated)
    XCTAssertTrue(idle.continuousRotationEnabled)
    XCTAssertGreaterThan(idle.rearVentilationActivity, 0)
    XCTAssertGreaterThan(idle.serverCoolingActivity, 0)
    XCTAssertGreaterThan(idle.rearVentilationRotationDuration, idle.serverCoolingRotationDuration)
  }

  func testReduceMotionKeepsMechanicalStateAndStopsRotation() {
    let standard = FounderGarageMechanicalPresentation.derive(
      agents: [],
      reduceMotion: false,
      sceneActive: true
    )
    let reduced = FounderGarageMechanicalPresentation.derive(
      agents: [],
      reduceMotion: true,
      sceneActive: true
    )
    XCTAssertFalse(reduced.continuousRotationEnabled)
    XCTAssertTrue(reduced.staticActivityIndicationVisible)
    XCTAssertEqual(reduced.rearVentilationActivity, standard.rearVentilationActivity)
    XCTAssertEqual(reduced.serverCoolingActivity, standard.serverCoolingActivity)
  }

  func testAtmosphereUsesSmallBoundedPresentationOnlyParticleBudget() {
    let standard = FounderGarageEnvironmentPresentation.derive(
      facility: .founderGarage,
      infrastructure: [],
      reduceMotion: false,
      sceneActive: true
    )
    let reduced = FounderGarageEnvironmentPresentation.derive(
      facility: .founderGarage,
      infrastructure: [],
      reduceMotion: true,
      sceneActive: true
    )
    XCTAssertEqual(standard.atmosphericParticleCount, 7)
    XCTAssertLessThanOrEqual(standard.atmosphericParticleCount, 8)
    XCTAssertEqual(reduced.atmosphericParticleCount, 0)
  }

  func testReduceMotionRetainsAmbientStateButStopsContinuousTravel() {
    let reduced = FounderGarageAmbientMotion.derive(agents: [], reduceMotion: true, sceneActive: true)
    XCTAssertFalse(reduced.continuousMotionEnabled)
    XCTAssertEqual(reduced.fanActivity, 0)
    XCTAssertGreaterThanOrEqual(reduced.perceptibleChannelCount, 5)
    XCTAssertGreaterThan(reduced.screenLife, 0)
    XCTAssertGreaterThan(reduced.serverActivity, 0)
    XCTAssertGreaterThan(reduced.lightingDrift, 0)
  }

  func testAmbientAudioHooksRemainPresentationOnly() {
    let hooks = FounderGarageAudioHookPresentation.derive(stations: [], event: .none)
    XCTAssertEqual(hooks.cues, [])
    XCTAssertEqual(hooks.ambientCues, [.garageVentilation, .serverHum, .equipmentCooling, .distantGarage])
    XCTAssertNil(hooks.eventToken)
  }

  func testOperationalLightingUsesVisibleStatePrecedence() {
    var momentumStats = FounderStats()
    momentumStats.momentum = 82
    let publicPressure = PublicMediaEvent(
      id: "public-pressure",
      program: .techComLive,
      tone: .critical,
      headline: "SOLO faces public scrutiny",
      summary: "A published company story enters the broadcast cycle.",
      tickerItems: ["SOLO PUBLIC UPDATE"],
      coverageDelta: -6,
      venture: 1,
      sprint: 1,
      concernsPlayerCompany: true
    )

    XCTAssertEqual(operationalMotion().lighting.operationalState, .quiet)
    XCTAssertEqual(operationalMotion(stats: momentumStats).lighting.operationalState, .positiveMomentum)
    XCTAssertEqual(
      operationalMotion(agents: [visibleAgent(activity: .working)]).lighting.operationalState,
      .activeWork
    )
    XCTAssertEqual(
      operationalMotion(publicEvents: [publicPressure]).lighting.operationalState,
      .publicPressure
    )
    XCTAssertEqual(
      operationalMotion(
        agents: [visibleAgent(activity: .awaitingReview, needsFounderAttention: true)],
        publicEvents: [publicPressure]
      ).lighting.operationalState,
      .reviewAttention
    )
  }

  func testOperationalLightingRejectsNonPublicPressureWithoutRNGInput() {
    let hidden = PublicMediaEvent(
      id: "hidden-pressure",
      program: .breaking,
      tone: .critical,
      headline: "Unrevealed result",
      summary: "Must not enter Garage presentation.",
      tickerItems: [],
      coverageDelta: -10,
      venture: 1,
      sprint: 1,
      concernsPlayerCompany: true,
      isPublic: false
    )
    let first = operationalMotion(publicEvents: [hidden])
    let second = operationalMotion(publicEvents: [hidden])
    XCTAssertEqual(first, second)
    XCTAssertEqual(first.lighting.operationalState, .quiet)
    XCTAssertEqual(first.lighting.publicPressureIntensity, 0)
  }

  func testCurrentSprintPublicFundingSuccessAddsStaticGarageAcknowledgment() throws {
    let opportunity = try XCTUnwrap(FundingBoardCatalog.opportunities.first {
      $0.id == "pioneer-ai-grant"
    })
    let fundingEvent = try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: opportunity,
      outcome: .awarded,
      venture: 1,
      sprint: 2
    ))
    let currentEvents = [fundingEvent, SignalTVProgramming.marketPulse(venture: 1, sprint: 2)]
    let previousEvents = [fundingEvent, SignalTVProgramming.marketPulse(venture: 1, sprint: 3)]
    let standard = operationalMotion(publicEvents: currentEvents)
    let reduced = operationalMotion(publicEvents: currentEvents, reduceMotion: true)

    XCTAssertGreaterThan(standard.lighting.fundingAcknowledgmentIntensity, 0)
    XCTAssertEqual(
      standard.lighting.fundingAcknowledgmentIntensity,
      reduced.lighting.fundingAcknowledgmentIntensity
    )
    XCTAssertFalse(reduced.ambient.continuousMotionEnabled)
    XCTAssertEqual(
      operationalMotion(publicEvents: previousEvents).lighting.fundingAcknowledgmentIntensity,
      0
    )
  }

  func testPhysicalDeviceSilhouettesRemainDistinctWithoutLabels() {
    for regularWidth in [false, true] {
      let viewport = regularWidth ? CGSize(width: 1_024, height: 1_366) : CGSize(width: 402, height: 874)
      let layout = FounderDeskEquipmentLayout(viewportSize: viewport, regularWidth: regularWidth)
      XCTAssertGreaterThan(layout.deviceSize(for: .computer).width, layout.deviceSize(for: .computer).height)
      XCTAssertGreaterThan(layout.deviceSize(for: .phone).height, layout.deviceSize(for: .phone).width)
      XCTAssertGreaterThan(layout.deviceSize(for: .tablet).width, layout.deviceSize(for: .tablet).height)
      XCTAssertGreaterThan(layout.deviceSize(for: .server).height, layout.deviceSize(for: .server).width)
    }
  }

  func testCameraChromeCollapsesAfterDiscoveryWithoutRemovingAccessibilityAlternatives() {
    XCTAssertFalse(FounderDeskCameraChromePolicy.exposesManualControls(expanded: false, accessibilityText: false))
    XCTAssertTrue(FounderDeskCameraChromePolicy.exposesManualControls(expanded: true, accessibilityText: false))
    XCTAssertTrue(FounderDeskCameraChromePolicy.exposesManualControls(expanded: false, accessibilityText: true))
    XCTAssertTrue(FounderDeskCameraChromePolicy.showsInstruction(hasUsedFreeLook: false))
    XCTAssertFalse(FounderDeskCameraChromePolicy.showsInstruction(hasUsedFreeLook: true))
  }

  func testReduceMotionKeepsEstablishedWorkspaceTransitionEndpoints() {
    var state = FounderDeskNavigationState()
    XCTAssertEqual(state.transitionStyle(reduceMotion: true), .crossfade)
    XCTAssertEqual(state.select(.computer), .computerFocused)
    state.completeCameraTransition(to: .computerFocused)
    XCTAssertEqual(state.camera.mode, .computerFocused)
    XCTAssertEqual(state.lookOut(), .freeLook)
    state.completeCameraTransition(to: .freeLook)
    XCTAssertEqual(state.camera.mode, .freeLook)
  }

  func testNormalMotionUsesSpatialFocus() {
    XCTAssertEqual(FounderDeskNavigationState().transitionStyle(reduceMotion: false), .spatialFocus)
  }

  func testReduceMotionUsesCrossfade() {
    XCTAssertEqual(FounderDeskNavigationState().transitionStyle(reduceMotion: true), .crossfade)
  }

  func testCompactAndRegularSizeClassesHaveDistinctSpatialLayouts() {
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: false, accessibilityText: false, height: 800), .spatialCompact)
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: true, accessibilityText: false, height: 800), .spatialRegular)
  }

  func testFundingBoardUsesCanonicalUpperLeftWallAnchor() throws {
    for size in [
      CGSize(width: 390, height: 844),
      CGSize(width: 440, height: 956),
      CGSize(width: 820, height: 1_180)
    ] {
      let layout = FounderEnvironmentLayout(viewportSize: size)
      let board = try XCTUnwrap(layout.anchors[.fundingBoard])
      let fan = try XCTUnwrap(layout.anchors[.mainVentilationFan])
      let television = try XCTUnwrap(layout.anchors[.signalTV])
      XCTAssertLessThan(board.x, fan.x)
      XCTAssertLessThan(fan.x, television.x)
      XCTAssertLessThanOrEqual(board.x, 280)
      XCTAssertLessThan(board.y, 200)
    }
  }

  func testFundingBoardHotspotIsReadableAndClearsGarageDoorAcrossIPhoneAndIPad() {
    let leftLook = FounderEnvironmentCameraState(horizontalLook: -1, mode: .freeLook)
    for size in [
      CGSize(width: 390, height: 844),
      CGSize(width: 440, height: 956),
      CGSize(width: 820, height: 1_180)
    ] {
      let hotspot = FundingBoardHotspotLayout(viewportSize: size)
      let frame = hotspot.frame(camera: leftLook)
      let activationFrame = hotspot.activationFrame(camera: leftLook)
      let doorFrame = FounderGarageDoorLayout(viewportSize: size).frame(camera: leftLook)
      let visibleFrame = frame.intersection(CGRect(origin: .zero, size: size))
      XCTAssertTrue(hotspot.isSelectable(camera: leftLook))
      XCTAssertGreaterThanOrEqual(frame.width, 44)
      XCTAssertGreaterThanOrEqual(frame.height, 44)
      XCTAssertGreaterThanOrEqual(visibleFrame.width / frame.width, 0.60)
      XCTAssertLessThan(frame.maxX, doorFrame.minX)
      XCTAssertGreaterThanOrEqual(activationFrame.width, 44)
      XCTAssertGreaterThanOrEqual(activationFrame.height, 44)
      XCTAssertTrue(CGRect(origin: .zero, size: size).contains(activationFrame))
      if size.width >= 700 {
        XCTAssertEqual(visibleFrame.width, frame.width, accuracy: 0.001)
      }
    }
  }

  func testFundingBoardFounderCopyContainsNoHiddenSimulationTruth() {
    let text = FundingBoardCatalog.opportunities.flatMap { opportunity in
      [opportunity.name, opportunity.summary, opportunity.terms]
        + opportunity.requirements.map { $0.metric.title }
    }
    .joined(separator: " ")
    .lowercased()
    for forbidden in ["actual quality", "overclaim", "drift", "verification", "seed", "probability", "deterministic baseline"] {
      XCTAssertFalse(text.contains(forbidden), "Funding Board leaked \(forbidden)")
    }
  }

  func testFundingBoardPresentationShowsDeadlineResultAndNextAction() throws {
    let snapshot = FundingBoardSnapshot(
      revenue: 500,
      trust: 68,
      momentum: 18,
      coverage: 0,
      venture: 1,
      evidenceCount: 0,
      careerSprint: 2,
      attentionRemaining: 2
    )
    let opportunity = try XCTUnwrap(FundingBoardEngine.presentations(
      snapshot: snapshot,
      applications: []
    ).first(where: { $0.id == "pioneer-ai-grant" }))
    XCTAssertEqual(opportunity.deadlineRemainingLabel, "Deadline: 2 sprints")
    XCTAssertEqual(opportunity.status, .eligible)
    XCTAssertEqual(opportunity.nextAction, "Submit the application.")
    XCTAssertNil(opportunity.resultLabel)
  }

  func testFundingBoardPresentationShowsActiveMilestoneProgressAndConsequence() throws {
    let application = FundingApplicationRecord(
      opportunityID: "founder-conviction-round",
      status: .resolved,
      appliedCareerSprint: 6,
      resolvedCareerSprint: 7,
      outcome: .funded,
      outcomeReason: "Every visible requirement remained met.",
      milestoneObligation: FundingMilestoneObligation(
        metric: .revenue,
        target: 6_000,
        createdCareerSprint: 7,
        dueCareerSprint: 11,
        missedTrustConsequence: 6,
        status: .active,
        resolvedCareerSprint: nil
      )
    )
    let snapshot = FundingBoardSnapshot(
      revenue: 3_400,
      trust: 72,
      momentum: 45,
      coverage: 10,
      venture: 1,
      evidenceCount: 3,
      careerSprint: 8,
      attentionRemaining: 2
    )
    let round = try XCTUnwrap(FundingBoardEngine.presentations(
      snapshot: snapshot,
      applications: [application]
    ).first(where: { $0.id == application.opportunityID }))
    XCTAssertEqual(round.status, .funded)
    XCTAssertEqual(round.milestoneProgressLabel, "$3,400 of $6,000")
    XCTAssertEqual(round.milestoneDeadlineLabel, "3 sprints remaining")
    XCTAssertEqual(round.nextAction, "Track the active investor milestone.")
    XCTAssertEqual(round.application?.milestoneObligation?.missedTrustConsequence, 6)
  }

  func testRearGarageDoorIsDiscoverableAtNeutralFreeLookOnIPhoneAndIPad() {
    let camera = FounderEnvironmentCameraState(mode: .freeLook)
    for size in [CGSize(width: 402, height: 874), CGSize(width: 1_024, height: 1_366)] {
      let door = FounderGarageDoorLayout(viewportSize: size)
      XCTAssertTrue(door.isVisible(camera: camera))
      XCTAssertGreaterThanOrEqual(door.visibleWidthRatio(camera: camera), 0.30)
    }
  }

  func testRearGarageDoorDominatesNeutralFreeLookOnIPhoneAndIPad() {
    let camera = FounderEnvironmentCameraState(mode: .freeLook)
    for size in [CGSize(width: 402, height: 874), CGSize(width: 1_024, height: 1_366)] {
      let door = FounderGarageDoorLayout(viewportSize: size)
      XCTAssertTrue(door.isVisible(camera: camera))
      XCTAssertGreaterThanOrEqual(door.visibleWidthRatio(camera: camera), 0.72)
      XCTAssertGreaterThan(door.frame(camera: camera).width, size.width * 0.70)
    }
  }

  func testUpperWallHierarchyKeepsFanBetweenFounderIdentityAndDoorSign() {
    let camera = FounderEnvironmentCameraState(mode: .freeLook)
    for size in [
      CGSize(width: 390, height: 844),
      CGSize(width: 440, height: 956),
      CGSize(width: 820, height: 1_180)
    ] {
      let layout = FounderEnvironmentLayout(viewportSize: size)
      let fanScale = layout.depthScale(for: .mainVentilationFan) * layout.scale
      let fanCenter = layout.viewportPosition(for: .mainVentilationFan, camera: camera, layer: .background)
      let fanFrame = CGRect(
        x: fanCenter.x - 64 * fanScale,
        y: fanCenter.y - 71 * fanScale,
        width: 128 * fanScale,
        height: 142 * fanScale
      )
      let doorCenter = layout.viewportPosition(for: .rearGarageDoor, camera: camera, layer: .background)
      let doorRenderScale = layout.depthScale(for: .rearGarageDoor) * layout.scale * 1.35
      let doorSignCenterY = doorCenter.y + FounderGarageDoorLayout.signVerticalOffset * doorRenderScale

      XCTAssertLessThan(layout.founderDeskHeadingY + 16, fanFrame.minY)
      XCTAssertLessThan(fanFrame.maxY + 6, doorSignCenterY)
      XCTAssertEqual(layout.anchors[.founderMonitor]?.x, 680)
    }
  }

  func testGarageDoorRenderAndAccessibilityGeometryRemainIdentical() {
    let door = FounderGarageDoorLayout(viewportSize: CGSize(width: 402, height: 874))
    for camera in [
      FounderEnvironmentCameraState(mode: .freeLook),
      FounderEnvironmentCameraState(horizontalLook: 1, verticalLook: -0.18, mode: .freeLook)
    ] {
      XCTAssertEqual(door.accessibilityFrame(camera: camera), door.frame(camera: camera))
    }
  }

  func testGarageDoorLightingUsesCanonicalMorningAndNightPeriods() {
    let morning = garageMotion(period: .morning)
    let night = garageMotion(period: .night)
    XCTAssertEqual(morning.lighting.operatingPeriod, .morning)
    XCTAssertEqual(night.lighting.operatingPeriod, .night)
    XCTAssertGreaterThan(morning.lighting.garageDoorPanelBrightness, night.lighting.garageDoorPanelBrightness)
    XCTAssertGreaterThan(night.lighting.garageDoorExteriorLeakIntensity, morning.lighting.garageDoorExteriorLeakIntensity)
  }

  func testFounderComputerRoundTripPreservesGarageDoorWorldState() {
    var state = FounderDeskNavigationState()
    state.setLook(horizontal: 1, vertical: -0.12, reduceMotion: false)
    let door = FounderGarageDoorLayout(viewportSize: CGSize(width: 402, height: 874))
    let before = door.frame(camera: state.camera)
    XCTAssertEqual(state.select(.computer), .computerFocused)
    state.completeCameraTransition(to: .computerFocused)
    XCTAssertEqual(state.lookOut(), .freeLook)
    state.completeCameraTransition(to: .freeLook)
    XCTAssertEqual(door.frame(camera: state.camera), before)
  }

  func testAccessibilityTextUsesReadableListLayout() {
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: false, accessibilityText: true, height: 800), .accessibleList)
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: true, accessibilityText: true, height: 1_100), .accessibleList)
  }

  func testCompactHeightUsesReadableListLayout() {
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: false, accessibilityText: false, height: 520), .accessibleList)
  }

  func testFormerMoreInventoryIsCompleteAndUnique() {
    XCTAssertEqual(CompanyServerDestination.allCases.count, 9)
    XCTAssertEqual(Set(CompanyServerDestination.allCases.map(\.id)).count, 9)
    XCTAssertEqual(Set(CompanyServerDestination.allCases.map(\.title)).count, 9)
  }

  func testFormerMoreInventoryRetainsEveryCanonicalDestination() {
    XCTAssertEqual(Set(CompanyServerDestination.allCases), Set([
      .evidence, .agentOperations, .achievements, .headquarters, .companyStory,
      .soloPro, .settings, .howToPlay, .restartCareer
    ]))
  }

  func testEvidenceAndAgentOperationsHandoffToCanonicalComputerTargets() {
    XCTAssertEqual(FounderComputerWorkspaceTarget.evidence.rawValue, "evidence")
    XCTAssertEqual(FounderComputerWorkspaceTarget.operations.rawValue, "viewport")
  }

  func testFounderComputerPreviewUsesOnlyVisibleLifecycleCounts() {
    let preview = FounderDeskPreviewPolicy.preview(for: .computer, input: input(
      visibleWorkCount: 2,
      visibleReviewCount: 0,
      canCommit: false
    ))
    XCTAssertEqual(preview.secondary, "2 active workstations")
    XCTAssertNil(preview.signal)
    assertNoHiddenTruth(in: preview)
  }

  func testFounderReviewSignalIsLifecycleDriven() {
    let preview = FounderDeskPreviewPolicy.preview(for: .computer, input: input(visibleReviewCount: 2))
    XCTAssertEqual(preview.secondary, "2 awaiting Founder review")
    XCTAssertEqual(preview.signal, "Review tray ready")
    assertNoHiddenTruth(in: preview)
  }

  func testSprintReadySignalDoesNotClaimOutcome() {
    let preview = FounderDeskPreviewPolicy.preview(for: .computer, input: input(canCommit: true))
    XCTAssertEqual(preview.signal, "Sprint ready")
    assertNoHiddenTruth(in: preview)
  }

  func testPhoneWithoutCanonicalHeadlineCreatesNoAlert() {
    let preview = FounderDeskPreviewPolicy.preview(for: .phone, input: input(latestPublishedHeadline: nil))
    XCTAssertEqual(preview.primary, "No new published stories")
    XCTAssertNil(preview.signal)
    assertNoHiddenTruth(in: preview)
  }

  func testPhoneSignalUsesCanonicalPublishedHeadline() {
    let preview = FounderDeskPreviewPolicy.preview(for: .phone, input: input(latestPublishedHeadline: "A published market story"))
    XCTAssertEqual(preview.primary, "A published market story")
    XCTAssertEqual(preview.signal, "Published update")
    XCTAssertTrue(preview.accessibilityLabel.contains("A published market story"))
  }

  func testTabletPreviewUsesVisibleObjectiveWithoutConsequences() {
    let preview = FounderDeskPreviewPolicy.preview(for: .tablet, input: input(
      ventureObjective: "Ship the visible prototype",
      ventureObjectiveComplete: false
    ))
    XCTAssertEqual(preview.primary, "Ship the visible prototype")
    XCTAssertNil(preview.signal)
    assertNoHiddenTruth(in: preview)
  }

  func testTabletMilestoneSignalRequiresVisibleCompletion() {
    let preview = FounderDeskPreviewPolicy.preview(for: .tablet, input: input(ventureObjectiveComplete: true))
    XCTAssertEqual(preview.signal, "Objective milestone")
  }

  func testServerSignalReflectsOwnedFacilityState() {
    let startup = FounderDeskPreviewPolicy.preview(for: .server, input: input(ownedFacilityCount: 1))
    let progressed = FounderDeskPreviewPolicy.preview(for: .server, input: input(ownedFacilityCount: 2))
    XCTAssertNil(startup.signal)
    XCTAssertEqual(progressed.signal, "Facilities available")
    assertNoHiddenTruth(in: progressed)
  }

  func testFacilityVariationKeepsStableDeviceIdentity() {
    let garage = FounderDeskPreviewPolicy.preview(for: .server, input: input(facilityName: "Founder Garage"))
    let office = FounderDeskPreviewPolicy.preview(for: .server, input: input(facilityName: "Office Suite"))
    XCTAssertEqual(garage.title, office.title)
    XCTAssertNotEqual(garage.primary, office.primary)
    XCTAssertEqual(FounderDeskDevice.server.title, "Company Server")
  }

  func testDeviceAccessibilityLabelsAreNamedAndTruthSafe() {
    for device in FounderDeskDevice.allCases {
      let preview = FounderDeskPreviewPolicy.preview(for: device, input: input())
      XCTAssertTrue(preview.accessibilityLabel.localizedCaseInsensitiveContains(device.title.components(separatedBy: " ").last ?? device.title))
      assertNoHiddenTruth(in: preview)
    }
  }

  func testStrategyBoardInitiativesHaveStableUniqueRoutes() {
    let initiatives = FounderStrategicInitiativeDefinition.all
    XCTAssertEqual(Set(initiatives.map(\.id)).count, initiatives.count)
    XCTAssertEqual(initiatives.map(\.category), [.productLaunch, .fundraising, .competitiveMove])

    let launch = initiatives[0]
    XCTAssertTrue(launch.executionSupported)
    XCTAssertEqual(launch.executionRoute, .commitSprint)
    XCTAssertEqual(Set(launch.preparation.map(\.id)).count, launch.preparation.count)
    XCTAssertEqual(Set(launch.preparation.map(\.track)), Set(FounderStrategyTrack.allCases))
    XCTAssertTrue(launch.preparation.filter(\.blocksCommit).allSatisfy { $0.route == .agentOperations || $0.route == .evidenceLedger })
  }

  func testStrategyBoardSixFixturesCoverReadinessStates() {
    let launch = FounderStrategicInitiativeDefinition.all[0]
    let expected: [FounderStrategyBoardFixture: FounderInitiativeReadiness] = [
      .empty: .notReady,
      .partial: .needsReview,
      .evidenceBlocker: .needsReview,
      .technicalBlocker: .blocked,
      .ready: .ready,
      .publicRivalRisk: .ready
    ]

    XCTAssertEqual(FounderStrategyBoardFixture.allCases.count, 6)
    for fixture in FounderStrategyBoardFixture.allCases {
      let projection = FounderStrategyBoardPolicy.project(launch, snapshot: fixture.snapshot)
      XCTAssertEqual(projection.readiness, expected[fixture], "Unexpected readiness for \(fixture.rawValue)")
      XCTAssertEqual(projection.commitEligible, fixture == .ready || fixture == .publicRivalRisk)
    }
  }

  func testStrategyBoardEvidenceAttentionAndTechnicalBlockersStayCanonical() {
    let launch = FounderStrategicInitiativeDefinition.all[0]
    let evidence = FounderStrategyBoardPolicy.project(launch, snapshot: FounderStrategyBoardFixture.evidenceBlocker.snapshot)
    let technical = FounderStrategyBoardPolicy.project(launch, snapshot: FounderStrategyBoardFixture.technicalBlocker.snapshot)

    XCTAssertEqual(evidence.evidenceBlockerCount, 1)
    XCTAssertTrue(evidence.blockers.contains { $0.contains("Founder Attention insufficient") })
    XCTAssertTrue(technical.blockers.contains { $0.contains("canonical resolution") || $0.contains("resolve Stacks") })
    XCTAssertFalse(evidence.commitEligible)
    XCTAssertFalse(technical.commitEligible)
  }

  func testStrategyBoardUsesPublicRivalClaimsWithoutHiddenTruth() {
    let launch = FounderStrategicInitiativeDefinition.all[0]
    let projection = FounderStrategyBoardPolicy.project(launch, snapshot: FounderStrategyBoardFixture.publicRivalRisk.snapshot)
    let visibleText = (projection.risks + projection.blockers + projection.preparation.map(\.detail)).joined(separator: " ").lowercased()

    XCTAssertTrue(visibleText.contains("publicly claims 90 momentum"))
    for forbidden in ["actual quality", "correctness", "overclaim", "drift", "hidden", "rng", "future outcome"] {
      XCTAssertFalse(visibleText.contains(forbidden), "Strategy projection leaked \(forbidden)")
    }
  }

  func testStrategyBoardCommitGateAllowsOneCanonicalExecutionPerPresentation() {
    var gate = FounderStrategyCommitGate()
    XCTAssertTrue(gate.claim(eligible: true, sprint: 2))
    XCTAssertFalse(gate.claim(eligible: true, sprint: 2))
    XCTAssertFalse(gate.claim(eligible: false, sprint: 3))
    XCTAssertEqual(gate.invocationCount, 3)
    XCTAssertEqual(gate.canonicalExecutionCount, 1)
    XCTAssertEqual(gate.duplicatePreventionCount, 1)
    XCTAssertEqual(gate.committedSprint, 2)
  }

  func testStrategyBoardProjectionIsPureAndKeepsCurrentSaveVersion() {
    let snapshot = FounderStrategyBoardFixture.ready.snapshot
    let launch = FounderStrategicInitiativeDefinition.all[0]
    let first = FounderStrategyBoardPolicy.project(launch, snapshot: snapshot)
    let second = FounderStrategyBoardPolicy.project(launch, snapshot: snapshot)

    XCTAssertEqual(first, second)
    XCTAssertEqual(snapshot, FounderStrategyBoardFixture.ready.snapshot)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  @MainActor
  func testStrategyBoardLiveProjectionCannotMutateGameStoreOrAtlantisSignals() {
    let store = GameStore()
    let stats = store.stats
    let rng = store.randomNumberGenerator
    let tasks = store.tasks
    let atlantis = AtlantisWorldSignalSnapshot.read(store)

    let snapshot = FounderStrategyBoardSnapshot.read(store)
    _ = FounderStrategyBoardPolicy.project(FounderStrategicInitiativeDefinition.all[0], snapshot: snapshot)

    XCTAssertEqual(store.stats, stats)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.tasks, tasks)
    XCTAssertEqual(AtlantisWorldSignalSnapshot.read(store), atlantis)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testStrategyBoardUnsupportedInitiativesRemainPlanningOnly() {
    for initiative in FounderStrategicInitiativeDefinition.all.dropFirst() {
      let projection = FounderStrategyBoardPolicy.project(initiative, snapshot: FounderStrategyBoardFixture.publicRivalRisk.snapshot)
      XCTAssertFalse(projection.commitEligible)
      XCTAssertEqual(projection.readiness, .notReady)
      XCTAssertTrue(projection.blockers.contains { $0.contains("Planning projection only") })
      XCTAssertEqual(projection.canonicalRouteCount, 1)
    }
  }

  private func input(
    visibleWorkCount: Int = 0,
    visibleReviewCount: Int = 0,
    canCommit: Bool = false,
    latestPublishedHeadline: String? = nil,
    ventureObjective: String = "Complete the visible objective",
    ventureObjectiveComplete: Bool = false,
    facilityName: String = "Founder Garage",
    ownedFacilityCount: Int = 1
  ) -> FounderDeskPreviewInput {
    FounderDeskPreviewInput(
      sprint: 3,
      venture: 1,
      sprintPhase: visibleReviewCount > 0 ? .reviewAndResolve : .chooseCommitments,
      visibleWorkCount: visibleWorkCount,
      visibleReviewCount: visibleReviewCount,
      evidenceCount: 2,
      canCommit: canCommit,
      latestPublishedHeadline: latestPublishedHeadline,
      marketRank: 4,
      ventureObjective: ventureObjective,
      ventureObjectiveComplete: ventureObjectiveComplete,
      facilityName: facilityName,
      achievementCount: 3,
      ownedFacilityCount: ownedFacilityCount
    )
  }

  private func focusedComputerState() -> FounderDeskNavigationState {
    var state = FounderDeskNavigationState()
    _ = state.select(.computer)
    state.completeCameraTransition(to: .computerFocused)
    return state
  }

  private func garageMotion(period: OperatingCalendar.Period) -> FounderGarageMotionPresentation {
    let environment = FounderEnvironmentProjection(
      facility: .founderGarage,
      atmosphere: .derive(stats: FounderStats(), facility: .founderGarage, venture: 1),
      infrastructure: [],
      agents: [],
      period: period
    )
    return FounderGarageMotionPresentation.derive(
      environment: environment,
      camera: FounderEnvironmentCameraState(mode: .freeLook),
      reduceMotion: false,
      sceneActive: true
    )
  }

  private func assertNoHiddenTruth(in preview: FounderDeskPreview, file: StaticString = #filePath, line: UInt = #line) {
    let text = [preview.title, preview.primary, preview.secondary, preview.signal, preview.accessibilityLabel]
      .compactMap { $0 }
      .joined(separator: " ")
      .lowercased()
    for forbidden in ["actual quality", "correctness", "overclaim", "drift", "hidden risk", "evidence complete", "verified outcome"] {
      XCTAssertFalse(text.contains(forbidden), "Desk chrome leaked \(forbidden)", file: file, line: line)
    }
  }

  private func devicePresentation(
    device: FounderDeskDevice,
    state: FounderPhysicalDeviceState,
    safePending: Bool = false,
    visibleOperatingIntensity: Double = 0,
    reduceMotion: Bool = false,
    visible: Bool = true
  ) -> FounderDevicePresentation {
    FounderDevicePresentation.derive(
      device: device,
      state: state,
      safePending: safePending,
      visibleOperatingIntensity: visibleOperatingIntensity,
      reduceMotion: reduceMotion,
      sceneActive: true,
      visible: visible
    )
  }

  private func operationalMotion(
    stats: FounderStats = FounderStats(),
    agents: [LivingAgentProjection] = [],
    publicEvents: [PublicMediaEvent] = [],
    reduceMotion: Bool = false
  ) -> FounderGarageMotionPresentation {
    FounderGarageMotionPresentation.derive(
      environment: FounderEnvironmentProjection(
        facility: .founderGarage,
        atmosphere: .derive(stats: stats, facility: .founderGarage, venture: 1),
        infrastructure: [],
        agents: agents,
        signalTVEvents: publicEvents
      ),
      camera: FounderEnvironmentCameraState(mode: .freeLook),
      reduceMotion: reduceMotion,
      sceneActive: true
    )
  }

  private func visibleAgent(
    activity: LivingAgentActivity,
    needsFounderAttention: Bool = false
  ) -> LivingAgentProjection {
    LivingAgentProjection(
      agentID: "stacks",
      name: "Stacks",
      initials: "ST",
      role: .engineering,
      taskID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
      taskTitle: "Visible work",
      activity: activity,
      conditions: [],
      emphasis: needsFounderAttention ? .founderAttention : .normal,
      progress: activity == .working ? 0.5 : 1,
      reviewRevealStep: 0,
      stressLabel: "Steady",
      trustLabel: "Trusted",
      level: 1,
      needsFounderAttention: needsFounderAttention,
      isResting: false
    )
  }
}

@MainActor
final class AgentOperationsEconomyTests: XCTestCase {
  func testBalancedDefaultsAreAgentSpecificBoundedAndLeaveHeadroom() {
    let state = AgentOperationsState.balanced
    for agentID in ["aurora", "stacks", "brio"] {
      let profile = state.profile(for: agentID)
      XCTAssertEqual(profile.capacity, 100)
      XCTAssertEqual(profile.allocated, 75)
      XCTAssertEqual(profile.headroom, 25)
      XCTAssertEqual(profile.autonomy, .guided)
      XCTAssertEqual(Set(profile.allocations.keys), Set(AgentOperationalDomain.domains(for: agentID)))
    }
    XCTAssertNotEqual(Set(state.profile(for: "aurora").allocations.keys), Set(state.profile(for: "stacks").allocations.keys))
  }

  func testAllocationRejectsNegativeWrongOwnerAndCapacityOverflow() {
    var profile = AgentOperationsProfile.balanced(agentID: "stacks")
    XCTAssertFalse(profile.setAllocation(-5, for: .reliability))
    XCTAssertFalse(profile.setAllocation(20, for: .marketResearch))
    XCTAssertFalse(profile.setAllocation(60, for: .productDevelopment))
    XCTAssertEqual(profile.allocated, 75)
    XCTAssertTrue(profile.setAllocation(45, for: .productDevelopment))
    XCTAssertEqual(profile.allocated, 95)
  }

  func testAssignmentLoadProducesDeterministicOverloadWithoutStoredWorkloadTruth() {
    let balanced = AgentOperationsFixture.balanced.state.profile(for: "stacks")
    XCTAssertEqual(AgentOperationsPolicy.workload(profile: balanced, assignmentUrgency: nil), 75)
    XCTAssertEqual(AgentOperationsPolicy.workload(profile: balanced, assignmentUrgency: .critical), 100)
    let overloaded = AgentOperationsFixture.stacksOverloaded.state.profile(for: "stacks")
    let workload = AgentOperationsPolicy.workload(profile: overloaded, assignmentUrgency: .critical)
    XCTAssertEqual(workload, 125)
    XCTAssertEqual(AgentOperationalWorkloadBand.classify(workload), .critical)
  }

  func testPresetsOnlyRearrangeAllocationAndPreserveHeadroom() {
    var profile = AgentOperationsProfile.balanced(agentID: "aurora")
    profile.applyPreset(.primary)
    XCTAssertEqual(profile.allocation(for: .marketResearch), 45)
    XCTAssertEqual(profile.allocated, 80)
    XCTAssertEqual(profile.headroom, 20)
    profile.applyPreset(.safeguard)
    XCTAssertEqual(profile.allocation(for: .evidenceVerification), 35)
    XCTAssertEqual(profile.allocated, 80)
  }

  func testAgentSpecificAllocationChangesOnlyRelevantAssignmentInputs() {
    let agents = ContentLibrary.initialAgents
    let aurora = agents.first { $0.id == "aurora" }!
    let stacks = agents.first { $0.id == "stacks" }!
    let brio = agents.first { $0.id == "brio" }!
    let research = SoloTask(title: "Market study", detail: "", role: .research, category: .research, impact: .trust(1))
    let engineering = SoloTask(title: "Harden release", detail: "", role: .engineering, category: .operations, impact: .trust(1))
    let campaign = SoloTask(title: "Campaign", detail: "", role: .marketing, category: .sales, impact: .momentum(1))
    let auroraAdjusted = AgentOperationsPolicy.assignmentAgent(aurora, profile: AgentOperationsFixture.auroraVerification.state.profile(for: "aurora"), task: research)
    let stacksAdjusted = AgentOperationsPolicy.assignmentAgent(stacks, profile: AgentOperationsFixture.reliabilityNeglected.state.profile(for: "stacks"), task: engineering)
    let brioAdjusted = AgentOperationsPolicy.assignmentAgent(brio, profile: AgentOperationsFixture.brioAcquisitionHeavy.state.profile(for: "brio"), task: campaign)
    XCTAssertGreaterThan(auroraAdjusted.calibration, aurora.calibration)
    XCTAssertNotEqual(stacksAdjusted.reliability, stacks.reliability)
    XCTAssertGreaterThan(brioAdjusted.reliability, brio.reliability)
  }

  func testAutonomyCreatesCalibrationThroughputAndRiskTradeoffs() {
    let agent = ContentLibrary.initialAgents.first { $0.id == "aurora" }!
    let task = SoloTask(title: "Research", detail: "", role: .research, impact: .trust(1))
    var controlled = AgentOperationsProfile.balanced(agentID: "aurora"); controlled.autonomy = .founderControlled
    var autonomous = controlled; autonomous.autonomy = .autonomous
    let founderInput = AgentOperationsPolicy.assignmentAgent(agent, profile: controlled, task: task)
    let autonomousInput = AgentOperationsPolicy.assignmentAgent(agent, profile: autonomous, task: task)
    XCTAssertGreaterThan(founderInput.calibration, autonomousInput.calibration)
    XCTAssertLessThan(founderInput.reliability, autonomousInput.reliability)
  }

  func testAutonomousDecisionIsDeterministicAndResolvesOnce() {
    let store = configuredStore(seed: 19_101)
    let request = store.agentOperationalDecisionRequest(for: "stacks")
    XCTAssertNotNil(request)
    let attention = store.attentionRemaining
    XCTAssertTrue(store.resolveAgentOperationalDecision(agentID: "stacks", choice: .letAgentDecide))
    XCTAssertEqual(store.attentionRemaining, attention)
    XCTAssertEqual(store.agentOperations.profile(for: "stacks").autonomousDecisionCount, 1)
    XCTAssertFalse(store.resolveAgentOperationalDecision(agentID: "stacks", choice: .letAgentDecide))
    XCTAssertEqual(store.agentOperations.recentDecisions.filter { $0.id == request?.id }.count, 1)
    store.resetCareer()
  }

  func testMicromanagementPenaltyIsContextual() {
    let high = configuredStore(seed: 19_102)
    high.installAgentOperationsForTesting(AgentOperationsFixture.highCalibrationFounderOverride.state, agents: AgentOperationsFixture.highCalibrationFounderOverride.agents)
    XCTAssertTrue(high.resolveAgentOperationalDecision(agentID: "aurora", choice: .verifyEvidence))
    XCTAssertEqual(high.agentOperations.profile(for: "aurora").micromanagementPenaltyActivations, 1)
    XCTAssertEqual(high.agentOperations.profile(for: "aurora").pendingTrustDelta, -2)
    high.resetCareer()

    let low = configuredStore(seed: 19_103)
    low.installAgentOperationsForTesting(AgentOperationsFixture.lowCalibrationIntervention.state, agents: AgentOperationsFixture.lowCalibrationIntervention.agents)
    XCTAssertTrue(low.resolveAgentOperationalDecision(agentID: "aurora", choice: .verifyEvidence))
    XCTAssertEqual(low.agentOperations.profile(for: "aurora").micromanagementPenaltyActivations, 0)
    XCTAssertGreaterThan(low.agentOperations.profile(for: "aurora").pendingCalibrationDelta, 0)
    low.resetCareer()
  }

  func testSprintOutcomesUseExistingTraitsAndRewardHeadroom() {
    let stacks = ContentLibrary.initialAgents.first { $0.id == "stacks" }!
    let healthy = AgentOperationsPolicy.sprintOutcome(agent: stacks, profile: AgentOperationsFixture.balanced.state.profile(for: "stacks"), assignmentUrgency: .normal)
    let overloaded = AgentOperationsPolicy.sprintOutcome(agent: stacks, profile: AgentOperationsFixture.stacksOverloaded.state.profile(for: "stacks"), assignmentUrgency: .critical)
    let neglected = AgentOperationsPolicy.sprintOutcome(agent: stacks, profile: AgentOperationsFixture.reliabilityNeglected.state.profile(for: "stacks"), assignmentUrgency: .normal)
    XCTAssertLessThan(healthy.stressDelta, overloaded.stressDelta)
    XCTAssertLessThan(overloaded.reliabilityDelta, healthy.reliabilityDelta)
    XCTAssertGreaterThan(neglected.driftDelta, healthy.driftDelta)
  }

  func testOperationalChoicesPersistThroughCanonicalVersionTwentySave() throws {
    let source = configuredStore(seed: 19_104)
    XCTAssertTrue(source.setAgentOperationsAllocation(agentID: "stacks", domain: .reliability, value: 30))
    XCTAssertTrue(source.setAgentOperationalAutonomy(agentID: "brio", autonomy: .autonomous))
    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(restored.agentOperations.profile(for: "stacks").allocation(for: .reliability), 30)
    XCTAssertEqual(restored.agentOperations.profile(for: "brio").autonomy, .autonomous)
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: data).version, 20)
    restored.resetCareer()
  }

  func testLegacyVersionNineteenSaveMigratesToBalancedOperations() throws {
    let source = configuredStore(seed: 19_105)
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var career = try XCTUnwrap(root["career"] as? [String: Any])
    career.removeValue(forKey: "agentOperations")
    root["career"] = career
    root["version"] = 19
    let legacy = try JSONSerialization.data(withJSONObject: root)
    source.resetCareer()
    UserDefaults.standard.set(legacy, forKey: GameStore.v19SaveKey)
    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(restored.agentOperations, .balanced)
    let migrated = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: migrated).version, 20)
    restored.resetCareer()
  }

  func testProductLaunchConsumesOperationsWithoutBypassingPreparation() {
    let balanced = AgentOperationsFixture.balanced.state.profile(for: "stacks")
    let neglected = AgentOperationsFixture.reliabilityNeglected.state.profile(for: "stacks")
    let balancedAdjustment = AgentOperationsPolicy.productLaunchQualityAdjustment(agentID: "stacks", profile: balanced, assignmentUrgency: .normal)
    let neglectedAdjustment = AgentOperationsPolicy.productLaunchQualityAdjustment(agentID: "stacks", profile: neglected, assignmentUrgency: .normal)
    XCTAssertGreaterThan(balancedAdjustment, neglectedAdjustment)
    XCTAssertTrue(GameStore().productLaunchOperation == nil)
  }

  func testStrategyBoardAddsOnlyFounderKnownOperationalRisk() {
    let store = configuredStore(seed: 19_106)
    store.installAgentOperationsForTesting(AgentOperationsFixture.reliabilityNeglected.state)
    let snapshot = FounderStrategyBoardSnapshot.read(store)
    XCTAssertTrue(snapshot.operationalRisks.contains { $0.contains("reliability allocation") })
    let description = snapshot.operationalRisks.joined(separator: " ").lowercased()
    XCTAssertFalse(description.contains("drift"))
    XCTAssertFalse(description.contains("actual quality"))
    store.resetCareer()
  }

  func testHiddenDriftDoesNotEnterOperationsPlayerSurfaceOrRequest() throws {
    let agent = AgentOperationsFixture.hiddenDrift.agents.first { $0.id == "stacks" }!
    let request = AgentOperationsPolicy.request(agent: agent, profile: AgentOperationsFixture.hiddenDrift.state.profile(for: "stacks"), venture: 1, sprint: 1)
    XCTAssertFalse(String(describing: request).lowercased().contains("drift"))
    let source = try sourceText("App/AIOperationsFloor.swift")
    let operationsSurface = source.components(separatedBy: "private var operationsSurface").dropFirst().first?.components(separatedBy: "private var primaryAction").first ?? ""
    XCTAssertFalse(operationsSurface.contains("canonicalAgent.drift"))
    XCTAssertFalse(operationsSurface.lowercased().contains("actual quality"))
  }

  func testOperationsResolutionHasNoAtlantisOrRuntimeNetworkAuthority() throws {
    let source = try sourceText("App/GameStore.swift")
    let boundary = source.components(separatedBy: "private func resolveAgentOperationsAtSprintBoundary()").dropFirst().first?.components(separatedBy: "private func completeAmbitionIfEligible").first ?? ""
    XCTAssertFalse(boundary.contains("Atlantis"))
    XCTAssertFalse(boundary.contains("URLSession"))
    XCTAssertFalse(boundary.contains(".random("))
  }

  private func configuredStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    return store
  }

  private func sourceText(_ relativePath: String) throws -> String {
    let repository = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return try String(contentsOf: repository.appendingPathComponent(relativePath), encoding: .utf8)
  }
}

@MainActor
final class ProductLaunchOperationTests: XCTestCase {
  func testBeginLaunchCapturesPreparedSprintCommitsOnceAndRejectsDuplicate() throws {
    let store = preparedStoreForLaunch(stacksState: .evidenceIncomplete)
    let sourceSprint = store.sprint
    let expectedTrust = store.stats.trust
    XCTAssertTrue(store.beginProductLaunch(), store.alertMessage ?? "")
    let operation = try XCTUnwrap(store.productLaunchOperation)
    XCTAssertEqual(operation.state, .launchCheck)
    XCTAssertEqual(operation.preparation.sprint, sourceSprint)
    XCTAssertEqual(operation.preparation.trust, expectedTrust)
    XCTAssertEqual(operation.preparation.reviewedEvidenceCount, 3)
    XCTAssertEqual(operation.preparation.stacks.visibleQuality, 88)
    XCTAssertFalse(operation.preparation.stacks.founderVerified)
    XCTAssertEqual(operation.resolutionTruth.stacksQuality, 46)
    XCTAssertEqual(store.sprint, sourceSprint + 1)

    XCTAssertFalse(store.beginProductLaunch())
    XCTAssertEqual(store.sprint, sourceSprint + 1)
    XCTAssertEqual(store.productLaunchOperation?.id, operation.id)
  }

  func testLifecycleRequiresDecisionsAndPreventsExecutionRollback() {
    let store = GameStore()
    store.installProductLaunchOperationForTesting(ProductLaunchFixture.strongPreparation.operation)

    XCTAssertFalse(store.executeProductLaunch())
    XCTAssertTrue(store.advanceProductLaunchToDecisions())
    XCTAssertFalse(store.executeProductLaunch())
    XCTAssertTrue(store.selectProductLaunchReleasePosture(.shipNow))
    XCTAssertTrue(store.selectProductLaunchPublicPosture(.evidenceLed))
    XCTAssertTrue(store.executeProductLaunch())
    XCTAssertEqual(store.productLaunchOperation?.state, .executing)
    XCTAssertFalse(store.advanceProductLaunchToDecisions())
    XCTAssertFalse(store.selectProductLaunchPublicPosture(.bold))
  }

  func testResolutionIsDeterministicForSameSnapshotSeedAndDecisions() throws {
    var first = ProductLaunchFixture.strongPreparation.operation
    first.releasePosture = .shipNow
    first.publicPosture = .bold
    let second = first
    XCTAssertEqual(try XCTUnwrap(ProductLaunchResolutionPolicy.resolve(first)), ProductLaunchResolutionPolicy.resolve(second))
  }

  func testAgentPreparationAffectsDistinctDimensions() throws {
    let strong = try resolve(.strongPreparation)
    let technicalRisk = try resolve(.technicalRisk)
    let marketHeavy = try resolve(.strongMarketWeakProduct)
    let productHeavy = try resolve(.strongProductWeakGrowth)

    XCTAssertLessThan(technicalRisk.technicalScore, strong.technicalScore)
    XCTAssertGreaterThan(marketHeavy.marketScore, marketHeavy.technicalScore)
    XCTAssertGreaterThan(productHeavy.technicalScore, productHeavy.marketScore)
  }

  func testWeakEvidenceMakesBoldPublicPostureRiskier() throws {
    let strong = try resolve(.strongPreparation, publicPosture: .bold)
    let weak = try resolve(.weakEvidence, publicPosture: .bold)
    XCTAssertLessThan(weak.publicScore, strong.publicScore)
    XCTAssertLessThan(weak.effects.trust, strong.effects.trust)
  }

  func testReleaseAndPublicPosturesMateriallyChangeResolution() throws {
    let ship = try resolve(.technicalRisk, release: .shipNow, publicPosture: .bold)
    let conservative = try resolve(.technicalRisk, release: .conservative, publicPosture: .evidenceLed)
    let quiet = try resolve(.technicalRisk, release: .conservative, publicPosture: .quiet)
    XCTAssertGreaterThan(conservative.technicalScore, ship.technicalScore)
    XCTAssertNotEqual(ship.marketScore, conservative.marketScore)
    XCTAssertNotEqual(conservative.coverageDelta, quiet.coverageDelta)
  }

  func testHiddenVarianceDoesNotEnterFounderSnapshotOrExplanation() throws {
    let operation = ProductLaunchFixture.hiddenOverclaim.operation
    XCTAssertEqual(operation.preparation.stacks.visibleQuality, 88)
    XCTAssertFalse(operation.preparation.stacks.founderVerified)
    let visible = String(describing: operation.preparation).lowercased()
    for forbidden in ["actualquality", "overclaim", "drift", "rng", "future"] {
      XCTAssertFalse(visible.contains(forbidden))
    }
    let result = try resolve(.hiddenOverclaim)
    XCTAssertTrue(result.unresolvedCause)
    let explanation = result.explanation.joined(separator: " ").lowercased()
    XCTAssertTrue(explanation.contains("not yet fully understood"))
    XCTAssertFalse(explanation.contains("overclaim"))
    XCTAssertFalse(explanation.contains("actual quality"))
  }

  func testCanonicalResolutionAppliesAllEffectsOnceAndPublishesOneEvent() throws {
    let store = GameStore()
    var operation = ProductLaunchFixture.duplicateResolution.operation
    operation.state = .founderDecision
    operation.releasePosture = .shipNow
    operation.publicPosture = .bold
    store.installProductLaunchOperationForTesting(operation)
    let before = store.stats

    XCTAssertTrue(store.executeProductLaunch())
    XCTAssertTrue(store.resolveProductLaunch())
    let resolvedStats = store.stats
    let result = try XCTUnwrap(store.productLaunchOperation?.result)
    XCTAssertEqual(resolvedStats.momentum, min(100, max(0, before.momentum + result.effects.momentum)))
    XCTAssertEqual(resolvedStats.trust, min(100, max(0, before.trust + result.effects.trust)))
    XCTAssertEqual(resolvedStats.coverage, min(100, max(-100, before.coverage + result.coverageDelta)))
    XCTAssertEqual(store.productLaunchOperation?.canonicalEffectApplicationCount, 1)

    XCTAssertFalse(store.resolveProductLaunch())
    XCTAssertEqual(store.stats, resolvedStats)
    XCTAssertEqual(store.productLaunchOperation?.canonicalEffectApplicationCount, 1)
    XCTAssertEqual(store.productLaunchOperation?.duplicateResolutionPreventionCount, 1)
    XCTAssertEqual(store.publicMediaEvents.filter { $0.id == "\(operation.id)-resolved" }.count, 1)
    XCTAssertTrue(store.finishProductLaunchPresentation())
    XCTAssertNil(store.productLaunchOperation)
    XCTAssertFalse(store.finishProductLaunchPresentation())
  }

  func testOperationRoundTripRecoversEveryInterruptedStage() throws {
    for state in [ProductLaunchOperationState.committed, .launchCheck, .founderDecision, .executing, .resolved] {
      var operation = ProductLaunchFixture.strongPreparation.operation
      operation.state = state
      operation.releasePosture = state == .committed || state == .launchCheck ? nil : .conservative
      operation.publicPosture = state == .committed || state == .launchCheck ? nil : .evidenceLed
      if state == .resolved { operation.result = ProductLaunchResolutionPolicy.resolve(operation) }
      let restored = try JSONDecoder().decode(ProductLaunchOperation.self, from: JSONEncoder().encode(operation))
      XCTAssertEqual(restored, operation)
    }
  }

  func testInterruptedOperationRecoversThroughCanonicalCareerSave() throws {
    let source = GameStore()
    source.resetCareer()
    defer { source.resetCareer() }
    source.startCareer(seed: 18_181)
    source.confirmVentureThesisIfNeeded()
    var interrupted = ProductLaunchFixture.technicalRisk.operation
    interrupted.state = .founderDecision
    interrupted.releasePosture = .conservative
    source.installProductLaunchOperationForTesting(interrupted, persist: true)

    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(restored.productLaunchOperation, interrupted)
    XCTAssertEqual(restored.productLaunchOperation?.state, .founderDecision)
    XCTAssertEqual(restored.productLaunchOperation?.releasePosture, .conservative)
  }

  func testAdditiveCareerSaveFieldKeepsCurrentVersionAndDecodesWhenMissing() throws {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 18_018)
    store.confirmVentureThesisIfNeeded()
    guard let data = UserDefaults.standard.data(forKey: GameStore.saveKey) else { return XCTFail("Missing baseline save") }
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var career = try XCTUnwrap(root["career"] as? [String: Any])
    career.removeValue(forKey: "productLaunchOperation")
    root["career"] = career
    let legacyCompatible = try JSONSerialization.data(withJSONObject: root)
    let decoded = try JSONDecoder().decode(SaveEnvelope.self, from: legacyCompatible)
    XCTAssertEqual(decoded.version, 20)
    XCTAssertNil(decoded.career.productLaunchOperation)
    store.resetCareer()
  }

  func testResolutionHasNoAtlantisAuthorityOrRuntimeRandomness() {
    let launchSource = try? String(contentsOfFile: "App/GameStore.swift", encoding: .utf8)
    XCTAssertFalse(launchSource?.contains("resolveProductLaunch") == false)
    let method = launchSource?.components(separatedBy: "func resolveProductLaunch()").dropFirst().first?.components(separatedBy: "private func captureProductLaunchPreparation").first ?? ""
    XCTAssertFalse(method.contains("Atlantis"))
    XCTAssertFalse(method.contains(".random("))
  }

  private func resolve(
    _ fixture: ProductLaunchFixture,
    release: ProductLaunchReleasePosture = .shipNow,
    publicPosture: ProductLaunchPublicPosture = .evidenceLed
  ) throws -> ProductLaunchResolution {
    var operation = fixture.operation
    operation.releasePosture = release
    operation.publicPosture = publicPosture
    return try XCTUnwrap(ProductLaunchResolutionPolicy.resolve(operation))
  }

  private func preparedStoreForLaunch(stacksState: VerificationState) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 18_180)
    store.confirmVentureThesisIfNeeded()
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let specs: [(String, AgentRole, Int, Int, VerificationState)] = [
      ("aurora", .research, 82, 84, .confirmed),
      ("stacks", .engineering, 46, 88, stacksState),
      ("brio", .marketing, 78, 80, .confirmed)
    ]
    store.tasks = specs.map { agentID, role, actual, reported, state in
      SoloTask(
        title: "\(agentID.capitalized) launch preparation", detail: "Prepared launch work",
        role: role, impact: .momentum(1), assignedAgentID: agentID, isReviewed: true,
        result: TaskResult(
          actualQuality: actual, reportedQuality: reported, verificationState: state,
          evidenceCompleteness: state == .evidenceIncomplete ? 38 : 82,
          correlatedFailureIdentifier: nil, immediateEffects: SimulationEffects(), delayedEffects: SimulationEffects(),
          confidenceLowerBound: 40, confidenceUpperBound: 90,
          knownOperationalRisk: agentID == "stacks" ? "Release reliability needs monitoring" : "No known risk"
        ),
        resolution: .approve, resolutionLocked: true
      )
    }
    store.evidence = store.tasks.map { task in
      let result = task.result!
      return EvidenceEntry(
        sprint: store.sprint, taskInstanceID: task.id.uuidString, task: task.title,
        agent: task.assignedAgentID!.capitalized, reviewed: true,
        evidenceVerified: result.verificationState != .evidenceIncomplete,
        verdict: "Reviewed", note: "Founder review complete", reportedQuality: result.reportedQuality,
        actualQuality: result.revealedActualQuality, verificationState: result.verificationState,
        overclaimAmount: 0, evidenceCompleteness: result.evidenceCompleteness,
        correlatedFailureIdentifier: nil
      )
    }
    return store
  }
}
