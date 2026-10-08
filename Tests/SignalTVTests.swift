import XCTest
import SwiftUI
import UIKit
import RealityKit
@testable import Solo_Unicorn_Run

@MainActor
final class SignalTVBroadcastDesignTests: XCTestCase {
  func testTickerCoordinatesKeepItemsAndDuplicateTracksSeparatedAcrossWidths() {
    for viewport in [268.0, 430, 780] {
      for widths in [[45.0, 210, 85], [110.0], [800.0, 65]] {
        let layout = SignalTVTickerLayout(widths: widths, viewportWidth: viewport)
        for index in widths.indices.dropLast() {
          XCTAssertEqual(layout.starts[index + 1] - (layout.starts[index] + widths[index]), 32, accuracy: 0.001)
        }
        let end = layout.starts.last! + widths.last!
        XCTAssertGreaterThanOrEqual(layout.period - end, 32)
        XCTAssertGreaterThanOrEqual(layout.period, viewport)
        for elapsed in [0.0, 9, 18, 35.999, 36, 72] {
          XCTAssertGreaterThanOrEqual(layout.offset(at: elapsed), 0)
          XCTAssertLessThan(layout.offset(at: elapsed), layout.period)
          XCTAssertEqual(layout.period - layout.offset(at: elapsed) - (end - layout.offset(at: elapsed)), layout.period - end, accuracy: 0.001)
        }
      }
    }
  }

  func testTickerGeometryHasStableSeamAndRejectsInvalidDimensions() {
    let layout = SignalTVTickerLayout(widths: [.nan, -4, 80], viewportWidth: .infinity, gap: -1)
    XCTAssertEqual(layout.widths, [0, 0, 80])
    XCTAssertEqual(layout.gap, 24)
    XCTAssertEqual(layout.offset(at: 36), 0)
    XCTAssertEqual(layout.offset(at: 18), layout.period / 2)
    XCTAssertEqual(layout.offset(at: -18), layout.period / 2)
  }

  func testFiveProgramsHaveDistinctTextSymbolsAndAccents() {
    let expected: [(SignalTVProgram, String, String, SignalTVProgramAccent)] = [
      (.marketPulse, "MARKET DESK", "square.grid.3x3", .mint),
      (.techComLive, "LIVE", "dot.radiowaves.left.and.right", .cyan),
      (.rivalWatch, "COMPETITION DESK", "building.2.crop.circle", .violet),
      (.breaking, "PUBLIC NEWS ALERT", "bolt.horizontal.circle", .coral),
      (.founderSpotlight, "FOUNDER FEATURE", "star.circle", .gold)
    ]
    for (program, desk, symbol, accent) in expected {
      let identity = SignalTVProgramIdentity(program: program)
      XCTAssertEqual(identity.program, program)
      XCTAssertEqual(identity.desk, desk)
      XCTAssertEqual(identity.symbol, symbol)
      XCTAssertEqual(identity.accent, accent)
    }
    XCTAssertEqual(Set(expected.map { $0.1 }).count, SignalTVProgram.allCases.count)
  }

  func testMotionAndTransitionsRespectBothAccessibilityAndPauseEndpoints() {
    let event = SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
    let normal = SignalTVBroadcastDesign.derive(event: event, reduceMotion: false)
    let reduced = SignalTVBroadcastDesign.derive(event: event, reduceMotion: true)
    let paused = SignalTVBroadcastDesign.derive(event: event, reduceMotion: false, continuousMotionEnabled: false)
    XCTAssertTrue(normal.continuousMotionEnabled)
    XCTAssertFalse(reduced.continuousMotionEnabled)
    XCTAssertFalse(paused.continuousMotionEnabled)
    XCTAssertEqual(reduced.transitionDuration, 0)
    XCTAssertEqual(paused.transitionDuration, 0)
    XCTAssertEqual(normal.identity, reduced.identity)
    XCTAssertEqual(normal.tickerItems, reduced.tickerItems)
  }

  func testTickerAndSummaryContainOnlyAuthorizedEventContent() {
    var event = SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
    event.tickerItems = ["EXACT PUBLIC ITEM"]
    let design = SignalTVBroadcastDesign.derive(event: event, reduceMotion: false)
    XCTAssertEqual(design.tickerItems, event.tickerItems)
    XCTAssertEqual(design.supportingSummary, event.summary)
    event.summary = event.headline
    XCTAssertNil(SignalTVBroadcastDesign.derive(event: event, reduceMotion: false).supportingSummary)
    event.tickerItems = []
    XCTAssertTrue(SignalTVBroadcastDesign.derive(event: event, reduceMotion: false).tickerItems.isEmpty)
    event.isPublic = false
    let hidden = SignalTVBroadcastDesign.derive(event: event, reduceMotion: false)
    XCTAssertTrue(hidden.tickerItems.isEmpty)
    XCTAssertNil(hidden.supportingSummary)
    event.isPublic = true
    event.headline = "SOLO review finds private overclaim"
    XCTAssertTrue(SignalTVBroadcastDesign.derive(event: event, reduceMotion: false).tickerItems.isEmpty)
  }

  func testPhysicalGarageScreenUsesSamePrimaryAndCachesTextureAcrossUpdates() throws {
    let world = FounderGarageRealityWorld()
    let ambient = SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
    let primary = PublicMediaEvent(id: "latent-screen-surfaced", program: .breaking, tone: .critical,
      headline: "A public production defect", summary: "The issue has surfaced publicly.", tickerItems: ["PUBLIC ISSUE"],
      coverageDelta: -10, venture: 1, sprint: 1, concernsPlayerCompany: true)
    try world.applySignalTVBroadcast([ambient, primary])
    XCTAssertEqual(world.signalTVStory, NarrativeStoryCompetition.selectPrimaryStory(from: [primary, ambient]))
    let screen = try XCTUnwrap(world.entities.signalTV.findEntity(named: "SignalTV.Broadcast.Screen") as? ModelEntity)
    XCTAssertTrue(world.entities.signalTV.isEnabled)
    XCTAssertEqual(screen.model?.materials.count, 1)
    XCTAssertEqual(world.signalTVTextureRefreshCount, 1)
    try world.applySignalTVBroadcast([primary, ambient])
    XCTAssertEqual(world.signalTVTextureRefreshCount, 1)
    XCTAssertEqual(world.entities.signalTV.findEntity(named: "SignalTV.Broadcast.Screen")?.id, screen.id)
    var updated = primary
    updated.headline = "An updated authorized headline"
    try world.applySignalTVBroadcast([updated, ambient])
    XCTAssertEqual(world.signalTVTextureRefreshCount, 2)
    XCTAssertEqual(world.signalTVStory, updated)
    updated.isPublic = false
    try world.applySignalTVBroadcast([updated, ambient])
    XCTAssertEqual(world.signalTVStory, ambient)
  }

  func testPublicImportanceAndPresentationDoNotChangeSelectedTruthCoverageOrRNG() throws {
    defer { UserDefaults.standard.removeObject(forKey: GameStore.saveKey) }
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 48_007)
    store.confirmVentureThesisIfNeeded()
    let story = PublicMediaEvent(id: "latent-public-surfaced", program: .breaking, tone: .critical,
      headline: "A public production issue surfaced", summary: "A publicly reported consequence.",
      tickerItems: ["PUBLIC CONSEQUENCE"], coverageDelta: -10, venture: 1, sprint: 1, concernsPlayerCompany: true)
    store.applyPublicMediaEvent(story)
    let ledger = store.publicMediaEvents
    let rng = store.randomNumberGenerator
    let coverage = store.stats.coverage
    let primary = try XCTUnwrap(NarrativeStoryCompetition.selectPrimaryStory(from: ledger))
    for _ in 0..<10 {
      let normal = SignalTVBroadcastDesign.derive(event: primary, reduceMotion: false)
      XCTAssertEqual(normal, SignalTVBroadcastDesign.derive(event: primary, reduceMotion: false))
      XCTAssertEqual(normal.prominence, .major)
      XCTAssertEqual(normal.supportingSummary, story.summary)
      XCTAssertEqual(normal.identity.program, story.program)
    }
    XCTAssertEqual(NarrativeStoryCompetition.selectPrimaryStory(from: ledger), primary)
    XCTAssertEqual(store.publicMediaEvents, ledger)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }
}

