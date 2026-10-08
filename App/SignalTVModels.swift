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

/// Public projection of a defect only after the canonical delayed consequence
/// has surfaced. Latent task truth never enters the public event ledger.
struct LatentDefectPublicMediaProjection: Equatable, Sendable {
  let sourceEventID: String
  let venture: Int
  let sprint: Int
  let headline: String
  let summary: String
  let tickerItems: [String]
  let coverageDelta: Int

  private init(sourceEventID: String, venture: Int, sprint: Int, headline: String,
               summary: String, tickerItems: [String], coverageDelta: Int) {
    self.sourceEventID = sourceEventID
    self.venture = venture
    self.sprint = sprint
    self.headline = headline
    self.summary = summary
    self.tickerItems = tickerItems
    self.coverageDelta = coverageDelta
  }

  /// Called by the canonical consequence path after applying the due defect.
  /// The date guard also rejects accidental projection of a future defect.
  static func surfaced(
    _ defect: LatentDefect,
    venture: Int,
    sprint: Int,
    careerSprint: Int
  ) -> Self? {
    guard defect.surfacesAtCareerSprint <= careerSprint else { return nil }
    return Self(
      sourceEventID: "latent-\(defect.id)-surfaced",
      venture: venture,
      sprint: sprint,
      headline: "SOLO launch hits a production defect",
      summary: "A delayed issue from \(defect.originTaskTitle) surfaced in production.",
      tickerItems: ["SOLO PRODUCTION DEFECT", "LAUNCH RELIABILITY UNDER REVIEW"],
      coverageDelta: -min(10, max(4, defect.severity / 2))
    )
  }
}

/// Projects only completed, founder-visible funding successes into the shared
/// public media ledger. Declines, applications, and missed obligations remain
/// private company records on their canonical surfaces.
enum PublicFundingProgress: Equatable, Sendable {
  case awarded
  case funded
  case milestoneMet
}

struct FundingPublicMediaProjection: Equatable, Sendable {
  let sourceEventID: String
  let progress: PublicFundingProgress
  let headline: String
  let summary: String
  let tickerItems: [String]
  let venture: Int
  let sprint: Int
  let coverageDelta: Int = 0

  private init(sourceEventID: String, progress: PublicFundingProgress, headline: String,
               summary: String, tickerItems: [String], venture: Int, sprint: Int) {
    self.sourceEventID = sourceEventID
    self.progress = progress
    self.headline = headline
    self.summary = summary
    self.tickerItems = tickerItems
    self.venture = venture
    self.sprint = sprint
  }

