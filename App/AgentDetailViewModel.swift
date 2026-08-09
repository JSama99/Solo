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
  var level: Int
  var xp: Int
  var nextLevelXP: Int?
  var stress: Int
  var stressBand: AgentStressBand
  var specialization: String?
  var perks: Set<AgentPerkID>
  var ambition: String
  var ambitionCompleted: Bool

  static func derive(agent: SoloAgent, task: SoloTask?, founderStats: FounderStats) -> Self {
    var detail = Self(station: .derive(agent: agent, task: task, founderStats: founderStats))
    detail.level = agent.progression.level
    detail.xp = agent.progression.xp
    detail.nextLevelXP = AgentLevel.nextThreshold(forXP: agent.progression.xp)
    detail.stress = agent.progression.stressLevel
    detail.stressBand = agent.progression.stressBand
    detail.specialization = agent.progression.specialization
    detail.perks = agent.progression.selectedPerks
    detail.ambition = agent.ambition
    detail.ambitionCompleted = agent.progression.ambitionCompleted
    return detail
  }

  static func commandDeck(agent: SoloAgent, task: SoloTask, founderStats: FounderStats) -> Self {
    derive(agent: agent, task: task, founderStats: founderStats)
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
    level = station.progression.level
    xp = station.progression.xp
    nextLevelXP = AgentLevel.nextThreshold(forXP: xp)
    stress = station.progression.stressLevel
    stressBand = station.progression.stressBand
    specialization = station.progression.specialization
    perks = station.progression.selectedPerks
    ambition = station.ambition
    ambitionCompleted = station.progression.ambitionCompleted
  }
}
