import Foundation

enum WorkSessionFamily: String, Codable, Hashable {
  case evidenceTriage
  case systemsReview
}

enum WorkSessionPath: String, Codable, Hashable {
  case manualReview
  case delegate
  case autoReview
}

enum WorkSessionStakes: String, Codable, Hashable {
  case routine
  case important
  case critical
  case companyDefining

  init(urgency: TaskUrgency) {
    switch urgency {
    case .normal: self = .routine
    case .important: self = .important
    case .critical: self = .critical
    }
  }
}

enum EvidenceTopic: String, Codable, CaseIterable, Hashable {
  case retention
  case pricing
  case market
  case product
  case customer
  case competition
  case growth
  case operations
}

enum EvidenceTriageAction: String, Codable, CaseIterable, Identifiable, Hashable {
  case reject
  case verify
  case use

  var id: Self { self }
  var title: String { rawValue.uppercased() }
  var symbol: String {
    switch self {
    case .reject: "xmark"
    case .verify: "checkmark.shield"
    case .use: "checkmark"
    }
  }
}

enum WorkSessionFindingPolarity: String, Codable, Hashable {
  case positive
  case negative
  case neutral
}

enum WorkSessionFinding: String, Codable, CaseIterable, Hashable {
  case acceptedWeakEvidence
  case rejectedStrongEvidence
  case failedToVerifyAmbiguity
  case overVerifiedClearEvidence
  case correctlyDetectedContradiction
  case correctlyFlaggedHighRiskAmbiguity
  case correctlyPreservedStrongEvidence
  case dependencyViolation
  case skippedVerification
  case unsafeRelease
  case correctlyPreservedDependency
  case correctlyRequiredVerification
  case correctlyIdentifiedReleaseGate

  var polarity: WorkSessionFindingPolarity {
    switch self {
    case .acceptedWeakEvidence, .rejectedStrongEvidence, .failedToVerifyAmbiguity, .overVerifiedClearEvidence,
         .dependencyViolation, .skippedVerification, .unsafeRelease:
      .negative
    case .correctlyDetectedContradiction, .correctlyFlaggedHighRiskAmbiguity, .correctlyPreservedStrongEvidence,
         .correctlyPreservedDependency, .correctlyRequiredVerification, .correctlyIdentifiedReleaseGate:
      .positive
    }
  }

  var hindsightExplanation: String {
    switch self {
    case .acceptedWeakEvidence: "A weak source was accepted during Founder Review."
    case .rejectedStrongEvidence: "A strong source was rejected, reducing usable evidence."
    case .failedToVerifyAmbiguity: "An ambiguous claim passed without a verification request."
    case .overVerifiedClearEvidence: "Clear evidence was sent for unnecessary verification."
    case .correctlyDetectedContradiction: "Founder Review correctly isolated a contradictory measurement."
    case .correctlyFlaggedHighRiskAmbiguity: "Founder Review correctly requested verification for a high-risk ambiguity."
    case .correctlyPreservedStrongEvidence: "Founder Review preserved a well-supported source for the operating decision."
    case .dependencyViolation: "A dependent implementation step was scheduled before its prerequisite."
    case .skippedVerification: "Founder Review allowed required verification to occur too late."
    case .unsafeRelease: "Founder Review allowed release before its required safety gate."
    case .correctlyPreservedDependency: "Founder Review preserved a critical technical dependency."
    case .correctlyRequiredVerification: "Founder Review kept required validation ahead of dependent work."
    case .correctlyIdentifiedReleaseGate: "Founder Review held release until required checks were complete."
    }
  }
}

enum WorkSessionCausalAttribution: String, Codable, Hashable {
  case agentOutput
  case founderReview
  case shared
  case delegation
  case potentialPreserved
}

/// UI-safe evidence. It deliberately contains no correctness, scoring weight,
/// hidden quality, drift, or verification truth.
struct EvidenceCardPresentation: Identifiable, Equatable, Hashable {
  var id: String
  var source: String
  var headline: String
  var detail: String
  var provenance: String
  var position: Int
  var total: Int

  var accessibilityLabel: String {
    "Evidence \(position) of \(total). \(source). \(headline). \(detail). Provenance: \(provenance)."
  }
}

