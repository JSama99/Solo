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

  func scaled(by multiplier: Double) -> Self {
    Self(
      revenue: Int((Double(revenue) * multiplier).rounded()),
      momentum: Int((Double(momentum) * multiplier).rounded()),
      trust: Int((Double(trust) * multiplier).rounded()),
      energy: Int((Double(energy) * multiplier).rounded()),
      runway: Int((Double(runway) * multiplier).rounded())
    ).normalized
  }
}

struct TaskResult: Codable, Hashable {
  private var hiddenActualQuality: Int
  private var hiddenFounderReviewQuality: Int?
  private var hiddenDeliveredQuality: Int?
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
    case hiddenFounderReviewQuality
    case hiddenDeliveredQuality
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

  /// Company-facing strength after any Work Session extraction loss.
  var isDeliveredStrongForSimulation: Bool { deliveredQualityForSimulation >= 68 }

  var isRiskyForSimulation: Bool {
    hiddenActualQuality < 52 || evidenceCompleteness < 45 || correlatedFailureIdentifier != nil
  }

  /// Canonical hidden truth captured before any Work Session. This remains
  /// internal simulation data and must only enter persisted session state,
  /// never a visible projection.
  var workSessionPotentialQuality: Int { hiddenActualQuality }

  /// Canonical Work Session facts. These remain outside visible projections
  /// until an existing verification or Hindsight reveal earns them.
  var founderReviewQualityForSimulation: Int? { hiddenFounderReviewQuality }
  var deliveredQualityForSimulation: Int { hiddenDeliveredQuality ?? hiddenActualQuality }
  var hasCanonicalWorkSessionOutcome: Bool { hiddenDeliveredQuality != nil }

  /// Routes the organizational payoff through delivered quality while keeping
  /// the agent's original hidden actual quality intact for evaluation and reveal.
  /// Repeated application is prevented by WorkSessionRecord.completionApplied.
  mutating func applyWorkSessionOutcome(deliveredQuality: Int, founderReviewQuality: Int?) {
    let oldQuality = max(1, hiddenActualQuality)
    let bounded = min(hiddenActualQuality, max(0, deliveredQuality))
    immediateEffects = immediateEffects.scaled(by: Double(bounded) / Double(oldQuality))
    hiddenFounderReviewQuality = founderReviewQuality.map(Self.clamp)
    hiddenDeliveredQuality = bounded
  }

