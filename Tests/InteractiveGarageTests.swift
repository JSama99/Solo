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

  func testStationsRejectTapsOutsideTheirPhase() {
    XCTAssertFalse(GarageTurnGate(phase: .founderEvent).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .assignTeam).stationIsActionable(idle))
    XCTAssertFalse(GarageTurnGate(phase: .reviewAndResolve).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsActionable(awaitingReview))
    XCTAssertFalse(GarageTurnGate(phase: .readyToCommit).stationIsActionable(awaitingReview))
  }

  func testDeskRemainsAvailableAfterFounderEvent() {
    XCTAssertTrue(GarageTurnGate(phase: .founderEvent).deskIsActionable)
    XCTAssertTrue(GarageTurnGate(phase: .assignTeam).deskIsActionable)
    XCTAssertTrue(GarageTurnGate(phase: .readyToCommit).deskIsActionable)
  }
}
