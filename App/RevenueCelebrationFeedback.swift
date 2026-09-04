import SwiftUI
import UIKit

enum RevenueCelebrationFeedback {
  static func shouldPlay(isEnabled: Bool, audioContext: AppAudioContext) -> Bool {
    isEnabled && audioContext != .background
  }

  /// Routes audible confirmation through the canonical app audio engine while
  /// retaining device-only success haptics as a bounded sensory enhancement.
  @MainActor
  static func play(settings: AppSettingsStore) {
    guard shouldPlay(
      isEnabled: settings.soundEffectsEnabled,
      audioContext: settings.audioContext
    ) else { return }
    settings.playFeedback(.revenueCelebration)
#if !targetEnvironment(simulator)
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(.success)
#endif
  }
}

extension View {
  @ViewBuilder
  func appSensoryFeedback<Value: Equatable>(_ feedback: SensoryFeedback, trigger: Value) -> some View {
#if targetEnvironment(simulator)
    self
#else
    sensoryFeedback(feedback, trigger: trigger)
#endif
  }
}
