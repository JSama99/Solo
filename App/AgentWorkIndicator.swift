import SwiftUI

/// The continuous, restrained activity an agent workspace shows while its work
/// is in flight.
///
/// It reads exactly the same facts the status label reads, so a founder can
/// tell a working desk from an idle one across the room without reading a
/// word. Nothing here consumes simulation randomness — the sweep is a fixed
/// linear cycle, not a roll.
struct AgentWorkIndicator: View {
  /// The card's work state, derived from the assignment itself rather than from
  /// the semantic status label, which folds in stress and drift warnings.
  enum Activity: String, Equatable, CaseIterable {
    /// No assignment this sprint.
    case idle
    /// Recovering; deliberately quiet.
    case resting
    /// Assigned and running; the founder has not reviewed the report yet.
    case working
    /// Reviewed; waiting on the founder's resolution.
    case awaitingDecision
    /// Resolution locked in for this sprint.
    case settled

    /// The work state of an agent given its assignment, ignoring how well or
    /// badly that work is going — that belongs to the status label.
    static func derive(task: SoloTask?, isResting: Bool) -> Self {
      if isResting { return .resting }
      guard let task else { return .idle }
      if task.resolutionLocked { return .settled }
      if task.isReviewed { return .awaitingDecision }
      return .working
    }

    var caption: String {
      switch self {
      case .idle: "Standing by"
      case .resting: "Recovering"
      case .working: "Working"
      case .awaitingDecision: "Awaiting your call"
      case .settled: "Resolved"
      }
    }

    /// Whether this state should show continuous motion.
    var isLive: Bool { self == .working || self == .awaitingDecision }
  }

  var activity: Activity
  var accent: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 7) {
        dots
        Text(activity.caption)
          .font(.caption2.weight(.bold))
          .foregroundStyle(activity.isLive ? accent : .secondary)
          .contentTransition(.opacity)
        Spacer(minLength: 0)
      }
      rail
    }
    .gameplayMotion(.emphasis, value: activity)
    .accessibilityHidden(true)
  }

  // ── Activity dots ───────────────────────────────────────────────────

  @ViewBuilder private var dots: some View {
    if activity == .working, !reduceMotion {
      HStack(spacing: 4) {
        ForEach(0..<3) { index in
          dot(index: index)
        }
      }
    } else {
      HStack(spacing: 4) {
        ForEach(0..<3) { _ in
          Circle()
            .fill(activity.isLive ? accent : Color.white.opacity(0.22))
            .frame(width: 6, height: 6)
        }
      }
    }
  }

  private func dot(index: Int) -> some View {
    Circle()
      .fill(accent)
      .frame(width: 6, height: 6)
      .phaseAnimator([0, 1, 2]) { view, phase in
        view
          .opacity(phase == index ? 1 : 0.25)
          .scaleEffect(phase == index ? 1.45 : 0.9)
      } animation: { _ in
        .easeInOut(duration: 0.28)
      }
  }

  // ── Progress rail ───────────────────────────────────────────────────

  private var rail: some View {
    GeometryReader { geometry in
      Capsule()
        .fill(Color.black.opacity(0.3))
        .overlay(alignment: .leading) { fill(width: geometry.size.width) }
        .clipShape(Capsule())
    }
    .frame(height: 6)
  }

  @ViewBuilder private func fill(width: CGFloat) -> some View {
    switch activity {
    case .idle:
      EmptyView()
    case .resting:
      Capsule().fill(Color.white.opacity(0.16)).frame(width: max(10, width * 0.18))
    case .working:
      sweep(width: width)
    case .awaitingDecision:
      pulse
    case .settled:
      Capsule().fill(accent)
    }
  }

  /// An indeterminate highlight that travels the rail, wrapping off both ends so
  /// the reset is never visible.
  @ViewBuilder private func sweep(width: CGFloat) -> some View {
    let highlightWidth = max(44, width * 0.4)
    let bar = Capsule()
      .fill(
        LinearGradient(
          colors: [accent.opacity(0), accent, accent.opacity(0)],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: highlightWidth)
    if reduceMotion {
      bar
    } else {
      bar.phaseAnimator([0, 1]) { view, phase in
        view.offset(x: phase == 0 ? -highlightWidth : width)
      } animation: { phase in
        phase == 0 ? .linear(duration: 0.01) : .linear(duration: 1.15)
      }
    }
  }

  /// A full rail that breathes, for work that is finished and waiting on the
  /// founder rather than on the agent.
  @ViewBuilder private var pulse: some View {
    let bar = Capsule().fill(accent).frame(maxWidth: .infinity)
    if reduceMotion {
      bar
    } else {
      bar.phaseAnimator([0, 1]) { view, phase in
        view.opacity(phase == 0 ? 0.35 : 1)
      } animation: { _ in
        .easeInOut(duration: 0.62)
      }
    }
  }
}

/// A slow accent glow around a card whose agent is actively working. Paired
/// with `AgentWorkIndicator`, it makes the working state legible from the shape
/// of the card alone.
private struct WorkingGlowModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var isWorking: Bool
  var accent: Color
  var cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content.overlay {
      if isWorking {
        let ring = RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(accent, lineWidth: 2)
          .allowsHitTesting(false)
        if reduceMotion {
          ring.opacity(0.35)
        } else {
          ring.phaseAnimator([0, 1]) { view, phase in
            view.opacity(phase == 0 ? 0.12 : 0.7)
          } animation: { _ in
            .easeInOut(duration: 1.1)
          }
        }
      }
    }
  }
}

extension View {
  /// Breathes an accent ring around a card while its agent is working.
  func workingGlow(isWorking: Bool, accent: Color, cornerRadius: CGFloat) -> some View {
    modifier(WorkingGlowModifier(isWorking: isWorking, accent: accent, cornerRadius: cornerRadius))
  }
}
