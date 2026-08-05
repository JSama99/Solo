import XCTest
@testable import Solo_Unicorn_Run

/// Hindsight is the reason a second venture is worth buying, so its rules are
/// tested directly — including the rule that it must never give advice.
final class HindsightTests: XCTestCase {

  private func context(
    doctrine: FounderDoctrine = .guided,
    intent: SprintIntent = .build,
    drift: ConditionBand = .medium,
    runway: ConditionBand = .medium,
    unverified: ConditionBand = .medium
  ) -> PrecedentContext {
    PrecedentContext(
      doctrine: doctrine,
      intent: intent,
      driftBand: drift,
      runwayBand: runway,
      unverifiedBand: unverified
    )
  }

  private func precedent(
    venture: Int = 1,
    sprint: Int = 5,
    context ctx: PrecedentContext? = nil,
    outcome: PrecedentOutcome = PrecedentOutcome(overclaimsSurfaced: 1)
  ) -> Precedent {
    Precedent(
      id: UUID(),
      venture: venture,
      sprint: sprint,
      context: ctx ?? context(),
      decisionSummary: "Committed 3 tasks with 1 verified and 2 unverified.",
      outcome: outcome
    )
  }

  // ── Bands ────────────────────────────────────────────────────────

  func testDriftBanding() {
    XCTAssertEqual(ConditionBand.drift(0), .low)
    XCTAssertEqual(ConditionBand.drift(24), .low)
    XCTAssertEqual(ConditionBand.drift(25), .medium)
    XCTAssertEqual(ConditionBand.drift(54), .medium)
    XCTAssertEqual(ConditionBand.drift(55), .high)
  }

  func testRunwayBandingIsInverted() {
    // Fewer days is the dangerous end, so a short runway must band low.
    XCTAssertEqual(ConditionBand.runway(5), .low)
    XCTAssertEqual(ConditionBand.runway(30), .medium)
    XCTAssertEqual(ConditionBand.runway(90), .high)
  }

  func testUnverifiedBanding() {
    XCTAssertEqual(ConditionBand.unverified(0), .low)
    XCTAssertEqual(ConditionBand.unverified(1), .medium)
    XCTAssertEqual(ConditionBand.unverified(3), .high)
  }

  // ── Similarity ───────────────────────────────────────────────────

  func testIdenticalContextScoresOne() {
    let ctx = context()
    XCTAssertEqual(HindsightEngine.similarity(precedent(context: ctx), ctx), 1.0, accuracy: 0.0001)
  }

  func testDivergentContextScoresBelowFloor() {
    let recorded = context(doctrine: .pure, intent: .build, drift: .low, runway: .high, unverified: .low)
    let live = context(doctrine: .trust, intent: .sell, drift: .high, runway: .low, unverified: .high)
    XCTAssertLessThan(HindsightEngine.similarity(precedent(context: recorded), live),
                      HindsightEngine.similarityFloor)
  }

  func testSimilarityIsMonotonic() {
    let live = context()
    let exact = HindsightEngine.similarity(precedent(context: live), live)
    let oneOff = HindsightEngine.similarity(
      precedent(context: context(drift: .high)), live
    )
    XCTAssertGreaterThan(exact, oneOff)
  }

  // ── Recall ───────────────────────────────────────────────────────

  func testRecallRequiresAnEarlierVenture() {
    let live = context()
    // Same venture: a precedent from the run you are inside is not hindsight.
    XCTAssertNil(HindsightEngine.recall(
      from: [precedent(venture: 2, context: live)],
      matching: live, currentVenture: 2, recallsAlreadyShown: 0
    ))
    XCTAssertNotNil(HindsightEngine.recall(
      from: [precedent(venture: 1, context: live)],
      matching: live, currentVenture: 2, recallsAlreadyShown: 0
    ))
  }

  func testRecallIsCappedPerVenture() {
    let live = context()
    let pool = [precedent(venture: 1, context: live)]
    XCTAssertNotNil(HindsightEngine.recall(
      from: pool, matching: live, currentVenture: 2,
      recallsAlreadyShown: HindsightEngine.maximumRecallsPerVenture - 1
    ))
    XCTAssertNil(HindsightEngine.recall(
      from: pool, matching: live, currentVenture: 2,
      recallsAlreadyShown: HindsightEngine.maximumRecallsPerVenture
    ))
  }

