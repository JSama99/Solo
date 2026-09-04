import Foundation

/// The financial source of truth for a career. `FounderStats.capital` remains a
/// compatibility projection for older UI and saves; it mirrors available cash.
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
  case space = "Space", aiWorkforce = "AI Workforce", infrastructure = "Infrastructure", operations = "Operations", growth = "Growth"
  var id: String { rawValue }
  var symbol: String { switch self { case .space: "building.2.fill"; case .aiWorkforce: "cpu.fill"; case .infrastructure: "server.rack"; case .operations: "gearshape.2.fill"; case .growth: "megaphone.fill" } }
}

enum FinancialTransactionKind: String, Codable { case revenue, capitalRaised, expense, reversal }

enum FundingOpportunityKind: String, Codable, CaseIterable, Sendable {
  case grant
  case fundraising

  var title: String { self == .grant ? "Grant" : "Fundraising" }
  var symbol: String { self == .grant ? "doc.text.fill" : "person.2.fill" }
}

enum FundingOpportunityStatus: String, Codable, CaseIterable, Sendable {
  case locked
  case available
  case eligible
  case pursuing
  case resolved
  case expired

  var title: String {
    switch self {
    case .locked: "Locked"
    case .available: "Available"
    case .eligible: "Eligible"
    case .pursuing: "Pursuing"
    case .resolved: "Resolved"
    case .expired: "Expired"
    }
  }
}

enum FundingRequirementMetric: String, Codable, CaseIterable, Sendable {
  case revenue
  case trust
  case momentum
  case coverage
  case venture
  case evidence

  var title: String {
    switch self {
    case .revenue: "Revenue"
    case .trust: "Company Trust"
    case .momentum: "Momentum"
    case .coverage: "Coverage"
    case .venture: "Venture"
    case .evidence: "Evidence records"
    }
  }
}

struct FundingRequirement: Codable, Hashable, Sendable {
  var metric: FundingRequirementMetric
  var minimum: Int
}

struct FundingOpportunity: Identifiable, Codable, Hashable, Sendable {
  var id: String
  var kind: FundingOpportunityKind
  var name: String
  var summary: String
  var amount: Int
  var availableFromCareerSprint: Int
  var expiresAfterCareerSprint: Int
  var founderAttentionCost: Int
  var requirements: [FundingRequirement]
  var terms: String
  var obligationSprints: Int

  var amountLabel: String {
    amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
  }

  var openingLabel: String { Self.sprintLabel(availableFromCareerSprint) }
  var deadlineLabel: String { Self.sprintLabel(expiresAfterCareerSprint) }

  static func sprintLabel(_ careerSprint: Int) -> String {
    let safe = max(1, careerSprint)
    return "Venture \(((safe - 1) / 12) + 1), Sprint \(((safe - 1) % 12) + 1)"
  }
}

enum FundingApplicationStatus: String, Codable, Sendable {
  case pursuing
  case resolved
}

struct FundingApplicationRecord: Identifiable, Codable, Hashable, Sendable {
  var id: String { opportunityID }
  var opportunityID: String
  var status: FundingApplicationStatus
  var appliedCareerSprint: Int
  var resolvedCareerSprint: Int?
}

struct FundingBoardSnapshot: Equatable, Sendable {
  var revenue: Int
  var trust: Int
  var momentum: Int
  var coverage: Int
  var venture: Int
  var evidenceCount: Int
  var careerSprint: Int
  var attentionRemaining: Int

  func value(for metric: FundingRequirementMetric) -> Int {
    switch metric {
    case .revenue: revenue
    case .trust: trust
    case .momentum: momentum
    case .coverage: coverage
    case .venture: venture
    case .evidence: evidenceCount
    }
  }
}

struct FundingRequirementPresentation: Identifiable, Equatable, Sendable {
  var id: String { requirement.metric.rawValue }
  var requirement: FundingRequirement
  var currentValue: Int

  var isMet: Bool { currentValue >= requirement.minimum }

