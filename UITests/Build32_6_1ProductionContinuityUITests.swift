import XCTest

final class Build32_6_2ProductionContinuityUITests: XCTestCase {
  func testAuroraContinuousWorkSessionReturn() throws {
    try exerciseWorkSessionReturn(argument: "--work-session-qa-handoff", title: "Evidence Triage")
  }

  func testStacksContinuousWorkSessionReturn() throws {
    try exerciseWorkSessionReturn(argument: "--systems-review-qa-handoff", title: "Systems Review")
  }

  func testBrioContinuousWorkSessionReturn() throws {
    try exerciseWorkSessionReturn(argument: "--campaign-calibration-qa-handoff", title: "Campaign Calibration")
  }

  private func exerciseWorkSessionReturn(argument: String, title: String) throws {
    let app = XCUIApplication()
    app.launchArguments = [argument]
    app.launch()
    let review = app.buttons["Open Founder Review"].firstMatch
    for _ in 0..<8 where !review.isHittable { app.swipeUp() }
    XCTAssertTrue(review.waitForExistence(timeout: 5))
    review.tap()
    XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["CONTINUE"].exists, "Unfinished sessions must not offer Continue")
    let delegate = app.buttons["DELEGATE"]
    for _ in 0..<6 where !delegate.isHittable { app.swipeUp() }
    XCTAssertTrue(delegate.isHittable)
    delegate.tap()
    let next = app.buttons["CONTINUE"]
    for _ in 0..<6 where !next.isHittable { app.swipeUp() }
    XCTAssertTrue(next.waitForExistence(timeout: 5))
    capture("\(title)_COMPLETED_BEFORE_RETURN", in: app)
    // Reopen the completed sheet with zero Attention before continuing.
    // The actual production callback, not a pre-reviewed fixture, must reveal it.
    app.buttons["Close"].tap()
    XCTAssertTrue(app.staticTexts["0/2"].firstMatch.exists, "Completion must exhaust the fixture's remaining Attention")
    for _ in 0..<8 where !review.isHittable { app.swipeUp() }
    XCTAssertTrue(review.isEnabled)
    review.tap()
    XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    for _ in 0..<6 where !next.isHittable { app.swipeUp() }
    // Repeated production input must still dismiss and apply review only once.
    next.doubleTap()
    if argument.contains("campaign") {
      XCUIDevice.shared.press(.home)
      app.activate()
    }
    let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars[title])
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    let resolve = app.buttons["Resolve Founder Decision"].firstMatch
    for _ in 0..<8 where !resolve.isHittable { app.swipeUp() }
    XCTAssertTrue(resolve.waitForExistence(timeout: 5))
    XCTAssertTrue(resolve.isEnabled)
    XCTAssertTrue(app.staticTexts["Reviewed"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["CONTINUE"].exists)
    capture("\(title)_DISMISSED_REVIEWED_PRODUCTION", in: app)
    app.terminate()
  }

  func testBrioCampaignCalibrationProductionSequence() throws {
    let phases: [(String, String, String)] = [
      ("choice", "REVIEW WORK", "BRIO_CAMPAIGN_01_WORK_COMPLETE"),
      ("audience", "STEP 1 OF 3 · AUDIENCE", "BRIO_CAMPAIGN_02_AUDIENCE"),
      ("message", "STEP 2 OF 3 · MESSAGE", "BRIO_CAMPAIGN_03_MESSAGE"),
      ("preview", "CAMPAIGN PREVIEW", "BRIO_CAMPAIGN_04_PREVIEW"),
      ("complete", "CAMPAIGN CALIBRATION COMPLETE", "BRIO_CAMPAIGN_05_COMPLETE")
    ]
    for (phase, expected, evidenceName) in phases {
      let app = XCUIApplication()
      app.launchArguments = ["--campaign-calibration-qa-\(phase)"]
      app.launch()
      XCTAssertTrue(app.descendants(matching: .any)[expected].waitForExistence(timeout: 6), phase)
      capture(evidenceName, in: app)
      app.terminate()
    }

    for regression in [("report", "AI OPERATIONS FLOOR", "BRIO_CAMPAIGN_06_CANONICAL_RETURN"),
                       ("aurora", "Evidence Triage", "BRIO_CAMPAIGN_07_AURORA_REGRESSION"),
                       ("stacks", "Systems Review", "BRIO_CAMPAIGN_08_STACKS_REGRESSION")] {
      let app = XCUIApplication()
      if regression.0 == "report" { app.launchArguments = ["--campaign-calibration-qa-report"] }
      else if regression.0 == "aurora" { app.launchArguments = ["--work-session-qa-active"] }
      else { app.launchArguments = ["--systems-review-qa-active"] }
      app.launch()
      XCTAssertTrue(app.descendants(matching: .any)[regression.1].waitForExistence(timeout: 6))
      capture(regression.2, in: app)
      app.terminate()
    }
  }

  func testStacksSystemsReviewProductionSequence() throws {
    let phases: [(String, String, String)] = [
      ("choice", "REVIEW WORK", "STACKS_SYSTEMS_01_WORK_COMPLETE"),
      ("active", "DEPENDENCY BUILD", "STACKS_SYSTEMS_02_ACTIVE"),
      ("selected", "3/6", "STACKS_SYSTEMS_03_SELECTED"),
      ("complete", "SYSTEMS REVIEW COMPLETE", "STACKS_SYSTEMS_04_COMPLETE")
    ]
    for (phase, expected, evidenceName) in phases {
      let app = XCUIApplication()
      app.launchArguments = ["--systems-review-qa-\(phase)"]
      app.launch()
      XCTAssertTrue(app.descendants(matching: .any)[expected].waitForExistence(timeout: 6), phase)
      capture(evidenceName, in: app)
      app.terminate()
    }

    let report = XCUIApplication()
    report.launchArguments = ["--systems-review-qa-report"]
    report.launch()
    XCTAssertTrue(report.staticTexts["AI OPERATIONS FLOOR"].waitForExistence(timeout: 6))
    capture("STACKS_SYSTEMS_05_CANONICAL_RETURN", in: report)
    report.terminate()

    let aurora = XCUIApplication()
    aurora.launchArguments = ["--work-session-qa-active"]
    aurora.launch()
    XCTAssertTrue(aurora.navigationBars["Evidence Triage"].waitForExistence(timeout: 6))
    capture("STACKS_SYSTEMS_06_AURORA_REGRESSION", in: aurora)
    aurora.terminate()
  }

  func testEvidenceTriageDelegateLanguageUsesFounderFiction() throws {
    let app = XCUIApplication()
    app.terminate()
    app.launchArguments = ["--work-session-qa-choice"]
    app.launch()

    XCTAssertTrue(app.buttons["DELEGATE"].waitForExistence(timeout: 6))
    XCTAssertTrue(app.staticTexts["Let Aurora finalize the packet · Founder Attention -1"].exists)
    XCTAssertEqual(
      app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'preserves Founder Attention'")).count,
      0
    )
    XCTAssertEqual(
      app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'deterministic baseline'")).count,
      0
    )
    capture("WORK_SESSION_CAUSAL_DELEGATE_COPY", in: app)
    app.terminate()
  }

  func testEvidenceTriageProgressPresentationContinuity() throws {
    let app = XCUIApplication()
    app.terminate()
    app.launchArguments = ["--work-session-qa-active"]
    app.launch()

    XCTAssertTrue(app.navigationBars["Evidence Triage"].waitForExistence(timeout: 6))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'EVIDENCE 1 OF '")).firstMatch.exists
    )
    XCTAssertTrue(app.progressIndicators.firstMatch.exists)
    capture("WORK_SESSION_PROGRESS_PRESENTATION", in: app)
    app.terminate()
  }

  func testBuild3277AuthoredMotionAndLightingEvidence() throws {
    let fixtures: [(String, String)] = [
      ("Idle overview", "20_AGENT_IDLE"),
      ("Aurora assignment received", "21_AURORA_ASSIGNMENT"),
      ("Aurora working", "22_AURORA_WORKING"),
      ("Stacks working", "23_STACKS_WORKING"),
      ("Brio working", "24_BRIO_WORKING"),
      ("Awaiting Founder review", "25_AWAITING_REVIEW"),
      ("Review step one", "26_FOUNDER_REVIEW_CUE"),
      ("Reduce Motion endpoints", "27_REDUCE_MOTION")
    ]

    for (fixture, evidenceName) in fixtures {
      let app = XCUIApplication()
      app.terminate()
      app.launchArguments = ["--motion-qa-physical"]
      app.launchEnvironment["SOLO_MOTION_QA_FIXTURE"] = fixture
      app.launch()
      XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 6), "Failed to launch fixture: \(fixture)")
      capture(evidenceName, in: app)
      app.terminate()
    }

    let app = XCUIApplication()
    app.terminate()
    app.launchArguments = ["--motion-qa-physical"]
    app.launchEnvironment["SOLO_MOTION_QA_FIXTURE"] = "Idle overview"
    app.launch()
    XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 6))
    capture("28_MORNING_GARAGE", in: app)
    let night = app.buttons["Night"]
    XCTAssertTrue(night.waitForExistence(timeout: 4))
    night.tap()
    capture("29_NIGHT_GARAGE", in: app)
    app.terminate()
  }

  func testIdleGarageAmbientLifeHold() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()

    let continueCareer = app.buttons["Continue Career"]
    if continueCareer.waitForExistence(timeout: 5) {
      continueCareer.tap()
    } else {
      // This ambient-life proof must be independently runnable on a clean
      // simulator; XCTest does not guarantee class or method ordering.
      enterFreshProductionCareer(in: app)
    }

    let computer = app.buttons["founder-desk-device-computer"]
    let lookOut = app.buttons["founder-computer-look-out"]
    if lookOut.waitForExistence(timeout: 4) {
      lookOut.tap()
    }
    XCTAssertTrue(computer.waitForExistence(timeout: 6))
    capture("10A_IDLE_LIGHTING_EARLY", in: app)

    // Purposefully perform no gameplay action. External simulator recording
    // captures the independent fan, LED, screen, light, air, and agent rhythms.
    sleep(8)
    capture("10B_IDLE_LIGHTING_MIDDLE", in: app)
    sleep(8)
    capture("10C_IDLE_LIGHTING_LATE", in: app)
    XCTAssertTrue(computer.exists)
  }

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
    capture("02B_LOOK_OUT_CONTINUITY", in: app)

    // Hold on the production Garage long enough to prove the independent,
    // presentation-only idle rhythms in a continuous simulator recording.
    capture("06A_CENTERED_IDLE_EARLY", in: app)
    sleep(8)
    capture("06B_CENTERED_IDLE_MIDDLE", in: app)
    sleep(8)
    capture("06C_CENTERED_IDLE_LATE", in: app)

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
    capture("07_LEFT_AURORA_VIEW", in: app)
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["viewfinder"].tap()
    capture("08_CENTER_STACKS_VIEW", in: app)
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["chevron.right"].tap()
    capture("09_RIGHT_BRIO_SERVER_VIEW", in: app)

    let signalTV = app.buttons["signal-tv-hotspot"]
    assertAccessibleTouchTarget(signalTV)
    signalTV.tap()
    XCTAssertTrue(app.navigationBars["Signal TV"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["THE STARTUP WORLD BROADCAST"].waitForExistence(timeout: 3))
    capture("09A_SIGNAL_TV_PHYSICAL_BROADCAST", in: app)
    app.buttons["close-signal-tv-viewer"].tap()
    XCTAssertTrue(signalTV.waitForExistence(timeout: 4))

    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["viewfinder"].tap()

    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    cameraControls.tap()
    app.buttons["chevron.left"].tap()
    let fundingBoard = app.buttons["funding-board-hotspot"]
    assertAccessibleTouchTarget(fundingBoard)
    fundingBoard.tap()
    XCTAssertTrue(app.navigationBars["Founder Funding Board"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["GRANTS & FUNDRAISING"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["ELIGIBLE"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Deadline: 3 sprints"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["1 Attention"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Next: Submit the application."].waitForExistence(timeout: 3))
    capture("09B_FOUNDER_FUNDING_BOARD", in: app)
    app.buttons["close-funding-board-viewer"].tap()
    XCTAssertTrue(fundingBoard.waitForExistence(timeout: 4))

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

    revealCameraPosition("chevron.right", in: app)
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
    capture("10_RETURNED_FREE_LOOK", in: app)

    let returnToComputer = app.buttons["free-look-return-computer"]
    XCTAssertTrue(returnToComputer.waitForExistence(timeout: 3))
    if returnToComputer.isHittable {
      returnToComputer.tap()
    } else {
      XCTAssertTrue(tapVisibleFrame(of: returnToComputer, in: app))
    }
    XCTAssertTrue(app.buttons["founder-computer-look-out"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Founder Computer"].waitForExistence(timeout: 5))
    capture("11_RETURNED_COMMAND_FOCUS", in: app)
    returnToDesk(from: .computer, in: app)
    XCTAssertTrue(app.buttons["founder-desk-device-server"].exists)
    capture("12_PRESERVED_RIGHT_FREE_LOOK", in: app)
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

  private func revealCameraPosition(_ control: String, in app: XCUIApplication) {
    let cameraControls = app.buttons["free-look-camera-controls"]
    XCTAssertTrue(cameraControls.waitForExistence(timeout: 3))
    if control == "viewfinder" {
      if cameraControls.isHittable {
        cameraControls.tap()
      } else {
        // Returning from a right-edge focused device can leave SwiftUI's AX
        // frame stale for one layout pass. The production Free Look gesture
        // remains available and one world-width drag returns +1 to center.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.71, dy: 0.44))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.29, dy: 0.44))
        start.press(forDuration: 0.08, thenDragTo: end)
      }
      return
    }
    let target = app.buttons[control]
    for _ in 0..<3 where !target.exists {
      if cameraControls.isHittable {
        cameraControls.tap()
      } else {
        XCTAssertTrue(tapVisibleFrame(of: cameraControls, in: app))
      }
      _ = target.waitForExistence(timeout: 1)
    }
    XCTAssertTrue(target.waitForExistence(timeout: 3))
    if target.isHittable {
      target.tap()
    } else {
      XCTAssertTrue(tapVisibleFrame(of: target, in: app))
    }
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
