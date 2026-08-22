import XCTest
@testable import Solo_Unicorn_Run

final class RivalEngineTests: XCTestCase {
  func testStrengthIsDeterministicAndConsumesNoGenerator() {
    let rival = ContentLibrary.rivalSimulationCompanies[1]
    let stats = FounderStats()
    let seed = RivalEngine.careerSeed(founderName: "Ada", productType: .saas)
    let first = RivalEngine.strength(of: rival, venture: 4, sprint: 7, careerSeed: seed, player: stats, playerFlags: [])
    let generator = SeededRandomNumberGenerator(seed: 42)
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

  func testStandingsDefaultLastPlayerEffectsMatchesExplicitEmpty() {
    let withDefault = RivalEngine.standings(companies: ContentLibrary.rivalSimulationCompanies, venture: 4, sprint: 6, careerSeed: 12, player: FounderStats(), playerFlags: [])
    let withExplicitEmpty = RivalEngine.standings(companies: ContentLibrary.rivalSimulationCompanies, venture: 4, sprint: 6, careerSeed: 12, player: FounderStats(), playerFlags: [], lastPlayerEffects: SimulationEffects())
    XCTAssertEqual(withDefault, withExplicitEmpty)
  }

  func testStandingsWithMovesStillSumMarketShareToOne() {
    for sprint in 1...12 {
      let standings = RivalEngine.standings(
        companies: ContentLibrary.rivalSimulationCompanies,
        venture: 3,
        sprint: sprint,
        careerSeed: 8,
        player: FounderStats(momentum: 40, trust: 55),
        playerFlags: [],
        lastPlayerEffects: SimulationEffects(revenue: 80, momentum: 12)
      )
      XCTAssertEqual(standings.map(\.marketShare).reduce(0, +), 1, accuracy: 0.0001)
    }
  }

  func testMoveEventsAreDeterministicAndConsumeNoGenerator() {
    let stats = FounderStats()
    let lastEffects = SimulationEffects(revenue: 40, momentum: 6, trust: -2)
    let generator = SeededRandomNumberGenerator(seed: 91)
    let before = generator
    let first = RivalEngine.moveEvents(companies: ContentLibrary.rivalSimulationCompanies, venture: 4, sprint: 7, careerSeed: 5_150, player: stats, playerFlags: [], lastPlayerEffects: lastEffects)
    let second = RivalEngine.moveEvents(companies: ContentLibrary.rivalSimulationCompanies, venture: 4, sprint: 7, careerSeed: 5_150, player: stats, playerFlags: [], lastPlayerEffects: lastEffects)
    XCTAssertEqual(first, second)
    XCTAssertEqual(generator, before)
  }

  func testMoveEventsRespectDebut() {
    let events = RivalEngine.moveEvents(companies: ContentLibrary.rivalSimulationCompanies, venture: 1, sprint: 1, careerSeed: 3, player: FounderStats(), playerFlags: [], lastPlayerEffects: SimulationEffects())
    XCTAssertFalse(events.contains { $0.rivalID == "mirror" })
    XCTAssertFalse(events.contains { $0.rivalID == "summit" })
    XCTAssertFalse(events.isEmpty)

    let laterEvents = RivalEngine.moveEvents(companies: ContentLibrary.rivalSimulationCompanies, venture: 16, sprint: 1, careerSeed: 3, player: FounderStats(), playerFlags: [], lastPlayerEffects: SimulationEffects())
    XCTAssertTrue(laterEvents.contains { $0.rivalID == "mirror" })
    XCTAssertTrue(laterEvents.contains { $0.rivalID == "summit" })
  }

  func testIncumbentNeverPlaysMovesOutsideItsKit() {
    let rival = RivalCompany(id: "test-incumbent", name: "Test Incumbent Co", archetype: .incumbent, debutVenture: 1, baseStrength: 1)
    var seen = Set<RivalMove>()
    for venture in 1...6 {
      for sprint in 1...12 {
        let move = RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 99, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects())
        seen.insert(move)
        XCTAssertNotEqual(move, .featureCopy)
        XCTAssertNotEqual(move, .fundraiseSurge)
      }
    }
    XCTAssertGreaterThanOrEqual(seen.count, 3)
  }

