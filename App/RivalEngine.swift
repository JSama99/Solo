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

/// A deterministic competitive action selected from an archetype-specific kit.
enum RivalMove: String, CaseIterable, Codable, Hashable {
  case steadyBuild
  case prBlitz
  case priceUndercut
  case featureCopy
  case talentPoach
  case fortify
  case fundraiseSurge
  case overreach

  var label: String {
    switch self {
    case .steadyBuild: "Steady Build"
    case .prBlitz: "PR Blitz"
    case .priceUndercut: "Price Undercut"
    case .featureCopy: "Feature Copy"
    case .talentPoach: "Talent Poach"
    case .fortify: "Fortify"
    case .fundraiseSurge: "Fundraise Surge"
    case .overreach: "Overreach"
    }
  }
}

/// One rival's resolved, unsaved action for a single sprint.
struct RivalMoveEvent: Identifiable, Hashable {
  var id: String
  var rivalID: String
  var rivalName: String
  var archetype: RivalArchetype
  var move: RivalMove
  var strengthBonus: Double
  var playerEffects: SimulationEffects
  var headline: String
}

enum RivalDiscontinuityKind: String, Codable, Hashable {
  case exposure, acquisition, pivot, collapse
}

struct RivalDiscontinuity: Codable, Hashable, Identifiable {
  var id: String
  var kind: RivalDiscontinuityKind
  var primaryRivalID: String
  var secondaryRivalID: String?
  var venture: Int
  var sprint: Int
  var headline: String
}

