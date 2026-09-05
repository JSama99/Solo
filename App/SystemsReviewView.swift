import SwiftUI

struct SystemsReviewView: View {
  var store: GameStore
  var taskID: UUID
  var onContinue: () -> Void

  @Environment(AppSettingsStore.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dismiss) private var dismiss
  @State private var selectionTrigger = 0
  @State private var actionInFlight = false
  @State private var isContinuing = false

  private var session: WorkSessionRecord? { store.workSession(for: taskID) }
  private var task: SoloTask? { store.tasks.first(where: { $0.id == taskID }) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          header
          if let session, let challenge = session.systemsChallenge {
            if session.completed {
              completion(session, challenge: challenge)
            } else if session.path == .manualReview {
              activeReview(session, challenge: challenge)
            } else {
              choice(session, challenge: challenge)
            }
          } else {
            ContentUnavailableView("Work Session unavailable", systemImage: "exclamationmark.triangle", description: Text("Stacks’ report can still use the standard review path."))
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Systems Review")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
        }
      }
    }
    .interactiveDismissDisabled(session?.path == .manualReview && session?.completed == false)
    .appSensoryFeedback(.selection, trigger: selectionTrigger)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("STACKS · WORK COMPLETE", systemImage: "point.3.connected.trianglepath.dotted")
        .font(.caption.weight(.black))
        .foregroundStyle(SoloTheme.amber)
      Text(task?.title ?? "Engineering & Execution")
        .font(.title2.weight(.bold))
        .fixedSize(horizontal: false, vertical: true)
      Text("Review whether Stacks’ implementation steps form a safe operational sequence. Technical correctness remains governed by the normal report and Hindsight flow.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func choice(_ session: WorkSessionRecord, challenge: SystemsReviewChallenge) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      operationalPanel(title: "FOUNDER DECISION") {
        decisionRow("Review Work", detail: "Sequence \(challenge.stepCount) implementation steps · Founder Attention -\(session.founderAttentionCost)", symbol: "eye.fill")
        decisionRow("Delegate", detail: "Let Stacks finalize the implementation · costs \(store.delegateAttentionCost) Founder Attention", symbol: "arrow.triangle.branch")
      }

      Button {
        guard store.beginManualSystemsReview(taskID: taskID) else { return }
        settings.playFeedback(.review)
      } label: {
        Label("REVIEW WORK", systemImage: "eye.fill")
          .font(.headline.weight(.black))
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(SoloTheme.amber, in: RoundedRectangle(cornerRadius: 14))
          .foregroundStyle(.black)
      }
      .buttonStyle(.plain)
      .disabled(store.attentionRemaining < session.founderAttentionCost)
      .accessibilityHint("Costs \(session.founderAttentionCost) Founder Attention and begins an untimed systems review")

      Button {
        guard store.delegateSystemsReview(taskID: taskID) else { return }
        settings.playFeedback(.dispatch)
      } label: {
        Label("DELEGATE", systemImage: "arrow.triangle.branch")
          .font(.headline.weight(.black))
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
      }
      .buttonStyle(.plain)
      .accessibilityHint("Lets Stacks finalize the implementation without Founder Review for \(store.delegateAttentionCost) Founder Attention, less than a manual review")

      if store.attentionRemaining < session.founderAttentionCost {
        Label("Insufficient Founder Attention for manual review. Delegation costs \(store.delegateAttentionCost) and remains available.", systemImage: "eye.slash")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(SoloTheme.amber)
      }
    }
  }

  private func activeReview(_ session: WorkSessionRecord, challenge: SystemsReviewChallenge) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text("DEPENDENCY BUILD")
          .font(.caption.weight(.black))
          .foregroundStyle(.secondary)
        Spacer()
        Label("UNTIMED", systemImage: "timer")
          .font(.caption2.weight(.bold))
          .foregroundStyle(SoloTheme.mint)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(challenge.title).font(.title3.weight(.bold))
        Text(challenge.summary).font(.subheadline).foregroundStyle(.secondary)
        Text("Tap each card in the order Stacks should execute it. Tap a selected card to remove it from the sequence.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      sequenceRail(session, challenge: challenge)

      Text("IMPLEMENTATION STEPS")
        .font(.caption.weight(.black))
        .foregroundStyle(.secondary)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
        ForEach(challenge.presentations(selection: session.systemsSequence)) { step in
          stepCard(step)
        }
      }
      .frame(maxWidth: .infinity)

      HStack(spacing: 12) {
        Button("RESET", systemImage: "arrow.counterclockwise") {
          guard !actionInFlight, store.resetSystemsReview(taskID: taskID) else { return }
          selectionTrigger += 1
          settings.playFeedback(.dispatch)
        }
        .buttonStyle(.bordered)
        .disabled(session.systemsSequence.isEmpty || actionInFlight)

        Button {
          submit(challenge: challenge)
        } label: {
          Label("SUBMIT REVIEW", systemImage: "checkmark.seal.fill")
            .font(.headline.weight(.black))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(SoloTheme.amber, in: RoundedRectangle(cornerRadius: 13))
            .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .disabled(session.systemsSequence.count != challenge.stepCount || actionInFlight)
        .accessibilityHint("Submits the complete sequence. Correctness is not disclosed before submission.")
      }
    }
    .animation(reduceMotion ? nil : .snappy, value: session.systemsSequence)
  }

  private func sequenceRail(_ session: WorkSessionRecord, challenge: SystemsReviewChallenge) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("EXECUTION SEQUENCE").font(.caption.weight(.black))
        Spacer()
        Text("\(session.systemsSequence.count)/\(challenge.stepCount)")
          .font(.caption.monospacedDigit().weight(.bold))
          .foregroundStyle(.secondary)
      }
      if session.systemsSequence.isEmpty {
        Text("No steps selected")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
      } else {
        ForEach(Array(session.systemsSequence.enumerated()), id: \.element) { index, id in
          if let step = challenge.steps.first(where: { $0.id == id }) {
            HStack(spacing: 12) {
              Text("\(index + 1)")
                .font(.caption.monospacedDigit().weight(.black))
                .frame(width: 28, height: 28)
                .background(SoloTheme.amber.opacity(0.18), in: Circle())
              Text(step.title).font(.subheadline.weight(.semibold))
              Spacer()
            }
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Execution sequence. \(session.systemsSequence.count) of \(challenge.stepCount) steps selected.")
  }

  private func stepCard(_ step: SystemsReviewStepPresentation) -> some View {
    Button {
      guard !actionInFlight else { return }
      let accepted: Bool
      if step.selectedPosition == nil {
        accepted = store.selectSystemsReviewStep(taskID: taskID, stepID: step.id)
      } else {
        accepted = store.removeSystemsReviewStep(taskID: taskID, stepID: step.id)
      }
      if accepted {
        selectionTrigger += 1
        settings.playFeedback(.review)
      }
    } label: {
      HStack(alignment: .top, spacing: 14) {
        if let position = step.selectedPosition {
          Text("\(position)")
            .font(.headline.monospacedDigit().weight(.black))
            .frame(width: 34, height: 34)
            .background(SoloTheme.amber, in: Circle())
            .foregroundStyle(.black)
        } else {
          Image(systemName: "plus")
            .font(.headline.weight(.bold))
            .frame(width: 34, height: 34)
            .background(.secondary.opacity(0.14), in: Circle())
        }
        VStack(alignment: .leading, spacing: 5) {
          Text(step.title).font(.headline).foregroundStyle(.primary)
          Text(step.detail).font(.footnote).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
      .background(step.selectedPosition == nil ? Color.secondary.opacity(0.09) : SoloTheme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 17))
      .overlay { RoundedRectangle(cornerRadius: 17).stroke(step.selectedPosition == nil ? Color.secondary.opacity(0.18) : SoloTheme.amber.opacity(0.45)) }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(step.accessibilityLabel)
    .accessibilityHint(step.selectedPosition == nil ? "Adds this step at the end of the execution sequence" : "Removes this step and renumbers the execution sequence")
  }

  private func completion(_ session: WorkSessionRecord, challenge: SystemsReviewChallenge) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      operationalPanel(title: "SYSTEMS REVIEW COMPLETE") {
        resultRow("Founder Review", session.founderReviewLabel)
        if session.path == .manualReview, let assessment = session.systemsAssessment {
          resultRow("Dependencies Reviewed", "\(assessment.dependencyCount)")
          resultRow("Verification Gates", "\(assessment.verificationGateCount)")
          resultRow("Founder Attention", "-\(session.founderAttentionCost)")
        } else {
          resultRow("Review Path", "Delegated")
          resultRow("Founder Attention", "-\(session.founderAttentionCost)")
        }
      }
      Text("Stacks’ implementation report is ready. Underlying engineering quality and delivered quality remain hidden until the normal reveal path allows them.")
        .font(.footnote)
        .foregroundStyle(.secondary)
      Button {
        guard !isContinuing else { return }
        isContinuing = true
        onContinue()
        dismiss()
      } label: {
        Label("CONTINUE", systemImage: "arrow.right")
          .font(.headline.weight(.black))
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(SoloTheme.mint, in: RoundedRectangle(cornerRadius: 14))
          .foregroundStyle(.black)
      }
      .buttonStyle(.plain)
      .disabled(isContinuing)
    }
  }

  private func submit(challenge: SystemsReviewChallenge) {
    guard !actionInFlight else { return }
    actionInFlight = true
    if store.submitSystemsReview(taskID: taskID) {
      settings.playFeedback(.verificationRequest)
    }
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(220)) }
      actionInFlight = false
    }
  }

  private func operationalPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title).font(.caption.weight(.black)).foregroundStyle(.secondary)
      content()
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
  }

  private func decisionRow(_ title: String, detail: String, symbol: String) -> some View {
    Label {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.weight(.bold))
        Text(detail).font(.footnote).foregroundStyle(.secondary)
      }
    } icon: { Image(systemName: symbol).foregroundStyle(SoloTheme.amber) }
  }

  private func resultRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label).foregroundStyle(.secondary)
      Spacer()
      Text(value).fontWeight(.bold).multilineTextAlignment(.trailing)
    }
    .font(.subheadline)
  }
}

