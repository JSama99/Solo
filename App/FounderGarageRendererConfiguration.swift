import Foundation

enum FounderGarageRenderer: String, Equatable, Sendable {
  case swiftUI
  case realityKitPrototype
}

/// Development-only selection for the physical Garage renderer. The value is
/// resolved from process configuration and is never written to player state.
struct FounderGarageRendererConfiguration {
  static let prototypeLaunchArgument = "--founder-garage-realitykit"
  static let prototypeEnvironmentKey = "SOLO_FOUNDER_GARAGE_RENDERER"

  static var active: FounderGarageRenderer {
    #if DEBUG
    resolve(
      arguments: ProcessInfo.processInfo.arguments,
      environment: ProcessInfo.processInfo.environment,
      prototypeAllowed: true
    )
    #else
    .swiftUI
    #endif
  }

  static func resolve(
    arguments: [String],
    environment: [String: String],
    prototypeAllowed: Bool
  ) -> FounderGarageRenderer {
    guard prototypeAllowed else { return .swiftUI }
    if arguments.contains(prototypeLaunchArgument)
      || environment[prototypeEnvironmentKey]?.lowercased() == "realitykit" {
      return .realityKitPrototype
    }
    return .swiftUI
  }
}
