import SwiftUI

struct FounderGarageEnvironment: View {
  var store: GameStore
  var presentation: PresentationCoordinator
  var policy: PresentationPolicy

  @State private var ambientPulse = false
  @State private var signalProgress = 1.0
  @State private var receiptProgress = 1.0
  @State private var eventDismissTask: Task<Void, Never>?

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Image("FounderGarage")
          .resizable()
          .scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
          .accessibilityHidden(true)

        LinearGradient(
          colors: [.clear, SoloTheme.background.opacity(0.62)],
          startPoint: .center,
          endPoint: .bottom
        )
        .accessibilityHidden(true)

        equipmentLayer(in: geometry.size)
          .accessibilityHidden(true)

        ForEach(store.agents) { agent in
          let point = stationPoint(for: agent.id)
          let state = AgentVisualState.derive(
            agent: agent,
            task: store.tasks.first(where: { $0.assignedAgentID == agent.id }),
            founderStats: store.stats
          )
          GarageAgentMarker(agent: agent, state: state, pulse: ambientPulse)
            .position(x: geometry.size.width * point.x, y: geometry.size.height * point.y)
            .accessibilityHidden(true)
        }

        signalLayer(in: geometry.size)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 3) {
          Text("FOUNDER GARAGE")
            .font(.headline.weight(.black))
          Text("Living headquarters • \(equipmentStageLabel)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(SoloTheme.cyan)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityHidden(true)
      }
    }
    .aspectRatio(16 / 9, contentMode: .fit)
    .clipShape(.rect(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(SoloTheme.cyan.opacity(0.3))
    }
    .compositingGroup()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Founder Garage environment")
    .accessibilityValue(environmentAccessibilityValue)
    .onChange(of: policy.allowsAmbientMotion, initial: true) { _, allowsMotion in
      ambientPulse = false
      guard allowsMotion else { return }
      withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
        ambientPulse = true
      }
    }
    .onChange(of: presentation.latestEvent?.id) { _, _ in
      stageLatestEvent()
    }
    .onAppear {
      stageLatestEvent()
    }
    .onDisappear {
      eventDismissTask?.cancel()
      if let eventID = presentation.latestEvent?.id {
        presentation.clearLatestEvent(id: eventID)
      }
    }
  }

  private var equipmentStage: GarageEquipmentStage {
    .derive(
      venture: store.venture,
      trackRecord: store.stats.trackRecord,
      capital: store.stats.capital
    )
  }

  private var equipmentStageLabel: String {
    switch equipmentStage {
    case .startup: "Core equipment"
    case .operating: "Operations rack online"
    case .established: "Expanded garage systems"
    }
  }

  private var environmentAccessibilityValue: String {
    let working = store.agents.filter { $0.assignment != nil }.map(\.name)
    let status = working.isEmpty ? "All agents ready" : "Working agents: \(working.joined(separator: ", "))"
    return "\(equipmentStageLabel). \(status). Evidence ledger contains \(store.evidence.count) records."
  }

  @ViewBuilder
  private func equipmentLayer(in size: CGSize) -> some View {
    let operating = equipmentStage.rawValue >= GarageEquipmentStage.operating.rawValue
    let established = equipmentStage == .established
    Circle()
      .fill(SoloTheme.amber.opacity(operating ? (ambientPulse ? 0.34 : 0.2) : 0.06))
      .frame(width: size.width * 0.035)
      .blur(radius: 3)
      .position(x: size.width * 0.765, y: size.height * 0.335)
    Circle()
      .fill(SoloTheme.cyan.opacity(established ? (ambientPulse ? 0.38 : 0.22) : 0.05))
      .frame(width: size.width * 0.045)
      .blur(radius: 4)
      .position(x: size.width * 0.17, y: size.height * 0.43)
    if established {
      RoundedRectangle(cornerRadius: 4)
        .stroke(SoloTheme.mint.opacity(ambientPulse ? 0.8 : 0.45), lineWidth: 2)
        .frame(width: size.width * 0.065, height: size.height * 0.17)
        .position(x: size.width * 0.79, y: size.height * 0.31)
    }
  }

  @ViewBuilder
  private func signalLayer(in size: CGSize) -> some View {
    if let target = eventTargetAgentID {
      let targetPoint = stationPoint(for: target)
      Path { path in
        path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.78))
        path.addQuadCurve(
          to: CGPoint(x: size.width * targetPoint.x, y: size.height * targetPoint.y),
          control: CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        )
      }
      .trim(from: 0, to: signalProgress)
      .stroke(signalColor.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 6]))
      .shadow(color: signalColor, radius: 5)

      if isEvidenceEvent {
        Image(systemName: "doc.text.fill")
          .font(.caption)
          .foregroundStyle(SoloTheme.mint)
          .padding(5)
          .background(.black.opacity(0.7), in: .circle)
          .position(
            x: size.width * (targetPoint.x + (0.72 - targetPoint.x) * receiptProgress),
            y: size.height * (targetPoint.y + (0.25 - targetPoint.y) * receiptProgress)
          )
          .opacity(receiptProgress < 1 ? 1 : 0)
      }
    }
  }

  private var eventTargetAgentID: String? {
    switch presentation.latestEvent {
    case .assignment(_, _, let agentID, _), .review(_, _, let agentID, _, _): agentID
    case .sprint, .none: nil
    }
  }

  private var isEvidenceEvent: Bool {
    guard case .review(_, _, _, _, let evidenceChanged) = presentation.latestEvent else { return false }
    return evidenceChanged
  }

  private var signalColor: Color {
    guard case .review(_, _, _, let result, _) = presentation.latestEvent else { return SoloTheme.cyan }
    switch result.verificationState {
    case .verified, .confirmed: return SoloTheme.mint
    case .overclaimed, .driftDetected, .evidenceIncomplete: return SoloTheme.amber
    case .reported, .unverified: return SoloTheme.cyan
    }
  }

  private func stageLatestEvent() {
    eventDismissTask?.cancel()
    guard eventTargetAgentID != nil,
          let eventID = presentation.latestEvent?.id else { return }
    if !policy.allowsAmbientMotion {
      signalProgress = 1
      receiptProgress = 1
      presentation.clearLatestEvent(id: eventID)
      return
    }
    signalProgress = 0
    receiptProgress = 0
    withAnimation(.snappy(duration: 0.65)) {
      signalProgress = 1
    }
    if isEvidenceEvent {
      withAnimation(.smooth(duration: 0.8).delay(0.35)) {
        receiptProgress = 1
      }
    }
    eventDismissTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.35))
      guard !Task.isCancelled else { return }
      withAnimation(.smooth(duration: 0.25)) {
        presentation.clearLatestEvent(id: eventID)
      }
    }
  }

  private func stationPoint(for agentID: String) -> CGPoint {
    switch agentID {
    case "aurora": CGPoint(x: 0.16, y: 0.48)
    case "stacks": CGPoint(x: 0.88, y: 0.52)
    case "brio": CGPoint(x: 0.70, y: 0.35)
    default: CGPoint(x: 0.5, y: 0.5)
    }
  }
}

