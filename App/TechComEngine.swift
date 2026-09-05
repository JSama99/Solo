import Foundation

enum TechComHeadlineCategory: String, Codable, CaseIterable {
  case ownCompany
  case trend
  case rival
}

struct TechComHeadline: Codable, Identifiable, Equatable {
  var id: UUID
  var category: TechComHeadlineCategory
  var text: String
  var venture: Int
  var sprint: Int
  var publicEventID: String? = nil
}

struct NewsHeadlineTemplate {
  var id: String
  var category: TechComHeadlineCategory
  var textTemplate: String
  var trigger: (TechComSnapshot) -> Bool

  func resolve(_ slots: [String: String]) -> String {
    slots.reduce(textTemplate) { text, slot in
      text.replacingOccurrences(of: "{\(slot.key)}", with: slot.value)
    }
  }
}

struct TechComSnapshot {
  var founderName: String
  var venture: Int
  var sprint: Int
  var stats: FounderStats
  var agents: [SoloAgent]
  var tasks: [SoloTask]
  var dilemmaChoice: DilemmaChoice?
}

struct TechComRival: Codable, Identifiable, Equatable {
  var id: String
  var name: String
  var claimedTrackRecord: Int
  var actualTrackRecord: Int
  var claimedRevenue: Int
  var actualRevenue: Int
  var claimedMomentum: Int
  var actualMomentum: Int
  var isVerified = false

  static let overclaimThreshold = 8
  var verificationState: VerificationState { isVerified ? (overclaimAmount >= Self.overclaimThreshold ? .overclaimed : .confirmed) : .unverified }
  var overclaimAmount: Int { max(0, claimedTrackRecord - actualTrackRecord) }
}

enum TechComRankingMetric: String, CaseIterable, Identifiable {
  case trackRecord = "Track Record"
  case revenue = "Revenue"
  case momentum = "Momentum"
  var id: Self { self }
}

struct TechComRankingEntry: Identifiable, Equatable {
  var id: String
  var name: String
  var value: Int
  var isPlayer: Bool
}

enum TechComEngine {
  static let maximumHeadlinesPerSprint = 3

  /// Reflects the canonical public ledger in Tech.com without writing a second
  /// persisted headline or consuming simulation randomness.
  static func mergedOwnCompanyHeadlines(
    headlines: [TechComHeadline],
    publicEvents: [PublicMediaEvent]
  ) -> [TechComHeadline] {
    var seenPublicIDs = Set<String>()
    let publicHeadlines = publicEvents
      .filter { $0.isPublic && $0.concernsPlayerCompany && seenPublicIDs.insert($0.id).inserted }
      .map { event in
        TechComHeadline(
          id: stableHeadlineID(event.id),
          category: .ownCompany,
          text: event.headline,
          venture: event.venture,
          sprint: event.sprint,
          publicEventID: event.id
        )
      }
    let publicIDs = Set(publicHeadlines.compactMap(\.publicEventID))
    let existing = headlines.filter {
      $0.category == .ownCompany
        && ($0.publicEventID.map { !publicIDs.contains($0) } ?? true)
    }
    return Array((publicHeadlines + existing).prefix(60))
  }

  static func headlines(
    snapshot: TechComSnapshot,
    events: [PresentationCoordinator.Event],
    generator: inout SeededRandomNumberGenerator
  ) -> [TechComHeadline] {
    let own = events.compactMap { headline(snapshot: snapshot, event: $0) }
    let trendAllowance = max(0, maximumHeadlinesPerSprint - min(maximumHeadlinesPerSprint, own.count))
    let trends = trendAllowance > 0 ? trendHeadlines(snapshot: snapshot, count: trendAllowance, generator: &generator) : []
    return Array((own + trends).prefix(maximumHeadlinesPerSprint))
  }

  static func rivals(seed: UInt64) -> [TechComRival] {
    var generator = SeededRandomNumberGenerator(seed: seed ^ 0x54454348434F4D)
    return ContentLibrary.rivalCompanies.map { definition in
      let actualTrack = generator.integer(in: 18...72)
      let gap = generator.integer(in: 0...18)
      let actualRevenue = generator.integer(in: 650...4_200)
      let actualMomentum = generator.integer(in: 25...88)
      return TechComRival(
        id: definition.id, name: definition.name,
        claimedTrackRecord: actualTrack + gap, actualTrackRecord: actualTrack,
        claimedRevenue: actualRevenue + generator.integer(in: 0...900), actualRevenue: actualRevenue,
        claimedMomentum: actualMomentum + generator.integer(in: 0...18), actualMomentum: actualMomentum
      )
    }
  }