@MainActor
final class NarrativeStoryCompetitionTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    super.tearDown()
  }

  func testImportancePlayerRelevanceAndBreakingConsequencePriority() throws {
    let major = story("latent-major-surfaced", program: .breaking, delta: -10, sprint: 2)
    let funding = story("funding-grant-awarded", program: .breaking, sprint: 3)
    XCTAssertEqual(primary([funding, major]), major)
    let unrelated = story("rival-generic", program: .rivalWatch, sprint: 3, player: false)
    XCTAssertEqual(primary([unrelated, funding]), funding)
    let consequence = story("latent-minor-surfaced", program: .breaking, delta: -4, sprint: 3)
    XCTAssertEqual(primary([funding, consequence]), consequence)
    XCTAssertEqual(try XCTUnwrap(NarrativeStoryCompetition.rankedCandidates(from: [major]).first).importance, .major)
  }

  func testFreshStoryAndAmbientProgrammingOutrankRepeatedNonMajorCategory() {
    let rivalA = story("rival-a", program: .rivalWatch, sprint: 2)
    let rivalB = story("rival-b", program: .rivalWatch, sprint: 3)
    let rivalC = story("rival-c", program: .rivalWatch, sprint: 3)
    let fresh = story("funding-grant-awarded", program: .breaking, sprint: 3)
    XCTAssertEqual(primary([rivalA, rivalB, rivalC, fresh]), fresh)
    let market = SignalTVProgramming.marketPulse(venture: 1, sprint: 3)
    XCTAssertEqual(primary([rivalA, rivalB, rivalC, market]), market)
    let milestoneA = story("funding-a-milestone-met", program: .techComLive, sprint: 2)
    let milestoneB = story("funding-b-milestone-met", program: .techComLive, sprint: 3)
    XCTAssertEqual(primary([milestoneA, milestoneB, market]), market)
    let flood = (0..<20).map { story("funding-\($0)-milestone-met", program: .techComLive, sprint: 3) }
    XCTAssertEqual(primary(flood + [market]), market)
    XCTAssertEqual(primary([market] + Array(flood.reversed())), market)
  }

  func testMajorCurrentConsequenceIsNeverSuppressedOrInventedByRecurrence() throws {
    let minor = story("latent-minor-surfaced", program: .breaking, delta: -4, sprint: 2)
    let repeatedMinor = story("latent-second-surfaced", program: .breaking, delta: -4, sprint: 3)
    let fresh = story("funding-grant-awarded", program: .breaking, sprint: 3)
    XCTAssertEqual(primary([minor, repeatedMinor, fresh]), fresh)
    XCTAssertTrue(NarrativeStoryCompetition.rankedCandidates(from: [minor, repeatedMinor]).allSatisfy {
      $0.importance == .significant && $0.fatigued
    })
    let major = story("latent-major-surfaced", program: .breaking, delta: -10, sprint: 3)
    XCTAssertEqual(primary([minor, repeatedMinor, fresh, major]), major)
    XCTAssertFalse(try XCTUnwrap(NarrativeStoryCompetition.rankedCandidates(from: [minor, major]).first).fatigued)
  }

  func testStableTieBreakWindowAndDeduplicationIgnoreInputOrdering() throws {
    let a = story("funding-a-awarded", program: .breaking, sprint: 3)
    let b = story("funding-b-awarded", program: .breaking, sprint: 3)
    XCTAssertEqual(primary([b, a]), a)
    XCTAssertEqual(primary([a, b]), a)
    XCTAssertEqual(NarrativeStoryCompetition.rankedCandidates(from: [a, a]),
      NarrativeStoryCompetition.rankedCandidates(from: [a]))
    XCTAssertFalse(try XCTUnwrap(NarrativeStoryCompetition.rankedCandidates(from: [a, a]).first).fatigued)
    var conflicting = a
    conflicting.summary = "Different legacy duplicate copy"
    XCTAssertEqual(NarrativeStoryCompetition.rankedCandidates(from: [a, conflicting]),
      NarrativeStoryCompetition.rankedCandidates(from: [conflicting, a]))
    let events = (0..<30).map { story(String(format: "rival-%02d", $0), program: .rivalWatch, sprint: 3) }
    let expected = NarrativeStoryCompetition.rankedCandidates(from: events)
    XCTAssertEqual(expected.count, 12)
    for offset in 0..<events.count {
      let rotated = Array(events.dropFirst(offset)) + Array(events.prefix(offset))
      XCTAssertEqual(NarrativeStoryCompetition.rankedCandidates(from: rotated), expected)
      XCTAssertEqual(primary(rotated), primary(events))
    }
    XCTAssertEqual(NarrativeStoryCompetition.rankedCandidates(from: Array(events.reversed())), expected)
  }

  func testSprintCooldownExpiresAndPriorVentureCannotOwnCurrentAttention() throws {
    let old = story("rival-old", program: .rivalWatch, sprint: 1)
    let current = story("rival-new", program: .rivalWatch, sprint: 3)
    let candidates = NarrativeStoryCompetition.rankedCandidates(from: [old, current])
    XCTAssertEqual(candidates.map(\.event.id), [current.id])
    XCTAssertFalse(try XCTUnwrap(candidates.first).fatigued)
    var previousVenture = story("latent-old-surfaced", program: .breaking, delta: -10, sprint: 9)
    previousVenture.venture = 0
    XCTAssertEqual(primary([previousVenture, current]), current)
    // Recency comes before event ID when other priority factors match.
    let newer = story("funding-z-awarded", program: .breaking, sprint: 3)
    let older = story("funding-a-awarded", program: .breaking, sprint: 2)
    XCTAssertEqual(primary([older, newer]), newer)
  }

  func testPrivateFactsCannotSupplyCandidates() throws {
    let store = activeStore()
    let publicStory = story("funding-public-awarded", program: .breaking, sprint: 1)
    store.applyPublicMediaEvent(publicStory)
    let baseline = primary(store.publicMediaEvents)
    XCTAssertTrue(store.pursueFundingOpportunity(id: "pioneer-ai-grant"))
    store.latentDefects.append(LatentDefect(id: "hidden", originVenture: 1, originSprint: 1,
      originTaskTitle: "Hidden task", originAgentName: "Stacks", originEvidenceCompleteness: 5,
      surfacesAtCareerSprint: 5, severity: 30))
    store.techComRivals[0].actualRevenue = 987_654
    let privateReview = FounderReviewNarrativeInput(sourceEventID: "review", venture: 1, sprint: 1,
      founderVisibleOutcome: .overclaimed, disclosure: .privateToFounder)
    XCTAssertNil(MediaNarrativeDirector.decide(event: .founderReview(privateReview)))
    XCTAssertEqual(primary(store.publicMediaEvents), baseline)
    XCTAssertEqual(NarrativeStoryCompetition.rankedCandidates(from: store.publicMediaEvents).map(\.event.id), [publicStory.id])
    var hidden = story("latent-hidden-surfaced", program: .breaking, delta: -15, sprint: 1)
    hidden.isPublic = false
    var legacy = hidden
    legacy.isPublic = true
    legacy.headline = "SOLO review finds private overclaim"
    XCTAssertEqual(primary([hidden, legacy, publicStory]), publicStory)
    XCTAssertNil(primary([hidden, legacy]))
  }

  func testSelectionPreservesLedgerCoverageRNGTechComAndSaveLoad() throws {
    let store = activeStore()
    let major = story("latent-major-surfaced", program: .breaking, delta: -10, sprint: 1)
    let secondary = story("funding-grant-awarded", program: .breaking, sprint: 1)
    store.applyPublicMediaEvent(major)
    store.applyPublicMediaEvent(secondary)
    let ledger = store.publicMediaEvents
    let rng = store.randomNumberGenerator
    let coverage = store.stats.coverage
    for _ in 0..<20 {
      XCTAssertEqual(primary(store.publicMediaEvents), major)
      _ = SignalTVProgramming.ambientEvents(publicEvents: ledger, techComHeadlines: store.techComHeadlines,
        rivals: store.techComRivals, coverage: coverage, venture: 1, sprint: 1)
    }
    XCTAssertEqual(store.publicMediaEvents, ledger)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertTrue(TechComEngine.mergedOwnCompanyHeadlines(headlines: [], publicEvents: ledger).contains {
      $0.publicEventID == secondary.id
    })
    XCTAssertTrue(SignalTVProgramming.publicBroadcastEvents(ledger).contains(secondary))
    // Retained stories remain available for explicit selection or later rotation.
    XCTAssertEqual(primary([secondary]), secondary)
    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(primary(restored.publicMediaEvents), major)
    XCTAssertEqual(restored.publicMediaEvents, ledger)
    XCTAssertEqual(restored.stats.coverage, coverage)
    XCTAssertEqual(restored.randomNumberGenerator, rng)
    XCTAssertFalse(restored.applyPublicMediaEvent(major))
    XCTAssertEqual(restored.stats.coverage, coverage)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testSecondaryContinuityAndBroadcastIntegrationRemainPublicAndUnchanged() throws {
    var opportunity = try XCTUnwrap(FundingBoardCatalog.opportunities.first)
    opportunity.id = "prior"
    let previous = MediaNarrativeEvent.publicFundingProgress(try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: opportunity, outcome: .awarded, venture: 1, sprint: 2)))
    let old = try XCTUnwrap(MediaNarrativeDirector.decide(event: previous)).story
    opportunity.id = "current"
    let current = MediaNarrativeEvent.publicFundingProgress(try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: opportunity, outcome: .awarded, venture: 1, sprint: 3)))
    let secondary = try XCTUnwrap(MediaNarrativeDirector.decide(event: current,
      history: PublicNarrativeHistory(publicEvents: [old], before: current))).story
    let major = story("latent-major-surfaced", program: .breaking, delta: -10, sprint: 3)
    let programming = SignalTVProgramming.ambientEvents(publicEvents: [secondary, major, old],
      techComHeadlines: [], rivals: [], coverage: 0, venture: 1, sprint: 3)
    XCTAssertEqual(primary(programming), major)
    XCTAssertTrue(programming.contains(secondary))
    XCTAssertTrue(secondary.summary.contains("earlier public funding success"))
    XCTAssertEqual(NarrativeStoryCompetition.rankedCandidates(from: programming).first { $0.event.id == secondary.id }?.event, secondary)
    let reduced = SignalTVBroadcastPresentation.derive(event: primary(programming)!, reduceMotion: true)
    let standard = SignalTVBroadcastPresentation.derive(event: primary(programming)!, reduceMotion: false)
    XCTAssertEqual(reduced.state, standard.state)
    XCTAssertFalse(reduced.continuousMotionEnabled)
  }

  private func primary(_ events: [PublicMediaEvent]) -> PublicMediaEvent? {
    NarrativeStoryCompetition.selectPrimaryStory(from: events)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 48_007)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func story(_ id: String, program: SignalTVProgram, delta: Int = 0,
                     sprint: Int, player: Bool = true) -> PublicMediaEvent {
    PublicMediaEvent(id: id, program: program, tone: delta < 0 ? .critical : .favorable,
      headline: "Public story", summary: "Authorized public facts", tickerItems: [], coverageDelta: delta,
      venture: 1, sprint: sprint, concernsPlayerCompany: player)
  }
}

