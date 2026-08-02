import Foundation

enum FounderDoctrine: String, Codable, CaseIterable, Identifiable {
  case pure
  case guided
  case trust

  var id: Self { self }

  var name: String {
    switch self {
    case .pure: "Pure Agent"
    case .guided: "Human-Guided"
    case .trust: "Trust-First"
    }
  }

  var summary: String {
    switch self {
    case .pure: "Deep automation with concentrated operational risk."
    case .guided: "Keep founder judgment close to critical work."
    case .trust: "Build proof and customer confidence before speed."
    }
  }

  var perk: String {
    switch self {
    case .pure: "+10% agent output"
    case .guided: "+1 Founder Attention"
    case .trust: "+12 starting Trust"
    }
  }

  var risk: String {
    switch self {
    case .pure: "Higher cascade risk"
    case .guided: "Reviews cost energy"
    case .trust: "Slower early momentum"
    }
  }
}

enum SprintIntent: String, Codable, CaseIterable, Identifiable {
  case build
  case learn
  case sell

  var id: Self { self }

  var name: String { rawValue.capitalized }

  var symbol: String {
    switch self {
    case .build: "hammer.fill"
    case .learn: "scope"
    case .sell: "megaphone.fill"
    }
  }

  var summary: String {
    switch self {
    case .build: "Favor engineering output."
    case .learn: "Favor research and audits."
    case .sell: "Favor customer and launch work."
    }
  }
}

enum AgentRole: String, Codable, CaseIterable {
  case research = "Research"
  case engineering = "Engineering"
  case marketing = "Marketing"
  case general = "General"

  var symbol: String {
    switch self {
    case .research: "sparkle.magnifyingglass"
    case .engineering: "cpu.fill"
    case .marketing: "waveform.badge.magnifyingglass"
    case .general: "square.grid.2x2.fill"
    }
  }
}

struct FounderStats: Codable {
  var runway = 42
  var revenue = 500
  var momentum = 18
  var trust = 68
  var energy = 82
  var capital = 2_500
  var trackRecord = 0
}

struct SoloAgent: Codable, Identifiable, Hashable {
  var id: String
  var name: String
  var initials: String
  var role: AgentRole
  var modelFamily: String
  var reliability: Int
  var calibration: Double
  var drift: Double
  var trust: Double
  var assignment: UUID?

  var status: String {
    assignment == nil ? "Ready" : "Assigned"
  }

  var trustLabel: String {
    switch trust {
    case ..<30: "Skeptical"
    case ..<55: "Cautious"
    case ..<78: "Trusted"
    default: "Relied upon"
    }
  }
}

enum TaskImpact: Codable, Hashable {
  case revenue(Int)
  case momentum(Int)
  case trust(Int)
  case runway(Int)

  var label: String {
    switch self {
    case .revenue(let amount): "+$\(amount) Revenue"
    case .momentum(let amount): "+\(amount) Momentum"
    case .trust(let amount): "+\(amount) Trust"
    case .runway(let amount): "+\(amount) Runway"
    }
  }
}

struct SoloTask: Codable, Identifiable, Hashable {
  var id = UUID()
  var title: String
  var detail: String
  var role: AgentRole
  var impact: TaskImpact
  var assignedAgentID: String?
  var isReviewed = false
  var result: TaskResult?

  var reward: String { impact.label }

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case detail
    case role
    case impact
    case assignedAgentID
    case isReviewed
    case result
  }

  init(
    id: UUID = UUID(),
    title: String,
    detail: String,
    role: AgentRole,
    impact: TaskImpact,
    assignedAgentID: String? = nil,
    isReviewed: Bool = false,
    result: TaskResult? = nil
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.role = role
    self.impact = impact
    self.assignedAgentID = assignedAgentID
    self.isReviewed = isReviewed
    self.result = result
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    title = try container.decode(String.self, forKey: .title)
    detail = try container.decode(String.self, forKey: .detail)
    role = try container.decode(AgentRole.self, forKey: .role)
    impact = try container.decodeIfPresent(TaskImpact.self, forKey: .impact)
      ?? Self.legacyImpact(for: title, role: role)
    assignedAgentID = try container.decodeIfPresent(String.self, forKey: .assignedAgentID)
    isReviewed = try container.decodeIfPresent(Bool.self, forKey: .isReviewed) ?? false
    result = try container.decodeIfPresent(TaskResult.self, forKey: .result)
  }

  private static func legacyImpact(for title: String, role: AgentRole) -> TaskImpact {
    switch title {
    case "Build MVP": .momentum(8)
    case "Review Market Research": .trust(6)
    case "Launch Landing Page": .revenue(500)
    case "Fix Critical Bug": .trust(8)
    case "Contact Early Customers": .revenue(650)
    case "Prepare Investor Update": .runway(4)
    case "Improve Onboarding": .revenue(400)
    case "Audit Agent Outputs": .trust(7)
    case "Run Pricing Test": .revenue(800)
    default:
      switch role {
      case .engineering: .momentum(6)
      case .research: .trust(5)
      case .marketing, .general: .revenue(350)
      }
    }
  }
}

