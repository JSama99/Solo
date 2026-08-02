import XCTest
@testable import Solo_Unicorn_Run

/// Build 3 — the Founder Pass must gate real content, and the purchase stack
/// must never again fail silently.
@MainActor
final class FounderPassGateTests: XCTestCase {
  override func tearDown() {
    GameStore().resetCareer()
    super.tearDown()
  }

  private func makeStore(hasPass: Bool, seed: UInt64 = 4_242) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: hasPass)
    store.startCareer(seed: seed)
    return store
  }

  /// Plays sprints until the venture ends, the career ends, or the gate holds.
  private func playVenture(_ store: GameStore) {
    var iterations = 0
    while store.careerOutcome == nil && !store.isVentureLocked && iterations < 40 {
      iterations += 1
      let startingVenture = store.venture
      for (offset, task) in store.tasks.enumerated() {
        let agent = store.agents[offset % store.agents.count]
        store.assign(agentID: agent.id, to: task.id)
      }
      store.commitSprint()
      store.report = nil
      if store.venture != startingVenture { return }
    }
  }

  func testFreeVentureIsFullyPlayable() {
    let store = makeStore(hasPass: false)
    XCTAssertEqual(store.venture, 1)
    XCTAssertFalse(store.isVentureLocked)
    playVenture(store)
    XCTAssertEqual(store.venture, 1, "the free venture must never advance past venture 1")
  }

  func testGateHoldsCareerWithoutPass() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked, "career ended on merit before reaching the gate")

    XCTAssertEqual(store.stage, .ventureUnlock)
    XCTAssertEqual(store.venture, 1, "the gate must not consume the venture increment")
    XCTAssertNil(store.careerOutcome)
  }

  func testGatePreservesCareerProgress() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked)

    XCTAssertFalse(store.evidence.isEmpty, "evidence from the free venture must survive the gate")
    XCTAssertGreaterThanOrEqual(store.stats.trackRecord, 0)
  }

  func testPassAdvancesIntoSecondVenture() throws {
    let store = makeStore(hasPass: true)
    playVenture(store)
    try XCTSkipUnless(store.careerOutcome == nil, "career ended on merit before the venture boundary")

    XCTAssertFalse(store.isVentureLocked)
    XCTAssertEqual(store.venture, 2)
    XCTAssertEqual(store.sprint, 1)
  }

  func testUnlockResumesTheSameCareer() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked)

    let evidenceBefore = store.evidence.count
    let precedentsBefore = store.precedents.count

    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.resumeAfterFounderPassUnlock()

    XCTAssertEqual(store.venture, 2)
    XCTAssertEqual(store.sprint, 1)
    XCTAssertFalse(store.isVentureLocked)
    XCTAssertGreaterThanOrEqual(store.evidence.count, evidenceBefore, "unlocking must not reset the career")
    XCTAssertEqual(store.precedents.count, precedentsBefore, "banked precedents must carry forward")
  }

  func testResumeWithoutPassDoesNothing() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked)

    store.resumeAfterFounderPassUnlock()

    XCTAssertTrue(store.isVentureLocked)
    XCTAssertEqual(store.venture, 1)
  }

  func testResumeIsIdempotent() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked)

    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.resumeAfterFounderPassUnlock()
    store.resumeAfterFounderPassUnlock()

    XCTAssertEqual(store.venture, 2, "a repeated unlock must not skip a venture")
  }

  func testHeldCareerSurvivesReloadAndStillShowsTheGate() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked)

    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: false)
    XCTAssertTrue(reloaded.hasSave)
    reloaded.continueCareer()

    XCTAssertTrue(reloaded.isVentureLocked)
    XCTAssertEqual(reloaded.stage, .ventureUnlock)
    XCTAssertEqual(reloaded.venture, 1)
  }

  func testHeldCareerReloadedWithPassResumesImmediately() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    try XCTSkipUnless(store.isVentureLocked)

    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    reloaded.continueCareer()
    reloaded.resumeAfterFounderPassUnlock()

    XCTAssertEqual(reloaded.venture, 2)
    XCTAssertFalse(reloaded.isVentureLocked)
  }
}

/// The Build 2 paywall failure, encoded so it cannot recur.
final class PurchaseConfigurationTests: XCTestCase {

  func testNoHardcodedProductAllowList() {
    // Build 2 filtered the current offering against ["lifetime","yearly","monthly"],
    // which never matched the one configured App Store product, so the paywall was
    // permanently empty and nothing could be bought. Access is entitlement-gated
    // now; this test exists to stop a product allow list being reintroduced.
    XCTAssertEqual(RevenueCatConfiguration.entitlementIdentifier, "solo_unicorn_run_pro")
    XCTAssertEqual(
      RevenueCatConfiguration.expectedStoreProductIdentifier,
      "com.talonsight.solounicornrun.founderpass"
    )
  }

  func testKeyClassification() {
    XCTAssertTrue(RevenueCatConfiguration.isTestStoreKey("test_abc"))
    XCTAssertTrue(RevenueCatConfiguration.isAppleProductionKey("appl_abc"))
    XCTAssertTrue(RevenueCatConfiguration.isSecretKey("sk_abc"))
    XCTAssertFalse(RevenueCatConfiguration.isSecretKey("appl_abc"))
    XCTAssertFalse(RevenueCatConfiguration.isAppleProductionKey(""))
  }

  func testEveryBlockingStatusNamesAConcreteRemedy() {
    let blocking: [PurchaseConfigurationStatus] = [
      .notConfigured, .missingAPIKey, .secretKeyOnDevice,
      .testKeyInReleaseBuild, .noCurrentOffering, .offeringHasNoPackages
    ]
    for status in blocking {
      XCTAssertTrue(status.isBlocking, "\(status) should block purchasing")
      XCTAssertFalse(status.headline.isEmpty)
      XCTAssertGreaterThan(status.remedy.count, 20, "a remedy must say what to actually do")
    }
    XCTAssertFalse(PurchaseConfigurationStatus.ready(packageCount: 1).isBlocking)
  }

  func testMissingPackageRemedyNamesTheRealProduct() {
    let remedy = PurchaseConfigurationStatus.offeringHasNoPackages.remedy
    XCTAssertTrue(remedy.contains(RevenueCatConfiguration.expectedStoreProductIdentifier))
  }
}
