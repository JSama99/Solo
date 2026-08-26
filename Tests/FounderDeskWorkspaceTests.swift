import XCTest
@testable import Solo_Unicorn_Run

final class FounderDeskWorkspaceTests: XCTestCase {
  func testDefaultSelectionIsDeskOverview() {
    XCTAssertEqual(FounderDeskNavigationState().selection, .overview)
  }

  func testEveryPhysicalDeviceCanBeSelectedAndClosed() {
    for device in FounderDeskDevice.allCases {
      var state = FounderDeskNavigationState()
      state.select(device)
      XCTAssertEqual(state.selection, .device(device))
      state.returnToDesk()
      XCTAssertEqual(state.selection, .overview)
    }
  }

  func testSwitchingDevicesUsesOneExclusiveSelection() {
    var state = FounderDeskNavigationState()
    state.select(.phone)
    state.select(.tablet)
    XCTAssertEqual(state.selection, .device(.tablet))
  }

  func testNormalMotionUsesSpatialFocus() {
    XCTAssertEqual(FounderDeskNavigationState().transitionStyle(reduceMotion: false), .spatialFocus)
  }

  func testReduceMotionUsesCrossfade() {
    XCTAssertEqual(FounderDeskNavigationState().transitionStyle(reduceMotion: true), .crossfade)
  }

