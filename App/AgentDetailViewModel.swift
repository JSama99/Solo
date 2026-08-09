import Foundation

/// Immutable data shared by every read-only Agent Detail entry point.
struct AgentDetailViewModel: Identifiable, Equatable {
  var id: String { agentID }
  var agentID: String
  var name: String
  var initials: String
  var role: AgentRole
  var modelFamily: String
  var trust: Double
  var trustBand: AgentStationViewModel.TrustBand
  var status: String
  var statusGlyph: String
  var mood: String
  var taskTitle: String?
  /// The simulation does not persist per-agent trust deltas, so this remains
  /// empty until such history exists rather than inventing a visual record.
  var recentTrustDeltas: [Int]

  static func derive(agent: SoloAgent, task: SoloTask?, founderStats: FounderStats) -> Self {
    Self(station: .derive(agent: agent, task: task, founderStats: founderStats))
  }

  init(station: AgentStationViewModel) {
    agentID = station.agentID
    name = station.name
    initials = station.initials
    role = station.role
    modelFamily = station.modelFamily
    trust = station.trust
    trustBand = station.trustBand
    status = station.semanticState.label
    statusGlyph = station.semanticState.glyph
    mood = station.mood
    taskTitle = station.taskTitle
    recentTrustDeltas = []
  }
}
