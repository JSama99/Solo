import SwiftUI

struct HUDMetricView: View {
  var label: String
  var value: Int
  var maximum: Int?
  var unit: String
  var symbol: String

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var delta = 0

  init(label: String, value: Int, maximum: Int? = nil, unit: String = "", symbol: String) {
    self.label = label
    self.value = value
    self.maximum = maximum
    self.unit = unit
    self.symbol = symbol
  }

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 1) {
          Text("\(value)")
            .contentTransition(.numericText(value: Double(value)))
          if let maximum { Text("/\(maximum)") } else if !unit.isEmpty { Text(unit) }
          if delta != 0 {
            Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
              .font(.system(size: 8, weight: .black))
              .foregroundStyle(delta > 0 ? SoloTheme.mint : SoloTheme.coral)
              .transition(.scale.combined(with: .opacity))
          }
        }
        .font(.subheadline.weight(.bold))
        Text(label).font(.caption2).foregroundStyle(.secondary)
      }
    } icon: {
      Image(systemName: symbol)
        .foregroundStyle(SoloTheme.cyan)
        .symbolEffect(.bounce, value: value)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 5)
    .padding(.horizontal, 4)
    .phaseAnimator([0, 1, 2], trigger: value) { content, phase in
      content
        .scaleEffect(!reduceMotion && phase == 1 ? 1.12 : 1)
        .background(SoloTheme.cyan.opacity(!reduceMotion && phase == 1 ? 0.2 : 0), in: Capsule())
        .overlay { Capsule().stroke(SoloTheme.cyan.opacity(!reduceMotion && phase == 1 ? 0.75 : 0), lineWidth: 1.5) }
    } animation: { phase in
      phase == 1 ? .snappy(duration: 0.18) : .smooth(duration: 0.24)
    }
    .onChange(of: value) { oldValue, newValue in delta = newValue - oldValue }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(maximum.map { "\(label), \(value) of \($0)" } ?? "\(label), \(value)\(unit)")
  }
}

struct EvidenceDrawerView: View {
  var evidence: [EvidenceEntry]
  @Binding var isExpanded: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var arrivalDelta = 0

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(evidence.prefix(8)) { entry in
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.task).font(.subheadline.weight(.semibold))
            Text("\(entry.agent) · \(entry.verdict) · Evidence \(entry.evidenceCompleteness)%")
              .font(.caption).foregroundStyle(.secondary)
            Text(entry.note).font(.caption2).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .padding(.top, 8)
    } label: {
      HStack(spacing: 7) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(SoloTheme.cyan)
          .symbolEffect(.bounce, value: evidence.count)
        Text("Evidence ·")
        Text("\(evidence.count)")
          .fontWeight(.bold)
          .contentTransition(.numericText(value: Double(evidence.count)))
        if arrivalDelta > 0 {
          Text("+\(arrivalDelta) Evidence")
            .font(.caption2.weight(.black))
            .foregroundStyle(SoloTheme.mint)
            .phaseAnimator([0, 1, 2], trigger: evidence.count) { content, phase in
              content
                .offset(y: !reduceMotion && phase == 1 ? -14 : 0)
                .opacity(!reduceMotion && phase == 2 ? 0 : 1)
            } animation: { phase in
              phase == 1 ? .snappy(duration: 0.2) : .smooth(duration: 0.25)
            }
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Evidence ledger, \(evidence.count) entries")
    }
    .accessibilityIdentifier("founder-computer-evidence")
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .phaseAnimator([0, 1, 2], trigger: evidence.count) { content, phase in
      content
        .scaleEffect(!reduceMotion && phase == 1 ? 1.035 : 1)
        .overlay {
          RoundedRectangle(cornerRadius: 18)
            .stroke(SoloTheme.mint.opacity(!reduceMotion && phase == 1 ? 0.9 : 0), lineWidth: 2)
        }
        .shadow(color: SoloTheme.cyan.opacity(!reduceMotion && phase == 1 ? 0.42 : 0), radius: 13)
    } animation: { phase in
      phase == 1 ? .snappy(duration: 0.2) : .smooth(duration: 0.25)
    }
    .gameplayMotion(.emphasis, value: isExpanded)
    .onChange(of: evidence.count) { oldCount, newCount in
      arrivalDelta = max(0, newCount - oldCount)
    }
  }
}

struct VerificationImpact: View {
  var state: VerificationState
  var active: Bool
  var reduceMotion: Bool

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        Text("VERIFICATION STATE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        Text(state.label).font(.caption.weight(.black))
      }
    } icon: {
      ZStack {
        Circle()
          .stroke(SoloTheme.mint.opacity(0.55), lineWidth: 2)
          .frame(width: 30, height: 30)
          .phaseAnimator([0, 1, 2], trigger: active) { content, phase in
            content
              .scaleEffect(!reduceMotion && phase == 1 ? 1.85 : 0.8)
              .opacity(!reduceMotion && phase == 1 ? 0 : 0.65)
          } animation: { _ in .smooth(duration: 0.42) }
        Image(systemName: verificationSymbol)
          .foregroundStyle(impactColor)
          .phaseAnimator([0, 1, 2], trigger: active) { content, phase in
            content.scaleEffect(!reduceMotion ? (phase == 0 ? 0.6 : phase == 1 ? 1.12 : 1) : 1)
          } animation: { phase in phase == 1 ? .bouncy(duration: 0.24) : .smooth(duration: 0.18) }
      }
    }
    .appSensoryFeedback(isSuccess ? .success : .warning, trigger: active)
  }

  private var isSuccess: Bool { state == .confirmed || state == .verified }
  private var impactColor: Color { isSuccess ? SoloTheme.mint : SoloTheme.amber }
  private var verificationSymbol: String { isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill" }
}