  static func rankings(snapshot: TechComSnapshot, rivals: [TechComRival], metric: TechComRankingMetric) -> [TechComRankingEntry] {
    let player: Int
    switch metric { case .trackRecord: player = snapshot.stats.trackRecord; case .revenue: player = snapshot.stats.revenue; case .momentum: player = snapshot.stats.momentum }
    let entries = [TechComRankingEntry(id: "solo", name: "SOLO", value: player, isPlayer: true)] + rivals.map { rival in
      let value: Int
      switch metric { case .trackRecord: value = rival.isVerified ? rival.actualTrackRecord : rival.claimedTrackRecord; case .revenue: value = rival.isVerified ? rival.actualRevenue : rival.claimedRevenue; case .momentum: value = rival.isVerified ? rival.actualMomentum : rival.claimedMomentum }
      return TechComRankingEntry(id: rival.id, name: rival.name, value: value, isPlayer: false)
    }
    return entries.sorted { $0.value == $1.value ? $0.name < $1.name : $0.value > $1.value }
  }

  private static func headline(snapshot: TechComSnapshot, event: PresentationCoordinator.Event) -> TechComHeadline? {
    let text: String
    switch event {
    case .assignment(_, let taskID, let agentID, _):
      guard let task = snapshot.tasks.first(where: { $0.id == taskID }), let agent = snapshot.agents.first(where: { $0.id == agentID }) else { return nil }
      text = "\(agent.name) takes on \(task.title) at SOLO"
    case .review(_, let taskID, let agentID, let result, _):
      guard let task = snapshot.tasks.first(where: { $0.id == taskID }), let agent = snapshot.agents.first(where: { $0.id == agentID }) else { return nil }
      if let actual = result.actualQuality, result.overclaimAmount > 0 { text = "SOLO review finds \(agent.name)'s \(task.title) overclaimed by \(result.overclaimAmount): actual \(actual)" }
      else { text = "SOLO verifies \(agent.name)'s \(task.title): \(result.verificationState.label)" }
    case .sprint(_, let result):
      text = "SOLO closes sprint \(result.sprint): \(result.headline) (\(result.revenueDelta >= 0 ? "+" : "")$\(result.revenueDelta) revenue)"
    }
    return TechComHeadline(id: UUID(), category: .ownCompany, text: text, venture: snapshot.venture, sprint: snapshot.sprint)
  }

  private static func trendHeadlines(snapshot: TechComSnapshot, count: Int, generator: inout SeededRandomNumberGenerator) -> [TechComHeadline] {
    var choices = ContentLibrary.techComHeadlineTemplates.filter { $0.category == .trend && $0.trigger(snapshot) }
    return (0..<count).compactMap { _ in
      guard !choices.isEmpty else { return nil }
      let index = generator.integer(in: 0...choices.count - 1)
      let template = choices.remove(at: index)
      return TechComHeadline(id: UUID(), category: .trend, text: template.resolve(["sprint": "\(snapshot.sprint)"]), venture: snapshot.venture, sprint: snapshot.sprint)
    }
  }

  private static func stableHeadlineID(_ eventID: String) -> UUID {
    let source = Array(eventID.utf8)
    var first: UInt64 = 14_695_981_039_346_656_037
    var second: UInt64 = 10_995_116_282_11
    for byte in source {
      first = (first ^ UInt64(byte)) &* 1_099_511_628_211
      second = (second ^ UInt64(byte &+ 31)) &* 1_099_511_628_211
    }
    return UUID(uuid: (
      UInt8(truncatingIfNeeded: first >> 56), UInt8(truncatingIfNeeded: first >> 48),
      UInt8(truncatingIfNeeded: first >> 40), UInt8(truncatingIfNeeded: first >> 32),
      UInt8(truncatingIfNeeded: first >> 24), UInt8(truncatingIfNeeded: first >> 16),
      UInt8(truncatingIfNeeded: first >> 8), UInt8(truncatingIfNeeded: first),
      UInt8(truncatingIfNeeded: second >> 56), UInt8(truncatingIfNeeded: second >> 48),
      UInt8(truncatingIfNeeded: second >> 40), UInt8(truncatingIfNeeded: second >> 32),
      UInt8(truncatingIfNeeded: second >> 24), UInt8(truncatingIfNeeded: second >> 16),
      UInt8(truncatingIfNeeded: second >> 8), UInt8(truncatingIfNeeded: second)
    ))
  }
}
