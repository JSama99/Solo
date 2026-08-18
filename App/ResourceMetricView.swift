import SwiftUI

/// A single HUD resource that answers "what just changed, and which way?"
/// without the founder having to remember the previous number.
///
/// The tile rolls its digits, flashes its tint, and floats a signed delta chip
/// for a moment before settling back to normal. Direction is carried by an
/// arrow as well as a colour, so the meaning never depends on hue alone.
struct ResourceMetricView: View {
  /// How the raw simulation integer is written for a player.
  enum Format {
    case plain
    case days
    case currency

    func string(_ value: Int) -> String {
      switch self {
      case .plain: "\(value)"
      case .days: "\(value)d"
      case .currency: Self.currencyString(value)
      }
    }

    static func currencyString(_ value: Int) -> String {
      let magnitude = abs(value)
      let sign = value < 0 ? "-" : ""
      if magnitude >= 10_000 { return "\(sign)$\(magnitude / 1_000)k" }
      if magnitude >= 1_000 {
        return String(format: "%@$%.1fk", sign, Double(magnitude) / 1_000)
      }
      return "\(sign)$\(magnitude)"
    }
  }

  /// How long a change stays emphasized before the tile returns to rest.
  static let emphasisDuration: Duration = .milliseconds(1_500)

  var label: String
  var value: Int
  var maximum: Int?
  var symbol: String
  var format: Format = .plain

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var delta: Int?
  @State private var emphasized = false
  @State private var settleTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 4) {
        Image(systemName: symbol)
          .font(.caption2)
          .foregroundStyle(emphasized ? emphasisColor : SoloTheme.cyan)
          .symbolEffect(.bounce, value: delta)
        HStack(spacing: 0) {
          Text(format.string(value))
            .contentTransition(.numericText(value: Double(value)))
          if let maximum {
            Text("/\(maximum)").foregroundStyle(.secondary)
          }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(emphasized ? AnyShapeStyle(emphasisColor) : AnyShapeStyle(.primary))
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(emphasisColor.opacity(emphasized ? 0.2 : 0), in: .rect(cornerRadius: 10))
    .scaleEffect(emphasized ? 1.07 : 1, anchor: .leading)
    .overlay(alignment: .topTrailing) { deltaChip }
    .gameplayMotion(.emphasis, value: value)
    .gameplayMotion(.celebration, value: emphasized)
    .onChange(of: value) { previous, current in
      register(change: current - previous)
    }
    .onDisappear { settleTask?.cancel() }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  // ── Delta presentation ──────────────────────────────────────────────

  @ViewBuilder private var deltaChip: some View {
    if let delta, delta != 0 {
      Label {
        Text(delta > 0 ? "+\(delta)" : "\(delta)")
      } icon: {
        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
      }
      .font(.caption2.weight(.heavy))
      .labelStyle(.titleAndIcon)
      .foregroundStyle(emphasisColor)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(emphasisColor.opacity(0.18), in: .capsule)
      .offset(y: -12)
      .transition(
        .asymmetric(
          insertion: .scale(scale: 0.5).combined(with: .opacity),
          removal: .offset(y: -10).combined(with: .opacity)
        )
      )
      .allowsHitTesting(false)
    }
  }

  private var emphasisColor: Color {
    guard let delta, delta != 0 else { return SoloTheme.cyan }
    return delta > 0 ? SoloTheme.mint : SoloTheme.coral
  }

  private var accessibilityLabel: String {
    var text = maximum.map { "\(label), \(value) of \($0)" } ?? "\(label), \(format.string(value))"
    if let delta, delta != 0 {
      text += delta > 0 ? ", up \(delta)" : ", down \(abs(delta))"
    }
    return text
  }

  /// Emphasizes a change, then schedules the tile's return to rest. A change
  /// that arrives during the emphasis window replaces it rather than queueing.
  private func register(change: Int) {
    guard change != 0 else { return }
    settleTask?.cancel()
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      delta = change
      emphasized = true
    }
    settleTask = Task { @MainActor in
      try? await Task.sleep(for: Self.emphasisDuration)
      guard !Task.isCancelled else { return }
      withAnimation(MotionKind.state.resolved(reduceMotion: reduceMotion)) {
        delta = nil
        emphasized = false
      }
    }
  }
}
