import XCTest

final class AtlantisRuntimeUITests: XCTestCase {
  func testFounderOnlyImportAndWalkingControls() {
    let app=XCUIApplication();app.launchArguments=["--atlantis-realitykit"];app.launch()
    let ready=app.staticTexts["atlantis.debug.benchmarkStatus"]
    XCTAssertTrue(ready.waitForExistence(timeout:30))
    let wait=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Founder ready"),object:ready)
    XCTAssertEqual(XCTWaiter.wait(for:[wait],timeout:45),.completed)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","districts")).firstMatch.exists)
    XCTAssertTrue(app.staticTexts["atlantis.debug.streaming.residents"].label.contains("Founder"))
    capture("Atlantis_Founder_FirstLoad",app)
    app.buttons["atlantis.debug.toggleWalk"].tap();app.buttons["atlantis.debug.forward"].tap()
    let walking=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label BEGINSWITH %@","Walking"),object:app.staticTexts["atlantis.debug.walkStatus"])
    XCTAssertEqual(XCTWaiter.wait(for:[walking],timeout:5),.completed)
    app.buttons["Pause"].tap();capture("Atlantis_Founder_Walking",app)
    app.buttons["atlantis.debug.unloadAll"].tap();XCTAssertTrue(app.staticTexts["0/7 districts"].waitForExistence(timeout:5))
  }
  func testStreamingHUDTransitionsSpireSwapAndLateEveningPhase() {
    continueAfterFailure=false
    let app=XCUIApplication();app.launchArguments=["--atlantis-realitykit","--atlantis-batched-assets"];app.launch()
    let status=app.staticTexts["atlantis.debug.benchmarkStatus"];XCTAssertTrue(status.waitForExistence(timeout:30))
    XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Founder ready"),object:status)],timeout:45),.completed)
    let residents=app.staticTexts["atlantis.debug.streaming.residents"],streaming=app.staticTexts["atlantis.debug.streaming.status"]
    XCTAssertTrue(residents.label.contains("Founder"));XCTAssertTrue(streaming.label.contains("Spire proxy"))
    app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Lighting:")).firstMatch.tap();app.buttons["Evening"].tap()
    for (button,current) in [("Enter Startup","Startup"),("Enter Commerce","Commerce"),("Enter Tech Core","Tech Core")] {
      app.buttons["atlantis.debug.streaming.traverse"].tap();app.buttons[button].tap()
      XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"label BEGINSWITH %@","Current: \(current)"),object:residents)],timeout:45),.completed)
      XCTAssertLessThanOrEqual(Int(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","districts")).firstMatch.label.split(separator:"/").first ?? "99") ?? 99,3)
    }
    XCTAssertTrue(streaming.label.contains("Spire full"));capture("Atlantis_Phase12_TechStreaming",app)
  }
  func testFullBenchmarkAndViews() {
    let app=XCUIApplication();app.launchArguments=["--atlantis-realitykit","--atlantis-benchmark","--atlantis-batched-assets"];app.launch()
    let status=app.staticTexts["atlantis.debug.benchmarkStatus"];XCTAssertTrue(status.waitForExistence(timeout:30))
    let finish=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label IN %@",["complete","failed"]),object:status)
    XCTAssertEqual(XCTWaiter.wait(for:[finish],timeout:240),.completed);XCTAssertEqual(status.label,"complete")
    capture("Atlantis_Benchmark_Aerial",app)
    for camera in ["founderStreet","startupBoulevard","commerceFlashpoint","techCoreSkyline","unicornOverlook","atlantisAerial"] {
      app.buttons["atlantis.debug.camera"].tap();app.buttons["atlantis.debug.camera.\(camera)"].tap()
      Thread.sleep(forTimeInterval:1);capture("Atlantis_\(camera)",app)
    }
  }
  func testWorldInteractionsRouteToCanonicalScreensAndRestoreAtlantis() {
    continueAfterFailure=false
    let app=XCUIApplication();app.launchArguments=["--atlantis-realitykit","--atlantis-batched-assets"];app.launch()
    let status=app.staticTexts["atlantis.debug.benchmarkStatus"];XCTAssertTrue(status.waitForExistence(timeout:30))
    XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Founder ready"),object:status)],timeout:45),.completed)

    roundTrip(app,targetID:"atlantis.interaction.founderGarage",approachLabel:nil,routeID:"founderGarage",screenshot:"Atlantis_Phase13_Garage")
    roundTrip(app,targetID:"atlantis.interaction.techCom",approachLabel:"Approach Open Tech.com",routeID:"techCom",screenshot:"Atlantis_Phase13_TechCom")
    roundTrip(app,targetID:"atlantis.interaction.ventureHall",approachLabel:"Approach Enter Venture Hall",routeID:"venture",screenshot:"Atlantis_Phase13_Venture")
    roundTrip(app,targetID:"atlantis.interaction.signalTV",approachLabel:"Approach Inspect Signal TV",routeID:"signalTV",screenshot:"Atlantis_Phase13_SignalTV")
    roundTrip(app,targetID:"atlantis.interaction.pallasAI",approachLabel:"Approach Inspect Pallas AI",routeID:"rival.pallas",screenshot:"Atlantis_Phase13_Pallas")
    roundTrip(app,targetID:"atlantis.interaction.northwindLabs",approachLabel:"Approach Inspect Northwind Labs",routeID:"rival.northwind",screenshot:"Atlantis_Phase13_Northwind")
    roundTrip(app,targetID:"atlantis.interaction.flashpoint",approachLabel:"Approach Inspect Flashpoint",routeID:"rival.flashpoint",screenshot:"Atlantis_Phase13_Flashpoint")
    roundTrip(app,targetID:"atlantis.interaction.playerHQ",approachLabel:"Approach Inspect Future Unicorn HQ",routeID:"playerHQ",screenshot:"Atlantis_Phase13_PlayerHQ")
  }
  private func roundTrip(_ app:XCUIApplication,targetID:String,approachLabel:String?,routeID:String,screenshot:String) {
    if let approachLabel {
      let menu=app.buttons["atlantis.debug.interactions"];XCTAssertTrue(menu.waitForExistence(timeout:10));menu.tap()
      let approach=app.buttons[approachLabel];XCTAssertTrue(approach.waitForExistence(timeout:10));approach.tap()
    }
    let prompt=app.buttons[targetID];XCTAssertTrue(prompt.waitForExistence(timeout:45))
    let position=app.staticTexts["atlantis.debug.streaming.position"].label
    prompt.tap()
    XCTAssertTrue(app.staticTexts["atlantis.canonical.\(routeID)"].waitForExistence(timeout:30))
    XCTAssertTrue(app.buttons["atlantis.interaction.return"].exists)
    capture(screenshot,app)
    if routeID=="founderGarage" {
      let computer=app.buttons["founder-desk-device-computer"];XCTAssertTrue(computer.waitForExistence(timeout:15));computer.tap()
      let lookOut=app.buttons["founder-computer-look-out"];XCTAssertTrue(lookOut.waitForExistence(timeout:15));lookOut.tap()
      XCTAssertTrue(computer.waitForExistence(timeout:15))
    }
    app.buttons["atlantis.interaction.return"].tap()
    let restored=app.staticTexts["atlantis.debug.streaming.position"]
    XCTAssertTrue(restored.waitForExistence(timeout:30));XCTAssertEqual(restored.label,position)
  }
  private func capture(_ name:String,_ app:XCUIApplication) {let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
