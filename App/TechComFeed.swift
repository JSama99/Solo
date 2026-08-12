import Foundation

enum FeedPostKind: String, Codable, Hashable {
  case pressInquiry, rivalMove, trendSignal, talentListing
}

struct FeedAction: Identifiable, Hashable, Codable {
  var id: String
  var label: String
  var detail: String
  var requiresStatement: Bool
  var effects: SimulationEffects
  var coverageDelta: Int = 0
  var grantsTaskTitle: String? = nil
}

struct FeedPost: Identifiable, Hashable, Codable {
  var id: String
  var kind: FeedPostKind
  var headline: String
  var body: String
  var venture: Int
  var sprint: Int
  var actions: [FeedAction] = []
  var resolvedActionID: String?
}

enum TechComFeedEngine {
  static func posts(venture: Int, sprint: Int, stats: FounderStats, standings: [RivalStanding]) -> [FeedPost] {
    let rival = standings.first(where: { !$0.isPlayer })
    var posts: [FeedPost] = [
      FeedPost(id: "press-\(venture)-\(sprint)", kind: .pressInquiry, headline: "Tech.com asks SOLO to explain its operating posture", body: "A public response can shape the story before commentators do.", venture: venture, sprint: sprint, actions: [
        FeedAction(id: "statement", label: "Give a statement", detail: "Trade a little trust for a clearer public narrative.", requiresStatement: true, effects: SimulationEffects(trust: -1), coverageDelta: 12),
        FeedAction(id: "silence", label: "Decline to comment", detail: "Let the story travel without you.", requiresStatement: false, effects: SimulationEffects(trust: -3), coverageDelta: -6)
      ])
    ]
    if let rival {
      posts.append(FeedPost(id: "rival-\(rival.id)-\(venture)-\(sprint)", kind: .rivalMove, headline: "\(rival.name) pressures the category", body: "Its market share is now \(Int((rival.marketShare * 100).rounded()))%.", venture: venture, sprint: sprint, actions: [
        FeedAction(id: "counter", label: "Counter with proof", detail: "Put a targeted response into the next task draft.", requiresStatement: true, effects: SimulationEffects(momentum: 2), coverageDelta: 6, grantsTaskTitle: "Counter \(rival.name)"),
        FeedAction(id: "ignore", label: "Ignore the move", detail: "Keep your current plan.", requiresStatement: false, effects: SimulationEffects())
      ]))
    }
    let nextEra = VentureEra.era(for: venture + VentureEra.venturesPerEra)
    posts.append(FeedPost(id: "trend-\(venture)", kind: .trendSignal, headline: "Ahead: \(nextEra.name) pressure", body: nextEra.newForce, venture: venture, sprint: sprint))
    return posts
  }
}