struct EvidenceTriageCard: Codable, Identifiable, Hashable {
  var id: String
  var source: String
  var headline: String
  var detail: String
  var provenance: String
  private var idealAction: EvidenceTriageAction
  private var weight: Int
  private var contradiction: Bool
  private var topicTags: Set<EvidenceTopic>?

  init(id: String, source: String, headline: String, detail: String, provenance: String, idealAction: EvidenceTriageAction, weight: Int, contradiction: Bool = false, topicTags: Set<EvidenceTopic> = []) {
    self.id = id
    self.source = source
    self.headline = headline
    self.detail = detail
    self.provenance = provenance
    self.idealAction = idealAction
    self.weight = weight
    self.contradiction = contradiction
    self.topicTags = topicTags
  }

  func presentation(position: Int, total: Int) -> EvidenceCardPresentation {
    EvidenceCardPresentation(id: id, source: source, headline: headline, detail: detail, provenance: provenance, position: position, total: total)
  }

  fileprivate func assessment(for action: EvidenceTriageAction) -> WorkSessionEngine.CardAssessment {
    var findings: [WorkSessionFinding] = []
    if action == idealAction {
      if contradiction && action == .verify {
        findings.append(.correctlyDetectedContradiction)
      } else if action == .verify {
        findings.append(.correctlyFlaggedHighRiskAmbiguity)
      } else if action == .use {
        findings.append(.correctlyPreservedStrongEvidence)
      }
      return .init(points: weight, possible: weight, findings: findings)
    }
    switch (idealAction, action) {
    case (.reject, .use): findings.append(.acceptedWeakEvidence)
    case (.use, .reject): findings.append(.rejectedStrongEvidence)
    case (.verify, _): findings.append(.failedToVerifyAmbiguity)
    case (.use, .verify): findings.append(.overVerifiedClearEvidence)
    default: break
    }
    let partial = action == .verify && idealAction == .reject ? weight / 3 : 0
    return .init(points: partial, possible: weight, findings: findings)
  }

  func supports(_ topic: EvidenceTopic) -> Bool { topicTags?.contains(topic) == true }
}

struct WorkSessionDecision: Codable, Identifiable, Hashable {
  var cardID: String
  var action: EvidenceTriageAction
  var sequence: Int
  var id: String { cardID }
}

struct WorkSessionRecord: Codable, Identifiable, Hashable {
  var id: String
  var assignmentID: UUID
  var agentID: String
  var family: WorkSessionFamily
  var stakes: WorkSessionStakes
  var challengeSeed: UInt64
  var agentPotentialQuality: Int
  var evidenceTopic: EvidenceTopic?
  var technicalTopic: TechnicalTopic?
  var path: WorkSessionPath?
  var cards: [EvidenceTriageCard]
  var decisions: [WorkSessionDecision]
  var systemsChallenge: SystemsReviewChallenge?
  var systemsSequence: [String]
  var founderReviewQuality: Int?
  var deliveredQuality: Int?
  var findings: [WorkSessionFinding]
  var founderAttentionCost: Int
  var founderAttentionCharged: Bool
  var completionApplied: Bool
  var completed: Bool
  var agentStressAtCreation: AgentStressBand

  var nextCardPresentation: EvidenceCardPresentation? {
    guard decisions.count < cards.count else { return nil }
    return cards[decisions.count].presentation(position: decisions.count + 1, total: cards.count)
  }

  var usedCount: Int { decisions.filter { $0.action == .use }.count }
  var verifiedCount: Int { decisions.filter { $0.action == .verify }.count }
  var rejectedCount: Int { decisions.filter { $0.action == .reject }.count }
  var systemsAssessment: SystemsReviewAssessment? {
    guard let systemsChallenge else { return nil }
    return SystemsReviewEvaluator.evaluate(challenge: systemsChallenge, sequence: systemsSequence)
  }

  var founderReviewLabel: String {
    guard let quality = founderReviewQuality else { return path == .delegate ? "Delegated" : "Pending" }
    return switch quality {
    case 95...: "Exceptional"
    case 85...: "Strong"
    case 75...: "Measured"
    case 60...: "Limited"
    default: "Fragile"
    }
  }

  var hindsightExplanations: [String] {
    var explanations = Array(Set(findings.map(\.hindsightExplanation))).sorted()
    let agentName = agentID == "stacks" ? "Stacks" : agentID == "aurora" ? "Aurora" : "The agent"
    explanations.insert(causalAttribution.hindsightExplanation(agentName: agentName), at: 0)
    return explanations
  }

