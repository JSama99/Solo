import XCTest
@testable import Solo_Unicorn_Run

final class HowToPlayContentTests: XCTestCase {
  func testSprintLoopMatchesRealPhaseOrder() {
    XCTAssertEqual(HowToPlayContent.phases.map(\.0), SprintPhase.allCases)
  }
  func testDoctrineDescriptionsUseLiveProfiles() {
    for doctrine in FounderDoctrine.allCases {
      let profile = DoctrineProfile.profile(for: doctrine)
      let text = HowToPlayContent.doctrineDescription(doctrine)
      XCTAssertTrue(text.contains("\(profile.attentionMaximum)"))
      XCTAssertTrue(text.contains("\(profile.reviewEnergyCost)"))
      XCTAssertTrue(text.contains("\(profile.actualQualityBonus)"))
    }
  }
  func testEverySectionHasContent() {
    XCTAssertTrue(HowToPlayContent.sections.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
    XCTAssertTrue(HowToPlayContent.phases.allSatisfy { !$0.1.isEmpty })
  }
}
