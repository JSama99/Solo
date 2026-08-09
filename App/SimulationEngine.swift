import Foundation

/// The pure simulation core, extracted from GameStore.swift.
///
/// Every function here is `static` and takes its dependencies explicitly —
/// no instance state, no hidden reads of `self.tasks` or `self.agents`. That
/// means each one can be unit-tested by calling it directly with fixture
/// values, without spinning up a full `@Observable` `GameStore`. Build 4's
/// version of this logic lived as private instance methods on GameStore,
/// which made "does correlated-failure math work" impossible to test in
/// isolation from the whole UI-facing store.
///
/// The RNG is threaded through as `inout SeededRandomNumberGenerator` rather
/// than owned here, so callers keep full control of the seed and the exact
/// sequence of consumption stays identical to Build 4 — this refactor changes
/// where the code lives, not what it computes or when it draws randomness.
enum SimulationEngine {

  /// Whether a correlated-failure event fires this sprint, and which model
  /// family it targets. 24% chance, matching Build 4 exactly.
  static func generateCorrelatedFailureEvent(
    venture: Int,
    sprint: Int,
    agents: [SoloAgent],
    rng: inout SeededRandomNumberGenerator
  ) -> CorrelatedFailureEvent? {
    let era = VentureEra.era(for: venture)
    guard rng.probability() < era.correlatedFailureBaseProbability else { return nil }
    let families = Array(Set(agents.map(\.modelFamily))).sorted()
    guard !families.isEmpty else { return nil }
    let family = families[rng.integer(in: 0 ... families.count - 1)]
    let eventCode = String(rng.next(), radix: 16, uppercase: true)
    return CorrelatedFailureEvent(
      id: "V\(venture)-S\(sprint)-\(eventCode)",
      modelFamily: family,
      qualityPenalty: rng.integer(in: 16 ... 24) + era.correlatedFailureExtraPenalty
    )
  }

  /// Computes what an agent actually did on a task, what it reports, and how
  /// much evidence backs the report. Identical math to Build 4's
  /// `GameStore.makeResult(for:agent:)`, just with every dependency passed in.
  static func makeResult(
    for task: SoloTask,
    agent: SoloAgent,
    intent: SprintIntent,
    doctrine: FounderDoctrine,
    correlatedFailureEvent: CorrelatedFailureEvent?,
    allTasks: [SoloTask],
    allAgents: [SoloAgent],
    facilityBonuses: FacilityBonuses = .none,
    rng: inout SeededRandomNumberGenerator
  ) -> TaskResult {
    let exactFit = agent.role == task.role
    let flexibleFit = agent.role == .general || task.role == .general
    let roleAdjustment = exactFit ? 14 : (flexibleFit ? 4 : -12)
    let intentAdjustment: Int
    switch (intent, task.role) {
    case (.build, .engineering), (.learn, .research), (.sell, .marketing):
      intentAdjustment = 6
    default:
      intentAdjustment = 0
    }
    let correlation = correlatedFailureEvent?.modelFamily == agent.modelFamily
      ? correlatedFailureEvent
      : nil
    let actualNoise = rng.integer(in: -12 ... 12)
    let relationshipAdjustment = min(8, max(-8, (agent.relationship - 55) / 5))
    let personalityAdjustment: Int
    switch agent.id {
    case "aurora":
      personalityAdjustment = task.role == .research || task.category == .trust ? 4 : (intent == .sell ? -2 : 0)
    case "stacks":
      personalityAdjustment = task.role == .engineering ? 4 : (task.urgency == .critical ? 2 : 0)
    case "brio":
      personalityAdjustment = task.role == .marketing || task.category == .sales ? 4 : (task.category == .trust ? -3 : 0)
    default:
      personalityAdjustment = 0
    }
    let facilityQualityBonus = agent.id == "stacks" && task.role == .engineering
      ? facilityBonuses.engineeringQualityBonus : 0
    let stressAdjustment: Int
    switch agent.progression.stressBand {
    case .focused: stressAdjustment = 2
    case .stable: stressAdjustment = 0
    case .pressured: stressAdjustment = -3
    case .overloaded: stressAdjustment = -7
    case .critical: stressAdjustment = -12
    }
    let perkQualityBonus: Int
    if agent.progression.selectedPerks.contains(.signalDetection), task.role == .research {
      perkQualityBonus = 4
    } else if agent.progression.selectedPerks.contains(.flowState), task.role == .engineering {
      perkQualityBonus = 3
    } else if agent.progression.selectedPerks.contains(.shippingMachine), task.role == .engineering {
      perkQualityBonus = 5
    } else {
      perkQualityBonus = 0
    }
    let rawActual = Double(agent.reliability) * 0.55
      + agent.calibration * 18
      + agent.trust * 0.18
      - agent.drift * 0.35
      + Double(roleAdjustment + intentAdjustment + relationshipAdjustment + personalityAdjustment
        + DoctrineProfile.profile(for: doctrine).actualQualityBonus + facilityQualityBonus + stressAdjustment + perkQualityBonus + actualNoise)
      - Double(correlation?.qualityPenalty ?? 0)
    let actualQuality = clampedPercent(Int(rawActual.rounded()))

    let reportSpread = max(2, Int(((1 - agent.calibration) * 18 + agent.drift * 0.22).rounded()))
    let reportedQuality = clampedPercent(
      actualQuality + rng.integer(in: -reportSpread ... reportSpread)
    )
    var evidenceAdjustment = agent.relationship >= 75 ? 6 : (agent.relationship < 35 ? -8 : 0)
    if agent.id == "aurora" && (task.role == .research || task.category == .trust) { evidenceAdjustment += 5 }
    if agent.id == "brio" && task.urgency == .critical && intent == .sell { evidenceAdjustment -= 5 }
    let facilityEvidenceBonus = agent.id == "aurora" && (task.role == .research || task.category == .trust)
      ? facilityBonuses.auroraEvidenceBonus : 0
    let perkEvidenceBonus = agent.progression.selectedPerks.contains(.sourceTriangulation)
      && (task.role == .research || task.category == .trust) ? 5 : 0
    let evidenceCompleteness = clampedPercent(
      Int((agent.calibration * 70 + Double(agent.reliability) * 0.25 - agent.drift * 0.25).rounded())
        + evidenceAdjustment + facilityEvidenceBonus + perkEvidenceBonus
        + rng.integer(in: -10 ... 10)
    )
    let confidenceWidth = max(
      4,
      Int(((1 - agent.calibration) * 20 + Double(100 - evidenceCompleteness) * 0.1).rounded())
    )
    let immediate = immediateEffects(for: task.impact, actualQuality: actualQuality)
    var delayed = SimulationEffects()
    if actualQuality < 52 {
      delayed.trust -= 2
      delayed.momentum -= 1
    }
    if correlation != nil {
      delayed.trust -= 3
      delayed.momentum -= 3
    }

    return TaskResult(
      actualQuality: actualQuality,
      reportedQuality: reportedQuality,
      evidenceCompleteness: evidenceCompleteness,
      correlatedFailureIdentifier: correlation?.id,
      immediateEffects: immediate,
      delayedEffects: delayed,
      confidenceLowerBound: reportedQuality - confidenceWidth,
      confidenceUpperBound: reportedQuality + confidenceWidth,
      knownOperationalRisk: knownRisk(
        for: task, agent: agent, evidenceCompleteness: evidenceCompleteness,
        allTasks: allTasks, allAgents: allAgents
      )
    )
  }

