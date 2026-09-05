import SwiftUI

struct CampaignCalibrationView: View {
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
          if let session, let challenge = session.campaignChallenge {
            if session.completed { completion(session) }
            else if session.path == .manualReview { activeReview(session, challenge: challenge) }
            else { choice(session, challenge: challenge) }
          } else {
            ContentUnavailableView("Work Session unavailable", systemImage: "exclamationmark.triangle", description: Text("Brio’s report can still use the standard review path."))
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Campaign Calibration")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
        }
      }
    }
    .interactiveDismissDisabled(session?.path == .manualReview && session?.completed == false)
    .appSensoryFeedback(.selection, trigger: selectionTrigger)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("BRIO · WORK COMPLETE", systemImage: "scope")
        .font(.caption.weight(.black)).foregroundStyle(SoloTheme.coral)
      Text(task?.title ?? "Growth & Campaigns").font(.title2.weight(.bold))
      Text("Calibrate who Brio should reach, what the campaign should say, and where it should meet them.")
        .font(.subheadline).foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func choice(_ session: WorkSessionRecord, challenge: CampaignCalibrationChallenge) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      panel(title: "FOUNDER DECISION") {
        decisionRow("Review Work", detail: "Assemble Brio’s campaign · Founder Attention -\(session.founderAttentionCost)", symbol: "eye.fill")
        decisionRow("Delegate", detail: "Let Brio finalize the campaign · costs \(store.delegateAttentionCost) Founder Attention", symbol: "arrow.triangle.branch")
      }
      objectiveCard(challenge)
      actionButton("REVIEW WORK", symbol: "eye.fill", primary: true) {
        guard store.beginManualCampaignCalibration(taskID: taskID) else { return }
        settings.playFeedback(.review)
      }
      .disabled(store.attentionRemaining < session.founderAttentionCost)
      .accessibilityHint("Costs \(session.founderAttentionCost) Founder Attention and begins an untimed campaign review")
      actionButton("DELEGATE", symbol: "arrow.triangle.branch", primary: false) {
        guard store.delegateCampaignCalibration(taskID: taskID) else { return }
        settings.playFeedback(.dispatch)
      }
      .accessibilityHint("Lets Brio finalize the campaign without Founder Review for \(store.delegateAttentionCost) Founder Attention, less than a manual review")
    }
  }

  private func activeReview(_ session: WorkSessionRecord, challenge: CampaignCalibrationChallenge) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text("CAMPAIGN MATCH").font(.caption.weight(.black)).foregroundStyle(.secondary)
        Spacer()
        Label("UNTIMED", systemImage: "timer").font(.caption2.weight(.bold)).foregroundStyle(SoloTheme.mint)
      }
      objectiveCard(challenge)
      filledSlots(session, challenge: challenge)
      if session.campaignSelection.isComplete, let preview = challenge.preview(for: session.campaignSelection) {
        campaignPreview(preview)
        HStack(spacing: 12) {
          Button("EDIT", systemImage: "pencil") {
            guard !actionInFlight, store.resetCampaignCalibration(taskID: taskID) else { return }
            selectionTrigger += 1
          }.buttonStyle(.bordered)
          actionButton("SUBMIT REVIEW", symbol: "checkmark.seal.fill", primary: true) { submit() }
            .disabled(actionInFlight)
            .accessibilityHint("Submits this campaign combination. Compatibility is not disclosed before submission.")
        }
      } else {
        let slot = nextSlot(session.campaignSelection)
        Text("STEP \(slotIndex(slot)) OF 3 · \(slot.title.uppercased())")
          .font(.caption.weight(.black)).foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
          ForEach(challenge.presentations(for: slot)) { option in optionCard(option) }
        }
        .frame(maxWidth: .infinity)
      }
    }
    .animation(reduceMotion ? nil : .snappy, value: session.campaignSelection)
  }

  private func objectiveCard(_ challenge: CampaignCalibrationChallenge) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("CAMPAIGN OBJECTIVE").font(.caption.weight(.black)).foregroundStyle(SoloTheme.coral)
      Text(challenge.objective).font(.headline)
      Text(challenge.context).font(.footnote).foregroundStyle(.secondary)
    }
    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
    .background(SoloTheme.coral.opacity(0.09), in: RoundedRectangle(cornerRadius: 17))
  }

  private func filledSlots(_ session: WorkSessionRecord, challenge: CampaignCalibrationChallenge) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(CampaignSlot.allCases) { slot in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: symbol(for: slot)).frame(width: 22).foregroundStyle(SoloTheme.coral)
          VStack(alignment: .leading, spacing: 2) {
            Text(slot.title.uppercased()).font(.caption2.weight(.black)).foregroundStyle(.secondary)
            if let id = session.campaignSelection[slot],
               let option = challenge.presentations(for: slot).first(where: { $0.id == id }) {
              Text(option.title).font(.subheadline.weight(.semibold))
            } else { Text("Not selected").font(.subheadline).foregroundStyle(.secondary) }
          }
          Spacer()
        }
      }
    }
    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
    .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
  }

  private func optionCard(_ option: CampaignOptionPresentation) -> some View {
    Button {
      guard !actionInFlight, store.selectCampaignOption(taskID: taskID, slot: option.slot, optionID: option.id) else { return }
      selectionTrigger += 1
      settings.playFeedback(.review)
    } label: {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: symbol(for: option.slot))
          .font(.headline).frame(width: 34, height: 34)
          .background(SoloTheme.coral.opacity(0.14), in: Circle())
        VStack(alignment: .leading, spacing: 5) {
          Text(option.title).font(.headline).foregroundStyle(.primary)
          Text(option.detail).font(.footnote).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .padding(16).frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
      .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 17))
      .overlay { RoundedRectangle(cornerRadius: 17).stroke(Color.secondary.opacity(0.18)) }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(option.accessibilityLabel)
    .accessibilityHint("Selects this \(option.slot.rawValue) for the campaign")
  }

  private func campaignPreview(_ preview: CampaignPreviewPresentation) -> some View {
    panel(title: "CAMPAIGN PREVIEW") {
      resultRow("Audience", preview.audience.title)
      resultRow("Message", preview.message.title)
      resultRow("Channel", preview.channel.title)
    }
    .accessibilityElement(children: .contain)
  }

  private func completion(_ session: WorkSessionRecord) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      panel(title: "CAMPAIGN CALIBRATION COMPLETE") {
        resultRow("Founder Review", session.founderReviewLabel)
        resultRow("Campaign Elements", session.path == .manualReview ? "3" : "Delegated")
        resultRow("Founder Attention", "-\(session.founderAttentionCost)")
      }
      Text("Brio’s campaign report is ready. Underlying campaign quality and market response remain governed by the normal report and Hindsight flow.")
        .font(.footnote).foregroundStyle(.secondary)
      actionButton("CONTINUE", symbol: "arrow.right", primary: true) {
        guard !isContinuing else { return }
        isContinuing = true
        onContinue()
        dismiss()
      }
      .disabled(isContinuing)
    }
  }

  private func nextSlot(_ selection: CampaignSelection) -> CampaignSlot {
    if selection.audienceID == nil { return .audience }
    if selection.messageID == nil { return .message }
    return .channel
  }

  private func slotIndex(_ slot: CampaignSlot) -> Int { CampaignSlot.allCases.firstIndex(of: slot)! + 1 }
  private func symbol(for slot: CampaignSlot) -> String {
    switch slot { case .audience: "person.2.fill"; case .message: "text.bubble.fill"; case .channel: "dot.radiowaves.left.and.right" }
  }

  private func submit() {
    guard !actionInFlight else { return }
    actionInFlight = true
    guard store.submitCampaignCalibration(taskID: taskID) else { actionInFlight = false; return }
    settings.playFeedback(.review)
    actionInFlight = false
  }

  private func actionButton(_ title: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(title, systemImage: symbol).font(.headline.weight(.black))
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(primary ? SoloTheme.coral : Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(primary ? Color.black : Color.primary)
    }.buttonStyle(.plain)
  }

  private func decisionRow(_ title: String, detail: String, symbol: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol).foregroundStyle(SoloTheme.coral).frame(width: 24)
      VStack(alignment: .leading, spacing: 3) { Text(title.uppercased()).font(.subheadline.weight(.black)); Text(detail).font(.footnote).foregroundStyle(.secondary) }
    }
  }

  private func resultRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing).fontWeight(.bold) }
  }

  private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) { Text(title).font(.caption.weight(.black)).foregroundStyle(.secondary); content() }
      .padding(16).frame(maxWidth: .infinity, alignment: .leading)
      .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
  }
}

