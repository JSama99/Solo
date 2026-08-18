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
  @State private var assignmentArrivalAgentID: String?
  @State private var activeReviewTaskID: UUID?
  @State private var reviewStage = 0
  @State private var resolutionFocus: TaskResolutionChoice?
  @State private var evidencePulse = false
  @State private var commitPulse = false

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 16) {
          hud
          FounderReviewStrip(store: store, onSelectAgent: select, onCommit: commit)
            .gameplayMotion(value: store.sprintPhase)
          ForEach(orderedStations) { station in
            AgentWorkspaceCard(
              station: station,
              agent: agent(for: station.agentID),
              task: task(for: station.agentID),
              isResting: store.restingAgentIDs.contains(station.agentID),
              selected: selectedAgentID == station.agentID,
              assignmentArrival: assignmentArrivalAgentID == station.agentID,
              reviewStage: activeReviewTaskID == task(for: station.agentID)?.id ? reviewStage : 0,
              resolutionFocus: resolutionFocus,
              reduceMotion: reduceMotion
            ) { select(station.agentID) }
            .id(station.id)
          }
          evidenceDrawer
          commandDeck
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .onAppear { selectedAgentID = selectedAgentID ?? orderedStations.first?.id }
      .onChange(of: selectedAgentID) { _, id in
        guard let id else { return }
        withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) { proxy.scrollTo(id, anchor: .center) }
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
      AgentStationViewModel.derive(agent: agent, task: task(for: agent.id), founderStats: store.stats)
    }.sorted { rank($0.agentID) < rank($1.agentID) }
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
        HUDMetric(label: "Runway", value: store.stats.runway, unit: "d", symbol: "calendar", reduceMotion: reduceMotion)
        HUDMetric(label: "Energy", value: store.stats.energy, symbol: "battery.75percent", reduceMotion: reduceMotion)
        HUDMetric(label: "Trust", value: store.stats.trust, symbol: "checkmark.shield", reduceMotion: reduceMotion)
        HUDMetric(label: "Attention", value: store.attentionRemaining, maximum: store.attentionMaximum, symbol: "eye", reduceMotion: reduceMotion)
      }
      Text("Venture \(store.venture) · Sprint \(store.sprint)/12 · \(store.chapter.name)").font(.caption).foregroundStyle(.secondary)
    }
    .padding(14).background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .scaleEffect(commitPulse && !reduceMotion ? 1.012 : 1)
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.cyan.opacity(commitPulse ? 0.7 : 0), lineWidth: 1.5) }
    .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: commitPulse)
    .gameplayMotion(value: store.sprintPhase)
    .gameplayMotion(value: HUDSnapshot(store: store))
  }

  /// Every resource the HUD reads, so one modifier animates all of them together
  /// when a sprint resolves.
  private struct HUDSnapshot: Equatable {
    var runway: Int, energy: Int, trust: Int, attention: Int, sprint: Int, venture: Int
    @MainActor init(store: GameStore) {
      runway = store.stats.runway; energy = store.stats.energy; trust = store.stats.trust
      attention = store.attentionRemaining; sprint = store.sprint; venture = store.venture
    }
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
      if task.resolutionLocked, let resolution = task.resolution {
        Label("\(resolution.title) locked", systemImage: "lock.fill")
          .foregroundStyle(SoloTheme.mint)
          .symbolEffect(.bounce, value: task.resolutionLocked)
          .transition(.opacity.combined(with: .scale(scale: 0.88)))
      } else {
        Text("Founder resolution required").font(.subheadline.weight(.bold))
        ForEach(TaskResolutionChoice.allCases) { choice in
          Button(choice.title, systemImage: choice.symbol) { resolve(taskID: task.id, choice: choice) }
            .buttonStyle(.bordered)
            .tint(resolutionFocus == choice ? SoloTheme.mint : SoloTheme.purple)
            .scaleEffect(resolutionFocus == choice && !reduceMotion ? 1.04 : 1)
            .opacity(resolutionFocus == nil || resolutionFocus == choice ? 1 : 0.38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(SoloMotion.resolved(SoloMotion.focus, reduceMotion: reduceMotion), value: resolutionFocus)
            .accessibilityHint(choice.summary)
        }
        Text("Rework: 1 Attention, 4 Energy, 1 Runway. Cross-Check: 1 Attention and an independent model family.").font(.caption2).foregroundStyle(.secondary)
      }
    }
  }

  private var evidenceDrawer: some View {
    DisclosureGroup(isExpanded: $evidenceExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(store.evidence.prefix(8)) { entry in
          VStack(alignment: .leading, spacing: 2) { Text(entry.task).font(.subheadline.weight(.semibold)); Text("\(entry.agent) · \(entry.verdict) · Evidence \(entry.evidenceCompleteness)%").font(.caption).foregroundStyle(.secondary); Text(entry.note).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }.padding(.top, 8)
    } label: {
      HStack(spacing: 4) {
        Text("Evidence · ")
        Text("\(store.evidence.count)").contentTransition(.numericText(value: Double(store.evidence.count)))
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Evidence ledger, \(store.evidence.count) entries")
    }
    .padding(14).background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.mint.opacity(evidencePulse ? 0.85 : 0), lineWidth: 1.5) }
    .scaleEffect(evidencePulse && !reduceMotion ? 1.015 : 1)
    .animation(SoloMotion.resolved(SoloMotion.impact, reduceMotion: reduceMotion), value: evidencePulse)
    .gameplayMotion(value: store.evidence.count)
    .gameplayMotion(.emphasis, value: evidenceExpanded)
  }

  private var phaseReason: some View {
    Group { if store.sprintPhase == .founderEvent { Text("Resolve the founder dilemma to unlock team controls.") } else if let blocker = store.commitBlockerMessage { Text(blocker) } }
      .font(.caption).foregroundStyle(.secondary)
  }
  private var selectedAgent: SoloAgent? { selectedAgentID.flatMap(agent(for:)) }
  private var canAssign: Bool { store.sprintPhase == .chooseCommitments || store.sprintPhase == .assignTeam }
  private var disabledReason: String { store.sprintPhase == .founderEvent ? "Resolve the founder dilemma first." : "This action is unavailable in the current phase." }
  private func canReview(_ id: String) -> Bool { guard let task = task(for: id) else { return false }; return store.sprintPhase == .reviewAndResolve && !task.isReviewed && task.result != nil && store.attentionRemaining > 0 }
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
    announce("Review complete.")
  }

  private func resolve(taskID: UUID, choice: TaskResolutionChoice) {
    withAnimation(SoloMotion.resolved(SoloMotion.focus, reduceMotion: reduceMotion)) {
      resolutionFocus = choice
    }
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(180)) }
      withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
        store.resolveReviewedTask(taskID: taskID, choice: choice)
      }
      resolutionTick += 1
      evidencePulse.toggle()
      activeReviewTaskID = nil
      resolutionFocus = nil
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

