import XCTest
@testable import Solo_Unicorn_Run

/// Build 5 — verifies the Phase 1 extraction actually achieved what it set
/// out to: DoctrineProfile centralizes what were 6 scattered ternaries
/// without changing a single value, SimulationEngine's functions are
/// genuinely callable without a GameStore instance, and the careerScore
/// revenue-dominance fix behaves as designed.
final class SimulationEngineTests: XCTestCase {

  // ── DoctrineProfile: must reproduce Build 4's exact original values ──

  func testDoctrineProfileReproducesBuild4Values() {
    let pure = DoctrineProfile.profile(for: .pure)
    XCTAssertEqual(pure.attentionMaximum, 2)
    XCTAssertEqual(pure.reviewEnergyCost, 1)
    XCTAssertEqual(pure.neglectDriftIncrease, 9.0)
    XCTAssertEqual(pure.actualQualityBonus, 7)
    XCTAssertEqual(pure.startingStatAdjustment, SimulationEffects())

    let guided = DoctrineProfile.profile(for: .guided)
    XCTAssertEqual(guided.attentionMaximum, 3)
    XCTAssertEqual(guided.reviewEnergyCost, 2)
    XCTAssertEqual(guided.neglectDriftIncrease, 6.5)
    XCTAssertEqual(guided.actualQualityBonus, 0)
    XCTAssertEqual(guided.startingStatAdjustment, SimulationEffects(energy: 5))

    let trust = DoctrineProfile.profile(for: .trust)
    XCTAssertEqual(trust.attentionMaximum, 2)
    XCTAssertEqual(trust.reviewEnergyCost, 1)
    XCTAssertEqual(trust.neglectDriftIncrease, 6.5)
    XCTAssertEqual(trust.actualQualityBonus, 0)
    XCTAssertEqual(trust.startingStatAdjustment, SimulationEffects(momentum: -4, trust: 12))
  }

  func testDoctrineProfileCoversEveryDoctrine() {
    for doctrine in FounderDoctrine.allCases {
      _ = DoctrineProfile.profile(for: doctrine)
    }
  }

  // ── SimulationEngine: genuinely callable without a GameStore instance ──

  func testMakeResultIsCallableWithoutAGameStoreInstance() {
    var rng = SeededRandomNumberGenerator(seed: 777)
    let agent = SoloAgent(
      id: "test", name: "Test", initials: "TS", role: .engineering, modelFamily: "Nova-1",
      reliability: 80, calibration: 0.75, drift: 0, trust: 60
    )
    let task = ContentLibrary.taskPool[0]

    let result = SimulationEngine.makeResult(
      for: task, agent: agent, intent: .build, doctrine: .pure,
      correlatedFailureEvent: nil, allTasks: [task], allAgents: [agent], rng: &rng
    )

    XCTAssertTrue(result.knownOperationalRisk.count > 0)
    XCTAssertNil(result.correlatedFailureIdentifier)
  }

  func testMakeResultIsDeterministicForTheSameSeed() {
    let agent = SoloAgent(
      id: "test", name: "Test", initials: "TS", role: .engineering, modelFamily: "Nova-1",
      reliability: 80, calibration: 0.75, drift: 0, trust: 60
    )
    let task = ContentLibrary.taskPool[0]

    var rngA = SeededRandomNumberGenerator(seed: 42)
    let resultA = SimulationEngine.makeResult(
      for: task, agent: agent, intent: .build, doctrine: .pure,
      correlatedFailureEvent: nil, allTasks: [task], allAgents: [agent], rng: &rngA
    )
    var rngB = SeededRandomNumberGenerator(seed: 42)
    let resultB = SimulationEngine.makeResult(
      for: task, agent: agent, intent: .build, doctrine: .pure,
      correlatedFailureEvent: nil, allTasks: [task], allAgents: [agent], rng: &rngB
    )

    XCTAssertEqual(resultA.reportedQuality, resultB.reportedQuality)
    XCTAssertEqual(resultA.revealedActualQuality, resultB.revealedActualQuality)
  }

