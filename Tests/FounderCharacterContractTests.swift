import XCTest
import RealityKit
@testable import Solo_Unicorn_Run

@MainActor
final class FounderCharacterContractTests: XCTestCase {
  func testCandidateImportsSkeletonSlotsMaterialsAndFacialTargets() async throws {
    XCTAssertNoThrow(try FounderCharacterContract.validateAcceptedRuntimeAsset())
    let asset = try await FounderCharacterContract.load()
    XCTAssertNotNil(asset.findEntity(named: "FounderRoot"))
    XCTAssertEqual(FounderCharacterContract.boneNames(asset), FounderCharacterContract.requiredBones)
    for name in FounderCharacterContract.slots + FounderCharacterContract.headParts + ["BodyMesh", "TopMesh", "BottomMesh", "ShoeMesh"] {
      XCTAssertNotNil(asset.findEntity(named: name), name)
    }
    let models = FounderCharacterContract.models(asset)
    XCTAssertEqual(models.count, 10, "Each skinned module must survive import independently")
    XCTAssertFalse(models.isEmpty)
    for model in models {
      XCTAssertFalse(model.jointNames.isEmpty, model.name)
      XCTAssertEqual(model.jointTransforms.count, model.jointNames.count)
      XCTAssertFalse(model.model?.materials.isEmpty ?? true, model.name)
    }
    let weights = FounderCharacterContract.descendants(asset).flatMap {
      $0.components[BlendShapeWeightsComponent.self]?.weightSet.flatMap(\.weightNames) ?? []
    }
    XCTAssertEqual(Set(weights), FounderCharacterContract.facialTargets, "Imported facial weights: \(weights)")
  }

  func testProductionWorldLoadsExactAcceptedFounderAndPreservesMaskingAndPose() async throws {
    let world = FounderGarageRealityWorld()
    let task = try XCTUnwrap(try world.requestProductionFounder())
    await task.value
    let source = FounderVisualSource.bundledUSDZ(name: FounderCharacterContract.candidateResource)
    XCTAssertEqual(world.assetLoadState, .ready(source))
    let adapter = try XCTUnwrap(world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)
    XCTAssertEqual(adapter.source, source)
    XCTAssertEqual(FounderCharacterContract.boneNames(adapter.rig.visualRoot), FounderCharacterContract.requiredBones)
    XCTAssertNotNil(adapter.rig.authoredPose)
    XCTAssertNil(world.proceduralFounderVisualAdapter.rig.normalizationRoot.parent)
    for target in ["Blink_L", "Blink_R", "JawOpen"] {
      XCTAssertGreaterThan(
        FounderCharacterContract.setFacialTarget(target, weight: 1, on: adapter.rig.visualRoot),
        0,
        "Production Founder must expose \(target) through the normal runtime adapter"
      )
    }

    world.founderAvatarController.locomotion.update(
      spatial: world.cameraController.spatialState,
      collisionBlocked: false,
      firstPerson: true,
      reduceMotion: true,
      deltaTime: 0.1
    )
    XCTAssertEqual(world.founderAvatarController.locomotion.state, .seatedIdle)
    XCTAssertFalse(adapter.rig.visualRoot.isEnabled)
  }

  func testNativeScalePlacementAndIndependentHeadVisibility() async throws {
    let asset = try await FounderCharacterContract.load()
    let bounds = asset.visualBounds(relativeTo: nil)
    XCTAssertGreaterThan(bounds.extents.y, 1.75)
    XCTAssertLessThan(bounds.extents.y, 1.95, "RealityKit may use conservative skeletal bounds; exact mesh height is audited in USD")
    XCTAssertGreaterThan(simd_determinant(asset.transform.matrix), 0)
    let seat = try XCTUnwrap(FounderGarageSpatialSpecification.standard.productionAnchors?.founderSeat)
    let authored = asset.transform
    let placed = FounderCharacterContract.placed(asset, at: seat)
    XCTAssertEqual(placed.position, seat)
    XCTAssertEqual(asset.transform, authored)
    FounderCharacterContract.setHeadVisible(false, on: asset)
    let head = try XCTUnwrap(asset.findEntity(named: "HeadMeshModule"))
    XCTAssertFalse(FounderCharacterContract.models(head).isEmpty, "Head visibility must affect actual renderable geometry")
    XCTAssertFalse(head.isEnabled)
    XCTAssertTrue(try XCTUnwrap(asset.findEntity(named: "BodyMeshModule")).isEnabled)
    FounderCharacterContract.setHeadVisible(true, on: asset)
    XCTAssertTrue(head.isEnabled)
  }

  func testBlinkAndJawOpenTargetsCanBeDrivenAtRuntime() async throws {
    let asset = try await FounderCharacterContract.load()
    for target in ["Blink_L", "Blink_R", "JawOpen"] {
      XCTAssertGreaterThan(FounderCharacterContract.setFacialTarget(target, weight: 1, on: asset), 0, target)
      let values = FounderCharacterContract.descendants(asset).flatMap { entity -> [Float] in
        guard let component = entity.components[BlendShapeWeightsComponent.self] else { return [] }
        return component.weightSet.compactMap { data in
          data.weightNames.firstIndex(of: target).map { data.weights[$0] }
        }
      }
      XCTAssertFalse(values.isEmpty, target)
      XCTAssertTrue(values.allSatisfy { $0 == 1 }, target)
    }
  }