@MainActor
final class PublicNarrativeContinuityTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    super.tearDown()
  }

  func testFirstAndRepeatedPublicEventsUseOnlyMatchingHistoryWithoutChangingPolicy() throws {
    let pairs: [(MediaNarrativeEvent, MediaNarrativeEvent, String)] = [
      (try funding("a", sprint: 1), try funding("b", sprint: 2), "earlier public funding success"),
      (try defect("a", sprint: 1), try defect("b", sprint: 2), "Another surfaced production defect"),
      (rival("a", sprint: 1), rival("b", sprint: 2), "Competitive pressure continues"),
      (launch("a", sprint: 1, favorable: false), launch("b", sprint: 2, favorable: false), "further public launch setback"),
      (launch("a", sprint: 1, favorable: false), launch("b", sprint: 2, favorable: true), "previously reported public launch setback")
    ]
    for (previous, current, text) in pairs {
      let first = try XCTUnwrap(MediaNarrativeDirector.decide(event: current))
      XCTAssertFalse(first.story.summary.contains(text))
      let priorStory = try XCTUnwrap(MediaNarrativeDirector.decide(event: previous)).story
      let history = PublicNarrativeHistory(publicEvents: [priorStory], before: current)
      let second = try XCTUnwrap(MediaNarrativeDirector.decide(event: current, history: history))
      XCTAssertTrue(second.story.summary.contains(text))
      XCTAssertEqual(second, MediaNarrativeDirector.decide(event: current, history: history))
      XCTAssertEqual(second.sourceEventID, first.sourceEventID)
      XCTAssertEqual(second.coverageDelta, first.coverageDelta)
      XCTAssertEqual(second.importance, first.importance)
      XCTAssertEqual(second.program, first.program)
      XCTAssertEqual(second.tone, first.tone)
      XCTAssertEqual(second.story.headline, first.story.headline)
      XCTAssertEqual(second.story.tickerItems, first.story.tickerItems)
      let unrelated = try XCTUnwrap(MediaNarrativeDirector.decide(event: launch("other", sprint: 1, favorable: true))).story
      XCTAssertEqual(MediaNarrativeDirector.decide(event: current,
        history: PublicNarrativeHistory(publicEvents: [unrelated], before: current)), first)
    }
  }

  func testHistoryExcludesCurrentFutureAndDuplicateIDsAndPreservesNewestFirstOrder() throws {
    let current = try funding("current", sprint: 3)
    let ownStory = try XCTUnwrap(MediaNarrativeDirector.decide(event: current)).story
    let old = try XCTUnwrap(MediaNarrativeDirector.decide(event: funding("old", sprint: 1))).story
    let recent = try XCTUnwrap(MediaNarrativeDirector.decide(event: funding("recent", sprint: 2))).story
    let future = try XCTUnwrap(MediaNarrativeDirector.decide(event: funding("future", sprint: 4))).story
    let history = PublicNarrativeHistory(publicEvents: [future, ownStory, recent, recent, ownStory, old], before: current)
    XCTAssertEqual(history.recentEvents.map(\.sourceEventID), [recent.id, old.id])
    let selfOnly = PublicNarrativeHistory(publicEvents: [ownStory, ownStory], before: current)
    XCTAssertTrue(selfOnly.recentEvents.isEmpty)
    XCTAssertEqual(MediaNarrativeDirector.decide(event: current, history: selfOnly),
      MediaNarrativeDirector.decide(event: current))
    let deduplicated = PublicNarrativeHistory(publicEvents: [recent], before: current)
    let duplicated = PublicNarrativeHistory(publicEvents: [recent, recent, recent], before: current)
    XCTAssertEqual(deduplicated, duplicated)
    XCTAssertEqual(MediaNarrativeDirector.decide(event: current, history: deduplicated),
      MediaNarrativeDirector.decide(event: current, history: duplicated))
    XCTAssertEqual(Set(Mirror(reflecting: history.recentEvents[0]).children.compactMap(\.label)),
      ["sourceEventID", "venture", "sprint", "category"])
  }

  func testHistoryHasEightEntryWindowAndThirtyEventScanBound() throws {
    let current = try funding("current", sprint: 10)
    let stories = try (0..<40).map {
      try XCTUnwrap(MediaNarrativeDirector.decide(event: funding("history-\($0)", sprint: 1))).story
    }
    let history = PublicNarrativeHistory(publicEvents: stories, before: current)
    XCTAssertEqual(history.recentEvents.map(\.sourceEventID), Array(stories.prefix(8)).map(\.id))
    var hidden = stories[0]
    hidden.isPublic = false
    XCTAssertTrue(PublicNarrativeHistory(publicEvents: Array(repeating: hidden, count: 30) + stories,
      before: current).recentEvents.isEmpty)
  }

  func testRecoveryUsesMostRecentPublicLaunchAndNeverImpliesCurrentDefect() throws {
    let current = launch("current", sprint: 3, favorable: true)
    let success = try XCTUnwrap(MediaNarrativeDirector.decide(event: launch("success", sprint: 2, favorable: true))).story
    let setback = try XCTUnwrap(MediaNarrativeDirector.decide(event: launch("setback", sprint: 1, favorable: false))).story
    let history = PublicNarrativeHistory(publicEvents: [success, setback], before: current)
    XCTAssertEqual(MediaNarrativeDirector.decide(event: current, history: history), MediaNarrativeDirector.decide(event: current))
    let oldDefect = try XCTUnwrap(MediaNarrativeDirector.decide(event: defect("old", sprint: 1))).story
    XCTAssertEqual(MediaNarrativeDirector.decide(event: current,
      history: PublicNarrativeHistory(publicEvents: [oldDefect], before: current)),
      MediaNarrativeDirector.decide(event: current))
  }

  func testPrivateSimulationAndHindsightCannotSupplyPublicContinuity() throws {
    let store = activeStore()
    let current = try funding("current", sprint: 2)
    let baseline = MediaNarrativeDirector.decide(event: current)
    store.precedents.append(Precedent(id: HindsightEngine.identifier(venture: 1, sprint: 1),
      venture: 1, sprint: 1,
      context: PrecedentContext(doctrine: .guided, intent: .build, driftBand: .high, runwayBand: .low, unverifiedBand: .high),
      decisionSummary: "Private overclaim and financing history",
      outcome: PrecedentOutcome(overclaimsSurfaced: 2, driftDetections: 2)))
    store.latentDefects.append(LatentDefect(id: "PRIVATE", originVenture: 1, originSprint: 1,
      originTaskTitle: "Hidden task", originAgentName: "Stacks", originEvidenceCompleteness: 12,
      surfacesAtCareerSprint: 5, severity: 30))
    XCTAssertTrue(store.pursueFundingOpportunity(id: "pioneer-ai-grant"))
    store.techComRivals[0].actualRevenue = 987_654
    let history = PublicNarrativeHistory(publicEvents: store.publicMediaEvents, before: current)
    XCTAssertTrue(history.recentEvents.isEmpty)
    XCTAssertEqual(MediaNarrativeDirector.decide(event: current, history: history), baseline)
    var hidden = try XCTUnwrap(MediaNarrativeDirector.decide(event: defect("hidden", sprint: 1))).story
    hidden.isPublic = false
    var oldReview = hidden
    oldReview.isPublic = true
    oldReview.headline = "SOLO review finds Stacks's private overclaim"
    XCTAssertTrue(PublicNarrativeHistory(publicEvents: [hidden, oldReview], before: current).recentEvents.isEmpty)
    let review = FounderReviewNarrativeInput(sourceEventID: "review", venture: 1, sprint: 2,
      founderVisibleOutcome: .overclaimed, disclosure: .privateToFounder)
    XCTAssertNil(MediaNarrativeDirector.decide(event: .founderReview(review), history: history))
  }

  func testCanonicalFundingContinuityMatchesAcrossSaveLoadWithoutRNGOrExtraCoverage() throws {
    let store = activeStore()
    let old = try XCTUnwrap(MediaNarrativeDirector.decide(event: funding("prior", sprint: 1))).story
    store.applyPublicMediaEvent(old)
    XCTAssertTrue(store.pursueFundingOpportunity(id: "pioneer-ai-grant"))
    let saved = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    store.sprint = 2
    let current = MediaNarrativeEvent.publicFundingProgress(try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: FundingBoardCatalog.opportunities.first { $0.id == "pioneer-ai-grant" }!,
      outcome: .awarded, venture: 1, sprint: 2)))
    let rng = store.randomNumberGenerator
    let expected = try XCTUnwrap(MediaNarrativeDirector.decide(event: current,
      history: PublicNarrativeHistory(publicEvents: store.publicMediaEvents, before: current))).story
    XCTAssertTrue(store.resolveFundingOpportunity(id: "pioneer-ai-grant"))
    XCTAssertEqual(store.publicMediaEvents.first { $0.id == expected.id }, expected)
    XCTAssertTrue(expected.summary.contains("earlier public funding success"))
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.coverage, 0)
    UserDefaults.standard.set(saved, forKey: GameStore.saveKey)
    let restored = GameStore()
    restored.continueCareer()
    restored.sprint = 2
    XCTAssertTrue(restored.resolveFundingOpportunity(id: "pioneer-ai-grant"))
    XCTAssertEqual(restored.publicMediaEvents.first { $0.id == expected.id }, expected)
    XCTAssertEqual(restored.randomNumberGenerator, rng)
    XCTAssertFalse(restored.applyPublicMediaEvent(expected))
    XCTAssertEqual(restored.publicMediaEvents.filter { $0.id == expected.id }, [expected])
    XCTAssertEqual(restored.stats.coverage, 0)
    XCTAssertEqual(SignalTVProgramming.publicBroadcastEvents(restored.publicMediaEvents).first, expected)
    XCTAssertEqual(TechComEngine.mergedOwnCompanyHeadlines(headlines: [], publicEvents: restored.publicMediaEvents)
      .first?.publicEventID, expected.id)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 48_007)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func funding(_ id: String, sprint: Int) throws -> MediaNarrativeEvent {
    var opportunity = try XCTUnwrap(FundingBoardCatalog.opportunities.first)
    opportunity.id = id
    return .publicFundingProgress(try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: opportunity, outcome: .awarded, venture: 1, sprint: sprint)))
  }

  private func launch(_ id: String, sprint: Int, favorable: Bool) -> MediaNarrativeEvent {
    .productLaunchResolved(PublicLaunchOutcome(sourceEventID: "product-launch-\(id)-resolved", venture: 1, sprint: sprint,
      overall: favorable ? .strong : .weak, marketRating: favorable ? .strong : .weak,
      publicRating: favorable ? .strong : .weak, headline: "SOLO public launch", coverageDelta: favorable ? 8 : -8))
  }

  private func defect(_ id: String, sprint: Int) throws -> MediaNarrativeEvent {
    .surfacedLatentDefect(try XCTUnwrap(LatentDefectPublicMediaProjection.surfaced(
      LatentDefect(id: id, originVenture: 1, originSprint: 1, originTaskTitle: "Public release",
        originAgentName: "Stacks", originEvidenceCompleteness: 13, surfacesAtCareerSprint: sprint, severity: 24),
      venture: 1, sprint: sprint, careerSprint: sprint)))
  }

  private func rival(_ id: String, sprint: Int) -> MediaNarrativeEvent {
    .rivalMove(PublicRivalMoveNarrativeInput(RivalMoveEvent(id: id, rivalID: "fixture", rivalName: "Fixture Co",
      archetype: .copycat, move: .featureCopy, strengthBonus: 0.1, playerEffects: SimulationEffects(trust: -1),
      headline: "Fixture Co copies a public feature"), venture: 1, sprint: sprint))
  }
}

@MainActor
final class FundingNarrativeTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    super.tearDown()
  }

  func testPublicFundingAndMilestoneDecisionsAreStableAndNarrow() throws {
    let store = activeStore()
    let rng = store.randomNumberGenerator
    let finance = store.finance
    let round = try opportunity("founder-conviction-round")
    let grant = try opportunity("pioneer-ai-grant")
    let inputs = [
      try XCTUnwrap(FundingPublicMediaProjection.resolution(opportunity: grant, outcome: .awarded, venture: 1, sprint: 2)),
      try XCTUnwrap(FundingPublicMediaProjection.resolution(opportunity: round, outcome: .funded, venture: 1, sprint: 7)),
      try XCTUnwrap(FundingPublicMediaProjection.milestoneMet(opportunity: round, obligation: obligation(.met), venture: 1, sprint: 9))
    ]
    let programs: [SignalTVProgram] = [.breaking, .founderSpotlight, .techComLive]
    for (input, program) in zip(inputs, programs) {
      let decision = try XCTUnwrap(MediaNarrativeDirector.decide(event: .publicFundingProgress(input)))
      for _ in 0..<10 {
        XCTAssertEqual(MediaNarrativeDirector.decide(event: .publicFundingProgress(input)), decision)
      }
      XCTAssertEqual(decision.program, program)
      XCTAssertEqual(decision.importance, input.progress == .funded ? .major : .significant)
      XCTAssertEqual(decision.tone, .favorable)
      XCTAssertEqual(decision.story.id, input.sourceEventID)
      XCTAssertEqual(decision.story.headline, input.headline)
      XCTAssertEqual(decision.story.summary, input.summary)
      XCTAssertEqual(decision.coverageDelta, 0)
      XCTAssertTrue(decision.story.isPublic)
      XCTAssertEqual(Set(Mirror(reflecting: input).children.compactMap(\.label)),
        ["sourceEventID", "progress", "headline", "summary", "tickerItems", "venture", "sprint", "coverageDelta"])
    }
    XCTAssertEqual(store.finance, finance)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertTrue(store.publicMediaEvents.isEmpty)
    XCTAssertEqual(store.stats.coverage, 0)
    XCTAssertNil(FundingPublicMediaProjection.resolution(opportunity: grant, outcome: .declined, venture: 1, sprint: 2))
    for status in [FundingMilestoneStatus.active, .missed] {
      let input = FundingPublicMediaProjection.milestoneMet(opportunity: round,
        obligation: obligation(status), venture: 1, sprint: 9)
      XCTAssertNil(input)
      XCTAssertNil(input.flatMap { MediaNarrativeDirector.decide(event: .publicFundingProgress($0)) })
    }
  }

  func testApplicationPendingAndDeclineRemainPrivateAcrossReload() throws {
    let store = activeStore()
    let rng = store.randomNumberGenerator
    XCTAssertTrue(store.pursueFundingOpportunity(id: "pioneer-ai-grant"))
    XCTAssertFalse(store.resolveFundingOpportunity(id: "pioneer-ai-grant"))
    assertNoFundingMedia(store)
    let restored = GameStore()
    restored.continueCareer()
    assertNoFundingMedia(restored)
    restored.sprint = 2
    restored.stats.trust = 40
    XCTAssertTrue(restored.resolveFundingOpportunity(id: "pioneer-ai-grant"))
    XCTAssertEqual(restored.finance.fundingApplications.first?.outcome, .declined)
    assertNoFundingMedia(restored)
    XCTAssertEqual(restored.randomNumberGenerator, rng)
  }

  func testCanonicalFundingSuccessPublishesDirectorStoryOnce() throws {
    let store = activeStore()
    let grant = try opportunity("pioneer-ai-grant")
    XCTAssertTrue(store.pursueFundingOpportunity(id: grant.id))
    store.sprint = 2
    let rng = store.randomNumberGenerator
    XCTAssertTrue(store.resolveFundingOpportunity(id: grant.id))
    let input = try XCTUnwrap(FundingPublicMediaProjection.resolution(opportunity: grant,
      outcome: .awarded, venture: 1, sprint: 2))
    let story = try XCTUnwrap(MediaNarrativeDirector.decide(event: .publicFundingProgress(input))).story
    try assertSinglePersistedStory(story, store: store)
    XCTAssertFalse(store.resolveFundingOpportunity(id: grant.id))
    XCTAssertEqual(store.randomNumberGenerator, rng)
  }

  func testOnlyCanonicallyCompletedCompanyMilestonePublishesAndPersistsOnce() throws {
    let store = activeStore()
    store.sprint = 9
    store.stats.revenue = 4_500
    store.finance.fundingApplications = [FundingApplicationRecord(
      opportunityID: "founder-conviction-round", status: .resolved,
      appliedCareerSprint: 6, resolvedCareerSprint: 7, outcome: .funded,
      milestoneObligation: obligation(.active))]
    store.updateFundingLifecycleForCurrentSprint()
    assertNoFundingMedia(store)
    let rng = store.randomNumberGenerator
    store.stats.revenue = 6_200
    store.updateFundingLifecycleForCurrentSprint()
    store.updateFundingLifecycleForCurrentSprint()
    let met = try XCTUnwrap(store.finance.fundingApplications.first?.milestoneObligation)
    let input = try XCTUnwrap(FundingPublicMediaProjection.milestoneMet(
      opportunity: opportunity("founder-conviction-round"), obligation: met, venture: 1, sprint: 9))
    let story = try XCTUnwrap(MediaNarrativeDirector.decide(event: .publicFundingProgress(input))).story
    try assertSinglePersistedStory(story, store: store)
    XCTAssertEqual(store.randomNumberGenerator, rng)
  }

  private func assertSinglePersistedStory(_ story: PublicMediaEvent, store: GameStore) throws {
    XCTAssertEqual(store.publicMediaEvents.filter { $0.id == story.id }, [story])
    XCTAssertFalse(store.applyPublicMediaEvent(story))
    XCTAssertFalse(store.applyPublicMediaEvent(story))
    XCTAssertEqual(store.stats.coverage, 0)
    let headlines = TechComEngine.mergedOwnCompanyHeadlines(headlines: store.techComHeadlines,
      publicEvents: store.publicMediaEvents)
    XCTAssertEqual(headlines.filter { $0.publicEventID == story.id }.count, 1)
    XCTAssertEqual(SignalTVProgramming.publicBroadcastEvents(store.publicMediaEvents).filter { $0.id == story.id }, [story])
    let restored = GameStore()
    restored.continueCareer()
    restored.updateFundingLifecycleForCurrentSprint()
    XCTAssertFalse(restored.applyPublicMediaEvent(story))
    XCTAssertEqual(restored.publicMediaEvents.filter { $0.id == story.id }, [story])
    XCTAssertEqual(restored.stats.coverage, 0)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  private func assertNoFundingMedia(_ store: GameStore) {
    XCTAssertFalse(store.publicMediaEvents.contains { $0.id.hasPrefix("funding-") })
    XCTAssertFalse(TechComEngine.mergedOwnCompanyHeadlines(headlines: store.techComHeadlines,
      publicEvents: store.publicMediaEvents).contains { $0.publicEventID?.hasPrefix("funding-") == true })
    XCTAssertFalse(SignalTVProgramming.ambientEvents(publicEvents: store.publicMediaEvents,
      techComHeadlines: store.techComHeadlines, rivals: [], coverage: store.stats.coverage,
      venture: store.venture, sprint: store.sprint).contains { $0.id.hasPrefix("funding-") })
    XCTAssertEqual(store.stats.coverage, 0)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 48_006)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func opportunity(_ id: String) throws -> FundingOpportunity {
    try XCTUnwrap(FundingBoardCatalog.opportunities.first { $0.id == id })
  }

  private func obligation(_ status: FundingMilestoneStatus) -> FundingMilestoneObligation {
    FundingMilestoneObligation(metric: .revenue, target: 6_000, createdCareerSprint: 7,
      dueCareerSprint: 11, missedTrustConsequence: 6, status: status,
      resolvedCareerSprint: status == .active ? nil : 9)
  }
}

