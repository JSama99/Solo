import Foundation

/// Presentation-only activity. It never participates in simulation, saves, or scoring.
enum LivingAgentActivity: String, CaseIterable, Equatable, Sendable {
  case idle
  case assignmentReceived
  case working
  case workComplete
  case awaitingReview
  case reviewing
  case reviewed
  case resolving
  case resolved
  case resting

  var label: String {
    switch self {
    case .idle: "Ready"
    case .assignmentReceived: "Assignment received"
    case .working: "Working"
    case .workComplete: "Work complete"
    case .awaitingReview: "Awaiting Founder review"
    case .reviewing: "Founder reviewing"
    case .reviewed: "Reviewed"
    case .resolving: "Resolution locking"
    case .resolved: "Resolved"
    case .resting: "Resting"
    }
  }
}

/// Independent, composable conditions. Hidden result truth is admitted only by
/// `LivingAgentProjection.derive` after the canonical reveal boundary.
enum LivingAgentCondition: String, CaseIterable, Hashable, Sendable {
  case focused
  case stressed
  case overloaded
  case drifting
  case verified
  case overclaimed
  case evidenceIncomplete

  var label: String {
    switch self {
    case .focused: "Focused"
    case .stressed: "Stressed"
    case .overloaded: "Overloaded"
    case .drifting: "Drift detected"
    case .verified: "Verified"
    case .overclaimed: "Overclaim detected"
    case .evidenceIncomplete: "Evidence incomplete"
    }
  }
}

enum LivingPresentationEmphasis: Equatable, Sendable {
  case normal
  case selected
  case founderAttention
  case inspection
  case decisionLock
}

/// Presentation-only focus for the command scene. It is never persisted or
/// passed into `GameStore`.
enum CompanyCommandFocus: Equatable, Sendable {
  case founder
  case agent(String)

  var scrollID: String {
    switch self {
    case .founder: "founder"
    case .agent(let agentID): agentID
    }
  }

  func toggled(by target: Self) -> Self? {
    self == target ? nil : target
  }
}

struct CompanyCommandNavigationRequest: Equatable, Sendable {
  var target: CompanyCommandFocus
  var sequence: Int
}

struct CompanyCommandInteractionState: Equatable, Sendable {
  private(set) var focus: CompanyCommandFocus?
  private(set) var navigationRequest: CompanyCommandNavigationRequest?
  private(set) var userInitiatedFocus = false
  private var navigationSequence = 0

  mutating func toggleFocus(_ target: CompanyCommandFocus) {
    focus = focus == target ? nil : target
    userInitiatedFocus = focus != nil
  }

  mutating func ambientFocus(_ target: CompanyCommandFocus) {
    guard !userInitiatedFocus else { return }
    focus = target
  }

  mutating func requestFullWorkstation(_ target: CompanyCommandFocus) {
    navigationSequence += 1
    navigationRequest = .init(target: target, sequence: navigationSequence)
  }

  mutating func clearAfterSprintCommit() {
    focus = nil
    userInitiatedFocus = false
  }
}

/// One canonical availability projection is shared by viewport actions and the
/// full workstation cards, preventing the compact surface from inventing rules.
struct CompanyCommandAgentAvailability: Equatable, Sendable {
  var canAssign = false
  var canReview = false
  var canRest = false
  var canSkipPresentation = false
  var requiresResolution = false

  static func derive(
    sprintPhase: SprintPhase,
    task: SoloTask?,
    presentation: PresentationCoordinator.AgentPresentation?,
    isResting: Bool,
    attentionRemaining: Int
  ) -> Self {
    let isPlanning = sprintPhase == .chooseCommitments || sprintPhase == .assignTeam
    let presentationReady = presentation == nil || presentation?.phase == .awaitingReview
    let activePresentation = presentation.map {
      [.assignmentReceived, .working, .workComplete, .reviewing, .resolving].contains($0.phase)
    } ?? false
    return Self(
      canAssign: isPlanning && task == nil && !isResting,
      canReview: sprintPhase == .reviewAndResolve
        && presentationReady
        && task?.isReviewed == false
        && task?.result != nil
        && attentionRemaining > 0,
      canRest: isPlanning && !isResting && (task == nil || task?.isReviewed == false),
      canSkipPresentation: activePresentation,
      requiresResolution: task?.isReviewed == true && task?.resolutionLocked == false
    )
  }
}

