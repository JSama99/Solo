import SwiftUI

struct FounderEnvironmentScreen: View {
  var store: GameStore
  var presentation: PresentationCoordinator

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      FounderComputerScreen(store: store, presentation: presentation)
      .navigationTitle("SOLO")
      .onChange(of: store.stats.trackRecord, initial: true) { _, value in
        progression.observe(trackRecord: value)
      }
    }
  }

}
