import XCTest
@testable import Solo_Unicorn_Run

final class AgentWorkstationTests: XCTestCase {
  func testOnlyOneWorkstationCanBeExpandedAndTappingItAgainCollapsesAll() {
    var selected: String?
    selected = AgentWorkstationConfiguration.toggledSelection(current: selected, tapped: "aurora")
    XCTAssertEqual(selected, "aurora")

    selected = AgentWorkstationConfiguration.toggledSelection(current: selected, tapped: "stacks")
    XCTAssertEqual(selected, "stacks")

    selected = AgentWorkstationConfiguration.toggledSelection(current: selected, tapped: "stacks")
    XCTAssertNil(selected)
  }

  func testCollapsedAndExpandedAttributeContracts() {
    XCTAssertEqual(
      AgentWorkstationConfiguration.visibleAttributes(expanded: false),
      [.stress, .trust]
    )
    XCTAssertEqual(
      AgentWorkstationConfiguration.visibleAttributes(expanded: true),
      [.stress, .trust, .xp, .focus]
    )
  }

  func testPortraitSizesMatchBuild281Targets() {
    XCTAssertEqual(AgentWorkstationConfiguration.collapsedPortraitSize, 64)
    XCTAssertEqual(AgentWorkstationConfiguration.expandedPortraitSize, 116)
  }

  func testInCardActionsContainEveryFormerCommandDeckAction() {
    XCTAssertTrue(AgentWorkstationConfiguration.hasFormerDeckParity)
    XCTAssertEqual(AgentWorkstationConfiguration.formerDeckCommands, [.assign, .review, .rest])
    XCTAssertTrue(AgentWorkstationConfiguration.inCardCommands.contains(.resolve))
  }

  func testLifecycleGuardsMatchCanonicalFounderControls() {
    let unassigned = SoloTask(
      title: "Validate evidence",
      detail: "A deliberately long assignment used by workstation coverage.",
      role: .research,
      impact: .trust(2)
    )
    var completed = unassigned
    completed.result = TaskResult(
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

    let assignment = AgentWorkstationActionAvailability(
      sprintPhase: .chooseCommitments,
      task: unassigned,
      presentationPhase: .idle,
      attentionRemaining: 2,
      isResting: false
    )
    XCTAssertTrue(assignment.canAssign)
    XCTAssertTrue(assignment.canRest)
    XCTAssertFalse(assignment.canReview)
    XCTAssertFalse(assignment.canResolve)

    let review = AgentWorkstationActionAvailability(
      sprintPhase: .reviewAndResolve,
      task: completed,
      presentationPhase: .awaitingReview,
      attentionRemaining: 1,
      isResting: false
    )
    XCTAssertFalse(review.canAssign)
    XCTAssertTrue(review.canReview)
    XCTAssertFalse(review.canRest)

    completed.isReviewed = true
    let resolution = AgentWorkstationActionAvailability(
      sprintPhase: .reviewAndResolve,
      task: completed,
      presentationPhase: .reviewed,
      attentionRemaining: 0,
      isResting: false
    )
    XCTAssertTrue(resolution.canResolve)

    let resolving = AgentWorkstationActionAvailability(
      sprintPhase: .reviewAndResolve,
      task: completed,
      presentationPhase: .resolving,
      attentionRemaining: 0,
      isResting: false
    )
    XCTAssertFalse(resolving.canResolve)
  }

  func testPortraitAssetMappingPreservesAgentIdentity() {
    XCTAssertEqual(AgentPortraitAsset.name(for: "aurora"), "agent_aurora_portrait")
    XCTAssertEqual(AgentPortraitAsset.name(for: "stacks"), "agent_stacks_portrait")
    XCTAssertEqual(AgentPortraitAsset.name(for: "brio"), "agent_brio_portrait")
  }

  func testUnknownAgentUsesInitialsFallback() {
    XCTAssertNil(AgentPortraitAsset.name(for: "unknown"))
  }
}
