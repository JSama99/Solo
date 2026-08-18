import SwiftUI

/// The Founder Review surface.
///
/// It enters rather than appears, sits above the rest of the screen on a
/// shadow, and reveals the founder's choices in sequence so the decision reads
/// as a moment rather than as a form. It renders only what the review already
/// revealed — it never asks the simulation anything new.
struct FounderResolutionPanel: View {
  var task: SoloTask
  var agentName: String
  var accent: Color
  var attentionRemaining: Int
  var onResolve: (TaskResolutionChoice) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header.milestoneReveal(order: 0)
      VStack(alignment: .leading, spacing: 3) {
        Text(task.title).font(.headline)
        Text("\(agentName) · Attention \(attentionRemaining) remaining")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .milestoneReveal(order: 1)
      if let result = task.result {
        verdict(result).milestoneReveal(order: 2)
      }
      VStack(spacing: 8) {
        ForEach(Array(TaskResolutionChoice.allCases.enumerated()), id: \.element) { index, choice in
          Button {
            onResolve(choice)
          } label: {
            Label {
              VStack(alignment: .leading, spacing: 1) {
                Text(choice.title).font(.subheadline.weight(.bold))
                Text(choice.summary).font(.caption2).opacity(0.8)
              }
            } icon: {
              Image(systemName: choice.symbol)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(ResolutionButtonStyle(accent: tint(for: choice), prominent: choice == .approve))
          .accessibilityHint(choice.summary)
          .milestoneReveal(order: 3 + index)
        }
      }
      Text("Rework: 1 Attention, 4 Energy, 1 Runway. Cross-Check: 1 Attention and an independent model family.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .milestoneReveal(order: 3 + TaskResolutionChoice.allCases.count)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SoloTheme.card, in: .rect(cornerRadius: 20))
    .background(SoloTheme.background.opacity(0.9), in: .rect(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.5), lineWidth: 1.5)
    }
    .shadow(color: accent.opacity(0.35), radius: 26, y: 14)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder review for \(task.title)")
  }

  private var header: some View {
    HStack {
      Label("FOUNDER REVIEW", systemImage: "checkmark.shield.fill")
        .font(.caption.weight(.black))
        .foregroundStyle(accent)
        .symbolEffect(.bounce, value: task.id)
      Spacer()
      Text("Decision required")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private func verdict(_ result: TaskResult) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 3) {
        Text("Reported quality ")
        Text(String(result.reportedQuality))
          .contentTransition(.numericText(value: Double(result.reportedQuality)))
        Text(" · Evidence \(result.evidenceCompleteness)%")
      }
      .font(.caption.weight(.semibold))
      Text(result.verificationState.label)
        .font(.caption)
        .foregroundStyle(SoloTheme.mint)
      if let actual = result.revealedActualQuality {
        Text(
          result.overclaimAmount > 0
            ? "Verified actual \(actual) · Overclaim +\(result.overclaimAmount)"
            : "Verified actual \(actual)"
        )
        .font(.caption)
      }
      Text(result.knownOperationalRisk)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.black.opacity(0.2), in: .rect(cornerRadius: 12))
  }

  private func tint(for choice: TaskResolutionChoice) -> Color {
    switch choice {
    case .approve: SoloTheme.mint
    case .rework: SoloTheme.amber
    case .shipAnyway: SoloTheme.coral
    case .escalate: SoloTheme.cyan
    }
  }
}

/// A press style for the founder's four resolutions. The compression is the
/// same one the agent cards use, so every founder decision feels alike.
private struct ResolutionButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var accent: Color
  var prominent: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .foregroundStyle(prominent ? AnyShapeStyle(Color.black) : AnyShapeStyle(accent))
      .background(accent.opacity(prominent ? 0.92 : 0.16), in: .rect(cornerRadius: 13))
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion), value: configuration.isPressed)
  }
}
