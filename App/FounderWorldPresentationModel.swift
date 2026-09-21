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
  case openFounderPhone
  case openFounderTablet
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
  static let founderPhone = "founderGarage.realityKit.founderPhone"
  static let founderTablet = "founderGarage.realityKit.founderTablet"
  static let chair = "founderGarage.realityKit.chair"
  static let whiteboard = "founderGarage.realityKit.whiteboard"
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
  static let founderPhoneEntityName = "FounderPhone.InteractionTarget"
  static let founderPhoneAccessibilityLabel = "Tech.com iPhone"
  static let founderPhoneAccessibilityHint = "Opens Tech.com on the Founder's iPhone."
  static let founderTabletEntityName = "FounderTablet.InteractionTarget"
  static let founderTabletAccessibilityLabel = "Venture iPad"
  static let founderTabletAccessibilityHint = "Opens Venture on the Founder's iPad."

  static func interaction(forEntityNamed name: String) -> FounderWorldInteraction? {
    switch name {
    case founderComputerEntityName: .openFounderComputer
    case founderPhoneEntityName: .openFounderPhone
    case founderTabletEntityName: .openFounderTablet
    default: nil
    }
  }
}

/// Session-only presentation feedback. It mirrors existing interaction truth and
/// never authorizes an interaction or enters career persistence.
enum GarageInteractionFeedbackState: Int, CaseIterable, Equatable, Sendable {
  case unavailable
  case available
  case focused
  case activated

  var exposesPrimaryPrompt: Bool { self == .focused || self == .activated }
}

enum GarageInteractionFeedbackPolicy: String, Equatable, Sendable {
  case none
  case deferred
}

struct GarageInteractionVisualEmphasis: Equatable, Sendable {
  let screenIntensityScale: Float
  let promptBorderOpacity: Double
  let promptScale: Double

  /// Shared target-strength signal. Individual materials translate this into a
  /// restrained local lift appropriate to the object instead of a global glow.
  var targetIntensityScale: Float { screenIntensityScale }

  static func resolve(
    state: GarageInteractionFeedbackState,
    reduceMotion: Bool
  ) -> Self {
    switch state {
    case .unavailable:
      .init(screenIntensityScale: 0.82, promptBorderOpacity: 0, promptScale: 1)
    case .available:
      .init(screenIntensityScale: 0.96, promptBorderOpacity: 0, promptScale: 1)
    case .focused:
      .init(screenIntensityScale: 1.14, promptBorderOpacity: 0.42, promptScale: 1)
    case .activated:
      .init(
        screenIntensityScale: 1.38,
        promptBorderOpacity: 0.78,
        promptScale: reduceMotion ? 1 : 1.025
      )
    }
  }
}

struct GarageInteractionFeedbackConfiguration: Equatable, Identifiable, Sendable {
  let targetID: String
  let promptText: String
  let activationDuration: TimeInterval
  let reducedMotionActivationDuration: TimeInterval
  let soundPolicy: GarageInteractionFeedbackPolicy
  let hapticPolicy: GarageInteractionFeedbackPolicy
  let promptPriority: Int
  let systemImage: String
  let accessibilityLabel: String
  let accessibilityHint: String
  let accessibilityIdentifier: String

  var id: String { targetID }

  init(
    targetID: String,
    promptText: String,
    activationDuration: TimeInterval,
    reducedMotionActivationDuration: TimeInterval,
    soundPolicy: GarageInteractionFeedbackPolicy,
    hapticPolicy: GarageInteractionFeedbackPolicy,
    promptPriority: Int,
    systemImage: String = "hand.tap.fill",
    accessibilityLabel: String = "Garage interaction",
    accessibilityHint: String = "Activates this Garage interaction.",
    accessibilityIdentifier: String = "founderGarage.realityKit.interaction"
  ) {
    self.targetID = targetID
    self.promptText = promptText
    self.activationDuration = activationDuration
    self.reducedMotionActivationDuration = reducedMotionActivationDuration
    self.soundPolicy = soundPolicy
    self.hapticPolicy = hapticPolicy
    self.promptPriority = promptPriority
    self.systemImage = systemImage
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.accessibilityIdentifier = accessibilityIdentifier
  }

  static func founderComputer(targetID: String) -> Self {
    .init(
      targetID: targetID,
      promptText: "OPEN COMPUTER",
      activationDuration: 0.22,
      reducedMotionActivationDuration: 0.08,
      soundPolicy: .deferred,
      hapticPolicy: .deferred,
      promptPriority: 100,
      systemImage: "desktopcomputer",
      accessibilityLabel: FounderWorldInteractionAdapter.founderComputerAccessibilityLabel,
      accessibilityHint: FounderWorldInteractionAdapter.founderComputerAccessibilityHint,
      accessibilityIdentifier: FounderGarageAccessibilityID.founderComputer
    )
  }

