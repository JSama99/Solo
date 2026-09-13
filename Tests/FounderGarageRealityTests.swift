import RealityKit
import XCTest
@testable import Solo_Unicorn_Run

final class FounderGarageRealityTests: XCTestCase {
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
    XCTAssertFalse(world.entities.iPhone.isEnabled)
    XCTAssertFalse(world.entities.iPad.isEnabled)
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
    let computer = try XCTUnwrap(space.zone(for: .founderComputer))
    let whiteboard = try XCTUnwrap(space.zone(for: .whiteboard))
    let door = try XCTUnwrap(space.zone(for: .garageDoor))

    XCTAssertEqual(computer.anchorName, "Anchor_Monitor_Face")
    XCTAssertEqual(computer.object.position, authored.monitorFace)
    XCTAssertEqual(computer.approach.position, authored.founderSeat)
    XCTAssertEqual(computer.activationBounds.size, [0.59, 0.34, 0.04])
    XCTAssertEqual(computer.activationBounds.center, authored.monitorFace)
    XCTAssertEqual(whiteboard.object.position, authored.whiteboardFace)
    XCTAssertTrue(spatial.isPointWalkable([whiteboard.approach.position.x, whiteboard.approach.position.z]))
    XCTAssertEqual(door.object.position, authored.doorMouth)
    XCTAssertEqual(door.activationBounds.planarBounds, spatial.occupiedZones.garageDoorClearance)
    XCTAssertTrue(spatial.isPointWalkable([door.approach.position.x, door.approach.position.z]))

    for zone in [computer, whiteboard, door] {
      let approachToObject = zone.object.position - zone.approach.position
      let planarDirection = simd_normalize(SIMD3<Float>(approachToObject.x, 0, approachToObject.z))
      XCTAssertGreaterThan(simd_dot(planarDirection, zone.approach.facingDirection), 0.99, zone.id)
      XCTAssertGreaterThan(zone.interactionDistance.rawValue, 0)
    }
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
    XCTAssertEqual(world.entities.camera.position, world.cameraController.recipe(for: .founderPOV).position)
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