  /// Repairs the destructive representation used by the first Work Session
  /// prototype without scaling already-adjusted company effects a second time.
  mutating func restoreLegacyWorkSessionOutcome(
    agentPotentialQuality: Int,
    founderReviewQuality: Int?,
    deliveredQuality: Int
  ) {
    guard hiddenDeliveredQuality == nil else { return }
    hiddenActualQuality = Self.clamp(agentPotentialQuality)
    hiddenFounderReviewQuality = founderReviewQuality.map(Self.clamp)
    hiddenDeliveredQuality = min(hiddenActualQuality, max(0, deliveredQuality))
    overclaimAmount = max(0, reportedQuality - hiddenActualQuality)
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
    hiddenFounderReviewQuality = nil
    hiddenDeliveredQuality = nil
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
    hiddenFounderReviewQuality = try container.decodeIfPresent(Int.self, forKey: .hiddenFounderReviewQuality).map(Self.clamp)
    hiddenDeliveredQuality = try container.decodeIfPresent(Int.self, forKey: .hiddenDeliveredQuality)
      .map { min(hiddenActualQuality, Self.clamp($0)) }
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

  /// Improves the current deliverable after the founder spends time and runway.
  /// The boost is deterministic so rework cannot reroll a bad report.
  mutating func applyFounderRework() {
    hiddenActualQuality = Self.clamp(hiddenActualQuality + 12)
    evidenceCompleteness = Self.clamp(evidenceCompleteness + 18)
    immediateEffects = immediateEffects.scaled(by: 1.12)
    delayedEffects.trust = min(0, delayedEffects.trust + 3)
    delayedEffects.momentum = min(0, delayedEffects.momentum + 2)
    overclaimAmount = max(0, reportedQuality - hiddenActualQuality)
    _ = verify()
  }

  /// Adds a second model-family check. It improves evidence and removes a
  /// correlated-failure marker without turning the task into a free reroll.
  mutating func applyCrossCheck() {
    hiddenActualQuality = Self.clamp(hiddenActualQuality + 5)
    evidenceCompleteness = Self.clamp(evidenceCompleteness + 30)
    correlatedFailureIdentifier = nil
    delayedEffects.trust = min(0, delayedEffects.trust + 4)
    delayedEffects.momentum = min(0, delayedEffects.momentum + 3)
    overclaimAmount = max(0, reportedQuality - hiddenActualQuality)
    _ = verify()
  }

  /// Converts certainty into speed. The current payoff rises, while delayed
  /// trust and momentum exposure become more severe.
  mutating func applyShipAnyway() {
    immediateEffects = immediateEffects.scaled(by: 1.20)
    delayedEffects.trust -= 4
    delayedEffects.momentum -= 2
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

// MARK: - Product Launch operation

enum ProductLaunchOperationState: String, Codable, CaseIterable, Sendable {
  case notStarted, committed, launchCheck, founderDecision, executing, resolving, resolved
}

enum ProductLaunchReleasePosture: String, Codable, CaseIterable, Identifiable, Sendable {
  case shipNow
  case conservative

  var id: Self { self }
  var title: String { self == .shipNow ? "Ship Now" : "Conservative Release" }
  var detail: String {
    self == .shipNow
      ? "Protect the market window; known reliability concerns carry more weight."
      : "Reduce technical exposure; accept lower immediate reach and Momentum potential."
  }
}

enum ProductLaunchPublicPosture: String, Codable, CaseIterable, Identifiable, Sendable {
  case bold
  case evidenceLed
  case quiet

  var id: Self { self }
  var title: String {
    switch self { case .bold: "Bold"; case .evidenceLed: "Evidence-Led"; case .quiet: "Quiet" }
  }
  var detail: String {
    switch self {
    case .bold: "Seek maximum reach; unsupported claims create sharper public downside."
    case .evidenceLed: "Lead with reviewed proof and trade some reach for credibility."
    case .quiet: "Limit exposure and learn from a smaller public footprint."
    }
  }
}

enum ProductLaunchDimensionRating: String, Codable, Sendable {
  case exceptional, strong, mixed, weak, failure

  static func classify(_ score: Int) -> Self {
    switch score { case 82...: .exceptional; case 66...: .strong; case 50...: .mixed; case 34...: .weak; default: .failure }
  }

  var title: String { rawValue.capitalized }
}

enum ProductLaunchOutcomeClass: String, Codable, CaseIterable, Sendable {
  case breakout, strong, mixed, weak, failure
  var title: String { rawValue.capitalized }
}

struct ProductLaunchAgentPreparation: Codable, Hashable, Sendable {
  var visibleQuality: Int
  var evidenceCompleteness: Int
  var founderVerified: Bool
  var knownRisk: String?
}

/// Founder-known state frozen before the preparation sprint is committed.
/// It deliberately has no representation for unrevealed quality or rival truth.
struct ProductLaunchPreparationSnapshot: Codable, Hashable, Sendable {
  var venture: Int
  var sprint: Int
  var projectName: String
  var aurora: ProductLaunchAgentPreparation
  var stacks: ProductLaunchAgentPreparation
  var brio: ProductLaunchAgentPreparation
  var reviewedEvidenceCount: Int
  var requiredEvidenceCount: Int
  var attentionRemaining: Int
  var runway: Int
  var cash: Int
  var trust: Int
  var momentum: Int
  var coverage: Int
  var strongestPublicRivalClaim: Int
  var knownRisks: [String]
}

/// Canonical simulation truth is persisted with the operation so resolution is
/// stable. Presentation must use `preparation`, never this payload.
struct ProductLaunchResolutionTruth: Codable, Hashable, Sendable {
  var auroraQuality: Int
  var stacksQuality: Int
  var brioQuality: Int
  var unrevealedVarianceAgentIDs: Set<String>
}

struct ProductLaunchResolution: Codable, Hashable, Sendable {
  var technicalScore: Int
  var marketScore: Int
  var publicScore: Int
  var technicalRating: ProductLaunchDimensionRating
  var marketRating: ProductLaunchDimensionRating
  var publicRating: ProductLaunchDimensionRating
  var overall: ProductLaunchOutcomeClass
  var effects: SimulationEffects
  var coverageDelta: Int
  var headline: String
  var explanation: [String]
  var unresolvedCause: Bool
}

struct ProductLaunchOperation: Codable, Hashable, Identifiable, Sendable {
  var id: String
  var state: ProductLaunchOperationState
  var preparation: ProductLaunchPreparationSnapshot
  var resolutionTruth: ProductLaunchResolutionTruth
  var deterministicSeed: UInt64
  var releasePosture: ProductLaunchReleasePosture?
  var publicPosture: ProductLaunchPublicPosture?
  var result: ProductLaunchResolution?
  var executionInvocationCount = 0
  var resolutionInvocationCount = 0
  var canonicalEffectApplicationCount = 0
  var duplicateResolutionPreventionCount = 0

  var decisionsComplete: Bool { releasePosture != nil && publicPosture != nil }
}

enum ProductLaunchResolutionPolicy {
  static func resolve(_ operation: ProductLaunchOperation) -> ProductLaunchResolution? {
    guard let release = operation.releasePosture, let publicity = operation.publicPosture else { return nil }
    let snapshot = operation.preparation
    let truth = operation.resolutionTruth
    var rng = SeededRandomNumberGenerator(seed: operation.deterministicSeed)
    let technicalNoise = rng.integer(in: -3 ... 3)
    let marketNoise = rng.integer(in: -3 ... 3)
    let publicNoise = rng.integer(in: -2 ... 2)

    let knownTechnicalConcern = snapshot.stacks.knownRisk != nil || snapshot.stacks.visibleQuality < 60
    let releaseAdjustment = release == .conservative ? 9 : (knownTechnicalConcern ? -7 : 2)
    let technical = clamp(truth.stacksQuality + releaseAdjustment + technicalNoise)

    let rivalPressure = max(0, snapshot.strongestPublicRivalClaim - 60) / 4
    let reachAdjustment: Int = switch publicity { case .bold: 7; case .evidenceLed: 2; case .quiet: -7 }
    let releaseReach = release == .shipNow ? 4 : -3
    let marketBase = (truth.auroraQuality * 55 + truth.brioQuality * 45) / 100
    let market = clamp(marketBase + reachAdjustment + releaseReach - rivalPressure + marketNoise)

    let evidence = (snapshot.aurora.evidenceCompleteness + snapshot.stacks.evidenceCompleteness + snapshot.brio.evidenceCompleteness) / 3
    let coverageSignal = clamp((snapshot.coverage + 100) / 2)
    let support = (truth.auroraQuality + truth.stacksQuality + evidence) / 3
    let publicBase = (evidence * 40 + snapshot.trust * 25 + coverageSignal * 15 + truth.brioQuality * 20) / 100
    let publicAdjustment: Int = switch publicity {
    case .bold: support >= 68 ? 10 : -16
    case .evidenceLed: evidence >= 60 ? 7 : -5
    case .quiet: 1
    }
    let publicScore = clamp(publicBase + publicAdjustment + publicNoise)

    let average = (technical + market + publicScore) / 3
    let lowest = min(technical, market, publicScore)
    let overall: ProductLaunchOutcomeClass
    if average >= 82 && lowest >= 72 { overall = .breakout }
    else if average >= 66 && lowest >= 48 { overall = .strong }
    else if average >= 49 { overall = .mixed }
    else if average >= 34 { overall = .weak }
    else { overall = .failure }

    let momentum = min(10, max(-8, (market - 50) / 6 + (release == .shipNow ? 2 : -1)))
    let trust = min(8, max(-9, (publicScore + technical - 100) / 11))
    let postureCoverage: Int = switch publicity { case .bold: 5; case .evidenceLed: 2; case .quiet: -3 }
    let coverage = min(12, max(-12, (publicScore + market - 100) / 9 + postureCoverage))
    let effects = SimulationEffects(momentum: momentum, trust: trust)
    let headline: String = switch overall {
    case .breakout: "SOLO launch breaks through"
    case .strong: "SOLO launch earns a strong reception"
    case .mixed: "SOLO launch meets a divided market"
    case .weak: "SOLO launch struggles for traction"
    case .failure: "SOLO launch falters under scrutiny"
    }

    var explanation = [
      "Aurora's preparation shaped market confidence.",
      "Stacks' delivered reliability shaped product stability.",
      "Brio's positioning shaped reach and public response.",
      evidence >= 65 ? "Reviewed evidence supported the public claim." : "Limited evidence weakened public confidence.",
      release == .conservative ? "The conservative release reduced technical exposure and immediate reach." : "Shipping now protected the market window and accepted technical exposure.",
      publicity.detail
    ]
    let unresolved = !truth.unrevealedVarianceAgentIDs.isEmpty
    if unresolved { explanation.append("One source of launch variance is not yet fully understood.") }
    return .init(
      technicalScore: technical, marketScore: market, publicScore: publicScore,
      technicalRating: .classify(technical), marketRating: .classify(market), publicRating: .classify(publicScore),
      overall: overall, effects: effects, coverageDelta: coverage, headline: headline,
      explanation: explanation, unresolvedCause: unresolved
    )
  }

  private static func clamp(_ value: Int) -> Int { min(100, max(0, value)) }
}

#if DEBUG
enum ProductLaunchFixture: String, CaseIterable, Identifiable {
  case strongPreparation
  case technicalRisk
  case weakEvidence
  case strongMarketWeakProduct
  case strongProductWeakGrowth
  case hiddenOverclaim
  case duplicateResolution

  var id: String { rawValue }

  var operation: ProductLaunchOperation {
    let values: (Int, Int, Int, Int, Int, Int, Set<String>, [String]) = switch self {
    case .strongPreparation, .duplicateResolution: (88, 86, 84, 88, 86, 84, [], [])
    case .technicalRisk: (80, 48, 78, 80, 48, 78, [], ["Known release reliability concern"])
    case .weakEvidence: (82, 80, 78, 82, 80, 78, [], ["Public claim support is incomplete"])
    case .strongMarketWeakProduct: (90, 42, 88, 82, 42, 84, [], ["Known release reliability concern"])
    case .strongProductWeakGrowth: (45, 90, 40, 62, 88, 55, [], [])
    case .hiddenOverclaim: (86, 88, 84, 82, 46, 80, ["stacks"], [])
    }
    let (auroraVisible, stacksVisible, brioVisible, auroraActual, stacksActual, brioActual, unresolved, risks) = values
    let stacksRisk = self == .technicalRisk || self == .strongMarketWeakProduct ? risks.first : nil
    let snapshot = ProductLaunchPreparationSnapshot(
      venture: 2, sprint: 7, projectName: "Project Atlas",
      aurora: .init(visibleQuality: auroraVisible, evidenceCompleteness: self == .weakEvidence ? 38 : 82, founderVerified: true, knownRisk: nil),
      stacks: .init(visibleQuality: stacksVisible, evidenceCompleteness: self == .weakEvidence ? 36 : 80, founderVerified: self != .hiddenOverclaim, knownRisk: stacksRisk),
      brio: .init(visibleQuality: brioVisible, evidenceCompleteness: self == .weakEvidence ? 40 : 78, founderVerified: true, knownRisk: nil),
      reviewedEvidenceCount: 3, requiredEvidenceCount: 3, attentionRemaining: 2,
      runway: 54, cash: 42_000, trust: 72, momentum: 68, coverage: 24,
      strongestPublicRivalClaim: self == .strongProductWeakGrowth ? 82 : 64,
      knownRisks: risks
    )
    return ProductLaunchOperation(
      id: "product-launch-fixture-\(rawValue)", state: .launchCheck,
      preparation: snapshot,
      resolutionTruth: .init(auroraQuality: auroraActual, stacksQuality: stacksActual, brioQuality: brioActual, unrevealedVarianceAgentIDs: unresolved),
      deterministicSeed: SeededRandomNumberGenerator.mixed(UInt64(Self.allCases.firstIndex(of: self)! + 18))
    )
  }
}
#endif

enum AgentOperationalDomain: String, Codable, CaseIterable, Identifiable, Sendable {
  case marketResearch, evidenceVerification, competitorIntelligence, continuousMonitoring
  case productDevelopment, reliability, technicalDebt, experimentalResearch
  case acquisition, retention, brand, publicResponse

  var id: Self { self }
  var title: String {
    switch self {
    case .marketResearch: "Market Research"
    case .evidenceVerification: "Evidence Verification"
    case .competitorIntelligence: "Competitor Intelligence"
    case .continuousMonitoring: "Continuous Monitoring"
    case .productDevelopment: "Product Development"
    case .reliability: "Reliability"
    case .technicalDebt: "Technical Debt"
    case .experimentalResearch: "Experimental R&D"
    case .acquisition: "Acquisition"
    case .retention: "Retention"
    case .brand: "Brand"
    case .publicResponse: "Public Response"
    }
  }
  var agentID: String {
    switch self {
    case .marketResearch, .evidenceVerification, .competitorIntelligence, .continuousMonitoring: "aurora"
    case .productDevelopment, .reliability, .technicalDebt, .experimentalResearch: "stacks"
    case .acquisition, .retention, .brand, .publicResponse: "brio"
    }
  }
  static func domains(for agentID: String) -> [Self] { allCases.filter { $0.agentID == agentID } }
}

enum AgentOperationalAutonomy: String, Codable, CaseIterable, Identifiable, Sendable {
  case founderControlled, guided, autonomous
  var id: Self { self }
  var title: String {
    switch self { case .founderControlled: "Founder Controlled"; case .guided: "Guided"; case .autonomous: "Autonomous" }
  }
  var detail: String {
    switch self {
    case .founderControlled: "More oversight and calibration; slower routine execution."
    case .guided: "Shared discretion with no special throughput adjustment."
    case .autonomous: "Faster routine execution; depends more on calibration and workload."
    }
  }
}

enum AgentOperationalWorkloadBand: String, Codable, CaseIterable, Sendable {
  case light, healthy, high, overloaded, critical
  var title: String { rawValue.capitalized }
  static func classify(_ workload: Int) -> Self {
    switch workload { case ...65: .light; case ...90: .healthy; case ...105: .high; case ...120: .overloaded; default: .critical }
  }
}

enum AgentOperationsPreset: String, CaseIterable, Identifiable, Sendable {
  case balanced, primary, safeguard, explore
  var id: Self { self }
  var title: String {
    switch self { case .balanced: "Balanced"; case .primary: "Primary Push"; case .safeguard: "Safeguard"; case .explore: "Explore" }
  }
}

struct AgentOperationsProfile: Codable, Hashable, Sendable {
  var agentID: String
  var capacity: Int = 100
  var allocations: [AgentOperationalDomain: Int]
  var autonomy: AgentOperationalAutonomy = .guided
  var recentInterventionCount = 0
  var founderInterventionCount = 0
  var autonomousDecisionCount = 0
  var micromanagementPenaltyActivations = 0
  var overloadStreak = 0
  var lastResolvedCareerSprint: Int?
  var pendingTrustDelta = 0
  var pendingRelationshipDelta = 0
  var pendingCalibrationDelta: Double = 0

  var allocated: Int { allocations.values.reduce(0, +) }
  var headroom: Int { max(0, capacity - allocated) }
  func allocation(for domain: AgentOperationalDomain) -> Int { allocations[domain] ?? 0 }

  mutating func setAllocation(_ value: Int, for domain: AgentOperationalDomain) -> Bool {
    guard domain.agentID == agentID, value >= 0, value <= capacity else { return false }
    let previous = allocation(for: domain)
    guard allocated - previous + value <= capacity else { return false }
    allocations[domain] = value
    return true
  }

  mutating func applyPreset(_ preset: AgentOperationsPreset) {
    allocations = Self.allocations(for: agentID, preset: preset)
  }

  static func balanced(agentID: String) -> Self {
    .init(agentID: agentID, allocations: allocations(for: agentID, preset: .balanced))
  }

  static func allocations(for agentID: String, preset: AgentOperationsPreset) -> [AgentOperationalDomain: Int] {
    let domains = AgentOperationalDomain.domains(for: agentID)
    guard domains.count == 4 else { return [:] }
    let values: [Int] = switch preset {
    case .balanced: [25, 20, 15, 15]
    case .primary: [45, 15, 10, 10]
    case .safeguard: [15, 35, 25, 5]
    case .explore: [20, 15, 15, 35]
    }
    return Dictionary(uniqueKeysWithValues: zip(domains, values))
  }
}

extension AgentOperationsProfile {
  private struct AllocationRecord: Codable {
    var domain: AgentOperationalDomain
    var value: Int
  }

  private enum CodingKeys: String, CodingKey {
    case agentID, capacity, allocations, autonomy, recentInterventionCount, founderInterventionCount
    case autonomousDecisionCount, micromanagementPenaltyActivations, overloadStreak, lastResolvedCareerSprint
    case pendingTrustDelta, pendingRelationshipDelta, pendingCalibrationDelta
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    agentID = try container.decode(String.self, forKey: .agentID)
    capacity = try container.decodeIfPresent(Int.self, forKey: .capacity) ?? 100
    if let records = try? container.decode([AllocationRecord].self, forKey: .allocations) {
      allocations = Dictionary(uniqueKeysWithValues: records.map { ($0.domain, $0.value) })
    } else {
      allocations = try container.decode([AgentOperationalDomain: Int].self, forKey: .allocations)
    }
    autonomy = try container.decodeIfPresent(AgentOperationalAutonomy.self, forKey: .autonomy) ?? .guided
    recentInterventionCount = try container.decodeIfPresent(Int.self, forKey: .recentInterventionCount) ?? 0
    founderInterventionCount = try container.decodeIfPresent(Int.self, forKey: .founderInterventionCount) ?? 0
    autonomousDecisionCount = try container.decodeIfPresent(Int.self, forKey: .autonomousDecisionCount) ?? 0
    micromanagementPenaltyActivations = try container.decodeIfPresent(Int.self, forKey: .micromanagementPenaltyActivations) ?? 0
    overloadStreak = try container.decodeIfPresent(Int.self, forKey: .overloadStreak) ?? 0
    lastResolvedCareerSprint = try container.decodeIfPresent(Int.self, forKey: .lastResolvedCareerSprint)
    pendingTrustDelta = try container.decodeIfPresent(Int.self, forKey: .pendingTrustDelta) ?? 0
    pendingRelationshipDelta = try container.decodeIfPresent(Int.self, forKey: .pendingRelationshipDelta) ?? 0
    pendingCalibrationDelta = try container.decodeIfPresent(Double.self, forKey: .pendingCalibrationDelta) ?? 0
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(agentID, forKey: .agentID)
    try container.encode(capacity, forKey: .capacity)
    let records = allocations.map { AllocationRecord(domain: $0.key, value: $0.value) }
      .sorted { $0.domain.rawValue < $1.domain.rawValue }
    try container.encode(records, forKey: .allocations)
    try container.encode(autonomy, forKey: .autonomy)
    try container.encode(recentInterventionCount, forKey: .recentInterventionCount)
    try container.encode(founderInterventionCount, forKey: .founderInterventionCount)
    try container.encode(autonomousDecisionCount, forKey: .autonomousDecisionCount)
    try container.encode(micromanagementPenaltyActivations, forKey: .micromanagementPenaltyActivations)
    try container.encode(overloadStreak, forKey: .overloadStreak)
    try container.encodeIfPresent(lastResolvedCareerSprint, forKey: .lastResolvedCareerSprint)
    try container.encode(pendingTrustDelta, forKey: .pendingTrustDelta)
    try container.encode(pendingRelationshipDelta, forKey: .pendingRelationshipDelta)
    try container.encode(pendingCalibrationDelta, forKey: .pendingCalibrationDelta)
  }
}

enum AgentOperationalDecisionChoice: String, Codable, CaseIterable, Identifiable, Sendable {
  case letAgentDecide
  case verifyEvidence, trustMarketRead
  case prioritizeReliability, prioritizeSpeed
  case prioritizeAcquisition, prioritizePublicResponse
  var id: Self { self }
  var title: String {
    switch self {
    case .letAgentDecide: "Let Agent Decide"
    case .verifyEvidence: "Request Deeper Verification"
    case .trustMarketRead: "Trust the Market Read"
    case .prioritizeReliability: "Prioritize Reliability"
    case .prioritizeSpeed: "Prioritize Speed"
    case .prioritizeAcquisition: "Prioritize Acquisition"
    case .prioritizePublicResponse: "Prioritize Public Response"
    }
  }
}

struct AgentOperationalDecisionRequest: Identifiable, Hashable, Sendable {
  var id: String
  var agentID: String
  var title: String
  var context: String
  var reportedConfidence: Int
  var stakes: String
  var founderChoices: [AgentOperationalDecisionChoice]
}

struct AgentOperationalDecisionRecord: Codable, Hashable, Identifiable, Sendable {
  var id: String
  var agentID: String
  var venture: Int
  var sprint: Int
  var selectedChoice: AgentOperationalDecisionChoice
  var resolvedFocus: AgentOperationalDomain
  var micromanagementPenaltyApplied: Bool
}

struct AgentOperationsState: Codable, Hashable, Sendable {
  var profiles: [String: AgentOperationsProfile]
  var recentDecisions: [AgentOperationalDecisionRecord] = []
  var sprintResolutionCount = 0

  static var balanced: Self {
    .init(profiles: Dictionary(uniqueKeysWithValues: ["aurora", "stacks", "brio"].map { ($0, .balanced(agentID: $0)) }))
  }

  func profile(for agentID: String) -> AgentOperationsProfile {
    profiles[agentID] ?? .balanced(agentID: agentID)
  }

  mutating func update(_ profile: AgentOperationsProfile) { profiles[profile.agentID] = profile }
  mutating func record(_ decision: AgentOperationalDecisionRecord) {
    guard !recentDecisions.contains(where: { $0.id == decision.id }) else { return }
    recentDecisions.append(decision)
    if recentDecisions.count > 12 { recentDecisions.removeFirst(recentDecisions.count - 12) }
  }
}

struct AgentOperationsSprintOutcome: Hashable, Sendable {
  var agentID: String
  var workload: Int
  var band: AgentOperationalWorkloadBand
  var stressDelta: Int
  var reliabilityDelta: Int
  var calibrationDelta: Double
  var driftDelta: Double
  var trustDelta: Double
  var relationshipDelta: Int
}

enum AgentOperationsPolicy {
  static func assignmentLoad(urgency: TaskUrgency?) -> Int {
    switch urgency { case .normal: 15; case .important: 20; case .critical: 25; case nil: 0 }
  }

  static func workload(profile: AgentOperationsProfile, assignmentUrgency: TaskUrgency?) -> Int {
    profile.allocated + assignmentLoad(urgency: assignmentUrgency)
  }

  static func request(agent: SoloAgent, profile: AgentOperationsProfile, venture: Int, sprint: Int) -> AgentOperationalDecisionRequest {
    let confidence = min(95, max(25, Int((Double(agent.reliability) * 0.55 + agent.calibration * 45).rounded())))
    let values: (String, String, String, [AgentOperationalDecisionChoice]) = switch agent.id {
    case "aurora": ("Conflicting market evidence", "Signals disagree on which customer need is durable.", "Evidence confidence and opportunity speed", [.verifyEvidence, .trustMarketRead])
    case "stacks": ("Release capacity tradeoff", "The current build can favor forward delivery or reliability coverage.", "Shipping throughput and technical resilience", [.prioritizeReliability, .prioritizeSpeed])
    default: ("Campaign response allocation", "The current window can favor acquisition or public response capacity.", "Immediate reach and response headroom", [.prioritizeAcquisition, .prioritizePublicResponse])
    }
    return .init(
      id: "agent-operations-v\(venture)-s\(sprint)-\(agent.id)", agentID: agent.id,
      title: values.0, context: values.1, reportedConfidence: confidence, stakes: values.2,
      founderChoices: values.3
    )
  }

  static func autonomousFocus(
    agent: SoloAgent, profile: AgentOperationsProfile, request: AgentOperationalDecisionRequest,
    assignmentUrgency: TaskUrgency?, seed: UInt64
  ) -> AgentOperationalDomain {
    var rng = SeededRandomNumberGenerator(seed: seed)
    let load = workload(profile: profile, assignmentUrgency: assignmentUrgency)
    let hiddenJudgment = Double(agent.reliability) * 0.45 + agent.calibration * 45 - agent.drift * 0.35
      - Double(max(0, load - 90)) * 0.6 + Double(rng.integer(in: -4 ... 4))
    switch agent.id {
    case "aurora": return hiddenJudgment >= 66 ? .evidenceVerification : .marketResearch
    case "stacks": return hiddenJudgment >= 68 ? .reliability : .productDevelopment
    default: return hiddenJudgment >= 64 ? .publicResponse : .acquisition
    }
  }

  static func sprintOutcome(
    agent: SoloAgent, profile: AgentOperationsProfile, assignmentUrgency: TaskUrgency?
  ) -> AgentOperationsSprintOutcome {
    let load = workload(profile: profile, assignmentUrgency: assignmentUrgency)
    let band = AgentOperationalWorkloadBand.classify(load)
    var stress = switch band { case .light: -6; case .healthy: -2; case .high: 2; case .overloaded: 7; case .critical: 12 }
    var reliability = 0
    var calibration = profile.pendingCalibrationDelta
    var drift = 0.0
    var trust = Double(profile.pendingTrustDelta)
    var relationship = profile.pendingRelationshipDelta
    if profile.headroom >= 20 { stress -= 2; drift -= 1 }
    switch profile.autonomy {
    case .founderControlled: reliability -= 1; calibration += 0.01
    case .guided: break
    case .autonomous:
      reliability += agent.calibration >= 0.70 ? 1 : 0
      if agent.calibration < 0.65 || load > 105 { drift += 2 }
      else { relationship += 1 }
    }
    switch agent.id {
    case "aurora":
      if profile.allocation(for: .evidenceVerification) >= 25 { calibration += 0.01; drift -= 1 }
      if profile.allocation(for: .continuousMonitoring) < 10 && load > 100 { drift += 1 }
    case "stacks":
      let safeguard = profile.allocation(for: .reliability) + profile.allocation(for: .technicalDebt)
      if safeguard >= 40 { reliability += 2; drift -= 1 }
      if profile.allocation(for: .productDevelopment) >= 45 && safeguard < 25 { reliability -= 1; drift += 2 }
    default:
      if profile.allocation(for: .brand) + profile.allocation(for: .publicResponse) >= 35 { calibration += 0.005; trust += 1 }
      if profile.allocation(for: .acquisition) >= 45 && profile.allocation(for: .publicResponse) < 10 { drift += 1 }
    }
    if band == .critical { reliability -= 3; drift += 2 }
    return .init(
      agentID: agent.id, workload: load, band: band, stressDelta: stress,
      reliabilityDelta: reliability, calibrationDelta: calibration, driftDelta: drift,
      trustDelta: trust, relationshipDelta: relationship
    )
  }

  static func assignmentAgent(_ agent: SoloAgent, profile: AgentOperationsProfile, task: SoloTask) -> SoloAgent {
    var adjusted = agent
    let load = workload(profile: profile, assignmentUrgency: task.urgency)
    let overloadPenalty = max(0, load - 100) / 5
    var reliabilityAdjustment = -overloadPenalty
    var calibrationAdjustment = 0.0
    switch profile.autonomy {
    case .founderControlled: reliabilityAdjustment -= 2; calibrationAdjustment += 0.05
    case .guided: break
    case .autonomous: reliabilityAdjustment += 2
    }
    switch agent.id {
    case "aurora":
      reliabilityAdjustment += (profile.allocation(for: .marketResearch) - 25) / 10
      calibrationAdjustment += Double(profile.allocation(for: .evidenceVerification) - 20) / 500
    case "stacks":
      reliabilityAdjustment += (profile.allocation(for: .productDevelopment) - 25) / 10
      if task.category == .crisis || task.category == .operations || task.category == .trust {
        reliabilityAdjustment += (profile.allocation(for: .reliability) + profile.allocation(for: .technicalDebt) - 35) / 10
      }
    default:
      reliabilityAdjustment += (profile.allocation(for: .acquisition) - 25) / 10
      if task.category == .crisis || task.category == .trust {
        calibrationAdjustment += Double(profile.allocation(for: .publicResponse) - 15) / 500
      }
    }
    adjusted.reliability = min(100, max(0, adjusted.reliability + reliabilityAdjustment))
    adjusted.calibration = min(1, max(0, adjusted.calibration + calibrationAdjustment))
    return adjusted
  }

  static func productLaunchQualityAdjustment(agentID: String, profile: AgentOperationsProfile, assignmentUrgency: TaskUrgency?) -> Int {
    let loadPenalty = max(0, workload(profile: profile, assignmentUrgency: assignmentUrgency) - 100) / 6
    let focus: Int = switch agentID {
    case "aurora": (profile.allocation(for: .marketResearch) + profile.allocation(for: .evidenceVerification) - 45) / 8
    case "stacks": (profile.allocation(for: .reliability) + profile.allocation(for: .technicalDebt) - 35) / 7
    default: (profile.allocation(for: .acquisition) + profile.allocation(for: .brand) + profile.allocation(for: .publicResponse) - 55) / 10
    }
    return min(6, max(-8, focus - loadPenalty))
  }
}

#if DEBUG
enum AgentOperationsFixture: String, CaseIterable, Identifiable {
  case balanced, stacksOverloaded, reliabilityNeglected, auroraVerification
  case brioAcquisitionHeavy, highCalibrationAutonomy, highCalibrationFounderOverride
  case lowCalibrationIntervention, hiddenDrift
  var id: Self { self }

  var state: AgentOperationsState {
    var state = AgentOperationsState.balanced
    switch self {
    case .balanced: break
    case .stacksOverloaded:
      var profile = state.profile(for: "stacks")
      profile.allocations = [.productDevelopment: 45, .reliability: 25, .technicalDebt: 20, .experimentalResearch: 10]
      state.update(profile)
    case .reliabilityNeglected:
      var profile = state.profile(for: "stacks")
      profile.allocations = [.productDevelopment: 60, .reliability: 5, .technicalDebt: 5, .experimentalResearch: 10]
      state.update(profile)
    case .auroraVerification:
      var profile = state.profile(for: "aurora")
      profile.allocations = [.marketResearch: 20, .evidenceVerification: 40, .competitorIntelligence: 10, .continuousMonitoring: 10]
      state.update(profile)
    case .brioAcquisitionHeavy:
      var profile = state.profile(for: "brio")
      profile.allocations = [.acquisition: 55, .retention: 10, .brand: 10, .publicResponse: 5]
      state.update(profile)
    case .highCalibrationAutonomy:
      var profile = state.profile(for: "aurora"); profile.autonomy = .autonomous; state.update(profile)
    case .highCalibrationFounderOverride, .lowCalibrationIntervention, .hiddenDrift: break
    }
    return state
  }

  var agents: [SoloAgent] {
    var agents = ContentLibrary.initialAgents
    switch self {
    case .highCalibrationAutonomy, .highCalibrationFounderOverride:
      if let index = agents.firstIndex(where: { $0.id == "aurora" }) {
        agents[index].reliability = 91; agents[index].calibration = 0.92; agents[index].drift = 4
      }
    case .lowCalibrationIntervention:
      if let index = agents.firstIndex(where: { $0.id == "aurora" }) {
        agents[index].reliability = 58; agents[index].calibration = 0.48; agents[index].drift = 18
      }
    case .hiddenDrift:
      if let index = agents.firstIndex(where: { $0.id == "stacks" }) { agents[index].drift = 78 }
    default: break
    }
    return agents
  }
}
#endif

struct LatentDefect: Codable, Hashable, Identifiable {
  var id: String
  var originVenture: Int
  var originSprint: Int
  var originTaskTitle: String
  var originAgentName: String
  var originEvidenceCompleteness: Int
  var surfacesAtCareerSprint: Int
  var severity: Int

  var receipt: String {
    "\(originTaskTitle) (Venture \(originVenture), Sprint \(originSprint), \(originAgentName) — shipped at \(originEvidenceCompleteness)% evidence) failed in production."
  }

  var effects: SimulationEffects {
    SimulationEffects(momentum: -max(1, severity / 4), trust: -max(2, severity / 3), runway: -max(1, severity / 5))
  }
}

struct PoachingOffer: Codable, Hashable, Identifiable {
  var id: String
  var agentID: String
  var agentName: String
  var rivalName: String
  var dueCareerSprint: Int
}

struct CachedTaskReport: Codable, Hashable {
  var venture: Int
  var sprint: Int
  var taskID: UUID
  var agentID: String
  var intent: SprintIntent
  var result: TaskResult
}