  var negativeFindings: [WorkSessionFinding] { findings.filter { $0.polarity == .negative } }
  var positiveFindings: [WorkSessionFinding] { findings.filter { $0.polarity == .positive } }

  var causalAttribution: WorkSessionCausalAttribution {
    guard let deliveredQuality else { return .potentialPreserved }
    if deliveredQuality >= agentPotentialQuality - 2 {
      return agentPotentialQuality < 68 ? .agentOutput : .potentialPreserved
    }
    if path == .delegate { return .delegation }
    let weakAgentOutput = agentPotentialQuality < 68
    let weakFounderReview = (founderReviewQuality ?? 100) < 75
    if weakAgentOutput && weakFounderReview { return .shared }
    if weakFounderReview { return .founderReview }
    return .agentOutput
  }
}

extension WorkSessionRecord {
  private enum CodingKeys: String, CodingKey {
    case id, assignmentID, agentID, family, stakes, challengeSeed, agentPotentialQuality, evidenceTopic, technicalTopic
    case path, cards, decisions, systemsChallenge, systemsSequence, founderReviewQuality, deliveredQuality, findings, mistakes
    case founderAttentionCost, founderAttentionCharged, completionApplied, completed, agentStressAtCreation
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    assignmentID = try values.decode(UUID.self, forKey: .assignmentID)
    id = try values.decodeIfPresent(String.self, forKey: .id)
      ?? "evidence-triage-\(assignmentID.uuidString.lowercased())"
    agentID = try values.decodeIfPresent(String.self, forKey: .agentID) ?? "aurora"
    family = try values.decodeIfPresent(WorkSessionFamily.self, forKey: .family) ?? .evidenceTriage
    stakes = try values.decodeIfPresent(WorkSessionStakes.self, forKey: .stakes) ?? .routine
    challengeSeed = try values.decodeIfPresent(UInt64.self, forKey: .challengeSeed) ?? 0
    agentPotentialQuality = min(100, max(0, try values.decodeIfPresent(Int.self, forKey: .agentPotentialQuality) ?? 0))
    evidenceTopic = try values.decodeIfPresent(EvidenceTopic.self, forKey: .evidenceTopic)
    technicalTopic = try values.decodeIfPresent(TechnicalTopic.self, forKey: .technicalTopic)
    path = try values.decodeIfPresent(WorkSessionPath.self, forKey: .path)
    cards = try values.decodeIfPresent([EvidenceTriageCard].self, forKey: .cards) ?? []
    decisions = try values.decodeIfPresent([WorkSessionDecision].self, forKey: .decisions) ?? []
    systemsChallenge = try values.decodeIfPresent(SystemsReviewChallenge.self, forKey: .systemsChallenge)
    systemsSequence = try values.decodeIfPresent([String].self, forKey: .systemsSequence) ?? []
    founderReviewQuality = try values.decodeIfPresent(Int.self, forKey: .founderReviewQuality)
    deliveredQuality = try values.decodeIfPresent(Int.self, forKey: .deliveredQuality)
    findings = try values.decodeIfPresent([WorkSessionFinding].self, forKey: .findings)
      ?? values.decodeIfPresent([WorkSessionFinding].self, forKey: .mistakes)
      ?? []
    founderAttentionCost = max(0, try values.decodeIfPresent(Int.self, forKey: .founderAttentionCost) ?? 0)
    founderAttentionCharged = try values.decodeIfPresent(Bool.self, forKey: .founderAttentionCharged) ?? false
    completionApplied = try values.decodeIfPresent(Bool.self, forKey: .completionApplied) ?? false
    completed = try values.decodeIfPresent(Bool.self, forKey: .completed) ?? false
    agentStressAtCreation = try values.decodeIfPresent(AgentStressBand.self, forKey: .agentStressAtCreation) ?? .focused
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(assignmentID, forKey: .assignmentID)
    try values.encode(agentID, forKey: .agentID)
    try values.encode(family, forKey: .family)
    try values.encode(stakes, forKey: .stakes)
    try values.encode(challengeSeed, forKey: .challengeSeed)
    try values.encode(agentPotentialQuality, forKey: .agentPotentialQuality)
    try values.encodeIfPresent(evidenceTopic, forKey: .evidenceTopic)
    try values.encodeIfPresent(technicalTopic, forKey: .technicalTopic)
    try values.encodeIfPresent(path, forKey: .path)
    try values.encode(cards, forKey: .cards)
    try values.encode(decisions, forKey: .decisions)
    try values.encodeIfPresent(systemsChallenge, forKey: .systemsChallenge)
    try values.encode(systemsSequence, forKey: .systemsSequence)
    try values.encodeIfPresent(founderReviewQuality, forKey: .founderReviewQuality)
    try values.encodeIfPresent(deliveredQuality, forKey: .deliveredQuality)
    try values.encode(findings, forKey: .findings)
    try values.encode(founderAttentionCost, forKey: .founderAttentionCost)
    try values.encode(founderAttentionCharged, forKey: .founderAttentionCharged)
    try values.encode(completionApplied, forKey: .completionApplied)
    try values.encode(completed, forKey: .completed)
    try values.encode(agentStressAtCreation, forKey: .agentStressAtCreation)
  }
}

