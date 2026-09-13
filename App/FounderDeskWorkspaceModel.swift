import Foundation

enum FounderDeskDevice: String, CaseIterable, Codable, Identifiable, Sendable {
  case computer
  case phone
  case tablet
  case server

  var id: String { rawValue }

  var title: String {
    switch self {
    case .computer: "Founder Computer"
    case .phone: "Tech.com iPhone"
    case .tablet: "Venture iPad"
    case .server: "Company Server"
    }
  }

  var symbol: String {
    switch self {
    case .computer: "desktopcomputer"
    case .phone: "iphone"
    case .tablet: "ipad.landscape"
    case .server: "server.rack"
    }
  }
}

enum FounderDeskSelection: Equatable, Sendable {
  case overview
  case device(FounderDeskDevice)
}

enum FounderDeskTransitionStyle: Equatable, Sendable {
  case spatialFocus
  case crossfade
}

enum FounderDeskLayout: Equatable, Sendable {
  case spatialCompact
  case spatialRegular
  case accessibleList
}

enum FounderDeskLayoutPolicy {
  static func layout(regularWidth: Bool, accessibilityText: Bool, height: Double) -> FounderDeskLayout {
    if accessibilityText || height < 560 { return .accessibleList }
    return regularWidth ? .spatialRegular : .spatialCompact
  }
}

enum FounderDeskCameraChromePolicy {
  static func exposesManualControls(expanded: Bool, accessibilityText: Bool) -> Bool {
    expanded || accessibilityText
  }

  static func showsInstruction(hasUsedFreeLook: Bool) -> Bool {
    !hasUsedFreeLook
  }
}

struct FounderDeskNavigationState: Equatable, Sendable {
  private(set) var garageCameraState: FounderGarageCameraState = .founderPOV
  private(set) var selection: FounderDeskSelection = .overview
  private(set) var camera = FounderEnvironmentCameraState(mode: .freeLook)

  var lookOutActive: Bool { selection == .overview && camera.mode == .freeLook }
  var cameraControlsActive: Bool { lookOutActive && camera.environmentAllowsCameraGestures }

  mutating func observeGarage(_ state: FounderGarageCameraState) {
    guard lookOutActive else { return }
    garageCameraState = state
  }

  @discardableResult
  mutating func select(_ device: FounderDeskDevice) -> FounderEnvironmentMode? {
    if device == .computer {
      guard camera.mode == .freeLook, garageCameraState.allowsComputer else { return nil }
      guard camera.beginComputerFocusTransition() else { return nil }
      return .computerFocused
    }
    guard lookOutActive else { return nil }
    selection = .device(device)
    return nil
  }

  @discardableResult
  mutating func lookOut() -> FounderEnvironmentMode? {
    guard selection == .device(.computer), camera.beginFreeLookTransition() else { return nil }
    selection = .overview
    garageCameraState = .founderPOV
    return .freeLook
  }

  mutating func closeSecondaryDevice() {
    guard case .device(let device) = selection, device != .computer else { return }
    selection = .overview
  }

  mutating func completeCameraTransition(to destination: FounderEnvironmentMode) {
    switch destination {
    case .computerFocused:
      camera.completeComputerFocusTransition()
      selection = .device(.computer)
    case .freeLook:
      camera.completeFreeLookTransition()
      selection = .overview
    case .transitioningToComputerFocus, .transitioningToFreeLook:
      break
    }
  }

  mutating func look(horizontal: Double, vertical: Double, reduceMotion: Bool) {
    guard cameraControlsActive else { return }
    camera.look(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
  }

  mutating func setLook(horizontal: Double, vertical: Double, reduceMotion: Bool) {
    guard cameraControlsActive else { return }
    camera.setLook(horizontal: horizontal, vertical: vertical, reduceMotion: reduceMotion)
  }

  mutating func centerCamera() {
    guard cameraControlsActive else { return }
    camera.center()
  }

  func transitionStyle(reduceMotion: Bool) -> FounderDeskTransitionStyle {
    reduceMotion ? .crossfade : .spatialFocus
  }
}

enum CompanyServerDestination: String, CaseIterable, Hashable, Identifiable, Sendable {
  case evidence
  case agentOperations
  case achievements
  case headquarters
  case companyStory
  case soloPro
  case settings
  case howToPlay
  case restartCareer

