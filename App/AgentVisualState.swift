import Foundation

struct AgentVisualState: Equatable {
  enum Activity: Equatable {
    case idle
    case working
    case reviewed
  }

  enum Verification: Equatable {
    case none
    case verified
    case confirmed
    case overclaiming(Int)
    case driftDetected
    case evidenceIncomplete
  }

  enum Warning: Hashable {
    case drifting
    case overloaded
  }

  var activity: Activity
  var verification: Verification
  var warnings: Set<Warning>

  static func derive(agent: SoloAgent, task: SoloTask?, founderStats: FounderStats) -> Self {
    guard let task, task.assignedAgentID == agent.id else {
      return Self(
        activity: .idle,
        verification: .none,
        warnings: agent.drift >= 35 ? [.drifting] : []
      )
    }
    let visible = task.result.map(VisibleSimulationProjection.taskResult)
    let activity: Activity = task.isReviewed ? .reviewed : .working
    let verification: Verification
    switch visible?.verificationState {
    case .verified: verification = .verified
    case .confirmed: verification = .confirmed
    case .overclaimed: verification = .overclaiming(visible?.overclaimAmount ?? 0)
    case .driftDetected: verification = .driftDetected
    case .evidenceIncomplete: verification = .evidenceIncomplete
    case .reported, .unverified, .none: verification = .none
    }
    var warnings = Set<Warning>()
    if agent.drift >= 35 || verification == .driftDetected {
      warnings.insert(.drifting)
    }
    let roleMismatch = agent.role != task.role && agent.role != .general && task.role != .general
    let companyStrained = founderStats.energy <= 38
      || founderStats.trust <= 24
      || founderStats.runway <= 8
    if agent.progression.stressBand == .overloaded || agent.progression.stressBand == .critical
      || (agent.drift >= 35 && (roleMismatch || companyStrained)) {
      warnings.insert(.overloaded)
    }
    return Self(activity: activity, verification: verification, warnings: warnings)
  }

  var accessibilityValue: String {
    var parts: [String] = []
    switch activity {
    case .idle: parts.append("Ready")
    case .working: parts.append("Working on an unverified report")
    case .reviewed: parts.append("Founder review completed")
    }
    switch verification {
    case .none: break
    case .verified: parts.append("Verified")
    case .confirmed: parts.append("Confirmed")
    case .overclaiming(let amount): parts.append("Overclaim of \(amount)")
    case .driftDetected: parts.append("Drift detected")
    case .evidenceIncomplete: parts.append("Evidence incomplete; actual quality remains hidden")
    }
    if warnings.contains(.overloaded) { parts.append("Visible workload warning") }
    if warnings.contains(.drifting) { parts.append("Elevated drift") }
    return parts.joined(separator: ", ")
  }
}
