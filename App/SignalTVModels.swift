import Foundation

enum SignalTVProgram: String, Codable, CaseIterable, Identifiable, Sendable {
  case marketPulse = "MARKET PULSE"
  case techComLive = "TECH.COM LIVE"
  case rivalWatch = "RIVAL WATCH"
  case breaking = "BREAKING"
  case founderSpotlight = "FOUNDER SPOTLIGHT"

  var id: Self { self }
}

enum PublicMediaTone: String, Codable, Sendable {
  case favorable
  case neutral
  case critical
}

/// Canonical public truth shared by Tech.com and Signal TV. It may contain
/// visible/public facts only; task internals and unrevealed result data have no
/// representation in this type.
struct PublicMediaEvent: Codable, Hashable, Identifiable, Sendable {
  var id: String
  var program: SignalTVProgram
  var tone: PublicMediaTone
  var headline: String
  var summary: String
  var tickerItems: [String]
  var coverageDelta: Int
  var venture: Int
  var sprint: Int
  var concernsPlayerCompany: Bool
  var isPublic: Bool

  init(
    id: String,
    program: SignalTVProgram,
    tone: PublicMediaTone,
    headline: String,
    summary: String,
    tickerItems: [String],
    coverageDelta: Int,
    venture: Int,
    sprint: Int,
    concernsPlayerCompany: Bool,
    isPublic: Bool = true
  ) {
    self.id = id
    self.program = program
    self.tone = tone
    self.headline = headline
    self.summary = summary
    self.tickerItems = Array(tickerItems.prefix(4))
    self.coverageDelta = CoverageTuning.clampDelta(coverageDelta)
    self.venture = venture
    self.sprint = sprint
    self.concernsPlayerCompany = concernsPlayerCompany
    self.isPublic = isPublic
  }

  /// Funding stories are intentionally recognizable from their public event
  /// namespace, never from private finance or application state.
  var isFundingSuccess: Bool {
    isPublic
      && concernsPlayerCompany
      && tone == .favorable
      && id.hasPrefix("funding-")
  }
}

/// Projects only completed, founder-visible funding successes into the shared
/// public media ledger. Declines, applications, and missed obligations remain
/// private company records on their canonical surfaces.
enum FundingPublicMediaProjection {
  static func resolution(
    opportunity: FundingOpportunity,
    outcome: FundingResolutionOutcome,
    venture: Int,
    sprint: Int
  ) -> PublicMediaEvent? {
    switch outcome {
    case .awarded:
      return event(
        id: "funding-\(opportunity.id)-awarded",
        headline: "SOLO secures \(opportunity.name)",
        summary: "The company received \(opportunity.amountLabel) in non-dilutive funding.",
        tickerItems: ["SOLO AWARDED \(opportunity.amountLabel)", "\(opportunity.name.uppercased())"],
        venture: venture,
        sprint: sprint
      )
    case .funded:
      return event(
        id: "funding-\(opportunity.id)-funded",
        headline: "SOLO closes \(opportunity.name)",
        summary: "The company closed \(opportunity.amountLabel) in outside funding.",
        tickerItems: ["SOLO FUNDED \(opportunity.amountLabel)", "\(opportunity.name.uppercased())"],
        venture: venture,
        sprint: sprint
      )
    case .declined:
      return nil
    }
  }

  static func milestoneMet(
    opportunity: FundingOpportunity,
    obligation: FundingMilestoneObligation,
    venture: Int,
    sprint: Int
  ) -> PublicMediaEvent {
    event(
      id: "funding-\(opportunity.id)-milestone-met",
      headline: "SOLO delivers on its \(opportunity.name) milestone",
      summary: "The company reached its published \(obligation.metric.title) target.",
      tickerItems: ["SOLO MILESTONE MET", "\(obligation.metric.title.uppercased()) TARGET REACHED"],
      venture: venture,
      sprint: sprint
    )
  }

  private static func event(
    id: String,
    headline: String,
    summary: String,
    tickerItems: [String],
    venture: Int,
    sprint: Int
  ) -> PublicMediaEvent {
    PublicMediaEvent(
      id: id,
      program: .breaking,
      tone: .favorable,
      headline: headline,
      summary: summary,
      tickerItems: tickerItems,
      coverageDelta: 0,
      venture: venture,
      sprint: sprint,
      concernsPlayerCompany: true
    )
  }
}

