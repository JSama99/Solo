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
}
