import XCTest

final class Build32_6_1ProductionContinuityUITests: XCTestCase {
  func testProductionCommandFocusFreeLookContinuity() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--build-32-6-1-production-proof"]
    app.launch()

    let continueCareer = app.buttons["Continue Career"]
    if continueCareer.waitForExistence(timeout: 5) {
      continueCareer.tap()
    }

    let lookOut = app.buttons["Look Out"]
    XCTAssertTrue(lookOut.waitForExistence(timeout: 8))

    // Recording starts externally after launch stabilization and before this
    // pause ends, keeping the production interaction free of launch snapshots.
    sleep(30)
    lookOut.tap()

    let founderComputer = app.buttons["Founder Computer"]
    XCTAssertTrue(founderComputer.waitForExistence(timeout: 4))
    sleep(2)

    let lookLeft = app.buttons["Look Left"]
    let center = app.buttons["Center"]
    let lookRight = app.buttons["Look Right"]
    XCTAssertTrue(lookLeft.exists)
    XCTAssertTrue(center.exists)
    XCTAssertTrue(lookRight.exists)

    lookLeft.tap()
    sleep(2)
    center.tap()
    sleep(2)
    lookRight.tap()
    sleep(2)
    center.tap()
    sleep(2)

    app.buttons["Return to Founder Computer"].tap()
    XCTAssertTrue(lookOut.waitForExistence(timeout: 5))
    // Leave a stable focused tail so external recording can stop before the
    // XCTest host tears the production app down.
    sleep(12)
  }
}
