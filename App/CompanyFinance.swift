import Foundation

/// The financial source of truth for a career. `FounderStats.capital` remains a
/// compatibility projection for older UI and saves; it mirrors available cash.
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
  case space = "Space", aiWorkforce = "AI Workforce", infrastructure = "Infrastructure", operations = "Operations", growth = "Growth"
  var id: String { rawValue }
  var symbol: String { switch self { case .space: "building.2.fill"; case .aiWorkforce: "cpu.fill"; case .infrastructure: "server.rack"; case .operations: "gearshape.2.fill"; case .growth: "megaphone.fill" } }
}

enum FinancialTransactionKind: String, Codable { case revenue, capitalRaised, expense, reversal }

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

  init(cash: Int = 2_500, capitalRaised: Int = 2_500, lifetimeRevenue: Int = 500, revenueToday: Int = 0, revenueThisSprint: Int = 0, transactions: [FinancialTransaction] = [], appliedTransactionIDs: Set<String> = []) {
    self.cash = cash; self.capitalRaised = capitalRaised; self.lifetimeRevenue = lifetimeRevenue
    self.revenueToday = revenueToday; self.revenueThisSprint = revenueThisSprint
    self.transactions = transactions; self.appliedTransactionIDs = appliedTransactionIDs
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