  func testRecallPrefersTheStrongerMatch() throws {
    let live = context()
    let weak = precedent(venture: 1, sprint: 2, context: context(runway: .high, unverified: .low))
    let strong = precedent(venture: 1, sprint: 3, context: live)
    let recall = try XCTUnwrap(HindsightEngine.recall(
      from: [weak, strong], matching: live, currentVenture: 2, recallsAlreadyShown: 0
    ))
    XCTAssertEqual(recall.precedent.id, strong.id)
  }

  func testRecallReturnsNilWhenNothingClearsTheFloor() {
    let recorded = context(intent: .build, drift: .low, runway: .high, unverified: .low)
    let live = context(intent: .sell, drift: .high, runway: .low, unverified: .high)
    XCTAssertNil(HindsightEngine.recall(
      from: [precedent(venture: 1, context: recorded)],
      matching: live, currentVenture: 2, recallsAlreadyShown: 0
    ))
  }

  // ── Consequence filter ───────────────────────────────────────────

  func testUneventfulSprintsAreNotRecorded() {
    XCTAssertFalse(HindsightEngine.isConsequential(PrecedentOutcome()))
    XCTAssertFalse(HindsightEngine.isConsequential(
      PrecedentOutcome(unverifiedCommitted: 1, trustDelta: 2)
    ))
  }

  func testConsequentialSprintsAreRecorded() {
    XCTAssertTrue(HindsightEngine.isConsequential(PrecedentOutcome(overclaimsSurfaced: 1)))
    XCTAssertTrue(HindsightEngine.isConsequential(PrecedentOutcome(driftDetections: 1)))
    XCTAssertTrue(HindsightEngine.isConsequential(PrecedentOutcome(unverifiedCommitted: 2)))
    XCTAssertTrue(HindsightEngine.isConsequential(PrecedentOutcome(trustDelta: -9)))
    XCTAssertTrue(HindsightEngine.isConsequential(PrecedentOutcome(runwayDelta: -12)))
  }

  // ── The load-bearing rule ────────────────────────────────────────

  func testRecallReportsConditionsAndNeverGivesAdvice() {
    let outcome = PrecedentOutcome(
      overclaimsSurfaced: 2, driftDetections: 1, unverifiedCommitted: 2,
      trustDelta: -9, runwayDelta: -6, momentumDelta: 3
    )
    let text = [precedent(outcome: outcome).context.summary, outcome.summary].joined(separator: " ")

    XCTAssertTrue(text.contains("overclaim"))
    XCTAssertTrue(text.contains("trust"))
    for banned in ["should", "wrong", "mistake", "avoid", "instead", "recommend", "better"] {
      XCTAssertFalse(
        text.lowercased().contains(banned),
        "a precedent must report conditions, never judge or advise (found '\(banned)')"
      )
    }
  }

  func testEmptyOutcomeStillReadsAsAStatement() {
    XCTAssertEqual(PrecedentOutcome().summary, "No measurable change was recorded.")
  }

  func testPrecedentSurvivesCoding() throws {
    let original = precedent()
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Precedent.self, from: data)
    XCTAssertEqual(decoded, original)
  }
}

/// The career layer must never perturb the seeded simulation.
@MainActor
final class HindsightIntegrationTests: XCTestCase {
  override func tearDown() {
    GameStore().resetCareer()
    super.tearDown()
  }

  func testRecallConsumesNoRandomnessAndChangesNoState() {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: 99)

    let rngBefore = store.randomNumberGenerator
    let statsBefore = store.stats
    store.refreshHindsightRecall()
    store.refreshHindsightRecall()

