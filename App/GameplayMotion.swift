import SwiftUI

/// The vocabulary of motion the game uses to communicate simulation state.
///
/// Animation in SOLO is presentation only: it reports what the simulation has
/// already decided and never feeds back into it. Routing every gameplay
/// animation through this type keeps the timing consistent across screens and
/// makes Reduce Motion a property of the policy rather than something each call
/// site has to remember.
enum MotionKind {
  /// Routine state changes: phase moves, status labels, disclosure.
  case state
  /// Direct manipulation feedback: selection, taps, assignment.
  case emphasis
  /// Earned moments: task completion, level ups, milestones, upgrades.
  case celebration

  var animation: Animation {
    switch self {
    case .state: .smooth
    case .emphasis: .snappy
    case .celebration: .bouncy
    }
  }

  /// The animation to use given the user's Reduce Motion setting. `nil` means
  /// "change the value immediately", which is what `withAnimation(nil)` and
  /// `.animation(nil, value:)` both honor.
  func resolved(reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : animation
  }
}

private struct GameplayMotionModifier<Value: Equatable>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var kind: MotionKind
  var value: Value

  func body(content: Content) -> some View {
    content.animation(kind.resolved(reduceMotion: reduceMotion), value: value)
  }
}

/// A staged entrance for milestone surfaces — venture checkpoints, chapter
/// beats, headquarters moves — so the payoff reads as a sequence of earned
/// facts rather than a wall of text appearing at once.
private struct MilestoneRevealModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var order: Int
  @State private var revealed = false

  func body(content: Content) -> some View {
    content
      .opacity(revealed ? 1 : 0)
      .offset(y: revealed ? 0 : 14)
      .onAppear {
        let animation = MotionKind.celebration.resolved(reduceMotion: reduceMotion)?
          .delay(Double(order) * 0.07)
        withAnimation(animation) { revealed = true }
      }
  }
}

private struct FounderEntranceModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var order: Int
  @State private var visible = false

  func body(content: Content) -> some View {
    content
      .opacity(visible ? 1 : 0)
      .offset(y: visible || reduceMotion ? 0 : 12)
      .onAppear {
        guard !visible else { return }
        let animation = reduceMotion ? nil : Animation.smooth(duration: 0.4).delay(Double(order) * 0.07)
        withAnimation(animation) { visible = true }
      }
  }
}

extension View {
  /// Animates changes to `value` with the shared gameplay timing, honoring
  /// Reduce Motion without the call site having to check for it.
  func gameplayMotion<Value: Equatable>(_ kind: MotionKind = .state, value: Value) -> some View {
    modifier(GameplayMotionModifier(kind: kind, value: value))
  }

  /// Reveals a milestone element in sequence. With Reduce Motion on, every
  /// element is simply present immediately.
  func milestoneReveal(order: Int) -> some View {
    modifier(MilestoneRevealModifier(order: order))
  }

  func founderEntrance(order: Int) -> some View {
    modifier(FounderEntranceModifier(order: order))
  }
}
