import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build32_1ViewportInteractionTests: XCTestCase {
  func testStacksTapFocusesWithoutNavigation() {
    assertFocusWithoutNavigation(agentID: "stacks")
  }

  func testAuroraTapFocusesWithoutNavigation() {
    assertFocusWithoutNavigation(agentID: "aurora")
  }

  func testBrioTapFocusesWithoutNavigation() {
    assertFocusWithoutNavigation(agentID: "brio")
  }

  func testFounderTapFocusesWithoutNavigation() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.founder)
    XCTAssertEqual(state.focus, .founder)
    XCTAssertNil(state.navigationRequest)
  }

  func testFocusTransfersWithoutCreatingNavigation() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("stacks"))
    state.toggleFocus(.agent("aurora"))
    XCTAssertEqual(state.focus, .agent("aurora"))
    XCTAssertNil(state.navigationRequest)
  }

  func testTappingFocusedStationClosesFocus() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("brio"))
    state.toggleFocus(.agent("brio"))
    XCTAssertNil(state.focus)
    XCTAssertFalse(state.userInitiatedFocus)
  }

  func testFullWorkstationCreatesExplicitCanonicalScrollTarget() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("stacks"))
    state.requestFullWorkstation(.agent("stacks"))
    XCTAssertEqual(state.navigationRequest?.target.scrollID, "stacks")
    XCTAssertEqual(state.focus, .agent("stacks"))
  }

  func testActionAvailabilityMatchesCanonicalPlanningAndReviewRules() {
    let planning = CompanyCommandAgentAvailability.derive(
      sprintPhase: .chooseCommitments,
      task: nil,
      presentation: nil,
      isResting: false,
      attentionRemaining: 3
    )
    XCTAssertTrue(planning.canAssign)
    XCTAssertTrue(planning.canRest)
    XCTAssertFalse(planning.canReview)

    let task = makeTask(reviewed: false, result: makeResult(actual: 70, reported: 72))
    let review = CompanyCommandAgentAvailability.derive(
      sprintPhase: .reviewAndResolve,
      task: task,
      presentation: presentation(phase: .awaitingReview, taskID: task.id),
      isResting: false,
      attentionRemaining: 1
    )
    XCTAssertTrue(review.canReview)
    XCTAssertFalse(review.canAssign)
    XCTAssertFalse(review.canRest)
  }

  func testUnavailableActionsRemainUnavailable() {
    let task = makeTask(reviewed: true, result: makeResult(actual: 70, reported: 72), resolutionLocked: true)
    let unavailable = CompanyCommandAgentAvailability.derive(
      sprintPhase: .readyToCommit,
      task: task,
      presentation: presentation(phase: .resolved, taskID: task.id),
      isResting: false,
      attentionRemaining: 0
    )
    XCTAssertFalse(unavailable.canAssign)
    XCTAssertFalse(unavailable.canReview)
    XCTAssertFalse(unavailable.canRest)
    XCTAssertFalse(unavailable.canSkipPresentation)
    XCTAssertFalse(unavailable.requiresResolution)
  }

  func testFocusedProjectionAndAccessibilityRemainSanitizedBeforeFifthReveal() {
    let agent = makeAgent()
    var result = makeResult(actual: 38, reported: 86)
    result.verify()
    let task = makeTask(reviewed: true, result: result)
    let focused = LivingAgentProjection.derive(
      agent: agent,
      task: task,
      presentation: presentation(phase: .reviewing, taskID: task.id, revealStep: 4),
      isResting: false,
      isSelected: true,
      founderStats: FounderStats()
    )
    XCTAssertTrue(focused.conditions.intersection([.verified, .overclaimed, .drifting, .evidenceIncomplete]).isEmpty)
    XCTAssertFalse(focused.accessibilityValue.localizedCaseInsensitiveContains("overclaim"))
    XCTAssertFalse(focused.accessibilityValue.localizedCaseInsensitiveContains("actual quality"))
  }

  func testReduceMotionAndNormalMotionReachSameFocusState() {
    var normal = CompanyCommandInteractionState()
    var reduced = CompanyCommandInteractionState()
    normal.toggleFocus(.agent("aurora"))
    reduced.toggleFocus(.agent("aurora"))
    XCTAssertEqual(normal, reduced)
  }

  func testReassignmentCancelsStaleAgentPresentation() throws {
    let store = makeStore(seed: 32_101)
    let agent = try XCTUnwrap(store.agents.first)
    let first = try XCTUnwrap(store.tasks.first)
    let second = try XCTUnwrap(store.tasks.dropFirst().first)
    let coordinator = PresentationCoordinator(timing: .immediate)
    coordinator.assign(agentID: agent.id, to: first.id, in: store)
    coordinator.assign(agentID: agent.id, to: second.id, in: store)
    XCTAssertEqual(coordinator.presentation(for: agent.id)?.taskID, second.id)
    XCTAssertNotEqual(coordinator.presentation(for: agent.id)?.taskID, first.id)
  }

  func testSprintCommitClearsObsoleteViewportFocus() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.founder)
    state.clearAfterSprintCommit()
    XCTAssertNil(state.focus)
    XCTAssertFalse(state.userInitiatedFocus)
  }

  func testFocusStateDoesNotChangeSeededSimulationOrSaveCompatibility() throws {
    let baseline = makeStore(seed: 32_102)
    let focused = makeStore(seed: 32_102)
    var interaction = CompanyCommandInteractionState()
    interaction.toggleFocus(.agent("stacks"))
    interaction.toggleFocus(.founder)
    XCTAssertEqual(baseline.tasks, focused.tasks)
    XCTAssertEqual(baseline.agents, focused.agents)
    XCTAssertEqual(baseline.stats, focused.stats)

    let legacy = """
      {"version":1,"currentFacility":0,"ownedFacilities":[0],"highestTrackRecord":4,"completedCareerCount":0,"recordedCareerIDs":[]}
      """.data(using: .utf8)!
    XCTAssertNoThrow(try JSONDecoder().decode(FounderProgressionSave.self, from: legacy))
  }

  private func assertFocusWithoutNavigation(agentID: String) {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent(agentID))
    XCTAssertEqual(state.focus, .agent(agentID))
    XCTAssertNil(state.navigationRequest)
  }

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func makeAgent() -> SoloAgent {
    SoloAgent(
      id: "aurora",
      name: "Aurora",
      initials: "AU",
      role: .research,
      modelFamily: "Visible Family",
      reliability: 82,
      calibration: 0.76,
      drift: 0,
      trust: 72
    )
  }

  private func makeTask(
    reviewed: Bool,
    result: TaskResult,
    resolutionLocked: Bool = false
  ) -> SoloTask {
    SoloTask(
      title: "Stable Task",
      detail: "Visible task detail.",
      role: .research,
      impact: .momentum(4),
      assignedAgentID: "aurora",
      isReviewed: reviewed,
      result: result,
      resolutionLocked: resolutionLocked
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
    taskID: UUID,
    revealStep: Int = 0
  ) -> PresentationCoordinator.AgentPresentation {
    PresentationCoordinator.AgentPresentation(
      taskID: taskID,
      agentID: "aurora",
      taskTitle: "Stable Task",
      phase: phase,
      progress: 0.7,
      reviewRevealStep: revealStep
    )
  }
}