enum RivalEngine {
  static func careerSeed(founderName: String, productType: ProductType) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in (founderName + productType.rawValue).utf8 { hash ^= UInt64(byte); hash &*= 0x100000001b3 }
    return hash
  }

  static func strength(of rival: RivalCompany, venture: Int, sprint: Int, careerSeed: UInt64, player: FounderStats, playerFlags: Set<CompanyFlag>, revealedDoctrine: FounderDoctrine? = nil, exposedRivalIDs: Set<String> = []) -> Double {
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
    let doctrineReaction: Double
    switch (rival.archetype, revealedDoctrine) {
    case (.hypeMachine, .trust): doctrineReaction = 1.1
    case (.quietBuilder, .pure): doctrineReaction = 0.9
    case (.copycat, .guided): doctrineReaction = 0.7
    default: doctrineReaction = 0
    }
    let exposureMultiplier = exposedRivalIDs.contains(rival.id) ? 0.35 : 1
    return max(0, (rival.baseStrength * (1 + growth) + reaction + doctrineReaction) * exposureMultiplier)
  }

  static func playerStrength(_ stats: FounderStats) -> Double {
    max(0.1, Double(stats.revenue) / 900 + Double(stats.momentum) * 0.045 + Double(stats.trust) * 0.030)
  }

  static func standings(companies: [RivalCompany], venture: Int, sprint: Int, careerSeed: UInt64, player: FounderStats, playerFlags: Set<CompanyFlag>, revealedDoctrine: FounderDoctrine? = nil, exposedRivalIDs: Set<String> = [], discontinuities: [RivalDiscontinuity] = [], lastPlayerEffects: SimulationEffects = SimulationEffects()) -> [RivalStanding] {
    let exited = Set(discontinuities.filter { $0.kind == .collapse || $0.kind == .acquisition }.compactMap { $0.kind == .collapse ? $0.primaryRivalID : $0.secondaryRivalID })
    let acquired = Set(discontinuities.filter { $0.kind == .acquisition }.map(\.primaryRivalID))
    let pivoted = Set(discontinuities.filter { $0.kind == .pivot }.map(\.primaryRivalID))
    let bonuses = Dictionary(uniqueKeysWithValues: moveEvents(
      companies: companies,
      venture: venture,
      sprint: sprint,
      careerSeed: careerSeed,
      player: player,
      playerFlags: playerFlags,
      revealedDoctrine: revealedDoctrine,
      exposedRivalIDs: exposedRivalIDs,
      discontinuities: discontinuities,
      lastPlayerEffects: lastPlayerEffects
    ).map { ($0.rivalID, $0.strengthBonus) })
    let rivalStrengths = companies.filter { !exited.contains($0.id) }.map { company -> (company: RivalCompany, strength: Double) in
      var value = strength(of: company, venture: venture, sprint: sprint, careerSeed: careerSeed, player: player, playerFlags: playerFlags, revealedDoctrine: revealedDoctrine, exposedRivalIDs: exposedRivalIDs)
      if acquired.contains(company.id) { value *= 1.35 }
      if pivoted.contains(company.id) { value *= 1.20 }
      return (company, max(0, value + (value > 0 ? bonuses[company.id] ?? 0 : 0)))
    }.filter { $0.strength > 0 }
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

  // MARK: - Rival AI

  /// Recomputes every active rival's move without consuming simulation RNG.
  static func moveEvents(
    companies: [RivalCompany],
    venture: Int,
    sprint: Int,
    careerSeed: UInt64,
    player: FounderStats,
    playerFlags: Set<CompanyFlag>,
    revealedDoctrine: FounderDoctrine? = nil,
    exposedRivalIDs: Set<String> = [],
    discontinuities: [RivalDiscontinuity] = [],
    lastPlayerEffects: SimulationEffects
  ) -> [RivalMoveEvent] {
    let playerStr = playerStrength(player)
    let exited = Set(discontinuities.filter { $0.kind == .collapse || $0.kind == .acquisition }.compactMap {
      $0.kind == .collapse ? $0.primaryRivalID : $0.secondaryRivalID
    })
    return companies.filter { !exited.contains($0.id) }.compactMap { company -> RivalMoveEvent? in
      let base = strength(
        of: company,
        venture: venture,
        sprint: sprint,
        careerSeed: careerSeed,
        player: player,
        playerFlags: playerFlags,
        revealedDoctrine: revealedDoctrine,
        exposedRivalIDs: exposedRivalIDs
      )
      guard base > 0 else { return nil }
      let move = decideMove(
        for: company,
        venture: venture,
        sprint: sprint,
        careerSeed: careerSeed,
        baseStrength: base,
        playerStrength: playerStr,
        lastPlayerEffects: lastPlayerEffects
      )
      let impact = moveImpact(
        move,
        rival: company,
        venture: venture,
        sprint: sprint,
        careerSeed: careerSeed,
        lastPlayerEffects: lastPlayerEffects
      )
      return RivalMoveEvent(
        id: "\(company.id)-v\(venture)s\(sprint)",
        rivalID: company.id,
        rivalName: company.name,
        archetype: company.archetype,
        move: move,
        strengthBonus: impact.strengthBonus,
        playerEffects: impact.playerEffects,
        headline: impact.headline
      )
    }
  }

  /// Selects a move from posture and prior-sprint reads using a hash roll.
  static func decideMove(
    for rival: RivalCompany,
    venture: Int,
    sprint: Int,
    careerSeed: UInt64,
    baseStrength: Double,
    playerStrength: Double,
    lastPlayerEffects: SimulationEffects
  ) -> RivalMove {
    var weights = archetypeWeights(rival.archetype)
    let ratio = playerStrength > 0.0001 ? baseStrength / playerStrength : 2

    if ratio < 0.7 {
      weights[.fundraiseSurge, default: 0] *= 2.2
      weights[.prBlitz, default: 0] *= 1.4
      weights[.fortify, default: 0] *= 0.4
    } else if ratio > 1.3 {
      weights[.fortify, default: 0] *= 1.6
      weights[.overreach, default: 0] *= 1.8
      weights[.steadyBuild, default: 0] *= 1.2
    }

    let dominant = dominantMagnitude(lastPlayerEffects)
    switch rival.archetype {
    case .copycat where dominant >= 5:
      weights[.featureCopy, default: 0] *= 1.6
    case .hypeMachine where lastPlayerEffects.momentum >= 6:
      weights[.prBlitz, default: 0] *= 1.5
    case .quietBuilder where lastPlayerEffects.revenue >= 60:
      weights[.priceUndercut, default: 0] *= 1.4
    case .incumbent where lastPlayerEffects.trust >= 6:
      weights[.fortify, default: 0] *= 1.3
    default:
      break
    }

    let roll = unitRoll(seed: careerSeed, rivalID: rival.id, venture: venture, sprint: sprint, channel: 1)
    return weightedPick(weights, roll: roll)
  }

  /// Resolves the bounded strength, player pressure, and visible headline.
  static func moveImpact(
    _ move: RivalMove,
    rival: RivalCompany,
    venture: Int,
    sprint: Int,
    careerSeed: UInt64,
    lastPlayerEffects: SimulationEffects
  ) -> (strengthBonus: Double, playerEffects: SimulationEffects, headline: String) {
    let magnitude = unitRoll(seed: careerSeed, rivalID: rival.id, venture: venture, sprint: sprint, channel: 2)
    let variant = unitRoll(seed: careerSeed, rivalID: rival.id, venture: venture, sprint: sprint, channel: 3) < 0.5 ? 0 : 1
    let name = rival.name

    switch move {
    case .steadyBuild:
      let bonus = 0.04 + magnitude * 0.06
      let headline = variant == 0
        ? "\(name) ships another quiet release — no headlines, just steady progress."
        : "\(name) keeps its head down and keeps shipping."
      return (bonus, SimulationEffects(), headline)
    case .prBlitz:
      let bonus = 0.15 + magnitude * 0.10
      let momentumHit = -(2 + Int(magnitude * 3))
      let headline = variant == 0
        ? "\(name) dominates the news cycle with a splashy launch push."
        : "\(name) goes loud — press, influencers, the works."
      return (bonus, SimulationEffects(momentum: momentumHit), headline)
    case .priceUndercut:
      let bonus = 0.08 + magnitude * 0.06
      let revenueHit = -(15 + Int(magnitude * 25))
      let headline = variant == 0
        ? "\(name) undercuts pricing across the board, pressuring the field."
        : "\(name) rolls out an aggressive discount campaign."
      return (bonus, SimulationEffects(revenue: revenueHit), headline)
    case .featureCopy:
      let dominant = dominantMagnitude(lastPlayerEffects)
      let bonus = min(0.30, 0.10 + Double(max(0, dominant)) * 0.02)
      let trustHit = -(1 + Int(magnitude * 2))
      let headline = variant == 0
        ? "\(name) quietly ships a feature that looks a lot like yours."
        : "\(name) matches your latest move almost exactly."
      return (bonus, SimulationEffects(trust: trustHit), headline)
    case .talentPoach:
      let bonus = 0.10 + magnitude * 0.06
      let energyHit = -(2 + Int(magnitude * 3))
      let headline = variant == 0
        ? "\(name) makes a run at your top talent."
        : "\(name) is quietly courting your best people."
      return (bonus, SimulationEffects(energy: energyHit), headline)
    case .fortify:
      let bonus = 0.10 + magnitude * 0.08
      let headline = variant == 0
        ? "\(name) doubles down on retention and moat-building."
        : "\(name) hunkers down and locks in its existing customers."
      return (bonus, SimulationEffects(), headline)
    case .fundraiseSurge:
      let bonus = 0.25 + magnitude * 0.20
      let headline = variant == 0
        ? "\(name) closes a big round and comes out swinging."
        : "\(name) raises fresh capital and goes on the attack."
      return (bonus, SimulationEffects(), headline)
    case .overreach:
      let bonus = -(0.10 + magnitude * 0.20)
      let headline = variant == 0
        ? "\(name) overreaches — a botched rollout costs them momentum."
        : "\(name) stumbles publicly after moving too fast."
      return (bonus, SimulationEffects(), headline)
    }
  }

  private static func archetypeWeights(_ archetype: RivalArchetype) -> [RivalMove: Double] {
    switch archetype {
    case .incumbent:
      return [.fortify: 0.30, .steadyBuild: 0.30, .priceUndercut: 0.20, .talentPoach: 0.10, .prBlitz: 0.05, .overreach: 0.05]
    case .upstart:
      return [.prBlitz: 0.25, .fundraiseSurge: 0.25, .talentPoach: 0.15, .steadyBuild: 0.15, .priceUndercut: 0.10, .overreach: 0.10]
    case .hypeMachine:
      return [.prBlitz: 0.40, .fundraiseSurge: 0.15, .overreach: 0.15, .talentPoach: 0.10, .steadyBuild: 0.10, .priceUndercut: 0.05, .fortify: 0.05]
    case .quietBuilder:
      return [.steadyBuild: 0.45, .fortify: 0.25, .priceUndercut: 0.15, .talentPoach: 0.10, .prBlitz: 0.05]
    case .copycat:
      return [.featureCopy: 0.45, .steadyBuild: 0.20, .priceUndercut: 0.15, .talentPoach: 0.10, .prBlitz: 0.10]
    }
  }

  private static func weightedPick(_ weights: [RivalMove: Double], roll: Double) -> RivalMove {
    let entries = RivalMove.allCases.map { ($0, max(0, weights[$0] ?? 0)) }
    let total = entries.reduce(0) { $0 + $1.1 }
    guard total > 0 else { return .steadyBuild }
    let target = roll * total
    var cursor = 0.0
    for (move, weight) in entries {
      cursor += weight
      if target < cursor { return move }
    }
    return entries.last?.0 ?? .steadyBuild
  }

  private static func dominantMagnitude(_ effects: SimulationEffects) -> Int {
    [effects.momentum, effects.trust, effects.energy, effects.revenue / 20].map { abs($0) }.max() ?? 0
  }

  private static func unitRoll(seed: UInt64, rivalID: String, venture: Int, sprint: Int, channel: UInt64) -> Double {
    var hash = seed &* 0x9E3779B97F4A7C15 &+ channel &* 0xBF58476D1CE4E5B9
    for byte in rivalID.utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100000001B3
    }
    hash ^= UInt64(bitPattern: Int64(venture) &* 2_654_435_761 &+ Int64(sprint) &* 40_503)
    hash &*= 0x100000001B3
    hash ^= hash >> 33
    return Double(hash % 1_000_000) / 1_000_000
  }

  private static func wobble(_ rival: RivalCompany, venture: Int, sprint: Int, seed: UInt64) -> Double {
    var hash = seed &* 0x9E3779B97F4A7C15
    for byte in rival.id.utf8 { hash ^= UInt64(byte); hash &*= 0x100000001B3 }
    hash ^= UInt64(venture * 733 + sprint * 97)
    hash &*= 0x100000001B3
    return Double(hash % 1_000) / 1_000 - 0.5
  }
}
