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

enum NarrativeThread: String, Codable, Hashable, Sendable {
  case momentum
  case credibility
  case rivalry
  case founderProfile
  case evidenceAndExecution
}

struct NarrativeBeat: Equatable, Hashable, Sendable {
  var id: String
  var thread: NarrativeThread
  var tone: PublicMediaTone
  var headline: String
  var summary: String
  var intensity: Int
  var sourceEventID: String?
  var preferredProgram: SignalTVProgram
}

struct NarrativeSnapshot: Equatable, Sendable {
  var activeThreads: [NarrativeThread]
  var leadBeat: NarrativeBeat?
}

struct NarrativeProjection: Equatable, Sendable {
  var headline: String
  var body: String
  var statementLabel: String
  var statementDetail: String
  var silenceDetail: String
}

/// Deterministic narrative interpretation of canonical public truth and current
/// public-facing company state. The director does not mutate simulation state,
/// consume simulation RNG, or inspect hidden task/result truth.
enum NarrativeDirector {
  static func evaluate(
    publicEvents: [PublicMediaEvent],
    stats: FounderStats,
    standings: [RivalStanding],
    venture: Int,
    sprint: Int
  ) -> NarrativeSnapshot {
    let publicPlayerEvents = publicEvents.filter { $0.isPublic && $0.concernsPlayerCompany }
    let latestEvent = publicPlayerEvents.max(by: eventPrecedes)
    let rival = standings.first(where: { !$0.isPlayer })

    let leadBeat = latestEvent.map(beat(for:)) ?? stateBeat(
      stats: stats,
      rival: rival,
      venture: venture,
      sprint: sprint
    )

    var threads: [NarrativeThread] = []
    if let leadBeat {
      threads.append(leadBeat.thread)
    }
    if stats.momentum >= 70 {
      appendUnique(.momentum, to: &threads)
    }
    if stats.trust <= 35 || stats.coverage <= -30 {
      appendUnique(.credibility, to: &threads)
    }
    if abs(stats.coverage) >= 60 {
      appendUnique(.founderProfile, to: &threads)
    }
    if let rival, rival.marketShare >= 0.25 {
      appendUnique(.rivalry, to: &threads)
    }

    return NarrativeSnapshot(activeThreads: threads, leadBeat: leadBeat)
  }

  static func techComProjection(for snapshot: NarrativeSnapshot, stats: FounderStats) -> NarrativeProjection {
    guard let beat = snapshot.leadBeat else {
      return fallbackProjection(stats: stats)
    }

    switch beat.thread {
    case .founderProfile:
      return NarrativeProjection(
        headline: beat.headline,
        body: beat.summary,
        statementLabel: "Own the spotlight",
        statementDetail: "Put the Founder on record while attention is concentrated on SOLO.",
        silenceDetail: "Leave a high-attention story for commentators and rivals to frame without you."
      )
    case .credibility:
      return NarrativeProjection(
        headline: beat.headline,
        body: beat.summary,
        statementLabel: "Answer with evidence",
        statementDetail: "Address the credibility gap publicly and make the company defend what it can prove.",
        silenceDetail: "Decline the challenge and accept that the skeptical narrative may travel farther."
      )
    case .momentum:
      return NarrativeProjection(
        headline: beat.headline,
        body: beat.summary,
        statementLabel: "Define the run",
        statementDetail: "Frame what is driving the company's progress before the market invents its own explanation.",
        silenceDetail: "Let strong operating results speak alone while outsiders decide what the run means."
      )
    case .rivalry:
      return NarrativeProjection(
        headline: beat.headline,
        body: beat.summary,
        statementLabel: "Set the competitive frame",
        statementDetail: "Respond publicly without abandoning the operating plan.",
        silenceDetail: "Keep the plan private and let the rival's move dominate the public frame."
      )
    case .evidenceAndExecution:
      return NarrativeProjection(
        headline: beat.headline,
        body: beat.summary,
        statementLabel: beat.tone == .critical ? "Answer with evidence" : "Put the proof on record",
        statementDetail: "Tie the public response to what SOLO has actually demonstrated.",
        silenceDetail: "Let the verified event travel without adding the Founder's framing."
      )
    }
  }

  private static func beat(for event: PublicMediaEvent) -> NarrativeBeat {
    let thread: NarrativeThread
    if event.isFundingSuccess {
      thread = .evidenceAndExecution
    } else if event.tone == .critical || event.coverageDelta < 0 {
      thread = .credibility
    } else if event.program == .founderSpotlight || event.coverageDelta >= 10 {
      thread = .founderProfile
    } else if event.tone == .favorable || event.coverageDelta > 0 {
      thread = .momentum
    } else {
      thread = .evidenceAndExecution
    }

    let intensity = min(100, max(20, 40 + abs(event.coverageDelta) * 4))
    return NarrativeBeat(
      id: "event-\(event.id)",
      thread: thread,
      tone: event.tone,
      headline: event.headline,
      summary: event.summary,
      intensity: intensity,
      sourceEventID: event.id,
      preferredProgram: event.program
    )
  }

