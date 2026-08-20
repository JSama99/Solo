import Foundation
import Observation

@MainActor
@Observable
final class PresentationCoordinator {
  enum AgentPhase: String, CaseIterable, Equatable, Sendable {
    case idle
    case assignmentReceived
    case working
    case workComplete
    case awaitingReview
    case reviewing
    case reviewed
    case resolving
    case resolved

    var statusLabel: String {
      switch self {
      case .idle: "Ready"
      case .assignmentReceived: "Task assigned"
      case .working: "Working"
      case .workComplete: "Work complete"
      case .awaitingReview: "Awaiting review"
      case .reviewing: "Founder review"
      case .reviewed: "Reviewed"
      case .resolving: "Locking decision"
      case .resolved: "Resolved"
      }
    }
  }

  struct AgentPresentation: Equatable, Sendable {
    var taskID: UUID?
    var agentID: String
    var taskTitle: String
    var phase: AgentPhase
    var progress: Double
    var reviewRevealStep = 0
    var resolutionChoice: TaskResolutionChoice?
    var sequenceID = UUID()
  }

  struct Timing: Equatable, Sendable {
    var assignmentAcknowledgement: Duration = .milliseconds(300)
    var working: Duration = .milliseconds(2_000)
    var progressTick: Duration = .milliseconds(100)
    var workComplete: Duration = .milliseconds(450)
    var reviewFocus: Duration = .milliseconds(250)
    var reviewStagger: Duration = .milliseconds(320)
    var resolution: Duration = .milliseconds(550)

    static var immediate: Self {
      Self(
        assignmentAcknowledgement: .zero,
        working: .zero,
        progressTick: .zero,
        workComplete: .zero,
        reviewFocus: .zero,
        reviewStagger: .zero,
        resolution: .zero
      )
    }
  }

  enum Event: Identifiable, Equatable {
    case assignment(id: UUID, taskID: UUID, agentID: String, restored: Bool)
    case review(id: UUID, taskID: UUID, agentID: String, result: VisibleTaskResult, evidenceChanged: Bool)
    case sprint(id: UUID, result: VisibleSprintResult)

    var id: UUID {
      switch self {
      case .assignment(let id, _, _, _), .review(let id, _, _, _, _), .sprint(let id, _): id
      }
    }
  }

  private(set) var latestEvent: Event?
  private(set) var eventHistory: [Event] = []
  private var bufferedVenture = 0
  private var bufferedSprint = 0
  private(set) var visibleSprintResult: VisibleSprintResult?
  private(set) var agentPresentations: [String: AgentPresentation] = [:]
  private(set) var debugPresentation: AgentPresentation?
  private var sequences: [String: Task<Void, Never>] = [:]
  private var timing: Timing

  init(timing: Timing = .init()) {
    self.timing = timing
  }

  func presentation(for agentID: String) -> AgentPresentation? {
    agentPresentations[agentID]
  }

  func assign(agentID: String?, to taskID: UUID, in store: GameStore) {
    let previouslyAssignedAgentID = store.tasks.first(where: { $0.id == taskID })?.assignedAgentID
    let restored = agentID.map { selectedAgentID in
      store.reportCache.contains {
        $0.venture == store.venture
          && $0.sprint == store.sprint
          && $0.taskID == taskID
          && $0.agentID == selectedAgentID
          && $0.intent == store.intent
      }
    } ?? false
    store.assign(agentID: agentID, to: taskID)
    if let previouslyAssignedAgentID, previouslyAssignedAgentID != agentID {
      cancelPresentation(for: previouslyAssignedAgentID)
    }
    guard let agentID else { return }
    guard let task = store.tasks.first(where: {
      $0.id == taskID && $0.assignedAgentID == agentID && $0.result != nil
    }) else { return }
    latestEvent = .assignment(
      id: UUID(),
      taskID: taskID,
      agentID: agentID,
      restored: restored
    )
    publish(latestEvent!, in: store)
    startAssignmentSequence(task: task, agentID: agentID, store: store)
  }

