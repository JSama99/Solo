import Foundation

/// Body-language states for the physical Founder representation. They are
/// presentation values only and never advance or persist the simulation.
enum FounderPresentationState: String, CaseIterable, Equatable, Sendable {
  case seatedIdle
  case typing
  case reviewing
  case standing
  case walking
  case interacting
  case lowEnergy
  case stressed
}

enum FounderWorldInteraction: Equatable, Sendable {
  case openFounderComputer
}

/// Session-only presentation state for the authored production sectional garage door.
/// It is deliberately excluded from GameStore and career persistence.
enum FounderGarageDoorState: Equatable, Sendable {
  case closed
  case open

  var isOpen: Bool { self == .open }
  var controlTitle: String { isOpen ? "CLOSE DOOR" : "OPEN DOOR" }
  var accessibilityValue: String { isOpen ? "Open" : "Closed" }
}

enum FounderEnvironmentTimeState: String, CaseIterable, Equatable, Sendable {
  case morning
  case day
  case evening
  case night

  var title: String { rawValue.capitalized }
  var accessibilityLabel: String { "\(title) Environment" }
}

struct FounderEnvironmentLightingPreset: Equatable, Sendable {
  let directionalPosition: SIMD3<Float>
  let directionalTarget: SIMD3<Float>
  var environmentIntensityExponent: Float = -1
  let directionalIntensity: Float
  let directionalColor: SIMD3<Float>
  let generalFillIntensity: Float
  let generalFillColor: SIMD3<Float>
  let hangingPracticalIntensity: Float
  let deskPracticalIntensity: Float
  var exteriorPracticalIntensity: Float = 0
  let practicalColor: SIMD3<Float>
  let backgroundTop: SIMD3<Float>
  let backgroundBottom: SIMD3<Float>
}

enum FounderEnvironmentLightingConfiguration {
  static let defaultState = FounderEnvironmentTimeState.day
  // Base authored world + this bounded preset. A future weather layer can compose
  // a resolved preset here without changing state ownership or scene construction.
  static let exteriorFixtureLensName = "ExteriorLight_01_Lens"
  static let exteriorFixtureOffset: SIMD3<Float> = [0, 0, 0.035]
  static let exteriorPracticalRadius: Float = 5

  static func preset(for state: FounderEnvironmentTimeState) -> FounderEnvironmentLightingPreset {
    switch state {
    case .morning:
      FounderEnvironmentLightingPreset(
        directionalPosition: [-5.8, 4.6, 10.5], directionalTarget: [0, 0.65, 1.1],
        environmentIntensityExponent: -1.5,
        directionalIntensity: 4_300, directionalColor: [1.00, 0.82, 0.65],
        generalFillIntensity: 650, generalFillColor: [0.72, 0.83, 1.00],
        hangingPracticalIntensity: 3_000, deskPracticalIntensity: 1_400,
        practicalColor: [1.00, 0.78, 0.56],
        backgroundTop: [0.22, 0.38, 0.58], backgroundBottom: [0.78, 0.57, 0.38]
      )
    case .day:
      FounderEnvironmentLightingPreset(
        directionalPosition: [-2.6, 7.2, 9.8], directionalTarget: [0, 0.55, 1.0],
        environmentIntensityExponent: -1,
        directionalIntensity: 5_600, directionalColor: [1.00, 0.96, 0.90],
        generalFillIntensity: 450, generalFillColor: [0.79, 0.88, 1.00],
        hangingPracticalIntensity: 2_000, deskPracticalIntensity: 1_000,
        practicalColor: [1.00, 0.80, 0.60],
        backgroundTop: [0.20, 0.50, 0.78], backgroundBottom: [0.66, 0.82, 0.94]
      )
    case .evening:
      FounderEnvironmentLightingPreset(
        directionalPosition: [7.5, 3.2, 10.8], directionalTarget: [0, 0.60, 1.0],
        environmentIntensityExponent: -3.5,
        directionalIntensity: 2_700, directionalColor: [1.00, 0.62, 0.38],
        generalFillIntensity: 5_000, generalFillColor: [1.00, 0.85, 0.72],
        hangingPracticalIntensity: 8_000, deskPracticalIntensity: 3_500,
        exteriorPracticalIntensity: 1_200,
        practicalColor: [1.00, 0.75, 0.48],
        backgroundTop: [0.14, 0.18, 0.36], backgroundBottom: [0.66, 0.30, 0.22]
      )
    case .night:
      FounderEnvironmentLightingPreset(
        directionalPosition: [-6.0, 6.5, 9.5], directionalTarget: [0, 0.70, 1.0],
        environmentIntensityExponent: -5,
        directionalIntensity: 850, directionalColor: [0.46, 0.58, 0.86],
        generalFillIntensity: 10_000, generalFillColor: [1.00, 0.82, 0.65],
        hangingPracticalIntensity: 12_000, deskPracticalIntensity: 5_000,
        exteriorPracticalIntensity: 3_000,
        practicalColor: [1, 0.72, 0.42],
        backgroundTop: [0.015, 0.025, 0.070], backgroundBottom: [0.035, 0.065, 0.130]
      )
    }
  }
}

