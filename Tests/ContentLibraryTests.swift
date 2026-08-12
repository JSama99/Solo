import XCTest
@testable import Solo_Unicorn_Run

final class ContentLibraryTests: XCTestCase {
  func testEmpireExpansionIsIncludedInTaskPool() {
    XCTAssertEqual(ContentLibrary.empireTaskExpansion.count, 40)
    XCTAssertEqual(ContentLibrary.allTaskPool.count, 307)
    XCTAssertTrue(ContentLibrary.allTaskPool.contains { $0.title == "Shard the Data Layer" })
    XCTAssertTrue(ContentLibrary.allTaskPool.contains { $0.title == "Mentor the Next Owner" })
  }
}
