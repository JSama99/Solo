import Foundation

/// Only facts authorized for the public launch story cross this boundary.
/// In particular, scores, preparation, agent state, and unresolved causes stay
/// with the simulation and Founder-facing launch result.
struct PublicLaunchOutcome: Equatable, Sendable {
  let sourceEventID: String
  let venture: Int
  let sprint: Int
  let overall: ProductLaunchOutcomeClass
  let marketRating: ProductLaunchDimensionRating
  let publicRating: ProductLaunchDimensionRating
  let headline: String
  let coverageDelta: Int
}

enum MediaNarrativeEvent: Equatable, Sendable {
  case productLaunchResolved(PublicLaunchOutcome)
  case founderReview(FounderReviewNarrativeInput)
  case surfacedLatentDefect(LatentDefectPublicMediaProjection)
  case rivalMove(PublicRivalMoveNarrativeInput)
  case publicFundingProgress(FundingPublicMediaProjection)

  fileprivate var identity: (id: String, venture: Int, sprint: Int) {
    switch self {
    case .productLaunchResolved(let value): (value.sourceEventID, value.venture, value.sprint)
    case .founderReview(let value): (value.sourceEventID, value.venture, value.sprint)
    case .surfacedLatentDefect(let value): (value.sourceEventID, value.venture, value.sprint)
    case .rivalMove(let value): (value.sourceEventID, value.venture, value.sprint)
    case .publicFundingProgress(let value): (value.sourceEventID, value.venture, value.sprint)
    }
  }
}

enum PublicNarrativeCategory: Equatable, Sendable {
  case launchSuccess, launchSetback, surfacedDefect, rivalPressure, fundingSuccess, fundingMilestone

  /// Existing stable namespaces and public metadata provide classification;
  /// headline prose and private simulation records are never interpretation inputs.
  init?(_ story: PublicMediaEvent) {
    guard story.isPublic else { return nil }
    if story.id.hasPrefix("product-launch-"), story.id.hasSuffix("-resolved"), story.concernsPlayerCompany {
      switch story.tone {
      case .favorable: self = .launchSuccess
      case .critical: self = .launchSetback
      case .neutral: return nil
      }
    } else if story.id.hasPrefix("latent-"), story.id.hasSuffix("-surfaced"), story.concernsPlayerCompany {
      self = .surfacedDefect
    } else if story.id.hasPrefix("funding-"), story.concernsPlayerCompany, story.tone == .favorable {
      if story.id.hasSuffix("-milestone-met") { self = .fundingMilestone }
      else if story.id.hasSuffix("-awarded") || story.id.hasSuffix("-funded") { self = .fundingSuccess }
      else { return nil }
    } else if story.program == .rivalWatch, story.concernsPlayerCompany {
      self = .rivalPressure
    } else { return nil }
  }
}

struct PublicNarrativeHistoryEntry: Equatable, Sendable {
  let sourceEventID: String
  let venture: Int
  let sprint: Int
  let category: PublicNarrativeCategory
}

/// A bounded reconstruction of the persisted newest-first public ledger.
/// No Hindsight, Evidence, task, agent, or financing record can enter this type.
struct PublicNarrativeHistory: Equatable, Sendable {
  static let maximumEntries = 8
  static let maximumLedgerScan = 30
  static let empty = Self(entries: [])
  let recentEvents: [PublicNarrativeHistoryEntry]

  private init(entries: [PublicNarrativeHistoryEntry]) { recentEvents = entries }

  init(publicEvents: [PublicMediaEvent], before event: MediaNarrativeEvent) {
    let current = event.identity
    let ledger = Array(publicEvents.prefix(Self.maximumLedgerScan))
    // A replay must see only events older than its first stored occurrence,
    // never more recently published stories. Same-sprint order stays ledger order.
    let start = ledger.firstIndex { $0.id == current.id }.map { $0 + 1 } ?? 0
    var seen = Set<String>()
    var entries: [PublicNarrativeHistoryEntry] = []
    for story in ledger.dropFirst(start) {
      guard story.id != current.id, story.isPublic,
            story.venture < current.venture || (story.venture == current.venture && story.sprint <= current.sprint),
            !MediaNarrativeDirector.isLegacyPrivateReviewHeadline(story.headline),
            seen.insert(story.id).inserted,
            let category = PublicNarrativeCategory(story) else { continue }
      entries.append(PublicNarrativeHistoryEntry(sourceEventID: story.id,
        venture: story.venture, sprint: story.sprint, category: category))
      if entries.count == Self.maximumEntries { break }
    }
    recentEvents = entries
  }
}

