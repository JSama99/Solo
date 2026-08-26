import Foundation

/// Why a visual treatment exists. Higher-purpose motion subordinates lower
/// tiers, so the room never asks the Founder to watch several focal events.
enum LivingMotionPurpose: Int, CaseIterable, Comparable, Sendable {
  case ambient
  case informational
  case interactive
  case consequential
  case milestone

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

enum LivingMotionIntensity: String, Equatable, Sendable {
  case paused
  case subdued
  case normal
  case dominant
}

enum LivingMotionEventKind: String, CaseIterable, Sendable {
  case roomAtmosphere
  case workInProgress
  case founderAttention
  case assignmentDispatch
  case reviewOpened
  case approve
  case rework
  case crossCheck
  case shipAnyway
  case sprintCommitted

  var purpose: LivingMotionPurpose {
    switch self {
    case .roomAtmosphere: .ambient
    case .workInProgress, .founderAttention: .informational
    case .assignmentDispatch, .reviewOpened: .interactive
    case .approve, .rework, .crossCheck, .shipAnyway: .consequential
    case .sprintCommitted: .milestone
    }
  }
}

struct LivingMotionCandidate: Equatable, Sendable {
  var kind: LivingMotionEventKind
  var stableID: String
  var agentID: String?

  var purpose: LivingMotionPurpose { kind.purpose }
}

/// Stable result of conflict resolution. It is a value projection only: it
/// owns no clock, queue, store, task, or gameplay mutation closure.
struct LivingMotionPrioritySelection: Equatable, Sendable {
  var dominant: LivingMotionCandidate?
  var ordered: [LivingMotionCandidate]
  var ambientIntensity: LivingMotionIntensity

  var suppressesAmbient: Bool {
    guard let dominant else { return false }
    return dominant.purpose >= .consequential
  }

  func intensity(for candidate: LivingMotionCandidate) -> LivingMotionIntensity {
    guard let dominant else { return candidate.purpose == .ambient ? .normal : .subdued }
    if candidate == dominant { return .dominant }
    if candidate.purpose < dominant.purpose { return suppressesAmbient ? .paused : .subdued }
    return .normal
  }
}

enum LivingMotionPriorityPolicy {
  static func select(_ candidates: [LivingMotionCandidate]) -> LivingMotionPrioritySelection {
    let ordered = candidates.sorted(by: precedes)
    let dominant = ordered.first
    let ambient: LivingMotionIntensity
    if let dominant, dominant.purpose >= .consequential {
      ambient = .paused
    } else if dominant?.purpose == .interactive || dominant?.purpose == .informational {
      ambient = .subdued
    } else {
      ambient = .normal
    }
    return Self.selection(dominant: dominant, ordered: ordered, ambient: ambient)
  }

  private static func selection(
    dominant: LivingMotionCandidate?,
    ordered: [LivingMotionCandidate],
    ambient: LivingMotionIntensity
  ) -> LivingMotionPrioritySelection {
    LivingMotionPrioritySelection(
      dominant: dominant,
      ordered: ordered,
      ambientIntensity: ambient
    )
  }

  private static func precedes(_ lhs: LivingMotionCandidate, _ rhs: LivingMotionCandidate) -> Bool {
    if lhs.purpose != rhs.purpose { return lhs.purpose > rhs.purpose }
    let lhsKind = kindRank(lhs.kind)
    let rhsKind = kindRank(rhs.kind)
    if lhsKind != rhsKind { return lhsKind < rhsKind }
    let lhsAgent = agentRank(lhs.agentID)
    let rhsAgent = agentRank(rhs.agentID)
    if lhsAgent != rhsAgent { return lhsAgent < rhsAgent }
    return lhs.stableID < rhs.stableID
  }

  private static func kindRank(_ kind: LivingMotionEventKind) -> Int {
    LivingMotionEventKind.allCases.firstIndex(of: kind) ?? .max
  }

  private static func agentRank(_ id: String?) -> Int {
    guard let id else { return .max }
    return ["aurora", "stacks", "brio"].firstIndex(of: id) ?? .max
  }
}

enum AgentMotionRhythm: String, Equatable, Sendable {
  case deliberateSweep
  case sequentialAssembly
  case outwardWave
  case operationalPulse
}

/// A role signature is shape, rhythm, and icon based; color is intentionally
/// absent so identity survives Differentiate Without Color and high contrast.
struct AgentMotionSignature: Equatable, Sendable {
  var rhythm: AgentMotionRhythm
  var primarySymbol: String
  var artifactSymbol: String
  var phaseCount: Int
  var accessibilityDescription: String

