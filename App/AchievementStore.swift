import Foundation
import Observation

enum AchievementFamily: String, Codable, CaseIterable {
  case progression
  case mastery
  case verification
  case story

  var title: String { rawValue.capitalized }
}

enum AchievementRarity: String, Codable {
  case bronze
  case silver
  case gold

  var xp: Int {
    switch self {
    case .bronze: 50
    case .silver: 150
    case .gold: 400
    }
  }

  var label: String { rawValue.capitalized }
}

struct Achievement: Identifiable, Hashable, Codable {
  var id: String
  var title: String
  var detail: String
  var family: AchievementFamily
  var rarity: AchievementRarity
  var hidden = false

  var xp: Int { rarity.xp }
}

enum AchievementCatalog {
  static let all: [Achievement] = [
    Achievement(id: "first-venture", title: "Off the Ground", detail: "Complete your first venture.", family: .progression, rarity: .bronze),
    Achievement(id: "career-complete", title: "Two Ventures, One Record", detail: "Finish a full Career.", family: .progression, rarity: .silver),
    Achievement(id: "reach-traction", title: "Traction", detail: "Reach Venture 11 in Empire.", family: .progression, rarity: .bronze),
    Achievement(id: "reach-scale", title: "Scale", detail: "Reach Venture 21 in Empire.", family: .progression, rarity: .silver),
    Achievement(id: "reach-leader", title: "Market Leader", detail: "Reach Venture 31 in Empire.", family: .progression, rarity: .silver),
    Achievement(id: "reach-empire", title: "Empire", detail: "Reach Venture 41 in Empire.", family: .progression, rarity: .gold),
    Achievement(id: "reach-dynasty", title: "Dynasty", detail: "Reach Venture 60 — the summit.", family: .progression, rarity: .gold),
    Achievement(id: "score-10k", title: "Serious Company", detail: "Finish a run with a career score of 10,000+.", family: .progression, rarity: .silver),
    Achievement(id: "win-pure", title: "Pure Automation", detail: "Win a run with the Pure Agent doctrine.", family: .mastery, rarity: .silver),
    Achievement(id: "win-guided", title: "Hand on the Wheel", detail: "Win a run with the Human-Guided doctrine.", family: .mastery, rarity: .silver),
    Achievement(id: "win-trust", title: "Proof First", detail: "Win a run with the Trust-First doctrine.", family: .mastery, rarity: .silver),
    Achievement(id: "triple-crown", title: "Triple Crown", detail: "Win with all three doctrines.", family: .mastery, rarity: .gold, hidden: true),
    Achievement(id: "zero-drift", title: "Perfectly Aligned", detail: "End a venture with every agent at zero drift.", family: .mastery, rarity: .silver),
    Achievement(id: "objective-10", title: "Goal-Oriented", detail: "Complete 10 sprint objectives in one run.", family: .mastery, rarity: .bronze),
    Achievement(id: "objective-30", title: "Relentless", detail: "Complete 30 sprint objectives in one run.", family: .mastery, rarity: .gold),
    Achievement(id: "flawless-venture", title: "Flawless Venture", detail: "Complete a venture reviewing every committed task.", family: .mastery, rarity: .gold),
    Achievement(id: "first-catch", title: "Caught It", detail: "Catch your first overclaimed report.", family: .verification, rarity: .bronze),
    Achievement(id: "auditor", title: "Auditor", detail: "Catch 10 overclaimed reports across your career.", family: .verification, rarity: .silver),
    Achievement(id: "truth-seeker", title: "Truth-Seeker", detail: "Finish a run reviewing at least 70% of committed work.", family: .verification, rarity: .gold),
    Achievement(id: "storm-breaker", title: "Storm-Breaker", detail: "Contain three correlated failures in a single venture.", family: .verification, rarity: .silver),
    Achievement(id: "clean-ledger", title: "Clean Ledger", detail: "End a venture with no unaddressed overclaim.", family: .verification, rarity: .silver),
    Achievement(id: "trusted-house", title: "The Trusted House", detail: "Reach Scale having caught 5+ overclaims that run.", family: .verification, rarity: .gold),
    Achievement(id: "acquired", title: "The Exit", detail: "End a run by accepting an acquisition.", family: .story, rarity: .silver),
    Achievement(id: "licensed", title: "Licensed", detail: "End a run by licensing the technology.", family: .story, rarity: .silver),
    Achievement(id: "independent", title: "Still Ours", detail: "Reach the summit having never taken investment.", family: .story, rarity: .gold),
    Achievement(id: "survivor", title: "Hard Lessons", detail: "Reach any failure ending — and learn from it.", family: .story, rarity: .bronze),
    Achievement(id: "people-first", title: "People First", detail: "Win a run that hired human customer success.", family: .story, rarity: .silver)
    ,Achievement(id: "out-of-garage", title: "Out of the Garage", detail: "Purchase the Founder Loft.", family: .progression, rarity: .silver)
    ,Achievement(id: "built-different", title: "Built Different", detail: "Purchase three facility upgrades.", family: .mastery, rarity: .bronze)
    ,Achievement(id: "fully-loaded-garage", title: "Fully Loaded Garage", detail: "Purchase every Garage upgrade.", family: .mastery, rarity: .gold)
    ,Achievement(id: "cash-discipline", title: "Cash Discipline", detail: "Move into the Loft with $1,500 Capital remaining.", family: .mastery, rarity: .silver)
    ,Achievement(id: "first-promotion", title: "First Promotion", detail: "Reach Level 5 with an AI agent.", family: .progression, rarity: .bronze)
    ,Achievement(id: "specialist", title: "Specialist", detail: "Choose an agent specialization perk.", family: .mastery, rarity: .bronze)
    ,Achievement(id: "full-team-development", title: "Full Team Development", detail: "Reach Level 5 with Aurora, Stacks, and Brio.", family: .mastery, rarity: .silver)
    ,Achievement(id: "trusted-advisor", title: "Trusted Advisor", detail: "Complete Aurora's ambition.", family: .story, rarity: .silver)
    ,Achievement(id: "systems-architect", title: "Systems Architect", detail: "Complete Stacks's ambition.", family: .story, rarity: .silver)
    ,Achievement(id: "category-creator", title: "Category Creator", detail: "Complete Brio's ambition.", family: .story, rarity: .silver)
    ,Achievement(id: "calm-under-pressure", title: "Calm Under Pressure", detail: "Recover an agent from Critical Stress.", family: .mastery, rarity: .bronze)
  ]