  static func resolution(
    opportunity: FundingOpportunity,
    outcome: FundingResolutionOutcome,
    venture: Int,
    sprint: Int
  ) -> Self? {
    switch outcome {
    case .awarded:
      return Self(
        sourceEventID: "funding-\(opportunity.id)-awarded",
        progress: .awarded,
        headline: "SOLO secures \(opportunity.name)",
        summary: "The company received \(opportunity.amountLabel) in non-dilutive funding.",
        tickerItems: ["SOLO AWARDED \(opportunity.amountLabel)", "\(opportunity.name.uppercased())"],
        venture: venture,
        sprint: sprint
      )
    case .funded:
      return Self(
        sourceEventID: "funding-\(opportunity.id)-funded",
        progress: .funded,
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
  ) -> Self? {
    guard obligation.status == .met else { return nil }
    return Self(
      sourceEventID: "funding-\(opportunity.id)-milestone-met",
      progress: .milestoneMet,
      headline: "SOLO delivers on its \(opportunity.name) milestone",
      summary: "The company reached its published \(obligation.metric.title) target.",
      tickerItems: ["SOLO MILESTONE MET", "\(obligation.metric.title.uppercased()) TARGET REACHED"],
      venture: venture,
      sprint: sprint
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

    // Company and rival actions arrive through the authorized public ledger.
    // Generic industry trends remain independently public market programming.
    if let headline = techComHeadlines.first(where: { $0.category == .trend }) {
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
    events.filter {
      $0.isPublic && !MediaNarrativeDirector.isLegacyPrivateReviewHeadline($0.headline)
    }
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

/// Broadcast styling only. Program identity never changes the event's program.
enum SignalTVProgramAccent: Equatable, Sendable {
  case mint, cyan, violet, coral, gold
}

/// Explicit ticker coordinates prevent SwiftUI stack compression from changing
/// the distance between repeated tracks. Widths are measured from resolved text.
struct SignalTVTickerLayout: Equatable, Sendable {
  let starts: [Double]
  let widths: [Double]
  let gap: Double
  let period: Double

  init(widths: [Double], viewportWidth: Double, gap: Double = 32) {
    self.widths = widths.map { $0.isFinite ? max(0, $0) : 0 }
    self.gap = max(24, gap.isFinite ? gap : 32)
    var cursor = 0.0
    var starts: [Double] = []
    for width in self.widths {
      starts.append(cursor)
      cursor += width + self.gap
    }
    self.starts = starts
    period = max(cursor, viewportWidth.isFinite ? max(1, viewportWidth) : 1)
  }

  func offset(at elapsed: Double) -> Double {
    let phase = elapsed.truncatingRemainder(dividingBy: 36)
    return (phase < 0 ? phase + 36 : phase) / 36 * period
  }
}

struct SignalTVProgramIdentity: Equatable, Sendable {
  let program: SignalTVProgram
  let desk: String
  let symbol: String
  let accent: SignalTVProgramAccent

  init(program: SignalTVProgram) {
    self.program = program
    switch program {
    case .marketPulse: desk = "MARKET DESK"; symbol = "square.grid.3x3"; accent = .mint
    case .techComLive: desk = "LIVE"; symbol = "dot.radiowaves.left.and.right"; accent = .cyan
    case .rivalWatch: desk = "COMPETITION DESK"; symbol = "building.2.crop.circle"; accent = .violet
    case .breaking: desk = "PUBLIC NEWS ALERT"; symbol = "bolt.horizontal.circle"; accent = .coral
    case .founderSpotlight: desk = "FOUNDER FEATURE"; symbol = "star.circle"; accent = .gold
    }
  }
}

enum SignalTVStoryProminence: String, Equatable, Sendable {
  case major = "MAJOR STORY"
  case normal = "PUBLIC STORY"
  case ambient = "WORLD BRIEF"
}

/// Uses Slice 7's established public importance; no new ranking or truth logic.
struct SignalTVBroadcastDesign: Equatable, Sendable {
  let identity: SignalTVProgramIdentity
  let prominence: SignalTVStoryProminence
  let tickerItems: [String]
  let supportingSummary: String?
  let continuousMotionEnabled: Bool
  let transitionDuration: Double

  static func derive(event: PublicMediaEvent, reduceMotion: Bool,
                     continuousMotionEnabled: Bool = true) -> Self {
    let candidate = NarrativeStoryCompetition.rankedCandidates(from: [event]).first
    let prominence: SignalTVStoryProminence = switch candidate?.importance {
    case .major: .major
    case .significant: .normal
    case .standard, nil: .ambient
    }
    return Self(identity: SignalTVProgramIdentity(program: event.program), prominence: prominence,
      tickerItems: candidate == nil ? [] : event.tickerItems,
      supportingSummary: candidate == nil || event.summary == event.headline || event.summary.isEmpty ? nil : event.summary,
      continuousMotionEnabled: continuousMotionEnabled && !reduceMotion,
      transitionDuration: reduceMotion || !continuousMotionEnabled ? 0 : 0.22)
  }
}

// MARK: - Slice 9: public expression only (no simulation or publication authority)

struct NarrativeExpressionDraft: Codable, Equatable, Sendable {
  let headline: String
  let summary: String
  let tickerItems: [String]

  /// Codable alone ignores unknown keys. External adapters must use this strict decoder.
  static func decodeStrict(_ data: Data) throws -> Self {
    guard data.count <= 8_192,
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          Set(object.keys) == ["headline", "summary", "tickerItems"] else {
      throw NarrativeExpressionFailure.invalidSchema
    }
    return try JSONDecoder().decode(Self.self, from: data)
  }
}

struct PublicNarrativeFacts: Equatable, Sendable {
  let category: PublicNarrativeCategory?
  /// Complete canonical clauses, including Director-authorized continuity.
  /// No history analysis, private records, or causal inference happens here.
  let canonicalCopy: NarrativeExpressionDraft
}

struct NarrativeExpressionStyle: Equatable, Sendable {
  let voice: String
  let leadIn: String

  init(program: SignalTVProgram) {
    switch program {
    case .marketPulse: voice = "Measured, analytical, concise"; leadIn = "Market desk: "
    case .techComLive: voice = "Credible technology and business news"; leadIn = "On the wire: "
    case .rivalWatch: voice = "Competitive, strategic, analytical"; leadIn = "Rival desk: "
    case .breaking: voice = "Urgent, direct, serious"; leadIn = "Developing: "
    case .founderSpotlight: voice = "Recognition, prestige, forward-looking"; leadIn = "In focus: "
    }
  }
}

struct NarrativeExpressionRequest: Equatable, Sendable {
  static let schemaVersion = 1
  let eventID: String
  let program: SignalTVProgram
  let tone: PublicMediaTone
  let importance: NarrativeImportance
  let publicFacts: PublicNarrativeFacts
  let style: NarrativeExpressionStyle

  /// Receives the existing public projection after authorization and selection.
  /// Eligibility is enforced here, never delegated to a provider.
  init?(authorizedEvent event: PublicMediaEvent) {
    guard let candidate = NarrativeStoryCompetition.rankedCandidates(from: [event]).first else { return nil }
    eventID = event.id
    program = event.program
    tone = event.tone
    importance = candidate.importance
    publicFacts = PublicNarrativeFacts(category: PublicNarrativeCategory(event),
      canonicalCopy: NarrativeExpressionDraft(headline: event.headline,
        summary: event.summary, tickerItems: event.tickerItems))
    style = NarrativeExpressionStyle(program: event.program)
  }

  /// A deliberately finite grammar. Each alternative retains every canonical
  /// fact verbatim; only a developer-owned desk lead-in can be added.
  /// Free-form paraphrases need a separately reviewed grounding design.
  var permittedExpression: NarrativeExpressionDraft {
    let original = publicFacts.canonicalCopy
    return NarrativeExpressionDraft(headline: style.leadIn + original.headline,
      summary: original.summary, tickerItems: original.tickerItems)
  }
}

protocol NarrativeExpressionProviding: Sendable {
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft
}

struct DeterministicFallbackExpressionProvider: NarrativeExpressionProviding {
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft {
    request.publicFacts.canonicalCopy
  }
}

/// Offline reference/test provider. Production defaults to canonical copy until
/// an owner approves a provider and its language quality.
struct DeterministicStyledExpressionProvider: NarrativeExpressionProviding {
  func generate(request: NarrativeExpressionRequest) async throws -> NarrativeExpressionDraft {
    request.permittedExpression
  }
}

enum NarrativeExpressionFailure: Error { case invalidSchema }

enum NarrativeExpressionValidator {
  static let maximumHeadlineCharacters = 72
  static let maximumSummaryCharacters = 480
  static let maximumTickerCharacters = 80

  static func accepts(_ draft: NarrativeExpressionDraft, for request: NarrativeExpressionRequest) -> Bool {
    guard !draft.headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !draft.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          draft.headline.count <= maximumHeadlineCharacters,
          draft.summary.count <= maximumSummaryCharacters,
          draft.tickerItems.count <= 4,
          draft.tickerItems.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && $0.count <= maximumTickerCharacters }) else { return false }
    // Exact whole-field membership rejects invented actors/numbers/causes,
    // negation, certainty, private language and unsupported continuity alike.
    return draft == request.publicFacts.canonicalCopy || draft == request.permittedExpression
  }
}

struct NarrativeExpressionResult: Equatable, Sendable {
  enum Status: Equatable, Sendable { case accepted, invalid, unavailable, timedOut }
  let copy: NarrativeExpressionDraft
  let status: Status
}

/// View-lifetime cache, never persisted. In-flight requests are coalesced;
/// changed public copy/metadata yields a different key even with the same ID.
actor NarrativeExpressionService {
  static let maximumEntries = 16
  private let provider: any NarrativeExpressionProviding
  private let timeout: Duration
  private var entries: [(request: NarrativeExpressionRequest, task: Task<NarrativeExpressionResult, Never>)] = []

  init(provider: any NarrativeExpressionProviding = DeterministicFallbackExpressionProvider(),
       timeout: Duration = .seconds(2)) {
    self.provider = provider
    self.timeout = max(.milliseconds(1), min(timeout, .seconds(2)))
  }

  func expression(for request: NarrativeExpressionRequest) async -> NarrativeExpressionResult {
    if let cached = entries.first(where: { $0.request == request }) { return await cached.task.value }
    // Hard cap bounds work even if a provider ignores cancellation. A fresh
    // viewer has a fresh cache; loading history never schedules generation.
    guard entries.count < Self.maximumEntries else {
      return NarrativeExpressionResult(copy: request.publicFacts.canonicalCopy, status: .unavailable)
    }
    let provider = self.provider
    let timeout = self.timeout
    let task = Task {
      await withCheckedContinuation { continuation in
        let race = NarrativeExpressionRace(continuation: continuation)
        let worker = Task.detached {
          let result: NarrativeExpressionResult
          do {
            let draft = try await provider.generate(request: request)
            result = NarrativeExpressionValidator.accepts(draft, for: request)
              ? NarrativeExpressionResult(copy: draft, status: .accepted)
              : NarrativeExpressionResult(copy: request.publicFacts.canonicalCopy, status: .invalid)
          } catch {
            result = NarrativeExpressionResult(copy: request.publicFacts.canonicalCopy, status: .unavailable)
          }
          await race.finish(result)
        }
        let deadline = Task.detached {
          do { try await Task.sleep(for: timeout) } catch { return }
          await race.finish(NarrativeExpressionResult(copy: request.publicFacts.canonicalCopy, status: .timedOut))
        }
        Task { await race.install(worker: worker, deadline: deadline) }
      }
    }
    entries.append((request, task))
    return await task.value
  }
}

/// First completion wins. Unlike a task group, timeout does not wait for an
/// uncooperative provider to finish; late results cannot replace fallback.
private actor NarrativeExpressionRace {
  private var continuation: CheckedContinuation<NarrativeExpressionResult, Never>?
  private var worker: Task<Void, Never>?
  private var deadline: Task<Void, Never>?

  init(continuation: CheckedContinuation<NarrativeExpressionResult, Never>) { self.continuation = continuation }

  func install(worker: Task<Void, Never>, deadline: Task<Void, Never>) {
    guard continuation != nil else { worker.cancel(); deadline.cancel(); return }
    self.worker = worker
    self.deadline = deadline
  }

  func finish(_ result: NarrativeExpressionResult) {
    guard let continuation else { return }
    self.continuation = nil
    worker?.cancel(); deadline?.cancel()
    worker = nil; deadline = nil
    continuation.resume(returning: result)
  }
}