private struct AgentWorkspaceCard: View {
  var station: AgentStationViewModel
  var agent: SoloAgent?
  var task: SoloTask?
  var isResting: Bool
  var selected: Bool
  var assignmentArrival: Bool
  var reviewStage: Int
  var resolutionFocus: TaskResolutionChoice?
  var reduceMotion: Bool
  var action: () -> Void
  var accent: Color { switch station.agentID { case "aurora": SoloTheme.purple; case "stacks": SoloTheme.cyan; case "brio": SoloTheme.coral; default: SoloTheme.mint } }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        header
        HStack(spacing: 8) { badge("Stress", station.progression.stressBand.label); badge("Trust", station.trustBand.label) }
          .gameplayMotion(value: StatusSnapshot(stress: station.progression.stressBand, trust: station.trustBand))
        taskHeadline
        Text(station.mood).font(.subheadline).foregroundStyle(.secondary)
        workspace
        if let task, let result = task.result {
          report(result, reviewed: task.isReviewed, stage: reviewStage)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        if selected { Text("Selected workspace").font(.caption.weight(.bold)).foregroundStyle(accent).transition(.opacity) }
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: selected ? 315 : 260, alignment: .leading)
      .background(accent.opacity(selected ? 0.14 : 0.06), in: .rect(cornerRadius: 22))
      .overlay { RoundedRectangle(cornerRadius: 22).stroke(selected ? accent.opacity(assignmentArrival ? 1 : 0.82) : .white.opacity(0.09), lineWidth: selected ? (assignmentArrival ? 2.8 : 2) : 1) }
    }
    .buttonStyle(WorkspacePressStyle(selected: selected, reduceMotion: reduceMotion))
    .scaleEffect((selected && reviewStage == 0 && task?.result != nil) || assignmentArrival ? (reduceMotion ? 1 : 1.018) : 1)
    .shadow(color: accent.opacity(selected ? 0.20 : 0), radius: selected ? 13 : 0, y: selected ? 6 : 0)
    .overlay { RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(assignmentArrival ? 0.9 : 0), lineWidth: assignmentArrival ? 2 : 0) }
    .animation(SoloMotion.resolved(SoloMotion.focus, reduceMotion: reduceMotion), value: selected)
    .animation(SoloMotion.resolved(SoloMotion.arrival, reduceMotion: reduceMotion), value: assignmentArrival)
    .gameplayMotion(.emphasis, value: selected)
    .gameplayMotion(value: WorkSnapshot(taskID: task?.id, hasResult: task?.result != nil, reviewed: task?.isReviewed ?? false, state: station.semanticState, resting: isResting))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(station.name), \(station.role.rawValue), level \(station.progression.level)")
    .accessibilityValue(station.accessibilityValue)
    .accessibilityHint("Select this agent workspace")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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

  private var header: some View {
    HStack {
      ZStack {
        Circle().fill(accent.opacity(0.25)).frame(width: 56, height: 56)
        Text(station.initials).font(.headline.weight(.heavy)).foregroundStyle(accent)
      }
      VStack(alignment: .leading) {
        Text(station.name).font(.title3.weight(.bold))
        HStack(spacing: 3) {
          Text(station.role.rawValue + " · Level ")
          Text(String(station.progression.level)).contentTransition(.numericText(value: Double(station.progression.level)))
        }
        .font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Label(isResting ? "Resting" : station.semanticState.label, systemImage: isResting ? "bed.double.fill" : station.semanticState.glyph)
        .font(.caption.weight(.bold)).foregroundStyle(accent)
        .contentTransition(.interpolate)
        .symbolEffect(.bounce, value: station.semanticState)
    }
    .gameplayMotion(.celebration, value: station.progression.level)
  }

  private func badge(_ title: String, _ value: String) -> some View {
    Text("\(title): \(value)").font(.caption2.weight(.semibold))
      .padding(.horizontal, 8).padding(.vertical, 5)
      .background(.black.opacity(0.16), in: Capsule())
      .contentTransition(.interpolate)
  }

  /// The desk contains the sole low-cost looping treatment. It is started only
  /// while this station is semantically working and never consults simulation RNG.
  private var workspace: some View {
    HStack {
      Image(systemName: station.role.symbol).font(.title).foregroundStyle(accent)
      VStack(alignment: .leading) {
        Text("LIVE WORKSPACE").font(.caption2.weight(.bold))
        Text(isResting ? "Quiet recovery station" : "Seated and \(station.semanticState.label.lowercased())").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      WorkspaceActivity(agentID: station.agentID, accent: accent, isWorking: isWorking, reduceMotion: reduceMotion)
    }
    .padding(12)
    .background(.black.opacity(0.16), in: .rect(cornerRadius: 14))
    .overlay { RoundedRectangle(cornerRadius: 14).stroke(accent.opacity((task?.result != nil && !task!.isReviewed) ? 0.52 : 0), lineWidth: 1) }
  }

  private var isWorking: Bool { !isResting && station.semanticState == .working }

  private var headline: String {
    if let title = task?.title { return title }
    return isResting ? "Recovery sprint selected" : "No task assigned"
  }

  private var taskHeadline: some View {
    Text(headline)
      .font(.headline)
      .id(headline)
      .transition(.opacity.combined(with: .move(edge: .trailing)))
  }

  private func verifiedSummary(actual: Int, overclaim: Int) -> String {
    let base = "Verified actual " + String(actual)
    return overclaim > 0 ? base + " · Overclaim +" + String(overclaim) : base
  }

  @ViewBuilder private func report(_ result: TaskResult, reviewed: Bool, stage: Int) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 3) {
        Text("Reported quality ")
        Text(String(result.reportedQuality)).contentTransition(.numericText(value: Double(result.reportedQuality)))
        Text(" · Evidence " + String(result.evidenceCompleteness) + "%")
      }
      .font(.caption.weight(.semibold))
      .opacity(reviewed && stage < 1 ? 0 : 1)
      if reviewed && stage >= 2 {
        Label(result.verificationState.label, systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(SoloTheme.mint)
          .transition(.opacity.combined(with: .scale(scale: 0.82)))
          .symbolEffect(.bounce, value: stage)
        if let actual = result.revealedActualQuality, stage >= 3 {
          Text(verifiedSummary(actual: actual, overclaim: result.overclaimAmount)).font(.caption)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
      }
      if !reviewed || stage >= 4 { Text(result.knownOperationalRisk).font(.caption2).foregroundStyle(.secondary).transition(.opacity.combined(with: .move(edge: .bottom))) }
    }
  }
}

