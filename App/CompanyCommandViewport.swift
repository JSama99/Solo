import SwiftUI

/// Compact, first-person overview of the canonical Founder Computer workflow.
/// It accepts immutable visible projections and owns no simulation state.
///
/// Build 32.4 keeps every automatic causal presentation inside one stable
/// spatial scene: choreography never opens agent focus, never expands the
/// canonical workstation, and never moves the page.
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
    let scene = ViewportSceneProjection(
      agents: agents,
      sprintPhase: sprintPhase,
      founderSummary: founderSummary,
      atmosphere: atmosphere,
      reduceMotion: reduceMotion
    )
    return TimelineView(.animation(minimumInterval: 1 / 18, paused: motionPaused)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      VStack(spacing: 7) {
        // The header carries essential state and must stay readable, so it is
        // capped far above the miniature scene labels below it.
        ViewportHeader(
          facilityName: atmosphere.facility.name,
          sprintPhase: sprintPhase,
          hierarchy: scene.hierarchy,
          secondaryInstruction: scene.secondaryInstruction,
          showsCloseFocus: focus != nil,
          onCloseFocus: { if let focus { onFocus(focus) } }
        )
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)

        commandFloor(time: time, scene: scene)
          .dynamicTypeSize(...DynamicTypeSize.xLarge)

        infrastructureRail
          .dynamicTypeSize(...DynamicTypeSize.large)
      }
      .padding(12)
      .frame(maxWidth: .infinity)
      .frame(height: viewportHeight)
      .background {
        viewportBackground(time: time, treatment: scene.treatment)
          .clipShape(.rect(cornerRadius: 24))
      }
      .overlay { viewportFrame(structure: scene.structure) }
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
    if dynamicTypeSize.isAccessibilitySize { return focus == nil ? 470 : 636 }
    return focus == nil ? 376 : 486
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

  // MARK: Scene

  private func commandFloor(time: TimeInterval, scene: ViewportSceneProjection) -> some View {
    GeometryReader { geometry in
      let layout = CompanySceneLayout(
        size: geometry.size,
        agentOrder: scene.agentOrder,
        structure: scene.structure
      )
      ZStack {
        FacilityStructureLayer(
          structure: scene.structure,
          layout: layout,
          treatment: scene.treatment,
          time: time,
          reduceMotion: reduceMotion,
          increasedContrast: increasedContrast
        )

        // The overview scene is always the spatial stage. Founder inspection
        // composes on top of it; only an explicit user focus replaces it.
        if scene.showsOverviewStage(focus: focus) {
          overviewStage(time: time, layout: layout, scene: scene)
            .transition(.opacity)
        }

        LocalizedAtmosphereLayer(
          treatment: scene.treatment,
          atmosphere: atmosphere,
          layout: layout,
          activeAgentIDs: scene.activeAgentIDs,
          time: time,
          reduceMotion: reduceMotion
        )
        .allowsHitTesting(false)

        if let inspectionAgent = scene.inspectionAgent {
          FounderInspectionComposition(agent: inspectionAgent, reduceMotion: reduceMotion, time: time)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .padding(.horizontal, 10)
            .position(x: geometry.size.width / 2, y: layout.bayCenterY + layout.bayHeight * 0.30)
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
            EmptyView()
          }
        }

        // Causal objects render last so an in-flight document is never hidden
        // by the inspection composition or by a user focus panel.
        causalLayer(plan: scene.plan, layout: layout, time: time)
      }
    }
    .clipped()
  }

  private func overviewStage(
    time: TimeInterval,
    layout: CompanySceneLayout,
    scene: ViewportSceneProjection
  ) -> some View {
    ZStack {
      ForEach(infrastructure) { item in
        PhysicalEquipmentView(
          item: item,
          structure: scene.structure,
          size: layout.systemSize(item.physicalLocation),
          time: time,
          reduceMotion: reduceMotion
        )
        .frame(
          width: layout.systemSize(item.physicalLocation).width,
          height: layout.systemSize(item.physicalLocation).height
        )
        .position(layout.point(.companySystem(item.physicalLocation)))
        .accessibilityLabel(item.title)
        .accessibilityValue("\(infrastructureLabel(item.state)). Located at \(item.physicalLocation.accessibilityName).")
      }

      ForEach(scene.agents) { item in
        ViewportAgentStation(
          agent: item.agent,
          time: time,
          reduceMotion: reduceMotion,
          dimmed: item.dimmed,
          prominence: scene.hierarchy.stationProminence,
          dominant: item.dominant,
          structure: scene.structure,
          confidence: scene.treatment.ambientMovementConfidence,
          signalIntegrity: item.agent.role == .marketing ? scene.treatment.externalSignalIntegrity : 1,
          action: { onFocus(.agent(item.agent.agentID)) }
        )
        .frame(width: layout.stationWidth(dominant: item.dominant), height: layout.bayHeight)
        .position(layout.stationCenter(item.agent.agentID))
        .accessibilitySortPriority(Double(scene.agents.count - item.index))
      }

      FounderCommandStation(
        activeCount: scene.activeCount,
        reviewCount: scene.reviewCount,
        pressure: atmosphere.pressure,
        deskProfile: scene.structure.founderDeskProfile,
        lightLevel: scene.treatment.founderLightLevel,
        action: { onFocus(.founder) }
      )
      .frame(width: layout.founderPanelWidth)
      .position(x: layout.size.width / 2, y: layout.founderDeskY)
    }
  }

  private func causalLayer(
    plan: CausalPresentationPlan,
    layout: CompanySceneLayout,
    time: TimeInterval
  ) -> some View {
    ZStack(alignment: .topLeading) {
      ForEach(plan.objects) { object in
        CausalJourney(
          object: object,
          accent: accent(for: object.agentID),
          start: layout.point(object.start),
          end: layout.point(object.end),
          lane: plan.lane(forAgentID: object.agentID, in: layout.agentOrder),
          laneCount: layout.agentOrder.count,
          time: time,
          reduceMotion: reduceMotion,
          increasedContrast: increasedContrast
        )
        .accessibilityHidden(true)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
  }

  private var infrastructureRail: some View {
    HStack(spacing: 6) {
      Text("SYSTEMS")
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .foregroundStyle(.secondary)
        .fixedSize()
      ForEach(infrastructure) { item in
        InfrastructureEquipmentView(item: item, reduceMotion: reduceMotion)
          .frame(maxWidth: .infinity, minHeight: 28)
          .accessibilityLabel(item.title)
          .accessibilityValue(infrastructureLabel(item.state))
      }
    }
    .frame(height: 30)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Company systems index")
  }

  // MARK: Chrome

  @ViewBuilder
  private func viewportBackground(time: TimeInterval, treatment: CompanyAtmosphereTreatment) -> some View {
    let pulse = motionPaused ? 0 : 0.02 * sin(time * (1.2 + atmosphere.momentum))
    LinearGradient(
      colors: [
        facilityBase.opacity(0.88),
        SoloTheme.background,
        atmosphereColor.opacity(0.08 + pulse)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay(alignment: .top) {
      LinearGradient(
        colors: [atmosphereColor.opacity((0.10 + pulse) * atmosphere.energy), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 96)
    }
  }

  private func viewportFrame(structure: FacilityStructureProjection) -> some View {
    RoundedRectangle(cornerRadius: 24)
      .stroke(
        LinearGradient(
          colors: [increasedContrast ? .white.opacity(0.85) : atmosphereColor.opacity(0.7), .white.opacity(0.08)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: increasedContrast ? 2.5 : structure.frameEdgeWeight
      )
      .allowsHitTesting(false)
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

  private func accent(for agentID: String) -> Color { SoloAgentAccent.color(agentID) }

  private func infrastructureLabel(_ state: InfrastructureVisual.State) -> String {
    switch state {
    case .uninstalled: "Not installed"
    case .installing: "Installation in progress"
    case .installed: "Installed"
    case .active: "Installed and active"
    }
  }
}

// MARK: - Shared accent

enum SoloAgentAccent {
  static func color(_ agentID: String) -> Color {
    switch agentID {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }
}

// MARK: - Header

/// Four independent regions: connection status, title and facility subtitle,
/// current phase and action, and an optional secondary instruction.
private struct ViewportHeader: View {
  var facilityName: String
  var sprintPhase: SprintPhase
  var hierarchy: CompanyPhaseHierarchy
  var secondaryInstruction: String?
  var showsCloseFocus: Bool
  var onCloseFocus: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    GeometryReader { geometry in
      let composition = ViewportHeaderComposition.derive(
        width: geometry.size.width,
        dynamicTypeSize: dynamicTypeSize,
        hasFocusAction: showsCloseFocus
      )
      Group {
        switch composition.layout {
        case .inline:
          HStack(alignment: .top, spacing: 8) {
            statusRegion(composition)
            titleRegion
            Spacer(minLength: 4)
            phaseRegion(composition)
            closeControl
          }
        case .stacked:
          VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
              statusRegion(composition)
              titleRegion
              Spacer(minLength: 4)
              closeControl
            }
            phaseRegion(composition)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: headerHeight)
  }

  private var headerHeight: CGFloat {
    if dynamicTypeSize.isAccessibilitySize { return showsCloseFocus ? 108 : 96 }
    if dynamicTypeSize >= .xxLarge { return 66 }
    return 38
  }

  /// The top-leading corner is reserved so nothing can be overdrawn on the
  /// title. It is a labelled control target, not a decorative dot.
  private func statusRegion(_ composition: ViewportHeaderComposition) -> some View {
    HStack(spacing: 3) {
      Circle()
        .fill(SoloTheme.mint)
        .frame(width: 7, height: 7)
      if composition.showsStatusText {
        Text("LIVE")
          .font(.system(size: 7, weight: .black, design: .monospaced))
          .foregroundStyle(SoloTheme.mint)
          .fixedSize()
      }
    }
    .frame(width: composition.showsStatusText ? nil : ViewportHeaderComposition.statusRegionWidth, alignment: .leading)
    .padding(.top, 3)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Company Command connection")
    .accessibilityValue("Live")
  }

  private var titleRegion: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("COMPANY COMMAND")
        .font(.caption.weight(.black))
        .foregroundStyle(SoloTheme.amber)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
      Text(facilityName.uppercased())
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Company Command, \(facilityName)")
  }

  @ViewBuilder
  private func phaseRegion(_ composition: ViewportHeaderComposition) -> some View {
    VStack(alignment: composition.layout == .inline ? .trailing : .leading, spacing: 2) {
      Group {
        if composition.collapsesPhaseToIcon {
          Label(sprintPhase.title, systemImage: sprintPhase.symbol).labelStyle(.iconOnly)
        } else {
          Label(sprintPhase.title, systemImage: sprintPhase.symbol).labelStyle(.titleAndIcon)
        }
      }
      .font(.caption2.weight(.bold))
      .lineLimit(2)
      .multilineTextAlignment(composition.layout == .inline ? .trailing : .leading)
      .fixedSize(horizontal: false, vertical: true)
      if composition.showsPriorityLine {
        Text(hierarchy.priority.rawValue.uppercased())
          .font(.system(size: 8, weight: .black, design: .monospaced))
          .foregroundStyle(SoloTheme.cyan)
          .lineLimit(1)
      } else if let secondaryInstruction, composition.layout == .stacked {
        Text(secondaryInstruction)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Current phase, \(sprintPhase.title)")
    .accessibilityValue(hierarchy.priority.rawValue)
  }

  @ViewBuilder
  private var closeControl: some View {
    if showsCloseFocus {
      Button("Close focus", systemImage: "xmark", action: onCloseFocus)
        .labelStyle(.iconOnly)
        .font(.footnote.weight(.bold))
        .frame(width: 44, height: 44)
        .contentShape(.rect)
        .buttonStyle(.plain)
        .offset(y: -4)
        .accessibilityHint("Returns to the full company overview without scrolling")
    }
  }
}

// MARK: - Scene projection

/// Precomputed, frame-independent scene indexing. Nothing here sorts, filters,
/// or allocates inside a frame-driven expression.
private struct ViewportSceneProjection {
  struct AgentItem: Identifiable {
    var id: String { agent.agentID }
    var index: Int
    var agent: LivingAgentProjection
    var dimmed: Bool
    var dominant: Bool
  }

  var agents: [AgentItem]
  var agentOrder: [String]
  var agentByID: [String: LivingAgentProjection]
  var surroundingAgents: [String: [LivingAgentProjection]]
  var activeAgentIDs: [String]
  var activeCount: Int
  var reviewCount: Int
  var hierarchy: CompanyPhaseHierarchy
  var structure: FacilityStructureProjection
  var treatment: CompanyAtmosphereTreatment
  var plan: CausalPresentationPlan
  var inspectionAgent: LivingAgentProjection?
  var secondaryInstruction: String?

  init(
    agents source: [LivingAgentProjection],
    sprintPhase: SprintPhase,
    founderSummary: CompanyCommandFounderSummary,
    atmosphere: CompanyAtmosphere,
    reduceMotion: Bool
  ) {
    let hasReviewingAgent = source.contains { $0.activity == .reviewing }
    let dominantID = CompanyPhaseHierarchy.dominantAgentID(agents: source, explicitFocus: nil)
    agents = source.enumerated().map { index, agent in
      AgentItem(
        index: index,
        agent: agent,
        dimmed: (hasReviewingAgent && agent.activity != .reviewing)
          || (dominantID != nil && dominantID != agent.agentID),
        dominant: dominantID == agent.agentID
      )
    }
    agentOrder = source.map(\.agentID)
    agentByID = Dictionary(uniqueKeysWithValues: source.map { ($0.agentID, $0) })
    surroundingAgents = Dictionary(uniqueKeysWithValues: source.map { agent in
      (agent.agentID, source.filter { $0.agentID != agent.agentID })
    })
    activeAgentIDs = source
      .filter { [.assignmentReceived, .working, .workComplete].contains($0.activity) }
      .map(\.agentID)
    activeCount = source.filter { [.assignmentReceived, .working].contains($0.activity) }.count
    reviewCount = source.filter { [.workComplete, .awaitingReview, .reviewing].contains($0.activity) }.count
    hierarchy = CompanyPhaseHierarchy.derive(
      sprintPhase: sprintPhase,
      agents: source,
      founderSummary: founderSummary
    )
    structure = FacilityStructureProjection.derive(atmosphere.facility)
    treatment = CompanyAtmosphereTreatment.derive(atmosphere)
    plan = CausalPresentationPlan.derive(agents: source, reduceMotion: reduceMotion)
    inspectionAgent = source.first { [.reviewing, .reviewed].contains($0.activity) }
    secondaryInstruction = founderSummary.nextAction
  }

  /// The spatial stage stays mounted for automatic presentation. Only an
  /// explicit user focus (with no inspection running) replaces it.
  func showsOverviewStage(focus: CompanyCommandFocus?) -> Bool {
    inspectionAgent != nil || focus == nil
  }
}

// MARK: - Facility structure

/// Garage and Loft differ by structure — proportion, rails, conduit, window
/// bays, recesses, mounting, and light character — not by a palette swap.
private struct FacilityStructureLayer: View {
  var structure: FacilityStructureProjection
  var layout: CompanySceneLayout
  var treatment: CompanyAtmosphereTreatment
  var time: TimeInterval
  var reduceMotion: Bool
  var increasedContrast: Bool

  var body: some View {
    ZStack {
      switch structure.presentation {
      case .improvisedGarage: garage
      case .elevatedLoft: loft
      }
      floorPlane
    }
    .allowsHitTesting(false)
  }

  // MARK: Garage

  /// Lower, tighter, improvised: recessed wall sections, asymmetric exposed
  /// rails, sagging conduit, and warm industrial practical lights.
  private var garage: some View {
    let band = layout.structureBandHeight
    return ZStack(alignment: .top) {
      HStack(spacing: 8) {
        ForEach(0..<structure.wallRecessCount, id: \.self) { index in
          Rectangle()
            .fill(.black.opacity(0.40))
            .frame(height: band * (index == 1 ? 0.92 : 0.72))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.07)).frame(height: 2) }
        }
      }
      .padding(.horizontal, 8)
      .frame(height: band, alignment: .top)

      // Asymmetric overhead rail plus uneven vertical supports in the bay gaps.
      Path { path in
        let width = layout.size.width
        path.move(to: CGPoint(x: 0, y: band * 0.62))
        path.addLine(to: CGPoint(x: width * 0.44, y: band * 0.28))
        path.addLine(to: CGPoint(x: width, y: band * 0.80))
        for index in 0..<layout.gapCount {
          let x = layout.gapX(index)
          path.move(to: CGPoint(x: x, y: index == 0 ? band * 0.3 : 0))
          path.addLine(to: CGPoint(x: x, y: index == 0 ? layout.floorY : layout.floorY * 0.88))
        }
      }
      .stroke(
        SoloTheme.amber.opacity(increasedContrast ? 0.55 : 0.34),
        style: StrokeStyle(lineWidth: 3, lineCap: .square)
      )

      ForEach(0..<structure.exposedConduitCount, id: \.self) { index in
        conduit(index: index, band: band)
      }

      HStack(spacing: layout.size.width * 0.26) {
        practicalLight
        practicalLight
      }
      .frame(height: band, alignment: .top)
      .offset(y: -band * 0.28)
    }
  }

  private func conduit(index: Int, band: CGFloat) -> some View {
    let width = layout.size.width
    let startX = width * (0.06 + Double(index) * 0.18)
    let sag = band * (0.24 + Double(index % 3) * 0.16)
    let top = band * 0.16
    return Path { path in
      path.move(to: CGPoint(x: startX, y: top))
      path.addQuadCurve(
        to: CGPoint(x: startX + width * 0.19, y: top + band * 0.08),
        control: CGPoint(x: startX + width * 0.095, y: top + sag)
      )
    }
    .stroke(
      Color(red: 0.46, green: 0.36, blue: 0.22).opacity(0.85),
      style: StrokeStyle(lineWidth: index.isMultiple(of: 2) ? 2.5 : 1.5, lineCap: .round)
    )
  }

  private var practicalLight: some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [SoloTheme.amber.opacity(0.6 * treatment.founderLightLevel), .clear],
          center: .center,
          startRadius: 1,
          endRadius: 30
        )
      )
      .frame(width: 58, height: 58)
      .overlay {
        Capsule()
          .fill(SoloTheme.amber.opacity(0.85 * treatment.founderLightLevel))
          .frame(width: 20, height: 4)
      }
  }

  // MARK: Loft

  /// Taller and cleaner: full-width window bays with an exterior skyline depth
  /// layer, organized mullions, and softer reflected light.
  private var loft: some View {
    let band = layout.structureBandHeight
    return ZStack(alignment: .top) {
      HStack(spacing: 10) {
        ForEach(0..<structure.windowBayCount, id: \.self) { index in
          windowBay(index: index, height: band)
        }
      }
      .padding(.horizontal, 8)
      .frame(height: band, alignment: .top)

      // Organized mullions continue cleanly down the bay gaps.
      Path { path in
        for index in 0..<layout.gapCount {
          let x = layout.gapX(index)
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x, y: layout.floorY))
        }
      }
      .stroke(SoloTheme.purple.opacity(increasedContrast ? 0.45 : 0.26), lineWidth: 2)

      LinearGradient(
        colors: [SoloTheme.cyan.opacity(0.20 * treatment.founderLightLevel), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: layout.size.height * 0.24)
    }
  }

  private func windowBay(index: Int, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: structure.bayCornerRadius)
      .fill(
        LinearGradient(
          colors: [SoloTheme.cyan.opacity(0.26), SoloTheme.purple.opacity(0.06)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(height: height)
      .overlay(alignment: .bottom) {
        if structure.hasSkylineLayer { skyline(index: index, height: height) }
      }
      .overlay {
        RoundedRectangle(cornerRadius: structure.bayCornerRadius)
          .stroke(.white.opacity(increasedContrast ? 0.5 : 0.22), lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: structure.bayCornerRadius))
  }

  private func skyline(index: Int, height: CGFloat) -> some View {
    HStack(alignment: .bottom, spacing: 3) {
      ForEach(0..<(6 + index), id: \.self) { building in
        Rectangle()
          .fill(.black.opacity(0.62))
          .frame(height: height * CGFloat(0.26 + Double((building * 11 + index * 7) % 26) / 52))
          .overlay(alignment: .top) {
            Rectangle().fill(SoloTheme.cyan.opacity(0.35)).frame(height: 1)
          }
      }
    }
    .padding(.horizontal, 4)
  }

  // MARK: Shared floor

  private var floorPlane: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      LinearGradient(
        colors: [
          .black.opacity(structure.presentation == .elevatedLoft ? 0.42 : 0.62),
          .black.opacity(0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: max(0, layout.size.height - layout.floorY))
      .overlay(alignment: .top) {
        Rectangle()
          .fill(
            structure.presentation == .elevatedLoft
              ? SoloTheme.cyan.opacity(0.24)
              : SoloTheme.amber.opacity(0.22)
          )
          .frame(height: structure.presentation == .elevatedLoft ? 1 : 2)
      }
    }
  }
}

// MARK: - Localized atmosphere

/// Every condition is expressed at a specific place in the room. Nothing here
/// tints the whole viewport, and every treatment carries text or a symbol.
private struct LocalizedAtmosphereLayer: View {
  var treatment: CompanyAtmosphereTreatment
  var atmosphere: CompanyAtmosphere
  var layout: CompanySceneLayout
  var activeAgentIDs: [String]
  var time: TimeInterval
  var reduceMotion: Bool

  var body: some View {
    ZStack {
      if treatment.showsMomentumLinks { momentumLinks }
      if treatment.showsTrustInterference { trustInterference }
      if treatment.showsEnergyStatus { energyStatus }
      if treatment.showsRunwayCountdown { runwayDepletion }
    }
  }

  /// Strengthened connections between active stations and Founder Command.
  private var momentumLinks: some View {
    ZStack {
      ForEach(activeAgentIDs, id: \.self) { agentID in
        Path { path in
          let station = layout.point(.roleMonitor(agentID))
          let founder = layout.point(.founderCommand)
          path.move(to: station)
          path.addQuadCurve(
            to: founder,
            control: CGPoint(x: (station.x + founder.x) / 2, y: layout.floorY - 6)
          )
        }
        .stroke(
          SoloTheme.mint.opacity(0.20 + 0.30 * treatment.momentumLinkStrength),
          style: StrokeStyle(lineWidth: 1.5 + 1.5 * treatment.momentumLinkStrength, lineCap: .round)
        )
      }
    }
  }

  /// Contained interference on the public-facing broadcast rail only.
  private var trustInterference: some View {
    let center = layout.point(.companySystem(.brioBroadcastRail))
    let jitter = reduceMotion ? 0 : sin(time * 5.5) * 1.6
    return VStack(spacing: 2) {
      Label("SIGNAL", systemImage: "antenna.radiowaves.left.and.right.slash")
        .font(.system(size: 7, weight: .black, design: .monospaced))
        .foregroundStyle(SoloTheme.coral)
        .fixedSize()
      ForEach(0..<3, id: \.self) { index in
        Rectangle()
          .fill(SoloTheme.coral.opacity(0.35 + 0.25 * (1 - treatment.externalSignalIntegrity)))
          .frame(width: 40, height: 1.5)
          .offset(x: index.isMultiple(of: 2) ? jitter : -jitter)
      }
    }
    // Sits on the public-facing display above the broadcast rail, clear of the
    // agent's own name and private work surface.
    .position(x: center.x, y: max(14, layout.structureBandHeight * 0.52))
    .accessibilityHidden(true)
  }

  /// Reduced practical light near Founder Command with a visible-safe symbol.
  private var energyStatus: some View {
    let founder = layout.point(.founderCommand)
    return Label("LOW ENERGY", systemImage: "battery.25percent")
      .font(.system(size: 8, weight: .black, design: .monospaced))
      .foregroundStyle(SoloTheme.purple)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(.black.opacity(0.72), in: Capsule())
      .fixedSize()
      .position(x: min(layout.size.width - 50, founder.x), y: max(16, founder.y - 42))
      .accessibilityHidden(true)
  }

  /// A depletion rail beside the Founder tray. It reuses the canonical runway
  /// value and invents no new timer.
  private var runwayDepletion: some View {
    let tray = layout.point(.founderTray)
    return VStack(alignment: .trailing, spacing: 2) {
      Label("\(max(0, atmosphere.runway))d", systemImage: "hourglass.bottomhalf.filled")
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .foregroundStyle(SoloTheme.amber)
        .fixedSize()
      HStack(spacing: 1.5) {
        ForEach(0..<8, id: \.self) { index in
          Capsule()
            .fill(Double(index) < Double(8) * (1 - treatment.runwayPressure)
              ? SoloTheme.amber
              : SoloTheme.amber.opacity(0.16))
            .frame(width: 4, height: 8)
        }
      }
    }
    .padding(.horizontal, 5)
    .padding(.vertical, 3)
    .background(.black.opacity(0.68), in: .rect(cornerRadius: 7))
    .position(x: min(layout.size.width - 40, tray.x + 4), y: max(18, tray.y - 46))
    .accessibilityHidden(true)
  }
}

// MARK: - Physical infrastructure

/// Installed infrastructure that reads as furniture in the room. Only the four
/// existing presentation states are represented; no bonus is invented.
private struct PhysicalEquipmentView: View {
  var item: InfrastructureVisual
  var structure: FacilityStructureProjection
  var size: CGSize
  var time: TimeInterval
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
      switch item.state {
      case .uninstalled: reservedMount
      case .installing: assemblyRails
      case .installed: equipment(active: false)
      case .active: equipment(active: true)
      }
    }
    .frame(width: size.width, height: size.height)
    .animation(reduceMotion ? nil : .smooth(duration: 0.9), value: item.state)
  }

  /// Empty mounting point with a reserved silhouette and no connection.
  private var reservedMount: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4)
        .stroke(.secondary.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
      HStack(spacing: 4) {
        ForEach(0..<2, id: \.self) { _ in
          Rectangle().fill(.secondary.opacity(0.20)).frame(width: 2, height: size.height * 0.55)
        }
      }
      Image(systemName: "plus")
        .font(.system(size: 7, weight: .black))
        .foregroundStyle(.secondary.opacity(0.65))
    }
  }

  /// Staged components on assembly rails.
  private var assemblyRails: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.62))
      VStack(spacing: 2) {
        HStack(spacing: 3) {
          ForEach(0..<3, id: \.self) { index in
            RoundedRectangle(cornerRadius: 1)
              .fill(SoloTheme.amber.opacity(index == staged ? 0.9 : 0.28))
              .frame(width: size.width * 0.16, height: size.height * 0.30)
          }
        }
        Rectangle().fill(SoloTheme.amber.opacity(0.7)).frame(height: 2)
      }
      .padding(.horizontal, 5)
      Image(systemName: "wrench.and.screwdriver.fill")
        .font(.system(size: 8, weight: .black))
        .foregroundStyle(SoloTheme.amber)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(2)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 4)
        .stroke(SoloTheme.amber.opacity(0.72), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
    }
  }

  private var staged: Int {
    reduceMotion ? 1 : Int(time.truncatingRemainder(dividingBy: 1.2) / 0.4) % 3
  }

  /// Persistent, recognizable equipment. Relevant-active adds a localized
  /// activation tied to the canonical context that already applies its bonus.
  private func equipment(active: Bool) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: structure.mountStyle == .organized ? 6 : 3)
        .fill(
          LinearGradient(
            colors: [.white.opacity(0.16), .black.opacity(0.86)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      silhouette(active: active)
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
      if active {
        RoundedRectangle(cornerRadius: structure.mountStyle == .organized ? 6 : 3)
          .fill(SoloTheme.mint.opacity(0.12))
        Image(systemName: "bolt.fill")
          .font(.system(size: 8, weight: .black))
          .foregroundStyle(SoloTheme.mint)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(2)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: structure.mountStyle == .organized ? 6 : 3)
        .stroke(active ? SoloTheme.mint.opacity(0.9) : .white.opacity(0.34), lineWidth: active ? 1.8 : 1)
    }
    .shadow(color: active ? SoloTheme.mint.opacity(0.4) : .clear, radius: 6)
  }

  @ViewBuilder
  private func silhouette(active: Bool) -> some View {
    let tint = active ? SoloTheme.mint : Color.white.opacity(0.72)
    switch item.id {
    case .developmentRig:
      // A stacked build rack against the Stacks bay.
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(0..<4, id: \.self) { index in
          RoundedRectangle(cornerRadius: 1)
            .fill(tint.opacity(0.30 + Double(index) * 0.16))
            .frame(maxWidth: .infinity)
            .frame(height: size.height * (0.42 + Double(index) * 0.13))
        }
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
    case .verificationArray:
      // A dish array on the Aurora verification bridge.
      HStack(spacing: 5) {
        ForEach(0..<3, id: \.self) { index in
          Circle()
            .stroke(tint.opacity(0.85), lineWidth: 1.5)
            .frame(width: size.height * 0.52, height: size.height * 0.52)
            .overlay { Circle().fill(tint).frame(width: 3, height: 3) }
            .offset(y: index == 1 ? -2 : 0)
        }
      }
    case .campaignStudio:
      // A broadcast console with output bars.
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(0..<5, id: \.self) { index in
          Capsule()
            .fill(tint.opacity(0.75))
            .frame(width: 3)
            .frame(height: size.height * (0.24 + Double((index * 3) % 5) * 0.14))
        }
        RoundedRectangle(cornerRadius: 2)
          .fill(tint.opacity(0.35))
          .frame(width: size.width * 0.24, height: size.height * 0.5)
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
    case .recoveryCorner:
      // A couch and lamp in the shared recovery bay.
      HStack(alignment: .bottom, spacing: 3) {
        RoundedRectangle(cornerRadius: 4)
          .fill(tint.opacity(0.55))
          .frame(width: size.width * 0.55, height: size.height * 0.48)
        VStack(spacing: 0) {
          Circle().fill(tint.opacity(0.8)).frame(width: 7, height: 7)
          Rectangle().fill(tint.opacity(0.5)).frame(width: 2, height: size.height * 0.42)
        }
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
    case .founderCommandDesk:
      // The foreground desk surface the Founder panel rests on.
      ZStack(alignment: .top) {
        UnevenRoundedRectangle(
          topLeadingRadius: structure.founderDeskProfile == .refined ? 8 : 2,
          bottomLeadingRadius: 2,
          bottomTrailingRadius: 2,
          topTrailingRadius: structure.founderDeskProfile == .refined ? 8 : 2
        )
        .fill(tint.opacity(structure.founderDeskProfile == .refined ? 0.30 : 0.22))
        Rectangle()
          .fill(tint.opacity(0.55))
          .frame(height: structure.founderDeskProfile == .refined ? 1.5 : 3)
      }
    }
  }
}

/// The compact status index. It stays a fast scan, never the primary
/// representation of installed infrastructure.
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
      Image(systemName: item.symbol)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(color.opacity(item.state == .uninstalled ? 0.35 : 0.92))
      Image(systemName: statusSymbol)
        .font(.system(size: 7, weight: .black))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(3)
    }
    .frame(maxWidth: .infinity, minHeight: 28)
    .background(color.opacity(item.state == .uninstalled ? 0.03 : 0.10), in: .rect(cornerRadius: 6))
    .overlay {
      RoundedRectangle(cornerRadius: 6)
        .stroke(style: StrokeStyle(lineWidth: 1, dash: item.state == .uninstalled ? [3, 3] : []))
        .foregroundStyle(color.opacity(0.40))
    }
    .symbolEffect(.pulse, options: .repeat(2), value: item.state == .installing)
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