  func testCatalogPreservesGraphAndDeclaresMissingProductionClips() {
    XCTAssertEqual(FounderLocomotionState.allCases.map(\.rawValue), ["seatedIdle", "seatedTurn", "standingUp", "standingIdle", "walkStart", "walking", "walkStop", "turnInPlace", "sittingDown"])
    for state in FounderLocomotionState.allCases { XCTAssertNil(FounderAnimationClipCatalog.clipName(for: state)) }
    XCTAssertFalse(FounderAnimationClipCatalog.rootMotionIsSpatialAuthority)
  }

  func testRoundOnePhaseVariantsAreFiniteBoundedTimingOffsetsOnly() {
    let variants = FounderLocomotionPhaseVariant.allCases
    XCTAssertEqual(variants.map(\.reviewLabel), ["Baseline", "Variant A", "Variant B", "Variant C"])
    XCTAssertEqual(FounderLocomotionPhaseVariant.productionDefault, .c)
    XCTAssertEqual(FounderLocomotionState.allCases.count, 9, "Round 1 must not change graph topology")
    XCTAssertTrue(FounderLocomotionPhaseVariant.baseline.profile.offsets.allSatisfy { $0 == 0 })
    XCTAssertEqual(Set(variants.map { $0.profile.offsets }).count, variants.count)
    for variant in variants {
      XCTAssertTrue(variant.profile.offsets.allSatisfy(\.isFinite), variant.reviewLabel)
      XCTAssertTrue(variant.profile.offsets.allSatisfy { abs($0) <= 0.55 }, variant.reviewLabel)
    }
  }

  func testRoundTwoProfilesAreBoundedAndFreezeRoundOneVariantC() {
    let variants = FounderWeightTransferVariant.allCases
    XCTAssertEqual(variants.map(\.reviewLabel), ["Baseline", "Variant A", "Variant B", "Variant C"])
    XCTAssertEqual(FounderWeightTransferVariant.productionDefault, .baseline)
    XCTAssertEqual(FounderLocomotionPhaseVariant.productionDefault, .c)
    XCTAssertTrue(FounderWeightTransferVariant.baseline.profile.values.allSatisfy { $0 == 0 })
    XCTAssertEqual(Set(variants.map { $0.profile.values }).count, variants.count)
    for variant in variants {
      let profile = variant.profile
      XCTAssertTrue(profile.values.allSatisfy(\.isFinite), variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.pelvisLateralAmplitude, 0.025, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.pelvisRollAmplitude, 0.030, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.torsoCounterbalanceFactor, 0.70, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.shoulderCompensationFactor, 0.35, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.shoulderCompensationFactor, profile.torsoCounterbalanceFactor, variant.reviewLabel)
    }
  }

  func testRoundTwoSupportSignalIsContinuousContralateralAndZeroMean() {
    var biasTotal: Float = 0
    let sampleCount = 720
    for index in 0..<sampleCount {
      let phase = Float(index) / Float(sampleCount) * 2 * .pi
      let frame = FounderWeightTransferFrame.resolve(gaitPhase: phase, gaitWeight: 1, variant: .c)
      XCTAssertGreaterThanOrEqual(frame.leftSupportWeight, 0)
      XCTAssertLessThanOrEqual(frame.leftSupportWeight, 1)
      XCTAssertGreaterThanOrEqual(frame.rightSupportWeight, 0)
      XCTAssertLessThanOrEqual(frame.rightSupportWeight, 1)
      XCTAssertEqual(frame.leftSupportWeight + frame.rightSupportWeight, 1, accuracy: 0.000_001)
      XCTAssertLessThanOrEqual(abs(frame.supportBias), 1.000_001)
      XCTAssertLessThanOrEqual(abs(frame.pelvisLateral), FounderWeightTransferVariant.c.profile.pelvisLateralAmplitude + 0.000_001)
      XCTAssertLessThanOrEqual(abs(frame.pelvisRoll), FounderWeightTransferVariant.c.profile.pelvisRollAmplitude + 0.000_001)
      XCTAssertLessThanOrEqual(abs(frame.shoulderCompensation), abs(frame.torsoCounterbalance) + 0.000_001)
      XCTAssertLessThanOrEqual(frame.pelvisRoll * frame.torsoCounterbalance, 0.000_001)
      biasTotal += frame.supportBias
    }
    XCTAssertEqual(biasTotal / Float(sampleCount), 0, accuracy: 0.000_01)
  }

  func testPassB2ProfilesAreBoundedAndFreezeAcceptedBaselines() {
    let variants = FounderKineticChainVariant.allCases
    XCTAssertEqual(variants.map(\.reviewLabel), ["Baseline", "Variant A", "Variant B", "Variant C"])
    XCTAssertEqual(FounderKineticChainVariant.productionDefault, .b)
    XCTAssertEqual(FounderLocomotionPhaseVariant.productionDefault, .c)
    XCTAssertEqual(FounderWeightTransferVariant.productionDefault, .baseline)
    XCTAssertTrue(FounderKineticChainVariant.baseline.profile.values.allSatisfy { $0 == 0 })
    XCTAssertEqual(Set(variants.map { $0.profile.values }).count, variants.count)
    for variant in variants {
      let profile = variant.profile
      XCTAssertTrue(profile.values.allSatisfy(\.isFinite), variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.supportLoadingStrength, 0.008, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.torsoLag, 0.045, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.shoulderLag, 0.035, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.armFollowThrough, 0.060, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.torsoLag, profile.armFollowThrough, variant.reviewLabel)
      XCTAssertLessThanOrEqual(profile.shoulderLag, profile.armFollowThrough, variant.reviewLabel)
    }
  }

