import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class TechComPresentationTests: XCTestCase {
  func testRankingsSortDescendingAndUseVerifiedActual() {
    var verified = TechComRival(id: "a", name: "Alpha", claimedTrackRecord: 90, actualTrackRecord: 20, claimedRevenue: 1, actualRevenue: 1, claimedMomentum: 1, actualMomentum: 1, isVerified: true)
    let unverified = TechComRival(id: "b", name: "Beta", claimedTrackRecord: 70, actualTrackRecord: 10, claimedRevenue: 1, actualRevenue: 1, claimedMomentum: 1, actualMomentum: 1)
    var stats = FounderStats(); stats.trackRecord = 50
    let ranked = TechComEngine.rankings(snapshot: TechComSnapshot(founderName: "F", venture: 1, sprint: 1, stats: stats, agents: [], tasks: [], dilemmaChoice: nil), rivals: [verified, unverified], metric: .trackRecord)
    XCTAssertEqual(ranked.map(\.name), ["Beta", "SOLO", "Alpha"])
    verified.isVerified = false
    XCTAssertEqual(TechComEngine.rankings(snapshot: TechComSnapshot(founderName: "F", venture: 1, sprint: 1, stats: stats, agents: [], tasks: [], dilemmaChoice: nil), rivals: [verified], metric: .trackRecord).first?.name, "Alpha")
  }

  func testPersistenceRoundTripRetainsRivalsAndHeadlines() throws {
    let rival = TechComRival(id: "r", name: "Rival", claimedTrackRecord: 70, actualTrackRecord: 50, claimedRevenue: 2, actualRevenue: 1, claimedMomentum: 3, actualMomentum: 2, isVerified: true)
    let headline = TechComHeadline(id: UUID(), category: .rival, text: "Rival verified", venture: 1, sprint: 2)
    let data = try JSONEncoder().encode([rival])
    XCTAssertEqual(try JSONDecoder().decode([TechComRival].self, from: data), [rival])
    XCTAssertEqual(try JSONDecoder().decode(TechComHeadline.self, from: JSONEncoder().encode(headline)), headline)
  }

  func testRivalPresentationNeverDisclosesActualValuesBeforeVerification() {
    var rival = TechComRival(id: "northwind", name: "Northwind Labs", claimedTrackRecord: 70, actualTrackRecord: 42, claimedRevenue: 2_000, actualRevenue: 1_300, claimedMomentum: 61, actualMomentum: 48)
    XCTAssertTrue(TechComPresentation.rivalMetrics(for: rival).allSatisfy { $0.actualValue == nil })

    rival.isVerified = true
    XCTAssertEqual(TechComPresentation.rivalMetrics(for: rival).compactMap(\.actualValue), [42, 1_300, 48])
  }

  func testMarketBarFractionUsesCanonicalShareAndClampsOnlyForLayout() {
    XCTAssertEqual(TechComPresentation.marketBarFraction(0.375), 0.375, accuracy: 0.0001)
    XCTAssertEqual(TechComPresentation.marketBarFraction(-0.2), 0)
    XCTAssertEqual(TechComPresentation.marketBarFraction(1.2), 1)
  }

  func testRankingGapUsesCanonicalOrderedValues() {
    let entries = [
      TechComRankingEntry(id: "a", name: "A", value: 50, isPlayer: false),
      TechComRankingEntry(id: "solo", name: "SOLO", value: 42, isPlayer: true),
      TechComRankingEntry(id: "b", name: "B", value: 20, isPlayer: false)
    ]
    XCTAssertEqual(TechComPresentation.gapToNextRank(entries: entries, playerIndex: 1), 8)
    XCTAssertNil(TechComPresentation.gapToNextRank(entries: entries, playerIndex: 0))
  }
}
