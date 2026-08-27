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
  var portraitEdgeLightIntensity: Double
  var postureOffsetY: Double
  var postureScale: Double
  var breathingAmplitude: Double
  var deskLightIntensity: Double
  var primaryDisplayIntensity: Double
  var secondaryDisplayIntensity: Double
  var coolingActivity: Double
  var indicatorActivity: Double
  var artifactState: FounderGarageArtifactState
  var artifactProgress: Double
  var focalEmphasis: Double
  var keyLightIntensity: Double
  var fillLightIntensity: Double
  var rimLightIntensity: Double
  var shadowMassOpacity: Double
  var reactionIntensity: Double
  var reactionMotionEnabled: Bool

  static func derive(
    activity: LivingAgentActivity,
    visibleProgress: Double,
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let active = sceneActive && !reduceMotion
    let isWorking = activity == .working
    let isOperating = [.assignmentReceived, .working, .reviewing, .resolving].contains(activity)
    let isAwaitingReview = [.workComplete, .awaitingReview].contains(activity)
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
      portraitEdgeLightIntensity: isOperating ? 0.72 : isAwaitingReview ? 0.48 : 0.24,
      postureOffsetY: isWorking ? 2.2 : activity == .assignmentReceived ? 1.2 : isAwaitingReview ? -0.4 : 0,
      postureScale: isWorking ? 1.018 : activity == .assignmentReceived ? 1.009 : 1,
      breathingAmplitude: active && [.idle, .working].contains(activity) ? (isWorking ? 0.72 : 1.05) : 0,
      deskLightIntensity: isOperating ? 0.74 : isAwaitingReview ? 0.50 : 0.22,
      primaryDisplayIntensity: isOperating ? 0.94 : activity == .idle ? 0.24 : 0.62,
      secondaryDisplayIntensity: isWorking ? 0.84 : activity == .assignmentReceived ? 0.58 : 0.18,
      coolingActivity: active && isWorking ? 0.82 : active ? 0.12 : 0,
      indicatorActivity: activity == .awaitingReview ? 1 : isOperating ? 0.72 : 0.18,
      artifactState: artifactState,
      artifactProgress: min(1, max(0, visibleProgress)),
      focalEmphasis: isWorking ? 1 : isAwaitingReview ? 0.82 : isOperating ? 0.76 : 0.42,
      keyLightIntensity: isOperating ? 0.88 : isAwaitingReview ? 0.70 : 0.42,
      fillLightIntensity: isOperating ? 0.38 : 0.24,
      rimLightIntensity: isOperating ? 0.62 : isAwaitingReview ? 0.48 : 0.26,
      shadowMassOpacity: isOperating || isAwaitingReview ? 0.30 : 0.46,
      reactionIntensity: isWorking ? 0.92 : activity == .assignmentReceived ? 0.72 : isAwaitingReview ? 0.58 : 0.16,
      reactionMotionEnabled: active && [.assignmentReceived, .working, .workComplete, .awaitingReview].contains(activity)
    )
  }
}

/// Presentation hook points for the existing lightweight audio engine. They
/// contain only visible lifecycle and event semantics and do not play audio by
/// themselves, keeping view rendering and simulation timing independent.
enum FounderGarageAudioCue: String, CaseIterable, Equatable, Sendable {
  case monitorWake
  case researchScanner
  case buildActivity
  case campaignActivity
  case reviewReady
  case garageVentilation
  case serverHum
  case equipmentCooling
  case distantGarage
}

struct FounderGarageAudioHookPresentation: Equatable, Sendable {
  var cues: [FounderGarageAudioCue]
  var ambientCues: [FounderGarageAudioCue]
  var eventToken: UUID?