  func testUpstartNeverPlaysMovesOutsideItsKit() {
    let rival = RivalCompany(id: "test-upstart", name: "Test Upstart Co", archetype: .upstart, debutVenture: 1, baseStrength: 1)
    for venture in 1...6 {
      for sprint in 1...12 {
        let move = RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 61, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects())
        XCTAssertNotEqual(move, .fortify)
        XCTAssertNotEqual(move, .featureCopy)
      }
    }
  }

  func testQuietBuilderNeverPlaysMovesOutsideItsKit() {
    let rival = RivalCompany(id: "test-quiet", name: "Test Quiet Co", archetype: .quietBuilder, debutVenture: 1, baseStrength: 1)
    for venture in 1...6 {
      for sprint in 1...12 {
        let move = RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 15, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects())
        XCTAssertNotEqual(move, .featureCopy)
        XCTAssertNotEqual(move, .fundraiseSurge)
        XCTAssertNotEqual(move, .overreach)
      }
    }
  }

  func testCopycatNeverPlaysMovesOutsideItsKit() {
    let rival = RivalCompany(id: "test-copycat", name: "Test Copycat Co", archetype: .copycat, debutVenture: 1, baseStrength: 1)
    for venture in 1...6 {
      for sprint in 1...12 {
        let move = RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 42, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects())
        XCTAssertNotEqual(move, .fortify)
        XCTAssertNotEqual(move, .fundraiseSurge)
        XCTAssertNotEqual(move, .overreach)
      }
    }
  }

  func testBehindRivalsLeanIntoComebackMoves() {
    let rival = RivalCompany(id: "test-comeback", name: "Test Comeback Co", archetype: .upstart, debutVenture: 1, baseStrength: 1)
    var behindCounts: [RivalMove: Int] = [:]
    var aheadCounts: [RivalMove: Int] = [:]
    for venture in 1...6 {
      for sprint in 1...12 {
        behindCounts[RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 55, baseStrength: 0.5, playerStrength: 2, lastPlayerEffects: SimulationEffects()), default: 0] += 1
        aheadCounts[RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 55, baseStrength: 2, playerStrength: 0.5, lastPlayerEffects: SimulationEffects()), default: 0] += 1
      }
    }
    XCTAssertGreaterThan(behindCounts[.fundraiseSurge, default: 0], aheadCounts[.fundraiseSurge, default: 0])
  }

  func testLeadingRivalsOverreachMoreOftenThanRivalsAtParity() {
    let rival = RivalCompany(id: "test-hype-lead", name: "Test Hype Co", archetype: .hypeMachine, debutVenture: 1, baseStrength: 1)
    var aheadCounts: [RivalMove: Int] = [:]
    var parityCounts: [RivalMove: Int] = [:]
    for venture in 1...6 {
      for sprint in 1...12 {
        aheadCounts[RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 77, baseStrength: 2, playerStrength: 0.5, lastPlayerEffects: SimulationEffects()), default: 0] += 1
        parityCounts[RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 77, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects()), default: 0] += 1
      }
    }
    XCTAssertGreaterThan(aheadCounts[.overreach, default: 0], parityCounts[.overreach, default: 0])
  }

  func testCopycatMirrorsPlayersDominantRecentMove() {
    let rival = RivalCompany(id: "test-copy-react", name: "Test Reactive Copy Co", archetype: .copycat, debutVenture: 1, baseStrength: 1)
    var quietCounts: [RivalMove: Int] = [:]
    var reactiveCounts: [RivalMove: Int] = [:]
    for venture in 1...6 {
      for sprint in 1...12 {
        quietCounts[RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 21, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects()), default: 0] += 1
        reactiveCounts[RivalEngine.decideMove(for: rival, venture: venture, sprint: sprint, careerSeed: 21, baseStrength: 1, playerStrength: 1, lastPlayerEffects: SimulationEffects(momentum: 20)), default: 0] += 1
      }
    }
    XCTAssertGreaterThan(reactiveCounts[.featureCopy, default: 0], quietCounts[.featureCopy, default: 0])
  }

  func testMoveImpactStrengthAndPlayerEffectsStayInBounds() {
    let rival = RivalCompany(id: "impact-test", name: "Impact Test Co", archetype: .upstart, debutVenture: 1, baseStrength: 1)
    for venture in 1...4 {
      for sprint in 1...12 {
        for move in RivalMove.allCases {
          let impact = RivalEngine.moveImpact(move, rival: rival, venture: venture, sprint: sprint, careerSeed: 123, lastPlayerEffects: SimulationEffects())
          XCTAssertTrue(impact.headline.contains(rival.name))
          switch move {
          case .steadyBuild:
            XCTAssertTrue((0.04...0.10).contains(impact.strengthBonus))
            XCTAssertEqual(impact.playerEffects, SimulationEffects())
          case .prBlitz:
            XCTAssertTrue((0.15...0.25).contains(impact.strengthBonus))
            XCTAssertTrue((-4 ... -2).contains(impact.playerEffects.momentum))
          case .priceUndercut:
            XCTAssertTrue((0.08...0.14).contains(impact.strengthBonus))
            XCTAssertTrue((-39 ... -15).contains(impact.playerEffects.revenue))
          case .featureCopy:
            XCTAssertEqual(impact.strengthBonus, 0.10, accuracy: 0.0001)
            XCTAssertTrue((-2 ... -1).contains(impact.playerEffects.trust))
          case .talentPoach:
            XCTAssertTrue((0.10...0.16).contains(impact.strengthBonus))
            XCTAssertTrue((-4 ... -2).contains(impact.playerEffects.energy))
          case .fortify:
            XCTAssertTrue((0.10...0.18).contains(impact.strengthBonus))
            XCTAssertEqual(impact.playerEffects, SimulationEffects())
          case .fundraiseSurge:
            XCTAssertTrue((0.25...0.45).contains(impact.strengthBonus))
            XCTAssertEqual(impact.playerEffects, SimulationEffects())
          case .overreach:
            XCTAssertTrue((-0.30 ... -0.10).contains(impact.strengthBonus))
            XCTAssertEqual(impact.playerEffects, SimulationEffects())
          }
        }
      }
    }
  }

  func testFeatureCopyBonusScalesWithPlayersDominantDeltaButStaysCapped() {
    let rival = RivalCompany(id: "copy-scale", name: "Copy Scale Co", archetype: .copycat, debutVenture: 1, baseStrength: 1)
    let quiet = RivalEngine.moveImpact(.featureCopy, rival: rival, venture: 2, sprint: 5, careerSeed: 44, lastPlayerEffects: SimulationEffects())
    let modest = RivalEngine.moveImpact(.featureCopy, rival: rival, venture: 2, sprint: 5, careerSeed: 44, lastPlayerEffects: SimulationEffects(momentum: 8))
    let huge = RivalEngine.moveImpact(.featureCopy, rival: rival, venture: 2, sprint: 5, careerSeed: 44, lastPlayerEffects: SimulationEffects(momentum: 200))
    XCTAssertEqual(quiet.strengthBonus, 0.10, accuracy: 0.0001)
    XCTAssertGreaterThan(modest.strengthBonus, quiet.strengthBonus)
    XCTAssertGreaterThan(huge.strengthBonus, modest.strengthBonus)
    XCTAssertLessThanOrEqual(huge.strengthBonus, 0.30)
  }

  func testOverreachIsAlwaysAPenaltyAndFundraiseSurgeIsAlwaysTheBiggestSingleGain() {
    let rival = RivalCompany(id: "bounds-check", name: "Bounds Check Co", archetype: .hypeMachine, debutVenture: 1, baseStrength: 1)
    for venture in 1...3 {
      for sprint in 1...12 {
        let overreach = RivalEngine.moveImpact(.overreach, rival: rival, venture: venture, sprint: sprint, careerSeed: 8_080, lastPlayerEffects: SimulationEffects())
        let fundraise = RivalEngine.moveImpact(.fundraiseSurge, rival: rival, venture: venture, sprint: sprint, careerSeed: 8_080, lastPlayerEffects: SimulationEffects())
        let steady = RivalEngine.moveImpact(.steadyBuild, rival: rival, venture: venture, sprint: sprint, careerSeed: 8_080, lastPlayerEffects: SimulationEffects())
        XCTAssertLessThan(overreach.strengthBonus, 0)
        XCTAssertGreaterThan(fundraise.strengthBonus, overreach.strengthBonus)
        XCTAssertGreaterThan(fundraise.strengthBonus, steady.strengthBonus)
      }
    }
  }
}
