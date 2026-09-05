import SwiftUI

struct EvidenceTriageView: View {
  var store: GameStore
  var taskID: UUID
  var onContinue: () -> Void

  @Environment(AppSettingsStore.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dismiss) private var dismiss
  @State private var decisionTrigger = 0
  @State private var actionInFlight = false
  @State private var isContinuing = false

  private var session: WorkSessionRecord? { store.workSession(for: taskID) }
  private var task: SoloTask? { store.tasks.first(where: { $0.id == taskID }) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          header
          if let session {
            if session.completed {
              completion(session)
            } else if session.path == .manualReview {
              activeReview(session)
            } else {
              choice(session)
            }
          } else {
            ContentUnavailableView("Work Session unavailable", systemImage: "exclamationmark.triangle", description: Text("Aurora’s report can still use the standard review path."))
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Evidence Triage")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
        }
      }
    }
    .interactiveDismissDisabled(session?.path == .manualReview && session?.completed == false)
    .appSensoryFeedback(.selection, trigger: decisionTrigger)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("AURORA · WORK COMPLETE", systemImage: "sparkle.magnifyingglass")
        .font(.caption.weight(.black))
        .foregroundStyle(SoloTheme.cyan)
      Text(task?.title ?? "Research & Evidence")
        .font(.title2.weight(.bold))
        .fixedSize(horizontal: false, vertical: true)
      Text("Decide how Aurora’s reported evidence becomes usable company output. Source correctness remains unresolved during review.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func choice(_ session: WorkSessionRecord) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      operationalPanel(title: "FOUNDER DECISION") {
        decisionRow("Review Work", detail: "Classify \(session.cards.count) evidence items · Founder Attention -\(session.founderAttentionCost)", symbol: "eye.fill")
        decisionRow("Delegate", detail: "Let Aurora finalize the packet · Founder Attention -\(store.delegateAttentionCost)", symbol: "arrow.triangle.branch")
      }
      Button {
        guard store.beginManualEvidenceTriage(taskID: taskID) else { return }
        settings.playFeedback(.review)
      } label: {
        Label("REVIEW WORK", systemImage: "eye.fill")
          .font(.headline.weight(.black))
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(SoloTheme.cyan, in: RoundedRectangle(cornerRadius: 14))
          .foregroundStyle(.black)
      }
      .buttonStyle(.plain)
      .disabled(store.attentionRemaining < session.founderAttentionCost)
      .accessibilityHint("Costs \(session.founderAttentionCost) Founder Attention and begins an untimed evidence review")
      Button {
        guard store.delegateEvidenceTriage(taskID: taskID) else { return }
        settings.playFeedback(.dispatch)
      } label: {
        Label("DELEGATE", systemImage: "arrow.triangle.branch")
          .font(.headline.weight(.black))
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
      }
      .buttonStyle(.plain)
      .accessibilityHint("Lets Aurora finalize the packet without Founder Review for \(store.delegateAttentionCost) Founder Attention, less than a manual review")

      if store.attentionRemaining < session.founderAttentionCost {
        Label("Insufficient Founder Attention for manual review. Delegation costs \(store.delegateAttentionCost) and remains available.", systemImage: "eye.slash")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(SoloTheme.amber)
          .accessibilityLabel("Insufficient Founder Attention for manual review. Delegate remains available.")
      }
    }
  }

  private func activeReview(_ session: WorkSessionRecord) -> some View {
    let progress = EvidenceTriageProgress(
      decisionCount: session.decisions.count,
      cardCount: session.cards.count
    )
    return VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text("EVIDENCE \(progress.currentItem) OF \(progress.itemCount)")
          .font(.caption.monospacedDigit().weight(.black))
          .foregroundStyle(.secondary)
        Spacer()
        Label("UNTIMED", systemImage: "timer")
          .font(.caption2.weight(.bold))
          .foregroundStyle(SoloTheme.mint)
      }
      ProgressView(
        value: progress.value,
        total: progress.total
      )
        .tint(SoloTheme.cyan)

      if let card = session.nextCardPresentation {
        evidenceCard(card)
          .id(card.id)
          .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
        classificationButtons
      }
    }
    .animation(reduceMotion ? nil : .snappy, value: session.decisions.count)
  }

  private func evidenceCard(_ card: EvidenceCardPresentation) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(card.source.uppercased(), systemImage: "doc.text.magnifyingglass")
        .font(.caption.weight(.black))
        .foregroundStyle(SoloTheme.cyan)
      Text(card.headline)
        .font(.title3.weight(.bold))
        .fixedSize(horizontal: false, vertical: true)
      Text(card.detail)
        .font(.body)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      Divider()
      Text(card.provenance)
        .font(.footnote.monospaced())
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12)) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(card.accessibilityLabel)
    .accessibilityHint("Choose Reject, Verify, or Use. No correctness is disclosed during classification.")
  }

  private var classificationButtons: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) { actionButtons }
      VStack(spacing: 10) { actionButtons }
    }
  }

  @ViewBuilder private var actionButtons: some View {
    ForEach(EvidenceTriageAction.allCases) { action in
      Button {
        classify(action)
      } label: {
        Label(action.title, systemImage: action.symbol)
          .font(.subheadline.weight(.black))
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(actionColor(action).opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
          .overlay { RoundedRectangle(cornerRadius: 14).stroke(actionColor(action).opacity(0.55)) }
      }
      .buttonStyle(.plain)
      .disabled(actionInFlight)
      .accessibilityHint("Classifies the current evidence as \(action.title.lowercased())")
    }
  }

  private func completion(_ session: WorkSessionRecord) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      operationalPanel(title: "REVIEW COMPLETE") {
        resultRow("Founder Review", session.founderReviewLabel)
        if session.path == .manualReview {
          resultRow("Evidence Used", "\(session.usedCount)")
          resultRow("Verification Requested", "\(session.verifiedCount)")
          resultRow("Evidence Rejected", "\(session.rejectedCount)")
          resultRow("Founder Attention", "-\(session.founderAttentionCost)")
        } else {
          resultRow("Review Path", "Delegated")
          resultRow("Founder Attention", "-\(session.founderAttentionCost)")
        }
      }
      Text("Aurora’s operational report is ready. Evidence truth remains governed by the normal verification and Hindsight flow.")
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
    } icon: { Image(systemName: symbol).foregroundStyle(SoloTheme.cyan) }
  }

  private func resultRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label).foregroundStyle(.secondary)
      Spacer()
      Text(value).fontWeight(.bold).multilineTextAlignment(.trailing)
    }
    .font(.subheadline)
  }

  private func classify(_ action: EvidenceTriageAction) {
    guard !actionInFlight else { return }
    actionInFlight = true
    let accepted = store.classifyEvidence(taskID: taskID, action: action)
    if accepted {
      decisionTrigger += 1
      settings.playFeedback(action == .verify ? .verificationRequest : .review)
    }
    Task { @MainActor in
      if !reduceMotion { try? await Task.sleep(for: .milliseconds(180)) }
      actionInFlight = false
    }
  }

  private func actionColor(_ action: EvidenceTriageAction) -> Color {
    switch action {
    case .reject: SoloTheme.coral
    case .verify: SoloTheme.amber
    case .use: SoloTheme.cyan
    }
  }
}

