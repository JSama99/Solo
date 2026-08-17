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
        metric("Runway", store.stats.runway, unit: "d", symbol: "calendar")
        metric("Energy", store.stats.energy, symbol: "battery.75percent")
        metric("Trust", store.stats.trust, symbol: "checkmark.shield")
        metric("Attention", store.attentionRemaining, of: store.attentionMaximum, symbol: "eye")
      }
      Text("Venture \(store.venture) · Sprint \(store.sprint)/12 · \(store.chapter.name)").font(.caption).foregroundStyle(.secondary)
    }
    .padding(14).background(SoloTheme.card, in: .rect(cornerRadius: 18))
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

  private func metric(_ label: String, _ value: Int, of maximum: Int? = nil, unit: String = "", symbol: String) -> some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 0) {
          Text("\(value)").contentTransition(.numericText(value: Double(value)))
          if let maximum { Text("/\(maximum)") } else if !unit.isEmpty { Text(unit) }
        }
        .font(.subheadline.weight(.bold))
        Text(label).font(.caption2).foregroundStyle(.secondary)
      }
    } icon: {
      Image(systemName: symbol).foregroundStyle(SoloTheme.cyan)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(maximum.map { "\(label), \(value) of \($0)" } ?? "\(label), \(value)\(unit)")
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
          .symbolEffect(.bounce, value: resolution)
      } else {
        Text("Founder resolution required").font(.subheadline.weight(.bold))
        ForEach(TaskResolutionChoice.allCases) { choice in
          Button(choice.title, systemImage: choice.symbol) { resolve(taskID: task.id, choice: choice) }
            .buttonStyle(.bordered).frame(maxWidth: .infinity, alignment: .leading).accessibilityHint(choice.summary)
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
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      presentation.review(taskID: task.id, in: store)
    }
    announce("Review complete.")
  }

  private func resolve(taskID: UUID, choice: TaskResolutionChoice) {
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      store.resolveReviewedTask(taskID: taskID, choice: choice)
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

private struct AgentWorkspaceCard: View {
  var station: AgentStationViewModel
  var agent: SoloAgent?
  var task: SoloTask?
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
        if let task, let result = task.result {
          report(result, reviewed: task.isReviewed)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        if selected { Text("Selected workspace").font(.caption.weight(.bold)).foregroundStyle(accent).transition(.opacity) }
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: selected ? 315 : 260, alignment: .leading)
      .background(accent.opacity(selected ? 0.14 : 0.06), in: .rect(cornerRadius: 22))
      .overlay { RoundedRectangle(cornerRadius: 22).stroke(selected ? accent : .white.opacity(0.09), lineWidth: selected ? 2 : 1) }
    }
    .buttonStyle(.plain)
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

  /// The desk itself. The monitor animates once when work state changes instead
  /// of running an indefinite effect for every active agent card.
  private var workspace: some View {
    HStack {
      Image(systemName: station.role.symbol).font(.title).foregroundStyle(accent)
      VStack(alignment: .leading) {
        Text("LIVE WORKSPACE").font(.caption2.weight(.bold))
        Text(isResting ? "Quiet recovery station" : "Seated and \(station.semanticState.label.lowercased())").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "desktopcomputer").foregroundStyle(accent)
        .symbolEffect(.bounce, value: isWorking && !reduceMotion)
    }
    .padding(12).background(.black.opacity(0.16), in: .rect(cornerRadius: 14))
  }

  private var isWorking: Bool { !isResting && station.semanticState == .working }

  private var headline: String {
    if let title = task?.title { return title }
    return isResting ? "Recovery sprint selected" : "No task assigned"
  }

  private func verifiedSummary(actual: Int, overclaim: Int) -> String {
    let base = "Verified actual " + String(actual)
    return overclaim > 0 ? base + " · Overclaim +" + String(overclaim) : base
  }

  @ViewBuilder private func report(_ result: TaskResult, reviewed: Bool) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 3) {
        Text("Reported quality ")
        Text(String(result.reportedQuality)).contentTransition(.numericText(value: Double(result.reportedQuality)))
        Text(" · Evidence " + String(result.evidenceCompleteness) + "%")
      }
      .font(.caption.weight(.semibold))
      if reviewed {
        Text(result.verificationState.label).font(.caption).foregroundStyle(SoloTheme.mint)
        if let actual = result.revealedActualQuality {
          Text(verifiedSummary(actual: actual, overclaim: result.overclaimAmount)).font(.caption)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
      }
      Text(result.knownOperationalRisk).font(.caption2).foregroundStyle(.secondary)
    }
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
        if let task = store.tasks.first(where: { $0.assignedAgentID != nil && !$0.isReviewed }) { strip("Review \(task.title)", task: task) }
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
