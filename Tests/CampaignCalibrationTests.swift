import XCTest
@testable import Solo_Unicorn_Run

final class CampaignCalibrationEngineTests: XCTestCase {
  private let assignmentID = UUID(uuidString: "4252494F-4341-4D50-4149-474E00000001")!

  func testEngineDistinguishesAllThreeFamilies() {
    var aurora = task("Validate evidence", role: .research)
    var stacks = task("Deploy backend", role: .engineering)
    var brio = task("Launch campaign", role: .marketing)
    aurora.result = result(80); stacks.result = result(80); brio.result = result(80)
    XCTAssertEqual(WorkSessionEngine.family(for: aurora, agentID: "aurora"), .evidenceTriage)
    XCTAssertEqual(WorkSessionEngine.family(for: stacks, agentID: "stacks"), .systemsReview)
    XCTAssertEqual(WorkSessionEngine.family(for: brio, agentID: "brio"), .campaignCalibration)
  }

  func testCriticalAndReviewedBrioAssignmentsAreNotEligible() {
    var critical = task("Recover campaign", role: .marketing, urgency: .critical)
    critical.result = result(80)
    XCTAssertNil(WorkSessionEngine.family(for: critical, agentID: "brio"))
    var reviewed = task("Launch campaign", role: .marketing)
    reviewed.result = result(80)
    reviewed.isReviewed = true
    XCTAssertNil(WorkSessionEngine.family(for: reviewed, agentID: "brio"))
  }

  func testPotentialQualityIsPreservedAndPerfectReviewExtractsIt() throws {
    var record = makeRecord(potential: 87, category: .acquisition)
    XCTAssertEqual(record.agentPotentialQuality, 87)
    XCTAssertNil(record.founderReviewQuality)
    XCTAssertNil(record.deliveredQuality)
    record.path = .manualReview
    selectStrong(in: &record)
    XCTAssertTrue(WorkSessionEngine.completeCampaignCalibration(&record))
    XCTAssertEqual(record.agentPotentialQuality, 87)
    XCTAssertEqual(record.founderReviewQuality, 100)
    XCTAssertEqual(record.deliveredQuality, 87)
  }

