import SwiftUI

struct VentureScreen: View {
  var store: GameStore

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(AppSettingsStore.self) private var settings
  @State private var revealStage = 0
  @State private var didCaptureInitialState = false
  @State private var knownConsequenceIDs = Set<String>()
  @State private var newConsequenceIDs = Set<String>()
  @State private var chapterFeedback = 0
  @State private var objectiveFeedback = 0
  @State private var pressurePhase: PressurePhase = .idle
  @State private var pressureCycle = 0

  private var presentation: VentureScreenPresentation {
    VentureScreenPresentation(store: store)
  }

  var body: some View {
    let state = presentation
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          VentureStatusInstrument(presentation: state)
            .ventureReveal(stage: revealStage, threshold: 1, reduceMotion: reduceMotion)

          VentureChapterCard(presentation: state, reduceMotion: reduceMotion)
            .id(state.chapterNumber)
            .transition(chapterTransition)
            .ventureReveal(stage: revealStage, threshold: 2, reduceMotion: reduceMotion)

          VentureObjectiveCard(objective: state.objective, reduceMotion: reduceMotion)
            .ventureReveal(stage: revealStage, threshold: 3, reduceMotion: reduceMotion)

          StrategicThesisCard(name: state.thesisName, detail: state.thesisDetail)
            .ventureReveal(stage: revealStage, threshold: 4, reduceMotion: reduceMotion)

          OperatingPressureCard(pressure: state.pressure, phase: pressurePhase)
            .ventureReveal(stage: revealStage, threshold: 4, reduceMotion: reduceMotion)

          CompanyConsequencesSection(
            consequences: state.consequences,
            newlyUnlockedIDs: newConsequenceIDs,
            reduceMotion: reduceMotion
          )
          .ventureReveal(stage: revealStage, threshold: 5, reduceMotion: reduceMotion)

          GarageInfrastructureSection(upgrades: state.upgrades)
            .ventureReveal(stage: revealStage, threshold: 5, reduceMotion: reduceMotion)

          FounderDoctrineCard(doctrine: state.doctrine)
            .ventureReveal(stage: revealStage, threshold: 6, reduceMotion: reduceMotion)

          CareerObjectiveCard(text: state.careerObjective)
            .ventureReveal(stage: revealStage, threshold: 6, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .safeAreaPadding(.bottom, 76)
        .frame(maxWidth: .infinity)
      }
      .scrollIndicators(.hidden)
      .navigationTitle("Venture \(state.venture)")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { captureInitialState(state) }
      .task { await revealScreenIfNeeded() }
      .onChange(of: state.chapterNumber) { oldValue, newValue in
        guard didCaptureInitialState, oldValue != newValue else { return }
        chapterFeedback += 1
        settings.playFeedback(.chapterAdvance)
      }
      .onChange(of: state.objective.isComplete) { wasComplete, isComplete in
        guard didCaptureInitialState, !wasComplete, isComplete else { return }
        objectiveFeedback += 1
      }
      .onChange(of: state.sprint) { oldValue, newValue in
        guard didCaptureInitialState, oldValue != newValue else { return }
        runPressureSequence()
      }
      .onChange(of: Set(state.consequences.map(\.id))) { _, currentIDs in
        guard didCaptureInitialState else { return }
        let additions = currentIDs.subtracting(knownConsequenceIDs)
        knownConsequenceIDs = currentIDs
        guard !additions.isEmpty else { return }
        newConsequenceIDs = additions
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(900))
          newConsequenceIDs.subtract(additions)
        }
      }
      .appSensoryFeedback(.success, trigger: chapterFeedback)
      .appSensoryFeedback(.success, trigger: objectiveFeedback)
    }
  }

  private var chapterTransition: AnyTransition {
    reduceMotion
      ? .opacity
      : .asymmetric(
        insertion: .opacity.combined(with: .offset(y: 14)),
        removal: .opacity.combined(with: .offset(y: -8))
      )
  }

  private func captureInitialState(_ state: VentureScreenPresentation) {
    guard !didCaptureInitialState else { return }
    knownConsequenceIDs = Set(state.consequences.map(\.id))
    didCaptureInitialState = true
  }

  @MainActor
  private func revealScreenIfNeeded() async {
    guard revealStage == 0 else { return }
    if reduceMotion {
      revealStage = 6
      return
    }
    for stage in 1...6 {
      withAnimation(.smooth(duration: 0.42)) { revealStage = stage }
      try? await Task.sleep(for: .milliseconds(85))
    }
  }

  private func runPressureSequence() {
    pressureCycle += 1
    let cycle = pressureCycle
    if reduceMotion {
      pressurePhase = .both
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        if pressureCycle == cycle { pressurePhase = .idle }
      }
      return
    }
    withAnimation(.smooth(duration: 0.2)) { pressurePhase = .runway }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(260))
      guard pressureCycle == cycle else { return }
      withAnimation(.smooth(duration: 0.2)) { pressurePhase = .energy }
      try? await Task.sleep(for: .milliseconds(300))
      guard pressureCycle == cycle else { return }
      withAnimation(.smooth(duration: 0.25)) { pressurePhase = .idle }
    }
  }
}