  var id: String { rawValue }

  var title: String {
    switch self {
    case .evidence: "Evidence Ledger"
    case .agentOperations: "Agent Operations"
    case .achievements: "Achievements"
    case .headquarters: "Headquarters Progress"
    case .companyStory: "Company Story"
    case .soloPro: "Solo Pro"
    case .settings: "Settings"
    case .howToPlay: "How to Play"
    case .restartCareer: "Restart Career"
    }
  }
}

enum FounderComputerWorkspaceTarget: String, Equatable, Sendable, Identifiable {
  case operations = "viewport"
  case founder
  case evidence
  case hindsight

  var id: String { rawValue }

  var accessibilityTitle: String {
    switch self {
    case .operations: "Agent operations"
    case .founder: "Founder actions"
    case .evidence: "Evidence Ledger"
    case .hindsight: "Hindsight"
    }
  }
}

struct FounderComputerWorkspaceRequest: Equatable, Sendable {
  var id = UUID()
  var target: FounderComputerWorkspaceTarget
}

struct FounderDeskPreview: Equatable, Sendable {
  var title: String
  var primary: String
  var secondary: String
  var signal: String?
  var accessibilityLabel: String
}

/// Only lifecycle-visible, already-published inputs may enter desk chrome.
/// Hidden task result fields deliberately do not exist in this input contract.
struct FounderDeskPreviewInput: Equatable, Sendable {
  var sprint: Int
  var venture: Int
  var sprintPhase: SprintPhase
  var visibleWorkCount: Int
  var visibleReviewCount: Int
  var evidenceCount: Int
  var canCommit: Bool
  var latestPublishedHeadline: String?
  var marketRank: Int?
  var ventureObjective: String
  var ventureObjectiveComplete: Bool
  var facilityName: String
  var achievementCount: Int
  var ownedFacilityCount: Int
}

enum FounderDeskPreviewPolicy {
  static func preview(for device: FounderDeskDevice, input: FounderDeskPreviewInput) -> FounderDeskPreview {
    switch device {
    case .computer:
      let work = input.visibleReviewCount > 0
        ? "\(input.visibleReviewCount) awaiting Founder review"
        : "\(input.visibleWorkCount) active workstation\(input.visibleWorkCount == 1 ? "" : "s")"
      let signal = input.visibleReviewCount > 0 ? "Review tray ready" : input.canCommit ? "Sprint ready" : nil
      return FounderDeskPreview(
        title: "FOUNDER COMMAND",
        primary: "Sprint \(input.sprint) · \(input.sprintPhase.safeDeskLabel)",
        secondary: work,
        signal: signal,
        accessibilityLabel: "Founder Computer. Sprint \(input.sprint). \(work).\(signal.map { " \($0)." } ?? "")"
      )
    case .phone:
      let headline = input.latestPublishedHeadline ?? "No new published stories"
      let rank = input.marketRank.map { "Company rank \($0)" } ?? "Ranking unavailable"
      return FounderDeskPreview(
        title: "TECH.COM",
        primary: headline,
        secondary: rank,
        signal: input.latestPublishedHeadline == nil ? nil : "Published update",
        accessibilityLabel: "Tech.com iPhone. \(headline). \(rank)."
      )
    case .tablet:
      let readiness = input.ventureObjectiveComplete ? "Objective complete" : "Objective active"
      return FounderDeskPreview(
        title: "VENTURE \(input.venture)",
        primary: input.ventureObjective,
        secondary: "Sprint \(input.sprint) · \(readiness)",
        signal: input.ventureObjectiveComplete ? "Objective milestone" : nil,
        accessibilityLabel: "Venture iPad. Venture \(input.venture), sprint \(input.sprint). \(input.ventureObjective). \(readiness)."
      )
    case .server:
      let records = "\(input.evidenceCount) evidence record\(input.evidenceCount == 1 ? "" : "s")"
      return FounderDeskPreview(
        title: "COMPANY SERVER",
        primary: input.facilityName,
        secondary: "\(records) · \(input.achievementCount) achievements",
        signal: input.ownedFacilityCount > 1 ? "Facilities available" : nil,
        accessibilityLabel: "Company Server. \(input.facilityName). \(records). \(input.achievementCount) achievements."
      )
    }
  }
}

private extension SprintPhase {
  var safeDeskLabel: String {
    switch self {
    case .founderEvent: "Founder event"
    case .chooseCommitments: "Planning"
    case .assignTeam: "Assign team"
    case .reviewAndResolve: "Founder review"
    case .readyToCommit: "Commit ready"
    }
  }
}

enum FounderStrategicInitiativeCategory: String, CaseIterable, Sendable {
  case productLaunch, fundraising, competitiveMove
}

enum FounderStrategyTrack: String, CaseIterable, Identifiable, Sendable {
  case market, product, growth, capital, risk

