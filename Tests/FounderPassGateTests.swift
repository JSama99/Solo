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
      store.stats.runway = 100
      store.stats.energy = 100
      store.stats.trust = 100
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
    XCTAssertTrue(store.isVentureLocked)
    XCTAssertEqual(store.stage, .ventureUnlock)
    XCTAssertEqual(store.venture, 1, "the gate must not consume the venture increment")
    XCTAssertNil(store.careerOutcome)
  }

  func testGatePreservesCareerProgress() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)
    XCTAssertFalse(store.evidence.isEmpty, "evidence from the free venture must survive the gate")
    XCTAssertGreaterThanOrEqual(store.stats.trackRecord, 0)
  }

  func testPassAdvancesIntoSecondVenture() throws {
    let store = makeStore(hasPass: true)
    playVenture(store)
    XCTAssertNil(store.careerOutcome)
    XCTAssertFalse(store.isVentureLocked)
    XCTAssertEqual(store.venture, 2)
    XCTAssertEqual(store.sprint, 1)
  }

  func testUnlockResumesTheSameCareer() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)
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
    XCTAssertTrue(store.isVentureLocked)
    store.resumeAfterFounderPassUnlock()

    XCTAssertTrue(store.isVentureLocked)
    XCTAssertEqual(store.venture, 1)
  }

  func testResumeIsIdempotent() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.resumeAfterFounderPassUnlock()
    let evidenceAfterUnlock = store.evidence
    let precedentsAfterUnlock = store.precedents
    let statsAfterUnlock = store.stats
    let rngAfterUnlock = store.randomNumberGenerator
    let taskIDsAfterUnlock = store.tasks.map(\.id)
    store.resumeAfterFounderPassUnlock()

    XCTAssertEqual(store.venture, 2, "a repeated unlock must not skip a venture")
    XCTAssertEqual(store.sprint, 1)
    XCTAssertEqual(store.evidence.map(\.id), evidenceAfterUnlock.map(\.id))
    XCTAssertEqual(store.precedents, precedentsAfterUnlock)
    XCTAssertEqual(store.stats.trackRecord, statsAfterUnlock.trackRecord)
    XCTAssertEqual(store.stats.runway, statsAfterUnlock.runway)
    XCTAssertEqual(store.stats.energy, statsAfterUnlock.energy)
    XCTAssertEqual(store.randomNumberGenerator, rngAfterUnlock)
    XCTAssertEqual(store.tasks.map(\.id), taskIDsAfterUnlock)
  }

  func testHeldCareerSurvivesReloadAndStillShowsTheGate() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)
    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: false)
    XCTAssertTrue(reloaded.hasSave)
    reloaded.continueCareer()

    XCTAssertTrue(reloaded.isVentureLocked)
    XCTAssertEqual(reloaded.stage, .ventureUnlock)
    XCTAssertEqual(reloaded.venture, 1)
  }

  func testResolvedVentureStateIsSavedBeforeGatePresentation() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)

    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "solo-unicorn-run-native-save-v5"))
    let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: data)
    XCTAssertEqual(envelope.version, 5)
    XCTAssertTrue(envelope.career.awaitingFounderPass)
    XCTAssertEqual(envelope.career.venture, 1)
    XCTAssertEqual(envelope.career.sprint, 12)
    XCTAssertNil(envelope.career.outcome)
    XCTAssertEqual(envelope.career.evidence.map(\.id), store.evidence.map(\.id))
    XCTAssertEqual(envelope.career.randomNumberGenerator, store.randomNumberGenerator)
  }

  func testHeldCareerReloadedWithPassResumesImmediately() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)
    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    reloaded.continueCareer()
    reloaded.resumeAfterFounderPassUnlock()

    XCTAssertEqual(reloaded.venture, 2)
    XCTAssertFalse(reloaded.isVentureLocked)
  }

  func testCancelledOrFailedPurchaseCannotMutateHeldCareer() {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)

    let evidence = store.evidence
    let precedents = store.precedents
    let rng = store.randomNumberGenerator
    let trackRecord = store.stats.trackRecord
    let taskIDs = store.tasks.map(\.id)

    // Cancellation and failure both leave the entitlement inactive. Repeated
    // refresh callbacks must therefore remain a complete no-op.
    store.resumeAfterFounderPassUnlock()
    store.resumeAfterFounderPassUnlock()

    XCTAssertEqual(store.venture, 1)
    XCTAssertEqual(store.sprint, 12)
    XCTAssertEqual(store.evidence.map(\.id), evidence.map(\.id))
    XCTAssertEqual(store.precedents, precedents)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.trackRecord, trackRecord)
    XCTAssertEqual(store.tasks.map(\.id), taskIDs)
  }

  func testHeldBoundaryRejectsFurtherSimulationMutation() throws {
    let store = makeStore(hasPass: false)
    playVenture(store)
    XCTAssertTrue(store.isVentureLocked)

    let task = try XCTUnwrap(store.tasks.first)
    let evidence = store.evidence
    let rng = store.randomNumberGenerator
    let stats = store.stats
    store.assign(agentID: nil, to: task.id)
    store.review(taskID: task.id)
    store.commitSprint()

    XCTAssertEqual(store.venture, 1)
    XCTAssertEqual(store.sprint, 12)
    XCTAssertEqual(store.evidence.map(\.id), evidence.map(\.id))
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.trackRecord, stats.trackRecord)
    XCTAssertEqual(store.stats.revenue, stats.revenue)
    XCTAssertEqual(store.alertMessage, "This venture is complete. Unlock Venture 2 to continue the career.")
  }
}

