import Foundation

/// How long a career runs. Both are first-class, player-chosen options —
/// continuous mode does not replace the original bounded arc, it sits
/// alongside it. Existing saves default to `.bounded` on migration, so a
/// career already in progress keeps behaving exactly as it did in Build 4.
enum CareerMode: String, Codable, CaseIterable, Identifiable {
  case daily
  /// The original arc: 2 ventures, 12 sprints each, a defined ending.
  case bounded
  /// Unlimited sequential ventures. Each venture keeps its normal 12-sprint
  /// shape and its own real ending moment (a checkpoint, not a stop) — only
  /// the career-level cap is removed. See BUILD5_CHANGELOG.md for why this,
  /// rather than one uncapped venture, is the sound foundation: Hindsight's
  /// venture-index comparison already generalizes to N ventures with zero
  /// changes, where a single endless venture would need a full redesign of
  /// what "an earlier, comparable stretch" even means.
  case continuous

  var id: Self { self }

  var name: String {
    switch self {
    case .daily: "Daily Challenge"
    case .bounded: "Career"
    case .continuous: "Empire"
    }
  }

  var summary: String {
    switch self {
    case .daily: "One shared seed. A few sprints. Beat your best."
    case .bounded: "Two ventures, twenty-four sprints, one complete story."
    case .continuous: "Sixty ventures across six eras. Build a dynasty."
    }
  }
}

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

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
  case product = "Product"
  case research = "Research"
  case sales = "Sales"
  case operations = "Operations"
  case trust = "Trust"
  case founderLife = "Founder Life"
  case crisis = "Crisis"

  var id: Self { self }

  var symbol: String {
    switch self {
    case .product: "shippingbox.fill"
    case .research: "magnifyingglass.circle.fill"
    case .sales: "person.2.wave.2.fill"
    case .operations: "gearshape.2.fill"
    case .trust: "checkmark.shield.fill"
    case .founderLife: "heart.fill"
    case .crisis: "exclamationmark.triangle.fill"
    }
  }
}

enum TaskUrgency: Int, Codable, CaseIterable {
  case normal = 1
  case important = 2
  case critical = 3

  var label: String {
    switch self {
    case .normal: "Normal"
    case .important: "Important"
    case .critical: "Critical"
    }
  }
}

enum TaskResolutionChoice: String, Codable, CaseIterable, Identifiable {
  case approve
  case rework
  case shipAnyway
  case escalate

  var id: Self { self }

  var title: String {
    switch self {
    case .approve: "Approve"
    case .rework: "Rework"
    case .shipAnyway: "Ship Anyway"
    case .escalate: "Cross-Check"
    }
  }

  var symbol: String {
    switch self {
    case .approve: "checkmark.circle.fill"
    case .rework: "arrow.triangle.2.circlepath"
    case .shipAnyway: "paperplane.fill"
    case .escalate: "person.2.badge.gearshape.fill"
    }
  }

  var summary: String {
    switch self {
    case .approve: "Accept the verified result as it stands."
    case .rework: "Spend energy and runway to improve the current work."
    case .shipAnyway: "Take a faster payoff and accept more delayed risk."
    case .escalate: "Use another model family to verify and stabilize the work."
    }
  }
}

enum VentureChapter: Int, Codable, CaseIterable, Identifiable {
  case prototype = 1
  case firstCustomers = 2
  case launchPressure = 3
  case surviveOrScale = 4

  var id: Self { self }

  var name: String {
    switch self {
    case .prototype: "Prototype"
    case .firstCustomers: "First Customers"
    case .launchPressure: "Launch Pressure"
    case .surviveOrScale: "Survive or Scale"
    }
  }

  var subtitle: String {
    switch self {
    case .prototype: "Prove the product deserves to exist."
    case .firstCustomers: "Turn early interest into trust and revenue."
    case .launchPressure: "Ship under attention, uncertainty, and rising stakes."
    case .surviveOrScale: "Choose what the company becomes next."
    }
  }

  static func chapter(for sprint: Int) -> Self {
    switch sprint {
    case ...3: .prototype
    case 4...6: .firstCustomers
    case 7...9: .launchPressure
    default: .surviveOrScale
    }
  }
}

