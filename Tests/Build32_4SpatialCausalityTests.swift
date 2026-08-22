import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build32_4SpatialCausalityTests: XCTestCase {
  func testAutomaticPresentationNeverCreatesViewportFocus() {
    var state = CompanyCommandInteractionState()
    state.receiveAutomaticPresentationUpdate()
    XCTAssertNil(state.focus)
  }

  func testAutomaticPresentationNeverCreatesNavigationRequest() {
    var state = CompanyCommandInteractionState()
    state.receiveAutomaticPresentationUpdate()
    XCTAssertNil(state.navigationRequest)
  }

  func testCausalObjectsRetainStableTaskAndAgentIdentity() throws {
    let taskID = fixedTaskID
    for phase in [PresentationCoordinator.AgentPhase.assignmentReceived, .workComplete, .resolving] {
      let object = try XCTUnwrap(CompanyCausalObject.project(agent: projection(phase: phase, taskID: taskID), reduceMotion: false))
      XCTAssertEqual(object.taskID, taskID)
      XCTAssertEqual(object.agentID, "aurora")
      XCTAssertTrue(object.id.contains(taskID.uuidString))
    }
  }

  func testCausalFamiliesHaveDistinctTypesAndEndpoints() throws {
    let objects = try [
      object(.assignmentReceived),
      object(.workComplete),
      object(.resolving)
    ]
    XCTAssertEqual(Set(objects.map(\.kind)), Set(CompanyCausalObjectKind.allCases))
    XCTAssertEqual(Set(objects.map(\.endpoint)), Set(CompanyCausalEndpoint.allCases))
  }

  func testReduceMotionUsesSameStableEndpoints() throws {
    for phase in [PresentationCoordinator.AgentPhase.assignmentReceived, .workComplete, .resolving] {
      let standard = try object(phase, reduceMotion: false)
      let reduced = try object(phase, reduceMotion: true)
      XCTAssertEqual(standard.id, reduced.id)
      XCTAssertEqual(standard.endpoint, reduced.endpoint)
      XCTAssertFalse(standard.atEndpoint)
      XCTAssertTrue(reduced.atEndpoint)
    }
  }

  func testSkipPresentationReachesEndpointWithoutChangingGameStore() throws {
    let store = makeStore(seed: 32_406)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let coordinator = PresentationCoordinator(timing: .immediate)
    coordinator.assign(agentID: agent.id, to: task.id, in: store)
    let canonicalTasks = store.tasks
    let canonicalStats = store.stats
    coordinator.skipPresentation(for: agent.id)
    XCTAssertEqual(store.tasks, canonicalTasks)
    XCTAssertEqual(store.stats, canonicalStats)
    XCTAssertEqual(coordinator.presentation(for: agent.id)?.phase, .awaitingReview)
  }

  func testReviewStepsOneThroughFourExposeNoHiddenTruthVisually() {
    for step in 1...4 {
      let value = projection(phase: .reviewing, conditions: [.overclaimed], revealStep: step)
      XCTAssertEqual(ReviewResultVisual.map(conditions: value.conditions, revealStep: step), .pending)
    }
  }

  func testReviewStepsOneThroughFourExposeNoHiddenTruthAccessibly() {
    for step in 1...4 {
      let value = derivedProjection(revealStep: step)
      XCTAssertFalse(value.accessibilityValue.localizedCaseInsensitiveContains("actual"))
      XCTAssertFalse(value.accessibilityValue.localizedCaseInsensitiveContains("overclaim"))
      XCTAssertTrue(value.conditions.intersection(revealedConditions).isEmpty)
    }
  }

  func testStepFiveAdmitsOnlyCanonicalRevealedCondition() {
    let mappings: [(LivingAgentCondition, ReviewResultVisual)] = [
      (.verified, .verified), (.overclaimed, .overclaimed),
      (.drifting, .driftDetected), (.evidenceIncomplete, .evidenceIncomplete)
    ]
    for (condition, result) in mappings {
      XCTAssertEqual(ReviewResultVisual.map(conditions: [condition], revealStep: 5), result)
    }
  }

  func testGarageAndLoftAreStructurallyDifferentIndependentOfPalette() {
    XCTAssertEqual(CompanySpatialPresentation.map(.founderGarage), .improvisedGarage)
    XCTAssertEqual(CompanySpatialPresentation.map(.founderLoft), .elevatedLoft)
    XCTAssertNotEqual(CompanySpatialPresentation.map(.founderGarage), CompanySpatialPresentation.map(.founderLoft))
  }

  func testAllFiveUpgradesHaveDistinctPhysicalLocations() {
    let locations = FacilityUpgradeID.allCases.map(InfrastructurePhysicalLocation.map)
    XCTAssertEqual(locations.count, 5)
    XCTAssertEqual(Set(locations).count, 5)
  }

  func testAllFourInfrastructureStatesAreDeterministic() throws {
    let agents = [projection(phase: .working, agentID: "stacks", role: .engineering)]
    let first = InfrastructureVisual.map(purchased: [.developmentRig, .campaignStudio], facility: .founderGarage, agents: agents, sprint: 2, installing: [.verificationArray])
    let second = InfrastructureVisual.map(purchased: [.developmentRig, .campaignStudio], facility: .founderGarage, agents: agents, sprint: 2, installing: [.verificationArray])
    XCTAssertEqual(first, second)
    XCTAssertEqual(Set(first.map(\.state)), Set([.active, .installed, .installing, .uninstalled]))
  }

  func testAtmosphereConditionsRemainIndependentAndVisibleDerived() {
    var stats = FounderStats()
    stats.energy = 38
    stats.runway = 8
    stats.trust = 24
    stats.momentum = 70
    let value = CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1)
    XCTAssertTrue(value.isLowEnergy)
    XCTAssertTrue(value.isLowRunway)
    XCTAssertTrue(value.isLowTrust)
    XCTAssertTrue(value.isHighMomentum)
  }

  func testUserFocusRemainsStableDuringUnrelatedPresentationUpdates() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("brio"))
    state.receiveAutomaticPresentationUpdate()
    XCTAssertEqual(state.focus, .agent("brio"))
    XCTAssertTrue(state.userInitiatedFocus)
  }

  func testFullWorkstationIsOnlyViewportNavigationAuthority() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("stacks"))
    state.ambientFocus(.agent("aurora"))
    state.receiveAutomaticPresentationUpdate()
    XCTAssertNil(state.navigationRequest)
    state.requestFullWorkstation(.agent("stacks"))
    XCTAssertEqual(state.navigationRequest?.target, .agent("stacks"))
  }

  func testDuplicateReviewIsIgnored() throws {
    let store = makeStore(seed: 32_416)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let coordinator = PresentationCoordinator(timing: .immediate)
    coordinator.assign(agentID: agent.id, to: task.id, in: store)
    coordinator.skipPresentation(for: agent.id)
    coordinator.review(taskID: task.id, in: store)
    let tasksAfterFirst = store.tasks
    let evidenceCountAfterFirst = store.evidence.count
    coordinator.review(taskID: task.id, in: store)
    XCTAssertEqual(store.tasks, tasksAfterFirst)
    XCTAssertEqual(store.evidence.count, evidenceCountAfterFirst)
  }

  func testSameSeedCanonicalSimulationParityRemainsIntact() {
    let first = makeStore(seed: 32_417)
    let second = makeStore(seed: 32_417)
    _ = CompanyCausalObject.project(agent: projection(phase: .assignmentReceived), reduceMotion: false)
    XCTAssertEqual(first.tasks, second.tasks)
    XCTAssertEqual(first.agents, second.agents)
    XCTAssertEqual(first.stats, second.stats)
  }

  func testLegacySaveDecodesUnchanged() {
    let data = """
      {"version":1,"currentFacility":0,"ownedFacilities":[0],"highestTrackRecord":4,"completedCareerCount":0,"recordedCareerIDs":[]}
      """.data(using: .utf8)!
    XCTAssertNoThrow(try JSONDecoder().decode(FounderProgressionSave.self, from: data))
  }

  func testCharacterRendererInputContainsNoHiddenResultData() {
    let input = LivingAgentCharacterInput.project(agent: projection(phase: .working), reduceMotion: false)
    let fields = Set(Mirror(reflecting: input).children.compactMap(\.label))
    XCTAssertEqual(fields, ["role", "activity", "conditions", "emphasis", "reduceMotion", "levelUpTrigger"])
    XCTAssertFalse(fields.contains("actualQuality"))
    XCTAssertFalse(fields.contains("taskResult"))
  }

  func testMissingRiveAssetsShipNativeRendererWithPortraitFallback() {
    XCTAssertEqual(LivingAgentRendererKind.shipped, .nativePortrait)
    XCTAssertNil(AgentPortraitAsset.name(for: "future-agent-without-asset"))
  }

  private var fixedTaskID: UUID { UUID(uuidString: "32400000-0000-0000-0000-000000000001")! }
  private var revealedConditions: Set<LivingAgentCondition> { [.verified, .overclaimed, .drifting, .evidenceIncomplete] }

  private func object(_ phase: PresentationCoordinator.AgentPhase, reduceMotion: Bool = false) throws -> CompanyCausalObject {
    try XCTUnwrap(CompanyCausalObject.project(agent: projection(phase: phase), reduceMotion: reduceMotion))
  }

  private func projection(
    phase: PresentationCoordinator.AgentPhase,
    taskID: UUID? = nil,
    agentID: String = "aurora",
    role: AgentRole = .research,
    conditions: Set<LivingAgentCondition> = [],
    revealStep: Int = 0
  ) -> LivingAgentProjection {
    LivingAgentProjection(
      agentID: agentID,
      name: agentID.capitalized,
      initials: String(agentID.prefix(2)).uppercased(),
      role: role,
      taskID: taskID ?? fixedTaskID,
      taskTitle: "Visible task",
      activity: LivingAgentActivity(rawValue: phase.rawValue) ?? .idle,
      conditions: conditions,
      emphasis: .normal,
      progress: phase == .assignmentReceived ? 0 : 1,
      reviewRevealStep: revealStep,
      stressLabel: "Stable",
      trustLabel: "Trusted",
      level: 2,
      needsFounderAttention: false,
      isResting: false
    )
  }

  private func derivedProjection(revealStep: Int) -> LivingAgentProjection {
    let agent = SoloAgent(id: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Visible", reliability: 80, calibration: 0.8, drift: 0, trust: 70)
    let result = TaskResult(actualQuality: 30, reportedQuality: 90, evidenceCompleteness: 80, correlatedFailureIdentifier: nil, immediateEffects: .init(), delayedEffects: .init(), confidenceLowerBound: 82, confidenceUpperBound: 96, knownOperationalRisk: "Visible risk")
    let task = SoloTask(id: fixedTaskID, title: "Visible task", detail: "Visible", role: .research, impact: .momentum(1), assignedAgentID: "aurora", isReviewed: true, result: result)
    let presentation = PresentationCoordinator.AgentPresentation(taskID: fixedTaskID, agentID: "aurora", taskTitle: task.title, phase: .reviewing, progress: 1, reviewRevealStep: revealStep)
    return LivingAgentProjection.derive(agent: agent, task: task, presentation: presentation, isResting: false, isSelected: false, founderStats: .init())
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