private enum PressurePhase {
  case idle
  case runway
  case energy
  case both
}

private struct VentureStatusInstrument: View {
  var presentation: VentureScreenPresentation
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(spacing: 18) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 6) { instrumentHeader }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          HStack { instrumentHeader }
        }
      }

      VStack(spacing: 2) {
        Text("SPRINT")
          .font(.caption.weight(.black))
          .tracking(2.4)
          .foregroundStyle(SoloTheme.amber)
        Text(presentation.sprint, format: .number.precision(.integerLength(2)))
          .font(.system(size: 66, weight: .black, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .contentTransition(.numericText(value: Double(presentation.sprint)))
        Text("OF \(presentation.totalSprints)")
          .font(.subheadline.weight(.bold))
          .tracking(1.5)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Sprint \(presentation.sprint) of \(presentation.totalSprints)")
      .accessibilityValue("\(presentation.completedSprints) sprints completed")

      SprintProgressTrack(
        segments: presentation.sprintSegments,
        currentSprint: presentation.sprint,
        totalSprints: presentation.totalSprints
      )

      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(spacing: 12) { instrumentMetrics }
        } else {
          HStack(spacing: 12) { instrumentMetrics }
        }
      }

      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 4) { chapterStatus }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          HStack(spacing: 6) { chapterStatus }
        }
      }
      .font(.caption.weight(.black))
      .tracking(0.7)
      .accessibilityElement(children: .combine)
    }
    .padding(20)
    .background {
      ZStack {
        LinearGradient(
          colors: [SoloTheme.purple.opacity(0.15), SoloTheme.card, Color.black.opacity(0.25)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        RadialGradient(
          colors: [SoloTheme.amber.opacity(0.08), .clear],
          center: .top,
          startRadius: 0,
          endRadius: 180
        )
      }
    }
    .clipShape(.rect(cornerRadius: 24))
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .stroke(contrast == .increased ? SoloTheme.purple.opacity(0.75) : SoloTheme.purple.opacity(0.3), lineWidth: 1)
    }
    .shadow(color: SoloTheme.purple.opacity(0.1), radius: 20, y: 8)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var instrumentHeader: some View {
    Label("VENTURE \(presentation.venture)", systemImage: "scope")
      .font(.caption.weight(.black))
      .tracking(1.2)
      .foregroundStyle(SoloTheme.purple)
      .fixedSize(horizontal: false, vertical: true)
    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
    Text("LIVE OPERATING BOARD")
      .font(.caption2.weight(.semibold))
      .tracking(0.8)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var instrumentMetrics: some View {
    InstrumentMetric(
      title: "EVIDENCE",
      value: presentation.evidence,
      symbol: "checkmark.seal.fill",
      color: SoloTheme.mint
    )
    if !dynamicTypeSize.isAccessibilitySize {
      Divider().overlay(.white.opacity(0.12)).frame(height: 42)
    }
    InstrumentMetric(
      title: "TRACK RECORD",
      value: presentation.trackRecord,
      symbol: "chart.line.uptrend.xyaxis",
      color: SoloTheme.cyan
    )
  }

  @ViewBuilder
  private var chapterStatus: some View {
        Text("CHAPTER \(presentation.chapterNumber)")
          .foregroundStyle(SoloTheme.amber)
        if !dynamicTypeSize.isAccessibilitySize { Text("·") }
        Text(presentation.chapterTitle.uppercased())
          .fixedSize(horizontal: false, vertical: true)
  }
}

private struct InstrumentMetric: View {
  var title: String
  var value: Int
  var symbol: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Label(title, systemImage: symbol)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      Text(value, format: .number.precision(.integerLength(2)))
        .font(.title2.weight(.black).monospacedDigit())
        .foregroundStyle(color)
        .contentTransition(.numericText(value: Double(value)))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title.capitalized)
    .accessibilityValue("\(value)")
  }
}