#if DEBUG
enum CampaignCalibrationQAPhase: String, CaseIterable { case choice, audience, message, preview, complete, report, handoff }

struct CampaignCalibrationQAHost: View {
  @State private var store: GameStore
  @State private var presentation = PresentationCoordinator()
  private var phase: CampaignCalibrationQAPhase
  private var taskID: UUID

  init(phase: CampaignCalibrationQAPhase) {
    self.phase = phase
    let fixture = GameStore()
    fixture.resetCareer()
    fixture.founderName = "Campaign QA"
    fixture.selectedDoctrine = .guided
    fixture.selectedProductType = .saas
    fixture.startCareer(seed: 8_204)
    fixture.selectThesisAndBegin()
    let id = fixture.tasks[0].id
    fixture.tasks[0].title = "Launch Founder Analytics"
    fixture.tasks[0].detail = "Increase qualified trial starts for the new analytics workflow."
    fixture.tasks[0].role = .marketing
    fixture.tasks[0].category = .sales
    fixture.tasks[0].urgency = .important
    fixture.assign(agentID: "brio", to: id)
    _ = fixture.prepareCampaignCalibration(taskID: id)
    if phase == .handoff {
      _ = fixture.pursueFundingOpportunity(id: "pioneer-ai-grant")
      if let choice = fixture.activeDilemma?.choices.first { fixture.selectDilemmaChoice(choice.id) }
      for agent in fixture.agents where agent.id != "brio" { fixture.restAgent(agentID: agent.id) }
    }
    if phase != .choice && phase != .handoff {
      _ = fixture.beginManualCampaignCalibration(taskID: id)
      if phase != .audience {
        _ = fixture.selectCampaignOption(taskID: id, slot: .audience, optionID: "alternate-audience")
      }
      if phase == .preview || phase == .complete || phase == .report {
        _ = fixture.selectCampaignOption(taskID: id, slot: .message, optionID: "alternate-message")
        _ = fixture.selectCampaignOption(taskID: id, slot: .channel, optionID: "alternate-channel")
      }
      if phase == .complete || phase == .report {
        _ = fixture.submitCampaignCalibration(taskID: id)
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
        CampaignCalibrationView(store: store, taskID: taskID) { }
      }
    }
    .background(SoloTheme.background)
  }
}
#endif
