import SwiftUI

/// The single vertical scrolling owner for the playable Founder Computer.
struct FounderComputerScreen: View {
  var store: GameStore
  var presentation: PresentationCoordinator

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var selectedAgentID: String?
  @State private var assignmentDestination: AssignmentDestination?
  @State private var restCandidate: RestCandidate?
  @State private var evidenceExpanded = false
  @State private var resolutionTick = 0
  // Presentation-only choreography. None of these values participate in the
  // deterministic simulation or are persisted in a save.
  @State private var assignmentArrivalAgentID: String?
  @State private var activeReviewTaskID: UUID?
  @State private var reviewStage = 0
  @State private var resolutionFocus: TaskResolutionChoice?
  @State private var commitPulse = false
  @State private var evidencePulse = false
  @State private var hasPresentedRoster = false
  @State private var commitInProgress = false
  #if DEBUG
  @State private var showsMotionVerification = false
  #endif

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 16) {
          hud.founderEntrance(order: 0, alreadyPresented: hasPresentedRoster)
          FounderWorkstationCard(
            store: store,
            presentation: presentation,
            expanded: selectedAgentID == nil,
            commitInProgress: commitInProgress,
            onSelect: selectFounder,
            onSelectAgent: beginReviewFocus,
            onCommit: commit
          )
          .id("founder")
          .founderEntrance(order: 1, alreadyPresented: hasPresentedRoster)
          ForEach(orderedStations) { station in
            workspaceCard(for: station)
            .id(station.id)
            .opacity(isReviewFocused && selectedAgentID != station.agentID ? 0.86 : 1)
            .founderEntrance(order: rank(station.agentID) + 2, alreadyPresented: hasPresentedRoster)
          }
          evidenceDrawer.founderEntrance(order: 5, alreadyPresented: hasPresentedRoster)
          HindsightArchiveCard(
            precedents: store.precedents,
            divergences: store.divergenceRecords
          )
          .founderEntrance(order: 6, alreadyPresented: hasPresentedRoster)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .safeAreaPadding(.bottom, 96)
      .onAppear {
        guard !hasPresentedRoster else { return }
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(1))
          hasPresentedRoster = true
        }
      }
      .onChange(of: selectedAgentID) { _, id in
        guard let id else { return }
        withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) { proxy.scrollTo(id, anchor: .center) }
      }
      .onChange(of: presentation.latestEvent) { _, event in
        guard case .assignment(_, _, let agentID, _) = event else { return }
        selectedAgentID = agentID
        withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) {
          proxy.scrollTo(agentID, anchor: .center)
        }
      }
    }
    .sensoryFeedback(.selection, trigger: selectedAgentID)
    .sensoryFeedback(.success, trigger: store.sprint)
    .sensoryFeedback(.impact(weight: .light), trigger: resolutionTick)
    .sensoryFeedback(.impact(weight: .medium), trigger: assignmentArrivalAgentID)
    .sensoryFeedback(.success, trigger: activeReviewTaskID)
    .onChange(of: presentation.latestEvent?.id) { _, _ in handlePresentationEvent() }
    .sheet(item: $assignmentDestination) { destination in
      TaskAssignmentSheet(store: store, presentation: presentation, agentID: destination.agentID) {
        assignmentDestination = nil
        announce("Assignment updated.")
      }
    }
    #if DEBUG
    .sheet(isPresented: $showsMotionVerification) {
      MotionVerificationScreen(presentation: presentation)
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Motion QA", systemImage: "waveform.path.ecg") {
          showsMotionVerification = true
        }
        .labelStyle(.iconOnly)
        .accessibilityHint("Opens presentation-only animation verification")
      }
    }
    #endif
    .confirmationDialog("Rest this sprint?", isPresented: Binding(
      get: { restCandidate != nil },
      set: { if !$0 { restCandidate = nil } }
    ), titleVisibility: .visible) {
      if let candidate = restCandidate {
        Button("Rest \(candidate.name)", role: .destructive) {
          withAnimation(MotionKind.state.resolved(reduceMotion: reduceMotion)) { store.restAgent(agentID: candidate.agentID) }
          announce("\(candidate.name) will rest this sprint.")
          restCandidate = nil
        }
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text(restCandidate?.hasAssignment == true ? "Rest clears the unreviewed assignment. The agent performs no task and recovers stress when the sprint commits." : "The agent performs no task and recovers stress when the sprint commits.")
    }
  }

  private func handlePresentationEvent() {
    guard let event = presentation.latestEvent else { return }
    switch event {
    case .assignment(_, _, let agentID, _):
      selectedAgentID = agentID
      assignmentArrivalAgentID = agentID
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(520))
        assignmentArrivalAgentID = nil
      }
    case .review(_, let taskID, let agentID, _, let evidenceChanged):
      selectedAgentID = agentID
      activeReviewTaskID = taskID
      reviewStage = reduceMotion ? 5 : 1
      if evidenceChanged { evidencePulse.toggle() }
      guard !reduceMotion else { return }
      Task { @MainActor in
        for stage in 2...5 {
          try? await Task.sleep(for: .milliseconds(320))
          guard activeReviewTaskID == taskID else { return }
          withAnimation(SoloMotion.arrival) { reviewStage = stage }
        }
      }
    case .sprint:
      commitPulse.toggle()
    }
  }

  private var orderedStations: [AgentStationViewModel] {
    store.agents.map { agent in
      AgentStationViewModel.derive(
        agent: agent,
        task: task(for: agent.id),
        founderStats: store.stats,
        presentationPhase: presentation.presentation(for: agent.id)?.phase
      )
    }.sorted { rank($0.agentID) < rank($1.agentID) }
  }

  @ViewBuilder
  private func workspaceCard(for station: AgentStationViewModel) -> some View {
    let agentID = station.agentID
    let assignedTask = task(for: agentID)
    let isSelected = selectedAgentID == agentID
    let currentReviewStage = activeReviewTaskID == assignedTask?.id ? reviewStage : 0
    AgentWorkspaceCard(
      station: station,
      agent: agent(for: agentID),
      task: assignedTask,
      presentation: presentation.presentation(for: agentID),
      isResting: store.restingAgentIDs.contains(agentID),
      selected: isSelected,
      assignmentArrival: assignmentArrivalAgentID == agentID,
      reviewStage: currentReviewStage,
      resolutionFocus: resolutionFocus,
      reduceMotion: reduceMotion,
      action: { select(agentID) },
      onAssign: { assignmentDestination = .init(agentID: agentID) },
      onReview: { review(agentID) },
      onRest: { restCandidate = .init(agentID: agentID, name: station.name, hasAssignment: assignedTask != nil) },
      onResolve: { choice in guard let taskID = assignedTask?.id else { return }; resolve(taskID: taskID, choice: choice) },
      canAssign: canAssign,
      canReview: canReview(agentID),
      canRest: canRest(agentID)
    )
  }

  private var hud: some View {
    VStack(alignment: .leading, spacing: 10) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 8) {
            hudTitle
            hudPhase
          }
        } else {
          HStack {
            hudTitle
            Spacer()
            hudPhase
          }
        }
      }
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          LazyVGrid(columns: accessibilityMetricColumns, alignment: .leading, spacing: 8) {
            hudMetrics
          }
        } else {
          HStack(spacing: 8) {
            hudMetrics
          }
        }
      }
      Text("Venture \(store.venture) · Sprint \(store.sprint)/12 · \(store.chapter.name)").font(.caption).foregroundStyle(.secondary)
    }
    .padding(14).background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .scaleEffect(commitPulse && !reduceMotion ? 1.012 : 1)
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.cyan.opacity(commitPulse ? 0.7 : 0), lineWidth: 1.5) }
    .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: commitPulse)
    .gameplayMotion(value: store.sprintPhase)
  }

  private var hudTitle: some View {
    Text("FOUNDER COMPUTER")
      .font(.caption.weight(.bold))
      .foregroundStyle(SoloTheme.cyan)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var hudPhase: some View {
    Label(store.sprintPhase.title, systemImage: store.sprintPhase.symbol)
      .font(.caption.weight(.bold))
      .fixedSize(horizontal: false, vertical: true)
      .contentTransition(.interpolate)
      .symbolEffect(.bounce, value: store.sprintPhase)
      .id(store.sprintPhase)
      .transition(.opacity.combined(with: .move(edge: .trailing)))
  }

  @ViewBuilder private var hudMetrics: some View {
    HUDMetricView(label: "Runway", value: store.stats.runway, unit: "d", symbol: "calendar")
    HUDMetricView(label: "Energy", value: store.stats.energy, symbol: "battery.75percent")
    HUDMetricView(label: "Momentum", value: store.stats.momentum, symbol: "arrow.up.right")
    HUDMetricView(label: "Attention", value: store.attentionRemaining, maximum: store.attentionMaximum, symbol: "eye")
  }

  private var accessibilityMetricColumns: [GridItem] {
    [GridItem(.flexible(), alignment: .leading)]
  }

  private var evidenceDrawer: some View {
    EvidenceDrawerView(evidence: store.evidence, isExpanded: $evidenceExpanded)
  }

  private var isReviewFocused: Bool {
    guard let selectedAgentID,
          let phase = presentation.presentation(for: selectedAgentID)?.phase else { return false }
    return phase == .reviewing
  }

  private func beginReviewFocus(_ id: String) {
    select(id)
  }

  private var canAssign: Bool { store.sprintPhase == .chooseCommitments || store.sprintPhase == .assignTeam }
  private func canReview(_ id: String) -> Bool {
    guard let task = task(for: id) else { return false }
    let phase = presentation.presentation(for: id)?.phase
    let presentationReady = phase == nil || phase == .awaitingReview
    return presentationReady && store.sprintPhase == .reviewAndResolve && !task.isReviewed && task.result != nil && store.attentionRemaining > 0
  }
  private func canRest(_ id: String) -> Bool { (store.sprintPhase == .chooseCommitments || store.sprintPhase == .assignTeam) && !store.restingAgentIDs.contains(id) }
  private func task(for agentID: String) -> SoloTask? { store.tasks.first { $0.assignedAgentID == agentID } }
  private func agent(for id: String) -> SoloAgent? { store.agents.first { $0.id == id } }
  private func rank(_ id: String) -> Int { ["aurora", "stacks", "brio"].firstIndex(of: id) ?? 100 + (store.agents.firstIndex { $0.id == id } ?? 0) }

  private func select(_ id: String) {
    withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) { selectedAgentID = id }
    announce("\(agent(for: id)?.name ?? "Agent") selected.")
  }

  private func selectFounder() {
    withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) { selectedAgentID = nil }
    announce("Founder workstation selected.")
  }

  private func review(_ id: String) {
    guard let task = task(for: id) else { return }
    selectedAgentID = id
    withAnimation(SoloMotion.resolved(SoloMotion.focus, reduceMotion: reduceMotion)) {
      activeReviewTaskID = task.id
      reviewStage = 0
    }
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(150)) }
      presentation.review(taskID: task.id, in: store)
    }
    announce("Founder review started.")
  }

  private func resolve(taskID: UUID, choice: TaskResolutionChoice) {
    resolutionFocus = choice
    resolutionTick += 1
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      presentation.resolve(taskID: taskID, choice: choice, in: store)
    }
    announce("\(choice.title) selected.")
  }

  private func commit() {
    guard !commitInProgress, store.canCommitSprint else { return }
    commitInProgress = true
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      presentation.commit(in: store, progression: progression)
    }
    announce("Sprint committed. Company metrics updated for sprint \(store.sprint).")
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(700))
      commitInProgress = false
    }
  }

  /// Speaks the outcome of an action that VoiceOver would otherwise have to
  /// discover by exploring the screen again.
  private func announce(_ text: String) {
    AccessibilityNotification.Announcement(text).post()
  }
}

