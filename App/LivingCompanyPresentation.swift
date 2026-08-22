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
  case levelUpCelebration
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

  /// Automatic choreography is deliberately observational. Calling this at
  /// every presentation event documents and enforces that playback cannot
  /// create focus, navigation, or accessibility transfer state.
  mutating func receiveAutomaticPresentationUpdate() {
    // Intentionally empty. User input is the only viewport-focus authority.
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
  var reviewRevealStep: Int
  var stressLabel: String
  var trustLabel: String
  var level: Int
  var needsFounderAttention: Bool
  var isResting: Bool
  var presentationSequenceID: UUID? = nil
  var resolutionChoice: TaskResolutionChoice? = nil

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
    founderStats: FounderStats,
    celebratingLevelUp: Bool = false
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
    if celebratingLevelUp {
      emphasis = .levelUpCelebration
    } else if activity == .reviewing {
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
      progress: activity == .resting ? 0 : min(1, max(0, presentation?.progress ?? defaultProgress(task: task))),
      reviewRevealStep: presentation?.reviewRevealStep ?? (task?.isReviewed == true ? 5 : 0),
      stressLabel: agent.progression.stressBand.label,
      trustLabel: AgentStationViewModel.TrustBand(trust: agent.trust).label,
      level: agent.progression.level,
      needsFounderAttention: [.workComplete, .awaitingReview, .reviewing].contains(activity),
      isResting: isResting,
      presentationSequenceID: presentation?.sequenceID,
      resolutionChoice: presentation?.resolutionChoice
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
  var isLowEnergy: Bool
  var isLowRunway: Bool
  var isLowTrust: Bool
  var isHighMomentum: Bool
  var runway: Int
  var trust: Int

  var localizedReaction: CompanyAtmosphereReaction {
    if isLowRunway { return .runwayDepletion }
    if isLowEnergy { return .selectivePowerDown }
    if isLowTrust { return .publicSignalInterference }
    if isHighMomentum { return .connectedMomentum }
    return .stable
  }

  var accessibilitySummary: String {
    var values = [isLowEnergy ? "Low Founder Energy" : "Founder Energy stable"]
    values.append(isLowRunway ? "Low Runway" : "Runway healthy")
    values.append(isLowTrust ? "Low Company Trust" : "Company Trust stable")
    values.append(isHighMomentum ? "High Momentum" : "Momentum steady")
    return values.joined(separator: ". ")
  }

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
      momentum: min(1, max(0, Double(stats.momentum) / 100)),
      isLowEnergy: stats.energy <= 38,
      isLowRunway: stats.runway <= 8,
      isLowTrust: stats.trust <= 24,
      isHighMomentum: stats.momentum >= 70,
      runway: stats.runway,
      trust: stats.trust
    )
  }
}

struct InfrastructureVisual: Identifiable, Equatable, Sendable {
  enum State: Hashable, Sendable { case uninstalled, installing, installed, active }

  var id: FacilityUpgradeID
  var title: String
  var symbol: String
  var state: State
  var physicalLocation: InfrastructurePhysicalLocation

  static func map(
    purchased: Set<FacilityUpgradeID>,
    facility: FacilityTier,
    agents: [LivingAgentProjection],
    sprint: Int,
    installing: Set<FacilityUpgradeID> = []
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
      let state: State
      if installing.contains(definition.id) {
        state = .installing
      } else if !isInstalled {
        state = .uninstalled
      } else {
        state = facility == definition.requiredFacility && isRelevant ? .active : .installed
      }
      return Self(
        id: definition.id,
        title: definition.title,
        symbol: definition.symbol,
        state: state,
        physicalLocation: InfrastructurePhysicalLocation.map(definition.id)
      )
    }
  }
}

struct CompanyPhaseHierarchy: Equatable, Sendable {
  enum Priority: String, Equatable, Sendable {
    case planning = "Plan assignments"
    case working = "Watch active work"
    case review = "Inspect Founder tray"
    case resolution = "Lock Founder decision"
    case commit = "Commit sprint"
  }

