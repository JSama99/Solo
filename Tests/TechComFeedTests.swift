import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class TechComFeedTests: XCTestCase {
  func testFeedIsDeterministicAndDoesNotUseRNG() {
    let generator = SeededRandomNumberGenerator(seed: 44)
    let before = generator
    let standings = RivalEngine.standings(companies: ContentLibrary.rivalSimulationCompanies, venture: 2, sprint: 3, careerSeed: 7, player: FounderStats(), playerFlags: [])
    XCTAssertEqual(TechComFeedEngine.posts(venture: 2, sprint: 3, stats: FounderStats(), standings: standings), TechComFeedEngine.posts(venture: 2, sprint: 3, stats: FounderStats(), standings: standings))
    XCTAssertEqual(generator, before)
  }

  func testHighCoverageTurnsPressInquiryIntoSpotlightNarrative() throws {
    var stats = FounderStats()
    stats.coverage = 67

    let posts = TechComFeedEngine.posts(venture: 2, sprint: 4, stats: stats, standings: [])
    let press = try XCTUnwrap(posts.first { $0.kind == .pressInquiry })

    XCTAssertEqual(press.headline, "Tech.com puts SOLO under the spotlight")
    XCTAssertTrue(press.body.contains("+67"))
    XCTAssertEqual(press.actions.first(where: { $0.id == "statement" })?.label, "Own the spotlight")
  }

  func testLowTrustTurnsPressInquiryIntoCredibilityNarrative() throws {
    var stats = FounderStats()
    stats.coverage = -12
    stats.trust = 31

    let posts = TechComFeedEngine.posts(venture: 1, sprint: 5, stats: stats, standings: [])
    let press = try XCTUnwrap(posts.first { $0.kind == .pressInquiry })

    XCTAssertEqual(press.headline, "Tech.com questions SOLO's credibility")
    XCTAssertTrue(press.body.contains("trust 31"))
    XCTAssertEqual(press.actions.first(where: { $0.id == "statement" })?.label, "Answer with evidence")
  }

  func testStrongOperatingStateProducesDurabilityNarrative() throws {
    var stats = FounderStats()
    stats.coverage = 20
    stats.trust = 72
    stats.momentum = 76

    let posts = TechComFeedEngine.posts(venture: 3, sprint: 2, stats: stats, standings: [])
    let press = try XCTUnwrap(posts.first { $0.kind == .pressInquiry })

    XCTAssertEqual(press.headline, "Tech.com asks whether SOLO's momentum is durable")
    XCTAssertTrue(press.body.contains("Momentum is 76"))
    XCTAssertTrue(press.body.contains("trust at 72"))
  }

  func testStatementBudgetAndCoverageClamp() {
    let store = GameStore()
    store.startCareer(seed: 18)
    store.confirmVentureThesisIfNeeded()
    let post = store.feedPosts.first { $0.kind == .pressInquiry }!
    store.resolveFeed(postID: post.id, actionID: "statement")
    XCTAssertFalse(store.statementAvailable)
    XCTAssertEqual(store.stats.coverage, 12)
  }

  func testResolvedFeedActionCannotExecuteTwice() {
    let store = GameStore()
    store.startCareer(seed: 18)
    store.confirmVentureThesisIfNeeded()
    let post = store.feedPosts.first { $0.kind == .pressInquiry }!

    store.resolveFeed(postID: post.id, actionID: "statement")
    let coverage = store.stats.coverage
    let spent = store.statementSpent
    store.resolveFeed(postID: post.id, actionID: "silence")

    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertEqual(store.statementSpent, spent)
    XCTAssertEqual(store.feedPosts.first { $0.id == post.id }?.resolvedActionID, "statement")
  }
}
