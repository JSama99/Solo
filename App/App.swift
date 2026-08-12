import SwiftUI

@main
struct SoloUnicornRunApp: App {
  @State private var subscriptions = SubscriptionStore.shared
  @State private var progression = FounderProgressionStore()
  @State private var achievements = AchievementStore()
  @State private var settings = AppSettingsStore()

  init() {
    SubscriptionStore.shared.configure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(subscriptions)
        .environment(progression)
        .environment(achievements)
        .environment(settings)
        .preferredColorScheme(.dark)
    }
  }
}