private struct SprintProgressTrack: View {
  var segments: [VentureScreenPresentation.SprintSegment]
  var currentSprint: Int
  var totalSprints: Int

  var body: some View {
    HStack(spacing: 5) {
      ForEach(segments) { segment in
        Capsule()
          .fill(color(for: segment.state))
          .frame(maxWidth: .infinity)
          .frame(height: segment.state == .current ? 9 : 5)
          .overlay {
            if segment.state == .current {
              Capsule().stroke(.white.opacity(0.7), lineWidth: 1)
            }
          }
          .animation(.smooth(duration: 0.35), value: segment.state)
          .accessibilityHidden(true)
      }
    }
    .frame(height: 10)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Sprint timeline")
    .accessibilityValue("Sprint \(currentSprint) of \(totalSprints); \(max(0, currentSprint - 1)) completed")
  }

  private func color(for state: VentureScreenPresentation.SprintSegment.State) -> Color {
    switch state {
    case .completed: SoloTheme.cyan
    case .current: SoloTheme.amber
    case .upcoming: .white.opacity(0.16)
    }
  }
}

private struct VentureChapterCard: View {
  var presentation: VentureScreenPresentation
  var reduceMotion: Bool
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    ZStack(alignment: .trailing) {
      ChapterSignalMotif(chapter: presentation.chapterNumber)
        .accessibilityHidden(true)

      Text("\(presentation.chapterNumber)")
        .font(.system(size: 132, weight: .black, design: .rounded))
        .foregroundStyle(SoloTheme.amber.opacity(0.075))
        .offset(x: 8, y: 8)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 10) {
        Group {
          if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) { chapterHeader }
          } else {
            HStack { chapterHeader }
          }
        }
        Text(presentation.chapterTitle)
          .font(.title.bold())
          .contentTransition(.interpolate)
        Text(presentation.chapterDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("IN PROGRESS")
          .font(.caption2.weight(.black))
          .tracking(1)
          .foregroundStyle(SoloTheme.amber)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(SoloTheme.amber.opacity(0.12), in: .capsule)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .frame(minHeight: 190)
    .ventureHeroSurface(accent: SoloTheme.amber)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Chapter \(presentation.chapterNumber), \(presentation.chapterTitle). \(presentation.chapterDetail). \(presentation.chapterProgressLabel)")
  }

  private var chapterSymbol: String {
    switch presentation.chapterNumber {
    case 1: "hammer.fill"
    case 2: "person.2.wave.2.fill"
    case 3: "megaphone.fill"
    default: "arrow.up.right"
    }
  }

  @ViewBuilder
  private var chapterHeader: some View {
    Label("CHAPTER \(presentation.chapterNumber)", systemImage: chapterSymbol)
      .font(.caption.weight(.black))
      .tracking(1.2)
      .foregroundStyle(SoloTheme.amber)
      .fixedSize(horizontal: false, vertical: true)
    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
    Text(presentation.chapterProgressLabel)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

private struct ChapterSignalMotif: View {
  var chapter: Int

  var body: some View {
    HStack(spacing: 9) {
      ForEach(0..<4, id: \.self) { index in
        VStack(spacing: 9) {
          Circle()
            .fill(index < chapter ? SoloTheme.amber.opacity(0.22) : .white.opacity(0.04))
            .frame(width: 8, height: 8)
          Capsule()
            .fill(.white.opacity(0.035))
            .frame(width: 2, height: CGFloat(20 + index * 10))
        }
      }
    }
    .padding(.trailing, 28)
  }
}

private struct VentureObjectiveCard: View {
  var objective: VentureScreenPresentation.Objective
  var reduceMotion: Bool
  @State private var displayedProgress = 0.0
  @State private var completionSweep = false
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 6) { objectiveHeader }
        } else {
          HStack(alignment: .top) { objectiveHeader }
        }
      }

      VStack(alignment: .leading, spacing: 5) {
        Text(objective.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
        Text(objective.detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      ObjectiveProgressTrack(progress: displayedProgress, sweep: completionSweep && !reduceMotion)

      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 10) { objectiveFooter }
        } else {
          HStack(alignment: .center, spacing: 10) { objectiveFooter }
        }
      }
    }
    .padding(20)
    .ventureHeroSurface(accent: SoloTheme.mint)
    .onAppear { displayedProgress = objective.progress }
    .onChange(of: objective.progress) { oldValue, newValue in
      guard oldValue != newValue else { return }
      withAnimation(reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.55)) {
        displayedProgress = newValue
      }
      guard newValue >= 1, oldValue < 1, !reduceMotion else { return }
      completionSweep = true
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(650))
        completionSweep = false
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Venture objective, \(objective.title). \(objective.detail)")
    .accessibilityValue("\(objective.percentage) percent complete. Reward: \(objective.reward)")
  }

  @ViewBuilder
  private var objectiveHeader: some View {
        Label("VENTURE OBJECTIVE", systemImage: objective.isComplete ? "checkmark.seal.fill" : "target")
          .font(.caption.weight(.black))
          .tracking(1.1)
          .foregroundStyle(SoloTheme.mint)
          .symbolEffect(.bounce, value: objective.isComplete)
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Text("\(objective.percentage)%")
          .font(.title3.weight(.black).monospacedDigit())
          .foregroundStyle(objective.isComplete ? SoloTheme.mint : .primary)
          .contentTransition(.numericText(value: Double(objective.percentage)))
  }

  @ViewBuilder
  private var objectiveFooter: some View {
        if objective.isComplete {
          Text("OBJECTIVE COMPLETE")
            .font(.caption.weight(.black))
            .tracking(0.9)
            .foregroundStyle(SoloTheme.mint)
            .transition(.opacity)
        } else {
          Text("\(objective.percentage)% COMPLETE")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Label(objective.reward, systemImage: "gift.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(objective.isComplete ? .black : SoloTheme.mint)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(objective.isComplete ? SoloTheme.mint : SoloTheme.mint.opacity(0.1), in: .capsule)
  }
}

private struct ObjectiveProgressTrack: View {
  var progress: Double
  var sweep: Bool

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.1))
        Capsule()
          .fill(LinearGradient(colors: [SoloTheme.cyan, SoloTheme.mint], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(8, proxy.size.width * progress))
        if sweep {
          Capsule()
            .fill(.white.opacity(0.75))
            .frame(width: 32)
            .blur(radius: 5)
            .offset(x: proxy.size.width - 32)
            .transition(.offset(x: -proxy.size.width))
        }
      }
    }
    .frame(height: 9)
    .accessibilityHidden(true)
  }
}

