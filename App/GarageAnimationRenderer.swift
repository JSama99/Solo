import SwiftUI

/// The single shared home for garage station animation math.
///
/// Both `FounderGarageScene.GarageBayStation` (the spatial garage map) and
/// `GarageVisualization.AgentStation` (the row-of-stations presentation) read
/// their motion from here so the two surfaces can never drift apart.
///
/// Everything in this type is a pure function of a `GarageAnimationProfile`
/// plus a time value. It never reads or writes game state.
enum GarageAnimationRenderer {

  // MARK: - Timing

  /// A per-station time value, phase-shifted by station identity so that
  /// neighbouring bays do not animate in lockstep.
  static func stationTime(date: Date, identity: String, index: Int) -> Double {
    date.timeIntervalSinceReferenceDate + GaragePhase.offset(identity: identity, index: index) * 2.4
  }

  // MARK: - Avatar

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
    let wave = sin(time * (.pi * 2) / 2.4)
    return profile.avatarPose == .heavy ? wave * 2 : 0
  }

  // MARK: - Warning motion

  /// A one-shot warning nudge driven by an explicit transition progress in `0...1`.
  /// Used where a state change has a known start time.
  static func warningOffset(profile: GarageAnimationProfile, transitionProgress: Double) -> CGFloat {
    guard profile.transition == .warning, transitionProgress < 1 else { return 0 }
    return CGFloat(sin(transitionProgress * .pi * 3) * (1 - transitionProgress) * 3)
  }

  /// A continuous warning sway for surfaces that do not track transition start
  /// times. Unlike `warningOffset`, this keeps moving for as long as the station
  /// is in a warning state, so a drifting or overloaded agent stays visible.
  static func ambientWarningOffset(profile: GarageAnimationProfile, time: Double) -> CGFloat {
    guard profile.transition == .warning, profile.allowsLoop else { return 0 }
    return CGFloat(sin(time * (.pi * 2) / 0.9) * 1.6)
  }

  // MARK: - Ring

  static func ringScale(profile: GarageAnimationProfile, time: Double) -> CGFloat {
    guard profile.allowsLoop, profile.ringBehavior == .pendingPulse else { return 1 }
    return 1 + CGFloat((sin(time * (.pi * 2) / 2.2) + 1) * 0.035)
  }

  static func ringOpacity(profile: GarageAnimationProfile, time: Double, transitionProgress: Double) -> Double {
    if profile.ringBehavior == .pendingPulse, profile.allowsLoop {
      return 0.62 + (sin(time * (.pi * 2) / 2.2) + 1) * 0.15
    }
    if profile.transition == .confirmation, transitionProgress < 1 {
      return 1 - transitionProgress * 0.28
    }
    return 0.9
  }

  /// A wider pulse for the large garage-bay avatar ring, where the subtle
  /// `ringScale` amplitude reads as no movement at all.
  static func bayRingScale(profile: GarageAnimationProfile, time: Double) -> CGFloat {
    guard profile.allowsLoop, profile.ringBehavior == .pendingPulse else { return 1 }
    return 1 + CGFloat((sin(time * (.pi * 2) / 2.2) + 1) * 0.09)
  }

  // MARK: - Monitor

  static func monitorColor(profile: GarageAnimationProfile) -> Color {
    switch profile.monitorBehavior {
    case .dim: .gray
    case .steady, .activity: SoloTheme.cyan
    case .warm: SoloTheme.amber
    }
  }

  /// Monitor colour that preserves each agent's accent identity.
  ///
  /// The flat `monitorColor(profile:)` above paints every active agent the same
  /// cyan, which erases the per-agent colour coding the garage bays rely on.
  /// This overload keeps the agent's own accent for ordinary active states and
  /// only overrides it when the state itself is the message: grey when idle,
  /// amber when overloaded.
  static func monitorColor(profile: GarageAnimationProfile, accent: Color) -> Color {
    switch profile.monitorBehavior {
    case .dim: .gray
    case .steady, .activity: accent
    case .warm: SoloTheme.amber
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

  // MARK: - Status colour

  static func statusColor(for state: AgentStationViewModel.SemanticState) -> Color {
    switch state {
    case .idle: .secondary
    case .working: SoloTheme.cyan
    case .awaitingReview: SoloTheme.amber
    case .drifting, .overloaded: SoloTheme.coral
    case .verified: SoloTheme.mint
    }
  }

  // MARK: - Particles

  /// Rising activity particles.
  ///
  /// The geometry parameters default to the compact sizing used by the
  /// row-of-stations presentation. The garage bays pass larger values because a
  /// 3pt dot is invisible at bay scale.
  @ViewBuilder
  static func particleLayer(
    count: Int,
    time: Double,
    identity: String,
    index: Int,
    motion: GarageMotionPolicy,
    color: Color,
    diameter: CGFloat = 3,
    spread: CGFloat = 28,
    rise: CGFloat = 34,
    baseline: CGFloat = 16,
    opacity: Double = 0.45
  ) -> some View {
    ForEach(0..<count, id: \.self) { particle in
      let particlePhase = GaragePhase.offset(identity: "\(identity)-\(particle)", index: index)
      let travel = motion == .active
        ? (time * 0.22 + particlePhase).truncatingRemainder(dividingBy: 1)
        : 0
      Circle()
        .fill(color.opacity(opacity))
        .frame(width: diameter, height: diameter)
        .offset(
          x: CGFloat((particlePhase - 0.5) * spread),
          y: CGFloat(baseline - travel * rise)
        )
        .opacity(1 - travel)
    }
  }
}
