import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class PresentationMappingTests: XCTestCase {
  func testIdleVisualStateMapping() {
    let state = AgentVisualState.derive(agent: makeAgent(), task: nil, founderStats: FounderStats())
    XCTAssertEqual(state.activity, .idle)
    XCTAssertEqual(state.verification, .none)
  }

  func testWorkingVisualStateMapping() {
    let agent = makeAgent()
    let task = makeTask(agent: agent, result: makeResult(actual: 70, reported: 72))
    let state = AgentVisualState.derive(agent: agent, task: task, founderStats: FounderStats())
    XCTAssertEqual(state.activity, .working)
    XCTAssertEqual(state.verification, .none)
  }

  func testReviewedStateMapping() {
    let agent = makeAgent()
    var result = makeResult(actual: 70, reported: 72)
    result.verify()
    let task = makeTask(agent: agent, reviewed: true, result: result)
    XCTAssertEqual(
      AgentVisualState.derive(agent: agent, task: task, founderStats: FounderStats()).activity,
      .reviewed
    )
  }

  func testVerifiedAndConfirmedMapping() {
    let agent = makeAgent()
    var confirmed = makeResult(actual: 72, reported: 74)
    confirmed.verify()
    var verified = makeResult(actual: 62, reported: 69)
    verified.verify()
    XCTAssertEqual(AgentVisualState.derive(
      agent: agent,
      task: makeTask(agent: agent, reviewed: true, result: confirmed),
      founderStats: FounderStats()
    ).verification, .confirmed)
    XCTAssertEqual(AgentVisualState.derive(
      agent: agent,
      task: makeTask(agent: agent, reviewed: true, result: verified),
      founderStats: FounderStats()
    ).verification, .verified)
  }

  func testOverclaimMapping() {
    let agent = makeAgent()
    var result = makeResult(actual: 50, reported: 72)
    result.verify()
    let state = AgentVisualState.derive(
      agent: agent,
      task: makeTask(agent: agent, reviewed: true, result: result),
      founderStats: FounderStats()
    )
    XCTAssertEqual(state.verification, .overclaiming(22))
  }

  func testDriftMapping() {
    var agent = makeAgent()
    agent.drift = 48
    let state = AgentVisualState.derive(agent: agent, task: nil, founderStats: FounderStats())
    XCTAssertTrue(state.warnings.contains(.drifting))
  }

  func testOverloadedPresentationMappingUsesOnlyVisibleConditions() {
    var agent = makeAgent()
    agent.drift = 48
    var task = makeTask(agent: agent, result: makeResult(actual: 70, reported: 72))
    task.role = .marketing
    let state = AgentVisualState.derive(agent: agent, task: task, founderStats: FounderStats())
    XCTAssertTrue(state.warnings.contains(.overloaded))
  }

  func testHiddenCorrelatedFailureProtection() {
    let result = makeResult(
      actual: 42,
      reported: 72,
      evidence: 82,
      correlatedFailureIdentifier: "HIDDEN-CASCADE"
    )
    let visible = VisibleSimulationProjection.taskResult(from: result)
    XCTAssertNil(visible.actualQuality)
    XCTAssertFalse(visible.correlatedFailureDetected)
    XCTAssertFalse(visible.hasVisibleRisk)
  }

  func testCorrelatedFailureAppearsOnlyAfterDriftDetection() {
    var result = makeResult(
      actual: 42,
      reported: 72,
      evidence: 82,
      correlatedFailureIdentifier: "DETECTED-CASCADE"
    )
    result.verify()
    let visible = VisibleSimulationProjection.taskResult(from: result)
    XCTAssertEqual(visible.verificationState, .driftDetected)
    XCTAssertTrue(visible.correlatedFailureDetected)
    XCTAssertEqual(visible.actualQuality, 42)
  }

  func testEvidenceIncompleteProtection() {
    var result = makeResult(actual: 81, reported: 82, evidence: 20)
    result.verify()
    let visible = VisibleSimulationProjection.taskResult(from: result)
    XCTAssertEqual(visible.verificationState, .evidenceIncomplete)
    XCTAssertNil(visible.actualQuality)
    XCTAssertFalse(visible.isVerifiedStrong)
  }

  func testVisibleSprintRejectsCanonicalHiddenCounts() {
    let agent = makeAgent()
    let hiddenCorrelation = makeResult(
      actual: 42,
      reported: 72,
      evidence: 82,
      correlatedFailureIdentifier: "HIDDEN-CASCADE"
    )
    let task = makeTask(agent: agent, result: hiddenCorrelation)
    let canonical = SprintReport(
      sprint: 1,
      headline: "Progress carried hidden risk",
      revenueDelta: 10,
      momentumDelta: 0,
      trustDelta: 0,
      energyDelta: -2,
      runwayDelta: -4,
      reviewed: 0,
      strongOutcomes: 99,
      riskyOutcomes: 99
    )
    let visible = VisibleSimulationProjection.sprintResult(
      canonicalReport: canonical,
      venture: 1,
      tasks: [task],
      statsBefore: FounderStats(),
      statsAfter: FounderStats(),
      agents: [agent],
      evidenceBefore: 0,
      evidenceAfter: 1,
      transition: .nextSprint
    )
    XCTAssertEqual(visible.verifiedStrongOutcomes, 0)
    XCTAssertEqual(visible.visibleRiskFlags, 0)
    XCTAssertNotEqual(visible.headline, canonical.headline)
    XCTAssertEqual(visible.assignments.count, 1)
    XCTAssertNil(visible.assignments[0].result.actualQuality)
    XCTAssertEqual(visible.assignments[0].result.confidenceRangeLabel, hiddenCorrelation.confidenceRangeLabel)
  }

  func testVisibleSprintSnapshotsMatchCanonicalBeforeAndAfterStats() {
    var before = FounderStats()
    before.runway = 40
    before.revenue = 700
    before.trackRecord = 11
    var after = before
    after.runway = 35
    after.revenue = 920
    after.trackRecord = 14
    let report = SprintReport(
      sprint: 3,
      headline: "Recorded",
      revenueDelta: 220,
      momentumDelta: 0,
      trustDelta: 0,
      energyDelta: 0,
      runwayDelta: -5,
      reviewed: 0,
      strongOutcomes: 0,
      riskyOutcomes: 0
    )

    let visible = VisibleSimulationProjection.sprintResult(
      canonicalReport: report,
      venture: 1,
      tasks: [],
      statsBefore: before,
      statsAfter: after,
      evidenceBefore: 0,
      evidenceAfter: 0,
      transition: .nextSprint
    )

    XCTAssertEqual(visible.before.runway, 40)
    XCTAssertEqual(visible.after.runway, 35)
    XCTAssertEqual(visible.before.revenue, 700)
    XCTAssertEqual(visible.after.revenue, 920)
    XCTAssertEqual(visible.before.trackRecord, 11)
    XCTAssertEqual(visible.after.trackRecord, 14)
  }

  func testReducedMotionPolicy() {
    let policy = PresentationPolicy(reduceMotion: true, applicationActivity: .active)
    XCTAssertFalse(policy.allowsAmbientMotion)
    XCTAssertFalse(policy.stagesResults)
  }

  func testBackgroundAnimationPolicy() {
    XCTAssertFalse(PresentationPolicy(reduceMotion: false, applicationActivity: .background).allowsAmbientMotion)
    XCTAssertFalse(PresentationPolicy(reduceMotion: false, applicationActivity: .inactive).stagesResults)
    XCTAssertTrue(PresentationPolicy(reduceMotion: false, applicationActivity: .active).allowsAmbientMotion)
  }

  func testVentureTransitionPresentation() {
    XCTAssertNotEqual(VisibleSprintResult.Transition.ventureThesis, .nextSprint)
  }

  func testPostCommitRoutesAreDerivedFromCanonicalStage() {
    let store = GameStore()
    let routes: [(GameStore.Stage, VisibleSprintResult.Transition)] = [
      (.game, .nextSprint),
      (.chapterMilestone, .chapterMilestone),
      (.ventureThesis, .ventureThesis),
      (.ventureCheckpoint, .ventureCheckpoint),
      (.ventureUnlock, .ventureUnlock)
    ]

    for (stage, expected) in routes {
      store.stage = stage
      XCTAssertEqual(PresentationCoordinator.transition(afterCommitting: store), expected)
    }
  }

  func testPostCommitRoutePrioritizesCareerOutcome() {
    let store = GameStore()
    store.stage = .game
    store.careerOutcome = CareerOutcome(
      kind: .victory,
      title: "Career complete",
      summary: "Recorded",
      score: 1
    )

    XCTAssertEqual(PresentationCoordinator.transition(afterCommitting: store), .careerEnded(.victory))
  }

  func testDistinctCareerEndingPresentation() {
    let treatments = Set([
      CareerEnvironmentTreatment(.victory),
      CareerEnvironmentTreatment(.bankruptcy),
      CareerEnvironmentTreatment(.burnout),
      CareerEnvironmentTreatment(.trustCollapse)
    ])
    XCTAssertEqual(treatments.count, 4)
  }

  private func makeAgent() -> SoloAgent {
    SoloAgent(
      id: "test-agent",
      name: "Test Agent",
      initials: "TA",
      role: .engineering,
      modelFamily: "Visible Family",
      reliability: 80,
      calibration: 0.75,
      drift: 0,
      trust: 65
    )
  }

  private func makeTask(
    agent: SoloAgent,
    reviewed: Bool = false,
    result: TaskResult
  ) -> SoloTask {
    SoloTask(
      title: "Test Task",
      detail: "Test visible mapping.",
      role: .engineering,
      impact: .momentum(5),
      assignedAgentID: agent.id,
      isReviewed: reviewed,
      result: result
    )
  }

  private func makeResult(
    actual: Int,
    reported: Int,
    evidence: Int = 80,
    correlatedFailureIdentifier: String? = nil
  ) -> TaskResult {
    TaskResult(
      actualQuality: actual,
      reportedQuality: reported,
      evidenceCompleteness: evidence,
      correlatedFailureIdentifier: correlatedFailureIdentifier,
      immediateEffects: SimulationEffects(),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: reported - 8,
      confidenceUpperBound: reported + 8,
      knownOperationalRisk: "Normal operational variance"
    )
  }
}
