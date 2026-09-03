import AudioToolbox
import SwiftUI
import UIKit

enum RevenueCelebrationFeedback {
  /// A brief, original confirmation using the system’s standard positive tone.
  static func play(isEnabled: Bool = true) {
    guard isEnabled else { return }
#if targetEnvironment(simulator)
    AudioServicesPlaySystemSound(1104)
#else
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(.success)
    AudioServicesPlaySystemSound(1104)
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
