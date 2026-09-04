import Foundation

/// Hindsight — the career layer that makes a second venture mean something.
///
/// A Precedent records a consequential sprint decision, the bucketed conditions
/// it was made under, and what measurably followed. When a structurally similar
/// situation recurs in a later venture, the past one surfaces.
///
/// THE LOAD-BEARING RULE: a Precedent reports what happened under what
/// conditions. It never says a choice was wrong and never recommends one. If it
/// did, players would simply invert it and the game would solve itself. The
/// defence is that the simulation is genuinely contextual — committing three
/// unverified reports is survivable with low drift and ruinous with high drift.
enum ConditionBand: String, Codable, CaseIterable, Hashable {
  case low, medium, high

  var label: String {
    switch self {
    case .low: "Low"
    case .medium: "Medium"
    case .high: "High"
    }
  }

  static func drift(_ value: Int) -> Self {
    value < 25 ? .low : value < 55 ? .medium : .high
  }

  /// Runway is inverted: fewer days is the dangerous end.
  static func runway(_ days: Int) -> Self {
    days < 20 ? .low : days < 45 ? .medium : .high
  }

  static func unverified(_ count: Int) -> Self {
    count <= 0 ? .low : count == 1 ? .medium : .high
  }
}

/// Bucketed decision context. Buckets, not raw values, so matching is stable.
struct PrecedentContext: Codable, Hashable {
  var doctrine: FounderDoctrine
  var intent: SprintIntent
  var driftBand: ConditionBand
  var runwayBand: ConditionBand
  var unverifiedBand: ConditionBand

  var summary: String {
    "\(intent.name) intent • \(driftBand.label.lowercased()) drift • "
      + "\(runwayBand.label.lowercased()) runway • \(unverifiedBand.label.lowercased()) unverified load"
  }
}

/// What measurably followed the decision.
struct PrecedentOutcome: Codable, Hashable {
  var overclaimsSurfaced = 0
  var driftDetections = 0
  var unverifiedCommitted = 0
  var trustDelta = 0
  var runwayDelta = 0
  var momentumDelta = 0

  /// Neutral, factual reading. No judgement, by design.
  var summary: String {
    var parts: [String] = []
    if overclaimsSurfaced > 0 {
      parts.append("\(overclaimsSurfaced) overclaim\(overclaimsSurfaced == 1 ? "" : "s") surfaced")
    }
    if driftDetections > 0 {
      parts.append("\(driftDetections) drift detection\(driftDetections == 1 ? "" : "s")")
    }
    if unverifiedCommitted > 0 {
      parts.append("\(unverifiedCommitted) report\(unverifiedCommitted == 1 ? "" : "s") committed unverified")
    }
    if trustDelta != 0 { parts.append("trust \(signed(trustDelta))") }
    if runwayDelta != 0 { parts.append("runway \(signed(runwayDelta))") }
    if momentumDelta != 0 { parts.append("momentum \(signed(momentumDelta))") }
    return parts.isEmpty ? "No measurable change was recorded." : parts.joined(separator: ", ") + "."
  }

  private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
}

struct Precedent: Codable, Hashable, Identifiable {
  var id: UUID
  var venture: Int
  var sprint: Int
  var context: PrecedentContext
  var decisionSummary: String
  var outcome: PrecedentOutcome
  var counterfactual: PrecedentOutcome? = nil
  /// Optional so saves written before funding history continue to decode
  /// through synthesized `decodeIfPresent` behavior.
  var recordKind: PrecedentRecordKind? = nil
  var founderVisibleOutcome: String? = nil

  var recallTitle: String { "Venture \(venture), Sprint \(sprint)" }
  var isFundingRecord: Bool { recordKind == .funding }
  var observedOutcomeSummary: String { founderVisibleOutcome ?? outcome.summary }
}

enum PrecedentRecordKind: String, Codable, Hashable {
  case operatingSprint
  case funding
}

/// A surfaced Precedent plus how strongly it matches the live situation.
struct HindsightRecall: Identifiable, Hashable {
  var precedent: Precedent
  var similarity: Double
  var id: UUID { precedent.id }

