import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class TechComEngineTests: XCTestCase {
  func testSlotsArePopulatedForAssignment() {
    let task = SoloTask(title: "Build Proof", detail: "", role: .engineering, impact: .momentum(2))
    let agent = SoloAgent(id: "a", name: "Avery", initials: "AV", role: .engineering, modelFamily: "M", reliability: 80, calibration: 0.7, drift: 0, trust: 60)
    var generator = SeededRandomNumberGenerator(seed: 1)
    let results = TechComEngine.headlines(snapshot: snapshot(tasks: [task], agents: [agent]), events: [.assignment(id: UUID(), taskID: task.id, agentID: agent.id, restored: false)], generator: &generator)
    XCTAssertTrue(results.contains { $0.text.contains("Avery") && $0.text.contains("Build Proof") })
    XCTAssertFalse(results.contains { $0.text.contains("{") })
  }

  func testThrottleCapsLoudSprintWithoutDroppingEventHeadlinePriority() {
    let task = SoloTask(title: "Proof", detail: "", role: .engineering, impact: .momentum(2))
    let agent = SoloAgent(id: "a", name: "Avery", initials: "AV", role: .engineering, modelFamily: "M", reliability: 80, calibration: 0.7, drift: 0, trust: 60)
    let result = VisibleTaskResult(reportedQuality: 80, actualQuality: 60, verificationState: .overclaimed, overclaimAmount: 20, evidenceCompleteness: 80, confidenceRangeLabel: "55–85", knownOperationalRisk: "Normal operational variance", correlatedFailureDetected: false)
    var generator = SeededRandomNumberGenerator(seed: 2)
    let events: [PresentationCoordinator.Event] = [.assignment(id: UUID(), taskID: task.id, agentID: agent.id, restored: false), .review(id: UUID(), taskID: task.id, agentID: agent.id, result: result, evidenceChanged: true), .sprint(id: UUID(), result: sprintResult())]
    let headlines = TechComEngine.headlines(snapshot: snapshot(tasks: [task], agents: [agent]), events: events, generator: &generator)
    XCTAssertEqual(headlines.count, TechComEngine.maximumHeadlinesPerSprint)
    XCTAssertEqual(headlines.filter { $0.category == .trend }.count, 0)
    XCTAssertTrue(headlines.contains { $0.text.contains("overclaimed by 20") })
  }

  func testRivalsAreDeterministic() { XCTAssertEqual(TechComEngine.rivals(seed: 77), TechComEngine.rivals(seed: 77)) }

  private func snapshot(tasks: [SoloTask] = [], agents: [SoloAgent] = []) -> TechComSnapshot { TechComSnapshot(founderName: "Founder", venture: 1, sprint: 1, stats: FounderStats(), agents: agents, tasks: tasks, dilemmaChoice: nil) }
  private func sprintResult() -> VisibleSprintResult { VisibleSprintResult(id: UUID(), venture: 1, sprint: 1, headline: "Evidence shaped the outcome", revenueDelta: 20, capitalDelta: 5, momentumDelta: 2, trustDelta: 0, energyDelta: -1, runwayDelta: -2, reviewsCompleted: 1, verifiedStrongOutcomes: 0, visibleRiskFlags: 1, evidenceRecorded: 1, transition: .nextSprint) }
}
