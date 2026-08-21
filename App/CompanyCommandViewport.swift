import SwiftUI

/// Compact, first-person overview of the canonical Founder Computer workflow.
/// It accepts immutable visible projections and owns no simulation state.
struct CompanyCommandViewport: View {
  var agents: [LivingAgentProjection]
  var atmosphere: CompanyAtmosphere
  var infrastructure: [InfrastructureVisual]
  var sprintPhase: SprintPhase
  var focus: CompanyCommandFocus?
  var agentAvailability: [String: CompanyCommandAgentAvailability]
  var founderSummary: CompanyCommandFounderSummary
  var reduceMotion: Bool
  var forceIncreasedContrast = false
  var onFocus: (CompanyCommandFocus) -> Void
  var onAssign: (String) -> Void
  var onReview: (String) -> Void
  var onRest: (String) -> Void
  var onSkipAgentPresentation: (String) -> Void
  var onOpenFullWorkstation: (CompanyCommandFocus) -> Void
  var onCommit: () -> Void
  var onVisibilityChange: (Bool) -> Void

  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var isVisible = true

  var body: some View {
    let scene = ViewportSceneProjection(agents: agents, sprintPhase: sprintPhase, founderSummary: founderSummary)
    return TimelineView(.animation(minimumInterval: 1 / 18, paused: motionPaused)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      VStack(spacing: 8) {
        header(hierarchy: scene.hierarchy)
        atmosphereStrip
        commandFloor(time: time, scene: scene)
        infrastructureRail
      }
      // The viewport is a compact spatial scene. Cap its miniature labels while
      // the canonical cards below continue to honor unrestricted Dynamic Type.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .padding(12)
      .frame(maxWidth: .infinity)
      .frame(height: viewportHeight)
      .background {
        viewportBackground(time: time)
          .clipShape(.rect(cornerRadius: 24))
      }
      .overlay { viewportFrame }
      .shadow(color: atmosphereColor.opacity(0.22), radius: 16, y: 8)
    }
    .onScrollVisibilityChange(threshold: 0.08) {
      isVisible = $0
      onVisibilityChange($0)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Company Command Viewport, \(atmosphere.facility.name), \(sprintPhase.title)")
    .accessibilityValue("Priority: \(scene.hierarchy.priority.rawValue). \(atmosphere.accessibilitySummary)")
    .accessibilityAction(named: Text("Focus Founder")) { onFocus(.founder) }
    .accessibilityAction(named: Text("Focus Aurora")) { focusCanonicalAgent("aurora") }
    .accessibilityAction(named: Text("Focus Stacks")) { focusCanonicalAgent("stacks") }
    .accessibilityAction(named: Text("Focus Brio")) { focusCanonicalAgent("brio") }
  }

  private var viewportHeight: CGFloat {
    if dynamicTypeSize.isAccessibilitySize { return focus == nil ? 450 : 610 }
    return focus == nil ? 382 : 468
  }

  private var motionPaused: Bool {
    reduceMotion || !isVisible || scenePhase != .active
  }

  private func focusCanonicalAgent(_ id: String) {
    guard ViewportSelectionMap.workstationID(
      for: id,
      canonicalAgentIDs: agents.map(\.agentID)
    ) != nil else { return }
    onFocus(.agent(id))
  }

  private func header(hierarchy: CompanyPhaseHierarchy) -> some View {
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
      VStack(alignment: .trailing, spacing: 1) {
        Label(sprintPhase.title, systemImage: sprintPhase.symbol)
          .font(.caption2.weight(.bold))
          .lineLimit(1)
        Text(hierarchy.priority.rawValue.uppercased())
          .font(.system(size: 7, weight: .black, design: .monospaced))
          .foregroundStyle(SoloTheme.cyan)
      }
      if focus != nil {
        Button("Close focus", systemImage: "xmark") {
          if let focus { onFocus(focus) }
        }
          .labelStyle(.iconOnly)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityHint("Returns to the full company overview without scrolling")
      }
    }
    .frame(minHeight: 30)
  }

