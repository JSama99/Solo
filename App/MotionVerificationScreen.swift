#if DEBUG
import SwiftUI

struct MotionVerificationScreen: View {
  enum Stage: String, CaseIterable, Identifiable {
    case selection = "Agent Selection"
    case auroraCollapsed = "Aurora Collapsed"
    case auroraExpanded = "Aurora Expanded"
    case stacksCollapsed = "Stacks Collapsed"
    case stacksExpanded = "Stacks Expanded"
    case brioCollapsed = "Brio Collapsed"
    case brioExpanded = "Brio Expanded"
    case auroraIdle = "Aurora Idle"
    case auroraWorking = "Aurora Working"
    case awaitingReview = "Awaiting Review"
    case auroraCompletion = "Aurora Completion"
    case stacksWorking = "Stacks Working"
    case brioWorking = "Brio Working"
    case review = "Founder Review"
    case verified = "Verified"
    case resolution = "Resolution"
    case hud = "HUD Change"
    case evidence = "Evidence Arrival"

    var id: String { rawValue }
  }

  var presentation: PresentationCoordinator
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var stage = Stage.selection
  @State private var selected = false
  @State private var hudValue = 64
  @State private var evidenceCount = 3

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Presentation-only visual QA. No career data, simulation state, saves, or RNG are touched.")
            .font(.caption)
            .foregroundStyle(.secondary)

          Picker("Verification state", selection: $stage) {
            ForEach(Stage.allCases) { stage in Text(stage.rawValue).tag(stage) }
          }
          .pickerStyle(.menu)
          .buttonStyle(.borderedProminent)

          stagePreview
            .frame(maxWidth: .infinity)