  var valueLabel: String {
    switch requirement.metric {
    case .revenue:
      "\(currentValue.formatted(.currency(code: "USD").precision(.fractionLength(0)))) of \(requirement.minimum.formatted(.currency(code: "USD").precision(.fractionLength(0))))"
    default:
      "\(currentValue) of \(requirement.minimum)"
    }
  }
}

struct FundingOpportunityPresentation: Identifiable, Equatable, Sendable {
  var id: String { opportunity.id }
  var opportunity: FundingOpportunity
  var status: FundingOpportunityStatus
  var requirements: [FundingRequirementPresentation]
  var attentionRemaining: Int
  var currentCareerSprint: Int
  var application: FundingApplicationRecord?

  var canApply: Bool {
    status == .eligible && attentionRemaining >= opportunity.founderAttentionCost
  }

  var canResolve: Bool {
    status == .pursuing
      && currentCareerSprint > (application?.appliedCareerSprint ?? currentCareerSprint)
  }

  var statusDetail: String {
    switch status {
    case .locked: "Opens \(opportunity.openingLabel)"
    case .available: "Meet every visible requirement before the deadline."
    case .eligible where !canApply: "Needs \(opportunity.founderAttentionCost) Founder Attention."
    case .eligible: "Ready to pursue."
    case .pursuing where canResolve: "A response is ready."
    case .pursuing: "Response expected after the next sprint."
    case .resolved: "Funding entered the company ledger."
    case .expired: "Closed after \(opportunity.deadlineLabel)."
    }
  }
}

enum FundingBoardCatalog {
  static let opportunities: [FundingOpportunity] = [
    FundingOpportunity(
      id: "pioneer-ai-grant",
      kind: .grant,
      name: "Pioneer AI Grant",
      summary: "Non-dilutive support for a young company building a trustworthy AI operating practice.",
      amount: 2_400,
      availableFromCareerSprint: 1,
      expiresAfterCareerSprint: 4,
      founderAttentionCost: 1,
      requirements: [
        FundingRequirement(metric: .venture, minimum: 1),
        FundingRequirement(metric: .trust, minimum: 60)
      ],
      terms: "Non-dilutive. One focused application packet.",
      obligationSprints: 0
    ),
    FundingOpportunity(
      id: "garage-innovation-fund",
      kind: .grant,
      name: "Garage Innovation Fund",
      summary: "A milestone grant for founders turning early operating evidence into a repeatable company system.",
      amount: 4_200,
      availableFromCareerSprint: 2,
      expiresAfterCareerSprint: 8,
      founderAttentionCost: 1,
      requirements: [
        FundingRequirement(metric: .momentum, minimum: 28),
        FundingRequirement(metric: .evidence, minimum: 2)
      ],
      terms: "Non-dilutive. Evidence and execution milestones remain public to the founder.",
      obligationSprints: 0
    ),
    FundingOpportunity(
      id: "emerging-venture-award",
      kind: .grant,
      name: "Emerging Venture Award",
      summary: "Recognition for a company pairing market visibility with credible customer progress.",
      amount: 6_500,
      availableFromCareerSprint: 4,
      expiresAfterCareerSprint: 15,
      founderAttentionCost: 1,
      requirements: [
        FundingRequirement(metric: .revenue, minimum: 1_500),
        FundingRequirement(metric: .trust, minimum: 65),
        FundingRequirement(metric: .coverage, minimum: 8)
      ],
      terms: "Non-dilutive. Award activity is based only on published company milestones.",
      obligationSprints: 0
    ),
    FundingOpportunity(
      id: "founder-conviction-round",
      kind: .fundraising,
      name: "Founder Conviction Round",
      summary: "A bounded outside-capital round for a company that can show traction and a credible public signal.",
      amount: 15_000,
      availableFromCareerSprint: 6,
      expiresAfterCareerSprint: 20,
      founderAttentionCost: 2,
      requirements: [
        FundingRequirement(metric: .revenue, minimum: 2_500),
        FundingRequirement(metric: .momentum, minimum: 38),
        FundingRequirement(metric: .coverage, minimum: 5)
      ],
      terms: "Ownership stays unchanged. Investor updates consume 1 Energy for 4 sprints.",
      obligationSprints: 4
    )
  ]
}