  static func derive(
    stations: [FounderGarageStationMotion],
    event: FounderGarageEventEmphasis
  ) -> Self {
    var cues: [FounderGarageAudioCue] = []
    for station in stations {
      switch station.workflow {
      case .assignmentArrival:
        cues.append(.monitorWake)
      case .researchScan:
        cues.append(.researchScanner)
      case .engineeringBuild:
        cues.append(.buildActivity)
      case .campaignDistribution:
        cues.append(.campaignActivity)
      case .artifactReady:
        cues.append(.reviewReady)
      default:
        break
      }
    }
    if event.kind == .founderReviewRequired, !cues.contains(.reviewReady) {
      cues.append(.reviewReady)
    }
    return Self(
      cues: cues,
      ambientCues: [.garageVentilation, .serverHum, .equipmentCooling, .distantGarage],
      eventToken: event.token
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
  var environmentOpacity: Double
  var computerOpacity: Double
  var showsMonitorHardware: Bool
  var showsDeskHardware: Bool
  var computerIsInteractive: Bool

  static func derive(mode: FounderEnvironmentMode) -> Self {
    switch mode {
    case .computerFocused:
      return Self(mode: mode, revealProgress: 0, environmentOpacity: 1, computerOpacity: 1, showsMonitorHardware: false, showsDeskHardware: false, computerIsInteractive: true)
    case .transitioningToComputerFocus:
      return Self(mode: mode, revealProgress: 0, environmentOpacity: 1, computerOpacity: 1, showsMonitorHardware: true, showsDeskHardware: true, computerIsInteractive: false)
    case .freeLook:
      return Self(mode: mode, revealProgress: 1, environmentOpacity: 1, computerOpacity: 1, showsMonitorHardware: true, showsDeskHardware: true, computerIsInteractive: false)
    case .transitioningToFreeLook:
      return Self(mode: mode, revealProgress: 1, environmentOpacity: 1, computerOpacity: 1, showsMonitorHardware: true, showsDeskHardware: true, computerIsInteractive: false)
    }
  }
}

struct FounderGarageAmbientMotion: Equatable, Sendable {
  var continuousMotionEnabled: Bool
  var fanActivity: Double
  var ledBreathing: Double
  var scanNoise: Double
  var particleDensity: Double
  var screenLife: Double
  var serverActivity: Double
  var lightingDrift: Double
  var perceptibleChannelCount: Int

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
      particleDensity: enabled ? (workingCount == 0 ? 0.04 : 0.09) : 0,
      screenLife: enabled ? (workingCount == 0 ? 0.22 : 0.52) : 0.16,
      serverActivity: enabled ? (workingCount == 0 ? 0.30 : 0.62) : 0.24,
      lightingDrift: enabled ? 0.20 : 0.12,
      perceptibleChannelCount: enabled ? 8 : 5
    )
  }
}

/// Safe, player-readable operating state for equipment that physically moves
/// in the Garage. This projection deliberately knows only visible workload,
/// lifecycle/accessibility state, and whether the scene can render.
struct FounderGarageMechanicalPresentation: Equatable, Sendable {
  var rearVentilationActivity: Double
  var rearVentilationRotationDuration: Double
  var serverCoolingActivity: Double
  var serverCoolingRotationDuration: Double
  var continuousRotationEnabled: Bool
  var staticActivityIndicationVisible: Bool

  static func derive(
    agents: [LivingAgentProjection],
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let operatingCount = agents.filter {
      [.assignmentReceived, .working, .reviewing, .resolving].contains($0.activity)
    }.count
    let workload = min(1, Double(operatingCount) / 3)
    return Self(
      rearVentilationActivity: 0.36 + workload * 0.38,
      rearVentilationRotationDuration: 15.2 - workload * 5.4,
      serverCoolingActivity: 0.30 + workload * 0.46,
      serverCoolingRotationDuration: 10.8 - workload * 3.7,
      continuousRotationEnabled: sceneActive && !reduceMotion,
      staticActivityIndicationVisible: true
    )
  }
}

/// Fixed presentation rhythms keep tertiary systems independent without
/// touching gameplay RNG or creating another simulation clock.
enum FounderGarageAmbientChannel: String, CaseIterable, Equatable, Sendable {
  case ventilation
  case router
  case founderDisplay
  case serverCooling
  case serverNetwork
  case auroraPresence
  case stacksPresence
  case brioPresence
  case environmentalLight
  case atmosphericDust
  case cableAirflow
  case ventilationShadow
}

