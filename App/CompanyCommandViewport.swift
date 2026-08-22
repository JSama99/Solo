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
        commandFloor(time: time, scene: scene)
        infrastructureRail
      }
      // The viewport is a compact spatial scene. Cap its miniature labels while
      // the canonical cards below continue to honor unrestricted Dynamic Type.
      .dynamicTypeSize(...DynamicTypeSize.xLarge)
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
    if dynamicTypeSize.isAccessibilitySize { return focus == nil ? 470 : 640 }
    return focus == nil ? 364 : 494
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
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Label("ONLINE", systemImage: "circle.fill")
          .font(.system(size: 8, weight: .black, design: .monospaced))
          .foregroundStyle(SoloTheme.mint)
          .fixedSize()
          .accessibilityLabel("Company connection online")
        Spacer(minLength: 8)
        Label(sprintPhase.title, systemImage: sprintPhase.symbol)
          .font(.caption2.weight(.bold))
          .lineLimit(2)
          .multilineTextAlignment(.trailing)
          .layoutPriority(1)
        if focus != nil {
          Button("Close focus", systemImage: "xmark") {
            if let focus { onFocus(focus) }
          }
          .labelStyle(.iconOnly)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityHint("Returns to the full company overview without scrolling")
        }
      }
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        VStack(alignment: .leading, spacing: 1) {
          Text("COMPANY COMMAND")
            .font(.caption.weight(.black))
            .foregroundStyle(SoloTheme.amber)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
          Text(atmosphere.facility.name.uppercased())
            .font(.caption2.monospaced().weight(.bold))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
        Spacer(minLength: 4)
        Text(hierarchy.priority.rawValue.uppercased())
          .font(.system(size: 8, weight: .black, design: .monospaced))
          .foregroundStyle(SoloTheme.cyan)
          .lineLimit(2)
          .multilineTextAlignment(.trailing)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(minHeight: 52)
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
        localizedAtmosphere
        if let inspectionAgent = scene.agents.first(where: { [.reviewing, .reviewed].contains($0.agent.activity) })?.agent {
          overviewCommandFloor(time: time, geometry: geometry, scene: scene)
          FounderInspectionComposition(agent: inspectionAgent, reduceMotion: reduceMotion, time: time)
            .padding(.horizontal, 24)
            .padding(.bottom, 42)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        } else {
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

        if focus != nil {
          ForEach(scene.packetAgents) { item in
            if let object = CompanyCausalObject.project(agent: item.agent, reduceMotion: reduceMotion) {
              CausalJourney(
                object: object,
                accent: accent(for: item.agent.agentID),
                start: causalStart(index: item.index, object: object, size: geometry.size),
                end: causalEnd(index: item.index, object: object, size: geometry.size),
                reduceMotion: reduceMotion
              )
              .accessibilityHidden(true)
            }
          }
        }
        }
      }
    }
    .clipped()
  }

  private func overviewCommandFloor(time: TimeInterval, geometry: GeometryProxy, scene: ViewportSceneProjection) -> some View {
    ZStack(alignment: .bottom) {
      physicalInfrastructure(in: geometry.size)

      ForEach(scene.agents) { item in
        ViewportAgentStation(
          agent: item.agent,
          time: time,
          reduceMotion: reduceMotion,
          dimmed: item.dimmed,
          prominence: scene.hierarchy.stationProminence,
          dominant: item.dominant,
          facility: CompanySpatialPresentation.map(atmosphere.facility),
          action: { onFocus(.agent(item.agent.agentID)) }
        )
        .frame(width: stationWidth(dominant: item.dominant, total: geometry.size.width))
        .position(stationPosition(index: item.index, size: geometry.size))
        .accessibilitySortPriority(Double(scene.agents.count - item.index))
      }

      FounderCommandStation(
        activeCount: scene.activeCount,
        reviewCount: scene.reviewCount,
        pressure: atmosphere.pressure,
        action: { onFocus(.founder) }
      )
      .frame(width: min(geometry.size.width * 0.62, 230))
      .offset(y: 7)

      ForEach(scene.packetAgents) { item in
        if let object = CompanyCausalObject.project(agent: item.agent, reduceMotion: reduceMotion) {
          CausalJourney(
            object: object,
            accent: accent(for: item.agent.agentID),
            start: causalStart(index: item.index, object: object, size: geometry.size),
            end: causalEnd(index: item.index, object: object, size: geometry.size),
            reduceMotion: reduceMotion
          )
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
        Circle().fill(atmosphereColor).frame(width: 7, height: 7)
        .padding(8)
        .accessibilityHidden(true)
      }
  }

  @ViewBuilder
  private var facilityStructure: some View {
    if atmosphere.facility == .founderLoft {
      ZStack {
        HStack(spacing: 14) {
          ForEach(0..<3, id: \.self) { index in
            RoundedRectangle(cornerRadius: 8)
              .fill(LinearGradient(colors: [SoloTheme.cyan.opacity(0.20), SoloTheme.purple.opacity(0.04)], startPoint: .top, endPoint: .bottom))
              .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 3) {
                  ForEach(0..<(5 + index), id: \.self) { building in
                    Rectangle()
                      .fill(.black.opacity(0.48))
                      .frame(height: CGFloat(10 + (building * 7 + index * 5) % 34))
                  }
                }
                .padding(5)
              }
              .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.16)) }
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 48)
        HStack {
          Rectangle().fill(SoloTheme.purple.opacity(0.28)).frame(width: 8)
          Spacer()
          Rectangle().fill(SoloTheme.cyan.opacity(0.18)).frame(width: 8)
        }
        Capsule().fill(.white.opacity(0.08)).frame(height: 3).padding(.horizontal, 24)
      }
    } else {
      ZStack {
        HStack {
          Rectangle().fill(SoloTheme.amber.opacity(0.20)).frame(width: 5)
          Spacer()
          Rectangle().fill(SoloTheme.amber.opacity(0.10)).frame(width: 3)
        }
        Path { path in
          path.move(to: CGPoint(x: 0, y: 12))
          path.addLine(to: CGPoint(x: 126, y: 72))
          path.addLine(to: CGPoint(x: 248, y: 2))
          path.move(to: CGPoint(x: 22, y: 120))
          path.addCurve(to: CGPoint(x: 292, y: 164), control1: CGPoint(x: 110, y: 40), control2: CGPoint(x: 210, y: 220))
        }
        .stroke(SoloTheme.amber.opacity(0.16), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      }
      .padding(.horizontal, 8)
    }
  }

  private func stationWidth(dominant: Bool, total: CGFloat) -> CGFloat {
    min(dominant ? 132 : 112, max(88, total * (dominant ? 0.35 : 0.29)))
  }

  private func stationPosition(index: Int, size: CGSize) -> CGPoint {
    let x = (CGFloat(index) + 0.5) * size.width / CGFloat(max(1, agents.count))
    let structuralOffset: CGFloat = atmosphere.facility == .founderLoft ? 0 : (index == 1 ? -4 : 5)
    return CGPoint(x: x, y: 84 + structuralOffset)
  }

  private func stationEndpoint(index: Int, size: CGSize) -> CGPoint {
    CGPoint(x: (CGFloat(index) + 0.5) * size.width / CGFloat(max(1, agents.count)), y: 80)
  }

  private func causalStart(index: Int, object: CompanyCausalObject, size: CGSize) -> CGPoint {
    object.kind == .completedArtifact ? stationEndpoint(index: index, size: size) : CGPoint(x: size.width / 2, y: size.height - 30)
  }

  private func causalEnd(index: Int, object: CompanyCausalObject, size: CGSize) -> CGPoint {
    object.kind == .completedArtifact ? CGPoint(x: size.width / 2, y: size.height - 30) : stationEndpoint(index: index, size: size)
  }

  @ViewBuilder
  private func physicalInfrastructure(in size: CGSize) -> some View {
    ForEach(infrastructure) { item in
      PhysicalInfrastructureView(item: item, reduceMotion: reduceMotion)
        .frame(width: item.physicalLocation == .founderForegroundDesk ? 70 : 46, height: 34)
        .position(infrastructurePosition(item.physicalLocation, in: size))
        .accessibilityHidden(true)
    }
  }

  private func infrastructurePosition(_ location: InfrastructurePhysicalLocation, in size: CGSize) -> CGPoint {
    switch location {
    case .stacksBuildRail: CGPoint(x: size.width * 0.50, y: 137)
    case .auroraFounderVerificationBridge: CGPoint(x: size.width * 0.27, y: size.height - 61)
    case .brioBroadcastRail: CGPoint(x: size.width * 0.83, y: 132)
    case .recoverySideBay: CGPoint(x: 24, y: size.height - 55)
    case .founderForegroundDesk: CGPoint(x: size.width * 0.72, y: size.height - 29)
    }
  }

  @ViewBuilder
  private var localizedAtmosphere: some View {
    switch atmosphere.localizedReaction {
    case .stable:
      EmptyView()
    case .selectivePowerDown:
      HStack {
        Rectangle().fill(.black.opacity(0.42)).frame(width: 76)
        Spacer()
        Rectangle().fill(.black.opacity(0.35)).frame(width: 72)
      }
      .allowsHitTesting(false)
    case .runwayDepletion:
      VStack(alignment: .trailing, spacing: 3) {
        Label("\(atmosphere.runway)d runway", systemImage: "hourglass.bottomhalf.filled")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.amber)
        ProgressView(value: Double(max(0, atmosphere.runway)), total: 42).tint(SoloTheme.amber)
      }
      .frame(width: 112)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      .padding(8)
    case .publicSignalInterference:
      VStack(spacing: 3) {
        Image(systemName: "antenna.radiowaves.left.and.right.slash")
        HStack(spacing: 2) { ForEach(0..<5, id: \.self) { _ in Rectangle().frame(height: 2) } }
      }
      .foregroundStyle(SoloTheme.coral)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      .padding(10)
    case .connectedMomentum:
      Path { path in
        path.move(to: CGPoint(x: 28, y: 150))
        path.addCurve(to: CGPoint(x: 310, y: 150), control1: CGPoint(x: 100, y: 112), control2: CGPoint(x: 220, y: 190))
      }
      .trim(from: 0.08, to: 0.94)
      .stroke(SoloTheme.mint.opacity(0.30), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 10]))
      .allowsHitTesting(false)
    }
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
    var dominant: Bool
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
    let dominantID = CompanyPhaseHierarchy.dominantAgentID(agents: source, explicitFocus: nil)
    agents = source.enumerated().map { index, agent in
      AgentItem(
        index: index,
        agent: agent,
        dimmed: (hasReviewingAgent && agent.activity != .reviewing) || (dominantID != nil && dominantID != agent.agentID),
        dominant: dominantID == agent.agentID
      )
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
        input: .project(agent: agent, reduceMotion: reduceMotion),
        time: time
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
              input: .project(agent: surrounding, reduceMotion: reduceMotion),
              time: time
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
  var input: LivingAgentCharacterInput
  var time: TimeInterval

  var body: some View {
    NativeAgentCharacterView(
      agentID: agentID,
      initials: initials,
      accent: accent,
      input: input,
      time: time
    )
  }
}