enum SprintObjectiveKind: String, Codable {
  case evidenceFirst
  case diversifiedModels
  case roleDiscipline
  case protectFounder
  case calculatedRisk
  case repairTrust
}


enum SprintPhase: Int, Codable, CaseIterable, Identifiable {
  case situation
  case intent
  case assign
  case commit

  var id: Self { self }

  var title: String {
    switch self {
    case .situation: "Situation"
    case .intent: "Intent"
    case .assign: "Assign"
    case .commit: "Commit"
    }
  }

  var symbol: String {
    switch self {
    case .situation: "bubble.left.and.exclamationmark.bubble.right.fill"
    case .intent: "scope"
    case .assign: "person.3.fill"
    case .commit: "checkmark.shield.fill"
    }
  }
}

enum CompanyFlag: String, Codable, CaseIterable, Identifiable, Hashable {
  case focusedProduct
  case featureDebt
  case evidenceLedClaims
  case hypeFirst
  case protectedFounderHealth
  case burnoutCulture
  case paidPilot
  case customerFirst
  case liabilityDenied
  case discountDependency
  case premiumPositioning
  case annualContracts
  case launchPaused
  case limitedLaunchMode
  case outageGamble
  case publicTransparency
  case simplifiedNarrative
  case mediaAverse
  case competitorRace
  case evidenceDifferentiation
  case focusedExecution
  case acceptedInvestment
  case bootstrapIndependent
  case founderFriendlyTerms
  case humanCustomerSuccess
  case agentOnlyCompany
  case contractorSupport
  case acquisitionAccepted
  case acquisitionRejected
  case licensedTechnology

  var id: Self { self }

  var name: String {
    switch self {
    case .focusedProduct: "Focused Product"
    case .featureDebt: "Custom Feature Debt"
    case .evidenceLedClaims: "Evidence-Led Claims"
    case .hypeFirst: "Hype-First Positioning"
    case .protectedFounderHealth: "Protected Founder Health"
    case .burnoutCulture: "Burnout Culture"
    case .paidPilot: "Paid Pilot"
    case .customerFirst: "Customer-First Recovery"
    case .liabilityDenied: "Liability Dispute"
    case .discountDependency: "Discount Dependency"
    case .premiumPositioning: "Premium Positioning"
    case .annualContracts: "Annual Contracts"
    case .launchPaused: "Launch Paused"
    case .limitedLaunchMode: "Limited Launch Mode"
    case .outageGamble: "Outage Gamble"
    case .publicTransparency: "Public Transparency"
    case .simplifiedNarrative: "Simplified Narrative"
    case .mediaAverse: "Media Averse"
    case .competitorRace: "Competitor Race"
    case .evidenceDifferentiation: "Evidence Differentiation"
    case .focusedExecution: "Focused Execution"
    case .acceptedInvestment: "Investor Control Rights"
    case .bootstrapIndependent: "Bootstrap Independence"
    case .founderFriendlyTerms: "Founder-Friendly Terms"
    case .humanCustomerSuccess: "Human Customer Success"
    case .agentOnlyCompany: "Agent-Only Company"
    case .contractorSupport: "Contractor Support"
    case .acquisitionAccepted: "Acquisition Accepted"
    case .acquisitionRejected: "Acquisition Rejected"
    case .licensedTechnology: "Licensed Technology"
    }
  }
}

struct CompanyObligation: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var detail: String
  var sourceDecision: String
  var remainingSprints: Int
  var effectsPerSprint: SimulationEffects

  var durationLabel: String {
    remainingSprints == 1 ? "1 sprint remaining" : "\(remainingSprints) sprints remaining"
  }
}

struct CareerDecisionRecord: Codable, Identifiable, Hashable {
  var id: String
  var venture: Int
  var sprint: Int
  var dilemmaTitle: String
  var choiceTitle: String
  var consequence: String
}

struct FounderStats: Codable, Hashable {
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
  var archetype: String
  var traits: [String]
  var ambition: String
  var stressTrigger: String
  var relationship: Int

  var status: String { assignment == nil ? "Ready" : "Assigned" }