  private static func stateBeat(
    stats: FounderStats,
    rival: RivalStanding?,
    venture: Int,
    sprint: Int
  ) -> NarrativeBeat {
    let coverage = stats.coverage
    let trust = stats.trust
    let momentum = stats.momentum

    if coverage >= 60 {
      return NarrativeBeat(
        id: "state-founder-profile-v\(venture)-s\(sprint)",
        thread: .founderProfile,
        tone: .favorable,
        headline: "Tech.com puts SOLO under the spotlight",
        summary: "Coverage is at +\(coverage). The company is no longer operating quietly; every public move now carries more scrutiny.",
        intensity: min(100, coverage),
        sourceEventID: nil,
        preferredProgram: .founderSpotlight
      )
    }

    if coverage <= -30 || trust <= 35 {
      return NarrativeBeat(
        id: "state-credibility-v\(venture)-s\(sprint)",
        thread: .credibility,
        tone: .critical,
        headline: "Tech.com questions SOLO's credibility",
        summary: "Public sentiment is under pressure: coverage \(signed(coverage)), trust \(trust). The next explanation may define whether skepticism hardens.",
        intensity: min(100, max(abs(coverage), 100 - trust)),
        sourceEventID: nil,
        preferredProgram: .techComLive
      )
    }

    if momentum >= 70 && trust >= 60 {
      return NarrativeBeat(
        id: "state-momentum-v\(venture)-s\(sprint)",
        thread: .momentum,
        tone: .favorable,
        headline: "Tech.com asks whether SOLO's momentum is durable",
        summary: "Momentum is \(momentum) with trust at \(trust). Attention is shifting from whether SOLO can move to whether it can sustain the run.",
        intensity: min(100, momentum),
        sourceEventID: nil,
        preferredProgram: .techComLive
      )
    }

    if let rival, rival.marketShare >= 0.25 {
      let share = Int((rival.marketShare * 100).rounded())
      return NarrativeBeat(
        id: "state-rivalry-\(rival.id)-v\(venture)-s\(sprint)",
        thread: .rivalry,
        tone: .neutral,
        headline: "Tech.com asks how SOLO will answer \(rival.name)",
        summary: "\(rival.name) now holds \(share)% market share. SOLO's public posture is becoming part of the competitive story.",
        intensity: min(100, max(25, share * 2)),
        sourceEventID: nil,
        preferredProgram: .rivalWatch
      )
    }

    return NarrativeBeat(
      id: "state-operating-posture-v\(venture)-s\(sprint)",
      thread: .evidenceAndExecution,
      tone: .neutral,
      headline: "Tech.com asks SOLO to explain its operating posture",
      summary: "Coverage is \(signed(coverage)), trust \(trust), momentum \(momentum). A public response can shape how the market interprets the company's next move.",
      intensity: 30,
      sourceEventID: nil,
      preferredProgram: .techComLive
    )
  }

  private static func fallbackProjection(stats: FounderStats) -> NarrativeProjection {
    NarrativeProjection(
      headline: "Tech.com asks SOLO to explain its operating posture",
      body: "Coverage is \(signed(stats.coverage)), trust \(stats.trust), momentum \(stats.momentum). A public response can shape how the market interprets the company's next move.",
      statementLabel: "Give a statement",
      statementDetail: "Trade a little trust for a clearer public narrative.",
      silenceDetail: "Let the story travel without you."
    )
  }

  private static func eventPrecedes(_ lhs: PublicMediaEvent, _ rhs: PublicMediaEvent) -> Bool {
    if lhs.venture != rhs.venture { return lhs.venture < rhs.venture }
    if lhs.sprint != rhs.sprint { return lhs.sprint < rhs.sprint }
    if abs(lhs.coverageDelta) != abs(rhs.coverageDelta) {
      return abs(lhs.coverageDelta) < abs(rhs.coverageDelta)
    }
    return lhs.id < rhs.id
  }

  private static func appendUnique(_ thread: NarrativeThread, to threads: inout [NarrativeThread]) {
    if !threads.contains(thread) {
      threads.append(thread)
    }
  }

  private static func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
  }
}

enum TechComFeedEngine {
  static func posts(
    venture: Int,
    sprint: Int,
    stats: FounderStats,
    standings: [RivalStanding],
    publicEvents: [PublicMediaEvent] = []
  ) -> [FeedPost] {
    let rival = standings.first(where: { !$0.isPlayer })
    let snapshot = NarrativeDirector.evaluate(
      publicEvents: publicEvents,
      stats: stats,
      standings: standings,
      venture: venture,
      sprint: sprint
    )
    let narrative = NarrativeDirector.techComProjection(for: snapshot, stats: stats)
    let press = pressInquiry(venture: venture, sprint: sprint, narrative: narrative)
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

  private static func pressInquiry(venture: Int, sprint: Int, narrative: NarrativeProjection) -> FeedPost {
    FeedPost(
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
}