enum FundingBoardEngine {
  static func presentations(
    snapshot: FundingBoardSnapshot,
    applications: [FundingApplicationRecord]
  ) -> [FundingOpportunityPresentation] {
    FundingBoardCatalog.opportunities.map { opportunity in
      let application = applications.first { $0.opportunityID == opportunity.id }
      let requirements = opportunity.requirements.map { requirement in
        FundingRequirementPresentation(
          requirement: requirement,
          currentValue: snapshot.value(for: requirement.metric)
        )
      }
      let status: FundingOpportunityStatus
      if application?.status == .resolved {
        status = .resolved
      } else if application?.status == .pursuing {
        status = .pursuing
      } else if snapshot.careerSprint < opportunity.availableFromCareerSprint {
        status = .locked
      } else if snapshot.careerSprint > opportunity.expiresAfterCareerSprint {
        status = .expired
      } else if requirements.allSatisfy(\.isMet) {
        status = .eligible
      } else {
        status = .available
      }
      return FundingOpportunityPresentation(
        opportunity: opportunity,
        status: status,
        requirements: requirements,
        attentionRemaining: snapshot.attentionRemaining,
        currentCareerSprint: snapshot.careerSprint,
        application: application
      )
    }
  }
}

struct FinancialTransaction: Codable, Identifiable, Hashable {
  var id: String
  var kind: FinancialTransactionKind
  var amount: Int
  var category: ExpenseCategory?
  var simulationDay: Int
  var source: String
  var isRecurring: Bool
  var agentID: String?
  var headquarters: FacilityTier?
}

struct CompanyFinance: Codable, Hashable {
  static let historyLimit = 120
  var cash: Int
  var capitalRaised: Int
  var lifetimeRevenue: Int
  var revenueToday: Int
  var revenueThisSprint: Int
  var transactions: [FinancialTransaction]
  var appliedTransactionIDs: Set<String>
  var fundingApplications: [FundingApplicationRecord]

  init(cash: Int = 2_500, capitalRaised: Int = 2_500, lifetimeRevenue: Int = 500, revenueToday: Int = 0, revenueThisSprint: Int = 0, transactions: [FinancialTransaction] = [], appliedTransactionIDs: Set<String> = [], fundingApplications: [FundingApplicationRecord] = []) {
    self.cash = cash; self.capitalRaised = capitalRaised; self.lifetimeRevenue = lifetimeRevenue
    self.revenueToday = revenueToday; self.revenueThisSprint = revenueThisSprint
    self.transactions = transactions; self.appliedTransactionIDs = appliedTransactionIDs
    self.fundingApplications = fundingApplications
  }

  private enum CodingKeys: String, CodingKey {
    case cash, capitalRaised, lifetimeRevenue, revenueToday, revenueThisSprint
    case transactions, appliedTransactionIDs, fundingApplications
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    cash = try values.decodeIfPresent(Int.self, forKey: .cash) ?? 2_500
    capitalRaised = try values.decodeIfPresent(Int.self, forKey: .capitalRaised) ?? cash
    lifetimeRevenue = try values.decodeIfPresent(Int.self, forKey: .lifetimeRevenue) ?? 500
    revenueToday = try values.decodeIfPresent(Int.self, forKey: .revenueToday) ?? 0
    revenueThisSprint = try values.decodeIfPresent(Int.self, forKey: .revenueThisSprint) ?? 0
    transactions = try values.decodeIfPresent([FinancialTransaction].self, forKey: .transactions) ?? []
    appliedTransactionIDs = try values.decodeIfPresent(Set<String>.self, forKey: .appliedTransactionIDs) ?? []
    fundingApplications = try values.decodeIfPresent([FundingApplicationRecord].self, forKey: .fundingApplications) ?? []
  }

