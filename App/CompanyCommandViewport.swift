import SwiftUI

/// Compact, first-person overview of the canonical Founder Computer workflow.
/// It accepts immutable visible projections and owns no simulation state.
struct CompanyCommandViewport: View {
  var agents: [LivingAgentProjection]
  var atmosphere: CompanyAtmosphere
  var infrastructure: [InfrastructureVisual]
  var sprintPhase: SprintPhase
  var reduceMotion: Bool
  var onSelectAgent: (String) -> Void
  var onSelectFounder: () -> Void
  var onSkipPresentation: () -> Void

  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var isVisible = true

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 18, paused: motionPaused)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      VStack(spacing: 8) {
        header
        commandFloor(time: time)
        infrastructureRail
      }
      .padding(12)
      .frame(maxWidth: .infinity)
      .frame(height: dynamicTypeSize.isAccessibilitySize ? 370 : 344)
      .background {
        viewportBackground(time: time)
          .clipShape(.rect(cornerRadius: 24))
      }
      .overlay { viewportFrame }
      .shadow(color: atmosphereColor.opacity(0.22), radius: 16, y: 8)
    }
    .onScrollVisibilityChange(threshold: 0.08) { isVisible = $0 }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Company Command Viewport, \(atmosphere.facility.name), \(sprintPhase.title)")
    .accessibilityAction(named: Text("Select Founder command station"), onSelectFounder)
    .accessibilityAction(named: Text("Select Aurora station")) { selectCanonicalAgent("aurora") }
    .accessibilityAction(named: Text("Select Stacks station")) { selectCanonicalAgent("stacks") }
    .accessibilityAction(named: Text("Select Brio station")) { selectCanonicalAgent("brio") }
  }

  private var motionPaused: Bool {
    reduceMotion || !isVisible || scenePhase != .active
  }

  private func selectCanonicalAgent(_ id: String) {
    guard ViewportSelectionMap.workstationID(
      for: id,
      canonicalAgentIDs: agents.map(\.agentID)
    ) != nil else { return }
    onSelectAgent(id)
  }

  private var header: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 1) {
        Text("COMPANY COMMAND")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.amber)
        Text(atmosphere.facility.name.uppercased())
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 4)
      Label(sprintPhase.title, systemImage: sprintPhase.symbol)
        .font(.caption2.weight(.bold))
        .lineLimit(1)
      if agents.contains(where: { [.assignmentReceived, .working, .workComplete, .reviewing, .resolving].contains($0.activity) }) {
        Button("Skip animation", systemImage: "forward.end.fill", action: onSkipPresentation)
          .labelStyle(.iconOnly)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityHint("Shows the already determined final presentation state immediately")
      }
    }
    .frame(minHeight: 30)
  }

  private func commandFloor(time: TimeInterval) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        facilityStructure
        HStack(alignment: .top, spacing: 6) {
          ForEach(Array(agents.enumerated()), id: \.element.id) { index, agent in
            ViewportAgentStation(
              agent: agent,
              time: time,
              reduceMotion: reduceMotion,
              dimmed: agents.contains(where: { $0.activity == .reviewing }) && agent.activity != .reviewing,
              action: { onSelectAgent(agent.agentID) }
            )
            .frame(maxWidth: .infinity)
            .accessibilitySortPriority(Double(agents.count - index))
          }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 5)
        .padding(.top, 4)

        FounderCommandStation(
          activeCount: agents.filter { [.assignmentReceived, .working].contains($0.activity) }.count,
          reviewCount: agents.filter { [.workComplete, .awaitingReview, .reviewing].contains($0.activity) }.count,
          pressure: atmosphere.pressure,
          action: onSelectFounder
        )
        .frame(width: min(geometry.size.width * 0.62, 230))
        .offset(y: 3)

        ForEach(Array(agents.enumerated()), id: \.element.id) { index, agent in
          if shouldShowPacket(for: agent.activity) {
            TaskPacket(
              accent: accent(for: agent.agentID),
              returning: [.workComplete, .awaitingReview, .reviewing].contains(agent.activity),
              settled: agent.activity == .awaitingReview || agent.activity == .reviewing,
              reduceMotion: reduceMotion
            )
            .position(packetPosition(index: index, agent: agent, size: geometry.size, time: time))
            .accessibilityHidden(true)
          }
        }
      }
    }
  }

  private var infrastructureRail: some View {
    HStack(spacing: 6) {
      Text("INFRA")
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .foregroundStyle(.secondary)
      ForEach(infrastructure) { item in
        Image(systemName: item.symbol)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(infrastructureColor(item.state))
          .frame(maxWidth: .infinity, minHeight: 24)
          .background(infrastructureColor(item.state).opacity(item.state == .uninstalled ? 0.02 : 0.11), in: .rect(cornerRadius: 6))
          .overlay { RoundedRectangle(cornerRadius: 6).stroke(infrastructureColor(item.state).opacity(0.35), lineWidth: 1) }
          .symbolEffect(.bounce, value: item.state)
          .accessibilityLabel(item.title)
          .accessibilityValue(infrastructureLabel(item.state))
      }
    }
    .frame(height: 26)
  }

  @ViewBuilder
  private func viewportBackground(time: TimeInterval) -> some View {
    let pulse = motionPaused ? 0 : 0.025 * sin(time * (1.2 + atmosphere.momentum))
    LinearGradient(
      colors: [
        facilityBase.opacity(0.88),
        SoloTheme.background,
        atmosphereColor.opacity(0.10 + pulse)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay(alignment: .top) {
      LinearGradient(
        colors: [atmosphereColor.opacity((0.12 + pulse) * atmosphere.energy), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 110)
    }
  }

  private var viewportFrame: some View {
    RoundedRectangle(cornerRadius: 24)
      .stroke(
        LinearGradient(
          colors: [contrast == .increased ? .white.opacity(0.8) : atmosphereColor.opacity(0.75), .white.opacity(0.08)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: contrast == .increased ? 2 : 1
      )
      .overlay(alignment: .topLeading) {
        HStack(spacing: 4) {
          Circle().fill(atmosphereColor).frame(width: 5, height: 5)
          Text(atmosphere.pressure == .stable ? "ONLINE" : atmosphere.pressure.rawValue.uppercased())
            .font(.system(size: 7, weight: .black, design: .monospaced))
        }
        .padding(8)
        .accessibilityHidden(true)
      }
  }

  @ViewBuilder
  private var facilityStructure: some View {
    if atmosphere.facility == .founderLoft {
      HStack(spacing: 10) {
        ForEach(0..<4, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [SoloTheme.cyan.opacity(0.12), SoloTheme.purple.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            .overlay { RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.08)) }
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 48)
    } else {
      HStack {
        Rectangle().fill(SoloTheme.amber.opacity(0.08)).frame(width: 3)
        Spacer()
        Rectangle().fill(SoloTheme.amber.opacity(0.08)).frame(width: 3)
      }
      .overlay {
        Path { path in
          path.move(to: .zero)
          path.addLine(to: CGPoint(x: 120, y: 80))
          path.move(to: CGPoint(x: 240, y: 0))
          path.addLine(to: CGPoint(x: 120, y: 80))
        }
        .stroke(SoloTheme.amber.opacity(0.08), lineWidth: 2)
      }
      .padding(.horizontal, 8)
    }
  }

  private func shouldShowPacket(for activity: LivingAgentActivity) -> Bool {
    [.assignmentReceived, .workComplete, .awaitingReview, .reviewing].contains(activity)
  }

  private func packetPosition(index: Int, agent: LivingAgentProjection, size: CGSize, time: TimeInterval) -> CGPoint {
    let count = max(1, agents.count)
    let stationX = (CGFloat(index) + 0.5) * size.width / CGFloat(count)
    let founder = CGPoint(x: size.width / 2, y: size.height - 24)
    let station = CGPoint(x: stationX, y: 52)
    if reduceMotion || agent.activity == .awaitingReview || agent.activity == .reviewing {
      return [.workComplete, .awaitingReview, .reviewing].contains(agent.activity) ? founder : station
    }
    let phase = CGFloat(time.truncatingRemainder(dividingBy: 0.8) / 0.8)
    let returning = [.workComplete, .awaitingReview, .reviewing].contains(agent.activity)
    let start = returning ? station : founder
    let end = returning ? founder : station
    return CGPoint(
      x: start.x + (end.x - start.x) * phase,
      y: start.y + (end.y - start.y) * phase - sin(phase * .pi) * 12
    )
  }

  private var facilityBase: Color {
    atmosphere.facility == .founderLoft ? SoloTheme.purple.opacity(0.30) : Color(red: 0.10, green: 0.09, blue: 0.08)
  }

  private var atmosphereColor: Color {
    switch atmosphere.pressure {
    case .stable: atmosphere.momentum >= 0.6 ? SoloTheme.mint : SoloTheme.cyan
    case .lowEnergy: SoloTheme.purple
    case .lowRunway: SoloTheme.amber
    case .lowTrust: SoloTheme.coral
    }
  }

  private func accent(for agentID: String) -> Color {
    switch agentID {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }

  private func infrastructureColor(_ state: InfrastructureVisual.State) -> Color {
    switch state {
    case .uninstalled: .secondary
    case .installed: .white
    case .active: SoloTheme.mint
    }
  }

  private func infrastructureLabel(_ state: InfrastructureVisual.State) -> String {
    switch state {
    case .uninstalled: "Not installed"
    case .installed: "Installed"
    case .active: "Installed and active"
    }
  }
}

/// Stable replacement boundary for a future Rive-backed character renderer.
struct LivingAgentCharacterView: View {
  var agentID: String
  var initials: String
  var accent: Color
  var activity: LivingAgentActivity
  var time: TimeInterval
  var reduceMotion: Bool

  var body: some View {
    NativeAgentCharacterView(
      agentID: agentID,
      initials: initials,
      accent: accent,
      activity: activity,
      time: time,
      reduceMotion: reduceMotion
    )
  }
}

private struct NativeAgentCharacterView: View {
  var agentID: String
  var initials: String
  var accent: Color
  var activity: LivingAgentActivity
  var time: TimeInterval
  var reduceMotion: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 11)
        .fill(.black.opacity(0.7))
      if let assetName = AgentPortraitAsset.name(for: agentID) {
        Image(assetName)
          .resizable()
          .scaledToFill()
          .scaleEffect(characterScale)
          .offset(y: characterOffset)
          .accessibilityHidden(true)
      } else {
        Text(initials).font(.headline.weight(.black)).foregroundStyle(accent)
      }
      LinearGradient(colors: [.clear, accent.opacity(activity == .resting ? 0.08 : 0.26)], startPoint: .top, endPoint: .bottom)
    }
    .clipShape(RoundedRectangle(cornerRadius: 11))
    .overlay { RoundedRectangle(cornerRadius: 11).stroke(accent.opacity(0.65), lineWidth: 1) }
  }

  private var characterScale: CGFloat {
    guard !reduceMotion else { return 1.05 }
    return switch activity {
    case .assignmentReceived: 1.09
    case .working: 1.06 + 0.012 * sin(time * 2.3)
    case .resting: 1.03
    default: 1.05 + 0.006 * sin(time * 0.8)
    }
  }

  private var characterOffset: CGFloat {
    reduceMotion || activity == .resting ? 0 : CGFloat(sin(time * 0.8)) * 0.6
  }
}

private struct ViewportAgentStation: View {
  var agent: LivingAgentProjection
  var time: TimeInterval
  var reduceMotion: Bool
  var dimmed: Bool
  var action: () -> Void

  private var accent: Color {
    switch agent.agentID {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        ZStack(alignment: .bottomTrailing) {
          LivingAgentCharacterView(
            agentID: agent.agentID,
            initials: agent.initials,
            accent: accent,
            activity: agent.activity,
            time: time,
            reduceMotion: reduceMotion
          )
          .frame(height: 104)
          conditionBadge
        }
        Text(agent.name)
          .font(.caption2.weight(.black))
          .lineLimit(1)
        Text(agent.activity.label)
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(statusColor)
          .lineLimit(1)
        stationMonitor
      }
      .padding(5)
      .frame(maxWidth: .infinity)
      .background(.black.opacity(agent.emphasis == .inspection ? 0.60 : 0.32), in: .rect(cornerRadius: 13))
      .overlay { RoundedRectangle(cornerRadius: 13).stroke(strokeColor, lineWidth: agent.emphasis == .inspection ? 2 : 1) }
      .opacity(dimmed ? 0.55 : 1)
      .scaleEffect(agent.emphasis == .selected && !reduceMotion ? 1.025 : 1)
    }
    .buttonStyle(SoloPressStyle(scale: 0.96))
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("\(agent.name), \(agent.role.rawValue) station")
    .accessibilityValue(agent.accessibilityValue)
    .accessibilityHint("Selects and scrolls to \(agent.name)'s full workstation")
  }

  @ViewBuilder
  private var conditionBadge: some View {
    if agent.conditions.contains(.overloaded) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SoloTheme.amber)
        .accessibilityHidden(true)
    } else if agent.conditions.contains(.verified) {
      Image(systemName: "checkmark.seal.fill").foregroundStyle(SoloTheme.mint)
        .accessibilityHidden(true)
    } else if agent.conditions.contains(.overclaimed) || agent.conditions.contains(.drifting) || agent.conditions.contains(.evidenceIncomplete) {
      Image(systemName: "waveform.badge.exclamationmark").foregroundStyle(SoloTheme.coral)
        .accessibilityHidden(true)
    } else if agent.activity == .resting {
      Image(systemName: "bed.double.fill").foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
  }

  private var stationMonitor: some View {
    HStack(spacing: 2) {
      ForEach(0..<5, id: \.self) { index in
        Capsule()
          .fill(Double(index + 1) / 5 <= agent.progress ? accent : .white.opacity(0.10))
          .frame(maxWidth: .infinity, minHeight: agent.activity == .working && !reduceMotion ? 3 + CGFloat(index % 2) : 3)
      }
    }
    .frame(height: 5)
  }

  private var statusColor: Color {
    if agent.conditions.contains(.overloaded) { return SoloTheme.amber }
    if agent.conditions.contains(.verified) { return SoloTheme.mint }
    if agent.conditions.contains(.overclaimed) || agent.conditions.contains(.drifting) { return SoloTheme.coral }
    return accent
  }

  private var strokeColor: Color {
    switch agent.emphasis {
    case .normal: accent.opacity(0.24)
    case .selected: accent.opacity(0.9)
    case .founderAttention: SoloTheme.amber
    case .inspection: accent
    case .decisionLock: SoloTheme.mint
    }
  }
}