  static func chair(targetID: String) -> Self {
    .init(
      targetID: targetID,
      promptText: "RETURN TO DESK",
      activationDuration: 0.22,
      reducedMotionActivationDuration: 0.08,
      soundPolicy: .deferred,
      hapticPolicy: .deferred,
      promptPriority: 90,
      systemImage: "chair.fill",
      accessibilityLabel: "Founder Chair",
      accessibilityHint: "Returns the Founder to the desk using the existing Chair interaction.",
      accessibilityIdentifier: FounderGarageAccessibilityID.chair
    )
  }

  static func whiteboard(targetID: String) -> Self {
    .init(
      targetID: targetID,
      promptText: "VIEW WHITEBOARD",
      activationDuration: 0.22,
      reducedMotionActivationDuration: 0.08,
      soundPolicy: .deferred,
      hapticPolicy: .deferred,
      promptPriority: 80,
      systemImage: "viewfinder",
      accessibilityLabel: "Garage Whiteboard",
      accessibilityHint: "Opens the existing Whiteboard observation view.",
      accessibilityIdentifier: FounderGarageAccessibilityID.whiteboard
    )
  }

  func duration(reduceMotion: Bool) -> TimeInterval {
    reduceMotion ? reducedMotionActivationDuration : activationDuration
  }
}

struct GarageInteractionFeedbackSnapshot: Equatable, Identifiable, Sendable {
  let configuration: GarageInteractionFeedbackConfiguration
  let state: GarageInteractionFeedbackState

  var id: String { configuration.targetID }
}

enum GarageInteractionFeedbackResolver {
  static func state(
    configuration: GarageInteractionFeedbackConfiguration,
    isAvailable: Bool,
    isFocused: Bool,
    activationElapsed: TimeInterval?,
    reduceMotion: Bool
  ) -> GarageInteractionFeedbackState {
    guard isAvailable else { return .unavailable }
    if let activationElapsed,
       activationElapsed >= 0,
       activationElapsed < configuration.duration(reduceMotion: reduceMotion) {
      return .activated
    }
    return isFocused ? .focused : .available
  }

  static func primaryPrompt(
    from snapshots: [GarageInteractionFeedbackSnapshot]
  ) -> GarageInteractionFeedbackSnapshot? {
    snapshots
      .filter { $0.state.exposesPrimaryPrompt }
      .sorted {
        if $0.state.rawValue != $1.state.rawValue {
          return $0.state.rawValue > $1.state.rawValue
        }
        if $0.configuration.promptPriority != $1.configuration.promptPriority {
          return $0.configuration.promptPriority > $1.configuration.promptPriority
        }
        return $0.configuration.targetID < $1.configuration.targetID
      }
      .first
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
  case walking
  case authoredInspection(FounderGarageCameraState)
  case interactionFocus(FounderGarageInteractionFocusTarget)
}

enum FounderGarageInteractionFocusTarget: String, CaseIterable, Equatable, Sendable {
  case computer, phone, tablet, strategyBoard, signalTV, server
}

/// Presentation-only handoff for the later locomotion graph. Camera physics may
/// consume this pose without owning animation, foot contacts, or canonical state.
struct FounderLocomotionCameraSample: Equatable, Sendable {
  enum Stance: Equatable, Sendable { case seated, standing }
  var bodyPosition: SIMD3<Float>
  var bodyHeading: Float
  var locomotionVelocity: SIMD3<Float>
  var stepPhase: Float?
  var stance: Stance
}

/// Read-only presentation state consumed by the future Founder locomotion graph.
/// It describes camera-owned navigation without transferring transform authority.
struct FounderCameraSpatialState: Equatable, Sendable {
  var position: SIMD3<Float>
  var facingDirection: SIMD3<Float>
  var horizontalVelocity: SIMD2<Float>
  var movementMagnitude: Float
  var stance: FounderLocomotionCameraSample.Stance
  var navigationMode: FounderGarageNavigationMode
  var normalizedLocomotionIntent: SIMD2<Float>?
  var stepPhase: Float?
}

/// Session-only RealityKit player state. This never enters GameStore or saves.
struct FounderGaragePlayerSpatialState: Equatable, Sendable {
  var playerPose: FounderPlayerPose
  var eyeOffset: SIMD3<Float>
  var lookOrientation: FounderLookOrientation = .neutral
  var navigationMode: FounderGarageNavigationMode = .seated

  var eyePosition: SIMD3<Float> { playerPose.position + eyeOffset }
}

/// Session-only spatial continuity passed from the Garage camera authority to
/// the existing Atlantis traversal runtime at the authored driveway seam.
struct FounderAtlantisTraversalHandoff: Identifiable, Equatable, Sendable {
  let id = UUID()
  var garagePosition: SIMD3<Float>
  var facingDirection: SIMD3<Float>
}
