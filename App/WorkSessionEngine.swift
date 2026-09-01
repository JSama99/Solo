import Foundation

enum WorkSessionFamily: String, Codable, Hashable {
  case evidenceTriage
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

enum WorkSessionMistake: String, Codable, CaseIterable, Hashable {
  case acceptedWeakEvidence
  case rejectedStrongEvidence
  case failedToVerifyAmbiguity
  case overVerifiedClearEvidence
  case correctlyDetectedContradiction

  var hindsightExplanation: String {
    switch self {
    case .acceptedWeakEvidence: "A weak source was accepted during Founder Review."
    case .rejectedStrongEvidence: "A strong source was rejected, reducing usable evidence."
    case .failedToVerifyAmbiguity: "An ambiguous claim passed without a verification request."
    case .overVerifiedClearEvidence: "Clear evidence was sent for unnecessary verification."
    case .correctlyDetectedContradiction: "Founder Review correctly isolated a contradictory measurement."
    }
  }
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
    "Evidence (position) of (total). (source). (headline). (detail). Provenance: (provenance)."
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

  init(id: String, source: String, headline: String, detail: String, provenance: String, idealAction: EvidenceTriageAction, weight: Int, contradiction: Bool = false) {
    self.id = id
    self.source = source
    self.headline = headline
    self.detail = detail
    self.provenance = provenance
    self.idealAction = idealAction
    self.weight = weight
    self.contradiction = contradiction
  }

  func presentation(position: Int, total: Int) -> EvidenceCardPresentation {
    EvidenceCardPresentation(id: id, source: source, headline: headline, detail: detail, provenance: provenance, position: position, total: total)
  }

  fileprivate func assessment(for action: EvidenceTriageAction) -> WorkSessionEngine.CardAssessment {
    var mistakes: [WorkSessionMistake] = []
    if action == idealAction {
      if contradiction && action == .verify { mistakes.append(.correctlyDetectedContradiction) }
      return .init(points: weight, possible: weight, mistakes: mistakes)
    }
    switch (idealAction, action) {
    case (.reject, .use): mistakes.append(.acceptedWeakEvidence)
    case (.use, .reject): mistakes.append(.rejectedStrongEvidence)
    case (.verify, _): mistakes.append(.failedToVerifyAmbiguity)
    case (.use, .verify): mistakes.append(.overVerifiedClearEvidence)
    default: break
    }
    let partial = action == .verify && idealAction == .reject ? weight / 3 : 0
    return .init(points: partial, possible: weight, mistakes: mistakes)
  }
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
  var path: WorkSessionPath?
  var cards: [EvidenceTriageCard]
  var decisions: [WorkSessionDecision]
  var founderReviewQuality: Int?
  var deliveredQuality: Int?
  var mistakes: [WorkSessionMistake]
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
    Array(Set(mistakes.map(\.hindsightExplanation))).sorted()
  }
}

enum WorkSessionEngine {
  struct CardAssessment {
    var points: Int
    var possible: Int
    var mistakes: [WorkSessionMistake]
  }

