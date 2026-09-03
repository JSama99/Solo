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
    XCTAssertTrue(record.negativeFindings.isEmpty)
    XCTAssertFalse(record.positiveFindings.isEmpty)
    XCTAssertTrue(record.positiveFindings.allSatisfy { $0.polarity == .positive })
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

  func testUntaggedChallengeUsesOriginalGeneralPool() {
    let record = makeRecord(potential: 80)
    let taggedExpansion = Set(["pricing-panel", "discount-conversion", "margin-thread"])
    XCTAssertTrue(Set(record.cards.map(\.id)).isDisjoint(with: taggedExpansion))
    XCTAssertNil(record.evidenceTopic)
  }

  func testTaggedChallengeIsDeterministicAndPrefersMatchingEvidence() {
    let first = makeRecord(potential: 80, topic: .retention)
    let second = makeRecord(potential: 80, topic: .retention)
    XCTAssertEqual(first.challengeSeed, second.challengeSeed)
    XCTAssertEqual(first.cards, second.cards)
    XCTAssertEqual(first.evidenceTopic, .retention)
    XCTAssertGreaterThanOrEqual(first.cards.filter { $0.supports(.retention) }.count, 3)
  }

  func testExplicitAndInferredTaskTopicsUseSafeFallbacks() {
    let explicit = SoloTask(title: "Review evidence", detail: "General packet", role: .research, impact: .trust(3), evidenceTopic: .pricing)
    let inferred = SoloTask(title: "Validate retention cohorts", detail: "Review churn and renewal behavior", role: .research, impact: .trust(3))
    let untagged = SoloTask(title: "Review evidence", detail: "Assess the available packet", role: .research, impact: .trust(3))
    XCTAssertEqual(explicit.resolvedEvidenceTopic, .pricing)
    XCTAssertEqual(inferred.resolvedEvidenceTopic, .retention)
    XCTAssertNil(untagged.resolvedEvidenceTopic)
  }

  func testTaskResultPreservesAgentQualityAndStoresCausalOutcomeSeparately() {
    var result = makeTaskResult(actual: 92, immediateMomentum: 92)
    result.applyWorkSessionOutcome(deliveredQuality: 64, founderReviewQuality: 55)
    XCTAssertEqual(result.workSessionPotentialQuality, 92)
    XCTAssertEqual(result.founderReviewQualityForSimulation, 55)
    XCTAssertEqual(result.deliveredQualityForSimulation, 64)
    XCTAssertEqual(result.immediateEffects.momentum, 64, "Company payoff must route through delivered quality")
    XCTAssertTrue(result.isStrongForSimulation, "Agent evaluation must retain Aurora's original quality")
    XCTAssertFalse(result.isDeliveredStrongForSimulation)
    _ = result.verify()
    XCTAssertEqual(result.revealedActualQuality, 92, "Earned reveal must report Aurora's original truth, not delivered quality")
  }

  func testPerfectReviewCannotRaiseWeakAgentOutput() {
    XCTAssertEqual(
      WorkSessionEngine.deliveredQuality(potential: 48, reviewQuality: 100, path: .manualReview, seed: 3),
      48
    )
  }

  func testCausalAttributionDistinguishesFounderAndAgentFailure() {
    var founderFailure = makeRecord(potential: 92)
    founderFailure.path = .manualReview
    founderFailure.founderReviewQuality = 55
    founderFailure.deliveredQuality = 64
    XCTAssertEqual(founderFailure.causalAttribution, .founderReview)

    var agentFailure = makeRecord(potential: 48)
    agentFailure.path = .manualReview
    agentFailure.founderReviewQuality = 100
    agentFailure.deliveredQuality = 48
    XCTAssertEqual(agentFailure.causalAttribution, .agentOutput)
    XCTAssertTrue(agentFailure.hindsightExplanations.contains { $0.contains("underlying output limited") })
  }

  func testVisibleCardAndVoiceOverMetadataDoNotLeakCorrectness() throws {
    let card = try XCTUnwrap(makeRecord(potential: 80).nextCardPresentation)
    let fieldNames = Set(Mirror(reflecting: card).children.compactMap(\.label))
    XCTAssertFalse(fieldNames.contains("idealAction"))
    XCTAssertFalse(fieldNames.contains("weight"))
    XCTAssertFalse(fieldNames.contains("agentPotentialQuality"))
    XCTAssertFalse(fieldNames.contains("founderReviewQuality"))
    XCTAssertFalse(fieldNames.contains("deliveredQuality"))
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

  /// P0 audit (Task 3): the new no-immediate-repeat window must default
  /// safely on saves written before it existed, with nothing else disturbed.
  func testLegacyCareerSaveWithoutVentureObjectiveWindowDecodes() throws {
    let save = CareerSave(founderName: "Legacy", doctrine: .guided, sprint: 4, venture: 2, intent: .learn, stats: FounderStats(), agents: ContentLibrary.initialAgents, tasks: [], evidence: [], outcome: nil, randomNumberGenerator: SeededRandomNumberGenerator(seed: 1), correlatedFailureEvent: nil, pendingEffects: [])
    let encoded = try JSONEncoder().encode(save)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    json.removeValue(forKey: "recentVentureObjectiveIDs")
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(CareerSave.self, from: legacyData)
    XCTAssertEqual(decoded.recentVentureObjectiveIDs, [], "Absent window defaults to empty")
    XCTAssertEqual(decoded.venture, 2, "Zero data loss elsewhere")
    XCTAssertEqual(decoded.sprint, 4)
    XCTAssertEqual(decoded.founderName, "Legacy")
  }

  /// A populated window survives a round trip.
  func testVentureObjectiveWindowRoundTripsThroughASave() throws {
    var save = CareerSave(founderName: "Round", doctrine: .guided, sprint: 1, venture: 3, intent: .learn, stats: FounderStats(), agents: ContentLibrary.initialAgents, tasks: [], evidence: [], outcome: nil, randomNumberGenerator: SeededRandomNumberGenerator(seed: 1), correlatedFailureEvent: nil, pendingEffects: [])
    save.recentVentureObjectiveIDs = ["pmf", "proof"]
    let decoded = try JSONDecoder().decode(CareerSave.self, from: try JSONEncoder().encode(save))
    XCTAssertEqual(decoded.recentVentureObjectiveIDs, ["pmf", "proof"])
  }

  func testLegacyWorkSessionMistakesDecodeAsTypedFindings() throws {
    var record = makeRecord(potential: 80)
    record.findings = [.acceptedWeakEvidence, .correctlyDetectedContradiction]
    let encoded = try JSONEncoder().encode(record)
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    json["mistakes"] = json.removeValue(forKey: "findings")
    json.removeValue(forKey: "evidenceTopic")
    let decoded = try JSONDecoder().decode(
      WorkSessionRecord.self,
      from: JSONSerialization.data(withJSONObject: json)
    )
    XCTAssertEqual(decoded.findings, record.findings)
    XCTAssertEqual(decoded.negativeFindings, [.acceptedWeakEvidence])
    XCTAssertEqual(decoded.positiveFindings, [.correctlyDetectedContradiction])
  }

  func testLegacyCausalRepairRestoresAgentTruthWithoutDoubleScalingCompanyEffects() {
    var legacyResult = makeTaskResult(actual: 64, immediateMomentum: 64)
    legacyResult.restoreLegacyWorkSessionOutcome(
      agentPotentialQuality: 92,
      founderReviewQuality: 55,
      deliveredQuality: 64
    )
    XCTAssertEqual(legacyResult.workSessionPotentialQuality, 92)
    XCTAssertEqual(legacyResult.founderReviewQualityForSimulation, 55)
    XCTAssertEqual(legacyResult.deliveredQualityForSimulation, 64)
    XCTAssertEqual(legacyResult.immediateEffects.momentum, 64)
  }

  private func makeRecord(potential: Int, topic: EvidenceTopic? = nil) -> WorkSessionRecord {
    WorkSessionEngine.makeRecord(assignmentID: assignmentID, agentID: "aurora", urgency: .normal, potentialQuality: potential, careerSeed: 10, venture: 1, sprint: 1, stress: .stable, attentionCost: 3, evidenceTopic: topic)
  }

  private func makeTaskResult(actual: Int, immediateMomentum: Int) -> TaskResult {
    TaskResult(
      actualQuality: actual,
      reportedQuality: actual,
      evidenceCompleteness: 80,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(momentum: immediateMomentum),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: actual - 5,
      confidenceUpperBound: actual + 5,
      knownOperationalRisk: "Normal operational variance"
    )
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

  func testPoorManualReviewPersistsTypedFindingsAndCausalHindsight() throws {
    let (store, taskID) = try makeEligibleStore()
    let potential = try XCTUnwrap(store.tasks.first(where: { $0.id == taskID })?.result?.workSessionPotentialQuality)
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    try finish(store: store, taskID: taskID, action: .use)
    let session = try XCTUnwrap(store.workSession(for: taskID))
    XCTAssertLessThanOrEqual(try XCTUnwrap(session.deliveredQuality), potential)
    let canonicalResult = try XCTUnwrap(store.tasks.first(where: { $0.id == taskID })?.result)
    XCTAssertEqual(canonicalResult.workSessionPotentialQuality, potential)
    XCTAssertEqual(canonicalResult.founderReviewQualityForSimulation, session.founderReviewQuality)
    XCTAssertEqual(canonicalResult.deliveredQualityForSimulation, session.deliveredQuality)
    XCTAssertFalse(session.negativeFindings.isEmpty)
    store.review(taskID: taskID)
    let evidence = try XCTUnwrap(store.evidence.first(where: { $0.taskInstanceID == taskID.uuidString }))
    XCTAssertEqual(evidence.workSessionFindings, session.findings)
    XCTAssertEqual(evidence.workSessionAgentQuality, session.agentPotentialQuality)
    XCTAssertEqual(evidence.workSessionFounderReviewQuality, session.founderReviewQuality)
    XCTAssertEqual(evidence.workSessionDeliveredQuality, session.deliveredQuality)
    XCTAssertEqual(evidence.workSessionCausalAttribution, session.causalAttribution)
    XCTAssertEqual(evidence.hindsightNotes, session.hindsightExplanations)
    XCTAssertFalse(evidence.hindsightNotes.isEmpty)
  }

  /// Rewritten for the P0 audit (Task 1). Delegation used to be free, which
  /// made it strictly dominant: full `isReviewed` credit at zero Attention.
  /// It now costs `delegateAttentionCost`, charged exactly once.
  func testDelegateCostsOneAttentionAndIsIdempotent() throws {
    let (store, taskID) = try makeEligibleStore()
    let before = store.attentionRemaining
    XCTAssertTrue(store.delegateEvidenceTriage(taskID: taskID))
    let first = try XCTUnwrap(store.workSession(for: taskID)?.deliveredQuality)
    XCTAssertEqual(store.attentionRemaining, before - store.delegateAttentionCost)
    // Re-delegating is rejected and must not double-charge.
    XCTAssertFalse(store.delegateEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.workSession(for: taskID)?.deliveredQuality, first)
    XCTAssertEqual(store.attentionRemaining, before - store.delegateAttentionCost)
    XCTAssertEqual(store.workSession(for: taskID)?.founderAttentionCost, store.delegateAttentionCost)
  }

  /// Delegation is cheaper than manual review but no longer free.
  func testDelegateIsCheaperThanManualButNotFree() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertEqual(store.delegateAttentionCost, 1)
    XCTAssertEqual(store.workSessionAttentionCost, 2)
    XCTAssertGreaterThan(store.workSessionAttentionCost, store.delegateAttentionCost)
    XCTAssertGreaterThan(store.delegateAttentionCost, 0)
  }

  /// The regression this fix exists to prevent: the manual cost must stay a
  /// flat 2 even on a sprint where the Founder Command Desk raises
  /// `attentionMaximum`, leaving the bonus Attention actually spendable.
  /// Under the old `min(3, attentionMaximum)` this cost 3 and consumed the
  /// entire boosted budget.
  func testManualWorkSessionCostsFlatTwoEvenOnABoostedSprint() throws {
    let (store, taskID) = try makeEligibleStore()
    let suite = "WorkSessionAttentionTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let progression = FounderProgressionStore(defaults: defaults, saveKey: "progression")
    XCTAssertEqual(progression.currentFacility, .founderGarage)
    XCTAssertEqual(
      progression.purchaseUpgrade(.founderCommandDesk, availableCapital: 10_000),
      .purchased(cost: 1_800)
    )
    store.progressionStore = progression
    store.sprint = 3
    XCTAssertTrue(store.sprint.isMultiple(of: 3))
    XCTAssertEqual(progression.bonuses.periodicAttentionBonus, 1)
    XCTAssertEqual(store.attentionMaximum, 3, "Boosted sprint should grant the periodic bonus")
    XCTAssertEqual(store.workSessionAttentionCost, 2, "Manual cost must not scale with the boosted budget")

    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.founderAttentionSpent, 2)
    XCTAssertEqual(store.attentionRemaining, 1, "The bonus Attention must survive a manual session")
  }

  /// Delegation still clears the neglect penalty, but it is a lesser tier: it
  /// does not satisfy objectives written around real founder review.
  func testDelegatedVerificationIsADistinctLesserTier() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.delegateEvidenceTriage(taskID: taskID))
    store.review(taskID: taskID)
    XCTAssertTrue(store.tasks[0].isReviewed, "Delegation still clears the neglect penalty")
    XCTAssertTrue(store.isDelegatedVerification(taskID: taskID))
    XCTAssertFalse(store.isFounderVerified(taskID: taskID), "Delegated work is not founder-verified")
  }

  /// Delegated evidence must not earn the career-score quality bonus that
  /// founder review does, even though both leave the task `isReviewed`.
  func testDelegatedEvidenceDoesNotEarnTheCareerScoreQualityBonus() throws {
    let (delegatedStore, delegatedID) = try makeEligibleStore()
    XCTAssertTrue(delegatedStore.delegateEvidenceTriage(taskID: delegatedID))
    delegatedStore.review(taskID: delegatedID)
    let delegatedEvidence = try XCTUnwrap(
      delegatedStore.evidence.first(where: { $0.taskInstanceID == delegatedID.uuidString })
    )
    XCTAssertTrue(delegatedEvidence.evidenceVerified, "The underlying evidence is still verified")
    XCTAssertTrue(delegatedStore.isDelegatedVerification(taskInstanceID: delegatedID.uuidString),
                  "…but it is attributable to delegation, so it must not score as founder-verified")

    let (manualStore, manualID) = try makeEligibleStore()
    XCTAssertTrue(manualStore.beginManualEvidenceTriage(taskID: manualID))
    try finish(store: manualStore, taskID: manualID, action: .verify)
    manualStore.review(taskID: manualID)
    XCTAssertFalse(manualStore.isDelegatedVerification(taskInstanceID: manualID.uuidString))
  }

  func testManualReviewCountsAsFounderVerified() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    try finish(store: store, taskID: taskID, action: .verify)
    store.review(taskID: taskID)
    XCTAssertFalse(store.isDelegatedVerification(taskID: taskID))
    XCTAssertTrue(store.isFounderVerified(taskID: taskID))
  }

  /// Under every doctrine, delegating every eligible task can no longer end
  /// the sprint fully verified at zero cost.
  func testDelegatingEveryEligibleTaskIsNoLongerFreeUnderAnyDoctrine() throws {
    for doctrine in FounderDoctrine.allCases {
      let store = GameStore()
      store.resetCareer()
      store.selectedDoctrine = doctrine
      store.selectedProductType = .saas
      store.founderName = "Doctrine \(doctrine.rawValue)"
      store.startCareer(seed: 55)
      store.confirmVentureThesisIfNeeded()
      XCTAssertEqual(store.attentionMaximum, 2, "All doctrines now share a 2-Attention baseline")

      var delegated = 0
      for index in store.tasks.indices {
        store.tasks[index].role = .research
        store.tasks[index].category = .research
        store.tasks[index].urgency = .important
        let id = store.tasks[index].id
        store.assign(agentID: "aurora", to: id)
        guard store.isEvidenceTriageEligible(taskID: id) else { continue }
        if store.delegateEvidenceTriage(taskID: id) { delegated += 1 }
      }
      XCTAssertGreaterThan(delegated, 0, "\(doctrine) should have at least one eligible task")
      XCTAssertEqual(store.founderAttentionSpent, delegated * store.delegateAttentionCost,
                     "\(doctrine): delegation must cost real Attention")
      XCTAssertLessThanOrEqual(delegated, store.attentionMaximum,
                               "\(doctrine): the budget must cap how many tasks can be delegated")
    }
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

  func testCompletedSessionRestoresAllCausalQualityAndFindings() throws {
    let (store, taskID) = try makeEligibleStore()
    XCTAssertTrue(store.beginManualEvidenceTriage(taskID: taskID))
    try finish(store: store, taskID: taskID, action: .reject)
    let before = try XCTUnwrap(store.workSession(for: taskID))
    let beforeResult = try XCTUnwrap(store.tasks.first(where: { $0.id == taskID })?.result)

    let restored = GameStore()
    restored.continueCareer()
    let after = try XCTUnwrap(restored.workSession(for: taskID))
    let afterResult = try XCTUnwrap(restored.tasks.first(where: { $0.id == taskID })?.result)
    XCTAssertEqual(after.agentPotentialQuality, before.agentPotentialQuality)
    XCTAssertEqual(after.founderReviewQuality, before.founderReviewQuality)
    XCTAssertEqual(after.deliveredQuality, before.deliveredQuality)
    XCTAssertEqual(after.findings, before.findings)
    XCTAssertEqual(afterResult.workSessionPotentialQuality, beforeResult.workSessionPotentialQuality)
    XCTAssertEqual(afterResult.founderReviewQualityForSimulation, beforeResult.founderReviewQualityForSimulation)
    XCTAssertEqual(afterResult.deliveredQualityForSimulation, beforeResult.deliveredQualityForSimulation)
  }

  func testTaggedSessionReopeningCannotRerollEvidence() throws {
    let (store, taskID) = try makeEligibleStore()
    let taskIndex = try XCTUnwrap(store.tasks.firstIndex(where: { $0.id == taskID }))
    store.tasks[taskIndex].evidenceTopic = .pricing
    XCTAssertTrue(store.prepareEvidenceTriage(taskID: taskID))
    let original = try XCTUnwrap(store.workSession(for: taskID))
    XCTAssertEqual(original.evidenceTopic, .pricing)
    XCTAssertGreaterThanOrEqual(original.cards.filter { $0.supports(.pricing) }.count, 3)
    XCTAssertTrue(store.prepareEvidenceTriage(taskID: taskID))
    XCTAssertEqual(store.workSession(for: taskID)?.challengeSeed, original.challengeSeed)
    XCTAssertEqual(store.workSession(for: taskID)?.cards, original.cards)
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