/// Copies only the resolved public action. Strength, archetype, gameplay
/// effects, rival actual metrics, and strategy calculations stay outside media.
struct PublicRivalMoveNarrativeInput: Equatable, Sendable {
  let sourceEventID: String
  let rivalID: String
  let rivalName: String
  let move: RivalMove
  let headline: String
  let venture: Int
  let sprint: Int

  init(_ event: RivalMoveEvent, venture: Int, sprint: Int) {
    sourceEventID = event.id
    rivalID = event.rivalID
    rivalName = event.rivalName
    move = event.move
    headline = event.headline
    self.venture = venture
    self.sprint = sprint
  }
}

/// A Founder reveal is knowledge for the player, not publication authority.
/// Add a public case only when a production event supplies an authorized
/// projection of the exact facts being disclosed.
enum PublicDisclosureStatus: Equatable, Sendable {
  case privateToFounder
}

enum FounderVisibleReviewOutcome: Equatable, Sendable {
  case confirmed
  case overclaimed
  case driftDetected
  case evidenceIncomplete
  case other

  init(_ state: VerificationState) {
    self = switch state {
    case .confirmed, .verified: .confirmed
    case .overclaimed: .overclaimed
    case .driftDetected: .driftDetected
    case .evidenceIncomplete: .evidenceIncomplete
    case .reported, .unverified: .other
    }
  }
}

/// No task, agent, evidence, quality score, or work-session record can enter
/// the Director through this Founder Review input.
struct FounderReviewNarrativeInput: Equatable, Sendable {
  let sourceEventID: String
  let venture: Int
  let sprint: Int
  let founderVisibleOutcome: FounderVisibleReviewOutcome
  let disclosure: PublicDisclosureStatus
}

enum NarrativeImportance: Equatable, Sendable {
  case standard
  case significant
  case major
}

enum NarrativeChannel: Equatable, Sendable {
  case signalTV
}

struct MediaNarrativeDecision: Equatable, Sendable {
  let sourceEventID: String
  let importance: NarrativeImportance
  let channel: NarrativeChannel
  let program: SignalTVProgram
  let tone: PublicMediaTone
  let coverageDelta: Int
  let story: PublicMediaEvent
}

/// Pure interpretation of an already-public resolved outcome. Publication and
/// Coverage mutation remain GameStore responsibilities.
enum MediaNarrativeDirector {
  static func decide(event: MediaNarrativeEvent, history: PublicNarrativeHistory = .empty) -> MediaNarrativeDecision? {
    guard let decision = baseDecision(event: event) else { return nil }
    guard let category = PublicNarrativeCategory(decision.story) else { return decision }
    let prior = history.recentEvents.filter {
      $0.sourceEventID != decision.sourceEventID
        && ($0.venture < decision.story.venture || ($0.venture == decision.story.venture && $0.sprint <= decision.story.sprint))
    }
    let sentence: String?
    switch category {
    case .launchSuccess:
      let lastLaunch = prior.first { $0.category == .launchSuccess || $0.category == .launchSetback }
      sentence = lastLaunch?.category == .launchSetback
        ? "This favorable launch follows a previously reported public launch setback." : nil
    case .launchSetback:
      sentence = prior.contains { $0.category == .launchSetback }
        ? "A further public launch setback brings renewed scrutiny." : nil
    case .surfacedDefect:
      sentence = prior.contains { $0.category == .surfacedDefect }
        ? "Another surfaced production defect brings renewed public scrutiny." : nil
    case .rivalPressure:
      sentence = prior.contains { $0.category == .rivalPressure }
        ? "Competitive pressure continues with another public rival move." : nil
    case .fundingSuccess:
      sentence = prior.contains { $0.category == .fundingSuccess }
        ? "This funding success follows an earlier public funding success." : nil
    case .fundingMilestone:
      sentence = prior.contains { $0.category == .fundingMilestone }
        ? "Another published funding milestone marks continued public progress." : nil
    }
    guard let sentence else { return decision }
    var story = decision.story
    story.summary += " " + sentence
    return MediaNarrativeDecision(sourceEventID: decision.sourceEventID,
      importance: decision.importance, channel: decision.channel, program: decision.program,
      tone: decision.tone, coverageDelta: decision.coverageDelta, story: story)
  }