          Text("Current state: \(stage.rawValue)")
            .font(.caption.weight(.black))
            .foregroundStyle(SoloTheme.cyan)
            .accessibilityIdentifier("motion-qa-current-state")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("Motion QA")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .onAppear { stagePresentation() }
      .onChange(of: stage) { _, _ in stagePresentation() }
      .onDisappear { presentation.clearDebugPresentation() }
    }
  }

  @ViewBuilder
  private var stagePreview: some View {
    switch stage {
    case .selection:
      Button {
        selected.toggle()
      } label: {
        VStack(alignment: .leading, spacing: 14) {
          HStack {
            Text("AURORA").font(.title3.weight(.black))
            Spacer()
            Image(systemName: selected ? "checkmark.seal.fill" : "circle")
          }
          LiveWorkspaceSurface(agentID: "aurora", taskTitle: nil, phase: .idle, progress: 0, reduceMotion: reduceMotion)
          if selected {
            Text("Selected workspace").font(.caption.weight(.black)).foregroundStyle(SoloTheme.purple)
          }
        }
        .padding(16)
        .background(SoloTheme.purple.opacity(selected ? 0.24 : 0.07), in: .rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(selected ? SoloTheme.purple : .white.opacity(0.1), lineWidth: selected ? 3 : 1) }
        .shadow(color: selected ? SoloTheme.purple.opacity(0.5) : .clear, radius: 16, y: 8)
      }
      .buttonStyle(QAPressStyle(reduceMotion: reduceMotion))
      .scaleEffect(selected ? 1.035 : 1)
      .animation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion), value: selected)
      .accessibilityLabel("Aurora motion QA selection card")
      .accessibilityValue(selected ? "Selected" : "Not selected")

    case .auroraCollapsed, .stacksCollapsed, .brioCollapsed:
      workstationLayout(agentID: previewAgentID, expanded: false)

    case .auroraExpanded, .stacksExpanded, .brioExpanded:
      workstationLayout(agentID: previewAgentID, expanded: true)

    case .auroraIdle, .auroraWorking, .auroraCompletion, .awaitingReview, .stacksWorking, .brioWorking:
      LiveWorkspaceSurface(
        agentID: previewAgentID,
        taskTitle: "Validate launch evidence",
        phase: previewPhase,
        progress: previewPhase == .working ? 0.64 : (previewPhase == .idle ? 0 : 1),
        reduceMotion: reduceMotion
      )

    case .review:
      VStack(alignment: .leading, spacing: 12) {
        Label("FOUNDER REVIEW", systemImage: "eye.fill").font(.headline).foregroundStyle(SoloTheme.cyan)
        reviewFact("1", "Reported Quality", "78")
        reviewFact("2", "Evidence", "84%")
        reviewFact("3", "Verification State", "Confirmed")
        reviewFact("4", "Verified Actual", "76")
        reviewFact("5", "Operational Risk", "Low — evidence supports the claim")
      }
      .padding(18)
      .background(SoloTheme.purple.opacity(0.2), in: .rect(cornerRadius: 20))
      .overlay { RoundedRectangle(cornerRadius: 20).stroke(SoloTheme.cyan, lineWidth: 2) }
      .shadow(color: SoloTheme.cyan.opacity(0.3), radius: 14, y: 7)

    case .verified:
      VStack(alignment: .leading, spacing: 16) {
        VerificationImpact(state: .confirmed, active: true, reduceMotion: reduceMotion)
        Text("Evidence 84%")
          .font(.title2.monospacedDigit().weight(.black))
          .contentTransition(.numericText(value: 84))
      }
      .padding(22)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(SoloTheme.mint.opacity(0.14), in: .rect(cornerRadius: 20))

    case .resolution:
      VStack(alignment: .leading, spacing: 12) {
        Text("FOUNDER RESOLUTION").font(.caption.weight(.black))
        Label("Accept", systemImage: "lock.fill")
          .font(.headline)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(SoloTheme.mint.gradient, in: .rect(cornerRadius: 12))
          .scaleEffect(1.055)
        Label("Rework", systemImage: "arrow.clockwise").opacity(0.4)
        Label("Cross-Check", systemImage: "arrow.triangle.branch").opacity(0.4)
        Text("Accept locked").font(.caption.weight(.black)).foregroundStyle(SoloTheme.mint)
      }
      .padding(18)
      .background(SoloTheme.card, in: .rect(cornerRadius: 20))

    case .hud:
      VStack(spacing: 16) {
        HUDMetricView(label: "Runway", value: hudValue, unit: "d", symbol: "calendar")
        Button("Trigger Runway Change", systemImage: "arrow.down") { hudValue -= 3 }
          .buttonStyle(.borderedProminent)
      }
      .padding(18)
      .background(SoloTheme.card, in: .rect(cornerRadius: 20))

    case .evidence:
      VStack(spacing: 16) {
        HStack {
          Image(systemName: "checkmark.seal.fill").foregroundStyle(SoloTheme.mint)
          Text("Evidence · \(evidenceCount)").font(.headline.monospacedDigit())
          Spacer()
          Text("+1 Evidence").font(.caption.weight(.black)).foregroundStyle(SoloTheme.mint)
        }
        .padding(16)
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(SoloTheme.cyan, lineWidth: 2) }
        .shadow(color: SoloTheme.mint.opacity(0.55), radius: 13)
        Button("Trigger Evidence Arrival", systemImage: "plus") { evidenceCount += 1 }
          .buttonStyle(.borderedProminent)
      }
    }
  }

  private var previewAgentID: String {
    switch stage {
    case .stacksWorking, .stacksCollapsed, .stacksExpanded: "stacks"
    case .brioWorking, .brioCollapsed, .brioExpanded: "brio"
    default: "aurora"
    }
  }

  private func workstationLayout(agentID: String, expanded: Bool) -> some View {
    let accent: Color = agentID == "aurora" ? SoloTheme.purple : (agentID == "stacks" ? SoloTheme.cyan : SoloTheme.coral)
    let name = agentID == "aurora" ? "Aurora" : (agentID == "stacks" ? "Stacks" : "Brio")
    let role = agentID == "aurora" ? "Research & Evidence" : (agentID == "stacks" ? "Engineering & Execution" : "Growth & Campaigns")
    return VStack(alignment: .leading, spacing: 14) {
      HStack {
        RoundedRectangle(cornerRadius: 16).fill(accent.opacity(0.2)).frame(width: expanded ? 88 : 62, height: expanded ? 88 : 62).overlay { Text(String(name.prefix(2)).uppercased()).font(.headline.weight(.black)).foregroundStyle(accent) }
        VStack(alignment: .leading) { Text(name).font(.title3.weight(.bold)); Text("\(role) · Level 1").font(.caption).foregroundStyle(.secondary) }
        Spacer()
        Text(expanded ? "WORKING" : "READY").font(.caption2.weight(.black)).foregroundStyle(accent)
      }
      HStack(spacing: 8) { qaChip("Stress", "Focused", accent); qaChip("Trust", "84", accent); qaChip("XP", "32", accent) }
      Text("CURRENT ASSIGNMENT").font(.caption2.weight(.black)).foregroundStyle(.secondary)
      Text(expanded ? "Validate launch evidence" : "No active assignment").font(.subheadline.weight(.semibold))
      if expanded {
        LiveWorkspaceSurface(agentID: agentID, taskTitle: "Validate launch evidence", phase: .working, progress: 0.64, reduceMotion: reduceMotion, expanded: true)
        Text("RESULT / EVIDENCE").font(.caption2.weight(.black)).foregroundStyle(.secondary)
        Label("Reported Quality · 78", systemImage: "chart.bar.fill").font(.caption)
        Button("Review", systemImage: "eye") { }.buttonStyle(.borderedProminent).tint(accent)
      } else {
        Label("LIVE WORKSPACE · READY", systemImage: "desktopcomputer").font(.caption2.monospaced().weight(.bold)).foregroundStyle(accent)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(accent.opacity(expanded ? 0.2 : 0.07), in: RoundedRectangle(cornerRadius: 22))
    .overlay { RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(expanded ? 1 : 0.35), lineWidth: expanded ? 2 : 1) }
  }

  private func qaChip(_ title: String, _ value: String, _ accent: Color) -> some View {
    Text("\(title) \(value)").font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 6).background(.black.opacity(0.16), in: Capsule()).foregroundStyle(accent)
  }

  private var previewPhase: PresentationCoordinator.AgentPhase {
    switch stage {
    case .auroraIdle: .idle
    case .auroraCompletion: .workComplete
    case .awaitingReview: .awaitingReview
    default: .working
    }
  }

  private func reviewFact(_ order: String, _ title: String, _ value: String) -> some View {
    HStack(alignment: .top) {
      Text(order).font(.caption2.monospacedDigit().weight(.black)).foregroundStyle(SoloTheme.cyan)
      VStack(alignment: .leading) {
        Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        Text(value).font(.subheadline.weight(.semibold))
      }
    }
  }

  private func stagePresentation() {
    switch stage {
    case .auroraIdle, .auroraCollapsed, .auroraExpanded: presentation.stageDebug(.idle, agentID: "aurora")
    case .auroraWorking: presentation.stageDebug(.working, agentID: "aurora")
    case .awaitingReview: presentation.stageDebug(.awaitingReview, agentID: "aurora")
    case .auroraCompletion: presentation.stageDebug(.workComplete, agentID: "aurora")
    case .stacksWorking, .stacksCollapsed, .stacksExpanded: presentation.stageDebug(.working, agentID: "stacks")
    case .brioWorking, .brioCollapsed, .brioExpanded: presentation.stageDebug(.working, agentID: "brio")
    case .review: presentation.stageDebug(.reviewing, agentID: "aurora")
    case .verified: presentation.stageDebug(.reviewed, agentID: "aurora")
    case .resolution: presentation.stageDebug(.resolved, agentID: "aurora")
    case .selection, .hud, .evidence: presentation.stageDebug(.idle, agentID: "aurora")
    }
  }
}

private struct QAPressStyle: ButtonStyle {
  var reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
      .animation(reduceMotion ? nil : .smooth(duration: 0.08), value: configuration.isPressed)
  }
}
#endif