private struct StrategicThesisCard: View {
  var name: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      ZStack {
        Circle().fill(SoloTheme.cyan.opacity(0.11))
        Image(systemName: "compass.drawing")
          .font(.title2)
          .foregroundStyle(SoloTheme.cyan)
      }
      .frame(width: 48, height: 48)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 6) {
        Text("ACTIVE THESIS")
          .font(.caption.weight(.black))
          .tracking(1)
          .foregroundStyle(SoloTheme.cyan)
        Text(name).font(.title3.bold())
        Text(detail).font(.callout).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(18)
    .ventureSystemSurface(accent: SoloTheme.cyan)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Active thesis: \(name). \(detail)")
  }
}

private struct OperatingPressureCard: View {
  var pressure: VentureScreenPresentation.Pressure
  var phase: PressurePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 5) { pressureHeader }
        } else {
          HStack { pressureHeader }
        }
      }

      Text(pressure.detail)
        .font(.callout)
        .foregroundStyle(.secondary)

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) { pressureCosts }
        VStack(spacing: 10) { pressureCosts }
      }

      Text(pressure.milestoneStatus)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .ventureSystemSurface(accent: SoloTheme.amber)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var pressureCosts: some View {
    PressureCost(
      title: "RUNWAY",
      value: pressure.runwayCost,
      symbol: "calendar.badge.minus",
      emphasized: phase == .runway || phase == .both
    )
    PressureCost(
      title: "ENERGY",
      value: pressure.energyCost,
      symbol: "bolt.fill",
      emphasized: phase == .energy || phase == .both
    )
  }

  @ViewBuilder
  private var pressureHeader: some View {
    Label("OPERATING PRESSURE", systemImage: "gauge.with.dots.needle.67percent")
      .font(.caption.weight(.black))
      .tracking(1)
      .foregroundStyle(SoloTheme.amber)
      .fixedSize(horizontal: false, vertical: true)
    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
    Text(pressure.eraName.uppercased())
      .font(.caption2.weight(.bold))
      .foregroundStyle(.secondary)
  }
}