enum CoverageTuning {
  static let range = -100...100
  static let seriousEventRange = -15...15

  static func clamp(_ value: Int) -> Int {
    min(range.upperBound, max(range.lowerBound, value))
  }

  static func clampDelta(_ value: Int) -> Int {
    min(seriousEventRange.upperBound, max(seriousEventRange.lowerBound, value))
  }

  static func delta(for result: VisibleSprintResult) -> Int {
    let publicSignal = result.momentumDelta + result.trustDelta + min(5, max(-5, result.revenueDelta / 150))
    return switch publicSignal {
    case 8...: min(10, max(4, publicSignal / 2))
    case 3...: min(5, max(2, publicSignal / 2))
    case ...(-8): max(-10, min(-4, publicSignal / 2))
    case ...(-3): max(-5, min(-2, publicSignal / 2))
    default: 0
    }
  }
}

enum SignalTVProgramming {
  static let safeMarketTicker = [
    "AI INFRASTRUCTURE DEMAND RISES",
    "DEV TOOLS HOLD STEADY",
    "CONSUMER AI COOLS"
  ]

  static func ambientEvents(
    publicEvents: [PublicMediaEvent],
    techComHeadlines: [TechComHeadline],
    rivals: [TechComRival],
    coverage: Int,
    venture: Int,
    sprint: Int
  ) -> [PublicMediaEvent] {
    var result = publicBroadcastEvents(publicEvents)
    result.append(marketPulse(venture: venture, sprint: sprint))

    if let headline = techComHeadlines.first {
      result.append(PublicMediaEvent(
        id: headline.publicEventID ?? "techcom-v\(headline.venture)-s\(headline.sprint)-\(stableID(headline.text))",
        program: .techComLive,
        tone: .neutral,
        headline: headline.text,
        summary: "A Tech.com report enters the startup-world broadcast cycle.",
        tickerItems: [headline.text] + safeMarketTicker,
        coverageDelta: 0,
        venture: headline.venture,
        sprint: headline.sprint,
        concernsPlayerCompany: headline.category == .ownCompany
      ))
    }

    if let rival = rivals.first {
      result.append(PublicMediaEvent(
        id: "rival-watch-\(rival.id)-v\(venture)-s\(sprint)",
        program: .rivalWatch,
        tone: .neutral,
        headline: "\(rival.name) presses its category position",
        summary: "Public claims put a rival company under the Signal TV lens.",
        tickerItems: ["\(rival.name.uppercased()) UPDATES MARKET", "RIVAL WATCH"] + safeMarketTicker,
        coverageDelta: 0,
        venture: venture,
        sprint: sprint,
        concernsPlayerCompany: false
      ))
    }

    if abs(coverage) >= 60, let playerStory = result.first(where: { $0.concernsPlayerCompany && $0.coverageDelta > 0 }) {
      result.append(PublicMediaEvent(
        id: "spotlight-\(playerStory.id)",
        program: .founderSpotlight,
        tone: .favorable,
        headline: "The founder behind SOLO's public momentum",
        summary: "Signal TV revisits a verified public company milestone.",
        tickerItems: ["FOUNDER SPOTLIGHT", playerStory.headline] + safeMarketTicker,
        coverageDelta: 0,
        venture: venture,
        sprint: sprint,
        concernsPlayerCompany: true
      ))
    }
    return deduplicated(result)
  }

  /// The final secrecy gate before stories enter presentation. Production
  /// callers already supply the public ledger, but keeping this boundary here
  /// prevents a future preview or fixture from accidentally airing hidden truth.
  static func publicBroadcastEvents(_ events: [PublicMediaEvent]) -> [PublicMediaEvent] {
    events.filter(\.isPublic)
  }