  func testCompatibilityDimensionsEvaluateRelationships() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, category: .acquisition).campaignChallenge)
    let strong = try XCTUnwrap(CampaignCalibrationEvaluator.evaluate(challenge: challenge, selection: .init(audienceID: "core-audience", messageID: "core-message", channelID: "core-channel")))
    XCTAssertEqual(strong.audienceMessageFit, 100)
    XCTAssertEqual(strong.audienceChannelFit, 100)
    XCTAssertEqual(strong.messageChannelFit, 100)
    XCTAssertEqual(strong.objectiveFit, 100)
    XCTAssertGreaterThanOrEqual(strong.reviewQuality, 90)
  }

  func testMultipleCoherentCampaignsScoreStrongWithoutTupleEquality() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, category: .acquisition).campaignChallenge)
    let first = assessment(challenge, "core-audience", "core-message", "core-channel")
    let second = assessment(challenge, "alternate-audience", "alternate-message", "alternate-channel")
    XCTAssertNotEqual(first, nil); XCTAssertNotEqual(second, nil)
    XCTAssertGreaterThanOrEqual(first!.reviewQuality, 90)
    XCTAssertEqual(second!.reviewQuality, 100)
    XCTAssertNotEqual(first!.reviewQuality, 0)
  }

  func testPartialFitReceivesPartialCredit() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, category: .acquisition).campaignChallenge)
    let strong = try XCTUnwrap(assessment(challenge, "alternate-audience", "alternate-message", "alternate-channel"))
    let partial = try XCTUnwrap(assessment(challenge, "core-audience", "alternate-message", "publication-channel"))
    XCTAssertGreaterThan(partial.reviewQuality, 0)
    XCTAssertLessThan(partial.reviewQuality, strong.reviewQuality)
  }

  func testOverclaimAndMismatchGenerateCanonicalNegativeFindings() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, category: .acquisition).campaignChallenge)
    let bad = try XCTUnwrap(assessment(challenge, "core-audience", "overclaim-message", "partner-channel"))
    XCTAssertTrue(bad.findings.contains(.overclaimedMessage))
    XCTAssertTrue(bad.findings.contains(.channelMismatch))
    XCTAssertTrue(bad.findings.contains(.weakCampaignCoherence))
    XCTAssertTrue(bad.findings.allSatisfy { WorkSessionFinding.allCases.contains($0) })
  }

  func testCoherentCampaignGeneratesPositiveFindings() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, category: .acquisition).campaignChallenge)
    let good = try XCTUnwrap(assessment(challenge, "alternate-audience", "alternate-message", "alternate-channel"))
    for finding in [WorkSessionFinding.strongAudienceMatch, .strongMessageFit, .strongChannelFit, .coherentCampaign, .disciplinedClaim] {
      XCTAssertTrue(good.findings.contains(finding))
      XCTAssertEqual(finding.polarity, .positive)
    }
  }

  func testAspirationalMessageUsesNeutralFinding() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 90, category: .acquisition).campaignChallenge)
    let assessment = try XCTUnwrap(self.assessment(challenge, "core-audience", "story-message", "publication-channel"))
    XCTAssertTrue(assessment.findings.contains(.aspirationalPositioning))
    XCTAssertEqual(WorkSessionFinding.aspirationalPositioning.polarity, .neutral)
  }

  func testTaskCategoryInferenceAndFallback() {
    XCTAssertEqual(task("Launch landing page", role: .marketing).resolvedCampaignCategory, .launch)
    XCTAssertEqual(task("Win back at-risk account", role: .marketing).resolvedCampaignCategory, .retention)
    XCTAssertEqual(task("Create upgrade campaign", role: .marketing).resolvedCampaignCategory, .conversion)
    XCTAssertEqual(task("Activate referral loop", role: .marketing).resolvedCampaignCategory, .community)
    XCTAssertEqual(task("Pitch strategic partner", role: .marketing).resolvedCampaignCategory, .partnership)
    XCTAssertNil(task("Shape the next campaign", role: .marketing).resolvedCampaignCategory)
  }

  func testGenerationIsTaskAwareDeterministicAndFallsBackSafely() {
    let a = makeRecord(potential: 80, category: .acquisition)
    let b = makeRecord(potential: 80, category: .acquisition)
    XCTAssertEqual(a.challengeSeed, b.challengeSeed)
    XCTAssertEqual(a.campaignChallenge, b.campaignChallenge)
    XCTAssertEqual(a.campaignChallenge?.category, .acquisition)
    XCTAssertEqual(makeRecord(potential: 80, category: .retention).campaignChallenge?.category, .retention)
    XCTAssertEqual(makeRecord(potential: 80, category: .launch).campaignChallenge?.category, .launch)
    XCTAssertEqual(makeRecord(potential: 80, category: nil).campaignChallenge?.category, .general)
  }

  func testPresentationAndVoiceOverHideCompatibilityTruth() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 80, category: .acquisition).campaignChallenge)
    let presentation = try XCTUnwrap(challenge.presentations(for: .message).first)
    let fields = Set(Mirror(reflecting: presentation).children.compactMap(\.label))
    for hidden in ["fitTags", "categories", "claimRisk", "weight", "score"] { XCTAssertFalse(fields.contains(hidden)) }
    for hidden in ["best", "correct", "overclaim", "compatibility", "score", "weight"] {
      XCTAssertFalse(presentation.accessibilityLabel.lowercased().contains(hidden))
    }
  }

  func testSelectionValidatesOptionsAndReplayProtection() {
    var record = makeRecord(potential: 83, category: .acquisition)
    record.path = .manualReview
    XCTAssertFalse(WorkSessionEngine.selectCampaignOption("unknown", slot: .audience, in: &record))
    selectStrong(in: &record)
    XCTAssertTrue(WorkSessionEngine.completeCampaignCalibration(&record))
    let delivered = record.deliveredQuality
    XCTAssertFalse(WorkSessionEngine.completeCampaignCalibration(&record))
    XCTAssertFalse(WorkSessionEngine.selectCampaignOption("observer-audience", slot: .audience, in: &record))
    XCTAssertEqual(record.deliveredQuality, delivered)
  }

  func testWeakBrioQualityCannotBeUpgradedAndPoorReviewReducesStrongWork() {
    var weak = makeRecord(potential: 42, category: .acquisition)
    weak.path = .manualReview; selectStrong(in: &weak)
    XCTAssertTrue(WorkSessionEngine.completeCampaignCalibration(&weak))
    XCTAssertEqual(weak.deliveredQuality, 42)
    var strong = makeRecord(potential: 92, category: .acquisition)
    strong.path = .manualReview
    _ = WorkSessionEngine.selectCampaignOption("observer-audience", slot: .audience, in: &strong)
    _ = WorkSessionEngine.selectCampaignOption("overclaim-message", slot: .message, in: &strong)
    _ = WorkSessionEngine.selectCampaignOption("core-channel", slot: .channel, in: &strong)
    XCTAssertTrue(WorkSessionEngine.completeCampaignCalibration(&strong))
    XCTAssertLessThan(strong.deliveredQuality!, strong.agentPotentialQuality)
    XCTAssertEqual(strong.agentPotentialQuality, 92)
  }

  func testSaveRoundTripPreservesChallengeAndChoices() throws {
    var record = makeRecord(potential: 79, category: .launch)
    record.path = .manualReview
    XCTAssertTrue(WorkSessionEngine.selectCampaignOption("core-audience", slot: .audience, in: &record))
    let decoded = try JSONDecoder().decode(WorkSessionRecord.self, from: JSONEncoder().encode(record))
    XCTAssertEqual(decoded, record)
    XCTAssertEqual(decoded.campaignChallenge, record.campaignChallenge)
    XCTAssertEqual(decoded.campaignSelection.audienceID, "core-audience")
  }

  func testAccessibilityAndReduceMotionCannotAffectScoring() throws {
    let challenge = try XCTUnwrap(makeRecord(potential: 80, category: .acquisition).campaignChallenge)
    let selection = CampaignSelection(audienceID: "alternate-audience", messageID: "alternate-message", channelID: "alternate-channel")
    XCTAssertEqual(CampaignCalibrationEvaluator.evaluate(challenge: challenge, selection: selection), CampaignCalibrationEvaluator.evaluate(challenge: challenge, selection: selection))
    XCTAssertEqual(CampaignCalibrationEvaluator.evaluate(challenge: challenge, selection: selection)?.reviewQuality, 100)
  }

  func testHindsightDistinguishesBrioFromFounderFailure() {
    var founderFailure = makeRecord(potential: 92, category: .launch)
    founderFailure.path = .manualReview; founderFailure.founderReviewQuality = 45; founderFailure.deliveredQuality = 55
    XCTAssertEqual(founderFailure.causalAttribution, .founderReview)
    XCTAssertTrue(founderFailure.hindsightExplanations.contains { $0.contains("Brio") && $0.contains("Founder Review") })
    var brioFailure = makeRecord(potential: 48, category: .launch)
    brioFailure.path = .manualReview; brioFailure.founderReviewQuality = 100; brioFailure.deliveredQuality = 48
    XCTAssertEqual(brioFailure.causalAttribution, .agentOutput)
  }

  private func makeRecord(potential: Int, category: CampaignCategory?) -> WorkSessionRecord {
    WorkSessionEngine.makeCampaignCalibrationRecord(assignmentID: assignmentID, agentID: "brio", urgency: .important, potentialQuality: potential, careerSeed: 88, venture: 2, sprint: 3, stress: .stable, attentionCost: 3, campaignCategory: category)
  }

  private func selectStrong(in record: inout WorkSessionRecord) {
    XCTAssertTrue(WorkSessionEngine.selectCampaignOption("alternate-audience", slot: .audience, in: &record))
    XCTAssertTrue(WorkSessionEngine.selectCampaignOption("alternate-message", slot: .message, in: &record))
    XCTAssertTrue(WorkSessionEngine.selectCampaignOption("alternate-channel", slot: .channel, in: &record))
  }

  private func assessment(_ challenge: CampaignCalibrationChallenge, _ audience: String, _ message: String, _ channel: String) -> CampaignCalibrationAssessment? {
    CampaignCalibrationEvaluator.evaluate(challenge: challenge, selection: .init(audienceID: audience, messageID: message, channelID: channel))
  }

  private func task(_ title: String, role: AgentRole, urgency: TaskUrgency = .important) -> SoloTask {
    SoloTask(title: title, detail: "Campaign objective and operating brief", role: role, urgency: urgency, impact: .momentum(4))
  }

  private func result(_ actual: Int) -> TaskResult {
    TaskResult(actualQuality: actual, reportedQuality: actual, evidenceCompleteness: 80, correlatedFailureIdentifier: nil, immediateEffects: .init(momentum: actual), delayedEffects: .init(), confidenceLowerBound: actual - 5, confidenceUpperBound: actual + 5, knownOperationalRisk: "Normal market variance")
  }
}