enum FounderGarageAccessibilityID {
  static let founderComputer = "founderGarage.realityKit.founderComputer"
  static let garageDoorToggle = "founderGarage.realityKit.garageDoor.toggle"
  static let environmentTimeMenu = "founderGarage.environment.timeMenu"

  static func environmentTime(_ state: FounderEnvironmentTimeState) -> String {
    "founderGarage.environment.time.\(state.rawValue)"
  }
}

struct FounderWorldInteractionAdapter {
  static let founderComputerEntityName = "FounderComputer.InteractionTarget"
  static let founderComputerAccessibilityLabel = "Founder Computer"
  static let founderComputerAccessibilityHint = "Opens Company Command on the Founder Computer."

  static func interaction(forEntityNamed name: String) -> FounderWorldInteraction? {
    name == founderComputerEntityName ? .openFounderComputer : nil
  }
}

/// Read-only values consumed by the RealityKit Garage. This deliberately
/// excludes task results, review truth, RNG, persistence, and mutation APIs.
struct FounderWorldPresentationModel: Equatable, Sendable {
  var cameraState: FounderGarageCameraState = .founderPOV
  var founderState: FounderPresentationState
  var facility: FacilityTier
  var operatingPeriod: OperatingCalendar.Period
  var activeWorkCount: Int
  var reviewAttentionCount: Int
  var energyLevel: Double
  var roomLightIntensity: Double
  var computerGlowIntensity: Double
  var founderComputerAvailable: Bool
  var statusLabel: String

  @MainActor
  static func derive(
    store: GameStore,
    progression: FounderProgressionStore,
    presentation: PresentationCoordinator
  ) -> Self {
    let founderSummary = CompanyCommandFounderSummary.derive(
      store: store,
      presentation: presentation
    )
    let atmosphere = CompanyAtmosphere.derive(
      stats: store.stats,
      facility: progression.currentFacility,
      venture: store.venture
    )

    let founderState: FounderPresentationState
    if founderSummary.reviewCount > 0 || founderSummary.resolutionCount > 0 {
      founderState = .reviewing
    } else {
      switch atmosphere.pressure {
      case .lowRunway, .lowTrust:
        founderState = .stressed
      case .lowEnergy:
        founderState = .lowEnergy
      case .stable:
        founderState = founderSummary.workInProgressCount > 0 ? .typing : .seatedIdle
      }
    }

    let roomLight = min(
      1,
      max(0.38, 0.48 + atmosphere.energy * 0.28 + atmosphere.momentum * 0.16)
    )
    let computerGlow = founderSummary.reviewCount > 0 || founderSummary.resolutionCount > 0
      ? 1
      : founderSummary.workInProgressCount > 0 ? 0.82 : 0.52

    return Self(
      founderState: founderState,
      facility: progression.currentFacility,
      operatingPeriod: store.operatingCalendar.period,
      activeWorkCount: founderSummary.workInProgressCount,
      reviewAttentionCount: founderSummary.reviewCount + founderSummary.resolutionCount,
      energyLevel: atmosphere.energy,
      roomLightIntensity: roomLight,
      computerGlowIntensity: computerGlow,
      founderComputerAvailable: true,
      statusLabel: founderSummary.nextAction
    )
  }

  var accessibilitySummary: String {
    "\(facility.name). \(operatingPeriod.title). \(statusLabel)"
  }
}

/// Authored viewpoints belong to presentation navigation, never career saves.
enum FounderGarageCameraState: String, CaseIterable, Equatable, Sendable {
  case founderPOV, garageOverview, whiteboard, frontBay, garageDoor, front

  var allowsComputer: Bool { self == .founderPOV }
  var title: String {
    switch self {
    case .founderPOV: "Founder View"
    case .garageOverview: "Garage Overview"
    case .whiteboard: "Whiteboard View"
    case .frontBay: "Front Bay View"
    case .garageDoor: "Garage Door View"
    case .front: "Front View"
    }
  }
}

/// Floor-level player pose, kept separate from the camera's eye transform so
/// future standing and translation can reuse the same spatial authority.
struct FounderPlayerPose: Equatable, Sendable {
  var position: SIMD3<Float>
  var heading: Float
}

/// Head rotation relative to the neutral Founder workstation composition.
struct FounderLookOrientation: Equatable, Sendable {
  var yaw: Float = 0
  var pitch: Float = 0

  static let neutral = FounderLookOrientation()
  var isNeutral: Bool { abs(yaw) < 0.0001 && abs(pitch) < 0.0001 }
}

/// Authored inspection views and the player-controlled seated view have
/// deliberately different input semantics.
enum FounderGarageNavigationMode: Equatable, Sendable {
  case seated
  case authoredInspection(FounderGarageCameraState)
}

/// Session-only RealityKit player state. This never enters GameStore or saves.
struct FounderGaragePlayerSpatialState: Equatable, Sendable {
  var playerPose: FounderPlayerPose
  var eyeOffset: SIMD3<Float>
  var lookOrientation: FounderLookOrientation = .neutral
  var navigationMode: FounderGarageNavigationMode = .seated

  var eyePosition: SIMD3<Float> { playerPose.position + eyeOffset }
}