private struct AssignmentDestination: Identifiable { var agentID: String; var id: String { agentID } }
private struct RestCandidate: Identifiable { var agentID: String; var name: String; var hasAssignment: Bool; var id: String { agentID } }

private struct AgentPortrait: View {
  var agentID: String
  var initials: String
  var name: String
  var accent: Color
  var state: AgentStationViewModel.SemanticState
  var selected: Bool
  var reduceMotion: Bool

  private var assetName: String? { AgentPortraitAsset.name(for: agentID) }
  private var image: UIImage? { assetName.flatMap(UIImage.init(named:)) }
  private var attentionState: Bool { state == .awaitingReview || state == .overloaded }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18)
        .fill(accent.opacity(0.18))
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .accessibilityHidden(true)
      } else {
        Text(initials).font(.headline.weight(.heavy)).foregroundStyle(accent)
      }
    }
    .frame(width: selected ? 116 : 64, height: selected ? 116 : 64)
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(selected ? 0.95 : 0.5), lineWidth: selected ? 2 : 1) }
    .shadow(color: accent.opacity(selected ? 0.42 : 0.14), radius: selected ? 10 : 4)
    .scaleEffect(attentionState && !reduceMotion ? 1.02 : 1)
    .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: state)
    .accessibilityLabel("\(name), \(agentID == "aurora" ? "Research and Evidence" : agentID == "stacks" ? "Engineering and Execution" : "Growth and Campaigns") agent")
  }
}

