import Foundation
import SwiftUI

enum GarageMotionPolicy: Equatable {
  case active
  case staticPose
}

enum GarageAvatarPose: Equatable {
  case still
  case breathing
  case working
  case heavy
}

enum GarageMonitorBehavior: Equatable {
  case dim
  case steady
  case activity
  case warm
}

enum GarageRingBehavior: Equatable {
  case steady
  case pendingPulse
  case verified
}

enum GarageTransitionAccent: Equatable {
  case none
  case wake
  case warning
  case confirmation
}

/// Pure visual policy. The Garage reads this policy; it never changes game state.
struct GarageAnimationProfile: Equatable {
  var avatarPose: GarageAvatarPose
  var monitorBehavior: GarageMonitorBehavior
  var ringBehavior: GarageRingBehavior
  var particleCount: Int
  var allowsLoop: Bool
  var transition: GarageTransitionAccent

  static func profile(
    for state: AgentStationViewModel.SemanticState,
    motion: GarageMotionPolicy
  ) -> Self {
    guard motion == .active else {
      return Self(
        avatarPose: .still,
        monitorBehavior: staticMonitor(for: state),
        ringBehavior: staticRing(for: state),
        particleCount: 0,
        allowsLoop: false,
        transition: .none
      )
    }
    switch state {
    case .idle:
      return Self(avatarPose: .breathing, monitorBehavior: .dim, ringBehavior: .steady, particleCount: 0, allowsLoop: true, transition: .none)
    case .working:
      return Self(avatarPose: .working, monitorBehavior: .activity, ringBehavior: .steady, particleCount: 3, allowsLoop: true, transition: .wake)
    case .awaitingReview:
      return Self(avatarPose: .breathing, monitorBehavior: .steady, ringBehavior: .pendingPulse, particleCount: 2, allowsLoop: true, transition: .none)
    case .drifting:
      return Self(avatarPose: .breathing, monitorBehavior: .steady, ringBehavior: .steady, particleCount: 2, allowsLoop: true, transition: .warning)
    case .overloaded:
      return Self(avatarPose: .heavy, monitorBehavior: .warm, ringBehavior: .steady, particleCount: 2, allowsLoop: true, transition: .warning)
    case .verified:
      return Self(avatarPose: .breathing, monitorBehavior: .steady, ringBehavior: .verified, particleCount: 2, allowsLoop: true, transition: .confirmation)
    }
  }

  private static func staticMonitor(for state: AgentStationViewModel.SemanticState) -> GarageMonitorBehavior {
    state == .overloaded ? .warm : (state == .idle ? .dim : .steady)
  }

  private static func staticRing(for state: AgentStationViewModel.SemanticState) -> GarageRingBehavior {
    state == .verified ? .verified : .steady
  }
}

enum GaragePhase {
  /// A stable phase in 0...1, calculated without Swift's randomly-seeded Hasher.
  static func offset(identity: String, index: Int) -> Double {
    let folded = identity.utf8.reduce(index * 131 + 17) { partial, byte in
      (partial * 31 + Int(byte)) % 10_000
    }
    return Double(folded) / 10_000
  }
}

enum GarageAnimationRenderer {
  static func avatarOffset(profile: GarageAnimationProfile, time: Double) -> CGFloat {
    guard profile.allowsLoop else { return 0 }
    let wave = sin(time * (.pi * 2) / 2.4)
    switch profile.avatarPose {
    case .still: return 0
    case .breathing: return CGFloat(wave * 0.8)
    case .working: return CGFloat(wave * 2.5)
    case .heavy: return CGFloat(wave * 1.2)
    }
  }

  static func avatarTilt(profile: GarageAnimationProfile, time: Double) -> Double {
    guard profile.allowsLoop else { return 0 }
    return profile.avatarPose == .heavy ? sin(time * (.pi * 2) / 2.4) * 2 : 0
  }

  static func warningOffset(profile: GarageAnimationProfile, transitionProgress: Double) -> CGFloat {
    guard profile.transition == .warning, transitionProgress < 1 else { return 0 }
    return CGFloat(sin(transitionProgress * .pi * 3) * (1 - transitionProgress) * 3)
  }

  static func ringScale(profile: GarageAnimationProfile, time: Double) -> CGFloat {
    guard profile.allowsLoop, profile.ringBehavior == .pendingPulse else { return 1 }
    return 1 + CGFloat((sin(time * (.pi * 2) / 2.2) + 1) * 0.035)
  }

  static func ringOpacity(profile: GarageAnimationProfile, time: Double, transitionProgress: Double) -> Double {
    if profile.ringBehavior == .pendingPulse, profile.allowsLoop { return 0.62 + (sin(time * (.pi * 2) / 2.2) + 1) * 0.15 }
    if profile.transition == .confirmation, transitionProgress < 1 { return 1 - transitionProgress * 0.28 }
    return 0.9
  }

  static func monitorColor(profile: GarageAnimationProfile) -> Color {
    switch profile.monitorBehavior { case .dim: .gray; case .steady, .activity: SoloTheme.cyan; case .warm: SoloTheme.amber }
  }

  static func monitorOpacity(profile: GarageAnimationProfile, time: Double) -> Double {
    guard profile.allowsLoop, profile.monitorBehavior == .activity else { return profile.monitorBehavior == .dim ? 0.28 : 0.72 }
    let stops = [0.48, 0.76, 0.58, 0.86, 0.64]
    let position = (time / 3.4).truncatingRemainder(dividingBy: 1) * Double(stops.count)
    return stops[Int(position) % stops.count]
  }

  @ViewBuilder static func particleLayer(count: Int, time: Double, identity: String, index: Int, motion: GarageMotionPolicy, color: Color) -> some View {
    ForEach(0..<count, id: \.self) { particle in
      let phase = GaragePhase.offset(identity: "\(identity)-\(particle)", index: index)
      let travel = motion == .active ? (time * 0.22 + phase).truncatingRemainder(dividingBy: 1) : 0
      Circle().fill(color.opacity(0.45)).frame(width: 3, height: 3)
        .offset(x: CGFloat((phase - 0.5) * 28), y: CGFloat(16 - travel * 34)).opacity(1 - travel)
    }
  }
}
