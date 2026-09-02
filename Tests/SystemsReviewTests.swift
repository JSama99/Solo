import XCTest
@testable import Solo_Unicorn_Run

final class SystemsReviewEngineTests: XCTestCase {
  private let assignmentID = UUID(uuidString: "51595354-454D-5352-4556-494557000001")!

  func testEngineDistinguishesAuroraAndStacksFamilies() {
    var aurora = task(title: "Validate retention", role: .research, urgency: .important)
    var stacks = task(title: "Deploy backend", role: .engineering, urgency: .important)
    aurora.result = result(actual: 80)
    stacks.result = result(actual: 80)
    XCTAssertEqual(WorkSessionEngine.family(for: aurora, agentID: "aurora"), .evidenceTriage)
    XCTAssertEqual(WorkSessionEngine.family(for: stacks, agentID: "stacks"), .systemsReview)
    XCTAssertNil(WorkSessionEngine.family(for: stacks, agentID: "aurora"))
  }

  func testStacksPotentialExistsBeforeFounderReviewAndRemainsSeparate() throws {
    var record = makeRecord(potential: 87, topic: .backend)
    XCTAssertEqual(record.agentPotentialQuality, 87)
    XCTAssertNil(record.founderReviewQuality)
    XCTAssertNil(record.deliveredQuality)
    record.path = .manualReview
    try select(sequence: ["schema", "logic", "contract", "client", "integration-test", "release"], in: &record)
    XCTAssertTrue(WorkSessionEngine.completeSystemsReview(&record))
    XCTAssertEqual(record.agentPotentialQuality, 87)
    XCTAssertEqual(record.founderReviewQuality, 100)
    XCTAssertEqual(record.deliveredQuality, 87)
  }