  var recentDailyNetBurn: Double {
    let recent = transactions.suffix(28)
    let expenses = recent.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
    let revenue = recent.filter { $0.kind == .revenue }.reduce(0) { $0 + $1.amount }
    return Double(max(0, expenses - revenue)) / Double(max(1, min(28, recent.count)))
  }

  func runwayLabel(fallbackDailyBurn: Double) -> String {
    let burn = max(recentDailyNetBurn, fallbackDailyBurn)
    guard burn > 0 else { return "Cash-flow positive" }
    return "\(Int((Double(cash) / burn).rounded(.down))) days"
  }

  mutating func apply(_ transaction: FinancialTransaction) -> Bool {
    guard transaction.amount >= 0, appliedTransactionIDs.insert(transaction.id).inserted else { return false }
    switch transaction.kind {
    case .revenue: cash += transaction.amount; lifetimeRevenue += transaction.amount; revenueToday += transaction.amount; revenueThisSprint += transaction.amount
    case .capitalRaised: cash += transaction.amount; capitalRaised += transaction.amount
    case .expense: cash = max(0, cash - transaction.amount)
    case .reversal: cash += transaction.amount
    }
    transactions.append(transaction)
    if transactions.count > Self.historyLimit { transactions.removeFirst(transactions.count - Self.historyLimit) }
    return true
  }

  @discardableResult
  mutating func beginFundingApplication(opportunityID: String, careerSprint: Int) -> Bool {
    guard !fundingApplications.contains(where: { $0.opportunityID == opportunityID }) else { return false }
    fundingApplications.append(FundingApplicationRecord(
      opportunityID: opportunityID,
      status: .pursuing,
      appliedCareerSprint: careerSprint,
      resolvedCareerSprint: nil
    ))
    return true
  }

  @discardableResult
  mutating func resolveFundingApplication(opportunityID: String, careerSprint: Int) -> Bool {
    guard let index = fundingApplications.firstIndex(where: {
      $0.opportunityID == opportunityID && $0.status == .pursuing
    }) else { return false }
    fundingApplications[index].status = .resolved
    fundingApplications[index].resolvedCareerSprint = careerSprint
    return true
  }

  mutating func closeDay() { revenueToday = 0 }
  mutating func beginSprint() { revenueThisSprint = 0 }
}

enum OperatingCostTuning {
  static let founderLoftDeposit = 3_000
  static let founderLoftFirstMonth = 3_000
  static let founderLoftMovingSetup = 1_500
  static let founderLoftMonthlyUtilities = 400
  static let founderLoftMonthlyRent = 3_000
  static let founderLoftMoveIn = founderLoftDeposit + founderLoftFirstMonth + founderLoftMovingSetup
  static let founderLoftMonthlyObligation = founderLoftMonthlyRent + founderLoftMonthlyUtilities
  static let dailyAIWorkforcePerAgent = 12
  static let dailyInfrastructure = 16
  static let dailyOperations = 14
  static let strategicFundingRound = 25_000
  static func assignmentCost(task: SoloTask, agent: SoloAgent) -> Int { max(12, task.urgency.rawValue * 7 + (agent.role == task.role ? 4 : 8)) }
}

struct OperatingCalendar: Codable, Hashable {
  var totalDays = 1
  var dayOfSprint = 1
  var hour = 9
  var period: Period { Period(hour: hour) }
  enum Period: String, Codable, CaseIterable { case morning, afternoon, evening, night
    init(hour: Int) { switch hour { case 5..<12: self = .morning; case 12..<17: self = .afternoon; case 17..<22: self = .evening; default: self = .night } }
    var title: String { rawValue.capitalized }
    var symbol: String { switch self { case .morning: "sunrise.fill"; case .afternoon: "sun.max.fill"; case .evening: "sunset.fill"; case .night: "moon.stars.fill" } }
  }
  mutating func advance(hours: Int) {
    let elapsed = max(1, hours); let startHour = hour; hour = (hour + elapsed) % 24
    let days = (startHour + elapsed) / 24; guard days > 0 else { return }
    totalDays += days; dayOfSprint = ((dayOfSprint - 1 + days) % 7) + 1
  }
}
