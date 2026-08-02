import SwiftUI

@main
struct SoloUnicornRunApp: App {
  @State private var subscriptions = SubscriptionStore.shared

  init() {
    SubscriptionStore.shared.configure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(subscriptions)
        .preferredColorScheme(.dark)
    }
  }
}