  func testPassB2SupportAndLagSignalsAreContinuousFiniteAndBounded() {
    let phaseRate = FounderGarageCameraConfiguration.walkingSpeed / 0.78 * 2 * Float.pi
    var previous: FounderKineticChainFrame?
    var transitionTotal: Float = 0
    for index in 0...720 {
      let phase = Float(index) / 720 * 2 * .pi
      let frame = FounderKineticChainFrame.resolve(
        gaitPhase: phase,
        gaitWeight: 1,
        phaseRate: phaseRate,
        armPhase: FounderLocomotionPhaseVariant.c.profile.arm,
        variant: .c
      )
      let values = [
        frame.leftSupportWeight, frame.rightSupportWeight, frame.totalSupport,
        frame.supportBias, frame.supportTransitionRate, frame.pelvisLoadResponse,
        frame.pelvisVerticalLoadOffset, frame.torsoPhaseOffset, frame.shoulderPhaseOffset,
        frame.shoulderResponse, frame.armTargetAngle, frame.armPresentedAngle, frame.armLag
      ]
      XCTAssertTrue(values.allSatisfy(\.isFinite))
      XCTAssertEqual(frame.totalSupport, 1, accuracy: 0.000_001)
      XCTAssertGreaterThanOrEqual(frame.pelvisLoadResponse, 0)
      XCTAssertLessThanOrEqual(frame.pelvisLoadResponse, 1)
      XCTAssertLessThanOrEqual(abs(frame.pelvisVerticalLoadOffset), 0.007_501)
      XCTAssertLessThanOrEqual(abs(frame.supportTransitionRate), phaseRate + 0.000_01)
      XCTAssertLessThanOrEqual(abs(frame.armPresentedAngle), 0.250_001)
      if let previous {
        XCTAssertLessThanOrEqual(abs(frame.pelvisVerticalLoadOffset - previous.pelvisVerticalLoadOffset), 0.000_08)
        XCTAssertLessThanOrEqual(abs(frame.armPresentedAngle - previous.armPresentedAngle), 0.003)
      }
      transitionTotal += frame.supportTransitionRate
      previous = frame
    }
    XCTAssertEqual(transitionTotal / 721, 0, accuracy: 0.000_1)
  }

  func testReviewTraversalUsesDeterministicTrackingOnlyForTranslatingSections() {
    let tracked: [FounderMotionReviewSection] = [.walkStart, .continuousWalk, .walkStop, .walkAndTurn]
    for section in FounderMotionReviewSection.allCases {
      XCTAssertEqual(section.usesTrackingReviewCamera, tracked.contains(section), section.rawValue)
    }
  }

  func testFootPhaseResolverIsDeterministicAndContralateral() {
    let quarterCycle = Float.pi / 2
    XCTAssertEqual(FounderFootPhase.resolve(gaitPhase: 0), .plant)
    XCTAssertEqual(FounderFootPhase.resolve(gaitPhase: quarterCycle), .pushOff)
    XCTAssertEqual(FounderFootPhase.resolve(gaitPhase: quarterCycle * 2), .swing)
    XCTAssertEqual(FounderFootPhase.resolve(gaitPhase: quarterCycle * 3), .approachingGround)
    XCTAssertEqual(FounderFootPhase.resolve(gaitPhase: quarterCycle * 4), .plant)
    XCTAssertEqual(FounderFootPhase.resolve(gaitPhase: -quarterCycle), .approachingGround)
    for step in 0..<32 {
      let phase = Float(step) / 32 * 2 * .pi
      XCTAssertEqual(
        FounderFootPhase.resolve(gaitPhase: phase, offset: .pi),
        FounderFootPhase.resolve(gaitPhase: phase + .pi)
      )
      XCTAssertNotEqual(
        FounderFootPhase.resolve(gaitPhase: phase),
        FounderFootPhase.resolve(gaitPhase: phase, offset: .pi)
      )
    }
  }

  func testProductionSeatedIdleAddsBoundedMicroMotionWithoutContactDrift() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    let spatial = world.cameraController.spatialState
    let authored = try XCTUnwrap((world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)?.rig.authoredPose)
    let expectedHips = try XCTUnwrap(authored.baselineTransform(named: "Hips", standing: false))
    let expectedLeftFoot = try XCTUnwrap(authored.baselineTransform(named: "Foot_L", standing: false))
    let expectedRightFoot = try XCTUnwrap(authored.baselineTransform(named: "Foot_R", standing: false))
    let expectedLeftHand = try XCTUnwrap(authored.baselineTransform(named: "Hand_L", standing: false))
    let expectedRightHand = try XCTUnwrap(authored.baselineTransform(named: "Hand_R", standing: false))
    let expectedHead = try XCTUnwrap(authored.baselineTransform(named: "Head", standing: false))
    var maximumHeadAngle: Float = 0

    for _ in 0..<900 {
      locomotion.update(
        spatial: spatial,
        collisionBlocked: false,
        firstPerson: false,
        reduceMotion: false,
        deltaTime: 1.0 / 60
      )
      let sample = try XCTUnwrap(locomotion.latestMotionSample)
      XCTAssertEqual(sample.state, .seatedIdle)
      assertTransform(sample.jointTransforms["Hips"], isCloseTo: expectedHips)
      assertTransform(sample.jointTransforms["Foot_L"], isCloseTo: expectedLeftFoot)
      assertTransform(sample.jointTransforms["Foot_R"], isCloseTo: expectedRightFoot)
      assertTransform(sample.jointTransforms["Hand_L"], isCloseTo: expectedLeftHand)
      assertTransform(sample.jointTransforms["Hand_R"], isCloseTo: expectedRightHand)
      maximumHeadAngle = max(maximumHeadAngle, angularDistance(sample.jointTransforms["Head"]?.rotation, expectedHead.rotation))
      XCTAssertTrue(sampleTransformsAreFinite(sample))
    }