  var trustLabel: String {
    switch trust {
    case ..<30: "Skeptical"
    case ..<55: "Cautious"
    case ..<78: "Trusted"
    default: "Relied upon"
    }
  }

  var relationshipLabel: String {
    switch relationship {
    case ..<30: "Distant"
    case ..<55: "Professional"
    case ..<78: "Aligned"
    default: "Founder Bond"
    }
  }

  var traitSummary: String { traits.joined(separator: " • ") }

  private enum CodingKeys: String, CodingKey {
    case id, name, initials, role, modelFamily, reliability, calibration, drift, trust, assignment
    case archetype, traits, ambition, stressTrigger, relationship
  }

  init(
    id: String,
    name: String,
    initials: String,
    role: AgentRole,
    modelFamily: String,
    reliability: Int,
    calibration: Double,
    drift: Double,
    trust: Double,
    assignment: UUID? = nil,
    archetype: String = "AI Teammate",
    traits: [String] = [],
    ambition: String = "Help the company succeed.",
    stressTrigger: String = "Unclear priorities.",
    relationship: Int = 55
  ) {
    self.id = id
    self.name = name
    self.initials = initials
    self.role = role
    self.modelFamily = modelFamily
    self.reliability = reliability
    self.calibration = calibration
    self.drift = drift
    self.trust = trust
    self.assignment = assignment
    let defaults = Self.personalityDefaults(for: id)
    self.archetype = archetype == "AI Teammate" ? defaults.archetype : archetype
    self.traits = traits.isEmpty ? defaults.traits : traits
    self.ambition = ambition == "Help the company succeed." ? defaults.ambition : ambition
    self.stressTrigger = stressTrigger == "Unclear priorities." ? defaults.stressTrigger : stressTrigger
    self.relationship = relationship
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    initials = try container.decode(String.self, forKey: .initials)
    role = try container.decode(AgentRole.self, forKey: .role)
    modelFamily = try container.decode(String.self, forKey: .modelFamily)
    reliability = try container.decode(Int.self, forKey: .reliability)
    calibration = try container.decode(Double.self, forKey: .calibration)
    drift = try container.decode(Double.self, forKey: .drift)
    trust = try container.decode(Double.self, forKey: .trust)
    assignment = try container.decodeIfPresent(UUID.self, forKey: .assignment)
    let defaults = Self.personalityDefaults(for: id)
    archetype = try container.decodeIfPresent(String.self, forKey: .archetype) ?? defaults.archetype
    traits = try container.decodeIfPresent([String].self, forKey: .traits) ?? defaults.traits
    ambition = try container.decodeIfPresent(String.self, forKey: .ambition) ?? defaults.ambition
    stressTrigger = try container.decodeIfPresent(String.self, forKey: .stressTrigger) ?? defaults.stressTrigger
    relationship = try container.decodeIfPresent(Int.self, forKey: .relationship) ?? 55
  }

  private static func personalityDefaults(for id: String) -> (
    archetype: String,
    traits: [String],
    ambition: String,
    stressTrigger: String
  ) {
    switch id {
    case "aurora":
      ("The Analyst", ["Cautious", "Evidence-driven"], "Become the founder's most trusted strategic advisor.", "Being forced to claim certainty without proof.")
    case "stacks":
      ("The Builder", ["Fast", "Systems-minded"], "Build infrastructure that can survive real scale.", "Constant priority changes and avoidable shortcuts.")
    case "brio":
      ("The Promoter", ["Bold", "Customer-obsessed"], "Turn the company into something the market cannot ignore.", "Playing too safely when momentum is available.")
    default:
      ("AI Teammate", ["Adaptive"], "Help the company succeed.", "Unclear priorities.")
    }
  }
}

enum TaskImpact: Codable, Hashable {
  case revenue(Int)
  case momentum(Int)
  case trust(Int)
  case runway(Int)
  case energy(Int)

  var label: String {
    switch self {
    case .revenue(let amount): "+$\(amount) Revenue"
    case .momentum(let amount): "+\(amount) Momentum"
    case .trust(let amount): "+\(amount) Trust"
    case .runway(let amount): "+\(amount) Runway"
    case .energy(let amount): "+\(amount) Energy"
    }
  }
}

