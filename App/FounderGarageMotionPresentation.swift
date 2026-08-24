import Foundation

/// The five independent presentation channels used by the physical Founder
/// environment. None of these values are simulation authority.
enum FounderGarageMotionLayer: String, CaseIterable, Equatable, Sendable {
  case camera
  case ambient
  case agentActivity
  case agentCondition
  case eventEmphasis
}

enum FounderGarageStationWorkflow: String, CaseIterable, Equatable, Sendable {
  case idle
  case assignmentArrival
  case researchScan
  case engineeringBuild
  case campaignDistribution
  case artifactReady
  case reviewing
  case reviewed
  case resolutionDispatch
  case resolved
  case resting
}

enum FounderGarageArtifactState: String, Equatable, Sendable {
  case none
  case inboundTask
  case assembling
  case returnedForReview
}

/// Object-level physical presentation derived exclusively from player-visible
/// lifecycle state. Values are deliberately role-neutral and contain no result
/// quality, verification, or resolution data.
struct FounderGarageStationPhysicalPresentation: Equatable, Sendable {
  var portraitMotionEnabled: Bool
  var portraitLightIntensity: Double
  var primaryDisplayIntensity: Double
  var secondaryDisplayIntensity: Double
  var coolingActivity: Double
  var indicatorActivity: Double
  var artifactState: FounderGarageArtifactState
  var artifactProgress: Double

  static func derive(
    activity: LivingAgentActivity,
    visibleProgress: Double,
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let active = sceneActive && !reduceMotion
    let isWorking = activity == .working
    let isOperating = [.assignmentReceived, .working, .reviewing, .resolving].contains(activity)
    let artifactState: FounderGarageArtifactState
    switch activity {
    case .assignmentReceived:
      artifactState = .inboundTask
    case .working:
      artifactState = .assembling
    case .workComplete, .awaitingReview:
      artifactState = .returnedForReview
    default:
      artifactState = .none
    }

    return Self(
      portraitMotionEnabled: active && [.idle, .working].contains(activity),
      portraitLightIntensity: isOperating ? 0.78 : activity == .awaitingReview ? 0.58 : 0.28,
      primaryDisplayIntensity: isOperating ? 0.94 : activity == .idle ? 0.24 : 0.62,
      secondaryDisplayIntensity: isWorking ? 0.84 : activity == .assignmentReceived ? 0.58 : 0.18,
      coolingActivity: active && isWorking ? 0.82 : active ? 0.12 : 0,
      indicatorActivity: activity == .awaitingReview ? 1 : isOperating ? 0.72 : 0.18,
      artifactState: artifactState,
      artifactProgress: min(1, max(0, visibleProgress))
    )
  }
}

enum FounderGarageVisibleEvent: Equatable, Sendable {
  case assignment(id: UUID, agentID: String)
  case review(id: UUID, agentID: String)
  case sprint(id: UUID)

  var id: UUID {
    switch self {
    case .assignment(let id, _), .review(let id, _), .sprint(let id): id
    }
  }
}

enum FounderGarageEventKind: String, Equatable, Sendable {
  case none
  case assignmentArrived
  case founderReviewRequired
  case reviewCompleted
  case resolutionLocked
  case sprintCommitted
}

struct FounderGarageCameraMotion: Equatable, Sendable {
  var mode: FounderEnvironmentMode
  var revealProgress: Double
  var showsMonitorHardware: Bool
  var showsDeskHardware: Bool
  var computerIsInteractive: Bool

  static func derive(mode: FounderEnvironmentMode) -> Self {
    let freeLook = mode == .freeLook
    return Self(
      mode: mode,
      revealProgress: freeLook ? 1 : 0,
      showsMonitorHardware: true,
      showsDeskHardware: true,
      computerIsInteractive: !freeLook
    )
  }
}

struct FounderGarageAmbientMotion: Equatable, Sendable {
  var continuousMotionEnabled: Bool
  var fanActivity: Double
  var ledBreathing: Double
  var scanNoise: Double
  var particleDensity: Double