  var id: String { rawValue }

  var title: String { rawValue.capitalized }
}

enum FounderStrategyOwner: String, Sendable {
  case aurora = "Aurora"
  case stacks = "Stacks"
  case brio = "Brio"
  case founder = "Founder"
  case system = "System"
}

enum FounderStrategyCanonicalRoute: String, CaseIterable, Hashable, Sendable {
  case agentOperations, evidenceLedger, fundingOpportunities, commitSprint
}

struct FounderStrategyPreparationDefinition: Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var requirement: String
  var track: FounderStrategyTrack
  var owner: FounderStrategyOwner
  var route: FounderStrategyCanonicalRoute
  var blocksCommit: Bool
}

struct FounderStrategicInitiativeDefinition: Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var category: FounderStrategicInitiativeCategory
  var objective: String
  var executionRoute: FounderStrategyCanonicalRoute
  var executionSupported: Bool
  var preparation: [FounderStrategyPreparationDefinition]

  static let all: [Self] = [
    .init(
      id: "product-launch",
      title: "Product Launch",
      category: .productLaunch,
      objective: "Coordinate research, reliability, evidence, and positioning into one launch-ready sprint.",
      executionRoute: .commitSprint,
      executionSupported: true,
      preparation: [
        .init(id: "launch.market-research", title: "Market research", requirement: "Aurora work reviewed and resolved", track: .market, owner: .aurora, route: .agentOperations, blocksCommit: true),
        .init(id: "launch.evidence", title: "Evidence confidence", requirement: "Submitted launch work has Founder-reviewed evidence", track: .risk, owner: .founder, route: .evidenceLedger, blocksCommit: true),
        .init(id: "launch.reliability", title: "Product reliability", requirement: "Stacks work reviewed and technically resolved", track: .product, owner: .stacks, route: .agentOperations, blocksCommit: true),
        .init(id: "launch.positioning", title: "Launch positioning", requirement: "Brio work reviewed and resolved", track: .growth, owner: .brio, route: .agentOperations, blocksCommit: true),
        .init(id: "launch.capital", title: "Capital impact", requirement: "No canonical Product Launch cost projection exists", track: .capital, owner: .system, route: .fundingOpportunities, blocksCommit: false)
      ]
    ),
    .init(
      id: "fundraising",
      title: "Fundraising",
      category: .fundraising,
      objective: "Review canonical grants, fundraising windows, evidence, and investor obligations.",
      executionRoute: .fundingOpportunities,
      executionSupported: false,
      preparation: []
    ),
    .init(
      id: "competitive-move",
      title: "Competitive Move",
      category: .competitiveMove,
      objective: "Coordinate a response using public rival claims and existing agent work.",
      executionRoute: .agentOperations,
      executionSupported: false,
      preparation: []
    )
  ]
}

struct FounderStrategyTaskSignal: Equatable, Sendable {
  var id: UUID
  var title: String
  var agentID: String
  var submitted: Bool
  var reviewed: Bool
  var resolutionLocked: Bool
  var evidenceRecorded: Bool
}

