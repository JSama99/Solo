import SwiftUI

@main
struct SoloUnicornRunApp: App {
  @State private var subscriptions = SubscriptionStore.shared
  @State private var progression = FounderProgressionStore()

  init() {
    SubscriptionStore.shared.configure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(subscriptions)
        .environment(progression)
        .preferredColorScheme(.dark)
    }
  }
}
