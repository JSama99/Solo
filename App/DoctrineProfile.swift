import Foundation

/// Centralizes every doctrine-conditional rule that was previously scattered
/// as inline ternaries through GameStore.swift (6 separate `doctrine == .x`
/// checks as of Build 4). One doctrine's full behavior is now readable in one
/// place, and adding a fourth doctrine means adding one case here instead of
/// auditing the whole file for missed branches.
///
/// Every value here is verified to reproduce Build 4's exact prior behavior —
/// this is a pure reorganization, not a rebalance. See BUILD5_CHANGELOG.md
/// for the line-by-line mapping back to what each value replaced.
struct DoctrineRules: Hashable {
  /// Founder Attention actions available per sprint.
  let attentionMaximum: Int
  /// Energy cost of a single Founder Review.
  let reviewEnergyCost: Int
  /// Drift added to an agent whose assigned task went unreviewed this sprint.
  let neglectDriftIncrease: Double
  /// Flat bonus to an agent's actual (hidden) quality on every task.
  let actualQualityBonus: Int
  /// Starting-stat adjustment applied once at career creation.
  let startingStatAdjustment: SimulationEffects

  static func profile(for doctrine: FounderDoctrine) -> DoctrineRules {
    switch doctrine {
    case .pure:
      DoctrineRules(
        attentionMaximum: 2,
        reviewEnergyCost: 1,
        neglectDriftIncrease: 9.0,
        actualQualityBonus: 7,
        startingStatAdjustment: SimulationEffects()
      )
    case .guided:
      DoctrineRules(
        attentionMaximum: 3,
        reviewEnergyCost: 2,
        neglectDriftIncrease: 6.5,
        actualQualityBonus: 0,
        startingStatAdjustment: SimulationEffects(energy: 5)
      )
    case .trust:
      DoctrineRules(
        attentionMaximum: 2,
        reviewEnergyCost: 1,
        neglectDriftIncrease: 6.5,
        actualQualityBonus: 0,
        startingStatAdjustment: SimulationEffects(momentum: -4, trust: 12)
      )
    }
  }
}

/// What the founder did, measured independently from what they declared.
struct DoctrineProfile: Codable, Hashable {
  var verificationRate: Double
  var unverifiedShipRate: Double
  var roleFitDiscipline: Double
  var restDiscipline: Double
  var evidenceThreshold: Double
  var relationshipInvestment: Double

  static let neutral = DoctrineProfile(
    verificationRate: 0,
    unverifiedShipRate: 0,
    roleFitDiscipline: 0,
    restDiscipline: 0,
    evidenceThreshold: 0,
    relationshipInvestment: 0
  )

  static func derive(
    evidence: [EvidenceEntry],
    agents: [SoloAgent],
    decisions: [CareerDecisionRecord],
    flags: Set<CompanyFlag>
  ) -> DoctrineProfile {
    let reviewable = max(1, evidence.count)
    let reviewed = evidence.filter(\.reviewAttempted).count
    let unverified = evidence.filter { !$0.reviewAttempted }.count
    let meanEvidence = evidence.isEmpty ? 0 : Double(evidence.map(\.evidenceCompleteness).reduce(0, +)) / Double(evidence.count)
    let roleMatched = agents.map(\.progression.roleMatchedTasks).reduce(0, +)
    let totalProgress = max(1, agents.map { max($0.progression.roleMatchedTasks, $0.progression.verifiedTasks) }.reduce(0, +))
    let meanRelationship = agents.isEmpty ? 55 : agents.map(\.relationship).reduce(0, +) / agents.count
    let recoverySignals = decisions.filter {
      $0.choiceTitle.localizedCaseInsensitiveContains("rest")
        || $0.choiceTitle.localizedCaseInsensitiveContains("pause")
        || $0.choiceTitle.localizedCaseInsensitiveContains("protect")
    }.count
    let restFlagBonus = flags.contains(.protectedFounderHealth) ? 0.35 : 0
    return DoctrineProfile(
      verificationRate: clamp(Double(reviewed) / Double(reviewable)),
      unverifiedShipRate: clamp(Double(unverified) / Double(reviewable)),
      roleFitDiscipline: clamp(Double(roleMatched) / Double(totalProgress)),
      restDiscipline: clamp(Double(recoverySignals) / Double(max(1, decisions.count)) + restFlagBonus),
      evidenceThreshold: clamp(meanEvidence / 100),
      relationshipInvestment: clamp(Double(meanRelationship) / 100)
    )
  }

  var revealed: FounderDoctrine {
    FounderDoctrine.allCases.min { distance(to: Self.centroid(for: $0)) < distance(to: Self.centroid(for: $1)) } ?? .guided
  }

  func gap(from declared: FounderDoctrine) -> Double {
    min(1, distance(to: Self.centroid(for: declared)) / Double(6).squareRoot())
  }

  private func distance(to other: DoctrineProfile) -> Double {
    let deltas = [
      verificationRate - other.verificationRate,
      unverifiedShipRate - other.unverifiedShipRate,
      roleFitDiscipline - other.roleFitDiscipline,
      restDiscipline - other.restDiscipline,
      evidenceThreshold - other.evidenceThreshold,
      relationshipInvestment - other.relationshipInvestment
    ]
    return deltas.reduce(0) { $0 + $1 * $1 }.squareRoot()
  }

  private static func centroid(for doctrine: FounderDoctrine) -> DoctrineProfile {
    switch doctrine {
    case .pure:
      DoctrineProfile(verificationRate: 0.18, unverifiedShipRate: 0.78, roleFitDiscipline: 0.55, restDiscipline: 0.25, evidenceThreshold: 0.38, relationshipInvestment: 0.35)
    case .guided:
      DoctrineProfile(verificationRate: 0.62, unverifiedShipRate: 0.30, roleFitDiscipline: 0.72, restDiscipline: 0.55, evidenceThreshold: 0.62, relationshipInvestment: 0.58)
    case .trust:
      DoctrineProfile(verificationRate: 0.86, unverifiedShipRate: 0.10, roleFitDiscipline: 0.82, restDiscipline: 0.78, evidenceThreshold: 0.82, relationshipInvestment: 0.80)
    }
  }

  private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}
