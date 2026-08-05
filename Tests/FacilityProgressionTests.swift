import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class FacilityProgressionTests: XCTestCase {
  func testFacilityTierOrdering() {
    XCTAssertEqual(FacilityTier.allCases.map(\.rawValue), Array(0...5))
    XCTAssertEqual(FacilityTier.founderGarage.next, .founderLoft)
    XCTAssertNil(FacilityTier.unicornHeadquarters.next)
  }

  func testApprovedBuild2Requirements() {
    let configuration = FacilityProgressionConfiguration.build2
    XCTAssertEqual(configuration.requirement(for: .founderLoft).minimumTrackRecord, 8)
    XCTAssertEqual(configuration.requirement(for: .founderLoft).capitalCost, 4_000)
    XCTAssertEqual(configuration.requirement(for: .smallOffice).completedCareers, 1)
    XCTAssertEqual(configuration.requirement(for: .unicornHeadquarters).minimumTrackRecord, 20)
    XCTAssertEqual(configuration.requirement(for: .unicornHeadquarters).capitalCost, 8_000)
    XCTAssertEqual(configuration.requirement(for: .unicornHeadquarters).completedCareers, 4)
  }

  func testFutureEnvironmentBlocksBuild2Purchase() {
    let context = makeStore()
    context.store.observe(trackRecord: 20)
    XCTAssertEqual(
      context.store.purchaseResult(for: .founderLoft, availableCapital: 10_000),
      .futureEnvironment
    )
  }

  func testFacilityUnlockEligibilityAndPurchaseRequirements() {
    let context = makeStore(configuration: availableConfiguration())
    XCTAssertEqual(
      context.store.purchaseResult(for: .founderLoft, availableCapital: 3_999),
      .trackRecordRequired(8)
    )
    context.store.observe(trackRecord: 8)
    XCTAssertEqual(
      context.store.purchaseResult(for: .founderLoft, availableCapital: 3_999),
      .insufficientCapital(4_000)
    )
    XCTAssertEqual(
      context.store.purchase(.founderLoft, availableCapital: 4_000),
      .purchased(cost: 4_000)
    )
    XCTAssertTrue(context.store.ownedFacilities.contains(.founderLoft))
  }

  func testCompletedCareerRecordingIsIdempotent() {
    let context = makeStore()
    context.store.beginCareer()
    XCTAssertTrue(context.store.recordCareerCompletion(trackRecord: 14))
    XCTAssertFalse(context.store.recordCareerCompletion(trackRecord: 14))
    XCTAssertEqual(context.store.completedCareerCount, 1)

    let relaunched = FounderProgressionStore(defaults: context.defaults, saveKey: context.key)
    XCTAssertFalse(relaunched.recordCareerCompletion(trackRecord: 14))
    XCTAssertEqual(relaunched.completedCareerCount, 1)
  }

  func testNewCareerCanBeCountedAfterPreviousCompletion() {
    let context = makeStore()
    context.store.beginCareer()
    XCTAssertTrue(context.store.recordCareerCompletion(trackRecord: 10))
    context.store.beginCareer()
    XCTAssertTrue(context.store.recordCareerCompletion(trackRecord: 15))
    XCTAssertEqual(context.store.completedCareerCount, 2)
    XCTAssertEqual(context.store.highestTrackRecord, 15)
  }

  func testProgressionSurvivesCareerRestart() {
    let context = makeStore()
    context.store.beginCareer()
    context.store.recordCareerCompletion(trackRecord: 12)
    GameStore().resetCareer()
    let relaunched = FounderProgressionStore(defaults: context.defaults, saveKey: context.key)
    XCTAssertEqual(relaunched.completedCareerCount, 1)
    XCTAssertEqual(relaunched.highestTrackRecord, 12)
    XCTAssertTrue(relaunched.ownedFacilities.contains(.founderGarage))
  }

  func testGarageEquipmentProgression() {
    XCTAssertEqual(GarageEquipmentStage.derive(venture: 1, trackRecord: 0, capital: 2_500), .startup)
    XCTAssertEqual(GarageEquipmentStage.derive(venture: 2, trackRecord: 8, capital: 4_000), .operating)
    XCTAssertEqual(GarageEquipmentStage.derive(venture: 2, trackRecord: 18, capital: 7_000), .established)
  }

  private func makeStore(
    configuration: FacilityProgressionConfiguration = .build2
  ) -> (store: FounderProgressionStore, defaults: UserDefaults, key: String) {
    let suite = "FacilityProgressionTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let key = "progression"
    return (
      FounderProgressionStore(defaults: defaults, saveKey: key, configuration: configuration),
      defaults,
      key
    )
  }

  private func availableConfiguration() -> FacilityProgressionConfiguration {
    var configuration = FacilityProgressionConfiguration.build2
    for tier in FacilityTier.allCases {
      var requirement = configuration.requirement(for: tier)
      requirement.environmentAvailable = true
      configuration.requirements[tier] = requirement
    }
    return configuration
  }
}