@MainActor
final class RivalNarrativeTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    super.tearDown()
  }

  func testExistingPublicMovesReceiveDeterministicRivalWatchTreatmentWithoutCoverageTuning() throws {
    let store = activeStore()
    let rng = store.randomNumberGenerator
    let standings = store.rivalStandings
    let moves = store.rivalMoveEvents
    for move in RivalMove.allCases {
      let input = PublicRivalMoveNarrativeInput(event(move), venture: 2, sprint: 3)
      let decision = MediaNarrativeDirector.decide(event: .rivalMove(input))
      if move == .steadyBuild {
        XCTAssertNil(decision)
        continue
      }
      let story = try XCTUnwrap(decision).story
      for _ in 0..<10 {
        XCTAssertEqual(MediaNarrativeDirector.decide(event: .rivalMove(input)), decision)
      }
      XCTAssertEqual(story.id, input.sourceEventID)
      XCTAssertEqual(story.headline, input.headline)
      XCTAssertEqual(story.program, .rivalWatch)
      XCTAssertEqual(story.tone, move == .overreach ? .critical : .neutral)
      XCTAssertTrue(story.isPublic)
      XCTAssertEqual(story.coverageDelta, 0, "Production defines no rival-move media Coverage delta")
      XCTAssertFalse(store.applyPublicMediaEvent(story))
      XCTAssertEqual(store.stats.coverage, 0)
      switch move {
      case .prBlitz, .priceUndercut, .featureCopy, .talentPoach:
        XCTAssertTrue(story.concernsPlayerCompany)
      default:
        XCTAssertFalse(story.concernsPlayerCompany)
      }
    }
    XCTAssertEqual(store.rivalStandings, standings)
    XCTAssertEqual(store.rivalMoveEvents, moves)
    XCTAssertEqual(store.randomNumberGenerator, rng)
  }

  func testProjectionDoesNotCarryPrivateRivalInternalsOrGameplayEffects() throws {
    let original = event(.featureCopy)
    var altered = original
    altered.archetype = .hypeMachine
    altered.strengthBonus = 9_999
    altered.playerEffects = SimulationEffects(revenue: -9_999, momentum: -99, trust: -99)
    let first = PublicRivalMoveNarrativeInput(original, venture: 2, sprint: 3)
    let second = PublicRivalMoveNarrativeInput(altered, venture: 2, sprint: 3)
    XCTAssertEqual(first, second)
    XCTAssertEqual(MediaNarrativeDirector.decide(event: .rivalMove(first)),
      MediaNarrativeDirector.decide(event: .rivalMove(second)))
    XCTAssertEqual(Set(Mirror(reflecting: first).children.compactMap(\.label)),
      ["sourceEventID", "rivalID", "rivalName", "move", "headline", "venture", "sprint"])
    let story = try XCTUnwrap(MediaNarrativeDirector.decide(event: .rivalMove(first))).story
    let copy = ([story.headline, story.summary] + story.tickerItems).joined(separator: " ")
    for term in ["9999", "archetype", "drift", "actual", "roll", "verification", "evidence"] {
      XCTAssertFalse(copy.localizedCaseInsensitiveContains(term))
    }
  }

  func testUnverifiedActualMetricsCannotProducePublicMoveCopy() {
    let store = activeStore()
    let coverage = store.stats.coverage
    let rng = store.randomNumberGenerator
    let publicEvents = store.publicMediaEvents
    let rival = TechComRival(id: "fixture", name: "Fixture Co", claimedTrackRecord: 70,
      actualTrackRecord: 11, claimedRevenue: 800, actualRevenue: 123_456,
      claimedMomentum: 60, actualMomentum: 12)
    var changed = rival
    changed.actualTrackRecord = 987_654
    changed.actualRevenue = 987_654
    changed.actualMomentum = 987_654
    store.techComRivals = [changed]
    XCTAssertEqual(store.publicMediaEvents, publicEvents)
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertTrue(TechComEngine.mergedRivalHeadlines(headlines: [], publicEvents: publicEvents).isEmpty)
    func broadcast(_ rival: TechComRival) -> [PublicMediaEvent] {
      SignalTVProgramming.ambientEvents(publicEvents: publicEvents, techComHeadlines: [],
        rivals: [rival], coverage: coverage, venture: 1, sprint: 1)
    }
    // Ambient Rival Watch uses public identity only; private metrics cannot
    // change its story or be promoted into a resolved rival-move narrative.
    XCTAssertEqual(broadcast(rival), broadcast(changed))
    XCTAssertTrue(TechComPresentation.rivalMetrics(for: changed).allSatisfy { $0.actualValue == nil })
    changed.isVerified = true
    XCTAssertTrue(TechComPresentation.rivalMetrics(for: changed).allSatisfy { $0.actualValue != nil })
  }

  func testPublicLedgerReflectionDeduplicatesRivalStoriesAndSurvivesSaveLoad() throws {
    let store = activeStore()
    let input = PublicRivalMoveNarrativeInput(event(.prBlitz), venture: 2, sprint: 3)
    let story = try XCTUnwrap(MediaNarrativeDirector.decide(event: .rivalMove(input))).story
    XCTAssertFalse(store.applyPublicMediaEvent(story))
    XCTAssertFalse(store.applyPublicMediaEvent(story))
    XCTAssertEqual(store.publicMediaEvents.filter { $0.id == story.id }, [story])
    let restored = GameStore()
    restored.continueCareer()
    XCTAssertFalse(restored.applyPublicMediaEvent(story))
    XCTAssertEqual(restored.stats.coverage, 0)
    XCTAssertEqual(restored.publicMediaEvents.filter { $0.id == story.id }, [story])
    let legacy = TechComHeadline(id: UUID(), category: .rival, text: story.headline,
      venture: story.venture, sprint: story.sprint)
    let reflected = TechComEngine.mergedRivalHeadlines(
      headlines: [legacy], publicEvents: [story, story]
    )
    XCTAssertEqual(reflected.count, 1)
    XCTAssertEqual(reflected.first?.publicEventID, input.sourceEventID)
    XCTAssertEqual(reflected, TechComEngine.mergedRivalHeadlines(
      headlines: [legacy], publicEvents: [story]
    ))
    var privateStory = story
    privateStory.isPublic = false
    XCTAssertTrue(TechComEngine.mergedRivalHeadlines(headlines: [], publicEvents: [privateStory]).isEmpty)
    XCTAssertTrue(SignalTVProgramming.publicBroadcastEvents([privateStory]).isEmpty)
    let broadcast = SignalTVProgramming.ambientEvents(publicEvents: [story],
      techComHeadlines: [legacy], rivals: [], coverage: 0, venture: 2, sprint: 3)
    XCTAssertEqual(broadcast.filter { $0.headline == story.headline }, [story])
    XCTAssertTrue(TechComEngine.mergedOwnCompanyHeadlines(headlines: [], publicEvents: [story]).isEmpty)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 48_005)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func event(_ move: RivalMove) -> RivalMoveEvent {
    let rival = RivalCompany(id: "fixture", name: "Fixture Co", archetype: .copycat,
      debutVenture: 1, baseStrength: 1)
    let impact = RivalEngine.moveImpact(move, rival: rival, venture: 2, sprint: 3,
      careerSeed: 48_005, lastPlayerEffects: SimulationEffects(momentum: 8))
    return RivalMoveEvent(id: "fixture-v2s3", rivalID: rival.id, rivalName: rival.name,
      archetype: rival.archetype, move: move, strengthBonus: impact.strengthBonus,
      playerEffects: impact.playerEffects, headline: impact.headline)
  }
}

