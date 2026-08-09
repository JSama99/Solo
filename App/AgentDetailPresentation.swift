import SwiftUI

struct AgentDetailPresentation: View {
  var agent: AgentDetailViewModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AccessibilityFocusState private var headingFocused: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text(agent.name)
            .font(.title.bold())
            .accessibilityFocused($headingFocused)
          Label(agent.role.rawValue, systemImage: agent.role.symbol)
            .font(.headline)
            .foregroundStyle(.secondary)
          detailRow("Model family", value: agent.modelFamily)
          detailRow("Trust", value: "\(Int(agent.trust.rounded())) • \(agent.trustBand.label)")
          detailRow("Status", value: agent.status, glyph: agent.statusGlyph)
          detailRow("Mood", value: agent.mood)
          detailRow("Current assignment", value: agent.taskTitle ?? "No task assigned")
          TrustDeltaStrip(deltas: agent.recentTrustDeltas, reduceMotion: reduceMotion)
          Label("To reassign work, use Command Deck.", systemImage: "slider.horizontal.3")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Agent Detail")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { headingFocused = true }
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  private func detailRow(_ title: String, value: String, glyph: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      if let glyph {
        Label(value, systemImage: glyph)
          .font(.body.weight(.semibold))
      } else {
        Text(value).font(.body.weight(.semibold))
      }
    }
  }
}

private struct TrustDeltaStrip: View {
  var deltas: [Int]
  var reduceMotion: Bool

  @State private var hasDrawn = false

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Recent trust changes")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      if deltas.isEmpty {
        Text("No per-agent trust history recorded yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        GeometryReader { geometry in
          let path = trustPath(in: geometry.size)
          ZStack(alignment: .leading) {
            path.stroke(SoloTheme.cyan.opacity(0.25), lineWidth: 2)
            path
              .trim(from: 0, to: hasDrawn ? 1 : 0)
              .stroke(SoloTheme.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
          }
        }
        .frame(height: 34)
        .accessibilityLabel("Recent trust changes")
        .accessibilityValue(deltas.map { $0 >= 0 ? "+\($0)" : "\($0)" }.joined(separator: ", "))
      }
    }
    .onAppear {
      guard !hasDrawn else { return }
      if reduceMotion {
        hasDrawn = true
      } else {
        withAnimation(.smooth(duration: 0.45)) { hasDrawn = true }
      }
    }
  }

  private func trustPath(in size: CGSize) -> Path {
    var path = Path()
    let values = deltas.map(Double.init)
    let peak = max(values.map { abs($0) }.max() ?? 1, 1)
    for (index, value) in values.enumerated() {
      let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
      let y = size.height / 2 - CGFloat(value / peak) * (size.height * 0.38)
      if index == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }
    return path
  }
}