// MARK: - Focus panels

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
        input: CharacterRendererInput.derive(agent: agent, reduceMotion: reduceMotion),
        accent: accent,
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
      Text("COMMAND ROOM")
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .foregroundStyle(.secondary)
      ForEach(surroundingAgents) { surrounding in
        Button { onTransferFocus(surrounding.agentID) } label: {
          HStack(spacing: 5) {
            LivingAgentCharacterView(
              input: CharacterRendererInput.derive(agent: surrounding, reduceMotion: reduceMotion),
              accent: SoloAgentAccent.color(surrounding.agentID),
              time: time
            )
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
              Text(surrounding.name).font(.caption2.weight(.black))
              Text(surrounding.activity.label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
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

  private var accent: Color { SoloAgentAccent.color(agent.agentID) }

  private var statusColor: Color {
    if agent.conditions.contains(.overloaded) { return SoloTheme.amber }
    if agent.conditions.contains(.verified) { return SoloTheme.mint }
    if !agent.conditions.intersection([.overclaimed, .drifting, .evidenceIncomplete]).isEmpty {
      return SoloTheme.coral
    }
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

// MARK: - Character renderer boundary

/// The stable replacement boundary for a bespoke character renderer. Build 32.4
/// resolves to the native portrait renderer because the repository contains no
/// production `.riv` asset. Only `CharacterRendererInput` crosses this line, so
/// no renderer can reach `GameStore`, a task result, hidden actual quality,
/// seeded RNG, persistence, or canonical action availability.
struct LivingAgentCharacterView: View {
  var input: CharacterRendererInput
  var accent: Color
  var time: TimeInterval

  var body: some View {
    switch CharacterRendererContract.resolvedRenderer() {
    case .rive, .native:
      // No production `.riv` asset ships in this build, and a failed asset load
      // must never blank a station, so the native renderer is the fallback for
      // both cases until real assets are integrated.
      NativeAgentCharacterView(input: input, accent: accent, time: time)
    }
  }
}

/// Native portrait renderer. It moves the whole portrait inside a fixed crop —
/// breathing depth, crop parallax, posture, and lighting — and never deforms or
/// continuously bounces a face.
private struct NativeAgentCharacterView: View {
  var input: CharacterRendererInput
  var accent: Color
  var time: TimeInterval

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 11).fill(.black.opacity(0.72))
      portrait
      // Rest settlement and station lighting.
      LinearGradient(
        colors: [.clear, accent.opacity(input.conditionModifiers.contains(.resting) ? 0.08 : 0.24)],
        startPoint: .top,
        endPoint: .bottom
      )
      conditionLighting
      if input.activity == .assignmentReceived {
        // Brief incoming-task response from the Founder side of the room.
        LinearGradient(colors: [accent.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
      }
      if input.emphasis == .inspection {
        // Inspection treatment stays isolated to the reviewed agent.
        RoundedRectangle(cornerRadius: 11)
          .stroke(SoloTheme.cyan, lineWidth: 2)
          .background(SoloTheme.cyan.opacity(0.10).clipShape(.rect(cornerRadius: 11)))
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
    .overlay { RoundedRectangle(cornerRadius: 11).stroke(rimColor, lineWidth: rimWidth) }
    .scaleEffect(celebration)
  }

  @ViewBuilder
  private var portrait: some View {
    if let assetName = AgentPortraitAsset.name(for: input.agentID) {
      Image(assetName)
        .resizable()
        .scaledToFill()
        .scaleEffect(depth)
        .offset(x: parallaxX, y: parallaxY)
        .grayscale(input.conditionModifiers.contains(.resting) ? 0.45 : 0)
        .accessibilityHidden(true)
    } else {
      Text(input.initials).font(.headline.weight(.black)).foregroundStyle(accent)
    }
  }

  /// Local amber pressure for stress and overload. Never a global filter.
  @ViewBuilder
  private var conditionLighting: some View {
    if input.conditionModifiers.contains(.overloaded) {
      LinearGradient(
        colors: [SoloTheme.amber.opacity(0.30), .clear],
        startPoint: .bottom,
        endPoint: .center
      )
    } else if input.conditionModifiers.contains(.stressed) {
      LinearGradient(
        colors: [SoloTheme.amber.opacity(0.16), .clear],
        startPoint: .bottom,
        endPoint: .center
      )
    }
  }

  /// Slow breathing depth. Stress and overload reduce motion confidence rather
  /// than adding new motion.
  private var depth: CGFloat {
    let base: CGFloat = 1.05
    guard !input.reduceMotion, !input.conditionModifiers.contains(.resting) else {
      return input.conditionModifiers.contains(.resting) ? 1.02 : base
    }
    let amplitude = confidence * (input.activity == .working ? 0.014 : 0.007)
    let rate = input.activity == .working ? 2.1 : 0.8
    let posture: CGFloat = input.activity == .assignmentReceived ? 0.045 : 0
    return base + posture + amplitude * CGFloat(sin(time * rate))
  }

  /// Controlled crop parallax that expresses where attention is directed.
  private var parallaxX: CGFloat {
    guard !input.reduceMotion else { return staticPosture }
    return staticPosture + 0.5 * confidence * CGFloat(sin(time * 0.55))
  }

  private var staticPosture: CGFloat {
    switch input.activity {
    // Working turns toward the role monitor at the front of the bay.
    case .working: 2.2
    // Completed work and review turn attention back toward Founder Command.
    case .workComplete, .awaitingReview, .reviewing, .reviewed: -2.4
    case .resolving, .resolved: -1.4
    default: 0
    }
  }

  private var parallaxY: CGFloat {
    guard !input.reduceMotion, !input.conditionModifiers.contains(.resting) else {
      return input.conditionModifiers.contains(.resting) ? 1.5 : 0
    }
    return 0.7 * confidence * CGFloat(sin(time * 0.8))
  }

  private var confidence: CGFloat {
    if input.conditionModifiers.contains(.overloaded) { return 0.35 }
    if input.conditionModifiers.contains(.stressed) { return 0.6 }
    return 1
  }

  /// One-shot earned celebration. The trigger is a level-up, not a loop.
  private var celebration: CGFloat {
    guard input.levelUpTrigger > 0, !input.reduceMotion else { return 1 }
    return 1.04
  }

  private var rimColor: Color {
    if input.conditionModifiers.contains(.overloaded) { return SoloTheme.amber }
    switch input.postReviewSignal {
    case .verified: return SoloTheme.mint
    case .overclaimed: return SoloTheme.coral
    case .driftDetected: return SoloTheme.purple
    case .evidenceIncomplete: return SoloTheme.amber
    case .pending: return accent.opacity(0.65)
    }
  }

  private var rimWidth: CGFloat {
    input.postReviewSignal == .pending && !input.conditionModifiers.contains(.overloaded) ? 1 : 2
  }
}

// MARK: - Workstation bay

private struct ViewportAgentStation: View {
  var agent: LivingAgentProjection
  var time: TimeInterval
  var reduceMotion: Bool
  var dimmed: Bool
  var prominence: Double
  var dominant: Bool
  var structure: FacilityStructureProjection
  var confidence: Double
  var signalIntegrity: Double
  var action: () -> Void

  private var accent: Color { SoloAgentAccent.color(agent.agentID) }

  var body: some View {
    Button(action: action) {
      ZStack {
        stationBay
        // The portrait absorbs the remaining height so the labels and the role
        // monitor always fit inside the bay at any viewport size.
        VStack(spacing: 3) {
          ZStack {
            LivingAgentCharacterView(
              input: CharacterRendererInput.derive(agent: agent, reduceMotion: reduceMotion),
              accent: accent,
              time: time
            )
            conditionBadge
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
              .padding(4)
          }
          .frame(maxHeight: .infinity)
          .padding(.horizontal, 6)

          Text(agent.name)
            .font(.caption.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
          Text(overviewState)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
          conditionTreatment
          RoleSpecificWorkSurface(
            agent: agent,
            accent: accent,
            time: time,
            reduceMotion: reduceMotion,
            signalIntegrity: signalIntegrity,
            confidence: confidence
          )
          .frame(height: 30)
          .padding(.horizontal, 4)
        }
        .padding(.vertical, 5)
        if agent.conditions.contains(.overloaded) {
          // Overload uses a stronger warning frame in addition to text and
          // symbol. No flashing, shaking, or flicker.
          bayShape
            .stroke(SoloTheme.amber, style: StrokeStyle(lineWidth: 2.5, dash: [6, 3]))
        }
      }
    }
    .buttonStyle(SoloPressStyle(scale: 0.96))
    .frame(minWidth: 44, minHeight: 44)
    .opacity(dimmed ? 0.42 : prominence)
    .scaleEffect(dominant && !reduceMotion ? max(scale, 1.03) : scale)
    .shadow(color: dominant ? accent.opacity(0.35) : .clear, radius: 10, y: 3)
    .accessibilityLabel("\(agent.name), \(agent.role.rawValue) station")
    .accessibilityValue(agent.accessibilityValue)
    .accessibilityHint("Focuses \(agent.name) inside Company Command without scrolling")
  }

  private var bayShape: UnevenRoundedRectangle {
    UnevenRoundedRectangle(
      topLeadingRadius: structure.bayCornerRadius,
      bottomLeadingRadius: 3,
      bottomTrailingRadius: 3,
      topTrailingRadius: structure.mountStyle == .improvised
        ? structure.bayCornerRadius * 2
        : structure.bayCornerRadius
    )
  }

  private var stationBay: some View {
    bayShape
      .fill(
        LinearGradient(
          colors: [accent.opacity(dominant ? 0.22 : 0.10), .black.opacity(0.78)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .overlay {
        bayShape.stroke(
          strokeColor.opacity(dominant ? 0.9 : 0.34),
          lineWidth: dominant ? structure.frameEdgeWeight + 0.5 : max(1, structure.frameEdgeWeight - 1.5)
        )
      }
      .overlay(alignment: .bottom) {
        Rectangle().fill(strokeColor.opacity(0.8)).frame(height: dominant ? 3 : 1)
      }
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

  @ViewBuilder
  private var conditionBadge: some View {
    if agent.conditions.contains(.overloaded) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(SoloTheme.amber)
        .accessibilityHidden(true)
    } else if agent.conditions.contains(.verified) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(SoloTheme.mint)
        .accessibilityHidden(true)
    } else if !agent.conditions.intersection([.overclaimed, .drifting, .evidenceIncomplete]).isEmpty {
      Image(systemName: "waveform.badge.exclamationmark")
        .foregroundStyle(SoloTheme.coral)
        .accessibilityHidden(true)
    } else if agent.activity == .resting {
      Image(systemName: "bed.double.fill")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
  }

  private var conditionTreatment: some View {
    Group {
      if agent.emphasis == .levelUpCelebration {
        // A short earned celebration: text plus symbol, then settlement.
        Label("LEVEL \(agent.level) EARNED", systemImage: "star.fill")
          .foregroundStyle(SoloTheme.mint)
      } else if let condition = primaryCondition {
        Label(condition.label, systemImage: conditionSymbol(condition))
          .foregroundStyle(conditionColor(condition))
      } else if agent.activity == .assignmentReceived {
        Label("Acknowledged", systemImage: "checkmark.message.fill").foregroundStyle(accent)
      } else if agent.activity == .resting {
        Label("Recovery active", systemImage: "bed.double.fill").foregroundStyle(.secondary)
      }
    }
    .font(.system(size: 8, weight: .black, design: .monospaced))
    .lineLimit(1)
    .minimumScaleFactor(0.7)
    .frame(maxWidth: .infinity, minHeight: 11)
  }

  private var primaryCondition: LivingAgentCondition? {
    let precedence: [LivingAgentCondition] = [
      .overloaded, .overclaimed, .drifting, .evidenceIncomplete, .verified, .stressed
    ]
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
    case .verified: SoloTheme.mint
    case .focused: accent
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
    if !agent.conditions.intersection([.overclaimed, .drifting, .evidenceIncomplete]).isEmpty {
      return SoloTheme.coral
    }
    return accent
  }

  private var strokeColor: Color {
    switch agent.emphasis {
    case .normal: accent.opacity(0.30)
    case .selected: accent
    case .founderAttention: SoloTheme.amber
    case .inspection: SoloTheme.cyan
    case .decisionLock: SoloTheme.mint
    case .levelUpCelebration: accent
    }
  }
}

/// The role monitor and work surface at the front of each bay. It is also the
/// dock target for an inbound assignment document.
private struct RoleSpecificWorkSurface: View {
  var agent: LivingAgentProjection
  var accent: Color
  var time: TimeInterval
  var reduceMotion: Bool
  var signalIntegrity: Double
  var confidence: Double

  private var active: Bool { agent.activity == .working || agent.activity == .assignmentReceived }
  private var motionPhase: Double {
    reduceMotion || !active ? 0 : time.truncatingRemainder(dividingBy: 1.4) / 1.4
  }

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(.black.opacity(agent.activity == .resting ? 0.52 : 0.82))
        roleArtwork
          .padding(.horizontal, 4)
          .opacity((agent.activity == .resting ? 0.30 : 1) * signalIntegrity)
        if agent.activity == .reviewing {
          Rectangle()
            .fill(LinearGradient(
              colors: [.clear, SoloTheme.cyan.opacity(0.75), .clear],
              startPoint: .leading,
              endPoint: .trailing
            ))
            .frame(width: 20)
            .offset(x: reduceMotion ? 0 : CGFloat(motionPhase * 54 - 27))
        }
      }
      .frame(maxHeight: .infinity)
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
          path.move(to: CGPoint(x: 6, y: 13))
          path.addLine(to: CGPoint(x: 25, y: 5))
          path.addLine(to: CGPoint(x: 48, y: 14))
          path.addLine(to: CGPoint(x: 70, y: 6))
        }
        .stroke(accent.opacity(active ? 0.8 : 0.25), lineWidth: 1)
        HStack {
          ForEach(0..<4, id: \.self) { index in
            Circle()
              .fill(index == Int(motionPhase * 4) ? .white : accent)
              .frame(width: 5, height: 5)
            if index < 3 { Spacer() }
          }
        }
      }
    case .engineering:
      HStack(spacing: 3) {
        ForEach(0..<4, id: \.self) { index in
          RoundedRectangle(cornerRadius: 2)
            .fill(Double(index + 1) / 4 <= agent.progress ? accent : accent.opacity(0.18))
            .frame(height: CGFloat(8 + index * 3))
            .overlay {
              Text("\(index + 1)").font(.system(size: 5, weight: .black)).foregroundStyle(.black)
            }
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
      HStack {
        ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.5)) }
      }
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

// MARK: - Founder foreground

private struct FounderCommandStation: View {
  var activeCount: Int
  var reviewCount: Int
  var pressure: CompanyAtmosphere.Pressure
  var deskProfile: FacilityStructureProjection.DeskProfile
  var lightLevel: Double
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "command")
          .font(.headline.weight(.black))
          .foregroundStyle(SoloTheme.amber.opacity(0.45 + 0.55 * lightLevel))
          .frame(width: 32, height: 32)
          .background(SoloTheme.amber.opacity(0.12 * lightLevel), in: .rect(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 1) {
          Text("FOUNDER COMMAND")
            .font(.system(size: 10, weight: .black))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          Text(reviewCount > 0
            ? "\(reviewCount) artifact\(reviewCount == 1 ? "" : "s") in review tray"
            : "\(activeCount) active station\(activeCount == 1 ? "" : "s")")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(reviewCount > 0 ? SoloTheme.amber : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        Spacer(minLength: 2)
        // The review tray. Returning artifacts settle here.
        ZStack {
          RoundedRectangle(cornerRadius: 6)
            .fill(.black.opacity(0.8))
            .frame(width: 30, height: 26)
          RoundedRectangle(cornerRadius: 6)
            .stroke(reviewCount > 0 ? SoloTheme.amber : .white.opacity(0.28), lineWidth: reviewCount > 0 ? 1.8 : 1)
            .frame(width: 30, height: 26)
          Image(systemName: reviewCount > 0 ? "tray.full.fill" : "tray")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(reviewCount > 0 ? SoloTheme.amber : .secondary)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(.black.opacity(0.86), in: .rect(cornerRadius: deskProfile == .refined ? 13 : 6))
      .overlay {
        RoundedRectangle(cornerRadius: deskProfile == .refined ? 13 : 6)
          .stroke(
            SoloTheme.amber.opacity((reviewCount > 0 ? 0.9 : 0.35) * (0.4 + 0.6 * lightLevel)),
            lineWidth: deskProfile == .refined ? 1 : 2
          )
      }
    }
    .buttonStyle(SoloPressStyle())
    .frame(minHeight: 44)
    .accessibilityLabel("Founder command station")
    .accessibilityValue(reviewCount > 0
      ? "\(reviewCount) artifacts await Founder attention"
      : "\(activeCount) agents active. Company pressure: \(pressure.rawValue)")
    .accessibilityHint("Focuses Founder command inside the viewport without scrolling")
  }
}

// MARK: - Causal objects

/// Three visibly distinct object families travelling between stable anchors.
/// Endpoints persist so Reduce Motion communicates the same causal result.
private struct CausalJourney: View {
  var object: CompanyCausalObject
  var accent: Color
  var start: CGPoint
  var end: CGPoint
  var lane: Int
  var laneCount: Int
  var time: TimeInterval
  var reduceMotion: Bool
  var increasedContrast: Bool

  var body: some View {
    ZStack(alignment: .topLeading) {
      if !object.atEndpoint {
        trail
      }
      if !(object.atEndpoint && object.kind == .assignmentPacket) {
        // The docked assignment marker is deliberately small enough that it
        // never needs the full endpoint ring; every other settled state keeps it.
        endpointMarker.position(end)
      }
      // A settled object tucks into the station monitor, the Founder tray, or
      // the company system it landed on instead of covering the label there.
      causalObjectView
        .scaleEffect(settledScale)
        .position(object.atEndpoint ? settledPoint : journeyPoint)
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

  private var trail: some View {
    Path { path in
      path.move(to: start)
      path.addQuadCurve(to: end, control: controlPoint)
    }
    .trim(from: max(0, progress - 0.28), to: progress)
    .stroke(
      journeyColor.opacity(increasedContrast ? 0.95 : 0.8),
      style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dash)
    )
  }

  private var endpointMarker: some View {
    Circle()
      .stroke(journeyColor.opacity(object.atEndpoint ? 0.9 : 0.35), lineWidth: object.atEndpoint ? 2.5 : 2)
      .frame(width: object.atEndpoint ? 30 : 28, height: object.atEndpoint ? 30 : 28)
      .overlay { Circle().fill(journeyColor.opacity(object.atEndpoint ? 0.14 : 0.05)).padding(4) }
  }

  /// A docked assignment sits directly on its stable anchor, which is already
  /// tucked into the lower edge of the role-specific work surface.
  private var settledPoint: CGPoint { end }

  /// The docked assignment badge is deliberately tiny — a resting indicator on
  /// the console, not a focal object — so it never competes with the task
  /// title or the work surface's own progress pips.
  private var settledScale: CGFloat {
    guard object.atEndpoint else { return 1 }
    return object.kind == .assignmentPacket ? 0.34 : 0.66
  }

  private var progress: CGFloat {
    guard !object.atEndpoint, !reduceMotion else { return 1 }
    let duration = max(0.2, object.travelDuration)
    return CGFloat(time.truncatingRemainder(dividingBy: duration) / duration)
  }

  /// Each agent gets a stable lane so concurrent paths never tangle.
  private var laneBend: CGFloat {
    let spread = CGFloat(max(1, laneCount - 1))
    let normalized = (CGFloat(lane) - spread / 2) / max(1, spread)
    return normalized * 26
  }

  private var controlPoint: CGPoint {
    CGPoint(x: (start.x + end.x) / 2 + bend + laneBend, y: min(start.y, end.y) - 18)
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

  @ViewBuilder
  private var causalObjectView: some View {
    switch object.kind {
    case .assignmentPacket: assignmentDocument
    case .completedArtifact: deliverableContainer
    case .resolutionResponse: decisionSeal
    }
  }

  /// Role-colored document with a task glyph.
  private var assignmentDocument: some View {
    ZStack {
      UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 10)
        .fill(.black.opacity(0.95))
        .frame(width: 28, height: 34)
      UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 10)
        .stroke(journeyColor, lineWidth: 2)
        .frame(width: 28, height: 34)
      VStack(spacing: 2) {
        Image(systemName: "checklist")
          .font(.system(size: 11, weight: .black))
          .foregroundStyle(journeyColor)
        Rectangle().fill(journeyColor.opacity(0.6)).frame(width: 14, height: 1.5)
        Rectangle().fill(journeyColor.opacity(0.4)).frame(width: 10, height: 1.5)
      }
    }
    .shadow(color: journeyColor.opacity(0.6), radius: reduceMotion ? 0 : 6)
  }

  /// Mint deliverable container with a completion mark.
  private var deliverableContainer: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5)
        .fill(.black.opacity(0.95))
        .frame(width: 40, height: 30)
      RoundedRectangle(cornerRadius: 5)
        .stroke(journeyColor, lineWidth: 2.5)
        .frame(width: 40, height: 30)
      Rectangle().fill(journeyColor.opacity(0.55)).frame(width: 40, height: 2).offset(y: -6)
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 13, weight: .black))
        .foregroundStyle(journeyColor)
        .offset(y: 3)
    }
    .shadow(color: journeyColor.opacity(0.6), radius: reduceMotion ? 0 : 6)
  }

  /// Purple decision seal with a visibly different silhouette.
  private var decisionSeal: some View {
    ZStack {
      Circle().fill(.black.opacity(0.95)).frame(width: 32, height: 32)
      ForEach(0..<8, id: \.self) { index in
        Capsule()
          .fill(journeyColor)
          .frame(width: 3, height: 7)
          .offset(y: -17)
          .rotationEffect(.degrees(Double(index) * 45))
      }
      Circle().stroke(journeyColor, lineWidth: 2).frame(width: 30, height: 30)
      Image(systemName: "seal.fill")
        .font(.system(size: 13, weight: .black))
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

  private var dash: [CGFloat] {
    switch object.kind {
    case .assignmentPacket: []
    case .completedArtifact: []
    case .resolutionResponse: [3, 6]
    }
  }

  private var lineWidth: CGFloat {
    switch object.kind {
    case .assignmentPacket: 3.5
    case .completedArtifact: 5
    case .resolutionResponse: 4
    }
  }
}

// MARK: - Founder review

/// Five visually distinct purposes over the same spatial scene. Hidden truth is
/// admitted only after the canonical fifth reveal step.
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
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer(minLength: 6)
        Text(agent.name)
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      HStack(spacing: 10) {
        artifact
        VStack(alignment: .leading, spacing: 3) {
          Text(agent.activity == .reviewed ? "INSPECTION COMPLETE" : "STEP \(step) OF 5")
            .font(.caption2.monospacedDigit().weight(.black))
            .foregroundStyle(displayColor)
            .lineLimit(1)
          // The result title must never truncate.
          Label(displayTitle, systemImage: agent.activity == .reviewed ? resultSymbol : stepSymbol)
            .font(.subheadline.weight(.black))
            .foregroundStyle(agent.activity == .reviewed ? displayColor : .primary)
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .fixedSize(horizontal: false, vertical: true)
          Text(displayPurpose)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack(spacing: 5) {
        ForEach(1...5, id: \.self) { index in
          VStack(spacing: 2) {
            Image(systemName: symbol(for: index))
              .font(.caption2.weight(.black))
              .foregroundStyle(index <= step ? color(for: index) : .secondary.opacity(0.35))
            Rectangle()
              .fill(index <= step ? color(for: index) : .secondary.opacity(0.22))
              .frame(height: index == step ? 2.5 : 1)
          }
          .frame(maxWidth: .infinity, minHeight: 26)
          .padding(.vertical, 2)
          .background(index == step ? color(for: index).opacity(0.15) : .clear, in: .rect(cornerRadius: 6))
        }
      }
    }
    .padding(11)
    .background(.black.opacity(0.95), in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(displayColor, lineWidth: 2) }
    .shadow(color: displayColor.opacity(0.40), radius: reduceMotion ? 0 : 14)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Founder inspection for \(agent.name), step \(step) of 5, \(stepTitle)")
    .accessibilityValue(agent.activity == .reviewed ? displayTitle : "Result not yet revealed")
  }

  private var artifact: some View {
    ZStack {
      resultShape
      Image(systemName: resultSymbol)
        .font(.title3.weight(.black))
        .foregroundStyle(resultColor)
      Rectangle()
        .fill(SoloTheme.cyan.opacity(0.50))
        .frame(height: 2)
        .offset(y: reduceMotion ? 0 : CGFloat(sin(time * 2.2)) * 20)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .frame(width: 64, height: 62)
  }

  @ViewBuilder private var resultShape: some View {
    switch result {
    case .pending:
      RoundedRectangle(cornerRadius: 12)
        .fill(SoloTheme.cyan.opacity(0.12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(SoloTheme.cyan, lineWidth: 2) }
    case .verified:
      Circle()
        .fill(SoloTheme.mint.opacity(0.15))
        .overlay { Circle().stroke(SoloTheme.mint, lineWidth: 3) }
    case .overclaimed:
      RoundedRectangle(cornerRadius: 3)
        .fill(SoloTheme.coral.opacity(0.16))
        .overlay {
          RoundedRectangle(cornerRadius: 3)
            .stroke(SoloTheme.coral, style: StrokeStyle(lineWidth: 3, dash: [7, 3]))
        }
    case .driftDetected:
      Capsule()
        .fill(SoloTheme.purple.opacity(0.16))
        .overlay { Capsule().stroke(SoloTheme.purple, style: StrokeStyle(lineWidth: 3, dash: [2, 5])) }
    case .evidenceIncomplete:
      UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 2, topTrailingRadius: 2)
        .fill(SoloTheme.amber.opacity(0.16))
        .overlay {
          UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, bottomTrailingRadius: 2, topTrailingRadius: 2)
            .stroke(SoloTheme.amber, lineWidth: 3)
        }
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
    [
      "chart.bar.doc.horizontal.fill",
      "point.3.connected.trianglepath.dotted",
      "checkmark.shield.fill",
      "arrow.left.arrow.right.square.fill",
      "exclamationmark.triangle.fill"
    ][step - 1]
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