  static func immediateEffects(for impact: TaskImpact, actualQuality: Int) -> SimulationEffects {
    let multiplier = Double(actualQuality) / 70
    switch impact {
    case .revenue(let amount):
      return SimulationEffects(revenue: Int((Double(amount) * multiplier).rounded()))
    case .momentum(let amount):
      return SimulationEffects(momentum: Int((Double(amount) * multiplier).rounded()))
    case .trust(let amount):
      return SimulationEffects(trust: Int((Double(amount) * multiplier).rounded()))
    case .runway(let amount):
      return SimulationEffects(runway: Int((Double(amount) * multiplier).rounded()))
    case .energy(let amount):
      return SimulationEffects(energy: Int((Double(amount) * multiplier).rounded()))
    }
  }

  static func knownRisk(
    for task: SoloTask,
    agent: SoloAgent,
    evidenceCompleteness: Int,
    allTasks: [SoloTask],
    allAgents: [SoloAgent]
  ) -> String {
    let familyAssignments = allTasks.filter { assignedTask in
      guard let assignedID = assignedTask.assignedAgentID else { return false }
      return allAgents.first(where: { $0.id == assignedID })?.modelFamily == agent.modelFamily
    }.count
    if agent.relationship >= 75 && evidenceCompleteness < 45 {
      return "Agent voluntarily flagged weak evidence"
    }
    if familyAssignments > 1 { return "Shared model-family exposure" }
    if agent.role != task.role && agent.role != .general && task.role != .general { return "Role mismatch" }
    if agent.drift >= 35 { return "Elevated operational drift" }
    if evidenceCompleteness < 45 { return "Limited supporting evidence" }
    return "Normal operational variance"
  }

  /// FIX (Build 5): revenue previously contributed to `careerScore` at a flat
  /// 1:1 rate with no ceiling, while momentum/trust/energy are all clamped to
  /// 0-100 before their multipliers apply. Individual tasks award 430-1,120
  /// revenue each, and 13 of the 38 authored tasks touch revenue directly —
  /// over a full career, cumulative revenue plausibly reaches the thousands,
  /// while trust+momentum+energy combined can never exceed 5,000 *at their
  /// absolute maximum* (100x20 + 100x20 + 100x10). That let revenue dominate
  /// the score almost regardless of how well trust was protected, undercutting
  /// the game's own thesis that verification matters as much as output.
  ///
  /// Revenue now contributes at a quarter of face value, capped at 5,000 —
  /// roughly commensurate with trust and momentum's combined ceiling. The
  /// exact divisor and cap are tunable; the structural fix (bounded,
  /// proportional contribution instead of an uncapped 1:1 term) is what
  /// matters and is not a judgment call.
  static func careerScore(stats: FounderStats) -> Int {
    let revenueContribution = min(stats.revenue / 4, 5_000)
    return max(
      0,
      stats.trackRecord * 10
        + revenueContribution
        + stats.momentum * 20
        + stats.trust * 20
        + stats.energy * 10
    )
  }



  static func careerScore(
    stats: FounderStats,
    verifiedEvidence: Int,
    completedObjectives: Int,
    averageRelationship: Int,
    unresolvedObligations: Int,
    completedVentures: Int
  ) -> Int {
    let base = careerScore(stats: stats)
    let qualityBonus = max(0, verifiedEvidence) * 35
    let objectiveBonus = max(0, completedObjectives) * 120
    let relationshipBonus = max(0, min(100, averageRelationship)) * 8
    let ventureBonus = max(0, completedVentures) * 250
    let obligationPenalty = max(0, unresolvedObligations) * 180
    return max(0, base + qualityBonus + objectiveBonus + relationshipBonus + ventureBonus - obligationPenalty)
  }

  private static func clampedPercent(_ value: Int) -> Int {
    min(100, max(0, value))
  }
}
