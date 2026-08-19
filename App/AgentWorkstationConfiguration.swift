import CoreGraphics
import Foundation

/// Presentation-only policy for the Founder Computer workstation cards.
/// Keeping these choices outside `GameStore` guarantees that expanding a card
/// cannot alter saves, seeded outcomes, or simulation state.
struct AgentWorkstationConfiguration {
  enum Attribute: String, CaseIterable, Hashable {
    case stress = "Stress"
    case trust = "Trust"
    case xp = "XP"
    case focus = "Focus"
  }

  enum Command: String, CaseIterable, Hashable {
    case assign
    case review
    case rest
    case resolve
  }

  static let collapsedPortraitSize: CGFloat = 64
  static let expandedPortraitSize: CGFloat = 116
  static let formerDeckCommands: [Command] = [.assign, .review, .rest]
  static let inCardCommands: [Command] = [.assign, .review, .rest, .resolve]

  static func visibleAttributes(expanded: Bool) -> [Attribute] {
    expanded ? Attribute.allCases : [.stress, .trust]
  }

  static func toggledSelection(current: String?, tapped: String) -> String? {
    current == tapped ? nil : tapped
  }

  static var hasFormerDeckParity: Bool {
    Set(formerDeckCommands).isSubset(of: Set(inCardCommands))
  }
}

struct AgentWorkstationActionAvailability: Equatable {
  var canAssign: Bool
  var canReview: Bool
  var canRest: Bool
  var canResolve: Bool

  init(
    sprintPhase: SprintPhase,
    task: SoloTask?,
    presentationPhase: PresentationCoordinator.AgentPhase?,
    attentionRemaining: Int,
    isResting: Bool
  ) {
    canAssign = sprintPhase == .chooseCommitments || sprintPhase == .assignTeam
    let presentationReady = presentationPhase == nil || presentationPhase == .awaitingReview
    canReview = presentationReady
      && sprintPhase == .reviewAndResolve
      && task?.isReviewed == false
      && task?.result != nil
      && attentionRemaining > 0
    canRest = canAssign && !isResting
    canResolve = task?.isReviewed == true
      && task?.resolutionLocked == false
      && presentationPhase != .resolving
  }
}