  private static func baseDecision(event: MediaNarrativeEvent) -> MediaNarrativeDecision? {
    switch event {
    case .founderReview:
      // No existing production event authorizes publication of review truth.
      return nil
    case .publicFundingProgress(let funding):
      let program: SignalTVProgram = switch funding.progress {
      case .awarded: .breaking
      case .funded: .founderSpotlight
      case .milestoneMet: .techComLive
      }
      let coverageDelta = CoverageTuning.clampDelta(funding.coverageDelta)
      let story = PublicMediaEvent(
        id: funding.sourceEventID, program: program, tone: .favorable,
        headline: funding.headline, summary: funding.summary,
        tickerItems: funding.tickerItems, coverageDelta: coverageDelta,
        venture: funding.venture, sprint: funding.sprint, concernsPlayerCompany: true
      )
      return MediaNarrativeDecision(
        sourceEventID: funding.sourceEventID,
        importance: funding.progress == .funded ? .major : .significant,
        channel: .signalTV, program: program, tone: .favorable,
        coverageDelta: coverageDelta, story: story
      )
    case .rivalMove(let rival):
      // Preserve the existing notable-move publication gate. Gameplay already
      // applied any player pressure; no existing move defines media Coverage.
      guard rival.move != .steadyBuild else { return nil }
      let concernsPlayer: Bool = switch rival.move {
      case .prBlitz, .priceUndercut, .featureCopy, .talentPoach: true
      case .steadyBuild, .fortify, .fundraiseSurge, .overreach: false
      }
      let tone: PublicMediaTone = rival.move == .overreach ? .critical : .neutral
      let story = PublicMediaEvent(
        id: rival.sourceEventID, program: .rivalWatch, tone: tone,
        headline: rival.headline, summary: rival.headline,
        tickerItems: [rival.rivalName.uppercased(), rival.move.label.uppercased()],
        coverageDelta: 0, venture: rival.venture, sprint: rival.sprint,
        concernsPlayerCompany: concernsPlayer
      )
      return MediaNarrativeDecision(
        sourceEventID: rival.sourceEventID, importance: .significant,
        channel: .signalTV, program: .rivalWatch, tone: tone,
        coverageDelta: 0, story: story
      )
    case .surfacedLatentDefect(let defect):
      let coverageDelta = CoverageTuning.clampDelta(defect.coverageDelta)
      let story = PublicMediaEvent(
        id: defect.sourceEventID, program: .breaking, tone: .critical,
        headline: defect.headline, summary: defect.summary,
        tickerItems: defect.tickerItems, coverageDelta: coverageDelta,
        venture: defect.venture, sprint: defect.sprint, concernsPlayerCompany: true
      )
      return MediaNarrativeDecision(
        sourceEventID: defect.sourceEventID,
        importance: coverageDelta <= -10 ? .major : .significant,
        channel: .signalTV, program: .breaking, tone: .critical,
        coverageDelta: coverageDelta, story: story
      )
    case .productLaunchResolved(let launch):
      let importance: NarrativeImportance = switch launch.overall {
      case .breakout, .failure: .major
      case .strong, .weak: .significant
      case .mixed: .standard
      }
      let program: SignalTVProgram = launch.overall == .breakout ? .founderSpotlight : .breaking
      let coverageDelta = CoverageTuning.clampDelta(launch.coverageDelta)
      let tone: PublicMediaTone = coverageDelta > 0 ? .favorable : coverageDelta < 0 ? .critical : .neutral
      let story = PublicMediaEvent(
        id: launch.sourceEventID,
        program: program,
        tone: tone,
        headline: launch.headline,
        summary: "The public launch resolved \(launch.overall.rawValue) with \(launch.marketRating.rawValue) market and \(launch.publicRating.rawValue) public reception.",
        tickerItems: [launch.headline.uppercased(), "SOLO PRODUCT LAUNCH", "MARKET \(launch.marketRating.rawValue.uppercased())"],
        coverageDelta: coverageDelta,
        venture: launch.venture,
        sprint: launch.sprint,
        concernsPlayerCompany: true
      )
      return MediaNarrativeDecision(
        sourceEventID: launch.sourceEventID,
        importance: importance,
        channel: .signalTV,
        program: program,
        tone: tone,
        coverageDelta: coverageDelta,
        story: story
      )
    }
  }

  /// Quarantine review copy written by pre-gate careers, including sprint
  /// summaries that embedded Founder-private verification or risk findings.
  static func isLegacyPrivateReviewHeadline(_ headline: String) -> Bool {
    if headline.hasPrefix("SOLO review finds ") || headline.hasPrefix("SOLO verifies ") {
      return true
    }
    return headline.hasPrefix("SOLO closes sprint ") && (
      headline.contains(": Known risks need founder attention (")
        || headline.contains(": Verified work moved the company forward (")
    )
  }
}

/// Attention metadata reconstructed solely from an authorized public story.
/// Persisted stories predate Director importance, so broadcast importance uses
/// their public consequence/program, never private outcomes or summary parsing.
struct NarrativeStoryCandidate: Equatable, Sendable {
  let event: PublicMediaEvent
  let importance: NarrativeImportance
  let category: PublicNarrativeCategory?
  let fatigued: Bool
}

