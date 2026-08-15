import SwiftUI

struct GarageVisualization: View {
  var stations: [AgentStationViewModel]
  var policy: PresentationPolicy
  var facility: FacilityTier
  var stats: FounderStats = .init()
  var attentionRemaining = 0
  var attentionMaximum = 0
  var store: GameStore?
  var progression: FounderProgressionStore?
  var presentation: PresentationCoordinator?

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  @State private var isVisible = false
  @State private var selectedStation: AgentStationViewModel?
  @State private var focusedStationID: String?
  @State private var knownStates: [String: AgentStationViewModel.SemanticState] = [:]
  @State private var transitionStarts: [String: Date] = [:]
  @State private var focusDismissTask: Task<Void, Never>?

  var body: some View {
    Group {
      if shouldAnimate {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
          content(at: context.date)
        }
      } else {
        content(at: Date())
      }
    }
    .onAppear {
      isVisible = true
      knownStates = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0.semanticState) })
    }
    .onDisappear {
      isVisible = false
      focusDismissTask?.cancel()
    }
    .onChange(of: stationStateSignatures) { _, newStates in
      stageTransitions(newStates)
    }
  }

  private var shouldAnimate: Bool {
    policy.allowsAmbientMotion && isVisible
  }

  private var motionPolicy: GarageMotionPolicy {
    shouldAnimate ? .active : .staticPose
  }

  private var stationStateSignatures: [StationStateSignature] {
    stations.map { StationStateSignature(id: $0.id, state: $0.semanticState) }
  }

  @ViewBuilder
  private func content(at date: Date) -> some View {
    FounderGarageScene(
      stations: stations,
      facility: facility,
      stats: stats,
      attentionRemaining: attentionRemaining,
      attentionMaximum: attentionMaximum,
      store: store,
      progression: progression,
      presentation: presentation,
      motion: motionPolicy,
      date: date,
      selectedStation: $selectedStation
    )
  }

  private func stationPresentation(at date: Date) -> some View {
    HStack(alignment: .top, spacing: 10) {
        ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
          Button {
            select(station)
          } label: {
            AgentStation(
              station: station,
              index: index,
              date: date,
              motion: motionPolicy,
              isFocused: focusedStationID == station.id,
              differentiateWithoutColor: differentiateWithoutColor,
              transitionStart: transitionStarts[station.id]
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(station.name), \(station.role.rawValue) agent")
          .accessibilityValue(station.accessibilityValue)
          .accessibilityHint("Opens read-only agent details")
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
  }

  static func presentation(for facility: FacilityTier) -> GarageVisualPresentation {
    facility == .founderLoft ? .loft : .stations
  }

  static let supportsTaskAssignment = false

  private func garageBackground(at date: Date) -> some ShapeStyle {
    let phase = shouldAnimate ? (sin(date.timeIntervalSinceReferenceDate * 0.22) + 1) / 2 : 0.35
    return LinearGradient(
      colors: [
        SoloTheme.card,
        SoloTheme.cyan.opacity(0.06 + phase * 0.04),
        SoloTheme.background.opacity(0.86)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private func select(_ station: AgentStationViewModel) {
    selectedStation = station
    focusedStationID = station.id
    focusDismissTask?.cancel()
    focusDismissTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(0.5))
      guard !Task.isCancelled else { return }
      focusedStationID = nil
    }
  }

  private func stageTransitions(_ newStates: [StationStateSignature]) {
    let newest = Dictionary(uniqueKeysWithValues: newStates.map { ($0.id, $0.state) })
    defer { knownStates = newest }
    guard shouldAnimate else { return }
    for (id, state) in newest where knownStates[id] != state {
      transitionStarts[id] = Date()
    }
  }
}

enum GarageVisualPresentation: Equatable {
  case stations
  case loft
}

private struct StationStateSignature: Equatable {
  var id: String
  var state: AgentStationViewModel.SemanticState
}

struct AgentStation: View {
  var station: AgentStationViewModel
  var index: Int
  var date: Date
  var motion: GarageMotionPolicy
  var isFocused: Bool
  var differentiateWithoutColor: Bool
  var transitionStart: Date?

  var body: some View {
    let profile = GarageAnimationProfile.profile(for: station.semanticState, motion: motion)
    let phase = GaragePhase.offset(identity: station.id, index: index)
    let time = date.timeIntervalSinceReferenceDate + phase * 2.4
    let transitionProgress = transitionProgress(at: date)

    VStack(spacing: 7) {
      ZStack {
        Circle()
          .fill(.black.opacity(0.28))
          .frame(width: 78, height: 78)

        Circle()
          .stroke(trustColor, lineWidth: 4)
          .frame(width: 68, height: 68)
          .scaleEffect(GarageAnimationRenderer.ringScale(profile: profile, time: time))
          .opacity(GarageAnimationRenderer.ringOpacity(profile: profile, time: time, transitionProgress: transitionProgress))

        avatar(profile: profile, time: time, transitionProgress: transitionProgress)

        if profile.transition == .confirmation, transitionProgress < 1 {
          Circle()
            .trim(from: 0, to: transitionProgress)
            .stroke(SoloTheme.mint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 74, height: 74)
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
        }

        if profile.particleCount > 0 {
          GarageAnimationRenderer.particleLayer(count: profile.particleCount, time: time, identity: station.id, index: index, motion: motion, color: statusColor)
        }

        Image(systemName: station.semanticState.glyph)
          .font(.system(size: 10, weight: .black))
          .foregroundStyle(statusColor)
          .padding(5)
          .background(.black.opacity(0.84), in: .circle)
          .offset(x: 27, y: -27)
          .accessibilityHidden(true)
      }
      .frame(height: 82)

      monitor(profile: profile, time: time)

      Text(station.name)
        .font(.caption.weight(.bold))
        .lineLimit(1)
      Text(station.semanticState.label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(statusColor)
        .lineLimit(1)
      if differentiateWithoutColor {
        Text("Trust \(Int(station.trust.rounded()))")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .padding(.horizontal, 6)
    .background(isFocused ? SoloTheme.cyan.opacity(0.16) : .white.opacity(0.025), in: .rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(isFocused ? SoloTheme.cyan : .white.opacity(0.08), lineWidth: isFocused ? 2 : 1)
    }
    .animation(motion == .active ? .snappy(duration: 0.35) : nil, value: isFocused)
  }

  private var trustColor: Color {
    switch station.trustBand {
    case .teal: SoloTheme.mint
    case .amber: SoloTheme.amber
    case .coral: SoloTheme.coral
    }
  }

  private var statusColor: Color {
    switch station.semanticState {
    case .idle: .secondary
    case .working: SoloTheme.cyan
    case .awaitingReview: SoloTheme.amber
    case .drifting, .overloaded: SoloTheme.coral
    case .verified: SoloTheme.mint
    }
  }

  @ViewBuilder
  private func avatar(profile: GarageAnimationProfile, time: Double, transitionProgress: Double) -> some View {
    let bob = GarageAnimationRenderer.avatarOffset(profile: profile, time: time)
    VStack(spacing: 2) {
      Circle()
        .fill(.white.opacity(0.88))
        .frame(width: 20, height: 20)
      RoundedRectangle(cornerRadius: 7)
        .fill(SoloTheme.purple.gradient)
        .frame(width: 31, height: 27)
      HStack(spacing: 13) {
        Capsule().fill(.white.opacity(0.55)).frame(width: 4, height: 17)
        Capsule().fill(.white.opacity(0.55)).frame(width: 4, height: 17)
      }
      .offset(y: -22)
    }
    .offset(x: GarageAnimationRenderer.warningOffset(profile: profile, transitionProgress: transitionProgress), y: bob)
    .rotationEffect(.degrees(GarageAnimationRenderer.avatarTilt(profile: profile, time: time)))
  }

  @ViewBuilder
  private func monitor(profile: GarageAnimationProfile, time: Double) -> some View {
    let activity = GarageAnimationRenderer.monitorOpacity(profile: profile, time: time)
    VStack(spacing: 2) {
      RoundedRectangle(cornerRadius: 3)
        .fill(.black.opacity(0.8))
        .frame(height: 20)
        .overlay {
          RoundedRectangle(cornerRadius: 2)
            .fill(GarageAnimationRenderer.monitorColor(profile: profile).opacity(activity))
            .padding(3)
        }
      RoundedRectangle(cornerRadius: 1)
        .fill(.white.opacity(0.26))
        .frame(width: 14, height: 3)
    }
    .accessibilityHidden(true)
  }

  private func transitionProgress(at date: Date) -> Double {
    guard motion == .active, let transitionStart else { return 1 }
    return min(max(date.timeIntervalSince(transitionStart) / 0.55, 0), 1)
  }
}
