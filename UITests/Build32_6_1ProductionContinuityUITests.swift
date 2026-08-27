import XCTest

final class Build32_6_2ProductionContinuityUITests: XCTestCase {
  func testProductionFounderDeskDeviceContinuity() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()

    enterFreshProductionCareer(in: app)

    let workspace = app.buttons["founder-desk-device-computer"]
    XCTAssertTrue(workspace.waitForExistence(timeout: 8))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("01_FOUNDER_DESK_OVERVIEW", in: app)

    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    XCTAssertTrue(app.buttons["founder-computer-look-out"].isHittable)
    XCTAssertTrue(app.staticTexts["Founder Computer"].exists)
    capture("02_FOUNDER_COMPUTER_FOCUSED", in: app)
    returnToDesk(from: .computer, in: app)

    let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.44))
    let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.66, dy: 0.48))
    dragStart.press(forDuration: 0.08, thenDragTo: dragEnd)

    let cameraControls = app.buttons["free-look-camera-controls"]
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    for control in ["chevron.left", "viewfinder", "chevron.right", "free-look-return-computer"] {
      XCTAssertTrue(app.buttons[control].waitForExistence(timeout: 3), "Missing Look Out control: \(control)")
    }
    app.buttons["chevron.left"].tap()
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["viewfinder"].tap()
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["chevron.right"].tap()
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["viewfinder"].tap()

    focusDevice(.phone, expectedTitle: "Tech.com iPhone", in: app)
    XCTAssertTrue(app.navigationBars["Tech.com"].waitForExistence(timeout: 4))
    capture("03_TECHCOM_IPHONE_FOCUSED", in: app)
    returnToDesk(from: .phone, in: app)

    focusDevice(.tablet, expectedTitle: "Venture iPad", in: app)
    XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'Venture'")).firstMatch.waitForExistence(timeout: 4))
    capture("04_VENTURE_IPAD_FOCUSED", in: app)
    returnToDesk(from: .tablet, in: app)

    focusDevice(.server, expectedTitle: "Company Server", in: app)
    let serverDestinations = [
      "Evidence Ledger", "Agent Operations", "Achievements", "Headquarters Progress",
      "Company Story", "Solo Pro", "Settings", "How to Play", "Restart Career"
    ]
    for destination in serverDestinations {
      XCTAssertTrue(revealServerButton(named: destination, in: app), "Missing server module: \(destination)")
    }
    capture("05_COMPANY_SERVER_FOCUSED", in: app)
    returnToDesk(from: .server, in: app)
    XCTAssertTrue(app.buttons["founder-desk-device-computer"].exists)
  }

  private func focusDevice(_ target: FocusedDevice, expectedTitle: String, in app: XCUIApplication) {
    let device = app.buttons["founder-desk-device-\(target.rawValue)"]
    XCTAssertTrue(device.waitForExistence(timeout: 5), "Missing \(expectedTitle) desk object")
    device.tap()
    let close = target == .computer
      ? app.buttons["founder-computer-look-out"]
      : app.buttons["return-to-founder-desk-\(target.rawValue)"]
    assertAccessibleTouchTarget(close)
    XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
  }

  private func returnToDesk(from device: FocusedDevice, in app: XCUIApplication) {
    let close = device == .computer
      ? app.buttons["founder-computer-look-out"]
      : app.buttons["return-to-founder-desk-\(device.rawValue)"]
    assertAccessibleTouchTarget(close)
    close.tap()
    XCTAssertTrue(app.buttons["founder-desk-device-computer"].waitForExistence(timeout: 4))
  }

  private func assertAccessibleTouchTarget(
    _ element: XCUIElement,
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
    let settledTarget = XCTNSPredicateExpectation(
      predicate: NSPredicate { object, _ in
        guard let candidate = object as? XCUIElement else { return false }
        return candidate.exists
          && candidate.isEnabled
          && candidate.frame.width >= 44
          && candidate.frame.height >= 44
      },
      object: element
    )
    XCTAssertEqual(XCTWaiter.wait(for: [settledTarget], timeout: timeout), .completed, file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.width, 44, file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.height, 44, file: file, line: line)
  }

  private func serverButton(named name: String, in app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", name)).firstMatch
  }

  private func revealServerButton(named name: String, in app: XCUIApplication) -> Bool {
    let button = serverButton(named: name, in: app)
    for _ in 0..<5 where !button.exists {
      app.swipeUp()
    }
    return button.exists
  }

  private enum FocusedDevice: String {
    case computer
    case phone
    case tablet
    case server
  }

  /// SwiftUI's scaled monitor can briefly report a visible nested button as
  /// non-hittable even though its accessibility frame is on screen. Drive the
  /// production control through that live frame instead of a brittle constant.
  private func tapVisibleFrame(of element: XCUIElement, in app: XCUIApplication) -> Bool {
    let frame = element.frame
    let appFrame = app.frame
    guard !frame.isEmpty, appFrame.intersects(frame), appFrame.width > 0, appFrame.height > 0 else { return false }
    app.coordinate(withNormalizedOffset: CGVector(
      dx: (frame.midX - appFrame.minX) / appFrame.width,
      dy: (frame.midY - appFrame.minY) / appFrame.height
    )).tap()
    return true
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