@MainActor
final class SurfacedDefectNarrativeTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    super.tearDown()
  }

  func testFutureDefectCannotSupplyDirectorInputOrPublicStory() {
    let hidden = defect(severity: 24)
    let projection = LatentDefectPublicMediaProjection.surfaced(
      hidden, venture: 1, sprint: 1, careerSprint: 1
    )
    XCTAssertNil(projection)
    // The event requires the separate projection; raw LatentDefect is not an
    // accepted Director input. A rejected projection cannot invoke it.
    let decision = projection.flatMap { MediaNarrativeDirector.decide(event: .surfacedLatentDefect($0)) }
    XCTAssertNil(decision)
    XCTAssertNil(decision?.story)
  }

  func testSurfacedDecisionsAreStableCriticalAndContainOnlyPublicFacts() throws {
    let store = activeStore()
    let rng = store.randomNumberGenerator
    let coverage = store.stats.coverage
    for (severity, delta, importance) in [(6, -4, NarrativeImportance.significant), (24, -10, .major)] {
      let projection = try XCTUnwrap(LatentDefectPublicMediaProjection.surfaced(
        defect(severity: severity), venture: 1, sprint: 2, careerSprint: 2
      ))
      let decision = try XCTUnwrap(MediaNarrativeDirector.decide(event: .surfacedLatentDefect(projection)))
      for _ in 0..<10 {
        XCTAssertEqual(MediaNarrativeDirector.decide(event: .surfacedLatentDefect(projection)), decision)
      }
      XCTAssertEqual(decision.importance, importance)
      XCTAssertEqual(decision.program, .breaking)
      XCTAssertEqual(decision.tone, .critical)
      XCTAssertEqual(decision.coverageDelta, delta)
      XCTAssertEqual(decision.story.coverageDelta, delta)
      XCTAssertEqual(decision.sourceEventID, "latent-DEF-SLICE3-surfaced")
      XCTAssertEqual(decision.story.id, decision.sourceEventID)
      XCTAssertEqual(decision.story.summary, "A delayed issue from Public release surfaced in production.")
      XCTAssertEqual(Set(Mirror(reflecting: projection).children.compactMap(\.label)),
        ["sourceEventID", "venture", "sprint", "headline", "summary", "tickerItems", "coverageDelta"])
      let copy = ([decision.story.headline, decision.story.summary] + decision.story.tickerItems).joined(separator: " ")
      for term in ["Private agent", "evidence", "quality", "drift", "overclaim", "probability", "shipAnyway"] {
        XCTAssertFalse(copy.localizedCaseInsensitiveContains(term))
      }
    }
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertTrue(store.publicMediaEvents.isEmpty)
  }

  func testInsertingDefectStaysPrivateThroughDueSprintPreparationThenCanonicalCommitPublishes() throws {
    let control = activeStore()
    let store = activeStore()
    let hidden = defect(severity: 24)
    let rng = store.randomNumberGenerator
    let coverage = store.stats.coverage
    store.latentDefects.append(hidden)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertEqual(store.publicMediaEvents, control.publicMediaEvents)
    XCTAssertEqual(store.feedPosts.map(\.id), control.feedPosts.map(\.id))
    assertNoDefectStory(in: store)

    commit(in: control)
    commit(in: store)
    XCTAssertEqual(store.sprint, 2)
    XCTAssertTrue(store.latentDefects.contains(hidden))
    XCTAssertEqual(store.stats.coverage, control.stats.coverage)
    XCTAssertEqual(store.randomNumberGenerator, control.randomNumberGenerator)
    // prepareSprint formerly published a private receipt at this exact point.
    assertNoDefectStory(in: store)

    let restored = GameStore()
    restored.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    restored.continueCareer()
    XCTAssertTrue(restored.latentDefects.contains(hidden))
    assertNoDefectStory(in: restored)
    let projection = try XCTUnwrap(LatentDefectPublicMediaProjection.surfaced(
      hidden, venture: 1, sprint: 2, careerSprint: 2
    ))
    let expected = try XCTUnwrap(MediaNarrativeDirector.decide(event: .surfacedLatentDefect(projection)))
    commit(in: restored)
    XCTAssertFalse(restored.latentDefects.contains(hidden))
    XCTAssertEqual(restored.publicMediaEvents.first { $0.id == expected.sourceEventID }, expected.story)
    XCTAssertTrue(restored.processedCoverageEventIDs.contains(expected.sourceEventID))
    XCTAssertTrue(SignalTVProgramming.publicBroadcastEvents(restored.publicMediaEvents).contains(expected.story))
    XCTAssertTrue(TechComEngine.mergedOwnCompanyHeadlines(
      headlines: restored.techComHeadlines, publicEvents: restored.publicMediaEvents
    ).contains { $0.publicEventID == expected.sourceEventID })
  }

  func testSurfacedStoryCoverageAndIdentityRemainIdempotentAcrossSaveLoad() throws {
    let store = activeStore()
    let projection = try XCTUnwrap(LatentDefectPublicMediaProjection.surfaced(
      defect(severity: 24), venture: 1, sprint: 2, careerSprint: 2
    ))
    let story = try XCTUnwrap(MediaNarrativeDirector.decide(event: .surfacedLatentDefect(projection))).story
    let rng = store.randomNumberGenerator
    XCTAssertTrue(store.applyPublicMediaEvent(story))
    XCTAssertEqual(store.stats.coverage, -10)
    XCTAssertFalse(store.applyPublicMediaEvent(story))
    XCTAssertEqual(store.stats.coverage, -10)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    let restored = GameStore()
    restored.continueCareer()
    XCTAssertFalse(restored.applyPublicMediaEvent(story))
    XCTAssertEqual(restored.stats.coverage, -10)
    XCTAssertEqual(restored.publicMediaEvents.filter { $0.id == story.id }, [story])
    XCTAssertEqual(restored.randomNumberGenerator, rng)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  private func defect(severity: Int) -> LatentDefect {
    LatentDefect(id: "DEF-SLICE3", originVenture: 1, originSprint: 1,
      originTaskTitle: "Public release", originAgentName: "Private agent",
      originResolution: .shipAnyway, originEvidenceCompleteness: 13,
      surfacesAtCareerSprint: 2, severity: severity)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: 48_004)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func commit(in store: GameStore) {
    store.report = nil
    store.stats.runway = 120
    store.stats.energy = 100
    store.stats.trust = 90
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    store.assign(agentID: "aurora", to: store.tasks[0].id)
    store.commitSprint()
  }

  private func assertNoDefectStory(in store: GameStore, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(store.publicMediaEvents.contains { $0.id.hasPrefix("latent-") }, file: file, line: line)
    XCTAssertFalse(store.feedPosts.contains { $0.id.hasPrefix("latent-") || $0.body.contains("Private agent") }, file: file, line: line)
    XCTAssertFalse(TechComEngine.mergedOwnCompanyHeadlines(
      headlines: store.techComHeadlines, publicEvents: store.publicMediaEvents
    ).contains { $0.publicEventID?.hasPrefix("latent-") == true }, file: file, line: line)
    XCTAssertFalse(SignalTVProgramming.ambientEvents(
      publicEvents: store.publicMediaEvents, techComHeadlines: store.techComHeadlines,
      rivals: [], coverage: store.stats.coverage, venture: store.venture, sprint: store.sprint
    ).contains { $0.id.hasPrefix("latent-") }, file: file, line: line)
  }
}

@MainActor
final class MediaNarrativeDirectorTests: XCTestCase {
  func testBreakoutDecisionIsStablePublicAndFavorableWithoutMutatingStoreOrRNG() throws {
    let store = GameStore()
    store.resetCareer()
    let coverage = store.stats.coverage
    let rng = store.randomNumberGenerator
    let outcome = PublicLaunchOutcome(
      sourceEventID: "product-launch-v1-s2-resolved", venture: 1, sprint: 2,
      overall: .breakout, marketRating: .exceptional, publicRating: .strong,
      headline: "SOLO launch breaks through", coverageDelta: 12
    )

    let first = try XCTUnwrap(MediaNarrativeDirector.decide(event: .productLaunchResolved(outcome)))
    let second = MediaNarrativeDirector.decide(event: .productLaunchResolved(outcome))

    XCTAssertEqual(first, second)
    XCTAssertEqual(first.sourceEventID, outcome.sourceEventID)
    XCTAssertEqual(first.story.id, outcome.sourceEventID)
    XCTAssertEqual(first.importance, .major)
    XCTAssertEqual(first.channel, .signalTV)
    XCTAssertEqual(first.program, .founderSpotlight)
    XCTAssertEqual(first.tone, .favorable)
    XCTAssertEqual(first.coverageDelta, 12)
    XCTAssertTrue(first.story.isPublic)
    XCTAssertEqual(SignalTVProgramming.publicBroadcastEvents([first.story]), [first.story])
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertTrue(store.publicMediaEvents.isEmpty)
    XCTAssertEqual(store.randomNumberGenerator, rng)

    let publicCopy = ([first.story.headline, first.story.summary] + first.story.tickerItems).joined(separator: " ")
    for hiddenTerm in ["quality", "drift", "overclaim", "verification", "unresolved"] {
      XCTAssertFalse(publicCopy.localizedCaseInsensitiveContains(hiddenTerm))
    }
  }

  func testFailedAndMixedDecisionsPreserveLaunchPolicyAndCoverageAuthority() throws {
    let store = GameStore()
    store.resetCareer()
    let failure = PublicLaunchOutcome(
      sourceEventID: "product-launch-v2-s3-resolved", venture: 2, sprint: 3,
      overall: .failure, marketRating: .failure, publicRating: .weak,
      headline: "SOLO launch falters under scrutiny", coverageDelta: -12
    )
    let decision = try XCTUnwrap(MediaNarrativeDirector.decide(event: .productLaunchResolved(failure)))
    XCTAssertEqual(decision.importance, .major)
    XCTAssertEqual(decision.program, .breaking)
    XCTAssertEqual(decision.tone, .critical)
    XCTAssertEqual(store.stats.coverage, 0)
    XCTAssertTrue(store.applyPublicMediaEvent(decision.story))
    XCTAssertEqual(store.stats.coverage, -12)
    XCTAssertFalse(store.applyPublicMediaEvent(decision.story))
    XCTAssertEqual(store.stats.coverage, -12)
    XCTAssertEqual(store.publicMediaEvents.filter { $0.id == failure.sourceEventID }.count, 1)

    let mixed = PublicLaunchOutcome(
      sourceEventID: "product-launch-v2-s4-resolved", venture: 2, sprint: 4,
      overall: .mixed, marketRating: .mixed, publicRating: .mixed,
      headline: "SOLO launch meets a divided market", coverageDelta: 0
    )
    let mixedDecision = try XCTUnwrap(MediaNarrativeDirector.decide(event: .productLaunchResolved(mixed)))
    XCTAssertEqual(mixedDecision.importance, .standard)
    XCTAssertEqual(mixedDecision.program, .breaking)
    XCTAssertEqual(mixedDecision.tone, .neutral)
    XCTAssertEqual(mixedDecision.coverageDelta, 0)
  }

  func testFounderReviewOutcomesRemainPrivateAndDirectorInputHasNoRawTruth() {
    let states: [(VerificationState, FounderVisibleReviewOutcome)] = [
      (.overclaimed, .overclaimed),
      (.driftDetected, .driftDetected),
      (.confirmed, .confirmed)
    ]
    for (state, expected) in states {
      let review = FounderReviewNarrativeInput(
        sourceEventID: "founder-review-task-v1-s2", venture: 1, sprint: 2,
        founderVisibleOutcome: FounderVisibleReviewOutcome(state),
        disclosure: .privateToFounder
      )
      XCTAssertEqual(review.founderVisibleOutcome, expected)
      XCTAssertNil(MediaNarrativeDirector.decide(event: .founderReview(review)))
      XCTAssertNil(MediaNarrativeDirector.decide(event: .founderReview(review)))
      XCTAssertEqual(
        Set(Mirror(reflecting: review).children.compactMap(\.label)),
        ["sourceEventID", "venture", "sprint", "founderVisibleOutcome", "disclosure"]
      )
    }
  }

  func testFounderPrivateReviewsDoNotPublishOrChangeMediaCoverage() {
    for state in [VerificationState.overclaimed, .driftDetected, .confirmed] {
      let store = GameStore()
      store.resetCareer()
      store.startCareer(seed: 48_002)
      store.confirmVentureThesisIfNeeded()
      let coverage = store.stats.coverage
      let rng = store.randomNumberGenerator
      let result = VisibleTaskResult(
        reportedQuality: 80, actualQuality: 60,
        verificationState: state, overclaimAmount: state == .overclaimed ? 20 : 0,
        evidenceCompleteness: 85, confidenceRangeLabel: "55–85",
        knownOperationalRisk: "Normal operational variance",
        correlatedFailureDetected: state == .driftDetected
      )
      store.recordTechComHeadlines(events: [
        .review(id: UUID(), taskID: UUID(), agentID: "stacks", result: result, evidenceChanged: true)
      ])

      XCTAssertEqual(store.stats.coverage, coverage)
      XCTAssertEqual(store.randomNumberGenerator, rng)
      XCTAssertFalse(store.publicMediaEvents.contains { $0.id.hasPrefix("founder-review-") })
      XCTAssertFalse(store.techComHeadlines.contains { $0.category == .ownCompany })
      let broadcast = SignalTVProgramming.ambientEvents(
        publicEvents: store.publicMediaEvents, techComHeadlines: store.techComHeadlines,
        rivals: [], coverage: store.stats.coverage, venture: store.venture, sprint: store.sprint
      )
      let publicCopy = (store.techComHeadlines.map(\.text) + broadcast.map(\.headline)).joined(separator: " ")
      for privateTerm in ["overclaim", "drift", "actual 60", "verifies stacks"] {
        XCTAssertFalse(publicCopy.localizedCaseInsensitiveContains(privateTerm))
      }
    }
  }

