import Foundation

enum FounderGarageRenderer: String, Equatable, Sendable {
  case swiftUI
  case realityKitPrototype
}

/// Presentation-only selection for the physical Garage renderer. RealityKit is
/// the production default; the legacy SwiftUI renderer remains available for
/// bounded fallback verification without touching player state.
struct FounderGarageRendererConfiguration {
  static let prototypeLaunchArgument = "--founder-garage-realitykit"
  static let legacyLaunchArgument = "--founder-garage-legacy"
  static let prototypeEnvironmentKey = "SOLO_FOUNDER_GARAGE_RENDERER"

  static var active: FounderGarageRenderer {
    resolve(
      arguments: ProcessInfo.processInfo.arguments,
      environment: ProcessInfo.processInfo.environment,
      prototypeAllowed: true
    )
  }

  static func resolve(
    arguments: [String],
    environment: [String: String],
    prototypeAllowed: Bool
  ) -> FounderGarageRenderer {
    guard prototypeAllowed else { return .swiftUI }
    if arguments.contains(legacyLaunchArgument)
      || environment[prototypeEnvironmentKey]?.lowercased() == "swiftui" {
      return .swiftUI
    }
    return .realityKitPrototype
  }
}