struct SoloTask: Codable, Identifiable, Hashable {
  var id = UUID()
  var title: String
  var detail: String
  var role: AgentRole
  var category: TaskCategory
  var urgency: TaskUrgency
  var impact: TaskImpact
  var skipEffects: SimulationEffects
  var assignedAgentID: String?
  var isReviewed = false
  var result: TaskResult?
  var resolution: TaskResolutionChoice?
  var resolutionLocked = false

  var reward: String { impact.label }
  var consequenceLabel: String { skipEffects.conciseLossLabel }

  private enum CodingKeys: String, CodingKey {
    case id, title, detail, role, category, urgency, impact, skipEffects
    case assignedAgentID, isReviewed, result, resolution, resolutionLocked
  }

  init(
    id: UUID = UUID(),
    title: String,
    detail: String,
    role: AgentRole,
    category: TaskCategory? = nil,
    urgency: TaskUrgency = .normal,
    impact: TaskImpact,
    skipEffects: SimulationEffects = SimulationEffects(),
    assignedAgentID: String? = nil,
    isReviewed: Bool = false,
    result: TaskResult? = nil,
    resolution: TaskResolutionChoice? = nil,
    resolutionLocked: Bool = false
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.role = role
    self.category = category ?? Self.legacyCategory(for: role)
    self.urgency = urgency
    self.impact = impact
    self.skipEffects = skipEffects
    self.assignedAgentID = assignedAgentID
    self.isReviewed = isReviewed
    self.result = result
    self.resolution = resolution
    self.resolutionLocked = resolutionLocked
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    title = try container.decode(String.self, forKey: .title)
    detail = try container.decode(String.self, forKey: .detail)
    role = try container.decode(AgentRole.self, forKey: .role)
    category = try container.decodeIfPresent(TaskCategory.self, forKey: .category) ?? Self.legacyCategory(for: role)
    urgency = try container.decodeIfPresent(TaskUrgency.self, forKey: .urgency) ?? .normal
    impact = try container.decodeIfPresent(TaskImpact.self, forKey: .impact)
      ?? Self.legacyImpact(for: title, role: role)
    skipEffects = try container.decodeIfPresent(SimulationEffects.self, forKey: .skipEffects) ?? SimulationEffects()
    assignedAgentID = try container.decodeIfPresent(String.self, forKey: .assignedAgentID)
    isReviewed = try container.decodeIfPresent(Bool.self, forKey: .isReviewed) ?? false
    result = try container.decodeIfPresent(TaskResult.self, forKey: .result)
    resolution = try container.decodeIfPresent(TaskResolutionChoice.self, forKey: .resolution)
    resolutionLocked = try container.decodeIfPresent(Bool.self, forKey: .resolutionLocked) ?? false
  }

  private static func legacyCategory(for role: AgentRole) -> TaskCategory {
    switch role {
    case .engineering: .product
    case .research: .research
    case .marketing: .sales
    case .general: .operations
    }
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

struct DilemmaChoice: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var detail: String
  var consequencePreview: String
  var effects: SimulationEffects
  var relationshipDeltas: [String: Int] = [:]
}

struct FounderDilemma: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var setup: String
  var chapter: VentureChapter
  var featuredAgentID: String?
  var choices: [DilemmaChoice]
  var requiredFlags: Set<CompanyFlag> = []
  var excludedFlags: Set<CompanyFlag> = []
  var minimumEra: VentureEra?

  private enum CodingKeys: String, CodingKey {
    case id, title, setup, chapter, featuredAgentID, choices, requiredFlags, excludedFlags, minimumEra
  }