struct FounderStrategyPublicRivalSignal: Equatable, Sendable {
  var id: String
  var name: String
  var claimedMomentum: Int
}

/// Founder-visible inputs only. Task quality, overclaim, drift, actual rival
/// values, future outcomes, and RNG state cannot enter the projection.
struct FounderStrategyBoardSnapshot: Equatable, Sendable {
  var sprint: Int
  var attentionRemaining: Int
  var runway: Int
  var cash: Int
  var canCommitSprint: Bool
  var canonicalCommitBlocker: String?
  var tasks: [FounderStrategyTaskSignal]
  var publicRivals: [FounderStrategyPublicRivalSignal]
  var operationalRisks: [String] = []
  var hiddenStateRejectionCount: Int

  @MainActor static func read(_ store: GameStore) -> Self {
    let evidenceTaskIDs = Set(store.evidence.map(\.taskInstanceID))
    return .init(
      sprint: store.sprint,
      attentionRemaining: store.attentionRemaining,
      runway: store.stats.runway,
      cash: store.finance.cash,
      canCommitSprint: store.canCommitSprint,
      canonicalCommitBlocker: store.commitBlockerMessage,
      tasks: store.tasks.compactMap { task in
        guard let agentID = task.assignedAgentID else { return nil }
        return .init(
          id: task.id,
          title: task.title,
          agentID: agentID,
          submitted: task.result != nil,
          reviewed: task.isReviewed,
          resolutionLocked: task.resolutionLocked,
          evidenceRecorded: evidenceTaskIDs.contains(task.id.uuidString)
        )
      },
      publicRivals: store.techComRivals.sorted { $0.id < $1.id }.map {
        .init(id: $0.id, name: $0.name, claimedMomentum: $0.claimedMomentum)
      },
      operationalRisks: ["aurora", "stacks", "brio"].compactMap { agentID in
        let workload = store.agentOperationsWorkload(for: agentID)
        let profile = store.agentOperationsProfile(for: agentID)
        if workload > 105 { return "\(agentID.capitalized) workload is \(workload)% before launch." }
        if agentID == "stacks", profile.allocation(for: .reliability) < 15 {
          return "Stacks reliability allocation is below 15%."
        }
        return nil
      },
      hiddenStateRejectionCount: store.techComRivals.count
    )
  }
}

enum FounderInitiativeItemStatus: String, Sendable {
  case complete, incomplete, blocked, reviewRequired, unavailable

  var symbol: String {
    switch self {
    case .complete: "checkmark.circle.fill"
    case .incomplete: "circle"
    case .blocked: "exclamationmark.triangle.fill"
    case .reviewRequired: "questionmark.circle.fill"
    case .unavailable: "minus.circle"
    }
  }

  var label: String {
    switch self {
    case .complete: "Complete"
    case .incomplete: "Incomplete"
    case .blocked: "Blocked"
    case .reviewRequired: "Review required"
    case .unavailable: "Unavailable"
    }
  }
}

struct FounderInitiativePreparationProjection: Identifiable, Equatable, Sendable {
  var definition: FounderStrategyPreparationDefinition
  var status: FounderInitiativeItemStatus
  var detail: String
  var id: String { definition.id }
  var isCommitBlocker: Bool { definition.blocksCommit && status != .complete }
}

enum FounderInitiativeReadiness: String, Sendable {
  case ready, notReady, blocked, needsReview

  var title: String {
    switch self {
    case .ready: "Ready"
    case .notReady: "Not Ready"
    case .blocked: "Blocked"
    case .needsReview: "Needs Review"
    }
  }
}

struct FounderInitiativeProjection: Equatable, Sendable {
  var definition: FounderStrategicInitiativeDefinition
  var preparation: [FounderInitiativePreparationProjection]
  var readiness: FounderInitiativeReadiness
  var blockers: [String]
  var risks: [String]
  var incompleteItemCount: Int
  var evidenceBlockerCount: Int
  var canonicalRouteCount: Int
  var commitEligible: Bool
  var capitalSummary: String
}

