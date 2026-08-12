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

  func testThreeToFiveBayLayoutsNeverOverlapEachOtherOrDesk() {
    for count in 3...5 {
      let layout = GarageBayLayout(stationCount: count)
      XCTAssertEqual(layout.bays.count, count)
      for first in layout.bays.indices {
        XCTAssertFalse(layout.bays[first].frame.intersects(GarageBayLayout.deskFrame))
        for second in layout.bays.indices where second > first {
          XCTAssertFalse(layout.bays[first].frame.intersects(layout.bays[second].frame))
          XCTAssertNotEqual(layout.bays[first].center, layout.bays[second].center)
        }
      }
    }
  }

  func testFiveBayPresentationTokensAreDistinct() {
    XCTAssertEqual(Set((0..<5).map(GarageBayPresentation.accentToken)).count, 5)
    XCTAssertEqual(Set((0..<5).map(GarageBayPresentation.icon)).count, 5)
  }

  func testFiveAgentStationsRemainAssignableAndReviewable() {
    let agents = (0..<5).map { index in
      SoloAgent(id: "agent-\(index)", name: "Agent \(index)", initials: "A\(index)", role: .general, modelFamily: "Model \(index)", reliability: 75, calibration: 0.7, drift: 0, trust: 60)
    }
    let stations = agents.map { AgentStationViewModel.derive(agent: $0, task: nil, founderStats: FounderStats()) }
    XCTAssertEqual(stations.count, agents.count)
    XCTAssertTrue(stations.allSatisfy { GarageTurnGate(phase: .assignTeam).stationIsActionable($0) })
    XCTAssertTrue(stations.allSatisfy { GarageTurnGate(phase: .reviewAndResolve).stationIsActionable($0) })
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