  static func by(_ id: String) -> Achievement? { all.first { $0.id == id } }
}

enum FounderLevel {
  static let base = 500

  static func threshold(forLevel level: Int) -> Int {
    max(0, base * (level - 1) * level / 2)
  }

  static func level(forXP xp: Int) -> Int {
    var level = 1
    while threshold(forLevel: level + 1) <= xp { level += 1 }
    return level
  }
}

struct AchievementContext {
  var venture = 1
  var careerMode: CareerMode = .bounded
  var doctrine: FounderDoctrine = .guided
  var outcomeKind: CareerOutcomeKind?
  var careerScore = 0
  var completedObjectives = 0
  var allAgentsZeroDrift = false
  var ventureReviewRate = 0.0
  var runReviewRate = 0.0
  var overclaimsCaughtThisRun = 0
  var correlatedContainedThisVenture = 0
  var companyFlags: Set<CompanyFlag> = []
  var ventureHasUnaddressedOverclaim = false
}

struct AchievementSave: Codable {
  static let currentVersion = 2

  var version = currentVersion
  var unlocked: [String: Date] = [:]
  var totalXP = 0
  var doctrinesWon: Set<String> = []
  var lifetimeOverclaimsCaught = 0
  var didEvaluateRetroactively = false
  var unseenRetroactiveUnlockIDs: Set<String> = []

