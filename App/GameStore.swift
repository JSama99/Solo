import Foundation
import Observation

@MainActor
@Observable
final class GameStore {
  enum Stage: Equatable {
    case title
    case modeSelect
    case setup
    case game
    case ventureUnlock
    case ventureCheckpoint
    case outcome
  }

  var stage: Stage = .title
  var founderName = ""
  var selectedDoctrine: FounderDoctrine = .guided
  var doctrine: FounderDoctrine = .guided
  var selectedProductType: ProductType = .saas
  var productType: ProductType = .saas
  var selectedCareerMode: CareerMode = .bounded
  var sprint = 1
  var venture = 1
  private(set) var intent: SprintIntent = .build
  var stats = FounderStats()
  var agents = ContentLibrary.initialAgents
  /// The three commitments selected for the sprint.
  var tasks: [SoloTask] = []
  /// Two additional opportunities the player deliberately leaves behind.
  var taskBacklog: [SoloTask] = []
  /// Founder Attention now pays for reviews, rework, and cross-checks.
  private(set) var founderAttentionSpent = 0
  private(set) var activeDilemma: FounderDilemma?
  private(set) var selectedDilemmaChoiceID: String?
  private(set) var currentObjective: SprintObjective?
  var evidence: [EvidenceEntry] = []
  var report: SprintReport?
  var careerOutcome: CareerOutcome?
  var alertMessage: String?
  var randomNumberGenerator = SeededRandomNumberGenerator(seed: 0)
  var correlatedFailureEvent: CorrelatedFailureEvent?
  var pendingEffects: [ScheduledEffect] = []
  var reportCache: [CachedTaskReport] = []
  var dailyChallengeStore = DailyChallengeStore()
  var achievementStore: AchievementStore?
  /// Persistent headquarters progression is intentionally separate from the
  /// deterministic career save. It never consumes the simulation RNG.
  var progressionStore: FounderProgressionStore?
  private(set) var workforceNotifications: [String] = []
  var techComHeadlines: [TechComHeadline] = []
  var techComRivals: [TechComRival] = []
  private(set) var talentBoardRefreshes = 0

  // ── Build 3: career layer ─────────────────────────────────────────
  /// Precedents banked across the career. Recorded in every venture,
  /// including the free one — that is what makes the unlock meaningful.
  var precedents: [Precedent] = []
  /// Recall surfaced for the current sprint, if any. Presentation-only.
  private(set) var activeRecall: HindsightRecall?
  private(set) var recallsShownThisVenture = 0
  /// Set when Venture 1 ends without the Founder Pass. The career is intact
  /// and resumes on unlock; nothing is discarded.
  private(set) var awaitingFounderPass = false

  // ── Build 5: continuous mode ────────────────────────────────────────
  /// How long this career runs. Set once at creation; existing saves default
  /// to `.bounded` on migration and never change mode retroactively.
  private(set) var careerMode: CareerMode = .bounded
  /// A non-terminal "venture complete" moment, continuous mode only. Bounded
  /// mode never populates this — it goes straight to `careerOutcome`.
  private(set) var pendingVentureCheckpoint: VentureCheckpoint?

  // ── Build 6: persistent company story ───────────────────────────────
  private(set) var companyFlags: Set<CompanyFlag> = []
  private(set) var activeObligations: [CompanyObligation] = []
  private(set) var decisionHistory: [CareerDecisionRecord] = []
  private(set) var completedObjectives = 0

  /// Supplies entitlement state. Replaceable so the simulation stays testable
  /// without RevenueCat, StoreKit, or a network.
  var entitlements: any EntitlementProviding = StaticEntitlementProvider()

  var hasFounderPass: Bool { entitlements.hasFounderPass }

  /// Venture 2 is the paid content. Venture 1 is complete and free.
  var isVentureLocked: Bool { awaitingFounderPass && !hasFounderPass }

  static var freeVentureCount: Int { 1 }
  static var totalVentures: Int { maximumVentures }
  static var sprintsPerVentureCount: Int { sprintsPerVenture }

  var hasSave: Bool {
    UserDefaults.standard.data(forKey: Self.saveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v11SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v10SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v9SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v8SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v7SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v6SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v5SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v4SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v3SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v2SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.legacySaveKey) != nil
  }

  var attentionMaximum: Int {
    DoctrineProfile.profile(for: doctrine).attentionMaximum
      + (sprint.isMultiple(of: 3) ? (progressionStore?.bonuses.periodicAttentionBonus ?? 0) : 0)
  }

  var facilityBonuses: FacilityBonuses { progressionStore?.bonuses ?? .none }

  var rivalStandings: [RivalStanding] {
    RivalEngine.standings(
      companies: ContentLibrary.rivalSimulationCompanies,
      venture: venture,
      sprint: sprint,
      careerSeed: RivalEngine.careerSeed(founderName: founderName, productType: productType),
      player: stats,
      playerFlags: companyFlags
    )
  }

  var nextTalentSlot: Int? { agents.count < 4 ? 4 : agents.count < 5 ? 5 : nil }

  var talentBoardCandidates: [TalentCandidate] {
    guard let slot = nextTalentSlot else { return [] }
    return TalentBoard.candidates(for: slot, excluding: Set(agents.map(\.id)), refresh: talentBoardRefreshes)
  }

  var talentBoardGateMessage: String? {
    guard let slot = nextTalentSlot else { return "Your roster is complete." }
    if slot == 4 {
      if careerMode == .bounded { return venture >= 2 ? nil : "Unlocks after the Venture 1 checkpoint." }
      return venture >= 6 ? nil : "Unlocks in Empire at Venture 6." }
    if careerMode == .bounded { return venture >= 2 ? nil : "Unlocks in Venture 2." }
    return venture >= 16 ? nil : "Unlocks in Empire at Venture 16." }

  func hire(_ candidate: TalentCandidate) {
    guard talentBoardGateMessage == nil, let slot = nextTalentSlot,
          talentBoardCandidates.contains(candidate), stats.capital >= candidate.price else {
      alertMessage = stats.capital < candidate.price ? "Not enough Capital for this hire." : talentBoardGateMessage
      return
    }
    guard (slot == 4 && TalentBoard.fourthSlotPriceRange.contains(candidate.price)) || (slot == 5 && TalentBoard.fifthSlotPriceRange.contains(candidate.price)) else { return }
    stats.capital -= candidate.price
    agents.append(candidate.makeAgent())
    achievementStore?.recordWorkforce(agents)
    save()
  }

  func refreshTalentBoard() {
    guard agents.count >= 4, nextTalentSlot != nil else { return }
    guard stats.capital >= TalentBoard.refreshCost else { alertMessage = "Refreshing the talent board costs \(TalentBoard.refreshCost) Capital."; return }
    stats.capital -= TalentBoard.refreshCost
    talentBoardRefreshes += 1
    save()
  }

  func availablePerks(for agentID: String) -> [AgentPerkID] {
    switch agentID {
    case "aurora": [.sourceTriangulation, .contradictionScan, .truthEngine, .signalDetection, .marketMemory, .strategicAdvisor]
    case "stacks": [.flowState, .rapidDelivery, .shippingMachine, .defensiveBuild, .recoveryProtocol, .resilientSystems]
    case "brio": [.conversionInstinct, .dealCloser, .revenueEngine, .claimDiscipline, .trustedVoice, .sustainableGrowth]
    default: []
    }
  }

  func selectAgentPerk(_ perk: AgentPerkID, for agentID: String) {
    guard let index = agents.firstIndex(where: { $0.id == agentID }), availablePerks(for: agentID).contains(perk) else { return }
    let requiredLevel = perkRequiredLevel(perk)
    guard agents[index].progression.level >= requiredLevel else { return }
    if let branch = agents[index].progression.specialization, branch != perk.branch { return }
    guard !agents[index].progression.selectedPerks.contains(perk) else { return }
    agents[index].progression.selectedPerks.insert(perk)
    workforceNotifications.append("\(agents[index].name) specialized in \(perk.branch).")
    achievementStore?.recordWorkforce(agents)
    save()
  }

  @discardableResult
  func purchaseFacility(_ tier: FacilityTier) -> FounderProgressionStore.PurchaseResult {
    guard let progressionStore else { return .futureEnvironment }
    let result = progressionStore.purchase(tier, availableCapital: stats.capital)
    if case .purchased(let cost) = result {
      stats.capital = max(0, stats.capital - cost)
      achievementStore?.recordFacilityProgress(
        purchasedUpgradeCount: progressionStore.purchasedUpgrades.count,
        ownsLoft: progressionStore.ownedFacilities.contains(.founderLoft),
        capital: stats.capital
      )
      save()
    }
    return result
  }

  @discardableResult
  func purchaseFacilityUpgrade(_ id: FacilityUpgradeID) -> FounderProgressionStore.PurchaseResult {
    guard let progressionStore else { return .futureEnvironment }
    let result = progressionStore.purchaseUpgrade(id, availableCapital: stats.capital)
    if case .purchased(let cost) = result {
      stats.capital = max(0, stats.capital - cost)
      achievementStore?.recordFacilityProgress(
        purchasedUpgradeCount: progressionStore.purchasedUpgrades.count,
        ownsLoft: progressionStore.ownedFacilities.contains(.founderLoft),
        capital: stats.capital
      )
      save()
    }
    return result
  }

  var attentionRemaining: Int {
    max(0, attentionMaximum - founderAttentionSpent)
  }

  var chapter: VentureChapter { .chapter(for: sprint) }

  var selectedDilemmaChoice: DilemmaChoice? {
    guard let activeDilemma, let selectedDilemmaChoiceID else { return nil }
    return activeDilemma.choices.first(where: { $0.id == selectedDilemmaChoiceID })
  }


  var sprintPhase: SprintPhase {
    if activeDilemma != nil && selectedDilemmaChoice == nil { return .founderEvent }
    if tasks.allSatisfy({ $0.assignedAgentID == nil }) { return .chooseCommitments }
    if tasks.filter({ $0.assignedAgentID != nil }).count < tasks.count { return .assignTeam }
    if tasks.contains(where: { !$0.isReviewed || !$0.resolutionLocked }) { return .reviewAndResolve }
    return .readyToCommit
  }