  private var atmosphereStrip: some View {
    HStack(spacing: 5) {
      atmosphereSignal(
        atmosphere.isLowEnergy ? "LOW ENERGY" : "ENERGY",
        symbol: atmosphere.isLowEnergy ? "battery.25percent" : "battery.75percent",
        color: atmosphere.isLowEnergy ? SoloTheme.amber : SoloTheme.mint
      )
      atmosphereSignal(
        atmosphere.isLowRunway ? "LOW RUNWAY" : "RUNWAY",
        symbol: atmosphere.isLowRunway ? "hourglass.bottomhalf.filled" : "calendar.badge.checkmark",
        color: atmosphere.isLowRunway ? SoloTheme.amber : SoloTheme.cyan
      )
      atmosphereSignal(
        atmosphere.isLowTrust ? "LOW TRUST" : "TRUST",
        symbol: atmosphere.isLowTrust ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.badge.checkmark",
        color: atmosphere.isLowTrust ? SoloTheme.coral : SoloTheme.mint
      )
      atmosphereSignal(
        atmosphere.isHighMomentum ? "HIGH FLOW" : "MOMENTUM",
        symbol: atmosphere.isHighMomentum ? "arrow.up.right" : "arrow.right",
        color: atmosphere.isHighMomentum ? SoloTheme.cyan : .secondary
      )
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(atmosphere.accessibilitySummary)
  }

  private func atmosphereSignal(_ title: String, symbol: String, color: Color) -> some View {
    Label(title, systemImage: symbol)
      .font(.system(size: 7, weight: .black, design: .monospaced))
      .foregroundStyle(color)
      .lineLimit(1)
      .minimumScaleFactor(0.65)
      .frame(maxWidth: .infinity, minHeight: 20)
      .background(color.opacity(0.08), in: Capsule())
  }

  private func commandFloor(time: TimeInterval, scene: ViewportSceneProjection) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        facilityStructure
        switch focus {
        case .agent(let agentID):
          if let agent = scene.agentByID[agentID] {
            AgentCommandFocusPanel(
              agent: agent,
              surroundingAgents: scene.surroundingAgents[agentID] ?? [],
              availability: agentAvailability[agentID] ?? .init(),
              time: time,
              reduceMotion: reduceMotion,
              onTransferFocus: { onFocus(.agent($0)) },
              onAssign: { onAssign(agentID) },
              onReview: { onReview(agentID) },
              onRest: { onRest(agentID) },
              onSkip: { onSkipAgentPresentation(agentID) },
              onFullWorkstation: { onOpenFullWorkstation(.agent(agentID)) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
          }
        case .founder:
          FounderCommandFocusPanel(
            summary: founderSummary,
            onCommit: onCommit,
            onFullWorkstation: { onOpenFullWorkstation(.founder) }
          )
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case nil:
          overviewCommandFloor(time: time, geometry: geometry, scene: scene)
        }
      }
    }
  }