  func testLegacyPrivateReviewCopyCannotReenterPublicChannels() {
    let oldReview = PublicMediaEvent(
      id: "techcom-v1-s1-old-review", program: .breaking, tone: .critical,
      headline: "SOLO review finds Stacks's Proof overclaimed by 20: actual 60",
      summary: "A canonical public company event enters the broadcast cycle.",
      tickerItems: ["SOLO REVIEW FINDS OVERCLAIM"], coverageDelta: -6,
      venture: 1, sprint: 1, concernsPlayerCompany: true
    )
    let oldHeadline = TechComHeadline(
      id: UUID(), category: .ownCompany, text: oldReview.headline,
      venture: 1, sprint: 1, publicEventID: oldReview.id
    )
    XCTAssertTrue(TechComEngine.mergedOwnCompanyHeadlines(
      headlines: [oldHeadline], publicEvents: [oldReview]
    ).isEmpty)
    XCTAssertTrue(SignalTVProgramming.publicBroadcastEvents([oldReview]).isEmpty)
    let broadcast = SignalTVProgramming.ambientEvents(
      publicEvents: [oldReview], techComHeadlines: [oldHeadline], rivals: [],
      coverage: 0, venture: 1, sprint: 1
    )
    XCTAssertFalse(broadcast.contains { $0.headline == oldReview.headline })
  }

  func testLegacyCareerLoadQuarantinesPrivateReviewCopyWithoutChangingHistoricalCoverage() throws {
    let source = GameStore()
    source.resetCareer()
    source.startCareer(seed: 48_003)
    source.confirmVentureThesisIfNeeded()
    let data = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    var envelope = try JSONDecoder().decode(SaveEnvelope.self, from: data)
    let oldReview = PublicMediaEvent(
      id: "techcom-v1-s1-old-review", program: .breaking, tone: .critical,
      headline: "SOLO verifies Stacks's Proof: Confirmed",
      summary: "A canonical public company event enters the broadcast cycle.",
      tickerItems: ["SOLO VERIFIES STACKS"], coverageDelta: 4,
      venture: 1, sprint: 1, concernsPlayerCompany: true
    )
    var oldSprintReview = oldReview
    oldSprintReview.id = "techcom-v1-s1-old-sprint-review"
    oldSprintReview.headline = "SOLO closes sprint 1: Known risks need founder attention (+$20 revenue)"
    envelope.career.publicMediaEvents.insert(oldSprintReview, at: 0)
    envelope.career.techComHeadlines.insert(TechComHeadline(
      id: UUID(), category: .ownCompany, text: oldSprintReview.headline,
      venture: 1, sprint: 1, publicEventID: oldSprintReview.id
    ), at: 0)
    envelope.career.publicMediaEvents.insert(oldReview, at: 0)
    envelope.career.techComHeadlines.insert(TechComHeadline(
      id: UUID(), category: .ownCompany, text: oldReview.headline,
      venture: 1, sprint: 1, publicEventID: oldReview.id
    ), at: 0)
    envelope.career.stats.coverage = 4
    envelope.career.processedCoverageEventIDs.insert(oldReview.id)
    UserDefaults.standard.set(try JSONEncoder().encode(envelope), forKey: GameStore.saveKey)

    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(restored.stats.coverage, 4)
    XCTAssertFalse(restored.publicMediaEvents.contains { $0.id == oldReview.id })
    XCTAssertFalse(restored.techComHeadlines.contains { $0.publicEventID == oldReview.id })
    XCTAssertFalse(restored.publicMediaEvents.contains { $0.id == oldSprintReview.id })
    XCTAssertFalse(restored.techComHeadlines.contains { $0.publicEventID == oldSprintReview.id })
    XCTAssertTrue(restored.processedCoverageEventIDs.contains(oldReview.id))
  }

  func testLegacySprintReviewFindingsAreFilteredWhilePublicRevenueStoriesRemain() {
    let privateSummaries = [
      "SOLO closes sprint 2: Known risks need founder attention (+$20 revenue)",
      "SOLO closes sprint 2: Verified work moved the company forward (+$20 revenue)"
    ]
    let publicSummary = "SOLO closes sprint 2 (+$20 revenue)"
    let stories = (privateSummaries + [publicSummary]).enumerated().map { index, headline in
      PublicMediaEvent(
        id: "techcom-v1-s2-\(index)", program: .techComLive, tone: .neutral,
        headline: headline, summary: "Public company update", tickerItems: [headline],
        coverageDelta: 0, venture: 1, sprint: 2, concernsPlayerCompany: true
      )
    }
    let headlines = stories.map {
      TechComHeadline(id: UUID(), category: .ownCompany, text: $0.headline,
        venture: 1, sprint: 2, publicEventID: $0.id)
    }
    XCTAssertEqual(SignalTVProgramming.publicBroadcastEvents(stories).map(\.headline), [publicSummary])
    XCTAssertEqual(TechComEngine.mergedOwnCompanyHeadlines(
      headlines: headlines, publicEvents: stories
    ).map(\.text), [publicSummary])
  }
}