private extension WorkSessionCausalAttribution {
  func hindsightExplanation(agentName: String) -> String {
    switch self {
    case .agentOutput: "\(agentName)'s underlying output limited the available organizational result."
    case .founderReview: "\(agentName)'s underlying work was stronger than the result preserved by Founder Review."
    case .shared: "Both \(agentName)'s underlying output and Founder Review constrained the delivered result."
    case .delegation: "Delegation preserved Founder Attention but left some of \(agentName)'s potential unextracted."
    case .potentialPreserved: "Founder management preserved \(agentName)'s available work quality."
    }
  }
}

enum WorkSessionEngine {
  struct CardAssessment {
    var points: Int
    var possible: Int
    var findings: [WorkSessionFinding]
  }

  static func isEligible(task: SoloTask, agentID: String) -> Bool {
    family(for: task, agentID: agentID) != nil
  }

  static func family(for task: SoloTask, agentID: String) -> WorkSessionFamily? {
    guard task.result != nil, !task.isReviewed else { return nil }
    if agentID == "aurora",
       task.role == .research || task.category == .research || task.category == .trust {
      return .evidenceTriage
    }
    if agentID == "stacks", task.role == .engineering, task.urgency != .critical {
      return .systemsReview
    }
    return nil
  }

  static func makeRecord(
    assignmentID: UUID,
    agentID: String,
    urgency: TaskUrgency,
    potentialQuality: Int,
    careerSeed: UInt64,
    venture: Int,
    sprint: Int,
    stress: AgentStressBand,
    attentionCost: Int,
    evidenceTopic: EvidenceTopic? = nil
  ) -> WorkSessionRecord {
    let seed = stableSeed(
      careerSeed: careerSeed,
      assignmentID: assignmentID,
      agentID: agentID,
      venture: venture,
      sprint: sprint,
      evidenceTopic: evidenceTopic
    )
    let count = stress == .overloaded || stress == .critical ? 7 : 6
    let cards = deterministicCards(seed: seed, count: count, topic: evidenceTopic)
    return WorkSessionRecord(
      id: "evidence-triage-\(assignmentID.uuidString.lowercased())",
      assignmentID: assignmentID,
      agentID: agentID,
      family: .evidenceTriage,
      stakes: WorkSessionStakes(urgency: urgency),
      challengeSeed: seed,
      agentPotentialQuality: min(100, max(0, potentialQuality)),
      evidenceTopic: evidenceTopic,
      technicalTopic: nil,
      path: nil,
      cards: cards,
      decisions: [],
      systemsChallenge: nil,
      systemsSequence: [],
      founderReviewQuality: nil,
      deliveredQuality: nil,
      findings: [],
      founderAttentionCost: max(0, attentionCost),
      founderAttentionCharged: false,
      completionApplied: false,
      completed: false,
      agentStressAtCreation: stress
    )
  }