  func testCorrelatedFailureEventTargetsAnActualRosterFamily() {
    let agents = [
      SoloAgent(id: "a", name: "A", initials: "A", role: .engineering, modelFamily: "Nova-1",
                reliability: 80, calibration: 0.7, drift: 0, trust: 60),
      SoloAgent(id: "b", name: "B", initials: "B", role: .research, modelFamily: "Atlas-2",
                reliability: 80, calibration: 0.7, drift: 0, trust: 60)
    ]
    var sawFamily = false
    // 24% fire chance -- run enough draws that at least one should fire.
    for seed in 0..<100 {
      var localRng = SeededRandomNumberGenerator(seed: UInt64(seed))
      if let event = SimulationEngine.generateCorrelatedFailureEvent(
        venture: 1, sprint: 1, agents: agents, rng: &localRng
      ) {
        XCTAssertTrue(["Nova-1", "Atlas-2"].contains(event.modelFamily))
        sawFamily = true
      }
    }
    XCTAssertTrue(sawFamily, "expected at least one fire across 100 seeded draws at 24% probability")
  }

  func testKnownRiskFlagsSharedModelFamilyExposure() {
    let agentA = SoloAgent(id: "a", name: "A", initials: "A", role: .engineering, modelFamily: "Nova-1",
                            reliability: 80, calibration: 0.7, drift: 0, trust: 60)
    let agentB = SoloAgent(id: "b", name: "B", initials: "B", role: .research, modelFamily: "Nova-1",
                            reliability: 80, calibration: 0.7, drift: 0, trust: 60)
    var taskA = ContentLibrary.taskPool[0]
    var taskB = ContentLibrary.taskPool[1]
    taskA.assignedAgentID = "a"
    taskB.assignedAgentID = "b"

    let risk = SimulationEngine.knownRisk(
      for: taskA, agent: agentA, evidenceCompleteness: 80,
      allTasks: [taskA, taskB], allAgents: [agentA, agentB]
    )
    XCTAssertEqual(risk, "Shared model-family exposure")
  }

  func testRelationshipAndPersonalityAffectSimulationQuality() throws {
    let task = ContentLibrary.allTaskPool.first(where: { $0.role == .research })!
    var low = ContentLibrary.initialAgents.first(where: { $0.id == "aurora" })!
    var high = low
    low.relationship = 20
    high.relationship = 90
    var lowRNG = SeededRandomNumberGenerator(seed: 6_100)
    var highRNG = SeededRandomNumberGenerator(seed: 6_100)
    var lowResult = SimulationEngine.makeResult(
      for: task, agent: low, intent: .learn, doctrine: .guided,
      correlatedFailureEvent: nil, allTasks: [task], allAgents: [low], rng: &lowRNG
    )
    var highResult = SimulationEngine.makeResult(
      for: task, agent: high, intent: .learn, doctrine: .guided,
      correlatedFailureEvent: nil, allTasks: [task], allAgents: [high], rng: &highRNG
    )
    _ = lowResult.verify()
    _ = highResult.verify()
    XCTAssertGreaterThan(
      try XCTUnwrap(highResult.revealedActualQuality),
      try XCTUnwrap(lowResult.revealedActualQuality)
    )
    XCTAssertGreaterThan(highResult.evidenceCompleteness, lowResult.evidenceCompleteness)
  }

  func testDetailedCareerScoreRewardsQualityAndPenalizesObligations() {
    let stats = FounderStats()
    let strong = SimulationEngine.careerScore(
      stats: stats, verifiedEvidence: 12, completedObjectives: 8,
      averageRelationship: 80, unresolvedObligations: 0, completedVentures: 2
    )
    let fragile = SimulationEngine.careerScore(
      stats: stats, verifiedEvidence: 2, completedObjectives: 1,
      averageRelationship: 30, unresolvedObligations: 5, completedVentures: 2
    )
    XCTAssertGreaterThan(strong, fragile)
  }