private struct FounderCommandStation: View {
  var activeCount: Int
  var reviewCount: Int
  var pressure: CompanyAtmosphere.Pressure
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "command")
          .font(.headline.weight(.black))
          .foregroundStyle(SoloTheme.amber)
          .frame(width: 34, height: 34)
          .background(SoloTheme.amber.opacity(0.12), in: .rect(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 2) {
          Text("FOUNDER COMMAND")
            .font(.caption2.weight(.black))
          Text(reviewCount > 0 ? "\(reviewCount) artifact\(reviewCount == 1 ? "" : "s") in review tray" : "\(activeCount) active station\(activeCount == 1 ? "" : "s")")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(reviewCount > 0 ? SoloTheme.amber : .secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 2)
        Image(systemName: reviewCount > 0 ? "tray.full.fill" : "rectangle.3.group.fill")
          .foregroundStyle(reviewCount > 0 ? SoloTheme.amber : .secondary)
      }
      .padding(7)
      .background(.black.opacity(0.84), in: .rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(SoloTheme.amber.opacity(reviewCount > 0 ? 0.9 : 0.35)) }
    }
    .buttonStyle(SoloPressStyle())
    .frame(minHeight: 44)
    .accessibilityLabel("Founder command station")
    .accessibilityValue(reviewCount > 0 ? "\(reviewCount) artifacts await Founder attention" : "\(activeCount) agents active. Company pressure: \(pressure.rawValue)")
    .accessibilityHint("Selects and scrolls to the full Founder workstation")
  }
}

private struct TaskPacket: View {
  var accent: Color
  var returning: Bool
  var settled: Bool
  var reduceMotion: Bool

  var body: some View {
    Image(systemName: returning ? "doc.richtext.fill" : "arrow.up.doc.fill")
      .font(.system(size: 10, weight: .black))
      .foregroundStyle(returning ? SoloTheme.mint : accent)
      .frame(width: 22, height: 22)
      .background(.black.opacity(0.92), in: .rect(cornerRadius: 6))
      .overlay { RoundedRectangle(cornerRadius: 6).stroke(returning ? SoloTheme.mint : accent) }
      .shadow(color: returning ? SoloTheme.mint.opacity(0.5) : accent.opacity(0.5), radius: reduceMotion ? 0 : 5)
      .opacity(settled ? 0.82 : 1)
  }
}
