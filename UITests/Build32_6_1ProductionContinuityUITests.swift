import XCTest

final class Build32_6_2ProductionContinuityUITests: XCTestCase {
  func testProductionCommandFocusFreeLookContinuity() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--build-32-6-2-production-proof"]
    app.launch()

    enterFreshProductionCareer(in: app)

    let lookOut = app.buttons["Look Out"]
    XCTAssertTrue(lookOut.waitForExistence(timeout: 8))

    let activeStationPrepared = prepareVisibleProductionActivity(in: app)
    XCTAssertTrue(lookOut.waitForExistence(timeout: 5))
    capture("11_PRODUCTION_COMMAND_FOCUS", in: app)
    capture("14_PRODUCTION_ALL_THREE_COMMAND_MONITOR", in: app)

    // Recording starts externally after launch stabilization and before this
    // pause ends, keeping the production interaction free of launch snapshots.
    sleep(20)
    lookOut.tap()
    usleep(140_000)
    capture("12_PRODUCTION_LOOK_OUT_TRANSITION", in: app)

    let founderComputer = app.buttons["Founder Computer"]
    XCTAssertTrue(founderComputer.waitForExistence(timeout: 4))
    sleep(1)
    capture("01_PRODUCTION_CENTERED_FREE_LOOK", in: app)
    capture("05_PRODUCTION_FOUNDER_DESK_STORYTELLING", in: app)
    capture(activeStationPrepared ? "10_PRODUCTION_ACTIVE_FOCAL_HIERARCHY" : "09_PRODUCTION_IDLE_TONAL_HIERARCHY", in: app)

    let lookLeft = app.buttons["Look Left"]
    let center = app.buttons["Center"]
    let lookRight = app.buttons["Look Right"]
    XCTAssertTrue(lookLeft.exists)
    XCTAssertTrue(center.exists)
    XCTAssertTrue(lookRight.exists)

    lookLeft.tap()
    sleep(1)
    capture("02_PRODUCTION_AURORA_AUTHORED_STATION", in: app)
    capture("06_PRODUCTION_LOCAL_LIGHT_VALUE_HIERARCHY", in: app)
    center.tap()
    sleep(1)
    capture("03_PRODUCTION_STACKS_AUTHORED_STATION", in: app)
    capture("07_PRODUCTION_MATERIAL_SURFACE_BREAKUP", in: app)
    capture("08_PRODUCTION_DIEGETIC_DEVICE_DOCKS", in: app)
    lookRight.tap()
    sleep(1)
    capture("04_PRODUCTION_BRIO_AUTHORED_STATION", in: app)
    capture("15_PRODUCTION_BACKGROUND_RECESSION", in: app)
    center.tap()
    sleep(1)
    capture("13_PRODUCTION_RETURNED_FREE_LOOK", in: app)

    app.buttons["Return to Founder Computer"].tap()
    XCTAssertTrue(lookOut.waitForExistence(timeout: 5))
    // Leave a stable focused tail so external recording can stop before the
    // XCTest host tears the production app down.
    sleep(8)
  }

  private func prepareVisibleProductionActivity(in app: XCUIApplication) -> Bool {
    let founderChoice = app.buttons["Narrow the Claim"]
    if founderChoice.exists {
      let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.74))
      let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.38))
      for _ in 0..<2 {
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)
        usleep(220_000)
      }
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.26, dy: 0.46)).tap()
      sleep(1)
      for _ in 0..<2 {
        dragEnd.press(forDuration: 0.05, thenDragTo: dragStart)
        usleep(120_000)
      }
      guard !founderChoice.exists else { return false }
    }

    let commit = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] 'COMMIT SPRINT'")
    ).firstMatch
    if commit.waitForExistence(timeout: 2), commit.isHittable, commit.isEnabled {
      commit.tap()
      sleep(2)
    }

    let stacks = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH[c] 'Stacks,' AND label CONTAINS[c] 'station'")
    ).firstMatch
    if stacks.waitForExistence(timeout: 3), stacks.isHittable {
      stacks.tap()
    } else {
      // The overview intentionally combines each illustrated station into one
      // accessibility element. XCTest can briefly classify that element as
      // non-hittable while the full-screen spatial transition settles, so use
      // the stable center bay coordinate as the production interaction fallback.
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.25)).tap()
    }

    let assign = app.buttons["Assign Task"]
    guard assign.waitForExistence(timeout: 3), assign.isHittable, assign.isEnabled else { return false }
    assign.tap()
    let sheetAssign = app.buttons["Assign"].firstMatch
    guard sheetAssign.waitForExistence(timeout: 3), sheetAssign.isHittable, sheetAssign.isEnabled else { return false }
    sheetAssign.tap()
    return app.buttons["Look Out"].waitForExistence(timeout: 5)
  }

  private func enterFreshProductionCareer(in app: XCUIApplication) {
    let chooseMode = app.buttons["Choose Mode"]
    XCTAssertTrue(chooseMode.waitForExistence(timeout: 5))
    chooseMode.tap()

    let career = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH[c] 'Career'")
    ).firstMatch
    XCTAssertTrue(career.waitForExistence(timeout: 5))
    career.tap()

    let openGarage = app.buttons["Open the Garage"]
    for _ in 0..<8 where !openGarage.isHittable {
      app.swipeUp()
      usleep(220_000)
    }
    XCTAssertTrue(openGarage.isHittable)
    openGarage.tap()

    let beginVenture = app.buttons["Begin Venture"]
    XCTAssertTrue(beginVenture.waitForExistence(timeout: 5))
    beginVenture.tap()
  }

  private func capture(_ name: String, in app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