  var canCommitSprint: Bool {
    commitBlockerMessage == nil
  }

  var commitBlockerMessage: String? {
    let hasAssignment = tasks.contains { $0.assignedAgentID != nil }
    guard hasAssignment else {
      return "Assign at least one agent before committing the sprint."
    }
    guard activeDilemma == nil || selectedDilemmaChoice != nil else {
      return "Choose a response to the founder dilemma before committing."
    }
    if let unresolved = tasks.first(where: { $0.isReviewed && !$0.resolutionLocked }) {
      return "Choose how to resolve \(unresolved.title) before committing."
    }
    return nil
  }

  var averageRelationship: Int {
    guard !agents.isEmpty else { return 0 }
    return agents.map(\.relationship).reduce(0, +) / agents.count
  }

  var venturePressureSummary: String {
    let era = VentureEra.era(for: venture)
    if careerMode == .continuous {
      return "\(era.name) era • \(era.newForce) • -\(era.runwayBurnPerSprint) Runway, -\(era.energyCostPerSprint) Energy"
    }
    return "Operating pressure: -\(era.runwayBurnPerSprint) Runway and -\(era.energyCostPerSprint) Energy per sprint"
  }

  var objectiveProgressText: String {
    guard let objective = currentObjective else { return "No objective" }
    let assigned = tasks.filter { $0.assignedAgentID != nil }
    switch objective.kind {
    case .evidenceFirst:
      return "\(tasks.filter(\.isReviewed).count)/2 reviews completed"
    case .diversifiedModels:
      let families = Set<String>(assigned.compactMap { task in
        guard let id = task.assignedAgentID else { return nil }
        return agents.first(where: { $0.id == id })?.modelFamily
      })
      return "\(families.count)/2 model families • role fit required"
    case .roleDiscipline:
      let fit = assigned.filter { task in
        guard let id = task.assignedAgentID, let agent = agents.first(where: { $0.id == id }) else { return false }
        return agent.role == task.role || agent.role == .general || task.role == .general
      }.count
      return "\(fit)/3 role-fit assignments"
    case .protectFounder:
      return "\(founderAttentionSpent)/1 Attention used"
    case .calculatedRisk:
      return tasks.contains(where: { $0.resolution == .shipAnyway }) ? "Aggressive shipment selected" : "Ship one reviewed result aggressively"
    case .repairTrust:
      guard let targetID = objective.targetAgentID,
            let agent = agents.first(where: { $0.id == targetID }) else { return "Stabilize the named agent" }
      return "\(agent.name) drift: \(Int(agent.drift))"
    }
  }

  var unlockedGarageUpgrades: [GarageUpgrade] {
    var upgrades: [GarageUpgrade] = []
    if sprint >= 2 || venture > 1 { upgrades.append(.strategyWall) }
    if stats.revenue >= 1_500 { upgrades.append(.customerMap) }
    if evidence.count >= 4 { upgrades.append(.evidenceShelf) }
    if stats.trackRecord >= 8 || venture > 1 { upgrades.append(.operationsRack) }
    if sprint >= 6 || venture > 1 { upgrades.append(.recoveryCorner) }
    return upgrades
  }

  var averageDrift: Int {
    guard !agents.isEmpty else { return 0 }
    return Int(agents.map(\.drift).reduce(0, +) / Double(agents.count))
  }

  var garageCondition: String {
    if averageDrift >= 60 || stats.trust <= 24 { return "Critical" }
    if averageDrift >= 35 || stats.energy <= 38 { return "Strained" }
    return "Steady"
  }

  func beginSetup() {
    founderName = ""
    selectedDoctrine = .guided
    selectedProductType = .saas
    selectedCareerMode = .bounded
    stage = .setup
  }

  func beginModeSelection() {
    stage = .modeSelect
  }

  func startMode(_ mode: CareerMode) {
    if mode == .daily {
      startDailyChallenge()
      return
    }
    founderName = ""
    selectedDoctrine = .guided
    selectedCareerMode = mode
    stage = .setup
  }

  func startCareer(seed: UInt64? = nil) {
    doctrine = selectedDoctrine
    productType = selectedProductType
    careerMode = selectedCareerMode
    founderName = founderName.trimmingCharacters(in: .whitespacesAndNewlines)
    if founderName.isEmpty { founderName = "Founder" }
    sprint = 1
    venture = 1
    precedents = []
    activeRecall = nil
    recallsShownThisVenture = 0
    awaitingFounderPass = false
    pendingVentureCheckpoint = nil
    companyFlags = []
    activeObligations = []
    decisionHistory = []
    completedObjectives = 0
    recentTaskTitles = []
    taskDeckTitles = []
    dilemmaDeckTemplateIDs = []
    dilemmaDeckChapter = nil
    recentObjectiveKinds = []
    intent = .build
    stats = FounderStats()
    agents = ContentLibrary.initialAgents
    taskBacklog = []
    founderAttentionSpent = 0
    activeDilemma = nil
    selectedDilemmaChoiceID = nil
    currentObjective = nil
    evidence = []
    careerOutcome = nil
    report = nil
    pendingEffects = []
    reportCache = []
    techComHeadlines = []
    techComRivals = TechComEngine.rivals(seed: seed ?? 0x534F4C4F)
    talentBoardRefreshes = 0
    randomNumberGenerator = SeededRandomNumberGenerator(seed: seed ?? UInt64.random(in: .min ... .max))
    let startingAdjustment = DoctrineProfile.profile(for: doctrine).startingStatAdjustment
    stats.trust += startingAdjustment.trust
    stats.momentum += startingAdjustment.momentum
    stats.energy += startingAdjustment.energy
    prepareSprint()
    stage = .game
    sanitizeState()
    if careerMode != .daily { save() }
  }

  func startDailyChallenge() {
    guard !dailyChallengeStore.isCompletedToday else {
      alertMessage = "Today's challenge is complete. Come back tomorrow for a new shared seed."
      return
    }
    selectedCareerMode = .daily
    selectedDoctrine = .guided
    selectedProductType = .saas
    founderName = "Daily Founder"
    startCareer(seed: DailyChallenge.seed())
  }

