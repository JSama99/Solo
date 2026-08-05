import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class GameStoreTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
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
    let taskIndex = try XCTUnwrap(
      store.tasks.firstIndex(where: { task in
        store.agents.contains(where: { $0.role == task.role })
      })
    )
    let task = store.tasks[taskIndex]
    let agentIndex = try XCTUnwrap(store.agents.firstIndex(where: { $0.role == task.role }))
    store.agents[agentIndex].drift = 30
    let originalCalibration = store.agents[agentIndex].calibration
    let originalDrift = store.agents[agentIndex].drift
    store.assign(agentID: store.agents[agentIndex].id, to: task.id)
    let reported = try XCTUnwrap(store.tasks[taskIndex].result?.reportedQuality)

    store.review(taskID: task.id)

    XCTAssertEqual(store.tasks[taskIndex].result?.reportedQuality, reported)
    XCTAssertNotNil(store.tasks[taskIndex].result?.revealedActualQuality)
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
    XCTAssertLessThan(store.report?.runwayDelta ?? 0, 0)
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
    XCTAssertNotNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v8"))
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

  func testV2SaveMigratesExplicitlyToV4() throws {
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
    XCTAssertNotNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v8"))
    XCTAssertNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v2"))
  }

  func testV3SaveMigratesExplicitlyToV4() throws {
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
    XCTAssertNotNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v8"))
    XCTAssertNil(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v3"))
  }

  func testIdenticalSeedsProduceIdenticalCompleteSimulationResults() throws {
    let first = makeStore(seed: 20_260_801)
    let second = makeStore(seed: 20_260_801)

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
  }

  func testFullTwoVentureCompletion() throws {
    let store = makeStore(seed: 2_024)

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

  func testBuild4CreatesFiveOptionSprintDraft() {
    let store = makeStore(seed: 6_001)

    XCTAssertEqual(store.tasks.count, 3)
    XCTAssertEqual(store.taskBacklog.count, 2)
    XCTAssertEqual(Set((store.tasks + store.taskBacklog).map(\.id)).count, 5)
    XCTAssertEqual(Set((store.tasks + store.taskBacklog).map(\.title)).count, 5)
  }

  func testDraftSwapWorksOnlyBeforeAssignments() throws {
    let store = makeStore(seed: 6_002)
    let active = try XCTUnwrap(store.tasks.first)
    let backlog = try XCTUnwrap(store.taskBacklog.first)

    XCTAssertTrue(store.swapDraftTask(activeTaskID: active.id, backlogTaskID: backlog.id))
    XCTAssertTrue(store.tasks.contains(where: { $0.id == backlog.id }))
    XCTAssertTrue(store.taskBacklog.contains(where: { $0.id == active.id }))

    try assignFirstTask(in: store)
    let nextBacklog = try XCTUnwrap(store.taskBacklog.first)
    XCTAssertFalse(store.swapDraftTask(activeTaskID: store.tasks[0].id, backlogTaskID: nextBacklog.id))
    XCTAssertEqual(store.alertMessage, "Clear assignments before changing the sprint draft.")
  }

  func testCommitRequiresFounderDilemmaDecision() throws {
    let store = makeStore(seed: 6_003)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
    store.assign(agentID: agent.id, to: task.id)

    store.commitSprint()

    XCTAssertEqual(store.sprint, 1)
    XCTAssertEqual(store.alertMessage, "Choose a response to the founder dilemma before committing.")
  }

  func testReviewedTaskRequiresExplicitResolution() throws {
    let store = makeStore(seed: 6_004)
    try assignFirstTask(in: store)
    store.review(taskID: store.tasks[0].id)

    store.commitSprint()

    XCTAssertEqual(store.sprint, 1)
    XCTAssertTrue(store.alertMessage?.contains("Choose how to resolve") == true)
    store.resolveReviewedTask(taskID: store.tasks[0].id, choice: .approve)
    store.commitSprint()
    XCTAssertNotEqual(store.sprint, 1)
  }

  func testReworkChangesCurrentResultAndConsumesAttention() throws {
    let store = makeStore(seed: 6_005)
    try assignFirstTask(in: store)
    store.tasks[0].result = TaskResult(
      actualQuality: 50,
      reportedQuality: 68,
      evidenceCompleteness: 70,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(revenue: 100),
      delayedEffects: SimulationEffects(momentum: -2, trust: -3),
      confidenceLowerBound: 50,
      confidenceUpperBound: 80,
      knownOperationalRisk: "Test risk"
    )
    store.review(taskID: store.tasks[0].id)
    let before = try XCTUnwrap(store.tasks[0].result?.revealedActualQuality)
    let energyBefore = store.stats.energy
    let runwayBefore = store.stats.runway

    store.resolveReviewedTask(taskID: store.tasks[0].id, choice: .rework)

    XCTAssertEqual(store.tasks[0].resolution, .rework)
    XCTAssertEqual(store.tasks[0].result?.revealedActualQuality, before + 12)
    XCTAssertEqual(store.attentionRemaining, store.attentionMaximum - 2)
    XCTAssertEqual(store.stats.energy, energyBefore - 4)
    XCTAssertEqual(store.stats.runway, runwayBefore - 1)
  }

  func testCrossCheckRemovesCorrelatedFailure() throws {
    let store = makeStore(seed: 6_006)
    try assignFirstTask(in: store)
    store.tasks[0].result = TaskResult(
      actualQuality: 45,
      reportedQuality: 75,
      evidenceCompleteness: 62,
      correlatedFailureIdentifier: "CASCADE",
      immediateEffects: SimulationEffects(momentum: 4),
      delayedEffects: SimulationEffects(momentum: -3, trust: -4),
      confidenceLowerBound: 55,
      confidenceUpperBound: 85,
      knownOperationalRisk: "Shared model-family exposure"
    )
    store.review(taskID: store.tasks[0].id)
    let evidenceBefore = store.tasks[0].result?.evidenceCompleteness ?? 0

    store.resolveReviewedTask(taskID: store.tasks[0].id, choice: .escalate)

    XCTAssertNil(store.tasks[0].result?.correlatedFailureIdentifier)
    XCTAssertGreaterThan(store.tasks[0].result?.evidenceCompleteness ?? 0, evidenceBefore)
    XCTAssertEqual(store.tasks[0].resolution, .escalate)
  }

  func testShipAnywayIncreasesPayoffAndDelayedRisk() throws {
    let store = makeStore(seed: 6_007)
    try assignFirstTask(in: store)
    store.tasks[0].result = TaskResult(
      actualQuality: 60,
      reportedQuality: 72,
      evidenceCompleteness: 75,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(revenue: 100),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: 60,
      confidenceUpperBound: 80,
      knownOperationalRisk: "Normal operational variance"
    )
    store.review(taskID: store.tasks[0].id)

    store.resolveReviewedTask(taskID: store.tasks[0].id, choice: .shipAnyway)

    XCTAssertEqual(store.tasks[0].result?.immediateEffects.revenue, 120)
    XCTAssertEqual(store.tasks[0].result?.delayedEffects.trust, -4)
    XCTAssertEqual(store.tasks[0].result?.delayedEffects.momentum, -2)
  }

  func testAgentsHavePersistentPersonalityAndRelationshipData() {
    let store = makeStore(seed: 6_008)
    let aurora = store.agents.first(where: { $0.id == "aurora" })
    let stacks = store.agents.first(where: { $0.id == "stacks" })
    let brio = store.agents.first(where: { $0.id == "brio" })

    XCTAssertEqual(aurora?.archetype, "The Analyst")
    XCTAssertEqual(stacks?.archetype, "The Builder")
    XCTAssertEqual(brio?.archetype, "The Promoter")
    XCTAssertFalse(aurora?.traits.isEmpty ?? true)
    XCTAssertTrue((0...100).contains(brio?.relationship ?? -1))
  }

  func testRevenueCatCatalogIdentifiers() {
    XCTAssertEqual(RevenueCatConfiguration.entitlementIdentifier, "solo_unicorn_run_pro")
    XCTAssertEqual(RevenueCatConfiguration.entitlementDisplayName, "Founder Pass")
    XCTAssertEqual(
      RevenueCatConfiguration.expectedStoreProductIdentifier,
      "com.talonsight.solounicornrun.founderpass.lifetime"
    )
  }

  func testBuild1V4SaveCompatibility() throws {
    let source = makeStore(seed: 4_004)
    try assignFirstTask(in: source)
    let expectedResult = source.tasks[0].result
    let expectedRNG = source.randomNumberGenerator
    let legacy = SaveEnvelope(version: 4, career: careerSave(from: source))
    let data = try JSONEncoder().encode(legacy)
    source.resetCareer()
    UserDefaults.standard.set(data, forKey: "solo-unicorn-run-native-save-v4")

    let restored = GameStore()
    restored.continueCareer()

    XCTAssertEqual(restored.stage, .game)
    XCTAssertEqual(restored.tasks[0].result, expectedResult)
    XCTAssertEqual(restored.randomNumberGenerator, expectedRNG)
    XCTAssertEqual(restored.taskBacklog.count, 2)
    XCTAssertNotNil(restored.activeDilemma)
    let migratedData = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v8"))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: migratedData).version, 8)
  }

  func testBuild6TaskDeckDoesNotRepeatAcrossFirstVenture() throws {
    let store = makeStore(seed: 61_001)
    var draftedTitles: [String] = []

    for _ in 1...12 {
      draftedTitles.append(contentsOf: (store.tasks + store.taskBacklog).map(\.title))
      if store.sprint == 12 { break }
      if let dilemma = store.activeDilemma,
         let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      for (offset, task) in store.tasks.enumerated() {
        store.assign(agentID: store.agents[offset].id, to: task.id)
      }
      store.stats.runway = max(store.stats.runway, 90)
      store.stats.energy = max(store.stats.energy, 90)
      store.stats.trust = max(store.stats.trust, 70)
      store.commitSprint()
      store.report = nil
    }

    XCTAssertEqual(draftedTitles.count, 60)
    XCTAssertEqual(Set(draftedTitles).count, 60, "the sixty-card venture deck should not recycle before every card appears")
  }

  func testBuild6ChapterDilemmasDoNotRepeat() {
    let store = makeStore(seed: 61_002)
    var titles: [String] = []

    for _ in 0..<3 {
      if let dilemma = store.activeDilemma {
        titles.append(dilemma.title)
        let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices[0]
        store.selectDilemmaChoice(choice.id)
      }
      for (offset, task) in store.tasks.enumerated() {
        store.assign(agentID: store.agents[offset].id, to: task.id)
      }
      store.stats.runway = 90
      store.stats.energy = 90
      store.stats.trust = 70
      store.commitSprint()
      store.report = nil
    }

    XCTAssertEqual(Set(titles).count, 3)
  }

  func testBuild6DilemmaCreatesPersistentCompanyState() throws {
    let store = makeStore(seed: 61_003)
    let dilemma = try XCTUnwrap(store.activeDilemma)
    let choice = try XCTUnwrap(dilemma.choices.first(where: { $0.id != "sell" }))
    store.selectDilemmaChoice(choice.id)
    try assignFirstTask(in: store)

    store.commitSprint()

    XCTAssertEqual(store.decisionHistory.count, 1)
    XCTAssertTrue(!store.companyFlags.isEmpty || !store.activeObligations.isEmpty)
  }

  func testBuild6SaveReloadPreservesFutureDraftAndDilemma() throws {
    let original = makeStore(seed: 61_004)
    if let dilemma = original.activeDilemma,
       let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices.first {
      original.selectDilemmaChoice(choice.id)
    }
    for (offset, task) in original.tasks.enumerated() {
      original.assign(agentID: original.agents[offset].id, to: task.id)
    }
    original.stats.runway = 90
    original.stats.energy = 90
    original.stats.trust = 70
    original.commitSprint()
    original.report = nil

    let saved = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v8"))

    if let dilemma = original.activeDilemma,
       let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices.first {
      original.selectDilemmaChoice(choice.id)
    }
    for (offset, task) in original.tasks.enumerated() {
      original.assign(agentID: original.agents[offset].id, to: task.id)
    }
    original.stats.runway = 90
    original.stats.energy = 90
    original.stats.trust = 70
    original.commitSprint()
    original.report = nil
    let expectedTitles = original.tasks.map(\.title)
    let expectedDilemma = original.activeDilemma?.title

    UserDefaults.standard.set(saved, forKey: "solo-unicorn-run-native-save-v8")
    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    reloaded.continueCareer()
    if let dilemma = reloaded.activeDilemma,
       let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices.first {
      reloaded.selectDilemmaChoice(choice.id)
    }
    for (offset, task) in reloaded.tasks.enumerated() {
      reloaded.assign(agentID: reloaded.agents[offset].id, to: task.id)
    }
    reloaded.stats.runway = 90
    reloaded.stats.energy = 90
    reloaded.stats.trust = 70
    reloaded.commitSprint()
    reloaded.report = nil

    XCTAssertEqual(reloaded.tasks.map(\.title), expectedTitles)
    XCTAssertEqual(reloaded.activeDilemma?.title, expectedDilemma)
  }

  private func makeStore(seed: UInt64 = 1_234) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    return store
  }

  private func assignFirstTask(in store: GameStore) throws {
    if let dilemma = store.activeDilemma,
       let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
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
      taskBacklog: store.taskBacklog,
      founderAttentionSpent: store.attentionMaximum - store.attentionRemaining,
      activeDilemma: store.activeDilemma,
      selectedDilemmaChoiceID: store.selectedDilemmaChoiceID,
      currentObjective: store.currentObjective,
      evidence: store.evidence,
      outcome: store.careerOutcome,
      randomNumberGenerator: store.randomNumberGenerator,
      correlatedFailureEvent: store.correlatedFailureEvent,
      pendingEffects: store.pendingEffects,
      reportCache: store.reportCache
    )
  }
}