  static func marketPulse(venture: Int, sprint: Int) -> PublicMediaEvent {
    PublicMediaEvent(
      id: "market-pulse-v\(venture)-s\(sprint)",
      program: .marketPulse,
      tone: .neutral,
      headline: "Startup Index: selective growth",
      summary: "AI infrastructure rises while developer tools hold and consumer AI cools.",
      tickerItems: safeMarketTicker,
      coverageDelta: 0,
      venture: venture,
      sprint: sprint,
      concernsPlayerCompany: false
    )
  }

  static func presentationIndex(elapsed: TimeInterval, count: Int, reduceMotion: Bool) -> Int {
    guard count > 0 else { return 0 }
    let interval = reduceMotion ? 12.0 : 8.0
    return Int(elapsed / interval) % count
  }

  static func tickerIndex(elapsed: TimeInterval, count: Int) -> Int {
    guard count > 0 else { return 0 }
    return Int(elapsed / 5.0) % count
  }

  static func stableID(_ text: String) -> String {
    var value: UInt64 = 14_695_981_039_346_656_037
    for byte in text.utf8 {
      value ^= UInt64(byte)
      value &*= 1_099_511_628_211
    }
    return String(value, radix: 16)
  }

  private static func deduplicated(_ events: [PublicMediaEvent]) -> [PublicMediaEvent] {
    var seen: Set<String> = []
    return events.filter { seen.insert($0.id).inserted }
  }
}

enum SignalTVBroadcastState: String, Equatable, Sendable {
  case idle
  case companyUpdate
  case momentum
  case pressure
  case spotlight
}

/// Presentation-only broadcast emphasis derived exclusively from public facts.
/// It consumes no simulation RNG and never mutates Coverage or the event ledger.
struct SignalTVBroadcastPresentation: Equatable, Sendable {
  var state: SignalTVBroadcastState
  var banner: String
  var symbol: String
  var intensity: Double
  var continuousMotionEnabled: Bool

  var isMeaningfulCompanyEvent: Bool { state != .idle }

  var accessibilityState: String {
    switch state {
    case .idle: "Startup world programming"
    case .companyUpdate: "Public SOLO update"
    case .momentum: "Favorable SOLO momentum"
    case .pressure: "Critical public SOLO pressure"
    case .spotlight: "SOLO founder spotlight"
    }
  }

  static func derive(
    event: PublicMediaEvent,
    reduceMotion: Bool,
    continuousMotionEnabled: Bool = true
  ) -> Self {
    let motionEnabled = continuousMotionEnabled && !reduceMotion
    guard event.isPublic, event.concernsPlayerCompany else {
      return Self(
        state: .idle,
        banner: "SIGNAL ONLINE",
        symbol: "antenna.radiowaves.left.and.right",
        intensity: 0.24,
        continuousMotionEnabled: motionEnabled
      )
    }

    if event.program == .founderSpotlight {
      return Self(
        state: .spotlight,
        banner: "FOUNDER SPOTLIGHT",
        symbol: "person.crop.rectangle",
        intensity: 0.92,
        continuousMotionEnabled: motionEnabled
      )
    }
    if event.tone == .critical || event.coverageDelta < 0 {
      return Self(
        state: .pressure,
        banner: "PUBLIC PRESSURE",
        symbol: "exclamationmark.triangle.fill",
        intensity: 0.86,
        continuousMotionEnabled: motionEnabled
      )
    }
    if event.tone == .favorable || event.coverageDelta > 0 {
      return Self(
        state: .momentum,
        banner: "SOLO RISING",
        symbol: "arrow.up.right",
        intensity: 0.78,
        continuousMotionEnabled: motionEnabled
      )
    }
    return Self(
      state: .companyUpdate,
      banner: "SOLO UPDATE",
      symbol: "building.2.fill",
      intensity: 0.56,
      continuousMotionEnabled: motionEnabled
    )
  }
}

enum SignalTVAudioFocus: String, Equatable, Sendable {
  case commandFocus
  case freeLook
  case majorStory

  var volume: Double {
    switch self {
    case .commandFocus: 0.12
    case .freeLook: 0.32
    case .majorStory: 0.48
    }
  }
}

struct CoverageChange: Equatable, Identifiable, Sendable {
  var eventID: String
  var delta: Int
  var reason: String

  var id: String { eventID }
}