  func testDependencyEvaluationSupportsPartialCredit() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, topic: .backend).systemsChallenge)
    let perfect = try XCTUnwrap(SystemsReviewEvaluator.evaluate(
      challenge: challenge,
      sequence: ["schema", "logic", "contract", "client", "integration-test", "release"]
    ))
    let partial = try XCTUnwrap(SystemsReviewEvaluator.evaluate(
      challenge: challenge,
      sequence: ["logic", "schema", "contract", "client", "release", "integration-test"]
    ))
    XCTAssertEqual(perfect.reviewQuality, 100)
    XCTAssertGreaterThan(partial.reviewQuality, 0)
    XCTAssertLessThan(partial.reviewQuality, perfect.reviewQuality)
    XCTAssertEqual(partial.satisfiedDependencies, perfect.dependencyCount - 1)
  }

  func testVerificationAndUnsafeReleaseProduceCanonicalFindings() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, topic: .backend).systemsChallenge)
    let assessment = try XCTUnwrap(SystemsReviewEvaluator.evaluate(
      challenge: challenge,
      sequence: ["release", "logic", "schema", "contract", "client", "integration-test"]
    ))
    XCTAssertTrue(assessment.findings.contains(.unsafeRelease))
    XCTAssertTrue(assessment.findings.contains(.skippedVerification))
    XCTAssertTrue(assessment.findings.contains(.dependencyViolation))
    XCTAssertTrue(assessment.findings.allSatisfy { WorkSessionFinding.allCases.contains($0) })
  }

  func testCorrectHandlingProducesPositiveFindings() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, topic: .backend).systemsChallenge)
    let assessment = try XCTUnwrap(SystemsReviewEvaluator.evaluate(
      challenge: challenge,
      sequence: ["schema", "logic", "contract", "client", "integration-test", "release"]
    ))
    XCTAssertTrue(assessment.findings.contains(.correctlyPreservedDependency))
    XCTAssertTrue(assessment.findings.contains(.correctlyRequiredVerification))
    XCTAssertTrue(assessment.findings.contains(.correctlyIdentifiedReleaseGate))
    XCTAssertTrue(assessment.findings.allSatisfy { $0.polarity == .positive })
  }

  func testPostReleaseMonitoringIsNotMisclassifiedAsSkippedVerification() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, topic: .data).systemsChallenge)
    let assessment = try XCTUnwrap(SystemsReviewEvaluator.evaluate(
      challenge: challenge,
      sequence: ["backup", "prepare", "migrate", "validate", "switch", "monitor"]
    ))
    XCTAssertEqual(assessment.reviewQuality, 100)
    XCTAssertFalse(assessment.findings.contains(.skippedVerification))
    XCTAssertFalse(assessment.findings.contains(.unsafeRelease))
  }

  func testChallengeGenerationIsTaskAwareDeterministicAndHasGeneralFallback() throws {
    let backendA = makeRecord(potential: 80, topic: .backend)
    let backendB = makeRecord(potential: 80, topic: .backend)
    let deployment = makeRecord(potential: 80, topic: .deployment)
    let fallback = makeRecord(potential: 80, topic: nil)
    XCTAssertEqual(backendA.challengeSeed, backendB.challengeSeed)
    XCTAssertEqual(backendA.systemsChallenge, backendB.systemsChallenge)
    XCTAssertEqual(backendA.systemsChallenge?.topic, .backend)
    XCTAssertEqual(deployment.systemsChallenge?.topic, .deployment)
    XCTAssertEqual(fallback.systemsChallenge?.topic, .general)
    XCTAssertEqual(backendA.family, .systemsReview)
  }

  func testTaskTopicInferenceMapsKnownDomainsAndLeavesUntaggedSafe() {
    XCTAssertEqual(task(title: "Deploy production release", role: .engineering).resolvedTechnicalTopic, .deployment)
    XCTAssertEqual(task(title: "Migrate customer database", role: .engineering).resolvedTechnicalTopic, .data)
    XCTAssertEqual(task(title: "Connect external API", role: .engineering).resolvedTechnicalTopic, .integration)
    XCTAssertNil(task(title: "Build MVP", role: .engineering).resolvedTechnicalTopic)
  }

  func testPresentationAndVoiceOverDoNotExposeCorrectness() throws {
    let record = makeRecord(potential: 80, topic: .backend)
    let challenge = try XCTUnwrap(record.systemsChallenge)
    let presentation = try XCTUnwrap(challenge.presentations(selection: []).first)
    let fields = Set(Mirror(reflecting: presentation).children.compactMap(\.label))
    for hidden in ["prerequisites", "constraintKind", "weight", "correctOrder", "agentPotentialQuality"] {
      XCTAssertFalse(fields.contains(hidden))
      XCTAssertFalse(presentation.accessibilityLabel.lowercased().contains(hidden.lowercased()))
    }
    for protected in ["correct", "unsafe", "prerequisite", "expected", "score", "hidden"] {
      XCTAssertFalse(presentation.accessibilityLabel.lowercased().contains(protected))
    }
  }

  func testSelectionPersistsPlayerOrderAndRejectsDuplicates() throws {
    var record = makeRecord(potential: 80, topic: .backend)
    record.path = .manualReview
    XCTAssertTrue(WorkSessionEngine.selectSystemStep("schema", in: &record))
    XCTAssertTrue(WorkSessionEngine.selectSystemStep("logic", in: &record))
    XCTAssertFalse(WorkSessionEngine.selectSystemStep("schema", in: &record))
    XCTAssertEqual(record.systemsSequence, ["schema", "logic"])
    XCTAssertTrue(WorkSessionEngine.removeSystemStep("schema", in: &record))
    XCTAssertEqual(record.systemsSequence, ["logic"])
    XCTAssertTrue(WorkSessionEngine.resetSystemsSequence(&record))
    XCTAssertTrue(record.systemsSequence.isEmpty)
  }

  func testDuplicateSubmissionAndReplayAreBlocked() throws {
    var record = makeRecord(potential: 83, topic: .backend)
    record.path = .manualReview
    try select(sequence: ["schema", "logic", "contract", "client", "integration-test", "release"], in: &record)
    XCTAssertTrue(WorkSessionEngine.completeSystemsReview(&record))
    let quality = record.deliveredQuality
    XCTAssertFalse(WorkSessionEngine.completeSystemsReview(&record))
    XCTAssertFalse(WorkSessionEngine.removeSystemStep("release", in: &record))
    XCTAssertEqual(record.deliveredQuality, quality)
  }

  func testPoorReviewReducesDeliveryAndCannotUpgradeWeakStacksWork() throws {
    var strong = makeRecord(potential: 92, topic: .backend)
    strong.path = .manualReview
    try select(sequence: ["release", "integration-test", "client", "contract", "logic", "schema"], in: &strong)
    XCTAssertTrue(WorkSessionEngine.completeSystemsReview(&strong))
    XCTAssertLessThan(try XCTUnwrap(strong.deliveredQuality), 92)
    XCTAssertEqual(strong.agentPotentialQuality, 92)

    var weak = makeRecord(potential: 44, topic: .backend)
    weak.path = .manualReview
    try select(sequence: ["schema", "logic", "contract", "client", "integration-test", "release"], in: &weak)
    XCTAssertTrue(WorkSessionEngine.completeSystemsReview(&weak))
    XCTAssertEqual(weak.founderReviewQuality, 100)
    XCTAssertEqual(weak.deliveredQuality, 44)
  }

  func testHindsightDistinguishesStacksAndFounderFailure() {
    var founderFailure = makeRecord(potential: 92, topic: .deployment)
    founderFailure.path = .manualReview
    founderFailure.founderReviewQuality = 45
    founderFailure.deliveredQuality = 55
    XCTAssertEqual(founderFailure.causalAttribution, .founderReview)
    XCTAssertTrue(founderFailure.hindsightExplanations.contains { $0.contains("Stacks") && $0.contains("Founder Review") })

    var stacksFailure = makeRecord(potential: 48, topic: .deployment)
    stacksFailure.path = .manualReview
    stacksFailure.founderReviewQuality = 100
    stacksFailure.deliveredQuality = 48
    XCTAssertEqual(stacksFailure.causalAttribution, .agentOutput)
    XCTAssertTrue(stacksFailure.hindsightExplanations.contains { $0.contains("Stacks") && $0.contains("underlying output") })
  }

  func testSaveRoundTripPreservesExactChallengeSequenceAndOutcome() throws {
    var record = makeRecord(potential: 79, topic: .data)
    record.path = .manualReview
    XCTAssertTrue(WorkSessionEngine.selectSystemStep("backup", in: &record))
    XCTAssertTrue(WorkSessionEngine.selectSystemStep("prepare", in: &record))
    let decoded = try JSONDecoder().decode(WorkSessionRecord.self, from: JSONEncoder().encode(record))
    XCTAssertEqual(decoded, record)
    XCTAssertEqual(decoded.systemsChallenge, record.systemsChallenge)
    XCTAssertEqual(decoded.systemsSequence, ["backup", "prepare"])
  }

  func testAccessibilityAndMotionSettingsCannotAffectAchievableQuality() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 80, topic: .backend).systemsChallenge)
    let sequence = ["schema", "logic", "contract", "client", "integration-test", "release"]
    let standard = SystemsReviewEvaluator.evaluate(challenge: challenge, sequence: sequence)
    let reduceMotionAndVoiceOver = SystemsReviewEvaluator.evaluate(challenge: challenge, sequence: sequence)
    XCTAssertEqual(standard, reduceMotionAndVoiceOver)
    XCTAssertEqual(standard?.reviewQuality, 100)
  }

  private func makeRecord(potential: Int, topic: TechnicalTopic?) -> WorkSessionRecord {
    WorkSessionEngine.makeSystemsReviewRecord(
      assignmentID: assignmentID,
      agentID: "stacks",
      urgency: .important,
      potentialQuality: potential,
      careerSeed: 88,
      venture: 2,
      sprint: 3,
      stress: .stable,
      attentionCost: 3,
      technicalTopic: topic
    )
  }

  private func select(sequence: [String], in record: inout WorkSessionRecord) throws {
    for id in sequence { XCTAssertTrue(WorkSessionEngine.selectSystemStep(id, in: &record), id) }
  }

  private func task(title: String, role: AgentRole, urgency: TaskUrgency = .normal) -> SoloTask {
    SoloTask(title: title, detail: "Operational implementation plan", role: role, urgency: urgency, impact: .momentum(4))
  }

  private func result(actual: Int) -> TaskResult {
    TaskResult(
      actualQuality: actual,
      reportedQuality: actual,
      evidenceCompleteness: 80,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(momentum: actual),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: actual - 5,
      confidenceUpperBound: actual + 5,
      knownOperationalRisk: "Normal operational variance"
    )
  }
}

