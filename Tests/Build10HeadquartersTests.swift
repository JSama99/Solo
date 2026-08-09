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