enum FounderStrategyBoardPolicy {
  static func project(
    _ definition: FounderStrategicInitiativeDefinition,
    snapshot: FounderStrategyBoardSnapshot
  ) -> FounderInitiativeProjection {
    guard definition.category == .productLaunch else {
      let rivalRisk = snapshot.publicRivals.filter { $0.claimedMomentum >= 70 }.map {
        "Public signal: \($0.name) claims \($0.claimedMomentum) Momentum."
      }
      return .init(
        definition: definition,
        preparation: [],
        readiness: .notReady,
        blockers: ["Planning projection only; canonical execution is not available in this phase."],
        risks: rivalRisk,
        incompleteItemCount: 0,
        evidenceBlockerCount: 0,
        canonicalRouteCount: 1,
        commitEligible: false,
        capitalSummary: "Canonical funding and runway data remain available in their existing surfaces."
      )
    }

    let items = definition.preparation.map { item in
      preparation(item, snapshot: snapshot)
    }
    var blockers = items.filter(\.isCommitBlocker).map { "\($0.definition.title): \($0.detail)" }
    let reviewCount = items.filter { $0.status == .reviewRequired }.count
    if reviewCount > snapshot.attentionRemaining {
      blockers.append("Founder Attention insufficient: \(snapshot.attentionRemaining) available for \(reviewCount) required reviews.")
    }
    if let canonical = snapshot.canonicalCommitBlocker, !blockers.contains(canonical) {
      blockers.append(canonical)
    }
    let risks = items.filter { $0.status == .blocked || $0.status == .reviewRequired }.map {
      "\($0.definition.track.title): \($0.detail)"
    } + snapshot.publicRivals.filter { $0.claimedMomentum >= 70 }.map {
      "Competitive: \($0.name) publicly claims \($0.claimedMomentum) Momentum."
    } + snapshot.operationalRisks
    let readiness: FounderInitiativeReadiness
    if items.contains(where: { $0.status == .blocked }) { readiness = .blocked }
    else if items.contains(where: { $0.status == .reviewRequired }) { readiness = .needsReview }
    else if blockers.isEmpty { readiness = .ready }
    else { readiness = .notReady }
    let eligible = readiness == .ready && snapshot.canCommitSprint
    return .init(
      definition: definition,
      preparation: items,
      readiness: eligible ? .ready : readiness,
      blockers: blockers,
      risks: risks,
      incompleteItemCount: items.filter { $0.status != .complete && $0.status != .unavailable }.count,
      evidenceBlockerCount: items.filter { $0.definition.id == "launch.evidence" && $0.status != .complete }.count,
      canonicalRouteCount: Set(items.map { $0.definition.route }).count + 1,
      commitEligible: eligible,
      capitalSummary: "Capital impact unavailable · Runway \(snapshot.runway) days · Cash \(snapshot.cash.formatted(.currency(code: "USD").precision(.fractionLength(0))))"
    )
  }

  private static func preparation(
    _ definition: FounderStrategyPreparationDefinition,
    snapshot: FounderStrategyBoardSnapshot
  ) -> FounderInitiativePreparationProjection {
    if definition.id == "launch.capital" {
      return .init(definition: definition, status: .unavailable, detail: "No canonical launch cost exists; no estimate is fabricated.")
    }
    if definition.id == "launch.evidence" {
      let required = ["aurora", "stacks", "brio"].compactMap { id in snapshot.tasks.first { $0.agentID == id } }
      if required.count < 3 {
        return .init(definition: definition, status: .incomplete, detail: "Assign Aurora, Stacks, and Brio preparation work first.")
      }
      if required.contains(where: { !$0.reviewed || !$0.evidenceRecorded }) {
        return .init(definition: definition, status: .reviewRequired, detail: "Submitted work still needs canonical Founder review and Evidence Ledger records.")
      }
      return .init(definition: definition, status: .complete, detail: "Founder-reviewed evidence is recorded for all launch tracks.")
    }
    let agentID = definition.owner.rawValue.lowercased()
    guard let task = snapshot.tasks.first(where: { $0.agentID == agentID }) else {
      return .init(definition: definition, status: .incomplete, detail: "No current \(definition.owner.rawValue) assignment.")
    }
    guard task.submitted else {
      return .init(definition: definition, status: .incomplete, detail: "\(task.title) is assigned; canonical work has not been submitted.")
    }
    guard task.reviewed else {
      return .init(definition: definition, status: .reviewRequired, detail: "\(task.title) is submitted; confidence remains unresolved until Founder review.")
    }
    guard task.resolutionLocked else {
      return .init(definition: definition, status: .blocked, detail: "\(task.title) was reviewed; choose its canonical resolution.")
    }
    return .init(definition: definition, status: .complete, detail: "\(task.title) is reviewed and resolved.")
  }
}

