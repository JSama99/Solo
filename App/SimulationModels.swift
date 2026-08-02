import Foundation

enum VerificationState: String, Codable, CaseIterable {
  case reported
  case unverified
  case verified
  case confirmed
  case overclaimed
  case driftDetected
  case evidenceIncomplete

  var revealsActualQuality: Bool {
    switch self {
    case .verified, .confirmed, .overclaimed, .driftDetected:
      true
    case .reported, .unverified, .evidenceIncomplete:
      false
    }
  }

  var reviewAttempted: Bool {
    switch self {
    case .reported, .unverified:
      false
    case .verified, .confirmed, .overclaimed, .driftDetected, .evidenceIncomplete:
      true
    }
  }

  var evidenceVerified: Bool {
    reviewAttempted && self != .evidenceIncomplete
  }

  var label: String {
    switch self {
    case .reported: "Reported"
    case .unverified: "Unverified"
    case .verified: "Verified"
    case .confirmed: "Confirmed"
    case .overclaimed: "Overclaimed"
    case .driftDetected: "Drift Detected"
    case .evidenceIncomplete: "Evidence Incomplete"
    }
  }
}

struct SimulationEffects: Codable, Hashable {
  var revenue = 0
  var momentum = 0
  var trust = 0
  var energy = 0
  var runway = 0

  static func + (lhs: Self, rhs: Self) -> Self {
    Self(
      revenue: lhs.revenue + rhs.revenue,
      momentum: lhs.momentum + rhs.momentum,
      trust: lhs.trust + rhs.trust,
      energy: lhs.energy + rhs.energy,
      runway: lhs.runway + rhs.runway
    )
  }

  var normalized: Self {
    Self(
      revenue: min(1_000_000, max(-1_000_000, revenue)),
      momentum: min(100, max(-100, momentum)),
      trust: min(100, max(-100, trust)),
      energy: min(100, max(-100, energy)),
      runway: min(365, max(-365, runway))
    )
  }
}

struct TaskResult: Codable, Hashable {
  private var hiddenActualQuality: Int
  var reportedQuality: Int
  var verificationState: VerificationState
  var overclaimAmount: Int
  var evidenceCompleteness: Int
  var correlatedFailureIdentifier: String?
  var immediateEffects: SimulationEffects
  var delayedEffects: SimulationEffects
  var confidenceLowerBound: Int
  var confidenceUpperBound: Int
  var knownOperationalRisk: String

  private enum CodingKeys: String, CodingKey {
    case hiddenActualQuality
    case reportedQuality
    case verificationState
    case overclaimAmount
    case evidenceCompleteness
    case correlatedFailureIdentifier
    case immediateEffects
    case delayedEffects
    case confidenceLowerBound
    case confidenceUpperBound
    case knownOperationalRisk
  }

  var revealedActualQuality: Int? {
    verificationState.revealsActualQuality ? hiddenActualQuality : nil
  }

  var confidenceRangeLabel: String {
    "\(confidenceLowerBound)–\(confidenceUpperBound)"
  }

  var isStrongForSimulation: Bool { hiddenActualQuality >= 68 }

  var isRiskyForSimulation: Bool {
    hiddenActualQuality < 52 || evidenceCompleteness < 45 || correlatedFailureIdentifier != nil
  }

  init(
    actualQuality: Int,
    reportedQuality: Int,
    verificationState: VerificationState = .reported,
    evidenceCompleteness: Int,
    correlatedFailureIdentifier: String?,
    immediateEffects: SimulationEffects,
    delayedEffects: SimulationEffects,
    confidenceLowerBound: Int,
    confidenceUpperBound: Int,
    knownOperationalRisk: String
  ) {
    hiddenActualQuality = Self.clamp(actualQuality)
    self.reportedQuality = Self.clamp(reportedQuality)
    self.verificationState = verificationState
    overclaimAmount = max(0, self.reportedQuality - hiddenActualQuality)
    self.evidenceCompleteness = Self.clamp(evidenceCompleteness)
    self.correlatedFailureIdentifier = correlatedFailureIdentifier
    self.immediateEffects = immediateEffects.normalized
    self.delayedEffects = delayedEffects.normalized
    self.confidenceLowerBound = Self.clamp(min(confidenceLowerBound, confidenceUpperBound))
    self.confidenceUpperBound = Self.clamp(max(confidenceLowerBound, confidenceUpperBound))
    self.knownOperationalRisk = knownOperationalRisk
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      actualQuality: try container.decodeIfPresent(Int.self, forKey: .hiddenActualQuality) ?? 0,
      reportedQuality: try container.decodeIfPresent(Int.self, forKey: .reportedQuality) ?? 0,
      verificationState: try container.decodeIfPresent(VerificationState.self, forKey: .verificationState) ?? .reported,
      evidenceCompleteness: try container.decodeIfPresent(Int.self, forKey: .evidenceCompleteness) ?? 0,
      correlatedFailureIdentifier: try container.decodeIfPresent(String.self, forKey: .correlatedFailureIdentifier),
      immediateEffects: try container.decodeIfPresent(SimulationEffects.self, forKey: .immediateEffects) ?? SimulationEffects(),
      delayedEffects: try container.decodeIfPresent(SimulationEffects.self, forKey: .delayedEffects) ?? SimulationEffects(),
      confidenceLowerBound: try container.decodeIfPresent(Int.self, forKey: .confidenceLowerBound) ?? 0,
      confidenceUpperBound: try container.decodeIfPresent(Int.self, forKey: .confidenceUpperBound) ?? 100,
      knownOperationalRisk: try container.decodeIfPresent(String.self, forKey: .knownOperationalRisk) ?? "Unknown operational risk"
    )
  }

  @discardableResult
  mutating func verify() -> VerificationState {
    let variance = abs(reportedQuality - hiddenActualQuality)
    if correlatedFailureIdentifier != nil && variance >= 12 {
      verificationState = .driftDetected
    } else if evidenceCompleteness < 45 {
      verificationState = .evidenceIncomplete
    } else if overclaimAmount >= 8 {
      verificationState = .overclaimed
    } else if variance <= 5 {
      verificationState = .confirmed
    } else {
      verificationState = .verified
    }
    return verificationState
  }

  mutating func markUnverified() {
    if verificationState == .reported {
      verificationState = .unverified
    }
  }

  private static func clamp(_ value: Int) -> Int {
    min(100, max(0, value))
  }
}

struct CorrelatedFailureEvent: Codable, Hashable {
  var id: String
  var modelFamily: String
  var qualityPenalty: Int
}

struct ScheduledEffect: Codable, Hashable {
  var dueCareerSprint: Int
  var source: String
  var effects: SimulationEffects
}

struct CachedTaskReport: Codable, Hashable {
  var venture: Int
  var sprint: Int
  var taskID: UUID
  var agentID: String
  var intent: SprintIntent
  var result: TaskResult
}