private struct NativeAgentCharacterView: View {
  var agentID: String
  var initials: String
  var accent: Color
  var input: LivingAgentCharacterInput
  var time: TimeInterval

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
      LinearGradient(colors: [.clear, accent.opacity(input.activity == .resting ? 0.08 : 0.26)], startPoint: .top, endPoint: .bottom)
      if input.activity == .assignmentReceived {
        LinearGradient(colors: [.clear, accent.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
      }
      if let symbol = conditionSymbol {
        Image(systemName: symbol)
          .font(.caption.weight(.black))
          .foregroundStyle(.white)
          .padding(6)
          .background(conditionColor, in: Circle())
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(6)
          .accessibilityHidden(true)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 11))
    .overlay { RoundedRectangle(cornerRadius: 11).stroke(accent.opacity(0.65), lineWidth: 1) }
  }

  private var characterScale: CGFloat {
    guard !input.reduceMotion else { return 1.05 }
    return switch input.activity {
    case .assignmentReceived: 1.09
    case .working: 1.06 + 0.012 * sin(time * 2.3)
    case .resting: 1.03
    default: 1.05 + 0.006 * sin(time * 0.8)
    }
  }

  private var characterOffset: CGFloat {
    guard !input.reduceMotion, input.activity != .resting else { return 0 }
    let breathing = CGFloat(sin(time * 0.8)) * 0.6
    let workDirection: CGFloat = input.activity == .working ? (input.role == .marketing ? 1.1 : -0.8) : 0
    return breathing + workDirection
  }