  static func makeSystemsReviewRecord(
    assignmentID: UUID,
    agentID: String,
    urgency: TaskUrgency,
    potentialQuality: Int,
    careerSeed: UInt64,
    venture: Int,
    sprint: Int,
    stress: AgentStressBand,
    attentionCost: Int,
    technicalTopic: TechnicalTopic?
  ) -> WorkSessionRecord {
    let stakes = WorkSessionStakes(urgency: urgency)
    let seed = stableSeed(
      careerSeed: careerSeed,
      assignmentID: assignmentID,
      agentID: agentID,
      venture: venture,
      sprint: sprint,
      family: .systemsReview,
      topicIdentity: technicalTopic?.rawValue
    )
    return WorkSessionRecord(
      id: "systems-review-\(assignmentID.uuidString.lowercased())",
      assignmentID: assignmentID,
      agentID: agentID,
      family: .systemsReview,
      stakes: stakes,
      challengeSeed: seed,
      agentPotentialQuality: min(100, max(0, potentialQuality)),
      evidenceTopic: nil,
      technicalTopic: technicalTopic,
      path: nil,
      cards: [],
      decisions: [],
      systemsChallenge: SystemsReviewChallengeFactory.make(seed: seed, topic: technicalTopic, stakes: stakes),
      systemsSequence: [],
      founderReviewQuality: nil,
      deliveredQuality: nil,
      findings: [],
      founderAttentionCost: max(0, attentionCost),
      founderAttentionCharged: false,
      completionApplied: false,
      completed: false,
      agentStressAtCreation: stress
    )
  }

  static func record(_ action: EvidenceTriageAction, in record: inout WorkSessionRecord) -> Bool {
    guard record.path == .manualReview, !record.completed, record.decisions.count < record.cards.count else { return false }
    let card = record.cards[record.decisions.count]
    guard !record.decisions.contains(where: { $0.cardID == card.id }) else { return false }
    record.decisions.append(.init(cardID: card.id, action: action, sequence: record.decisions.count))
    return true
  }

  static func completeManual(_ record: inout WorkSessionRecord) -> Bool {
    if record.family == .systemsReview { return completeSystemsReview(&record) }
    guard record.path == .manualReview, !record.completed, record.decisions.count == record.cards.count else { return false }
    var earned = 0
    var possible = 0
    var findings: [WorkSessionFinding] = []
    for (card, decision) in zip(record.cards, record.decisions) {
      let assessment = card.assessment(for: decision.action)
      earned += assessment.points
      possible += assessment.possible
      findings.append(contentsOf: assessment.findings)
    }
    let raw = possible == 0 ? 0 : Int((Double(earned) / Double(possible) * 100).rounded())
    record.founderReviewQuality = min(100, max(0, raw))
    record.findings = findings
    record.deliveredQuality = deliveredQuality(potential: record.agentPotentialQuality, reviewQuality: raw, path: .manualReview, seed: record.challengeSeed)
    record.completed = true
    return true
  }

  static func selectSystemStep(_ stepID: String, in record: inout WorkSessionRecord) -> Bool {
    guard record.family == .systemsReview,
          record.path == .manualReview,
          !record.completed,
          let challenge = record.systemsChallenge,
          challenge.steps.contains(where: { $0.id == stepID }),
          !record.systemsSequence.contains(stepID) else { return false }
    record.systemsSequence.append(stepID)
    return true
  }

  static func removeSystemStep(_ stepID: String, in record: inout WorkSessionRecord) -> Bool {
    guard record.family == .systemsReview,
          record.path == .manualReview,
          !record.completed,
          let index = record.systemsSequence.firstIndex(of: stepID) else { return false }
    record.systemsSequence.remove(at: index)
    return true
  }

  static func resetSystemsSequence(_ record: inout WorkSessionRecord) -> Bool {
    guard record.family == .systemsReview,
          record.path == .manualReview,
          !record.completed,
          !record.systemsSequence.isEmpty else { return false }
    record.systemsSequence.removeAll()
    return true
  }

  static func completeSystemsReview(_ record: inout WorkSessionRecord) -> Bool {
    guard record.family == .systemsReview,
          record.path == .manualReview,
          !record.completed,
          let challenge = record.systemsChallenge,
          let assessment = SystemsReviewEvaluator.evaluate(challenge: challenge, sequence: record.systemsSequence) else { return false }
    record.founderReviewQuality = assessment.reviewQuality
    record.findings = assessment.findings
    record.deliveredQuality = deliveredQuality(
      potential: record.agentPotentialQuality,
      reviewQuality: assessment.reviewQuality,
      path: .manualReview,
      seed: record.challengeSeed
    )
    record.completed = true
    return true
  }