  init(id: String, title: String, setup: String, chapter: VentureChapter, featuredAgentID: String?, choices: [DilemmaChoice], requiredFlags: Set<CompanyFlag> = [], excludedFlags: Set<CompanyFlag> = [], minimumEra: VentureEra? = nil) {
    self.id = id
    self.title = title
    self.setup = setup
    self.chapter = chapter
    self.featuredAgentID = featuredAgentID
    self.choices = choices
    self.requiredFlags = requiredFlags
    self.excludedFlags = excludedFlags
    self.minimumEra = minimumEra
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    title = try values.decode(String.self, forKey: .title)
    setup = try values.decode(String.self, forKey: .setup)
    chapter = try values.decode(VentureChapter.self, forKey: .chapter)
    featuredAgentID = try values.decodeIfPresent(String.self, forKey: .featuredAgentID)
    choices = try values.decode([DilemmaChoice].self, forKey: .choices)
    requiredFlags = try values.decodeIfPresent(Set<CompanyFlag>.self, forKey: .requiredFlags) ?? []
    excludedFlags = try values.decodeIfPresent(Set<CompanyFlag>.self, forKey: .excludedFlags) ?? []
    minimumEra = try values.decodeIfPresent(VentureEra.self, forKey: .minimumEra)
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(title, forKey: .title)
    try values.encode(setup, forKey: .setup)
    try values.encode(chapter, forKey: .chapter)
    try values.encodeIfPresent(featuredAgentID, forKey: .featuredAgentID)
    try values.encode(choices, forKey: .choices)
    try values.encode(requiredFlags, forKey: .requiredFlags)
    try values.encode(excludedFlags, forKey: .excludedFlags)
    try values.encodeIfPresent(minimumEra, forKey: .minimumEra)
  }
}

struct SprintObjective: Codable, Identifiable, Hashable {
  var id: String
  var kind: SprintObjectiveKind
  var title: String
  var detail: String
  var reward: SimulationEffects
  var rewardLabel: String
  var targetAgentID: String? = nil
}

enum GarageUpgrade: String, CaseIterable, Identifiable {
  case strategyWall
  case customerMap
  case evidenceShelf
  case operationsRack
  case recoveryCorner

  var id: Self { self }

  var name: String {
    switch self {
    case .strategyWall: "Strategy Wall"
    case .customerMap: "Customer Map"
    case .evidenceShelf: "Evidence Shelf"
    case .operationsRack: "Operations Rack"
    case .recoveryCorner: "Recovery Corner"
    }
  }

