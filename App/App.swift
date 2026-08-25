import SwiftUI

@main
struct SoloUnicornRunApp: App {
  @State private var subscriptions = SubscriptionStore.shared
  @State private var progression = FounderProgressionStore()
  @State private var achievements = AchievementStore()
  @State private var settings = AppSettingsStore()

  private var isMotionQA: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("--motion-qa")
      || ProcessInfo.processInfo.arguments.contains("--motion-qa-physical")
      || ProcessInfo.processInfo.environment["SOLO_MOTION_QA_FIXTURE"] != nil
      || ProcessInfo.processInfo.environment["SOLO_MOTION_QA_SEQUENCE"] == "1"
    #else
    false
    #endif
  }

  init() {
    #if DEBUG
    if !ProcessInfo.processInfo.arguments.contains("--motion-qa") {
      SubscriptionStore.shared.configure()
    }
    #else
    SubscriptionStore.shared.configure()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      Group {
        #if DEBUG
        if isMotionQA {
          MotionVerificationScreen(initialFixture: motionQAFixture)
        } else {
          ContentView()
        }
        #else
        ContentView()
        #endif
      }
        .environment(subscriptions)
        .environment(progression)
        .environment(achievements)
        .environment(settings)
        .preferredColorScheme(.dark)
    }
  }

  #if DEBUG
  private var motionQAFixture: LivingCompanyFixture.ID {
    if let rawValue = ProcessInfo.processInfo.environment["SOLO_MOTION_QA_FIXTURE"],
       let fixture = LivingCompanyFixture.ID(rawValue: rawValue) {
      return fixture
    }
    if ProcessInfo.processInfo.arguments.contains("--motion-qa-command-focus-proof") {
      return .planningPhase
    }
    if ProcessInfo.processInfo.arguments.contains("--motion-qa-sequence")
      || ProcessInfo.processInfo.environment["SOLO_MOTION_QA_SEQUENCE"] == "1" {
      return .planningPhase
    }
    return .idleOverview
  }
  #endif
}