  private var conditionSymbol: String? {
    if input.conditions.contains(.overloaded) { return "exclamationmark.triangle.fill" }
    if input.conditions.contains(.stressed) { return "gauge.with.dots.needle.67percent" }
    if input.levelUpTrigger { return "star.fill" }
    return nil
  }

  private var conditionColor: Color {
    input.conditions.contains(.overloaded) ? SoloTheme.coral : (input.levelUpTrigger ? SoloTheme.mint : SoloTheme.amber)
  }
}

private struct ViewportAgentStation: View {
  var agent: LivingAgentProjection
  var time: TimeInterval
  var reduceMotion: Bool
  var dimmed: Bool
  var prominence: Double
  var dominant: Bool
  var facility: CompanySpatialPresentation
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
      VStack(spacing: 4) {
        ZStack(alignment: .bottom) {
          stationBay
          LivingAgentCharacterView(
            agentID: agent.agentID,
            initials: agent.initials,
            accent: accent,
            input: .project(agent: agent, reduceMotion: reduceMotion),
            time: time
          )
          .frame(height: dominant ? 112 : 96)
          .padding(.horizontal, 7)
          .offset(y: dominant ? -9 : -5)
          consoleSilhouette
          conditionBadge
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(5)
        }
        .frame(height: dominant ? 112 : 100)
        Text(agent.name)
          .font(.caption.weight(.black))
          .lineLimit(1)
        Text(overviewState)
          .font(.caption2.weight(.bold))
          .foregroundStyle(statusColor)
          .lineLimit(1)
        conditionTreatment
        RoleSpecificWorkSurface(agent: agent, accent: accent, time: time, reduceMotion: reduceMotion)
      }
      .padding(.horizontal, 4)
      .padding(.bottom, 5)
      .frame(maxWidth: .infinity)
      .background(.black.opacity(agent.emphasis == .inspection ? 0.58 : 0.20), in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 5, bottomTrailingRadius: 5, topTrailingRadius: 18))
      .overlay(alignment: .bottom) { Rectangle().fill(strokeColor.opacity(0.78)).frame(height: dominant ? 3 : 1) }
      .opacity(dimmed ? 0.40 : prominence)
      .scaleEffect(dominant && !reduceMotion ? max(scale, 1.04) : scale)
      .shadow(color: dominant ? accent.opacity(0.35) : .clear, radius: 10, y: 3)
    }
    .buttonStyle(SoloPressStyle(scale: 0.96))
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("\(agent.name), \(agent.role.rawValue) station")
    .accessibilityValue(agent.accessibilityValue)
    .accessibilityHint("Focuses \(agent.name) inside Company Command without scrolling")
  }

  private var overviewState: String {
    switch agent.activity {
    case .idle: "Available"
    case .assignmentReceived: "Receiving assignment"
    case .working: agent.taskTitle ?? "Working"
    case .workComplete, .awaitingReview: "Founder review needed"
    case .reviewing: "In Founder review"
    case .reviewed: "Review complete"
    case .resolving: "Decision incoming"
    case .resolved: "Decision locked"
    case .resting: "Recovering"
    }
  }

  private var stationBay: some View {
    UnevenRoundedRectangle(
      topLeadingRadius: facility == .elevatedLoft ? 18 : 8,
      bottomLeadingRadius: 2,
      bottomTrailingRadius: 2,
      topTrailingRadius: facility == .elevatedLoft ? 18 : 13
    )
    .fill(LinearGradient(
      colors: [accent.opacity(dominant ? 0.22 : 0.10), .black.opacity(0.72)],
      startPoint: .top,
      endPoint: .bottom
    ))
    .overlay {
      UnevenRoundedRectangle(
        topLeadingRadius: facility == .elevatedLoft ? 18 : 8,
        bottomLeadingRadius: 2,
        bottomTrailingRadius: 2,
        topTrailingRadius: facility == .elevatedLoft ? 18 : 13
      )
      .stroke(accent.opacity(dominant ? 0.75 : 0.20), lineWidth: dominant ? 2 : 1)
    }
  }

  private var consoleSilhouette: some View {
    VStack(spacing: 0) {
      Spacer()
      RoundedRectangle(cornerRadius: 3)
        .fill(.black.opacity(0.86))
        .frame(height: 19)
        .overlay(alignment: .top) {
          HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
              Capsule()
                .fill(Double(index + 1) / 4 <= agent.progress ? accent : .white.opacity(0.16))
                .frame(height: 3)
            }
          }
          .padding(4)
        }
      Rectangle().fill(.black.opacity(0.88)).frame(height: 5).padding(.horizontal, -4)
    }
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
    let precedence: [LivingAgentCondition] = [.overloaded, .overclaimed, .drifting, .evidenceIncomplete, .verified, .stressed]
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
      .frame(height: 32)
      HStack(spacing: 2) {
        ForEach(0..<5, id: \.self) { index in
          Capsule()
            .fill(Double(index + 1) / 5 <= agent.progress ? accent : .white.opacity(0.10))
            .frame(maxWidth: .infinity, minHeight: 4)
        }
      }
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