  static func derive(
    agents: [LivingAgentProjection],
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let workingCount = agents.filter {
      [.assignmentReceived, .working, .reviewing, .resolving].contains($0.activity)
    }.count
    let enabled = sceneActive && !reduceMotion
    return Self(
      continuousMotionEnabled: enabled,
      fanActivity: enabled ? min(1, 0.16 + Double(workingCount) * 0.24) : 0,
      ledBreathing: enabled ? (workingCount == 0 ? 0.18 : 0.48) : 0,
      scanNoise: enabled ? min(0.42, Double(workingCount) * 0.12) : 0,
      particleDensity: enabled ? (workingCount == 0 ? 0.04 : 0.09) : 0
    )
  }
}

struct FounderGarageStationMotion: Equatable, Sendable {
  var agentID: String
  var role: AgentRole
  var activity: LivingAgentActivity
  var workflow: FounderGarageStationWorkflow
  var activityIntensity: Double
  var localLightIntensity: Double
  var equipmentActivity: Double
  var visibleProgress: Double
  var safeConditionSignals: Set<LivingAgentCondition>
  var needsFounderAttention: Bool
  var continuousMotionEnabled: Bool
  var eventToken: UUID?
  var physical: FounderGarageStationPhysicalPresentation

  static func derive(
    agent: LivingAgentProjection,
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let workflow = workflow(for: agent)
    let intensity = activityIntensity(for: agent.activity)
    let visibleConditions = agent.conditions.filter {
      if [.focused, .stressed, .overloaded].contains($0) { return true }
      return agent.reviewRevealStep >= 5
    }
    return Self(
      agentID: agent.agentID,
      role: agent.role,
      activity: agent.activity,
      workflow: workflow,
      activityIntensity: intensity,
      localLightIntensity: min(1, 0.18 + intensity * 0.68),
      equipmentActivity: min(1, intensity * 0.86),
      visibleProgress: min(1, max(0, agent.progress)),
      safeConditionSignals: visibleConditions,
      needsFounderAttention: agent.needsFounderAttention,
      continuousMotionEnabled: sceneActive && !reduceMotion && agent.activity == .working,
      eventToken: agent.presentationSequenceID,
      physical: .derive(
        activity: agent.activity,
        visibleProgress: agent.progress,
        reduceMotion: reduceMotion,
        sceneActive: sceneActive
      )
    )
  }

  private static func workflow(for agent: LivingAgentProjection) -> FounderGarageStationWorkflow {
    switch agent.activity {
    case .idle: .idle
    case .assignmentReceived: .assignmentArrival
    case .working:
      switch agent.role {
      case .research: .researchScan
      case .engineering: .engineeringBuild
      case .marketing: .campaignDistribution
      case .general: .engineeringBuild
      }
    case .workComplete, .awaitingReview: .artifactReady
    case .reviewing: .reviewing
    case .reviewed: .reviewed
    case .resolving: .resolutionDispatch
    case .resolved: .resolved
    case .resting: .resting
    }
  }

  private static func activityIntensity(for activity: LivingAgentActivity) -> Double {
    switch activity {
    case .idle: 0.10
    case .assignmentReceived: 0.58
    case .working: 0.82
    case .workComplete, .awaitingReview: 0.42
    case .reviewing: 0.54
    case .reviewed: 0.24
    case .resolving: 0.68
    case .resolved: 0.18
    case .resting: 0.05
    }
  }
}

struct FounderGarageLightingPresentation: Equatable, Sendable {
  var practicalLightIntensity: Double
  var founderMonitorGlow: Double
  var warningIntensity: Double
  var momentumConnectionIntensity: Double
  var brioPublicSignalStability: Double
  var founderNotificationIntensity: Double