private struct PressureCost: View {
  var title: String
  var value: Int
  var symbol: String
  var emphasized: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(SoloTheme.amber)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.caption2.weight(.black)).tracking(0.8).foregroundStyle(.secondary)
        Text("−\(value) / SPRINT")
          .font(.title3.weight(.black).monospacedDigit())
          .contentTransition(.numericText())
      }
      Spacer(minLength: 4)
    }
    .padding(12)
    .frame(maxWidth: .infinity)
    .background(emphasized ? SoloTheme.amber.opacity(0.18) : .white.opacity(0.04), in: .rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(emphasized ? SoloTheme.amber.opacity(0.65) : .white.opacity(0.06), lineWidth: 1)
    }
    .scaleEffect(emphasized ? 1.015 : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title.capitalized) operating cost")
    .accessibilityValue("Minus \(value) each sprint")
  }
}

private struct CompanyConsequencesSection: View {
  var consequences: [VentureScreenPresentation.Consequence]
  var newlyUnlockedIDs: Set<String>
  var reduceMotion: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeading(
        title: "Company consequences",
        detail: "The permanent shape left by founder decisions.",
        symbol: "point.topleft.down.curvedto.point.bottomright.up",
        color: SoloTheme.cyan
      )
      if consequences.isEmpty {
        SupportingEmptyState(
          text: "Founder decisions will appear here when they create lasting company state.",
          symbol: "circle.dashed"
        )
      } else {
        VStack(spacing: 10) {
          ForEach(consequences) { consequence in
            CompanyConsequenceView(
              consequence: consequence,
              isNew: newlyUnlockedIDs.contains(consequence.id),
              reduceMotion: reduceMotion
            )
          }
        }
      }
    }
    .ventureSupportingSection()
  }
}

private struct CompanyConsequenceView: View {
  var consequence: VentureScreenPresentation.Consequence
  var isNew: Bool
  var reduceMotion: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: consequence.symbol)
        .font(.headline)
        .foregroundStyle(consequence.kind == .companyStandard ? SoloTheme.cyan : SoloTheme.amber)
        .frame(width: 28, height: 28)
        .symbolEffect(.bounce, value: isNew)
      VStack(alignment: .leading, spacing: 4) {
        Text(consequence.title).font(.subheadline.bold())
        Text(consequence.detail).font(.caption).foregroundStyle(.secondary)
        Text(consequence.status.uppercased())
          .font(.caption2.weight(.black))
          .tracking(0.6)
          .foregroundStyle(consequence.kind == .companyStandard ? SoloTheme.cyan : SoloTheme.amber)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(.white.opacity(0.035), in: .rect(cornerRadius: 12))
    .overlay(alignment: .leading) {
      Capsule()
        .fill(consequence.kind == .companyStandard ? SoloTheme.cyan : SoloTheme.amber)
        .frame(width: 2)
        .opacity(isNew ? 1 : 0.3)
    }
    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .leading)))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Company consequence: \(consequence.title). \(consequence.detail). \(consequence.status)")
  }
}

private struct GarageInfrastructureSection: View {
  var upgrades: [VentureScreenPresentation.Upgrade]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeading(
        title: "Garage infrastructure",
        detail: "Installed capabilities supporting the company.",
        symbol: "shippingbox.fill",
        color: SoloTheme.cyan
      )
      if upgrades.isEmpty {
        SupportingEmptyState(
          text: "Complete sprints, earn revenue, and record evidence to evolve the garage.",
          symbol: "wrench.adjustable"
        )
      } else {
        VStack(spacing: 8) {
          ForEach(upgrades) { upgrade in
            HStack(spacing: 12) {
              Image(systemName: upgrade.symbol)
                .foregroundStyle(SoloTheme.cyan)
                .frame(width: 26)
              VStack(alignment: .leading, spacing: 2) {
                Text(upgrade.name.uppercased()).font(.subheadline.weight(.bold))
                Text("INSTALLED · ACTIVE")
                  .font(.caption2.weight(.black))
                  .tracking(0.6)
                  .foregroundStyle(SoloTheme.cyan)
              }
              Spacer()
              Image(systemName: "checkmark.circle.fill").foregroundStyle(SoloTheme.cyan)
            }
            .padding(12)
            .background(SoloTheme.cyan.opacity(0.055), in: .rect(cornerRadius: 11))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(upgrade.name), installed and active")
          }
        }
      }
    }
    .ventureSupportingSection()
  }
}

