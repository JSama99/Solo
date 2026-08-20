import Foundation

enum Divergence {
  static let horizon = 4
  static let maximumForksPerVenture = 2

  static func pressure(sprintsSinceFork: Int, horizon: Int = horizon) -> Double {
    guard horizon > 0 else { return 1 }
    return min(1, max(0, Double(sprintsSinceFork) / Double(horizon)))
  }

  static func diverges(at coordinate: DrawCoordinate, sprintsSinceFork: Int, horizon: Int = horizon) -> Bool {
    let probability = pressure(sprintsSinceFork: sprintsSinceFork, horizon: horizon)
    guard probability > 0 else { return false }
    let unsalted = coordinate.replacing(channel: coordinate.channel, divergenceSalt: 0)
    let roll = Double(SeededRandomNumberGenerator.mixed(unsalted.key) >> 11) / Double(1 << 53)
    return roll < probability
  }

  static func drawCoordinate(
    _ coordinate: DrawCoordinate,
    sprintsSinceFork: Int,
    horizon: Int = horizon
  ) -> DrawCoordinate {
    diverges(at: coordinate, sprintsSinceFork: sprintsSinceFork, horizon: horizon)
      ? coordinate
      : coordinate.replacing(channel: coordinate.channel, divergenceSalt: 0)
  }
}

enum ForkChoice: String, Codable, Hashable {
  case shipAll
  case holdUnverified

  var title: String {
    switch self {
    case .shipAll: "Ship all three"
    case .holdUnverified: "Hold the unverified one back"
    }
  }

  var opposite: ForkChoice { self == .shipAll ? .holdUnverified : .shipAll }
}

struct DivergenceOffer: Identifiable, Hashable {
  var id: String
  var venture: Int
  var sprint: Int
  var context: PrecedentContext
}

struct GhostPolicy: Codable, Hashable {
  var archetype: RivalArchetype
  var verificationRate: Double
  var prefersRoleFit: Bool
  var protectsRest: Bool
  var shipsRisk: Bool

  static func policy(for archetype: RivalArchetype, profile: DoctrineProfile) -> GhostPolicy {
    switch archetype {
    case .incumbent: GhostPolicy(archetype: archetype, verificationRate: 0.78, prefersRoleFit: true, protectsRest: false, shipsRisk: false)
    case .upstart: GhostPolicy(archetype: archetype, verificationRate: 0.18, prefersRoleFit: false, protectsRest: false, shipsRisk: true)
    case .hypeMachine: GhostPolicy(archetype: archetype, verificationRate: 0.03, prefersRoleFit: false, protectsRest: false, shipsRisk: true)
    case .quietBuilder: GhostPolicy(archetype: archetype, verificationRate: 0.95, prefersRoleFit: true, protectsRest: true, shipsRisk: false)
    case .copycat: GhostPolicy(archetype: archetype, verificationRate: profile.verificationRate, prefersRoleFit: profile.roleFitDiscipline >= 0.5, protectsRest: profile.restDiscipline >= 0.5, shipsRisk: profile.unverifiedShipRate >= 0.5)
    }
  }

  static func selectRival(from rivals: [RivalCompany], profile: DoctrineProfile) -> RivalCompany? {
    rivals.max { lhs, rhs in
      let left = distance(policy(for: lhs.archetype, profile: profile), profile: profile)
      let right = distance(policy(for: rhs.archetype, profile: profile), profile: profile)
      return left == right ? lhs.id > rhs.id : left < right
    }
  }

  private static func distance(_ policy: GhostPolicy, profile: DoctrineProfile) -> Double {
    abs(policy.verificationRate - profile.verificationRate)
      + abs((policy.shipsRisk ? 1 : 0) - profile.unverifiedShipRate)
      + abs((policy.prefersRoleFit ? 1 : 0) - profile.roleFitDiscipline)
      + abs((policy.protectsRest ? 1 : 0) - profile.restDiscipline)
  }
}

struct DivergenceOutcome: Codable, Hashable {
  var summary: String
  var outcome: PrecedentOutcome
  var effects: SimulationEffects
  var resolutions: Int
}

