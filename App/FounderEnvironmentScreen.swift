import SwiftUI

struct FounderEnvironmentScreen: View {
  var store: GameStore

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          environmentHeader
          GarageVisualization(stations: stationModels, policy: presentationPolicy)
          operationsSummary
          agentStatusList
          NavigationLink {
            HeadquartersProgressScreen(store: store)
          } label: {
            headquartersProgressLink
          }
          .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("SOLO")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Text(store.stats.capital, format: .currency(code: "USD").precision(.fractionLength(0)))
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(SoloTheme.mint)
            .contentTransition(.numericText())
            .animation(.snappy, value: store.stats.capital)
            .accessibilityLabel("Capital")
        }
      }
      .onChange(of: store.stats.trackRecord, initial: true) { _, value in
        progression.observe(trackRecord: value)
      }
    }
  }

  private var presentationPolicy: PresentationPolicy {
    let activity: ApplicationActivity
    switch scenePhase {
    case .active: activity = .active
    case .inactive: activity = .inactive
    case .background: activity = .background
    @unknown default: activity = .inactive
    }
    return PresentationPolicy(
      reduceMotion: reduceMotion,
      applicationActivity: activity
    )
  }

  private var environmentHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(progression.currentFacility.name)
          .font(.headline)
        Text("Venture \(store.venture) • \(store.chapter.name) • Sprint \(store.sprint)/12")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Label(store.garageCondition, systemImage: "waveform.path.ecg")
        .font(.caption.weight(.bold))
        .foregroundStyle(store.garageCondition == "Steady" ? SoloTheme.mint : SoloTheme.amber)
    }
  }

  private var stationModels: [AgentStationViewModel] {
    store.agents.map { agent in
      AgentStationViewModel.derive(
        agent: agent,
        task: store.tasks.first(where: { $0.assignedAgentID == agent.id }),
        founderStats: store.stats
      )
    }
  }

  private var operationsSummary: some View {
    HStack {
      Label("\(store.intent.name) intent", systemImage: store.intent.symbol)
        .font(.subheadline.weight(.bold))
      Spacer()
      Text("Mean drift \(store.averageDrift)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 4)
  }

  private var agentStatusList: some View {
    VStack(spacing: 10) {
      ForEach(store.agents) { agent in
        EnvironmentAgentRow(
          agent: agent,
          dialogue: store.agentDialogue(for: agent.id),
          state: AgentVisualState.derive(
            agent: agent,
            task: store.tasks.first(where: { $0.assignedAgentID == agent.id }),
            founderStats: store.stats
          )
        )
      }
    }
  }

  private var headquartersProgressLink: some View {
    HStack(spacing: 12) {
      Image(systemName: "building.2.fill")
        .foregroundStyle(SoloTheme.cyan)
        .frame(width: 42, height: 42)
        .background(SoloTheme.cyan.opacity(0.12), in: .rect(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 3) {
        Text("Headquarters Progress").font(.headline)
        Text("\(progression.purchasedUpgrades.count) infrastructure upgrades owned • \(progression.currentFacility.name) active")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
    }
    .soloCard()
  }
}


private struct EnvironmentAgentRow: View {
  var agent: SoloAgent
  var dialogue: String
  var state: AgentVisualState

  var body: some View {
    HStack(spacing: 12) {
      Text(agent.initials)
        .font(.caption.weight(.black))
        .frame(width: 44, height: 44)
        .background(markerColor.gradient, in: .circle)
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(agent.name).font(.headline)
          Text(agent.role.rawValue).font(.caption).foregroundStyle(.secondary)
        }
        Text(state.accessibilityValue)
          .font(.caption)
          .foregroundStyle(markerColor)
          .lineLimit(1)
        Text("“\(dialogue)”")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Image(systemName: statusSymbol)
        .foregroundStyle(markerColor)
        .accessibilityHidden(true)
    }
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(agent.name), \(agent.role.rawValue) agent")
    .accessibilityValue("\(state.accessibilityValue). \(dialogue)")
  }

  private var markerColor: Color {
    if state.warnings.contains(.overloaded) { return SoloTheme.amber }
    switch state.verification {
    case .verified, .confirmed: return SoloTheme.mint
    case .overclaiming, .driftDetected, .evidenceIncomplete: return SoloTheme.amber
    case .none: return state.activity == .idle ? .secondary : SoloTheme.cyan
    }
  }

  private var statusSymbol: String {
    switch state.verification {
    case .verified, .confirmed: "checkmark.seal.fill"
    case .overclaiming: "exclamationmark.triangle.fill"
    case .driftDetected: "waveform.badge.exclamationmark"
    case .evidenceIncomplete: "doc.badge.ellipsis"
    case .none: state.activity == .idle ? "pause.fill" : "gearshape.2.fill"
    }
  }
}

private struct AgentStationViewModel: Identifiable {
  var agent: SoloAgent
  var task: SoloTask?
  var state: AgentVisualState

  var id: String { agent.id }

  static func derive(agent: SoloAgent, task: SoloTask?, founderStats: FounderStats) -> Self {
    Self(agent: agent, task: task, state: AgentVisualState.derive(agent: agent, task: task, founderStats: founderStats))
  }
}

/// A lightweight, motion-aware headquarters overview. The Command Deck retains
/// the interactive task and review controls, so this visual is never the only
/// way to operate the company.
private struct GarageVisualization: View {
  var stations: [AgentStationViewModel]
  var policy: PresentationPolicy

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("LIVE WORKSTATIONS", systemImage: "rectangle.3.group.fill")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        Text(policy.applicationActivity == .active ? "Operating" : "Paused")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 10) {
        ForEach(stations) { station in
          VStack(alignment: .leading, spacing: 6) {
            Image(systemName: station.agent.role.symbol)
              .font(.title2)
              .foregroundStyle(color(for: station))
            Text(station.agent.name).font(.caption.weight(.bold))
            Text(station.task?.title ?? "Ready")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
          .padding(12)
          .background(SoloTheme.background.opacity(0.65), in: .rect(cornerRadius: 14))
          .overlay { RoundedRectangle(cornerRadius: 14).stroke(color(for: station).opacity(0.35)) }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("\(station.agent.name) workstation")
          .accessibilityValue(station.state.accessibilityValue)
        }
      }
    }
    .soloCard()
  }

  private func color(for station: AgentStationViewModel) -> Color {
    if station.state.warnings.contains(.overloaded) { return SoloTheme.amber }
    return station.state.activity == .idle ? .secondary : SoloTheme.cyan
  }
}