  private func overviewCommandFloor(time: TimeInterval, geometry: GeometryProxy, scene: ViewportSceneProjection) -> some View {
    ZStack(alignment: .bottom) {
      HStack(alignment: .top, spacing: 6) {
        ForEach(scene.agents) { item in
          ViewportAgentStation(
            agent: item.agent,
            time: time,
            reduceMotion: reduceMotion,
            dimmed: item.dimmed,
            prominence: scene.hierarchy.stationProminence,
            action: { onFocus(.agent(item.agent.agentID)) }
          )
          .frame(maxWidth: .infinity)
          .accessibilitySortPriority(Double(scene.agents.count - item.index))
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .padding(.horizontal, 5)
      .padding(.top, 4)

      FounderCommandStation(
        activeCount: scene.activeCount,
        reviewCount: scene.reviewCount,
        pressure: atmosphere.pressure,
        action: { onFocus(.founder) }
      )
      .frame(width: min(geometry.size.width * 0.62, 230))
      .offset(y: 3)

      ForEach(scene.packetAgents) { item in
        if shouldShowPacket(for: item.agent.activity) {
          TaskPacket(
            accent: accent(for: item.agent.agentID),
            returning: [.workComplete, .awaitingReview, .reviewing].contains(item.agent.activity),
            settled: [.awaitingReview, .reviewing, .resolved].contains(item.agent.activity),
            decisionResponse: [.resolving, .resolved].contains(item.agent.activity),
            reduceMotion: reduceMotion
          )
          .position(packetPosition(index: item.index, agent: item.agent, size: geometry.size, time: time))
          .accessibilityHidden(true)
        }
      }
    }
  }

  private var infrastructureRail: some View {
    HStack(spacing: 6) {
      Text("COMPANY SYSTEMS")
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .foregroundStyle(.secondary)
      ForEach(infrastructure) { item in
        InfrastructureEquipmentView(item: item, reduceMotion: reduceMotion)
          .frame(maxWidth: .infinity, minHeight: 30)
          .accessibilityLabel(item.title)
          .accessibilityValue(infrastructureLabel(item.state))
      }
    }
    .frame(height: 32)
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
          colors: [increasedContrast ? .white.opacity(0.8) : atmosphereColor.opacity(0.75), .white.opacity(0.08)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: increasedContrast ? 2 : 1
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
      VStack(spacing: 9) {
        HStack(spacing: 10) {
          ForEach(0..<4, id: \.self) { index in
            RoundedRectangle(cornerRadius: 5)
              .fill(LinearGradient(colors: [SoloTheme.cyan.opacity(0.18), SoloTheme.purple.opacity(0.04)], startPoint: .top, endPoint: .bottom))
              .overlay { RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.12)) }
              .overlay(alignment: .bottom) {
                Capsule()
                  .fill(index.isMultiple(of: 2) ? SoloTheme.cyan.opacity(0.25) : SoloTheme.purple.opacity(0.25))
                  .frame(height: 2)
                  .padding(4)
              }
          }
        }
        Capsule().fill(.white.opacity(0.08)).frame(height: 3).padding(.horizontal, 24)
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 48)
    } else {
      VStack(spacing: 4) {
        HStack {
          Rectangle().fill(SoloTheme.amber.opacity(0.16)).frame(width: 4)
          Spacer()
          Rectangle().fill(SoloTheme.amber.opacity(0.16)).frame(width: 4)
        }
        HStack(spacing: 5) {
          ForEach(0..<7, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 2).fill(SoloTheme.amber.opacity(0.10)).frame(height: 5)
          }
        }
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
    [.assignmentReceived, .workComplete, .awaitingReview, .reviewing, .resolving, .resolved].contains(activity)
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

  private var increasedContrast: Bool {
    contrast == .increased || forceIncreasedContrast
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
    case .installing: SoloTheme.amber
    case .installed: .white
    case .active: SoloTheme.mint
    }
  }

  private func infrastructureLabel(_ state: InfrastructureVisual.State) -> String {
    switch state {
    case .uninstalled: "Not installed"
    case .installing: "Installation in progress"
    case .installed: "Installed"
    case .active: "Installed and active"
    }
  }
}

private struct ViewportSceneProjection {
  struct AgentItem: Identifiable {
    var id: String { agent.agentID }
    var index: Int
    var agent: LivingAgentProjection
    var dimmed: Bool
  }

  var agents: [AgentItem]
  var packetAgents: [AgentItem]
  var agentByID: [String: LivingAgentProjection]
  var surroundingAgents: [String: [LivingAgentProjection]]
  var activeCount: Int
  var reviewCount: Int
  var hierarchy: CompanyPhaseHierarchy

  init(agents source: [LivingAgentProjection], sprintPhase: SprintPhase, founderSummary: CompanyCommandFounderSummary) {
    let hasReviewingAgent = source.contains { $0.activity == .reviewing }
    agents = source.enumerated().map { index, agent in
      AgentItem(index: index, agent: agent, dimmed: hasReviewingAgent && agent.activity != .reviewing)
    }
    packetAgents = agents.filter { [.assignmentReceived, .workComplete, .awaitingReview, .reviewing, .resolving, .resolved].contains($0.agent.activity) }
    agentByID = Dictionary(uniqueKeysWithValues: source.map { ($0.agentID, $0) })
    surroundingAgents = Dictionary(uniqueKeysWithValues: source.map { agent in
      (agent.agentID, source.filter { $0.agentID != agent.agentID })
    })
    activeCount = source.filter { [.assignmentReceived, .working].contains($0.activity) }.count
    reviewCount = source.filter { [.workComplete, .awaitingReview, .reviewing].contains($0.activity) }.count
    hierarchy = CompanyPhaseHierarchy.derive(sprintPhase: sprintPhase, agents: source, founderSummary: founderSummary)
  }
}

private struct InfrastructureEquipmentView: View {
  var item: InfrastructureVisual
  var reduceMotion: Bool

