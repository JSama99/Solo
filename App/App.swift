import SwiftUI

@main
struct SoloUnicornRunApp: App {
  @State private var subscriptions = SubscriptionStore.shared
  @State private var progression = FounderProgressionStore()
  @State private var achievements = AchievementStore()

  init() {
    SubscriptionStore.shared.configure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(subscriptions)
        .environment(progression)
        .environment(achievements)
        .preferredColorScheme(.dark)
    }
  }
}