    XCTAssertEqual(store.randomNumberGenerator, rngBefore, "recall must not consume simulation RNG")
    XCTAssertEqual(store.stats.runway, statsBefore.runway)
    XCTAssertEqual(store.stats.trust, statsBefore.trust)
  }

  func testRecallIsSuppressedWithoutTheFounderPass() {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: false)
    store.startCareer(seed: 7)
    store.refreshHindsightRecall()
    XCTAssertNil(store.activeRecall, "Hindsight Recall is Founder Pass content")
  }

  func testPrecedentContextReflectsLiveConditions() {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 11)
    let context = store.currentPrecedentContext()
    XCTAssertEqual(context.doctrine, store.doctrine)
    XCTAssertEqual(context.intent, store.intent)
    XCTAssertEqual(context.driftBand, ConditionBand.drift(store.averageDrift))
  }
}

/// Determinism guarantees for the career layer.
final class PrecedentIdentityTests: XCTestCase {

  func testIdentityIsStableForTheSameCareerPosition() {
    XCTAssertEqual(
      HindsightEngine.identifier(venture: 1, sprint: 7),
      HindsightEngine.identifier(venture: 1, sprint: 7)
    )
  }

  func testIdentityIsUniquePerCareerPosition() {
    var seen = Set<UUID>()
    for venture in 1...2 {
      for sprint in 1...12 {
        XCTAssertTrue(
          seen.insert(HindsightEngine.identifier(venture: venture, sprint: sprint)).inserted,
          "venture \(venture) sprint \(sprint) collided"
        )
      }
    }
    XCTAssertEqual(seen.count, 24)
  }

  func testIdentityHandlesOutOfRangeInputSafely() {
    // Must not trap on negative input from a corrupted save.
    XCTAssertNoThrow(HindsightEngine.identifier(venture: -5, sprint: -9))
  }
}

/// Recording a precedent must never perturb the run being recorded.
@MainActor
final class PrecedentRecordingDeterminismTests: XCTestCase {
  override func tearDown() {
    GameStore().resetCareer()
    super.tearDown()
  }

  private func digest(seed: UInt64) -> String {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    var parts: [String] = []
    var iterations = 0
    while store.careerOutcome == nil && iterations < 24 {
      iterations += 1
      for (offset, task) in store.tasks.enumerated() {
        store.assign(agentID: store.agents[offset % store.agents.count].id, to: task.id)
      }
      if let choice = store.activeDilemma?.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      store.commitSprint()
      store.report = nil
      parts.append("\(store.stats.revenue)|\(store.stats.trust)|\(store.stats.runway)|\(store.averageDrift)")
    }
    return parts.joined(separator: ";")
  }

  func testSeededRunsAreReproducibleWithPrecedentRecordingActive() {
    XCTAssertEqual(digest(seed: 555), digest(seed: 555))
  }

  func testDifferentSeedsDiverge() {
    XCTAssertNotEqual(digest(seed: 1), digest(seed: 2))
  }

  func testConsequentialSprintsProducePrecedents() {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: 8_675_309)

    var iterations = 0
    while store.careerOutcome == nil && store.precedents.isEmpty && iterations < 24 {
      iterations += 1
      // Commit everything unverified — the reliable way to make a sprint matter.
      for (offset, task) in store.tasks.enumerated() {
        store.assign(agentID: store.agents[offset % store.agents.count].id, to: task.id)
      }
      if let choice = store.activeDilemma?.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      store.commitSprint()
      store.report = nil
    }
    XCTAssertFalse(store.precedents.isEmpty, "unverified commits must bank precedents")
    for precedent in store.precedents {
      XCTAssertFalse(precedent.decisionSummary.isEmpty)
      XCTAssertGreaterThan(precedent.sprint, 0)
    }
  }

  func testPrecedentsSurviveSaveAndReload() throws {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: 24_680)

    var iterations = 0
    while store.careerOutcome == nil && store.precedents.isEmpty && iterations < 24 {
      iterations += 1
      for (offset, task) in store.tasks.enumerated() {
        store.assign(agentID: store.agents[offset % store.agents.count].id, to: task.id)
      }
      if let choice = store.activeDilemma?.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      store.commitSprint()
      store.report = nil
    }
    try XCTSkipIf(store.precedents.isEmpty, "no consequential sprint occurred for this seed")
    let expected = store.precedents.count

    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    reloaded.continueCareer()
    XCTAssertEqual(reloaded.precedents.count, expected, "precedents must persist across reload")
  }
}