  private var color: Color {
    switch item.state {
    case .uninstalled: .secondary
    case .installing: SoloTheme.amber
    case .installed: .white
    case .active: SoloTheme.mint
    }
  }

  var body: some View {
    ZStack {
      equipmentShape
        .foregroundStyle(color.opacity(item.state == .uninstalled ? 0.20 : 0.78))
      Image(systemName: statusSymbol)
        .font(.system(size: 7, weight: .black))
        .foregroundStyle(color)
        .offset(x: 13, y: -7)
    }
    .frame(maxWidth: .infinity, minHeight: 30)
    .background(color.opacity(item.state == .uninstalled ? 0.025 : 0.09), in: .rect(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(style: StrokeStyle(lineWidth: 1, dash: item.state == .uninstalled ? [3, 3] : [])) .foregroundStyle(color.opacity(0.38)) }
    .symbolEffect(.pulse, options: .repeat(2), value: item.state == .installing)
  }

  @ViewBuilder
  private var equipmentShape: some View {
    switch item.id {
    case .developmentRig:
      HStack(spacing: 2) {
        ForEach(0..<3, id: \.self) { index in
          RoundedRectangle(cornerRadius: 1).frame(width: 7, height: CGFloat(8 + index * 3))
        }
      }
    case .verificationArray:
      ZStack {
        Circle().stroke(color.opacity(0.75), lineWidth: 2).frame(width: 22, height: 22)
        Circle().fill(color).frame(width: 5, height: 5)
      }
    case .campaignStudio:
      HStack(alignment: .bottom, spacing: 2) {
        ForEach(0..<4, id: \.self) { index in Capsule().frame(width: 3, height: CGFloat(6 + index * 3)) }
      }
    case .recoveryCorner:
      HStack(alignment: .bottom, spacing: 2) {
        RoundedRectangle(cornerRadius: 3).frame(width: 21, height: 9)
        Capsule().frame(width: 4, height: 17)
      }
    case .founderCommandDesk:
      VStack(spacing: 2) {
        HStack(spacing: 2) { ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 1).frame(width: 7, height: 8) } }
        Capsule().frame(width: 28, height: 3)
      }
    }
  }

  private var statusSymbol: String {
    switch item.state {
    case .uninstalled: "plus"
    case .installing: "wrench.and.screwdriver.fill"
    case .installed: "checkmark"
    case .active: "bolt.fill"
    }
  }
}

