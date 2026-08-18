import SwiftUI

/// The press-and-select feel for an agent workspace card.
///
/// Selecting an agent is a founder decision, so the card answers three ways at
/// once: it compresses under the finger, settles slightly larger than its
/// neighbours once chosen, and lifts off the background on a coloured shadow.
/// All three run on the same spring so the whole thing reads as one gesture
/// rather than three effects that happen to fire together.
struct AgentCardPressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var isSelected: Bool
  var accent: Color

  /// How far the card compresses under the finger.
  static let pressedScale: CGFloat = 0.955
  /// How far the selected card grows above its unselected neighbours.
  static let selectedScale: CGFloat = 1.025

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    return configuration.label
      .scaleEffect(Self.scale(pressed: pressed, selected: isSelected))
      .shadow(
        color: accent.opacity(isSelected ? 0.5 : 0.1),
        radius: isSelected ? 22 : 6,
        y: isSelected ? 12 : 3
      )
      .animation(motion, value: pressed)
      .animation(motion, value: isSelected)
  }

  /// The resting scale for a card in a given interaction state. Pressing always
  /// wins over selection so a tap on the already-selected card still registers.
  static func scale(pressed: Bool, selected: Bool) -> CGFloat {
    if pressed { return pressedScale }
    return selected ? selectedScale : 1
  }

  private var motion: Animation? { MotionKind.emphasis.resolved(reduceMotion: reduceMotion) }
}