struct FounderGarageAmbientRhythm: Equatable, Sendable {
  var channel: FounderGarageAmbientChannel
  var duration: Double
  var phase: Double
  var amplitude: Double

  static func profile(for channel: FounderGarageAmbientChannel) -> Self {
    switch channel {
    case .ventilation: Self(channel: channel, duration: 8.4, phase: 0.11, amplitude: 0.028)
    case .router: Self(channel: channel, duration: 1.7, phase: 0.47, amplitude: 0.045)
    case .founderDisplay: Self(channel: channel, duration: 6.8, phase: 0.29, amplitude: 0.032)
    case .serverCooling: Self(channel: channel, duration: 7.3, phase: 0.63, amplitude: 0.035)
    case .serverNetwork: Self(channel: channel, duration: 2.3, phase: 0.19, amplitude: 0.050)
    case .auroraPresence: Self(channel: channel, duration: 5.1, phase: 0.07, amplitude: 0.018)
    case .stacksPresence: Self(channel: channel, duration: 5.9, phase: 0.38, amplitude: 0.016)
    case .brioPresence: Self(channel: channel, duration: 6.7, phase: 0.74, amplitude: 0.019)
    case .environmentalLight: Self(channel: channel, duration: 12.6, phase: 0.52, amplitude: 0.030)
    case .atmosphericDust: Self(channel: channel, duration: 17.4, phase: 0.83, amplitude: 0.022)
    case .cableAirflow: Self(channel: channel, duration: 13.9, phase: 0.33, amplitude: 0.012)
    case .ventilationShadow: Self(channel: channel, duration: 15.2, phase: 0.68, amplitude: 0.018)
    }
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

enum FounderGarageEnvironmentDetail: Int, Equatable, Sendable {
  case improvised
  case equipped
  case established
}

/// Static depth and material policy derived only from player-visible facility
/// ownership. It never receives task results, review truth, or simulation RNG.
struct FounderGarageEnvironmentPresentation: Equatable, Sendable {
  var detail: FounderGarageEnvironmentDetail
  var installedInfrastructureCount: Int
  var rearContrast: Double
  var middleContrast: Double
  var foregroundContrast: Double
  var atmosphericMotionEnabled: Bool
  var atmosphericParticleCount: Int

  static func derive(
    facility: FacilityTier,
    infrastructure: [InfrastructureVisual],
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let installedCount = infrastructure.filter { $0.state != .uninstalled }.count
    let detail: FounderGarageEnvironmentDetail
    if facility != .founderGarage || installedCount >= 4 {
      detail = .established
    } else if installedCount >= 2 {
      detail = .equipped
    } else {
      detail = .improvised
    }
    let atmosphericMotionEnabled = sceneActive && !reduceMotion
    return Self(
      detail: detail,
      installedInfrastructureCount: installedCount,
      rearContrast: 0.74,
      middleContrast: 0.90,
      foregroundContrast: 1,
      atmosphericMotionEnabled: atmosphericMotionEnabled,
      atmosphericParticleCount: atmosphericMotionEnabled ? 7 : 0
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
  var mechanical: FounderGarageMechanicalPresentation
  var stations: [FounderGarageStationMotion]
  var lighting: FounderGarageLightingPresentation
  var environment: FounderGarageEnvironmentPresentation
  var event: FounderGarageEventEmphasis
  var audioHooks: FounderGarageAudioHookPresentation

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
      mechanical: .derive(
        agents: environment.agents,
        reduceMotion: reduceMotion,
        sceneActive: sceneActive
      ),
      stations: stations,
      lighting: .derive(atmosphere: environment.atmosphere, stations: stations, event: event),
      environment: .derive(
        facility: environment.facility,
        infrastructure: environment.infrastructure,
        reduceMotion: reduceMotion,
        sceneActive: sceneActive
      ),
      event: event,
      audioHooks: .derive(stations: stations, event: event)
    )
  }

  func station(for agentID: String) -> FounderGarageStationMotion? {
    stations.first { $0.agentID == agentID }
  }
}
