import RealityKit
import XCTest
@testable import Solo_Unicorn_Run

final class FounderGarageRealityTests: XCTestCase {
  func testD13WhiteboardFeedbackConsumesExistingC1IdentityAndSharedTiming() throws {
    let zone = try XCTUnwrap(
      FounderGarageSpatialSpecification.standard.facilityTier0InteractionSpace?
        .zone(for: .whiteboard)
    )
    let target = try XCTUnwrap(zone.founderInteractionTarget)
    let configuration = GarageInteractionFeedbackConfiguration.whiteboard(targetID: zone.id)

    XCTAssertEqual(configuration.targetID, "facilityTier0.whiteboard")
    XCTAssertEqual(configuration.targetID, target.id)
    XCTAssertEqual(target.interactionType, .standingObservation)
    XCTAssertEqual(configuration.promptText, "VIEW WHITEBOARD")
    XCTAssertEqual(configuration.activationDuration, 0.22)
    XCTAssertEqual(configuration.reducedMotionActivationDuration, 0.08)
    XCTAssertEqual(configuration.soundPolicy, .deferred)
    XCTAssertEqual(configuration.hapticPolicy, .deferred)
  }

  func testD13WhiteboardAvailabilityAndActivationRemainTruthfulAndBounded() {
    let configuration = GarageInteractionFeedbackConfiguration.whiteboard(
      targetID: "facilityTier0.whiteboard"
    )

    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: false,
        isFocused: true,
        activationElapsed: nil,
        reduceMotion: false
      ),
      .unavailable
    )
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: true,
        isFocused: true,
        activationElapsed: 0.01,
        reduceMotion: false
      ),
      .activated
    )
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: true,
        isFocused: true,
        activationElapsed: configuration.reducedMotionActivationDuration,
        reduceMotion: true
      ),
      .focused
    )
    XCTAssertEqual(
      GarageInteractionVisualEmphasis.resolve(state: .activated, reduceMotion: true)
        .promptScale,
      1
    )
  }

  func testD13ThreeTargetConflictResolvesToOneDeterministicPrompt() throws {
    let computer = GarageInteractionFeedbackSnapshot(
      configuration: .founderComputer(targetID: "facilityTier0.founderComputer"),
      state: .focused
    )
    let chair = GarageInteractionFeedbackSnapshot(
      configuration: .chair(targetID: "facilityTier0.chair"),
      state: .focused
    )
    let whiteboard = GarageInteractionFeedbackSnapshot(
      configuration: .whiteboard(targetID: "facilityTier0.whiteboard"),
      state: .focused
    )

    let primary = try XCTUnwrap(
      GarageInteractionFeedbackResolver.primaryPrompt(from: [whiteboard, chair, computer])
    )
    XCTAssertEqual(primary.configuration.promptText, "OPEN COMPUTER")
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.primaryPrompt(from: [whiteboard])?
        .configuration.promptText,
      "VIEW WHITEBOARD"
    )
    let chairFallback = GarageInteractionFeedbackSnapshot(
      configuration: chair.configuration,
      state: .available
    )
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.primaryPrompt(from: [chairFallback, whiteboard])?
        .configuration.promptText,
      "VIEW WHITEBOARD"
    )
  }

  @MainActor
  func testD13WorldMirrorsC1WhiteboardTruthAndAcknowledgesOnlySuccessfulIntent() throws {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(
      world.spatialSpecification.facilityTier0InteractionSpace?
        .founderInteractionTarget(for: .whiteboard)
    )

    XCTAssertFalse(world.whiteboardObservationAvailable)
    XCTAssertFalse(world.whiteboardInteractionFocused)
    XCTAssertFalse(world.requestWhiteboardObservation())
    world.apply(makePresentation(), whiteboardInteractionFeedback: .focused)
    XCTAssertEqual(world.whiteboardInteractionFeedbackState, .unavailable)

    world.cameraController.configureWalkability { _ in true }
    XCTAssertTrue(world.cameraController.beginInteractionStanding(
      at: target.approach,
      reduceMotion: true
    ))
    XCTAssertTrue(world.whiteboardObservationAvailable)
    XCTAssertTrue(world.whiteboardInteractionFocused)

    world.apply(makePresentation(), whiteboardInteractionFeedback: .focused)
    XCTAssertEqual(world.whiteboardInteractionFeedbackState, .focused)
    XCTAssertTrue(world.requestWhiteboardObservation())
    world.apply(makePresentation(), whiteboardInteractionFeedback: .activated)
    XCTAssertEqual(world.whiteboardInteractionFeedbackState, .activated)

    world.cameraController.transition(to: .whiteboard, reduceMotion: true)
    XCTAssertEqual(
      world.cameraController.playerSpatialState.navigationMode,
      .authoredInspection(.whiteboard)
    )
    XCTAssertFalse(world.requestWhiteboardObservation())
    world.apply(makePresentation(), whiteboardInteractionFeedback: .activated)
    XCTAssertEqual(world.whiteboardInteractionFeedbackState, .activated)
    world.apply(makePresentation(), whiteboardInteractionFeedback: .unavailable)
    XCTAssertEqual(world.whiteboardInteractionFeedbackState, .unavailable)
    XCTAssertEqual(world.interactionCoordinator.phase, .idle)
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testD12ChairFeedbackConsumesExistingC1IdentityAndSharedTiming() throws {
    let zone = try XCTUnwrap(
      FounderGarageSpatialSpecification.standard.facilityTier0InteractionSpace?
        .zone(for: .chair)
    )
    let configuration = GarageInteractionFeedbackConfiguration.chair(targetID: zone.id)

    XCTAssertEqual(configuration.targetID, "facilityTier0.chair")
    XCTAssertEqual(configuration.targetID, zone.founderInteractionTarget?.id)
    XCTAssertEqual(configuration.promptText, "RETURN TO DESK")
    XCTAssertEqual(configuration.activationDuration, 0.22)
    XCTAssertEqual(configuration.reducedMotionActivationDuration, 0.08)
    XCTAssertEqual(configuration.soundPolicy, .deferred)
    XCTAssertEqual(configuration.hapticPolicy, .deferred)
  }

  func testD12ChairAvailabilityAndActivationRemainTruthfulAndBounded() {
    let configuration = GarageInteractionFeedbackConfiguration.chair(
      targetID: "facilityTier0.chair"
    )

    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: false,
        isFocused: true,
        activationElapsed: nil,
        reduceMotion: false
      ),
      .unavailable
    )
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: true,
        isFocused: true,
        activationElapsed: 0.01,
        reduceMotion: false
      ),
      .activated
    )
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: false,
        isFocused: false,
        activationElapsed: 0.01,
        reduceMotion: false
      ),
      .unavailable
    )
    XCTAssertEqual(
      GarageInteractionVisualEmphasis.resolve(state: .activated, reduceMotion: true)
        .promptScale,
      1
    )
  }

  func testD12ComputerChairConflictResolvesToOneDeterministicPrompt() throws {
    let computer = GarageInteractionFeedbackSnapshot(
      configuration: .founderComputer(targetID: "facilityTier0.founderComputer"),
      state: .focused
    )
    let chair = GarageInteractionFeedbackSnapshot(
      configuration: .chair(targetID: "facilityTier0.chair"),
      state: .focused
    )

    let primary = try XCTUnwrap(
      GarageInteractionFeedbackResolver.primaryPrompt(from: [chair, computer])
    )
    XCTAssertEqual(primary.configuration.promptText, "OPEN COMPUTER")
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.primaryPrompt(from: [chair])?.configuration.promptText,
      "RETURN TO DESK"
    )
  }

  @MainActor
  func testD12WorldMirrorsChairPipelineAndAcknowledgesOnlySuccessfulIntent() throws {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)

    XCTAssertFalse(world.chairInteractionAvailable)
    world.apply(makePresentation(), chairInteractionFeedback: .focused)
    XCTAssertEqual(world.chairInteractionFeedbackState, .unavailable)

    world.cameraController.configureWalkability { _ in true }
    XCTAssertTrue(world.cameraController.beginInteractionStanding(
      at: target.approach,
      reduceMotion: true
    ))
    advance(world, frames: 8)
    XCTAssertTrue(world.chairInteractionAvailable)

    world.apply(makePresentation(), chairInteractionFeedback: .focused)
    XCTAssertEqual(world.chairInteractionFeedbackState, .focused)
    XCTAssertTrue(world.requestChairInteraction(reduceMotion: true))
    world.apply(makePresentation(), chairInteractionFeedback: .activated)
    XCTAssertEqual(world.chairInteractionFeedbackState, .activated)
    XCTAssertEqual(world.interactionCoordinator.phase, .approaching)

    world.apply(makePresentation(), chairInteractionFeedback: .unavailable)
    XCTAssertEqual(world.chairInteractionFeedbackState, .unavailable)
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testD11ComputerFeedbackUsesExistingTargetIdentityAndDeterministicPrompt() throws {
    let zone = try XCTUnwrap(
      FounderGarageSpatialSpecification.standard.facilityTier0InteractionSpace?
        .zone(for: .founderComputer)
    )
    let configuration = GarageInteractionFeedbackConfiguration.founderComputer(targetID: zone.id)

    XCTAssertEqual(configuration.targetID, "facilityTier0.founderComputer")
    XCTAssertEqual(configuration.promptText, "OPEN COMPUTER")
    XCTAssertEqual(configuration.soundPolicy, .deferred)
    XCTAssertEqual(configuration.hapticPolicy, .deferred)
    XCTAssertGreaterThan(configuration.activationDuration, 0)
    XCTAssertLessThanOrEqual(configuration.activationDuration, 0.25)
    XCTAssertLessThan(configuration.reducedMotionActivationDuration, configuration.activationDuration)
  }

  func testD11ComputerFeedbackNeverAdvertisesUnavailableActivation() {
    let configuration = GarageInteractionFeedbackConfiguration.founderComputer(targetID: "facilityTier0.founderComputer")

    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: false,
        isFocused: true,
        activationElapsed: 0,
        reduceMotion: false
      ),
      .unavailable
    )
    XCTAssertFalse(GarageInteractionFeedbackState.unavailable.exposesPrimaryPrompt)
    XCTAssertFalse(GarageInteractionFeedbackState.available.exposesPrimaryPrompt)
  }

  func testD11ComputerActivationIsBoundedAndReduceMotionPreservesClarity() {
    let configuration = GarageInteractionFeedbackConfiguration.founderComputer(targetID: "facilityTier0.founderComputer")

    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: true,
        isFocused: true,
        activationElapsed: 0.01,
        reduceMotion: false
      ),
      .activated
    )
    XCTAssertEqual(
      GarageInteractionFeedbackResolver.state(
        configuration: configuration,
        isAvailable: true,
        isFocused: true,
        activationElapsed: configuration.activationDuration,
        reduceMotion: false
      ),
      .focused
    )
    let normal = GarageInteractionVisualEmphasis.resolve(state: .activated, reduceMotion: false)
    let reduced = GarageInteractionVisualEmphasis.resolve(state: .activated, reduceMotion: true)
    XCTAssertGreaterThan(normal.promptScale, 1)
    XCTAssertEqual(reduced.promptScale, 1)
    XCTAssertEqual(normal.screenIntensityScale, reduced.screenIntensityScale)
  }

  func testD11PrimaryPromptResolverReturnsOnlyOneDeterministicTarget() throws {
    let computer = GarageInteractionFeedbackSnapshot(
      configuration: .founderComputer(targetID: "facilityTier0.founderComputer"),
      state: .focused
    )
    let lowerPriority = GarageInteractionFeedbackSnapshot(
      configuration: .init(
        targetID: "fixture.secondary",
        promptText: "FIXTURE",
        activationDuration: 0.2,
        reducedMotionActivationDuration: 0.08,
        soundPolicy: .none,
        hapticPolicy: .none,
        promptPriority: 1
      ),
      state: .focused
    )

    let primary = try XCTUnwrap(
      GarageInteractionFeedbackResolver.primaryPrompt(from: [lowerPriority, computer])
    )
    XCTAssertEqual(primary.id, computer.id)
  }

  @MainActor
  func testD11WorldFeedbackMirrorsExistingComputerAvailabilityWithoutStateMutation() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    var presentation = makePresentation()

    world.apply(presentation, interactionFeedback: .focused, reduceMotion: false)
    XCTAssertEqual(world.computerInteractionFeedbackState, .focused)
    XCTAssertTrue(world.founderComputerInteractionAvailable)
    XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)

    presentation.founderComputerAvailable = false
    world.apply(presentation, interactionFeedback: .activated, reduceMotion: false)
    XCTAssertEqual(world.computerInteractionFeedbackState, .unavailable)
    XCTAssertFalse(world.founderComputerInteractionAvailable)
    XCTAssertNil(world.interaction(for: world.entities.founderComputerInteractionTarget))
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testPass6PrototypeContractRemainsAvailableAsMigrationHistory() {
    let prototype = FounderGarageSpatialSpecification.pass6Prototype

    XCTAssertEqual(prototype.contractIdentity, .pass6Prototype)
    XCTAssertEqual(prototype.room.width, 5.80)
    XCTAssertEqual(prototype.room.depth, 6.40)
    XCTAssertEqual(prototype.room.wallHeight, 3.10)
    XCTAssertNil(prototype.productionAnchors)
  }

  func testFacilityTier0CanonicalAnchorMapMatchesAuthoredProductionCoordinates() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let anchors = try XCTUnwrap(spatial.productionAnchors)

    XCTAssertEqual(anchors.namedPositions.count, 20)
    XCTAssertEqual(anchors.founderSeat, [0.34, 0, -0.22])
    XCTAssertEqual(anchors.deskSurface, [0.95, 0.7575, -1.05])
    XCTAssertEqual(anchors.monitorFace, [1.42, 1.30, -1.08])
    XCTAssertEqual(anchors.cameraIso, [5.40, 4.10, 6.30])
    XCTAssertEqual(anchors.cameraFront, [0.60, 2.60, 8.20])
    XCTAssertEqual(anchors.cameraLook, [0.45, 1.00, -0.35])
    XCTAssertEqual(anchors.doorMouth, [0, 1.20, 2.75])
    XCTAssertEqual(anchors.whiteboardFace, [-2.42, 1.52, -0.40])
    XCTAssertEqual(anchors.hangingLights, [[-0.30, 2.04, -1.55], [1.10, 2.04, 0.05]])
    XCTAssertEqual(anchors.deskLamp, [0.175, 1.22, -1.185])
    XCTAssertEqual(anchors.deskGlowVFX, [0.95, 0.92, -1.05])
    XCTAssertEqual(anchors.doorLightVFX, [0, 2.00, 2.60])
  }

  func testFacilityTier0AgentSlotsAreFloorClearInsideAndMutuallySeparated() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let slots = try XCTUnwrap(spatial.productionAnchors?.agentSlots)

    XCTAssertEqual(slots, [
      [-1.75, 0, -0.40], [1.28, 0, 1.52], [-1.45, 0, -1.20], [0.35, 0, 2.05]
    ])
    for slot in slots {
      XCTAssertEqual(slot.y, 0, accuracy: 0.0001)
      XCTAssertTrue(spatial.room.interiorBounds.contains([slot.x, slot.z]))
      XCTAssertTrue(spatial.walkableRegion.contains([slot.x, slot.z]))
    }
    for firstIndex in slots.indices {
      for secondIndex in slots.indices where secondIndex > firstIndex {
        XCTAssertGreaterThanOrEqual(
          simd_distance(slots[firstIndex], slots[secondIndex]),
          0.60
        )
      }
    }
  }

  @MainActor
  func testBundledFacilityTier0AssetLoadsAtNativeScaleAndBecomesActiveSource() async throws {
    let source = FounderGarageArchitectureSource.bundledProductionAsset(name: "founder_garage")
    XCTAssertNotNil(Bundle.main.url(forResource: "founder_garage", withExtension: "usdz"))

    let world = FounderGarageRealityWorld()
    let task = try XCTUnwrap(
      world.requestGarageArchitecture(source, descriptor: .facilityTier0)
    )
    await task.value

    guard case .ready(let readySource) = world.architectureLoadState else {
      return XCTFail("Production asset did not become ready: \(world.architectureLoadState)")
    }
    XCTAssertEqual(readySource, source)
    XCTAssertEqual(world.activeGarageArchitectureAdapter.source, source)
    let adapter = try XCTUnwrap(world.activeGarageArchitectureAdapter as? ImportedGarageArchitectureAdapter)
    let monitorMaterials = adapter.rig.visualRoot.findEntity(named: "Monitor_Screen")?.components[ModelComponent.self]?.materials ?? []
    let monitorMaterial = try XCTUnwrap(monitorMaterials.first as? PhysicallyBasedMaterial)
    XCTAssertEqual(adapter.normalization.uniformScale, 1, accuracy: 0.0001)
    XCTAssertEqual(adapter.normalization.translationCorrection, .zero)
    XCTAssertTrue(adapter.normalization.nativeBounds.approximatelyMatches(
      FounderGarageArchitectureBounds(minimum: [-2.62, -0.12, -2.87], maximum: [2.62, 2.70, 2.89]),
      tolerance: 0.025
    ))
    XCTAssertEqual(adapter.renderableEntityCount, 168)
    XCTAssertEqual(adapter.materialCount, 168)
    XCTAssertEqual(adapter.preservedAnchorPositions.count, 20)
    XCTAssertTrue(adapter.missingAnchorNames.isEmpty)
    XCTAssertEqual(monitorMaterial.roughness.scale, 0.15, accuracy: 0.001)
    XCTAssertEqual(monitorMaterial.metallic.scale, 0, accuracy: 0.001)
    XCTAssertNil(monitorMaterial.roughness.texture)
    XCTAssertNil(monitorMaterial.metallic.texture)
    XCTAssertNil(monitorMaterial.emissiveColor.texture)
    XCTAssertGreaterThan(monitorMaterial.emissiveIntensity, 0)
    XCTAssertNil(adapter.rig.visualRoot.findEntity(named: "Materials"))
    XCTAssertTrue(adapter.usesAuthoredCutaway)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Wall_Right_Cutaway")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Header_Beam")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Door_Rolled")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Track_Vert_R")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Track_Horiz_R")?.isEnabled, false)
    XCTAssertFalse(world.entities.furniture.isEnabled)
    XCTAssertTrue(world.entities.iPhone.isEnabled)
    XCTAssertTrue(world.entities.iPad.isEnabled)
    XCTAssertTrue(world.entities.founderComputerInteractionTarget.isEnabled)
    XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)

    let expectedAnchors = try XCTUnwrap(world.spatialSpecification.productionAnchors).namedPositions
    for (name, importedPosition) in adapter.preservedAnchorPositions {
      let expected = try XCTUnwrap(expectedAnchors[name])
      XCTAssertEqual(importedPosition.x, expected.x, accuracy: 0.001, name)
      XCTAssertEqual(importedPosition.y, expected.y, accuracy: 0.001, name)
      XCTAssertEqual(importedPosition.z, expected.z, accuracy: 0.001, name)
    }
  }

  func testFacilityTier0InteractionSpaceHasOneActiveZoneAndStableSemantics() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let space = try XCTUnwrap(spatial.facilityTier0InteractionSpace)

    XCTAssertEqual(space.zones.count, FacilityTier0InteractionZone.SemanticObject.allCases.count)
    XCTAssertEqual(space.activeZones.map(\.semanticObject), [.founderComputer])
    XCTAssertEqual(space.zone(for: .chair)?.id, "facilityTier0.chair")
    XCTAssertEqual(space.zone(for: .founderComputer)?.id, "facilityTier0.founderComputer")
    XCTAssertEqual(space.zone(for: .whiteboard)?.id, "facilityTier0.whiteboard")
    XCTAssertEqual(space.zone(for: .garageDoor)?.id, "facilityTier0.garageDoor")
    XCTAssertEqual(space.zone(for: .secondWorkstation)?.isEnabled, false)
    XCTAssertEqual(space.zone(for: .signalTV)?.isEnabled, false)
    XCTAssertEqual(space.zone(for: .fundingSurface)?.isEnabled, false)
  }

  func testFacilityTier0ComputerWhiteboardAndDoorZonesAlignToAuthoredAnchors() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let authored = try XCTUnwrap(spatial.productionAnchors)
    let space = try XCTUnwrap(spatial.facilityTier0InteractionSpace)
    let chair = try XCTUnwrap(space.zone(for: .chair))
    let computer = try XCTUnwrap(space.zone(for: .founderComputer))
    let whiteboard = try XCTUnwrap(space.zone(for: .whiteboard))
    let door = try XCTUnwrap(space.zone(for: .garageDoor))

    XCTAssertEqual(chair.anchorName, "Anchor_Founder_Seat")
    XCTAssertEqual(chair.object.position, authored.founderSeat)
    XCTAssertTrue(spatial.isPointWalkable([chair.approach.position.x, chair.approach.position.z]))
    XCTAssertEqual(computer.anchorName, "Anchor_Monitor_Face")
    XCTAssertEqual(computer.object.position, authored.monitorFace)
    XCTAssertNotEqual(computer.approach.position, authored.founderSeat)
    XCTAssertTrue(spatial.isPointWalkable([computer.approach.position.x, computer.approach.position.z]))
    XCTAssertEqual(computer.activationBounds.size, [0.59, 0.34, 0.04])
    XCTAssertEqual(computer.activationBounds.center, authored.monitorFace)
    XCTAssertEqual(whiteboard.object.position, authored.whiteboardFace)
    XCTAssertTrue(spatial.isPointWalkable([whiteboard.approach.position.x, whiteboard.approach.position.z]))
    XCTAssertEqual(door.object.position, authored.doorMouth)
    XCTAssertEqual(door.activationBounds.planarBounds, spatial.occupiedZones.garageDoorClearance)
    XCTAssertTrue(spatial.isPointWalkable([door.approach.position.x, door.approach.position.z]))

    for zone in [chair, computer, whiteboard, door] {
      let approachToObject = zone.object.position - zone.approach.position
      let planarDirection = simd_normalize(SIMD3<Float>(approachToObject.x, 0, approachToObject.z))
      XCTAssertGreaterThan(simd_dot(planarDirection, zone.approach.facingDirection), 0.99, zone.id)
      XCTAssertGreaterThan(zone.interactionDistance.rawValue, 0)
    }
  }

  func testPassC1FounderInteractionTargetsAreBoundedStableAndFinite() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let space = try XCTUnwrap(spatial.facilityTier0InteractionSpace)
    let targets = space.founderInteractionTargets

    XCTAssertEqual(targets.map(\.id), [
      "facilityTier0.chair",
      "facilityTier0.founderComputer",
      "facilityTier0.whiteboard"
    ])
    XCTAssertEqual(Set(targets.map(\.id)).count, targets.count)
    XCTAssertEqual(targets.map(\.semanticObject), [.chair, .founderComputer, .whiteboard])
    XCTAssertEqual(targets.map(\.interactionType), [.seat, .seatedWorkstation, .standingObservation])
    XCTAssertTrue(targets.allSatisfy(\.hasFiniteValues))
    XCTAssertTrue(targets.allSatisfy { $0.positionToleranceMeters > 0 })
    XCTAssertTrue(targets.allSatisfy { $0.facingToleranceRadians > 0 })
    XCTAssertTrue(targets.allSatisfy { $0.preferredHand == nil && $0.handTarget == nil })

    for semanticObject in [
      FacilityTier0InteractionZone.SemanticObject.garageDoor,
      .signalTV, .fundingSurface, .secondWorkstation
    ] {
      XCTAssertNil(space.founderInteractionTarget(for: semanticObject))
    }
  }

  func testPassC1ApproachesAreWalkableAndAcceptedEndpointsRemainAuthored() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let authored = try XCTUnwrap(spatial.productionAnchors)
    let space = try XCTUnwrap(spatial.facilityTier0InteractionSpace)
    let chair = try XCTUnwrap(space.founderInteractionTarget(for: .chair))
    let computer = try XCTUnwrap(space.founderInteractionTarget(for: .founderComputer))
    let whiteboard = try XCTUnwrap(space.founderInteractionTarget(for: .whiteboard))

    for target in [chair, computer, whiteboard] {
      XCTAssertTrue(
        spatial.isPointWalkable([target.approach.position.x, target.approach.position.z]),
        target.id
      )
      XCTAssertEqual(target.approach.position.y, 0, accuracy: 0.0001, target.id)
    }

    XCTAssertEqual(chair.interaction, spatial.anchors.founder)
    XCTAssertEqual(computer.interaction, spatial.anchors.founder)
    XCTAssertEqual(chair.gazeTarget, [authored.founderSeat.x, 0.455, authored.founderSeat.z])
    XCTAssertEqual(computer.gazeTarget, authored.monitorFace)
    XCTAssertEqual(whiteboard.gazeTarget, authored.whiteboardFace)
    XCTAssertEqual(whiteboard.interaction, whiteboard.approach)
    XCTAssertGreaterThan(simd_distance(chair.approach.position, chair.interaction.position), 0.80)
    XCTAssertGreaterThan(simd_distance(computer.approach.position, computer.interaction.position), 0.80)
  }

  @MainActor
  func testGI01ChairInteractionRunsStandingThroughSeatedAndDeparture() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    world.cameraController.configureWalkability { _ in true }
    world.cameraController.beginWalking(reduceMotion: false)
    world.cameraController.consume(.init(
      bodyPosition: target.approach.position + [-0.72, 0, 0.54],
      bodyHeading: -1.15,
      locomotionVelocity: .zero,
      stepPhase: nil,
      stance: .standing
    ))
    advance(world, frames: 40)

    XCTAssertTrue(world.requestChairInteraction())
    var observed: Set<FounderInteractionPhase> = [world.interactionCoordinator.phase]
    advance(world, until: .seated, observed: &observed)

    XCTAssertTrue(observed.isSuperset(of: [.approaching, .stopping, .aligning, .sitting, .seated]))
    XCTAssertEqual(world.founderAvatarController.locomotion.state, .seatedIdle)
    XCTAssertEqual(world.cameraController.playerSpatialState.navigationMode, .seated)
    XCTAssertFalse(world.cameraController.founderObservationActive)
    XCTAssertTrue(world.cameraController.usesFirstPersonPresentation)
    XCTAssertFalse(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertEqual(
      world.cameraController.camera.position,
      world.cameraController.playerSpatialState.eyePosition
    )
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.approachPositionError, target.positionToleranceMeters)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.approachYawError, target.facingToleranceRadians)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.stopVelocity, 0.01)
    XCTAssertEqual(world.interactionCoordinator.diagnostics.seatEndpointError, 0, accuracy: 0.0001)
    XCTAssertGreaterThanOrEqual(world.interactionCoordinator.diagnostics.sitDuration, 0.40)
    XCTAssertLessThan(world.interactionCoordinator.diagnostics.sitDuration, 0.52)

    XCTAssertTrue(world.requestChairExit())
    advance(world, until: .idle, observed: &observed)
    XCTAssertTrue(observed.isSuperset(of: [.standing, .departing]))
    XCTAssertEqual(world.cameraController.playerSpatialState.navigationMode, .walking)
    XCTAssertEqual(world.founderAvatarController.locomotion.state, .standingIdle)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.standingEndpointError, 0.0025)
    XCTAssertEqual(world.interactionCoordinator.diagnostics.invalidTransformCount, 0)
  }

  @MainActor
  func testGI05FounderModeIsFirstPersonAndExploreRemainsThirdPerson() {
    let world = FounderGarageRealityWorld()
    let camera = world.cameraController

    camera.beginWalking(reduceMotion: true)
    world.advanceSession(deltaTime: 0.1)

    XCTAssertTrue(camera.founderObservationActive)
    XCTAssertFalse(camera.usesFirstPersonPresentation)
    XCTAssertTrue(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertNotEqual(camera.camera.transform.translation, camera.playerSpatialState.eyePosition)

    camera.endWalking(reduceMotion: true)
    world.advanceSession(deltaTime: 0.1)
    XCTAssertFalse(camera.founderObservationActive)
    XCTAssertTrue(camera.usesFirstPersonPresentation)
    XCTAssertFalse(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertEqual(world.founderAvatarController.locomotion.state, .seatedIdle)
    XCTAssertEqual(camera.spatialState.stance, .seated)

    camera.recenterFounderPOV(reduceMotion: true)
    world.advanceSession(deltaTime: 0.1)
    XCTAssertFalse(camera.founderObservationActive)
    XCTAssertTrue(camera.usesFirstPersonPresentation)
    XCTAssertFalse(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertEqual(camera.camera.transform.translation, camera.playerSpatialState.eyePosition)
    XCTAssertEqual(camera.spatialState.stance, .seated)

    XCTAssertTrue(camera.focus(on: .computer, reduceMotion: true))
    world.advanceSession(deltaTime: 0.1)
    XCTAssertTrue(camera.usesFirstPersonPresentation)
    XCTAssertFalse(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertEqual(camera.camera.transform.translation, camera.playerSpatialState.eyePosition)
  }

  @MainActor
  func testGI02ChairInteractionFiftyCyclesHaveNoDriftOrInvalidTransforms() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    world.cameraController.configureWalkability { _ in true }
    XCTAssertTrue(world.cameraController.beginInteractionStanding(at: target.approach, reduceMotion: true))
    advance(world, frames: 8)

    for _ in 0..<50 {
      XCTAssertTrue(world.requestChairInteraction(reduceMotion: true))
      advance(world, until: .seated)
      XCTAssertTrue(world.requestChairExit(reduceMotion: true))
      advance(world, until: .idle)
    }

    let diagnostics = world.interactionCoordinator.diagnostics
    XCTAssertEqual(diagnostics.completedCycleCount, 50)
    XCTAssertEqual(diagnostics.invalidTransformCount, 0)
    XCTAssertEqual(diagnostics.cyclePositionDrift, 0, accuracy: 0.0001)
    XCTAssertEqual(diagnostics.cycleYawDrift, 0, accuracy: 0.0001)
    XCTAssertEqual(diagnostics.seatEndpointError, 0, accuracy: 0.0001)
    XCTAssertEqual(diagnostics.standingEndpointError, 0, accuracy: 0.0001)
    XCTAssertEqual(
      diagnostics.deterministicSignature,
      "chair|d=0.0000|p=0.0000|y=0.0000|v=0.0000|at=0.0000|ar=0.0000|sit=0.1000|seat=0.0000|stand=0.1000|standing=0.0000|depart=0.2500|recover=0.0000|drift=0.0000,0.0000|invalid=0|cycles=50"
    )
  }

  @MainActor
  func testGI03ReduceMotionUsesAcceptedBoundedChairTransitions() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    world.cameraController.configureWalkability { _ in true }
    XCTAssertTrue(world.cameraController.beginInteractionStanding(at: target.approach, reduceMotion: true))
    advance(world, frames: 8)

    XCTAssertTrue(world.requestChairInteraction(reduceMotion: true))
    advance(world, until: .seated)
    XCTAssertGreaterThanOrEqual(world.interactionCoordinator.diagnostics.sitDuration, 0.08)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.sitDuration, 0.12)
    XCTAssertTrue(world.requestChairExit(reduceMotion: true))
    advance(world, until: .idle)
    XCTAssertGreaterThanOrEqual(world.interactionCoordinator.diagnostics.standDuration, 0.08)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.standDuration, 0.12)
    XCTAssertEqual(FounderAnimationTiming.seatedTransition, 0.42)
    XCTAssertEqual(FounderAnimationTiming.standingTransition, 0.68)
    XCTAssertEqual(FounderAnimationTiming.reducedTransition, 0.08)
  }

  @MainActor
  func testGI03NormalStandUsesIsolatedVariantBDurationWithoutChangingSit() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    world.cameraController.configureWalkability { _ in true }
    XCTAssertTrue(world.cameraController.beginInteractionStanding(at: target.approach, reduceMotion: true))
    advance(world, frames: 8)

    XCTAssertTrue(world.requestChairInteraction(reduceMotion: false))
    advance(world, until: .seated)
    XCTAssertGreaterThanOrEqual(world.interactionCoordinator.diagnostics.sitDuration, 0.42)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.sitDuration, 0.46)

    XCTAssertTrue(world.requestChairExit(reduceMotion: false))
    advance(world, until: .idle)
    XCTAssertGreaterThanOrEqual(world.interactionCoordinator.diagnostics.standDuration, 0.68)
    XCTAssertLessThanOrEqual(world.interactionCoordinator.diagnostics.standDuration, 0.72)
  }

  @MainActor
  func testGI04ChairContractAndLocomotionTopologyRemainLocked() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    XCTAssertEqual(target.id, "facilityTier0.chair")
    XCTAssertEqual(target.approach.position.x, -0.301470, accuracy: 0.000001)
    XCTAssertEqual(target.approach.position.y, 0, accuracy: 0.000001)
    XCTAssertEqual(target.approach.position.z, 0.290800, accuracy: 0.000001)
    XCTAssertEqual(target.interaction.position, [0.34, 0, -0.22])
    XCTAssertEqual(target.positionToleranceMeters, 0.08)
    XCTAssertEqual(target.facingToleranceRadians, 0.14)
    XCTAssertEqual(FounderLocomotionState.allCases.count, 9)
    XCTAssertEqual(Set(FounderLocomotionState.allCases), [
      .seatedIdle, .seatedTurn, .standingUp, .standingIdle,
      .walkStart, .walking, .walkStop, .turnInPlace, .sittingDown
    ])
  }

  @MainActor
  func testGI11ApproachInterruptionRecoversImmediatelyToStableStanding() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    world.cameraController.configureWalkability { _ in true }
    world.cameraController.beginWalking(reduceMotion: false)
    world.cameraController.consume(.init(
      bodyPosition: target.approach.position + [-1.0, 0, 0.8],
      bodyHeading: 0.7,
      locomotionVelocity: .zero,
      stepPhase: nil,
      stance: .standing
    ))
    advance(world, frames: 40)
    XCTAssertTrue(world.requestChairInteraction())
    advance(world, frames: 12)
    XCTAssertEqual(world.interactionCoordinator.phase, .approaching)

    world.cancelChairInteraction()
    XCTAssertEqual(world.interactionCoordinator.phase, .recovering)
    advance(world, until: .idle)
    XCTAssertEqual(world.cameraController.playerSpatialState.navigationMode, .walking)
    XCTAssertEqual(world.founderAvatarController.locomotion.state, .standingIdle)
    XCTAssertGreaterThan(world.interactionCoordinator.diagnostics.interruptRecoveryTime, 0)
    XCTAssertEqual(world.interactionCoordinator.diagnostics.invalidTransformCount, 0)
  }

  @MainActor
  func testGI12SeatedInterruptionUsesStandSafeBoundaryBeforeRelease() throws {
    let world = FounderGarageRealityWorld()
    let target = try XCTUnwrap(world.interactionCoordinator.chairTarget)
    world.cameraController.configureWalkability { _ in true }
    XCTAssertTrue(world.cameraController.beginInteractionStanding(at: target.approach, reduceMotion: false))
    advance(world, frames: 30)
    XCTAssertTrue(world.requestChairInteraction())
    advance(world, until: .seated)

    world.cancelChairInteraction()
    XCTAssertEqual(world.interactionCoordinator.phase, .standing)
    advance(world, until: .idle)
    XCTAssertEqual(world.cameraController.playerSpatialState.navigationMode, .walking)
    XCTAssertEqual(world.founderAvatarController.locomotion.state, .standingIdle)
    XCTAssertEqual(world.cameraController.playerSpatialState.playerPose.position, target.approach.position)
    XCTAssertGreaterThanOrEqual(world.interactionCoordinator.diagnostics.interruptRecoveryTime, 0.40)
    XCTAssertEqual(world.interactionCoordinator.diagnostics.invalidTransformCount, 0)
  }

  func testPassC1FacingAgreesWithTargetsWithinContractTolerance() throws {
    let space = try XCTUnwrap(
      FounderGarageSpatialSpecification.standard.facilityTier0InteractionSpace
    )

    for target in space.founderInteractionTargets {
      let gaze = try XCTUnwrap(target.gazeTarget)
      let origin = target.interactionType == .standingObservation
        ? target.interaction.position
        : target.approach.position
      let offset = gaze - origin
      let expected = simd_normalize(SIMD3<Float>(offset.x, 0, offset.z))
      let facing = target.interactionType == .standingObservation
        ? target.interaction.facingDirection
        : target.approach.facingDirection
      let cosine = min(max(simd_dot(expected, facing), -1), 1)
      XCTAssertLessThanOrEqual(acos(cosine), target.facingToleranceRadians, target.id)
    }
  }

  func testPassC1ContractDoesNotExpandMotionOrPersistenceState() {
    XCTAssertEqual(FounderLocomotionState.allCases.map(\.rawValue), [
      "seatedIdle", "seatedTurn", "standingUp", "standingIdle",
      "walkStart", "walking", "walkStop", "turnInPlace", "sittingDown"
    ])
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testFacilityTier0AgentOccupancyAnchorsHaveStableIdentityAndFacing() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let space = try XCTUnwrap(spatial.facilityTier0InteractionSpace)

    XCTAssertEqual(space.agentSlots.map(\.id), [
      "facilityTier0.agentSlot01", "facilityTier0.agentSlot02",
      "facilityTier0.agentSlot03", "facilityTier0.agentSlot04"
    ])
    XCTAssertEqual(space.agentSlots.map(\.anchorName), [
      "Anchor_Agent_Slot_01", "Anchor_Agent_Slot_02",
      "Anchor_Agent_Slot_03", "Anchor_Agent_Slot_04"
    ])
    for slot in space.agentSlots {
      XCTAssertEqual(slot.pose.position.y, 0, accuracy: 0.0001)
      XCTAssertTrue(spatial.isPointWalkable([slot.pose.position.x, slot.pose.position.z]))
      XCTAssertEqual(simd_length(slot.pose.facingDirection), 1, accuracy: 0.0001)
    }
  }

  func testFacilityTier0WalkableQueriesRejectOccupiedAndAcceptDoorClearance() {
    let spatial = FounderGarageSpatialSpecification.standard

    XCTAssertTrue(spatial.isPointInsideFacility([0, 0]))
    XCTAssertFalse(spatial.isPointInsideFacility([2.51, 0]))
    for bounds in spatial.walkableRegion.exclusions {
      XCTAssertTrue(spatial.isPointInsideOccupiedZone(bounds.center))
      XCTAssertFalse(spatial.isPointWalkable(bounds.center))
    }
    XCTAssertTrue(spatial.isPointWalkable([0, 1.20]))
    XCTAssertTrue(spatial.isPointWalkable(spatial.occupiedZones.garageDoorClearance.center))
  }

  @MainActor
  func testImportedAnchorMapResolvesOnceAndRetainsDirectEntityIdentity() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world)
    let anchorMap = try XCTUnwrap(adapter.resolvedAnchorMap)
    let rootID = adapter.rig.visualRoot.id
    let anchorIDs = anchorMap.entitiesByName.mapValues { $0.id }

    world.apply(makePresentation(), reduceMotion: true)
    await world.requestGarageArchitecture(
      .bundledProductionAsset(name: "founder_garage"),
      descriptor: .facilityTier0
    )?.value

    XCTAssertEqual(adapter.anchorMapResolutionCount, 1)
    XCTAssertEqual(anchorMap.entitiesByName.count, 20)
    XCTAssertEqual(adapter.rig.visualRoot.id, rootID)
    XCTAssertEqual(anchorMap.entitiesByName.mapValues { $0.id }, anchorIDs)
    XCTAssertTrue(world.activeGarageArchitectureAdapter === adapter)
    XCTAssertEqual(world.architectureLoadDiagnostics.successfulInstallationCount, 1)
  }

  @MainActor
  func testImportedOccupiedBoundsDriveWorldWalkabilityInsideFacility() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world)
    let occupied = try XCTUnwrap(adapter.importedOccupiedBounds)

    XCTAssertEqual(world.effectiveOccupiedBounds.count, 4)
    for bounds in occupied.all {
      XCTAssertTrue(world.spatialSpecification.room.interiorBounds.contains(bounds, margin: -0.03))
      XCTAssertTrue(world.isPointInsideOccupiedZone(bounds.center))
      XCTAssertFalse(world.isPointWalkable(bounds.center))
    }
    XCTAssertTrue(world.isPointWalkable(world.spatialSpecification.occupiedZones.garageDoorClearance.center))
    XCTAssertTrue(world.isPointWalkable([0, 1.20]))
  }

  func testFacilityTier0LightingContractUsesAuthoredFixtureAnchors() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let authored = try XCTUnwrap(spatial.productionAnchors)
    let lighting = try XCTUnwrap(FacilityTier0LightingRigContract(spatial: spatial))

    XCTAssertEqual(lighting.doorwayKey.kind, .directional)
    XCTAssertEqual(lighting.doorwayKey.anchorName, "Anchor_VFX_DoorLight")
    XCTAssertEqual(lighting.doorwayKey.position, authored.doorLightVFX)
    XCTAssertEqual(lighting.doorwayKey.target, [0.95, 0.82, -1.05])
    XCTAssertEqual(lighting.doorwayKey.baseIntensity, 5_600)
    XCTAssertEqual(lighting.hangingFill.position, authored.hangingLights[1])
    XCTAssertEqual(lighting.hangingFill.baseIntensity, 450)
    XCTAssertEqual(lighting.hangingPractical.position, authored.hangingLights[0])
    XCTAssertEqual(lighting.hangingPractical.baseIntensity, 320)
    XCTAssertEqual(lighting.deskPractical.position, authored.deskLamp)
    XCTAssertEqual(lighting.deskPractical.baseIntensity, 180)
    for light in [lighting.hangingFill, lighting.hangingPractical, lighting.deskPractical] {
      XCTAssertLessThan(light.position.y, spatial.room.ceilingHeight)
      XCTAssertEqual(light.kind, .point)
    }
  }

  @MainActor
  func testLightingEntitiesKeepIdentityAndApplyProductionIntensities() async throws {
    let world = FounderGarageRealityWorld()
    let lightIDs = [
      world.entities.keyLight.id, world.entities.fillLight.id,
      world.entities.hangingPracticalLight.id, world.entities.deskPracticalLight.id
    ]
    let presentation = makePresentation()
    world.apply(presentation, reduceMotion: true)
    _ = try await loadFacilityTier0(in: world)
    let intensity = Float(presentation.roomLightIntensity)

    XCTAssertEqual(world.entities.keyLight.position, [0, 2.00, 2.60])
    XCTAssertEqual(world.entities.fillLight.position, [1.10, 2.04, 0.05])
    XCTAssertEqual(world.entities.hangingPracticalLight.position, [-0.30, 2.04, -1.55])
    XCTAssertEqual(world.entities.deskPracticalLight.position, [0.175, 1.22, -1.185])
    XCTAssertEqual(world.entities.keyLight.light.intensity, 5_600 * intensity, accuracy: 0.01)
    XCTAssertEqual(world.entities.fillLight.light.intensity, 450 * intensity, accuracy: 0.01)
    XCTAssertEqual(world.entities.hangingPracticalLight.light.intensity, 320 * intensity, accuracy: 0.01)
    XCTAssertEqual(world.entities.deskPracticalLight.light.intensity, 180 * intensity, accuracy: 0.01)
    XCTAssertEqual(lightIDs, [
      world.entities.keyLight.id, world.entities.fillLight.id,
      world.entities.hangingPracticalLight.id, world.entities.deskPracticalLight.id
    ])
    XCTAssertTrue(world.entities.validateIntegrity())
  }

  @MainActor
  func testImportedMaterialAuditPreservesPBRBindingsAcrossAllCategories() async throws {
    let adapter = try await loadFacilityTier0(in: FounderGarageRealityWorld())
    let audit = try XCTUnwrap(adapter.materialAudit)

    XCTAssertEqual(Set(audit.entitiesByCategory.keys), Set(FacilityTier0MaterialAudit.Category.allCases))
    XCTAssertTrue(audit.overriddenEntityNames.isEmpty)
    for category in FacilityTier0MaterialAudit.Category.allCases {
      let entities = try XCTUnwrap(audit.entitiesByCategory[category], category.rawValue)
      XCTAssertFalse(entities.isEmpty, category.rawValue)
      XCTAssertTrue(entities.allSatisfy { $0.components[ModelComponent.self] != nil }, category.rawValue)
      XCTAssertTrue(entities.allSatisfy {
        !($0.components[ModelComponent.self]?.materials.isEmpty ?? true)
      }, category.rawValue)
    }
    XCTAssertEqual(adapter.materialCount, 168)
  }

  @MainActor
  func testImportedLayerRegistryPreservesNarrativeLayersAndExactCutaway() async throws {
    let adapter = try await loadFacilityTier0(in: FounderGarageRealityWorld())
    let layers = try XCTUnwrap(adapter.layerRegistry)

    for layer in [
      layers.shell, layers.door, layers.furniture, layers.tech,
      layers.clutter, layers.frontBay, layers.wallDressing, layers.lighting
    ] {
      XCTAssertTrue(layer.isEnabled, layer.name)
    }
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Wall_Right_Cutaway")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Header_Beam")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Door_Rolled")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Track_Vert_R")?.isEnabled, false)
    XCTAssertEqual(adapter.rig.visualRoot.findEntity(named: "Track_Horiz_R")?.isEnabled, false)
  }

  @MainActor
  func testProceduralArchitectureIsTheInstalledFallbackSource() throws {
    let world = FounderGarageRealityWorld()
    let adapter = world.proceduralGarageArchitectureAdapter

    XCTAssertEqual(adapter.source, .procedural)
    XCTAssertEqual(world.activeGarageArchitectureAdapter.source, .procedural)
    XCTAssertEqual(world.architectureLoadState, .ready(.procedural))
    XCTAssertTrue(adapter.rig.anchor === world.entities.environment)
    XCTAssertTrue(adapter.rig.normalizationRoot.parent === world.entities.environment)
    XCTAssertTrue(adapter.rig.visualRoot.parent === adapter.rig.normalizationRoot)
    XCTAssertEqual(adapter.materialCount, 8)
    XCTAssertNotNil(adapter.rig.visualRoot.findEntity(named: "Architecture.FloorFinish"))
    XCTAssertNotNil(adapter.rig.visualRoot.findEntity(named: "Architecture.RearWall.InteriorFinish"))
    XCTAssertNotNil(adapter.rig.visualRoot.findEntity(named: "Architecture.Ceiling.LeftPanel"))
    XCTAssertNotNil(adapter.rig.visualRoot.findEntity(named: "Architecture.Ceiling.RightPanel"))
    XCTAssertNotNil(adapter.rig.visualRoot.findEntity(named: "Architecture.GarageDoorFrame"))
  }

  @MainActor
  func testProceduralArchitectureBoundsExactlyMatchSpatialContract() throws {
    let world = FounderGarageRealityWorld()
    let expected = FounderGarageArchitectureBounds.canonical(for: world.spatialSpecification)
    let normalization = world.proceduralGarageArchitectureAdapter.normalization
    let visualRoot = world.proceduralGarageArchitectureAdapter.rig.visualRoot
    let floorFinish = try XCTUnwrap(visualRoot.findEntity(named: "Architecture.FloorFinish"))

    XCTAssertEqual(normalization.nativeBounds, expected)
    XCTAssertEqual(normalization.targetBounds, expected)
    XCTAssertEqual(normalization.resultingBounds, expected)
    XCTAssertEqual(normalization.uniformScale, 1)
    XCTAssertEqual(normalization.translationCorrection, .zero)
    XCTAssertEqual(floorFinish.visualBounds(relativeTo: visualRoot).max.y, 0, accuracy: 0.0001)
  }

  @MainActor
  func testSyntheticImportedArchitectureNormalizesUniformlyToCanonicalBounds() throws {
    let spatial = FounderGarageSpatialSpecification.pass6Prototype
    let fixture = makeSyntheticArchitecture(size: [58, 31, 64])
    let source = FounderGarageArchitectureSource.bundledProductionAsset(name: "SyntheticGarage")
    let anchor = Entity()
    let adapter = try ImportedGarageArchitectureAdapter(
      source: source,
      loadedRoot: fixture,
      anchor: anchor,
      spatial: spatial,
      descriptor: .canonicalAxes
    )

    XCTAssertEqual(adapter.source, source)
    XCTAssertEqual(adapter.normalization.nativeBounds.size, SIMD3<Float>(58, 31, 64))
    XCTAssertEqual(adapter.normalization.uniformScale, 0.1, accuracy: 0.0001)
    XCTAssertEqual(adapter.normalization.translationCorrection, .zero)
    XCTAssertTrue(
      adapter.normalization.resultingBounds.approximatelyMatches(
        .canonical(for: spatial),
        tolerance: 0.001
      )
    )
    XCTAssertEqual(adapter.materialCount, 1)
  }

  @MainActor
  func testImportedArchitectureRejectsDistortedOrEmptyFixtures() {
    let spatial = FounderGarageSpatialSpecification.standard
    let anchor = Entity()

    XCTAssertThrowsError(
      try ImportedGarageArchitectureAdapter(
        source: .bundledProductionAsset(name: "Distorted"),
        loadedRoot: makeSyntheticArchitecture(size: [58, 10, 64]),
        anchor: anchor,
        spatial: spatial,
        descriptor: .canonicalAxes
      )
    ) { error in
      XCTAssertEqual(error as? FounderGarageArchitectureAdapterError, .incompatibleProportions)
    }
    XCTAssertThrowsError(
      try ImportedGarageArchitectureAdapter(
        source: .bundledProductionAsset(name: "Empty"),
        loadedRoot: Entity(),
        anchor: anchor,
        spatial: spatial,
        descriptor: .canonicalAxes
      )
    ) { error in
      XCTAssertEqual(error as? FounderGarageArchitectureAdapterError, .invalidHierarchy)
    }
  }

  @MainActor
  func testArchitectureInstallationKeepsCanonicalWorldAndArchitectureRootStable() throws {
    let world = FounderGarageRealityWorld(spatialSpecification: .pass6Prototype)
    let identities = world.entities.identitySnapshot
    let spatial = world.spatialSpecification
    let adapter = try ImportedGarageArchitectureAdapter(
      source: .bundledProductionAsset(name: "SyntheticInstall"),
      loadedRoot: makeSyntheticArchitecture(size: [58, 31, 64]),
      anchor: world.entities.environment,
      spatial: spatial,
      descriptor: .canonicalAxes
    )

    try world.installGarageArchitectureAdapter(adapter)

    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertTrue(adapter.rig.normalizationRoot.parent === world.entities.environment)
    XCTAssertNil(world.proceduralGarageArchitectureAdapter.rig.normalizationRoot.parent)
    XCTAssertEqual(world.entities.desk.position, spatial.anchors.desk.position)
    XCTAssertEqual(world.entities.founderAnchor.position, spatial.anchors.founder.position)
    XCTAssertEqual(
      world.entities.camera.position,
      world.cameraController.playerSpatialState.eyePosition
    )
    XCTAssertEqual(spatial.occupiedZones.garageDoorClearance, FounderGarageSpatialSpecification.pass6Prototype.occupiedZones.garageDoorClearance)
    XCTAssertEqual(spatial.walkableRegion.boundary, FounderGarageSpatialSpecification.pass6Prototype.walkableRegion.boundary)
  }

  @MainActor
  func testArchitectureIdentitySurvivesPresentationAndGarageAttachments() {
    let world = FounderGarageRealityWorld()
    let identities = world.entities.identitySnapshot
    let architectureRootID = world.activeGarageArchitectureAdapter.rig.normalizationRoot.id
    var attachment: Entity?

    world.attachRoot { attachment = $0 }
    world.apply(makePresentation(), reduceMotion: true)
    world.apply(makePresentation(), reduceMotion: false)

    XCTAssertTrue(attachment === world.entities.root)
    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertEqual(world.activeGarageArchitectureAdapter.rig.normalizationRoot.id, architectureRootID)
    XCTAssertEqual(world.diagnostics.constructionCount, 1)
    XCTAssertEqual(world.activeAccessibilitySubscriptionCount, 0)
  }

  @MainActor
  func testArchitectureLoadIsDeduplicatedAndInstalledOnce() async throws {
    let world = FounderGarageRealityWorld()
    let loader = ControlledGarageArchitectureLoader()
    let source = FounderGarageArchitectureSource.bundledProductionAsset(name: "SyntheticDeduplication")

    let first = try XCTUnwrap(
      world.requestGarageArchitecture(source, descriptor: .canonicalAxes, loader: loader)
    )
    await loader.waitUntilStarted()
    let second = try XCTUnwrap(
      world.requestGarageArchitecture(source, descriptor: .canonicalAxes, loader: loader)
    )

    XCTAssertEqual(loader.callCount, 1)
    XCTAssertEqual(world.architectureLoadDiagnostics.loaderInvocationCount, 1)
    XCTAssertEqual(world.architectureLoadDiagnostics.duplicateRequestCount, 1)
    loader.succeed(with: makeSyntheticArchitecture(size: [58, 31, 64]))
    await first.value
    await second.value

    XCTAssertEqual(world.architectureLoadState, .ready(source))
    XCTAssertEqual(world.architectureLoadDiagnostics.successfulInstallationCount, 1)
    XCTAssertEqual(world.activeGarageArchitectureAdapter.source, source)
  }

  @MainActor
  func testArchitectureLoadFailureRetainsUsableProceduralGarage() async throws {
    let world = FounderGarageRealityWorld()
    let identities = world.entities.identitySnapshot
    let loader = ImmediateGarageArchitectureLoader(result: .failure(TestLoaderError.expectedFailure))
    let source = FounderGarageArchitectureSource.bundledProductionAsset(name: "MissingGarage")
    let task = try XCTUnwrap(
      world.requestGarageArchitecture(source, descriptor: .canonicalAxes, loader: loader)
    )

    await task.value

    guard case .failed(let failedSource, let message) = world.architectureLoadState else {
      return XCTFail("Expected a bounded architecture load failure")
    }
    XCTAssertEqual(failedSource, source)
    XCTAssertTrue(message.contains("expectedFailure"))
    XCTAssertEqual(world.activeGarageArchitectureAdapter.source, .procedural)
    XCTAssertTrue(world.proceduralGarageArchitectureAdapter.rig.normalizationRoot.parent === world.entities.environment)
    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)
  }

  @MainActor
  func testArchitectureContainsNoInputCollisionOrGameplayComponents() {
    let world = FounderGarageRealityWorld()
    let architectureEntities = descendants(including: world.activeGarageArchitectureAdapter.rig.visualRoot)

    for entity in architectureEntities {
      XCTAssertNil(entity.components[InputTargetComponent.self], entity.name)
      XCTAssertNil(entity.components[CollisionComponent.self], entity.name)
      XCTAssertNil(entity.components[PhysicsBodyComponent.self], entity.name)
    }
    XCTAssertNotNil(world.entities.founderComputerInteractionTarget.components[InputTargetComponent.self])
    XCTAssertNotNil(world.entities.founderComputerInteractionTarget.components[CollisionComponent.self])
  }

  @MainActor
  func testArchitectureSelectionDoesNotMutateCanonicalSimulation() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()

    world.restoreProceduralGarageArchitecture()
    _ = world.requestGarageArchitecture(.procedural)

    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(world.activeGarageArchitectureAdapter.source, .procedural)
    XCTAssertEqual(world.interaction(for: world.entities.signalTV), nil)
    XCTAssertEqual(world.interaction(for: world.entities.fundingBoard), nil)
    XCTAssertEqual(world.interaction(for: world.entities.garageDoor), nil)
  }

  func testSpatialConventionUsesMetersAndOneInwardAxis() {
    XCTAssertEqual(FounderGarageSpatialSpecification.metersPerRealityKitUnit, 1)
    XCTAssertEqual(FounderGarageSpatialSpecification.inwardDirection, SIMD3<Float>(0, 0, -1))

    let spatial = FounderGarageSpatialSpecification.standard
    XCTAssertGreaterThan(spatial.room.width, 0)
    XCTAssertGreaterThan(spatial.room.depth, spatial.room.width)
    XCTAssertEqual(spatial.architecture.garageDoor.facingDirection, [0, 0, -1])
    XCTAssertEqual(spatial.architecture.rearWall.facingDirection, [0, 0, 1])
  }

  func testCompactGarageDimensionsAndDoorOpeningArePhysicallyPlausible() {
    let spatial = FounderGarageSpatialSpecification.standard

    XCTAssertEqual(spatial.contractIdentity, .facilityTier0Production)
    XCTAssertEqual(spatial.room.width, 5.00)
    XCTAssertEqual(spatial.room.depth, 5.50)
    XCTAssertEqual(spatial.room.wallHeight, 2.70)
    XCTAssertLessThan(spatial.room.doorOpeningWidth, spatial.room.width)
    XCTAssertLessThan(spatial.room.doorOpeningHeight, spatial.room.wallHeight)
    XCTAssertEqual(spatial.room.doorTravelDirection, [0, 1, 0])
    XCTAssertTrue(spatial.validationFailures.isEmpty, spatial.validationFailures.joined(separator: ", "))
  }

  func testArchitecturalAnchorsDefineOneRoomBoundary() {
    let spatial = FounderGarageSpatialSpecification.standard
    let room = spatial.room

    XCTAssertEqual(spatial.architecture.floor.position.y, -room.floorThickness / 2, accuracy: 0.0001)
    XCTAssertEqual(spatial.architecture.rearWall.position.z, -room.depth / 2 - room.wallThickness / 2, accuracy: 0.0001)
    XCTAssertEqual(spatial.architecture.leftWall.position.x, -room.width / 2 - room.wallThickness / 2, accuracy: 0.0001)
    XCTAssertEqual(spatial.architecture.rightWall.position.x, room.width / 2 + room.wallThickness / 2, accuracy: 0.0001)
    XCTAssertLessThan(spatial.architecture.ceilingBeam.position.y, room.ceilingHeight)
    XCTAssertEqual(spatial.architecture.garageDoor.position.z, room.depth / 2, accuracy: 0.0001)
  }

  func testWorkstationRelationshipsSupportASeatedFounder() {
    let spatial = FounderGarageSpatialSpecification.standard
    let desk = spatial.workstation

    XCTAssertTrue((0.70...0.85).contains(desk.deskHeight))
    XCTAssertEqual(desk.deskSize.x, 1.85, accuracy: 0.0001)
    XCTAssertGreaterThan(desk.deskSize.z, 0.7)
    XCTAssertEqual(desk.desktopSurfaceHeight, desk.deskHeight, accuracy: 0.0001)
    XCTAssertEqual(spatial.anchors.chair.position.x, spatial.anchors.founder.position.x, accuracy: 0.0001)
    XCTAssertLessThan(abs(spatial.anchors.chair.position.z - spatial.anchors.founder.position.z), 0.15)
    XCTAssertGreaterThan(spatial.anchors.founder.position.z, spatial.occupiedZones.desk.maxZ)
    XCTAssertEqual(spatial.anchors.founder.facingDirection.x, 0.7823, accuracy: 0.001)
    XCTAssertEqual(spatial.anchors.founder.facingDirection.z, -0.6229, accuracy: 0.001)
  }

  func testComputerPhoneAndTabletAreSupportedByDesktop() {
    let spatial = FounderGarageSpatialSpecification.standard
    let desk = spatial.occupiedZones.desk

    for anchor in [spatial.anchors.founderComputer, spatial.anchors.iPhone, spatial.anchors.iPad] {
      XCTAssertTrue(desk.contains([anchor.position.x, anchor.position.z]))
    }
    XCTAssertEqual(
      spatial.anchors.iPhone.position.y,
      spatial.workstation.desktopSurfaceHeight + spatial.workstation.iPhoneSize.y / 2,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      spatial.anchors.iPad.position.y,
      spatial.workstation.desktopSurfaceHeight + spatial.workstation.iPadSize.y / 2,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      spatial.anchors.founderComputer.facingDirection,
      -spatial.anchors.founder.facingDirection
    )
  }

  func testMediaAndGarageDoorOccupyTheirExpectedWalls() {
    let spatial = FounderGarageSpatialSpecification.standard
    let rearWallFrontZ = spatial.architecture.rearWall.position.z + spatial.room.wallThickness / 2

    XCTAssertEqual(spatial.anchors.signalTV.position.z, rearWallFrontZ + spatial.media.signalTV.z / 2, accuracy: 0.0001)
    XCTAssertEqual(spatial.anchors.fundingBoard.position.z, rearWallFrontZ + spatial.media.fundingBoard.z / 2, accuracy: 0.0001)
    XCTAssertLessThan(spatial.anchors.signalTV.position.x, 0)
    XCTAssertGreaterThan(spatial.anchors.fundingBoard.position.x, 0)
    XCTAssertEqual(spatial.anchors.signalTV.facingDirection, [0, 0, 1])
    XCTAssertEqual(spatial.anchors.fundingBoard.facingDirection, [0, 0, 1])
    XCTAssertEqual(spatial.architecture.garageDoor.position.y, spatial.room.doorOpeningHeight / 2, accuracy: 0.0001)
  }

  func testOccupiedZonesFitAndWalkableRegionExcludesFurniture() {
    let spatial = FounderGarageSpatialSpecification.standard
    let room = spatial.room.interiorBounds

    XCTAssertTrue(room.contains(spatial.occupiedZones.founderWork))
    XCTAssertTrue(room.contains(spatial.occupiedZones.desk))
    XCTAssertTrue(room.contains(spatial.occupiedZones.chair))
    XCTAssertTrue(room.contains(spatial.occupiedZones.wallMedia))
    XCTAssertTrue(room.contains(spatial.occupiedZones.garageDoorClearance))
    XCTAssertFalse(spatial.walkableRegion.contains(spatial.occupiedZones.desk.center))
    XCTAssertFalse(spatial.walkableRegion.contains(spatial.occupiedZones.chair.center))
    XCTAssertTrue(spatial.walkableRegion.contains([0, 1.2]))
  }

  @MainActor
  func testFutureApproachesUseObjectFacingAndDistanceLanguageWithoutNewInteractions() {
    let spatial = FounderGarageSpatialSpecification.standard
    let approaches = [
      spatial.interactionApproaches.founderComputer,
      spatial.interactionApproaches.signalTV,
      spatial.interactionApproaches.fundingBoard,
      spatial.interactionApproaches.garageDoor
    ]

    for approach in approaches {
      XCTAssertLessThan(simd_dot(approach.object.facingDirection, approach.approach.facingDirection), -0.75)
      XCTAssertGreaterThan(approach.distance.rawValue, 0)
    }
    XCTAssertEqual(Set(FounderGarageInteractionDistance.allCases.map(\.rawValue)).count, 3)

    let world = FounderGarageRealityWorld()
    XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)
    XCTAssertNil(world.interaction(for: world.entities.signalTV))
    XCTAssertNil(world.interaction(for: world.entities.fundingBoard))
    XCTAssertNil(world.interaction(for: world.entities.garageDoor))
  }

  func testHumanScaleEnvelopeClearsDeskAndCeiling() {
    let spatial = FounderGarageSpatialSpecification.standard

    XCTAssertGreaterThanOrEqual(spatial.humanScale.minimumStandingHeight, 1.5)
    XCTAssertLessThanOrEqual(spatial.humanScale.maximumStandingHeight, 2.0)
    XCTAssertLessThan(spatial.humanScale.maximumStandingHeight, spatial.room.ceilingHeight)
    XCTAssertLessThan(spatial.anchors.founder.position.y + spatial.humanScale.seatedHeadHeight, spatial.room.ceilingHeight)
    XCTAssertGreaterThan(spatial.walkableRegion.boundary.size.x, spatial.workstation.deskSize.x)
  }

  func testFixedCameraLooksThroughDoorTowardWorkZone() {
    let spatial = FounderGarageSpatialSpecification.standard
    let cameraXZ = SIMD2(spatial.anchors.camera.position.x, spatial.anchors.camera.position.z)
    let cameraForward = simd_normalize(spatial.anchors.cameraTarget - spatial.anchors.camera.position)
    let workCenter = SIMD3<Float>(
      spatial.occupiedZones.founderWork.center.x,
      spatial.anchors.cameraTarget.y,
      spatial.occupiedZones.founderWork.center.y
    )

    XCTAssertTrue(spatial.cameraViewingRegion.contains(cameraXZ))
    XCTAssertGreaterThan(simd_dot(cameraForward, FounderGarageSpatialSpecification.inwardDirection), 0.70)
    XCTAssertLessThan(cameraForward.x, -0.50)
    XCTAssertGreaterThan(simd_dot(cameraForward, workCenter - spatial.anchors.camera.position), 0)
    XCTAssertGreaterThan(spatial.anchors.camera.position.z, spatial.room.depth / 2)
    XCTAssertTrue((45...65).contains(spatial.cameraFieldOfViewDegrees))
  }

  @MainActor
  func testWorldConstructsOnceFromSpatialSpecificationAndRetainsAnchorIdentity() {
    let spatial = FounderGarageSpatialSpecification.standard
    let world = FounderGarageRealityWorld(spatialSpecification: spatial)
    let identities = world.entities.identitySnapshot

    XCTAssertEqual(world.entities.desk.position, spatial.anchors.desk.position)
    XCTAssertEqual(world.entities.chair.position, spatial.anchors.chair.position)
    XCTAssertEqual(world.entities.founderAnchor.position, spatial.anchors.founder.position)
    XCTAssertEqual(world.entities.founderComputer.position, spatial.anchors.founderComputer.position)
    XCTAssertEqual(world.entities.iPhone.position, spatial.anchors.iPhone.position)
    XCTAssertEqual(world.entities.iPad.position, spatial.anchors.iPad.position)
    XCTAssertEqual(world.entities.signalTV.position, spatial.anchors.signalTV.position)
    XCTAssertEqual(world.entities.fundingBoard.position, spatial.anchors.fundingBoard.position)
    XCTAssertEqual(world.entities.garageDoor.position, spatial.architecture.garageDoor.position)
    XCTAssertEqual(world.entities.camera.camera.fieldOfViewInDegrees, world.cameraController.recipe(for: .founderPOV).fieldOfView, accuracy: 0.0001)

    world.apply(makePresentation(), reduceMotion: true)
    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertEqual(world.diagnostics.constructionCount, 1)
  }

  func testRealityKitRendererIsProductionDefaultWithExplicitLegacyFallback() {
    XCTAssertEqual(
      FounderGarageRendererConfiguration.resolve(
        arguments: ["Solo Unicorn Run", FounderGarageRendererConfiguration.prototypeLaunchArgument],
        environment: [:],
        prototypeAllowed: true
      ),
      .realityKitPrototype
    )
    XCTAssertEqual(
      FounderGarageRendererConfiguration.resolve(
        arguments: ["Solo Unicorn Run", FounderGarageRendererConfiguration.legacyLaunchArgument],
        environment: [:],
        prototypeAllowed: true
      ),
      .swiftUI
    )
    XCTAssertEqual(
      FounderGarageRendererConfiguration.resolve(
        arguments: ["Solo Unicorn Run"],
        environment: [:],
        prototypeAllowed: true
      ),
      .realityKitPrototype
    )
  }

  func testFounderDeskDeviceEntitiesMapToCanonicalInteractionIntents() {
    XCTAssertEqual(
      FounderWorldInteractionAdapter.interaction(
        forEntityNamed: FounderWorldInteractionAdapter.founderComputerEntityName
      ),
      .openFounderComputer
    )
    XCTAssertEqual(
      FounderWorldInteractionAdapter.interaction(
        forEntityNamed: FounderWorldInteractionAdapter.founderPhoneEntityName
      ),
      .openFounderPhone
    )
    XCTAssertEqual(
      FounderWorldInteractionAdapter.interaction(
        forEntityNamed: FounderWorldInteractionAdapter.founderTabletEntityName
      ),
      .openFounderTablet
    )
    XCTAssertNil(FounderWorldInteractionAdapter.interaction(forEntityNamed: "FundingBoard"))
  }

  func testFounderComputerSemanticIdentityIsStable() {
    XCTAssertEqual(
      FounderGarageAccessibilityID.founderComputer,
      "founderGarage.realityKit.founderComputer"
    )
    XCTAssertEqual(
      FounderWorldInteractionAdapter.founderComputerAccessibilityLabel,
      "Founder Computer"
    )
  }

  @MainActor
  func testRegisteredFounderDeskDevicesHaveNativeAccessibilityAndInputSemantics() {
    let world = FounderGarageRealityWorld()
    for device in [
      world.entities.founderComputerInteractionTarget,
      world.entities.iPhone,
      world.entities.iPad
    ] {
      let accessibility = device.components[AccessibilityComponent.self]
      XCTAssertEqual(accessibility?.isAccessibilityElement, true)
      XCTAssertEqual(accessibility?.traits.contains(.button), true)
      XCTAssertEqual(accessibility?.systemActions.contains(.activate), true)
      XCTAssertNotNil(device.components[InputTargetComponent.self])
      XCTAssertNotNil(device.components[CollisionComponent.self])
    }
  }

  @MainActor
  func testFounderDeskDeviceGeometryIsFlatDistinctAndNonOverlapping() throws {
    let spatial = FounderGarageSpatialSpecification.standard
    let phone = spatial.workstation.iPhoneSize
    let tablet = spatial.workstation.iPadSize
    let phonePose = spatial.anchors.iPhone.position
    let tabletPose = spatial.anchors.iPad.position

    XCTAssertGreaterThan(phone.z, phone.x)
    XCTAssertLessThan(phone.y, phone.x * 0.15)
    XCTAssertGreaterThan(tablet.x, tablet.z)
    XCTAssertLessThan(tablet.y, tablet.z * 0.10)
    let separatedOnX = abs(phonePose.x - tabletPose.x) >= (phone.x + tablet.x) / 2
    let separatedOnZ = abs(phonePose.z - tabletPose.z) >= (phone.z + tablet.z) / 2
    XCTAssertTrue(separatedOnX || separatedOnZ)

    let world = FounderGarageRealityWorld()
    XCTAssertEqual(world.entities.iPhone.name, FounderWorldInteractionAdapter.founderPhoneEntityName)
    XCTAssertEqual(world.entities.iPad.name, FounderWorldInteractionAdapter.founderTabletEntityName)
    XCTAssertNotNil(world.entities.iPhone.findEntity(named: "FounderPhone.Screen"))
    XCTAssertNotNil(world.entities.iPad.findEntity(named: "FounderTablet.Screen"))
    XCTAssertEqual(world.interaction(for: world.entities.iPhone), .openFounderPhone)
    XCTAssertEqual(world.interaction(for: world.entities.iPad), .openFounderTablet)
  }

  @MainActor
  func testFounderDeskDeviceIntentsUseExistingNavigationWithoutSimulationMutation() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    var navigation = FounderDeskNavigationState()

    XCTAssertNil(navigation.select(.phone))
    XCTAssertEqual(navigation.selection, .device(.phone))
    navigation.closeSecondaryDevice()
    XCTAssertNil(navigation.select(.tablet))
    XCTAssertEqual(navigation.selection, .device(.tablet))
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  @MainActor
  func testWorldConstructsOneCompleteRegistryAcrossAttachments() {
    let world = FounderGarageRealityWorld()
    var firstAttachment: Entity?
    var secondAttachment: Entity?

    world.attachRoot { firstAttachment = $0 }
    world.attachRoot { secondAttachment = $0 }

    XCTAssertTrue(world.entities.validateIntegrity())
    XCTAssertTrue(firstAttachment === world.entities.root)
    XCTAssertTrue(secondAttachment === world.entities.root)
    XCTAssertEqual(world.diagnostics.constructionCount, 1)
    XCTAssertEqual(world.diagnostics.attachmentCount, 2)
  }

  @MainActor
  func testRegisteredEntityIdentitiesRemainStableAcrossPresentationUpdates() {
    let world = FounderGarageRealityWorld()
    let initial = makePresentation()
    var updated = initial
    updated.founderState = initial.founderState == .lowEnergy ? .stressed : .lowEnergy
    updated.roomLightIntensity = initial.roomLightIntensity < 0.7 ? 0.9 : 0.4
    let identities = world.entities.identitySnapshot

    world.apply(initial, reduceMotion: true)
    world.apply(updated, reduceMotion: true)
    world.apply(updated, reduceMotion: true)

    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertEqual(world.diagnostics.constructionCount, 1)
    XCTAssertEqual(world.diagnostics.presentationApplicationCount, 2)
  }

  @MainActor
  func testPresentationUpdatesMutateRegisteredEntitiesWithoutReconstruction() {
    let world = FounderGarageRealityWorld()
    let initial = makePresentation()
    world.apply(initial, reduceMotion: true)
    let identities = world.entities.identitySnapshot
    let initialLightIntensity = world.entities.keyLight.light.intensity

    var updated = initial
    updated.founderState = initial.founderState == .lowEnergy ? .stressed : .lowEnergy
    updated.roomLightIntensity = initial.roomLightIntensity < 0.7 ? 0.9 : 0.4
    world.apply(updated, reduceMotion: true)

    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertEqual(world.entities.founderAnchor.position, world.spatialSpecification.anchors.founder.position)
    let recipe = try! XCTUnwrap(ProceduralFounderPresentationRecipe.recipe(for: updated.founderState))
    assertTransform(world.proceduralFounderVisualAdapter.rig.bodyTarget.transform, equals: recipe.torsoTransform)
    assertTransform(world.proceduralFounderVisualAdapter.rig.headTarget!.transform, equals: recipe.headTransform)
    XCTAssertNotEqual(world.entities.keyLight.light.intensity, initialLightIntensity)
    XCTAssertEqual(
      world.entities.keyLight.light.intensity,
      Float(26_000 * updated.roomLightIntensity),
      accuracy: 0.001
    )
  }

  @MainActor
  func testPresentationRecipesCoverOnlyCanonicallyDerivedStates() throws {
    let expected: [(FounderPresentationState, ProceduralFounderPresentationMaterial, TimeInterval)] = [
      (.seatedIdle, .jacket, 0.24),
      (.typing, .jacket, 0.22),
      (.reviewing, .review, 0.26),
      (.lowEnergy, .lowEnergy, 0.30),
      (.stressed, .stressed, 0.18)
    ]

    for (state, material, duration) in expected {
      let recipe = try XCTUnwrap(ProceduralFounderPresentationRecipe.recipe(for: state))
      XCTAssertEqual(recipe.state, state)
      XCTAssertEqual(recipe.material, material)
      XCTAssertEqual(recipe.duration, duration, accuracy: 0.001)
      XCTAssertEqual(recipe.timing, .easeInOut)
      XCTAssertEqual(recipe.torsoTransform.scale, .one)
      XCTAssertEqual(recipe.headTransform.scale, .one)
    }

    XCTAssertNil(ProceduralFounderPresentationRecipe.recipe(for: .standing))
    XCTAssertNil(ProceduralFounderPresentationRecipe.recipe(for: .walking))
    XCTAssertNil(ProceduralFounderPresentationRecipe.recipe(for: .interacting))
  }

  @MainActor
  func testReducedMotionStateTransitionsUseAbsoluteTargetsAndStableEntities() throws {
    let world = FounderGarageRealityWorld()
    let identities = world.entities.identitySnapshot
    let controllerIdentities = world.founderPresentationController.targetIdentitySnapshot
    let unrelatedEntityIDs = [
      world.entities.root.id,
      world.entities.desk.id,
      world.entities.chair.id,
      world.entities.founderComputer.id,
      world.entities.founderComputerInteractionTarget.id,
      world.entities.iPhone.id,
      world.entities.iPad.id,
      world.entities.signalTV.id,
      world.entities.fundingBoard.id,
      world.entities.camera.id,
      world.entities.keyLight.id,
      world.entities.fillLight.id,
      world.entities.hangingPracticalLight.id,
      world.entities.deskPracticalLight.id
    ]
    let transitions: [(FounderPresentationState, FounderPresentationState)] = [
      (.seatedIdle, .typing),
      (.typing, .reviewing),
      (.reviewing, .seatedIdle),
      (.seatedIdle, .lowEnergy),
      (.seatedIdle, .stressed),
      (.stressed, .seatedIdle)
    ]

    for (source, target) in transitions {
      for state in [source, target] {
        var presentation = makePresentation()
        presentation.founderState = state
        world.apply(presentation, reduceMotion: true)

        let recipe = try XCTUnwrap(ProceduralFounderPresentationRecipe.recipe(for: state))
        assertTransform(world.proceduralFounderVisualAdapter.rig.bodyTarget.transform, equals: recipe.torsoTransform)
        assertTransform(world.proceduralFounderVisualAdapter.rig.headTarget!.transform, equals: recipe.headTransform)
        XCTAssertEqual(world.entities.founderAnchor.position, world.spatialSpecification.anchors.founder.position)
      }
    }

    XCTAssertEqual(world.entities.identitySnapshot, identities)
    XCTAssertEqual(
      unrelatedEntityIDs,
      [
        world.entities.root.id,
        world.entities.desk.id,
        world.entities.chair.id,
        world.entities.founderComputer.id,
        world.entities.founderComputerInteractionTarget.id,
        world.entities.iPhone.id,
        world.entities.iPad.id,
        world.entities.signalTV.id,
        world.entities.fundingBoard.id,
        world.entities.camera.id,
        world.entities.keyLight.id,
        world.entities.fillLight.id,
        world.entities.hangingPracticalLight.id,
        world.entities.deskPracticalLight.id
      ]
    )
    XCTAssertEqual(
      controllerIdentities,
      world.proceduralFounderVisualAdapter.rig.identitySnapshot
    )
    XCTAssertEqual(world.diagnostics.constructionCount, 1)
    XCTAssertEqual(world.diagnostics.subscriptionInstallationCount, 0)
  }

  @MainActor
  func testEqualStateRequestDoesNotRestartPresentation() {
    let world = FounderGarageRealityWorld()
    let controller = world.founderPresentationController

    controller.transition(to: .typing, reduceMotion: true)
    let transform = world.proceduralFounderVisualAdapter.rig.bodyTarget.transform
    controller.transition(to: .typing, reduceMotion: true)

    XCTAssertEqual(controller.diagnostics.applicationCount, 1)
    XCTAssertEqual(controller.diagnostics.redundantRequestCount, 1)
    assertTransform(world.proceduralFounderVisualAdapter.rig.bodyTarget.transform, equals: transform)
  }

  @MainActor
  func testRapidRetargetMakesNewestStateAuthoritative() throws {
    let world = FounderGarageRealityWorld()
    let controller = world.founderPresentationController
    let identities = world.entities.identitySnapshot

    controller.transition(to: .seatedIdle, reduceMotion: false)
    controller.transition(to: .typing, reduceMotion: false)
    controller.transition(to: .stressed, reduceMotion: true)

    let stressed = try XCTUnwrap(ProceduralFounderPresentationRecipe.recipe(for: .stressed))
    XCTAssertEqual(controller.diagnostics.lastRequestedState, .stressed)
    XCTAssertEqual(controller.diagnostics.lastAppliedState, .stressed)
    XCTAssertEqual(controller.diagnostics.applicationCount, 3)
    assertTransform(world.proceduralFounderVisualAdapter.rig.bodyTarget.transform, equals: stressed.torsoTransform)
    assertTransform(world.proceduralFounderVisualAdapter.rig.headTarget!.transform, equals: stressed.headTransform)
    XCTAssertEqual(world.entities.identitySnapshot, identities)
  }

  @MainActor
  func testUnsupportedExtensionStatesDoNotMutateFounderPresentation() {
    let world = FounderGarageRealityWorld()
    let controller = world.founderPresentationController
    controller.transition(to: .seatedIdle, reduceMotion: true)
    let torso = world.proceduralFounderVisualAdapter.rig.bodyTarget.transform
    let head = world.proceduralFounderVisualAdapter.rig.headTarget!.transform

    controller.transition(to: .standing, reduceMotion: false)
    controller.transition(to: .walking, reduceMotion: false)
    controller.transition(to: .interacting, reduceMotion: false)

    XCTAssertEqual(controller.diagnostics.unsupportedRequestCount, 3)
    XCTAssertEqual(controller.diagnostics.lastAppliedState, .seatedIdle)
    assertTransform(world.proceduralFounderVisualAdapter.rig.bodyTarget.transform, equals: torso)
    assertTransform(world.proceduralFounderVisualAdapter.rig.headTarget!.transform, equals: head)
  }

  @MainActor
  func testProceduralAdapterExposesStableRigWithPass4VisualParity() throws {
    let world = FounderGarageRealityWorld()
    let adapter = world.proceduralFounderVisualAdapter
    let idle = try XCTUnwrap(ProceduralFounderPresentationRecipe.recipe(for: .seatedIdle))

    XCTAssertEqual(adapter.source, .procedural)
    XCTAssertTrue(adapter.rig.anchor === world.entities.founderAnchor)
    XCTAssertTrue(adapter.rig.normalizationRoot.parent === world.entities.founderAnchor)
    XCTAssertTrue(adapter.rig.visualRoot.parent === adapter.rig.normalizationRoot)
    XCTAssertTrue(adapter.rig.bodyTarget.parent === adapter.rig.visualRoot)
    XCTAssertTrue(adapter.rig.headTarget?.parent === adapter.rig.visualRoot)
    XCTAssertEqual(
      adapter.capabilities,
      FounderVisualCapabilities(
        hasBodyTarget: true,
        hasHeadTarget: true,
        availableAnimationCount: 0
      )
    )
    assertTransform(adapter.rig.bodyTarget.transform, equals: idle.torsoTransform)
    assertTransform(try XCTUnwrap(adapter.rig.headTarget).transform, equals: idle.headTransform)
  }

  @MainActor
  func testSyntheticImportedHierarchyResolvesRigOnceAndControllerUsesAdapter() throws {
    let fixture = makeSyntheticImportedHierarchy()
    let anchor = Entity()
    let normalization = Transform(
      scale: [0.72, 0.72, 0.72],
      rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]),
      translation: [0.03, -0.08, 0.02]
    )
    let source = FounderVisualSource.bundledUSDZ(name: "SyntheticFounder")
    let adapter = try USDZFounderVisualAdapter(
      source: source,
      loadedRoot: fixture.root,
      anchor: anchor,
      descriptor: makeRigDescriptor(normalization: normalization)
    )
    anchor.addChild(adapter.rig.normalizationRoot)
    let controller = FounderPresentationController(visualAdapter: adapter)

    controller.transition(to: .typing, reduceMotion: false)
    controller.transition(to: .stressed, reduceMotion: true)

    XCTAssertEqual(adapter.source, source)
    XCTAssertTrue(adapter.rig.visualRoot === fixture.root)
    XCTAssertTrue(adapter.rig.bodyTarget === fixture.body)
    XCTAssertTrue(adapter.rig.headTarget === fixture.head)
    XCTAssertTrue(adapter.rig.normalizationRoot.parent === anchor)
    assertTransform(adapter.rig.normalizationRoot.transform, equals: normalization)
    XCTAssertEqual(adapter.capabilities.availableAnimationCount, 0)
    XCTAssertEqual(adapter.presentationCount, 2)
    XCTAssertEqual(adapter.lastIntent, FounderPresentationIntent(state: .stressed, reduceMotion: true))
    XCTAssertEqual(controller.diagnostics.lastAppliedState, .stressed)
  }

  @MainActor
  func testImportedHierarchyValidationReturnsBoundedErrorsAndAllowsMissingHead() throws {
    let anchor = Entity()
    XCTAssertThrowsError(
      try USDZFounderVisualAdapter(
        source: .bundledUSDZ(name: "Empty"),
        loadedRoot: Entity(),
        anchor: anchor,
        descriptor: makeRigDescriptor()
      )
    ) { error in
      XCTAssertEqual(error as? FounderAssetAdapterError, .invalidHierarchy)
    }

    let fixture = makeSyntheticImportedHierarchy()
    XCTAssertThrowsError(
      try USDZFounderVisualAdapter(
        source: .bundledUSDZ(name: "MissingBody"),
        loadedRoot: fixture.root,
        anchor: anchor,
        descriptor: FounderAssetRigDescriptor(
          bodyPath: ["UnknownBody"],
          headPath: nil,
          normalization: .identity
        )
      )
    ) { error in
      XCTAssertEqual(
        error as? FounderAssetAdapterError,
        .missingBodyTarget(path: ["UnknownBody"])
      )
    }

    let noHeadFixture = makeSyntheticImportedHierarchy()
    let adapter = try USDZFounderVisualAdapter(
      source: .bundledUSDZ(name: "OptionalHead"),
      loadedRoot: noHeadFixture.root,
      anchor: anchor,
      descriptor: FounderAssetRigDescriptor(
        bodyPath: ["SkeletonOrBodyContainer", "BodyMesh"],
        headPath: ["UnavailableHead"],
        normalization: .identity
      )
    )
    XCTAssertNil(adapter.rig.headTarget)
    XCTAssertFalse(adapter.capabilities.hasHeadTarget)
  }

  @MainActor
  func testInjectedLoaderSuccessInstallsImportedVisualWithoutChangingGarageIdentity() async throws {
    let world = FounderGarageRealityWorld()
    var presentation = makePresentation()
    presentation.founderState = .typing
    world.apply(presentation, reduceMotion: true)
    let garageIdentities = world.entities.identitySnapshot
    let proceduralVisualID = world.proceduralFounderVisualAdapter.rig.visualRoot.id
    let fixture = makeSyntheticImportedHierarchy()
    let loader = ImmediateFounderAssetLoader(result: .success(fixture.root))
    let source = FounderVisualSource.bundledUSDZ(name: "SyntheticSuccess")
    let normalization = Transform(
      scale: [0.8, 0.8, 0.8],
      rotation: simd_quatf(angle: 0.25, axis: [0, 1, 0]),
      translation: [0, -0.1, 0]
    )

    XCTAssertEqual(world.assetLoadState, .notRequested)
    let task = try XCTUnwrap(
      world.requestFounderVisual(
        source,
        descriptor: makeRigDescriptor(normalization: normalization),
        loader: loader
      )
    )
    XCTAssertEqual(world.assetLoadState, .loading(source))
    await task.value

    let adapter = try XCTUnwrap(world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)
    XCTAssertEqual(world.assetLoadState, .ready(source))
    XCTAssertEqual(loader.callCount, 1)
    XCTAssertEqual(world.assetLoadDiagnostics.successfulInstallationCount, 1)
    XCTAssertEqual(world.entities.identitySnapshot, garageIdentities)
    XCTAssertEqual(world.entities.founderAnchor.id, garageIdentities.founderAnchor)
    XCTAssertNotEqual(adapter.rig.visualRoot.id, proceduralVisualID)
    XCTAssertTrue(adapter.rig.normalizationRoot.parent === world.entities.founderAnchor)
    XCTAssertNil(world.proceduralFounderVisualAdapter.rig.normalizationRoot.parent)
    assertTransform(adapter.rig.normalizationRoot.transform, equals: normalization)
    XCTAssertEqual(adapter.lastIntent, FounderPresentationIntent(state: .typing, reduceMotion: true))
    XCTAssertEqual(world.diagnostics.constructionCount, 1)
    XCTAssertEqual(world.diagnostics.subscriptionInstallationCount, 0)
  }

  @MainActor
  func testInjectedLoaderFailureKeepsProceduralFallbackAndComputerInteraction() async throws {
    let world = FounderGarageRealityWorld()
    let store = GameStore()
    let canonicalBefore = CanonicalSnapshot(store: store)
    let garageIdentities = world.entities.identitySnapshot
    let proceduralRig = world.proceduralFounderVisualAdapter.rig.identitySnapshot
    let previousFixture = makeSyntheticImportedHierarchy()
    let previousAdapter = try USDZFounderVisualAdapter(
      source: .bundledUSDZ(name: "PreviouslyInstalled"),
      loadedRoot: previousFixture.root,
      anchor: world.entities.founderAnchor,
      descriptor: makeRigDescriptor()
    )
    try world.installFounderVisualAdapter(previousAdapter)
    XCTAssertEqual(world.activeFounderVisualAdapter.source, .bundledUSDZ(name: "PreviouslyInstalled"))
    let loader = ImmediateFounderAssetLoader(result: .failure(TestLoaderError.expectedFailure))
    let source = FounderVisualSource.bundledUSDZ(name: "SyntheticFailure")

    let task = try XCTUnwrap(
      world.requestFounderVisual(
        source,
        descriptor: makeRigDescriptor(),
        loader: loader
      )
    )
    await task.value

    guard case .failed(let failedSource, let message) = world.assetLoadState else {
      return XCTFail("Expected presentation-only failed load state")
    }
    XCTAssertEqual(failedSource, source)
    XCTAssertTrue(message.contains("expectedFailure"))
    XCTAssertEqual(world.assetLoadDiagnostics.failedLoadCount, 1)
    XCTAssertEqual(world.activeFounderVisualAdapter.source, .procedural)
    XCTAssertEqual(world.activeFounderVisualAdapter.rig.identitySnapshot, proceduralRig)
    XCTAssertEqual(world.entities.identitySnapshot, garageIdentities)
    XCTAssertEqual(CanonicalSnapshot(store: store), canonicalBefore)
    XCTAssertEqual(
      world.interaction(for: world.entities.founderComputerInteractionTarget),
      .openFounderComputer
    )
  }

  @MainActor
  func testRepeatedAssetRequestIsDeduplicatedWithoutSleep() async throws {
    let world = FounderGarageRealityWorld()
    let loader = ControlledFounderAssetLoader()
    let source = FounderVisualSource.bundledUSDZ(name: "SyntheticDeduplication")
    let descriptor = makeRigDescriptor()

    let first = try XCTUnwrap(
      world.requestFounderVisual(source, descriptor: descriptor, loader: loader)
    )
    await loader.waitUntilStarted()
    let second = try XCTUnwrap(
      world.requestFounderVisual(source, descriptor: descriptor, loader: loader)
    )

    XCTAssertEqual(world.assetLoadDiagnostics.requestCount, 2)
    XCTAssertEqual(world.assetLoadDiagnostics.loaderInvocationCount, 1)
    XCTAssertEqual(world.assetLoadDiagnostics.duplicateRequestCount, 1)
    XCTAssertEqual(loader.callCount, 1)

    loader.succeed(with: makeSyntheticImportedHierarchy().root)
    await first.value
    await second.value
    XCTAssertEqual(world.assetLoadState, .ready(source))
  }

  @MainActor
  func testStaleLoadCannotReplaceNewerVisualSelection() async throws {
    let world = FounderGarageRealityWorld()
    let loaderA = ControlledFounderAssetLoader()
    let loaderB = ControlledFounderAssetLoader()
    let sourceA = FounderVisualSource.bundledUSDZ(name: "SyntheticA")
    let sourceB = FounderVisualSource.bundledUSDZ(name: "SyntheticB")

    let taskA = try XCTUnwrap(
      world.requestFounderVisual(sourceA, descriptor: makeRigDescriptor(), loader: loaderA)
    )
    await loaderA.waitUntilStarted()
    let taskB = try XCTUnwrap(
      world.requestFounderVisual(sourceB, descriptor: makeRigDescriptor(), loader: loaderB)
    )
    await loaderB.waitUntilStarted()

    let fixtureB = makeSyntheticImportedHierarchy()
    loaderB.succeed(with: fixtureB.root)
    await taskB.value
    let fixtureA = makeSyntheticImportedHierarchy()
    loaderA.succeed(with: fixtureA.root)
    await taskA.value

    XCTAssertEqual(world.assetLoadState, .ready(sourceB))
    XCTAssertEqual(world.activeFounderVisualAdapter.source, sourceB)
    XCTAssertTrue(world.activeFounderVisualAdapter.rig.visualRoot === fixtureB.root)
    XCTAssertNil(fixtureA.root.parent)
    XCTAssertEqual(world.assetLoadDiagnostics.successfulInstallationCount, 1)
    XCTAssertEqual(world.assetLoadDiagnostics.staleResultCount, 1)
  }

  @MainActor
  func testDestroyingWorldCancelsLoadAndCannotInstallIntoDeadSession() async throws {
    let loader = ControlledFounderAssetLoader()
    let source = FounderVisualSource.bundledUSDZ(name: "SyntheticLifetime")
    var world: FounderGarageRealityWorld? = FounderGarageRealityWorld()
    weak let weakWorld = world
    let task = try XCTUnwrap(
      world?.requestFounderVisual(source, descriptor: makeRigDescriptor(), loader: loader)
    )
    await loader.waitUntilStarted()

    world = nil
    XCTAssertNil(weakWorld)
    let fixture = makeSyntheticImportedHierarchy()
    loader.succeed(with: fixture.root)
    await task.value

    XCTAssertNil(fixture.root.parent)
  }

  @MainActor
  func testDeskDeviceInteractionsUseRegisteredIdentityInsteadOfEntityName() {
    let world = FounderGarageRealityWorld()
    world.entities.founderComputerInteractionTarget.name = "Renamed for identity verification"
    world.entities.iPhone.name = "Renamed phone for identity verification"
    world.entities.iPad.name = "Renamed tablet for identity verification"

    XCTAssertEqual(
      world.interaction(for: world.entities.founderComputerInteractionTarget),
      .openFounderComputer
    )
    XCTAssertEqual(world.interaction(for: world.entities.iPhone), .openFounderPhone)
    XCTAssertEqual(world.interaction(for: world.entities.iPad), .openFounderTablet)
  }

  @MainActor
  func testPresentationDerivationDoesNotMutateCanonicalState() {
    let store = GameStore()
    let progression = FounderProgressionStore()
    let presentation = PresentationCoordinator(timing: .immediate)
    let before = CanonicalSnapshot(store: store)

    let first = FounderWorldPresentationModel.derive(
      store: store,
      progression: progression,
      presentation: presentation
    )
    let second = FounderWorldPresentationModel.derive(
      store: store,
      progression: progression,
      presentation: presentation
    )
    let world = FounderGarageRealityWorld()
    for state in [
      FounderPresentationState.seatedIdle, .typing, .reviewing, .lowEnergy, .stressed
    ] {
      world.founderPresentationController.transition(to: state, reduceMotion: true)
    }

    XCTAssertEqual(first, second)
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertTrue(first.founderComputerAvailable)
  }

  @MainActor
  func testRendererResolutionDoesNotMutateCanonicalState() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)

    _ = FounderGarageRendererConfiguration.resolve(
      arguments: [FounderGarageRendererConfiguration.prototypeLaunchArgument],
      environment: [:],
      prototypeAllowed: true
    )
    _ = FounderGarageRendererConfiguration.resolve(
      arguments: [],
      environment: [:],
      prototypeAllowed: true
    )

    XCTAssertEqual(CanonicalSnapshot(store: store), before)
  }

  @MainActor
  func testCameraRecipesUseCanonicalAnchorsAndSafeRegion() throws {
    let world = FounderGarageRealityWorld()
    let camera = world.cameraController
    let spatial = world.spatialSpecification
    let authored = FounderGarageCameraConfiguration(spatial: spatial)
    let canonical = camera.recipe(for: .founderPOV)
    XCTAssertEqual(canonical.position, camera.playerSpatialState.eyePosition)
    XCTAssertEqual(canonical.fieldOfView, 56)
    for target in FounderGarageCameraState.allCases {
      let recipe = camera.recipe(for: target)
      XCTAssertGreaterThan(simd_distance(recipe.position, recipe.lookTarget), 1)
      XCTAssertTrue((40...65).contains(recipe.fieldOfView))
    }
    let anchors = try XCTUnwrap(spatial.productionAnchors)
    XCTAssertEqual(authored.recipe(for: .whiteboard).lookTarget, anchors.whiteboardFace)
    XCTAssertEqual(authored.recipe(for: .garageDoor).lookTarget, anchors.doorMouth + [0, 0.05, -0.05])
    XCTAssertEqual(authored.recipe(for: .garageDoor).position, anchors.doorMouth + [2.5, 1.10, 8.80])
    XCTAssertEqual(authored.recipe(for: .front).lookTarget, anchors.doorMouth + [0, 0.05, -0.05])
    XCTAssertEqual(authored.recipe(for: .front).position, anchors.doorMouth + [0, 0.25, 9.45])
    XCTAssertEqual(authored.recipe(for: .frontBay).lookTarget, anchors.agentDeskSurface + [0, 0.15, 0])
  }

  @MainActor
  func testCameraReducedMotionAndRepeatedRequestsUseExactEndpoint() {
    let world = FounderGarageRealityWorld()
    let controller = world.cameraController
    controller.transition(to: .whiteboard, reduceMotion: true)
    assertTransform(world.entities.camera.transform, equals: controller.recipe(for: .whiteboard).transform)
    controller.transition(to: .whiteboard, reduceMotion: true)
    XCTAssertEqual(controller.diagnostics.applicationCount, 1)
    controller.transition(to: .founderPOV, reduceMotion: true)
    assertTransform(world.entities.camera.transform, equals: controller.recipe(for: .founderPOV).transform)
  }

  @MainActor
  func testRapidCameraRetargetKeepsNewestIntent() {
    let controller = FounderGarageRealityWorld().cameraController
    controller.transition(to: .whiteboard, reduceMotion: false)
    controller.transition(to: .garageDoor, reduceMotion: false)
    controller.transition(to: .frontBay, reduceMotion: true)
    XCTAssertEqual(controller.state, .frontBay)
    XCTAssertEqual(controller.diagnostics.lastApplied, .frontBay)
    assertTransform(controller.camera.transform, equals: controller.recipe(for: .frontBay).transform)
  }

  @MainActor
  func testCameraPhysicsReturnsToExactFounderEndpointAcrossOneHundredCycles() {
    let controller = FounderGarageRealityWorld().cameraController
    let exact = controller.recipe(for: .founderPOV).transform
    for _ in 0..<100 {
      for destination in [FounderGarageCameraState.whiteboard, .frontBay, .garageDoor] {
        controller.transition(to: destination, reduceMotion: true)
        controller.transition(to: .founderPOV, reduceMotion: true)
      }
    }
    assertTransform(controller.camera.transform, equals: exact)
    XCTAssertEqual(controller.playerSpatialState.lookOrientation, .neutral)
  }

  @MainActor
  func testWalkingUsesAccelerationCruiseDecelerationAndExactDeskReturn() {
    let controller = FounderGarageRealityWorld().cameraController
    controller.configureWalkability { _ in true }
    controller.beginWalking()
    controller.setMovementIntent(.init(forward: 1))
    controller.advance(deltaTime: 1.0 / 60)
    let firstSpeed = simd_length(controller.snapshot.velocity)
    XCTAssertGreaterThan(firstSpeed, 0)
    XCTAssertLessThan(firstSpeed, FounderGarageCameraConfiguration.walkingSpeed)
    for _ in 0..<120 { controller.advance(deltaTime: 1.0 / 60) }
    XCTAssertEqual(simd_length(controller.snapshot.velocity), FounderGarageCameraConfiguration.walkingSpeed, accuracy: 0.002)
    controller.setMovementIntent(.idle)
    for _ in 0..<30 { controller.advance(deltaTime: 1.0 / 60) }
    XCTAssertEqual(simd_length(controller.snapshot.velocity), 0, accuracy: 0.001)
    controller.endWalking()
    assertTransform(controller.camera.transform, equals: controller.recipe(for: .founderPOV).transform)
  }

  @MainActor
  func testWalkingIsFrameRateIndependentAndClampsHitches() {
    func position(rate: Int) -> SIMD3<Float> {
      let controller = FounderGarageRealityWorld().cameraController
      controller.configureWalkability { _ in true }
      controller.beginWalking(); controller.setMovementIntent(.init(forward: 1))
      for _ in 0..<rate { controller.advance(deltaTime: 1.0 / Double(rate)) }
      return controller.snapshot.position
    }
    let p30 = position(rate: 30), p60 = position(rate: 60), p120 = position(rate: 120)
    XCTAssertLessThan(simd_distance(p30, p60), 0.025)
    XCTAssertLessThan(simd_distance(p60, p120), 0.015)
    let controller = FounderGarageRealityWorld().cameraController
    controller.configureWalkability { _ in true }; controller.beginWalking(); controller.setMovementIntent(.init(forward: 1))
    let before = controller.snapshot.position
    controller.advance(deltaTime: 2)
    XCTAssertLessThan(simd_distance(before, controller.snapshot.position), 0.06)
  }

  @MainActor
  func testCollisionProjectsAlongWallAndBlocksCorner() {
    let controller = FounderGarageRealityWorld().cameraController
    let start = controller.playerSpatialState.playerPose.position
    controller.configureWalkability { point in point.x < start.x + 0.18 && point.y < start.z + 0.18 }
    controller.beginWalking(); controller.setMovementIntent(.init(lateral: 1, forward: 1))
    for _ in 0..<60 { controller.advance(deltaTime: 1.0 / 60) }
    XCTAssertNotEqual(controller.snapshot.collision, "none")
    XCTAssertLessThanOrEqual(controller.snapshot.position.x, start.x + 0.18)
  }

  @MainActor
  func testReduceMotionLookAndCameraTransitionsAreImmediate() {
    let controller = FounderGarageRealityWorld().cameraController
    controller.transition(to: .whiteboard, reduceMotion: true)
    assertTransform(controller.camera.transform, equals: controller.recipe(for: .whiteboard).transform)
    controller.transition(to: .founderPOV, reduceMotion: true)
    controller.setLookOrientation(.init(yaw: 9, pitch: -9))
    XCTAssertEqual(controller.playerSpatialState.lookOrientation.yaw, FounderGarageCameraConfiguration.yawLimits.upperBound)
    XCTAssertEqual(controller.playerSpatialState.lookOrientation.pitch, FounderGarageCameraConfiguration.pitchLimits.lowerBound)
  }

  @MainActor
  func testSeatedFreeLookSupportsRearInspectionAndExactRecentering() {
    let controller = FounderGarageRealityWorld().cameraController
    let home = controller.recipe(for: .founderPOV).transform
    XCTAssertGreaterThan(FounderGarageCameraConfiguration.yawLimits.upperBound, 170 * .pi / 180)
    XCTAssertLessThan(FounderGarageCameraConfiguration.yawLimits.lowerBound, -170 * .pi / 180)
    for yaw in [FounderGarageCameraConfiguration.yawLimits.lowerBound,
                FounderGarageCameraConfiguration.yawLimits.upperBound] {
      controller.setLookOrientation(.init(yaw: yaw, pitch: 0))
      for _ in 0..<240 { controller.advance(deltaTime: 1.0 / 120) }
      XCTAssertEqual(controller.playerSpatialState.lookOrientation.yaw, yaw, accuracy: 0.001)
      let matrix = controller.camera.transform.matrix
      let right = SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
      XCTAssertEqual(simd_dot(right, SIMD3<Float>(0, 1, 0)), 0, accuracy: 0.0001)
      controller.recenterFounderPOV(reduceMotion: true)
      assertTransform(controller.camera.transform, equals: home, accuracy: 0.0001)
    }
  }

  func testSeatedFreeLookDragResponseIsViewportNormalized() {
    let normalizedDrag: Float = 0.48
    let expectedYaw = FounderGarageCameraConfiguration.dragYawRadiansPerViewport * normalizedDrag
    for viewportWidth: Float in [440, 1_180] {
      let sensitivity = FounderGarageCameraConfiguration.dragSensitivityRadiansPerPoint(
        viewportWidth: viewportWidth
      )
      XCTAssertEqual(sensitivity * viewportWidth * normalizedDrag, expectedYaw, accuracy: 0.0001)
    }
  }

  @MainActor
  func testWalkingResolvesChairOverlapIntoWalkableGarageInterior() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v8: true)
    XCTAssertFalse(world.isPointWalkable([
      world.cameraController.playerSpatialState.playerPose.position.x,
      world.cameraController.playerSpatialState.playerPose.position.z
    ]))
    world.cameraController.beginWalking(reduceMotion: true)
    let standing = world.cameraController.playerSpatialState.playerPose.position
    XCTAssertTrue(world.isPointWalkable([standing.x, standing.z]))
    XCTAssertTrue(world.spatialSpecification.room.interiorBounds.contains([standing.x, standing.z]))
  }

  @MainActor
  func testExploreStandingResolutionKeepsStraightDoorPathCollisionFree() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v8: true)
    world.cameraController.beginWalking(reduceMotion: true)
    world.cameraController.setMovementIntent(.init(forward: 1))

    var collisions: [String] = []
    for _ in 0..<240 {
      world.cameraController.advance(deltaTime: 1.0 / 60)
      let snapshot = world.cameraController.snapshot
      if snapshot.playerPosition.z >= 1.9 { break }
      collisions.append(snapshot.collision)
    }

    XCTAssertFalse(collisions.isEmpty)
    XCTAssertEqual(Set(collisions), ["none"])
    XCTAssertGreaterThanOrEqual(world.cameraController.snapshot.playerPosition.z, 1.9)
  }

  @MainActor
  func testOpenDrivewayHandsWalkingPoseToExistingAtlantisWorldWithoutDrift() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v8: true)
    world.setGarageDoor(.open, reduceMotion: true)
    var received: FounderAtlantisTraversalHandoff?
    world.configureAtlantisTraversal { received = $0 }
    world.cameraController.beginWalking(reduceMotion: true)
    let crossing = SIMD3<Float>(0.4, 0, FounderGarageRealityWorld.atlantisHandoffThresholdZ)
    world.cameraController.consume(.init(
      bodyPosition: crossing,
      bodyHeading: .pi,
      locomotionVelocity: [0, 0, 1],
      stepPhase: nil,
      stance: .standing
    ))
    world.requestAtlantisTraversalIfNeeded()
    let handoff = try XCTUnwrap(received)
    XCTAssertEqual(handoff.garagePosition, crossing)
    XCTAssertEqual(AtlantisSpatialContract.fromFounderGarage(handoff.garagePosition), [
      AtlantisSpatialContract.founderGarage.x + crossing.x,
      AtlantisSpatialContract.founderGarageFloorY,
      AtlantisSpatialContract.founderGarage.z + crossing.z
    ])
    let restored = world.cameraController.playerSpatialState.playerPose.position
    XCTAssertEqual(restored, world.spatialSpecification.interactionApproaches.garageDoor.approach.position)
  }

  @MainActor
  func testAtlantisHandoffTransfersOneVisibleFounderAndRestoresSameRig() throws {
    let garage = FounderGarageRealityWorld()
    let atlantis = AtlantisRealityWorld(manifest: try .load())
    let rig = garage.activeFounderVisualAdapter.rig
    let handoff = FounderAtlantisTraversalHandoff(
      garagePosition: [0.4, 0, FounderGarageRealityWorld.atlantisHandoffThresholdZ],
      facingDirection: [0, 0, 1]
    )

    atlantis.enterFromFounderGarage(handoff)
    garage.transferFounderPresentation(to: atlantis, reduceMotion: false)

    XCTAssertTrue(garage.isFounderPresentedInAtlantis)
    XCTAssertTrue(atlantis.hasFounderPresentation)
    XCTAssertTrue(rig.anchor.parent === atlantis.root)
    XCTAssertTrue(rig.visualRoot.isEnabled)
    XCTAssertGreaterThan(
      simd_distance(atlantis.camera.position(relativeTo: atlantis.root), atlantis.playerRoot.position),
      1.5
    )

    garage.restoreFounderPresentation(from: atlantis)

    XCTAssertFalse(garage.isFounderPresentedInAtlantis)
    XCTAssertFalse(atlantis.hasFounderPresentation)
    XCTAssertTrue(rig.anchor.parent === garage.entities.root)
    XCTAssertTrue(rig.visualRoot.isEnabled)
  }

  @MainActor
  func testExploreForwardPathCrossesOpenGarageDoorIntoAtlantis() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v8: true)
    world.setGarageDoor(.open, reduceMotion: true)
    var received: FounderAtlantisTraversalHandoff?
    world.configureAtlantisTraversal { received = $0 }
    world.cameraController.beginWalking(reduceMotion: true)
    world.cameraController.setMovementIntent(.init(forward: 1))

    for _ in 0..<600 where received == nil {
      world.cameraController.advance(deltaTime: 1.0 / 60)
      world.requestAtlantisTraversalIfNeeded()
    }

    let handoff = try XCTUnwrap(received)
    XCTAssertGreaterThanOrEqual(
      handoff.garagePosition.z,
      FounderGarageRealityWorld.atlantisHandoffThresholdZ
    )
    XCTAssertGreaterThan(handoff.facingDirection.z, 0.9)
  }

  @MainActor
  func testInteractionFocusRetargetsWithoutNestingAndRestoresExactState() {
    let controller = FounderGarageRealityWorld().cameraController
    let original = controller.camera.transform
    let originalFOV = controller.camera.camera.fieldOfViewInDegrees
    XCTAssertTrue(controller.focus(on: .phone, reduceMotion: true))
    XCTAssertEqual(controller.interactionFocusTarget, .phone)
    XCTAssertEqual(controller.playerSpatialState.navigationMode, .interactionFocus(.phone))
    XCTAssertTrue(controller.focus(on: .strategyBoard, reduceMotion: true))
    XCTAssertEqual(controller.interactionFocusTarget, .strategyBoard)
    XCTAssertTrue(controller.restoreInteractionFocus(reduceMotion: true))
    XCTAssertNil(controller.interactionFocusTarget)
    XCTAssertEqual(controller.playerSpatialState.navigationMode, .seated)
    assertTransform(controller.camera.transform, equals: original)
    XCTAssertEqual(controller.camera.camera.fieldOfViewInDegrees, originalFOV)
    XCTAssertFalse(controller.restoreInteractionFocus(reduceMotion: true))
  }

  @MainActor
  func testWalkingRejectsInteractionFocusAndComputerActivation() {
    let world = FounderGarageRealityWorld()
    let controller = world.cameraController
    controller.beginWalking(reduceMotion: true)
    XCTAssertFalse(controller.focus(on: .computer, reduceMotion: true))
    XCTAssertNil(world.interaction(for: world.entities.founderComputerInteractionTarget))
    controller.endWalking(reduceMotion: true)
    XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)
  }

  @MainActor
  func testAngularInertiaIsBoundedAndRepeatedFreeLookHasNoRollOrDrift() {
    let controller = FounderGarageRealityWorld().cameraController
    let home = controller.recipe(for: .founderPOV).transform
    for _ in 0..<100 {
      controller.setLookOrientation(.init(yaw: 0.65, pitch: -0.2))
      controller.advance(deltaTime: 1.0 / 60)
      XCTAssertLessThanOrEqual(simd_length(controller.snapshot.angularVelocity), FounderGarageCameraConfiguration.maximumAngularSpeed + 0.0001)
      controller.recenterFounderPOV()
      for _ in 0..<120 { controller.advance(deltaTime: 1.0 / 120) }
    }
    assertTransform(controller.camera.transform, equals: home, accuracy: 0.0001)
    XCTAssertEqual(controller.snapshot.founderPOVDriftError, 0, accuracy: 0.0001)
    let matrix = controller.camera.transform.matrix
    let right = SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
    XCTAssertEqual(simd_dot(right, SIMD3<Float>(0, 1, 0)), 0, accuracy: 0.0001)
  }

  @MainActor
  func testFutureLocomotionStateReportsCameraOwnedNavigationWithoutMutation() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let controller = FounderGarageRealityWorld().cameraController
    controller.configureWalkability { _ in true }
    controller.beginWalking()
    controller.setMovementIntent(.init(lateral: 0.25, forward: 1))
    for _ in 0..<30 { controller.advance(deltaTime: 1.0 / 60) }
    let state = controller.spatialState
    XCTAssertEqual(state.navigationMode, .walking)
    XCTAssertEqual(state.stance, .standing)
    XCTAssertGreaterThan(state.movementMagnitude, 0)
    XCTAssertNotNil(state.normalizedLocomotionIntent)
    XCTAssertNil(state.stepPhase)
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
  }

  @MainActor
  func testTransitionInterruptionCountsAndNewestDestinationWins() {
    let controller = FounderGarageRealityWorld().cameraController
    controller.configureWalkability { _ in true }
    controller.beginWalking()
    controller.setMovementIntent(.init(forward: 1))
    controller.advance(deltaTime: 0.05)
    XCTAssertGreaterThan(simd_length(controller.snapshot.velocity), 0)
    controller.transition(to: .whiteboard, reduceMotion: false)
    XCTAssertEqual(controller.snapshot.velocity, .zero)
    XCTAssertEqual(controller.playerSpatialState.navigationMode, .authoredInspection(.whiteboard))
    controller.advance(deltaTime: 0.05)
    controller.transition(to: .frontBay, reduceMotion: false)
    XCTAssertEqual(controller.diagnostics.interruptedCount, 1)
    for _ in 0..<60 { controller.advance(deltaTime: 1.0 / 120) }
    XCTAssertEqual(controller.state, .frontBay)
    assertTransform(controller.camera.transform, equals: controller.recipe(for: .frontBay).transform)
  }

  @MainActor
  func testLocomotionGraphMovesThroughStandStartWalkStopAndIdle() {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    XCTAssertEqual(locomotion.state, .seatedIdle)
    spatial.stance = .standing; spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -0.8]; spatial.movementMagnitude = 0.8
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .standingUp)
    for _ in 0..<42 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60) }
    XCTAssertEqual(locomotion.state, .walkStart)
    for _ in 0..<12 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60) }
    XCTAssertEqual(locomotion.state, .walking)
    spatial.horizontalVelocity = .zero; spatial.movementMagnitude = 0
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .walkStop)
    for _ in 0..<16 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60) }
    XCTAssertEqual(locomotion.state, .standingIdle)
  }

  @MainActor
  func testLocomotionPlaybackTracksVelocityAndCollisionStopsWalking() {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing; spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    for _ in 0..<50 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
    XCTAssertEqual(locomotion.state, .walking)
    XCTAssertEqual(locomotion.diagnostics.playbackSpeed, 1, accuracy: 0.001)
    locomotion.update(spatial: spatial, collisionBlocked: true, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .walkStop)
    XCTAssertEqual(locomotion.diagnostics.movementMagnitude, 0)
  }

  @MainActor
  func testProceduralWalkCycleIsVelocityDrivenAndReduceMotionRemovesWeightShift() {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing; spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -0.9]; spatial.movementMagnitude = 0.9
    for _ in 0..<50 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60) }
    let first = world.proceduralFounderVisualAdapter.rig.bodyTarget.transform
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 0.1)
    let second = world.proceduralFounderVisualAdapter.rig.bodyTarget.transform
    XCTAssertNotEqual(first.translation, second.translation)
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 0.1)
    XCTAssertEqual(world.proceduralFounderVisualAdapter.rig.bodyTarget.transform.translation.x, 0, accuracy: 0.0001)
  }

  @MainActor
  func testLocomotionDirectionTurnsSmoothlyAndUsesTurnInPlaceForLargeDelta() {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing; spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0.8, -0.8]; spatial.movementMagnitude = simd_length(spatial.horizontalVelocity)
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    let firstFacing = locomotion.diagnostics.avatarFacing
    XCTAssertTrue(firstFacing.isFinite)
    XCTAssertLessThan(abs(firstFacing - locomotion.diagnostics.targetFacing), .pi)
    for _ in 0..<20 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
    spatial.horizontalVelocity = .zero; spatial.movementMagnitude = 0
    for _ in 0..<20 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
    XCTAssertEqual(locomotion.state, .standingIdle)
    let small = locomotion.diagnostics.avatarFacing + 0.10
    spatial.facingDirection = [sin(small), 0, -cos(small)]
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .standingIdle)
    spatial.facingDirection = [-1, 0, 0]
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .turnInPlace)
  }

  @MainActor
  func testSittingRequiresChairAndResolvesExactAnchor() {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing; spatial.navigationMode = .walking
    for _ in 0..<40 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
    spatial.stance = .seated; spatial.navigationMode = .seated; spatial.position += [1, 0, 0]
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60)
    XCTAssertNotEqual(locomotion.state, .sittingDown)
    spatial.position = FounderGarageCameraConfiguration(
      spatial: world.spatialSpecification
    ).seatedPlayerState.playerPose.position
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .sittingDown)
    for _ in 0..<8 { locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
    XCTAssertEqual(locomotion.state, .seatedIdle)
    XCTAssertEqual(locomotion.diagnostics.seatedAnchorError, 0, accuracy: 0.0001)
  }

  @MainActor
  func testFirstPersonHidesHeadAndAlternateViewRestoresIt() throws {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    let head = try XCTUnwrap(world.proceduralFounderVisualAdapter.rig.headTarget)
    locomotion.update(spatial: world.cameraController.spatialState, collisionBlocked: false, firstPerson: true, reduceMotion: true, deltaTime: 0.1)
    XCTAssertTrue(head.isEnabled)
    XCTAssertFalse(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertTrue(locomotion.diagnostics.firstPersonHeadHidden)
    locomotion.update(spatial: world.cameraController.spatialState, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 0.1)
    XCTAssertTrue(head.isEnabled)
    XCTAssertTrue(world.proceduralFounderVisualAdapter.rig.visualRoot.isEnabled)
    XCTAssertTrue(world.entities.founderAnchor.isEnabled)
  }

  @MainActor
  func testFirstPersonSynchronouslySeatsAndHidesCompleteImportedFounder() throws {
    let world = FounderGarageRealityWorld()
    let fixture = makeSyntheticImportedHierarchy()
    let adapter = try USDZFounderVisualAdapter(
      source: .bundledUSDZ(name: "FirstPersonSeatedFixture"),
      loadedRoot: fixture.root,
      anchor: world.entities.founderAnchor,
      descriptor: makeRigDescriptor()
    )
    try world.installFounderVisualAdapter(adapter)
    var standing = world.cameraController.spatialState
    standing.stance = .standing
    standing.navigationMode = .walking
    standing.horizontalVelocity = [0, -0.8]
    standing.movementMagnitude = 0.8

    world.founderAvatarController.locomotion.update(
      spatial: standing,
      collisionBlocked: false,
      firstPerson: false,
      reduceMotion: true,
      deltaTime: 0.1
    )
    XCTAssertNotEqual(world.founderAvatarController.locomotion.state, .seatedIdle)
    XCTAssertTrue(adapter.rig.visualRoot.isEnabled)

    world.founderAvatarController.locomotion.update(
      spatial: standing,
      collisionBlocked: false,
      firstPerson: true,
      reduceMotion: true,
      deltaTime: 0.1
    )

    XCTAssertEqual(world.founderAvatarController.locomotion.state, .seatedIdle)
    XCTAssertFalse(adapter.rig.visualRoot.isEnabled)
    XCTAssertEqual(adapter.rig.anchor.position, world.cameraController.playerSpatialState.playerPose.position)
    XCTAssertTrue(world.founderAvatarController.locomotion.diagnostics.firstPersonHeadHidden)
  }

  @MainActor
  func testLocomotionCannotApplyRootMotionOrMutateCanonicalState() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let cameraBefore = world.cameraController.spatialState
    var spatial = cameraBefore
    spatial.stance = .standing; spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0.4, -0.7]; spatial.movementMagnitude = simd_length(spatial.horizontalVelocity)
    world.proceduralFounderVisualAdapter.rig.visualRoot.position = [99, 0, 99]
    world.founderAvatarController.locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 0.1)
    XCTAssertEqual(world.cameraController.spatialState, cameraBefore)
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  @MainActor
  func testOneHundredLocomotionCyclesAccumulateNoSeatOrOrientationDrift() {
    let world = FounderGarageRealityWorld()
    let locomotion = world.founderAvatarController.locomotion
    let seated = world.cameraController.spatialState
    var standing = seated
    standing.stance = .standing; standing.navigationMode = .walking
    standing.horizontalVelocity = [0, -0.9]; standing.movementMagnitude = 0.9
    for _ in 0..<100 {
      for _ in 0..<8 { locomotion.update(spatial: standing, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
      standing.horizontalVelocity = .zero; standing.movementMagnitude = 0
      for _ in 0..<8 { locomotion.update(spatial: standing, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60) }
      for _ in 0..<8 { locomotion.update(spatial: seated, collisionBlocked: false, firstPerson: true, reduceMotion: true, deltaTime: 1.0 / 60) }
      standing.horizontalVelocity = [0, -0.9]; standing.movementMagnitude = 0.9
    }
    XCTAssertEqual(locomotion.state, .seatedIdle)
    XCTAssertEqual(locomotion.diagnostics.seatedAnchorError, 0, accuracy: 0.0001)
    XCTAssertEqual(locomotion.diagnostics.avatarFacing, locomotion.diagnostics.targetFacing, accuracy: 0.0001)
  }

  @MainActor
  func testObservationRoundTripPreservesWorldAndSuppressesComputer() async throws {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world)
    let ids = world.entities.identitySnapshot
    let facilityRootID = adapter.rig.visualRoot.id
    let cameraRigID = world.entities.cameraRig.id
    let anchorIDs = adapter.resolvedAnchorMap?.entitiesByName.mapValues { $0.id }
    var model = makePresentation()
    world.apply(model, reduceMotion: true)
    let founderApplications = world.founderPresentationController.diagnostics.applicationCount
    for state in [FounderGarageCameraState.garageOverview, .whiteboard, .garageDoor, .frontBay, .founderPOV] {
      model.cameraState = state
      world.apply(model, reduceMotion: true)
      XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), state.allowsComputer ? .openFounderComputer : nil)
      XCTAssertEqual(world.entities.identitySnapshot, ids)
      XCTAssertEqual(world.activeGarageArchitectureAdapter.rig.visualRoot.id, facilityRootID)
      XCTAssertEqual(world.entities.cameraRig.id, cameraRigID)
      XCTAssertTrue(world.entities.validateIntegrity())
    }
    XCTAssertEqual(world.founderPresentationController.diagnostics.applicationCount, founderApplications)
    XCTAssertEqual(adapter.resolvedAnchorMap?.entitiesByName.mapValues { $0.id }, anchorIDs)
    XCTAssertEqual(world.architectureLoadDiagnostics.loaderInvocationCount, 1)
    XCTAssertEqual(world.activeAccessibilitySubscriptionCount, 0)
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
  }

  func testExistingDeskNavigationOwnsObservationAndComputerReturn() {
    var navigation = FounderDeskNavigationState()
    navigation.observeGarage(.garageOverview)
    XCTAssertTrue(navigation.lookOutActive)
    XCTAssertNil(navigation.select(.computer))
    navigation.observeGarage(.founderPOV)
    XCTAssertEqual(navigation.garageCameraState, .founderPOV)
    XCTAssertEqual(navigation.select(.computer), .computerFocused)
    navigation.completeCameraTransition(to: .computerFocused)
    navigation.observeGarage(.garageOverview)
    XCTAssertEqual(navigation.garageCameraState, .founderPOV)
    XCTAssertEqual(navigation.lookOut(), .freeLook)
    navigation.completeCameraTransition(to: .freeLook)
    XCTAssertEqual(navigation.garageCameraState, .founderPOV)
  }

  @MainActor
  func testV3NativeAssetPreservesAnchorContractAndImportedHierarchy() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v3: true)
    XCTAssertEqual(adapter.normalization.uniformScale, 1)
    XCTAssertEqual(adapter.normalization.translationCorrection, .zero)
    XCTAssertEqual(adapter.normalization.orientationCorrection.angle, 0)
    XCTAssertEqual(adapter.preservedAnchorPositions.count, 20)
    for (name, expected) in try XCTUnwrap(world.spatialSpecification.productionAnchors).namedPositions {
      let actual = try XCTUnwrap(adapter.preservedAnchorPositions[name])
      XCTAssertLessThan(simd_distance(actual, expected), 0.001, name)
    }
    for name in ["FounderChair", "FounderDesk", "FounderMonitor", "Monitor_Display", "Floor", "RearWall"] {
      XCTAssertNotNil(adapter.rig.visualRoot.findEntity(named: name), name)
    }
    XCTAssertGreaterThan(adapter.renderableEntityCount, 50)
    XCTAssertGreaterThan(adapter.materialCount, 50)
    XCTAssertFalse(world.entities.founderAnchor.isEnabled)
  }

  @MainActor
  func testV4ProductionAssetLoadsAsNativeCompleteEnclosure() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v4: true)
    let root = adapter.rig.visualRoot

    XCTAssertEqual(
      world.activeGarageArchitectureAdapter.source,
      .bundledProductionAsset(name: "founder_garage_v4")
    )
    XCTAssertEqual(adapter.normalization.uniformScale, 1, accuracy: 0.0001)
    XCTAssertEqual(adapter.normalization.translationCorrection, .zero)
    XCTAssertEqual(adapter.normalization.orientationCorrection.angle, 0, accuracy: 0.0001)
    XCTAssertTrue(adapter.normalization.nativeBounds.approximatelyMatches(
      FounderGarageArchitectureBounds(
        minimum: [-2.66, -0.18, -2.91],
        maximum: [2.70, 2.88, 2.91]
      ),
      tolerance: 0.001
    ))
    XCTAssertFalse(adapter.usesAuthoredCutaway)
    for name in [
      "Garage_RightWall", "Ceiling", "GarageDoor_Panel", "GarageDoor_Header",
      "GarageDoor_Frame_L", "GarageDoor_Frame_R", "GarageDoor_Track_L",
      "GarageDoor_Track_R"
    ] {
      XCTAssertEqual(root.findEntity(named: name)?.isEnabled, true, name)
    }

    let rightWall = try XCTUnwrap(root.findEntity(named: "Garage_RightWall")).visualBounds(relativeTo: root)
    let ceiling = try XCTUnwrap(root.findEntity(named: "Ceiling")).visualBounds(relativeTo: root)
    let door = try XCTUnwrap(root.findEntity(named: "GarageDoor_Panel")).visualBounds(relativeTo: root)
    XCTAssertGreaterThan(rightWall.extents.y, 2.60)
    XCTAssertGreaterThan(rightWall.extents.z, 5.40)
    XCTAssertGreaterThan(rightWall.min.x, 2.49)
    XCTAssertGreaterThan(ceiling.extents.x, 5.0)
    XCTAssertGreaterThan(ceiling.extents.z, 5.40)
    XCTAssertGreaterThan(ceiling.min.y, 2.69)
    XCTAssertGreaterThan(door.extents.x, 4.10)
    XCTAssertGreaterThan(door.extents.y, 2.20)
    XCTAssertEqual(door.center.z, 2.65, accuracy: 0.05)
    for name in ["Garage_RightWall", "Ceiling", "GarageDoor_Panel", "GarageDoor_Track_R"] {
      XCTAssertTrue(hasRenderableMaterial(in: try XCTUnwrap(root.findEntity(named: name))), name)
    }
  }

  @MainActor
  func testV4PreservesAllCanonicalAnchorsWithoutMeaningfulDrift() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v4: true)
    let expected = try XCTUnwrap(world.spatialSpecification.productionAnchors).namedPositions

    XCTAssertEqual(adapter.preservedAnchorPositions.count, 20)
    XCTAssertTrue(adapter.missingAnchorNames.isEmpty)
    XCTAssertEqual(Set(adapter.preservedAnchorPositions.keys), Set(expected.keys))
    let drift = expected.map { name, expectedPosition in
      simd_distance(adapter.preservedAnchorPositions[name]!, expectedPosition)
    }
    XCTAssertLessThanOrEqual(try XCTUnwrap(drift.max()), 0.001)
  }

  @MainActor
  func testV4DoorHierarchyRetainsIndependentAnimationReadySections() async throws {
    let adapter = try await loadFacilityTier0(in: FounderGarageRealityWorld(), v4: true)
    let root = adapter.rig.visualRoot
    let door = try XCTUnwrap(root.findEntity(named: "Door"))
    let panel = try XCTUnwrap(door.findEntity(named: "GarageDoor_Panel"))

    XCTAssertEqual(panel.position(relativeTo: root), [0, 0.025, 2.65])
    for index in 1...5 {
      let section = try XCTUnwrap(panel.findEntity(named: String(format: "GarageDoor_Section_%02d", index)))
      XCTAssertTrue(section.parent === panel)
      XCTAssertGreaterThan(section.position.y, 0)
    }
    for name in [
      "GarageDoor_Header", "GarageDoor_Frame_L", "GarageDoor_Frame_R",
      "GarageDoor_Track_L", "GarageDoor_Track_R"
    ] {
      XCTAssertTrue(try XCTUnwrap(door.findEntity(named: name)).parent === door, name)
    }
  }

  @MainActor
  func testV4GarageDoorOpensOntoOverheadTracksAndClosesExactly() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v4: true)
    let panel = try XCTUnwrap(adapter.rig.visualRoot.findEntity(named: "GarageDoor_Panel"))
    let sections = try (1...5).map {
      try XCTUnwrap(panel.findEntity(named: String(format: "GarageDoor_Section_%02d", $0)))
    }
    let closedTransforms = sections.map(\.transform)

    XCTAssertTrue(world.garageDoorControlAvailable)
    XCTAssertEqual(world.garageDoorState, .closed)
    world.setGarageDoor(.open, reduceMotion: true)
    XCTAssertEqual(world.garageDoorState, .open)
    for (index, section) in sections.enumerated() {
      XCTAssertEqual(section.position.y, 2.455, accuracy: 0.001)
      XCTAssertEqual(section.position.z, closedTransforms[index].translation.y - 2.65, accuracy: 0.001)
      XCTAssertEqual(section.orientation.angle, .pi / 2, accuracy: 0.001)
    }
    XCTAssertLessThan(sections[0].position.z, sections[4].position.z)

    world.toggleGarageDoor(reduceMotion: true)
    XCTAssertEqual(world.garageDoorState, .closed)
    for (section, closed) in zip(sections, closedTransforms) {
      assertTransform(section.transform, equals: closed)
    }
  }

  @MainActor
  func testV4GarageDoorStateRemainsPresentationOnly() async throws {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v4: true)

    world.setGarageDoor(.open, reduceMotion: true)
    world.setGarageDoor(.closed, reduceMotion: true)

    XCTAssertEqual(CanonicalSnapshot(store: store), before)
  }

  @MainActor
  func testV4RuntimeVisibilityIsEnclosedExceptForOverviewCutaway() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v4: true)
    let root = adapter.rig.visualRoot
    var presentation = makePresentation()

    presentation.cameraState = .founderPOV
    world.apply(presentation, reduceMotion: true)
    XCTAssertEqual(root.findEntity(named: "Garage_RightWall")?.isEnabled, true)
    XCTAssertEqual(root.findEntity(named: "Ceiling")?.isEnabled, true)
    XCTAssertEqual(root.findEntity(named: "GarageDoor_Panel")?.isEnabled, true)

    presentation.cameraState = .garageOverview
    world.apply(presentation, reduceMotion: true)
    XCTAssertEqual(root.findEntity(named: "Garage_RightWall")?.isEnabled, false)
    XCTAssertEqual(root.findEntity(named: "Ceiling")?.isEnabled, false)
    XCTAssertEqual(root.findEntity(named: "GarageDoor_Panel")?.isEnabled, true)
    XCTAssertEqual(root.findEntity(named: "GarageDoor_Track_R")?.isEnabled, true)

    presentation.cameraState = .founderPOV
    world.apply(presentation, reduceMotion: true)
    XCTAssertEqual(root.findEntity(named: "Garage_RightWall")?.isEnabled, true)
    XCTAssertEqual(root.findEntity(named: "Ceiling")?.isEnabled, true)
  }

  @MainActor
  func testFounderDisplayUsesFirstPersonCompositionFromCanonicalSeat() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v4: true)
    let controller = world.cameraController
    let pose = controller.recipe(for: .founderPOV)
    XCTAssertEqual(
      controller.playerSpatialState.eyePosition,
      world.spatialSpecification.anchors.founder.position + [0, 1.18, 0]
    )
    XCTAssertEqual(pose.position, controller.playerSpatialState.eyePosition)
    XCTAssertTrue(controller.usesFirstPersonPresentation)
    let m = pose.transform.matrix
    let right = SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z)
    let up = SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z)
    let forward = -SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z)
    let projected = controller.displayCorners.map { point -> SIMD2<Float> in
      let v = point - pose.position
      return SIMD2<Float>(simd_dot(v, right), simd_dot(v, up)) / simd_dot(v, forward)
    }
    XCTAssertEqual(projected.count, 8)
    for axis in 0..<2 {
      let values = projected.map { $0[axis] }
      XCTAssertEqual((try XCTUnwrap(values.min()) + XCTUnwrap(values.max())) / 2, 0, accuracy: 0.1)
    }
  }

  @MainActor
  func testV4FounderDisplayFacesCanonicalSeatedEyeHeadOn() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v4: true)
    let root = adapter.rig.visualRoot
    let monitor = try XCTUnwrap(root.findEntity(named: "FounderMonitor"))
    let display = try XCTUnwrap(root.findEntity(named: "Monitor_Display"))
    let bounds = display.visualBounds(relativeTo: display)
    let center = display.convert(position: bounds.center, to: root)
    let origin = display.convert(position: .zero, to: root)
    let frontPoint = display.convert(position: [0, 0, 1], to: root)
    let front = simd_normalize(SIMD3<Float>(
      frontPoint.x - origin.x,
      0,
      frontPoint.z - origin.z
    ))
    let eye = world.cameraController.playerSpatialState.eyePosition
    let towardEye = simd_normalize(SIMD3<Float>(
      eye.x - center.x,
      0,
      eye.z - center.z
    ))

    XCTAssertGreaterThan(simd_dot(front, towardEye), 0.9999)
    XCTAssertEqual(monitor.position(relativeTo: root).x, 1.42, accuracy: 0.001)
    XCTAssertEqual(monitor.position(relativeTo: root).y, 1.30, accuracy: 0.001)
    XCTAssertEqual(monitor.position(relativeTo: root).z, -1.114, accuracy: 0.001)
    XCTAssertEqual(
      world.cameraController.recipe(for: .founderPOV).position,
      world.cameraController.playerSpatialState.eyePosition
    )
  }

  @MainActor
  func testV6ProductionAssetLoadsAtNativeScaleWithCompleteExterior() async throws {
    XCTAssertNotNil(Bundle.main.url(forResource: "founder_garage_v6", withExtension: "usdz"))
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v6: true)
    let root = adapter.rig.visualRoot

    XCTAssertEqual(
      world.activeGarageArchitectureAdapter.source,
      .bundledProductionAsset(name: "founder_garage_v6")
    )
    XCTAssertEqual(adapter.normalization.uniformScale, 1, accuracy: 0.0001)
    XCTAssertEqual(adapter.normalization.translationCorrection, .zero)
    XCTAssertEqual(adapter.normalization.orientationCorrection.angle, 0, accuracy: 0.0001)
    XCTAssertTrue(adapter.normalization.nativeBounds.approximatelyMatches(
      FounderGarageArchitectureBounds(
        minimum: [-40.0, -0.21, -30.0],
        maximum: [40.0, 7.9, 26.0]
      ),
      tolerance: 0.025
    ))
    XCTAssertFalse(adapter.usesAuthoredCutaway)
    XCTAssertGreaterThanOrEqual(adapter.renderableEntityCount, 150)
    for name in [
      "Exterior", "Driveway", "LotGround", "Sidewalk", "DrivewayApron_CurbCut",
      "Curb_L", "Curb_R", "Street", "Facade_Fascia", "FrontYard_L",
      "FrontYard_R", "Mailbox", "Tree_L", "Tree_R"
    ] {
      XCTAssertNotNil(root.findEntity(named: name), name)
    }
    let exterior = try XCTUnwrap(root.findEntity(named: "Exterior"))
    XCTAssertGreaterThan(exterior.visualBounds(relativeTo: root).extents.z, 40)
  }

  @MainActor
  func testV6PreservesCanonicalInteriorAndAllTwentyAnchors() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v6: true)
    let expected = try XCTUnwrap(world.spatialSpecification.productionAnchors).namedPositions

    XCTAssertEqual(world.spatialSpecification.room.width, 5.0)
    XCTAssertEqual(world.spatialSpecification.room.depth, 5.5)
    XCTAssertEqual(world.spatialSpecification.room.wallHeight, 2.7)
    XCTAssertEqual(adapter.preservedAnchorPositions.count, 20)
    XCTAssertTrue(adapter.missingAnchorNames.isEmpty)
    XCTAssertEqual(Set(adapter.preservedAnchorPositions.keys), Set(expected.keys))
    for (name, expectedPosition) in expected {
      XCTAssertLessThanOrEqual(
        simd_distance(try XCTUnwrap(adapter.preservedAnchorPositions[name]), expectedPosition),
        0.001,
        name
      )
    }
  }

  @MainActor
  func testV6UsesOnlyPersistentRuntimeLightingRig() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v6: true)
    for entity in descendants(including: adapter.rig.visualRoot) {
      XCTAssertNil(entity.components[DirectionalLightComponent.self], entity.name)
      XCTAssertNil(entity.components[PointLightComponent.self], entity.name)
      XCTAssertNil(entity.components[SpotLightComponent.self], entity.name)
      XCTAssertNil(entity.components[ImageBasedLightComponent.self], entity.name)
    }
    XCTAssertEqual(world.entities.lighting.children.count, 4)
    XCTAssertTrue(world.entities.validateIntegrity())
  }

  func testEnvironmentTimeConfigurationIsDeterministicCompleteAndDistinct() {
    XCTAssertEqual(FounderEnvironmentLightingConfiguration.defaultState, .day)
    XCTAssertEqual(FounderEnvironmentTimeState.allCases, [.morning, .day, .evening, .night])
    let first = FounderEnvironmentTimeState.allCases.map {
      FounderEnvironmentLightingConfiguration.preset(for: $0)
    }
    let second = FounderEnvironmentTimeState.allCases.map {
      FounderEnvironmentLightingConfiguration.preset(for: $0)
    }
    XCTAssertEqual(first, second)
    XCTAssertEqual(Set(first.map(\.directionalIntensity)).count, 4)
    XCTAssertEqual(Set(first.map(\.backgroundTop)).count, 4)
    XCTAssertTrue(first.allSatisfy {
      $0.directionalIntensity > 0 && $0.generalFillIntensity > 0
        && $0.hangingPracticalIntensity > 0 && $0.deskPracticalIntensity > 0
    })
  }

  @MainActor
  func testV6TimeSelectionUpdatesPresentationOnlyAndPreservesOpenDoor() async throws {
    let store = GameStore()
    let canonicalBefore = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let presentation = makePresentation()
    world.apply(presentation, reduceMotion: true)
    _ = try await loadFacilityTier0(in: world, v6: true)
    let lightIDs = [
      world.entities.keyLight.id, world.entities.fillLight.id,
      world.entities.hangingPracticalLight.id, world.entities.deskPracticalLight.id
    ]

    XCTAssertEqual(world.environmentTimeState, .day)
    XCTAssertTrue(world.garageDoorControlAvailable)
    world.setGarageDoor(.open, reduceMotion: true)
    for state in FounderEnvironmentTimeState.allCases {
      let preset = FounderEnvironmentLightingConfiguration.preset(for: state)
      world.setEnvironmentTimeState(state, reduceMotion: true)
      XCTAssertEqual(world.environmentTimeState, state)
      XCTAssertEqual(world.entities.keyLight.position, preset.directionalPosition)
      XCTAssertEqual(
        world.entities.keyLight.light.intensity,
        preset.directionalIntensity * Float(presentation.roomLightIntensity),
        accuracy: 0.01
      )
      XCTAssertEqual(
        world.entities.fillLight.light.intensity,
        preset.generalFillIntensity * Float(presentation.roomLightIntensity),
        accuracy: 0.01
      )
      XCTAssertEqual(world.garageDoorState, .open)
      XCTAssertEqual(lightIDs, [
        world.entities.keyLight.id, world.entities.fillLight.id,
        world.entities.hangingPracticalLight.id, world.entities.deskPracticalLight.id
      ])
    }
    XCTAssertEqual(CanonicalSnapshot(store: store), canonicalBefore)
  }

  @MainActor
  func testV6GarageDoorOpensAndClosesWithoutChangingTimeState() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v6: true)
    let panel = try XCTUnwrap(adapter.rig.visualRoot.findEntity(named: "GarageDoor_Panel"))
    let sections = try (1...5).map {
      try XCTUnwrap(panel.findEntity(named: String(format: "GarageDoor_Section_%02d", $0)))
    }
    let closedTransforms = sections.map(\.transform)

    world.setEnvironmentTimeState(.night, reduceMotion: true)
    world.setGarageDoor(.open, reduceMotion: true)
    XCTAssertEqual(world.garageDoorState, .open)
    XCTAssertEqual(world.environmentTimeState, .night)
    XCTAssertTrue(sections.allSatisfy { abs($0.position.y - 2.455) < 0.001 })
    world.setGarageDoor(.closed, reduceMotion: true)
    XCTAssertEqual(world.garageDoorState, .closed)
    XCTAssertEqual(world.environmentTimeState, .night)
    for (section, closed) in zip(sections, closedTransforms) {
      assertTransform(section.transform, equals: closed)
    }
  }

  @MainActor
  func testV7ProductionAssetLoadsAtNativeScaleWithCompleteExterior() async throws {
    XCTAssertNotNil(Bundle.main.url(forResource: "founder_garage_v7", withExtension: "usdz"))
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v7: true)
    let root = adapter.rig.visualRoot

    XCTAssertEqual(
      world.activeGarageArchitectureAdapter.source,
      .bundledProductionAsset(name: "founder_garage_v7")
    )
    XCTAssertEqual(adapter.normalization.uniformScale, 1, accuracy: 0.0001)
    XCTAssertEqual(adapter.normalization.translationCorrection, .zero)
    XCTAssertEqual(adapter.normalization.orientationCorrection.angle, 0, accuracy: 0.0001)
    XCTAssertTrue(adapter.normalization.nativeBounds.approximatelyMatches(
      FounderGarageArchitectureBounds(
        minimum: [-40.0, -0.24, -30.0],
        maximum: [40.0, 7.9, 26.0]
      ),
      tolerance: 0.025
    ))
    XCTAssertFalse(adapter.usesAuthoredCutaway)
    XCTAssertGreaterThanOrEqual(adapter.renderableEntityCount, 150)
    for name in [
      "Exterior", "Driveway", "LotGround", "Sidewalk", "DrivewayApron_CurbCut",
      "Curb_L", "Curb_R", "Street", "Facade_Fascia", "FrontYard_L",
      "FrontYard_R", "Mailbox", "Tree_L", "Tree_R"
    ] {
      XCTAssertNotNil(root.findEntity(named: name), name)
    }
    let exterior = try XCTUnwrap(root.findEntity(named: "Exterior"))
    XCTAssertGreaterThan(exterior.visualBounds(relativeTo: root).extents.z, 40)
  }

  @MainActor
  func testV7PreservesCanonicalInteriorAndAllTwentyAnchors() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v7: true)
    let expected = try XCTUnwrap(world.spatialSpecification.productionAnchors).namedPositions

    XCTAssertEqual(world.spatialSpecification.room.width, 5.0)
    XCTAssertEqual(world.spatialSpecification.room.depth, 5.5)
    XCTAssertEqual(world.spatialSpecification.room.wallHeight, 2.7)
    XCTAssertEqual(adapter.preservedAnchorPositions.count, 20)
    XCTAssertTrue(adapter.missingAnchorNames.isEmpty)
    XCTAssertEqual(Set(adapter.preservedAnchorPositions.keys), Set(expected.keys))
    for (name, expectedPosition) in expected {
      XCTAssertLessThanOrEqual(
        simd_distance(try XCTUnwrap(adapter.preservedAnchorPositions[name]), expectedPosition),
        0.001,
        name
      )
    }
  }

  @MainActor
  func testV7UsesOnlyPersistentRuntimeLightingRig() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v7: true)
    for entity in descendants(including: adapter.rig.visualRoot) {
      XCTAssertNil(entity.components[DirectionalLightComponent.self], entity.name)
      XCTAssertNil(entity.components[PointLightComponent.self], entity.name)
      XCTAssertNil(entity.components[SpotLightComponent.self], entity.name)
      XCTAssertNil(entity.components[ImageBasedLightComponent.self], entity.name)
    }
    XCTAssertEqual(world.entities.lighting.children.count, 5)
    XCTAssertTrue(world.entities.validateIntegrity())
  }

  func testV7EnvironmentTimeConfigurationIsDeterministicCompleteAndDistinct() {
    XCTAssertEqual(FounderEnvironmentLightingConfiguration.defaultState, .day)
    XCTAssertEqual(FounderEnvironmentTimeState.allCases, [.morning, .day, .evening, .night])
    let first = FounderEnvironmentTimeState.allCases.map {
      FounderEnvironmentLightingConfiguration.preset(for: $0)
    }
    let second = FounderEnvironmentTimeState.allCases.map {
      FounderEnvironmentLightingConfiguration.preset(for: $0)
    }
    XCTAssertEqual(first, second)
    XCTAssertEqual(Set(first.map(\.directionalIntensity)).count, 4)
    XCTAssertEqual(Set(first.map(\.backgroundTop)).count, 4)
    XCTAssertTrue(first.allSatisfy {
      $0.directionalIntensity > 0 && $0.generalFillIntensity > 0
        && $0.hangingPracticalIntensity > 0 && $0.deskPracticalIntensity > 0
    })
  }

  @MainActor
  func testV7TimeSelectionUpdatesPresentationOnlyAndPreservesOpenDoor() async throws {
    let store = GameStore()
    let canonicalBefore = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let presentation = makePresentation()
    world.apply(presentation, reduceMotion: true)
    _ = try await loadFacilityTier0(in: world, v7: true)
    let lightIDs = [
      world.entities.keyLight.id, world.entities.fillLight.id,
      world.entities.hangingPracticalLight.id, world.entities.deskPracticalLight.id
    ]

    XCTAssertEqual(world.environmentTimeState, .day)
    XCTAssertTrue(world.garageDoorControlAvailable)
    world.setGarageDoor(.open, reduceMotion: true)
    for state in FounderEnvironmentTimeState.allCases {
      let preset = FounderEnvironmentLightingConfiguration.preset(for: state)
      world.setEnvironmentTimeState(state, reduceMotion: true)
      XCTAssertEqual(world.environmentTimeState, state)
      XCTAssertEqual(world.entities.keyLight.position, preset.directionalPosition)
      XCTAssertEqual(
        world.entities.keyLight.light.intensity,
        preset.directionalIntensity * Float(presentation.roomLightIntensity),
        accuracy: 0.01
      )
      XCTAssertEqual(
        world.entities.fillLight.light.intensity,
        preset.generalFillIntensity * Float(presentation.roomLightIntensity),
        accuracy: 0.01
      )
      XCTAssertEqual(world.garageDoorState, .open)
      XCTAssertEqual(lightIDs, [
        world.entities.keyLight.id, world.entities.fillLight.id,
        world.entities.hangingPracticalLight.id, world.entities.deskPracticalLight.id
      ])
    }
    XCTAssertEqual(CanonicalSnapshot(store: store), canonicalBefore)
  }

  @MainActor
  func testV7GarageDoorOpensAndClosesWithoutChangingTimeState() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v7: true)
    let panel = try XCTUnwrap(adapter.rig.visualRoot.findEntity(named: "GarageDoor_Panel"))
    let sections = try (1...5).map {
      try XCTUnwrap(panel.findEntity(named: String(format: "GarageDoor_Section_%02d", $0)))
    }
    let closedTransforms = sections.map(\.transform)

    world.setEnvironmentTimeState(.night, reduceMotion: true)
    world.setGarageDoor(.open, reduceMotion: true)
    XCTAssertEqual(world.garageDoorState, .open)
    XCTAssertEqual(world.environmentTimeState, .night)
    XCTAssertTrue(sections.allSatisfy { abs($0.position.y - 2.455) < 0.001 })
    world.setGarageDoor(.closed, reduceMotion: true)
    XCTAssertEqual(world.garageDoorState, .closed)
    XCTAssertEqual(world.environmentTimeState, .night)
    for (section, closed) in zip(sections, closedTransforms) {
      assertTransform(section.transform, equals: closed)
    }
  }

  @MainActor
  func testEveryAuthoredViewReturnsToFounderPOVWithStableV4IdentityAndComputer() async throws {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v4: true)
    let ids = world.entities.identitySnapshot
    let visualID = adapter.rig.visualRoot.id
    var navigation = FounderDeskNavigationState()
    var model = makePresentation()
    XCTAssertEqual(navigation.garageCameraState, .founderPOV)
    XCTAssertEqual(model.cameraState, .founderPOV)
    assertTransform(world.entities.camera.transform, equals: world.cameraController.recipe(for: .founderPOV).transform)
    for view in FounderGarageCameraState.allCases where view != .founderPOV {
      navigation.observeGarage(view)
      model.cameraState = navigation.garageCameraState
      world.apply(model, reduceMotion: true)
      XCTAssertEqual(world.cameraController.state, view)
      XCTAssertNil(world.interaction(for: world.entities.founderComputerInteractionTarget))
      navigation.observeGarage(.founderPOV)
      model.cameraState = navigation.garageCameraState
      world.apply(model, reduceMotion: true)
      XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)
      XCTAssertEqual(world.entities.identitySnapshot, ids)
      XCTAssertEqual(world.activeGarageArchitectureAdapter.rig.visualRoot.id, visualID)
    }
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
    XCTAssertEqual(world.architectureLoadDiagnostics.loaderInvocationCount, 1)
  }

  @MainActor
  func testAuthoredViewLabelsAreUniqueAndEndpointsHaveNoRoll() {
    let world = FounderGarageRealityWorld()
    XCTAssertEqual(Set(FounderGarageCameraState.allCases.map(\.title)).count, 6)
    for view in FounderGarageCameraState.allCases {
      let recipe = world.cameraController.recipe(for: view)
      XCTAssertEqual(recipe.transform.matrix.columns.0.y, 0, accuracy: 0.0001)
      world.cameraController.transition(to: view, reduceMotion: true)
      assertTransform(world.entities.camera.transform, equals: recipe.transform)
    }
  }

  @MainActor
  func testSeatedPlayerRootAndEyeOffsetRemainSeparate() throws {
    let configuration = FounderGarageCameraConfiguration(spatial: .standard)
    let state = configuration.seatedPlayerState
    let anchors = try XCTUnwrap(FounderGarageSpatialSpecification.standard.productionAnchors)
    XCTAssertEqual(state.playerPose.position, anchors.founderSeat)
    XCTAssertEqual(state.eyeOffset, [0, 1.18, 0])
    XCTAssertEqual(state.eyePosition, [0.34, 1.18, -0.22])
    XCTAssertNotEqual(state.playerPose.position, state.eyePosition)
    XCTAssertEqual(state.navigationMode, .seated)
    XCTAssertEqual(state.lookOrientation, .neutral)
  }

  @MainActor
  func testFreeLookClampsYawAndPitchAtCentralizedLimits() {
    let configuration = FounderGarageCameraConfiguration(spatial: .standard)
    XCTAssertEqual(
      configuration.clamped(FounderLookOrientation(yaw: -10, pitch: -10)),
      FounderLookOrientation(
        yaw: FounderGarageCameraConfiguration.yawLimits.lowerBound,
        pitch: FounderGarageCameraConfiguration.pitchLimits.lowerBound
      )
    )
    XCTAssertEqual(
      configuration.clamped(FounderLookOrientation(yaw: 10, pitch: 10)),
      FounderLookOrientation(
        yaw: FounderGarageCameraConfiguration.yawLimits.upperBound,
        pitch: FounderGarageCameraConfiguration.pitchLimits.upperBound
      )
    )
  }

  @MainActor
  func testFounderFreeLookRotatesFirstPersonWithoutRollOrMovingPlayer() {
    let world = FounderGarageRealityWorld()
    let controller = world.cameraController
    let root = controller.playerSpatialState.playerPose
    let neutral = controller.recipe(for: .founderPOV).transform
    controller.setLookOrientation(FounderLookOrientation(yaw: 0.45, pitch: -0.20))
    for _ in 0..<90 { controller.advance(deltaTime: 1.0 / 60) }
    XCTAssertEqual(controller.playerSpatialState.playerPose, root)
    XCTAssertEqual(controller.playerSpatialState.lookOrientation.yaw, 0.45, accuracy: 0.0001)
    XCTAssertEqual(controller.playerSpatialState.lookOrientation.pitch, -0.20, accuracy: 0.0001)
    XCTAssertEqual(controller.camera.transform.translation, neutral.translation)
    XCTAssertEqual(controller.camera.transform.translation, controller.playerSpatialState.eyePosition)
    XCTAssertNotEqual(controller.camera.transform.rotation.vector, neutral.rotation.vector)
    let matrix = controller.camera.transform.matrix
    let right = SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
    let forward = -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
    XCTAssertEqual(simd_dot(right, SIMD3<Float>(0, 1, 0)), 0, accuracy: 0.0001)
    XCTAssertEqual(simd_dot(right, forward), 0, accuracy: 0.0001)
  }

  @MainActor
  func testRecenterRestoresNeutralFounderPOV() {
    let controller = FounderGarageRealityWorld().cameraController
    controller.setLookOrientation(FounderLookOrientation(yaw: -0.7, pitch: 0.3))
    controller.recenterFounderPOV()
    for _ in 0..<90 { controller.advance(deltaTime: 1.0 / 60) }
    XCTAssertEqual(controller.playerSpatialState.lookOrientation, .neutral)
    XCTAssertEqual(controller.playerSpatialState.navigationMode, .seated)
    assertTransform(controller.camera.transform, equals: controller.recipe(for: .founderPOV).transform)
    XCTAssertEqual(controller.diagnostics.recenterCount, 1)
  }

  @MainActor
  func testEveryAuthoredInspectionReturnsToNeutralSeatedMode() {
    let controller = FounderGarageRealityWorld().cameraController
    let playerRoot = controller.playerSpatialState.playerPose
    for view in FounderGarageCameraState.allCases where view != .founderPOV {
      controller.setLookOrientation(FounderLookOrientation(yaw: 0.5, pitch: -0.2))
      controller.transition(to: view, reduceMotion: true)
      XCTAssertEqual(controller.playerSpatialState.navigationMode, .authoredInspection(view))
      XCTAssertEqual(controller.playerSpatialState.lookOrientation, .neutral)
      let authoredTransform = controller.camera.transform
      controller.setLookOrientation(FounderLookOrientation(yaw: -0.5, pitch: 0.2))
      assertTransform(controller.camera.transform, equals: authoredTransform)
      controller.transition(to: .founderPOV, reduceMotion: true)
      XCTAssertEqual(controller.playerSpatialState.navigationMode, .seated)
      XCTAssertEqual(controller.playerSpatialState.lookOrientation, .neutral)
      XCTAssertEqual(controller.playerSpatialState.playerPose, playerRoot)
      assertTransform(controller.camera.transform, equals: controller.recipe(for: .founderPOV).transform)
    }
  }

  @MainActor
  func testFreeLookRemainsIsolatedFromCanonicalSimulationState() {
    let store = GameStore()
    let before = CanonicalSnapshot(store: store)
    let controller = FounderGarageRealityWorld().cameraController
    controller.setLookOrientation(FounderLookOrientation(yaw: 0.8, pitch: -0.4))
    controller.recenterFounderPOV()
    XCTAssertEqual(CanonicalSnapshot(store: store), before)
  }

  @MainActor
  func testV7FixtureLightTracksAuthoredLensAndFallbackRemovesIt() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v7: true)
    let lens = try XCTUnwrap(adapter.rig.visualRoot.findEntity(named: FounderEnvironmentLightingConfiguration.exteriorFixtureLensName))
    XCTAssertLessThan(simd_distance(world.exteriorPracticalLight.position, lens.visualBounds(relativeTo: world.entities.lighting).center), 0.05)
    XCTAssertFalse(world.exteriorPracticalLight.isEnabled)
    world.setEnvironmentTimeState(.night, reduceMotion: true)
    XCTAssertTrue(world.exteriorPracticalLight.isEnabled)
    XCTAssertGreaterThan(world.exteriorPracticalLight.light.intensity, 0)
    for entity in descendants(including: adapter.rig.visualRoot) {
      XCTAssertNil(entity.components[InputTargetComponent.self], entity.name)
      XCTAssertNil(entity.components[CollisionComponent.self], entity.name)
      XCTAssertNil(entity.components[PhysicsBodyComponent.self], entity.name)
    }
    world.restoreProceduralGarageArchitecture()
    XCTAssertNil(world.exteriorPracticalLight.parent)
    XCTAssertFalse(world.exteriorPracticalLight.isEnabled)
  }

  func testV7PresetValuesAreFiniteAndNightUsesPracticalLighting() {
    let day = FounderEnvironmentLightingConfiguration.preset(for: .day)
    let night = FounderEnvironmentLightingConfiguration.preset(for: .night)
    XCTAssertGreaterThan(day.directionalIntensity, night.directionalIntensity)
    XCTAssertGreaterThan(night.hangingPracticalIntensity, day.hangingPracticalIntensity)
    XCTAssertGreaterThan(night.exteriorPracticalIntensity, day.exteriorPracticalIntensity)
    for state in FounderEnvironmentTimeState.allCases {
      let p = FounderEnvironmentLightingConfiguration.preset(for: state)
      for value in [p.directionalIntensity, p.generalFillIntensity, p.hangingPracticalIntensity, p.deskPracticalIntensity, p.exteriorPracticalIntensity] {
        XCTAssertTrue(value.isFinite && value >= 0)
      }
      for v in [p.directionalPosition, p.directionalTarget, p.directionalColor, p.generalFillColor, p.practicalColor, p.backgroundTop, p.backgroundBottom] {
        XCTAssertTrue(v.x.isFinite && v.y.isFinite && v.z.isFinite)
      }
    }
  }

  @MainActor
  func testV7EnvironmentLightingAndCameraOverridesRemainPresentationOnly() async throws {
    let world = FounderGarageRealityWorld()
    let camera = world.cameraController
    let states: [FounderGarageCameraState] = [.front, .whiteboard, .frontBay, .garageDoor]
    let baseline = states.map { camera.recipe(for: $0) }
    _ = try await loadFacilityTier0(in: world, v7: true)
    for (state, expected) in zip(states.dropLast(), baseline.dropLast()) {
      XCTAssertEqual(camera.recipe(for: state).position, expected.position)
      XCTAssertEqual(camera.recipe(for: state).lookTarget, expected.lookTarget)
    }
    XCTAssertEqual(camera.recipe(for: .garageDoor).position, [0.2, 1.45, -2.2])
    XCTAssertEqual(camera.recipe(for: .garageDoor).lookTarget, [0, 1.1, 6])
    XCTAssertGreaterThan(
      simd_distance(
        camera.recipe(for: .garageDoor).position,
        camera.playerSpatialState.playerPose.position
      ),
      1.5
    )
    world.setGarageDoor(.open, reduceMotion: true)
    let spatial = camera.playerSpatialState
    let lightID = world.environmentLight.id
    for state in FounderEnvironmentTimeState.allCases {
      world.setEnvironmentTimeState(state, reduceMotion: true)
      XCTAssertEqual(world.environmentLight.id, lightID)
      XCTAssertEqual(world.environmentLight.components[ImageBasedLightComponent.self]?.intensityExponent,
                     FounderEnvironmentLightingConfiguration.preset(for: state).environmentIntensityExponent)
      XCTAssertEqual(camera.playerSpatialState, spatial)
      XCTAssertEqual(world.garageDoorState, .open)
    }
    world.restoreProceduralGarageArchitecture()
    XCTAssertNil(world.environmentLight.parent)
    XCTAssertFalse(camera.usesV7ExteriorViews)
  }

  func testV7PackageIntegrityContractRejectsCorruption() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: FounderGarageV7AssetContract.resourceName, withExtension: "usdz"))
    var data = try Data(contentsOf: url)
    XCTAssertNoThrow(try FounderGarageV7AssetContract.validatePackage(data))
    data[data.startIndex] ^= 1
    XCTAssertThrowsError(try FounderGarageV7AssetContract.validatePackage(data))
  }

  func testV8PackageIntegrityAndRightSideDoorContract() throws {
    let url = try XCTUnwrap(Bundle.main.url(
      forResource: FounderGarageV8AssetContract.resourceName,
      withExtension: "usdz"
    ))
    var data = try Data(contentsOf: url)
    XCTAssertNoThrow(try FounderGarageV8AssetContract.validatePackage(data))
    data[data.startIndex] ^= 1
    XCTAssertThrowsError(try FounderGarageV8AssetContract.validatePackage(data))
  }

  @MainActor
  func testV8RightSideDoorLoadsAtStableAuthoredTransform() async throws {
    let world = FounderGarageRealityWorld()
    let adapter = try await loadFacilityTier0(in: world, v8: true)
    let door = try XCTUnwrap(adapter.rig.visualRoot.findEntity(
      named: FounderGarageV8AssetContract.rightSideDoorEntityName
    ))
    let bounds = door.visualBounds(relativeTo: adapter.rig.visualRoot)
    let replacedLaptop = try XCTUnwrap(adapter.rig.visualRoot.findEntity(named: "FounderLaptop"))
    XCTAssertEqual(bounds.center.x, 2.43, accuracy: 0.08)
    XCTAssertEqual(bounds.center.y, 1.08, accuracy: 0.08)
    XCTAssertEqual(bounds.center.z, 0.78, accuracy: 0.08)
    XCTAssertGreaterThan(bounds.extents.y, 2.0)
    XCTAssertFalse(replacedLaptop.isEnabled)
    XCTAssertTrue(world.entities.iPhone.isEnabled)
    XCTAssertTrue(world.entities.iPad.isEnabled)
    XCTAssertEqual(world.interaction(for: world.entities.iPhone), .openFounderPhone)
    XCTAssertEqual(world.interaction(for: world.entities.iPad), .openFounderTablet)
    world.applyRuntimeEnclosureVisibility(for: .founderPOV)
    XCTAssertTrue(door.isEnabled)
    world.applyRuntimeEnclosureVisibility(for: .garageOverview)
    XCTAssertFalse(door.isEnabled)
  }

  @MainActor
  func testV7ValidationFailureRestoresProceduralGarage() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v4: true)
    let source = FounderGarageArchitectureSource.bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName)
    let loader = ImmediateGarageArchitectureLoader(result: .failure(FounderGarageV7AssetContract.ValidationError.integrityMismatch))
    await world.requestGarageArchitecture(source, descriptor: .facilityTier0V7, loader: loader)?.value
    guard case .failed = world.architectureLoadState else { return XCTFail("Expected failed V7 validation") }
    XCTAssertEqual(world.activeGarageArchitectureAdapter.source, .procedural)
    XCTAssertEqual(world.interaction(for: world.entities.founderComputerInteractionTarget), .openFounderComputer)
  }

  @MainActor
  private func loadFacilityTier0(
    in world: FounderGarageRealityWorld,
    v3: Bool = false,
    v4: Bool = false,
    v6: Bool = false,
    v7: Bool = false,
    v8: Bool = false
  ) async throws -> ImportedGarageArchitectureAdapter {
    precondition([v3, v4, v6, v7, v8].filter { $0 }.count <= 1)
    let assetName = v8 ? "founder_garage_v8" : v7 ? "founder_garage_v7" : v6
      ? "founder_garage_v6"
      : v4 ? "founder_garage_v4" : (v3 ? "founder_garage_v3" : "founder_garage")
    let descriptor: FounderGarageArchitectureAssetDescriptor = v8 ? .facilityTier0V8 : v7 ? .facilityTier0V7 : v6
      ? .facilityTier0V6
      : v4 ? .facilityTier0V4 : (v3 ? .facilityTier0V3 : .facilityTier0)
    let task = try XCTUnwrap(world.requestGarageArchitecture(
      .bundledProductionAsset(name: assetName),
      descriptor: descriptor
    ))
    await task.value
    guard case .ready = world.architectureLoadState else {
      XCTFail("Facility Tier 0 did not load: \(world.architectureLoadState)")
      throw TestLoaderError.expectedFailure
    }
    return try XCTUnwrap(world.activeGarageArchitectureAdapter as? ImportedGarageArchitectureAdapter)
  }

  @MainActor
  private func advance(
    _ world: FounderGarageRealityWorld,
    frames: Int,
    deltaTime: TimeInterval = 1.0 / 60
  ) {
    for _ in 0..<frames { world.advanceSession(deltaTime: deltaTime) }
  }

  @MainActor
  private func advance(
    _ world: FounderGarageRealityWorld,
    until expected: FounderInteractionPhase,
    limit: Int = 1_200,
    deltaTime: TimeInterval = 1.0 / 60
  ) {
    var observed = Set<FounderInteractionPhase>()
    advance(world, until: expected, observed: &observed, limit: limit, deltaTime: deltaTime)
  }

  @MainActor
  private func advance(
    _ world: FounderGarageRealityWorld,
    until expected: FounderInteractionPhase,
    observed: inout Set<FounderInteractionPhase>,
    limit: Int = 1_200,
    deltaTime: TimeInterval = 1.0 / 60
  ) {
    for _ in 0..<limit where world.interactionCoordinator.phase != expected {
      world.advanceSession(deltaTime: deltaTime)
      observed.insert(world.interactionCoordinator.phase)
    }
    XCTAssertEqual(
      world.interactionCoordinator.phase,
      expected,
      world.interactionCoordinator.diagnostics.deterministicSignature
    )
  }

  private func hasRenderableMaterial(in entity: Entity) -> Bool {
    if let model = entity.components[ModelComponent.self], !model.materials.isEmpty {
      return true
    }
    return entity.children.contains { hasRenderableMaterial(in: $0) }
  }

  @MainActor
  private func makePresentation() -> FounderWorldPresentationModel {
    FounderWorldPresentationModel.derive(
      store: GameStore(),
      progression: FounderProgressionStore(),
      presentation: PresentationCoordinator(timing: .immediate)
    )
  }

  private func assertTransform(
    _ actual: Transform,
    equals expected: Transform,
    accuracy: Float = 0.0001,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(actual.translation.x, expected.translation.x, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.translation.y, expected.translation.y, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.translation.z, expected.translation.z, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.scale.x, expected.scale.x, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.scale.y, expected.scale.y, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.scale.z, expected.scale.z, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.rotation.vector.x, expected.rotation.vector.x, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.rotation.vector.y, expected.rotation.vector.y, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.rotation.vector.z, expected.rotation.vector.z, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.rotation.vector.w, expected.rotation.vector.w, accuracy: accuracy, file: file, line: line)
  }

  @MainActor
  private func makeSyntheticArchitecture(size: SIMD3<Float>) -> Entity {
    let root = Entity()
    root.name = "SyntheticGarageArchitecture"
    let shell = ModelEntity(
      mesh: .generateBox(size: size),
      materials: [SimpleMaterial(color: .gray, roughness: .float(0.7), isMetallic: false)]
    )
    shell.name = "SyntheticGarageShell"
    shell.position = [0, size.y / 2, 0]
    root.addChild(shell)
    return root
  }

  private func descendants(including root: Entity) -> [Entity] {
    [root] + root.children.flatMap { descendants(including: $0) }
  }

  @MainActor
  private func makeSyntheticImportedHierarchy() -> (root: Entity, body: ModelEntity, head: ModelEntity) {
    let root = Entity()
    root.name = "ImportedFounderFixture"
    let bodyContainer = Entity()
    bodyContainer.name = "SkeletonOrBodyContainer"
    let body = ModelEntity(
      mesh: .generateBox(size: [0.4, 0.7, 0.25]),
      materials: [SimpleMaterial(color: .gray, isMetallic: false)]
    )
    body.name = "BodyMesh"
    let headContainer = Entity()
    headContainer.name = "HeadContainer"
    let head = ModelEntity(
      mesh: .generateSphere(radius: 0.18),
      materials: [SimpleMaterial(color: .lightGray, isMetallic: false)]
    )
    head.name = "HeadMesh"
    bodyContainer.addChild(body)
    headContainer.addChild(head)
    root.addChild(bodyContainer)
    root.addChild(headContainer)
    return (root, body, head)
  }

  private func makeRigDescriptor(
    normalization: Transform = .identity
  ) -> FounderAssetRigDescriptor {
    FounderAssetRigDescriptor(
      bodyPath: ["SkeletonOrBodyContainer", "BodyMesh"],
      headPath: ["HeadContainer", "HeadMesh"],
      normalization: FounderVisualNormalization(transform: normalization)
    )
  }

  private enum TestLoaderError: Error {
    case expectedFailure
  }

  @MainActor
  private final class ImmediateGarageArchitectureLoader: FounderGarageArchitectureLoading {
    private let result: Result<Entity, Error>
    private(set) var callCount = 0

    init(result: Result<Entity, Error>) {
      self.result = result
    }

    func load(_ source: FounderGarageArchitectureSource) async throws -> Entity {
      callCount += 1
      return try result.get()
    }
  }

  @MainActor
  private final class ControlledGarageArchitectureLoader: FounderGarageArchitectureLoading {
    private var loadContinuation: CheckedContinuation<Entity, Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var callCount = 0

    func load(_ source: FounderGarageArchitectureSource) async throws -> Entity {
      try await withCheckedThrowingContinuation { continuation in
        loadContinuation = continuation
        callCount += 1
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
      }
    }

    func waitUntilStarted() async {
      guard callCount == 0 else { return }
      await withCheckedContinuation { startWaiters.append($0) }
    }

    func succeed(with entity: Entity) {
      loadContinuation?.resume(returning: entity)
      loadContinuation = nil
    }
  }

  @MainActor
  private final class ImmediateFounderAssetLoader: FounderAssetLoading {
    private let result: Result<Entity, Error>
    private(set) var callCount = 0

    init(result: Result<Entity, Error>) {
      self.result = result
    }

    func load(_ source: FounderVisualSource) async throws -> Entity {
      callCount += 1
      return try result.get()
    }
  }

  @MainActor
  private final class ControlledFounderAssetLoader: FounderAssetLoading {
    private var loadContinuation: CheckedContinuation<Entity, Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var callCount = 0

    func load(_ source: FounderVisualSource) async throws -> Entity {
      try await withCheckedThrowingContinuation { continuation in
        loadContinuation = continuation
        callCount += 1
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
      }
    }

    func waitUntilStarted() async {
      guard callCount == 0 else { return }
      await withCheckedContinuation { startWaiters.append($0) }
    }

    func succeed(with entity: Entity) {
      loadContinuation?.resume(returning: entity)
      loadContinuation = nil
    }
  }

  @MainActor
  private struct CanonicalSnapshot: Equatable {
    var stage: GameStore.Stage
    var sprint: Int
    var venture: Int
    var stats: FounderStats
    var taskCount: Int
    var evidenceCount: Int
    var attentionSpent: Int
    var finance: CompanyFinance
    var randomNumberGenerator: SeededRandomNumberGenerator

    init(store: GameStore) {
      stage = store.stage
      sprint = store.sprint
      venture = store.venture
      stats = store.stats
      taskCount = store.tasks.count
      evidenceCount = store.evidence.count
      attentionSpent = store.founderAttentionSpent
      finance = store.finance
      randomNumberGenerator = store.randomNumberGenerator
    }
  }
}
