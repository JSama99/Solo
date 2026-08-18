import SwiftUI

/// The beat an agent card plays the moment the founder hands it work: the card
/// takes the hit, then a ring of the agent's colour expands out of it and
/// dissolves. It fires once per assignment and then gets out of the way, so the
/// continuous working animation is what remains.
struct AssignmentAcknowledgementModifier: ViewModifier {
  /// The stages of the acknowledgement. Phase order is the animation.
  enum Phase: CaseIterable {
    case rest
    case impact
    case bloom

    var cardScale: CGFloat {
      switch self {
      case .rest: 1
      case .impact: 1.045
      case .bloom: 1
      }
    }

    var ringScale: CGFloat {
      switch self {
      case .rest: 0.94
      case .impact: 1.01
      case .bloom: 1.12
      }
    }

    var ringOpacity: Double {
      switch self {
      case .rest: 0
      case .impact: 0.85
      case .bloom: 0
      }
    }

    var animation: Animation {
      switch self {
      case .rest: .linear(duration: 0.01)
      case .impact: .spring(duration: 0.24, bounce: 0.5)
      case .bloom: .easeOut(duration: 0.5)
      }
    }
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var trigger: Int
  var accent: Color
  var cornerRadius: CGFloat

  func body(content: Content) -> some View {
    if reduceMotion || trigger == 0 {
      content
    } else {
      content.phaseAnimator(Phase.allCases, trigger: trigger) { view, phase in
        view
          .scaleEffect(phase.cardScale)
          .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
              .strokeBorder(accent, lineWidth: 3)
              .scaleEffect(phase.ringScale)
              .opacity(phase.ringOpacity)
              .allowsHitTesting(false)
          }
      } animation: { phase in
        phase.animation
      }
    }
  }
}

extension View {
  /// Plays the assignment acknowledgement each time `trigger` changes.
  ///
  /// The trigger is an incrementing count rather than the task identifier so a
  /// reassignment back to a task the agent already held still reads.
  func assignmentAcknowledgement(trigger: Int, accent: Color, cornerRadius: CGFloat = 22) -> some View {
    modifier(AssignmentAcknowledgementModifier(trigger: trigger, accent: accent, cornerRadius: cornerRadius))
  }
}