    XCTAssertGreaterThan(maximumHeadAngle, 0.002, "Seated production idle must not remain frozen")
    XCTAssertLessThan(maximumHeadAngle, 0.08, "Seated head/gaze motion must remain restrained")
    XCTAssertEqual(locomotion.diagnostics.seatedAnchorError, 0, accuracy: 0.0001)
  }

  func testProductionStandingIdlePreservesFeetAndUsesAperiodicTorsoMotion() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    for _ in 0..<48 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    }
    XCTAssertEqual(locomotion.state, .standingIdle)
    let authored = try XCTUnwrap((world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)?.rig.authoredPose)
    let expectedHips = try XCTUnwrap(authored.baselineTransform(named: "Hips", standing: true))
    let expectedLeftFoot = try XCTUnwrap(authored.baselineTransform(named: "Foot_L", standing: true))
    let expectedRightFoot = try XCTUnwrap(authored.baselineTransform(named: "Foot_R", standing: true))
    let expectedChest = try XCTUnwrap(authored.baselineTransform(named: "Chest", standing: true))
    var chestAngles: [Float] = []

    for _ in 0..<720 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
      let sample = try XCTUnwrap(locomotion.latestMotionSample)
      assertTransform(sample.jointTransforms["Hips"], isCloseTo: expectedHips)
      assertTransform(sample.jointTransforms["Foot_L"], isCloseTo: expectedLeftFoot)
      assertTransform(sample.jointTransforms["Foot_R"], isCloseTo: expectedRightFoot)
      chestAngles.append(angularDistance(sample.jointTransforms["Chest"]?.rotation, expectedChest.rotation))
      XCTAssertTrue(sampleTransformsAreFinite(sample))
    }

    XCTAssertGreaterThan(chestAngles.max() ?? 0, 0.003)
    XCTAssertLessThan(chestAngles.max() ?? 1, 0.02)
    XCTAssertNotEqual(chestAngles[0], chestAngles[288], "Mixed 4.8 s and 7.3 s breathing periods must avoid a short obvious loop")
  }

  func testProductionSitStandConvergesExactlyAndNeverMovesSpatialAuthority() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    let seated = world.cameraController.spatialState
    var standing = seated
    standing.stance = .standing
    standing.navigationMode = .walking
    let cameraBefore = world.cameraController.spatialState
    for _ in 0..<8 {
      locomotion.update(spatial: standing, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60)
    }
    XCTAssertEqual(locomotion.state, .standingIdle)
    let authored = try XCTUnwrap((world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)?.rig.authoredPose)
    var sample = try XCTUnwrap(locomotion.latestMotionSample)
    assertTransform(sample.jointTransforms["Hips"], isCloseTo: try XCTUnwrap(authored.baselineTransform(named: "Hips", standing: true)))
    assertTransform(sample.jointTransforms["Foot_L"], isCloseTo: try XCTUnwrap(authored.baselineTransform(named: "Foot_L", standing: true)))
    for _ in 0..<8 {
      locomotion.update(spatial: seated, collisionBlocked: false, firstPerson: true, reduceMotion: true, deltaTime: 1.0 / 60)
    }
    XCTAssertEqual(locomotion.state, .seatedIdle)
    sample = try XCTUnwrap(locomotion.latestMotionSample)
    assertTransform(sample.jointTransforms["Hips"], isCloseTo: try XCTUnwrap(authored.baselineTransform(named: "Hips", standing: false)))
    assertTransform(sample.jointTransforms["Foot_L"], isCloseTo: try XCTUnwrap(authored.baselineTransform(named: "Foot_L", standing: false)))
    XCTAssertEqual(locomotion.diagnostics.seatedAnchorError, 0, accuracy: 0.0001)
    XCTAssertEqual(world.cameraController.spatialState, cameraBefore)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testProductionGaitMatchesWorldSpeedAndBlendsStartStop() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    var startWeights: [Float] = []
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      if locomotion.state == .walkStart { startWeights.append(locomotion.diagnostics.gaitWeight) }
    }
    XCTAssertEqual(locomotion.state, .walking)
    XCTAssertEqual(startWeights, startWeights.sorted())
    let firstWalk = try XCTUnwrap(locomotion.latestMotionSample?.jointTransforms["Foot_L"])
    for _ in 0..<120 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      XCTAssertLessThanOrEqual(locomotion.diagnostics.footSlideRatio, 0.02)
      XCTAssertTrue(sampleTransformsAreFinite(try XCTUnwrap(locomotion.latestMotionSample)))
    }
    let laterWalk = try XCTUnwrap(locomotion.latestMotionSample?.jointTransforms["Foot_L"])
    XCTAssertNotEqual(firstWalk.rotation, laterWalk.rotation)
    XCTAssertEqual(locomotion.diagnostics.gaitCycleDistance, 0.78, accuracy: 0.001)

    spatial.horizontalVelocity = .zero
    spatial.movementMagnitude = 0
    var stopWeights: [Float] = []
    for _ in 0..<20 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      if locomotion.state == .walkStop { stopWeights.append(locomotion.diagnostics.gaitWeight) }
    }
    XCTAssertEqual(locomotion.state, .standingIdle)
    XCTAssertEqual(stopWeights, stopWeights.sorted(by: >))
  }

  func testRoundOneVariantsPreserveWorldAuthoritySpeedCadenceAndFiniteTransforms() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    let cameraBefore = world.cameraController.spatialState

    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(
        spatial: spatial,
        collisionBlocked: false,
        firstPerson: false,
        reduceMotion: false,
        deltaTime: TimeInterval(delta)
      )
    }
    XCTAssertEqual(locomotion.state, .walking)

    for variant in FounderLocomotionPhaseVariant.allCases {
      locomotion.configurePhaseVariantForReview(variant)
      var observedLeft: Set<FounderFootPhase> = []
      var observedRight: Set<FounderFootPhase> = []
      for _ in 0..<60 {
        spatial.position.z += spatial.horizontalVelocity.y * delta
        locomotion.update(
          spatial: spatial,
          collisionBlocked: false,
          firstPerson: false,
          reduceMotion: false,
          deltaTime: TimeInterval(delta)
        )
        let sample = try XCTUnwrap(locomotion.latestMotionSample)
        XCTAssertEqual(sample.rootTransform.translation, spatial.position, variant.reviewLabel)
        XCTAssertEqual(locomotion.diagnostics.phaseVariant, variant)
        XCTAssertEqual(
          locomotion.diagnostics.movementMagnitude,
          FounderGarageCameraConfiguration.walkingSpeed,
          accuracy: 0.000_001
        )
        XCTAssertEqual(locomotion.diagnostics.gaitCycleDistance, 0.78, accuracy: 0.001)
        XCTAssertLessThanOrEqual(locomotion.diagnostics.footSlideRatio, 0.02)
        XCTAssertTrue(sampleTransformsAreFinite(sample), variant.reviewLabel)
        observedLeft.insert(locomotion.diagnostics.leftFootPhase)
        observedRight.insert(locomotion.diagnostics.rightFootPhase)
      }
      XCTAssertEqual(observedLeft, Set(FounderFootPhase.allCases), variant.reviewLabel)
      XCTAssertEqual(observedRight, Set(FounderFootPhase.allCases), variant.reviewLabel)
    }

    XCTAssertEqual(world.cameraController.spatialState, cameraBefore)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testGLWT01StraightWeightTransferPreservesContactsAndWorldAuthority() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    for variant in FounderWeightTransferVariant.allCases {
      locomotion.configureWeightTransferVariantForReview(variant)
      for _ in 0..<180 {
        spatial.position.z += spatial.horizontalVelocity.y * delta
        locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
        let frame = locomotion.diagnostics.weightTransfer
        let profile = variant.profile
        XCTAssertEqual(locomotion.diagnostics.phaseVariant, .c, variant.reviewLabel)
        XCTAssertEqual(frame.variant, variant)
        XCTAssertLessThanOrEqual(abs(frame.pelvisLateral), profile.pelvisLateralAmplitude + 0.000_001)
        XCTAssertLessThanOrEqual(abs(frame.pelvisRoll), profile.pelvisRollAmplitude + 0.000_001)
        XCTAssertLessThanOrEqual(abs(frame.torsoCounterbalance), profile.pelvisRollAmplitude * profile.torsoCounterbalanceFactor + 0.000_001)
        XCTAssertLessThanOrEqual(abs(frame.shoulderCompensation), profile.pelvisRollAmplitude * profile.shoulderCompensationFactor + 0.000_001)
        XCTAssertEqual(try XCTUnwrap(locomotion.latestMotionSample).rootTransform.translation, spatial.position)
        XCTAssertLessThanOrEqual(locomotion.diagnostics.footSlideRatio, 0.02)
        XCTAssertTrue(sampleTransformsAreFinite(try XCTUnwrap(locomotion.latestMotionSample)))
      }
    }
  }

  func testGLWT02LongTraversalHasNoLocalOrRootDrift() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    XCTAssertEqual(locomotion.state, .walking)
    for _ in 0..<720 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      XCTAssertEqual(try XCTUnwrap(locomotion.latestMotionSample).rootTransform.translation, spatial.position)
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.weightTransfer.pelvisLateral), 0.022_001)
      XCTAssertTrue(sampleTransformsAreFinite(try XCTUnwrap(locomotion.latestMotionSample)))
    }
    XCTAssertEqual(locomotion.diagnostics.gaitCycleDistance, 0.78, accuracy: 0.001)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testGLWT03MovingTurnKeepsWeightLayerAndFacingBounded() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    let speed = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    spatial.horizontalVelocity = [0, -speed]
    spatial.movementMagnitude = speed
    spatial.facingDirection = [0, 0, -1]
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    XCTAssertEqual(locomotion.state, .walking)
    var previousFacing = locomotion.diagnostics.avatarFacing
    for index in 0..<240 {
      let angle = min(Float(index) / 180, 1) * (.pi / 4)
      spatial.horizontalVelocity = [sin(angle) * speed, -cos(angle) * speed]
      spatial.movementMagnitude = speed
      spatial.facingDirection = [sin(angle), 0, -cos(angle)]
      spatial.position.x += spatial.horizontalVelocity.x * delta
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.avatarFacing - previousFacing), 5.0 * delta + 0.000_01)
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.weightTransfer.pelvisRoll), 0.026_001)
      XCTAssertLessThanOrEqual(locomotion.diagnostics.footSlideRatio, 0.02)
      previousFacing = locomotion.diagnostics.avatarFacing
    }
  }

  func testGLWT04StartStopAndReduceMotionEnvelopeWeightTransfer() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    let delta: Float = 1.0 / 60
    for _ in 0..<48 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    XCTAssertEqual(locomotion.diagnostics.weightTransfer.pelvisLateral, 0)

    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    var previousLateral: Float = 0
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      let lateral = locomotion.diagnostics.weightTransfer.pelvisLateral
      XCTAssertLessThanOrEqual(abs(lateral - previousLateral), 0.008)
      XCTAssertLessThanOrEqual(abs(lateral), FounderWeightTransferVariant.c.profile.pelvisLateralAmplitude * locomotion.diagnostics.gaitWeight + 0.000_001)
      previousLateral = lateral
    }

    spatial.horizontalVelocity = .zero
    spatial.movementMagnitude = 0
    for _ in 0..<30 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    XCTAssertEqual(locomotion.state, .standingIdle)
    XCTAssertEqual(locomotion.diagnostics.weightTransfer.pelvisLateral, 0)
    XCTAssertEqual(locomotion.diagnostics.weightTransfer.pelvisRoll, 0)

    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: TimeInterval(delta))
    XCTAssertEqual(locomotion.diagnostics.weightTransfer.pelvisLateral, 0)
    XCTAssertEqual(locomotion.diagnostics.weightTransfer.pelvisRoll, 0)
  }

  func testGK01StraightCruisePreservesContactAndExposesBoundedKineticChain() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.baseline)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    XCTAssertEqual(locomotion.state, .walking)

    for variant in FounderKineticChainVariant.allCases {
      locomotion.configureKineticChainVariantForReview(variant)
      var maximumPelvisLoad: Float = 0
      var maximumArmLag: Float = 0
      for _ in 0..<180 {
        spatial.position.z += spatial.horizontalVelocity.y * delta
        locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
        let frame = locomotion.diagnostics.kineticChain
        XCTAssertEqual(frame.variant, variant)
        XCTAssertEqual(locomotion.diagnostics.phaseVariant, .c)
        XCTAssertEqual(locomotion.diagnostics.weightTransfer.variant, .baseline)
        XCTAssertLessThanOrEqual(abs(frame.pelvisVerticalLoadOffset), variant.profile.supportLoadingStrength + 0.000_001)
        XCTAssertLessThanOrEqual(abs(frame.shoulderResponse), 0.036_001)
        XCTAssertLessThanOrEqual(abs(frame.armPresentedAngle), 0.250_001)
        XCTAssertEqual(try XCTUnwrap(locomotion.latestMotionSample).rootTransform.translation, spatial.position)
        XCTAssertLessThanOrEqual(locomotion.diagnostics.footSlideRatio, 0.02)
        XCTAssertTrue(sampleTransformsAreFinite(try XCTUnwrap(locomotion.latestMotionSample)))
        maximumPelvisLoad = max(maximumPelvisLoad, abs(frame.pelvisVerticalLoadOffset))
        maximumArmLag = max(maximumArmLag, abs(frame.armLag))
      }
      if variant == .baseline {
        XCTAssertEqual(maximumPelvisLoad, 0)
        XCTAssertEqual(maximumArmLag, 0, accuracy: 0.000_001)
      } else {
        XCTAssertGreaterThan(maximumPelvisLoad, 0)
        XCTAssertGreaterThan(maximumArmLag, 0)
      }
    }
  }

  func testGK02WalkStartEnvelopesKineticChainWithoutPoppingOrReduceMotionLeak() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.baseline)
    locomotion.configureKineticChainVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    let delta: Float = 1.0 / 60
    for _ in 0..<48 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    var previousPelvis: Float = 0
    var previousArm: Float = 0
    for _ in 0..<30 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      let frame = locomotion.diagnostics.kineticChain
      XCTAssertLessThanOrEqual(abs(frame.pelvisVerticalLoadOffset - previousPelvis), 0.0025)
      XCTAssertLessThanOrEqual(abs(frame.armPresentedAngle - previousArm), 0.09)
      XCTAssertLessThanOrEqual(abs(frame.pelvisVerticalLoadOffset), FounderKineticChainVariant.c.profile.supportLoadingStrength * locomotion.diagnostics.gaitWeight + 0.000_001)
      previousPelvis = frame.pelvisVerticalLoadOffset
      previousArm = frame.armPresentedAngle
    }
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: TimeInterval(delta))
    XCTAssertEqual(locomotion.diagnostics.kineticChain.pelvisVerticalLoadOffset, 0)
    XCTAssertEqual(locomotion.diagnostics.kineticChain.shoulderResponse, 0)
    XCTAssertEqual(locomotion.diagnostics.kineticChain.armPresentedAngle, 0)
  }

  func testGK03WalkStopSettlesToUnchangedStandingEndpoints() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let adapter = try XCTUnwrap(world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.baseline)
    locomotion.configureKineticChainVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    for _ in 0..<80 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    spatial.horizontalVelocity = .zero
    spatial.movementMagnitude = 0
    for _ in 0..<30 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    XCTAssertEqual(locomotion.state, .standingIdle)
    let frame = locomotion.diagnostics.kineticChain
    XCTAssertEqual(frame.pelvisVerticalLoadOffset, 0)
    XCTAssertEqual(frame.shoulderResponse, 0)
    XCTAssertEqual(frame.armPresentedAngle, 0)
    let sample = try XCTUnwrap(locomotion.latestMotionSample)
    assertTransform(sample.jointTransforms["Hips"], isCloseTo: try XCTUnwrap(adapter.rig.authoredPose?.baselineTransform(named: "Hips", standing: true)))
    assertTransform(sample.jointTransforms["UpperArm_L"], isCloseTo: try XCTUnwrap(adapter.rig.authoredPose?.baselineTransform(named: "UpperArm_L", standing: true)))
  }

  func testGK04MildTurnKeepsKineticChainAndFacingBounded() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.baseline)
    locomotion.configureKineticChainVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    let speed = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    spatial.horizontalVelocity = [0, -speed]
    spatial.movementMagnitude = speed
    spatial.facingDirection = [0, 0, -1]
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    var previousFacing = locomotion.diagnostics.avatarFacing
    for index in 0..<240 {
      let angle = min(Float(index) / 180, 1) * (.pi / 4)
      spatial.horizontalVelocity = [sin(angle) * speed, -cos(angle) * speed]
      spatial.movementMagnitude = speed
      spatial.facingDirection = [sin(angle), 0, -cos(angle)]
      spatial.position.x += spatial.horizontalVelocity.x * delta
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.avatarFacing - previousFacing), 5.0 * delta + 0.000_01)
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.kineticChain.pelvisVerticalLoadOffset), 0.007_501)
      XCTAssertLessThanOrEqual(locomotion.diagnostics.footSlideRatio, 0.02)
      previousFacing = locomotion.diagnostics.avatarFacing
    }
  }

  func testGK05LongTraversalHasNoKineticChainOrRootDrift() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let locomotion = world.founderAvatarController.locomotion
    locomotion.configurePhaseVariantForReview(.c)
    locomotion.configureWeightTransferVariantForReview(.baseline)
    locomotion.configureKineticChainVariantForReview(.c)
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = [0, -FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    let delta: Float = 1.0 / 60
    for _ in 0..<60 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
    }
    for _ in 0..<720 {
      spatial.position.z += spatial.horizontalVelocity.y * delta
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: TimeInterval(delta))
      XCTAssertEqual(try XCTUnwrap(locomotion.latestMotionSample).rootTransform.translation, spatial.position)
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.kineticChain.pelvisVerticalLoadOffset), 0.007_501)
      XCTAssertLessThanOrEqual(abs(locomotion.diagnostics.kineticChain.armPresentedAngle), 0.250_001)
      XCTAssertTrue(sampleTransformsAreFinite(try XCTUnwrap(locomotion.latestMotionSample)))
    }
    XCTAssertEqual(locomotion.diagnostics.gaitCycleDistance, 0.78, accuracy: 0.001)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testProductionTurnUsesBoundedAnticipationThenFirstPersonEnforcesSeatedMask() async throws {
    let world = FounderGarageRealityWorld()
    await try XCTUnwrap(try world.requestProductionFounder()).value
    let adapter = try XCTUnwrap(world.activeFounderVisualAdapter as? USDZFounderVisualAdapter)
    let locomotion = world.founderAvatarController.locomotion
    var spatial = world.cameraController.spatialState
    spatial.stance = .standing
    spatial.navigationMode = .walking
    for _ in 0..<8 {
      locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: true, deltaTime: 1.0 / 60)
    }
    let facingBefore = locomotion.diagnostics.avatarFacing
    spatial.facingDirection = [-1, 0, 0]
    locomotion.update(spatial: spatial, collisionBlocked: false, firstPerson: false, reduceMotion: false, deltaTime: 1.0 / 60)
    XCTAssertEqual(locomotion.state, .turnInPlace)
    XCTAssertLessThan(abs(locomotion.diagnostics.avatarFacing - facingBefore), 0.10, "Turn must anticipate rather than snap")
    let sample = try XCTUnwrap(locomotion.latestMotionSample)
    let restSpine = try XCTUnwrap(adapter.rig.authoredPose?.baselineTransform(named: "Spine01", standing: true))
    let restHead = try XCTUnwrap(adapter.rig.authoredPose?.baselineTransform(named: "Head", standing: true))
    let spineAngle = angularDistance(sample.jointTransforms["Spine01"]?.rotation, restSpine.rotation)
    let headAngle = angularDistance(sample.jointTransforms["Head"]?.rotation, restHead.rotation)
    XCTAssertGreaterThan(spineAngle, 0.01)
    XCTAssertGreaterThan(headAngle, spineAngle)
    XCTAssertLessThan(headAngle, 0.10)
    XCTAssertTrue(sampleTransformsAreFinite(sample))
    XCTAssertTrue(adapter.rig.visualRoot.isEnabled)

    locomotion.update(
      spatial: spatial,
      collisionBlocked: false,
      firstPerson: true,
      reduceMotion: false,
      deltaTime: 1.0 / 60
    )
    XCTAssertEqual(locomotion.state, .seatedIdle)
    XCTAssertFalse(adapter.rig.visualRoot.isEnabled)
    XCTAssertTrue(locomotion.diagnostics.firstPersonHeadHidden)
  }

  func testAuthoredSeatedPosePreservesRigAndGroundsBothLegs() async throws {
    let pose = try FounderCharacterValidationPose.load()
    XCTAssertEqual(Set(pose.seated.keys), FounderCharacterContract.requiredBones)
    let asset = try await FounderCharacterContract.load()
    let model = try XCTUnwrap(FounderCharacterContract.models(asset).first)
    var world: [String: simd_float4x4] = [:]
    for path in model.jointNames {
      let components = path.split(separator: "/")
      let name = String(try XCTUnwrap(components.last))
      let local = try XCTUnwrap(pose.transform(for: name)).matrix
      XCTAssertGreaterThan(simd_determinant(local), 0.99, name)
      let parent = components.dropLast().joined(separator: "/")
      world[path] = (world[parent] ?? matrix_identity_float4x4) * local
    }
    func point(_ name: String) throws -> SIMD3<Float> {
      let path = try XCTUnwrap(model.jointNames.first { $0.split(separator: "/").last == Substring(name) })
      let value = try XCTUnwrap(world[path]).columns.3
      // Authored bones use Blender Z-up under the retained USD root conversion.
      return [value.x, value.z + pose.root_vertical_offset, -value.y]
    }
    let hip = try point("Hips")
    XCTAssertEqual(hip.y, 0.49224, accuracy: 0.005, "Pelvis remains above the 0.45m chair cushion")
    let leftKnee = try point("Calf_L")
    let rightKnee = try point("Calf_R")
    XCTAssertEqual(leftKnee.y, rightKnee.y, accuracy: 0.002)
    XCTAssertLessThan(max(leftKnee.y, rightKnee.y) + 0.10, 0.72, "Thigh/knee envelope below desk underside")
    for side in ["L", "R"] {
      let ankle = try point("Foot_" + side)
      XCTAssertEqual(ankle.y, 0.07214, accuracy: 0.003, "Sole-to-ankle distance preserves floor contact")
      XCTAssertEqual(abs(ankle.x), 0.13111, accuracy: 0.003, "No crossed or asymmetric legs")
    }
    XCTAssertEqual(pose.sole_floor_error, 0, accuracy: 0.001)

    let leftEye = try point("Eye_L")
    let rightEye = try point("Eye_R")
    let eyeMidpointLocal = (leftEye + rightEye) / 2
    let seat = try XCTUnwrap(FounderGarageSpatialSpecification.standard.productionAnchors?.founderSeat)
    let eyeMidpoint = seat + [-eyeMidpointLocal.x, eyeMidpointLocal.y, -eyeMidpointLocal.z]
    let camera = FounderGarageCameraConfiguration(spatial: .standard).recipe(for: .founderPOV).position
    XCTAssertLessThanOrEqual(abs(eyeMidpoint.y - camera.y), 0.015, "Seated eyes must remain within 15 mm of the canonical POV height")
    XCTAssertLessThanOrEqual(
      simd_distance(SIMD2<Float>(eyeMidpoint.x, eyeMidpoint.z), SIMD2<Float>(camera.x, camera.z)),
      0.025,
      "Seated eyes must remain within 25 mm horizontally of the canonical POV"
    )
    for side in ["L", "R"] {
      let hand = try point("Hand_" + side)
      XCTAssertLessThanOrEqual(abs(hand.y - 0.7575), 0.05, "Hands must remain usable at desktop height")
    }
  }

  func testValidationMaskPreservesCanonicalFounderPOV() async throws {
    let candidate = try await FounderCharacterContract.load()
    let state = FounderCharacterQAState()
    try state.bind(candidate)
    state.placement = FounderCharacterContract.placed(candidate, at: .zero)
    state.camera = PerspectiveCamera()
    state.firstPerson = true
    state.update()
    let expected = FounderGarageCameraConfiguration(spatial: .standard).recipe(for: .founderPOV)
    XCTAssertEqual(expected.position, SIMD3<Float>(0.34, 1.18, -0.22))
    XCTAssertEqual(expected.lookTarget, SIMD3<Float>(1.42, 1.30, -1.08))
    XCTAssertEqual(state.camera?.position, expected.position)
    XCTAssertEqual(state.headModules.count, 6)
    XCTAssertTrue(state.headModules.allSatisfy { !$0.isEnabled })
    XCTAssertTrue(try XCTUnwrap(candidate.findEntity(named: "BodyMeshModule")).isEnabled)
    for name in ["EyeMesh_L", "EyeMesh_R"] {
      XCTAssertFalse(FounderCharacterContract.models(try XCTUnwrap(candidate.findEntity(named: name + "Module"))).isEmpty)
    }
  }

  private func angularDistance(_ lhs: simd_quatf?, _ rhs: simd_quatf) -> Float {
    guard let lhs else { return .infinity }
    return 2 * acos(min(abs(simd_dot(lhs.vector, rhs.vector)), 1))
  }

  private func sampleTransformsAreFinite(_ sample: FounderMotionCaptureSample) -> Bool {
    let transforms = [sample.rootTransform] + Array(sample.jointTransforms.values)
    return transforms.allSatisfy { transform in
      transform.translation.x.isFinite && transform.translation.y.isFinite && transform.translation.z.isFinite
        && transform.scale.x.isFinite && transform.scale.y.isFinite && transform.scale.z.isFinite
        && transform.rotation.vector.x.isFinite && transform.rotation.vector.y.isFinite
        && transform.rotation.vector.z.isFinite && transform.rotation.vector.w.isFinite
    }
  }

  private func assertTransform(
    _ actual: Transform?,
    isCloseTo expected: Transform,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard let actual else {
      XCTFail("Missing sampled transform", file: file, line: line)
      return
    }
    XCTAssertLessThanOrEqual(simd_distance(actual.translation, expected.translation), 0.000_001, file: file, line: line)
    XCTAssertLessThanOrEqual(simd_distance(actual.scale, expected.scale), 0.000_001, file: file, line: line)
    XCTAssertLessThanOrEqual(angularDistance(actual.rotation, expected.rotation), 0.001_1, file: file, line: line)
  }
}
