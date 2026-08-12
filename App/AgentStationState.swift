import Foundation

struct GarageTurnGate: Equatable {
  enum Primary: Equatable { case desk, stations }
  var phase: SprintPhase

  var primary: Primary {
    switch phase {
    case .founderEvent, .readyToCommit: .desk
    case .chooseCommitments, .assignTeam, .reviewAndResolve: .stations
    }
  }

  var deskIsActionable: Bool { primary == .desk || phase != .founderEvent }

  func stationIsActionable(_ station: AgentStationViewModel) -> Bool {
    switch phase {
    case .founderEvent, .readyToCommit: false
    case .chooseCommitments, .assignTeam: station.semanticState != .awaitingReview
    case .reviewAndResolve: station.semanticState == .awaitingReview
    }
  }
}

/// The immutable, visible data a Garage station may render. It deliberately has
/// no reference to GameStore, assignments, or a mutation callback.
struct AgentStationViewModel: Identifiable, Equatable {
  enum SemanticState: String, CaseIterable, Equatable {
    case idle
    case working
    case awaitingReview
    case drifting
    case overloaded
    case verified

    var label: String {
      switch self {
      case .idle: "Ready"
      case .working: "Working"
      case .awaitingReview: "Awaiting review"
      case .drifting: "Needs attention"
      case .overloaded: "Overloaded"
      case .verified: "Verified"
      }
    }

    var glyph: String {
      switch self {
      case .idle: "pause.fill"
      case .working: "hammer.fill"
      case .awaitingReview: "eye.fill"
      case .drifting: "waveform.badge.exclamationmark"
      case .overloaded: "exclamationmark.triangle.fill"
      case .verified: "checkmark.seal.fill"
      }
    }
  }

  enum TrustBand: Equatable {
    case coral
    case amber
    case teal

    init(trust: Double) {
      switch trust {
      case 85...: self = .teal
      case 65...: self = .amber
      default: self = .coral
      }
    }

    var label: String {
      switch self {
      case .coral: "Trust below 65"
      case .amber: "Trust 65 to 84"
      case .teal: "Trust 85 or higher"
      }
    }
  }

  var id: String { agentID }
  var agentID: String
  var name: String
  var initials: String
  var role: AgentRole
  var modelFamily: String
  var trust: Double
  var taskTitle: String?
  var semanticState: SemanticState
  var mood: String
  var progression: AgentProgressionState = .init()
  var ambition = "Help the company succeed."

  var trustBand: TrustBand { TrustBand(trust: trust) }

  var accessibilityValue: String {
    let task = taskTitle.map { "Task \($0)." } ?? "No current task."
    return "\(semanticState.label). Trust \(Int(trust.rounded())). \(task) Mood: \(mood)."
  }

  static func derive(agent: SoloAgent, task: SoloTask?, founderStats: FounderStats) -> Self {
    let visualState = AgentVisualState.derive(agent: agent, task: task, founderStats: founderStats)
    let semanticState: SemanticState
    if visualState.warnings.contains(.overloaded) {
      semanticState = .overloaded
    } else if visualState.warnings.contains(.drifting)
      || isVisibleConcern(visualState.verification) {
      semanticState = .drifting
    } else if isVerified(visualState.verification) {
      semanticState = .verified
    } else if task?.result != nil, task?.isReviewed == false {
      semanticState = .awaitingReview
    } else if task != nil {
      semanticState = .working
    } else {
      semanticState = .idle
    }
    return Self(
      agentID: agent.id,
      name: agent.name,
      initials: agent.initials,
      role: agent.role,
      modelFamily: agent.modelFamily,
      trust: agent.trust,
      taskTitle: task?.title,
      semanticState: semanticState,
      mood: mood(for: visualState, fallback: agent.trustLabel),
      progression: agent.progression,
      ambition: agent.ambition
    )
  }

  private static func isVisibleConcern(_ verification: AgentVisualState.Verification) -> Bool {
    switch verification {
    case .overclaiming, .driftDetected, .evidenceIncomplete: true
    case .none, .verified, .confirmed: false
    }
  }

  private static func isVerified(_ verification: AgentVisualState.Verification) -> Bool {
    switch verification {
    case .verified, .confirmed: true
    case .none, .overclaiming, .driftDetected, .evidenceIncomplete: false
    }
  }

  private static func mood(for state: AgentVisualState, fallback: String) -> String {
    if state.warnings.contains(.overloaded) { return "Under pressure" }
    if state.warnings.contains(.drifting) { return "Unsteady" }
    switch state.verification {
    case .verified, .confirmed: return "Resolved"
    case .overclaiming, .driftDetected, .evidenceIncomplete: return "Cautious"
    case .none: return state.activity == .idle ? fallback : "Focused"
    }
  }
}