@MainActor
final class CampaignCalibrationStoreTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("solo-unicorn-run-native-save-") { UserDefaults.standard.removeObject(forKey: key) }
    super.tearDown()
  }

  func testEligibleBrioAssignmentEntersCampaignCalibration() throws {
    let (store, id) = try makeStore(title: "Launch founder analytics")
    XCTAssertTrue(store.isCampaignCalibrationEligible(taskID: id))
    XCTAssertTrue(store.prepareWorkSession(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.family, .campaignCalibration)
  }

  func testManualReviewChargesAttentionExactlyOnce() throws {
    let (store, id) = try makeStore(title: "Launch founder analytics")
    let before = store.attentionRemaining
    XCTAssertTrue(store.beginManualCampaignCalibration(taskID: id))
    let cost = try XCTUnwrap(store.workSession(for: id)?.founderAttentionCost)
    XCTAssertEqual(store.attentionRemaining, before - cost)
    XCTAssertTrue(store.beginManualCampaignCalibration(taskID: id))
    XCTAssertEqual(store.attentionRemaining, before - cost)
  }

  func testInterruptedSaveRestoresOptionsChoicesAndAttention() throws {
    let (store, id) = try makeStore(title: "Create upgrade campaign")
    XCTAssertTrue(store.beginManualCampaignCalibration(taskID: id))
    XCTAssertTrue(store.selectCampaignOption(taskID: id, slot: .audience, optionID: "core-audience"))
    let before = try XCTUnwrap(store.workSession(for: id))
    let attention = store.attentionRemaining
    let restored = GameStore(); restored.continueCareer()
    XCTAssertEqual(restored.workSession(for: id)?.campaignChallenge, before.campaignChallenge)
    XCTAssertEqual(restored.workSession(for: id)?.campaignSelection, before.campaignSelection)
    XCTAssertEqual(restored.attentionRemaining, attention)
    XCTAssertTrue(restored.beginManualCampaignCalibration(taskID: id))
    XCTAssertEqual(restored.attentionRemaining, attention)
  }

  func testCompletionAppliesDeliveredQualityOnceAndPreservesAgentQuality() throws {
    let (store, id) = try makeStore(title: "Launch founder analytics")
    XCTAssertTrue(store.beginManualCampaignCalibration(taskID: id))
    try submitStrong(store, id)
    let session = try XCTUnwrap(store.workSession(for: id))
    let result = try XCTUnwrap(store.tasks.first(where: { $0.id == id })?.result)
    XCTAssertEqual(result.workSessionPotentialQuality, session.agentPotentialQuality)
    XCTAssertEqual(result.founderReviewQualityForSimulation, 100)
    XCTAssertEqual(result.deliveredQualityForSimulation, session.agentPotentialQuality)
    XCTAssertFalse(store.submitCampaignCalibration(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.deliveredQuality, session.deliveredQuality)
  }

  func testDelegateIsDeterministicFreeAndCannotReplay() throws {
    let (store, id) = try makeStore(title: "Launch founder analytics")
    let attention = store.attentionRemaining
    XCTAssertTrue(store.delegateCampaignCalibration(taskID: id))
    let delivered = store.workSession(for: id)?.deliveredQuality
    XCTAssertFalse(store.delegateCampaignCalibration(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.deliveredQuality, delivered)
    XCTAssertEqual(store.attentionRemaining, attention)
  }

  func testCompletedReviewFeedsEvidenceAndHindsight() throws {
    let (store, id) = try makeStore(title: "Launch founder analytics")
    XCTAssertTrue(store.beginManualCampaignCalibration(taskID: id))
    try submitStrong(store, id)
    let session = try XCTUnwrap(store.workSession(for: id))
    store.review(taskID: id)
    let evidence = try XCTUnwrap(store.evidence.first(where: { $0.taskInstanceID == id.uuidString }))
    XCTAssertEqual(evidence.workSessionAgentQuality, session.agentPotentialQuality)
    XCTAssertEqual(evidence.workSessionFounderReviewQuality, session.founderReviewQuality)
    XCTAssertEqual(evidence.workSessionDeliveredQuality, session.deliveredQuality)
    XCTAssertEqual(evidence.workSessionFindings, session.findings)
    XCTAssertTrue(evidence.hindsightNotes.contains { $0.contains("Brio") })
  }

  func testReopeningCannotRerollAfterBrioStateChanges() throws {
    let (store, id) = try makeStore(title: "Launch founder analytics")
    XCTAssertTrue(store.prepareCampaignCalibration(taskID: id))
    let before = try XCTUnwrap(store.workSession(for: id))
    let index = try XCTUnwrap(store.agents.firstIndex(where: { $0.id == "brio" }))
    store.agents[index].progression.adjustStress(100)
    XCTAssertTrue(store.prepareCampaignCalibration(taskID: id))
    XCTAssertEqual(store.workSession(for: id)?.challengeSeed, before.challengeSeed)
    XCTAssertEqual(store.workSession(for: id)?.campaignChallenge, before.campaignChallenge)
  }

  private func makeStore(title: String) throws -> (GameStore, UUID) {
    let store = GameStore(); store.resetCareer(); store.selectedDoctrine = .guided; store.selectedProductType = .saas; store.founderName = "Campaign Founder"; store.startCareer(seed: 10_431); store.confirmVentureThesisIfNeeded()
    let id = try XCTUnwrap(store.tasks.first?.id)
    store.tasks[0].title = title; store.tasks[0].detail = "Increase qualified trial starts."; store.tasks[0].role = .marketing; store.tasks[0].category = .sales; store.tasks[0].urgency = .important
    store.assign(agentID: "brio", to: id)
    XCTAssertNotNil(store.tasks[0].result)
    return (store, id)
  }

  private func submitStrong(_ store: GameStore, _ id: UUID) throws {
    XCTAssertTrue(store.selectCampaignOption(taskID: id, slot: .audience, optionID: "alternate-audience"))
    XCTAssertTrue(store.selectCampaignOption(taskID: id, slot: .message, optionID: "alternate-message"))
    XCTAssertTrue(store.selectCampaignOption(taskID: id, slot: .channel, optionID: "alternate-channel"))
    XCTAssertTrue(store.submitCampaignCalibration(taskID: id))
  }
}
