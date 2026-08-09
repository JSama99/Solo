import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class ModeSelectTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  func testDailyModeRoutesThroughDailyChallengeStart() {
    let store = GameStore()
    store.startMode(.daily)

    XCTAssertEqual(store.stage, .game)
    XCTAssertEqual(store.careerMode, .daily)
    XCTAssertEqual(store.selectedCareerMode, .daily)
  }

  func testCareerModeRoutesToBoundedFounderSetup() {
    let store = GameStore()
    store.startMode(.bounded)

    XCTAssertEqual(store.stage, .setup)
    XCTAssertEqual(store.selectedCareerMode, .bounded)
  }

  func testEmpireModeRoutesToContinuousFounderSetup() {
    let store = GameStore()
    store.startMode(.continuous)

    XCTAssertEqual(store.stage, .setup)
    XCTAssertEqual(store.selectedCareerMode, .continuous)
  }
}