  static func derive(role: AgentRole) -> Self {
    switch role {
    case .research:
      Self(
        rhythm: .deliberateSweep,
        primarySymbol: "doc.text.magnifyingglass",
        artifactSymbol: "point.3.connected.trianglepath.dotted",
        phaseCount: 4,
        accessibilityDescription: "Measured evidence scan and source comparison"
      )
    case .engineering:
      Self(
        rhythm: .sequentialAssembly,
        primarySymbol: "hammer.fill",
        artifactSymbol: "square.3.layers.3d",
        phaseCount: 5,
        accessibilityDescription: "Sequential build stages and compilation pulses"
      )
    case .marketing:
      Self(
        rhythm: .outwardWave,
        primarySymbol: "antenna.radiowaves.left.and.right",
        artifactSymbol: "rectangle.3.group.fill",
        phaseCount: 3,
        accessibilityDescription: "Campaign lanes and outward market-response wave"
      )
    case .general:
      Self(
        rhythm: .operationalPulse,
        primarySymbol: "gearshape.2.fill",
        artifactSymbol: "tray.full.fill",
        phaseCount: 4,
        accessibilityDescription: "Structured operational handoff"
      )
    }
  }
}

enum TruthSafeArtifactTone: String, Equatable, Sendable {
  case neutralProcess
  case reviewedFact
  case knownWarning
  case knownSuccess
}

struct CompanyCausalVisualLanguage: Equatable, Sendable {
  var symbol: String
  var tone: TruthSafeArtifactTone
  var shapeName: String
  var accessibilityDescription: String
}

extension CompanyCausalObject {
  var visualLanguage: CompanyCausalVisualLanguage {
    switch kind {
    case .assignmentPacket:
      CompanyCausalVisualLanguage(
        symbol: "checklist",
        tone: .neutralProcess,
        shapeName: "folded document",
        accessibilityDescription: "Neutral assignment packet"
      )
    case .completedArtifact:
      CompanyCausalVisualLanguage(
        symbol: "doc.text.fill",
        tone: .neutralProcess,
        shapeName: "document tray",
        accessibilityDescription: "Completed work awaiting Founder review; correctness unknown"
      )
    case .resolutionResponse:
      CompanyCausalVisualLanguage(
        symbol: resolutionChoice?.symbol ?? "seal.fill",
        tone: .reviewedFact,
        shapeName: resolutionShapeName,
        accessibilityDescription: resolutionChoice.map { "Founder action: \($0.title)" } ?? "Founder decision response"
      )
    }
  }

  private var resolutionShapeName: String {
    switch resolutionChoice {
    case .approve: "closed seal"
    case .rework: "return arrow"
    case .escalate: "cross-check bridge"
    case .shipAnyway: "outbound dispatch"
    case nil: "decision seal"
    }
  }
}

/// Concise post-action recap built only after the canonical resolution locks.
/// It intentionally contains no task-result fields.
struct LivingCausalRecap: Equatable, Identifiable, Sendable {
  var id: String
  var choice: TaskResolutionChoice
  var title: String
  var artifactLine: String
  var visibleConsequences: [String]
  var agentReaction: String?
  var followUpDevice: FounderDeskDevice

  var accessibilityAnnouncement: String {
    ([title, artifactLine] + visibleConsequences + [agentReaction].compactMap { $0 } + ["Follow-up is on the \(followUpDevice.title)."]) 
      .joined(separator: " ")
  }

  static func derive(
    taskID: UUID,
    taskTitle: String,
    agentName: String,
    choice: TaskResolutionChoice,
    before: VisibleCompanySnapshot,
    after: VisibleCompanySnapshot,
    relationshipBefore: Int,
    relationshipAfter: Int
  ) -> Self {
    var consequences: [String] = []
    appendDelta("Energy", before.energy, after.energy, to: &consequences)
    appendDelta("Runway", before.runway, after.runway, to: &consequences)
    appendDelta("Trust", before.trust, after.trust, to: &consequences)
    appendDelta("Momentum", before.momentum, after.momentum, to: &consequences)
    appendDelta("Revenue", before.revenue, after.revenue, to: &consequences)
    appendDelta("Capital", before.capital, after.capital, to: &consequences)
    if consequences.isEmpty { consequences = ["No immediate company metric changed"] }

    let relationshipDelta = relationshipAfter - relationshipBefore
    let reaction = relationshipDelta == 0
      ? nil
      : "\(agentName) relationship \(signed(relationshipDelta))"
    return Self(
      id: "\(taskID.uuidString)-\(choice.rawValue)",
      choice: choice,
      title: "\(choice.title) confirmed",
      artifactLine: artifactLine(taskTitle: taskTitle, agentName: agentName, choice: choice),
      visibleConsequences: consequences,
      agentReaction: reaction,
      followUpDevice: .computer
    )
  }

  private static func artifactLine(
    taskTitle: String,
    agentName: String,
    choice: TaskResolutionChoice
  ) -> String {
    switch choice {
    case .approve: "\(taskTitle) closed in Founder review"
    case .rework: "\(taskTitle) returned to \(agentName)"
    case .escalate: "\(taskTitle) routed through the canonical cross-check"
    case .shipAnyway: "\(taskTitle) dispatched with the reviewed decision"
    }
  }

  private static func appendDelta(
    _ label: String,
    _ before: Int,
    _ after: Int,
    to values: inout [String]
  ) {
    let delta = after - before
    if delta != 0 { values.append("\(label) \(signed(delta))") }
  }

  private static func signed(_ value: Int) -> String {
    value > 0 ? "+\(value)" : "\(value)"
  }
}
