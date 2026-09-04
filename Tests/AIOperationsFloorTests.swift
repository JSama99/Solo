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
    XCTAssertEqual(queue[0].lifecycle, "Reported output")
    XCTAssertFalse(queue[0].decisionSummary.localizedCaseInsensitiveContains("verified"))
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

  func testPrimaryStationProjectionUsesEachCanonicalAgentOnce() {
    let agents = [
      agent(id: "aurora", activity: .idle, conditions: []),
      agent(id: "aurora", activity: .working, conditions: [.focused]),
      agent(id: "stacks", activity: .idle, conditions: []),
      agent(id: "brio", activity: .idle, conditions: [])
    ]
    let stationIDs = AIOperationsFloorProjection.primaryStationIDs(from: agents)
    XCTAssertEqual(stationIDs, ["aurora", "stacks", "brio"])
  }

  func testQueueActionRequiresCanonicalReviewAvailability() {
    let item = AIOperationsFloorProjection.derive(
      agents: [agent(id: "aurora", activity: .awaitingReview, conditions: [])],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue[0]
    XCTAssertFalse(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(canReview: false)))
    XCTAssertTrue(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(canReview: true)))
  }

  func testCriticalFounderDecisionOutranksInformationalTransition() {
    let queue = AIOperationsFloorProjection.derive(
      agents: [
        agent(id: "brio", activity: .resolving, conditions: []),
        agent(id: "aurora", activity: .awaitingReview, conditions: [])
      ],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue
    XCTAssertEqual(queue.map(\.agentID), ["aurora", "brio"])
    XCTAssertEqual(queue.map(\.priority), [.critical, .informational])
  }

  func testReviewedItemNavigatesToResolutionWithoutReinvokingReview() {
    let item = AIOperationsFloorProjection.derive(
      agents: [agent(id: "stacks", activity: .reviewed, conditions: [])],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue[0]
    XCTAssertEqual(item.action, .resolve)
    XCTAssertFalse(item.isReviewable)
    XCTAssertFalse(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(canReview: true)))
    XCTAssertTrue(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(requiresResolution: true)))
  }

  func testEmptyQueueExplainsCanonicalRouting() {
    XCTAssertEqual(
      AIOperationsFloorProjection.emptyQueueText,
      "No reports awaiting Founder Review. Aurora, Stacks and Brio will route reported outputs here."
    )
  }

  func testPrimaryCompositionDeclaresOneConsoleQueueAndCanonicalStations() {
    let ids = AIOperationsFloorProjection.primarySurfaceIDs
    XCTAssertEqual(ids.count, 5)
    XCTAssertEqual(Set(ids).count, 5)
    XCTAssertEqual(ids.filter { $0 == "founder-command-console" }.count, 1)
    XCTAssertEqual(ids.filter { $0 == "operations-station-aurora" }.count, 1)
    XCTAssertEqual(ids.filter { $0 == "operations-station-stacks" }.count, 1)
    XCTAssertEqual(ids.filter { $0 == "operations-station-brio" }.count, 1)
  }

  func testReviewPrioritySuppressesCommitAsNextAction() {
    var founder = summary()
    founder.canCommit = true
    founder.reviewCount = 1
    let projection = AIOperationsFloorProjection.derive(
      agents: [agent(id: "aurora", activity: .awaitingReview, conditions: [])],
      summary: founder, finance: .init(), calendar: .init()
    )
    XCTAssertEqual(projection.nextAction.eyebrow, "FOUNDER REVIEW")
    XCTAssertNotEqual(projection.nextAction.shortTitle, "Commit Sprint")
  }

  func testProjectionDoesNotMutateCanonicalFinanceOrCalendar() {
    let finance = CompanyFinance(cash: 1_234, lifetimeRevenue: 432)
    let calendar = OperatingCalendar(totalDays: 91, dayOfSprint: 3, hour: 14)
    _ = AIOperationsFloorProjection.derive(
      agents: [agent(id: "aurora", activity: .working, conditions: [.focused])],
      summary: summary(), finance: finance, calendar: calendar
    )
    XCTAssertEqual(finance.cash, 1_234)
    XCTAssertEqual(finance.lifetimeRevenue, 432)
    XCTAssertEqual(calendar.totalDays, 91)
    XCTAssertEqual(calendar.dayOfSprint, 3)
    XCTAssertEqual(calendar.period, .afternoon)
  }

  func testReportedAccessibilityNeverClaimsVerification() {
    let reported = agent(id: "aurora", activity: .awaitingReview, conditions: [])
    let item = AIOperationsFloorProjection.derive(
      agents: [reported], summary: summary(), finance: .init(), calendar: .init()
    ).queue[0]
    XCTAssertTrue(item.accessibilityLabel.localizedCaseInsensitiveContains("reported"))
    XCTAssertFalse(item.accessibilityLabel.localizedCaseInsensitiveContains("verified"))
    XCTAssertFalse(reported.accessibilityValue.localizedCaseInsensitiveContains("verified"))
  }

  func testActiveFundingMilestoneAppearsInFounderCommandProjection() throws {
    let opportunity = try XCTUnwrap(FundingBoardCatalog.opportunities.first {
      $0.id == "founder-conviction-round"
    })
    let application = FundingApplicationRecord(
      opportunityID: opportunity.id,
      status: .resolved,
      appliedCareerSprint: 6,
      resolvedCareerSprint: 7,
      outcome: .funded,
      outcomeReason: "Every visible requirement remained met.",
      milestoneObligation: FundingMilestoneObligation(
        metric: .revenue,
        target: 6_000,
        createdCareerSprint: 7,
        dueCareerSprint: 11,
        missedTrustConsequence: 6,
        status: .active,
        resolvedCareerSprint: nil
      )
    )
    let presentations = FundingBoardEngine.presentations(
      snapshot: FundingBoardSnapshot(
        revenue: 4_200,
        trust: 70,
        momentum: 45,
        coverage: 10,
        venture: 1,
        evidenceCount: 2,
        careerSprint: 9,
        attentionRemaining: 2
      ),
      applications: [application]
    )
    let projection = AIOperationsFloorProjection.derive(
      agents: [],
      summary: summary(),
      finance: .init(),
      calendar: .init(),
      fundingOpportunities: presentations
    )
    let milestone = try XCTUnwrap(projection.fundingMilestone)

    XCTAssertTrue(milestone.title.contains(opportunity.name))
    XCTAssertTrue(milestone.progress.contains("$4,200"))
    XCTAssertTrue(milestone.progress.contains("$6,000"))
    XCTAssertTrue(milestone.deadline.contains("sprints remaining"))
    XCTAssertEqual(milestone.consequence, "If missed: Company Trust −6")

    for status: FundingMilestoneStatus in [.met, .missed] {
      var resolved = presentations
      let index = try XCTUnwrap(resolved.firstIndex { $0.id == opportunity.id })
      resolved[index].application?.milestoneObligation?.status = status
      XCTAssertNil(AIOperationsFloorProjection.derive(
        agents: [], summary: summary(), finance: .init(), calendar: .init(),
        fundingOpportunities: resolved
      ).fundingMilestone)
    }
  }

  private func agent(id: String, activity: LivingAgentActivity, conditions: Set<LivingAgentCondition>) -> LivingAgentProjection {
    LivingAgentProjection(agentID: id, name: id.capitalized, initials: String(id.prefix(1)).uppercased(), role: id == "aurora" ? .research : id == "stacks" ? .engineering : .marketing, taskID: UUID(), taskTitle: "Canonical task", activity: activity, conditions: conditions, emphasis: .normal, progress: 0.5, reviewRevealStep: 0, stressLabel: "Stable", trustLabel: "Trust 85 or higher", level: 1, needsFounderAttention: false, isResting: false)
  }

  private func summary() -> CompanyCommandFounderSummary {
    .init(sprintPhase: .reviewAndResolve, workInProgressCount: 0, reviewCount: 1, resolutionCount: 0, attentionRemaining: 2, attentionMaximum: 2, canCommit: false, nextAction: "Review work")
  }
}