@MainActor
final class SignalTVTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    for key in GameStore.resetCareerPurgeKeys { UserDefaults.standard.removeObject(forKey: key) }
    super.tearDown()
  }

  func testCoverageDefaultsToNeutralAndLegacyStatsDecodeSafely() throws {
    XCTAssertEqual(FounderStats().coverage, 0)
    let legacy = Data(#"{"runway":42,"revenue":500,"momentum":18,"trust":68,"energy":82,"capital":2500,"trackRecord":0}"#.utf8)
    XCTAssertEqual(try JSONDecoder().decode(FounderStats.self, from: legacy).coverage, 0)
  }

  func testPositiveNegativeAndClampedCoverageChanges() {
    let store = activeStore()
    XCTAssertTrue(store.applyPublicMediaEvent(event(id: "positive", delta: 12)))
    XCTAssertEqual(store.stats.coverage, 12)
    XCTAssertTrue(store.applyPublicMediaEvent(event(id: "negative", delta: -7)))
    XCTAssertEqual(store.stats.coverage, 5)
    store.stats.coverage = 98
    XCTAssertTrue(store.applyPublicMediaEvent(event(id: "upper", delta: 15)))
    XCTAssertEqual(store.stats.coverage, 100)
    store.stats.coverage = -96
    XCTAssertTrue(store.applyPublicMediaEvent(event(id: "lower", delta: -15)))
    XCTAssertEqual(store.stats.coverage, -100)
  }

  func testDuplicateEventAndSharedTechComBroadcastApplyOnlyOnce() {
    let store = activeStore()
    let shared = event(id: "public-launch-v1-s1", delta: 8)
    XCTAssertTrue(store.applyPublicMediaEvent(shared))
    XCTAssertFalse(store.applyPublicMediaEvent(shared))
    XCTAssertEqual(store.stats.coverage, 8)
    XCTAssertEqual(store.publicMediaEvents.filter { $0.id == shared.id }.count, 1)
  }

  func testCoverageAndEventLedgerSurviveSaveLoad() {
    let original = activeStore()
    let shared = event(id: "persisted-event", delta: -9)
    XCTAssertTrue(original.applyPublicMediaEvent(shared))

    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(restored.stats.coverage, -9)
    XCTAssertTrue(restored.processedCoverageEventIDs.contains(shared.id))
    XCTAssertFalse(restored.applyPublicMediaEvent(shared))
    XCTAssertEqual(restored.stats.coverage, -9)
  }

  func testNonPublicEventIsRejectedWithoutStateOrRNGMutation() {
    let store = activeStore()
    let rng = store.randomNumberGenerator
    let hidden = PublicMediaEvent(
      id: "hidden-result", program: .breaking, tone: .critical,
      headline: "Unrevealed quality", summary: "Must never air", tickerItems: [],
      coverageDelta: -15, venture: 1, sprint: 1, concernsPlayerCompany: true, isPublic: false
    )
    XCTAssertFalse(store.applyPublicMediaEvent(hidden))
    XCTAssertEqual(store.stats.coverage, 0)
    XCTAssertTrue(store.publicMediaEvents.isEmpty)
    XCTAssertEqual(store.randomNumberGenerator, rng)
  }

  func testFounderReviewPendingCannotGenerateResultCoverage() {
    let store = activeStore()
    let task = store.tasks[0]
    store.recordTechComHeadlines(events: [
      .assignment(id: UUID(), taskID: task.id, agentID: "stacks", restored: false)
    ])
    XCTAssertEqual(store.stats.coverage, 0)
    XCTAssertFalse(store.publicMediaEvents.contains { $0.coverageDelta != 0 })
  }

  func testDecorativeProgrammingDoesNotConsumeSimulationRNG() {
    var generator = SeededRandomNumberGenerator(seed: 0x51_47_4E_41_4C)
    let before = generator
    _ = SignalTVProgramming.presentationIndex(elapsed: 123.4, count: 5, reduceMotion: false)
    _ = SignalTVProgramming.tickerIndex(elapsed: 123.4, count: 4)
    _ = SignalTVProgramming.ambientEvents(publicEvents: [], techComHeadlines: [], rivals: [], coverage: 0, venture: 3, sprint: 7)
    XCTAssertEqual(generator, before)
    _ = generator.next()
    XCTAssertNotEqual(generator, before)
  }

  func testFiveProgramsAndSpotlightEligibilityUsePublicStory() {
    let publicStory = event(id: "earned-story", delta: 10)
    let rival = TechComRival(id: "vector", name: "VectorLoop", claimedTrackRecord: 10, actualTrackRecord: 8, claimedRevenue: 900, actualRevenue: 800, claimedMomentum: 55, actualMomentum: 50)
    let headline = TechComHeadline(id: UUID(), category: .ownCompany, text: "SOLO launches publicly", venture: 1, sprint: 2, publicEventID: publicStory.id)
    let low = SignalTVProgramming.ambientEvents(publicEvents: [publicStory], techComHeadlines: [headline], rivals: [rival], coverage: 10, venture: 1, sprint: 2)
    XCTAssertFalse(low.contains { $0.program == .founderSpotlight })

    let high = SignalTVProgramming.ambientEvents(publicEvents: [publicStory], techComHeadlines: [headline], rivals: [rival], coverage: 65, venture: 1, sprint: 2)
    XCTAssertTrue(high.contains { $0.program == .marketPulse })
    XCTAssertTrue(high.contains { $0.program == .techComLive })
    XCTAssertTrue(high.contains { $0.program == .rivalWatch })
    XCTAssertTrue(high.contains { $0.program == .founderSpotlight })
    XCTAssertEqual(event(id: "breaking", delta: -10).program, .techComLive)
    XCTAssertTrue(SignalTVProgram.allCases.contains(.breaking))
  }

  func testResponsiveTVPlacementPreservesUpperRightWallObjectAndHotspot() {
    let rightLook = FounderEnvironmentCameraState(horizontalLook: 1, mode: .freeLook)
    let sizes = [
      CGSize(width: 390, height: 844),
      CGSize(width: 440, height: 956),
      CGSize(width: 820, height: 1_180)
    ]

    for size in sizes {
      let layout = FounderEnvironmentLayout(viewportSize: size)
      let hotspot = SignalTVHotspotLayout(viewportSize: size)
      let frame = hotspot.frame(camera: rightLook)

      XCTAssertEqual(
        layout.anchors[.signalTV],
        layout.composition == .compactCockpit ? CGPoint(x: 980, y: 132) : CGPoint(x: 1_100, y: 132)
      )
      XCTAssertGreaterThan(frame.midX, size.width / 2)
      XCTAssertLessThanOrEqual(frame.maxX, size.width - 10)
      XCTAssertGreaterThan(frame.minY, layout.founderDeskHeadingY + 10)
      XCTAssertTrue(hotspot.isSelectable(camera: rightLook))
      XCTAssertGreaterThanOrEqual(frame.width, 44)
      XCTAssertGreaterThanOrEqual(frame.height, 44)
    }
  }

  func testReduceMotionTickerAndAudioFocusMappings() {
    XCTAssertEqual(SignalTVProgramming.presentationIndex(elapsed: 0, count: 5, reduceMotion: true), 0)
    XCTAssertEqual(SignalTVProgramming.presentationIndex(elapsed: 11.9, count: 5, reduceMotion: true), 0)
    XCTAssertEqual(SignalTVProgramming.presentationIndex(elapsed: 12, count: 5, reduceMotion: true), 1)
    XCTAssertLessThan(SignalTVAudioFocus.commandFocus.volume, SignalTVAudioFocus.freeLook.volume)
    XCTAssertGreaterThan(SignalTVAudioFocus.majorStory.volume, SignalTVAudioFocus.freeLook.volume)
  }

  func testBroadcastPresentationDifferentiatesPublicCompanyStates() {
    let idle = SignalTVBroadcastPresentation.derive(
      event: SignalTVProgramming.marketPulse(venture: 1, sprint: 1),
      reduceMotion: false
    )
    var update = event(id: "company-update", delta: 0)
    var momentum = event(id: "company-momentum", delta: 7)
    var pressure = event(id: "company-pressure", delta: -7)
    var spotlight = event(id: "company-spotlight", delta: 10)
    update.tone = .neutral
    momentum.tone = .favorable
    pressure.tone = .critical
    spotlight.program = .founderSpotlight

    XCTAssertEqual(idle.state, .idle)
    XCTAssertEqual(SignalTVBroadcastPresentation.derive(event: update, reduceMotion: false).state, .companyUpdate)
    XCTAssertEqual(SignalTVBroadcastPresentation.derive(event: momentum, reduceMotion: false).state, .momentum)
    XCTAssertEqual(SignalTVBroadcastPresentation.derive(event: pressure, reduceMotion: false).state, .pressure)
    XCTAssertEqual(SignalTVBroadcastPresentation.derive(event: spotlight, reduceMotion: false).state, .spotlight)
  }

  func testBroadcastPresentationPreservesStateWithoutMotion() {
    let story = event(id: "reduced-motion-story", delta: -9)
    let standard = SignalTVBroadcastPresentation.derive(event: story, reduceMotion: false)
    let reduced = SignalTVBroadcastPresentation.derive(event: story, reduceMotion: true)
    XCTAssertEqual(standard.state, reduced.state)
    XCTAssertEqual(standard.banner, reduced.banner)
    XCTAssertTrue(standard.continuousMotionEnabled)
    XCTAssertFalse(reduced.continuousMotionEnabled)
  }

  func testPublicBroadcastFilterRejectsHiddenStories() {
    let publicStory = event(id: "public-story", delta: 4)
    var hiddenStory = event(id: "hidden-story", delta: -15)
    hiddenStory.isPublic = false
    hiddenStory.headline = "Unrevealed task quality"
    let filtered = SignalTVProgramming.publicBroadcastEvents([hiddenStory, publicStory])
    XCTAssertEqual(filtered.map(\.id), [publicStory.id])
    XCTAssertFalse(filtered.contains { $0.headline.contains("Unrevealed") })
  }

  func testFundingProjectionPublishesOnlySuccessfulFounderVisibleTruth() throws {
    let grant = try XCTUnwrap(FundingBoardCatalog.opportunities.first {
      $0.id == "pioneer-ai-grant"
    })
    let awardedProjection = try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: grant,
      outcome: .awarded,
      venture: 1,
      sprint: 2
    ))
    let awarded = try XCTUnwrap(MediaNarrativeDirector.decide(event: .publicFundingProgress(awardedProjection))).story
    XCTAssertTrue(awarded.isFundingSuccess)
    XCTAssertEqual(awarded.program, .breaking)
    XCTAssertEqual(awarded.coverageDelta, 0)
    XCTAssertTrue(awarded.headline.contains(grant.name))
    XCTAssertNil(FundingPublicMediaProjection.resolution(
      opportunity: grant,
      outcome: .declined,
      venture: 1,
      sprint: 2
    ))
    XCTAssertEqual(
      SignalTVBroadcastPresentation.derive(event: awarded, reduceMotion: false).state,
      .momentum
    )
    let programming = SignalTVProgramming.ambientEvents(
      publicEvents: [awarded, awarded], techComHeadlines: [], rivals: [],
      coverage: 0, venture: 1, sprint: 2
    )
    XCTAssertEqual(programming.filter { $0.id == awarded.id }, [awarded])
    let round = try XCTUnwrap(FundingBoardCatalog.opportunities.first { $0.kind == .fundraising })
    let fundedProjection = try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: round, outcome: .funded, venture: 1, sprint: 7
    ))
    let funded = try XCTUnwrap(MediaNarrativeDirector.decide(event: .publicFundingProgress(fundedProjection))).story
    XCTAssertTrue(awarded.summary.contains("non-dilutive"))
    XCTAssertTrue(funded.summary.contains("outside funding"))
    XCTAssertEqual(funded.coverageDelta, 0)
    let allCopy = ([awarded.headline, awarded.summary] + awarded.tickerItems).joined(separator: " ")
    for hiddenTerm in ["quality", "drift", "overclaim", "verification"] {
      XCTAssertFalse(allCopy.localizedCaseInsensitiveContains(hiddenTerm))
    }
  }

  func testCoverageRemainsMechanicallyIndependentFromTrust() {
    let store = activeStore()
    store.stats.trust = 85
    XCTAssertTrue(store.applyPublicMediaEvent(event(id: "skeptical", delta: -12)))
    XCTAssertEqual(store.stats.trust, 85)
    XCTAssertEqual(store.stats.coverage, -12)
  }

  private func activeStore() -> GameStore {
    let store = GameStore()
    store.startCareer(seed: 32_708)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func event(id: String, delta: Int) -> PublicMediaEvent {
    PublicMediaEvent(
      id: id, program: .techComLive,
      tone: delta > 0 ? .favorable : delta < 0 ? .critical : .neutral,
      headline: "SOLO public story", summary: "Signal TV aired a canonical public event.",
      tickerItems: ["SOLO PUBLIC STORY"], coverageDelta: delta,
      venture: 1, sprint: 1, concernsPlayerCompany: true
    )
  }
}

