import XCTest
@testable import Solo_Unicorn_Run

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
    XCTAssertEqual(GameStore.saveVersion, 17)
  }

  func testDivergenceBranchContainsNoRestorableCareerSnapshot() {
    let propertyNames = Set(Mirror(reflecting: emptyBranch()).children.compactMap(\.label))
    XCTAssertFalse(propertyNames.contains("save"))
    XCTAssertFalse(propertyNames.contains("careerSave"))
  }

  private func coordinate(task: String, agent: String, salt: UInt64) -> DrawCoordinate {
    DrawCoordinate(careerSeed: 77, venture: 3, sprint: 7, taskInstanceID: task, agentID: agent, channel: .quality, divergenceSalt: salt)
  }

  private func emptyBranch() -> DivergenceBranch {
    let context = PrecedentContext(doctrine: .guided, intent: .build, driftBand: .low, runwayBand: .high, unverifiedBand: .low)
    let rival = RivalCompany(id: "copy", name: "Copy", archetype: .copycat, debutVenture: 1, baseStrength: 1)
    let policy = GhostPolicy.policy(for: .copycat, profile: .neutral)
    return DivergenceBranch(id: "fork", venture: 1, sprint: 6, context: context, takenChoice: .shipAll, takenSummary: "Facts", takenOutcome: PrecedentOutcome(), ghostRival: rival, ghostPolicy: policy, ghostOutcome: DivergenceOutcome(summary: "Facts", outcome: PrecedentOutcome(), effects: SimulationEffects(), resolutions: 0), collapsedAtCareerSprint: 10)
  }
}
