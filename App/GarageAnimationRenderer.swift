import SwiftUI

enum GarageAnimationRenderer {
  static func warningOffset(
    profile: GarageAnimationProfile,
    transitionProgress: Double
  ) -> CGFloat {
    guard profile.transition == .warning, transitionProgress < 1 else { return 0 }
    return CGFloat(sin(transitionProgress * .pi * 3) * (1 - transitionProgress) * 3)
  }

  static func monitorColor(profile: GarageAnimationProfile) -> Color {
    switch profile.monitorBehavior {
    case .dim:
      .gray
    case .steady, .activity:
      SoloTheme.cyan
    case .warm:
      SoloTheme.amber
    }
  }

  static func monitorOpacity(profile: GarageAnimationProfile, time: Double) -> Double {
    guard profile.allowsLoop, profile.monitorBehavior == .activity else {
      return profile.monitorBehavior == .dim ? 0.28 : 0.72
    }
    let stops = [0.48, 0.76, 0.58, 0.86, 0.64]
    let position = (time / 3.4).truncatingRemainder(dividingBy: 1) * Double(stops.count)
    return stops[Int(position) % stops.count]
  }

  @ViewBuilder
  static func particleLayer(
    count: Int,
    time: Double,
    identity: String,
    index: Int,
    motion: GarageMotionPolicy,
    color: Color
  ) -> some View {
    ForEach(0..<count, id: \.self) { particle in
      let particlePhase = GaragePhase.offset(identity: "\(identity)-\(particle)", index: index)
      let travel = motion == .active
        ? (time * 0.22 + particlePhase).truncatingRemainder(dividingBy: 1)
        : 0
      Circle()
        .fill(color.opacity(0.45))
        .frame(width: 3, height: 3)
        .offset(
          x: CGFloat((particlePhase - 0.5) * 28),
          y: CGFloat(16 - travel * 34)
        )
        .opacity(1 - travel)
    }
  }
}