private struct PhysicalInfrastructureView: View {
  var item: InfrastructureVisual
  var reduceMotion: Bool

  var body: some View {
    InfrastructureEquipmentView(item: item, reduceMotion: reduceMotion)
      .scaleEffect(item.state == .installing && !reduceMotion ? 1.06 : 1)
      .animation(reduceMotion ? nil : .smooth(duration: 0.9), value: item.state)
  }
}

private struct CausalJourney: View {
  var object: CompanyCausalObject
  var accent: Color
  var start: CGPoint
  var end: CGPoint
  var reduceMotion: Bool
  @State private var progress: CGFloat = 0

  var body: some View {
    ZStack(alignment: .topLeading) {
      Path { path in
        path.move(to: start)
        path.addQuadCurve(to: end, control: controlPoint)
      }
      .trim(from: max(0, progress - 0.30), to: progress)
      .stroke(journeyColor.opacity(0.82), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dash))
      Circle()
        .stroke(journeyColor.opacity(object.atEndpoint ? 0.85 : 0.38), lineWidth: 3)
        .frame(width: object.atEndpoint ? 42 : 30, height: object.atEndpoint ? 42 : 30)
        .overlay { Circle().fill(journeyColor.opacity(object.atEndpoint ? 0.16 : 0.05)).padding(5) }
        .position(end)
      causalObjectView.position(journeyPoint)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      guard !object.atEndpoint, !reduceMotion else {
        progress = 1
        return
      }
      withAnimation(.linear(duration: travelDuration)) {
        progress = 1
      }
    }
    .onChange(of: object.atEndpoint) { _, settled in
      if settled { progress = 1 }
    }
  }

  private var travelDuration: TimeInterval {
    switch object.kind {
    case .assignmentPacket: 0.70
    case .completedArtifact: 0.82
    case .resolutionResponse: 0.75
    }
  }

  private var controlPoint: CGPoint {
    CGPoint(x: (start.x + end.x) / 2 + bend, y: min(start.y, end.y) - 20)
  }

  private var bend: CGFloat {
    switch object.kind {
    case .assignmentPacket: -9
    case .completedArtifact: 10
    case .resolutionResponse: 18
    }
  }

  private var journeyPoint: CGPoint {
    let first = CGPoint(
      x: start.x + (controlPoint.x - start.x) * progress,
      y: start.y + (controlPoint.y - start.y) * progress
    )
    let second = CGPoint(
      x: controlPoint.x + (end.x - controlPoint.x) * progress,
      y: controlPoint.y + (end.y - controlPoint.y) * progress
    )
    return CGPoint(
      x: first.x + (second.x - first.x) * progress,
      y: first.y + (second.y - first.y) * progress
    )
  }

  private var causalObjectView: some View {
    ZStack {
      if object.kind == .resolutionResponse {
        RoundedRectangle(cornerRadius: 7)
          .fill(.black)
          .frame(width: 30, height: 30)
          .rotationEffect(.degrees(45))
          .overlay { RoundedRectangle(cornerRadius: 7).stroke(journeyColor, lineWidth: 2).rotationEffect(.degrees(45)) }
      } else {
        RoundedRectangle(cornerRadius: object.kind == .assignmentPacket ? 9 : 4)
          .fill(.black.opacity(0.94))
          .frame(width: object.kind == .completedArtifact ? 36 : 32, height: object.kind == .completedArtifact ? 32 : 28)
          .overlay { RoundedRectangle(cornerRadius: object.kind == .assignmentPacket ? 9 : 4).stroke(journeyColor, lineWidth: 2) }
      }
      Image(systemName: symbol)
        .font(.subheadline.weight(.black))
        .foregroundStyle(journeyColor)
    }
    .shadow(color: journeyColor.opacity(0.65), radius: reduceMotion ? 0 : 7)
  }

  private var journeyColor: Color {
    switch object.kind {
    case .assignmentPacket: accent
    case .completedArtifact: SoloTheme.mint
    case .resolutionResponse: SoloTheme.purple
    }
  }

  private var symbol: String {
    switch object.kind {
    case .assignmentPacket: "arrow.up.doc.fill"
    case .completedArtifact: "doc.richtext.fill"
    case .resolutionResponse: "checkmark.seal.fill"
    }
  }

  private var dash: [CGFloat] {
    object.kind == .resolutionResponse ? [3, 6] : []
  }

  private var lineWidth: CGFloat {
    object.kind == .completedArtifact ? 5 : 4
  }
}