private struct WorkspacePressStyle: ButtonStyle {
  var selected: Bool
  var reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : (selected && !reduceMotion ? 1.012 : 1))
      .brightness(configuration.isPressed ? -0.025 : 0)
      .animation(SoloMotion.resolved(SoloMotion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
  }
}

/// A single contained activity surface shared by each card design. Its phase is
/// local and stops being animated as soon as work is no longer active.
private struct WorkspaceActivity: View {
  var agentID: String
  var accent: Color
  var isWorking: Bool
  var reduceMotion: Bool
  @State private var active = false

  var body: some View {
    ZStack {
      Image(systemName: "desktopcomputer").foregroundStyle(accent)
      if isWorking {
        activity
          .transition(.opacity)
      }
    }
    .frame(width: 54, height: 32)
    .onAppear { active = isWorking && !reduceMotion }
    .onChange(of: isWorking) { _, value in active = value && !reduceMotion }
    .onChange(of: reduceMotion) { _, value in active = isWorking && !value }
  }

  @ViewBuilder private var activity: some View {
    switch agentID {
    case "aurora":
      AuroraWorkspaceActivity(accent: accent, active: active)
    case "stacks":
      StacksWorkspaceActivity(accent: accent, active: active)
    case "brio":
      BrioWorkspaceActivity(accent: accent, active: active)
    default:
      Image(systemName: "sparkle.magnifyingglass").foregroundStyle(accent)
    }
  }
}

private struct AuroraWorkspaceActivity: View {
  var accent: Color
  var active: Bool
  @State private var scan = false
  var body: some View {
    ZStack {
      HStack(spacing: 5) { ForEach(0..<4, id: \.self) { index in Circle().fill(accent).frame(width: 4, height: 4).opacity(scan ? (index.isMultiple(of: 2) ? 1 : 0.28) : 0.3).scaleEffect(scan && index == 2 ? 1.5 : 1) } }
      Rectangle().fill(LinearGradient(colors: [.clear, accent.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 30, height: 1).offset(y: scan ? -9 : 9)
    }
    .onAppear { update() }.onChange(of: active) { _, _ in update() }
  }
  private func update() { withAnimation(active ? .linear(duration: 1.15).repeatForever(autoreverses: true) : nil) { scan = active } }
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
        if let task = store.tasks.first(where: { $0.assignedAgentID != nil && !$0.isReviewed }) { strip("Review \(task.title)", task: task) }
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
