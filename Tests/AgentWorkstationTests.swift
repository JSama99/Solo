import XCTest
@testable import Solo_Unicorn_Run

final class AgentWorkstationTests: XCTestCase {
  func testPortraitAssetMappingPreservesAgentIdentity() {
    XCTAssertEqual(AgentPortraitAsset.name(for: "aurora"), "agent_aurora_portrait")
    XCTAssertEqual(AgentPortraitAsset.name(for: "stacks"), "agent_stacks_portrait")
    XCTAssertEqual(AgentPortraitAsset.name(for: "brio"), "agent_brio_portrait")
  }

  func testUnknownAgentUsesInitialsFallback() {
    XCTAssertNil(AgentPortraitAsset.name(for: "unknown"))
  }
}