  static func derive(
    atmosphere: CompanyAtmosphere,
    stations: [FounderGarageStationMotion],
    event: FounderGarageEventEmphasis
  ) -> Self {
    let activeCount = stations.filter { $0.activityIntensity >= 0.5 }.count
    let attention = stations.contains { $0.needsFounderAttention }
    return Self(
      practicalLightIntensity: max(0.32, min(0.86, 0.38 + atmosphere.energy * 0.42)),
      founderMonitorGlow: min(0.92, 0.42 + Double(activeCount) * 0.09),
      warningIntensity: atmosphere.isLowRunway ? 0.62 : 0,
      momentumConnectionIntensity: atmosphere.isHighMomentum ? 0.72 : 0.14,
      brioPublicSignalStability: atmosphere.isLowTrust ? 0.52 : 1,
      founderNotificationIntensity: attention ? 0.88 : event.kind == .none ? 0 : 0.52
    )
  }
}

struct FounderGarageEventEmphasis: Equatable, Sendable {
  var kind: FounderGarageEventKind
  var agentID: String?
  var token: UUID?
  var priority: Int
  var duration: TimeInterval

  static let none = Self(kind: .none, priority: 0, duration: 0)

  static func derive(
    agents: [LivingAgentProjection],
    visibleEvent: FounderGarageVisibleEvent?
  ) -> Self {
    if let attention = agents
      .filter(\.needsFounderAttention)
      .sorted(by: { canonicalRank($0.agentID) < canonicalRank($1.agentID) })
      .first {
      return Self(
        kind: .founderReviewRequired,
        agentID: attention.agentID,
        token: attention.presentationSequenceID ?? attention.taskID,
        priority: 5,
        duration: 0.86
      )
    }

    if let visibleEvent {
      switch visibleEvent {
      case .sprint(let id):
        return Self(kind: .sprintCommitted, token: id, priority: 4, duration: 1.0)
      case .review(let id, let agentID):
        return Self(kind: .reviewCompleted, agentID: agentID, token: id, priority: 3, duration: 0.72)
      case .assignment(let id, let agentID):
        return Self(kind: .assignmentArrived, agentID: agentID, token: id, priority: 2, duration: 0.58)
      }
    }

    if let resolving = agents
      .filter({ [.resolving, .resolved].contains($0.activity) })
      .sorted(by: { canonicalRank($0.agentID) < canonicalRank($1.agentID) })
      .first {
      return Self(
        kind: .resolutionLocked,
        agentID: resolving.agentID,
        token: resolving.presentationSequenceID ?? resolving.taskID,
        priority: 1,
        duration: 0.64
      )
    }
    return .none
  }

  private static func canonicalRank(_ id: String) -> Int {
    ["aurora", "stacks", "brio"].firstIndex(of: id) ?? .max
  }
}

struct FounderGarageMotionPresentation: Equatable, Sendable {
  var layers: [FounderGarageMotionLayer]
  var camera: FounderGarageCameraMotion
  var ambient: FounderGarageAmbientMotion
  var stations: [FounderGarageStationMotion]
  var lighting: FounderGarageLightingPresentation
  var event: FounderGarageEventEmphasis

  static func derive(
    environment: FounderEnvironmentProjection,
    camera: FounderEnvironmentCameraState,
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let stations = environment.agents.map {
      FounderGarageStationMotion.derive(
        agent: $0,
        reduceMotion: reduceMotion,
        sceneActive: sceneActive
      )
    }
    let event = FounderGarageEventEmphasis.derive(
      agents: environment.agents,
      visibleEvent: environment.visibleEvent
    )
    return Self(
      layers: FounderGarageMotionLayer.allCases,
      camera: .derive(mode: camera.mode),
      ambient: .derive(
        agents: environment.agents,
        reduceMotion: reduceMotion,
        sceneActive: sceneActive
      ),
      stations: stations,
      lighting: .derive(atmosphere: environment.atmosphere, stations: stations, event: event),
      event: event
    )
  }

  func station(for agentID: String) -> FounderGarageStationMotion? {
    stations.first { $0.agentID == agentID }
  }
}