struct AgentWorkspaceCard: View {
  var station: AgentStationViewModel
  var agent: SoloAgent?
  var task: SoloTask?
  var presentation: PresentationCoordinator.AgentPresentation?
  var isResting: Bool
  var selected: Bool
  var assignmentArrival: Bool
  var reviewStage: Int
  var resolutionFocus: TaskResolutionChoice?
  var reduceMotion: Bool
  var action: () -> Void
  var onAssign: () -> Void
  var onReview: () -> Void
  var onRest: () -> Void
  var onResolve: (TaskResolutionChoice) -> Void
  var canAssign: Bool
  var canReview: Bool
  var canRest: Bool
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var accent: Color { switch station.agentID { case "aurora": SoloTheme.cyan; case "stacks": SoloTheme.amber; case "brio": SoloTheme.coral; default: SoloTheme.mint } }

  var body: some View {
    VStack(alignment: .leading, spacing: selected ? 16 : 12) {
      identity
      attributes
      assignmentSummary
      if selected {
        expandedContent.transition(.opacity.combined(with: .move(edge: .bottom)))
      } else {
        compactWorkspace
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(accent.opacity(selected ? 0.20 : 0.07), in: .rect(cornerRadius: 22))
    .overlay { RoundedRectangle(cornerRadius: 22).stroke(selected ? accent : .white.opacity(0.09), lineWidth: selected ? 2.5 : 1) }
    .shadow(color: selected ? accent.opacity(0.30) : .clear, radius: selected ? 14 : 0, y: selected ? 7 : 0)
    .contentShape(.rect(cornerRadius: 22))
    .onTapGesture(perform: action)
    .scaleEffect(cardScale)
    .phaseAnimator([0, 1, 2], trigger: selected) { content, phase in
      content.scaleEffect(!reduceMotion && selected && phase == 1 ? 1.035 : 1)
    } animation: { phase in
      phase == 1 ? .snappy(duration: 0.14) : .smooth(duration: 0.2)
    }
    .gameplayMotion(.emphasis, value: selected)
    .gameplayMotion(value: WorkSnapshot(taskID: task?.id, hasResult: task?.result != nil, reviewed: task?.isReviewed ?? false, state: station.semanticState, resting: isResting))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(station.name), \(station.role.rawValue) agent")
    .accessibilityValue(station.accessibilityValue)
    .accessibilityHint("Select this agent workspace")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { action() }
  }

  /// The work state this card animates on: a new assignment, a delivered
  /// result, a completed review, or a change of station status.
  private struct WorkSnapshot: Equatable {
    var taskID: UUID?; var hasResult: Bool; var reviewed: Bool
    var state: AgentStationViewModel.SemanticState; var resting: Bool
  }

  private struct StatusSnapshot: Equatable {
    var stress: AgentStressBand; var trust: AgentStationViewModel.TrustBand
  }

  private var identity: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 10) {
          AgentPortrait(agentID: station.agentID, initials: station.initials, name: station.name, accent: accent, state: station.semanticState, selected: selected, reduceMotion: reduceMotion)
          identityText
          statusLabel
        }
      } else {
        HStack {
          AgentPortrait(agentID: station.agentID, initials: station.initials, name: station.name, accent: accent, state: station.semanticState, selected: selected, reduceMotion: reduceMotion)
          identityText
          Spacer()
          statusLabel
        }
      }
    }
    .gameplayMotion(.celebration, value: station.progression.level)
  }

  private var identityText: some View {
    VStack(alignment: .leading) {
      Text(station.name).font(selected ? .title3.weight(.bold) : .headline.weight(.bold))
      HStack(spacing: 3) {
        Text(station.role.rawValue + " · Level ")
        Text(String(station.progression.level)).contentTransition(.numericText(value: Double(station.progression.level)))
      }
      .font(.caption).foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var statusLabel: some View {
    Label(isResting ? "Resting" : effectivePhase.statusLabel, systemImage: isResting ? "bed.double.fill" : station.semanticState.glyph)
      .font(.caption.weight(.bold)).foregroundStyle(accent)
      .fixedSize(horizontal: false, vertical: true)
      .contentTransition(.interpolate)
      .symbolEffect(.bounce, value: station.semanticState)
  }

  private var attributes: some View {
    VStack(alignment: .leading, spacing: 7) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 8) {
            attributeViews
          }
        } else if selected {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            attributeViews
          }
        } else {
          HStack(spacing: 8) {
            compactAttributeViews
          }
        }
      }
      if selected {
        HStack(spacing: 8) {
          Text("LEVEL \(station.progression.level)").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
          ProgressView(value: xpProgress).tint(accent)
          Text(xpProgress.formatted(.percent.precision(.fractionLength(0)))).font(.caption2.monospacedDigit().weight(.bold))
        }
        .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .gameplayMotion(value: StatusSnapshot(stress: station.progression.stressBand, trust: station.trustBand))
  }

  @ViewBuilder private var attributeViews: some View {
    attribute("Stress", station.progression.stressBand.label, "gauge.with.dots.needle.50percent")
    attribute("Trust", "\(Int(station.trust.rounded()))", "checkmark.shield")
    if selected {
      attribute("XP", "\(station.progression.xp)", "sparkles")
      attribute("Focus", station.progression.specialization ?? station.role.rawValue, station.role.symbol)
    }
  }

  @ViewBuilder private var compactAttributeViews: some View {
    attribute("Stress", station.progression.stressBand.label, "gauge.with.dots.needle.50percent")
    attribute("Trust", "\(Int(station.trust.rounded()))", "checkmark.shield")
  }

  private var xpProgress: Double {
    let current = AgentLevel.threshold(forLevel: station.progression.level)
    guard let next = AgentLevel.nextThreshold(forXP: station.progression.xp) else { return 1 }
    return min(1, max(0, Double(station.progression.xp - current) / Double(next - current)))
  }

  private func attribute(_ title: String, _ value: String, _ symbol: String) -> some View {
    Label { VStack(alignment: .leading, spacing: 1) { Text(title.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary); Text(value).font(.caption2.weight(.semibold)).lineLimit(1) } } icon: {
      Image(systemName: symbol).font(.caption2).foregroundStyle(accent)
    }
    .padding(.horizontal, 8).padding(.vertical, 7)
    .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
    .contentTransition(.interpolate)
  }

  private var assignmentSummary: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("CURRENT ASSIGNMENT").font(.caption2.weight(.black)).foregroundStyle(.secondary)
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 6) {
            assignmentHeadline
            assignmentStatus
          }
        } else {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            assignmentHeadline
            Spacer(minLength: 0)
            assignmentStatus
          }
        }
      }
      if selected && effectivePhase == .working { ProgressView(value: presentation?.progress ?? 0.45).tint(accent) }
    }
  }

  private var assignmentHeadline: some View {
    Text(headline)
      .font(.subheadline.weight(.semibold))
      .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : (selected ? 2 : 1))
      .fixedSize(horizontal: false, vertical: true)
  }

  private var assignmentStatus: some View {
    Text(isResting ? "Resting" : effectivePhase.statusLabel)
      .font(.caption2.weight(.bold))
      .foregroundStyle(accent)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var compactWorkspace: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Image(systemName: station.role.symbol).foregroundStyle(accent)
        Text("LIVE WORKSPACE · \(effectivePhase.statusLabel.uppercased())").font(.caption2.monospaced().weight(.bold)).foregroundStyle(accent.opacity(0.85))
        Spacer()
        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      if effectivePhase == .awaitingReview {
        Label("Founder attention required", systemImage: "eye.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(SoloTheme.amber)
      }
    }
    .padding(.top, 2)
  }

  private var expandedContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      LiveWorkspaceSurface(agentID: station.agentID, taskTitle: task?.title, phase: isResting ? .idle : effectivePhase, progress: presentation?.progress ?? (station.semanticState == .working ? 0.45 : 0), reduceMotion: reduceMotion, expanded: true)
      if let task, let result = task.result, canRevealResult {
        VStack(alignment: .leading, spacing: 8) {
          Text("RESULT / EVIDENCE").font(.caption2.weight(.black)).foregroundStyle(.secondary)
          report(result, reviewed: task.isReviewed, revealStep: max(reviewStage, presentation?.reviewRevealStep ?? 5))
        }
        .padding(10)
        .background(resultBackground(result), in: .rect(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
          if effectivePhase == .reviewing {
            Label("INSPECTING", systemImage: "magnifyingglass")
              .font(.caption2.weight(.black))
              .foregroundStyle(accent)
              .padding(8)
          }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
      actions
    }
  }

  private var actions: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        if task == nil && !isResting { cardAction("Assign", "checklist", onAssign, enabled: canAssign) }
        if let task, !task.isReviewed && effectivePhase == .awaitingReview { cardAction("Review", "eye", onReview, enabled: canReview) }
        if !isResting && (task == nil || task?.isReviewed == false) { cardAction("Rest", "bed.double", onRest, enabled: canRest) }
        if task?.resolutionLocked == true { Label("Resolved", systemImage: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(SoloTheme.mint) }
        Spacer(minLength: 0)
      }
      if let task, task.isReviewed { inlineResolution(task) }
    }
    .padding(.top, 2)
  }

  private func cardAction(_ title: String, _ symbol: String, _ operation: @escaping () -> Void, enabled: Bool) -> some View {
    Button(title, systemImage: symbol, action: operation).buttonStyle(.borderedProminent).tint(accent).controlSize(.small).frame(minHeight: 38).disabled(!enabled)
  }

  @ViewBuilder private func inlineResolution(_ task: SoloTask) -> some View {
    if task.resolutionLocked, let resolution = task.resolution {
      Label("\(resolution.title) locked", systemImage: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(SoloTheme.mint)
    } else {
      VStack(alignment: .leading, spacing: 7) {
        Text("FOUNDER RESOLUTION").font(.caption2.weight(.black)).foregroundStyle(.secondary)
        ForEach(TaskResolutionChoice.allCases) { choice in
          Button(choice.title, systemImage: choice.symbol) { onResolve(choice) }
            .buttonStyle(.bordered)
            .tint(resolutionFocus == choice ? SoloTheme.mint : accent)
            .opacity(effectivePhase == .resolving && resolutionFocus != choice ? 0.35 : 1)
            .scaleEffect(effectivePhase == .resolving && resolutionFocus == choice ? 1.03 : 1)
            .disabled(effectivePhase == .resolving)
        }
      }
    }
  }

  private var effectivePhase: PresentationCoordinator.AgentPhase {
    if let presentation { return presentation.phase }
    switch station.semanticState {
    case .idle: return .idle
    case .working: return .working
    case .awaitingReview: return .awaitingReview
    case .drifting, .overloaded, .verified: return task?.isReviewed == true ? .reviewed : .idle
    }
  }

  private var canRevealResult: Bool {
    guard let phase = presentation?.phase else { return true }
    switch phase {
    case .awaitingReview, .reviewing, .reviewed, .resolving, .resolved: return true
    case .idle, .assignmentReceived, .working, .workComplete: return false
    }
  }

  private var cardScale: CGFloat {
    switch effectivePhase {
    case .assignmentReceived: 1.025
    case .reviewing: 1.03
    default: 1
    }
  }

  private var headline: String {
    if let title = task?.title { return title }
    return isResting ? "Recovery sprint selected" : "No task assigned"
  }

  private func verifiedSummary(actual: Int, overclaim: Int) -> String {
    let base = "Verified actual " + String(actual)
    return overclaim > 0 ? base + " · Overclaim +" + String(overclaim) : base
  }

  @ViewBuilder private func report(_ result: TaskResult, reviewed: Bool, revealStep: Int) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      if !reviewed || revealStep >= 1 {
        fact("Reported Quality", value: String(result.reportedQuality), symbol: "chart.bar.fill")
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      if !reviewed || revealStep >= 2 {
        fact("Evidence", value: "\(result.evidenceCompleteness)%", symbol: "doc.text.magnifyingglass")
          .contentTransition(.numericText(value: Double(result.evidenceCompleteness)))
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      if reviewed, revealStep >= 3 {
        VerificationImpact(state: result.verificationState, active: revealStep >= 3, reduceMotion: reduceMotion)
          .transition(.scale(scale: 0.6).combined(with: .opacity))
      }
      if reviewed, revealStep >= 4, let actual = result.revealedActualQuality {
        fact("Verified Actual", value: verifiedSummary(actual: actual, overclaim: result.overclaimAmount), symbol: "checkmark.seal.fill")
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      if !reviewed || revealStep >= 5 {
        fact("Operational Risk", value: result.knownOperationalRisk, symbol: "exclamationmark.shield.fill")
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .animation(MotionKind.state.resolved(reduceMotion: reduceMotion), value: revealStep)
  }

  private func fact(_ title: String, value: String, symbol: String) -> some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        Text(value).font(.caption.weight(.semibold))
      }
    } icon: {
      Image(systemName: symbol).foregroundStyle(accent)
    }
  }

  private func resultBackground(_ result: TaskResult) -> Color {
    guard task?.isReviewed == true else { return accent.opacity(0.08) }
    switch result.verificationState {
    case .confirmed, .verified: return SoloTheme.mint.opacity(0.10)
    default: return SoloTheme.amber.opacity(0.10)
    }
  }
}