  func testCompactAndRegularSizeClassesHaveDistinctSpatialLayouts() {
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: false, accessibilityText: false, height: 800), .spatialCompact)
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: true, accessibilityText: false, height: 800), .spatialRegular)
  }

  func testAccessibilityTextUsesReadableListLayout() {
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: false, accessibilityText: true, height: 800), .accessibleList)
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: true, accessibilityText: true, height: 1_100), .accessibleList)
  }

  func testCompactHeightUsesReadableListLayout() {
    XCTAssertEqual(FounderDeskLayoutPolicy.layout(regularWidth: false, accessibilityText: false, height: 520), .accessibleList)
  }

  func testFormerMoreInventoryIsCompleteAndUnique() {
    XCTAssertEqual(CompanyServerDestination.allCases.count, 9)
    XCTAssertEqual(Set(CompanyServerDestination.allCases.map(\.id)).count, 9)
    XCTAssertEqual(Set(CompanyServerDestination.allCases.map(\.title)).count, 9)
  }

  func testFormerMoreInventoryRetainsEveryCanonicalDestination() {
    XCTAssertEqual(Set(CompanyServerDestination.allCases), Set([
      .evidence, .agentOperations, .achievements, .headquarters, .companyStory,
      .soloPro, .settings, .howToPlay, .restartCareer
    ]))
  }

  func testEvidenceAndAgentOperationsHandoffToCanonicalComputerTargets() {
    XCTAssertEqual(FounderComputerWorkspaceTarget.evidence.rawValue, "evidence")
    XCTAssertEqual(FounderComputerWorkspaceTarget.operations.rawValue, "viewport")
  }

  func testFounderComputerPreviewUsesOnlyVisibleLifecycleCounts() {
    let preview = FounderDeskPreviewPolicy.preview(for: .computer, input: input(
      visibleWorkCount: 2,
      visibleReviewCount: 0,
      canCommit: false
    ))
    XCTAssertEqual(preview.secondary, "2 active workstations")
    XCTAssertNil(preview.signal)
    assertNoHiddenTruth(in: preview)
  }

  func testFounderReviewSignalIsLifecycleDriven() {
    let preview = FounderDeskPreviewPolicy.preview(for: .computer, input: input(visibleReviewCount: 2))
    XCTAssertEqual(preview.secondary, "2 awaiting Founder review")
    XCTAssertEqual(preview.signal, "Review tray ready")
    assertNoHiddenTruth(in: preview)
  }

  func testSprintReadySignalDoesNotClaimOutcome() {
    let preview = FounderDeskPreviewPolicy.preview(for: .computer, input: input(canCommit: true))
    XCTAssertEqual(preview.signal, "Sprint ready")
    assertNoHiddenTruth(in: preview)
  }

  func testPhoneWithoutCanonicalHeadlineCreatesNoAlert() {
    let preview = FounderDeskPreviewPolicy.preview(for: .phone, input: input(latestPublishedHeadline: nil))
    XCTAssertEqual(preview.primary, "No new published stories")
    XCTAssertNil(preview.signal)
    assertNoHiddenTruth(in: preview)
  }

  func testPhoneSignalUsesCanonicalPublishedHeadline() {
    let preview = FounderDeskPreviewPolicy.preview(for: .phone, input: input(latestPublishedHeadline: "A published market story"))
    XCTAssertEqual(preview.primary, "A published market story")
    XCTAssertEqual(preview.signal, "Published update")
    XCTAssertTrue(preview.accessibilityLabel.contains("A published market story"))
  }

  func testTabletPreviewUsesVisibleObjectiveWithoutConsequences() {
    let preview = FounderDeskPreviewPolicy.preview(for: .tablet, input: input(
      ventureObjective: "Ship the visible prototype",
      ventureObjectiveComplete: false
    ))
    XCTAssertEqual(preview.primary, "Ship the visible prototype")
    XCTAssertNil(preview.signal)
    assertNoHiddenTruth(in: preview)
  }

  func testTabletMilestoneSignalRequiresVisibleCompletion() {
    let preview = FounderDeskPreviewPolicy.preview(for: .tablet, input: input(ventureObjectiveComplete: true))
    XCTAssertEqual(preview.signal, "Objective milestone")
  }

  func testServerSignalReflectsOwnedFacilityState() {
    let startup = FounderDeskPreviewPolicy.preview(for: .server, input: input(ownedFacilityCount: 1))
    let progressed = FounderDeskPreviewPolicy.preview(for: .server, input: input(ownedFacilityCount: 2))
    XCTAssertNil(startup.signal)
    XCTAssertEqual(progressed.signal, "Facilities available")
    assertNoHiddenTruth(in: progressed)
  }

  func testFacilityVariationKeepsStableDeviceIdentity() {
    let garage = FounderDeskPreviewPolicy.preview(for: .server, input: input(facilityName: "Founder Garage"))
    let office = FounderDeskPreviewPolicy.preview(for: .server, input: input(facilityName: "Office Suite"))
    XCTAssertEqual(garage.title, office.title)
    XCTAssertNotEqual(garage.primary, office.primary)
    XCTAssertEqual(FounderDeskDevice.server.title, "Company Server")
  }

  func testDeviceAccessibilityLabelsAreNamedAndTruthSafe() {
    for device in FounderDeskDevice.allCases {
      let preview = FounderDeskPreviewPolicy.preview(for: device, input: input())
      XCTAssertTrue(preview.accessibilityLabel.localizedCaseInsensitiveContains(device.title.components(separatedBy: " ").last ?? device.title))
      assertNoHiddenTruth(in: preview)
    }
  }

  private func input(
    visibleWorkCount: Int = 0,
    visibleReviewCount: Int = 0,
    canCommit: Bool = false,
    latestPublishedHeadline: String? = nil,
    ventureObjective: String = "Complete the visible objective",
    ventureObjectiveComplete: Bool = false,
    facilityName: String = "Founder Garage",
    ownedFacilityCount: Int = 1
  ) -> FounderDeskPreviewInput {
    FounderDeskPreviewInput(
      sprint: 3,
      venture: 1,
      sprintPhase: visibleReviewCount > 0 ? .reviewAndResolve : .chooseCommitments,
      visibleWorkCount: visibleWorkCount,
      visibleReviewCount: visibleReviewCount,
      evidenceCount: 2,
      canCommit: canCommit,
      latestPublishedHeadline: latestPublishedHeadline,
      marketRank: 4,
      ventureObjective: ventureObjective,
      ventureObjectiveComplete: ventureObjectiveComplete,
      facilityName: facilityName,
      achievementCount: 3,
      ownedFacilityCount: ownedFacilityCount
    )
  }

  private func assertNoHiddenTruth(in preview: FounderDeskPreview, file: StaticString = #filePath, line: UInt = #line) {
    let text = [preview.title, preview.primary, preview.secondary, preview.signal, preview.accessibilityLabel]
      .compactMap { $0 }
      .joined(separator: " ")
      .lowercased()
    for forbidden in ["actual quality", "correctness", "overclaim", "drift", "hidden risk", "evidence complete", "verified outcome"] {
      XCTAssertFalse(text.contains(forbidden), "Desk chrome leaked \(forbidden)", file: file, line: line)
    }
  }
}
