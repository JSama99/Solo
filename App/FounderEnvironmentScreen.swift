import SwiftUI

struct FounderEnvironmentScreen: View {
  var store: GameStore
  var presentation: PresentationCoordinator

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          if progression.currentFacility == .founderLoft, #available(iOS 18.0, *) {
            FounderLoftEnvironment()
          } else {
            GarageVisualization(
              stations: stationModels,
              policy: presentationPolicy,
              facility: progression.currentFacility,
              stats: store.stats,
              attentionRemaining: store.attentionRemaining,
              attentionMaximum: store.attentionMaximum,
              store: store,
              progression: progression,
              presentation: presentation
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