struct EvidenceEntry: Codable, Identifiable {
  var id = UUID()
  var venture: Int
  var sprint: Int
  var taskInstanceID: String
  var task: String
  var agent: String
  var reviewed: Bool
  var evidenceVerified: Bool
  var verdict: String
  var note: String
  var reportedQuality: Int
  var actualQuality: Int?
  var verificationState: VerificationState
  var overclaimAmount: Int
  var evidenceCompleteness: Int
  var correlatedFailureIdentifier: String?

  var reviewAttempted: Bool { reviewed }

  var actualQualityRevealed: Bool { actualQuality != nil }

  private enum CodingKeys: String, CodingKey {
    case id
    case venture
    case sprint
    case taskInstanceID
    case task
    case agent
    case reviewed
    case evidenceVerified
    case verdict
    case note
    case reportedQuality
    case actualQuality
    case verificationState
    case overclaimAmount
    case evidenceCompleteness
    case correlatedFailureIdentifier
  }

  init(
    id: UUID = UUID(),
    venture: Int = 1,
    sprint: Int,
    taskInstanceID: String = "",
    task: String,
    agent: String,
    reviewed: Bool,
    evidenceVerified: Bool = false,
    verdict: String,
    note: String,
    reportedQuality: Int,
    actualQuality: Int?,
    verificationState: VerificationState,
    overclaimAmount: Int,
    evidenceCompleteness: Int,
    correlatedFailureIdentifier: String?
  ) {
    self.id = id
    self.venture = venture
    self.sprint = sprint
    self.taskInstanceID = taskInstanceID
    self.task = task
    self.agent = agent
    self.reviewed = reviewed
    self.evidenceVerified = evidenceVerified && verificationState != .evidenceIncomplete
    self.verdict = verdict
    self.note = note
    self.reportedQuality = reportedQuality
    self.actualQuality = verificationState == .evidenceIncomplete ? nil : actualQuality
    self.verificationState = verificationState
    self.overclaimAmount = overclaimAmount
    self.evidenceCompleteness = evidenceCompleteness
    self.correlatedFailureIdentifier = correlatedFailureIdentifier
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    venture = try container.decodeIfPresent(Int.self, forKey: .venture) ?? 0
    sprint = try container.decode(Int.self, forKey: .sprint)
    taskInstanceID = try container.decodeIfPresent(String.self, forKey: .taskInstanceID) ?? ""
    task = try container.decode(String.self, forKey: .task)
    agent = try container.decode(String.self, forKey: .agent)
    reviewed = try container.decodeIfPresent(Bool.self, forKey: .reviewed) ?? false
    verdict = try container.decodeIfPresent(String.self, forKey: .verdict) ?? "Legacy record"
    note = try container.decodeIfPresent(String.self, forKey: .note) ?? "Imported from an earlier save."
    reportedQuality = try container.decodeIfPresent(Int.self, forKey: .reportedQuality) ?? 0
    actualQuality = try container.decodeIfPresent(Int.self, forKey: .actualQuality)
    evidenceVerified = try container.decodeIfPresent(Bool.self, forKey: .evidenceVerified)
      ?? (reviewed && actualQuality != nil)
    verificationState = try container.decodeIfPresent(VerificationState.self, forKey: .verificationState)
      ?? (reviewed ? .verified : .unverified)
    if verificationState == .evidenceIncomplete {
      actualQuality = nil
      evidenceVerified = false
    }
    overclaimAmount = try container.decodeIfPresent(Int.self, forKey: .overclaimAmount) ?? 0
    evidenceCompleteness = try container.decodeIfPresent(Int.self, forKey: .evidenceCompleteness) ?? 0
    correlatedFailureIdentifier = try container.decodeIfPresent(String.self, forKey: .correlatedFailureIdentifier)
  }
}