  var strengthLabel: String {
    similarity >= 0.85 ? "Strong resonance" : similarity >= 0.72 ? "Close match" : "Partial match"
  }
}

enum HindsightEngine {
  /// Deterministic identity for a precedent, derived from its career position
  /// rather than drawn from the simulation RNG.
  ///
  /// This matters: recording a precedent must not consume a random draw, or the
  /// act of remembering would perturb the run being remembered. Career position
  /// is unique per precedent (one per venture/sprint at most) and stable across
  /// reloads.
  static func identifier(venture: Int, sprint: Int) -> UUID {
    var bytes = [UInt8](repeating: 0, count: 16)
    let tag = Array("SOLOHNDS".utf8)
    for index in 0..<8 { bytes[index] = tag[index] }
    let position = UInt64(max(0, venture)) << 32 | UInt64(max(0, sprint))
    for index in 0..<8 {
      bytes[8 + index] = UInt8(truncatingIfNeeded: position >> (56 - index * 8))
    }
    return UUID(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }

  /// Funding history shares the Hindsight archive without consuming simulation
  /// randomness or colliding with the one operating precedent per sprint.
  static func fundingIdentifier(
    opportunityID: String,
    event: String,
    careerSprint: Int
  ) -> UUID {
    let source = Array("\(opportunityID)|\(event)|\(max(0, careerSprint))".utf8)
    var first: UInt64 = 14_695_981_039_346_656_037
    var second: UInt64 = 10_995_116_282_11
    for byte in source {
      first = (first ^ UInt64(byte)) &* 1_099_511_628_211
      second = (second ^ UInt64(byte &+ 31)) &* 1_099_511_628_211
    }
    var bytes = Array("SOLOFUND".utf8)
    for index in 0..<4 { bytes.append(UInt8(truncatingIfNeeded: first >> (24 - index * 8))) }
    for index in 0..<4 { bytes.append(UInt8(truncatingIfNeeded: second >> (24 - index * 8))) }
    return UUID(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }

  /// Below this, do not surface. Weak matches are noise, not memory.
  static let similarityFloor = 0.62
  /// A resource, not a nag.
  static let maximumRecallsPerVenture = 3

  /// Deterministic field comparison. No model, no inference, no RNG —
  /// so recall can never perturb a seeded simulation.
  static func similarity(_ precedent: Precedent, _ context: PrecedentContext) -> Double {
    var score = 0.0
    if precedent.context.intent == context.intent { score += 0.30 }
    if precedent.context.driftBand == context.driftBand { score += 0.25 }
    if precedent.context.unverifiedBand == context.unverifiedBand { score += 0.25 }
    if precedent.context.runwayBand == context.runwayBand { score += 0.15 }
    if precedent.context.doctrine == context.doctrine { score += 0.05 }
    return min(1.0, score)
  }

  /// Best matching precedent from an earlier venture, if one clears the floor.
  static func recall(
    from precedents: [Precedent],
    matching context: PrecedentContext,
    currentVenture: Int,
    recallsAlreadyShown: Int
  ) -> HindsightRecall? {
    guard recallsAlreadyShown < maximumRecallsPerVenture else { return nil }
    let earlier = precedents.filter { $0.venture < currentVenture && !$0.isFundingRecord }
    let recalls = earlier.map { precedent in
      HindsightRecall(precedent: precedent, similarity: similarity(precedent, context))
    }
    let viable = recalls.filter { $0.similarity >= similarityFloor }
    return viable.sorted { lhs, rhs in
      if lhs.similarity == rhs.similarity {
        return lhs.precedent.sprint > rhs.precedent.sprint
      }
      return lhs.similarity > rhs.similarity
    }.first
  }

  /// Whether a sprint was consequential enough to be worth remembering.
  /// Uninteresting sprints are not recorded; the corpus stays signal.
  static func isConsequential(_ outcome: PrecedentOutcome) -> Bool {
    outcome.overclaimsSurfaced > 0
      || outcome.driftDetections > 0
      || outcome.unverifiedCommitted >= 2
      || abs(outcome.trustDelta) >= 6
      || abs(outcome.runwayDelta) >= 8
  }
}