  static func isEligible(task: SoloTask, agentID: String) -> Bool {
    agentID == "aurora"
      && (task.role == .research || task.category == .research || task.category == .trust)
      && task.result != nil
      && !task.isReviewed
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
    attentionCost: Int
  ) -> WorkSessionRecord {
    let seed = stableSeed(careerSeed: careerSeed, assignmentID: assignmentID, agentID: agentID, venture: venture, sprint: sprint)
    let count = stress == .overloaded || stress == .critical ? 7 : 6
    let cards = deterministicCards(seed: seed, count: count)
    return WorkSessionRecord(
      id: "evidence-triage-\(assignmentID.uuidString.lowercased())",
      assignmentID: assignmentID,
      agentID: agentID,
      family: .evidenceTriage,
      stakes: WorkSessionStakes(urgency: urgency),
      challengeSeed: seed,
      agentPotentialQuality: min(100, max(0, potentialQuality)),
      path: nil,
      cards: cards,
      decisions: [],
      founderReviewQuality: nil,
      deliveredQuality: nil,
      mistakes: [],
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
    guard record.path == .manualReview, !record.completed, record.decisions.count == record.cards.count else { return false }
    var earned = 0
    var possible = 0
    var mistakes: [WorkSessionMistake] = []
    for (card, decision) in zip(record.cards, record.decisions) {
      let assessment = card.assessment(for: decision.action)
      earned += assessment.points
      possible += assessment.possible
      mistakes.append(contentsOf: assessment.mistakes)
    }
    let raw = possible == 0 ? 0 : Int((Double(earned) / Double(possible) * 100).rounded())
    record.founderReviewQuality = min(100, max(0, raw))
    record.mistakes = mistakes
    record.deliveredQuality = deliveredQuality(potential: record.agentPotentialQuality, reviewQuality: raw, path: .manualReview, seed: record.challengeSeed)
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

  private static func stableSeed(careerSeed: UInt64, assignmentID: UUID, agentID: String, venture: Int, sprint: Int) -> UInt64 {
    var value = careerSeed ^ UInt64(max(0, venture) * 10_000 + max(0, sprint) * 100)
    for byte in "\(assignmentID.uuidString.lowercased())|\(agentID)|evidence-triage-v1".utf8 {
      value ^= UInt64(byte)
      value &*= 0x100000001B3
    }
    return SeededRandomNumberGenerator.mixed(value)
  }

  private static func deterministicCards(seed: UInt64, count: Int) -> [EvidenceTriageCard] {
    let ranked = challengePool.enumerated().sorted { left, right in
      let l = SeededRandomNumberGenerator.mixed(seed ^ UInt64(left.offset + 1) &* 0x9E3779B97F4A7C15)
      let r = SeededRandomNumberGenerator.mixed(seed ^ UInt64(right.offset + 1) &* 0x9E3779B97F4A7C15)
      return l == r ? left.element.id < right.element.id : l < r
    }
    return Array(ranked.prefix(min(count, ranked.count)).map(\.element))
  }

  private static let challengePool: [EvidenceTriageCard] = [
    .init(id: "activation-cohort", source: "Product Analytics", headline: "Activation rose in the newest cohort", detail: "The event is defined consistently across three releases and includes the full eligible population.", provenance: "First-party event warehouse · 28-day cohort", idealAction: .use, weight: 18),
    .init(id: "interview-theme", source: "Customer Research", headline: "Teams struggle to coordinate handoffs", detail: "Eight of twelve recorded interviews independently describe the same workflow failure.", provenance: "Recorded customer interviews · coded notes", idealAction: .use, weight: 16),
    .init(id: "social-thread", source: "Social Claim", headline: "Everyone is switching to autonomous agents", detail: "The claim traces to one viral post that provides no sample, method, or source links.", provenance: "Public social post · author estimate", idealAction: .reject, weight: 18),
    .init(id: "tam-forecast", source: "Market Forecast", headline: "The category will triple within two years", detail: "The forecast is directionally plausible, but its model and customer definition are unavailable.", provenance: "External analyst summary · methodology withheld", idealAction: .verify, weight: 17),
    .init(id: "retention-conflict", source: "Conflicting Measurement", headline: "Retention improved while active accounts fell", detail: "The dashboard and billing export use different account windows and cannot yet be reconciled.", provenance: "Analytics dashboard + billing export", idealAction: .verify, weight: 20, contradiction: true),
    .init(id: "competitor-claim", source: "Competitor Statement", headline: "A competitor reports 94% customer retention", detail: "The figure appears in marketing copy without a period, cohort definition, or independent audit.", provenance: "Competitor website · self-reported", idealAction: .verify, weight: 15),
    .init(id: "support-volume", source: "First-Party Data", headline: "Onboarding questions dominate support volume", detail: "Tagged tickets show the pattern across every customer segment for the last six weeks.", provenance: "Support system export · 436 tickets", idealAction: .use, weight: 17),
    .init(id: "single-customer", source: "Customer Anecdote", headline: "One design partner would pay twice the current price", detail: "The statement is direct but conflicts with three recent pricing interviews.", provenance: "Sales call note · one account", idealAction: .verify, weight: 16, contradiction: true),
    .init(id: "synthetic-survey", source: "Questionable Survey", headline: "Nine in ten founders want the proposed feature", detail: "Respondents were recruited from a feature-specific community and incentives were not disclosed.", provenance: "Third-party online poll · 61 responses", idealAction: .reject, weight: 17),
    .init(id: "experiment", source: "Controlled Experiment", headline: "Guided setup improved first-week completion", detail: "The preregistered experiment met its sample target with balanced cohorts and no early stopping.", provenance: "First-party experiment · 1,842 accounts", idealAction: .use, weight: 20),
    .init(id: "churn-notes", source: "Incomplete Evidence", headline: "Missing integrations may drive churn", detail: "Exit notes support the pattern, but only a third of churned accounts supplied a reason.", provenance: "Cancellation survey · partial response set", idealAction: .verify, weight: 15),
    .init(id: "old-benchmark", source: "External Benchmark", headline: "Peer products convert at 12%", detail: "The benchmark predates major platform changes and combines consumer and business products.", provenance: "Industry report · published four years ago", idealAction: .reject, weight: 14)
  ]
}