private struct TaskAssignmentSheet: View {
  var store: GameStore
  var presentation: PresentationCoordinator
  var agentID: String
  var didFinish: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var assignmentTap = false
  private var agent: SoloAgent? { store.agents.first { $0.id == agentID } }
  var body: some View {
    NavigationStack {
      List {
        ForEach(store.tasks) { task in
          VStack(alignment: .leading, spacing: 7) {
            Text(task.title).font(.headline)
            Text(task.detail).font(.caption).foregroundStyle(.secondary)
            Text("\(task.role.rawValue) · \(task.category.rawValue) · \(task.urgency.label)").font(.caption2)
            Text("Reward: \(task.reward) · If ignored: \(task.consequenceLabel)").font(.caption2).foregroundStyle(SoloTheme.amber)
            HStack {
              Button("Assign") {
                assignmentTap.toggle()
                presentation.assign(agentID: agentID, to: task.id, in: store)
                dismiss()
                didFinish()
              }
              .buttonStyle(.borderedProminent)
              .disabled(task.isReviewed)
              if task.assignedAgentID == agentID && !task.isReviewed {
                Button("Remove", role: .destructive) { presentation.assign(agentID: nil, to: task.id, in: store); dismiss(); didFinish() }.buttonStyle(.bordered)
              }
            }
          }.padding(.vertical, 5)
        }
      }
      .navigationTitle("Assign \(agent?.name ?? "Agent")")
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: assignmentTap)
  }
}

