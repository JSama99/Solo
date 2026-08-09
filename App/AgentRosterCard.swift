import SwiftUI

struct AgentRosterCard: View {
  var agent: AgentDetailViewModel

  var body: some View {
    HStack(spacing: 12) {
      Text(agent.initials)
        .font(.caption.weight(.black))
        .frame(width: 44, height: 44)
        .background(SoloTheme.purple.gradient, in: .circle)
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(agent.name).font(.headline)
          Text(agent.role.rawValue).font(.caption).foregroundStyle(.secondary)
        }
        Text(agent.modelFamily)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Label(agent.status, systemImage: agent.statusGlyph)
          .font(.caption.weight(.semibold))
          .foregroundStyle(statusColor)
          .contentTransition(.opacity)
          .animation(.smooth(duration: 0.2), value: agent.status)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text("Trust")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text("\(Int(agent.trust.rounded()))")
          .font(.headline.monospacedDigit())
          .foregroundStyle(trustColor)
          .contentTransition(.numericText(value: agent.trust))
          .animation(.snappy, value: agent.trust)
        Capsule()
          .fill(trustColor.opacity(0.28))
          .frame(width: 54, height: 4)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(trustColor)
              .frame(width: max(3, 54 * CGFloat(agent.trust / 100)), height: 4)
              .animation(.snappy, value: agent.trust)
          }
      }
    }
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(agent.name), \(agent.role.rawValue) agent")
    .accessibilityValue("\(agent.status). Trust \(Int(agent.trust.rounded())). \(agent.taskTitle ?? "No task assigned")")
  }

  private var trustColor: Color {
    switch agent.trustBand {
    case .teal: SoloTheme.mint
    case .amber: SoloTheme.amber
    case .coral: SoloTheme.coral
    }
  }

  private var statusColor: Color {
    agent.status == "Verified" ? SoloTheme.mint : SoloTheme.cyan
  }
}