private struct FounderInspectionComposition: View {
  var agent: LivingAgentProjection
  var reduceMotion: Bool
  var time: TimeInterval

  private var step: Int { max(1, min(5, agent.reviewRevealStep)) }
  private var result: ReviewResultVisual {
    ReviewResultVisual.map(conditions: agent.conditions, revealStep: agent.reviewRevealStep)
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Label("FOUNDER INSPECTION", systemImage: "viewfinder")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        Text(agent.name).font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      HStack(spacing: 12) {
        artifact
        VStack(alignment: .leading, spacing: 3) {
          Text(agent.activity == .reviewed ? "INSPECTION COMPLETE" : "STEP \(step) OF 5")
            .font(.caption2.monospacedDigit().weight(.black))
            .foregroundStyle(displayColor)
          Label(displayTitle, systemImage: agent.activity == .reviewed ? resultSymbol : stepSymbol)
            .font(.subheadline.weight(.black))
            .foregroundStyle(agent.activity == .reviewed ? displayColor : .primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
          Text(displayPurpose).font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack(spacing: 6) {
        ForEach(1...5, id: \.self) { index in
          Image(systemName: symbol(for: index))
            .font(.caption2.weight(.black))
            .foregroundStyle(index <= step ? color(for: index) : .secondary.opacity(0.35))
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(index == step ? color(for: index).opacity(0.15) : .clear, in: .rect(cornerRadius: 6))
        }
      }
    }
    .padding(12)
    .background(.black.opacity(0.94), in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(displayColor, lineWidth: 2) }
    .shadow(color: displayColor.opacity(0.40), radius: reduceMotion ? 0 : 14)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Founder inspection for \(agent.name), step \(step) of 5, \(stepTitle)")
  }

  private var artifact: some View {
    ZStack {
      resultShape
      Image(systemName: resultSymbol)
        .font(.title2.weight(.black))
        .foregroundStyle(resultColor)
      Rectangle()
        .fill(SoloTheme.cyan.opacity(0.50))
        .frame(height: 2)
        .offset(y: reduceMotion ? 0 : CGFloat(sin(time * 2.2)) * 22)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .frame(width: 76, height: 70)
  }

  @ViewBuilder private var resultShape: some View {
    switch result {
    case .pending:
      RoundedRectangle(cornerRadius: 12).fill(SoloTheme.cyan.opacity(0.12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(SoloTheme.cyan, lineWidth: 2) }
    case .verified:
      Circle().fill(SoloTheme.mint.opacity(0.15)).overlay { Circle().stroke(SoloTheme.mint, lineWidth: 3) }
    case .overclaimed:
      RoundedRectangle(cornerRadius: 3).fill(SoloTheme.coral.opacity(0.16)).overlay { RoundedRectangle(cornerRadius: 3).stroke(SoloTheme.coral, style: StrokeStyle(lineWidth: 3, dash: [7, 3])) }
    case .driftDetected:
      Capsule().fill(SoloTheme.purple.opacity(0.16)).overlay { Capsule().stroke(SoloTheme.purple, style: StrokeStyle(lineWidth: 3, dash: [2, 5])) }
    case .evidenceIncomplete:
      UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 2, topTrailingRadius: 2)
        .fill(SoloTheme.amber.opacity(0.16))
        .overlay { UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 2, topTrailingRadius: 2).stroke(SoloTheme.amber, lineWidth: 3) }
    }
  }

  private var stepTitle: String {
    ["Reported Quality", "Evidence", "Verification State", "Verified Actual", "Operational Risk"][step - 1]
  }

  private var stepPurpose: String {
    ["Incoming report", "Support inspection", "Canonical truth gate", "Report comparison", "Resulting risk assessment"][step - 1]
  }

  private var stepSymbol: String { symbol(for: step) }
  private var stepColor: Color { color(for: step) }
  private var displayColor: Color { agent.activity == .reviewed ? resultColor : stepColor }

  private var displayTitle: String {
    guard agent.activity == .reviewed else { return stepTitle }
    return switch result {
    case .pending: "Review Complete"
    case .verified: "Verified"
    case .overclaimed: "Overclaimed"
    case .driftDetected: "Drift Detected"
    case .evidenceIncomplete: "Evidence Incomplete"
    }
  }

  private var displayPurpose: String {
    guard agent.activity == .reviewed else { return stepPurpose }
    return switch result {
    case .pending: "Founder decision required"
    case .verified: "Report and verified actual align"
    case .overclaimed: "Reported quality exceeds verified actual"
    case .driftDetected: "Operational evidence has become unstable"
    case .evidenceIncomplete: "Evidence cannot support verification"
    }
  }

  private func symbol(for step: Int) -> String {
    ["chart.bar.doc.horizontal.fill", "point.3.connected.trianglepath.dotted", "checkmark.shield.fill", "arrow.left.arrow.right.square.fill", "exclamationmark.triangle.fill"][step - 1]
  }

  private func color(for step: Int) -> Color {
    [SoloTheme.cyan, SoloTheme.purple, SoloTheme.amber, SoloTheme.mint, SoloTheme.coral][step - 1]
  }

  private var resultSymbol: String {
    switch result {
    case .pending: stepSymbol
    case .verified: "checkmark.seal.fill"
    case .overclaimed: "arrow.up.and.down.text.horizontal"
    case .driftDetected: "waveform.badge.exclamationmark"
    case .evidenceIncomplete: "doc.badge.ellipsis"
    }
  }

  private var resultColor: Color {
    switch result {
    case .pending: stepColor
    case .verified: SoloTheme.mint
    case .overclaimed: SoloTheme.coral
    case .driftDetected: SoloTheme.purple
    case .evidenceIncomplete: SoloTheme.amber
    }
  }
}