struct CompanyCommandFounderSummary: Equatable, Sendable {
  var sprintPhase: SprintPhase
  var workInProgressCount: Int
  var reviewCount: Int
  var resolutionCount: Int
  var attentionRemaining: Int
  var attentionMaximum: Int
  var canCommit: Bool
  var nextAction: String

  @MainActor
  static func derive(store: GameStore, presentation: PresentationCoordinator) -> Self {
    let workInProgressCount = store.tasks.compactMap(\.assignedAgentID).filter { agentID in
      guard let phase = presentation.presentation(for: agentID)?.phase else { return false }
      return [.assignmentReceived, .working, .workComplete].contains(phase)
    }.count
    let reviewCount = store.tasks.filter {
      $0.assignedAgentID != nil && !$0.isReviewed && $0.result != nil
    }.count
    let resolutionCount = store.tasks.filter { $0.isReviewed && !$0.resolutionLocked }.count
    let nextAction: String
    if store.sprintPhase == .founderEvent {
      nextAction = "Choose a response to the Founder Event."
    } else if workInProgressCount > 0 {
      nextAction = "Agent work is still in progress."
    } else if resolutionCount > 0 {
      nextAction = "Resolve the waiting Founder decision."
    } else if reviewCount > 0 && store.attentionRemaining > 0 {
      nextAction = "Review the completed work."
    } else {
      nextAction = store.commitBlockerMessage ?? "Ready to commit this sprint."
    }
    return Self(
      sprintPhase: store.sprintPhase,
      workInProgressCount: workInProgressCount,
      reviewCount: reviewCount,
      resolutionCount: resolutionCount,
      attentionRemaining: store.attentionRemaining,
      attentionMaximum: store.attentionMaximum,
      canCommit: store.canCommitSprint,
      nextAction: nextAction
    )
  }
}

struct LivingAgentProjection: Identifiable, Equatable, Sendable {
  var id: String { agentID }
  var agentID: String
  var name: String
  var initials: String
  var role: AgentRole
  var taskID: UUID?
  var taskTitle: String?
  var activity: LivingAgentActivity
  var conditions: Set<LivingAgentCondition>
  var emphasis: LivingPresentationEmphasis
  var progress: Double
  var stressLabel: String
  var trustLabel: String
  var level: Int
  var needsFounderAttention: Bool
  var isResting: Bool

  var accessibilityValue: String {
    let task = taskTitle.map { "Task: \($0)." } ?? "No current task."
    let conditionsText = conditions
      .sorted { $0.rawValue < $1.rawValue }
      .map(\.label)
      .joined(separator: ", ")
    return "\(activity.label). \(task) Stress \(stressLabel). Trust \(trustLabel). Level \(level). \(conditionsText)."
  }

  static func derive(
    agent: SoloAgent,
    task: SoloTask?,
    presentation: PresentationCoordinator.AgentPresentation?,
    isResting: Bool,
    isSelected: Bool,
    founderStats: FounderStats
  ) -> Self {
    let activity = deriveActivity(task: task, presentation: presentation, isResting: isResting)
    var conditions = Set<LivingAgentCondition>()

    if activity == .working || activity == .assignmentReceived {
      conditions.insert(.focused)
    }
    switch agent.progression.stressBand {
    case .pressured:
      conditions.insert(.stressed)
    case .overloaded, .critical:
      conditions.insert(.stressed)
      conditions.insert(.overloaded)
    case .focused, .stable:
      break
    }

    // `review()` reveals canonical truth immediately so it can record Evidence,
    // but visual truth must wait until the report's fifth reveal step completes.
    let revealComplete = task?.isReviewed == true && presentation.map {
      $0.reviewRevealStep == 5 || [.reviewed, .resolving, .resolved].contains($0.phase)
    } ?? true
    if revealComplete, let result = task?.result {
      let visible = VisibleSimulationProjection.taskResult(from: result)
      switch visible.verificationState {
      case .verified, .confirmed:
        conditions.insert(.verified)
      case .overclaimed:
        conditions.insert(.overclaimed)
      case .driftDetected:
        conditions.insert(.drifting)
      case .evidenceIncomplete:
        conditions.insert(.evidenceIncomplete)
      case .reported, .unverified:
        break
      }
    }

    let emphasis: LivingPresentationEmphasis
    if activity == .reviewing {
      emphasis = .inspection
    } else if activity == .awaitingReview || activity == .workComplete {
      emphasis = .founderAttention
    } else if activity == .resolving || activity == .resolved {
      emphasis = .decisionLock
    } else if isSelected {
      emphasis = .selected
    } else {
      emphasis = .normal
    }

    return Self(
      agentID: agent.id,
      name: agent.name,
      initials: agent.initials,
      role: agent.role,
      taskID: task?.id,
      taskTitle: task?.title,
      activity: activity,
      conditions: conditions,
      emphasis: emphasis,
      progress: min(1, max(0, presentation?.progress ?? defaultProgress(task: task))),
      stressLabel: agent.progression.stressBand.label,
      trustLabel: AgentStationViewModel.TrustBand(trust: agent.trust).label,
      level: agent.progression.level,
      needsFounderAttention: [.workComplete, .awaitingReview, .reviewing].contains(activity),
      isResting: isResting
    )
  }

