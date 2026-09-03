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

  /// P0 audit (Task 2): a tier with no built environment is now purchasable —
  /// it charges rent and grants its mechanical payload — but the player does
  /// not visually move in. `currentFacility` drives the entire Living Company
  /// visual layer, so it must never advance to a tier without art.
  func testUnbuiltEnvironmentIsOwnableButNeverBecomesTheRenderedFacility() {
    let context = makeStore()
    context.store.observe(trackRecord: 20)
    XCTAssertEqual(
      context.store.purchaseResult(for: .founderLoft, availableCapital: 10_000),
      .purchased(cost: 4_000)
    )
    XCTAssertEqual(context.store.purchase(.founderLoft, availableCapital: 10_000), .purchased(cost: 4_000))
    XCTAssertTrue(context.store.ownedFacilities.contains(.founderLoft), "Ownership is granted")
    XCTAssertEqual(context.store.operatingTier, .founderLoft, "Mechanics follow ownership")
    XCTAssertEqual(context.store.currentFacility, .founderGarage, "Rendering stays on built art")
    XCTAssertFalse(context.store.activate(.founderLoft), "Cannot move into an unbuilt environment")
    XCTAssertEqual(context.store.currentFacility, .founderGarage)
  }

  /// The live build10 configuration: no owned tier may ever render without art.
  func testRenderedFacilityAlwaysHasABuiltEnvironment() {
    let context = makeStore(configuration: .build10)
    context.store.observe(trackRecord: 40)
    for _ in 0..<5 { context.store.beginCareer(); _ = context.store.recordCareerCompletion(trackRecord: 40) }
    for tier in FacilityTier.allCases where tier.rawValue > 0 {
      _ = context.store.purchase(tier, availableCapital: 500_000)
    }
    XCTAssertEqual(context.store.operatingTier, .unicornHeadquarters, "All tiers owned")
    XCTAssertTrue(
      FacilityProgressionConfiguration.build10.requirement(for: context.store.currentFacility).environmentAvailable,
      "The rendered facility must always be one with built art"
    )
    XCTAssertEqual(context.store.currentFacility, .founderLoft)
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

  // MARK: - operatingTier fallback reachability (BUILD33 closeout, Item 2)

  /// The raw decoder *can* produce an empty owned set. `decodeIfPresent ?? [...]`
  /// supplies its default only when the key is absent, not when it is present
  /// and empty — so a hand-edited or corrupted save can carry
  /// `"ownedFacilities": []` alongside a non-Garage `currentFacility`. This
  /// documents the hazard that the store is responsible for repairing.
  func testRawSaveDecoderCanProduceAnEmptyOwnedFacilitySet() throws {
    let json = """
    {"version":2,"currentFacility":5,"ownedFacilities":[],"highestTrackRecord":40,"completedCareerCount":4}
    """
    let decoded = try JSONDecoder().decode(FounderProgressionSave.self, from: Data(json.utf8))
    XCTAssertTrue(decoded.ownedFacilities.isEmpty, "The decoder alone does not repair an explicit empty set")
    XCTAssertEqual(decoded.currentFacility, .unicornHeadquarters)
  }

  /// …and `sanitize()` repairs exactly that combination on load, which is what
  /// makes `operatingTier`'s `?? .founderGarage` fallback unreachable through
  /// the store. If the `sanitize()` call were ever dropped from `init`, the
  /// fallback would go live and this test would fail.
  func testStoreRepairsEmptyOwnedFacilitiesOnLoadSoTheFallbackNeverFires() throws {
    let suite = "FallbackReachability-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let key = "progression"
    let json = """
    {"version":2,"currentFacility":5,"ownedFacilities":[],"highestTrackRecord":40,"completedCareerCount":4}
    """
    defaults.set(Data(json.utf8), forKey: key)

    let store = FounderProgressionStore(defaults: defaults, saveKey: key)

    XCTAssertFalse(store.ownedFacilities.isEmpty, "sanitize() must guarantee a non-empty owned set")
    XCTAssertTrue(store.ownedFacilities.contains(.founderGarage))
    XCTAssertEqual(store.currentFacility, .founderGarage,
                   "A rendered facility the player does not own must be reset")
    XCTAssertEqual(store.operatingTier, .founderGarage,
                   "operatingTier resolves from a real owned tier, not the nil-coalescing fallback")
    XCTAssertEqual(store.operatingTier.monthlyObligation, 0,
                   "Rent correctly follows the repaired ownership, so nothing is silently unpaid")
  }

  /// No code path removes from `ownedFacilities` — purchase only inserts, and
  /// sanitize only inserts. The Garage is therefore permanently owned once the
  /// store exists, which is the invariant the fallback's unreachability rests on.
  func testOwnedFacilitiesOnlyEverGrows() {
    let context = makeStore(configuration: .build10)
    context.store.observe(trackRecord: 40)
    for _ in 0..<5 { context.store.beginCareer(); _ = context.store.recordCareerCompletion(trackRecord: 40) }
    var previous = context.store.ownedFacilities
    XCTAssertTrue(previous.contains(.founderGarage))
    for tier in FacilityTier.allCases where tier.rawValue > 0 {
      _ = context.store.purchase(tier, availableCapital: 500_000)
      let current = context.store.ownedFacilities
      XCTAssertTrue(previous.isSubset(of: current), "Purchasing \(tier.name) must not drop an owned tier")
      XCTAssertTrue(current.contains(.founderGarage))
      XCTAssertFalse(current.isEmpty)
      previous = current
    }
    // Surviving a reload keeps the invariant.
    let reloaded = FounderProgressionStore(defaults: context.defaults, saveKey: context.key)
    XCTAssertEqual(reloaded.ownedFacilities, previous)
    XCTAssertEqual(reloaded.operatingTier, .unicornHeadquarters)
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
