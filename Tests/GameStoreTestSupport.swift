import XCTest
@testable import Solo_Unicorn_Run

/// Shared helpers for driving a `GameStore` the way a player actually drives it.
///
/// Build 25 put a Thesis choice at the head of every venture, which means a
/// store is not ready to run sprints the instant `startCareer` returns: the
/// player still has to confirm a thesis, and that confirmation is what prepares
/// the sprint board. Tests that predate the thesis screen used to skip this
/// step, so they exercised a state a real player can never reach.
@MainActor
extension GameStore {
  /// Confirms the pending venture thesis, if one is pending, exactly as the
  /// venture thesis screen does. A no-op otherwise, so it is safe to call in a
  /// loop or after any venture transition.
  func confirmVentureThesisIfNeeded() {
    guard awaitingThesisSelection else { return }
    selectThesisAndBegin()
  }
}