  func review(taskID: UUID, in store: GameStore) {
    let evidenceBefore = store.evidence.count
    store.review(taskID: taskID)
    guard let task = store.tasks.first(where: { $0.id == taskID }),
          task.isReviewed,
          let agentID = task.assignedAgentID,
          let result = task.result else { return }
    latestEvent = .review(
      id: UUID(),
      taskID: taskID,
      agentID: agentID,
      result: VisibleSimulationProjection.taskResult(from: result),
      evidenceChanged: store.evidence.count != evidenceBefore
    )
    publish(latestEvent!, in: store)
    startReviewSequence(task: task, agentID: agentID)
  }

  func resolve(taskID: UUID, choice: TaskResolutionChoice, in store: GameStore) {
    guard let taskBefore = store.tasks.first(where: { $0.id == taskID }),
          let agentID = taskBefore.assignedAgentID else { return }
    store.resolveReviewedTask(taskID: taskID, choice: choice)
    guard store.tasks.first(where: { $0.id == taskID })?.resolutionLocked == true else { return }
    sequences[agentID]?.cancel()
    var state = agentPresentations[agentID] ?? AgentPresentation(
      taskID: taskID,
      agentID: agentID,
      taskTitle: taskBefore.title,
      phase: .reviewed,
      progress: 1
    )
    state.phase = .resolving
    state.resolutionChoice = choice
    state.sequenceID = UUID()
    agentPresentations[agentID] = state
    let sequenceID = state.sequenceID
    sequences[agentID] = Task { @MainActor [weak self] in
      guard let self else { return }
      await pause(timing.resolution)
      guard !Task.isCancelled,
            agentPresentations[agentID]?.sequenceID == sequenceID else { return }
      agentPresentations[agentID]?.phase = .resolved
    }
  }

  func commit(in store: GameStore, progression: FounderProgressionStore) {
    guard visibleSprintResult == nil, store.report == nil else { return }
    if store.prepareDivergenceOfferIfEligible() { return }
    let tasksBefore = store.tasks
    let statsBefore = store.stats
    let ventureBefore = store.venture
    let sprintBefore = store.sprint
    let sprintEvidenceCount = store.evidence.filter {
      $0.venture == ventureBefore && $0.sprint == sprintBefore
    }.count
    let snapshot = TechComSnapshot(founderName: store.founderName, venture: ventureBefore, sprint: sprintBefore, stats: statsBefore, agents: store.agents, tasks: tasksBefore, dilemmaChoice: store.selectedDilemmaChoice)
    store.commitSprint()
    guard let canonicalReport = store.report else { return }
    let transition: VisibleSprintResult.Transition
    if let outcome = store.careerOutcome {
      transition = .careerEnded(outcome.kind)
    } else if ventureBefore == 1 && sprintBefore == 12 {
      transition = .ventureCompleted
    } else {
      transition = .nextSprint
    }
    let visible = VisibleSimulationProjection.sprintResult(
      canonicalReport: canonicalReport,
      venture: ventureBefore,
      tasks: tasksBefore,
      statsBefore: statsBefore,
      statsAfter: store.stats,
      agents: store.agents,
      evidenceBefore: 0,
      evidenceAfter: sprintEvidenceCount,
      transition: transition
    )
    visibleSprintResult = visible
    latestEvent = .sprint(id: UUID(), result: visible)
    buffer(latestEvent!, venture: ventureBefore, sprint: sprintBefore)
    store.recordTechComHeadlines(events: eventHistory, snapshot: snapshot)
    eventHistory = []
    progression.observe(trackRecord: store.stats.trackRecord)
    if store.careerOutcome != nil {
      progression.recordCareerCompletion(trackRecord: store.stats.trackRecord)
    }
  }

  func clearSprintPresentation() {
    visibleSprintResult = nil
    cancelAllAgentPresentations()
  }

  func clearLatestEvent(id: UUID) {
    guard latestEvent?.id == id else { return }
    latestEvent = nil
  }

  private func publish(_ event: Event, in store: GameStore) {
    buffer(event, venture: store.venture, sprint: store.sprint)
  }

  private func buffer(_ event: Event, venture: Int, sprint: Int) {
    if bufferedVenture != venture || bufferedSprint != sprint {
      eventHistory = []
      bufferedVenture = venture
      bufferedSprint = sprint
    }
    eventHistory.append(event)
  }

  func cancelPresentation(for agentID: String) {
    sequences[agentID]?.cancel()
    sequences[agentID] = nil
    agentPresentations[agentID] = nil
  }

  func cancelAllAgentPresentations() {
    sequences.values.forEach { $0.cancel() }
    sequences = [:]
    agentPresentations = [:]
  }