private struct AgentCommandFocusPanel: View {
  var agent: LivingAgentProjection
  var surroundingAgents: [LivingAgentProjection]
  var availability: CompanyCommandAgentAvailability
  var time: TimeInterval
  var reduceMotion: Bool
  var onTransferFocus: (String) -> Void
  var onAssign: () -> Void
  var onReview: () -> Void
  var onRest: () -> Void
  var onSkip: () -> Void
  var onFullWorkstation: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 10 : 8) {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(spacing: 8) {
          focusedCharacter.frame(height: 92)
          focusInformation
        }
      } else {
        HStack(alignment: .top, spacing: 12) {
          focusedCharacter.frame(width: 128, height: 132)
          focusInformation
        }
      }
      surroundingStations
      actionTray
    }
    .padding(.horizontal, 5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(agent.name) command focus")
  }

  private var focusedCharacter: some View {
    Button { onTransferFocus(agent.agentID) } label: {
      LivingAgentCharacterView(
        agentID: agent.agentID,
        initials: agent.initials,
        accent: accent,
        activity: agent.activity,
        time: time,
        reduceMotion: reduceMotion
      )
      .overlay(alignment: .bottomLeading) {
        Label(agent.role.rawValue, systemImage: agent.role.symbol)
          .font(.caption2.weight(.black))
          .padding(6)
          .background(.black.opacity(0.82), in: .rect(cornerRadius: 8))
          .padding(6)
      }
    }
    .buttonStyle(SoloPressStyle(scale: 0.98))
    .accessibilityLabel("Close \(agent.name) focus")
    .accessibilityHint("Returns to the company overview without scrolling")
  }

  private var focusInformation: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text(agent.name).font(.title3.weight(.black))
          Text(agent.role.rawValue).font(.caption.weight(.bold)).foregroundStyle(accent)
        }
        Spacer()
        Label("Lv \(agent.level)", systemImage: "star.fill")
          .font(.caption.weight(.bold))
      }
      Label(agent.activity.label, systemImage: activitySymbol)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(statusColor)
      Text(agent.taskTitle ?? "No task assigned")
        .font(.subheadline.weight(.semibold))
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
      HStack(spacing: 10) {
        Label(agent.stressLabel, systemImage: "gauge.with.dots.needle.50percent")
        Label(agent.trustLabel, systemImage: "person.crop.circle.badge.checkmark")
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      if agent.activity == .working || agent.activity == .assignmentReceived {
        ProgressView(value: agent.progress) {
          Text("WORK PROGRESS").font(.caption2.weight(.black))
        }
        .tint(accent)
      }
      if agent.needsFounderAttention {
        Label("Founder attention required", systemImage: "eye.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(SoloTheme.amber)
      }
      if agent.isResting {
        Label("Recovering this sprint", systemImage: "bed.double.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }
      RoleActivityMonitor(role: agent.role, progress: agent.progress, accent: accent)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityValue(agent.accessibilityValue)
  }

  private var surroundingStations: some View {
    HStack(spacing: 10) {
      Text("COMMAND ROOM").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.secondary)
      ForEach(surroundingAgents) { surrounding in
        Button { onTransferFocus(surrounding.agentID) } label: {
          HStack(spacing: 5) {
            LivingAgentCharacterView(
              agentID: surrounding.agentID,
              initials: surrounding.initials,
              accent: accent(for: surrounding.agentID),
              activity: surrounding.activity,
              time: time,
              reduceMotion: reduceMotion
            )
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
              Text(surrounding.name).font(.caption2.weight(.black))
              Text(surrounding.activity.label).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
            }
          }
          .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Focus \(surrounding.name)")
        .accessibilityValue(surrounding.accessibilityValue)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var actionTray: some View {
    LazyVGrid(columns: actionColumns, spacing: 7) {
      if availability.canAssign {
        commandAction("Assign Task", symbol: "checklist", action: onAssign)
      }
      if availability.canReview {
        commandAction("Review Work", symbol: "eye.fill", action: onReview)
      }
      if availability.requiresResolution {
        commandAction("Resolve in Full Workstation", symbol: "lock.open.fill", action: onFullWorkstation)
      }
      if availability.canRest {
        commandAction("Rest", symbol: "bed.double.fill", action: onRest)
      }
      if availability.canSkipPresentation {
        commandAction("Skip Presentation", symbol: "forward.end.fill", action: onSkip)
      }
      commandAction("Full Workstation", symbol: "rectangle.expand.vertical", action: onFullWorkstation)
    }
    .padding(7)
    .background(.black.opacity(0.58), in: .rect(cornerRadius: 12))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Contextual actions")
  }

  private var actionColumns: [GridItem] {
    dynamicTypeSize.isAccessibilitySize
      ? [GridItem(.flexible())]
      : [GridItem(.flexible()), GridItem(.flexible())]
  }

  private func commandAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
    Button(title, systemImage: symbol, action: action)
      .font(.caption.weight(.bold))
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(accent.opacity(0.12), in: .rect(cornerRadius: 9))
      .buttonStyle(.plain)
  }

  private var accent: Color { accent(for: agent.agentID) }

  private func accent(for agentID: String) -> Color {
    switch agentID {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }

  private var statusColor: Color {
    if agent.conditions.contains(.overloaded) { return SoloTheme.amber }
    if agent.conditions.contains(.verified) { return SoloTheme.mint }
    if !agent.conditions.intersection([.overclaimed, .drifting, .evidenceIncomplete]).isEmpty { return SoloTheme.coral }
    return accent
  }

  private var activitySymbol: String {
    switch agent.activity {
    case .idle: "circle.dotted"
    case .assignmentReceived: "arrow.down.doc.fill"
    case .working: agent.role.symbol
    case .workComplete, .awaitingReview: "tray.full.fill"
    case .reviewing, .reviewed: "eye.fill"
    case .resolving, .resolved: "lock.fill"
    case .resting: "bed.double.fill"
    }
  }
}

private struct RoleActivityMonitor: View {
  var role: AgentRole
  var progress: Double
  var accent: Color

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: role.symbol).font(.caption2.weight(.black))
      ForEach(0..<6, id: \.self) { index in
        Capsule()
          .fill(Double(index + 1) / 6 <= progress ? accent : .white.opacity(0.10))
          .frame(maxWidth: .infinity, minHeight: 5)
      }
    }
    .padding(6)
    .background(accent.opacity(0.08), in: .rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(role.rawValue) monitor")
    .accessibilityValue("\(Int((progress * 100).rounded())) percent activity")
  }
}

private struct FounderCommandFocusPanel: View {
  var summary: CompanyCommandFounderSummary
  var onCommit: () -> Void
  var onFullWorkstation: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "command")
          .font(.title2.weight(.black))
          .foregroundStyle(SoloTheme.amber)
          .frame(width: 52, height: 52)
          .background(SoloTheme.amber.opacity(0.13), in: .rect(cornerRadius: 14))
        VStack(alignment: .leading, spacing: 2) {
          Text("FOUNDER COMMAND").font(.headline.weight(.black))
          Label(summary.sprintPhase.title, systemImage: summary.sprintPhase.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(SoloTheme.amber)
        }
      }
      LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
        metric("Work active", summary.workInProgressCount, "waveform.path.ecg")
        metric("Reviews waiting", summary.reviewCount, "eye.fill")
        metric("Resolutions", summary.resolutionCount, "lock.open.fill")
        metric("Attention", summary.attentionRemaining, "eye.circle.fill", suffix: "/\(summary.attentionMaximum)")
      }
      Label(summary.nextAction, systemImage: summary.canCommit ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(summary.canCommit ? SoloTheme.mint : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.black.opacity(0.46), in: .rect(cornerRadius: 10))
      VStack(spacing: 7) {
        if summary.canCommit {
          Button("Commit Sprint", systemImage: "arrow.forward.square.fill", action: onCommit)
            .font(.subheadline.weight(.black))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(SoloTheme.amber, in: .rect(cornerRadius: 10))
            .foregroundStyle(.black)
            .buttonStyle(.plain)
        }
        Button("Full Founder Workstation", systemImage: "rectangle.expand.vertical", action: onFullWorkstation)
          .font(.subheadline.weight(.bold))
          .frame(maxWidth: .infinity, minHeight: 44)
          .background(SoloTheme.amber.opacity(0.13), in: .rect(cornerRadius: 10))
          .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder command focus")
  }

  private var metricColumns: [GridItem] {
    dynamicTypeSize.isAccessibilitySize
      ? [GridItem(.flexible())]
      : [GridItem(.flexible()), GridItem(.flexible())]
  }

  private func metric(_ label: String, _ value: Int, _ symbol: String, suffix: String = "") -> some View {
    Label {
      Text("\(label) \(value)\(suffix)").font(.caption.weight(.semibold))
    } icon: {
      Image(systemName: symbol).foregroundStyle(SoloTheme.amber)
    }
    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
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
      if activity == .assignmentReceived {
        LinearGradient(colors: [.clear, accent.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
      }
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
  var prominence: Double
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
        conditionTreatment
        RoleSpecificWorkSurface(agent: agent, accent: accent, time: time, reduceMotion: reduceMotion)
      }
      .padding(5)
      .frame(maxWidth: .infinity)
      .background(.black.opacity(agent.emphasis == .inspection ? 0.60 : 0.32), in: .rect(cornerRadius: 13))
      .overlay { RoundedRectangle(cornerRadius: 13).stroke(strokeColor, lineWidth: agent.emphasis == .inspection ? 2 : 1) }
      .opacity(dimmed ? 0.55 : prominence)
      .scaleEffect(scale)
    }
    .buttonStyle(SoloPressStyle(scale: 0.96))
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("\(agent.name), \(agent.role.rawValue) station")
    .accessibilityValue(agent.accessibilityValue)
    .accessibilityHint("Focuses \(agent.name) inside Company Command without scrolling")
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

  private var conditionTreatment: some View {
    Group {
      if let condition = primaryCondition {
        Label(condition.label, systemImage: conditionSymbol(condition))
          .foregroundStyle(conditionColor(condition))
      } else if agent.activity == .assignmentReceived {
        Label("Acknowledged", systemImage: "checkmark.message.fill").foregroundStyle(accent)
      } else if agent.activity == .resting {
        Label("Recovery active", systemImage: "bed.double.fill").foregroundStyle(.secondary)
      }
    }
    .font(.system(size: 7, weight: .black, design: .monospaced))
    .lineLimit(1)
    .minimumScaleFactor(0.65)
    .frame(maxWidth: .infinity, minHeight: 11)
  }

  private var primaryCondition: LivingAgentCondition? {
    let precedence: [LivingAgentCondition] = [.overloaded, .overclaimed, .drifting, .evidenceIncomplete, .verified, .stressed, .focused]
    return precedence.first(where: agent.conditions.contains)
  }

  private func conditionSymbol(_ condition: LivingAgentCondition) -> String {
    switch condition {
    case .focused: "scope"
    case .stressed: "gauge.with.dots.needle.67percent"
    case .overloaded: "exclamationmark.triangle.fill"
    case .drifting: "point.bottomleft.forward.to.point.topright.scurvepath"
    case .verified: "checkmark.seal.fill"
    case .overclaimed: "arrow.up.and.down.text.horizontal"
    case .evidenceIncomplete: "link.badge.plus"
    }
  }

  private func conditionColor(_ condition: LivingAgentCondition) -> Color {
    switch condition {
    case .verified, .focused: condition == .verified ? SoloTheme.mint : accent
    case .stressed, .overloaded: SoloTheme.amber
    case .overclaimed, .drifting, .evidenceIncomplete: SoloTheme.coral
    }
  }

  private var scale: CGFloat {
    guard !reduceMotion else { return 1 }
    return switch agent.emphasis {
    case .selected: 1.025
    case .levelUpCelebration: 1.045
    default: 1
    }
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
    case .levelUpCelebration: accent
    }
  }
}

private struct RoleSpecificWorkSurface: View {
  var agent: LivingAgentProjection
  var accent: Color
  var time: TimeInterval
  var reduceMotion: Bool

  private var active: Bool { agent.activity == .working || agent.activity == .assignmentReceived }
  private var motionPhase: Double { reduceMotion || !active ? 0 : time.truncatingRemainder(dividingBy: 1.4) / 1.4 }

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        RoundedRectangle(cornerRadius: 4).fill(.black.opacity(agent.activity == .resting ? 0.52 : 0.78))
        roleArtwork
          .padding(.horizontal, 4)
          .opacity(agent.activity == .resting ? 0.30 : 1)
        if agent.activity == .reviewing {
          Rectangle()
            .fill(LinearGradient(colors: [.clear, SoloTheme.cyan.opacity(0.75), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(width: 20)
            .offset(x: reduceMotion ? 0 : CGFloat(motionPhase * 54 - 27))
        }
      }
      .frame(height: 27)
      HStack(spacing: 2) {
        ForEach(0..<5, id: \.self) { index in
          Capsule()
            .fill(Double(index + 1) / 5 <= agent.progress ? accent : .white.opacity(0.10))
            .frame(maxWidth: .infinity, minHeight: 3)
        }
      }
      Text(surfaceLabel)
        .font(.system(size: 6, weight: .black, design: .monospaced))
        .foregroundStyle(active ? accent : .secondary)
        .lineLimit(1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(agent.role.rawValue) workspace, \(surfaceLabel), \(Int((agent.progress * 100).rounded())) percent")
  }

  @ViewBuilder
  private var roleArtwork: some View {
    switch agent.role {
    case .research:
      ZStack {
        Path { path in
          path.move(to: CGPoint(x: 6, y: 13)); path.addLine(to: CGPoint(x: 25, y: 5)); path.addLine(to: CGPoint(x: 48, y: 14)); path.addLine(to: CGPoint(x: 70, y: 6))
        }.stroke(accent.opacity(active ? 0.8 : 0.25), lineWidth: 1)
        HStack { ForEach(0..<4, id: \.self) { index in Circle().fill(index == Int(motionPhase * 4) ? .white : accent).frame(width: 5, height: 5); if index < 3 { Spacer() } } }
      }
    case .engineering:
      HStack(spacing: 3) {
        ForEach(0..<4, id: \.self) { index in
          RoundedRectangle(cornerRadius: 2)
            .fill(Double(index + 1) / 4 <= agent.progress ? accent : accent.opacity(0.18))
            .frame(height: CGFloat(8 + index * 3))
            .overlay { Text("\(index + 1)").font(.system(size: 5, weight: .black)).foregroundStyle(.black) }
        }
      }
    case .marketing:
      ZStack(alignment: .leading) {
        ForEach(0..<3, id: \.self) { index in
          Capsule()
            .stroke(accent.opacity(0.32 + Double(index) * 0.18), lineWidth: 1)
            .frame(width: CGFloat(28 + index * 18), height: CGFloat(8 + index * 5))
        }
        Circle().fill(accent).frame(width: 6, height: 6).offset(x: CGFloat(motionPhase * 54))
      }
    case .general:
      HStack { ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.5)) } }
    }
  }

  private var surfaceLabel: String {
    if agent.activity == .resting { return "RECOVERY · NO TASK PROGRESS" }
    if agent.activity == .awaitingReview { return "ARTIFACT STABLE · REVIEW READY" }
    if agent.activity == .reviewing { return "FOUNDER INSPECTION · STEP \(max(1, agent.reviewRevealStep))/5" }
    if agent.activity == .reviewed { return "REPORT REVIEWED · RESOLUTION READY" }
    if agent.activity == .resolving { return "DECISION LOCKING · ALTERNATIVES HELD" }
    if agent.activity == .resolved { return "FOUNDER RESPONSE RECEIVED" }
    return switch agent.role {
    case .research: active ? "SOURCES → EVIDENCE → VERIFY" : "SOURCE SCAN STANDBY"
    case .engineering: active ? "BUILD → COMPILE → DEPLOY" : "PROCESSOR RAIL STANDBY"
    case .marketing: active ? "MESSAGE → CHANNELS → RESPONSE" : "SIGNAL CONSOLE STANDBY"
    case .general: active ? "OPERATIONS ACTIVE" : "OPERATIONS STANDBY"
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
    .accessibilityHint("Focuses Founder command inside the viewport without scrolling")
  }
}

private struct TaskPacket: View {
  var accent: Color
  var returning: Bool
  var settled: Bool
  var decisionResponse: Bool
  var reduceMotion: Bool

  var body: some View {
    Image(systemName: decisionResponse ? "lock.doc.fill" : (returning ? "doc.richtext.fill" : "arrow.up.doc.fill"))
      .font(.system(size: 10, weight: .black))
      .foregroundStyle(returning || decisionResponse ? SoloTheme.mint : accent)
      .frame(width: 22, height: 22)
      .background(.black.opacity(0.92), in: .rect(cornerRadius: 6))
      .overlay { RoundedRectangle(cornerRadius: 6).stroke(returning || decisionResponse ? SoloTheme.mint : accent) }
      .shadow(color: returning ? SoloTheme.mint.opacity(0.5) : accent.opacity(0.5), radius: reduceMotion ? 0 : 5)
      .opacity(settled ? 0.82 : 1)
  }
}