/// Pure broadcast scheduling. It neither publishes nor changes any story.
/// Production input is the 30-entry ledger plus bounded ambient programming.
enum NarrativeStoryCompetition {
  static let maximumCandidates = 12
  static let cooldownSprintDistance = 1

  static func selectPrimaryStory(from events: [PublicMediaEvent]) -> PublicMediaEvent? {
    rankedCandidates(from: events).first?.event
  }

  static func rankedCandidates(from events: [PublicMediaEvent]) -> [NarrativeStoryCandidate] {
    // Canonicalize before taking the window: insertion order cannot choose the
    // candidate set or resolve conflicting duplicate IDs.
    let ordered = SignalTVProgramming.publicBroadcastEvents(events).sorted(by: canonicalOrder)
    guard let newest = ordered.first else { return [] }
    var seen = Set<String>()
    let eligible = ordered.filter {
      $0.venture == newest.venture && $0.sprint >= newest.sprint - cooldownSprintDistance
        && seen.insert($0.id).inserted
    }
    var recent = Array(eligible.prefix(maximumCandidates))
    // Reserve a safe market slot so a full window of repeated updates cannot
    // crowd out the fresh ambient alternative and monopolize the spotlight.
    if let market = eligible.first(where: { $0.program == .marketPulse }),
       !recent.contains(where: { $0.id == market.id }) {
      recent[recent.count - 1] = market
    }
    return recent.map { event in
      let category = PublicNarrativeCategory(event)
        ?? (event.program == .rivalWatch ? .rivalPressure : nil)
      let importance: NarrativeImportance
      if abs(event.coverageDelta) >= 10
          || (event.program == .founderSpotlight && event.concernsPlayerCompany && !event.id.hasPrefix("spotlight-")) {
        importance = .major
      } else if category != nil || event.coverageDelta != 0 {
        importance = .significant
      } else {
        importance = .standard
      }
      let repeated = category.map { category in
        recent.filter {
          (PublicNarrativeCategory($0) ?? ($0.program == .rivalWatch ? .rivalPressure : nil)) == category
        }.count > 1
      } ?? false
      return NarrativeStoryCandidate(event: event, importance: importance,
        category: category, fatigued: repeated && importance != .major)
    }.sorted(by: outranks)
  }

  private static func outranks(_ lhs: NarrativeStoryCandidate, _ rhs: NarrativeStoryCandidate) -> Bool {
    // Major consequences are exempt from fatigue. Fresh programming wins over
    // a cooled-down non-major category, including when only repeats remain.
    func tier(_ candidate: NarrativeStoryCandidate) -> Int {
      candidate.importance == .major ? 2 : candidate.fatigued ? 0 : 1
    }
    if tier(lhs) != tier(rhs) { return tier(lhs) > tier(rhs) }
    func importance(_ value: NarrativeImportance) -> Int {
      switch value { case .major: 2; case .significant: 1; case .standard: 0 }
    }
    if lhs.importance != rhs.importance { return importance(lhs.importance) > importance(rhs.importance) }
    if lhs.event.concernsPlayerCompany != rhs.event.concernsPlayerCompany { return lhs.event.concernsPlayerCompany }
    func breaking(_ event: PublicMediaEvent) -> Bool {
      event.program == .breaking && (event.tone == .critical || event.coverageDelta < 0)
    }
    if breaking(lhs.event) != breaking(rhs.event) { return breaking(lhs.event) }
    return canonicalOrder(lhs.event, rhs.event)
  }

  private static func canonicalOrder(_ lhs: PublicMediaEvent, _ rhs: PublicMediaEvent) -> Bool {
    if lhs.venture != rhs.venture { return lhs.venture > rhs.venture }
    if lhs.sprint != rhs.sprint { return lhs.sprint > rhs.sprint }
    if lhs.id != rhs.id { return lhs.id < rhs.id }
    // Defensive resolution of inconsistent duplicate fixtures/legacy records.
    // Identical IDs never receive two candidate slots or increase fatigue.
    if lhs.coverageDelta != rhs.coverageDelta { return lhs.coverageDelta < rhs.coverageDelta }
    if lhs.concernsPlayerCompany != rhs.concernsPlayerCompany { return lhs.concernsPlayerCompany }
    return ([lhs.program.rawValue, lhs.tone.rawValue, lhs.headline, lhs.summary] + lhs.tickerItems)
      .lexicographicallyPrecedes([rhs.program.rawValue, rhs.tone.rawValue, rhs.headline, rhs.summary] + rhs.tickerItems)
  }
}
