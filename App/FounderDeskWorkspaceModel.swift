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

struct FounderDeskNavigationState: Equatable, Sendable {
  private(set) var selection: FounderDeskSelection = .overview
  private(set) var camera = FounderEnvironmentCameraState(mode: .freeLook)

  var lookOutActive: Bool { selection == .overview && camera.mode == .freeLook }
  var cameraControlsActive: Bool { lookOutActive && camera.environmentAllowsCameraGestures }

  @discardableResult
  mutating func select(_ device: FounderDeskDevice) -> FounderEnvironmentMode? {
    if device == .computer {
      guard camera.mode == .freeLook else { return nil }
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

enum FounderComputerWorkspaceTarget: String, Equatable, Sendable {
  case operations = "viewport"
  case founder
  case evidence
  case hindsight

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
