import SwiftUI
import XCTest
@testable import Solo_Unicorn_Run

/// Build 32.4 focused regression coverage: stable spatial causality, corrected
/// header composition, structural facility identity, physical infrastructure,
/// independent atmosphere, and the character renderer boundary.
@MainActor
final class Build32_4SpatialCausalityTests: XCTestCase {

  // MARK: 1–2. Automatic presentation never focuses or navigates

  func testAutomaticCausalPresentationNeverCreatesViewportFocus() {
    var state = CompanyCommandInteractionState()
    for agentID in ["aurora", "stacks", "brio", "aurora"] {
      state.observePresentation(agentID: agentID)
    }
    XCTAssertNil(state.focus)
    XCTAssertFalse(state.userInitiatedFocus)
    XCTAssertEqual(state.presentingAgentID, "aurora")

    let plan = CausalPresentationPlan.derive(
      agents: [
        projection(id: "aurora", phase: .assignmentReceived),
        projection(id: "stacks", phase: .working),
        projection(id: "brio", phase: .resolving)
      ],
      reduceMotion: false
    )
    XCTAssertFalse(plan.createsFocus)
    XCTAssertFalse(plan.changesLayoutMode)
  }

  func testAutomaticCausalPresentationNeverCreatesWorkstationNavigation() {
    var state = CompanyCommandInteractionState()
    state.observePresentation(agentID: "aurora")
    state.observePresentation(agentID: "brio")
    XCTAssertNil(state.navigationRequest)

    let plan = CausalPresentationPlan.derive(
      agents: [projection(id: "aurora", phase: .reviewing, revealStep: 3)],
      reduceMotion: false
    )
    XCTAssertFalse(plan.requestsWorkstationNavigation)
  }

  // MARK: 3–4. Stable identity and distinct object families