  private enum CodingKeys: String, CodingKey {
    case version, unlocked, totalXP, doctrinesWon, lifetimeOverclaimsCaught
    case didEvaluateRetroactively, unseenRetroactiveUnlockIDs
  }

  init() {}

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    unlocked = try container.decodeIfPresent([String: Date].self, forKey: .unlocked) ?? [:]
    totalXP = try container.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
    doctrinesWon = try container.decodeIfPresent(Set<String>.self, forKey: .doctrinesWon) ?? []
    lifetimeOverclaimsCaught = try container.decodeIfPresent(Int.self, forKey: .lifetimeOverclaimsCaught) ?? 0
    didEvaluateRetroactively = try container.decodeIfPresent(Bool.self, forKey: .didEvaluateRetroactively) ?? false
    unseenRetroactiveUnlockIDs = try container.decodeIfPresent(Set<String>.self, forKey: .unseenRetroactiveUnlockIDs) ?? []
  }
}

struct AchievementProgress: Equatable {
  var current: Double
  var target: Double
  var label: String
  var fraction: Double { min(max(current / max(target, 1), 0), 1) }
}

struct AchievementDisplayContext {
  var venture: Int
  var careerScore: Int
  var completedObjectives: Int
  var currentRunOverclaims: Int
  var reviewRate: Double
}

