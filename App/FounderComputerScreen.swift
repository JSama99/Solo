import SwiftUI

/// The single vertical scrolling owner for the playable Founder Computer.
struct FounderComputerScreen: View {
  var store: GameStore
  var presentation: PresentationCoordinator

  @Environment(FounderProgressionStore.self) private var progression
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
  #if DEBUG
  @State private var showsMotionVerification = false
  #endif

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 16) {
          hud.founderEntrance(order: 0)
          FounderReviewStrip(store: store, presentation: presentation, onSelectAgent: beginReviewFocus, onCommit: commit)
            .gameplayMotion(value: store.sprintPhase)
            .founderEntrance(order: 1)
          ForEach(orderedStations) { station in
            workspaceCard(for: station)
            .id(station.id)
            .opacity(isReviewFocused && selectedAgentID != station.agentID ? 0.86 : 1)
            .founderEntrance(order: rank(station.agentID) + 2)
          }
          evidenceDrawer.founderEntrance(order: 5)
          commandDeck.founderEntrance(order: 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .safeAreaPadding(.bottom, 96)
      .onAppear { selectedAgentID = selectedAgentID ?? orderedStations.first?.id }
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
          try? await Task.sleep(for: .milliseconds(75))
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
      onRest: { restCandidate = .init(agentID: agentID, name: station.name, hasAssignment: assignedTask != nil) }
    )
  }

  private var hud: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("FOUNDER COMPUTER").font(.caption.weight(.bold)).foregroundStyle(SoloTheme.cyan)
        Spacer()
        Label(store.sprintPhase.title, systemImage: store.sprintPhase.symbol)
          .font(.caption.weight(.bold))
          .contentTransition(.interpolate)
          .symbolEffect(.bounce, value: store.sprintPhase)
          .id(store.sprintPhase)
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      }
      HStack(spacing: 8) {
        HUDMetricView(label: "Runway", value: store.stats.runway, unit: "d", symbol: "calendar")
        HUDMetricView(label: "Energy", value: store.stats.energy, symbol: "battery.75percent")
        HUDMetricView(label: "Trust", value: store.stats.trust, symbol: "checkmark.shield")
        HUDMetricView(label: "Attention", value: store.attentionRemaining, maximum: store.attentionMaximum, symbol: "eye")
      }
      Text("Venture \(store.venture) · Sprint \(store.sprint)/12 · \(store.chapter.name)").font(.caption).foregroundStyle(.secondary)
    }
    .padding(14).background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .scaleEffect(commitPulse && !reduceMotion ? 1.012 : 1)
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.cyan.opacity(commitPulse ? 0.7 : 0), lineWidth: 1.5) }
    .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: commitPulse)
    .gameplayMotion(value: store.sprintPhase)
  }

  private var commandDeck: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Selected agent").font(.caption.weight(.bold)).foregroundStyle(.secondary)
      if let agent = selectedAgent {
        HStack { Text(agent.name).font(.headline); Spacer(); Text(task(for: agent.id)?.title ?? (store.restingAgentIDs.contains(agent.id) ? "Resting" : "No task")).font(.caption).foregroundStyle(.secondary) }
        HStack(spacing: 10) {
          command("Assign", "checklist", enabled: canAssign) { assignmentDestination = .init(agentID: agent.id) }
          command("Review", "eye", enabled: canReview(agent.id)) { review(agent.id) }
          command(store.restingAgentIDs.contains(agent.id) ? "Resting" : "Rest", "bed.double", enabled: canRest(agent.id)) { restCandidate = .init(agentID: agent.id, name: agent.name, hasAssignment: task(for: agent.id) != nil) }
        }
        if let task = task(for: agent.id), task.isReviewed {
          resolutionControls(task).transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      } else { Text("Select an agent to issue commands.").foregroundStyle(.secondary) }
      phaseReason
    }
    .padding(14).background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .gameplayMotion(.emphasis, value: selectedAgentID)
    .gameplayMotion(value: CommandDeckSnapshot(store: store, selectedAgentID: selectedAgentID))
  }

  /// The selected agent's command-relevant state: which task is theirs, whether
  /// it has been reviewed, and whether its resolution is locked in.
  private struct CommandDeckSnapshot: Equatable {
    var taskID: UUID?, reviewed: Bool, locked: Bool, resting: Bool, phase: SprintPhase
    @MainActor init(store: GameStore, selectedAgentID: String?) {
      let task = store.tasks.first { $0.assignedAgentID != nil && $0.assignedAgentID == selectedAgentID }
      taskID = task?.id
      reviewed = task?.isReviewed ?? false
      locked = task?.resolutionLocked ?? false
      resting = selectedAgentID.map(store.restingAgentIDs.contains) ?? false
      phase = store.sprintPhase
    }
  }

  private func command(_ title: String, _ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(title, systemImage: symbol, action: action)
      .buttonStyle(.borderedProminent).tint(SoloTheme.purple)
      .frame(minHeight: 44)
      .disabled(!enabled)
      .accessibilityHint(enabled ? "Acts on the selected agent." : disabledReason)
  }

  @ViewBuilder private func resolutionControls(_ task: SoloTask) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider()
      let agentPresentation = task.assignedAgentID.flatMap(presentation.presentation(for:))
      if task.resolutionLocked,
         agentPresentation?.phase != .resolving,
         let resolution = task.resolution {
        Label("\(resolution.title) locked", systemImage: "lock.fill")
          .foregroundStyle(SoloTheme.mint)
          .symbolEffect(.bounce, value: task.resolutionLocked)
          .transition(.opacity.combined(with: .scale(scale: 0.88)))
      } else {
        Text("Founder resolution required").font(.subheadline.weight(.bold))
        ForEach(TaskResolutionChoice.allCases) { choice in
          Button(choice.title, systemImage: choice.symbol) { resolve(taskID: task.id, choice: choice) }
            .buttonStyle(.borderedProminent)
            .tint(agentPresentation?.resolutionChoice == choice ? SoloTheme.mint : SoloTheme.purple)
            .scaleEffect(agentPresentation?.resolutionChoice == choice ? 1.055 : 1)
            .opacity(agentPresentation?.phase == .resolving && agentPresentation?.resolutionChoice != choice ? 0.4 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint(choice.summary)
        }
        Text("Rework: 1 Attention, 4 Energy, 1 Runway. Cross-Check: 1 Attention and an independent model family.").font(.caption2).foregroundStyle(.secondary)
      }
    }
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

  private var phaseReason: some View {
    Group { if store.sprintPhase == .founderEvent { Text("Resolve the founder dilemma to unlock team controls.") } else if let blocker = store.commitBlockerMessage { Text(blocker) } }
      .font(.caption).foregroundStyle(.secondary)
  }
  private var selectedAgent: SoloAgent? { selectedAgentID.flatMap(agent(for:)) }
  private var canAssign: Bool { store.sprintPhase == .chooseCommitments || store.sprintPhase == .assignTeam }
  private var disabledReason: String { store.sprintPhase == .founderEvent ? "Resolve the founder dilemma first." : "This action is unavailable in the current phase." }
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
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      presentation.commit(in: store, progression: progression)
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
    .frame(width: selected ? 88 : 62, height: selected ? 88 : 62)
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
  var accent: Color { switch station.agentID { case "aurora": SoloTheme.purple; case "stacks": SoloTheme.cyan; case "brio": SoloTheme.coral; default: SoloTheme.mint } }

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
    .frame(maxWidth: .infinity, minHeight: selected ? 520 : 210, alignment: .leading)
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
    HStack {
      AgentPortrait(agentID: station.agentID, initials: station.initials, name: station.name, accent: accent, state: station.semanticState, selected: selected, reduceMotion: reduceMotion)
      VStack(alignment: .leading) {
        Text(station.name).font(selected ? .title3.weight(.bold) : .headline.weight(.bold))
        HStack(spacing: 3) {
          Text(station.role.rawValue + " · Level ")
          Text(String(station.progression.level)).contentTransition(.numericText(value: Double(station.progression.level)))
        }
        .font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Label(isResting ? "Resting" : effectivePhase.statusLabel, systemImage: isResting ? "bed.double.fill" : station.semanticState.glyph)
        .font(.caption.weight(.bold)).foregroundStyle(accent)
        .contentTransition(.interpolate)
        .symbolEffect(.bounce, value: station.semanticState)
    }
    .gameplayMotion(.celebration, value: station.progression.level)
  }

  private var attributes: some View {
    HStack(spacing: 8) {
      attribute("Stress", station.progression.stressBand.label, "gauge.with.dots.needle.50percent")
      attribute("Trust", "\(Int(station.trust.rounded()))", "checkmark.shield")
      attribute("XP", "\(station.progression.xp)", "sparkles")
      if let specialization = station.progression.specialization { attribute("Focus", specialization, station.role.symbol) }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .gameplayMotion(value: StatusSnapshot(stress: station.progression.stressBand, trust: station.trustBand))
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
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(headline).font(.subheadline.weight(.semibold)).lineLimit(selected ? 2 : 1)
        Spacer(minLength: 0)
        Text(isResting ? "Resting" : effectivePhase.statusLabel).font(.caption2.weight(.bold)).foregroundStyle(accent)
      }
      if selected && effectivePhase == .working { ProgressView(value: presentation?.progress ?? 0.45).tint(accent) }
    }
  }

  private var compactWorkspace: some View {
    HStack(spacing: 8) {
      Image(systemName: station.role.symbol).foregroundStyle(accent)
      Text("LIVE WORKSPACE · \(effectivePhase.statusLabel.uppercased())").font(.caption2.monospaced().weight(.bold)).foregroundStyle(accent.opacity(0.85))
      Spacer()
      Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
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
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
      actions
    }
  }

  private var actions: some View {
    HStack(spacing: 8) {
      if task == nil && !isResting { cardAction("Assign", "checklist", onAssign) }
      if let task, !task.isReviewed && effectivePhase == .awaitingReview { cardAction("Review", "eye", onReview) }
      if !isResting && (task == nil || task?.isReviewed == false) { cardAction("Rest", "bed.double", onRest) }
      if task?.resolutionLocked == true { Label("Resolved", systemImage: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(SoloTheme.mint) }
      Spacer(minLength: 0)
    }
    .padding(.top, 2)
  }

  private func cardAction(_ title: String, _ symbol: String, _ operation: @escaping () -> Void) -> some View {
    Button(title, systemImage: symbol, action: operation).buttonStyle(.borderedProminent).tint(accent).controlSize(.small).frame(minHeight: 38)
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
}

private struct StacksWorkspaceActivity: View {
  var accent: Color
  var active: Bool
  @State private var build = false
  var body: some View {
    HStack(spacing: 3) { ForEach(0..<5, id: \.self) { index in RoundedRectangle(cornerRadius: 1).fill(accent).frame(width: 5, height: index.isMultiple(of: 2) ? 8 : 13).opacity(build ? (index < 3 ? 1 : 0.3) : 0.25) } }
      .offset(x: build ? 3 : -3)
      .onAppear { update() }.onChange(of: active) { _, _ in update() }
  }
  private func update() { withAnimation(active ? .easeInOut(duration: 0.72).repeatForever(autoreverses: true) : nil) { build = active } }
}

private struct BrioWorkspaceActivity: View {
  var accent: Color
  var active: Bool
  @State private var signal = false
  var body: some View {
    HStack(alignment: .center, spacing: 3) { ForEach(0..<4, id: \.self) { index in Capsule().fill(accent).frame(width: 3, height: signal ? CGFloat(7 + index * 3) : CGFloat(5 + (3 - index) * 2)).opacity(signal ? 1 : 0.32) } }
      .onAppear { update() }.onChange(of: active) { _, _ in update() }
  }
  private func update() { withAnimation(active ? .easeInOut(duration: 0.68).repeatForever(autoreverses: true) : nil) { signal = active } }
}

private struct HUDMetric: View {
  var label: String
  var value: Int
  var maximum: Int? = nil
  var unit: String = ""
  var symbol: String
  var reduceMotion: Bool
  @State private var pulse = false

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 0) { Text("\(value)").contentTransition(.numericText(value: Double(value))); if let maximum { Text("/\(maximum)") } else if !unit.isEmpty { Text(unit) } }
          .font(.subheadline.weight(.bold))
        Text(label).font(.caption2).foregroundStyle(.secondary)
      }
    } icon: { Image(systemName: symbol).foregroundStyle(SoloTheme.cyan).symbolEffect(.bounce, value: pulse) }
      .frame(maxWidth: .infinity, alignment: .leading)
      .scaleEffect(pulse && !reduceMotion ? 1.08 : 1)
      .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: pulse)
      .onChange(of: value) { _, _ in
        guard !reduceMotion else { return }
        pulse.toggle()
        Task { @MainActor in try? await Task.sleep(for: .milliseconds(300)); pulse.toggle() }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(maximum.map { "\(label), \(value) of \($0)" } ?? "\(label), \(value)\(unit)")
  }
}

