import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build32LivingCompanyTests: XCTestCase {
  func testActivityDerivationMapsEveryPresentationPhase() {
    let agent = makeAgent()
    let task = makeTask(agent: agent)
    let expected: [PresentationCoordinator.AgentPhase: LivingAgentActivity] = [
      .idle: .idle,
      .assignmentReceived: .assignmentReceived,
      .working: .working,
      .workComplete: .workComplete,
      .awaitingReview: .awaitingReview,
      .reviewing: .reviewing,
      .reviewed: .reviewed,
      .resolving: .resolving,
      .resolved: .resolved
    ]

    for phase in PresentationCoordinator.AgentPhase.allCases {
      let projection = LivingAgentProjection.derive(
        agent: agent,
        task: task,
        presentation: presentation(phase: phase),
        isResting: false,
        isSelected: false,
        founderStats: FounderStats()
      )
      XCTAssertEqual(projection.activity, expected[phase], "Incorrect activity for \(phase)")
    }
  }

  func testRestingPrecedesAssignmentAndOverloadConditionRemainsVisible() {
    var agent = makeAgent()
    agent.progression.stressLevel = 92
    let projection = LivingAgentProjection.derive(
      agent: agent,
      task: makeTask(agent: agent),
      presentation: presentation(phase: .working),
      isResting: true,
      isSelected: false,
      founderStats: FounderStats()
    )

    XCTAssertEqual(projection.activity, .resting)
    XCTAssertTrue(projection.conditions.contains(.stressed))
    XCTAssertTrue(projection.conditions.contains(.overloaded))
    XCTAssertFalse(projection.conditions.contains(.focused))
  }

  func testStressConditionBandsAreIndependentFromActivity() {
    var agent = makeAgent()
    agent.progression.stressLevel = 60
    let stressed = LivingAgentProjection.derive(
      agent: agent,
      task: nil,
      presentation: nil,
      isResting: false,
      isSelected: false,
      founderStats: FounderStats()
    )
    XCTAssertEqual(stressed.activity, .idle)
    XCTAssertTrue(stressed.conditions.contains(.stressed))
    XCTAssertFalse(stressed.conditions.contains(.overloaded))
  }

  func testHiddenTruthIsSanitizedUntilFifthReviewReveal() {
    let agent = makeAgent()
    var result = makeResult(actual: 42, reported: 78)
    result.verify()
    let task = makeTask(agent: agent, reviewed: true, result: result)

    let concealed = LivingAgentProjection.derive(
      agent: agent,
      task: task,
      presentation: presentation(phase: .reviewing, revealStep: 4),
      isResting: false,
      isSelected: true,
      founderStats: FounderStats()
    )
    XCTAssertFalse(concealed.conditions.contains(.overclaimed))
    XCTAssertFalse(concealed.conditions.contains(.verified))
    XCTAssertFalse(concealed.conditions.contains(.drifting))
    XCTAssertFalse(concealed.accessibilityValue.localizedCaseInsensitiveContains("overclaim"))

    let revealed = LivingAgentProjection.derive(
      agent: agent,
      task: task,
      presentation: presentation(phase: .reviewing, revealStep: 5),
      isResting: false,
      isSelected: true,
      founderStats: FounderStats()
    )
    XCTAssertTrue(revealed.conditions.contains(.overclaimed))
  }

  func testUnreviewedResultNeverLeaksVerificationThroughVisualOrAccessibilityState() {
    let agent = makeAgent()
    let task = makeTask(agent: agent, result: makeResult(actual: 90, reported: 90))
    let projection = LivingAgentProjection.derive(
      agent: agent,
      task: task,
      presentation: presentation(phase: .awaitingReview),
      isResting: false,
      isSelected: false,
      founderStats: FounderStats()
    )

    XCTAssertEqual(projection.conditions.intersection([.verified, .overclaimed, .drifting, .evidenceIncomplete]), [])
    XCTAssertFalse(projection.accessibilityValue.localizedCaseInsensitiveContains("verified"))
  }

  func testViewportSelectionMapsOnlyCanonicalAgentIDs() {
    let ids = ["aurora", "stacks", "brio"]
    XCTAssertEqual(ViewportSelectionMap.workstationID(for: "aurora", canonicalAgentIDs: ids), "aurora")
    XCTAssertEqual(ViewportSelectionMap.workstationID(for: "stacks", canonicalAgentIDs: ids), "stacks")
    XCTAssertEqual(ViewportSelectionMap.workstationID(for: "brio", canonicalAgentIDs: ids), "brio")
    XCTAssertNil(ViewportSelectionMap.workstationID(for: "invented", canonicalAgentIDs: ids))
  }

  func testInfrastructureVisualMappingHasStableSlotsAndRelevantActiveState() {
    let agent = makeAgent(id: "stacks")
    let working = LivingAgentProjection.derive(
      agent: agent,
      task: makeTask(agent: agent),
      presentation: presentation(phase: .working),
      isResting: false,
      isSelected: false,
      founderStats: FounderStats()
    )
    let mapped = InfrastructureVisual.map(
      purchased: [.developmentRig, .campaignStudio],
      facility: .founderGarage,
      agents: [working],
      sprint: 1
    )

    XCTAssertEqual(mapped.map(\.id), FacilityUpgradeDefinition.all.map(\.id))
    XCTAssertEqual(mapped.first(where: { $0.id == .developmentRig })?.state, .active)
    XCTAssertEqual(mapped.first(where: { $0.id == .campaignStudio })?.state, .installed)
    XCTAssertEqual(mapped.first(where: { $0.id == .verificationArray })?.state, .uninstalled)
  }

  func testInstalledGarageUpgradeIsNotActiveInFounderLoft() {
    let agent = makeAgent(id: "stacks")
    let working = LivingAgentProjection.derive(
      agent: agent,
      task: makeTask(agent: agent),
      presentation: presentation(phase: .working),
      isResting: false,
      isSelected: false,
      founderStats: FounderStats()
    )
    let mapped = InfrastructureVisual.map(
      purchased: [.developmentRig],
      facility: .founderLoft,
      agents: [working],
      sprint: 3
    )
    XCTAssertEqual(mapped.first(where: { $0.id == .developmentRig })?.state, .installed)
  }

  func testFacilityAndOperationalAtmosphereMappingIsDeterministic() {
    var stats = FounderStats()
    stats.runway = 7
    let garage = CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1)
    let loft = CompanyAtmosphere.derive(stats: stats, facility: .founderLoft, venture: 1)

    XCTAssertEqual(garage.pressure, .lowRunway)
    XCTAssertEqual(loft.pressure, .lowRunway)
    XCTAssertEqual(garage.facility, .founderGarage)
    XCTAssertEqual(loft.facility, .founderLoft)
    XCTAssertEqual(garage, CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1))
    XCTAssertNotEqual(garage, loft)
  }

  func testSkipPresentationReachesSameCanonicalResultAsTimedPresentation() async throws {
    let timedStore = makeStore(seed: 32_001)
    let skippedStore = makeStore(seed: 32_001)
    let timedTask = try XCTUnwrap(timedStore.tasks.first)
    let skippedTask = try XCTUnwrap(skippedStore.tasks.first)
    let timedAgent = try XCTUnwrap(timedStore.agents.first)
    let skippedAgent = try XCTUnwrap(skippedStore.agents.first)
    let timing = PresentationCoordinator.Timing(
      assignmentAcknowledgement: .milliseconds(5),
      working: .milliseconds(10),
      progressTick: .milliseconds(5),
      workComplete: .milliseconds(5),
      reviewFocus: .milliseconds(5),
      reviewStagger: .milliseconds(5),
      resolution: .milliseconds(5)
    )
    let timed = PresentationCoordinator(timing: timing)
    let skipped = PresentationCoordinator(timing: timing)

    timed.assign(agentID: timedAgent.id, to: timedTask.id, in: timedStore)
    skipped.assign(agentID: skippedAgent.id, to: skippedTask.id, in: skippedStore)
    skipped.skipPresentation(for: skippedAgent.id)
    try await Task.sleep(for: .milliseconds(40))

    XCTAssertEqual(timedStore.tasks.first?.result, skippedStore.tasks.first?.result)
    XCTAssertEqual(timedStore.stats, skippedStore.stats)
    XCTAssertEqual(timed.presentation(for: timedAgent.id)?.phase, .awaitingReview)
    XCTAssertEqual(skipped.presentation(for: skippedAgent.id)?.phase, .awaitingReview)
  }

  func testReduceMotionImmediatePathHasSameFinalPresentationState() async throws {
    let store = makeStore(seed: 32_002)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let coordinator = PresentationCoordinator(timing: .immediate)
    coordinator.assign(agentID: agent.id, to: task.id, in: store)
    coordinator.skipPresentation(for: agent.id)
    XCTAssertEqual(coordinator.presentation(for: agent.id)?.progress, 1)
    XCTAssertEqual(coordinator.presentation(for: agent.id)?.phase, .awaitingReview)
    XCTAssertNotNil(store.tasks.first?.result)
  }

  func testDuplicateReviewDoesNotPublishAnotherEventOrSpendAttention() throws {
    let store = makeStore(seed: 32_003)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let coordinator = PresentationCoordinator(timing: .immediate)
    coordinator.assign(agentID: agent.id, to: task.id, in: store)
    for _ in 0..<8 { RunLoop.current.run(until: Date()) }
    coordinator.review(taskID: task.id, in: store)
    let eventID = coordinator.latestEvent?.id
    let attention = store.attentionRemaining
    let evidence = store.evidence.count

    coordinator.review(taskID: task.id, in: store)

    XCTAssertEqual(coordinator.latestEvent?.id, eventID)
    XCTAssertEqual(store.attentionRemaining, attention)
    XCTAssertEqual(store.evidence.count, evidence)
  }

  func testDuplicateResolutionDoesNotRestartPresentationOrMutateState() throws {
    let store = makeStore(seed: 32_004)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let coordinator = PresentationCoordinator(timing: .immediate)
    coordinator.assign(agentID: agent.id, to: task.id, in: store)
    coordinator.skipPresentation(for: agent.id)
    coordinator.review(taskID: task.id, in: store)
    coordinator.skipPresentation(for: agent.id)
    coordinator.resolve(taskID: task.id, choice: .approve, in: store)
    let sequence = coordinator.presentation(for: agent.id)?.sequenceID
    let stats = store.stats
    let evidence = store.evidence.count

    coordinator.resolve(taskID: task.id, choice: .shipAnyway, in: store)

    XCTAssertEqual(coordinator.presentation(for: agent.id)?.sequenceID, sequence)
    XCTAssertEqual(store.stats, stats)
    XCTAssertEqual(store.evidence.count, evidence)
    XCTAssertEqual(store.tasks.first?.resolution, .approve)
  }

  func testLegacyProgressionSaveWithoutBuild32FieldsStillDecodes() throws {
    let json = """
      {"version":1,"currentFacility":0,"ownedFacilities":[0],"highestTrackRecord":4,"completedCareerCount":0,"recordedCareerIDs":[]}
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(FounderProgressionSave.self, from: json)
    XCTAssertEqual(decoded.currentFacility, .founderGarage)
    XCTAssertEqual(decoded.purchasedUpgrades, [])
    XCTAssertEqual(decoded.highestTrackRecord, 4)
  }

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func makeAgent(id: String = "aurora") -> SoloAgent {
    SoloAgent(
      id: id,
      name: id.capitalized,
      initials: String(id.prefix(2)).uppercased(),
      role: id == "brio" ? .marketing : .engineering,
      modelFamily: "Visible Family",
      reliability: 82,
      calibration: 0.76,
      drift: 0,
      trust: 72
    )
  }

  private func makeTask(
    agent: SoloAgent,
    reviewed: Bool = false,
    result: TaskResult? = nil
  ) -> SoloTask {
    SoloTask(
      title: "Stable Task",
      detail: "Visible task detail.",
      role: agent.role,
      impact: .momentum(4),
      assignedAgentID: agent.id,
      isReviewed: reviewed,
      result: result ?? makeResult(actual: 70, reported: 74)
    )
  }

  private func makeResult(actual: Int, reported: Int) -> TaskResult {
    TaskResult(
      actualQuality: actual,
      reportedQuality: reported,
      evidenceCompleteness: 88,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: reported - 8,
      confidenceUpperBound: reported + 8,
      knownOperationalRisk: "Normal operational variance"
    )
  }

  private func presentation(
    phase: PresentationCoordinator.AgentPhase,
    revealStep: Int = 0
  ) -> PresentationCoordinator.AgentPresentation {
    PresentationCoordinator.AgentPresentation(
      taskID: UUID(),
      agentID: "aurora",
      taskTitle: "Stable Task",
      phase: phase,
      progress: phase == .idle ? 0 : 0.7,
      reviewRevealStep: revealStep
    )
  }
}