/// Matched simulator evidence of the production wall/viewer components using
/// public-only fixtures. These captures are not career-route or owner acceptance.
@MainActor
final class SignalTVVisualCaptureTests: XCTestCase {
  func testCaptureTickerAtTrackStartSeamAndStaticEndpoint() throws {
    let items = SignalTVProgramming.marketPulse(venture: 1, sprint: 3).tickerItems
    for phase in [0.0, 18, 35.9] {
      let renderer = ImageRenderer(content: SignalTVBroadcastTicker(items: items, moves: true, compact: true, reviewElapsed: phase)
        .frame(width: 268, height: 19))
      renderer.scale = 4
      let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
      attachment.name = "Signal TV ticker close inspection phase \(phase)"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
    let renderer = ImageRenderer(content: SignalTVBroadcastTicker(items: items, moves: false, compact: true)
      .frame(width: 268, height: 19))
    renderer.scale = 4
    let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
    attachment.name = "Signal TV ticker close inspection Reduce Motion"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testCaptureFiveProgramsNormalAndReduceMotion() throws {
    let screen = UIScreen.main.bounds
    for program in SignalTVProgram.allCases {
      let event = fixture(program)
      for reduced in [false, true] {
        let host = UIHostingController(rootView: SignalTVViewer(events: [event], coverage: 0, reduceMotionOverride: reduced)
          .environment(\.colorScheme, .dark))
        let window = UIWindow(frame: screen)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = screen
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        let image = UIGraphicsImageRenderer(bounds: screen).image { _ in
          host.view.drawHierarchy(in: screen, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "SignalTV-\(program.rawValue.replacingOccurrences(of: " ", with: "-"))-\(reduced ? "Reduced" : "Normal")"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(NarrativeStoryCompetition.selectPrimaryStory(from: [event]), event)
        window.isHidden = true
        window.rootViewController = nil
      }
    }
  }

  private func fixture(_ program: SignalTVProgram) -> PublicMediaEvent {
    let copy: (String, String, [String], Int, Bool)
    switch program {
    case .marketPulse:
      return SignalTVProgramming.marketPulse(venture: 1, sprint: 3)
    case .techComLive:
      copy = ("SOLO closes sprint with new revenue", "The company reported its public sprint revenue update.", ["SOLO PUBLIC COMPANY UPDATE", "TECH.COM LIVE"], 4, true)
    case .rivalWatch:
      copy = ("VectorLoop announces a competing feature", "A public rival move adds competitive pressure around SOLO's category.", ["VECTORLOOP", "FEATURE COPY"], 0, true)
    case .breaking:
      copy = ("SOLO launch hits a production defect", "A previously reported release issue has surfaced in production. Another surfaced production defect brings renewed public scrutiny.", ["SOLO PRODUCTION DEFECT", "LAUNCH RELIABILITY UNDER REVIEW"], -10, true)
    case .founderSpotlight:
      copy = ("SOLO closes its Founder Conviction Round", "The company closed outside funding. This funding success follows an earlier public funding success.", ["SOLO PUBLIC FUNDING SUCCESS", "FOUNDER CONVICTION ROUND"], 0, true)
    }
    return PublicMediaEvent(id: "capture-\(program.rawValue)", program: program,
      tone: program == .breaking ? .critical : program == .rivalWatch ? .neutral : .favorable,
      headline: copy.0, summary: copy.1, tickerItems: copy.2, coverageDelta: copy.3,
      venture: 1, sprint: 3, concernsPlayerCompany: copy.4)
  }
}

@MainActor
final class NarrativeExpressionTests: XCTestCase {
  func testWorkerDoesNotPublishMutateCoverageConsumeRNGOrPersistExpression() async throws {
    let store = GameStore()
    store.resetCareer()
    defer { store.resetCareer() }
    store.startCareer(seed: 48_009)
    store.confirmVentureThesisIfNeeded()
    let event = story()
    _ = store.applyPublicMediaEvent(event)
    let coverage = store.stats.coverage
    let rng = store.randomNumberGenerator
    let ledger = store.publicMediaEvents
    let processed = store.processedCoverageEventIDs
    let saved = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: event))
    _ = await NarrativeExpressionService(provider: DeterministicStyledExpressionProvider()).expression(for: request)
    XCTAssertEqual(store.stats.coverage, coverage)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.publicMediaEvents, ledger)
    XCTAssertEqual(store.processedCoverageEventIDs, processed)
    XCTAssertEqual(UserDefaults.standard.data(forKey: GameStore.saveKey), saved)
    XCTAssertEqual(GameStore.saveVersion, 20)
    let restored = GameStore()
    restored.continueCareer()
    XCTAssertEqual(restored.publicMediaEvents, ledger)
    XCTAssertEqual(restored.stats.coverage, coverage)
  }
  private func story(program: SignalTVProgram = .breaking, id: String = "latent-public-surfaced") -> PublicMediaEvent {
    PublicMediaEvent(id: id, program: program, tone: .critical,
      headline: "SOLO launch hits a production defect",
      summary: "A production defect surfaced. Another surfaced production defect brings renewed public scrutiny.",
      tickerItems: ["SOLO PRODUCTION DEFECT"], coverageDelta: -4,
      venture: 1, sprint: 3, concernsPlayerCompany: true)
  }

  func testPublicRequestHasNoPrivateStateCoverageOrPublicationCapability() throws {
    let event = story()
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: event))
    XCTAssertEqual(Set(Mirror(reflecting: request).children.compactMap(\.label)),
      ["eventID", "program", "tone", "importance", "publicFacts", "style"])
    XCTAssertEqual(Set(Mirror(reflecting: request.publicFacts).children.compactMap(\.label)),
      ["category", "canonicalCopy"])
    XCTAssertEqual(request.publicFacts.canonicalCopy.summary, event.summary)
    XCTAssertEqual(request.importance, NarrativeStoryCompetition.rankedCandidates(from: [event]).first?.importance)
    var hidden = event; hidden.isPublic = false
    XCTAssertNil(NarrativeExpressionRequest(authorizedEvent: hidden))
    hidden.isPublic = true; hidden.headline = "SOLO review finds Stacks's Proof overclaimed by 20: actual 60"
    XCTAssertNil(NarrativeExpressionRequest(authorizedEvent: hidden))
  }

  func testImprovementPreservesAllMetadataCanonicalLedgerAndTechCom() async throws {
    let event = story()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let before = try encoder.encode(event)
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: event))
    let service = NarrativeExpressionService(provider: DeterministicStyledExpressionProvider())
    let result = await service.expression(for: request)
    XCTAssertEqual(result.status, .accepted)
    XCTAssertNotEqual(result.copy.headline, event.headline)
    XCTAssertEqual(result.copy.summary, event.summary)
    XCTAssertEqual(result.copy.tickerItems, event.tickerItems)
    XCTAssertEqual(try encoder.encode(event), before)
    XCTAssertEqual(TechComEngine.mergedOwnCompanyHeadlines(headlines: [], publicEvents: [event]).first?.text, event.headline)
    XCTAssertEqual(Set(Mirror(reflecting: result.copy).children.compactMap(\.label)), ["headline", "summary", "tickerItems"])
  }

  func testAllProgramVoicesAreBoundedAndCannotCrossPrograms() async throws {
    for program in SignalTVProgram.allCases {
      let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story(program: program)))
      let draft = request.permittedExpression
      XCTAssertTrue(NarrativeExpressionValidator.accepts(draft, for: request))
      XCTAssertFalse(request.style.voice.isEmpty)
      for other in SignalTVProgram.allCases where other != program {
        let otherRequest = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story(program: other)))
        XCTAssertFalse(NarrativeExpressionValidator.accepts(otherRequest.permittedExpression, for: request))
      }
    }
  }

  func testAdversarialFactsPrivateStateAndMeaningChangesAlwaysFallBack() async throws {
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    let attacks = [
      "Stacks caused the defect.", "SOLO raised $50M.",
      "VectorLoop is secretly losing users.", "Aurora overclaimed its evidence.",
      "The defect had been known internally for weeks.",
      "Founder Review confirmed hidden quality of 98.",
      "An unsurfaced latent defect will fail next sprint.",
      "VectorLoop has 50,000 customers.", "Investor Casey privately committed $20M.",
      "SOLO has no production defect.", "SOLO is the market leader.",
      "The defect certainly destroyed customer confidence.",
      "A revolutionary, unprecedented launch.", "SOLO launch hits another production defect"
    ]
    for attack in attacks {
      for field in 0..<3 {
        let canonical = request.publicFacts.canonicalCopy
        let draft = NarrativeExpressionDraft(headline: field == 0 ? attack : canonical.headline,
          summary: field == 1 ? attack : canonical.summary,
          tickerItems: field == 2 ? [attack] : canonical.tickerItems)
        let result = await NarrativeExpressionService(provider: FixedNarrativeExpressionProvider(draft: draft)).expression(for: request)
        XCTAssertEqual(result.status, .invalid, attack)
        XCTAssertEqual(result.copy, canonical, attack)
      }
    }
  }

  func testWordReorderingNegationAndUnsupportedContinuityAreRejected() throws {
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    for headline in ["Production hits SOLO launch defect", "SOLO launch avoids a production defect", "SOLO launch recovers from a production defect"] {
      XCTAssertFalse(NarrativeExpressionValidator.accepts(NarrativeExpressionDraft(headline: headline,
        summary: request.publicFacts.canonicalCopy.summary, tickerItems: request.publicFacts.canonicalCopy.tickerItems), for: request))
    }
  }

  func testEmptyAndOversizedFieldsFallBackWithoutTruncatingFacts() async throws {
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    let original = request.publicFacts.canonicalCopy
    let invalid = [
      NarrativeExpressionDraft(headline: " ", summary: original.summary, tickerItems: original.tickerItems),
      NarrativeExpressionDraft(headline: original.headline, summary: "", tickerItems: original.tickerItems),
      NarrativeExpressionDraft(headline: String(repeating: "x", count: 73), summary: original.summary, tickerItems: original.tickerItems),
      NarrativeExpressionDraft(headline: original.headline, summary: String(repeating: "x", count: 481), tickerItems: original.tickerItems),
      NarrativeExpressionDraft(headline: original.headline, summary: original.summary, tickerItems: [String(repeating: "x", count: 81)]),
      NarrativeExpressionDraft(headline: original.headline, summary: original.summary, tickerItems: ["", "", "", "", ""])
    ]
    for draft in invalid {
      let result = await NarrativeExpressionService(provider: FixedNarrativeExpressionProvider(draft: draft)).expression(for: request)
      XCTAssertEqual(result.status, .invalid)
      XCTAssertEqual(result.copy, original)
    }
    var oversizedCanonical = story(); oversizedCanonical.headline = String(repeating: "x", count: 73)
    let oversizedRequest = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: oversizedCanonical))
    let result = await NarrativeExpressionService().expression(for: oversizedRequest)
    XCTAssertEqual(result.copy.headline, oversizedCanonical.headline)
    XCTAssertEqual(result.status, .invalid)
  }

  func testStrictResponseSchemaRejectsAuthorityFieldsAndBadTypes() throws {
    let draft = NarrativeExpressionDraft(headline: "Public update", summary: "Public story.", tickerItems: [])
    XCTAssertEqual(try NarrativeExpressionDraft.decodeStrict(JSONEncoder().encode(draft)), draft)
    for extra in ["coverage", "program", "importance", "publish", "eventID", "confidence", "hiddenAnalysis"] {
      let data = try JSONSerialization.data(withJSONObject: ["headline": "Public update", "summary": "Public story.", "tickerItems": [], extra: 1])
      XCTAssertThrowsError(try NarrativeExpressionDraft.decodeStrict(data))
    }
    XCTAssertThrowsError(try NarrativeExpressionDraft.decodeStrict(Data("{\"headline\":1}".utf8)))
    XCTAssertThrowsError(try NarrativeExpressionDraft.decodeStrict(Data(repeating: 32, count: 8_193)))
  }

  func testUnavailableProviderAndAbsentModelPreserveOfflineCopy() async throws {
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    let unavailable = await NarrativeExpressionService(provider: FailingNarrativeExpressionProvider()).expression(for: request)
    XCTAssertEqual(unavailable.status, .unavailable)
    XCTAssertEqual(unavailable.copy, request.publicFacts.canonicalCopy)
    let offline = await NarrativeExpressionService().expression(for: request)
    XCTAssertEqual(offline.copy, request.publicFacts.canonicalCopy)
  }

  func testTimeoutWinsEvenWhenProviderIgnoresCancellationAndLateCopyCannotReplaceIt() async throws {
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    let provider = DelayedNarrativeExpressionProvider()
    let service = NarrativeExpressionService(provider: provider, timeout: .milliseconds(10))
    let start = ContinuousClock.now
    let result = await service.expression(for: request)
    XCTAssertEqual(result.status, .timedOut)
    XCTAssertLessThan(start.duration(to: .now), .milliseconds(200))
    XCTAssertEqual(result.copy, request.publicFacts.canonicalCopy)
    try await Task.sleep(for: .milliseconds(350))
    let cached = await service.expression(for: request)
    XCTAssertEqual(cached, result)
  }

  func testConcurrentAndRepeatedViewsCoalesceProviderCalls() async throws {
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    let provider = CountingNarrativeExpressionProvider()
    let service = NarrativeExpressionService(provider: provider)
    async let first = service.expression(for: request)
    async let second = service.expression(for: request)
    let results = await (first, second)
    let repeatResult = await service.expression(for: request)
    XCTAssertEqual(results.0, results.1)
    XCTAssertEqual(repeatResult, results.0)
    let count = await provider.calls
    XCTAssertEqual(count, 1)
  }

  func testCacheIncludesPublicCopyAndMetadataAndHasHardLimit() async throws {
    let provider = CountingNarrativeExpressionProvider()
    let service = NarrativeExpressionService(provider: provider)
    for index in 0..<NarrativeExpressionService.maximumEntries + 1 {
      var event = story(); event.summary += " Public note \(index)."
      let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: event))
      let result = await service.expression(for: request)
      XCTAssertEqual(result.status, index == 16 ? .unavailable : .accepted)
    }
    let count = await provider.calls
    XCTAssertEqual(count, 16)
    let freshRequest = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story()))
    let fresh = await NarrativeExpressionService(provider: provider).expression(for: freshRequest)
    XCTAssertEqual(fresh.status, .accepted)
    let metadataProvider = CountingNarrativeExpressionProvider()
    let metadataService = NarrativeExpressionService(provider: metadataProvider)
    for program in SignalTVProgram.allCases {
      let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: story(program: program)))
      _ = await metadataService.expression(for: request)
    }
    let metadataCalls = await metadataProvider.calls
    XCTAssertEqual(metadataCalls, 5)
  }

  func testCanonicalCopyIsImmediatelyRenderableBeforeEnhancementCompletes() async throws {
    let event = story()
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: event))
    let service = NarrativeExpressionService(provider: DelayedNarrativeExpressionProvider())
    let pending = Task { await service.expression(for: request) }
    let renderer = ImageRenderer(content: SignalTVViewer(events: [event], coverage: 0).frame(width: 430, height: 932))
    XCTAssertNotNil(renderer.uiImage)
    XCTAssertEqual(request.publicFacts.canonicalCopy.headline, event.headline)
    _ = await pending.value
  }

  func testBroadcastDesignMotionAndSelectionNeverDependOnEnhancedWords() async throws {
    let event = story()
    let normal = SignalTVBroadcastDesign.derive(event: event, reduceMotion: false)
    let reduced = SignalTVBroadcastDesign.derive(event: event, reduceMotion: true)
    let request = try XCTUnwrap(NarrativeExpressionRequest(authorizedEvent: event))
    _ = await NarrativeExpressionService(provider: DeterministicStyledExpressionProvider()).expression(for: request)
    XCTAssertEqual(SignalTVBroadcastDesign.derive(event: event, reduceMotion: false), normal)
    XCTAssertEqual(SignalTVBroadcastDesign.derive(event: event, reduceMotion: true), reduced)
    XCTAssertEqual(NarrativeStoryCompetition.selectPrimaryStory(from: [event]), event)
  }
}

private struct FixedNarrativeExpressionProvider: NarrativeExpressionProviding {
  let draft: NarrativeExpressionDraft
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft { draft }
}
private struct FailingNarrativeExpressionProvider: NarrativeExpressionProviding {
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft { throw NarrativeExpressionFailure.invalidSchema }
}
private actor CountingNarrativeExpressionProvider: NarrativeExpressionProviding {
  private(set) var calls = 0
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft {
    calls += 1
    try await Task.sleep(for: .milliseconds(5))
    return request.permittedExpression
  }
}
private struct DelayedNarrativeExpressionProvider: NarrativeExpressionProviding {
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft {
    // Intentionally ignores cancellation to prove that timeout never joins it.
    await withCheckedContinuation { continuation in
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { continuation.resume() }
    }
    return request.permittedExpression
  }
}