#if DEBUG
enum SystemsReviewQAPhase: String, CaseIterable {
  case handoff
  case choice
  case active
  case selected
  case complete
  case report
}

/// Deterministic production-view harness for simulator and UI-test evidence.
struct SystemsReviewQAHost: View {
  @State private var store: GameStore
  @State private var presentation = PresentationCoordinator()
  private var phase: SystemsReviewQAPhase
  private var taskID: UUID

  init(phase: SystemsReviewQAPhase) {
    self.phase = phase
    let fixture = GameStore()
    fixture.resetCareer()
    fixture.founderName = "Systems QA"
    fixture.selectedDoctrine = .guided
    fixture.selectedProductType = .saas
    fixture.startCareer(seed: 7_704)
    fixture.selectThesisAndBegin()
    let id = fixture.tasks[0].id
    fixture.tasks[0].title = "Deploy Customer Data Service"
    fixture.tasks[0].detail = "Sequence the backend migration, verification, and controlled release."
    fixture.tasks[0].role = .engineering
    fixture.tasks[0].category = .product
    fixture.tasks[0].urgency = .important
    fixture.assign(agentID: "stacks", to: id)
    _ = fixture.prepareSystemsReview(taskID: id)
    if phase == .handoff {
      _ = fixture.pursueFundingOpportunity(id: "pioneer-ai-grant")
      if let choice = fixture.activeDilemma?.choices.first { fixture.selectDilemmaChoice(choice.id) }
      for agent in fixture.agents where agent.id != "stacks" { fixture.restAgent(agentID: agent.id) }
    }
    if phase != .choice && phase != .handoff {
      _ = fixture.beginManualSystemsReview(taskID: id)
      let order = ["backup", "prepare", "migrate", "validate", "switch", "monitor"]
      let selectionCount = phase == .active ? 0 : phase == .selected ? 3 : order.count
      for stepID in order.prefix(selectionCount) {
        _ = fixture.selectSystemsReviewStep(taskID: id, stepID: stepID)
      }
      if phase == .complete || phase == .report {
        _ = fixture.submitSystemsReview(taskID: id)
      }
      if phase == .report { fixture.review(taskID: id) }
    }
    _store = State(initialValue: fixture)
    taskID = id
  }

  var body: some View {
    Group {
      if phase == .report || phase == .handoff {
        FounderComputerScreen(store: store, presentation: presentation)
      } else {
        SystemsReviewView(store: store, taskID: taskID) { }
      }
    }
    .background(SoloTheme.background)
  }
}
#endif