struct DivergenceBranch: Codable, Hashable, Identifiable {
  var id: String
  var venture: Int
  var sprint: Int
  var context: PrecedentContext
  var takenChoice: ForkChoice
  var takenSummary: String
  var takenOutcome: PrecedentOutcome
  var ghostRival: RivalCompany
  var ghostPolicy: GhostPolicy
  var ghostOutcome: DivergenceOutcome
  var collapsedAtCareerSprint: Int
}

struct DivergenceRecord: Codable, Hashable, Identifiable {
  var id: UUID
  var venture: Int
  var sprint: Int
  var context: PrecedentContext
  var takenSummary: String
  var takenOutcome: PrecedentOutcome
  var ghostRivalID: String
  var ghostRivalName: String
  var ghostArchetype: RivalArchetype
  var ghostSummary: String
  var ghostOutcome: PrecedentOutcome
  var collapsedAtSprint: Int
}

extension SimulationEngine {
  static func runGhost(
    tasks: [SoloTask],
    agents: [SoloAgent],
    intent: SprintIntent,
    doctrine: FounderDoctrine,
    careerSeed: UInt64,
    forkVenture: Int,
    forkSprint: Int,
    choice: ForkChoice,
    policy: GhostPolicy,
    horizon: Int
  ) -> DivergenceOutcome {
    guard !tasks.isEmpty, !agents.isEmpty, horizon > 0 else {
      return DivergenceOutcome(summary: "No ghost work resolved.", outcome: PrecedentOutcome(), effects: SimulationEffects(), resolutions: 0)
    }
    var effects = SimulationEffects()
    var outcome = PrecedentOutcome()
    var resolutions = 0
    for offset in 0..<horizon {
      var sprintTasks = tasks
      if choice == .holdUnverified, let risky = sprintTasks.indices.max(by: {
        (sprintTasks[$0].result?.evidenceCompleteness ?? 0) > (sprintTasks[$1].result?.evidenceCompleteness ?? 0)
      }) {
        sprintTasks.remove(at: risky)
      }
      for (index, task) in sprintTasks.enumerated() {
        let agent: SoloAgent
        if policy.prefersRoleFit, let fit = agents.first(where: { $0.role == task.role || $0.role == .general || task.role == .general }) {
          agent = fit
        } else {
          agent = agents[index % agents.count]
        }
        let coordinate = DrawCoordinate(
          careerSeed: careerSeed,
          venture: forkVenture,
          sprint: forkSprint + offset,
          taskInstanceID: task.id.uuidString,
          agentID: agent.id,
          channel: .quality,
          divergenceSalt: 0x47484F5354
        )
        var fallback = SeededRandomNumberGenerator(seed: coordinate.key)
        var result = makeResult(
          for: task,
          agent: agent,
          intent: intent,
          doctrine: doctrine,
          correlatedFailureEvent: nil,
          allTasks: sprintTasks,
          allAgents: agents,
          coordinate: coordinate,
          sprintsSinceFork: offset,
          rng: &fallback
        )
        let verificationRoll = Double(SeededRandomNumberGenerator.mixed(coordinate.replacing(channel: .evidence).key) >> 11) / Double(1 << 53)
        if verificationRoll < policy.verificationRate { _ = result.verify() } else { result.markUnverified() }
        guard policy.shipsRisk || !result.isRiskyForSimulation else { continue }
        effects = effects + result.immediateEffects + result.delayedEffects
        if !result.verificationState.evidenceVerified { outcome.unverifiedCommitted += 1 }
        if result.verificationState == .overclaimed { outcome.overclaimsSurfaced += 1 }
        if result.verificationState == .driftDetected { outcome.driftDetections += 1 }
        resolutions += 1
      }
    }
    outcome.trustDelta = effects.trust
    outcome.runwayDelta = effects.runway
    outcome.momentumDelta = effects.momentum
    return DivergenceOutcome(
      summary: "\(policy.archetype.label) policy resolved \(resolutions) tasks across \(horizon) ghost sprints.",
      outcome: outcome,
      effects: effects,
      resolutions: resolutions
    )
  }
}
