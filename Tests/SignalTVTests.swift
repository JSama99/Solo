import XCTest
@testable import Solo_Unicorn_Run

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
    let awarded = try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: grant,
      outcome: .awarded,
      venture: 1,
      sprint: 2
    ))

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
    let funded = try XCTUnwrap(FundingPublicMediaProjection.resolution(
      opportunity: round, outcome: .funded, venture: 1, sprint: 7
    ))
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
