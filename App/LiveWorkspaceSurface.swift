import SwiftUI

struct LiveWorkspaceSurface: View {
  var agentID: String
  var taskTitle: String?
  var phase: PresentationCoordinator.AgentPhase
  var progress: Double
  var reduceMotion: Bool
  var isVerified = false

  private var accent: Color {
    switch agentID {
    case "aurora": SoloTheme.purple
    case "stacks": SoloTheme.cyan
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }

  private var isWorking: Bool { phase == .working }
  private var isComplete: Bool { phase == .workComplete }
  private var isAwaitingReview: Bool { phase == .awaitingReview }

  var body: some View {
    TimelineView(.animation(minimumInterval: isWorking ? 1 / 20 : 1 / 12, paused: reduceMotion)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      let reviewPulse = isAwaitingReview ? 0.5 + 0.5 * sin(time * .pi * 2 / 2.5) : 0
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("LIVE WORKSPACE")
            .font(.caption2.weight(.black))
            .foregroundStyle(accent)
          Spacer()
          Label(isVerified ? "VERIFIED" : phase.statusLabel.uppercased(), systemImage: isVerified ? "checkmark.seal.fill" : statusSymbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(isVerified ? SoloTheme.mint : (isAwaitingReview ? accent : .primary))
            .padding(.horizontal, isAwaitingReview || isVerified ? 7 : 0)
            .padding(.vertical, isAwaitingReview || isVerified ? 4 : 0)
            .background((isVerified ? SoloTheme.mint : accent).opacity(isAwaitingReview ? 0.16 + reviewPulse * 0.17 : (isVerified ? 0.16 : 0)), in: Capsule())
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
            .id("\(agentID)-\(phase.rawValue)-\(isVerified)")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
          if phase == .assignmentReceived {
            assignmentChip
          }
          if isComplete {
            completionOverlay
          }
        }
        .frame(height: 108)
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              (isVerified ? SoloTheme.mint : accent).opacity(
                isComplete ? 0.92 : (isWorking ? 0.88 : (isAwaitingReview ? 0.28 + reviewPulse * 0.44 : (isVerified ? 0.58 : 0.2)))
              ),
              lineWidth: isComplete ? 2.5 : (isAwaitingReview || isVerified ? 1.7 : 1)
            )
        }
        .overlay {
          if isAwaitingReview {
            RoundedRectangle(cornerRadius: 12)
              .stroke(accent.opacity(reviewPulse * 0.42), lineWidth: 5)
              .blur(radius: 5)
          }
        }
        .shadow(color: (isVerified ? SoloTheme.mint : accent).opacity(isComplete ? 0.65 : (isWorking ? 0.4 : (isVerified ? 0.2 : 0))), radius: isComplete ? 16 : (isWorking ? 11 : 8))

        if isWorking || isComplete {
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
      .animation(MotionKind.state.resolved(reduceMotion: reduceMotion), value: phase)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text("Live workspace, \(phase.statusLabel)"))
    .accessibilityValue(taskTitle ?? "No task assigned")
  }

