import SwiftUI

/// The answer the screen gives back when the founder locks in a resolution.
///
/// Approve blooms — a ring of mint opens out of the panel behind a seal. Every
/// other call gets a restrained version: a short lateral nudge of the panel
/// itself and a coloured ring, never a shake of the whole screen.
struct ResolutionFeedback: Equatable {
  enum Kind: Equatable {
    case positive
    case restrained

    var accent: Color {
      switch self {
      case .positive: SoloTheme.mint
      case .restrained: SoloTheme.amber
      }
    }
  }

  var kind: Kind
  var symbol: String
  /// Increments per resolution so repeated identical calls still animate.
  var count: Int

  init(choice: TaskResolutionChoice, count: Int) {
    kind = choice == .approve ? .positive : .restrained
    symbol = choice.symbol
    self.count = count
  }
}

struct ResolutionFeedbackModifier: ViewModifier {
  enum Phase: CaseIterable {
    case rest
    case strike
    case counter
    case hold
    case settle

    var animation: Animation {
      switch self {
      case .rest: .linear(duration: 0.01)
      case .strike: .spring(duration: 0.2, bounce: 0.45)
      case .counter: .spring(duration: 0.2, bounce: 0.3)
      // The hold is what makes the outcome legible: the seal stays up long
      // enough to be read before it releases.
      case .hold: .easeInOut(duration: 0.55)
      case .settle: .easeOut(duration: 0.5)
      }
    }

    var ringScale: CGFloat {
      switch self {
      case .rest: 0.9
      case .strike: 1.02
      case .counter: 1.1
      case .hold: 1.12
      case .settle: 1.22
      }
    }

    var ringOpacity: Double {
      switch self {
      case .rest: 0
      case .strike: 0.95
      case .counter: 0.7
      case .hold: 0.6
      case .settle: 0
      }
    }

    var sealScale: CGFloat {
      switch self {
      case .rest: 0.5
      case .strike: 1.2
      case .counter: 1.05
      case .hold: 1.08
      case .settle: 1.35
      }
    }

    var sealOpacity: Double {
      switch self {
      case .rest: 0
      case .strike: 1
      case .counter: 0.95
      case .hold: 0.9
      case .settle: 0
      }
    }

    /// Only the restrained variant moves the panel, and only sideways.
    var nudge: CGFloat {
      switch self {
      case .rest: 0
      case .strike: -8
      case .counter: 5
      case .hold: 0
      case .settle: 0
      }
    }
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var feedback: ResolutionFeedback?
  var cornerRadius: CGFloat

  /// A stand-in so the view keeps one identity whether or not a resolution has
  /// been made yet. Count zero never fires the trigger.
  private static let idle = ResolutionFeedback(choice: .approve, count: 0)

  func body(content: Content) -> some View {
    let resolved = feedback ?? Self.idle
    if reduceMotion {
      content.overlay { staticMark(resolved) }
    } else {
      content.phaseAnimator(Phase.allCases, trigger: resolved.count) { view, phase in
        view
          .offset(x: resolved.kind == .restrained ? phase.nudge : 0)
          .overlay { ring(resolved, phase: phase) }
          .overlay { seal(resolved, phase: phase) }
      } animation: { phase in
        phase.animation
      }
    }
  }

  private func ring(_ feedback: ResolutionFeedback, phase: Phase) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .strokeBorder(feedback.kind.accent, lineWidth: feedback.kind == .positive ? 4 : 2)
      .scaleEffect(feedback.kind == .positive ? phase.ringScale : 1)
      .opacity(phase.ringOpacity)
      .allowsHitTesting(false)
  }

  @ViewBuilder private func seal(_ feedback: ResolutionFeedback, phase: Phase) -> some View {
    if feedback.kind == .positive {
      Image(systemName: feedback.symbol)
        .font(.system(size: 78, weight: .bold))
        .foregroundStyle(feedback.kind.accent)
        .scaleEffect(phase.sealScale)
        .opacity(phase.sealOpacity)
        .shadow(color: feedback.kind.accent.opacity(0.6), radius: 20)
        .allowsHitTesting(false)
    }
  }

  /// With Reduce Motion on, the outcome is still marked — it just does not move.
  @ViewBuilder private func staticMark(_ feedback: ResolutionFeedback) -> some View {
    if feedback.count > 0 {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(feedback.kind.accent, lineWidth: 2)
        .allowsHitTesting(false)
    }
  }
}

extension View {
  /// Plays the founder's resolution feedback over this view. Passing `nil`
  /// leaves the view untouched.
  func resolutionFeedback(_ feedback: ResolutionFeedback?, cornerRadius: CGFloat = 20) -> some View {
    modifier(ResolutionFeedbackModifier(feedback: feedback, cornerRadius: cornerRadius))
  }
}