struct FounderWorkstationSummary: Equatable {
  enum Readiness: Equatable {
    case workInProgress
    case founderReviewPending
    case resolutionRequired
    case blocked(String)
    case ready

    var message: String {
      switch self {
      case .workInProgress: "Agent work is still in progress"
      case .founderReviewPending: "Founder review pending"
      case .resolutionRequired: "Resolution required"
      case .blocked(let message): message
      case .ready: "Ready to commit this sprint"
      }
    }
  }

  var inProgressCount: Int
  var reviewCount: Int
  var resolutionCount: Int
  var readiness: Readiness

  @MainActor
  init(store: GameStore, presentation: PresentationCoordinator) {
    inProgressCount = store.tasks.compactMap(\.assignedAgentID).filter { agentID in
      guard let phase = presentation.presentation(for: agentID)?.phase else { return false }
      return phase == .assignmentReceived || phase == .working || phase == .workComplete
    }.count
    reviewCount = store.tasks.filter { $0.assignedAgentID != nil && !$0.isReviewed && $0.result != nil }.count
    resolutionCount = store.tasks.filter { $0.isReviewed && !$0.resolutionLocked }.count

    if inProgressCount > 0 {
      readiness = .workInProgress
    } else if resolutionCount > 0 {
      readiness = .resolutionRequired
    } else if reviewCount > 0 && store.attentionRemaining > 0 {
      readiness = .founderReviewPending
    } else if let blocker = store.commitBlockerMessage {
      readiness = .blocked(blocker)
    } else {
      readiness = .ready
    }
  }
}

