import SwiftUI
import UIKit

struct CommandDeck: View {
  @Bindable var store: GameStore
  var presentation: PresentationCoordinator
  var progression: FounderProgressionStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pickedTask: SoloTask?
  @State private var transitioning = false

  var body: some View {
    VStack(spacing: 0) {
      hud
      steps
      ScrollView {
        phaseContent
          .id(store.commandDeckPhase)
          .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 14)), removal: .opacity.combined(with: .offset(y: -10))))
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .animation(reduceMotion ? .easeInOut(duration: 0.12) : .smooth(duration: 0.3), value: store.commandDeckPhase)
      Button(actionTitle, systemImage: store.commandDeckPhase == .commit ? "bolt.fill" : "arrow.right") { advance() }
        .buttonStyle(SoloPrimaryButtonStyle())
        .disabled(!canAdvance || transitioning)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
    .sheet(item: $pickedTask) { task in AgentPicker(store: store, task: task) }
  }

  private var hud: some View {
    HStack(spacing: 8) {
      hudMetric("Runway", "\(store.stats.runway)d", "calendar")
      hudMetric("Capital", store.stats.capital.formatted(.currency(code: "USD").precision(.fractionLength(0))), "dollarsign")
      hudMetric("Attention", "\(store.attentionRemaining)", "eye.fill")
    }
    .padding(12)
    .background(SoloTheme.background)
  }

  private func hudMetric(_ name: String, _ value: String, _ symbol: String) -> some View {
    Label { VStack(alignment: .leading, spacing: 2) { Text(name).font(.caption2); Text(value).font(.caption.weight(.bold).monospacedDigit()) } } icon: { Image(systemName: symbol) }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityLabel("\(name), \(value)")
  }

  private var steps: some View {
    HStack(spacing: 4) {
      ForEach(SprintPhase.allCases) { phase in
        Button {
          store.returnToCommandDeckPhase(phase)
        } label: {
          VStack(spacing: 3) {
            Image(systemName: phase.rawValue < store.commandDeckPhase.rawValue ? "checkmark.circle.fill" : phase == store.commandDeckPhase ? "circle.inset.filled" : "circle")
            Text(phase.title).font(.caption2).lineLimit(1)
          }
          .frame(maxWidth: .infinity)
          .foregroundStyle(phase.rawValue <= store.maxPhaseReached ? SoloTheme.cyan : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(phase.rawValue > store.maxPhaseReached)
      }
    }
    .padding(.horizontal, 12)
  }

  @ViewBuilder private var phaseContent: some View {
    switch store.commandDeckPhase {
    case .situation: situation
    case .intent: intent
    case .assign: assign
    case .commit: commit
    }
  }

  private var situation: some View {
    VStack(alignment: .leading, spacing: 14) {
      heading("Situation", "Make the founder call before setting direction.")
      if let dilemma = store.activeDilemma {
        Text(dilemma.title).font(.title3.bold())
        Text(dilemma.setup).foregroundStyle(.secondary)
        ForEach(dilemma.choices) { choice in
          Button {
            store.selectDilemmaChoice(choice.id)
            UIAccessibility.post(notification: .announcement, argument: "Selected \(choice.title). Continue is available.")
          } label: {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: store.selectedDilemmaChoiceID == choice.id ? "checkmark.circle.fill" : "circle")
              VStack(alignment: .leading) { Text(choice.title).font(.headline); Text(choice.detail).font(.caption).foregroundStyle(.secondary); Text(choice.consequencePreview).font(.caption.weight(.semibold)).foregroundStyle(SoloTheme.amber) }
              Spacer()
            }
            .padding(14)
            .background(store.selectedDilemmaChoiceID == choice.id ? SoloTheme.cyan.opacity(0.14) : SoloTheme.card, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(store.selectedDilemmaChoiceID == choice.id ? SoloTheme.cyan : .clear, lineWidth: 2) }
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(store.selectedDilemmaChoiceID == choice.id ? .isSelected : [])
        }
      } else { ContentUnavailableView("No Founder Dilemma", systemImage: "checkmark.shield") }
    }
  }

  private var intent: some View {
    VStack(alignment: .leading, spacing: 14) {
      heading("Intent", "Set the operating bias for this sprint.")
      ForEach(SprintIntent.allCases) { intent in
        Button { _ = store.setIntent(intent) } label: {
          HStack(spacing: 14) { Image(systemName: intent.symbol).font(.title2).frame(width: 30); VStack(alignment: .leading) { Text(intent.name).font(.headline); Text(intent.summary).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: store.intent == intent ? "checkmark.circle.fill" : "circle") }
            .padding(16).background(store.intent == intent ? SoloTheme.cyan.opacity(0.14) : SoloTheme.card, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.intent == intent ? .isSelected : [])
      }
    }
  }

  private var assign: some View {
    VStack(alignment: .leading, spacing: 14) {
      heading("Assign", "Pair each priority task with one agent.")
      ForEach(store.tasks) { task in
        VStack(alignment: .leading, spacing: 10) {
          Text(task.title).font(.headline); Text(task.detail).font(.caption).foregroundStyle(.secondary)
          if let agentID = task.assignedAgentID, let agent = store.agents.first(where: { $0.id == agentID }) {
            HStack { Label(agent.name, systemImage: "person.fill"); Spacer(); Text(task.result?.confidenceRangeLabel ?? "Reported range pending").font(.caption.monospacedDigit()) }.padding(12).background(SoloTheme.cyan.opacity(0.14), in: .rect(cornerRadius: 12))
          }
          Button(task.assignedAgentID == nil ? "Assign Agent" : "Change Agent", systemImage: "person.badge.plus") { pickedTask = task }.buttonStyle(.bordered).frame(minHeight: 44)
        }
        .padding(16).background(SoloTheme.card, in: .rect(cornerRadius: 18))
      }
    }
  }

  private var commit: some View {
    VStack(alignment: .leading, spacing: 14) {
      heading("Commit", "Review fogged reports using Founder Attention, then resolve the sprint.")
      ForEach(store.tasks.filter { $0.assignedAgentID != nil }) { task in
        VStack(alignment: .leading, spacing: 10) {
          Text(task.title).font(.headline)
          if let result = task.result {
            if let actual = result.revealedActualQuality {
              Label("Verified \(actual)", systemImage: result.overclaimAmount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill").foregroundStyle(result.overclaimAmount > 0 ? SoloTheme.amber : SoloTheme.mint)
              if result.overclaimAmount > 0 { Text("Below reported range").font(.caption.weight(.bold)).foregroundStyle(SoloTheme.amber) }
            } else {
              Text("Reported range: \(result.confidenceRangeLabel)").font(.subheadline.monospacedDigit())
              Button("Review for 1 Attention", systemImage: "eye.fill") { presentation.review(taskID: task.id, in: store) }.buttonStyle(.bordered).disabled(task.isReviewed)
            }
          }
          if task.isReviewed && !task.resolutionLocked { Menu("Resolve", systemImage: "checkmark.circle") { ForEach(TaskResolutionChoice.allCases) { choice in Button(choice.title, systemImage: choice.symbol) { store.resolveReviewedTask(taskID: task.id, choice: choice) } } }.buttonStyle(.bordered) }
        }
        .padding(16).background(SoloTheme.card, in: .rect(cornerRadius: 18))
      }
    }
  }

  private func heading(_ title: String, _ detail: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader); Text(detail).foregroundStyle(.secondary) } }
  private var actionTitle: String { ["Continue to Intent", "Continue to Assign", "Continue to Commit", "Commit Sprint"][store.commandDeckPhase.rawValue] }
  private var canAdvance: Bool { switch store.commandDeckPhase { case .situation: store.activeDilemma == nil || store.selectedDilemmaChoiceID != nil; case .intent: true; case .assign: store.tasks.contains { $0.assignedAgentID != nil }; case .commit: !store.tasks.contains { $0.isReviewed && !$0.resolutionLocked } } }
  private func advance() { guard !transitioning else { return }; if store.commandDeckPhase == .commit { presentation.commit(in: store, progression: progression); return }; transitioning = true; _ = store.advanceCommandDeck(); UIAccessibility.post(notification: .layoutChanged, argument: store.commandDeckPhase.title); DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.12 : 0.32)) { transitioning = false } }
}

private struct AgentPicker: View {
  @Environment(\.dismiss) private var dismiss
  var store: GameStore
  var task: SoloTask
  var body: some View { NavigationStack { List(store.agents) { agent in Button { store.assign(agentID: agent.id, to: task.id); UIAccessibility.post(notification: .announcement, argument: "\(agent.name) assigned to \(task.title)"); dismiss() } label: { HStack { Text(agent.initials).font(.caption.weight(.black)).frame(width: 36, height: 36).background(SoloTheme.purple, in: .circle); VStack(alignment: .leading) { Text(agent.name); Text("\(agent.role.rawValue) · Trust \(agent.trust)").font(.caption).foregroundStyle(.secondary) }; Spacer(); if agent.assignment != nil { Text("Busy").font(.caption).foregroundStyle(SoloTheme.amber) } } }.buttonStyle(.plain) }.navigationTitle("Assign Agent") } }
}
