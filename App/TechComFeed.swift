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
    let press = pressInquiry(venture: venture, sprint: sprint, stats: stats, rival: rival)
    var posts: [FeedPost] = [press]

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

  private static func pressInquiry(venture: Int, sprint: Int, stats: FounderStats, rival: RivalStanding?) -> FeedPost {
    let narrative = mediaNarrative(stats: stats, rival: rival)
    return FeedPost(
      id: "press-\(venture)-\(sprint)",
      kind: .pressInquiry,
      headline: narrative.headline,
      body: narrative.body,
      venture: venture,
      sprint: sprint,
      actions: [
        FeedAction(
          id: "statement",
          label: narrative.statementLabel,
          detail: narrative.statementDetail,
          requiresStatement: true,
          effects: SimulationEffects(trust: -1),
          coverageDelta: 12
        ),
        FeedAction(
          id: "silence",
          label: "Decline to comment",
          detail: narrative.silenceDetail,
          requiresStatement: false,
          effects: SimulationEffects(trust: -3),
          coverageDelta: -6
        )
      ]
    )
  }

  private static func mediaNarrative(stats: FounderStats, rival: RivalStanding?) -> MediaNarrative {
    let coverage = stats.coverage
    let trust = stats.trust
    let momentum = stats.momentum

    if coverage >= 60 {
      return MediaNarrative(
        headline: "Tech.com puts SOLO under the spotlight",
        body: "Coverage is at +\(coverage). The company is no longer operating quietly; every public move now carries more scrutiny.",
        statementLabel: "Own the spotlight",
        statementDetail: "Put the Founder on record while attention is concentrated on SOLO.",
        silenceDetail: "Leave a high-attention story for commentators and rivals to frame without you."
      )
    }

    if coverage <= -30 || trust <= 35 {
      return MediaNarrative(
        headline: "Tech.com questions SOLO's credibility",
        body: "Public sentiment is under pressure: coverage \(signed(coverage)), trust \(trust). The next explanation may define whether skepticism hardens.",
        statementLabel: "Answer with evidence",
        statementDetail: "Address the credibility gap publicly and make the company defend what it can prove.",
        silenceDetail: "Decline the challenge and accept that the skeptical narrative may travel farther."
      )
    }

    if momentum >= 70 && trust >= 60 {
      return MediaNarrative(
        headline: "Tech.com asks whether SOLO's momentum is durable",
        body: "Momentum is \(momentum) with trust at \(trust). Attention is shifting from whether SOLO can move to whether it can sustain the run.",
        statementLabel: "Define the run",
        statementDetail: "Use the moment to frame what is driving the company's progress before the market invents its own explanation.",
        silenceDetail: "Let strong operating results speak alone while outsiders decide what the run means."
      )
    }

    if let rival, rival.marketShare >= 0.25 {
      return MediaNarrative(
        headline: "Tech.com asks how SOLO will answer \(rival.name)",
        body: "\(rival.name) now holds \(Int((rival.marketShare * 100).rounded()))% market share. SOLO's public posture is becoming part of the competitive story.",
        statementLabel: "Set the competitive frame",
        statementDetail: "Respond publicly without abandoning the operating plan.",
        silenceDetail: "Keep the plan private and let the rival's move dominate the public frame."
      )
    }

    return MediaNarrative(
      headline: "Tech.com asks SOLO to explain its operating posture",
      body: "Coverage is \(signed(coverage)), trust \(trust), momentum \(momentum). A public response can shape how the market interprets the company's next move.",
      statementLabel: "Give a statement",
      statementDetail: "Trade a little trust for a clearer public narrative.",
      silenceDetail: "Let the story travel without you."
    )
  }

  private static func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
  }

  private struct MediaNarrative {
    var headline: String
    var body: String
    var statementLabel: String
    var statementDetail: String
    var silenceDetail: String
  }
}