  var priority: Priority
  var taskProminence: Double
  var stationProminence: Double
  var founderTrayProminence: Double
  var decisionProminence: Double
  var commitProminence: Double

  static func derive(
    sprintPhase: SprintPhase,
    agents: [LivingAgentProjection],
    founderSummary: CompanyCommandFounderSummary
  ) -> Self {
    if agents.contains(where: { $0.activity == .reviewing }) || founderSummary.reviewCount > 0 {
      return Self(priority: .review, taskProminence: 0.55, stationProminence: 0.72, founderTrayProminence: 1, decisionProminence: 0.55, commitProminence: 0.35)
    }
    if founderSummary.resolutionCount > 0 || agents.contains(where: { [.reviewed, .resolving, .resolved].contains($0.activity) }) {
      return Self(priority: .resolution, taskProminence: 0.55, stationProminence: 0.68, founderTrayProminence: 0.76, decisionProminence: 1, commitProminence: 0.45)
    }
    if sprintPhase == .readyToCommit {
      return Self(priority: .commit, taskProminence: 0.40, stationProminence: 0.55, founderTrayProminence: 0.55, decisionProminence: 0.55, commitProminence: 1)
    }
    if agents.contains(where: { [.assignmentReceived, .working, .workComplete].contains($0.activity) }) {
      return Self(priority: .working, taskProminence: 0.88, stationProminence: 1, founderTrayProminence: 0.62, decisionProminence: 0.35, commitProminence: 0.25)
    }
    return Self(priority: .planning, taskProminence: 1, stationProminence: 0.82, founderTrayProminence: 0.45, decisionProminence: 0.30, commitProminence: 0.25)
  }

  static func dominantAgentID(
    agents: [LivingAgentProjection],
    explicitFocus: CompanyCommandFocus?
  ) -> String? {
    if case .agent(let id) = explicitFocus { return id }
    return agents
      .filter { [.reviewing, .awaitingReview, .workComplete, .resolving, .assignmentReceived, .working].contains($0.activity) }
      .sorted {
        if emphasisRank($0.emphasis) != emphasisRank($1.emphasis) {
          return emphasisRank($0.emphasis) > emphasisRank($1.emphasis)
        }
        if $0.progress != $1.progress { return $0.progress > $1.progress }
        return canonicalRank($0.agentID) < canonicalRank($1.agentID)
      }
      .first?.agentID
  }

  private static func emphasisRank(_ emphasis: LivingPresentationEmphasis) -> Int {
    switch emphasis {
    case .normal: 0
    case .selected: 1
    case .founderAttention: 2
    case .inspection: 3
    case .decisionLock: 4
    case .levelUpCelebration: 5
    }
  }

  private static func canonicalRank(_ id: String) -> Int {
    ["aurora", "stacks", "brio"].firstIndex(of: id) ?? .max
  }
}

enum CompanyAtmosphereReaction: String, Equatable, Sendable {
  case stable
  case selectivePowerDown
  case runwayDepletion
  case publicSignalInterference
  case connectedMomentum
}

enum InfrastructurePhysicalLocation: String, CaseIterable, Equatable, Sendable {
  case stacksBuildRail
  case auroraFounderVerificationBridge
  case brioBroadcastRail
  case recoverySideBay
  case founderForegroundDesk

  static func map(_ id: FacilityUpgradeID) -> Self {
    switch id {
    case .developmentRig: .stacksBuildRail
    case .verificationArray: .auroraFounderVerificationBridge
    case .campaignStudio: .brioBroadcastRail
    case .recoveryCorner: .recoverySideBay
    case .founderCommandDesk: .founderForegroundDesk
    }
  }
}

enum CompanySpatialPresentation: String, Equatable, Sendable {
  case improvisedGarage
  case elevatedLoft

  static func map(_ facility: FacilityTier) -> Self {
    facility == .founderLoft ? .elevatedLoft : .improvisedGarage
  }
}

enum CompanyCausalObjectKind: String, CaseIterable, Hashable, Sendable {
  case assignmentPacket
  case completedArtifact
  case resolutionResponse
}