@MainActor
final class SystemsReviewStoreTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  func testEligibleStacksAssignmentEntersSystemsReviewAndAuroraStillUsesTriage() throws {
    let (stacksStore, stacksID) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Deploy backend service")
    XCTAssertTrue(stacksStore.isSystemsReviewEligible(taskID: stacksID))
    XCTAssertTrue(stacksStore.prepareWorkSession(taskID: stacksID))
    XCTAssertEqual(stacksStore.workSession(for: stacksID)?.family, .systemsReview)

    let (auroraStore, auroraID) = try makeEligibleStore(agentID: "aurora", role: .research, title: "Validate retention evidence")
    XCTAssertTrue(auroraStore.isEvidenceTriageEligible(taskID: auroraID))
    XCTAssertTrue(auroraStore.prepareWorkSession(taskID: auroraID))
    XCTAssertEqual(auroraStore.workSession(for: auroraID)?.family, .evidenceTriage)
  }

  func testManualReviewChargesAttentionOnceAcrossReopening() throws {
    let (store, id) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Deploy backend service")
    XCTAssertTrue(store.prepareSystemsReview(taskID: id))
    let before = store.attentionRemaining
    let cost = try XCTUnwrap(store.workSession(for: id)?.founderAttentionCost)
    XCTAssertTrue(store.beginManualSystemsReview(taskID: id))
    XCTAssertEqual(store.attentionRemaining, before - cost)
    XCTAssertTrue(store.beginManualSystemsReview(taskID: id))
    XCTAssertTrue(store.prepareSystemsReview(taskID: id))
    XCTAssertEqual(store.attentionRemaining, before - cost)
  }

  func testInterruptedSaveRestoresChallengeOrderAndPlayerSequence() throws {
    let (store, id) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Migrate customer database")
    XCTAssertTrue(store.beginManualSystemsReview(taskID: id))
    let firstStep = try XCTUnwrap(store.workSession(for: id)?.systemsChallenge?.steps.first?.id)
    XCTAssertTrue(store.selectSystemsReviewStep(taskID: id, stepID: firstStep))
    let before = try XCTUnwrap(store.workSession(for: id))
    let attention = store.attentionRemaining

    let restored = GameStore()
    restored.continueCareer()
    let after = try XCTUnwrap(restored.workSession(for: id))
    XCTAssertEqual(after.challengeSeed, before.challengeSeed)
    XCTAssertEqual(after.systemsChallenge, before.systemsChallenge)
    XCTAssertEqual(after.systemsSequence, before.systemsSequence)
    XCTAssertEqual(restored.attentionRemaining, attention)
    XCTAssertTrue(restored.beginManualSystemsReview(taskID: id))
    XCTAssertEqual(restored.attentionRemaining, attention)
  }

  func testCompletionAppliesOnceAndPreservesAgentEvaluation() throws {
    let (store, id) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Build backend service")
    XCTAssertTrue(store.beginManualSystemsReview(taskID: id))
    try submitPerfect(store: store, taskID: id)
    let session = try XCTUnwrap(store.workSession(for: id))
    let result = try XCTUnwrap(store.tasks.first(where: { $0.id == id })?.result)
    XCTAssertEqual(result.workSessionPotentialQuality, session.agentPotentialQuality)
    XCTAssertEqual(result.founderReviewQualityForSimulation, 100)
    XCTAssertEqual(result.deliveredQualityForSimulation, session.agentPotentialQuality)
    XCTAssertEqual(result.isStrongForSimulation, session.agentPotentialQuality >= 68)
    XCTAssertFalse(store.submitSystemsReview(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.deliveredQuality, session.deliveredQuality)
  }

  /// P0 audit (Task 1): delegation now costs `delegateAttentionCost` instead
  /// of being free, charged exactly once even across a rejected replay.
  func testDelegateIsDeterministicCostsOneAttentionAndCannotReplay() throws {
    let (store, id) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Deploy production release")
    let before = store.attentionRemaining
    XCTAssertTrue(store.delegateSystemsReview(taskID: id))
    let delivered = try XCTUnwrap(store.workSession(for: id)?.deliveredQuality)
    XCTAssertEqual(store.attentionRemaining, before - store.delegateAttentionCost)
    XCTAssertFalse(store.delegateSystemsReview(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.deliveredQuality, delivered)
    XCTAssertEqual(store.attentionRemaining, before - store.delegateAttentionCost,
                   "A rejected replay must not charge Attention twice")
  }

  func testCompletedReviewFeedsCanonicalEvidenceAndCausalHindsight() throws {
    let (store, id) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Build backend service")
    XCTAssertTrue(store.beginManualSystemsReview(taskID: id))
    let reverse = try XCTUnwrap(store.workSession(for: id)?.systemsChallenge?.steps.map(\.id).reversed())
    for stepID in reverse { XCTAssertTrue(store.selectSystemsReviewStep(taskID: id, stepID: stepID)) }
    XCTAssertTrue(store.submitSystemsReview(taskID: id))
    let session = try XCTUnwrap(store.workSession(for: id))
    XCTAssertFalse(session.negativeFindings.isEmpty)
    store.review(taskID: id)
    let evidence = try XCTUnwrap(store.evidence.first(where: { $0.taskInstanceID == id.uuidString }))
    XCTAssertEqual(evidence.workSessionAgentQuality, session.agentPotentialQuality)
    XCTAssertEqual(evidence.workSessionFounderReviewQuality, session.founderReviewQuality)
    XCTAssertEqual(evidence.workSessionDeliveredQuality, session.deliveredQuality)
    XCTAssertEqual(evidence.workSessionFindings, session.findings)
    XCTAssertEqual(evidence.workSessionCausalAttribution, session.causalAttribution)
    XCTAssertTrue(evidence.hindsightNotes.contains { $0.contains("Stacks") })
  }

  func testReopeningCannotRerollAfterStacksStateChanges() throws {
    let (store, id) = try makeEligibleStore(agentID: "stacks", role: .engineering, title: "Deploy production release")
    XCTAssertTrue(store.prepareSystemsReview(taskID: id))
    let before = try XCTUnwrap(store.workSession(for: id))
    let index = try XCTUnwrap(store.agents.firstIndex(where: { $0.id == "stacks" }))
    store.agents[index].progression.adjustStress(100)
    XCTAssertTrue(store.prepareSystemsReview(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.challengeSeed, before.challengeSeed)
    XCTAssertEqual(store.workSession(for: id)?.systemsChallenge, before.systemsChallenge)
    XCTAssertEqual(store.workSession(for: id)?.agentStressAtCreation, before.agentStressAtCreation)
  }

  private func makeEligibleStore(agentID: String, role: AgentRole, title: String) throws -> (GameStore, UUID) {
    let store = GameStore()
    store.resetCareer()
    store.selectedDoctrine = .guided
    store.selectedProductType = .saas
    store.founderName = "Systems Founder"
    store.startCareer(seed: 9_991)
    store.confirmVentureThesisIfNeeded()
    let id = try XCTUnwrap(store.tasks.first?.id)
    store.tasks[0].title = title
    store.tasks[0].detail = "Review the implementation and release path."
    store.tasks[0].role = role
    store.tasks[0].category = role == .engineering ? .product : .research
    store.tasks[0].urgency = .important
    store.assign(agentID: agentID, to: id)
    XCTAssertNotNil(store.tasks[0].result)
    return (store, id)
  }

  private func submitPerfect(store: GameStore, taskID: UUID) throws {
    let challenge = try XCTUnwrap(store.workSession(for: taskID)?.systemsChallenge)
    let order: [String]
    switch challenge.id {
    case "backend-feature": order = ["schema", "logic", "contract", "client", "integration-test", "release"]
    case "data-migration": order = ["backup", "prepare", "migrate", "validate", "switch", "monitor"]
    case "external-integration": order = ["api-contract", "credentials", "adapter", "sandbox", "production", "errors"]
    case "controlled-deployment": order = ["build", "tests", "stage", "health", "production", "monitor"]
    case "reliability-fix": order = ["failure", "guardrail", "failure-test", "deploy", "rate"]
    case "client-feature": order = ["contract", "client", "accessibility", "regression", "flag", "monitor"]
    default: order = ["scope", "implement", "test", "stage", "release", "monitor"]
    }
    for stepID in order { XCTAssertTrue(store.selectSystemsReviewStep(taskID: taskID, stepID: stepID)) }
    XCTAssertTrue(store.submitSystemsReview(taskID: taskID))
  }
}