  @ViewBuilder
  private func workspace(time: TimeInterval) -> some View {
    let idlePhase = time.truncatingRemainder(dividingBy: 7.2)
    let idlePulse = reduceMotion || idlePhase > 1 ? 0 : sin(idlePhase * .pi)
    let intensity = isWorking ? 1.0 : idlePulse * 0.18
    switch agentID {
    case "aurora": AuroraWorkspace(time: time, progress: progress, intensity: intensity, accent: accent)
    case "stacks": StacksWorkspace(time: time, progress: progress, intensity: intensity, accent: accent)
    case "brio": BrioWorkspace(time: time, progress: progress, intensity: intensity, accent: accent)
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
    Label("WORK COMPLETE", systemImage: "checkmark.seal.fill")
      .font(.subheadline.weight(.black))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(SoloTheme.mint.gradient, in: Capsule())
      .symbolEffect(.bounce)
      .transition(.scale(scale: 0.72).combined(with: .opacity))
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
  var intensity: Double
  var accent: Color

  var body: some View {
    GeometryReader { geometry in
      let active = intensity > 0.2
      let travel = active ? time.truncatingRemainder(dividingBy: 1.18) / 1.18 : time.truncatingRemainder(dividingBy: 7.2) / 7.2
      let x = geometry.size.width * travel
      ZStack(alignment: .leading) {
        Path { path in
          path.move(to: CGPoint(x: 8, y: geometry.size.height * 0.68))
          path.addLine(to: CGPoint(x: geometry.size.width - 8, y: geometry.size.height * 0.68))
        }
        .stroke(accent.opacity(0.16 + intensity * 0.72), style: StrokeStyle(lineWidth: active ? 2.5 : 1, dash: [5, 5]))
        ForEach(0..<6, id: \.self) { index in
          let nodeX = 12 + (geometry.size.width - 24) * Double(index) / 5
          let nodeTravel = Double(index) / 5
          let scanGlow = max(0, 1 - abs(travel - nodeTravel) * 4)
          Circle()
            .fill(accent.opacity(Double(index) / 5 <= progress ? 0.38 + intensity * 0.62 : 0.05 + scanGlow * intensity * 0.26))
            .stroke(accent.opacity(0.36 + intensity * 0.64), lineWidth: active ? 2 : 1)
            .frame(width: active ? 14 : 8, height: active ? 14 : 8)
            .shadow(color: SoloTheme.cyan.opacity(scanGlow * intensity), radius: 7)
            .position(x: nodeX, y: geometry.size.height * (index.isMultiple(of: 2) ? 0.42 : 0.68))
        }
        Rectangle()
          .fill(LinearGradient(colors: [.clear, SoloTheme.cyan, .white, .clear], startPoint: .top, endPoint: .bottom))
          .frame(width: active ? 5 : 1, height: geometry.size.height - 8)
          .shadow(color: SoloTheme.cyan, radius: active ? 12 : 2)
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
  var intensity: Double
  var accent: Color

  var body: some View {
    GeometryReader { geometry in
      let active = intensity > 0.2
      let sweep = geometry.size.width * (time.truncatingRemainder(dividingBy: active ? 0.95 : 7.2) / (active ? 0.95 : 7.2))
      let activeBlock = Int((time * 5).truncatingRemainder(dividingBy: 7))
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Label(active ? "BUILD EXECUTION" : "PROCESSOR READY", systemImage: "cpu.fill")
            .font(.caption2.monospaced().weight(.bold))
          Spacer()
          Image(systemName: active ? "bolt.horizontal.fill" : "power")
            .symbolEffect(.pulse, isActive: active)
            .scaleEffect(active ? 1.08 + 0.12 * sin(time * 8) : 1)
        }
        HStack(spacing: 6) {
          ForEach(0..<7, id: \.self) { index in
            RoundedRectangle(cornerRadius: 3)
              .fill((Double(index + 1) / 7 <= progress || (active && index == activeBlock)) ? accent.gradient : Color.white.opacity(0.09).gradient)
              .frame(maxWidth: .infinity, minHeight: active ? 37 : 30)
              .shadow(color: active && index == activeBlock ? accent.opacity(0.72) : .clear, radius: 7)
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
          .frame(width: active ? 56 : 26)
          .offset(x: sweep - (active ? 28 : 13))
      }
    }
  }
}

private struct BrioWorkspace: View {
  var time: TimeInterval
  var progress: Double
  var intensity: Double
  var accent: Color

  var body: some View {
    GeometryReader { geometry in
      let active = intensity > 0.2
      HStack(spacing: 12) {
        ZStack {
          ForEach(0..<3, id: \.self) { index in
            Circle()
              .stroke(accent.opacity(0.12 + intensity * (0.92 - Double(index) * 0.2)), lineWidth: active ? 2.8 : 1)
              .frame(width: 24 + CGFloat(index) * 18, height: 24 + CGFloat(index) * 18)
              .scaleEffect(active ? 0.8 + 0.24 * sin(time * 5 + Double(index)) : 0.94)
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
              let amplitude = active ? abs(sin(time * 6 + Double(index) * 0.72)) : 0.1 + intensity * 0.35 * abs(sin(time * 2 + Double(index)))
              Capsule()
                .fill(Double(index) / 12 <= progress || (active && index == Int((time * 6).truncatingRemainder(dividingBy: 12))) ? accent : accent.opacity(0.22))
                .frame(maxWidth: .infinity)
                .frame(height: 9 + 52 * amplitude)
                .shadow(color: accent.opacity(active ? 0.45 : 0), radius: 4)
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
