import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class AgentWorkstationTests: XCTestCase {
  func testOnlyOneWorkstationCanBeExpandedAndTappingItAgainCollapsesAll() {
    var selected: String?
    selected = selected == "aurora" ? nil : "aurora"
    XCTAssertEqual(selected, "aurora")

    selected = selected == "stacks" ? nil : "stacks"
    XCTAssertEqual(selected, "stacks")

    selected = selected == "stacks" ? nil : "stacks"
    XCTAssertNil(selected)
  }

  func testCollapsedAndExpandedAttributeContracts() {
    let progression = AgentProgressionState(
      xp: 250,
      selectedPerks: [.sourceTriangulation],
      stressLevel: 62
    )
    let station = AgentStationViewModel.derive(
      agent: makeAgent(progression: progression),
      task: nil,
      founderStats: FounderStats()
    )
    XCTAssertEqual(station.progression.stressBand, .pressured)
    XCTAssertEqual(station.trust, 67)
    XCTAssertEqual(station.progression.xp, 250)
    XCTAssertEqual(station.progression.specialization, "Evidence Architect")
  }

  func testPortraitSizesMatchBuild281Targets() {
    let station = AgentStationViewModel.derive(
      agent: makeAgent(),
      task: nil,
      founderStats: FounderStats()
    )
    XCTAssertEqual(station.agentID, "aurora")
    XCTAssertEqual(station.initials, "AU")
    XCTAssertEqual(station.semanticState, .idle)
  }

  func testInCardActionsContainEveryFormerCommandDeckAction() {
    XCTAssertEqual(GarageTurnGate(phase: .chooseCommitments).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .assignTeam).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .reviewAndResolve).primary, .stations)
    XCTAssertEqual(Set(TaskResolutionChoice.allCases), Set([.approve, .rework, .shipAnyway, .escalate]))
  }

  func testLifecycleGuardsMatchCanonicalFounderControls() {
    let agent = makeAgent()
    var task = makeTask(agentID: agent.id)

    for phase in [PresentationCoordinator.AgentPhase.assignmentReceived, .working, .workComplete] {
      XCTAssertEqual(station(agent: agent, task: task, phase: phase).semanticState, .working)
    }
    XCTAssertEqual(station(agent: agent, task: task, phase: .awaitingReview).semanticState, .awaitingReview)

    task.isReviewed = true
    task.result?.verify()
    for phase in [PresentationCoordinator.AgentPhase.reviewed, .resolving, .resolved] {
      XCTAssertEqual(station(agent: agent, task: task, phase: phase).semanticState, .verified)
    }
  }

  func testPortraitAssetMappingPreservesAgentIdentity() {
    XCTAssertEqual(AgentPortraitAsset.name(for: "aurora"), "agent_aurora_portrait")
    XCTAssertEqual(AgentPortraitAsset.name(for: "stacks"), "agent_stacks_portrait")
    XCTAssertEqual(AgentPortraitAsset.name(for: "brio"), "agent_brio_portrait")
  }

  func testUnknownAgentUsesInitialsFallback() {
    XCTAssertNil(AgentPortraitAsset.name(for: "unknown"))
  }

  private func makeAgent(progression: AgentProgressionState = .init()) -> SoloAgent {
    SoloAgent(
      id: "aurora",
      name: "Aurora",
      initials: "AU",
      role: .research,
      modelFamily: "Evidence Model",
      reliability: 84,
      calibration: 0.8,
      drift: 0,
      trust: 67,
      progression: progression
    )
  }

  private func makeTask(agentID: String) -> SoloTask {
    SoloTask(
      title: "Validate evidence",
      detail: "Verify the workstation lifecycle.",
      role: .research,
      impact: .trust(2),
      assignedAgentID: agentID,
      result: TaskResult(
        actualQuality: 72,
        reportedQuality: 76,
        evidenceCompleteness: 84,
        correlatedFailureIdentifier: nil,
        immediateEffects: SimulationEffects(),
        delayedEffects: SimulationEffects(),
        confidenceLowerBound: 65,
        confidenceUpperBound: 81,
        knownOperationalRisk: "Evidence must be independently checked before launch."
      )
    )
  }

  private func station(
    agent: SoloAgent,
    task: SoloTask,
    phase: PresentationCoordinator.AgentPhase
  ) -> AgentStationViewModel {
    AgentStationViewModel.derive(
      agent: agent,
      task: task,
      founderStats: FounderStats(),
      presentationPhase: phase
    )
  }
}