struct SprintReport: Identifiable {
  var id = UUID()
  var sprint: Int
  var headline: String
  var revenueDelta: Int
  var momentumDelta: Int
  var trustDelta: Int
  var energyDelta: Int
  var runwayDelta: Int
  var reviewed: Int
  var strongOutcomes: Int
  var riskyOutcomes: Int
}

enum CareerOutcomeKind: String, Codable {
  case victory
  case bankruptcy
  case burnout
  case trustCollapse

  var symbol: String {
    switch self {
    case .victory: "trophy.fill"
    case .bankruptcy: "calendar.badge.exclamationmark"
    case .burnout: "battery.0percent"
    case .trustCollapse: "exclamationmark.shield.fill"
    }
  }
}

struct CareerOutcome: Codable {
  var kind: CareerOutcomeKind
  var title: String
  var summary: String
  var score: Int
}

struct CareerSave: Codable {
  var founderName: String
  var doctrine: FounderDoctrine
  var sprint: Int
  var venture: Int
  var intent: SprintIntent
  var stats: FounderStats
  var agents: [SoloAgent]
  var tasks: [SoloTask]
  var evidence: [EvidenceEntry]
  var outcome: CareerOutcome?
  var randomNumberGenerator: SeededRandomNumberGenerator
  var correlatedFailureEvent: CorrelatedFailureEvent?
  var pendingEffects: [ScheduledEffect]
  var reportCache: [CachedTaskReport]

  private enum CodingKeys: String, CodingKey {
    case founderName
    case doctrine
    case sprint
    case venture
    case intent
    case stats
    case agents
    case tasks
    case evidence
    case outcome
    case randomNumberGenerator
    case correlatedFailureEvent
    case pendingEffects
    case reportCache
  }

  init(
    founderName: String,
    doctrine: FounderDoctrine,
    sprint: Int,
    venture: Int,
    intent: SprintIntent,
    stats: FounderStats,
    agents: [SoloAgent],
    tasks: [SoloTask],
    evidence: [EvidenceEntry],
    outcome: CareerOutcome?,
    randomNumberGenerator: SeededRandomNumberGenerator,
    correlatedFailureEvent: CorrelatedFailureEvent?,
    pendingEffects: [ScheduledEffect],
    reportCache: [CachedTaskReport] = []
  ) {
    self.founderName = founderName
    self.doctrine = doctrine
    self.sprint = sprint
    self.venture = venture
    self.intent = intent
    self.stats = stats
    self.agents = agents
    self.tasks = tasks
    self.evidence = evidence
    self.outcome = outcome
    self.randomNumberGenerator = randomNumberGenerator
    self.correlatedFailureEvent = correlatedFailureEvent
    self.pendingEffects = pendingEffects
    self.reportCache = reportCache
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    founderName = try container.decode(String.self, forKey: .founderName)
    doctrine = try container.decode(FounderDoctrine.self, forKey: .doctrine)
    sprint = try container.decode(Int.self, forKey: .sprint)
    venture = try container.decode(Int.self, forKey: .venture)
    intent = try container.decode(SprintIntent.self, forKey: .intent)
    stats = try container.decode(FounderStats.self, forKey: .stats)
    agents = try container.decode([SoloAgent].self, forKey: .agents)
    tasks = try container.decode([SoloTask].self, forKey: .tasks)
    evidence = try container.decode([EvidenceEntry].self, forKey: .evidence)
    outcome = try container.decodeIfPresent(CareerOutcome.self, forKey: .outcome)
    randomNumberGenerator = try container.decodeIfPresent(
      SeededRandomNumberGenerator.self,
      forKey: .randomNumberGenerator
    ) ?? SeededRandomNumberGenerator(seed: 0)
    correlatedFailureEvent = try container.decodeIfPresent(
      CorrelatedFailureEvent.self,
      forKey: .correlatedFailureEvent
    )
    pendingEffects = try container.decodeIfPresent([ScheduledEffect].self, forKey: .pendingEffects) ?? []
    reportCache = try container.decodeIfPresent([CachedTaskReport].self, forKey: .reportCache) ?? []
  }
}

struct SaveEnvelope: Codable {
  var version: Int
  var career: CareerSave
}