  #if DEBUG
  func stageDebug(_ phase: AgentPhase, agentID: String = "aurora") {
    debugPresentation = AgentPresentation(
      taskID: nil,
      agentID: agentID,
      taskTitle: "Validate launch evidence",
      phase: phase,
      progress: phase == .working ? 0.58 : (phase == .idle || phase == .assignmentReceived ? 0 : 1),
      reviewRevealStep: phase == .reviewing ? 3 : (phase == .reviewed || phase == .resolved ? 5 : 0),
      resolutionChoice: phase == .resolving || phase == .resolved ? .approve : nil
    )
  }

  func clearDebugPresentation() {
    debugPresentation = nil
  }
  #endif

  private func startAssignmentSequence(task: SoloTask, agentID: String, store: GameStore) {
    sequences[agentID]?.cancel()
    let state = AgentPresentation(
      taskID: task.id,
      agentID: agentID,
      taskTitle: task.title,
      phase: .assignmentReceived,
      progress: 0
    )
    agentPresentations[agentID] = state
    let sequenceID = state.sequenceID
    sequences[agentID] = Task { @MainActor [weak self, weak store] in
      guard let self, let store else { return }
      await pause(timing.assignmentAcknowledgement)
      guard assignmentIsCurrent(taskID: task.id, agentID: agentID, sequenceID: sequenceID, store: store) else { return }
      agentPresentations[agentID]?.phase = .working

      let tickSeconds = max(0.001, timing.progressTick.timeInterval)
      let workingSeconds = max(0, timing.working.timeInterval)
      let tickCount = max(1, Int((workingSeconds / tickSeconds).rounded(.up)))
      for tick in 1...tickCount {
        await pause(timing.progressTick)
        guard assignmentIsCurrent(taskID: task.id, agentID: agentID, sequenceID: sequenceID, store: store) else { return }
        agentPresentations[agentID]?.progress = min(1, Double(tick) / Double(tickCount))
      }

      guard assignmentIsCurrent(taskID: task.id, agentID: agentID, sequenceID: sequenceID, store: store) else { return }
      agentPresentations[agentID]?.progress = 1
      agentPresentations[agentID]?.phase = .workComplete
      await pause(timing.workComplete)
      guard assignmentIsCurrent(taskID: task.id, agentID: agentID, sequenceID: sequenceID, store: store) else { return }
      agentPresentations[agentID]?.phase = .awaitingReview
    }
  }

  private func startReviewSequence(task: SoloTask, agentID: String) {
    sequences[agentID]?.cancel()
    var state = agentPresentations[agentID] ?? AgentPresentation(
      taskID: task.id,
      agentID: agentID,
      taskTitle: task.title,
      phase: .awaitingReview,
      progress: 1
    )
    state.phase = .reviewing
    state.reviewRevealStep = 0
    state.sequenceID = UUID()
    agentPresentations[agentID] = state
    let sequenceID = state.sequenceID
    sequences[agentID] = Task { @MainActor [weak self] in
      guard let self else { return }
      await pause(timing.reviewFocus)
      for step in 1...5 {
        guard !Task.isCancelled,
              agentPresentations[agentID]?.sequenceID == sequenceID else { return }
        agentPresentations[agentID]?.reviewRevealStep = step
        if step < 5 { await pause(timing.reviewStagger) }
      }
      guard !Task.isCancelled,
            agentPresentations[agentID]?.sequenceID == sequenceID else { return }
      agentPresentations[agentID]?.phase = .reviewed
    }
  }

  private func assignmentIsCurrent(
    taskID: UUID,
    agentID: String,
    sequenceID: UUID,
    store: GameStore
  ) -> Bool {
    guard !Task.isCancelled,
          agentPresentations[agentID]?.sequenceID == sequenceID,
          let task = store.tasks.first(where: { $0.id == taskID }) else { return false }
    if task.assignedAgentID != agentID || task.result == nil {
      cancelPresentation(for: agentID)
      return false
    }
    return true
  }

  private func pause(_ duration: Duration) async {
    guard duration > .zero else {
      await Task.yield()
      return
    }
    try? await Task.sleep(for: duration)
  }
}

private extension Duration {
  var timeInterval: TimeInterval {
    let parts = components
    return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
  }
}
