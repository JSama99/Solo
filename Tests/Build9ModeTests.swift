import XCTest
@testable import Solo_Unicorn_Run

final class Build9ModeTests: XCTestCase {
  func testDailySeedIsStableForSameUTCDay() {
    let date = Date(timeIntervalSince1970: 1_785_945_600)
    XCTAssertEqual(DailyChallenge.seed(for: date), DailyChallenge.seed(for: date))
  }

  func testDailySeedDiffersAcrossUTCDays() {
    let first = Date(timeIntervalSince1970: 1_785_945_600)
    let second = first.addingTimeInterval(86_400)
    XCTAssertNotEqual(DailyChallenge.seed(for: first), DailyChallenge.seed(for: second))
  }

  func testEraMappingBoundaries() {
    XCTAssertEqual(VentureEra.era(for: 1), .garage)
    XCTAssertEqual(VentureEra.era(for: 10), .garage)
    XCTAssertEqual(VentureEra.era(for: 11), .traction)
    XCTAssertEqual(VentureEra.era(for: 60), .dynasty)
    XCTAssertEqual(VentureEra.era(for: 61), .dynasty)
  }

  func testExistingCareerRawValuesRemainStable() {
    XCTAssertEqual(CareerMode.bounded.rawValue, "bounded")
    XCTAssertEqual(CareerMode.continuous.rawValue, "continuous")
    XCTAssertEqual(CareerMode(rawValue: "continuous"), .continuous)
  }
}