private struct FounderWorkstationCard: View {
  var store: GameStore
  var presentation: PresentationCoordinator
  var expanded: Bool
  var commitInProgress: Bool
  var onSelect: () -> Void
  var onSelectAgent: (String) -> Void
  var onCommit: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  private let accent = SoloTheme.amber

  private var summary: FounderWorkstationSummary {
    FounderWorkstationSummary(store: store, presentation: presentation)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: expanded ? 16 : 12) {
      identity
      metrics
      pendingWork
      if expanded {
        founderCommand
        readiness
        commitAction
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(accent.opacity(expanded ? 0.14 : 0.06), in: .rect(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(expanded ? accent.opacity(isReady ? 0.95 : 0.62) : .white.opacity(0.09), lineWidth: expanded ? 2.5 : 1)
    }
    .shadow(color: isReady && expanded ? accent.opacity(0.28) : .clear, radius: 16, y: 7)
    .contentShape(.rect(cornerRadius: 22))
    .onTapGesture(perform: onSelect)
    .gameplayMotion(.emphasis, value: expanded)
    .gameplayMotion(value: summary)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder workstation")
    .accessibilityValue(summary.readiness.message)
    .accessibilityAddTraits(expanded ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { onSelect() }
  }

  private var identity: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 18).fill(accent.opacity(0.16))
        Image(systemName: "building.2.crop.circle.fill")
          .font(.system(size: expanded ? 45 : 28, weight: .semibold))
          .foregroundStyle(accent)
      }
      .frame(width: expanded ? 88 : 64, height: expanded ? 88 : 64)
      .overlay { RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.7), lineWidth: 1.5) }
      VStack(alignment: .leading, spacing: 3) {
        Text(store.founderName.isEmpty ? "FOUNDER" : store.founderName.uppercased())
          .font(expanded ? .title3.weight(.bold) : .headline.weight(.bold))
        Text("Strategic Command · \(store.chapter.name)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Label(store.sprintPhase.title, systemImage: store.sprintPhase.symbol)
          .font(.caption.weight(.bold))
          .foregroundStyle(accent)
      }
      Spacer(minLength: 0)
      if !expanded {
        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
    }
  }

  private var metrics: some View {
    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
      founderMetric("Energy", "\(store.stats.energy)", "battery.75percent")
      founderMetric("Attention", "\(store.attentionRemaining)/\(store.attentionMaximum)", "eye")
      founderMetric("Runway", "\(store.stats.runway)d", "calendar")
      founderMetric("Momentum", "\(store.stats.momentum)", "arrow.up.right")
      if expanded {
        founderMetric("Company Trust", "\(store.stats.trust)", "checkmark.shield")
        founderMetric("Revenue", store.stats.revenue.formatted(.currency(code: "USD").precision(.fractionLength(0))), "dollarsign")
        founderMetric("Capital", store.stats.capital.formatted(.currency(code: "USD").precision(.fractionLength(0))), "banknote")
      }
    }
  }

  private var metricColumns: [GridItem] {
    dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
  }

  private func founderMetric(_ label: String, _ value: String, _ symbol: String) -> some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        Text(value).font(.caption.weight(.semibold)).contentTransition(.interpolate)
      }
    } icon: {
      Image(systemName: symbol).foregroundStyle(accent)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(.black.opacity(0.16), in: .rect(cornerRadius: 10))
  }

  private var pendingWork: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("PENDING WORK").font(.caption2.weight(.black)).foregroundStyle(.secondary)
      pendingRow("Work in progress", summary.inProgressCount, "waveform.path.ecg")
      pendingRow("Founder reviews", summary.reviewCount, "eye.fill")
      pendingRow("Resolution decisions", summary.resolutionCount, "lock.open.fill")
    }
  }

  private func pendingRow(_ title: String, _ count: Int, _ symbol: String) -> some View {
    Label {
      HStack { Text(title); Spacer(); Text("\(count)").monospacedDigit().fontWeight(.bold) }
    } icon: { Image(systemName: symbol).foregroundStyle(count > 0 ? accent : SoloTheme.mint) }
      .font(.caption)
      .accessibilityLabel("\(title), \(count)")
  }

  @ViewBuilder private var founderCommand: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("FOUNDER COMMAND").font(.caption2.weight(.black)).foregroundStyle(.secondary)
      if store.sprintPhase == .founderEvent, let dilemma = store.activeDilemma {
        Text(dilemma.title).font(.headline)
        Text(dilemma.setup).font(.caption).foregroundStyle(.secondary)
        ForEach(dilemma.choices) { choice in
          Button(choice.title) { store.selectDilemmaChoice(choice.id) }
            .buttonStyle(.bordered)
            .tint(accent)
            .accessibilityHint(choice.consequencePreview)
          Text(choice.consequencePreview).font(.caption2).foregroundStyle(.secondary)
        }
      } else if let task = nextAttentionTask, let agentID = task.assignedAgentID {
        Button { onSelectAgent(agentID) } label: {
          Label(commandTitle(for: task), systemImage: task.isReviewed ? "lock.open.fill" : "eye.fill")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(accent.opacity(0.12), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(SoloPressStyle())
      } else {
        Label("No Founder decisions waiting", systemImage: "checkmark.circle.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(SoloTheme.mint)
      }
    }
  }

  private var readiness: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("SPRINT READINESS").font(.caption2.weight(.black)).foregroundStyle(.secondary)
      Label(summary.readiness.message, systemImage: readinessSymbol)
        .font(.headline)
        .foregroundStyle(isReady ? accent : .primary)
      readinessCheck("Agent work complete", complete: summary.inProgressCount == 0)
      readinessCheck("Founder reviews handled or Attention exhausted", complete: summary.reviewCount == 0 || store.attentionRemaining == 0)
      readinessCheck("Resolution decisions locked", complete: summary.resolutionCount == 0)
      readinessCheck("Canonical sprint blockers cleared", complete: store.commitBlockerMessage == nil)
    }
  }

  private func readinessCheck(_ title: String, complete: Bool) -> some View {
    Label(title, systemImage: complete ? "checkmark.circle.fill" : "circle")
      .font(.caption)
      .foregroundStyle(complete ? SoloTheme.mint : .secondary)
  }

  private var commitAction: some View {
    Button(action: onCommit) {
      Label(commitInProgress ? "COMMITTING SPRINT…" : "COMMIT SPRINT", systemImage: commitInProgress ? "hourglass" : "arrow.forward.square.fill")
        .font(.headline.weight(.black))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isReady ? accent.gradient : Color.secondary.opacity(0.18).gradient, in: .rect(cornerRadius: 14))
        .foregroundStyle(isReady ? Color.black : Color.secondary)
    }
    .buttonStyle(SoloPressStyle())
    .disabled(!isReady || commitInProgress)
    .accessibilityHint(isReady ? "Advances immediately through the canonical sprint simulation." : summary.readiness.message)
  }

  private var nextAttentionTask: SoloTask? {
    store.tasks.first { $0.isReviewed && !$0.resolutionLocked }
      ?? store.tasks.first { $0.assignedAgentID != nil && !$0.isReviewed && $0.result != nil }
  }

  private func commandTitle(for task: SoloTask) -> String {
    task.isReviewed ? "Resolve \(task.title)" : "Review \(task.title)"
  }

  private var isReady: Bool { summary.readiness == .ready && store.canCommitSprint }
  private var readinessSymbol: String {
    switch summary.readiness {
    case .workInProgress: "waveform.path.ecg"
    case .founderReviewPending: "eye.fill"
    case .resolutionRequired: "lock.open.fill"
    case .blocked: "exclamationmark.triangle.fill"
    case .ready: "checkmark.seal.fill"
    }
  }
}