  func testPrototypeRendererRequiresExplicitDevelopmentAllowance() {
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
        arguments: ["Solo Unicorn Run", FounderGarageRendererConfiguration.prototypeLaunchArgument],
        environment: [:],
        prototypeAllowed: false
      ),
      .swiftUI
    )
    XCTAssertEqual(
      FounderGarageRendererConfiguration.resolve(
        arguments: ["Solo Unicorn Run"],
        environment: [:],
        prototypeAllowed: true
      ),
      .swiftUI
    )
  }

  func testOnlyFounderComputerEntityMapsToCanonicalInteractionIntent() {
    XCTAssertEqual(
      FounderWorldInteractionAdapter.interaction(
        forEntityNamed: FounderWorldInteractionAdapter.founderComputerEntityName
      ),
      .openFounderComputer
    )
    XCTAssertNil(FounderWorldInteractionAdapter.interaction(forEntityNamed: "iPhone"))
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
  func testOnlyRegisteredFounderComputerHasNativeAccessibilityAndInputSemantics() {
    let world = FounderGarageRealityWorld()
    let computer = world.entities.founderComputerInteractionTarget
    let phone = world.entities.iPhone

    let accessibility = computer.components[AccessibilityComponent.self]
    XCTAssertEqual(accessibility?.isAccessibilityElement, true)
    XCTAssertEqual(accessibility?.traits.contains(.button), true)
    XCTAssertEqual(accessibility?.systemActions.contains(.activate), true)
    XCTAssertNotNil(computer.components[InputTargetComponent.self])
    XCTAssertNotNil(computer.components[CollisionComponent.self])
    XCTAssertNil(phone.components[AccessibilityComponent.self])
    XCTAssertNil(phone.components[InputTargetComponent.self])
    XCTAssertNil(phone.components[CollisionComponent.self])
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
  func testComputerInteractionUsesRegisteredIdentityInsteadOfEntityName() {
    let world = FounderGarageRealityWorld()
    world.entities.founderComputerInteractionTarget.name = "Renamed for identity verification"

    XCTAssertEqual(
      world.interaction(for: world.entities.founderComputerInteractionTarget),
      .openFounderComputer
    )
    XCTAssertNil(world.interaction(for: world.entities.iPhone))
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
    let canonical = camera.recipe(for: .founderPOV)
    XCTAssertEqual(canonical.position, spatial.anchors.founder.position + [0, 1.18, 0])
    XCTAssertEqual(canonical.lookTarget, spatial.anchors.founderComputer.position)
    XCTAssertEqual(canonical.fieldOfView, 56)
    for target in FounderGarageCameraState.allCases {
      let recipe = camera.recipe(for: target)
      if target == .garageDoor || target == .front {
        XCTAssertGreaterThan(recipe.position.z, spatial.room.interiorBounds.maxZ)
      } else {
        XCTAssertTrue(spatial.cameraViewingRegion.contains([recipe.position.x, recipe.position.z]) || spatial.room.interiorBounds.contains([recipe.position.x, recipe.position.z]))
      }
      XCTAssertGreaterThan(simd_distance(recipe.position, recipe.lookTarget), 1)
      XCTAssertTrue((40...65).contains(recipe.fieldOfView))
    }
    let anchors = try XCTUnwrap(spatial.productionAnchors)
    XCTAssertEqual(camera.recipe(for: .whiteboard).lookTarget, anchors.whiteboardFace)
    XCTAssertEqual(camera.recipe(for: .garageDoor).lookTarget, anchors.doorMouth + [0, 0.05, -0.05])
    XCTAssertEqual(camera.recipe(for: .garageDoor).position, anchors.doorMouth + [2.5, 1.10, 8.80])
    XCTAssertEqual(camera.recipe(for: .front).lookTarget, anchors.doorMouth + [0, 0.05, -0.05])
    XCTAssertEqual(camera.recipe(for: .front).position, anchors.doorMouth + [0, 0.25, 9.45])
    XCTAssertEqual(camera.recipe(for: .frontBay).lookTarget, anchors.agentDeskSurface + [0, 0.15, 0])
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
  func testFounderDisplayIsCenteredInProjectionFromCanonicalSeat() async throws {
    let world = FounderGarageRealityWorld()
    _ = try await loadFacilityTier0(in: world, v4: true)
    let controller = world.cameraController
    let pose = controller.recipe(for: .founderPOV)
    XCTAssertEqual(pose.position, world.spatialSpecification.anchors.founder.position + [0, 1.18, 0])
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
      XCTAssertEqual((try XCTUnwrap(values.min()) + XCTUnwrap(values.max())) / 2, 0, accuracy: 0.001)
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
    XCTAssertEqual(world.cameraController.recipe(for: .founderPOV).position, eye)
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
  func testFreeLookRotatesAtFixedSeatedEyeWithoutRollOrTranslation() {
    let world = FounderGarageRealityWorld()
    let controller = world.cameraController
    let root = controller.playerSpatialState.playerPose
    let neutral = controller.recipe(for: .founderPOV).transform
    controller.setLookOrientation(FounderLookOrientation(yaw: 0.45, pitch: -0.20))
    XCTAssertEqual(controller.playerSpatialState.playerPose, root)
    XCTAssertEqual(controller.playerSpatialState.lookOrientation, FounderLookOrientation(yaw: 0.45, pitch: -0.20))
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
    _ = try await loadFacilityTier0(in: world, v7: true)
    let camera = world.cameraController
    let baseline = FounderGarageCameraConfiguration(spatial: world.spatialSpecification)
    for state in [FounderGarageCameraState.front, .whiteboard, .frontBay] {
      XCTAssertEqual(camera.recipe(for: state).position, baseline.recipe(for: state).position)
      XCTAssertEqual(camera.recipe(for: state).lookTarget, baseline.recipe(for: state).lookTarget)
    }
    XCTAssertGreaterThan(camera.recipe(for: .garageDoor).lookTarget.z, camera.recipe(for: .garageDoor).position.z)
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
    v7: Bool = false
  ) async throws -> ImportedGarageArchitectureAdapter {
    precondition([v3, v4, v6, v7].filter { $0 }.count <= 1)
    let assetName = v7 ? "founder_garage_v7" : v6
      ? "founder_garage_v6"
      : v4 ? "founder_garage_v4" : (v3 ? "founder_garage_v3" : "founder_garage")
    let descriptor: FounderGarageArchitectureAssetDescriptor = v7 ? .facilityTier0V7 : v6
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