enum CompanyCausalEndpoint: String, CaseIterable, Hashable, Sendable {
  case roleMonitor
  case founderReviewTray
  case affectedCompanySystem
}

struct CompanyCausalObject: Identifiable, Equatable, Sendable {
  var id: String
  var taskID: UUID
  var agentID: String
  var kind: CompanyCausalObjectKind
  var endpoint: CompanyCausalEndpoint
  var atEndpoint: Bool

  static func project(agent: LivingAgentProjection, reduceMotion: Bool) -> Self? {
    guard let taskID = agent.taskID else { return nil }
    let kind: CompanyCausalObjectKind
    let endpoint: CompanyCausalEndpoint
    let settled: Bool
    switch agent.activity {
    case .assignmentReceived:
      kind = .assignmentPacket
      endpoint = .roleMonitor
      settled = reduceMotion
    case .workComplete:
      kind = .completedArtifact
      endpoint = .founderReviewTray
      settled = reduceMotion
    case .awaitingReview, .reviewing, .reviewed:
      kind = .completedArtifact
      endpoint = .founderReviewTray
      settled = true
    case .resolving:
      kind = .resolutionResponse
      endpoint = .affectedCompanySystem
      settled = reduceMotion
    case .resolved:
      kind = .resolutionResponse
      endpoint = .affectedCompanySystem
      settled = true
    default:
      return nil
    }
    return Self(
      id: "\(kind.rawValue)-\(taskID.uuidString)",
      taskID: taskID,
      agentID: agent.agentID,
      kind: kind,
      endpoint: endpoint,
      atEndpoint: settled
    )
  }
}

/// Narrow, visible-safe contract shared by native and future bespoke renderers.
/// Task results, quality, RNG, persistence, and action availability cannot enter
/// the character pipeline because they are not members of this value.
struct LivingAgentCharacterInput: Equatable, Sendable {
  var role: AgentRole
  var activity: LivingAgentActivity
  var conditions: Set<LivingAgentCondition>
  var emphasis: LivingPresentationEmphasis
  var reduceMotion: Bool
  var levelUpTrigger: Bool

  static func project(agent: LivingAgentProjection, reduceMotion: Bool) -> Self {
    Self(
      role: agent.role,
      activity: agent.activity,
      conditions: agent.conditions,
      emphasis: agent.emphasis,
      reduceMotion: reduceMotion,
      levelUpTrigger: agent.emphasis == .levelUpCelebration
    )
  }
}

enum LivingAgentRendererKind: String, Equatable, Sendable {
  case nativePortrait

  static var shipped: Self { .nativePortrait }
}

enum ReviewResultVisual: String, CaseIterable, Equatable, Sendable {
  case pending
  case verified
  case overclaimed
  case driftDetected
  case evidenceIncomplete

  static func map(conditions: Set<LivingAgentCondition>, revealStep: Int) -> Self {
    guard revealStep >= 5 else { return .pending }
    if conditions.contains(.overclaimed) { return .overclaimed }
    if conditions.contains(.drifting) { return .driftDetected }
    if conditions.contains(.evidenceIncomplete) { return .evidenceIncomplete }
    if conditions.contains(.verified) { return .verified }
    return .pending
  }
}

struct ViewportTextPriorityProjection: Equatable, Sendable {
  var visibleOverviewFields: [String]
  var focusOnlyFields: [String]
  var accessibilityOnlyFields: [String]

  static let build32_3 = Self(
    visibleOverviewFields: ["agentName", "safeActivity", "taskTitle", "primaryAction", "criticalWarning"],
    focusOnlyFields: ["role", "level", "stress", "trust", "detailedProgress"],
    accessibilityOnlyFields: ["infrastructureTitle", "facilityStructure", "causalJourney"]
  )
}

enum ViewportSelectionMap {
  static func workstationID(for agentID: String, canonicalAgentIDs: [String]) -> String? {
    canonicalAgentIDs.contains(agentID) ? agentID : nil
  }
}