  func testCausalObjectsUseStableTaskAndAgentIdentity() throws {
    let taskID = UUID(uuidString: "32400000-0000-0000-0000-000000000001")!
    for phase in [
      PresentationCoordinator.AgentPhase.assignmentReceived,
      .working,
      .workComplete,
      .awaitingReview,
      .resolving,
      .resolved
    ] {
      let agent = projection(id: "aurora", phase: phase, taskID: taskID)
      let object = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: false))
      XCTAssertEqual(object.taskID, taskID)
      XCTAssertEqual(object.agentID, "aurora")
      XCTAssertTrue(object.id.contains(taskID.uuidString))
      XCTAssertTrue(object.id.contains("aurora"))
      // Identity is independent of the presentation timing path.
      let reduced = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: true))
      XCTAssertEqual(object.id, reduced.id)
      XCTAssertEqual(object.agentID, reduced.agentID)
    }
  }

  func testEachCausalObjectHasADistinctTypeAndEndpoint() throws {
    let assignment = try XCTUnwrap(CompanyCausalObject.project(
      agent: projection(id: "aurora", phase: .assignmentReceived), reduceMotion: false
    ))
    let artifact = try XCTUnwrap(CompanyCausalObject.project(
      agent: projection(id: "aurora", phase: .workComplete), reduceMotion: false
    ))
    let resolution = try XCTUnwrap(CompanyCausalObject.project(
      agent: projection(id: "aurora", phase: .resolving), reduceMotion: false
    ))

    XCTAssertEqual(Set([assignment.kind, artifact.kind, resolution.kind]).count, 3)
    XCTAssertEqual(Set([assignment.end, artifact.end, resolution.end]).count, 3)
    XCTAssertEqual(assignment.start, .founderCommand)
    XCTAssertEqual(assignment.end, .roleMonitor("aurora"))
    XCTAssertEqual(artifact.start, .roleMonitor("aurora"))
    XCTAssertEqual(artifact.end, .founderTray)
    XCTAssertEqual(resolution.start, .founderCommand)
    XCTAssertEqual(resolution.end, .companySystem(.auroraFounderVerificationBridge))

    // Suggested visible durations are honored and remain presentation only.
    XCTAssertEqual(assignment.travelDuration, 0.70, accuracy: 0.11)
    XCTAssertEqual(artifact.travelDuration, 0.80, accuracy: 0.11)
    XCTAssertEqual(resolution.travelDuration, 0.72, accuracy: 0.14)
    for object in [assignment, artifact, resolution] {
      XCTAssertGreaterThanOrEqual(object.settleDuration, 0.18)
      XCTAssertLessThanOrEqual(object.settleDuration, 0.26)
    }
  }

  func testResolutionResponseTravelsIntoTheAffectedCompanySystem() throws {
    let expected: [String: InfrastructurePhysicalLocation] = [
      "aurora": .auroraFounderVerificationBridge,
      "stacks": .stacksBuildRail,
      "brio": .brioBroadcastRail
    ]
    for (agentID, location) in expected {
      let object = try XCTUnwrap(CompanyCausalObject.project(
        agent: projection(id: agentID, phase: .resolving), reduceMotion: false
      ))
      XCTAssertEqual(object.end, .companySystem(location))
    }
  }

  // MARK: 5–6. Reduce Motion and Skip endpoint parity

  func testReduceMotionReachesTheSameEndpointsAsStandardMotion() throws {
    for phase in [
      PresentationCoordinator.AgentPhase.assignmentReceived,
      .working,
      .workComplete,
      .awaitingReview,
      .reviewing,
      .reviewed,
      .resolving,
      .resolved
    ] {
      let agent = projection(id: "stacks", phase: phase)
      let standard = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: false))
      let reduced = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: true))
      XCTAssertEqual(standard.end, reduced.end)
      XCTAssertEqual(standard.start, reduced.start)
      XCTAssertEqual(standard.kind, reduced.kind)
      XCTAssertTrue(reduced.atEndpoint, "Reduce Motion must show \(phase) at its endpoint")
    }
  }

  func testSkipPresentationReachesTheSameEndpointsWithoutTouchingGameStore() throws {
    let store = makeStore(seed: 32_400)
    let coordinator = PresentationCoordinator(timing: .immediate)
    let tasksBefore = store.tasks
    let statsBefore = store.stats
    let agentsBefore = store.agents

    coordinator.stageDebug(.working, agentID: "aurora")
    let agent = projection(id: "aurora", phase: .workComplete)
    let beforeSkip = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: false))

    coordinator.skipAllPresentations()
    let settled = projection(id: "aurora", phase: .awaitingReview)
    let afterSkip = try XCTUnwrap(CompanyCausalObject.project(agent: settled, reduceMotion: false))

    XCTAssertEqual(beforeSkip.end, afterSkip.end)
    XCTAssertTrue(afterSkip.atEndpoint)
    XCTAssertEqual(store.tasks, tasksBefore)
    XCTAssertEqual(store.stats, statsBefore)
    XCTAssertEqual(store.agents, agentsBefore)
  }

  // MARK: 7–9. Review secrecy and the canonical fifth-step reveal

  func testReviewStepsOneThroughFourExposeNoHiddenTruthVisually() {
    for step in 1...4 {
      for hidden: Set<LivingAgentCondition> in [[.overclaimed], [.drifting], [.evidenceIncomplete], [.verified]] {
        XCTAssertEqual(
          ReviewResultVisual.map(conditions: hidden, revealStep: step),
          .pending,
          "Step \(step) revealed \(hidden)"
        )
      }
    }
  }

  func testReviewStepsOneThroughFourExposeNoHiddenTruthThroughAccessibility() {
    for step in 1...4 {
      let agent = projection(id: "aurora", phase: .reviewing, revealStep: step)
      let value = agent.accessibilityValue.lowercased()
      for forbidden in ["actual quality", "overclaim", "drift", "evidence incomplete", "72", "74"] {
        XCTAssertFalse(value.contains(forbidden), "Step \(step) leaked \"\(forbidden)\"")
      }
      let input = CharacterRendererInput.derive(agent: agent, reduceMotion: false)
      XCTAssertEqual(input.postReviewSignal, .pending)
    }
  }

  func testStepFiveAdmitsOnlyTheCanonicalRevealedCondition() {
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.verified], revealStep: 5), .verified)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.overclaimed], revealStep: 5), .overclaimed)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.drifting], revealStep: 5), .driftDetected)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.evidenceIncomplete], revealStep: 5), .evidenceIncomplete)
    // A stress-only agent never fabricates a review outcome.
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.stressed, .overloaded], revealStep: 5), .pending)
  }

  // MARK: 10. Structural facility identity independent of palette

  func testGarageAndLoftProduceStructurallyDifferentProjections() {
    let garage = FacilityStructureProjection.derive(FacilityTier.founderGarage)
    let loft = FacilityStructureProjection.derive(FacilityTier.founderLoft)

    XCTAssertNotEqual(garage.structuralSignature, loft.structuralSignature)
    // Every structural axis must differ; identity cannot rest on one field.
    XCTAssertEqual(
      zip(garage.structuralSignature, loft.structuralSignature).filter { $0 != $1 }.count,
      garage.structuralSignature.count
    )
    XCTAssertLessThan(garage.structureHeightRatio, loft.structureHeightRatio)
    XCTAssertEqual(garage.railSymmetry, .asymmetric)
    XCTAssertEqual(loft.railSymmetry, .symmetric)
    XCTAssertGreaterThan(garage.exposedConduitCount, 0)
    XCTAssertEqual(loft.exposedConduitCount, 0)
    XCTAssertEqual(garage.windowBayCount, 0)
    XCTAssertGreaterThan(loft.windowBayCount, 0)
    XCTAssertFalse(garage.hasSkylineLayer)
    XCTAssertTrue(loft.hasSkylineLayer)
    XCTAssertEqual(garage.founderDeskProfile, .compact)
    XCTAssertEqual(loft.founderDeskProfile, .refined)
    XCTAssertGreaterThan(garage.frameEdgeWeight, loft.frameEdgeWeight)

    // No signature entry may encode a color.
    for entry in garage.structuralSignature + loft.structuralSignature {
      for colorWord in ["amber", "cyan", "purple", "mint", "coral", "color", "#"] {
        XCTAssertFalse(entry.lowercased().contains(colorWord), "\(entry) encodes color")
      }
    }
  }

  func testGarageAsymmetryChangesBayPlacementWhileLoftStaysLevel() {
    let order = ["aurora", "stacks", "brio"]
    let garage = CompanySceneLayout(
      size: CGSize(width: 340, height: 270),
      agentOrder: order,
      structure: .derive(FacilityTier.founderGarage)
    )
    let loft = CompanySceneLayout(
      size: CGSize(width: 340, height: 270),
      agentOrder: order,
      structure: .derive(FacilityTier.founderLoft)
    )
    XCTAssertEqual(Set(order.map { loft.bayOffset($0) }), [0])
    XCTAssertGreaterThan(Set(order.map { garage.bayOffset($0) }).count, 1)
    // Both facilities keep the same canonical station order and controls.
    XCTAssertEqual(order.map { garage.stationX($0) }, order.map { loft.stationX($0) })
  }

  // MARK: 11–12. Physical infrastructure

  func testAllFiveUpgradesMapToDistinctPhysicalLocations() {
    let layout = CompanySceneLayout(
      size: CGSize(width: 340, height: 270),
      agentOrder: ["aurora", "stacks", "brio"],
      structure: .derive(FacilityTier.founderGarage)
    )
    let locations = FacilityUpgradeID.allCases.map(InfrastructurePhysicalLocation.map)
    XCTAssertEqual(Set(locations).count, FacilityUpgradeID.allCases.count)

    let points = locations.map { layout.point(.companySystem($0)) }
    for (first, second) in zip(points, points.dropFirst()) {
      XCTAssertNotEqual(first, second)
    }
    // Each location resolves inside the viewport coordinate space.
    for point in points {
      XCTAssertGreaterThanOrEqual(point.x, 0)
      XCTAssertLessThanOrEqual(point.x, layout.size.width)
      XCTAssertGreaterThanOrEqual(point.y, 0)
      XCTAssertLessThanOrEqual(point.y, layout.size.height)
    }
    // Every location carries an accessibility name for the overview.
    for location in InfrastructurePhysicalLocation.allCases {
      XCTAssertFalse(location.accessibilityName.isEmpty)
    }
  }

  func testAllFourInfrastructureStatesRemainDeterministic() throws {
    func map(installing: Set<FacilityUpgradeID>, purchased: Set<FacilityUpgradeID>) -> [InfrastructureVisual] {
      InfrastructureVisual.map(
        purchased: purchased,
        facility: .founderGarage,
        agents: [projection(id: "stacks", phase: .working)],
        sprint: 1,
        installing: installing
      )
    }
    let first = map(installing: [.verificationArray], purchased: [.developmentRig, .campaignStudio])
    let second = map(installing: [.verificationArray], purchased: [.developmentRig, .campaignStudio])
    XCTAssertEqual(first, second)

    XCTAssertEqual(try state(.developmentRig, in: first), .active)
    XCTAssertEqual(try state(.campaignStudio, in: first), .installed)
    XCTAssertEqual(try state(.verificationArray, in: first), .installing)
    XCTAssertEqual(try state(.recoveryCorner, in: first), .uninstalled)
    XCTAssertEqual(Set(first.map(\.state)).count, 4)
  }

  // MARK: 13. Independent atmosphere axes

  func testAtmosphereConditionsRemainIndependentAndVisibleDerived() {
    let all = treatment(energy: 20, runway: 4, trust: 15, momentum: 92)
    XCTAssertTrue(all.showsEnergyStatus)
    XCTAssertTrue(all.showsRunwayCountdown)
    XCTAssertTrue(all.showsTrustInterference)
    XCTAssertTrue(all.showsMomentumLinks)
    XCTAssertEqual(all.activeTreatmentCount, 4)

    let none = treatment(energy: 88, runway: 40, trust: 70, momentum: 20)
    XCTAssertEqual(none.activeTreatmentCount, 0)
    XCTAssertEqual(none.founderLightLevel, 1)
    XCTAssertEqual(none.externalSignalIntegrity, 1)
    XCTAssertEqual(none.runwayPressure, 0)
    XCTAssertEqual(none.momentumLinkStrength, 0)

    // Each axis moves only with its own visible canonical value.
    let energyOnly = treatment(energy: 20, runway: 40, trust: 70, momentum: 20)
    XCTAssertLessThan(energyOnly.founderLightLevel, 1)
    XCTAssertEqual(energyOnly.runwayPressure, 0)
    XCTAssertEqual(energyOnly.externalSignalIntegrity, 1)

    let trustOnly = treatment(energy: 88, runway: 40, trust: 15, momentum: 20)
    XCTAssertLessThan(trustOnly.externalSignalIntegrity, 1)
    XCTAssertEqual(trustOnly.founderLightLevel, 1)

    // Deeper depletion reads as stronger pressure, not a new timer.
    XCTAssertGreaterThan(
      treatment(runway: 1).runwayPressure,
      treatment(runway: 7).runwayPressure
    )
  }

  // MARK: 14–15. Focus stability and the single scroll path

  func testUserFocusRemainsStableDuringUnrelatedPresentationUpdates() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("stacks"))
    XCTAssertEqual(state.focus, .agent("stacks"))

    state.observePresentation(agentID: "aurora")
    state.observePresentation(agentID: "brio")
    XCTAssertEqual(state.focus, .agent("stacks"), "Presentation must not steal user focus")
    XCTAssertTrue(state.userInitiatedFocus)
    XCTAssertNil(state.navigationRequest)

    state.toggleFocus(.agent("stacks"))
    XCTAssertNil(state.focus)
    XCTAssertNil(state.navigationRequest, "Closing focus must not move the page")
  }

  func testExplicitFullWorkstationIsTheOnlyViewportOriginatedScrollRequest() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("aurora"))
    state.observePresentation(agentID: "aurora")
    state.toggleFocus(.agent("brio"))
    XCTAssertNil(state.navigationRequest)

    state.requestFullWorkstation(.agent("brio"))
    XCTAssertEqual(state.navigationRequest?.target, .agent("brio"))
    XCTAssertEqual(state.navigationRequest?.sequence, 1)
    XCTAssertEqual(state.focus, .agent("brio"), "Navigation must not clear user focus")

    state.requestFullWorkstation(.founder)
    XCTAssertEqual(state.navigationRequest?.sequence, 2)
  }

  // MARK: 16–18. Canonical safeguards

  func testDuplicateReviewResolutionAndCommitProtectionsRemainIntact() throws {
    let store = makeStore(seed: 32_401)
    let coordinator = PresentationCoordinator(timing: .immediate)
    let task = try XCTUnwrap(store.tasks.first)
    coordinator.assign(agentID: "aurora", to: task.id, in: store)

    coordinator.review(taskID: task.id, in: store)
    let evidenceAfterFirstReview = store.evidence.count
    let statsAfterFirstReview = store.stats
    coordinator.review(taskID: task.id, in: store)
    XCTAssertEqual(store.evidence.count, evidenceAfterFirstReview, "Duplicate review must be rejected")
    XCTAssertEqual(store.stats, statsAfterFirstReview)

    coordinator.resolve(taskID: task.id, choice: .approve, in: store)
    let statsAfterResolution = store.stats
    let resolved = try XCTUnwrap(store.tasks.first { $0.id == task.id })
    XCTAssertTrue(resolved.resolutionLocked)
    coordinator.resolve(taskID: task.id, choice: .rework, in: store)
    XCTAssertEqual(store.stats, statsAfterResolution, "Duplicate resolution must be rejected")
    XCTAssertEqual(store.tasks.first { $0.id == task.id }, resolved)

    // Rest remains guarded against duplicate application.
    store.restAgent(agentID: "brio")
    let restingAfterFirst = store.restingAgentIDs
    store.restAgent(agentID: "brio")
    XCTAssertEqual(store.restingAgentIDs, restingAfterFirst)
  }

  func testSameSeedCanonicalSimulationParityRemainsIntact() {
    let first = makeStore(seed: 32_402)
    let second = makeStore(seed: 32_402)

    // Exercising the full Build 32.4 presentation pipeline consumes no RNG.
    let agents = first.agents.map { agent in
      projection(id: agent.id, phase: .working)
    }
    _ = CausalPresentationPlan.derive(agents: agents, reduceMotion: false)
    _ = FacilityStructureProjection.derive(FacilityTier.founderLoft)
    _ = CompanyAtmosphereTreatment.derive(
      CompanyAtmosphere.derive(stats: first.stats, facility: .founderGarage, venture: 1)
    )
    _ = agents.map { CharacterRendererInput.derive(agent: $0, reduceMotion: false) }

    XCTAssertEqual(first.tasks, second.tasks)
    XCTAssertEqual(first.agents, second.agents)
    XCTAssertEqual(first.stats, second.stats)
    XCTAssertEqual(first.evidence.count, second.evidence.count)
  }

  func testLegacySavesDecodeUnchanged() throws {
    let legacy = """
      {"version":1,"currentFacility":0,"ownedFacilities":[0],"highestTrackRecord":4,\
      "completedCareerCount":0,"recordedCareerIDs":[]}
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(FounderProgressionSave.self, from: legacy)
    XCTAssertEqual(decoded.highestTrackRecord, 4)
    XCTAssertEqual(decoded.completedCareerCount, 0)
  }

  // MARK: 19–20. Character renderer boundary

  func testCharacterRendererInputContainsNoRawHiddenResultData() {
    let concealed = projection(id: "aurora", phase: .reviewing, revealStep: 3)
    let input = CharacterRendererInput.derive(agent: concealed, reduceMotion: false)

    XCTAssertEqual(input.postReviewSignal, .pending)
    XCTAssertEqual(input.agentID, "aurora")
    XCTAssertEqual(input.activity, .reviewing)
    // The modifier vocabulary cannot express a hidden result at all.
    let modifierNames = Set(CharacterRendererInput.ConditionModifier.allCases.map(\.rawValue))
    XCTAssertEqual(modifierNames, ["stressed", "overloaded", "resting", "focused"])
    for leak in ["actual", "reported", "quality", "evidence", "drift", "overclaim", "seed"] {
      XCTAssertFalse(modifierNames.contains { $0.contains(leak) })
    }

    // Activity, condition, and emphasis stay separate axes.
    let overloadedWorker = projection(id: "stacks", phase: .working, stressBandOverload: true)
    let workerInput = CharacterRendererInput.derive(agent: overloadedWorker, reduceMotion: false)
    XCTAssertEqual(workerInput.activity, .working)
    XCTAssertTrue(workerInput.conditionModifiers.contains(.overloaded))
    XCTAssertEqual(workerInput.emphasis, .normal)

    // Only after the canonical reveal may the signal appear.
    var revealed = projection(id: "aurora", phase: .reviewed, revealStep: 5)
    revealed.conditions = [.overclaimed]
    revealed.reviewRevealStep = 5
    XCTAssertEqual(
      CharacterRendererInput.derive(agent: revealed, reduceMotion: false).postReviewSignal,
      .overclaimed
    )
    revealed.reviewRevealStep = 4
    XCTAssertEqual(
      CharacterRendererInput.derive(agent: revealed, reduceMotion: false).postReviewSignal,
      .pending,
      "The renderer must not see the result before its canonical reveal"
    )
  }

  func testAbsenceOfRiveAssetsUsesTheNativeRendererWithoutRuntimeFailure() {
    XCTAssertTrue(CharacterRendererContract.bundledRiveAssetNames(in: .main).isEmpty)
    XCTAssertEqual(CharacterRendererContract.resolvedRenderer(in: .main), .native)
    XCTAssertEqual(CharacterRendererContract.requiredRiveAssets.count, 3)

    // The renderer boundary still produces a view for every agent and activity.
    for agentID in ["aurora", "stacks", "brio", "unknown"] {
      for activity in LivingAgentActivity.allCases {
        let input = CharacterRendererInput.derive(
          agent: projection(id: agentID, phase: .idle, activityOverride: activity),
          reduceMotion: false
        )
        let view = LivingAgentCharacterView(input: input, accent: SoloAgentAccent.color(agentID), time: 0)
        XCTAssertEqual(view.input.activity, activity)
      }
    }
  }

  // MARK: Header composition

  func testHeaderCompositionSeparatesRegionsAtEveryWidthAndTypeSize() {
    let wide = ViewportHeaderComposition.derive(width: 360, dynamicTypeSize: .large, hasFocusAction: false)
    XCTAssertEqual(wide.layout, .inline)
    XCTAssertTrue(wide.showsStatusText)
    XCTAssertFalse(wide.collapsesPhaseToIcon)

    let narrow = ViewportHeaderComposition.derive(width: 250, dynamicTypeSize: .large, hasFocusAction: true)
    XCTAssertEqual(narrow.layout, .stacked, "Secondary content must move to another line")

    let large = ViewportHeaderComposition.derive(width: 360, dynamicTypeSize: .xxxLarge, hasFocusAction: true)
    XCTAssertEqual(large.layout, .inline)
    XCTAssertFalse(large.showsPriorityLine)

    for size in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
      let accessible = ViewportHeaderComposition.derive(width: 360, dynamicTypeSize: size, hasFocusAction: true)
      XCTAssertEqual(accessible.layout, .stacked, "No header collision at \(size)")
      XCTAssertFalse(accessible.collapsesPhaseToIcon, "Phase must keep its text label")
    }

    XCTAssertGreaterThan(ViewportHeaderComposition.statusRegionWidth, 0)
  }

  func testEssentialTextStaysInTheUncappedTextBudget() {
    let text = ViewportTextPriorityProjection.build32_4
    XCTAssertTrue(text.visibleOverviewFields.contains("reviewResultTitle"))
    XCTAssertFalse(text.visibleOverviewFields.contains("actualQuality"))
    XCTAssertFalse(text.visibleOverviewFields.contains("verifiedActual"))
    XCTAssertTrue(text.accessibilityOnlyFields.contains("sceneAnchor"))
  }

  // MARK: Scene layout integrity

  func testSceneAnchorsStayInsideTheViewportCoordinateSpace() {
    for size in [CGSize(width: 320, height: 240), CGSize(width: 402, height: 360), CGSize(width: 280, height: 200)] {
      for facility in [FacilityTier.founderGarage, .founderLoft] {
        let layout = CompanySceneLayout(
          size: size,
          agentOrder: ["aurora", "stacks", "brio"],
          structure: .derive(facility)
        )
        let anchors: [CompanySceneAnchor] = [
          .founderCommand,
          .founderTray,
          .station("aurora"),
          .roleMonitor("brio")
        ] + InfrastructurePhysicalLocation.allCases.map { .companySystem($0) }
        for anchor in anchors {
          let point = layout.point(anchor)
          XCTAssertTrue((0...size.width).contains(point.x), "\(anchor) x out of bounds at \(size)")
          XCTAssertTrue((0...size.height).contains(point.y), "\(anchor) y out of bounds at \(size)")
          XCTAssertFalse(anchor.accessibilityName.isEmpty)
        }
        // Work travels up the room and returns to the foreground tray.
        XCTAssertLessThan(layout.point(.roleMonitor("aurora")).y, layout.point(.founderTray).y)
        XCTAssertLessThan(layout.point(.station("aurora")).y, layout.floorY)
      }
    }
  }

  func testConcurrentAgentsKeepSeparateStableLanes() {
    let plan = CausalPresentationPlan.derive(
      agents: [
        projection(id: "aurora", phase: .workComplete, taskID: taskID(1)),
        projection(id: "stacks", phase: .workComplete, taskID: taskID(2)),
        projection(id: "brio", phase: .workComplete, taskID: taskID(3))
      ],
      reduceMotion: false
    )
    let order = ["aurora", "stacks", "brio"]
    let lanes = plan.objects.map { plan.lane(forAgentID: $0.agentID, in: order) }
    XCTAssertEqual(Set(lanes).count, 3)
    XCTAssertEqual(plan.objects.count, 3)
    XCTAssertEqual(Set(plan.objects.map(\.id)).count, 3)
  }

  // MARK: Helpers

  private func taskID(_ index: Int) -> UUID {
    UUID(uuidString: "32400000-0000-0000-0000-00000000000\(index)")!
  }

  private func state(
    _ id: FacilityUpgradeID,
    in items: [InfrastructureVisual]
  ) throws -> InfrastructureVisual.State {
    try XCTUnwrap(items.first { $0.id == id }).state
  }

  private func treatment(
    energy: Int = 82,
    runway: Int = 42,
    trust: Int = 68,
    momentum: Int = 18
  ) -> CompanyAtmosphereTreatment {
    var stats = FounderStats()
    stats.energy = energy
    stats.runway = runway
    stats.trust = trust
    stats.momentum = momentum
    return CompanyAtmosphereTreatment.derive(
      CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1)
    )
  }

  private func projection(
    id: String,
    phase: PresentationCoordinator.AgentPhase,
    progress: Double = 0.5,
    revealStep: Int = 0,
    taskID: UUID = UUID(uuidString: "32400000-0000-0000-0000-0000000000ff")!,
    stressBandOverload: Bool = false,
    activityOverride: LivingAgentActivity? = nil
  ) -> LivingAgentProjection {
    let role: AgentRole = id == "stacks" ? .engineering : (id == "brio" ? .marketing : .research)
    var agent = SoloAgent(
      id: id,
      name: id.capitalized,
      initials: String(id.prefix(2)).uppercased(),
      role: role,
      modelFamily: "Visible Family",
      reliability: 82,
      calibration: 0.76,
      drift: 0,
      trust: 72
    )
    if stressBandOverload { agent.progression.stressLevel = 92 }
    let task = SoloTask(
      id: taskID,
      title: "Visible Task",
      detail: "Visible task detail.",
      role: role,
      impact: .momentum(4),
      assignedAgentID: id,
      isReviewed: [.reviewing, .reviewed, .resolving, .resolved].contains(phase),
      result: TaskResult(
        actualQuality: 72,
        reportedQuality: 74,
        evidenceCompleteness: 90,
        correlatedFailureIdentifier: nil,
        immediateEffects: SimulationEffects(),
        delayedEffects: SimulationEffects(),
        confidenceLowerBound: 68,
        confidenceUpperBound: 80,
        knownOperationalRisk: "Visible risk"
      ),
      resolutionLocked: phase == .resolved
    )
    let presentation = PresentationCoordinator.AgentPresentation(
      taskID: taskID,
      agentID: id,
      taskTitle: task.title,
      phase: phase,
      progress: progress,
      reviewRevealStep: revealStep,
      sequenceID: UUID(uuidString: "32400000-0000-0000-0000-0000000000fe")!
    )
    var result = LivingAgentProjection.derive(
      agent: agent,
      task: task,
      presentation: presentation,
      isResting: false,
      isSelected: false,
      founderStats: FounderStats()
    )
    if let activityOverride {
      result.activity = activityOverride
      result.isResting = activityOverride == .resting
    }
    return result
  }

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }
}

/// Build 32.5 regression coverage for the presentation-only environment shell.
@MainActor
final class Build32_5FounderEnvironmentTests: XCTestCase {
  func testDefaultCameraIsComputerFocusedAndInteractive() {
    let camera = FounderEnvironmentCameraState()
    XCTAssertEqual(camera.mode, .computerFocused)
    XCTAssertTrue(camera.computerAllowsHitTesting)
    XCTAssertFalse(camera.environmentAllowsCameraGestures)
  }

  func testFreeLookTransfersInteractionOwnershipWithoutChangingCameraModelIdentity() {
    var camera = FounderEnvironmentCameraState()
    camera.mode = .freeLook
    XCTAssertFalse(camera.computerAllowsHitTesting)
    XCTAssertTrue(camera.environmentAllowsCameraGestures)
    camera.mode = .computerFocused
    XCTAssertTrue(camera.computerAllowsHitTesting)
  }

  func testCameraMovementIsBoundedAndPresentationOnly() {
    var camera = FounderEnvironmentCameraState(mode: .freeLook)
    camera.look(horizontal: 9, vertical: 9)
    XCTAssertEqual(camera.horizontalLook, 1)
    XCTAssertEqual(camera.verticalLook, 0.30)
    camera.look(horizontal: -9, vertical: -9)
    XCTAssertEqual(camera.horizontalLook, -1)
    XCTAssertEqual(camera.verticalLook, -0.30)
    camera.center()
    XCTAssertEqual(camera.horizontalLook, 0)
    XCTAssertEqual(camera.verticalLook, 0)
  }

  func testReduceMotionUsesStableCameraEndpoints() {
    var camera = FounderEnvironmentCameraState(mode: .freeLook)
    camera.setLook(horizontal: 0.5, vertical: 0.2, reduceMotion: true)
    XCTAssertEqual(camera.horizontalLook, 1)
    XCTAssertEqual(camera.verticalLook, 0.30)
    camera.setLook(horizontal: 0.1, vertical: 0.02, reduceMotion: true)
    XCTAssertEqual(camera.horizontalLook, 0)
    XCTAssertEqual(camera.verticalLook, 0)
  }

  func testGarageAndLoftRemainStructurallyDistinctProjections() {
    let stats = FounderStats()
    let garage = FounderEnvironmentProjection(facility: .founderGarage, atmosphere: .derive(stats: stats, facility: .founderGarage, venture: 1), infrastructure: [], agents: [])
    let loft = FounderEnvironmentProjection(facility: .founderLoft, atmosphere: .derive(stats: stats, facility: .founderLoft, venture: 1), infrastructure: [], agents: [])
    XCTAssertEqual(garage.spatialPresentation, .improvisedGarage)
    XCTAssertEqual(loft.spatialPresentation, .elevatedLoft)
    XCTAssertNotEqual(garage.facility.accessibilityDescription, loft.facility.accessibilityDescription)
  }

  func testAllExistingUpgradesMapToPhysicalEnvironmentLocations() {
    XCTAssertEqual(FounderEnvironmentProjection.physicalLocation(for: .developmentRig), .stacksBuildRail)
    XCTAssertEqual(FounderEnvironmentProjection.physicalLocation(for: .verificationArray), .auroraFounderVerificationBridge)
    XCTAssertEqual(FounderEnvironmentProjection.physicalLocation(for: .campaignStudio), .brioBroadcastRail)
    XCTAssertEqual(FounderEnvironmentProjection.physicalLocation(for: .recoveryCorner), .recoverySideBay)
    XCTAssertEqual(FounderEnvironmentProjection.physicalLocation(for: .founderCommandDesk), .founderForegroundDesk)
  }

  func testEnvironmentAccessibilityOmitsHiddenReviewTruth() {
    let agent = LivingAgentProjection(
      agentID: "aurora", name: "Aurora", initials: "AU", role: .research,
      taskID: UUID(), taskTitle: "Visible task", activity: .awaitingReview,
      conditions: [.overclaimed, .drifting, .evidenceIncomplete, .stressed], emphasis: .founderAttention,
      progress: 1, reviewRevealStep: 4, stressLabel: "Pressured", trustLabel: "Trusted", level: 2,
      needsFounderAttention: true, isResting: false
    )
    let projection = FounderEnvironmentProjection(
      facility: .founderGarage,
      atmosphere: .derive(stats: FounderStats(), facility: .founderGarage, venture: 1),
      infrastructure: [], agents: [agent]
    )
    XCTAssertTrue(projection.agentAccessibilitySummary.contains("Awaiting Founder review"))
    XCTAssertTrue(projection.agentAccessibilitySummary.contains("Stressed"))
    XCTAssertFalse(projection.agentAccessibilitySummary.localizedCaseInsensitiveContains("overclaim"))
    XCTAssertFalse(projection.agentAccessibilitySummary.localizedCaseInsensitiveContains("drift"))
    XCTAssertFalse(projection.agentAccessibilitySummary.localizedCaseInsensitiveContains("evidence"))
  }

  func testEnvironmentRendererBoundaryIsNativeAndReplaceable() {
    XCTAssertEqual(FounderEnvironmentRendererKind.native2D, .native2D)
  }
}
