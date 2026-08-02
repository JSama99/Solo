import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class GameStoreTests: XCTestCase {
  override func tearDown() {
    GameStore().resetCareer()
    super.tearDown()
  }

  func testUnassignedSprintDoesNotAdvance() {
    let store = makeStore()

    store.commitSprint()

    XCTAssertEqual(store.sprint, 1)
    XCTAssertEqual(store.alertMessage, "Assign at least one agent before committing the sprint.")
  }

  func testReviewImprovesSpecialistForecast() throws {
    let store = makeStore()
    let task = try XCTUnwrap(store.tasks.first)
    let agentIndex = try XCTUnwrap(store.agents.firstIndex(where: { $0.role == task.role }))
    store.agents[agentIndex].drift = 30
    let originalCalibration = store.agents[agentIndex].calibration
    let originalDrift = store.agents[agentIndex].drift
    store.assign(agentID: store.agents[agentIndex].id, to: task.id)
    let reported = try XCTUnwrap(store.tasks[0].result?.reportedQuality)

    store.review(taskID: task.id)

    XCTAssertEqual(store.tasks[0].result?.reportedQuality, reported)
    XCTAssertNotNil(store.tasks[0].result?.revealedActualQuality)
    XCTAssertGreaterThan(store.agents[agentIndex].calibration, originalCalibration)
    XCTAssertLessThan(store.agents[agentIndex].drift, originalDrift)
    XCTAssertEqual(store.attentionRemaining, store.attentionMaximum - 1)
  }

  func testRunwayFailureEndsCareer() throws {
    let store = makeStore()
    store.stats.runway = 1
    try assignFirstTask(in: store)

    store.commitSprint()

    XCTAssertEqual(store.careerOutcome?.kind, .bankruptcy)
    XCTAssertEqual(store.sprint, 1)
    XCTAssertEqual(store.report?.runwayDelta, -4)
  }

  func testFinalSprintCompletesTwoVentureCareer() throws {
    let store = makeStore()
    store.venture = 2
    store.sprint = 12
    store.stats.runway = 50
    store.stats.energy = 50
    store.stats.trust = 50
    try assignFirstTask(in: store)

    store.commitSprint()
    store.finishReport()

    XCTAssertEqual(store.careerOutcome?.kind, .victory)
    XCTAssertEqual(store.stage, .outcome)
    XCTAssertEqual(store.venture, 2)
    XCTAssertEqual(store.sprint, 12)
  }

  func testLegacyTaskGainsTypedImpact() throws {
    let json = """
    {
      "id": "2FD0809C-DA27-4989-BC10-D01DF2C48DA1",
      "title": "Fix Critical Bug",
      "detail": "Stabilize the product.",
      "role": "Engineering",
      "reward": "+8 Trust",
      "isReviewed": false
    }
    """

    let task = try JSONDecoder().decode(SoloTask.self, from: Data(json.utf8))

    XCTAssertEqual(task.impact, .trust(8))
    XCTAssertEqual(task.reward, "+8 Trust")
    XCTAssertNil(task.result)
  }

  func testV1CareerMigratesToVersionedSave() throws {
    let source = makeStore()
    let legacy = careerSave(from: source)
    let legacyData = try JSONEncoder().encode(legacy)
    source.resetCareer()
    UserDefaults.standard.set(legacyData, forKey: "solo-unicorn-run-native-save-v1")

    let migrated = GameStore()
    migrated.continueCareer()

    XCTAssertEqual(migrated.founderName, "Founder")
    XCTAssertEqual(migrated.stage, .game)
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v5"))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: data).version, 5)
    XCTAssertNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v1"))
  }

  func testIdenticalSeedsProduceIdenticalResults() throws {
    let first = makeStore(seed: 42)
    let second = makeStore(seed: 42)

    try assignFirstTask(in: first)
    try assignFirstTask(in: second)

    XCTAssertEqual(first.tasks[0].result, second.tasks[0].result)
    XCTAssertEqual(first.randomNumberGenerator, second.randomNumberGenerator)
  }

  func testDifferentSeedsCanProduceDifferentResults() throws {
    let first = makeStore(seed: 41)
    let second = makeStore(seed: 99)

    try assignFirstTask(in: first)
    try assignFirstTask(in: second)

    XCTAssertNotEqual(first.tasks[0].result, second.tasks[0].result)
  }

  func testActualQualityRemainsHiddenBeforeReview() throws {
    let store = makeStore(seed: 7)
    try assignFirstTask(in: store)

    XCTAssertNotNil(store.tasks[0].result?.reportedQuality)
    XCTAssertNil(store.tasks[0].result?.revealedActualQuality)

    store.review(taskID: store.tasks[0].id)

    XCTAssertNotNil(store.tasks[0].result?.revealedActualQuality)
  }

  func testConfirmedReport() {
    var result = makeResult(actual: 72, reported: 75, evidence: 82)

    result.verify()

    XCTAssertEqual(result.verificationState, .confirmed)
    XCTAssertEqual(result.revealedActualQuality, 72)
  }

  func testOverclaimDetection() {
    var result = makeResult(actual: 54, reported: 76, evidence: 88)

    result.verify()

    XCTAssertEqual(result.verificationState, .overclaimed)
    XCTAssertEqual(result.overclaimAmount, 22)
    XCTAssertEqual(result.revealedActualQuality, 54)
  }

  func testEvidenceIncompleteReviewDoesNotRevealActualQuality() throws {
    let store = makeStore(seed: 8_120)
    try assignFirstTask(in: store)
    store.tasks[0].result = makeResult(actual: 81, reported: 84, evidence: 20)

    store.review(taskID: store.tasks[0].id)

    let result = try XCTUnwrap(store.tasks[0].result)
    XCTAssertEqual(result.verificationState, .evidenceIncomplete)
    XCTAssertTrue(result.verificationState.reviewAttempted)
    XCTAssertFalse(result.verificationState.evidenceVerified)
    XCTAssertNil(result.revealedActualQuality)
    let entry = try XCTUnwrap(store.evidence.first)
    XCTAssertTrue(entry.reviewAttempted)
    XCTAssertFalse(entry.evidenceVerified)
    XCTAssertNil(entry.actualQuality)
  }

  func testReassigningSameAgentRestoresReportWithoutAdvancingRNG() throws {
    let store = makeStore(seed: 4_040)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
    store.assign(agentID: agent.id, to: task.id)
    let original = try XCTUnwrap(store.tasks[0].result)
    let stateAfterFirstReport = store.randomNumberGenerator

    store.assign(agentID: nil, to: task.id)
    store.assign(agentID: agent.id, to: task.id)

    XCTAssertEqual(store.tasks[0].result, original)
    XCTAssertEqual(store.randomNumberGenerator, stateAfterFirstReport)
  }

  func testRelaunchCannotRerollCachedReport() throws {
    let source = makeStore(seed: 9_191)
    let task = try XCTUnwrap(source.tasks.first)
    let agent = source.agents.first(where: { $0.role == task.role }) ?? source.agents[0]
    source.assign(agentID: agent.id, to: task.id)
    let original = try XCTUnwrap(source.tasks[0].result)
    let savedState = source.randomNumberGenerator

    let restored = GameStore()
    restored.continueCareer()
    restored.assign(agentID: nil, to: task.id)
    restored.assign(agentID: agent.id, to: task.id)

    XCTAssertEqual(restored.tasks[0].result, original)
    XCTAssertEqual(restored.randomNumberGenerator, savedState)
  }

  func testIntentCannotChangeAfterAssignment() throws {
    let store = makeStore(seed: 77)
    try assignFirstTask(in: store)

    XCTAssertFalse(store.setIntent(.sell))
    XCTAssertEqual(store.intent, .build)
    XCTAssertEqual(store.alertMessage, "Clear all assignments to change sprint intent.")
  }

  func testIntentCanChangeAfterAllAssignmentsAreCleared() throws {
    let store = makeStore(seed: 78)
    try assignFirstTask(in: store)
    let task = try XCTUnwrap(store.tasks.first)
    store.assign(agentID: nil, to: task.id)

    XCTAssertTrue(store.setIntent(.learn))
    XCTAssertEqual(store.intent, .learn)
  }

  func testCorrelatedFamilyFailureAffectsEveryLinkedAgent() throws {
    let store = makeStore(seed: 12)
    store.correlatedFailureEvent = CorrelatedFailureEvent(
      id: "TEST-NOVA-CASCADE",
      modelFamily: "Nova-1",
      qualityPenalty: 24
    )
    let firstTask = try XCTUnwrap(store.tasks.first)
    let secondTask = try XCTUnwrap(store.tasks.dropFirst().first)
    let novaAgents = store.agents.filter { $0.modelFamily == "Nova-1" }
    XCTAssertEqual(novaAgents.count, 2)

    store.assign(agentID: novaAgents[0].id, to: firstTask.id)
    store.assign(agentID: novaAgents[1].id, to: secondTask.id)

    XCTAssertEqual(store.tasks[0].result?.correlatedFailureIdentifier, "TEST-NOVA-CASCADE")
    XCTAssertEqual(store.tasks[1].result?.correlatedFailureIdentifier, "TEST-NOVA-CASCADE")
    XCTAssertLessThanOrEqual(store.tasks[0].result?.delayedEffects.trust ?? 0, -3)
    XCTAssertLessThanOrEqual(store.tasks[1].result?.delayedEffects.trust ?? 0, -3)
  }

  func testReviewCreatesEvidenceWithReportedAndActualValues() throws {
    let store = makeStore(seed: 88)
    try assignFirstTask(in: store)
    let task = store.tasks[0]
    let reported = try XCTUnwrap(task.result?.reportedQuality)

    store.review(taskID: task.id)

    let entry = try XCTUnwrap(store.evidence.first)
    XCTAssertEqual(entry.reportedQuality, reported)
    XCTAssertNotNil(entry.actualQuality)
    XCTAssertTrue(entry.reviewed)
    XCTAssertTrue(entry.verificationState.revealsActualQuality)
  }

  func testLaterReviewPreservesOriginalEvidenceReport() throws {
    let store = makeStore(seed: 144)
    try assignFirstTask(in: store)
    let task = store.tasks[0]
    let agentID = try XCTUnwrap(task.assignedAgentID)
    let agent = try XCTUnwrap(store.agents.first(where: { $0.id == agentID }))
    let originallyReported = 17
    store.evidence = [
      EvidenceEntry(
        venture: store.venture,
        sprint: store.sprint,
        taskInstanceID: task.id.uuidString,
        task: task.title,
        agent: agent.name,
        reviewed: false,
        verdict: VerificationState.unverified.label,
        note: "Original report",
        reportedQuality: originallyReported,
        actualQuality: nil,
        verificationState: .unverified,
        overclaimAmount: 0,
        evidenceCompleteness: 31,
        correlatedFailureIdentifier: nil
      )
    ]

    store.review(taskID: task.id)

    let entry = try XCTUnwrap(store.evidence.first)
    XCTAssertEqual(store.evidence.count, 1)
    XCTAssertEqual(entry.reportedQuality, originallyReported)
    XCTAssertEqual(entry.evidenceCompleteness, 31)
    XCTAssertNotNil(entry.actualQuality)
    XCTAssertTrue(entry.reviewed)
  }

  func testVentureTwoEvidenceCannotOverwriteVentureOneEvidence() throws {
    let store = makeStore(seed: 616)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
    store.evidence = [
      EvidenceEntry(
        id: task.id,
        venture: 1,
        sprint: store.sprint,
        taskInstanceID: task.id.uuidString,
        task: task.title,
        agent: agent.name,
        reviewed: false,
        verdict: VerificationState.unverified.label,
        note: "Venture One report",
        reportedQuality: 33,
        actualQuality: nil,
        verificationState: .unverified,
        overclaimAmount: 0,
        evidenceCompleteness: 70,
        correlatedFailureIdentifier: nil
      )
    ]
    store.venture = 2
    store.assign(agentID: agent.id, to: task.id)
    store.review(taskID: task.id)

    XCTAssertEqual(store.evidence.count, 2)
    XCTAssertEqual(store.evidence.first(where: { $0.venture == 1 })?.reportedQuality, 33)
    XCTAssertNotNil(store.evidence.first(where: { $0.venture == 2 }))
  }

  func testV2SaveMigratesExplicitlyToV5() throws {
    let source = makeStore(seed: 321)
    let envelope = SaveEnvelope(version: 2, career: careerSave(from: source))
    let encoded = try JSONEncoder().encode(envelope)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var career = try XCTUnwrap(object["career"] as? [String: Any])
    career.removeValue(forKey: "randomNumberGenerator")
    career.removeValue(forKey: "correlatedFailureEvent")
    career.removeValue(forKey: "pendingEffects")
    var tasks = try XCTUnwrap(career["tasks"] as? [[String: Any]])
    for index in tasks.indices {
      tasks[index].removeValue(forKey: "result")
    }
    career["tasks"] = tasks
    object["career"] = career
    let v2Data = try JSONSerialization.data(withJSONObject: object)
    source.resetCareer()
    UserDefaults.standard.set(v2Data, forKey: "solo-unicorn-run-native-save-v2")

    let migrated = GameStore()
    migrated.continueCareer()

    XCTAssertEqual(migrated.stage, .game)
    XCTAssertNil(migrated.tasks[0].result)
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v5"))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: data).version, 5)
    XCTAssertNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v2"))
  }

  func testV3SaveMigratesExplicitlyToV5() throws {
    let source = makeStore(seed: 3_004)
    try assignFirstTask(in: source)
    source.review(taskID: source.tasks[0].id)
    let envelope = SaveEnvelope(version: 3, career: careerSave(from: source))
    let encoded = try JSONEncoder().encode(envelope)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var career = try XCTUnwrap(object["career"] as? [String: Any])
    career.removeValue(forKey: "reportCache")
    var entries = career["evidence"] as? [[String: Any]] ?? []
    for index in entries.indices {
      entries[index].removeValue(forKey: "venture")
      entries[index].removeValue(forKey: "taskInstanceID")
      entries[index].removeValue(forKey: "evidenceVerified")
    }
    career["evidence"] = entries
    object["career"] = career
    let v3Data = try JSONSerialization.data(withJSONObject: object)
    source.resetCareer()
    UserDefaults.standard.set(v3Data, forKey: "solo-unicorn-run-native-save-v3")

    let migrated = GameStore()
    migrated.continueCareer()

    XCTAssertEqual(migrated.stage, .game)
    XCTAssertEqual(migrated.reportCache.count, 1)
    XCTAssertEqual(migrated.evidence.first?.venture, migrated.venture)
    XCTAssertFalse(migrated.evidence.first?.taskInstanceID.isEmpty ?? true)
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v5"))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: data).version, 5)
    XCTAssertNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v3"))
  }

  func testIdenticalSeedsProduceIdenticalCompleteSimulationResults() throws {
    let first = makeStore(seed: 20_260_801)
    let second = makeStore(seed: 20_260_801)
    first.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    second.entitlements = StaticEntitlementProvider(hasFounderPass: true)

    for _ in 1...24 {
      for store in [first, second] {
        store.stats.runway = 100
        store.stats.energy = 100
        store.stats.trust = 100
        try assignFirstTask(in: store)
        store.commitSprint()
        store.finishReport()
      }
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    XCTAssertEqual(
      try encoder.encode(careerSave(from: first)),
      try encoder.encode(careerSave(from: second))
    )
    XCTAssertEqual(first.careerOutcome?.kind, .victory)
    XCTAssertEqual(second.careerOutcome?.kind, .victory)
  }

  func testFullTwoVentureCompletion() throws {
    let store = makeStore(seed: 2_024)
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)

    for _ in 1...24 {
      store.stats.runway = 100
      store.stats.energy = 100
      store.stats.trust = 100
      try assignFirstTask(in: store)
      store.commitSprint()
      store.finishReport()
    }

    XCTAssertEqual(store.careerOutcome?.kind, .victory)
    XCTAssertEqual(store.stage, .outcome)
    XCTAssertEqual(store.venture, 2)
    XCTAssertEqual(store.sprint, 12)
  }

  func testInvalidNumericStatesAreSanitized() throws {
    let store = makeStore(seed: 5)
    store.stats.revenue = -500
    store.stats.capital = -100
    store.stats.momentum = 500
    store.stats.trust = -50
    store.stats.energy = 300
    store.agents[0].reliability = 400
    store.agents[0].calibration = .nan
    store.agents[0].drift = .infinity
    store.agents[0].trust = -.infinity

    try assignFirstTask(in: store)

    XCTAssertGreaterThanOrEqual(store.stats.revenue, 0)
    XCTAssertGreaterThanOrEqual(store.stats.capital, 0)
    XCTAssertTrue((0...100).contains(store.stats.momentum))
    XCTAssertTrue((0...100).contains(store.stats.trust))
    XCTAssertTrue((0...100).contains(store.stats.energy))
    XCTAssertTrue((0...100).contains(store.agents[0].reliability))
    XCTAssertTrue(store.agents[0].calibration.isFinite)
    XCTAssertTrue((0...1).contains(store.agents[0].calibration))
    XCTAssertTrue(store.agents[0].drift.isFinite)
    XCTAssertTrue((0...100).contains(store.agents[0].drift))
    XCTAssertTrue(store.agents[0].trust.isFinite)
    XCTAssertTrue((0...100).contains(store.agents[0].trust))
    let result = try XCTUnwrap(store.tasks[0].result)
    XCTAssertTrue((0...100).contains(result.reportedQuality))
    XCTAssertTrue((0...100).contains(result.evidenceCompleteness))
  }

  func testRevenueCatCatalogIdentifiers() {
    XCTAssertEqual(RevenueCatConfiguration.entitlementIdentifier, "solo_unicorn_run_pro")
    XCTAssertEqual(RevenueCatConfiguration.entitlementDisplayName, "Founder Pass")
    XCTAssertEqual(
      RevenueCatConfiguration.expectedStoreProductIdentifier,
      "com.talonsight.solounicornrun.founderpass"
    )
  }

  func testBuild1V4SaveCompatibility() throws {
    let source = makeStore(seed: 4_004)
    try assignFirstTask(in: source)
    let expectedResult = source.tasks[0].result
    let expectedRNG = source.randomNumberGenerator
    let envelope = SaveEnvelope(version: 4, career: careerSave(from: source))
    let encoded = try JSONEncoder().encode(envelope)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var career = try XCTUnwrap(object["career"] as? [String: Any])
    career.removeValue(forKey: "precedents")
    career.removeValue(forKey: "awaitingFounderPass")
    object["career"] = career
    let v4Data = try JSONSerialization.data(withJSONObject: object)
    source.resetCareer()
    UserDefaults.standard.set(v4Data, forKey: "solo-unicorn-run-native-save-v4")

    let restored = GameStore()
    restored.continueCareer()

    XCTAssertEqual(restored.stage, .game)
    XCTAssertEqual(restored.tasks[0].result, expectedResult)
    XCTAssertEqual(restored.randomNumberGenerator, expectedRNG)
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v5"))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: data).version, 5)
    XCTAssertNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v4"))
  }

  func testExistingVentureTwoV4SaveRemainsUngated() throws {
    let source = makeStore(seed: 4_204)
    source.venture = 2
    source.sprint = 4
    let envelope = SaveEnvelope(version: 4, career: careerSave(from: source))
    let encoded = try JSONEncoder().encode(envelope)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var career = try XCTUnwrap(object["career"] as? [String: Any])
    career.removeValue(forKey: "precedents")
    career.removeValue(forKey: "awaitingFounderPass")
    object["career"] = career
    let v4Data = try JSONSerialization.data(withJSONObject: object)
    source.resetCareer()
    UserDefaults.standard.set(v4Data, forKey: "solo-unicorn-run-native-save-v4")

    let restored = GameStore()
    restored.entitlements = StaticEntitlementProvider(hasFounderPass: false)
    restored.continueCareer()

    XCTAssertEqual(restored.venture, 2)
    XCTAssertEqual(restored.sprint, 4)
    XCTAssertEqual(restored.stage, .game)
    XCTAssertFalse(restored.isVentureLocked)
    XCTAssertFalse(restored.awaitingFounderPass)
  }

  private func makeStore(seed: UInt64 = 1_234) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: seed)
    return store
  }

  private func assignFirstTask(in store: GameStore) throws {
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
    store.assign(agentID: agent.id, to: task.id)
    XCTAssertNotNil(store.tasks[0].result)
  }

  private func makeResult(actual: Int, reported: Int, evidence: Int) -> TaskResult {
    TaskResult(
      actualQuality: actual,
      reportedQuality: reported,
      evidenceCompleteness: evidence,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: reported - 8,
      confidenceUpperBound: reported + 8,
      knownOperationalRisk: "Normal operational variance"
    )
  }

  private func careerSave(from store: GameStore) -> CareerSave {
    CareerSave(
      founderName: store.founderName,
      doctrine: store.doctrine,
      sprint: store.sprint,
      venture: store.venture,
      intent: store.intent,
      stats: store.stats,
      agents: store.agents,
      tasks: store.tasks,
      evidence: store.evidence,
      outcome: store.careerOutcome,
      randomNumberGenerator: store.randomNumberGenerator,
      correlatedFailureEvent: store.correlatedFailureEvent,
      pendingEffects: store.pendingEffects,
      reportCache: store.reportCache
    )
  }
}
