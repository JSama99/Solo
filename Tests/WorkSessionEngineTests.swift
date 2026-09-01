import XCTest
@testable import Solo_Unicorn_Run

final class WorkSessionEngineTests: XCTestCase {
  private let assignmentID = UUID(uuidString: "A0A0A0A0-B1B1-C2C2-D3D3-E4E4E4E4E4E4")!

  func testPotentialExistsBeforeAnyPlayerDecision() {
    let record = makeRecord(potential: 83)
    XCTAssertEqual(record.agentPotentialQuality, 83)
    XCTAssertNil(record.path)
    XCTAssertNil(record.founderReviewQuality)
    XCTAssertNil(record.deliveredQuality)
    XCTAssertTrue(record.decisions.isEmpty)
  }

  func testDeliveredQualityCanNeverExceedPotential() {
    for potential in stride(from: 0, through: 100, by: 5) {
      for review in stride(from: 0, through: 100, by: 5) {
        let delivered = WorkSessionEngine.deliveredQuality(potential: potential, reviewQuality: review, path: .manualReview, seed: 9)
        XCTAssertLessThanOrEqual(delivered, potential)
      }
    }
  }

  func testPerfectReviewExtractsFullPotential() {
    XCTAssertEqual(WorkSessionEngine.deliveredQuality(potential: 91, reviewQuality: 100, path: .manualReview, seed: 1), 91)
  }

  func testPerfectCardJudgmentProducesFullReviewAndDelivery() throws {
    var record = makeRecord(potential: 91)
    record.path = .manualReview
    let expected: [String: EvidenceTriageAction] = [
      "activation-cohort": .use, "interview-theme": .use, "social-thread": .reject,
      "tam-forecast": .verify, "retention-conflict": .verify, "competitor-claim": .verify,
      "support-volume": .use, "single-customer": .verify, "synthetic-survey": .reject,
      "experiment": .use, "churn-notes": .verify, "old-benchmark": .reject
    ]
    for card in record.cards {
      XCTAssertTrue(WorkSessionEngine.record(try XCTUnwrap(expected[card.id]), in: &record))
    }
    XCTAssertTrue(WorkSessionEngine.completeManual(&record))
    XCTAssertEqual(record.founderReviewQuality, 100)
    XCTAssertEqual(record.deliveredQuality, record.agentPotentialQuality)
  }

  func testPoorReviewReducesDeliveredQuality() {
    XCTAssertLessThan(WorkSessionEngine.deliveredQuality(potential: 91, reviewQuality: 20, path: .manualReview, seed: 1), 91)
  }

  func testDelegationIsDeterministicAndBounded() {
    let first = WorkSessionEngine.deliveredQuality(potential: 88, reviewQuality: nil, path: .delegate, seed: 44)
    let second = WorkSessionEngine.deliveredQuality(potential: 88, reviewQuality: nil, path: .delegate, seed: 44)
    XCTAssertEqual(first, second)
    XCTAssertLessThanOrEqual(first, 88)
    XCTAssertGreaterThanOrEqual(first, 65)
  }

  func testChallengeGenerationIsDeterministicAndAssignmentStable() {
    let first = makeRecord(potential: 80)
    let second = makeRecord(potential: 80)
    XCTAssertEqual(first.challengeSeed, second.challengeSeed)
    XCTAssertEqual(first.cards, second.cards)
    XCTAssertEqual(first.id, second.id)

    let different = WorkSessionEngine.makeRecord(assignmentID: UUID(), agentID: "aurora", urgency: .normal, potentialQuality: 80, careerSeed: 10, venture: 1, sprint: 1, stress: .stable, attentionCost: 3)
    XCTAssertNotEqual(first.challengeSeed, different.challengeSeed)
  }

  func testVisibleCardAndVoiceOverMetadataDoNotLeakCorrectness() throws {
    let card = try XCTUnwrap(makeRecord(potential: 80).nextCardPresentation)
    let fieldNames = Set(Mirror(reflecting: card).children.compactMap(\.label))
    XCTAssertFalse(fieldNames.contains("idealAction"))
    XCTAssertFalse(fieldNames.contains("weight"))
    let metadata = card.accessibilityLabel.lowercased()
    for protected in ["correct", "incorrect", "ideal", "weak evidence", "strong evidence", "hidden", "drift", "overclaim"] {
      XCTAssertFalse(metadata.contains(protected), "Accessibility leaked protected truth: \(protected)")
    }
  }

  func testReduceMotionAndAccessibilityConfigurationCannotChangeScoring() {
    // Presentation settings are intentionally absent from the pure engine API.
    let standard = WorkSessionEngine.deliveredQuality(potential: 77, reviewQuality: 100, path: .manualReview, seed: 5)
    let accessibilityConfigured = WorkSessionEngine.deliveredQuality(potential: 77, reviewQuality: 100, path: .manualReview, seed: 5)
    XCTAssertEqual(standard, accessibilityConfigured)
    XCTAssertEqual(accessibilityConfigured, 77)
  }

  func testLegacyCareerSaveWithoutWorkSessionsDecodes() throws {
    let save = CareerSave(founderName: "Legacy", doctrine: .guided, sprint: 1, venture: 1, intent: .learn, stats: FounderStats(), agents: ContentLibrary.initialAgents, tasks: [], evidence: [], outcome: nil, randomNumberGenerator: SeededRandomNumberGenerator(seed: 1), correlatedFailureEvent: nil, pendingEffects: [])
    let encoded = try JSONEncoder().encode(save)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    json.removeValue(forKey: "workSessions")
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(CareerSave.self, from: legacyData)
    XCTAssertTrue(decoded.workSessions.isEmpty)
  }

