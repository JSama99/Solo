import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build10HeadquartersTests: XCTestCase {
  func testDailyStreakUsesCalendarAcrossMonthBoundary() {
    let defaults = isolatedDefaults()
    let store = DailyChallengeStore(defaults: defaults)
    store.record(score: 10, date: date(2026, 1, 31))
    store.record(score: 12, date: date(2026, 2, 1))
    XCTAssertEqual(store.save.currentStreak, 2)
  }

  func testDailyStorePersistsToInjectedDefaults() {
    let defaults = isolatedDefaults()
    DailyChallengeStore(defaults: defaults).record(score: 42, date: date(2026, 2, 28))
    XCTAssertEqual(DailyChallengeStore(defaults: defaults).save.bestScore, 42)
  }

  func testDailyStreakUsesUTCAcrossDSTBoundary() {
    let store = DailyChallengeStore(defaults: isolatedDefaults())
    store.record(score: 10, date: Date(timeIntervalSince1970: 1_773_085_200))
    store.record(score: 12, date: Date(timeIntervalSince1970: 1_773_171_600))
    XCTAssertEqual(store.save.currentStreak, 2)
  }

  func testEveryFacilityUpgradeHasADefinition() {
    XCTAssertEqual(FacilityUpgradeDefinition.all.count, FacilityUpgradeID.allCases.count)
    XCTAssertEqual(FacilityUpgradeDefinition.definitions.count, FacilityUpgradeID.allCases.count)
  }

  func testFacilityPurchaseDeductsCapitalAndPersists() {
    let defaults = isolatedDefaults()
    let progression = FounderProgressionStore(defaults: defaults, saveKey: "progress")
    progression.observe(trackRecord: 8)
    let store = GameStore()
    store.progressionStore = progression
    store.stats.capital = 4_500
    XCTAssertEqual(store.purchaseFacility(.founderLoft), .purchased(cost: 4_000))
    XCTAssertEqual(store.stats.capital, 500)
    XCTAssertTrue(FounderProgressionStore(defaults: defaults, saveKey: "progress").ownedFacilities.contains(.founderLoft))
  }

  func testInsufficientCapitalAndDuplicatePurchasesFail() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "progress")
    XCTAssertEqual(progression.upgradePurchaseResult(for: .developmentRig, availableCapital: 799), .insufficientCapital(800))
    XCTAssertEqual(progression.purchaseUpgrade(.developmentRig, availableCapital: 800), .purchased(cost: 800))
    XCTAssertEqual(progression.purchaseUpgrade(.developmentRig, availableCapital: 800), .alreadyOwned)
  }

  func testActiveFacilityControlsGarageBonuses() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "progress")
    _ = progression.purchaseUpgrade(.developmentRig, availableCapital: 800)
    XCTAssertEqual(progression.bonuses.engineeringQualityBonus, 4)
    progression.observe(trackRecord: 8)
    _ = progression.purchase(.founderLoft, availableCapital: 4_000)
    XCTAssertEqual(progression.bonuses.engineeringQualityBonus, 0)
    XCTAssertEqual(progression.bonuses.ventureEnergyBonus, 5)
    XCTAssertTrue(progression.activate(.founderGarage))
    XCTAssertEqual(progression.bonuses.engineeringQualityBonus, 4)
  }

  func testLateTasksAreGatedFromGarageEra() {
    let garageTasks = ContentLibrary.taskPool(for: .garage).filter { ($0.minimumEra?.rawValue ?? 0) <= VentureEra.garage.rawValue }
    XCTAssertFalse(garageTasks.contains(where: { $0.title == "Shard the Data Layer" }))
    XCTAssertTrue(ContentLibrary.taskPool(for: .scale).contains(where: { $0.title == "Shard the Data Layer" && $0.minimumEra == .scale }))
  }

  func testAgentLevelCurveAndStressBandsAreCentralized() {
    XCTAssertEqual(AgentLevel.level(forXP: 0), 1)
    XCTAssertEqual(AgentLevel.level(forXP: 100), 2)
    XCTAssertEqual(AgentLevel.level(forXP: 700), 5)
    XCTAssertEqual(AgentStressBand.band(for: 24), .focused)
    XCTAssertEqual(AgentStressBand.band(for: 25), .stable)
    XCTAssertEqual(AgentStressBand.band(for: 75), .overloaded)
    XCTAssertEqual(AgentStressBand.band(for: 90), .critical)
  }

  func testAgentProgressionMigratesFromPreBuild11AgentData() throws {
    let json = """
    {"id":"aurora","name":"Aurora","initials":"AU","role":"Research","modelFamily":"Nova-1","reliability":78,"calibration":0.72,"drift":0,"trust":62}
    """
    let agent = try JSONDecoder().decode(SoloAgent.self, from: Data(json.utf8))
    XCTAssertEqual(agent.progression.xp, 0)
    XCTAssertEqual(agent.progression.stressLevel, 0)
    XCTAssertFalse(agent.progression.ambitionCompleted)
  }

  func testGarageAndLoftWorkforceModifiersAreActiveOnlyAtCurrentFacility() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "workforce")
    _ = progression.purchaseUpgrade(.developmentRig, availableCapital: 800)
    XCTAssertEqual(progression.bonuses.agentXPBonusMultiplier, 1.1)
    XCTAssertEqual(progression.bonuses.stressAccumulationMultiplier, 1)
    progression.observe(trackRecord: 8)
    _ = progression.purchase(.founderLoft, availableCapital: 4_000)
    XCTAssertEqual(progression.bonuses.agentXPBonusMultiplier, 1)
    XCTAssertEqual(progression.bonuses.stressAccumulationMultiplier, 0.9)
  }

  func testAgentProgressionEarnsXPAndStressFromCommittedWork() {
    let store = GameStore()
    store.startCareer(seed: 99)
    store.confirmVentureThesisIfNeeded()
    let task = store.tasks[0]
    let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
    store.assign(agentID: agent.id, to: task.id)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let before = store.agents.first(where: { $0.id == agent.id })!.progression
    store.commitSprint()
    let after = store.agents.first(where: { $0.id == agent.id })!.progression
    XCTAssertGreaterThan(after.xp, before.xp)
    XCTAssertGreaterThanOrEqual(after.stressLevel, 0)
    XCTAssertLessThanOrEqual(after.stressLevel, 100)
  }

  func testSpecializationRequiresLevelAndLocksToOneBranch() {
    let store = GameStore()
    store.startCareer(seed: 101)
    guard let index = store.agents.firstIndex(where: { $0.id == "aurora" }) else { return XCTFail("Missing Aurora") }
    store.selectAgentPerk(.sourceTriangulation, for: "aurora")
    XCTAssertTrue(store.agents[index].progression.selectedPerks.isEmpty)
    store.agents[index].progression.xp = 100
    store.selectAgentPerk(.sourceTriangulation, for: "aurora")
    store.selectAgentPerk(.signalDetection, for: "aurora")
    XCTAssertTrue(store.agents[index].progression.selectedPerks.contains(.sourceTriangulation))
    XCTAssertFalse(store.agents[index].progression.selectedPerks.contains(.signalDetection))
  }

  private func isolatedDefaults() -> UserDefaults {
    let suite = "Build10Tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
  }
}