  // ── careerScore: the actual fix, verified numerically ───────────────

  func testCareerScoreCapsRevenueContribution() {
    var highRevenue = FounderStats()
    highRevenue.revenue = 20_000
    highRevenue.momentum = 0
    highRevenue.trust = 0
    highRevenue.energy = 0
    highRevenue.trackRecord = 0

    let score = SimulationEngine.careerScore(stats: highRevenue)

    XCTAssertEqual(score, 5_000)
    XCTAssertLessThan(score, 20_000, "revenue must no longer contribute 1:1 uncapped")
  }

  func testCareerScoreLowRevenueStillContributesProportionally() {
    var modestRevenue = FounderStats()
    modestRevenue.revenue = 400
    modestRevenue.momentum = 0
    modestRevenue.trust = 0
    modestRevenue.energy = 0
    modestRevenue.trackRecord = 0

    XCTAssertEqual(SimulationEngine.careerScore(stats: modestRevenue), 100)
  }

  func testCareerScoreNeverGoesNegative() {
    var empty = FounderStats()
    empty.revenue = 0
    empty.momentum = 0
    empty.trust = 0
    empty.energy = 0
    empty.trackRecord = 0
    XCTAssertGreaterThanOrEqual(SimulationEngine.careerScore(stats: empty), 0)
  }

  func testCareerScoreRewardsProtectingTrustAndMomentumMeaningfully() {
    var highRevenueLowTrust = FounderStats()
    highRevenueLowTrust.revenue = 20_000
    highRevenueLowTrust.trust = 0
    highRevenueLowTrust.momentum = 0

    var modestRevenueHighTrust = FounderStats()
    modestRevenueHighTrust.revenue = 2_000
    modestRevenueHighTrust.trust = 100
    modestRevenueHighTrust.momentum = 100

    let dominatedScore = SimulationEngine.careerScore(stats: highRevenueLowTrust)
    let protectedScore = SimulationEngine.careerScore(stats: modestRevenueHighTrust)

    XCTAssertLessThan(
      Double(dominatedScore) / Double(max(protectedScore, 1)), 2.0,
      "a revenue-heavy, zero-trust run should no longer blow out a trust-protecting run by more than 2x"
    )
  }

  // ── ContentLibrary: the extraction must not have lost or duplicated content ──

  func testContentLibraryContainsAllHundredAuthoredTasks() {
    XCTAssertEqual(ContentLibrary.taskPool(for: .scale).count, 100)
  }

  func testContentLibraryDilemmaCountUnchangedFromBuild4() {
    XCTAssertEqual(ContentLibrary.dilemmaPool.count, 12)
  }

  func testContentLibraryObjectiveCountUnchangedFromBuild4() {
    XCTAssertEqual(ContentLibrary.objectivePool.count, 6)
  }

  func testContentLibraryDilemmasAreEvenlySpreadAcrossChapters() {
    for chapter in VentureChapter.allCases {
      let count = ContentLibrary.dilemmaPool.filter { $0.chapter == chapter }.count
      XCTAssertEqual(count, 3, "\(chapter.name) should have exactly 3 dilemmas")
    }
  }

  func testInitialAgentsCarryRealPersonalityData() {
    for agent in ContentLibrary.initialAgents {
      XCTAssertNotEqual(agent.archetype, "AI Teammate", "\(agent.id) should have real personality, not the generic default")
      XCTAssertFalse(agent.traits.isEmpty)
    }
  }

  func testTaskPoolTitlesAreUnique() {
    let titles = ContentLibrary.allTaskPool.map(\.title)
    XCTAssertEqual(Set(titles).count, titles.count, "duplicate task titles would break the repeat-spacing exclusion logic")
  }
}