private struct WorkspacePressButtonStyle: ButtonStyle {
  var reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .animation(reduceMotion ? nil : .smooth(duration: 0.08), value: configuration.isPressed)
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

private struct FounderReviewStrip: View {
  var store: GameStore
  var presentation: PresentationCoordinator
  var onSelectAgent: (String) -> Void
  var onCommit: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var attentionPulse = false

  var body: some View {
    Group {
      switch store.sprintPhase {
      case .founderEvent:
        if let dilemma = store.activeDilemma {
          VStack(alignment: .leading, spacing: 8) {
            Text(dilemma.title).font(.headline)
            Text(dilemma.setup).font(.caption).foregroundStyle(.secondary)
            ForEach(dilemma.choices) { choice in
              Button(choice.title) { store.selectDilemmaChoice(choice.id) }.buttonStyle(.bordered).accessibilityHint(choice.consequencePreview)
              Text(choice.consequencePreview).font(.caption2).foregroundStyle(.secondary)
            }
          }.padding(14)
        }
      case .readyToCommit:
        VStack(alignment: .leading, spacing: 8) {
          Text("Ready to commit").font(.headline)
          Button("Commit Sprint", systemImage: "bolt.fill", action: onCommit).buttonStyle(.borderedProminent).disabled(!store.canCommitSprint)
          if let blocker = store.commitBlockerMessage { Text(blocker).font(.caption).foregroundStyle(.secondary) }
        }.padding(14)
      default:
        if let task = store.tasks.first(where: { $0.assignedAgentID != nil && !$0.isReviewed }) {
          if let agentID = task.assignedAgentID,
             let phase = presentation.presentation(for: agentID)?.phase,
             phase != .awaitingReview {
            Label("\(phase.statusLabel): \(task.title)", systemImage: phase == .workComplete ? "checkmark.seal.fill" : "waveform.path.ecg")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(phase == .workComplete ? SoloTheme.mint : SoloTheme.cyan)
              .padding(14)
              .contentTransition(.interpolate)
          } else {
            strip("Review \(task.title)", task: task)
          }
        }
        else if let task = store.tasks.first(where: { $0.isReviewed && !$0.resolutionLocked }) { strip("Resolve \(task.title)", task: task) }
        else { Text("Assign work, then return for Founder Review. Attention \(store.attentionRemaining)/\(store.attentionMaximum)").padding(14) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .scaleEffect(attentionPulse && !reduceMotion ? 1.015 : 1)
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.mint.opacity(attentionPulse ? 0.7 : 0), lineWidth: 1.5) }
    .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: attentionPulse)
    .onChange(of: reviewableTaskID) { _, id in
      guard id != nil, !reduceMotion else { return }
      attentionPulse = true
      Task { @MainActor in try? await Task.sleep(for: .milliseconds(280)); attentionPulse = false }
    }
    .transition(.opacity.combined(with: .scale(scale: 0.98)))
  }

  private var reviewableTaskID: UUID? {
    store.tasks.first(where: { $0.assignedAgentID != nil && !$0.isReviewed && $0.result != nil })?.id
  }

  private func strip(_ title: String, task: SoloTask) -> some View {
    Button { if let id = task.assignedAgentID { onSelectAgent(id) } } label: {
      Label(title, systemImage: "eye").frame(maxWidth: .infinity, alignment: .leading).padding(14)
    }
    .buttonStyle(.plain)
  }
}
