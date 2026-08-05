import Foundation

enum ApplicationActivity: Equatable {
  case active
  case inactive
  case background
}

struct PresentationPolicy: Equatable {
  var reduceMotion: Bool
  var applicationActivity: ApplicationActivity

  var allowsAmbientMotion: Bool {
    !reduceMotion && applicationActivity == .active
  }

  var stagesResults: Bool {
    !reduceMotion && applicationActivity == .active
  }
}
