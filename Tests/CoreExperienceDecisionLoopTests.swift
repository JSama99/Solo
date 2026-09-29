import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class CoreExperienceDecisionLoopTests: XCTestCase {
  private let seed: UInt64 = 0x50_41_53_53_32_41
  private let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  func testStacksLaunchRiskProducesAttributedDeterministicConsequenceChain() throws {
    let expectedTypes: [TraceEvent.Kind] = [
      .assignment, .report, .uncertainty, .evidence, .founderJudgment,
      .delayedRisk, .delayedConsequence, .publicReaction, .hindsight, .nextDecisionContext
    ]

    let first = try runFixture(reloadAfterScheduling: false)
    assertFirstDivergence(actual: first.events.map(\.kind), expected: expectedTypes)

    let replay = try runFixture(reloadAfterScheduling: false)
    assertFirstDivergence(actual: replay.events, expected: first.events)
    XCTAssertEqual(replay.finalRNGState, first.finalRNGState)

    let restored = try runFixture(reloadAfterScheduling: true)
    assertFirstDivergence(actual: restored.events, expected: first.events)
    XCTAssertEqual(restored.finalRNGState, first.finalRNGState)
  }

  func testVersionTwentyLatentDefectWithoutPass2AAttributionStillDecodes() throws {
    let legacy = Data(#"""
    {
      "id":"DEF-LEGACY","originVenture":1,"originSprint":2,
      "originTaskTitle":"Legacy launch","originAgentName":"Stacks",
      "originEvidenceCompleteness":30,"surfacesAtCareerSprint":4,"severity":18
    }
    """#.utf8)

    let defect = try JSONDecoder().decode(LatentDefect.self, from: legacy)

    XCTAssertNil(defect.originTaskID)
    XCTAssertNil(defect.originAgentID)
    XCTAssertNil(defect.originResolution)
    XCTAssertEqual(defect.id, "DEF-LEGACY")
  }

  private func runFixture(reloadAfterScheduling: Bool) throws -> FixtureResult {
    var store = makeStore()
    let initialStacksTrust = try XCTUnwrap(store.agents.first(where: { $0.id == "stacks" })?.trust)
    store.tasks[0] = SoloTask(
      id: taskID,
      title: "Launch Readiness",
      detail: "Prove the production build is ready for the public launch window.",
      role: .engineering,
      category: .product,
      urgency: .critical,
      impact: .momentum(10),
      skipEffects: SimulationEffects(momentum: -6, trust: -4)
    )
    selectFirstDilemma(in: store)
    store.assign(agentID: "stacks", to: taskID)
    store.tasks[0].result = TaskResult(
      actualQuality: 42,
      reportedQuality: 86,
      evidenceCompleteness: 30,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(revenue: 180, momentum: 8),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: 80,
      confidenceUpperBound: 92,
      knownOperationalRisk: "Launch telemetry is incomplete"
    )

    var events: [TraceEvent] = [
      event(.assignment, id: taskID.uuidString, source: nil, system: "GameStore",
            summary: "Stacks receives Launch Readiness",
            delta: "seed=\(seed);venture=1;sprint=1;agent=stacks"),
      event(.report, id: "report-\(taskID.uuidString)", source: nil, system: "TaskResult",
            summary: "Stacks reports launch readiness at 86",
            delta: "reported=86;actual(verifier)=42;confidence=80-92;evidence=30")
    ]

    store.review(taskID: taskID)
    let reviewed = try XCTUnwrap(store.tasks[0].result)
    XCTAssertEqual(reviewed.verificationState, .evidenceIncomplete)
    XCTAssertNil(reviewed.revealedActualQuality, "incomplete evidence must not reveal hidden truth")
    events.append(event(
      .uncertainty, id: "verification-\(taskID.uuidString)", source: nil,
      system: "VerificationState", summary: "Review cannot resolve the confident report",
      delta: "state=evidenceIncomplete;actual(player)=hidden"
    ))

    let evidence = try XCTUnwrap(store.evidence.first(where: { $0.taskInstanceID == taskID.uuidString }))
    XCTAssertEqual(evidence.reportedQuality, 86)
    XCTAssertNil(evidence.actualQuality)
    events.append(event(
      .evidence, id: evidence.id.uuidString, source: nil, system: "EvidenceEntry",
      summary: "Evidence preserves the report without leaking actual quality",
      delta: "complete=30;reported=86;actual=hidden"
    ))

    store.resolveReviewedTask(taskID: taskID, choice: .shipAnyway)
    let expectedDecisionID = "founder-decision-\(taskID.uuidString.lowercased())-shipAnyway"
    events.append(event(
      .founderJudgment, id: expectedDecisionID, source: expectedDecisionID,
      system: "GameStore", summary: "Founder ships despite unresolved evidence",
      delta: "action=shipAnyway;stacksTrust=\(store.agents.first(where: { $0.id == "stacks" })?.trust ?? -1)"
    ))

    store.stats.runway = 120
    store.stats.energy = 100
    store.stats.trust = 90
    store.commitSprint()
    let defect = try XCTUnwrap(store.latentDefects.first(where: { $0.originTaskID == taskID }))
    XCTAssertEqual(defect.originAgentID, "stacks")
    XCTAssertEqual(defect.originResolution, .shipAnyway)
    XCTAssertEqual(defect.sourceDecisionID, expectedDecisionID)
    events.append(event(
      .delayedRisk, id: defect.id, source: defect.sourceDecisionID,
      system: "LatentDefect", summary: "The unresolved launch weakness remains latent",
      delta: "surfaceAt=\(defect.surfacesAtCareerSprint);severity=\(defect.severity)"
    ))

    if reloadAfterScheduling {
      let restored = GameStore()
      restored.entitlements = StaticEntitlementProvider(hasFounderPass: true)
      restored.continueCareer()
      store = restored
      XCTAssertTrue(store.latentDefects.contains(where: { $0.id == defect.id }))
    }
    store.stats.coverage = 0

    while !store.publicMediaEvents.contains(where: { $0.id == "latent-\(defect.id)-surfaced" }) {
      XCTAssertLessThan(store.sprint, 8, "fixture must surface the delayed defect before sprint 8")
      store.report = nil
      store.stats.runway = max(store.stats.runway, 100)
      store.stats.energy = max(store.stats.energy, 90)
      store.stats.trust = max(store.stats.trust, 80)
      store.stats.coverage = 0
      selectFirstDilemma(in: store)
      let next = try XCTUnwrap(store.tasks.first)
      store.assign(agentID: "aurora", to: next.id)
      store.commitSprint()
    }

    XCTAssertFalse(store.latentDefects.contains(where: { $0.id == defect.id }))
    events.append(event(
      .delayedConsequence, id: defect.id, source: defect.sourceDecisionID,
      system: "GameStore", summary: "The production defect surfaces and applies company cost",
      delta: defect.effects.conciseLossLabel
    ))

    let mediaID = "latent-\(defect.id)-surfaced"
    let media = try XCTUnwrap(store.publicMediaEvents.first(where: { $0.id == mediaID }))
    XCTAssertTrue(media.isPublic)
    XCTAssertLessThan(media.coverageDelta, 0)
    XCTAssertTrue(
      TechComEngine.mergedOwnCompanyHeadlines(
        headlines: store.techComHeadlines,
        publicEvents: store.publicMediaEvents
      ).contains(where: { $0.publicEventID == media.id })
    )
    XCTAssertTrue(
      SignalTVProgramming.publicBroadcastEvents(store.publicMediaEvents)
        .contains(where: { $0.id == media.id })
    )
    events.append(event(
      .publicReaction, id: media.id, source: defect.sourceDecisionID,
      system: "PublicMediaEvent", summary: media.headline,
      delta: "coverage=\(media.coverageDelta);tone=\(media.tone.rawValue)"
    ))

    let precedent = try XCTUnwrap(store.precedents.first(where: { $0.delayedConsequenceID == defect.id }))
    XCTAssertEqual(precedent.sourceDecisionID, defect.sourceDecisionID)
    XCTAssertEqual(precedent.sourceAgentID, "stacks")
    XCTAssertTrue(precedent.decisionSummary.contains("Stacks"))
    XCTAssertTrue(precedent.decisionSummary.contains("shipped"))
    events.append(event(
      .hindsight, id: precedent.id.uuidString, source: defect.sourceDecisionID,
      system: "Hindsight", summary: precedent.decisionSummary,
      delta: precedent.observedOutcomeSummary
    ))

    let currentStacksTrust = try XCTUnwrap(store.agents.first(where: { $0.id == "stacks" })?.trust)
    XCTAssertLessThan(currentStacksTrust, initialStacksTrust)
    XCTAssertLessThan(store.stats.coverage, 0)
    events.append(event(
      .nextDecisionContext, id: "context-v\(store.venture)-s\(store.sprint)",
      source: defect.sourceDecisionID, system: "GameStore + Hindsight",
      summary: "The next decision retains Stacks history and public pressure",
      delta: "stacksTrust=\(currentStacksTrust);coverage=negative;precedent=\(precedent.id.uuidString)"
    ))

    return FixtureResult(events: events, finalRNGState: store.randomNumberGenerator)
  }

  private func makeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.founderName = "Pass 2A Founder"
    store.selectedProductType = .saas
    store.selectedDoctrine = .guided
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func selectFirstDilemma(in store: GameStore) {
    if let choice = store.activeDilemma?.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
  }

  private func event(
    _ kind: TraceEvent.Kind,
    id: String,
    source: String?,
    system: String,
    summary: String,
    delta: String
  ) -> TraceEvent {
    TraceEvent(kind: kind, eventID: id, sourceDecisionID: source,
               system: system, summary: summary, stateDelta: delta)
  }

  private func assertFirstDivergence<T: Equatable>(
    actual: [T],
    expected: [T],
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for index in 0..<min(actual.count, expected.count) where actual[index] != expected[index] {
      XCTFail("First divergence at event \(index + 1): expected \(expected[index]), got \(actual[index])",
              file: file, line: line)
      return
    }
    XCTAssertEqual(actual.count, expected.count,
                   "First divergence at event \(min(actual.count, expected.count) + 1): trace length differs",
                   file: file, line: line)
  }
}

private struct FixtureResult {
  var events: [TraceEvent]
  var finalRNGState: SeededRandomNumberGenerator
}

private struct TraceEvent: Equatable, CustomStringConvertible {
  enum Kind: String, Equatable, CustomStringConvertible {
    case assignment, report, uncertainty, evidence, founderJudgment
    case delayedRisk, delayedConsequence, publicReaction, hindsight, nextDecisionContext
    var description: String { rawValue }
  }

  var kind: Kind
  var eventID: String
  var sourceDecisionID: String?
  var system: String
  var summary: String
  var stateDelta: String

  var description: String {
    "\(kind.rawValue)|\(eventID)|\(sourceDecisionID ?? "none")|\(system)|\(summary)|\(stateDelta)"
  }
}
