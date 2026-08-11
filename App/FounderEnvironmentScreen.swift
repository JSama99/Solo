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
          if progression.currentFacility == .founderLoft, #available(iOS 18.0, *) {
            FounderLoftEnvironment()
          } else {
            GarageVisualization(
              stations: stationModels,
              policy: presentationPolicy,
              facility: progression.currentFacility,
              stats: store.stats,
              attentionRemaining: store.attentionRemaining,
              attentionMaximum: store.attentionMaximum
            )
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("SOLO")
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

}