  var symbol: String {
    switch self {
    case .strategyWall: "rectangle.and.pencil.and.ellipsis"
    case .customerMap: "map.fill"
    case .evidenceShelf: "checkmark.seal.fill"
    case .operationsRack: "server.rack"
    case .recoveryCorner: "cup.and.saucer.fill"
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
    case id, venture, sprint, taskInstanceID, task, agent, reviewed, evidenceVerified
    case verdict, note, reportedQuality, actualQuality, verificationState
    case overclaimAmount, evidenceCompleteness, correlatedFailureIdentifier
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
  var chapterName: String
  var objectiveTitle: String?
  var objectiveCompleted: Bool
  var dilemmaSummary: String?
  var skippedTasks: Int

  init(
    id: UUID = UUID(),
    sprint: Int,
    headline: String,
    revenueDelta: Int,
    momentumDelta: Int,
    trustDelta: Int,
    energyDelta: Int,
    runwayDelta: Int,
    reviewed: Int,
    strongOutcomes: Int,
    riskyOutcomes: Int,
    chapterName: String = "",
    objectiveTitle: String? = nil,
    objectiveCompleted: Bool = false,
    dilemmaSummary: String? = nil,
    skippedTasks: Int = 0
  ) {
    self.id = id
    self.sprint = sprint
    self.headline = headline
    self.revenueDelta = revenueDelta
    self.momentumDelta = momentumDelta
    self.trustDelta = trustDelta
    self.energyDelta = energyDelta
    self.runwayDelta = runwayDelta
    self.reviewed = reviewed
    self.strongOutcomes = strongOutcomes
    self.riskyOutcomes = riskyOutcomes
    self.chapterName = chapterName
    self.objectiveTitle = objectiveTitle
    self.objectiveCompleted = objectiveCompleted
    self.dilemmaSummary = dilemmaSummary
    self.skippedTasks = skippedTasks
  }
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

/// A non-terminal "venture complete" moment in continuous mode. Bounded mode
/// never produces one of these — it goes straight to `CareerOutcome` at
/// venture 2. This exists specifically so completing a venture in continuous
/// mode still feels like a real beat with a real payoff, not a silent
/// rollover into the next set of 12 sprints. The player explicitly chooses
/// `.continue` or `.retire`; retiring converts this into a genuine `.victory`
/// `CareerOutcome`, so a continuous career still gets to end on the player's
/// own terms rather than never ending at all.
struct VentureCheckpoint: Codable, Hashable {
  var venture: Int
  var trackRecordEarned: Int
  var revenue: Int
  var trust: Int
  var momentum: Int
  var precedentsBanked: Int

  var headline: String {
    "Venture \(venture) complete"
  }
}

enum VentureCheckpointDecision {
  case `continue`
  case retire
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
  var taskBacklog: [SoloTask]
  var founderAttentionSpent: Int
  var activeDilemma: FounderDilemma?
  var selectedDilemmaChoiceID: String?
  var currentObjective: SprintObjective?
  var evidence: [EvidenceEntry]
  var outcome: CareerOutcome?
  var randomNumberGenerator: SeededRandomNumberGenerator
  var correlatedFailureEvent: CorrelatedFailureEvent?
  var pendingEffects: [ScheduledEffect]
  var reportCache: [CachedTaskReport]
  var precedents: [Precedent]
  var awaitingFounderPass: Bool
  var careerMode: CareerMode
  var pendingVentureCheckpoint: VentureCheckpoint?
  var recentTaskTitles: [String]
  var taskDeckTitles: [String]
  var dilemmaDeckTemplateIDs: [String]
  var dilemmaDeckChapter: VentureChapter?
  var recentObjectiveKinds: [SprintObjectiveKind]
  var companyFlags: Set<CompanyFlag>
  var activeObligations: [CompanyObligation]
  var decisionHistory: [CareerDecisionRecord]
  var completedObjectives: Int

  private enum CodingKeys: String, CodingKey {
    case founderName, doctrine, sprint, venture, intent, stats, agents, tasks
    case taskBacklog, founderAttentionSpent, activeDilemma, selectedDilemmaChoiceID, currentObjective
    case evidence, outcome, randomNumberGenerator, correlatedFailureEvent
    case pendingEffects, reportCache, precedents, awaitingFounderPass
    case careerMode, pendingVentureCheckpoint
    case recentTaskTitles, taskDeckTitles, dilemmaDeckTemplateIDs, dilemmaDeckChapter
    case recentObjectiveKinds, companyFlags, activeObligations, decisionHistory, completedObjectives
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
    taskBacklog: [SoloTask] = [],
    founderAttentionSpent: Int = 0,
    activeDilemma: FounderDilemma? = nil,
    selectedDilemmaChoiceID: String? = nil,
    currentObjective: SprintObjective? = nil,
    evidence: [EvidenceEntry],
    outcome: CareerOutcome?,
    randomNumberGenerator: SeededRandomNumberGenerator,
    correlatedFailureEvent: CorrelatedFailureEvent?,
    pendingEffects: [ScheduledEffect],
    reportCache: [CachedTaskReport] = [],
    precedents: [Precedent] = [],
    awaitingFounderPass: Bool = false,
    careerMode: CareerMode = .bounded,
    pendingVentureCheckpoint: VentureCheckpoint? = nil,
    recentTaskTitles: [String] = [],
    taskDeckTitles: [String] = [],
    dilemmaDeckTemplateIDs: [String] = [],
    dilemmaDeckChapter: VentureChapter? = nil,
    recentObjectiveKinds: [SprintObjectiveKind] = [],
    companyFlags: Set<CompanyFlag> = [],
    activeObligations: [CompanyObligation] = [],
    decisionHistory: [CareerDecisionRecord] = [],
    completedObjectives: Int = 0
  ) {
    self.founderName = founderName
    self.doctrine = doctrine
    self.sprint = sprint
    self.venture = venture
    self.intent = intent
    self.stats = stats
    self.agents = agents
    self.tasks = tasks
    self.taskBacklog = taskBacklog
    self.founderAttentionSpent = founderAttentionSpent
    self.activeDilemma = activeDilemma
    self.selectedDilemmaChoiceID = selectedDilemmaChoiceID
    self.currentObjective = currentObjective
    self.evidence = evidence
    self.outcome = outcome
    self.randomNumberGenerator = randomNumberGenerator
    self.correlatedFailureEvent = correlatedFailureEvent
    self.pendingEffects = pendingEffects
    self.reportCache = reportCache
    self.precedents = precedents
    self.awaitingFounderPass = awaitingFounderPass
    self.careerMode = careerMode
    self.pendingVentureCheckpoint = pendingVentureCheckpoint
    self.recentTaskTitles = recentTaskTitles
    self.taskDeckTitles = taskDeckTitles
    self.dilemmaDeckTemplateIDs = dilemmaDeckTemplateIDs
    self.dilemmaDeckChapter = dilemmaDeckChapter
    self.recentObjectiveKinds = recentObjectiveKinds
    self.companyFlags = companyFlags
    self.activeObligations = activeObligations
    self.decisionHistory = decisionHistory
    self.completedObjectives = completedObjectives
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
    taskBacklog = try container.decodeIfPresent([SoloTask].self, forKey: .taskBacklog) ?? []
    founderAttentionSpent = try container.decodeIfPresent(Int.self, forKey: .founderAttentionSpent)
      ?? tasks.filter(\.isReviewed).count
    activeDilemma = try container.decodeIfPresent(FounderDilemma.self, forKey: .activeDilemma)
    selectedDilemmaChoiceID = try container.decodeIfPresent(String.self, forKey: .selectedDilemmaChoiceID)
    currentObjective = try container.decodeIfPresent(SprintObjective.self, forKey: .currentObjective)
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
    precedents = try container.decodeIfPresent([Precedent].self, forKey: .precedents) ?? []
    awaitingFounderPass = try container.decodeIfPresent(Bool.self, forKey: .awaitingFounderPass) ?? false
    pendingEffects = try container.decodeIfPresent([ScheduledEffect].self, forKey: .pendingEffects) ?? []
    reportCache = try container.decodeIfPresent([CachedTaskReport].self, forKey: .reportCache) ?? []
    // Every pre-Build-5 save predates career mode entirely. Defaulting to
    // .bounded means an existing career keeps behaving exactly as it did --
    // continuous mode is opt-in for new careers, never applied retroactively.
    careerMode = try container.decodeIfPresent(CareerMode.self, forKey: .careerMode) ?? .bounded
    pendingVentureCheckpoint = try container.decodeIfPresent(
      VentureCheckpoint.self, forKey: .pendingVentureCheckpoint
    )
    recentTaskTitles = try container.decodeIfPresent([String].self, forKey: .recentTaskTitles) ?? []
    taskDeckTitles = try container.decodeIfPresent([String].self, forKey: .taskDeckTitles) ?? []
    dilemmaDeckTemplateIDs = try container.decodeIfPresent([String].self, forKey: .dilemmaDeckTemplateIDs) ?? []
    dilemmaDeckChapter = try container.decodeIfPresent(VentureChapter.self, forKey: .dilemmaDeckChapter)
    recentObjectiveKinds = try container.decodeIfPresent([SprintObjectiveKind].self, forKey: .recentObjectiveKinds) ?? []
    companyFlags = try container.decodeIfPresent(Set<CompanyFlag>.self, forKey: .companyFlags) ?? []
    activeObligations = try container.decodeIfPresent([CompanyObligation].self, forKey: .activeObligations) ?? []
    decisionHistory = try container.decodeIfPresent([CareerDecisionRecord].self, forKey: .decisionHistory) ?? []
    completedObjectives = try container.decodeIfPresent(Int.self, forKey: .completedObjectives) ?? 0
  }
}

struct SaveEnvelope: Codable {
  var version: Int
  var career: CareerSave
}

extension SimulationEffects {
  var conciseLossLabel: String {
    let parts = [
      revenue == 0 ? nil : "\(revenue > 0 ? "+" : "")$\(revenue)",
      momentum == 0 ? nil : "\(momentum > 0 ? "+" : "")\(momentum) Momentum",
      trust == 0 ? nil : "\(trust > 0 ? "+" : "")\(trust) Trust",
      energy == 0 ? nil : "\(energy > 0 ? "+" : "")\(energy) Energy",
      runway == 0 ? nil : "\(runway > 0 ? "+" : "")\(runway) Runway"
    ].compactMap { $0 }
    return parts.isEmpty ? "No immediate penalty" : parts.joined(separator: " • ")
  }
}
