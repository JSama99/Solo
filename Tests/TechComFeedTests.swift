import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class TechComFeedTests: XCTestCase {
  func testFeedIsDeterministicAndDoesNotUseRNG() {
    var generator = SeededRandomNumberGenerator(seed: 44)
    let before = generator
    let standings = RivalEngine.standings(companies: ContentLibrary.rivalSimulationCompanies, venture: 2, sprint: 3, careerSeed: 7, player: FounderStats(), playerFlags: [])
    XCTAssertEqual(TechComFeedEngine.posts(venture: 2, sprint: 3, stats: FounderStats(), standings: standings), TechComFeedEngine.posts(venture: 2, sprint: 3, stats: FounderStats(), standings: standings))
    XCTAssertEqual(generator, before)
  }

  func testStatementBudgetAndCoverageClamp() {
    let store = GameStore()
    store.startCareer(seed: 18)
    let post = store.feedPosts.first { $0.kind == .pressInquiry }!
    store.resolveFeed(postID: post.id, actionID: "statement")
    XCTAssertFalse(store.statementAvailable)
    XCTAssertEqual(store.stats.coverage, 12)
  }
}