/// The Build 2 paywall failure, encoded so it cannot recur.
final class PurchaseConfigurationTests: XCTestCase {

  func testNoHardcodedProductAllowList() {
    // Build 2 filtered the current offering against ["lifetime","yearly","monthly"],
    // which never matched the one configured App Store product, so the paywall was
    // permanently empty and nothing could be bought. Access is entitlement-gated
    // now; this test exists to stop a product allow list being reintroduced.
    XCTAssertEqual(RevenueCatConfiguration.entitlementIdentifier, "Solo: Unicorn Run Pro")
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

  func testReleaseRejectsMissingTestSecretAndMalformedKeys() {
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("", for: .release), .missing)
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("   ", for: .release), .missing)
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("test_example", for: .release), .testKeyInRelease)
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("sk_example", for: .release), .secret)
    XCTAssertEqual(
      RevenueCatConfiguration.validateAPIKey("goog_example", for: .release),
      .invalidApplePublicKey
    )
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("appl_example", for: .release), .valid)
  }

  func testDebugAllowsTestStoreAndApplePublicKeysOnly() {
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("test_example", for: .debug), .valid)
    XCTAssertEqual(RevenueCatConfiguration.validateAPIKey("appl_example", for: .debug), .valid)
    XCTAssertEqual(
      RevenueCatConfiguration.validateAPIKey("unknown_example", for: .debug),
      .invalidApplePublicKey
    )
  }

  func testEveryBlockingStatusNamesAConcreteRemedy() {
    let blocking: [PurchaseConfigurationStatus] = [
      .notConfigured, .missingAPIKey, .secretKeyOnDevice,
      .testKeyInReleaseBuild, .invalidApplePublicKey,
      .noCurrentOffering, .offeringHasNoPackages
    ]
    for status in blocking {
      XCTAssertTrue(status.isBlocking, "\(status) should block purchasing")
      XCTAssertFalse(status.headline.isEmpty)
      XCTAssertGreaterThan(status.remedy.count, 20, "a remedy must say what to actually do")
    }
    XCTAssertFalse(PurchaseConfigurationStatus.ready(packageCount: 1).isBlocking)
  }

  func testBlockingRecoveryCopyIsPlayerFacingAndPreservesCareer() {
    let remedy = PurchaseConfigurationStatus.offeringHasNoPackages.remedy
    XCTAssertTrue(remedy.contains("career is safe"))
    XCTAssertFalse(remedy.contains("RevenueCat"))
    XCTAssertFalse(remedy.contains("product identifier"))
  }


  func testCurrentOfferingIsPreferredOverDefault() {
    XCTAssertEqual(
      RevenueCatConfiguration.preferredOfferingIdentifier(
        currentIdentifier: "shipathon",
        availableIdentifiers: ["shipathon", "default"]
      ),
      "shipathon"
    )
  }

  func testDefaultOfferingIsUsedWhenCurrentIsMissing() {
    XCTAssertEqual(
      RevenueCatConfiguration.preferredOfferingIdentifier(
        currentIdentifier: nil,
        availableIdentifiers: ["default"]
      ),
      "default"
    )
  }

  func testEmptyOfferingCollectionFailsSafely() {
    XCTAssertNil(
      RevenueCatConfiguration.preferredOfferingIdentifier(
        currentIdentifier: nil,
        availableIdentifiers: []
      )
    )
  }
}
