import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class DivergenceSystemTests: XCTestCase {
  func testPressureIsMonotonicClampedAndHandlesInvalidHorizon() {
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: -2), 0)
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: 0), 0)
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: 1), 0.25)
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: 4), 1)
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: 99), 1)
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: 0, horizon: 0), 1)
    XCTAssertEqual(Divergence.pressure(sprintsSinceFork: 0, horizon: -1), 1)
  }

  func testMixedAndCoordinatesAreStableAndDistinct() {
    XCTAssertEqual(SeededRandomNumberGenerator.mixed(42), SeededRandomNumberGenerator.mixed(42))
    XCTAssertNotEqual(SeededRandomNumberGenerator.mixed(42), SeededRandomNumberGenerator.mixed(43))
    let a = coordinate(task: "A", agent: "stacks", salt: 0)
    let b = coordinate(task: "B", agent: "stacks", salt: 0)
    XCTAssertEqual(a.key, a.key)
    XCTAssertNotEqual(a.key, b.key)
  }

  func testControlledExperimentMatchesAtForkAndDivergesOutward() {
    let task = SoloTask(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "Build", detail: "Fixture", role: .engineering, impact: .momentum(8))
    let agent = SoloAgent(id: "stacks", name: "Stacks", initials: "ST", role: .engineering, modelFamily: "Nova", reliability: 80, calibration: 0.75, drift: 5, trust: 65)
    var canonicalRNG = SeededRandomNumberGenerator(seed: 1)
    var ghostRNG = SeededRandomNumberGenerator(seed: 999)
    let canonical = SimulationEngine.makeResult(for: task, agent: agent, intent: .build, doctrine: .guided, correlatedFailureEvent: nil, allTasks: [task], allAgents: [agent], coordinate: coordinate(task: task.id.uuidString, agent: agent.id, salt: 0), sprintsSinceFork: 0, rng: &canonicalRNG)
    let ghost = SimulationEngine.makeResult(for: task, agent: agent, intent: .build, doctrine: .guided, correlatedFailureEvent: nil, allTasks: [task], allAgents: [agent], coordinate: coordinate(task: task.id.uuidString, agent: agent.id, salt: 123), sprintsSinceFork: 0, rng: &ghostRNG)
    XCTAssertEqual(canonical, ghost)

    for offset in 0...4 {
      let count = (0..<10_000).filter { index in
        Divergence.diverges(at: coordinate(task: "task-\(index)", agent: "agent", salt: 123), sprintsSinceFork: offset)
      }.count
      XCTAssertEqual(Double(count) / 10_000, Divergence.pressure(sprintsSinceFork: offset), accuracy: 0.025)
    }
  }

  func testGhostPoliciesAndCopycatProfile() {
    let profile = DoctrineProfile(verificationRate: 0.41, unverifiedShipRate: 0.7, roleFitDiscipline: 0.8, restDiscipline: 0.2, evidenceThreshold: 0.5, relationshipInvestment: 0.5)
    XCTAssertGreaterThan(GhostPolicy.policy(for: .quietBuilder, profile: profile).verificationRate, 0.9)
    XCTAssertLessThan(GhostPolicy.policy(for: .hypeMachine, profile: profile).verificationRate, 0.1)
    let copycat = GhostPolicy.policy(for: .copycat, profile: profile)
    XCTAssertEqual(copycat.verificationRate, 0.41)
    XCTAssertTrue(copycat.prefersRoleFit)
    XCTAssertTrue(copycat.shipsRisk)
  }

  func testPerfectContextProducesPerfectHindsightSimilarity() {
    let context = PrecedentContext(doctrine: .guided, intent: .learn, driftBand: .high, runwayBand: .low, unverifiedBand: .medium)
    let precedent = Precedent(id: HindsightEngine.identifier(venture: 1, sprint: 2), venture: 1, sprint: 2, context: context, decisionSummary: "Facts", outcome: PrecedentOutcome())
    XCTAssertEqual(HindsightEngine.similarity(precedent, context), 1)
  }

  func testV17PurgeListsCannotDrift() {
    XCTAssertEqual(GameStore.saveCareerPurgeKeys, GameStore.resetCareerPurgeKeys)
    XCTAssertEqual(GameStore.saveVersion, 19)
  }

  func testDivergenceBranchContainsNoRestorableCareerSnapshot() {
    let propertyNames = Set(Mirror(reflecting: emptyBranch()).children.compactMap(\.label))
    XCTAssertFalse(propertyNames.contains("save"))
    XCTAssertFalse(propertyNames.contains("careerSave"))
  }

  func testV16ShapeDecodesNewFieldsWithDefaultsAndPreservesReportCache() throws {
    let task = SoloTask(id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!, title: "Legacy", detail: "Fixture", role: .engineering, impact: .momentum(2))
    let result = TaskResult(actualQuality: 50, reportedQuality: 61, evidenceCompleteness: 40, correlatedFailureIdentifier: nil, immediateEffects: SimulationEffects(), delayedEffects: SimulationEffects(), confidenceLowerBound: 40, confidenceUpperBound: 70, knownOperationalRisk: "Fixture")
    let cached = CachedTaskReport(venture: 1, sprint: 2, taskID: task.id, agentID: "stacks", intent: .build, result: result)
    let save = CareerSave(founderName: "Legacy", doctrine: .guided, sprint: 2, venture: 1, intent: .build, stats: FounderStats(), agents: ContentLibrary.initialAgents, tasks: [task], evidence: [], outcome: nil, randomNumberGenerator: SeededRandomNumberGenerator(seed: 5), correlatedFailureEvent: nil, pendingEffects: [], reportCache: [cached])
    let data = try JSONEncoder().encode(save)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    ["activeDivergence", "divergenceRecords", "forksUsedThisVenture", "latentDefects", "doctrineProfile", "unicornIdentity", "rivalDiscontinuities"].forEach { object.removeValue(forKey: $0) }
    let migrated = try JSONDecoder().decode(CareerSave.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertEqual(migrated.reportCache, [cached])
    XCTAssertNil(migrated.activeDivergence)
    XCTAssertEqual(migrated.divergenceRecords, [])
    XCTAssertEqual(migrated.latentDefects, [])
    XCTAssertEqual(migrated.rivalDiscontinuities, [])
  }

  func testEraForcesChangeRulesWithoutRandomness() {
    let context = EraContext(unverifiedCount: 2, averageDrift: 60, profile: .neutral, flags: [.featureDebt])
    var garage = SimulationEffects()
    VentureEra.garage.force.modify(&garage, context: context)
    XCTAssertEqual(garage, SimulationEffects())
    var scrutiny = SimulationEffects()
    VentureEra.marketLeader.force.modify(&scrutiny, context: context)
    XCTAssertEqual(scrutiny.trust, -4)
    var dynasty = SimulationEffects()
    VentureEra.dynasty.force.modify(&dynasty, context: context)
    XCTAssertEqual(dynasty.runway, -2)
  }

  func testRivalDiscontinuitiesMechanicallyChangeField() {
    let companies = [
      RivalCompany(id: "inc", name: "Inc", archetype: .incumbent, debutVenture: 1, baseStrength: 2),
      RivalCompany(id: "up", name: "Up", archetype: .upstart, debutVenture: 1, baseStrength: 1)
    ]
    let acquisition = RivalDiscontinuity(id: "a", kind: .acquisition, primaryRivalID: "inc", secondaryRivalID: "up", venture: 2, sprint: 12, headline: "Facts")
    let standings = RivalEngine.standings(companies: companies, venture: 2, sprint: 12, careerSeed: 7, player: FounderStats(), playerFlags: [], discontinuities: [acquisition])
    XCTAssertFalse(standings.contains { $0.id == "up" })
    XCTAssertTrue(standings.contains { $0.id == "inc" })
  }

  func testGhostRunStaysOffRenderBudget() {
    let tasks = Array(ContentLibrary.taskPool.prefix(3))
    let profile = DoctrineProfile.neutral
    let clock = ContinuousClock()
    let start = clock.now
    for _ in 0..<100 {
      _ = SimulationEngine.runGhost(tasks: tasks, agents: ContentLibrary.initialAgents, intent: .build, doctrine: .guided, careerSeed: 8, forkVenture: 2, forkSprint: 4, choice: .shipAll, policy: GhostPolicy.policy(for: .copycat, profile: profile), horizon: 4)
    }
    let elapsed = start.duration(to: clock.now)
    XCTAssertLessThan(elapsed, .seconds(1), "100 ghost runs should remain comfortably outside a frame-scale concern")
  }

  func testShipAllExecutesScriptedBoundedDivergenceExactlyOnce() throws {
    let store = divergenceStore(seed: 71_001)
    let assignedBefore = store.tasks.filter { $0.assignedAgentID != nil }.count

    XCTAssertTrue(store.chooseDivergence(.shipAll))
    let branch = try XCTUnwrap(store.activeDivergence)
    XCTAssertEqual(branch.takenChoice, .shipAll)
    XCTAssertEqual(branch.ghostRival.archetype, .copycat)
    XCTAssertEqual(store.tasks.filter { $0.assignedAgentID != nil }.count, assignedBefore)
    XCTAssertNil(store.pendingDivergenceOffer)
    XCTAssertEqual(store.forksUsedThisVenture, 1)

    XCTAssertFalse(store.chooseDivergence(.holdUnverified))
    XCTAssertEqual(store.activeDivergence?.takenChoice, .shipAll)
    XCTAssertEqual(store.forksUsedThisVenture, 1)
    commitChosenDivergence(in: store, suiteName: "divergence-ship-all")
    XCTAssertNotNil(store.report)
  }

  func testHoldUnverifiedExecutesScriptedBoundedDivergenceExactlyOnce() throws {
    let store = divergenceStore(seed: 71_002)
    let assignedBefore = store.tasks.filter { $0.assignedAgentID != nil }.count

    XCTAssertTrue(store.chooseDivergence(.holdUnverified))
    let branch = try XCTUnwrap(store.activeDivergence)
    XCTAssertEqual(branch.takenChoice, .holdUnverified)
    XCTAssertEqual(branch.ghostRival.archetype, .copycat)
    XCTAssertEqual(store.tasks.filter { $0.assignedAgentID != nil }.count, assignedBefore - 1)
    XCTAssertTrue(branch.takenSummary.contains("held"))
    XCTAssertNil(store.pendingDivergenceOffer)
    XCTAssertEqual(store.forksUsedThisVenture, 1)

    XCTAssertFalse(store.chooseDivergence(.holdUnverified))
    XCTAssertEqual(store.tasks.filter { $0.assignedAgentID != nil }.count, assignedBefore - 1)
    XCTAssertEqual(store.forksUsedThisVenture, 1)
    commitChosenDivergence(in: store, suiteName: "divergence-hold-unverified")
    XCTAssertNotNil(store.report)
  }

  private func coordinate(task: String, agent: String, salt: UInt64) -> DrawCoordinate {
    DrawCoordinate(careerSeed: 77, venture: 3, sprint: 7, taskInstanceID: task, agentID: agent, channel: .quality, divergenceSalt: salt)
  }

  private func divergenceStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    store.sprint = 6
    if let choice = store.activeDilemma?.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
    for (index, task) in store.tasks.prefix(store.agents.count).enumerated() {
      store.assign(agentID: store.agents[index].id, to: task.id)
    }
    store.pendingDivergenceOffer = DivergenceOffer(
      id: "FORK-V1-S6",
      venture: 1,
      sprint: 6,
      context: PrecedentContext(
        doctrine: .guided,
        intent: .build,
        driftBand: .low,
        runwayBand: .high,
        unverifiedBand: .medium
      )
    )
    return store
  }

  private func commitChosenDivergence(in store: GameStore, suiteName: String) {
    let presentation = PresentationCoordinator(timing: .immediate)
    let progressionDefaults = UserDefaults(suiteName: suiteName)!
    progressionDefaults.removePersistentDomain(forName: suiteName)
    let progression = FounderProgressionStore(defaults: progressionDefaults, saveKey: "progress")
    presentation.commit(in: store, progression: progression)
    XCTAssertNotNil(presentation.visibleSprintResult)
  }

  private func emptyBranch() -> DivergenceBranch {
    let context = PrecedentContext(doctrine: .guided, intent: .build, driftBand: .low, runwayBand: .high, unverifiedBand: .low)
    let rival = RivalCompany(id: "copy", name: "Copy", archetype: .copycat, debutVenture: 1, baseStrength: 1)
    let policy = GhostPolicy.policy(for: .copycat, profile: .neutral)
    return DivergenceBranch(id: "fork", venture: 1, sprint: 6, context: context, takenChoice: .shipAll, takenSummary: "Facts", takenOutcome: PrecedentOutcome(), ghostRival: rival, ghostPolicy: policy, ghostOutcome: DivergenceOutcome(summary: "Facts", outcome: PrecedentOutcome(), effects: SimulationEffects(), resolutions: 0), collapsedAtCareerSprint: 10)
  }
}