private struct GarageAgentMarker: View {
  var agent: SoloAgent
  var state: AgentVisualState
  var pulse: Bool

  var body: some View {
    ZStack {
      Circle()
        .fill(.black.opacity(0.7))
      Circle()
        .stroke(markerColor, lineWidth: state.activity == .idle ? 1.5 : 3)
        .scaleEffect(state.activity == .working && pulse ? 1.16 : 1)
        .opacity(state.activity == .working && pulse ? 0.55 : 1)
      Text(agent.initials)
        .font(.system(size: 9, weight: .black))
        .foregroundStyle(.white)
    }
    .frame(width: 30, height: 30)
    .overlay(alignment: .topTrailing) {
      if state.verification != .none {
        Image(systemName: verificationSymbol)
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(markerColor)
          .padding(3)
          .background(.black, in: .circle)
          .offset(x: 5, y: -5)
      }
    }
  }

  private var markerColor: Color {
    if state.warnings.contains(.overloaded) { return SoloTheme.amber }
    switch state.verification {
    case .verified, .confirmed: return SoloTheme.mint
    case .overclaiming, .driftDetected, .evidenceIncomplete: return SoloTheme.amber
    case .none:
      switch agent.role {
      case .research: return SoloTheme.cyan
      case .engineering: return Color(red: 1, green: 0.35, blue: 0.3)
      case .marketing, .general: return SoloTheme.amber
      }
    }
  }

  private var verificationSymbol: String {
    switch state.verification {
    case .verified, .confirmed: "checkmark"
    case .overclaiming: "exclamationmark"
    case .driftDetected: "waveform"
    case .evidenceIncomplete: "ellipsis"
    case .none: "circle"
    }
  }
}