struct FounderStrategyCommitGate: Equatable, Sendable {
  private(set) var invocationCount = 0
  private(set) var canonicalExecutionCount = 0
  private(set) var duplicatePreventionCount = 0
  private(set) var committedSprint: Int?

  mutating func claim(eligible: Bool, sprint: Int) -> Bool {
    invocationCount += 1
    guard eligible else { return false }
    guard committedSprint == nil else { duplicatePreventionCount += 1; return false }
    committedSprint = sprint
    canonicalExecutionCount += 1
    return true
  }
}

#if DEBUG
enum FounderStrategyBoardFixture: String, CaseIterable, Identifiable {
  case empty = "A · Empty launch"
  case partial = "B · Partial preparation"
  case evidenceBlocker = "C · Evidence blocker"
  case technicalBlocker = "D · Technical blocker"
  case ready = "E · Ready"
  case publicRivalRisk = "F · Public rival risk"

  var id: String { rawValue }
  var accessibilityID: String {
    switch self {
    case .empty: "empty"
    case .partial: "partial"
    case .evidenceBlocker: "evidenceBlocker"
    case .technicalBlocker: "technicalBlocker"
    case .ready: "ready"
    case .publicRivalRisk: "publicRivalRisk"
    }
  }

  var snapshot: FounderStrategyBoardSnapshot {
    let allIDs = ["aurora", "stacks", "brio"]
    func signal(_ agentID: String, submitted: Bool = true, reviewed: Bool, locked: Bool) -> FounderStrategyTaskSignal {
      let id = UUID(uuidString: agentID == "aurora" ? "00000000-0000-0000-0000-0000000000A1" : agentID == "stacks" ? "00000000-0000-0000-0000-0000000000B2" : "00000000-0000-0000-0000-0000000000C3")!
      return .init(id: id, title: "\(agentID.capitalized) launch preparation", agentID: agentID, submitted: submitted, reviewed: reviewed, resolutionLocked: locked, evidenceRecorded: locked)
    }
    let tasks: [FounderStrategyTaskSignal]
    let attention: Int
    let canCommit: Bool
    let blocker: String?
    switch self {
    case .empty:
      tasks=[];attention=2;canCommit=false;blocker="Assign at least one agent before committing the sprint."
    case .partial:
      tasks=[signal("aurora",reviewed:true,locked:true),signal("stacks",reviewed:false,locked:false)];attention=2;canCommit=true;blocker=nil
    case .evidenceBlocker:
      tasks=allIDs.map { signal($0,reviewed:false,locked:false) };attention=3;canCommit=true;blocker=nil
    case .technicalBlocker:
      tasks=[signal("aurora",reviewed:true,locked:true),signal("stacks",reviewed:true,locked:false),signal("brio",reviewed:true,locked:true)];attention=2;canCommit=false;blocker="Choose how to resolve Stacks launch preparation before committing."
    case .ready,.publicRivalRisk:
      tasks=allIDs.map { signal($0,reviewed:true,locked:true) };attention=2;canCommit=true;blocker=nil
    }
    let rivals = self == .publicRivalRisk ? [FounderStrategyPublicRivalSignal(id:"pallas",name:"Pallas AI",claimedMomentum:90)] : []
    return .init(sprint:2,attentionRemaining:attention,runway:44,cash:1_200,canCommitSprint:canCommit,canonicalCommitBlocker:blocker,tasks:tasks,publicRivals:rivals,hiddenStateRejectionCount:rivals.count)
  }
}
#endif
