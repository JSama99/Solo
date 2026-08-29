import XCTest
@testable import Solo_Unicorn_Run

final class AIOperationsFloorTests: XCTestCase {
  func testReviewQueueProjectsReportedOutputWithoutVerifiedClaim() {
    let reported = agent(id: "aurora", activity: .awaitingReview, conditions: [.focused])
    let queue = AIOperationsFloorProjection.derive(
      agents: [reported], summary: summary(), finance: .init(), calendar: .init()
    ).queue
    XCTAssertEqual(queue.count, 1)
    XCTAssertTrue(queue[0].isReviewable)
    XCTAssertTrue(queue[0].title.contains("reported output"))
    XCTAssertFalse(queue[0].detail.localizedCaseInsensitiveContains("verified"))
  }

  func testQueueIdentityIsCanonicalAgentIdentityAndDoesNotDuplicate() {
    let agent = agent(id: "stacks", activity: .workComplete, conditions: [.focused])
    let queue = AIOperationsFloorProjection.derive(agents: [agent], summary: summary(), finance: .init(), calendar: .init()).queue
    XCTAssertEqual(queue.map(\.id), ["stacks"])
  }

  func testReviewedAndResolvingWorkCannotBeReinvokedFromQueue() {
    let items = AIOperationsFloorProjection.derive(
      agents: [agent(id: "brio", activity: .reviewed, conditions: []), agent(id: "aurora", activity: .resolving, conditions: [])],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue
    XCTAssertEqual(items.count, 2)
    XCTAssertTrue(items.allSatisfy { !$0.isReviewable })
  }

  private func agent(id: String, activity: LivingAgentActivity, conditions: Set<LivingAgentCondition>) -> LivingAgentProjection {
    LivingAgentProjection(agentID: id, name: id.capitalized, initials: String(id.prefix(1)).uppercased(), role: id == "aurora" ? .research : id == "stacks" ? .engineering : .marketing, taskID: UUID(), taskTitle: "Canonical task", activity: activity, conditions: conditions, emphasis: .normal, progress: 0.5, reviewRevealStep: 0, stressLabel: "Stable", trustLabel: "Trust 85 or higher", level: 1, needsFounderAttention: false, isResting: false)
  }

  private func summary() -> CompanyCommandFounderSummary {
    .init(sprintPhase: .reviewAndResolve, workInProgressCount: 0, reviewCount: 1, resolutionCount: 0, attentionRemaining: 2, attentionMaximum: 2, canCommit: false, nextAction: "Review work")
  }
}
