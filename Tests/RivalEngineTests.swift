import XCTest
@testable import Solo_Unicorn_Run

final class RivalEngineTests: XCTestCase {
  func testStrengthIsDeterministicAndConsumesNoGenerator() {
    let rival = ContentLibrary.rivalSimulationCompanies[1]
    let stats = FounderStats()
    let seed = RivalEngine.careerSeed(founderName: "Ada", productType: .saas)
    let first = RivalEngine.strength(of: rival, venture: 4, sprint: 7, careerSeed: seed, player: stats, playerFlags: [])
    var generator = SeededRandomNumberGenerator(seed: 42)
    let before = generator
    let second = RivalEngine.strength(of: rival, venture: 4, sprint: 7, careerSeed: seed, player: stats, playerFlags: [])
    XCTAssertEqual(first, second)
    XCTAssertEqual(generator, before)
  }

  func testMarketSharesSumToOneAndRespectDebut() {
    let standings = RivalEngine.standings(companies: ContentLibrary.rivalSimulationCompanies, venture: 1, sprint: 1, careerSeed: 7, player: FounderStats(), playerFlags: [])
    XCTAssertEqual(standings.map(\.marketShare).reduce(0, +), 1, accuracy: 0.0001)
    XCTAssertFalse(standings.contains { $0.id == "mirror" })
    XCTAssertFalse(standings.contains { $0.id == "summit" })
  }

  func testRevenueMultiplierStaysBounded() {
    for share in stride(from: 0.0, through: 1.0, by: 0.01) {
      let multiplier = RivalEngine.revenueMultiplier(marketShare: share, fieldSize: 6)
      XCTAssertGreaterThanOrEqual(multiplier, 0.85)
      XCTAssertLessThanOrEqual(multiplier, 1.15)
    }
  }
}