  private static func deriveActivity(
    task: SoloTask?,
    presentation: PresentationCoordinator.AgentPresentation?,
    isResting: Bool
  ) -> LivingAgentActivity {
    if isResting { return .resting }
    if let phase = presentation?.phase {
      switch phase {
      case .idle: return .idle
      case .assignmentReceived: return .assignmentReceived
      case .working: return .working
      case .workComplete: return .workComplete
      case .awaitingReview: return .awaitingReview
      case .reviewing: return .reviewing
      case .reviewed: return .reviewed
      case .resolving: return .resolving
      case .resolved: return .resolved
      }
    }
    guard let task else { return .idle }
    if task.resolutionLocked { return .resolved }
    if task.isReviewed { return .reviewed }
    return task.result == nil ? .assignmentReceived : .awaitingReview
  }

  private static func defaultProgress(task: SoloTask?) -> Double {
    guard let task else { return 0 }
    return task.result == nil ? 0 : 1
  }
}

struct CompanyAtmosphere: Equatable, Sendable {
  enum Pressure: String, Equatable, Sendable {
    case stable
    case lowEnergy
    case lowRunway
    case lowTrust
  }

  var facility: FacilityTier
  var equipmentStage: GarageEquipmentStage
  var pressure: Pressure
  var energy: Double
  var momentum: Double

  static func derive(stats: FounderStats, facility: FacilityTier, venture: Int) -> Self {
    let pressure: Pressure
    if stats.runway <= 8 { pressure = .lowRunway }
    else if stats.energy <= 38 { pressure = .lowEnergy }
    else if stats.trust <= 24 { pressure = .lowTrust }
    else { pressure = .stable }
    return Self(
      facility: facility,
      equipmentStage: .derive(venture: venture, trackRecord: stats.trackRecord, capital: stats.capital),
      pressure: pressure,
      energy: min(1, max(0.35, Double(stats.energy) / 100)),
      momentum: min(1, max(0, Double(stats.momentum) / 100))
    )
  }
}

struct InfrastructureVisual: Identifiable, Equatable, Sendable {
  enum State: Equatable, Sendable { case uninstalled, installed, active }

  var id: FacilityUpgradeID
  var title: String
  var symbol: String
  var state: State

  static func map(
    purchased: Set<FacilityUpgradeID>,
    facility: FacilityTier,
    agents: [LivingAgentProjection],
    sprint: Int
  ) -> [Self] {
    FacilityUpgradeDefinition.all.map { definition in
      let isInstalled = purchased.contains(definition.id)
      let isRelevant: Bool
      switch definition.id {
      case .developmentRig:
        isRelevant = agents.contains { $0.agentID == "stacks" && $0.activity == .working }
      case .verificationArray:
        isRelevant = agents.contains { $0.agentID == "aurora" && [.working, .reviewing].contains($0.activity) }
      case .campaignStudio:
        isRelevant = agents.contains { $0.agentID == "brio" && $0.activity == .working }
      case .recoveryCorner:
        isRelevant = agents.contains { $0.activity == .resting }
      case .founderCommandDesk:
        isRelevant = sprint.isMultiple(of: 3)
      }
      let state: State = !isInstalled ? .uninstalled : (facility == definition.requiredFacility && isRelevant ? .active : .installed)
      return Self(id: definition.id, title: definition.title, symbol: definition.symbol, state: state)
    }
  }
}

enum ViewportSelectionMap {
  static func workstationID(for agentID: String, canonicalAgentIDs: [String]) -> String? {
    canonicalAgentIDs.contains(agentID) ? agentID : nil
  }
}
