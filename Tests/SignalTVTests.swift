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

  func testResponsiveTVPlacementPreservesSameWorldObject() {
    let phone = FounderEnvironmentLayout(viewportSize: CGSize(width: 390, height: 844))
    let tablet = FounderEnvironmentLayout(viewportSize: CGSize(width: 1024, height: 768))
    XCTAssertEqual(phone.anchors[.signalTV], CGPoint(x: 840, y: 205))
    XCTAssertEqual(tablet.anchors[.signalTV], CGPoint(x: 835, y: 205))
    let phonePosition = phone.viewportPosition(for: .signalTV, camera: FounderEnvironmentCameraState(mode: .freeLook), layer: .background)
    let tabletPosition = tablet.viewportPosition(for: .signalTV, camera: FounderEnvironmentCameraState(mode: .freeLook), layer: .background)
    XCTAssertGreaterThan(phonePosition.x, 300)
    XCTAssertLessThan(phonePosition.x, 390)
    XCTAssertGreaterThan(tabletPosition.x, 512)
    XCTAssertLessThan(tabletPosition.x, 900)
    let phoneHotspot = SignalTVHotspotLayout(viewportSize: CGSize(width: 390, height: 844))
    let tabletHotspot = SignalTVHotspotLayout(viewportSize: CGSize(width: 1024, height: 768))
    XCTAssertTrue(phoneHotspot.isSelectable(camera: FounderEnvironmentCameraState(mode: .freeLook)))
    XCTAssertTrue(tabletHotspot.isSelectable(camera: FounderEnvironmentCameraState(mode: .freeLook)))
    XCTAssertGreaterThanOrEqual(phoneHotspot.frame(camera: FounderEnvironmentCameraState(mode: .freeLook)).width, 44)
  }

  func testReduceMotionTickerAndAudioFocusMappings() {
    XCTAssertEqual(SignalTVProgramming.presentationIndex(elapsed: 0, count: 5, reduceMotion: true), 0)
    XCTAssertEqual(SignalTVProgramming.presentationIndex(elapsed: 11.9, count: 5, reduceMotion: true), 0)
    XCTAssertEqual(SignalTVProgramming.presentationIndex(elapsed: 12, count: 5, reduceMotion: true), 1)
    XCTAssertLessThan(SignalTVAudioFocus.commandFocus.volume, SignalTVAudioFocus.freeLook.volume)
    XCTAssertGreaterThan(SignalTVAudioFocus.majorStory.volume, SignalTVAudioFocus.freeLook.volume)
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
