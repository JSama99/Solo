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
            let agentPresentation = presentation.presentation(for: station.agentID)
            AgentWorkspaceCard(
              station: station,
              agent: agent(for: station.agentID),
              task: task(for: station.agentID),
              presentation: agentPresentation,
              isResting: store.restingAgentIDs.contains(station.agentID),
              selected: selectedAgentID == station.agentID,
              reduceMotion: reduceMotion
            ) { select(station.agentID) }
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
          .symbolEffect(.bounce, value: resolution)
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
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      presentation.review(taskID: task.id, in: store)
    }
    announce("Founder review started.")
  }

  private func resolve(taskID: UUID, choice: TaskResolutionChoice) {
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      presentation.resolve(taskID: taskID, choice: choice, in: store)
    }
    resolutionTick += 1
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

struct AgentWorkspaceCard: View {
  var station: AgentStationViewModel
  var agent: SoloAgent?
  var task: SoloTask?
  var presentation: PresentationCoordinator.AgentPresentation?
  var isResting: Bool
  var selected: Bool
  var reduceMotion: Bool
  var action: () -> Void
  var accent: Color { switch station.agentID { case "aurora": SoloTheme.purple; case "stacks": SoloTheme.cyan; case "brio": SoloTheme.coral; default: SoloTheme.mint } }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        header
        HStack(spacing: 8) { badge("Stress", station.progression.stressBand.label); badge("Trust", station.trustBand.label) }
          .gameplayMotion(value: StatusSnapshot(stress: station.progression.stressBand, trust: station.trustBand))
        Text(headline).font(.headline)
          .id(headline)
          .transition(.opacity.combined(with: .move(edge: .leading)))
        Text(station.mood).font(.subheadline).foregroundStyle(.secondary)
        workspace
        if let task, let result = task.result, canRevealResult {
          report(result, reviewed: task.isReviewed, revealStep: presentation?.reviewRevealStep ?? 5)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        if selected { Text("Selected workspace").font(.caption.weight(.bold)).foregroundStyle(accent).transition(.opacity) }
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: selected ? 348 : 290, alignment: .leading)
      .background(accent.opacity(selected ? 0.23 : 0.07), in: .rect(cornerRadius: 22))
      .overlay { RoundedRectangle(cornerRadius: 22).stroke(selected ? accent : .white.opacity(0.09), lineWidth: selected ? 3 : 1) }
      .shadow(color: selected ? accent.opacity(0.38) : .clear, radius: selected ? 16 : 0, y: selected ? 8 : 0)
    }
    .buttonStyle(WorkspacePressButtonStyle(reduceMotion: reduceMotion))
    .scaleEffect(cardScale)
    .phaseAnimator([0, 1, 2], trigger: selected) { content, phase in
      content.scaleEffect(!reduceMotion && selected && phase == 1 ? 1.035 : 1)
    } animation: { phase in
      phase == 1 ? .snappy(duration: 0.14) : .smooth(duration: 0.2)
    }
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
      Label(isResting ? "Resting" : effectivePhase.statusLabel, systemImage: isResting ? "bed.double.fill" : station.semanticState.glyph)
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

  private var workspace: some View {
    LiveWorkspaceSurface(
      agentID: station.agentID,
      taskTitle: task?.title,
      phase: isResting ? .idle : effectivePhase,
      progress: presentation?.progress ?? (station.semanticState == .working ? 0.45 : 0),
      reduceMotion: reduceMotion
    )
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
  private var agent: SoloAgent? { store.agents.first { $0.id == agentID } }
  var body: some View { NavigationStack { List { ForEach(store.tasks) { task in
    VStack(alignment: .leading, spacing: 7) { Text(task.title).font(.headline); Text(task.detail).font(.caption).foregroundStyle(.secondary); Text("\(task.role.rawValue) · \(task.category.rawValue) · \(task.urgency.label)").font(.caption2); Text("Reward: \(task.reward) · If ignored: \(task.consequenceLabel)").font(.caption2).foregroundStyle(SoloTheme.amber); Text(task.isReviewed ? "Reviewed — locked" : task.assignedAgentID.flatMap { id in store.agents.first { $0.id == id }?.name }.map { "Assigned: \($0)" } ?? "Unassigned").font(.caption.weight(.semibold)); if let agent { Text(agent.role == task.role || agent.role == .general || task.role == .general ? "Role fit" : "Role mismatch — allowed").font(.caption2).foregroundStyle(agent.role == task.role ? SoloTheme.mint : SoloTheme.amber) }; HStack { Button("Assign") { presentation.assign(agentID: agentID, to: task.id, in: store); dismiss(); didFinish() }.buttonStyle(.borderedProminent).disabled(task.isReviewed); if task.assignedAgentID == agentID && !task.isReviewed { Button("Remove", role: .destructive) { presentation.assign(agentID: nil, to: task.id, in: store); dismiss(); didFinish() }.buttonStyle(.bordered) } }
    }.padding(.vertical, 5)
  } }.navigationTitle("Assign \(agent?.name ?? "Agent")").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } } }
}

private struct FounderReviewStrip: View {
  var store: GameStore
  var presentation: PresentationCoordinator
  var onSelectAgent: (String) -> Void
  var onCommit: () -> Void

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
    .transition(.opacity.combined(with: .scale(scale: 0.98)))
  }

  private func strip(_ title: String, task: SoloTask) -> some View {
    Button { if let id = task.assignedAgentID { onSelectAgent(id) } } label: {
      Label(title, systemImage: "eye").frame(maxWidth: .infinity, alignment: .leading).padding(14)
    }
    .buttonStyle(.plain)
  }
}
