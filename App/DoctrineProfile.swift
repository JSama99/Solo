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
struct DoctrineProfile: Hashable {
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

  static func profile(for doctrine: FounderDoctrine) -> DoctrineProfile {
    switch doctrine {
    case .pure:
      DoctrineProfile(
        attentionMaximum: 2,
        reviewEnergyCost: 1,
        neglectDriftIncrease: 9.0,
        actualQualityBonus: 7,
        startingStatAdjustment: SimulationEffects()
      )
    case .guided:
      DoctrineProfile(
        attentionMaximum: 3,
        reviewEnergyCost: 2,
        neglectDriftIncrease: 6.5,
        actualQualityBonus: 0,
        startingStatAdjustment: SimulationEffects(energy: 5)
      )
    case .trust:
      DoctrineProfile(
        attentionMaximum: 2,
        reviewEnergyCost: 1,
        neglectDriftIncrease: 6.5,
        actualQualityBonus: 0,
        startingStatAdjustment: SimulationEffects(trust: 12, momentum: -4)
      )
    }
  }
}
