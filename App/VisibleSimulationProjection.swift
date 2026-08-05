import Foundation

struct VisibleTaskResult: Equatable {
  var reportedQuality: Int
  var actualQuality: Int?
  var verificationState: VerificationState
  var overclaimAmount: Int
  var evidenceCompleteness: Int
  var confidenceRangeLabel: String
  var knownOperationalRisk: String
  var correlatedFailureDetected: Bool

  var isVerifiedStrong: Bool {
    guard verificationState.evidenceVerified,
          let actualQuality else { return false }
    return actualQuality >= 68
  }

  var hasVisibleRisk: Bool {
    if verificationState == .overclaimed
      || verificationState == .driftDetected
      || verificationState == .evidenceIncomplete {
      return true
    }
    return knownOperationalRisk != "Normal operational variance"
  }
}

struct VisibleSprintResult: Identifiable, Equatable {
  enum Transition: Equatable {
    case nextSprint
    case ventureCompleted
    case careerEnded(CareerOutcomeKind)
  }

  var id: UUID
  var venture: Int
  var sprint: Int
  var headline: String
  var revenueDelta: Int
  var capitalDelta: Int
  var momentumDelta: Int
  var trustDelta: Int
  var energyDelta: Int
  var runwayDelta: Int
  var reviewsCompleted: Int
  var verifiedStrongOutcomes: Int
  var visibleRiskFlags: Int
  var evidenceRecorded: Int
  var transition: Transition
}

enum VisibleSimulationProjection {
  static func taskResult(from result: TaskResult) -> VisibleTaskResult {
    VisibleTaskResult(
      reportedQuality: result.reportedQuality,
      actualQuality: result.revealedActualQuality,
      verificationState: result.verificationState,
      overclaimAmount: result.revealedActualQuality == nil ? 0 : result.overclaimAmount,
      evidenceCompleteness: result.evidenceCompleteness,
      confidenceRangeLabel: result.confidenceRangeLabel,
      knownOperationalRisk: result.knownOperationalRisk,
      correlatedFailureDetected: result.verificationState == .driftDetected
    )
  }

  static func sprintResult(
    canonicalReport: SprintReport,
    venture: Int,
    tasks: [SoloTask],
    statsBefore: FounderStats,
    statsAfter: FounderStats,
    evidenceBefore: Int,
    evidenceAfter: Int,
    transition: VisibleSprintResult.Transition
  ) -> VisibleSprintResult {
    let visibleResults = tasks.compactMap { task -> VisibleTaskResult? in
      guard let result = task.result else { return nil }
      return taskResult(from: result)
    }
    let strong = visibleResults.filter(\.isVerifiedStrong).count
    let risks = visibleResults.filter(\.hasVisibleRisk).count
    let headline: String
    if risks > 0 {
      headline = "Known risks need founder attention"
    } else if strong > 0 {
      headline = "Verified work moved the company forward"
    } else {
      headline = "The sprint is resolved"
    }
    return VisibleSprintResult(
      id: canonicalReport.id,
      venture: venture,
      sprint: canonicalReport.sprint,
      headline: headline,
      revenueDelta: canonicalReport.revenueDelta,
      capitalDelta: statsAfter.capital - statsBefore.capital,
      momentumDelta: canonicalReport.momentumDelta,
      trustDelta: canonicalReport.trustDelta,
      energyDelta: canonicalReport.energyDelta,
      runwayDelta: canonicalReport.runwayDelta,
      reviewsCompleted: tasks.filter(\.isReviewed).count,
      verifiedStrongOutcomes: strong,
      visibleRiskFlags: risks,
      evidenceRecorded: max(0, evidenceAfter - evidenceBefore),
      transition: transition
    )
  }
}
