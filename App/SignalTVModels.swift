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
    var result = publicEvents.filter(\.isPublic)
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