/// Presentation-only normalization for legacy or transitional Work Session
/// records. It never mutates the canonical cards or decisions.
struct EvidenceTriageProgress: Equatable, Sendable {
  let completedCount: Int
  let itemCount: Int

  init(decisionCount: Int, cardCount: Int) {
    itemCount = max(0, cardCount)
    completedCount = min(max(0, decisionCount), max(itemCount, 1))
  }

  var value: Double { Double(completedCount) }
  var total: Double { Double(max(itemCount, 1)) }
  var currentItem: Int {
    guard itemCount > 0 else { return 0 }
    return min(completedCount + 1, itemCount)
  }
}

#if DEBUG
enum WorkSessionQAPhase: String, CaseIterable {
  case handoff
  case choice
  case active
  case complete
  case report
}

/// Deterministic visual-acceptance harness. It renders the production views
/// and production store methods; it is compiled out of Release builds.
struct WorkSessionQAHost: View {
  @State private var store: GameStore
  @State private var presentation = PresentationCoordinator()
  private var phase: WorkSessionQAPhase
  private var taskID: UUID

  init(phase: WorkSessionQAPhase) {
    self.phase = phase
    let fixture = GameStore()
    fixture.resetCareer()
    fixture.founderName = "Visual QA"
    fixture.selectedDoctrine = .guided
    fixture.selectedProductType = .saas
    fixture.startCareer(seed: 7_703)
    fixture.selectThesisAndBegin()
    let id = fixture.tasks[0].id
    fixture.tasks[0].title = "Validate Retention Signal"
    fixture.tasks[0].detail = "Separate durable retention evidence from loud but incomplete claims."
    fixture.tasks[0].role = .research
    fixture.tasks[0].category = .research
    fixture.tasks[0].urgency = .important
    fixture.assign(agentID: "aurora", to: id)
    _ = fixture.prepareEvidenceTriage(taskID: id)
    if phase == .handoff {
      _ = fixture.pursueFundingOpportunity(id: "pioneer-ai-grant")
      if let choice = fixture.activeDilemma?.choices.first { fixture.selectDilemmaChoice(choice.id) }
      for agent in fixture.agents where agent.id != "aurora" { fixture.restAgent(agentID: agent.id) }
    }
    if phase != .choice && phase != .handoff {
      _ = fixture.beginManualEvidenceTriage(taskID: id)
      if phase == .complete || phase == .report {
        let count = fixture.workSession(for: id)?.cards.count ?? 0
        for _ in 0..<count { _ = fixture.classifyEvidence(taskID: id, action: .verify) }
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
        EvidenceTriageView(store: store, taskID: taskID) { }
      }
    }
    .background(SoloTheme.background)
  }
}
#endif