private struct FounderDoctrineCard: View {
  var doctrine: VentureScreenPresentation.Doctrine

  var body: some View {
    ZStack(alignment: .topTrailing) {
      DoctrineNetworkMotif().accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 10) {
        Label("FOUNDER DOCTRINE", systemImage: "network")
          .font(.caption.weight(.black))
          .tracking(1.1)
          .foregroundStyle(SoloTheme.purple)
        Text(doctrine.name)
          .font(.title.bold())
        Text(doctrine.summary)
          .font(.callout)
          .foregroundStyle(.secondary)
        Divider().overlay(.white.opacity(0.1))
        Label(doctrine.consequenceStatement, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary.opacity(0.9))
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .background {
      LinearGradient(
        colors: [SoloTheme.purple.opacity(0.14), SoloTheme.cyan.opacity(0.045), SoloTheme.card],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    .clipShape(.rect(cornerRadius: 20))
    .overlay { RoundedRectangle(cornerRadius: 20).stroke(SoloTheme.purple.opacity(0.3), lineWidth: 1) }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Founder doctrine: \(doctrine.name). \(doctrine.summary). \(doctrine.consequenceStatement)")
  }
}

private struct DoctrineNetworkMotif: View {
  var body: some View {
    ZStack {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .stroke(SoloTheme.purple.opacity(0.08 + Double(index) * 0.03), lineWidth: 1)
          .frame(width: CGFloat(48 + index * 34), height: CGFloat(48 + index * 34))
      }
      Circle().fill(SoloTheme.cyan.opacity(0.25)).frame(width: 7, height: 7)
    }
    .frame(width: 130, height: 130)
    .offset(x: 34, y: -34)
  }
}

private struct CareerObjectiveCard: View {
  var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("CAREER OBJECTIVE", systemImage: "map.fill")
        .font(.caption.weight(.black))
        .tracking(1)
        .foregroundStyle(.secondary)
      Text(text)
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct SectionHeading: View {
  var title: String
  var detail: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 11) {
      Image(systemName: symbol).foregroundStyle(color).frame(width: 24)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.headline)
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

private struct SupportingEmptyState: View {
  var text: String
  var symbol: String

  var body: some View {
    Label(text, systemImage: symbol)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.white.opacity(0.025), in: .rect(cornerRadius: 11))
  }
}

private struct VentureRevealModifier: ViewModifier {
  var stage: Int
  var threshold: Int
  var reduceMotion: Bool

  func body(content: Content) -> some View {
    content
      .opacity(stage >= threshold ? 1 : 0)
      .offset(y: reduceMotion || stage >= threshold ? 0 : 10)
  }
}

private struct VentureHeroSurfaceModifier: ViewModifier {
  var accent: Color
  @Environment(\.colorSchemeContrast) private var contrast

  func body(content: Content) -> some View {
    content
      .background(
        LinearGradient(
          colors: [accent.opacity(0.085), SoloTheme.card, Color.black.opacity(0.12)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(.rect(cornerRadius: 20))
      .overlay {
        RoundedRectangle(cornerRadius: 20)
          .stroke(accent.opacity(contrast == .increased ? 0.7 : 0.25), lineWidth: 1)
      }
  }
}

private struct VentureSystemSurfaceModifier: ViewModifier {
  var accent: Color
  @Environment(\.colorSchemeContrast) private var contrast

  func body(content: Content) -> some View {
    content
      .background(SoloTheme.card.opacity(0.8), in: .rect(cornerRadius: 16))
      .overlay(alignment: .leading) {
        Capsule().fill(accent.opacity(0.75)).frame(width: 3).padding(.vertical, 14)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(.white.opacity(contrast == .increased ? 0.24 : 0.07), lineWidth: 1)
      }
  }
}

private extension View {
  func ventureReveal(stage: Int, threshold: Int, reduceMotion: Bool) -> some View {
    modifier(VentureRevealModifier(stage: stage, threshold: threshold, reduceMotion: reduceMotion))
  }

  func ventureHeroSurface(accent: Color) -> some View {
    modifier(VentureHeroSurfaceModifier(accent: accent))
  }

  func ventureSystemSurface(accent: Color) -> some View {
    modifier(VentureSystemSurfaceModifier(accent: accent))
  }

  func ventureSupportingSection() -> some View {
    padding(16)
      .background(.white.opacity(0.025), in: .rect(cornerRadius: 16))
      .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.055), lineWidth: 1) }
  }
}
