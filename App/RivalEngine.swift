import Foundation

enum RivalArchetype: String, Codable, CaseIterable, Hashable {
  case incumbent, upstart, hypeMachine, quietBuilder, copycat

  var label: String {
    switch self {
    case .incumbent: "Incumbent"
    case .upstart: "Upstart"
    case .hypeMachine: "Hype Machine"
    case .quietBuilder: "Quiet Builder"
    case .copycat: "Copycat"
    }
  }
}

struct RivalCompany: Identifiable, Hashable, Codable {
  var id: String
  var name: String
  var archetype: RivalArchetype
  var debutVenture: Int
  var baseStrength: Double
}

struct RivalStanding: Identifiable, Hashable {
  var id: String
  var name: String
  var archetype: RivalArchetype?
  var strength: Double
  var marketShare: Double
  var isPlayer: Bool
}

enum RivalEngine {
  static func careerSeed(founderName: String, productType: ProductType) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in (founderName + productType.rawValue).utf8 { hash ^= UInt64(byte); hash &*= 0x100000001b3 }
    return hash
  }

  static func strength(of rival: RivalCompany, venture: Int, sprint: Int, careerSeed: UInt64, player: FounderStats, playerFlags: Set<CompanyFlag>) -> Double {
    guard venture >= rival.debutVenture else { return 0 }
    let age = Double((venture - rival.debutVenture) * 12 + sprint)
    let wobble = self.wobble(rival, venture: venture, sprint: sprint, seed: careerSeed)
    let growth: Double
    switch rival.archetype {
    case .incumbent: growth = 0.55 * log(age + 2)
    case .upstart: growth = 0.30 * age.squareRoot() + wobble * 1.8
    case .hypeMachine: growth = 0.45 * age.squareRoot() + wobble * 2.6
    case .quietBuilder: growth = 0.22 * age.squareRoot() + 0.03 * age
    case .copycat: growth = 0.28 * age.squareRoot()
    }
    let reaction: Double
    switch rival.archetype {
    case .copycat: reaction = Double(max(player.momentum, player.trust)) * 0.020
    case .hypeMachine: reaction = -Double(player.momentum) * 0.014
    case .quietBuilder: reaction = (playerFlags.contains(.hypeFirst) ? 1.4 : 0) - Double(player.trust) * 0.010
    case .incumbent: reaction = -Double(player.momentum) * 0.006
    case .upstart: reaction = 0.8
    }
    return max(0, rival.baseStrength * (1 + growth) + reaction)
  }

  static func playerStrength(_ stats: FounderStats) -> Double {
    max(0.1, Double(stats.revenue) / 900 + Double(stats.momentum) * 0.045 + Double(stats.trust) * 0.030)
  }

  static func standings(companies: [RivalCompany], venture: Int, sprint: Int, careerSeed: UInt64, player: FounderStats, playerFlags: Set<CompanyFlag>) -> [RivalStanding] {
    let rivalStrengths = companies.map { (company: $0, strength: strength(of: $0, venture: venture, sprint: sprint, careerSeed: careerSeed, player: player, playerFlags: playerFlags)) }.filter { $0.strength > 0 }
    let playerStrength = playerStrength(player)
    let total = playerStrength + rivalStrengths.reduce(0) { $0 + $1.strength }
    let player = RivalStanding(id: "solo", name: "SOLO", archetype: nil, strength: playerStrength, marketShare: playerStrength / total, isPlayer: true)
    return ([player] + rivalStrengths.map { RivalStanding(id: $0.company.id, name: $0.company.name, archetype: $0.company.archetype, strength: $0.strength, marketShare: $0.strength / total, isPlayer: false) }).sorted { $0.strength > $1.strength }
  }

  static func revenueMultiplier(marketShare: Double, fieldSize: Int) -> Double {
    let fairShare = 1 / Double(fieldSize + 1)
    let ratio = marketShare / max(fairShare, 0.0001)
    return min(1.15, max(0.85, 0.85 + 0.30 * min(ratio, 1.6) / 1.6))
  }

  private static func wobble(_ rival: RivalCompany, venture: Int, sprint: Int, seed: UInt64) -> Double {
    var hash = seed &* 0x9E3779B97F4A7C15
    for byte in rival.id.utf8 { hash ^= UInt64(byte); hash &*= 0x100000001B3 }
    hash ^= UInt64(venture * 733 + sprint * 97)
    hash &*= 0x100000001B3
    return Double(hash % 1_000) / 1_000 - 0.5
  }
}
