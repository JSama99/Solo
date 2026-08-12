import XCTest
@testable import Solo_Unicorn_Run

final class InteractiveGarageTests: XCTestCase {
  private let idle = AgentStationViewModel(agentID: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Nova", trust: 80, taskTitle: nil, semanticState: .idle, mood: "Ready")
  private let awaitingReview = AgentStationViewModel(agentID: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Nova", trust: 80, taskTitle: "Audit", semanticState: .awaitingReview, mood: "Focused")

  func testPhaseActionabilityMapping() {
    XCTAssertEqual(GarageTurnGate(phase: .founderEvent).primary, .desk)
    XCTAssertEqual(GarageTurnGate(phase: .chooseCommitments).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .assignTeam).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .reviewAndResolve).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .readyToCommit).primary, .desk)
  }

  func testStationsAreReachableAfterFounderEventAndHighlightGuidesNextWork() {
    XCTAssertFalse(GarageTurnGate(phase: .founderEvent).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .assignTeam).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsActionable(awaitingReview))
    XCTAssertTrue(GarageTurnGate(phase: .readyToCommit).stationIsActionable(awaitingReview))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsHighlighted(awaitingReview))
    XCTAssertTrue(GarageTurnGate(phase: .assignTeam).stationIsHighlighted(idle))
  }

  @MainActor func testFullTurnKeepsStationsReachable() throws {
    let store = GameStore()
    store.selectedCareerMode = .bounded
    store.startCareer(seed: 321)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let presentation = PresentationCoordinator()
    for task in store.tasks {
      let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
      let station = AgentStationViewModel.derive(agent: agent, task: task, founderStats: store.stats)
      XCTAssertTrue(GarageTurnGate(phase: store.sprintPhase).stationIsActionable(station))
      presentation.assign(agentID: agent.id, to: task.id, in: store)
    }
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first(where: { $0.id == task.assignedAgentID }))
    XCTAssertTrue(GarageTurnGate(phase: store.sprintPhase).stationIsActionable(.derive(agent: agent, task: task, founderStats: store.stats)))
    presentation.review(taskID: task.id, in: store)
    store.resolveReviewedTask(taskID: task.id, choice: .approve)
    XCTAssertTrue(store.canCommitSprint == false || GarageTurnGate(phase: store.sprintPhase).stationIsActionable(.derive(agent: agent, task: task, founderStats: store.stats)))
  }
}
