import XCTest

final class Build32_6_2ProductionContinuityUITests: XCTestCase {
  func testAgentOperationsOverloadAllocationAndReopenPersistence() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--agent-operations-qa", "--agent-operations-fixture-stacksOverloaded",
      "--agent-operations-reduce-motion"
    ]
    app.launch()
    XCTAssertTrue(app.otherElements["ai-operations-floor"].waitForExistence(timeout: 6))

    let toggle = app.buttons["agent-operations-toggle-stacks"]
    revealAndTapAgentOperations(toggle, in: app)
    let warning = app.staticTexts["agent-operations-overload-warning-stacks"]
    XCTAssertTrue(warning.waitForExistence(timeout: 4))
    let diagnostics = app.staticTexts["agent-operations-diagnostics-stacks"]
    XCTAssertTrue(diagnostics.label.contains("effective workload 115"), diagnostics.label)

    revealAndTapAgentOperations(app.buttons["agent-operations-decrement-stacks-productDevelopment"], in: app)
    XCTAssertTrue(diagnostics.label.contains("Product Development 40"), diagnostics.label)
    XCTAssertTrue(diagnostics.label.contains("headroom 5"), diagnostics.label)

    revealAndTapAgentOperations(toggle, in: app)
    revealAndTapAgentOperations(toggle, in: app)
    XCTAssertTrue(diagnostics.label.contains("Product Development 40"), diagnostics.label)
    XCTAssertTrue(app.staticTexts["agent-operations-headroom-stacks"].label.contains("5"))
  }

  func testAgentOperationsAutonomyDecisionsAndDistinctDomainsAtLargestType() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--agent-operations-qa", "--agent-operations-fixture-balanced",
      "--agent-operations-reduce-motion",
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    ]
    app.launch()
    XCTAssertTrue(app.otherElements["ai-operations-floor"].waitForExistence(timeout: 6))

    let auroraToggle = app.buttons["agent-operations-toggle-aurora"]
    revealAndTapAgentOperations(auroraToggle, in: app)
    XCTAssertTrue(app.otherElements["agent-operations-allocation-aurora-evidenceVerification"].waitForExistence(timeout: 4))
    revealAndTapAgentOperations(app.buttons["agent-operations-increment-aurora-evidenceVerification"], in: app)
    revealAndTapAgentOperations(app.buttons["Autonomous"].firstMatch, in: app)
    XCTAssertTrue(app.staticTexts["agent-operations-diagnostics-aurora"].label.contains("autonomy Autonomous"))
    revealAndTapAgentOperations(app.buttons["agent-operations-let-decide-aurora"], in: app)
    XCTAssertFalse(app.otherElements["agent-operations-decision-aurora"].exists)

    revealAndTapAgentOperations(auroraToggle, in: app)
    let brioToggle = app.buttons["agent-operations-toggle-brio"]
    revealAndTapAgentOperations(brioToggle, in: app)
    XCTAssertTrue(app.otherElements["agent-operations-allocation-brio-acquisition"].waitForExistence(timeout: 4))
    revealAndTapAgentOperations(app.buttons["agent-operations-increment-brio-acquisition"], in: app)
    revealAndTapAgentOperations(app.buttons["agent-operations-intervene-brio-prioritizePublicResponse"], in: app)
    XCTAssertFalse(app.otherElements["agent-operations-decision-brio"].exists)
    let brioDiagnostics = app.staticTexts["agent-operations-diagnostics-brio"]
    XCTAssertTrue(brioDiagnostics.label.contains("founder interventions 1"), brioDiagnostics.label)
  }

  func testProductLaunchFixtureCompletesDecisionExecutionOutcomeAndDuplicateGuard() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--strategy-board-qa", "--strategy-board-fixtures", "--strategy-board-reduce-motion"]
    app.launch()
    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 6))

    revealAndTap(app.buttons["launch-fixture-strongPreparation"], in: app)
    XCTAssertEqual(app.staticTexts["product-launch-stage"].label, "Launch Check")
    revealAndTap(app.buttons["product-launch-continue"], in: app)
    XCTAssertEqual(app.staticTexts["product-launch-stage"].label, "Founder Decisions")
    revealAndTap(app.buttons["product-launch-release-shipNow"], in: app)
    revealAndTap(app.buttons["product-launch-public-evidenceLed"], in: app)
    revealAndTap(app.buttons["product-launch-execute"], in: app)
    XCTAssertEqual(app.staticTexts["product-launch-stage"].label, "Launch In Progress")
    revealAndTap(app.buttons["product-launch-resolve"], in: app)
    XCTAssertTrue(app.otherElements["product-launch-outcome"].waitForExistence(timeout: 4))
    XCTAssertTrue(app.staticTexts["product-launch-consequences"].exists)
    revealAndTap(app.buttons["product-launch-debug-resolve-again"], in: app)
    let diagnostics = app.staticTexts["product-launch-diagnostics"]
    XCTAssertTrue(diagnostics.label.contains("resolution invocations 2"), diagnostics.label)
    XCTAssertTrue(diagnostics.label.contains("canonical effects 1"), diagnostics.label)
    XCTAssertTrue(diagnostics.label.contains("duplicates prevented 1"), diagnostics.label)
    revealAndTap(app.buttons["product-launch-return"], in: app)
    XCTAssertTrue(app.staticTexts["strategy-board-readiness"].waitForExistence(timeout: 4))
  }

  func testProductLaunchRiskAndEvidenceFixturesStayFounderSafeAtLargestType() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--strategy-board-qa", "--strategy-board-fixtures", "--strategy-board-reduce-motion",
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    ]
    app.launch()
    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 6))

    revealAndTap(app.buttons["launch-fixture-technicalRisk"], in: app)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'reliability'" )).firstMatch.waitForExistence(timeout: 4))
    let technicalVisible = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ").lowercased()
    XCTAssertFalse(technicalVisible.contains("actual quality"))
    XCTAssertFalse(technicalVisible.contains("overclaim"))
    revealAndTap(app.buttons["product-launch-return-check"], in: app)

    revealAndTap(app.buttons["launch-fixture-weakEvidence"], in: app)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Evidence 3/3'" )).firstMatch.waitForExistence(timeout: 4))
    revealAndTap(app.buttons["product-launch-continue"], in: app)
    revealAndTap(app.buttons["product-launch-release-conservative"], in: app)
    revealAndTap(app.buttons["product-launch-public-bold"], in: app)
    revealAndTap(app.buttons["product-launch-execute"], in: app)
    revealAndTap(app.buttons["product-launch-resolve"], in: app)
    XCTAssertTrue(app.otherElements["product-launch-outcome"].waitForExistence(timeout: 4))
  }

  func testFounderStrategyBoardFixturesRoutesAndReturnContext() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--strategy-board-qa", "--strategy-board-fixtures", "--strategy-board-reduce-motion",
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    ]
    app.launch()

    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 6))
    let expected = [
      ("empty", "readiness notReady"),
      ("partial", "readiness needsReview"),
      ("evidenceBlocker", "readiness needsReview"),
      ("technicalBlocker", "readiness blocked"),
      ("ready", "readiness ready"),
      ("publicRivalRisk", "readiness ready")
    ]
    let diagnostics = app.staticTexts["strategy-board-diagnostics"]
    for (fixture, readiness) in expected {
      let button = app.buttons["strategy-board-fixture-\(fixture)"]
      for _ in 0..<10 where !button.isHittable { app.swipeUp() }
      XCTAssertTrue(button.isHittable, fixture)
      button.tap()
      XCTAssertTrue(diagnostics.label.contains(readiness), diagnostics.label)
    }

    let partial = app.buttons["strategy-board-fixture-partial"]
    for _ in 0..<10 where !partial.isHittable { app.swipeUp() }
    partial.tap()
    let preparation = app.buttons["Preparation"]
    for _ in 0..<10 where !preparation.isHittable { app.swipeDown() }
    XCTAssertTrue(preparation.isHittable)
    preparation.tap()
    let route = app.buttons["strategy-board-route-launch.market-research"]
    for _ in 0..<10 where !route.isHittable { app.swipeUp() }
    XCTAssertTrue(route.isHittable)
    route.tap()
    XCTAssertTrue(app.navigationBars["Canonical Agent operations"].waitForExistence(timeout: 6))
    app.buttons["strategy-board-return"].tap()
    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 6))
    XCTAssertTrue(app.buttons["strategy-board-route-launch.market-research"].waitForExistence(timeout: 4))
    XCTAssertTrue(diagnostics.label.contains("readiness needsReview"))
  }

  func testFounderStrategyBoardDuplicateCommitAndPublicRiskBoundary() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--strategy-board-qa", "--strategy-board-fixtures"]
    app.launch()
    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 6))

    let ready = app.buttons["strategy-board-fixture-ready"]
    for _ in 0..<10 where !ready.isHittable { app.swipeUp() }
    ready.tap()
    let doubleCommit = app.buttons["strategy-board-debug-double-commit"]
    for _ in 0..<8 where !doubleCommit.isHittable { app.swipeUp() }
    XCTAssertTrue(doubleCommit.isHittable)
    doubleCommit.tap()
    let diagnostics = app.staticTexts["strategy-board-diagnostics"]
    XCTAssertTrue(diagnostics.label.contains("commit invocations 2"), diagnostics.label)
    XCTAssertTrue(diagnostics.label.contains("canonical executions 1"), diagnostics.label)
    XCTAssertTrue(diagnostics.label.contains("duplicates prevented 1"), diagnostics.label)

    let rival = app.buttons["strategy-board-fixture-publicRivalRisk"]
    for _ in 0..<8 where !rival.isHittable { app.swipeUp() }
    rival.tap()
    let risks = app.buttons["Risks"]
    for _ in 0..<10 where !risks.isHittable { app.swipeDown() }
    risks.tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'publicly claims 90 Momentum'")).firstMatch.waitForExistence(timeout: 4))
    let visible = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ").lowercased()
    for forbidden in ["actual quality", "correctness", "overclaim", "drift", "future outcome"] {
      XCTAssertFalse(visible.contains(forbidden), "Strategy Board exposed \(forbidden)")
    }
  }

  func testCommandCenterPortraitProductionAssignmentsAndReturn() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()
    enterFreshProductionCareer(in: app)
    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    app.buttons["founder-next-action"].tap()
    let founderChoice = app.buttons.matching(NSPredicate(format: "label IN %@", [
      "Cut the Feature", "Build It", "Time-Box a Spike", "Narrow the Claim",
      "Use the Bold Claim", "Delay for Proof", "Protect Sleep", "Push Through", "Delegate the Demo"
    ])).firstMatch
    for _ in 0..<8 where !founderChoice.isHittable { app.swipeUp() }
    XCTAssertTrue(founderChoice.isHittable)
    founderChoice.tap()
    let founderSheet = app.navigationBars["Founder Command"]
    for _ in 0..<3 where founderSheet.exists {
      // A full drag dismisses both the iPad form sheet and iPhone detents;
      // a short swipe confined to the navigation bar can only collapse it.
      founderSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
    }
    XCTAssertFalse(founderSheet.exists)
    XCTAssertTrue(app.buttons["founder-computer-look-out"].waitForExistence(timeout: 5))

    for (index, name) in ["Aurora", "Stacks", "Brio"].enumerated() {
      let assign = app.buttons["Assign \(name)"].firstMatch
      for _ in 0..<10 where !assign.isHittable { app.swipeUp() }
      XCTAssertTrue(assign.isHittable, name)
      assign.tap()
      XCTAssertTrue(app.navigationBars["Assign \(name)"].waitForExistence(timeout: 5))
      // Choose different real tasks through the existing confirmation UI.
      let choices = app.buttons.matching(identifier: "Review assignment")
      let choice = choices.element(boundBy: index)
      for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
      XCTAssertTrue(choice.isHittable)
      choice.tap()
      let confirm = app.buttons["Confirm assignment"]
      for _ in 0..<8 where !confirm.isHittable { app.swipeUp() }
      XCTAssertTrue(confirm.isHittable)
      confirm.tap()
      let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["Assign \(name)"])
      XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
      let station = app.otherElements["operations-station-\(name.lowercased())"].firstMatch
      XCTAssertTrue(station.waitForExistence(timeout: 5))
      XCTAssertTrue(station.staticTexts["Awaiting Founder review"].waitForExistence(timeout: 6))
      assertNoRevealedOutcome(in: station)
      let action = index < 2 ? "Inspect \(name)" : "Open Founder Review"
      XCTAssertTrue(station.buttons[action].waitForExistence(timeout: 5))
      if index < 2 { XCTAssertFalse(station.buttons["Open Founder Review"].exists) }
      capture("PORTRAIT_\(name.uppercased())_PRODUCTION_AWAITING_REVIEW", in: app)
    }

    // Real offscreen scrolls and mounted-but-unfocused Computer return, followed
    // by a scene transition. Durable review endpoints/actions must survive all.
    for _ in 0..<5 { app.swipeDown() }
    returnToDesk(from: .computer, in: app)
    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    XCUIDevice.shared.press(.home)
    app.activate()
    for name in ["Aurora", "Stacks", "Brio"] {
      let station = app.otherElements["operations-station-\(name.lowercased())"].firstMatch
      for _ in 0..<10 where !station.buttons["Open Founder Review"].isHittable { app.swipeUp() }
      XCTAssertTrue(station.staticTexts["Awaiting Founder review"].exists)
      XCTAssertTrue(station.buttons["Open Founder Review"].isEnabled)
      XCTAssertEqual(station.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).count, 1)
    }
    capture("PORTRAIT_PRODUCTION_RETURN_ENDPOINTS", in: app)

    // Relaunch the same persisted career. Presentation choreography is not
    // persisted, so each station must derive the durable awaiting-review state
    // without reconstructing assignment or completion transitions.
    app.terminate()
    app.launch()
    let continueCareer = app.buttons["Continue Career"]
    XCTAssertTrue(continueCareer.waitForExistence(timeout: 6))
    continueCareer.tap()
    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    for name in ["Aurora", "Stacks", "Brio"] {
      let station = app.otherElements["operations-station-\(name.lowercased())"].firstMatch
      for _ in 0..<10 where !station.buttons["Open Founder Review"].isHittable { app.swipeUp() }
      XCTAssertTrue(station.staticTexts["Awaiting Founder review"].exists)
      XCTAssertTrue(station.buttons["Open Founder Review"].isEnabled)
      XCTAssertFalse(station.staticTexts["Assignment received"].exists)
      XCTAssertFalse(station.staticTexts["Working"].exists)
      XCTAssertFalse(station.staticTexts["Work complete"].exists)
      assertNoRevealedOutcome(in: station)
    }
    capture("PORTRAIT_PRODUCTION_RELAUNCH_ENDPOINTS", in: app)
    app.terminate()
  }

  func testAuroraPortraitNativeAcceptanceHold() throws {
    try exercisePortraitNativeAcceptance(name: "Aurora", taskIndex: 0)
  }

  func testStacksPortraitNativeAcceptanceHold() throws {
    try exercisePortraitNativeAcceptance(name: "Stacks", taskIndex: 1)
  }

  func testBrioPortraitNativeAcceptanceHold() throws {
    try exercisePortraitNativeAcceptance(name: "Brio", taskIndex: 2)
  }

  func testPortraitFramingNativeAcceptanceHold() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()
    enterFreshProductionCareer(in: app)
    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    resolveInitialFounderCommand(in: app)

    for name in ["Aurora", "Stacks", "Brio"] {
      let station = app.otherElements["operations-station-\(name.lowercased())"].firstMatch
      XCTAssertTrue(station.waitForExistence(timeout: 6), name)
      for _ in 0..<10 where !station.isHittable { app.swipeUp() }
      XCTAssertTrue(station.isHittable, name)
      capture("PORTRAIT_FRAMING_\(name.uppercased())", in: app)
      sleep(4)
    }
    app.terminate()
  }

  func testPositiveOutcomePortraitNativeAcceptanceHold() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--work-session-qa-handoff"]
    app.launch()

    let review = app.buttons["Open Founder Review"].firstMatch
    for _ in 0..<8 where !review.isHittable { app.swipeUp() }
    XCTAssertTrue(review.waitForExistence(timeout: 5))
    review.tap()
    XCTAssertTrue(app.navigationBars["Evidence Triage"].waitForExistence(timeout: 5))
    let delegate = app.buttons["DELEGATE"]
    for _ in 0..<6 where !delegate.isHittable { app.swipeUp() }
    XCTAssertTrue(delegate.isHittable)
    delegate.tap()
    let next = app.buttons["CONTINUE"]
    for _ in 0..<6 where !next.isHittable { app.swipeUp() }
    XCTAssertTrue(next.waitForExistence(timeout: 5))

    capture("PORTRAIT_POSITIVE_REVEAL_READY", in: app)
    sleep(5)
    next.tap()
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"),
      object: app.navigationBars["Evidence Triage"]
    )
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    let station = app.otherElements["operations-station-aurora"].firstMatch
    XCTAssertTrue(station.waitForExistence(timeout: 5))
    XCTAssertTrue(station.staticTexts["Reviewed"].waitForExistence(timeout: 6))
    XCTAssertTrue(station.staticTexts["Verified"].exists)
    sleep(4)
    capture("PORTRAIT_POSITIVE_REVEAL_STABLE", in: app)
    app.terminate()
  }

  func testReviewedOutcomePortraitRestoreRemainsStable() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--work-session-qa-report"]
    app.launch()
    assertReviewedVerifiedAurora(in: app)

    XCUIDevice.shared.press(.home)
    app.activate()
    assertReviewedVerifiedAurora(in: app)
    app.swipeUp()
    app.swipeDown()
    assertReviewedVerifiedAurora(in: app)

    app.terminate()
    app.launch()
    assertReviewedVerifiedAurora(in: app)
    app.terminate()
  }

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

  /// Runs the real Founder Desk -> Computer -> assignment flow and pauses before
  /// confirmation so a human can watch the native Simulator at the existing
  /// production timing. The sheet-covered acknowledgment remains intentionally
  /// skipped; the hold is for the visible working/completion/awaiting sequence.
  private func exercisePortraitNativeAcceptance(name: String, taskIndex: Int) throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()
    enterFreshProductionCareer(in: app)
    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    resolveInitialFounderCommand(in: app)

    let assign = app.buttons["Assign \(name)"].firstMatch
    for _ in 0..<10 where !assign.isHittable { app.swipeUp() }
    XCTAssertTrue(assign.isHittable, name)
    assign.tap()
    XCTAssertTrue(app.navigationBars["Assign \(name)"].waitForExistence(timeout: 5))

    let choices = app.buttons.matching(identifier: "Review assignment")
    let choice = choices.element(boundBy: taskIndex)
    for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
    XCTAssertTrue(choice.isHittable)
    choice.tap()

    let confirm = app.buttons["Confirm assignment"]
    for _ in 0..<8 where !confirm.isHittable { app.swipeUp() }
    XCTAssertTrue(confirm.isHittable)
    capture("PORTRAIT_\(name.uppercased())_NATIVE_ACCEPTANCE_READY", in: app)
    sleep(5)
    confirm.tap()

    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"),
      object: app.navigationBars["Assign \(name)"]
    )
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    let station = app.otherElements["operations-station-\(name.lowercased())"].firstMatch
    XCTAssertTrue(station.waitForExistence(timeout: 5))
    sleep(4)
    XCTAssertTrue(station.staticTexts["Awaiting Founder review"].exists)
    capture("PORTRAIT_\(name.uppercased())_NATIVE_ACCEPTANCE_ENDPOINT", in: app)
    app.terminate()
  }

  private func resolveInitialFounderCommand(in app: XCUIApplication) {
    app.buttons["founder-next-action"].tap()
    let founderChoice = app.buttons.matching(NSPredicate(format: "label IN %@", [
      "Cut the Feature", "Build It", "Time-Box a Spike", "Narrow the Claim",
      "Use the Bold Claim", "Delay for Proof", "Protect Sleep", "Push Through", "Delegate the Demo"
    ])).firstMatch
    for _ in 0..<8 where !founderChoice.isHittable { app.swipeUp() }
    XCTAssertTrue(founderChoice.isHittable)
    founderChoice.tap()
    let founderSheet = app.navigationBars["Founder Command"]
    for _ in 0..<3 where founderSheet.exists {
      founderSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
    }
    XCTAssertFalse(founderSheet.exists)
    XCTAssertTrue(app.buttons["founder-computer-look-out"].waitForExistence(timeout: 5))
  }

  private func assertNoRevealedOutcome(in station: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    for label in ["Verified", "Evidence incomplete", "Overclaim detected", "Drift detected"] {
      XCTAssertFalse(station.staticTexts[label].exists, "Pre-review station exposed \(label)", file: file, line: line)
    }
  }

  private func assertReviewedVerifiedAurora(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let station = app.otherElements["operations-station-aurora"].firstMatch
    XCTAssertTrue(station.waitForExistence(timeout: 6), file: file, line: line)
    XCTAssertTrue(station.staticTexts["Reviewed"].exists, file: file, line: line)
    XCTAssertTrue(station.staticTexts["Verified"].exists, file: file, line: line)
    XCTAssertFalse(station.staticTexts["Founder reviewing"].exists, file: file, line: line)
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

  func testCompanyServerCanonicalOperationsRoundTrip() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()
    enterFreshProductionCareer(in: app)

    revealCompanyServer(in: app)
    for cycle in 0..<2 {
      focusDevice(.server, expectedTitle: "Company Server", in: app)

      let evidence = app.buttons["server-module-evidence"]
      assertAccessibleTouchTarget(evidence)
      XCTAssertTrue(evidence.isHittable)
      evidence.tap()
      let computerClose = app.buttons["founder-computer-look-out"]
      XCTAssertTrue(computerClose.waitForExistence(timeout: 6), "Evidence Ledger did not leave Company Server")
      assertHittable(computerClose, message: "Evidence Ledger did not make the Founder Computer interactive")
      capture("SERVER_EVIDENCE_ROUTE_\(cycle)", in: app)
      XCTAssertTrue(app.descendants(matching: .any)["founder-computer-evidence"].firstMatch.waitForExistence(timeout: 6))
      computerClose.tap()
      let serverClose = app.buttons["return-to-founder-desk-server"]
      XCTAssertTrue(serverClose.waitForExistence(timeout: 6), "Evidence Ledger return did not restore Company Server")
      assertHittable(serverClose, message: "Evidence Ledger return did not restore interactive Company Server Operations")

      let operations = app.buttons["server-module-agent-operations"]
      assertAccessibleTouchTarget(operations)
      XCTAssertTrue(operations.isHittable)
      operations.tap()
      XCTAssertTrue(computerClose.waitForExistence(timeout: 6), "Agent Operations did not leave Company Server")
      assertHittable(computerClose, message: "Agent Operations did not make the Founder Computer interactive")
      capture("SERVER_AGENT_OPERATIONS_ROUTE_\(cycle)", in: app)
      XCTAssertTrue(app.otherElements["ai-operations-floor"].waitForExistence(timeout: 6))
      computerClose.tap()
      XCTAssertTrue(app.buttons["return-to-founder-desk-server"].waitForExistence(timeout: 6), "Agent Operations return did not restore Company Server")
      assertHittable(serverClose, message: "Agent Operations return did not restore interactive Company Server Operations")

      returnToDesk(from: .server, in: app)
      if cycle == 0 {
        XCTAssertTrue(app.buttons["founder-desk-device-server"].waitForExistence(timeout: 5))
      }
    }
    app.terminate()
  }

  func testRealityKitGarageFounderComputerRoundTrip() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--founder-desk-production-proof",
      "--founder-garage-realitykit"
    ]
    app.launch()
    enterFreshProductionCareer(in: app)

    let garage = app.otherElements["founder-garage-realitykit"]
    XCTAssertTrue(garage.waitForExistence(timeout: 8), "RealityKit Garage did not replace the development overview renderer")
    XCTAssertTrue(garage.isHittable)
    XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Founder View"), object: app.descendants(matching: .any)["founderGarage.currentView"])], timeout: 15) == .completed)
    capture("FOUNDER_POV_INITIAL", in: app)

    let computerClose = app.buttons["founder-computer-look-out"]
    app.coordinate(withNormalizedOffset: CGVector(
      dx: 0.50,
      dy: 0.50
    )).tap()
    XCTAssertTrue(computerClose.waitForExistence(timeout: 6), "The imported monitor region did not open the canonical Computer")
    XCTAssertEqual(app.buttons.matching(identifier: "founder-computer-look-out").count, 1)
    computerClose.tap()
    XCTAssertTrue(garage.waitForExistence(timeout: 6), "Closing the physically tapped Computer did not restore Facility Tier 0")

    let computer = app.buttons["founderGarage.realityKit.founderComputer"]
    assertAccessibleTouchTarget(computer)
    assertHittable(computer, message: "RealityKit Founder Computer control was not interactive")
    XCTAssertEqual(computer.label, "Founder Computer")
    XCTAssertEqual(app.buttons.matching(identifier: "founderGarage.realityKit.founderComputer").count, 1)
    computer.tap()
    XCTAssertTrue(computerClose.waitForExistence(timeout: 6), "RealityKit Founder Computer did not open the canonical Computer")
    assertHittable(computerClose, message: "Canonical Founder Computer did not become interactive")
    XCTAssertFalse(computer.isHittable, "Garage control must be inactive while the Computer is focused")
    capture("REALITYKIT_CANONICAL_COMPUTER", in: app)

    computerClose.tap()
    XCTAssertTrue(garage.waitForExistence(timeout: 6), "Closing the Founder Computer did not restore the RealityKit Garage")
    assertHittable(garage, message: "RealityKit Garage was not interactive after returning from the Computer")
    XCTAssertEqual(app.buttons.matching(identifier: "founderGarage.realityKit.founderComputer").count, 1)
    capture("REALITYKIT_GARAGE_RETURN", in: app)
    assertAccessibleTouchTarget(computer)
    assertHittable(computer, message: "Founder Computer control did not return with the Garage")
    computer.tap()
    assertHittable(computerClose, message: "Founder Computer could not reopen through its semantic control")
    computerClose.tap()
    assertHittable(computer, message: "Founder Computer control did not survive a second round trip")
    XCTAssertEqual(app.buttons.matching(identifier: "founderGarage.realityKit.founderComputer").count, 1)
    app.terminate()
  }

  func testRealityKitLookOutFocusAndReturn() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof", "--founder-garage-realitykit"]
    app.launch()
    enterFreshProductionCareer(in: app)
    let computer = app.buttons["founderGarage.realityKit.founderComputer"]
    XCTAssertTrue(computer.waitForExistence(timeout: 8))
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Founder View"), object: app.descendants(matching: .any)["founderGarage.currentView"])], timeout: 15), .completed)
    capture("POV_INITIAL", in: app)
    app.buttons["founderGarage.lookOut"].tap()
    XCTAssertTrue(app.buttons["founderGarage.focusMenu"].waitForExistence(timeout: 5))
    XCTAssertFalse(computer.waitForExistence(timeout: 0.5))
    capture("POV_OVERVIEW", in: app)
    for target in ["garageOverview", "whiteboard", "garageDoor", "frontBay", "front"] {
      app.buttons["founderGarage.focusMenu"].tap()
      app.buttons["founderGarage.focus.\(target)"].tap()
      XCTAssertTrue(app.buttons["founderGarage.returnWorkstation"].isHittable)
      XCTAssertFalse(computer.waitForExistence(timeout: 0.5))
      XCTAssertFalse(app.buttons["founderGarage.focusMenu"].value as? String == "Founder View")
      capture("POV_\(target)", in: app)
      if target == "garageDoor" {
        let doorToggle = app.buttons["founderGarage.realityKit.garageDoor.toggle"]
        XCTAssertTrue(doorToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(doorToggle.value as? String, "Closed")
        doorToggle.tap()
        XCTAssertEqual(doorToggle.value as? String, "Open")
        sleep(2)
        capture("POV_GARAGE_DOOR_OPEN", in: app)
        doorToggle.tap()
        XCTAssertEqual(doorToggle.value as? String, "Closed")
        sleep(2)
        capture("POV_GARAGE_DOOR_CLOSED", in: app)
      }
      app.buttons["founderGarage.returnWorkstation"].tap()
      XCTAssertTrue(computer.waitForExistence(timeout: 5))
      computer.tap()
      let close = app.buttons["founder-computer-look-out"]
      XCTAssertTrue(close.waitForExistence(timeout: 6))
      close.tap()
      XCTAssertTrue(computer.waitForExistence(timeout: 6))
      app.buttons["founderGarage.lookOut"].tap()
    }
    app.buttons["founderGarage.returnWorkstation"].tap()
    XCTAssertTrue(computer.waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons.matching(identifier: "founderGarage.realityKit.founderComputer").count, 1)
    capture("POV_RETURN", in: app)
    computer.tap()
    let close = app.buttons["founder-computer-look-out"]
    XCTAssertTrue(close.waitForExistence(timeout: 6))
    close.tap()
    XCTAssertTrue(computer.waitForExistence(timeout: 6))
    app.terminate()
  }

  func testRealityKitV7DayVisualContinuity() throws { try captureV7EnvironmentStates(["day"]) }
  func testRealityKitV7MorningVisualContinuity() throws { try captureV7EnvironmentStates(["morning"]) }
  func testRealityKitV7EveningVisualContinuity() throws { try captureV7EnvironmentStates(["evening"]) }
  func testRealityKitV7NightVisualContinuity() throws { try captureV7EnvironmentStates(["night"]) }

  private func captureV7EnvironmentStates(_ states: [String]) throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof", "--founder-garage-realitykit"]
    app.launch()
    enterFreshProductionCareer(in: app)
    let timeMenu = app.buttons["founderGarage.environment.timeMenu"]
    let computer = app.buttons["founderGarage.realityKit.founderComputer"]
    let toggle = app.buttons["founderGarage.realityKit.garageDoor.toggle"]
    XCTAssertTrue(timeMenu.waitForExistence(timeout: 8))
    XCTAssertEqual(timeMenu.value as? String, "Day")

    func view(_ name: String) {
      if computer.exists { app.buttons["founderGarage.lookOut"].tap() }
      let menu = app.buttons["founderGarage.focusMenu"]
      XCTAssertTrue(menu.waitForExistence(timeout: 5))
      menu.tap()
      app.buttons["founderGarage.focus.\(name)"].tap()
      sleep(1)
      XCTAssertFalse((app.otherElements["founder-garage-realitykit"].value as? String ?? "").contains("Simplified"))
    }
    func founder() {
      app.buttons["founderGarage.returnWorkstation"].tap()
      XCTAssertTrue(computer.waitForExistence(timeout: 5))
      sleep(1)
    }
    func proof(_ name: String) { sleep(1); capture("V7_\(name)", in: app) }

    for state in states {
      timeMenu.tap()
      app.buttons["founderGarage.environment.time.\(state)"].tap()
      XCTAssertEqual(timeMenu.value as? String, state.capitalized)
      proof("\(state)_founder_closed")
      view("garageDoor")
      XCTAssertEqual(toggle.value as? String, "Closed")
      proof("\(state)_garageDoor_closed")
      view("front")
      proof("\(state)_front_closed")
      toggle.tap()
      XCTAssertEqual(toggle.value as? String, "Open")
      sleep(2)
      proof("\(state)_front_open")
      view("garageDoor")
      proof("\(state)_garageDoor_open")
      founder()
      proof("\(state)_founder_open")
      if state == "day" || state == "night" {
        for (label, start, end) in [
          ("yaw_min", CGVector(dx: 0.15, dy: 0.5), CGVector(dx: 0.95, dy: 0.5)),
          ("yaw_max", CGVector(dx: 0.90, dy: 0.5), CGVector(dx: 0.10, dy: 0.5)),
          ("pitch_min", CGVector(dx: 0.6, dy: 0.2), CGVector(dx: 0.6, dy: 0.8)),
          ("pitch_max", CGVector(dx: 0.6, dy: 0.8), CGVector(dx: 0.6, dy: 0.2))
        ] {
          app.coordinate(withNormalizedOffset: start).press(forDuration: 0.08, thenDragTo: app.coordinate(withNormalizedOffset: end))
          proof("\(state)_open_\(label)")
          app.buttons["founderGarage.recenter"].tap()
          XCTAssertEqual(app.buttons["founderGarage.recenter"].value as? String, "Centered")
        }
      }
      for camera in ["garageOverview", "whiteboard", "frontBay"] {
        view(camera)
        proof("\(state)_\(camera)_open")
      }
      view("garageDoor")
      toggle.tap()
      XCTAssertEqual(toggle.value as? String, "Closed")
      sleep(2)
      founder()
      XCTAssertEqual(timeMenu.value as? String, state.capitalized)
    }
    computer.tap()
    let close = app.buttons["founder-computer-look-out"]
    XCTAssertTrue(close.waitForExistence(timeout: 6))
    close.tap()
    XCTAssertTrue(computer.waitForExistence(timeout: 6))
    XCTAssertEqual(timeMenu.value as? String, states.last?.capitalized)
    app.terminate()
  }

  func testRealityKitFounderSeatedFreeLookAndRecenter() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof", "--founder-garage-realitykit"]
    app.launch()
    enterFreshProductionCareer(in: app)

    let garage = app.otherElements["founder-garage-realitykit"]
    let computer = app.buttons["founderGarage.realityKit.founderComputer"]
    let recenter = app.buttons["founderGarage.recenter"]
    XCTAssertTrue(garage.waitForExistence(timeout: 8))
    XCTAssertTrue(computer.waitForExistence(timeout: 8))
    XCTAssertTrue(recenter.waitForExistence(timeout: 8))
    assertAccessibleTouchTarget(recenter)
    XCTAssertEqual(recenter.label, "Recenter Founder View")
    XCTAssertEqual(recenter.value as? String, "Centered")
    capture("FREE_LOOK_NEUTRAL", in: app)

    let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.55))
    let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.47))
    dragStart.press(forDuration: 0.08, thenDragTo: dragEnd)
    let freeLookExpectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "Free look active"),
      object: recenter
    )
    XCTAssertEqual(XCTWaiter.wait(for: [freeLookExpectation], timeout: 4), .completed)
    XCTAssertTrue(computer.isHittable, "Free-look must preserve the canonical Computer interaction route")
    XCTAssertTrue(app.buttons["founderGarage.lookOut"].isHittable)
    capture("FREE_LOOK_OFFSET", in: app)

    recenter.tap()
    XCTAssertEqual(recenter.value as? String, "Centered")
    capture("FREE_LOOK_RECENTERED", in: app)

    let yawStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.54))
    let yawEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.54))
    yawStart.press(forDuration: 0.08, thenDragTo: yawEnd)
    capture("FREE_LOOK_YAW_LIMIT", in: app)
    recenter.tap()

    let pitchUpStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.66))
    let pitchUpEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.24))
    pitchUpStart.press(forDuration: 0.08, thenDragTo: pitchUpEnd)
    capture("FREE_LOOK_PITCH_UP_LIMIT", in: app)
    recenter.tap()

    let pitchDownStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.34))
    let pitchDownEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.78))
    pitchDownStart.press(forDuration: 0.08, thenDragTo: pitchDownEnd)
    capture("FREE_LOOK_PITCH_DOWN_LIMIT", in: app)
    recenter.tap()

    app.buttons["founderGarage.lookOut"].tap()
    XCTAssertTrue(app.buttons["founderGarage.returnWorkstation"].waitForExistence(timeout: 5))
    app.buttons["founderGarage.returnWorkstation"].tap()
    XCTAssertTrue(recenter.waitForExistence(timeout: 5))
    XCTAssertEqual(recenter.value as? String, "Centered")

    let secondDragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.54))
    let secondDragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.56, dy: 0.50))
    secondDragStart.press(forDuration: 0.08, thenDragTo: secondDragEnd)
    let secondFreeLookExpectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "Free look active"),
      object: recenter
    )
    XCTAssertEqual(XCTWaiter.wait(for: [secondFreeLookExpectation], timeout: 4), .completed)
    computer.tap()
    let close = app.buttons["founder-computer-look-out"]
    XCTAssertTrue(close.waitForExistence(timeout: 6))
    close.tap()
    XCTAssertTrue(recenter.waitForExistence(timeout: 6))
    XCTAssertEqual(recenter.value as? String, "Centered")
    app.terminate()
  }

  func testRealityKitCameraPhysicsExploreAndExactDeskReturn() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--founder-desk-production-proof", "--founder-garage-realitykit",
      "--founder-camera-diagnostics"
    ]
    app.launch()
    enterFreshProductionCareer(in: app)

    let toggle = app.buttons["founderGarage.camera.toggleWalking"]
    let computer = app.buttons["founderGarage.realityKit.founderComputer"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 8))
    XCTAssertEqual(toggle.value as? String, "Seated")
    assertAccessibleTouchTarget(toggle)
    toggle.tap()
    XCTAssertEqual(toggle.value as? String, "Walking")
    XCTAssertFalse(computer.exists)

    let movement = app.descendants(matching: .any)["founderGarage.camera.movementPad"]
    XCTAssertTrue(movement.waitForExistence(timeout: 4))
    assertAccessibleTouchTarget(movement)
    let start = movement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let forward = movement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
    start.press(forDuration: 0.12, thenDragTo: forward)
    XCTAssertTrue(app.descendants(matching: .any)["founderGarage.camera.diagnostics"].exists)

    toggle.tap()
    XCTAssertEqual(toggle.value as? String, "Seated")
    XCTAssertTrue(computer.waitForExistence(timeout: 3))
    XCTAssertEqual(
      app.descendants(matching: .any)["founderGarage.currentView"].value as? String,
      "Founder View"
    )
    computer.tap()
    XCTAssertTrue(app.buttons["founder-computer-look-out"].waitForExistence(timeout: 6))
    app.terminate()
  }

  func testLegacySwiftUIGarageRemainsDefaultAndInteractive() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--founder-desk-production-proof"]
    app.launch()
    enterFreshProductionCareer(in: app)

    XCTAssertTrue(app.descendants(matching: .any)["founder-desk-overview"].firstMatch.waitForExistence(timeout: 6))
    XCTAssertFalse(app.otherElements["founder-garage-realitykit"].exists)
    focusDevice(.computer, expectedTitle: "Founder Computer", in: app)
    returnToDesk(from: .computer, in: app)
    XCTAssertTrue(app.descendants(matching: .any)["founder-desk-overview"].firstMatch.waitForExistence(timeout: 6))
    app.terminate()
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
    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Product Launch"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["strategy-board-readiness"].waitForExistence(timeout: 3))
    app.buttons["strategy-board-initiative-picker"].tap()
    app.buttons["Fundraising"].tap()
    app.buttons["strategy-board-open-funding"].tap()
    XCTAssertTrue(app.navigationBars["Founder Funding Board"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["GRANTS & FUNDRAISING"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["ELIGIBLE"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Deadline: 3 sprints"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["1 Attention"].firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Next: Submit the application."].waitForExistence(timeout: 3))
    capture("09B_FOUNDER_FUNDING_BOARD", in: app)
    app.buttons["close-funding-board-viewer"].tap()
    XCTAssertTrue(app.navigationBars["Founder Strategy Board"].waitForExistence(timeout: 4))
    app.buttons["close-strategy-board-viewer"].tap()
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

    revealCompanyServer(in: app)
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
    if device.isHittable {
      device.tap()
    } else {
      XCTAssertTrue(tapVisibleFrame(of: device, in: app), "\(expectedTitle) desk object has no visible activation frame")
    }
    let close = target == .computer
      ? app.buttons["founder-computer-look-out"]
      : app.buttons["return-to-founder-desk-\(target.rawValue)"]
    assertAccessibleTouchTarget(close)
    assertHittable(close, message: "\(expectedTitle) did not become the focused interactive device")
    XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
  }

  private func returnToDesk(from device: FocusedDevice, in app: XCUIApplication) {
    let close = device == .computer
      ? app.buttons["founder-computer-look-out"]
      : app.buttons["return-to-founder-desk-\(device.rawValue)"]
    assertAccessibleTouchTarget(close)
    assertHittable(close, message: "\(device.rawValue) was not the focused interactive device")
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

  private func assertHittable(
    _ element: XCUIElement,
    timeout: TimeInterval = 6,
    message: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate { object, _ in
        guard let candidate = object as? XCUIElement else { return false }
        return candidate.exists && candidate.isEnabled && candidate.isHittable
      },
      object: element
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [expectation], timeout: timeout),
      .completed,
      message,
      file: file,
      line: line
    )
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

  private func revealCompanyServer(in app: XCUIApplication) {
    revealCameraPosition("chevron.right", in: app)
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.50))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.44, dy: 0.50))
    start.press(forDuration: 0.08, thenDragTo: end)
    usleep(300_000)
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
    let visibleFrame = frame.intersection(appFrame)
    guard !visibleFrame.isEmpty, appFrame.width > 0, appFrame.height > 0 else { return false }
    app.coordinate(withNormalizedOffset: CGVector(
      dx: (visibleFrame.midX - appFrame.minX) / appFrame.width,
      dy: (visibleFrame.midY - appFrame.minY) / appFrame.height
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

  private func revealAndTap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<14 where !element.isHittable { app.swipeUp(); usleep(120_000) }
    XCTAssertTrue(element.isHittable, element.debugDescription, file: file, line: line)
    element.tap()
  }

  private func revealAndTapAgentOperations(
    _ element: XCUIElement,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for _ in 0..<10 where !element.isHittable {
      if element.exists && element.frame.midY < app.frame.minY + 150 {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.22))
          .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.88)))
      } else {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.82))
          .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.18)))
      }
      usleep(140_000)
    }
    if element.isHittable {
      element.tap()
    } else {
      XCTAssertTrue(tapVisibleFrame(of: element, in: app), element.debugDescription, file: file, line: line)
    }
  }
}
