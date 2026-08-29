import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class EnvironmentalInteractionTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    UserDefaults.standard.removeObject(forKey: GameStore.environmentalSaveKey)
    super.tearDown()
  }

  func testGarageOwnsFounderObjectsButCompanyCommandOwnsAgentStations() {
    XCTAssertEqual(FounderEnvironmentalObject.allCases.map(\.rawValue), ["couch", "workoutBench"])
    XCTAssertTrue(CompanyCommandFocus.agent("aurora") != .founder)
    XCTAssertTrue(FounderEnvironmentLayout(viewportSize: CGSize(width: 390, height: 844)).anchors[.founderCouch] != nil)
    XCTAssertTrue(FounderEnvironmentLayout(viewportSize: CGSize(width: 390, height: 844)).anchors[.workoutBench] != nil)
  }

  func testCouchRestoresEnergyAndChargesOperatingBurnOnce() {
    let store = activeStore()
    store.stats.energy = 50
    store.stats.runway = 20
    let before = store.stats
    XCTAssertTrue(store.performEnvironmentalAction(.rest, now: Date(timeIntervalSince1970: 100)))
    XCTAssertEqual(store.stats.energy, before.energy + FounderEnvironmentalTuning.restEnergy)
    XCTAssertEqual(store.stats.momentum, before.momentum + FounderEnvironmentalTuning.restMomentum)
    XCTAssertEqual(store.stats.runway, before.runway - 1)
    let saved = try! XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.environmentalSaveKey))
    XCTAssertEqual(try! JSONDecoder().decode(FounderEnvironmentalSave.self, from: saved).elapsedHours, FounderEnvironmentalTuning.restHours)
    XCTAssertFalse(store.performEnvironmentalAction(.rest, now: Date(timeIntervalSince1970: 101)))
  }

  func testWorkoutCostsEnergyAndBuildsMomentumOnce() {
    let store = activeStore()
    store.stats.energy = 60
    let before = store.stats
    XCTAssertTrue(store.performEnvironmentalAction(.train, now: Date(timeIntervalSince1970: 200)))
    XCTAssertEqual(store.stats.energy, before.energy + FounderEnvironmentalTuning.trainingEnergy)
    XCTAssertEqual(store.stats.momentum, before.momentum + FounderEnvironmentalTuning.trainingMomentum)
    XCTAssertFalse(store.performEnvironmentalAction(.train, now: Date(timeIntervalSince1970: 201)))
  }

  func testEnvironmentalCooldownSurvivesRelaunch() {
    let store = activeStore()
    XCTAssertTrue(store.performEnvironmentalAction(.train, now: Date(timeIntervalSince1970: 300)))
    let relaunched = GameStore()
    relaunched.startCareer(seed: 9)
    XCTAssertFalse(relaunched.environmentalPreview(for: .train, now: Date(timeIntervalSince1970: 301)).available)
  }

  func testCancellationPreviewDoesNotMutate() {
    let store = activeStore()
    let before = store.stats
    _ = store.environmentalPreview(for: .rest)
    XCTAssertEqual(store.stats, before)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 32_709)
    store.confirmVentureThesisIfNeeded()
    return store
  }
}
