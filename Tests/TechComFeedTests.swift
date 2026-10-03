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

  func testNarrativeDirectorUsesLatestPublicPlayerEventAsLeadBeat() throws {
    let older = PublicMediaEvent(
      id: "launch-older",
      program: .techComLive,
      tone: .favorable,
      headline: "SOLO ships an early win",
      summary: "The company posts a public launch milestone.",
      tickerItems: ["SOLO SHIPS"],
      coverageDelta: 5,
      venture: 2,
      sprint: 2,
      concernsPlayerCompany: true
    )
    let latest = PublicMediaEvent(
      id: "latent-issue-surfaced",
      program: .breaking,
      tone: .critical,
      headline: "SOLO launch hits a production defect",
      summary: "A delayed issue surfaced in production.",
      tickerItems: ["SOLO PRODUCTION DEFECT"],
      coverageDelta: -8,
      venture: 2,
      sprint: 3,
      concernsPlayerCompany: true
    )

    let snapshot = NarrativeDirector.evaluate(
      publicEvents: [older, latest],
      stats: FounderStats(),
      standings: [],
      venture: 2,
      sprint: 3
    )
    let beat = try XCTUnwrap(snapshot.leadBeat)

    XCTAssertEqual(beat.sourceEventID, latest.id)
    XCTAssertEqual(beat.thread, .credibility)
    XCTAssertEqual(beat.headline, latest.headline)
    XCTAssertEqual(beat.preferredProgram, .breaking)
  }

  func testNarrativeDirectorRejectsPrivateAndNonPlayerEvents() throws {
    let privateEvent = PublicMediaEvent(
      id: "private-story",
      program: .breaking,
      tone: .critical,
      headline: "Hidden truth",
      summary: "This should never become narrative input.",
      tickerItems: [],
      coverageDelta: -15,
      venture: 1,
      sprint: 1,
      concernsPlayerCompany: true,
      isPublic: false
    )
    let rivalEvent = PublicMediaEvent(
      id: "rival-story",
      program: .rivalWatch,
      tone: .critical,
      headline: "A rival has trouble",
      summary: "This concerns another company.",
      tickerItems: [],
      coverageDelta: -10,
      venture: 1,
      sprint: 1,
      concernsPlayerCompany: false
    )

    let snapshot = NarrativeDirector.evaluate(
      publicEvents: [privateEvent, rivalEvent],
      stats: FounderStats(),
      standings: [],
      venture: 1,
      sprint: 1
    )
    let beat = try XCTUnwrap(snapshot.leadBeat)

    XCTAssertNil(beat.sourceEventID)
    XCTAssertEqual(beat.id, "state-operating-posture-v1-s1")
  }

  func testTechComProjectsCanonicalPublicEventInsteadOfGenericStateStory() throws {
    var stats = FounderStats()
    stats.coverage = 72
    let event = PublicMediaEvent(
      id: "funding-demo-awarded",
      program: .breaking,
      tone: .favorable,
      headline: "SOLO secures Demo Grant",
      summary: "The company received $50K in non-dilutive funding.",
      tickerItems: ["SOLO AWARDED $50K"],
      coverageDelta: 0,
      venture: 2,
      sprint: 4,
      concernsPlayerCompany: true
    )

    let posts = TechComFeedEngine.posts(
      venture: 2,
      sprint: 4,
      stats: stats,
      standings: [],
      publicEvents: [event]
    )
    let press = try XCTUnwrap(posts.first { $0.kind == .pressInquiry })

    XCTAssertEqual(press.headline, event.headline)
    XCTAssertEqual(press.body, event.summary)
    XCTAssertEqual(press.actions.first(where: { $0.id == "statement" })?.label, "Put the proof on record")
  }

  func testNarrativeDirectorIsDeterministicForSameInputs() {
    let event = PublicMediaEvent(
      id: "public-story",
      program: .techComLive,
      tone: .favorable,
      headline: "SOLO earns attention",
      summary: "A public milestone moves through the media cycle.",
      tickerItems: ["SOLO UPDATE"],
      coverageDelta: 6,
      venture: 3,
      sprint: 1,
      concernsPlayerCompany: true
    )

    let first = NarrativeDirector.evaluate(publicEvents: [event], stats: FounderStats(), standings: [], venture: 3, sprint: 1)
    let second = NarrativeDirector.evaluate(publicEvents: [event], stats: FounderStats(), standings: [], venture: 3, sprint: 1)

    XCTAssertEqual(first, second)
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
