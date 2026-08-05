import Foundation
import Observation

@MainActor
@Observable
final class PresentationCoordinator {
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
  private(set) var visibleSprintResult: VisibleSprintResult?

  func assign(agentID: String?, to taskID: UUID, in store: GameStore) {
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
    guard let agentID,
          store.tasks.first(where: { $0.id == taskID })?.result != nil else { return }
    latestEvent = .assignment(
      id: UUID(),
      taskID: taskID,
      agentID: agentID,
      restored: restored
    )
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
  }

  func commit(in store: GameStore, progression: FounderProgressionStore) {
    let tasksBefore = store.tasks
    let statsBefore = store.stats
    let evidenceBefore = store.evidence.count
    let ventureBefore = store.venture
    let sprintBefore = store.sprint
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
      evidenceBefore: evidenceBefore,
      evidenceAfter: store.evidence.count,
      transition: transition
    )
    visibleSprintResult = visible
    latestEvent = .sprint(id: UUID(), result: visible)
    progression.observe(trackRecord: store.stats.trackRecord)
    if store.careerOutcome != nil {
      progression.recordCareerCompletion(trackRecord: store.stats.trackRecord)
    }
  }

  func clearSprintPresentation() {
    visibleSprintResult = nil
  }

  func clearLatestEvent(id: UUID) {
    guard latestEvent?.id == id else { return }
    latestEvent = nil
  }
}