  static func delegate(_ record: inout WorkSessionRecord) -> Bool {
    guard !record.completed, record.path == nil else { return false }
    record.path = .delegate
    record.founderReviewQuality = nil
    record.deliveredQuality = deliveredQuality(potential: record.agentPotentialQuality, reviewQuality: nil, path: .delegate, seed: record.challengeSeed)
    record.completed = true
    return true
  }

  static func deliveredQuality(potential: Int, reviewQuality: Int?, path: WorkSessionPath, seed: UInt64) -> Int {
    let boundedPotential = min(100, max(0, potential))
    let extraction: Double
    switch path {
    case .manualReview:
      switch reviewQuality ?? 0 {
      case 100: extraction = 1
      case 95...: extraction = 0.98
      case 85...: extraction = 0.92
      case 75...: extraction = 0.82
      case 60...: extraction = 0.70
      default: extraction = 0.60
      }
    case .delegate:
      let deterministicAdjustment = Double(Int(SeededRandomNumberGenerator.mixed(seed ^ 0xD31E6A7E) % 5) - 2) / 100
      extraction = 0.77 + deterministicAdjustment
    case .autoReview:
      extraction = 0.86
    }
    return min(boundedPotential, max(0, Int((Double(boundedPotential) * extraction).rounded())))
  }

  private static func stableSeed(
    careerSeed: UInt64,
    assignmentID: UUID,
    agentID: String,
    venture: Int,
    sprint: Int,
    evidenceTopic: EvidenceTopic?
  ) -> UInt64 {
    stableSeed(
      careerSeed: careerSeed,
      assignmentID: assignmentID,
      agentID: agentID,
      venture: venture,
      sprint: sprint,
      family: .evidenceTriage,
      topicIdentity: evidenceTopic?.rawValue
    )
  }

  private static func stableSeed(
    careerSeed: UInt64,
    assignmentID: UUID,
    agentID: String,
    venture: Int,
    sprint: Int,
    family: WorkSessionFamily,
    topicIdentity: String?
  ) -> UInt64 {
    var value = careerSeed ^ UInt64(max(0, venture) * 10_000 + max(0, sprint) * 100)
    var identity = "\(assignmentID.uuidString.lowercased())|\(agentID)|\(family.rawValue)-v1"
    if let topicIdentity { identity += "|topic:\(topicIdentity)" }
    for byte in identity.utf8 {
      value ^= UInt64(byte)
      value &*= 0x100000001B3
    }
    return SeededRandomNumberGenerator.mixed(value)
  }

  private static func deterministicCards(seed: UInt64, count: Int, topic: EvidenceTopic?) -> [EvidenceTriageCard] {
    // Untagged assignments intentionally rank only the original twelve-card
    // pool, preserving the first prototype's exact deterministic behavior.
    let pool = topic == nil ? Array(challengePool.prefix(12)) : challengePool
    let ranked = pool.enumerated().sorted { left, right in
      let l = SeededRandomNumberGenerator.mixed(seed ^ UInt64(left.offset + 1) &* 0x9E3779B97F4A7C15)
      let r = SeededRandomNumberGenerator.mixed(seed ^ UInt64(right.offset + 1) &* 0x9E3779B97F4A7C15)
      return l == r ? left.element.id < right.element.id : l < r
    }
    let boundedCount = min(count, ranked.count)
    guard let topic else { return Array(ranked.prefix(boundedCount).map(\.element)) }

    let matchingQuota = min((boundedCount + 1) / 2, ranked.filter { $0.element.supports(topic) }.count)
    let preferredIDs = Set(ranked.lazy.filter { $0.element.supports(topic) }.prefix(matchingQuota).map { $0.element.id })
    let fallbackIDs = Set(ranked.lazy.filter { !preferredIDs.contains($0.element.id) }.prefix(boundedCount - matchingQuota).map { $0.element.id })
    let selectedIDs = preferredIDs.union(fallbackIDs)
    return ranked.lazy.filter { selectedIDs.contains($0.element.id) }.map(\.element)
  }

