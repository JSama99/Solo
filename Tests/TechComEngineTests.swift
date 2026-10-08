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

  func testPrivateReviewCannotTakePublicHeadlineSlot() {
    let task = SoloTask(title: "Proof", detail: "", role: .engineering, impact: .momentum(2))
    let agent = SoloAgent(id: "a", name: "Avery", initials: "AV", role: .engineering, modelFamily: "M", reliability: 80, calibration: 0.7, drift: 0, trust: 60)
    let result = VisibleTaskResult(reportedQuality: 80, actualQuality: 60, verificationState: .overclaimed, overclaimAmount: 20, evidenceCompleteness: 80, confidenceRangeLabel: "55–85", knownOperationalRisk: "Normal operational variance", correlatedFailureDetected: false)
    var sprint = sprintResult()
    sprint.headline = "Known risks need founder attention"
    var generator = SeededRandomNumberGenerator(seed: 2)
    let events: [PresentationCoordinator.Event] = [.assignment(id: UUID(), taskID: task.id, agentID: agent.id, restored: false), .review(id: UUID(), taskID: task.id, agentID: agent.id, result: result, evidenceChanged: true), .sprint(id: UUID(), result: sprint)]
    let headlines = TechComEngine.headlines(snapshot: snapshot(tasks: [task], agents: [agent]), events: events, generator: &generator)
    XCTAssertEqual(headlines.count, TechComEngine.maximumHeadlinesPerSprint)
    XCTAssertEqual(headlines.filter { $0.category == .trend }.count, 1)
    XCTAssertFalse(headlines.contains { $0.text.contains("overclaimed") || $0.text.contains("actual 60") })
    XCTAssertFalse(headlines.contains { $0.text.contains("Known risks") })
    XCTAssertTrue(headlines.contains { $0.text.contains("takes on") })
    XCTAssertTrue(headlines.contains { $0.text.contains("closes sprint") })
  }

  func testRivalsAreDeterministicAndClaimsNeverTrailActuals() {
    let rivals = TechComEngine.rivals(seed: 77)
    XCTAssertEqual(rivals, TechComEngine.rivals(seed: 77))
    XCTAssertNotEqual(rivals, TechComEngine.rivals(seed: 78))
    for rival in rivals {
      XCTAssertGreaterThanOrEqual(rival.claimedTrackRecord, rival.actualTrackRecord)
      XCTAssertGreaterThanOrEqual(rival.claimedRevenue, rival.actualRevenue)
      XCTAssertGreaterThanOrEqual(rival.claimedMomentum, rival.actualMomentum)
    }
  }

  func testIndustryTrendsDoNotDependOnPrivateReviewOrAgentState() {
    var task = SoloTask(title: "Private proof", detail: "", role: .engineering, impact: .momentum(2))
    task.isReviewed = true
    task.result = TaskResult(
      actualQuality: 40, reportedQuality: 90, evidenceCompleteness: 80,
      correlatedFailureIdentifier: nil, immediateEffects: SimulationEffects(),
      delayedEffects: SimulationEffects(), confidenceLowerBound: 70,
      confidenceUpperBound: 95, knownOperationalRisk: "Normal operational variance"
    )
    let agent = SoloAgent(id: "stacks", name: "Stacks", initials: "ST", role: .engineering,
      modelFamily: "M", reliability: 80, calibration: 0.7, drift: 80, trust: 60)
    for seed in UInt64(0)..<20 {
      var privateGenerator = SeededRandomNumberGenerator(seed: seed)
      var publicGenerator = privateGenerator
      let privateHeadlines = TechComEngine.headlines(
        snapshot: snapshot(tasks: [task], agents: [agent]), events: [], generator: &privateGenerator
      )
      let publicHeadlines = TechComEngine.headlines(
        snapshot: snapshot(), events: [], generator: &publicGenerator
      )
      XCTAssertEqual(privateHeadlines.map(\.text), publicHeadlines.map(\.text))
      XCTAssertEqual(privateGenerator, publicGenerator)
      XCTAssertEqual(publicHeadlines.count, TechComEngine.maximumHeadlinesPerSprint)
    }
  }

  func testPublicCompanyEventsMergeDeterministicallyWithoutDuplicateHeadline() {
    let publicEvent = PublicMediaEvent(
      id: "funding-pioneer-ai-grant-awarded",
      program: .breaking,
      tone: .favorable,
      headline: "SOLO secures Pioneer AI Grant",
      summary: "The public award was announced.",
      tickerItems: ["SOLO AWARDED"],
      coverageDelta: 0,
      venture: 1,
      sprint: 2,
      concernsPlayerCompany: true
    )
    let duplicate = TechComHeadline(
      id: UUID(),
      category: .ownCompany,
      text: "Duplicate",
      venture: 1,
      sprint: 2,
      publicEventID: publicEvent.id
    )
    let first = TechComEngine.mergedOwnCompanyHeadlines(
      headlines: [duplicate],
      publicEvents: [publicEvent, publicEvent]
    )
    let second = TechComEngine.mergedOwnCompanyHeadlines(
      headlines: [duplicate],
      publicEvents: [publicEvent]
    )

    XCTAssertEqual(first, second)
    XCTAssertEqual(first.count, 1)
    XCTAssertEqual(first[0].text, publicEvent.headline)
    XCTAssertEqual(first[0].publicEventID, publicEvent.id)

    var privateEvent = publicEvent
    privateEvent.isPublic = false
    var rivalEvent = publicEvent
    rivalEvent.concernsPlayerCompany = false
    XCTAssertTrue(TechComEngine.mergedOwnCompanyHeadlines(
      headlines: [], publicEvents: [privateEvent, rivalEvent]
    ).isEmpty)
  }

  private func snapshot(tasks: [SoloTask] = [], agents: [SoloAgent] = []) -> TechComSnapshot { TechComSnapshot(founderName: "Founder", venture: 1, sprint: 1, stats: FounderStats(), agents: agents, tasks: tasks, dilemmaChoice: nil) }
  private func sprintResult() -> VisibleSprintResult { VisibleSprintResult(id: UUID(), venture: 1, sprint: 1, headline: "Evidence shaped the outcome", revenueDelta: 20, capitalDelta: 5, momentumDelta: 2, trustDelta: 0, energyDelta: -1, runwayDelta: -2, reviewsCompleted: 1, verifiedStrongOutcomes: 0, visibleRiskFlags: 1, evidenceRecorded: 1, transition: .nextSprint) }
}
