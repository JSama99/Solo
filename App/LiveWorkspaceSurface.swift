import SwiftUI

struct LiveWorkspaceSurface: View {
  var agentID: String
  var taskTitle: String?
  var phase: PresentationCoordinator.AgentPhase
  var progress: Double
  var reduceMotion: Bool
  var isActive = true
  var expanded = false

  private var accent: Color {
    switch agentID {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }

  private var isWorking: Bool { phase == .working }
  private var isComplete: Bool { phase == .workComplete }
  private var needsAttention: Bool { phase == .awaitingReview }
  private var isReviewing: Bool { phase == .reviewing }
  private var isSettled: Bool { phase == .reviewed || phase == .resolved }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || !isActive)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("LIVE WORKSPACE")
            .font(.caption2.weight(.black))
            .foregroundStyle(accent)
          Spacer()
          Label(phase.statusLabel.uppercased(), systemImage: statusSymbol)
            .font(.caption2.weight(.bold))
            .contentTransition(.interpolate)
        }

        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(
              LinearGradient(
                colors: [accent.opacity(isWorking ? 0.27 : 0.1), .black.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
          workspace(time: time)
            .padding(10)
          if phase == .assignmentReceived {
            assignmentChip
          }
          if isComplete {
            completionOverlay
          }
          if needsAttention {
            attentionOverlay
          }
          if isReviewing {
            inspectionOverlay
          }
          if isSettled {
            settledOverlay
          }
        }
        .frame(height: expanded ? 136 : 108)
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(needsAttention ? SoloTheme.amber.opacity(0.72) : accent.opacity(isWorking || isComplete || isSettled ? 0.72 : 0.2), lineWidth: isComplete || isSettled ? 2.5 : 1)
        }
        .shadow(color: accent.opacity(isComplete ? 0.65 : (isWorking ? 0.25 : 0)), radius: isComplete ? 16 : 8)

        if isWorking || isComplete || needsAttention {
          HStack(spacing: 8) {
            ProgressView(value: progress)
              .tint(accent)
            Text(progress.formatted(.percent.precision(.fractionLength(0))))
              .font(.caption.monospacedDigit().weight(.bold))
              .contentTransition(.numericText(value: progress))
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .padding(12)
      .background(.black.opacity(0.2), in: .rect(cornerRadius: 14))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text("Live workspace, \(phase.statusLabel)"))
    .accessibilityValue(taskTitle ?? "No task assigned")
  }

  @ViewBuilder
  private func workspace(time: TimeInterval) -> some View {
    switch agentID {
    case "aurora": AuroraWorkspace(time: time, progress: progress, active: isWorking, accent: accent)
    case "stacks": StacksWorkspace(time: time, progress: progress, active: isWorking, accent: accent)
    case "brio": BrioWorkspace(time: time, progress: progress, active: isWorking, accent: accent)
    default: DefaultWorkspace(active: isWorking, accent: accent)
    }
  }

  private var assignmentChip: some View {
    VStack(spacing: 5) {
      Label("TASK ASSIGNED", systemImage: "arrow.down.doc.fill")
        .font(.caption.weight(.black))
      if let taskTitle {
        Text(taskTitle)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(accent.gradient, in: Capsule())
    .transition(.move(edge: .top).combined(with: .scale(scale: 0.86)).combined(with: .opacity))
  }

  private var completionOverlay: some View {
    Label("READY FOR REVIEW", systemImage: "doc.text.fill")
      .font(.subheadline.weight(.black))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.gray.gradient, in: Capsule())
      .transition(reduceMotion ? .opacity : .scale(scale: 0.84).combined(with: .opacity))
  }

  private var attentionOverlay: some View {
    Label("FOUNDER ATTENTION REQUIRED", systemImage: "eye.fill")
      .font(.caption.weight(.black))
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .background(SoloTheme.amber.gradient, in: Capsule())
      .transition(.opacity.combined(with: .scale(scale: 0.92)))
  }

  private var inspectionOverlay: some View {
    RoundedRectangle(cornerRadius: 12)
      .stroke(accent.opacity(0.9), lineWidth: 2)
      .overlay {
        LinearGradient(colors: [.clear, accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .accessibilityHidden(true)
  }

  private var settledOverlay: some View {
    Label(phase == .resolved ? "DECISION LOCKED" : "REVIEW COMPLETE", systemImage: phase == .resolved ? "lock.fill" : "checkmark.seal.fill")
      .font(.caption.weight(.black))
      .foregroundStyle(phase == .resolved ? SoloTheme.mint : accent)
      .padding(9)
      .background(.black.opacity(0.72), in: Capsule())
      .transition(.opacity)
  }

  private var statusSymbol: String {
    switch phase {
    case .idle: "pause.fill"
    case .assignmentReceived: "arrow.down.doc.fill"
    case .working: "waveform.path.ecg"
    case .workComplete: "checkmark.seal.fill"
    case .awaitingReview: "eye.fill"
    case .reviewing: "magnifyingglass"
    case .reviewed: "doc.text.fill"
    case .resolving: "lock.open.fill"
    case .resolved: "lock.fill"
    }
  }
}

private struct AuroraWorkspace: View {
  var time: TimeInterval
  var progress: Double
  var active: Bool
  var accent: Color

  var body: some View {
    GeometryReader { geometry in
      let travel = active ? time.truncatingRemainder(dividingBy: 1.35) / 1.35 : time.truncatingRemainder(dividingBy: 7) / 7
      let x = geometry.size.width * travel
      ZStack(alignment: .leading) {
        Path { path in
          path.move(to: CGPoint(x: 8, y: geometry.size.height * 0.68))
          path.addLine(to: CGPoint(x: geometry.size.width - 8, y: geometry.size.height * 0.68))
        }
        .stroke(accent.opacity(active ? 0.72 : 0.2), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
        ForEach(0..<6, id: \.self) { index in
          let nodeX = 12 + (geometry.size.width - 24) * Double(index) / 5
          Circle()
            .fill(Double(index) / 5 <= progress ? accent : .clear)
            .stroke(accent.opacity(0.85), lineWidth: 1.5)
            .frame(width: active ? 11 : 8, height: active ? 11 : 8)
            .position(x: nodeX, y: geometry.size.height * (index.isMultiple(of: 2) ? 0.42 : 0.68))
        }
        Rectangle()
          .fill(LinearGradient(colors: [.clear, SoloTheme.cyan, .white, .clear], startPoint: .top, endPoint: .bottom))
          .frame(width: active ? 3 : 1, height: geometry.size.height - 8)
          .shadow(color: SoloTheme.cyan, radius: active ? 7 : 2)
          .offset(x: x)
        Text(active ? "SCANNING EVIDENCE" : "EVIDENCE MONITOR")
          .font(.caption2.monospaced().weight(.bold))
          .foregroundStyle(accent.opacity(active ? 1 : 0.5))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
  }
}

private struct StacksWorkspace: View {
  var time: TimeInterval
  var progress: Double
  var active: Bool
  var accent: Color

  var body: some View {
    GeometryReader { geometry in
      let sweep = geometry.size.width * (time.truncatingRemainder(dividingBy: active ? 1.1 : 6) / (active ? 1.1 : 6))
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Label(active ? "BUILD EXECUTION" : "PROCESSOR READY", systemImage: "cpu.fill")
            .font(.caption2.monospaced().weight(.bold))
          Spacer()
          Image(systemName: active ? "bolt.horizontal.fill" : "power")
            .symbolEffect(.pulse, isActive: active)
        }
        HStack(spacing: 6) {
          ForEach(0..<7, id: \.self) { index in
            RoundedRectangle(cornerRadius: 3)
              .fill(Double(index + 1) / 7 <= progress ? accent.gradient : Color.white.opacity(0.09).gradient)
              .frame(maxWidth: .infinity, minHeight: 32)
              .overlay(alignment: .bottom) {
                Text("\(index + 1)").font(.system(size: 8, weight: .bold, design: .monospaced)).padding(.bottom, 3)
              }
          }
        }
      }
      .foregroundStyle(accent)
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(LinearGradient(colors: [.clear, .white.opacity(active ? 0.8 : 0.18), .clear], startPoint: .leading, endPoint: .trailing))
          .frame(width: 38)
          .offset(x: sweep - 20)
      }
    }
  }
}

private struct BrioWorkspace: View {
  var time: TimeInterval
  var progress: Double
  var active: Bool
  var accent: Color

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 12) {
        ZStack {
          ForEach(0..<3, id: \.self) { index in
            Circle()
              .stroke(accent.opacity(active ? 0.8 - Double(index) * 0.2 : 0.16), lineWidth: 2)
              .frame(width: 24 + CGFloat(index) * 17, height: 24 + CGFloat(index) * 17)
              .scaleEffect(active ? 0.88 + 0.12 * sin(time * 4 + Double(index)) : 0.94)
          }
          Image(systemName: "antenna.radiowaves.left.and.right")
            .foregroundStyle(accent)
        }
        VStack(alignment: .leading, spacing: 7) {
          Text(active ? "CAMPAIGN SIGNAL" : "DISTRIBUTION LISTENING")
            .font(.caption2.monospaced().weight(.bold))
            .foregroundStyle(accent)
          HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
              let amplitude = active ? abs(sin(time * 5 + Double(index) * 0.72)) : 0.12 + 0.05 * sin(time + Double(index))
              Capsule()
                .fill(Double(index) / 12 <= progress ? accent : accent.opacity(0.22))
                .frame(maxWidth: .infinity)
                .frame(height: 8 + 42 * amplitude)
            }
          }
          .frame(maxHeight: .infinity, alignment: .bottom)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

private struct DefaultWorkspace: View {
  var active: Bool
  var accent: Color

  var body: some View {
    Label(active ? "EXECUTING TASK" : "SYSTEM READY", systemImage: "desktopcomputer")
      .font(.caption.monospaced().weight(.bold))
      .foregroundStyle(accent)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