  private static let challengePool: [EvidenceTriageCard] = [
    .init(id: "activation-cohort", source: "Product Analytics", headline: "Activation rose in the newest cohort", detail: "The event is defined consistently across three releases and includes the full eligible population.", provenance: "First-party event warehouse · 28-day cohort", idealAction: .use, weight: 18, topicTags: [.product, .growth, .retention]),
    .init(id: "interview-theme", source: "Customer Research", headline: "Teams struggle to coordinate handoffs", detail: "Eight of twelve recorded interviews independently describe the same workflow failure.", provenance: "Recorded customer interviews · coded notes", idealAction: .use, weight: 16, topicTags: [.customer, .operations, .product]),
    .init(id: "social-thread", source: "Social Claim", headline: "Everyone is switching to autonomous agents", detail: "The claim traces to one viral post that provides no sample, method, or source links.", provenance: "Public social post · author estimate", idealAction: .reject, weight: 18, topicTags: [.market, .growth]),
    .init(id: "tam-forecast", source: "Market Forecast", headline: "The category will triple within two years", detail: "The forecast is directionally plausible, but its model and customer definition are unavailable.", provenance: "External analyst summary · methodology withheld", idealAction: .verify, weight: 17, topicTags: [.market, .growth]),
    .init(id: "retention-conflict", source: "Conflicting Measurement", headline: "Retention improved while active accounts fell", detail: "The dashboard and billing export use different account windows and cannot yet be reconciled.", provenance: "Analytics dashboard + billing export", idealAction: .verify, weight: 20, contradiction: true, topicTags: [.retention, .operations]),
    .init(id: "competitor-claim", source: "Competitor Statement", headline: "A competitor reports 94% customer retention", detail: "The figure appears in marketing copy without a period, cohort definition, or independent audit.", provenance: "Competitor website · self-reported", idealAction: .verify, weight: 15, topicTags: [.competition, .retention, .market]),
    .init(id: "support-volume", source: "First-Party Data", headline: "Onboarding questions dominate support volume", detail: "Tagged tickets show the pattern across every customer segment for the last six weeks.", provenance: "Support system export · 436 tickets", idealAction: .use, weight: 17, topicTags: [.customer, .operations, .product]),
    .init(id: "single-customer", source: "Customer Anecdote", headline: "One design partner would pay twice the current price", detail: "The statement is direct but conflicts with three recent pricing interviews.", provenance: "Sales call note · one account", idealAction: .verify, weight: 16, contradiction: true, topicTags: [.pricing, .customer]),
    .init(id: "synthetic-survey", source: "Questionable Survey", headline: "Nine in ten founders want the proposed feature", detail: "Respondents were recruited from a feature-specific community and incentives were not disclosed.", provenance: "Third-party online poll · 61 responses", idealAction: .reject, weight: 17, topicTags: [.customer, .market, .product]),
    .init(id: "experiment", source: "Controlled Experiment", headline: "Guided setup improved first-week completion", detail: "The preregistered experiment met its sample target with balanced cohorts and no early stopping.", provenance: "First-party experiment · 1,842 accounts", idealAction: .use, weight: 20, topicTags: [.product, .growth, .retention]),
    .init(id: "churn-notes", source: "Incomplete Evidence", headline: "Missing integrations may drive churn", detail: "Exit notes support the pattern, but only a third of churned accounts supplied a reason.", provenance: "Cancellation survey · partial response set", idealAction: .verify, weight: 15, topicTags: [.retention, .customer, .product]),
    .init(id: "old-benchmark", source: "External Benchmark", headline: "Peer products convert at 12%", detail: "The benchmark predates major platform changes and combines consumer and business products.", provenance: "Industry report · published four years ago", idealAction: .reject, weight: 14, topicTags: [.competition, .market, .growth]),
    .init(id: "pricing-panel", source: "Pricing Research", headline: "Annual buyers accept the proposed price band", detail: "A balanced customer panel completed a blinded willingness-to-pay exercise with consistent results.", provenance: "Customer pricing panel · 84 qualified buyers", idealAction: .use, weight: 18, topicTags: [.pricing, .customer]),
    .init(id: "discount-conversion", source: "Pricing Experiment", headline: "A deeper discount increased trial conversion", detail: "The test stopped after three days and did not measure paid retention or refund behavior.", provenance: "Checkout experiment · early read", idealAction: .verify, weight: 17, topicTags: [.pricing, .growth, .retention]),
    .init(id: "margin-thread", source: "Internal Forecast", headline: "The new tier can sustain current service margins", detail: "The estimate excludes support load and assumes infrastructure costs remain flat at ten times usage.", provenance: "Finance worksheet · unsupported assumptions", idealAction: .reject, weight: 16, topicTags: [.pricing, .operations])
  ]
}