@MainActor
@Observable
final class AchievementStore {
  private(set) var save = AchievementSave()
  private(set) var latestUnlock: Achievement?
  private var defaults: UserDefaults
  private let saveKey = "solo-achievements-v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: saveKey),
       let decoded = try? JSONDecoder().decode(AchievementSave.self, from: data) {
      save = decoded
    }
  }

  var totalXP: Int { save.totalXP }
  var level: Int { FounderLevel.level(forXP: totalXP) }
  var xpIntoCurrentLevel: Int { totalXP - FounderLevel.threshold(forLevel: level) }
  var xpForNextLevel: Int { FounderLevel.threshold(forLevel: level + 1) - FounderLevel.threshold(forLevel: level) }
  var levelProgress: Double { xpForNextLevel > 0 ? Double(xpIntoCurrentLevel) / Double(xpForNextLevel) : 1 }
  var unlockedCount: Int { save.unlocked.count }

  func isUnlocked(_ id: String) -> Bool { save.unlocked[id] != nil }
  func unlockDate(_ id: String) -> Date? { save.unlocked[id] }
  func isRetroactivelyNew(_ id: String) -> Bool { save.unseenRetroactiveUnlockIDs.contains(id) }

  func markRetroactiveUnlocksSeen() {
    guard !save.unseenRetroactiveUnlockIDs.isEmpty else { return }
    save.unseenRetroactiveUnlockIDs.removeAll()
    persist()
  }

  func progress(for achievement: Achievement, context: AchievementDisplayContext) -> AchievementProgress? {
    guard !isUnlocked(achievement.id) else { return nil }
    switch achievement.id {
    case "first-venture": return progress(context.venture, 2, label: "Venture progress")
    case "reach-traction": return progress(context.venture, 11, label: "Ventures reached")
    case "reach-scale": return progress(context.venture, 21, label: "Ventures reached")
    case "reach-leader": return progress(context.venture, 31, label: "Ventures reached")
    case "reach-empire": return progress(context.venture, 41, label: "Ventures reached")
    case "reach-dynasty", "independent": return progress(context.venture, 60, label: "Ventures reached")
    case "score-10k": return progress(context.careerScore, 10_000, label: "Career score")
    case "triple-crown": return progress(save.doctrinesWon.count, 3, label: "Doctrines won")
    case "objective-10": return progress(context.completedObjectives, 10, label: "Objectives completed")
    case "objective-30": return progress(context.completedObjectives, 30, label: "Objectives completed")
    case "first-catch": return progress(max(save.lifetimeOverclaimsCaught, context.currentRunOverclaims), 1, label: "Overclaims caught")
    case "auditor": return progress(max(save.lifetimeOverclaimsCaught, context.currentRunOverclaims), 10, label: "Overclaims caught")
    case "truth-seeker": return progress(context.reviewRate * 100, 70, label: "Review rate")
    default: return nil
    }
  }

  func recordFacilityProgress(purchasedUpgradeCount: Int, ownsLoft: Bool, capital: Int) {
    var unlocked: [Achievement] = []
    func award(_ id: String, when condition: Bool) {
      guard condition, save.unlocked[id] == nil, let achievement = AchievementCatalog.by(id) else { return }
      save.unlocked[id] = Date()
      save.totalXP += achievement.xp
      unlocked.append(achievement)
    }
    award("out-of-garage", when: ownsLoft)
    award("built-different", when: purchasedUpgradeCount >= 3)
    award("fully-loaded-garage", when: purchasedUpgradeCount == FacilityUpgradeID.allCases.count)
    award("cash-discipline", when: ownsLoft && capital >= 1_500)
    if let first = unlocked.first { latestUnlock = first }
    if !unlocked.isEmpty { persist() }
  }

  func recordWorkforce(_ agents: [SoloAgent]) {
    let completed = Set(agents.filter(\.progression.ambitionCompleted).map(\.id))
    let levels = agents.map(\.progression.level)
    let hasPerk = agents.contains { !$0.progression.selectedPerks.isEmpty }
    let recoveredCritical = agents.contains { $0.progression.stressLevel < 75 && $0.progression.recoveredFailures > 0 }
    var unlocked: [Achievement] = []
    func award(_ id: String, _ condition: Bool) {
      guard condition, save.unlocked[id] == nil, let achievement = AchievementCatalog.by(id) else { return }
      save.unlocked[id] = Date()
      save.totalXP += achievement.xp
      unlocked.append(achievement)
    }
    award("first-promotion", levels.contains(where: { $0 >= 5 }))
    award("specialist", hasPerk)
    award("full-team-development", agents.count >= 3 && levels.allSatisfy { $0 >= 5 })
    award("trusted-advisor", completed.contains("aurora"))
    award("systems-architect", completed.contains("stacks"))
    award("category-creator", completed.contains("brio"))
    award("calm-under-pressure", recoveredCritical)
    if let first = unlocked.first { latestUnlock = first }
    if !unlocked.isEmpty { persist() }
  }

  @discardableResult
  func recordReveal(context: AchievementContext) -> [Achievement] { evaluate(context) }

  @discardableResult
  func recordVentureCommit(context: AchievementContext) -> [Achievement] { evaluate(context) }

  @discardableResult
  func closeRun(context: AchievementContext) -> [Achievement] {
    save.totalXP += max(0, context.careerScore / 50)
    save.lifetimeOverclaimsCaught += max(0, context.overclaimsCaughtThisRun)
    if context.outcomeKind == .victory { save.doctrinesWon.insert(context.doctrine.rawValue) }
    let unlocked = evaluate(context)
    persist()
    return unlocked
  }

  @discardableResult
  func evaluateRetroactive(save careerSave: CareerSave) -> [Achievement] {
    guard !save.didEvaluateRetroactively else { return [] }
    self.save.didEvaluateRetroactively = true
    var context = AchievementContext(
      venture: careerSave.venture,
      careerMode: careerSave.careerMode,
      doctrine: careerSave.doctrine,
      outcomeKind: careerSave.outcome?.kind,
      careerScore: careerSave.outcome?.score ?? SimulationEngine.careerScore(stats: careerSave.stats),
      completedObjectives: careerSave.completedObjectives,
      companyFlags: careerSave.companyFlags
    )
    context.ventureReviewRate = reviewRate(in: careerSave.evidence.filter { $0.venture == careerSave.venture })
    context.runReviewRate = reviewRate(in: careerSave.evidence)
    context.overclaimsCaughtThisRun = careerSave.evidence.filter { $0.verificationState == .overclaimed }.count
    if context.outcomeKind == .victory { self.save.doctrinesWon.insert(context.doctrine.rawValue) }
    let unlocked = evaluate(context, announces: false)
    save.unseenRetroactiveUnlockIDs.formUnion(unlocked.map(\.id))
    persist()
    return unlocked
  }

  @discardableResult
  private func evaluate(_ context: AchievementContext, announces: Bool = true) -> [Achievement] {
    var unlocked: [Achievement] = []
    func award(_ id: String, when condition: Bool) {
      guard condition, save.unlocked[id] == nil, let achievement = AchievementCatalog.by(id) else { return }
      save.unlocked[id] = Date()
      save.totalXP += achievement.xp
      unlocked.append(achievement)
    }

    let won = context.outcomeKind == .victory
    let failed = context.outcomeKind == .bankruptcy || context.outcomeKind == .burnout || context.outcomeKind == .trustCollapse
    award("first-venture", when: context.venture >= 2 || context.outcomeKind != nil)
    award("career-complete", when: won && context.careerMode == .bounded)
    award("reach-traction", when: context.venture >= 11)
    award("reach-scale", when: context.venture >= 21)
    award("reach-leader", when: context.venture >= 31)
    award("reach-empire", when: context.venture >= 41)
    award("reach-dynasty", when: context.venture >= 60)
    award("score-10k", when: context.careerScore >= 10_000)
    award("win-pure", when: won && context.doctrine == .pure)
    award("win-guided", when: won && context.doctrine == .guided)
    award("win-trust", when: won && context.doctrine == .trust)
    award("triple-crown", when: save.doctrinesWon.count >= 3)
    award("zero-drift", when: context.allAgentsZeroDrift)
    award("objective-10", when: context.completedObjectives >= 10)
    award("objective-30", when: context.completedObjectives >= 30)
    award("flawless-venture", when: context.ventureReviewRate >= 1)
    award("first-catch", when: context.overclaimsCaughtThisRun >= 1 || save.lifetimeOverclaimsCaught >= 1)
    award("auditor", when: save.lifetimeOverclaimsCaught >= 10)
    award("truth-seeker", when: context.outcomeKind != nil && context.runReviewRate >= 0.7)
    award("storm-breaker", when: context.correlatedContainedThisVenture >= 3)
    award("clean-ledger", when: context.ventureReviewRate >= 1 && !context.ventureHasUnaddressedOverclaim)
    award("trusted-house", when: context.venture >= 21 && context.overclaimsCaughtThisRun >= 5)
    award("acquired", when: context.companyFlags.contains(.acquisitionAccepted))
    award("licensed", when: context.companyFlags.contains(.licensedTechnology))
    award("independent", when: context.venture >= 60 && context.companyFlags.contains(.bootstrapIndependent))
    award("survivor", when: failed)
    award("people-first", when: won && context.companyFlags.contains(.humanCustomerSuccess))

    if announces, let first = unlocked.first { latestUnlock = first }
    if !unlocked.isEmpty { persist() }
    return unlocked
  }

  private func reviewRate(in evidence: [EvidenceEntry]) -> Double {
    guard !evidence.isEmpty else { return 0 }
    return Double(evidence.filter(\.reviewed).count) / Double(evidence.count)
  }

  private func progress(_ current: Int, _ target: Int, label: String) -> AchievementProgress? {
    guard current > 0 else { return nil }
    return AchievementProgress(current: Double(current), target: Double(target), label: label)
  }

  private func progress(_ current: Double, _ target: Double, label: String) -> AchievementProgress? {
    guard current > 0 else { return nil }
    return AchievementProgress(current: current, target: target, label: label)
  }

  private func persist() {
    save.version = AchievementSave.currentVersion
    if let data = try? JSONEncoder().encode(save) { defaults.set(data, forKey: saveKey) }
  }
}
