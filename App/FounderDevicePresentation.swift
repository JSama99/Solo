import Foundation

/// A presentation-only physical lifecycle. Canonical feature ownership stays
/// in FounderDeskNavigationState and the existing feature screens.
enum FounderPhysicalDeviceState: String, CaseIterable, Equatable, Sendable {
  case asleep
  case idle
  case waking
  case active
  case settling
}

struct FounderDevicePresentation: Equatable, Sendable {
  var state: FounderPhysicalDeviceState
  var screenLuminance: Double
  var localGlowIntensity: Double
  var reflectionOffset: Double
  var powerIndicatorIntensity: Double
  var peripheralBacklightIntensity: Double
  var operatingIndicatorIntensity: Double
  var physicalResponseEnabled: Bool
  var screenLifeEnabled: Bool
  var safePendingIndicatorVisible: Bool

  static func derive(
    device: FounderDeskDevice,
    state: FounderPhysicalDeviceState,
    safePending: Bool,
    visibleOperatingIntensity: Double = 0,
    reduceMotion: Bool,
    sceneActive: Bool,
    visible: Bool
  ) -> Self {
    let baseLuminance: Double = switch state {
    case .asleep: 0.24
    case .idle: 0.58
    case .waking: 0.96
    case .active: 1
    case .settling: 0.72
    }
    let deviceBias: Double = switch device {
    case .computer: 0.02
    case .phone: -0.06
    case .tablet: -0.03
    case .server: -0.10
    }
    let operating = min(1, max(0, visibleOperatingIntensity))
    let luminanceBoost: Double = switch device {
    case .computer: operating * 0.06
    case .server: operating * 0.05
    case .phone: operating * 0.015
    case .tablet: operating * 0.02
    }
    let glowBoost: Double = switch device {
    case .computer: operating * 0.18
    case .server: operating * 0.14
    case .phone: operating * 0.04
    case .tablet: operating * 0.06
    }
    let baseGlow = state == .active ? 0.88 : state == .waking ? 0.76 : state == .settling ? 0.46 : 0.20
    let responseEnabled = sceneActive && visible && !reduceMotion
    return Self(
      state: state,
      screenLuminance: min(1, max(0.18, baseLuminance + deviceBias + luminanceBoost)),
      localGlowIntensity: min(1, baseGlow + glowBoost),
      reflectionOffset: responseEnabled && state == .waking ? (device == .phone ? 9 : device == .tablet ? 6 : 4) : 0,
      powerIndicatorIntensity: state == .asleep ? 0.28 : safePending ? 1 : state == .idle ? 0.58 : 0.84,
      peripheralBacklightIntensity: device == .computer
        ? min(1, (state == .active ? 0.90 : state == .waking ? 0.76 : state == .settling ? 0.50 : 0.28) + operating * 0.10)
        : 0,
      operatingIndicatorIntensity: 0.24 + operating * 0.68,
      physicalResponseEnabled: responseEnabled && [.waking, .settling].contains(state),
      screenLifeEnabled: sceneActive && visible && !reduceMotion && state != .asleep,
      safePendingIndicatorVisible: safePending
    )
  }
}

enum FounderDeviceTransitionPolicy {
  static func wakeDelayMilliseconds(for device: FounderDeskDevice, reduceMotion: Bool) -> Int {
    guard !reduceMotion else { return 0 }
    switch device {
    case .computer: return 105
    case .phone: return 125
    case .tablet: return 155
    case .server: return 110
    }
  }

  static func restingState(afterClosing device: FounderDeskDevice) -> FounderPhysicalDeviceState {
    device == .computer ? .active : .idle
  }
}

/// Deterministic device/network reaction derived only from visible lifecycle
/// and interaction state. It deliberately has no random-number input.
struct FounderInfrastructureReactionPresentation: Equatable, Sendable {
  var serverFanActivity: Double
  var serverFanRotationDuration: Double
  var storageActivity: Double
  var networkActivity: Double
  var routerActivity: Double
  var statusRefreshActivity: Double
  var continuousMotionEnabled: Bool
  var eventToken: UUID?

  static func derive(
    stations: [FounderGarageStationMotion],
    event: FounderGarageEventEmphasis,
    reduceMotion: Bool,
    sceneActive: Bool
  ) -> Self {
    let operatingCount = stations.filter {
      [.assignmentReceived, .working, .reviewing, .resolving].contains($0.activity)
    }.count
    let workload = min(1, Double(operatingCount) / 3)
    let eventBurst: Double = switch event.kind {
    case .assignmentArrived, .founderReviewRequired, .reviewCompleted: 0.24
    case .resolutionLocked, .sprintCommitted: 0.16
    case .none: 0
    }
    let serverActivity = min(1, 0.34 + workload * 0.44 + eventBurst)
    let network = min(1, 0.24 + workload * 0.38 + eventBurst * 1.25)
    return Self(
      serverFanActivity: serverActivity,
      serverFanRotationDuration: 11.2 - serverActivity * 4.4,
      storageActivity: min(1, 0.20 + workload * 0.48 + eventBurst),
      networkActivity: network,
      routerActivity: min(1, 0.22 + workload * 0.34 + eventBurst * 1.45),
      statusRefreshActivity: min(1, 0.28 + workload * 0.36 + eventBurst),
      continuousMotionEnabled: sceneActive && !reduceMotion,
      eventToken: event.token
    )
  }
}
