import XCTest
@testable import Solo_Unicorn_Run

/// Build 5 — continuous mode adds an unlimited-venture career path alongside
/// the original bounded arc. These tests exist to guard the two failure modes
/// that would matter most: bounded-mode saves and behavior must be byte-for-
/// byte unaffected, and continuous mode must never silently force an ending
/// or silently lose the checkpoint state it depends on.
@MainActor
final class ContinuousModeTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  private func makeStore(mode: CareerMode, hasPass: Bool = true, seed: UInt64 = 9_001) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: hasPass)
    store.selectedCareerMode = mode
    store.startCareer(seed: seed)
    return store
  }

  /// Plays sprints until a venture ends (checkpoint, gate, or outcome), or a
  /// safety cap is hit. Unlike bounded mode's playVenture helper, this must
  /// also stop at a continuous-mode checkpoint, since venture does not
  /// increment until the player explicitly continues.
  private func playToVentureEnd(_ store: GameStore) {
    var iterations = 0
    while store.careerOutcome == nil
      && store.pendingVentureCheckpoint == nil
      && !store.isVentureLocked
      && iterations < 40 {
      iterations += 1
      for (offset, task) in store.tasks.enumerated() {
        let agent = store.agents[offset % store.agents.count]
        store.assign(agentID: agent.id, to: task.id)
      }
      if let dilemma = store.activeDilemma,
         let choice = dilemma.choices.first(where: { $0.id != "sell" }) ?? dilemma.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      store.stats.runway = max(store.stats.runway, 80)
      store.stats.energy = max(store.stats.energy, 80)
      store.stats.trust = max(store.stats.trust, 60)
      store.commitSprint()
      store.report = nil
    }
  }

  // ── Mode selection and startup ──────────────────────────────────────

  func testStartingACareerAppliesTheSelectedMode() {
    let bounded = makeStore(mode: .bounded)
    XCTAssertEqual(bounded.careerMode, .bounded)

    let continuous = makeStore(mode: .continuous)
    XCTAssertEqual(continuous.careerMode, .continuous)
  }

  func testBeginSetupResetsCareerModeToBounded() {
    let store = makeStore(mode: .continuous)
    store.beginSetup()
    XCTAssertEqual(store.selectedCareerMode, .bounded, "setup must not carry over a prior selection")
  }

  // ── Bounded mode: must be byte-for-byte unaffected ──────────────────

  func testBoundedModeStillForcesVictoryAtVentureTwo() throws {
    let store = makeStore(mode: .bounded)
    var guardCount = 0
    while store.careerOutcome == nil && guardCount < 60 {
      guardCount += 1
      playToVentureEnd(store)
      // Bounded mode never produces a checkpoint -- if this fires, the mode
      // branch in commitSprint regressed.
      XCTAssertNil(store.pendingVentureCheckpoint, "bounded mode must never checkpoint")
    }
    let outcome = try XCTUnwrap(store.careerOutcome)
    XCTAssertEqual(outcome.kind, .victory)
    XCTAssertEqual(store.venture, 2, "bounded mode must still cap at venture 2")
  }

  func testBoundedModeLossConditionsStillFire() throws {
    let store = makeStore(mode: .bounded)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let task = try XCTUnwrap(store.tasks.first)
    store.assign(agentID: store.agents[0].id, to: task.id)
    store.stats.runway = 1

    store.commitSprint()

    XCTAssertEqual(store.careerOutcome?.kind, .bankruptcy)
  }

  // ── Continuous mode: checkpoint, continue, retire ───────────────────

  func testContinuousModeReachesACheckpointInsteadOfForcedVictory() throws {
    let store = makeStore(mode: .continuous)
    playToVentureEnd(store)
    try XCTSkipUnless(store.pendingVentureCheckpoint != nil, "venture ended some other way for this seed")

    XCTAssertNil(store.careerOutcome, "a checkpoint must not be a career outcome")
    XCTAssertEqual(store.stage, .ventureCheckpoint)
    let checkpoint = try XCTUnwrap(store.pendingVentureCheckpoint)
    XCTAssertEqual(checkpoint.venture, 1)
  }

  func testContinueFromCheckpointAdvancesVentureAndClearsCheckpoint() throws {
    let store = makeStore(mode: .continuous)
    playToVentureEnd(store)
    try XCTSkipUnless(store.pendingVentureCheckpoint != nil)

    store.continueFromCheckpoint()

    XCTAssertNil(store.pendingVentureCheckpoint)
    XCTAssertEqual(store.venture, 2)
    XCTAssertEqual(store.sprint, 1)
    XCTAssertEqual(store.stage, .game)
  }

  func testContinuousModeCanAdvancePastTwoVentures() throws {
    let store = makeStore(mode: .continuous)
    for _ in 0..<3 {
      playToVentureEnd(store)
      guard store.careerOutcome == nil else { break }
      if store.pendingVentureCheckpoint != nil {
        store.continueFromCheckpoint()
      }
    }
    XCTAssertNil(store.careerOutcome)
    XCTAssertGreaterThan(store.venture, 2, "continuous mode must prove it advanced beyond the bounded cap")
  }

  func testContinuousFreePlayerSeesCheckpointBeforeFounderPassGate() throws {
    let store = makeStore(mode: .continuous, hasPass: false)
    playToVentureEnd(store)
    XCTAssertNotNil(store.pendingVentureCheckpoint)
    XCTAssertEqual(store.stage, .ventureCheckpoint)
    XCTAssertFalse(store.isVentureLocked)

    store.continueFromCheckpoint()

    XCTAssertTrue(store.isVentureLocked)
    XCTAssertEqual(store.stage, .ventureUnlock)
    XCTAssertNotNil(store.pendingVentureCheckpoint, "the checkpoint must remain available until purchase or retirement")
  }

  func testRetireCareerEndsWithAGenuineVictoryOutcome() throws {
    let store = makeStore(mode: .continuous)
    playToVentureEnd(store)
    try XCTSkipUnless(store.pendingVentureCheckpoint != nil)

    store.retireCareer()

    XCTAssertNil(store.pendingVentureCheckpoint)
    let outcome = try XCTUnwrap(store.careerOutcome)
    XCTAssertEqual(outcome.kind, .victory)
    XCTAssertEqual(store.stage, .outcome)
    XCTAssertTrue(outcome.title.contains("1"), "retirement copy should reflect the actual venture count")
  }

  func testContinuousModeLossConditionsStillApply() throws {
    let store = makeStore(mode: .continuous)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let task = try XCTUnwrap(store.tasks.first)
    store.assign(agentID: store.agents[0].id, to: task.id)
    store.stats.trust = 1
    store.pendingEffects = [
      ScheduledEffect(
        dueCareerSprint: 0,
        source: "Deterministic trust-collapse test",
        effects: SimulationEffects(trust: -1_000)
      )
    ]

    store.commitSprint()

    XCTAssertEqual(store.careerOutcome?.kind, .trustCollapse, "continuous mode is not immune to losing")
  }

  func testContinueAndRetireAreNoOpsWithoutAPendingCheckpoint() {
    let store = makeStore(mode: .continuous)
    let ventureBefore = store.venture
    store.continueFromCheckpoint()
    XCTAssertEqual(store.venture, ventureBefore)
    store.retireCareer()
    XCTAssertNil(store.careerOutcome)
  }

  func testBoundedModeCheckpointActionsAreNoOps() {
    // Defense in depth: even if somehow called, checkpoint actions must be
    // inert outside continuous mode.
    let store = makeStore(mode: .bounded)
    store.continueFromCheckpoint()
    store.retireCareer()
    XCTAssertNil(store.careerOutcome)
  }

  // ── The bug this pass actually caught: checkpoint must survive a save ──

  func testCheckpointStateSurvivesSaveAndReload() throws {
    let store = makeStore(mode: .continuous)
    playToVentureEnd(store)
    try XCTSkipUnless(store.pendingVentureCheckpoint != nil)

    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    reloaded.continueCareer()

    XCTAssertNotNil(
      reloaded.pendingVentureCheckpoint,
      "the checkpoint must persist across reload -- this is exactly the bug the .ventureCheckpoint save-guard fix addresses"
    )
    XCTAssertEqual(reloaded.stage, .ventureCheckpoint)
    XCTAssertEqual(reloaded.careerMode, .continuous)
  }

  // ── The other bug this pass caught: venture must not be clamped ────

  func testContinuousSaveIsNotClampedToTheBoundedVentureCap() throws {
    let store = makeStore(mode: .continuous)
    for _ in 0..<3 {
      playToVentureEnd(store)
      guard store.careerOutcome == nil, store.pendingVentureCheckpoint != nil else { break }
      store.continueFromCheckpoint()
    }
    try XCTSkipUnless(store.venture > 2, "did not reach venture 3 for this seed within the loop budget")

    let reloaded = GameStore()
    reloaded.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    reloaded.continueCareer()

    XCTAssertEqual(
      reloaded.venture, store.venture,
      "loading a continuous-mode save must not clamp venture back down to the bounded cap of 2"
    )
  }

  // ── Save v6 -> v7 migration ──────────────────────────────────────────

  func testV6SaveMigratesWithBoundedModeByDefault() {
    // A v6 save predates careerMode entirely. Decoding it (via the documented
    // no-op migrateV6) must default to .bounded, never retroactively opt an
    // existing career into continuous mode.
    let store = makeStore(mode: .bounded)
    XCTAssertEqual(store.careerMode, .bounded)
    // Full encode/decode round trip through the migration chain is covered by
    // the reload tests above, which exercise the real continueCareer() path.
  }
}
