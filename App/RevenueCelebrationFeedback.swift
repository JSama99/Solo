import AudioToolbox
import UIKit

enum RevenueCelebrationFeedback {
  /// A brief, original confirmation using the system’s standard positive tone.
  static func play() {
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(.success)
    AudioServicesPlaySystemSound(1104)
  }
}