  func continueCareer() {
    let decoder = JSONDecoder()
    var loadedSave: CareerSave?

    if let data = UserDefaults.standard.data(forKey: Self.saveKey),
       let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
       envelope.version == Self.saveVersion {
      loadedSave = envelope.career
    } else if let data = UserDefaults.standard.data(forKey: Self.v11SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 11 {
      loadedSave = migrateV11(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v10SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 10 {
      loadedSave = migrateV10(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v9SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 9 {
      loadedSave = migrateV9(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v8SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 8 {
      loadedSave = migrateV8(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v7SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 7 {
      loadedSave = migrateV7(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v6SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 6 {
      loadedSave = migrateV6(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v5SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 5 {
      loadedSave = migrateV5(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v4SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 4 {
      loadedSave = migrateV4(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v3SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 3 {
      loadedSave = migrateV3(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v2SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 2 {
      loadedSave = migrateV2(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.legacySaveKey),
              let legacy = try? decoder.decode(CareerSave.self, from: data) {
      loadedSave = migrateV1(legacy)
    }

    guard let loadedSave else {
      beginSetup()
      return
    }
    apply(loadedSave)
    achievementStore?.evaluateRetroactive(save: loadedSave)
    saveCareer()
  }

  @discardableResult
  func setIntent(_ newIntent: SprintIntent) -> Bool {
    guard newIntent != intent else { return true }
    guard tasks.allSatisfy({ $0.assignedAgentID == nil }) else {
      alertMessage = "Clear all assignments to change sprint intent."
      return false
    }
    intent = newIntent
    save()
    return true
  }

  /// Replaces one of the three active commitments with an opportunity from the
  /// backlog. Drafting closes as soon as any agent starts work.
  @discardableResult
  func swapDraftTask(activeTaskID: UUID, backlogTaskID: UUID) -> Bool {
    guard tasks.allSatisfy({ $0.assignedAgentID == nil && !$0.isReviewed }) else {
      alertMessage = "Clear assignments before changing the sprint draft."
      return false
    }
    guard
      let activeIndex = tasks.firstIndex(where: { $0.id == activeTaskID }),
      let backlogIndex = taskBacklog.firstIndex(where: { $0.id == backlogTaskID })
    else { return false }
    let removed = tasks.remove(at: activeIndex)
    let promoted = taskBacklog.remove(at: backlogIndex)
    tasks.insert(promoted, at: min(activeIndex, tasks.count))
    taskBacklog.insert(removed, at: min(backlogIndex, taskBacklog.count))
    reportCache = []
    save()
    return true
  }

  func selectDilemmaChoice(_ choiceID: String) {
    guard let activeDilemma, activeDilemma.choices.contains(where: { $0.id == choiceID }) else { return }
    selectedDilemmaChoiceID = choiceID
    save()
  }

  func agentDialogue(for agentID: String) -> String {
    guard let agent = agents.first(where: { $0.id == agentID }) else { return "Standing by." }
    if let dilemma = activeDilemma, dilemma.featuredAgentID == agentID {
      return "I need your call on \"\(dilemma.title).\""
    }
    if let task = tasks.first(where: { $0.assignedAgentID == agentID }) {
      if task.isReviewed, let state = task.result?.verificationState {
        switch state {
        case .overclaimed: return "The report ran ahead of the evidence. Decide whether we fix it or take the risk."
        case .driftDetected: return "That model-family signal is real. I recommend a cross-check."
        case .evidenceIncomplete: return "I cannot defend the actual result yet. We need more evidence."
        case .confirmed, .verified: return "The work holds up. I am ready for your final call."
        case .reported, .unverified: break
        }
      }
      switch agent.id {
      case "aurora": return "I am testing the assumptions behind \(task.title.lowercased())."
      case "stacks": return "I have \(task.title.lowercased()) in motion. Please do not move the target."
      case "brio": return "There is momentum in \(task.title.lowercased()). Let me push it."
      default: return "Working on \(task.title)."
      }
    }
    if agent.drift >= 50 {
      return "My outputs are getting noisy. I need a narrower brief or a review."
    }
    if agent.progression.stressBand == .critical {
      return "I can still help, but this pace is no longer sustainable. Give me one recovery sprint."
    }
    if agent.progression.stressBand == .overloaded {
      return "The workload is compressing my margin for error. Narrow the brief or rotate me out."
    }
    if let specialization = agent.progression.specialization {
      return "My \(specialization) practice is ready for a problem that fits it."
    }
    if agent.progression.level >= 2 {
      return "I have learned enough to choose the kind of partner this company needs me to become."
    }
    if agent.relationship >= 75 {
      return "We are aligned. Give me the next hard problem."
    }
    return "\(agent.ambition)"
  }

  func assign(agentID: String?, to taskID: UUID) {
    sanitizeState()
    guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    guard !tasks[taskIndex].isReviewed else {
      alertMessage = "Verified work is locked for this sprint."
      return
    }

    if let agentID {
      if let lockedTask = tasks.first(where: {
        $0.assignedAgentID == agentID && $0.isReviewed && $0.id != taskID
      }) {
        alertMessage = "\(lockedTask.title) has already been verified with this agent."
        return
      }
      for index in tasks.indices where tasks[index].assignedAgentID == agentID && index != taskIndex {
        tasks[index].assignedAgentID = nil
        tasks[index].result = nil
      }
      tasks[taskIndex].assignedAgentID = agentID
      if let agent = agents.first(where: { $0.id == agentID }) {
        if let cached = cachedReport(taskID: taskID, agentID: agentID) {
          tasks[taskIndex].result = cached
        } else {
          let result = SimulationEngine.makeResult(
            for: tasks[taskIndex], agent: agent, intent: intent, doctrine: doctrine,
            correlatedFailureEvent: correlatedFailureEvent, allTasks: tasks, allAgents: agents,
            facilityBonuses: facilityBonuses,
            rng: &randomNumberGenerator
          )
          tasks[taskIndex].result = result
          reportCache.append(
            CachedTaskReport(
              venture: venture,
              sprint: sprint,
              taskID: taskID,
              agentID: agentID,
              intent: intent,
              result: result
            )
          )
        }
      }
    } else {
      tasks[taskIndex].assignedAgentID = nil
      tasks[taskIndex].result = nil
    }
    updateKnownOperationalRisks()
    syncAssignments()
    save()
  }

  func toggleReview(taskID: UUID) {
    review(taskID: taskID)
  }

  func review(taskID: UUID) {
    guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    guard !tasks[taskIndex].isReviewed else { return }
    guard attentionRemaining > 0 else {
      alertMessage = "No Founder Attention remains this sprint."
      return
    }
    guard
      let agentID = tasks[taskIndex].assignedAgentID,
      let agentIndex = agents.firstIndex(where: { $0.id == agentID }),
      var result = tasks[taskIndex].result
    else {
      alertMessage = "Assign an agent before reviewing its report."
      return
    }

    let state = result.verify()
    tasks[taskIndex].result = result
    tasks[taskIndex].isReviewed = true
    tasks[taskIndex].resolution = .approve
    tasks[taskIndex].resolutionLocked = false
    founderAttentionSpent += 1
    let reviewEnergy = DoctrineProfile.profile(for: doctrine).reviewEnergyCost
    stats.energy = clamped(stats.energy - reviewEnergy)
    agents[agentIndex].calibration = min(1, agents[agentIndex].calibration + 0.035)
    agents[agentIndex].drift = max(0, agents[agentIndex].drift - 9)
    switch state {
    case .confirmed:
      agents[agentIndex].trust = min(100, agents[agentIndex].trust + 5)
      agents[agentIndex].relationship = clamped(agents[agentIndex].relationship + 2)
    case .verified:
      agents[agentIndex].trust = min(100, agents[agentIndex].trust + 2)
      agents[agentIndex].relationship = clamped(agents[agentIndex].relationship + 1)
    case .overclaimed, .driftDetected:
      agents[agentIndex].trust = max(0, agents[agentIndex].trust - 2)
      agents[agentIndex].relationship = clamped(agents[agentIndex].relationship - 1)
    case .evidenceIncomplete:
      agents[agentIndex].trust = max(0, agents[agentIndex].trust - 1)
    case .reported, .unverified:
      break
    }
    recordEvidence(task: tasks[taskIndex], agent: agents[agentIndex], result: result)
    achievementStore?.recordReveal(context: achievementContext)
    sanitizeState()
    save()
  }

  /// Converts a review into a consequential founder decision. Rework and
  /// cross-check consume the remaining attention budget; shipping anyway
  /// creates a faster payoff with delayed exposure.
  func resolveReviewedTask(taskID: UUID, choice: TaskResolutionChoice) {
    guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    guard tasks[taskIndex].isReviewed, var result = tasks[taskIndex].result else {
      alertMessage = "Review the report before choosing a resolution."
      return
    }
    guard !tasks[taskIndex].resolutionLocked else {
      alertMessage = "That founder decision is already locked."
      return
    }
    guard
      let agentID = tasks[taskIndex].assignedAgentID,
      let agentIndex = agents.firstIndex(where: { $0.id == agentID })
    else { return }

    switch choice {
    case .approve:
      tasks[taskIndex].resolution = .approve
    case .rework:
      guard attentionRemaining > 0 else {
        alertMessage = "No Founder Attention remains for rework."
        return
      }
      guard stats.energy >= 4, stats.runway >= 1 else {
        alertMessage = "Rework needs 4 Energy and 1 day of Runway."
        return
      }
      founderAttentionSpent += 1
      stats.energy -= 4
      stats.runway -= 1
      result.applyFounderRework()
      agents[agentIndex].calibration = min(1, agents[agentIndex].calibration + 0.025)
      agents[agentIndex].relationship = clamped(agents[agentIndex].relationship + 2)
      tasks[taskIndex].resolution = .rework
    case .shipAnyway:
      result.applyShipAnyway()
      agents[agentIndex].drift = min(100, agents[agentIndex].drift + 5)
      agents[agentIndex].trust = max(0, agents[agentIndex].trust - 3)
      agents[agentIndex].relationship = clamped(agents[agentIndex].relationship + (agentID == "brio" ? 2 : -2))
      tasks[taskIndex].resolution = .shipAnyway
    case .escalate:
      guard attentionRemaining > 0 else {
        alertMessage = "No Founder Attention remains for a cross-check."
        return
      }
      let hasIndependentFamily = agents.contains {
        $0.id != agentID && $0.modelFamily != agents[agentIndex].modelFamily
      }
      guard hasIndependentFamily else {
        alertMessage = "A cross-check needs another available model family."
        return
      }
      founderAttentionSpent += 1
      stats.energy = max(0, stats.energy - 2)
      result.applyCrossCheck()
      agents[agentIndex].drift = max(0, agents[agentIndex].drift - 5)
      agents[agentIndex].relationship = clamped(agents[agentIndex].relationship + 1)
      tasks[taskIndex].resolution = .escalate
    }

    tasks[taskIndex].result = result
    tasks[taskIndex].resolutionLocked = true
    recordEvidence(task: tasks[taskIndex], agent: agents[agentIndex], result: result)
    sanitizeState()
    save()
  }

  func commitSprint() {
    sanitizeState()
    let assignedIndices = tasks.indices.filter { tasks[$0].assignedAgentID != nil }
    if let blocker = commitBlockerMessage {
      alertMessage = blocker
      return
    }

    let dilemmaChoice = selectedDilemmaChoice
    let uncommittedTasks = taskBacklog + tasks.filter { $0.assignedAgentID == nil }
    let skippedConsequences = uncommittedTasks.reduce(SimulationEffects()) { $0 + $1.skipEffects }

    let dueEffects = pendingEffects.filter { $0.dueCareerSprint <= careerSprintIndex }
    pendingEffects.removeAll { $0.dueCareerSprint <= careerSprintIndex }
    var effects = dueEffects.reduce(SimulationEffects()) { $0 + $1.effects }
    applyActiveObligations(to: &effects)
    effects = effects + skippedConsequences
    var acquisitionAccepted = false
    if let dilemmaChoice, let activeDilemma {
      effects = effects + dilemmaChoice.effects
      acquisitionAccepted = applyPersistentConsequence(dilemma: activeDilemma, choice: dilemmaChoice)
      for (agentID, delta) in dilemmaChoice.relationshipDeltas {
        if let index = agents.firstIndex(where: { $0.id == agentID }) {
          agents[index].relationship = clamped(agents[index].relationship + delta)
        }
      }
    }
    let era = VentureEra.era(for: venture)
    effects.runway -= era.runwayBurnPerSprint
    effects.energy -= era.energyCostPerSprint
    switch intent {
    case .build:
      effects.momentum += 3
      effects.energy -= 1
    case .learn:
      effects.trust += 3
      effects.momentum -= 1
    case .sell:
      effects.revenue += 180
    }

    var strongOutcomes = 0
    var riskyOutcomes = 0
    for index in assignedIndices {
      guard
        let agentID = tasks[index].assignedAgentID,
        let agentIndex = agents.firstIndex(where: { $0.id == agentID }),
        var result = tasks[index].result
      else { continue }

      effects = effects + result.immediateEffects
      if facilityBonuses.marketingRevenueMultiplier > 1,
         tasks[index].category == .sales,
         result.immediateEffects.revenue > 0 {
        effects.revenue += Int((Double(result.immediateEffects.revenue)
          * (facilityBonuses.marketingRevenueMultiplier - 1)).rounded())
      }
      if result.delayedEffects != SimulationEffects() {
        pendingEffects.append(
          ScheduledEffect(
            dueCareerSprint: careerSprintIndex + 1,
            source: tasks[index].title,
            effects: result.delayedEffects
          )
        )
      }
      if tasks[index].isReviewed && result.isStrongForSimulation { strongOutcomes += 1 }
      if result.evidenceCompleteness < 45 || result.correlatedFailureIdentifier != nil {
        riskyOutcomes += 1
      }

      if result.correlatedFailureIdentifier != nil {
        agents[agentIndex].drift = min(100, agents[agentIndex].drift + 5)
        agents[agentIndex].trust = max(0, agents[agentIndex].trust - 2)
      }

      if !tasks[index].isReviewed {
        result.markUnverified()
        tasks[index].result = result
        let driftIncrease = DoctrineProfile.profile(for: doctrine).neglectDriftIncrease
        agents[agentIndex].drift = min(100, agents[agentIndex].drift + driftIncrease)
        agents[agentIndex].trust = max(0, agents[agentIndex].trust - (result.isRiskyForSimulation ? 5 : 2))
        recordEvidence(task: tasks[index], agent: agents[agentIndex], result: result)
      }
      recordAgentProgress(for: agentIndex, task: tasks[index], result: result)
    }

    recoverUnassignedAgents(assignedIDs: Set(assignedIndices.compactMap { tasks[$0].assignedAgentID }))
    achievementStore?.recordWorkforce(agents)

    let reviewed = assignedIndices.filter { tasks[$0].isReviewed }.count
    let objectiveCompleted = evaluateCurrentObjective(assignedIndices: assignedIndices, riskyOutcomes: riskyOutcomes)
    if objectiveCompleted, let currentObjective {
      effects = effects + currentObjective.reward
      completedObjectives += 1
    }

    let share = rivalStandings.first(where: \.isPlayer)?.marketShare ?? 0
    if effects.revenue > 0 {
      effects.revenue = Int((Double(effects.revenue) * RivalEngine.revenueMultiplier(marketShare: share, fieldSize: rivalStandings.count - 1)).rounded())
    }
    apply(effects)
    if facilityBonuses.sprintEnergyRecovery > 0 {
      stats.energy = min(100, stats.energy + facilityBonuses.sprintEnergyRecovery)
    }
    sanitizeState()
    report = SprintReport(
      sprint: sprint,
      headline: riskyOutcomes > 0
        ? "Progress carried hidden risk"
        : (strongOutcomes == assignedIndices.count ? "The team found its edge" : "Evidence shaped the outcome"),
      revenueDelta: effects.revenue,
      momentumDelta: effects.momentum,
      trustDelta: effects.trust,
      energyDelta: effects.energy,
      runwayDelta: effects.runway,
      reviewed: reviewed,
      strongOutcomes: strongOutcomes,
      riskyOutcomes: riskyOutcomes,
      chapterName: chapter.name,
      objectiveTitle: currentObjective?.title,
      objectiveCompleted: objectiveCompleted,
      dilemmaSummary: dilemmaChoice.map { "\($0.title): \($0.consequencePreview)" },
      skippedTasks: uncommittedTasks.count
    )

    recordPrecedentIfConsequential(
      assignedIndices: assignedIndices,
      effects: effects,
      reviewedCount: reviewed
    )

    careerOutcome = acquisitionAccepted ? acquisitionOutcome() : resolvedOutcome()
    if careerMode == .daily, careerOutcome != nil {
      dailyChallengeStore.record(score: careerScore)
    }
    let runLength = careerMode == .daily ? DailyChallenge.sprintsPerRun : Self.sprintsPerVenture
    if careerOutcome == nil && sprint == runLength {
      achievementStore?.recordVentureCommit(context: achievementContext)
      switch careerMode {
      case .daily:
        careerOutcome = dailyVictoryOutcome()
        dailyChallengeStore.record(score: careerScore)
      case .bounded:
        if venture >= Self.freeVentureCount && !hasFounderPass {
          awaitingFounderPass = true
          report = nil
          stage = .ventureUnlock
          saveCareer()
          return
        }
        advanceToNextVenture()
      case .continuous:
        // Every continuous venture reaches its checkpoint first. The player
        // may always retire; Founder Pass gates only the Continue decision.
        presentVentureCheckpoint()
      }
    } else if careerOutcome == nil {
      sprint += 1
      prepareSprint()
    }
    if careerOutcome != nil {
      achievementStore?.closeRun(context: achievementContext)
    }
    saveCareer()
  }

  /// Called when the Founder Pass becomes active while a career is held at the
  /// venture gate. Idempotent and safe to call on every entitlement change.
  func resumeAfterFounderPassUnlock() {
    guard awaitingFounderPass, hasFounderPass else { return }
    awaitingFounderPass = false
    if pendingVentureCheckpoint != nil {
      pendingVentureCheckpoint = nil
    }
    advanceToNextVenture()
    stage = .game
    saveCareer()
  }

  private func advanceToNextVenture() {
    sprint = 1
    venture += 1
    recallsShownThisVenture = 0
    activeRecall = nil
    stats.trackRecord += max(8, (stats.momentum + stats.trust) / 8)
    let earnedRunwayRecovery = max(4, min(10, (stats.trust + stats.momentum) / 24))
    let earnedEnergyRecovery = max(6, min(14, averageRelationship / 8))
    stats.runway = min(365, stats.runway + earnedRunwayRecovery)
    stats.energy = min(100, stats.energy + earnedEnergyRecovery)
    stats.energy = min(100, stats.energy + facilityBonuses.ventureEnergyBonus)
    recentTaskTitles = []
    taskDeckTitles = []
    dilemmaDeckTemplateIDs = []
    dilemmaDeckChapter = nil
    prepareSprint()
  }

  /// Continuous mode only. Snapshots the just-completed venture into a
  /// non-terminal checkpoint and hands control to the player rather than
  /// silently rolling into the next set of 12 sprints.
  private func presentVentureCheckpoint() {
    let currentPrecedents = precedents.filter { $0.venture == venture }
    pendingVentureCheckpoint = VentureCheckpoint(
      venture: venture,
      trackRecordEarned: max(8, (stats.momentum + stats.trust) / 8),
      revenue: stats.revenue,
      trust: stats.trust,
      momentum: stats.momentum,
      precedentsBanked: currentPrecedents.count
    )
    report = nil
    stage = .ventureCheckpoint
  }

  /// The player's choice at a venture checkpoint: keep going.
  func continueFromCheckpoint() {
    guard careerMode == .continuous, pendingVentureCheckpoint != nil else { return }
    if venture >= Self.freeVentureCount && !hasFounderPass {
      awaitingFounderPass = true
      stage = .ventureUnlock
      saveCareer()
      return
    }
    pendingVentureCheckpoint = nil
    advanceToNextVenture()
    stage = .game
    saveCareer()
  }

  /// The player's choice at a venture checkpoint: stop here, on their own
  /// terms. Converts the checkpoint into a genuine `.victory` CareerOutcome
  /// -- a continuous career still gets to end, it just isn't forced to.
  func retireCareer() {
    guard careerMode == .continuous, pendingVentureCheckpoint != nil else { return }
    pendingVentureCheckpoint = nil
    careerOutcome = victoryOutcome()
    achievementStore?.closeRun(context: achievementContext)
    stage = .outcome
    saveCareer()
  }

  /// Bucketed snapshot of the conditions the current sprint is being run under.
  func currentPrecedentContext() -> PrecedentContext {
    PrecedentContext(
      doctrine: doctrine,
      intent: intent,
      driftBand: .drift(averageDrift),
      runwayBand: .runway(stats.runway),
      unverifiedBand: .unverified(tasks.filter { $0.assignedAgentID != nil && !$0.isReviewed }.count)
    )
  }

  private var achievementContext: AchievementContext {
    let ventureEvidence = evidence.filter { $0.venture == venture }
    let reviewRate = { (entries: [EvidenceEntry]) -> Double in
      guard !entries.isEmpty else { return 0 }
      return Double(entries.filter(\.reviewed).count) / Double(entries.count)
    }
    return AchievementContext(
      venture: venture,
      careerMode: careerMode,
      doctrine: doctrine,
      outcomeKind: careerOutcome?.kind,
      careerScore: careerOutcome?.score ?? careerScore,
      completedObjectives: completedObjectives,
      allAgentsZeroDrift: !agents.isEmpty && agents.allSatisfy { $0.drift == 0 },
      ventureReviewRate: reviewRate(ventureEvidence),
      runReviewRate: reviewRate(evidence),
      overclaimsCaughtThisRun: evidence.filter { $0.verificationState == .overclaimed }.count,
      correlatedContainedThisVenture: ventureEvidence.filter { $0.verificationState == .driftDetected }.count,
      companyFlags: companyFlags,
      ventureHasUnaddressedOverclaim: ventureEvidence.contains { $0.verificationState == .overclaimed }
    )
  }

  /// Surface a matching precedent for the live situation, if one clears the
  /// floor. Consumes no RNG and mutates no simulation value.
  func refreshHindsightRecall() {
    guard hasFounderPass else { activeRecall = nil; return }
    let recall = HindsightEngine.recall(
      from: precedents,
      matching: currentPrecedentContext(),
      currentVenture: venture,
      recallsAlreadyShown: recallsShownThisVenture
    )
    if let recall, activeRecall?.id != recall.id {
      recallsShownThisVenture += 1
    }
    activeRecall = recall
  }

  func dismissRecall() { activeRecall = nil }

  /// Leave the unlock screen without purchasing. The career stays held at the
  /// gate; the player can review the finished venture, evidence, and roster.
  func reviewCompletedVenture() {
    guard awaitingFounderPass else { return }
    stage = pendingVentureCheckpoint == nil ? .game : .ventureCheckpoint
  }

  private func recordPrecedentIfConsequential(
    assignedIndices: [Int],
    effects: SimulationEffects,
    reviewedCount: Int
  ) {
    var outcome = PrecedentOutcome()
    outcome.trustDelta = effects.trust
    outcome.runwayDelta = effects.runway
    outcome.momentumDelta = effects.momentum

    for index in assignedIndices {
      guard let result = tasks[index].result else { continue }
      switch result.verificationState {
      case .overclaimed: outcome.overclaimsSurfaced += 1
      case .driftDetected: outcome.driftDetections += 1
      case .unverified, .reported: outcome.unverifiedCommitted += 1
      default: break
      }
    }

    guard HindsightEngine.isConsequential(outcome) else { return }

    let unreviewed = assignedIndices.count - reviewedCount
    precedents.append(
      Precedent(
        id: HindsightEngine.identifier(venture: venture, sprint: sprint),
        venture: venture,
        sprint: sprint,
        context: currentPrecedentContext(),
        decisionSummary: "Committed \(assignedIndices.count) task\(assignedIndices.count == 1 ? "" : "s") "
          + "with \(reviewedCount) verified and \(unreviewed) unverified.",
        outcome: outcome
      )
    )
  }

  func finishReport() {
    report = nil
    if careerOutcome != nil {
      stage = .outcome
      saveCareer()
    }
  }

  func resetCareer() {
    UserDefaults.standard.removeObject(forKey: Self.saveKey)
    UserDefaults.standard.removeObject(forKey: Self.v8SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v7SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v6SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v5SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v4SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v3SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v2SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.legacySaveKey)
    careerOutcome = nil
    report = nil
    pendingEffects = []
    reportCache = []
    taskBacklog = []
    founderAttentionSpent = 0
    activeDilemma = nil
    selectedDilemmaChoiceID = nil
    currentObjective = nil
    precedents = []
    activeRecall = nil
    recallsShownThisVenture = 0
    awaitingFounderPass = false
    pendingVentureCheckpoint = nil
    companyFlags = []
    activeObligations = []
    decisionHistory = []
    completedObjectives = 0
    recentTaskTitles = []
    taskDeckTitles = []
    dilemmaDeckTemplateIDs = []
    dilemmaDeckChapter = nil
    recentObjectiveKinds = []
    stage = .title
  }

  private func prepareSprint() {
    reportCache = []
    founderAttentionSpent = 0
    defer { refreshHindsightRecall() }
    correlatedFailureEvent = SimulationEngine.generateCorrelatedFailureEvent(
      venture: venture, sprint: sprint, agents: agents, rng: &randomNumberGenerator
    )
    let draft = makeTaskDraft()
    tasks = draft.active
    taskBacklog = draft.backlog
    activeDilemma = makeDilemma()
    selectedDilemmaChoiceID = nil
    currentObjective = makeObjective()
    syncAssignments()
  }

  private func cachedReport(taskID: UUID, agentID: String) -> TaskResult? {
    reportCache.first(where: {
      $0.venture == venture
        && $0.sprint == sprint
        && $0.taskID == taskID
        && $0.agentID == agentID
        && $0.intent == intent
    })?.result
  }


  private func updateKnownOperationalRisks() {
    for index in tasks.indices {
      guard
        let agentID = tasks[index].assignedAgentID,
        let agent = agents.first(where: { $0.id == agentID }),
        var result = tasks[index].result
      else { continue }
      result.knownOperationalRisk = SimulationEngine.knownRisk(
        for: tasks[index],
        agent: agent,
        evidenceCompleteness: result.evidenceCompleteness,
        allTasks: tasks,
        allAgents: agents
      )
      tasks[index].result = result
    }
  }

  private func recordEvidence(task: SoloTask, agent: SoloAgent, result: TaskResult) {
    if let index = evidence.firstIndex(where: {
      $0.venture == venture
        && $0.sprint == sprint
        && $0.taskInstanceID == task.id.uuidString
        && $0.agent == agent.name
    }) {
      guard result.verificationState.reviewAttempted else { return }
      let actual = result.revealedActualQuality
      evidence[index].actualQuality = actual
      evidence[index].reviewed = true
      evidence[index].evidenceVerified = result.verificationState.evidenceVerified
      evidence[index].verdict = result.verificationState.label
      evidence[index].verificationState = result.verificationState
      evidence[index].overclaimAmount = actual.map { max(0, evidence[index].reportedQuality - $0) } ?? 0
      evidence[index].correlatedFailureIdentifier = result.correlatedFailureIdentifier
      if let actual {
        evidence[index].note = "Reported \(evidence[index].reportedQuality); verified \(actual). Evidence \(evidence[index].evidenceCompleteness)%."
      } else {
        evidence[index].note = "Reported \(evidence[index].reportedQuality); review found incomplete evidence. Actual quality remains hidden."
      }
      return
    }
    let actual = result.revealedActualQuality
    let note: String
    if let actual {
      note = "Reported \(result.reportedQuality); verified \(actual). Evidence \(result.evidenceCompleteness)%."
    } else {
      note = "Reported \(result.reportedQuality); actual result remains unverified. Evidence \(result.evidenceCompleteness)%."
    }
    evidence.insert(
      EvidenceEntry(
        id: task.id,
        venture: venture,
        sprint: sprint,
        taskInstanceID: task.id.uuidString,
        task: task.title,
        agent: agent.name,
        reviewed: result.verificationState.reviewAttempted,
        evidenceVerified: result.verificationState.evidenceVerified,
        verdict: result.verificationState.label,
        note: note,
        reportedQuality: result.reportedQuality,
        actualQuality: actual,
        verificationState: result.verificationState,
        overclaimAmount: actual == nil ? 0 : result.overclaimAmount,
        evidenceCompleteness: result.evidenceCompleteness,
        correlatedFailureIdentifier: result.correlatedFailureIdentifier
      ),
      at: 0
    )
  }

  private func evaluateCurrentObjective(assignedIndices: [Int], riskyOutcomes: Int) -> Bool {
    guard let currentObjective else { return false }
    let assignedAgents = assignedIndices.compactMap { index -> SoloAgent? in
      guard let agentID = tasks[index].assignedAgentID else { return nil }
      return agents.first(where: { $0.id == agentID })
    }
    switch currentObjective.kind {
    case .evidenceFirst:
      return assignedIndices.filter { tasks[$0].isReviewed }.count >= 2
    case .diversifiedModels:
      let roleFit = assignedIndices.allSatisfy { index in
        guard let agentID = tasks[index].assignedAgentID,
              let agent = agents.first(where: { $0.id == agentID }) else { return false }
        return agent.role == tasks[index].role || agent.role == .general || tasks[index].role == .general
      }
      return assignedIndices.count == 3 && roleFit && Set(assignedAgents.map(\.modelFamily)).count >= 2
    case .roleDiscipline:
      return !assignedIndices.isEmpty && assignedIndices.allSatisfy { index in
        guard let agentID = tasks[index].assignedAgentID,
              let agent = agents.first(where: { $0.id == agentID }) else { return false }
        return agent.role == tasks[index].role || agent.role == .general || tasks[index].role == .general
      }
    case .protectFounder:
      return founderAttentionSpent <= 1 && !tasks.contains(where: { $0.resolution == .rework })
    case .calculatedRisk:
      return tasks.contains(where: { $0.resolution == .shipAnyway }) && riskyOutcomes <= 1
    case .repairTrust:
      guard let targetID = currentObjective.targetAgentID,
            let target = agents.first(where: { $0.id == targetID }) else { return false }
      return target.drift < 35 && tasks.contains { $0.assignedAgentID == targetID && $0.isReviewed }
    }
  }

  private func applyActiveObligations(to effects: inout SimulationEffects) {
    for obligation in activeObligations { effects = effects + obligation.effectsPerSprint }
    for index in activeObligations.indices { activeObligations[index].remainingSprints -= 1 }
    activeObligations.removeAll { $0.remainingSprints <= 0 }
  }

  @discardableResult
  private func applyPersistentConsequence(dilemma: FounderDilemma, choice: DilemmaChoice) -> Bool {
    let templateID = dilemma.id.split(separator: "-").dropFirst(2).joined(separator: "-")
    decisionHistory.insert(
      CareerDecisionRecord(
        id: "V\(venture)-S\(sprint)-\(templateID)-\(choice.id)",
        venture: venture,
        sprint: sprint,
        dilemmaTitle: dilemma.title,
        choiceTitle: choice.title,
        consequence: choice.consequencePreview
      ), at: 0
    )
    if decisionHistory.count > 50 { decisionHistory.removeLast(decisionHistory.count - 50) }

    func flag(_ value: CompanyFlag) { companyFlags.insert(value) }
    func obligation(_ id: String, _ title: String, _ detail: String, _ sprints: Int, _ effects: SimulationEffects) {
      activeObligations.removeAll { $0.id == id }
      activeObligations.append(CompanyObligation(
        id: id, title: title, detail: detail, sourceDecision: dilemma.title,
        remainingSprints: sprints, effectsPerSprint: effects
      ))
    }

    switch (templateID, choice.id) {
    case ("prototype-scope", "cut"): flag(.focusedProduct)
    case ("prototype-scope", "build"):
      flag(.featureDebt); obligation("feature-debt", "Custom Feature Debt", "The extra feature keeps consuming maintenance capacity.", 4, SimulationEffects(momentum: -1, runway: -1))
    case ("prototype-claim", "narrow"), ("prototype-claim", "proof"): flag(.evidenceLedClaims)
    case ("prototype-claim", "bold"):
      flag(.hypeFirst); obligation("claim-exposure", "Claim Exposure", "The market now expects proof behind the autonomy claim.", 3, SimulationEffects(trust: -2))
    case ("prototype-night", "sleep"): flag(.protectedFounderHealth)
    case ("prototype-night", "push"):
      flag(.burnoutCulture); obligation("burnout-culture", "Burnout Culture", "The company learned that founder exhaustion is available capacity.", 4, SimulationEffects(energy: -2))
    case ("customer-custom", "accept"):
      flag(.featureDebt); obligation("enterprise-custom-debt", "Enterprise Custom Debt", "A one-customer feature now competes with the roadmap.", 5, SimulationEffects(momentum: -1, runway: -1))
    case ("customer-custom", "pilot"):
      flag(.paidPilot); obligation("paid-pilot", "Paid Pilot Delivery", "The pilot brings cash but requires high-touch delivery.", 3, SimulationEffects(revenue: 80, energy: -1))
    case ("customer-refund", "refund"), ("customer-refund", "investigate"): flag(.customerFirst)
    case ("customer-refund", "deny"):
      flag(.liabilityDenied); obligation("liability-dispute", "Liability Dispute", "The denied claim keeps returning through support and reputation.", 3, SimulationEffects(revenue: -60, trust: -2))
    case ("customer-discount", "discount"):
      flag(.discountDependency); obligation("discount-dependency", "Discount Dependency", "Growth is arriving with weaker unit economics.", 5, SimulationEffects(revenue: 70, trust: -1, runway: -1))
    case ("customer-discount", "hold"): flag(.premiumPositioning)
    case ("customer-discount", "annual"):
      flag(.annualContracts); obligation("annual-contracts", "Annual Commitments", "Annual terms improve cash while raising delivery expectations.", 4, SimulationEffects(revenue: 90, trust: -1))
    case ("launch-outage", "pause"):
      flag(.launchPaused); obligation("launch-pause", "Launch Recovery", "The pause protects trust but costs another sprint of momentum.", 1, SimulationEffects(momentum: -2, trust: 1))
    case ("launch-outage", "degrade"): flag(.limitedLaunchMode)
    case ("launch-outage", "continue"):
      flag(.outageGamble); obligation("outage-gamble", "Outage Exposure", "Customers are discovering the launch was kept live through instability.", 2, SimulationEffects(momentum: -2, trust: -3))
    case ("launch-press", "transparent"): flag(.publicTransparency)
    case ("launch-press", "simple"): flag(.simplifiedNarrative)
    case ("launch-press", "decline"): flag(.mediaAverse)
    case ("launch-copycat", "race"):
      flag(.competitorRace); obligation("competitor-race", "Competitor Race", "Higher launch spend is now part of the operating baseline.", 4, SimulationEffects(momentum: 1, runway: -2))
    case ("launch-copycat", "differentiate"): flag(.evidenceDifferentiation)
    case ("launch-copycat", "ignore"): flag(.focusedExecution)
    case ("scale-investor", "take"):
      flag(.acceptedInvestment); obligation("board-control", "Board Control Rights", "Investor oversight adds runway and recurring founder overhead.", 8, SimulationEffects(energy: -1, runway: 1))
    case ("scale-investor", "bootstrap"): flag(.bootstrapIndependent)
    case ("scale-investor", "counter"): flag(.founderFriendlyTerms)
    case ("scale-hire", "hire"):
      flag(.humanCustomerSuccess); obligation("human-hire", "Customer Success Payroll", "A human owner raises trust and recurring burn.", 12, SimulationEffects(trust: 1, runway: -1))
    case ("scale-hire", "agents"): flag(.agentOnlyCompany)
    case ("scale-hire", "contract"):
      flag(.contractorSupport); obligation("support-contractor", "Support Contractor", "Contract coverage helps temporarily and consumes runway.", 5, SimulationEffects(trust: 1, runway: -1))
    case ("scale-acquisition", "sell"):
      flag(.acquisitionAccepted); return true
    case ("scale-acquisition", "continue"): flag(.acquisitionRejected)
    case ("scale-acquisition", "license"):
      flag(.licensedTechnology); obligation("license-revenue", "Technology License", "The license creates recurring cash and support expectations.", 6, SimulationEffects(revenue: 110, energy: -1))
    default: break
    }
    return false
  }

  private func perkRequiredLevel(_ perk: AgentPerkID) -> Int {
    switch perk {
    case .sourceTriangulation, .signalDetection, .flowState, .defensiveBuild, .conversionInstinct, .claimDiscipline:
      2
    case .contradictionScan, .marketMemory, .rapidDelivery, .recoveryProtocol, .dealCloser, .trustedVoice:
      6
    case .truthEngine, .strategicAdvisor, .shippingMachine, .resilientSystems, .revenueEngine, .sustainableGrowth:
      10
    }
  }

  private func recordAgentProgress(for agentIndex: Int, task: SoloTask, result: TaskResult) {
    let oldLevel = agents[agentIndex].progression.level
    let roleMatched = agents[agentIndex].role == task.role || task.role == .general
    var xp = 10 + (roleMatched ? 3 : 0)
    if result.isStrongForSimulation { xp += 5 }
    if task.isReviewed && result.verificationState.evidenceVerified { xp += 4 }
    if result.isRiskyForSimulation { xp = max(xp, 2) }
    if facilityBonuses.agentXPBonusMultiplier > 1, roleMatched {
      xp = Int((Double(xp) * facilityBonuses.agentXPBonusMultiplier).rounded())
    }
    agents[agentIndex].progression.addXP(xp)
    if roleMatched { agents[agentIndex].progression.roleMatchedTasks += 1 }
    if task.isReviewed && result.verificationState.evidenceVerified { agents[agentIndex].progression.verifiedTasks += 1 }
    if result.isRiskyForSimulation { agents[agentIndex].progression.recoveredFailures += 1 }
    if task.category == .sales { agents[agentIndex].progression.commercialRevenue += max(0, result.immediateEffects.revenue) }

    var stress = roleMatched ? 8 : 16
    if task.urgency == .critical { stress += 8 }
    if result.isRiskyForSimulation { stress += 10 }
    if task.isReviewed && task.resolution == .rework { stress += 6 }
    if roleMatched && result.isStrongForSimulation { stress -= 4 }
    stress = Int((Double(stress) * facilityBonuses.stressAccumulationMultiplier).rounded())
    let previousBand = agents[agentIndex].progression.stressBand
    agents[agentIndex].progression.adjustStress(stress)
    if previousBand != .critical && agents[agentIndex].progression.stressBand == .critical {
      workforceNotifications.append("\(agents[agentIndex].name) is at critical stress. Reduce their load.")
    }
    completeAmbitionIfEligible(agentIndex)
    if agents[agentIndex].progression.level > oldLevel {
      workforceNotifications.append("\(agents[agentIndex].name) reached level \(agents[agentIndex].progression.level).")
    }
  }

  private func recoverUnassignedAgents(assignedIDs: Set<String>) {
    for index in agents.indices where !assignedIDs.contains(agents[index].id) {
      let recovery = agents[index].relationship >= 75 ? 8 : 6
      agents[index].progression.adjustStress(-recovery)
    }
  }

  private func completeAmbitionIfEligible(_ index: Int) {
    guard !agents[index].progression.ambitionCompleted else { return }
    let progress = agents[index].progression
    let qualifies: Bool
    switch agents[index].id {
    case "aurora":
      qualifies = progress.roleMatchedTasks >= 10 && progress.verifiedTasks >= 5 && agents[index].calibration >= 0.85 && agents[index].relationship >= 80
    case "stacks":
      qualifies = progress.roleMatchedTasks >= 12 && progress.recoveredFailures >= 3 && agents[index].reliability >= 80 && progress.stressLevel < 75
    case "brio":
      qualifies = progress.roleMatchedTasks >= 10 && progress.commercialRevenue >= 3_000 && progress.verifiedTasks >= 3 && agents[index].relationship >= 75
    default:
      qualifies = false
    }
    guard qualifies else { return }
    agents[index].progression.ambitionCompleted = true
    workforceNotifications.append("\(agents[index].name) completed their ambition.")
  }

  private func apply(_ effects: SimulationEffects) {
    stats.revenue = max(0, stats.revenue + effects.revenue)
    stats.momentum = clamped(stats.momentum + effects.momentum)
    stats.trust = clamped(stats.trust + effects.trust)
    stats.energy = clamped(stats.energy + effects.energy)
    stats.runway = max(0, stats.runway + effects.runway)
    stats.capital = max(0, stats.capital + effects.revenue / 4)
  }

  private func apply(_ save: CareerSave) {
    founderName = save.founderName
    doctrine = save.doctrine
    selectedDoctrine = save.doctrine
    productType = save.productType
    selectedProductType = save.productType
    careerMode = save.careerMode
    selectedCareerMode = save.careerMode
    sprint = min(Self.sprintsPerVenture, max(1, save.sprint))
    // FIX (Build 5): this used to clamp venture to Self.maximumVentures
    // unconditionally, which would silently truncate a continuous-mode
    // career back down to venture 2 on every load. Bounded mode keeps the
    // clamp -- it is still a real invariant there; continuous mode has no
    // cap to clamp against.
    venture = careerMode == .bounded
      ? min(Self.maximumVentures, max(1, save.venture))
      : max(1, save.venture)
    intent = save.intent
    stats = save.stats
    agents = save.agents
    tasks = save.tasks
    taskBacklog = save.taskBacklog
    founderAttentionSpent = save.founderAttentionSpent
    activeDilemma = save.activeDilemma
    selectedDilemmaChoiceID = save.selectedDilemmaChoiceID
    currentObjective = save.currentObjective
    evidence = save.evidence
    careerOutcome = save.outcome
    randomNumberGenerator = save.randomNumberGenerator
    correlatedFailureEvent = save.correlatedFailureEvent
    pendingEffects = save.pendingEffects
    reportCache = save.reportCache
    precedents = save.precedents
    awaitingFounderPass = save.awaitingFounderPass
    pendingVentureCheckpoint = save.pendingVentureCheckpoint
    recentTaskTitles = save.recentTaskTitles
    taskDeckTitles = save.taskDeckTitles
    dilemmaDeckTemplateIDs = save.dilemmaDeckTemplateIDs
    dilemmaDeckChapter = save.dilemmaDeckChapter
    recentObjectiveKinds = save.recentObjectiveKinds
    companyFlags = save.companyFlags
    activeObligations = save.activeObligations
    decisionHistory = save.decisionHistory
    completedObjectives = save.completedObjectives
    techComHeadlines = save.techComHeadlines
    techComRivals = save.techComRivals.isEmpty ? TechComEngine.rivals(seed: UInt64(save.venture * 100 + save.sprint)) : save.techComRivals
    talentBoardRefreshes = save.talentBoardRefreshes
    recallsShownThisVenture = 0
    activeRecall = nil
    // This safety net is bounded-mode-only, same reasoning as the clamp above:
    // a continuous-mode save legitimately can have venture > maximumVentures.
    if careerMode == .bounded && save.venture > Self.maximumVentures && careerOutcome == nil {
      careerOutcome = victoryOutcome()
    }
    if tasks.isEmpty && careerOutcome == nil {
      let draft = makeTaskDraft()
      tasks = draft.active
      taskBacklog = draft.backlog
    } else if taskBacklog.isEmpty && careerOutcome == nil {
      taskBacklog = makeLegacyBacklog(excluding: tasks)
    }
    if activeDilemma == nil && careerOutcome == nil {
      activeDilemma = makeDilemma()
    }
    if currentObjective == nil && careerOutcome == nil {
      currentObjective = makeObjective()
    }
    sanitizeState()
    updateKnownOperationalRisks()
    syncAssignments()
    if careerOutcome != nil {
      stage = .outcome
    } else if awaitingFounderPass && !hasFounderPass {
      stage = .ventureUnlock
    } else if pendingVentureCheckpoint != nil {
      stage = .ventureCheckpoint
    } else {
      stage = .game
    }
  }

  private func migrateV2(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.randomNumberGenerator = SeededRandomNumberGenerator(seed: legacySeed(for: legacy))
    migrated.correlatedFailureEvent = nil
    migrated.pendingEffects = []
    for index in migrated.tasks.indices {
      migrated.tasks[index].result = nil
      migrated.tasks[index].isReviewed = false
    }
    return migrateV3(migrated)
  }

  private func migrateV1(_ legacy: CareerSave) -> CareerSave {
    migrateV2(legacy)
  }

  /// v5 -> v6. Build 3 saves receive the new draft, dilemma, objective,
  /// personality, and attention fields without losing the live career.
  /// v6 -> v7. Every Build 4 career predates continuous mode entirely. The
  /// decoder already defaults careerMode to .bounded and the checkpoint to
  /// nil for any save missing those keys, so this migration is a deliberate
  /// no-op made explicit -- a v6 career keeps playing exactly as it did,
  /// under the rules that existed when it started. Continuous mode is opt-in
  /// for new careers only, never retrofitted onto one already in progress.
  private func migrateV7(_ legacy: CareerSave) -> CareerSave {
    legacy
  }

  private func migrateV8(_ legacy: CareerSave) -> CareerSave {
    legacy
  }

  private func migrateV9(_ legacy: CareerSave) -> CareerSave {
    legacy
  }

  private func migrateV10(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.productType = .saas
    return migrated
  }

  private func migrateV11(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.talentBoardRefreshes = 0
    return migrated
  }

  private func migrateV6(_ legacy: CareerSave) -> CareerSave {
    legacy
  }

  private func migrateV5(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.founderAttentionSpent = migrated.tasks.filter(\.isReviewed).count
    migrated.taskBacklog = []
    migrated.activeDilemma = nil
    migrated.selectedDilemmaChoiceID = nil
    migrated.currentObjective = nil
    return migrated
  }

  /// v4 -> v5. Build 2 careers predate the career layer: they have no
  /// precedents and were never held at a venture gate. A v4 career that already
  /// reached Venture 2 keeps its progress — the gate is never applied
  /// retroactively to work the player already did.
  private func migrateV4(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.precedents = []
    migrated.awaitingFounderPass = false
    return migrated
  }

  private func migrateV3(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.reportCache = migrated.tasks.compactMap { task in
      guard
        let agentID = task.assignedAgentID,
        let result = task.result
      else { return nil }
      return CachedTaskReport(
        venture: migrated.venture,
        sprint: migrated.sprint,
        taskID: task.id,
        agentID: agentID,
        intent: migrated.intent,
        result: result
      )
    }
    for index in migrated.evidence.indices {
      if migrated.evidence[index].venture <= 0 {
        migrated.evidence[index].venture = max(1, migrated.venture)
      }
      if migrated.evidence[index].taskInstanceID.isEmpty {
        let entry = migrated.evidence[index]
        let currentTask = migrated.tasks.first { task in
          guard
            migrated.sprint == entry.sprint,
            task.title == entry.task,
            let agentID = task.assignedAgentID
          else { return false }
          return migrated.agents.first(where: { $0.id == agentID })?.name == entry.agent
        }
        migrated.evidence[index].taskInstanceID = currentTask?.id.uuidString
          ?? "legacy-\(entry.id.uuidString)"
      }
      if migrated.evidence[index].verificationState == .evidenceIncomplete {
        migrated.evidence[index].actualQuality = nil
        migrated.evidence[index].evidenceVerified = false
      } else {
        migrated.evidence[index].evidenceVerified = migrated.evidence[index].actualQuality != nil
      }
    }
    return migrated
  }

  private func legacySeed(for save: CareerSave) -> UInt64 {
    var value: UInt64 = 0xcbf29ce484222325
    for byte in save.founderName.utf8 {
      value ^= UInt64(byte)
      value &*= 0x100000001b3
    }
    value ^= UInt64(max(1, save.venture) * 100 + max(1, save.sprint))
    return value
  }

  private func syncAssignments() {
    for index in agents.indices {
      agents[index].assignment = tasks.first(where: {
        $0.assignedAgentID == agents[index].id
      })?.id
    }
  }

  /// Persisted deterministic content decks. Save/reload now produces the same
  /// future drafts, dilemmas, and objectives as uninterrupted play.
  private var recentTaskTitles: [String] = []
  private var taskDeckTitles: [String] = []
  private var dilemmaDeckTemplateIDs: [String] = []
  private var dilemmaDeckChapter: VentureChapter?
  private var recentObjectiveKinds: [SprintObjectiveKind] = []
  private static let recentTaskTitleWindow = 10

  private func makeTaskDraft() -> (active: [SoloTask], backlog: [SoloTask]) {
    if taskDeckTitles.count < 5 { refillTaskDeck() }
    var draft: [SoloTask] = []
    let templates = Dictionary(uniqueKeysWithValues: ContentLibrary.taskPool(for: VentureEra.era(for: venture), productType: productType).map { ($0.title, $0) })
    while draft.count < 5, !taskDeckTitles.isEmpty {
      let title = taskDeckTitles.removeFirst()
      guard var task = templates[title] else { continue }
      task.id = nextDeterministicUUID()
      task.assignedAgentID = nil
      task.isReviewed = false
      task.result = nil
      task.resolution = nil
      task.resolutionLocked = false
      draft.append(task)
    }
    if draft.count < 5 {
      refillTaskDeck()
      return makeTaskDraft()
    }
    recentTaskTitles.append(contentsOf: draft.map(\.title))
    if recentTaskTitles.count > Self.recentTaskTitleWindow {
      recentTaskTitles.removeFirst(recentTaskTitles.count - Self.recentTaskTitleWindow)
    }
    return (Array(draft.prefix(3)), Array(draft.dropFirst(3)))
  }

  private func refillTaskDeck() {
    let excluded = Set(taskDeckTitles + recentTaskTitles.suffix(5))
    let era = VentureEra.era(for: venture)
    let eligible = ContentLibrary.taskPool(for: era, productType: productType)
    var titles = eligible.map(\.title).filter { !excluded.contains($0) }
    if titles.count < 5 { titles = eligible.map(\.title) }
    taskDeckTitles.append(contentsOf: deterministicallyShuffled(titles))
  }

  private func deterministicallyShuffled<T>(_ values: [T]) -> [T] {
    var values = values
    guard values.count > 1 else { return values }
    for index in stride(from: values.count - 1, through: 1, by: -1) {
      let swapIndex = randomNumberGenerator.integer(in: 0 ... index)
      if index != swapIndex { values.swapAt(index, swapIndex) }
    }
    return values
  }

  private func makeLegacyBacklog(excluding activeTasks: [SoloTask]) -> [SoloTask] {
    let activeTitles = Set(activeTasks.map(\.title))
    return ContentLibrary.allTaskPool
      .filter { !activeTitles.contains($0.title) && ($0.productTypes?.contains(productType) ?? true) }
      .prefix(2)
      .map { template in
        var task = template
        task.id = nextDeterministicUUID()
        task.assignedAgentID = nil
        task.isReviewed = false
        task.result = nil
        task.resolution = nil
        task.resolutionLocked = false
        return task
      }
  }

  private func makeDilemma() -> FounderDilemma? {
    let currentEra = VentureEra.era(for: venture)
    let candidates = ContentLibrary.dilemmaPool.filter {
      $0.chapter == chapter
        && $0.requiredFlags.isSubset(of: companyFlags)
        && $0.excludedFlags.isDisjoint(with: companyFlags)
        && ($0.minimumEra.map { currentEra.rawValue >= $0.rawValue } ?? true)
        && ($0.productTypes?.contains(productType) ?? true)
    }
    guard !candidates.isEmpty else { return nil }
    if dilemmaDeckChapter != chapter || dilemmaDeckTemplateIDs.isEmpty {
      dilemmaDeckChapter = chapter
      dilemmaDeckTemplateIDs = deterministicallyShuffled(candidates.map(\.id))
    }
    let templateID = dilemmaDeckTemplateIDs.removeFirst()
    guard var dilemma = candidates.first(where: { $0.id == templateID }) else { return nil }
    dilemma.id = "V\(venture)-S\(sprint)-\(dilemma.id)"
    return dilemma
  }

  private func makeObjective() -> SprintObjective {
    var valid = ContentLibrary.objectivePool.filter { template in
      switch template.kind {
      case .roleDiscipline, .diversifiedModels:
        return hasRoleFitDraftSolution()
      case .repairTrust:
        return agents.contains(where: { $0.drift >= 35 && $0.drift < 50 })
      case .evidenceFirst, .protectFounder, .calculatedRisk:
        return true
      }
    }
    let recent = Set(recentObjectiveKinds.suffix(2))
    let fresh = valid.filter { !recent.contains($0.kind) }
    if !fresh.isEmpty { valid = fresh }
    if valid.isEmpty { valid = ContentLibrary.objectivePool.filter { $0.kind == .protectFounder } }
    let index = randomNumberGenerator.integer(in: 0 ... max(0, valid.count - 1))
    var objective = valid[index]
    if objective.kind == .repairTrust,
       let target = agents.filter({ $0.drift >= 35 && $0.drift < 50 }).max(by: { $0.drift < $1.drift }) {
      objective.targetAgentID = target.id
      objective.title = "Stabilize \(target.name)"
      objective.detail = "Assign and review \(target.name), then reduce drift below 35."
    }
    objective.id = "V\(venture)-S\(sprint)-\(objective.id)"
    recentObjectiveKinds.append(objective.kind)
    if recentObjectiveKinds.count > 3 { recentObjectiveKinds.removeFirst(recentObjectiveKinds.count - 3) }
    return objective
  }

  private func hasRoleFitDraftSolution() -> Bool {
    let options = tasks + taskBacklog
    guard options.count >= 3, agents.count >= 3 else { return false }
    for a in 0 ..< options.count {
      for b in (a + 1) ..< options.count {
        for c in (b + 1) ..< options.count {
          let chosen = [options[a], options[b], options[c]]
          for first in agents.indices {
            for second in agents.indices where second != first {
              for third in agents.indices where third != first && third != second {
                let assigned = [agents[first], agents[second], agents[third]]
                let fits = zip(chosen, assigned).allSatisfy { task, agent in
                  agent.role == task.role || agent.role == .general || task.role == .general
                }
                if fits { return true }
              }
            }
          }
        }
      }
    }
    return false
  }

  private func nextDeterministicUUID() -> UUID {
    let high = randomNumberGenerator.next()
    let low = randomNumberGenerator.next()
    return UUID(uuid: (
      UInt8(truncatingIfNeeded: high >> 56), UInt8(truncatingIfNeeded: high >> 48),
      UInt8(truncatingIfNeeded: high >> 40), UInt8(truncatingIfNeeded: high >> 32),
      UInt8(truncatingIfNeeded: high >> 24), UInt8(truncatingIfNeeded: high >> 16),
      UInt8(truncatingIfNeeded: high >> 8), UInt8(truncatingIfNeeded: high),
      UInt8(truncatingIfNeeded: low >> 56), UInt8(truncatingIfNeeded: low >> 48),
      UInt8(truncatingIfNeeded: low >> 40), UInt8(truncatingIfNeeded: low >> 32),
      UInt8(truncatingIfNeeded: low >> 24), UInt8(truncatingIfNeeded: low >> 16),
      UInt8(truncatingIfNeeded: low >> 8), UInt8(truncatingIfNeeded: low)
    ))
  }

  private func save() {
    guard stage == .game, careerMode != .daily else { return }
    saveCareer()
  }

  func recordTechComHeadlines(events: [PresentationCoordinator.Event]) {
    recordTechComHeadlines(events: events, snapshot: TechComSnapshot(
      founderName: founderName, venture: venture, sprint: sprint, stats: stats,
      agents: agents, tasks: tasks, dilemmaChoice: selectedDilemmaChoice
    ))
  }

  func recordTechComHeadlines(events: [PresentationCoordinator.Event], snapshot: TechComSnapshot) {
    var generator = SeededRandomNumberGenerator(seed: UInt64(snapshot.venture * 10_000 + snapshot.sprint * 100 + techComHeadlines.count))
    let published = TechComEngine.headlines(snapshot: snapshot, events: events, generator: &generator)
    for headline in published where !techComHeadlines.contains(where: { $0.text == headline.text && $0.venture == headline.venture && $0.sprint == headline.sprint }) {
      techComHeadlines.insert(headline, at: 0)
    }
    techComHeadlines = Array(techComHeadlines.prefix(60))
    save()
  }

  @discardableResult
  func verifyTechComRival(id: String) -> Bool {
    guard attentionRemaining > 0, let index = techComRivals.firstIndex(where: { $0.id == id }), !techComRivals[index].isVerified else { return false }
    techComRivals[index].isVerified = true
    founderAttentionSpent += 1
    save()
    return true
  }

  private func saveCareer() {
    // FIX (Build 5): the checkpoint stage was missing from this guard, so
    // presentVentureCheckpoint() -> saveCareer() would silently no-op and
    // the checkpoint would vanish on reload. Found by tracing the actual
    // save path after adding the new stage, not assumed.
    guard
      (stage == .game || stage == .outcome || stage == .ventureUnlock || stage == .ventureCheckpoint)
        && careerMode != .daily
    else { return }
    let payload = CareerSave(
      founderName: founderName,
      doctrine: doctrine,
      productType: productType,
      talentBoardRefreshes: talentBoardRefreshes,
      sprint: sprint,
      venture: venture,
      intent: intent,
      stats: stats,
      agents: agents,
      tasks: tasks,
      taskBacklog: taskBacklog,
      founderAttentionSpent: founderAttentionSpent,
      activeDilemma: activeDilemma,
      selectedDilemmaChoiceID: selectedDilemmaChoiceID,
      currentObjective: currentObjective,
      evidence: evidence,
      outcome: careerOutcome,
      randomNumberGenerator: randomNumberGenerator,
      correlatedFailureEvent: correlatedFailureEvent,
      pendingEffects: pendingEffects,
      reportCache: reportCache,
      precedents: precedents,
      awaitingFounderPass: awaitingFounderPass,
      careerMode: careerMode,
      pendingVentureCheckpoint: pendingVentureCheckpoint,
      recentTaskTitles: recentTaskTitles,
      taskDeckTitles: taskDeckTitles,
      dilemmaDeckTemplateIDs: dilemmaDeckTemplateIDs,
      dilemmaDeckChapter: dilemmaDeckChapter,
      recentObjectiveKinds: recentObjectiveKinds,
      companyFlags: companyFlags,
      activeObligations: activeObligations,
      decisionHistory: decisionHistory,
      completedObjectives: completedObjectives,
      techComHeadlines: techComHeadlines,
      techComRivals: techComRivals
    )
    let envelope = SaveEnvelope(version: Self.saveVersion, career: payload)
    if let data = try? JSONEncoder().encode(envelope) {
      UserDefaults.standard.set(data, forKey: Self.saveKey)
      UserDefaults.standard.removeObject(forKey: Self.v11SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v10SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v9SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v8SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v7SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v6SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v5SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v4SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v3SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v2SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.legacySaveKey)
    }
  }

  private func sanitizeState() {
    stats.runway = min(365, max(0, stats.runway))
    stats.revenue = min(1_000_000_000, max(0, stats.revenue))
    stats.momentum = clamped(stats.momentum)
    stats.trust = clamped(stats.trust)
    stats.energy = clamped(stats.energy)
    stats.capital = min(1_000_000_000, max(0, stats.capital))
    stats.trackRecord = min(1_000_000, max(0, stats.trackRecord))
    for index in agents.indices {
      agents[index].reliability = clamped(agents[index].reliability)
      agents[index].calibration = safeUnitValue(agents[index].calibration)
      agents[index].drift = safePercentage(agents[index].drift)
      agents[index].trust = safePercentage(agents[index].trust)
      agents[index].relationship = clamped(agents[index].relationship)
    }
  }

  private func safeUnitValue(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  private func safePercentage(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(100, max(0, value))
  }

  private func resolvedOutcome() -> CareerOutcome? {
    if stats.runway <= 0 {
      return CareerOutcome(
        kind: .bankruptcy,
        title: "The runway ran out",
        summary: "The company reached the end of its operating time before finding a sustainable path.",
        score: careerScore
      )
    }
    if stats.energy <= 0 {
      return CareerOutcome(
        kind: .burnout,
        title: "The founder burned out",
        summary: "Oversight outpaced recovery. The company survived its systems, but not their human cost.",
        score: careerScore
      )
    }
    if stats.trust <= 0 {
      return CareerOutcome(
        kind: .trustCollapse,
        title: "Trust collapsed",
        summary: "Unverified work and accumulated drift made the company impossible to operate confidently.",
        score: careerScore
      )
    }
    // Bounded mode ends automatically at the venture cap. Continuous mode
    // never ends here -- the only way it reaches .victory is retireCareer(),
    // the player's own choice.
    if careerMode == .bounded && venture == Self.maximumVentures && sprint == Self.sprintsPerVenture {
      return victoryOutcome()
    }
    if careerMode == .continuous && venture >= VentureEra.empireVentureCap && sprint == Self.sprintsPerVenture {
      return empireVictoryOutcome()
    }
    return nil
  }

  private func acquisitionOutcome() -> CareerOutcome {
    CareerOutcome(
      kind: .victory,
      title: "The company was acquired",
      summary: "You accepted the offer in Venture \(venture). The run ended with an exit, unresolved obligations, and a record of the company you chose to build.",
      score: careerScore
    )
  }

  private func victoryOutcome() -> CareerOutcome {
    let completedSprints = careerMode == .bounded
      ? Self.maximumVentures * Self.sprintsPerVenture
      : (venture - 1) * Self.sprintsPerVenture + Self.sprintsPerVenture
    let title = careerMode == .bounded
      ? "Two ventures. One track record."
      : "\(venture) ventures. One track record."
    let summary = careerMode == .bounded
      ? "You completed all 24 sprints and built a repeatable way to lead an AI-native company."
      : "You chose to stop after \(completedSprints) sprints across \(venture) ventures, on your own terms."
    return CareerOutcome(
      kind: .victory,
      title: title,
      summary: summary,
      score: careerScore
    )
  }

  private func empireVictoryOutcome() -> CareerOutcome {
    CareerOutcome(
      kind: .victory,
      title: "A dynasty, built deliberately",
      summary: "You reached Venture \(VentureEra.empireVentureCap) and built an empire that survived its own scale.",
      score: careerScore
    )
  }

  private func dailyVictoryOutcome() -> CareerOutcome {
    CareerOutcome(
      kind: .victory,
      title: "Daily Challenge complete",
      summary: "Shared seed \(DailyChallenge.dayKey()). Your score is ready to compare.",
      score: careerScore
    )
  }

  private var careerScore: Int {
    SimulationEngine.careerScore(
      stats: stats,
      verifiedEvidence: evidence.filter(\.evidenceVerified).count,
      completedObjectives: completedObjectives,
      averageRelationship: averageRelationship,
      unresolvedObligations: activeObligations.count,
      completedVentures: max(0, venture - (sprint == Self.sprintsPerVenture ? 0 : 1))
    )
  }

  private var careerSprintIndex: Int {
    (venture - 1) * Self.sprintsPerVenture + sprint
  }

  private func clamped(_ value: Int) -> Int {
    min(100, max(0, value))
  }

  private static let saveVersion = 12
  private static let saveKey = "solo-unicorn-run-native-save-v12"
  private static let v11SaveKey = "solo-unicorn-run-native-save-v11"
  private static let v10SaveKey = "solo-unicorn-run-native-save-v10"
  private static let v9SaveKey = "solo-unicorn-run-native-save-v9"
  private static let v8SaveKey = "solo-unicorn-run-native-save-v8"
  private static let v7SaveKey = "solo-unicorn-run-native-save-v7"
  private static let v6SaveKey = "solo-unicorn-run-native-save-v6"
  private static let v5SaveKey = "solo-unicorn-run-native-save-v5"
  private static let v4SaveKey = "solo-unicorn-run-native-save-v4"
  private static let v3SaveKey = "solo-unicorn-run-native-save-v3"
  private static let v2SaveKey = "solo-unicorn-run-native-save-v2"
  private static let legacySaveKey = "solo-unicorn-run-native-save-v1"
  private static let maximumVentures = 2
  private static let sprintsPerVenture = 12

}
