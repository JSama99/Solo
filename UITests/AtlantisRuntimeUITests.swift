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
  private func capture(_ name:String,_ app:XCUIApplication) {let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
