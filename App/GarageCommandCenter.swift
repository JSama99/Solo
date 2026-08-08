import SwiftUI

struct GarageCommandCenter: View {
  @Bindable var store: GameStore
  var presentation: PresentationCoordinator
  var onSelectTask: (UUID?) -> Void
  var selectedTaskID: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("COMMAND CONSOLE", systemImage: "slider.horizontal.3")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        Text(store.sprintPhase.title)
          .font(.caption.weight(.bold))
          .foregroundStyle(SoloTheme.mint)
      }

      Picker("Sprint intent", selection: Binding(
        get: { store.intent },
        set: {
          if store.setIntent($0) { onSelectTask(nil) }
        }
      )) {
        ForEach(SprintIntent.allCases) { intent in
          Label(intent.name, systemImage: intent.symbol).tag(intent)
        }
      }
      .pickerStyle(.segmented)
      .disabled(store.tasks.contains { $0.assignedAgentID != nil })

      Label("\(store.intent.summary) Your available work has been refreshed.", systemImage: store.intent.symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(SoloTheme.cyan)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SoloTheme.cyan.opacity(0.12), in: .rect(cornerRadius: 12))

      if let dilemma = store.activeDilemma {
        DisclosureGroup("Founder dilemma: \(dilemma.title)") {
          VStack(alignment: .leading, spacing: 8) {
            Text(dilemma.setup).font(.caption).foregroundStyle(.secondary)
            ForEach(dilemma.choices) { choice in
              Button {
                store.selectDilemmaChoice(choice.id)
              } label: {
                Text(choice.title)
              }
              .buttonStyle(.bordered)
              .tint(store.selectedDilemmaChoiceID == choice.id ? SoloTheme.cyan : .gray)
            }
          }
          .padding(.top, 6)
        }
        .font(.subheadline.weight(.semibold))
      }

      if let objective = store.currentObjective {
        Label("Objective: \(objective.title) — \(store.objectiveProgressText)", systemImage: "target")
          .font(.caption)
          .foregroundStyle(SoloTheme.mint)
      }

      VStack(spacing: 8) {
        ForEach(store.tasks) { task in
          GarageTaskRow(
            task: task,
            isSelected: task.id == selectedTaskID,
            onSelect: { onSelectTask(task.id == selectedTaskID ? nil : task.id) },
            onUnassign: { presentation.assign(agentID: nil, to: task.id, in: store) },
            onReview: { presentation.review(taskID: task.id, in: store) },
            onResolution: { presentationChoice in
              store.resolveReviewedTask(taskID: task.id, choice: presentationChoice)
            }
          )
        }
      }

      if selectedTaskID != nil {
        Label("Task armed — tap its android or workstation in the garage to assign.", systemImage: "hand.tap.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(SoloTheme.cyan)
      }
    }
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Garage command console")
  }
}

private struct GarageTaskRow: View {
  var task: SoloTask
  var isSelected: Bool
  var onSelect: () -> Void
  var onUnassign: () -> Void
  var onReview: () -> Void
  var onResolution: (TaskResolutionChoice) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Button(action: onSelect) {
        HStack(alignment: .top, spacing: 9) {
          Image(systemName: task.role.symbol)
            .foregroundStyle(isSelected ? SoloTheme.cyan : .secondary)
            .frame(width: 20)
          VStack(alignment: .leading, spacing: 2) {
            Text(task.title).font(.subheadline.weight(.bold))
            Text(task.assignedAgentID == nil ? "Select, then tap an android to assign" : "Assigned — live in the garage")
              .font(.caption)
              .foregroundStyle(task.assignedAgentID == nil ? .secondary : SoloTheme.cyan)
          }
          Spacer()
          Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
            .foregroundStyle(isSelected ? AnyShapeStyle(SoloTheme.cyan) : AnyShapeStyle(.tertiary))
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if let result = task.result {
        Text("Report \(result.reportedQuality) • Evidence \(result.evidenceCompleteness)% • \(result.verificationState.label)")
          .font(.caption2)
          .foregroundStyle(task.isReviewed ? SoloTheme.mint : SoloTheme.amber)
      }

      HStack(spacing: 8) {
        if task.assignedAgentID != nil {
          Button("Unassign", systemImage: "xmark") { onUnassign() }
            .buttonStyle(.bordered)
        }
        Button(task.isReviewed ? "Reviewed" : "Review", systemImage: task.isReviewed ? "checkmark.seal.fill" : "eye.fill") {
          onReview()
        }
        .buttonStyle(.bordered)
        .tint(SoloTheme.purple)
        .disabled(task.result == nil || task.isReviewed)
        if task.isReviewed {
          Menu("Resolve", systemImage: task.resolution?.symbol ?? "checkmark.circle") {
            ForEach(TaskResolutionChoice.allCases) { choice in
              Button(choice.title, systemImage: choice.symbol) { onResolution(choice) }
            }
          }
          .buttonStyle(.bordered)
          .tint(SoloTheme.purple)
          .disabled(task.resolutionLocked)
        }
      }
    }
    .padding(11)
    .background(isSelected ? SoloTheme.cyan.opacity(0.14) : .white.opacity(0.035), in: .rect(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(isSelected ? SoloTheme.cyan.opacity(0.85) : .white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
    }
    .accessibilityElement(children: .contain)
  }
}