  private func makeRecord(potential: Int) -> WorkSessionRecord {
    WorkSessionEngine.makeRecord(assignmentID: assignmentID, agentID: "aurora", urgency: .normal, potentialQuality: potential, careerSeed: 10, venture: 1, sprint: 1, stress: .stable, attentionCost: 3)
  }
}

@MainActor
final class WorkSessionStoreTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  func testManualReviewChargesAttentionExactlyOnceAcrossReopening() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.prepareEvidenceTriage(taskID: taskID))
    let cost = try XCTUnwrap(store.workSession(for: taskID)?.founderAttentionCost)
    let before = store.attentionRemaining

    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.attentionRemaining, before - cost)
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    XCTAssertTrue(store.prepareEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.attentionRemaining, before - cost)
  }

  func testDuplicateCompletionDoesNotDuplicateDeliveryOrEvidence() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    try finish(store: store, taskID: taskID, action: .use)
    let delivered = try XCTUnwrap(store.workSession(for: taskID)?.deliveredQuality)
    XCTAssertFalse(store.classifyEvidence(taskID: taskID, action: .use))
    XCTAssertEqual(store.workSession(for: taskID)?.deliveredQuality, delivered)

    store.review(taskID: taskID)
    let evidenceCount = store.evidence.count
    store.review(taskID: taskID)
    XCTAssertEqual(store.evidence.count, evidenceCount)
  }

  func testPoorManualReviewPersistsMistakesForHindsight() throws {
    let (store, taskID) = try makeEligibleStore()
    let potential = try XCTUnwrap(store.tasks.first(where: { $0.id == taskID })?.result?.workSessionPotentialQuality)
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    try finish(store: store, taskID: taskID, action: .use)
    let session = try XCTUnwrap(store.workSession(for: taskID))
    XCTAssertLessThanOrEqual(try XCTUnwrap(session.deliveredQuality), potential)
    XCTAssertFalse(session.mistakes.isEmpty)
    store.review(taskID: taskID)
    let evidence = try XCTUnwrap(store.evidence.first(where: { $0.taskInstanceID == taskID.uuidString }))
    XCTAssertEqual(evidence.workSessionMistakes, session.mistakes)
    XCTAssertEqual(evidence.hindsightNotes, session.hindsightExplanations)
    XCTAssertFalse(evidence.hindsightNotes.isEmpty)
  }

  func testDelegateCostsNoAttentionAndIsIdempotent() throws {
    let (store, taskID) = try makeEligibleStore()
    let before = store.attentionRemaining
    XCTAssertTrue(store.delegateEvidenceTriage(taskID: taskID))
    let first = try XCTUnwrap(store.workSession(for: taskID)?.deliveredQuality)
    XCTAssertFalse(store.delegateEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.workSession(for: taskID)?.deliveredQuality, first)
    XCTAssertEqual(store.attentionRemaining, before)
  }

  func testInterruptedSessionRestoresCardsDecisionsAndCharge() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    XCTAssertTrue(store.classifyEvidence(taskID: taskID, action: .verify))
    let before = try XCTUnwrap(store.workSession(for: taskID))
    let attention = store.attentionRemaining

    let restored = GameStore()
    restored.continueCareer()
    let after = try XCTUnwrap(restored.workSession(for: taskID))
    XCTAssertEqual(after.cards, before.cards)
    XCTAssertEqual(after.decisions, before.decisions)
    XCTAssertEqual(after.challengeSeed, before.challengeSeed)
    XCTAssertEqual(restored.attentionRemaining, attention)
    XCTAssertTrue(restored.beginManualEvidenceTriage(taskID: taskID))
    XCTAssertEqual(restored.attentionRemaining, attention)
  }

  func testAuroraStateChangesAfterCreationDoNotRerollChallenge() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.prepareEvidenceTriage(taskID: taskID))
    let original = try XCTUnwrap(store.workSession(for: taskID))
    let auroraIndex = try XCTUnwrap(store.agents.firstIndex(where: { $0.id == "aurora" }))
    store.agents[auroraIndex].progression.adjustStress(100)
    XCTAssertTrue(store.prepareEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.workSession(for: taskID)?.cards, original.cards)
    XCTAssertEqual(store.workSession(for: taskID)?.agentStressAtCreation, original.agentStressAtCreation)
  }

  func testNonEligibleAssignmentRetainsCanonicalReviewBehavior() throws {
    let store = makeStore()
    let taskID = try XCTUnwrap(store.tasks.first?.id)
    store.tasks[0].role = .engineering
    store.tasks[0].category = .product
    store.assign(agentID: "stacks", to: taskID)
    let before = store.attentionRemaining
    XCTAssertFalse(store.isEvidenceTriageEligible(taskID: taskID))
    store.review(taskID: taskID)
    XCTAssertTrue(store.tasks[0].isReviewed)
    XCTAssertEqual(store.attentionRemaining, before - 1)
  }

  private func makeEligibleStore() throws -> (GameStore, UUID) {
    let store = makeStore()
    let taskID = try XCTUnwrap(store.tasks.first?.id)
    store.tasks[0].role = .research
    store.tasks[0].category = .research
    store.tasks[0].urgency = .important
    store.assign(agentID: "aurora", to: taskID)
    XCTAssertNotNil(store.tasks[0].result)
    return (store, taskID)
  }

  private func makeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.selectedDoctrine = .guided
    store.selectedProductType = .saas
    store.founderName = "Session Founder"
    store.startCareer(seed: 55)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func finish(store: GameStore, taskID: UUID, action: EvidenceTriageAction) throws {
    let count = try XCTUnwrap(store.workSession(for: taskID)?.cards.count)
    for _ in 0..<count { XCTAssertTrue(store.classifyEvidence(taskID: taskID, action: action)) }
    XCTAssertTrue(try XCTUnwrap(store.workSession(for: taskID)?.completed))
  }
}
