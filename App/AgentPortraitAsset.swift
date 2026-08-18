import Foundation

/// Centralizes the fixed portrait contract so UI rendering cannot accidentally
/// swap agent identity when the asset catalog is updated.
enum AgentPortraitAsset {
  static func name(for agentID: String) -> String? {
    switch agentID {
    case "aurora": "agent_aurora_portrait"
    case "stacks": "agent_stacks_portrait"
    case "brio": "agent_brio_portrait"
    default: nil
    }
  }
}
