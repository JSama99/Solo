import XCTest
@testable import Solo_Unicorn_Run

final class AgentDetailTests: XCTestCase {
  func testSharedDetailSnapshotMatchesAllEntryPointDerivations() {
    let agent = SoloAgent(
      id: "aurora",
      name: "Aurora",
      initials: "AU",
      role: .research,
      modelFamily: "Scout",
      reliability: 80,
      calibration: 0.7,
      drift: 4,
      trust: 85
    )
    let task = SoloTask(
      title: "Research retention",
      detail: "Shared detail test.",
      role: .research,
      impact: .trust(4),
      assignedAgentID: agent.id
    )
    let stats = FounderStats()

    let roster = AgentDetailViewModel.derive(agent: agent, task: task, founderStats: stats)
    let garage = AgentDetailViewModel(
      station: AgentStationViewModel.derive(agent: agent, task: task, founderStats: stats)
    )
    let commandDeck = AgentDetailViewModel.derive(agent: agent, task: task, founderStats: stats)

    XCTAssertEqual(roster, garage)
    XCTAssertEqual(garage, commandDeck)
    XCTAssertEqual(roster.taskTitle, task.title)
  }

  func testDetailDoesNotInventTrustHistory() {
    let agent = SoloAgent(
      id: "stacks",
      name: "Stacks",
      initials: "ST",
      role: .engineering,
      modelFamily: "Forge",
      reliability: 80,
      calibration: 0.7,
      drift: 4,
      trust: 64
    )

    let detail = AgentDetailViewModel.derive(agent: agent, task: nil, founderStats: FounderStats())

    XCTAssertEqual(detail.recentTrustDeltas, [])
    XCTAssertEqual(detail.trustBand, .coral)
    XCTAssertEqual(detail.status, "Ready")
  }
}
