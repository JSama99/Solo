import SwiftUI

struct VentureScreen: View {
  var store: GameStore

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealStage = 0
  @State private var didCaptureInitialState = false
  @State private var isVisible = false
  @State private var motionSnapshot: VentureMotionSnapshot?
  @State private var newConsequenceIDs = Set<String>()
  @State private var newUpgradeIDs = Set<String>()
  @State private var displayedSprint = 1
  @State private var sprintPhase: SprintMotionPhase = .idle
  @State private var sprintCycle = 0
  @State private var evidenceFeedback = 0
  @State private var trackRecordFeedback = 0
  @State private var objectiveMotionFeedback = 0
  @State private var chapterMotionFeedback = 0
  @State private var thesisFeedback = 0
  @State private var doctrineFeedback = 0
  @State private var sprintFeedback = 0
  @State private var consequenceFeedback = 0
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
          VentureStatusInstrument(
            presentation: state,
            displayedSprint: displayedSprint,
            sprintPhase: sprintPhase,
            evidenceFeedback: evidenceFeedback,
            trackRecordFeedback: trackRecordFeedback,
            reduceMotion: reduceMotion
          )
            .ventureReveal(stage: revealStage, threshold: 1, reduceMotion: reduceMotion)

          VentureChapterCard(
            presentation: state,
            changeTrigger: chapterMotionFeedback,
            reduceMotion: reduceMotion
          )
            .ventureReveal(stage: revealStage, threshold: 2, reduceMotion: reduceMotion)

          VentureObjectiveCard(
            objective: state.objective,
            changeTrigger: objectiveMotionFeedback,
            reduceMotion: reduceMotion
          )
            .ventureReveal(stage: revealStage, threshold: 3, reduceMotion: reduceMotion)

          StrategicThesisCard(
            name: state.thesisName,
            detail: state.thesisDetail,
            changeTrigger: thesisFeedback,
            reduceMotion: reduceMotion
          )
            .ventureReveal(stage: revealStage, threshold: 4, reduceMotion: reduceMotion)

          OperatingPressureCard(pressure: state.pressure, phase: pressurePhase)
            .ventureReveal(stage: revealStage, threshold: 4, reduceMotion: reduceMotion)

          CompanyConsequencesSection(
            consequences: state.consequences,
            newlyUnlockedIDs: newConsequenceIDs,
            reduceMotion: reduceMotion
          )
          .ventureReveal(stage: revealStage, threshold: 5, reduceMotion: reduceMotion)

          GarageInfrastructureSection(
            upgrades: state.upgrades,
            newlyInstalledIDs: newUpgradeIDs,
            reduceMotion: reduceMotion
          )
            .ventureReveal(stage: revealStage, threshold: 5, reduceMotion: reduceMotion)

          FounderDoctrineCard(
            doctrine: state.doctrine,
            changeTrigger: doctrineFeedback,
            reduceMotion: reduceMotion
          )
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
      .onAppear { handleAppearance(state) }
      .onDisappear { isVisible = false }
      .task { await revealScreenIfNeeded() }
      .onChange(of: state) { _, current in processChange(current) }
      .sensoryFeedback(.impact(weight: .medium), trigger: sprintFeedback)
      .sensoryFeedback(.impact(weight: .medium), trigger: consequenceFeedback)
      .sensoryFeedback(.impact(weight: .heavy, intensity: 0.78), trigger: chapterFeedback)
      .sensoryFeedback(.impact(weight: .heavy, intensity: 0.68), trigger: objectiveFeedback)
    }
  }

  private func captureInitialState(_ state: VentureScreenPresentation) {
    guard !didCaptureInitialState else { return }
    motionSnapshot = VentureMotionSnapshot(state)
    displayedSprint = state.sprint
    didCaptureInitialState = true
  }

  private func handleAppearance(_ state: VentureScreenPresentation) {
    isVisible = true
    if didCaptureInitialState {
      processChange(state)
    } else {
      captureInitialState(state)
    }
  }

  private func processChange(_ state: VentureScreenPresentation) {
    guard isVisible else { return }
    let current = VentureMotionSnapshot(state)
    guard didCaptureInitialState, let previous = motionSnapshot else {
      motionSnapshot = current
      displayedSprint = state.sprint
      return
    }
    motionSnapshot = current
    let events = VentureMotionEvents(previous: previous, current: current)

    if let advance = events.sprintAdvance {
      runSprintSequence(advance)
      runPressureSequence()
    } else if previous.venture != current.venture || previous.sprint != current.sprint {
      displayedSprint = current.sprint
    }
    if events.evidenceGain > 0 { evidenceFeedback += 1 }
    if events.trackRecordDelta != 0 { trackRecordFeedback += 1 }
    if previous.objectiveProgress != current.objectiveProgress { objectiveMotionFeedback += 1 }
    if events.chapterAdvanced { chapterMotionFeedback += 1 }
    if events.thesisChanged { thesisFeedback += 1 }
    if events.doctrineChanged { doctrineFeedback += 1 }
    presentNewConsequences(events.newConsequenceIDs)
    presentNewUpgrades(events.newUpgradeIDs)

    // One haptic per causal batch; the most important company event wins.
    if events.chapterAdvanced {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 350))
        chapterFeedback += 1
      }
    } else if events.objectiveCompleted {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 160 : 730))
        objectiveFeedback += 1
      }
    } else if !events.newConsequenceIDs.isEmpty {
      consequenceFeedback += 1
    } else if events.sprintAdvance != nil {
      sprintFeedback += 1
    }
  }

  private func presentNewConsequences(_ additions: Set<String>) {
    guard !additions.isEmpty else { return }
    newConsequenceIDs.formUnion(additions)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(1_050))
      newConsequenceIDs.subtract(additions)
    }
  }

  private func presentNewUpgrades(_ additions: Set<String>) {
    guard !additions.isEmpty else { return }
    newUpgradeIDs.formUnion(additions)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(900))
      newUpgradeIDs.subtract(additions)
    }
  }

  @MainActor
  private func revealScreenIfNeeded() async {
    guard revealStage == 0 else { return }
    if reduceMotion {
      revealStage = 6
      return
    }
    for stage in 1...6 {
      withAnimation(VentureMotion.standard) { revealStage = stage }
      try? await Task.sleep(for: VentureMotion.stagger)
    }
  }

  private func runSprintSequence(_ advance: VentureMotionEvents.SprintAdvance) {
    sprintCycle += 1
    let cycle = sprintCycle
    displayedSprint = advance.from
    if reduceMotion {
      sprintPhase = .activating
      displayedSprint = advance.to
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(240))
        if sprintCycle == cycle { sprintPhase = .idle }
      }
      return
    }
    withAnimation(VentureMotion.fast) { sprintPhase = .resolving }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(150))
      guard sprintCycle == cycle else { return }
      withAnimation(VentureMotion.marker) {
        sprintPhase = .advancing
        displayedSprint = advance.to
      }
      try? await Task.sleep(for: .milliseconds(360))
      guard sprintCycle == cycle else { return }
      withAnimation(VentureMotion.fast) { sprintPhase = .activating }
      try? await Task.sleep(for: .milliseconds(180))
      guard sprintCycle == cycle else { return }
      withAnimation(VentureMotion.fast) { sprintPhase = .idle }
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
      try? await Task.sleep(for: .milliseconds(130))
      guard pressureCycle == cycle else { return }
      withAnimation(.smooth(duration: 0.2)) { pressurePhase = .energy }
      try? await Task.sleep(for: .milliseconds(260))
      guard pressureCycle == cycle else { return }
      withAnimation(.smooth(duration: 0.25)) { pressurePhase = .idle }
    }
  }
}

private enum SprintMotionPhase: Equatable {
  case idle
  case resolving
  case advancing
  case activating
}

private enum PressurePhase: Equatable {
  case idle
  case runway
  case energy
  case both
}

private struct VentureStatusInstrument: View {
  var presentation: VentureScreenPresentation
  var displayedSprint: Int
  var sprintPhase: SprintMotionPhase
  var evidenceFeedback: Int
  var trackRecordFeedback: Int
  var reduceMotion: Bool
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
        Text(displayedSprint, format: .number.precision(.integerLength(2)))
          .font(.system(size: 66, weight: .black, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .contentTransition(.numericText(value: Double(displayedSprint)))
          .animation(reduceMotion ? .easeOut(duration: 0.14) : VentureMotion.marker, value: displayedSprint)
        Text("OF \(presentation.totalSprints)")
          .font(.subheadline.weight(.bold))
          .tracking(1.5)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Sprint \(displayedSprint) of \(presentation.totalSprints)")
      .accessibilityValue("\(max(0, displayedSprint - 1)) sprints completed")

      SprintProgressTrack(
        currentSprint: displayedSprint,
        totalSprints: presentation.totalSprints,
        phase: sprintPhase,
        reduceMotion: reduceMotion
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
      color: SoloTheme.mint,
      feedbackTrigger: evidenceFeedback,
      feedbackKind: .evidence
    )
    if !dynamicTypeSize.isAccessibilitySize {
      Divider().overlay(.white.opacity(0.12)).frame(height: 42)
    }
    InstrumentMetric(
      title: "TRACK RECORD",
      value: presentation.trackRecord,
      symbol: "chart.line.uptrend.xyaxis",
      color: SoloTheme.cyan,
      feedbackTrigger: trackRecordFeedback,
      feedbackKind: .trackRecord
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
  enum FeedbackKind: Equatable {
    case evidence
    case trackRecord
  }

  var title: String
  var value: Int
  var symbol: String
  var color: Color
  var feedbackTrigger: Int
  var feedbackKind: FeedbackKind
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var displayedValue: Int
  @State private var feedbackActive = false

  init(
    title: String,
    value: Int,
    symbol: String,
    color: Color,
    feedbackTrigger: Int,
    feedbackKind: FeedbackKind
  ) {
    self.title = title
    self.value = value
    self.symbol = symbol
    self.color = color
    self.feedbackTrigger = feedbackTrigger
    self.feedbackKind = feedbackKind
    _displayedValue = State(initialValue: value)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Label(title, systemImage: symbol)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      Text(displayedValue, format: .number.precision(.integerLength(2)))
        .font(.title2.weight(.black).monospacedDigit())
        .foregroundStyle(color)
        .contentTransition(.numericText(value: Double(displayedValue)))
        .animation(reduceMotion ? .easeOut(duration: 0.14) : VentureMotion.standard, value: displayedValue)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 3)
    .padding(.horizontal, 5)
    .background(color.opacity(feedbackActive ? 0.14 : 0), in: .rect(cornerRadius: 9))
    .overlay(alignment: .topTrailing) {
      if feedbackActive && feedbackKind == .evidence {
        Image(systemName: "checkmark.seal.fill")
          .font(.caption)
          .foregroundStyle(color)
          .offset(y: reduceMotion ? 0 : -8)
          .transition(.opacity)
          .accessibilityHidden(true)
      }
    }
    .onChange(of: feedbackTrigger) { _, _ in runFeedback() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title.capitalized)
    .accessibilityValue("\(displayedValue)")
  }

  private func runFeedback() {
    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : VentureMotion.fast) {
      displayedValue = value
      feedbackActive = true
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(feedbackKind == .evidence ? 360 : 260))
      withAnimation(.easeOut(duration: 0.18)) { feedbackActive = false }
    }
  }
}

private struct SprintProgressTrack: View {
  var currentSprint: Int
  var totalSprints: Int
  var phase: SprintMotionPhase
  var reduceMotion: Bool

  var body: some View {
    GeometryReader { proxy in
      let spacing: CGFloat = 5
      let width = max(1, (proxy.size.width - spacing * CGFloat(max(0, totalSprints - 1))) / CGFloat(max(1, totalSprints)))
      ZStack(alignment: .leading) {
        HStack(spacing: spacing) {
          ForEach(1...max(1, totalSprints), id: \.self) { sprint in
            Capsule()
              .fill(sprint < currentSprint ? SoloTheme.cyan.opacity(0.72) : .white.opacity(0.14))
              .frame(maxWidth: .infinity)
              .frame(height: sprint < currentSprint ? 5 : 4)
          }
        }
        Capsule()
          .fill(SoloTheme.amber)
          .frame(width: width, height: phase == .activating && !reduceMotion ? 10 : 8)
          .overlay { Capsule().stroke(.white.opacity(0.72), lineWidth: 1) }
          .shadow(color: SoloTheme.amber.opacity(phase == .idle ? 0.22 : 0.58), radius: phase == .idle ? 3 : 7)
          .scaleEffect(x: phase == .resolving ? 1.06 : 1, y: phase == .activating ? 1.12 : 1)
          .offset(x: CGFloat(max(0, currentSprint - 1)) * (width + spacing))
          .animation(reduceMotion ? .easeOut(duration: 0.14) : VentureMotion.marker, value: currentSprint)
          .animation(reduceMotion ? nil : VentureMotion.fast, value: phase)
      }
    }
    .frame(height: 12)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Sprint timeline")
    .accessibilityValue("Sprint \(currentSprint) of \(totalSprints); \(max(0, currentSprint - 1)) completed")
  }
}

private struct VentureChapterCard: View {
  var presentation: VentureScreenPresentation
  var changeTrigger: Int
  var reduceMotion: Bool
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var displayedPresentation: VentureScreenPresentation
  @State private var revealPhase: ChapterRevealPhase = .settled
  @State private var transitionCycle = 0

  init(presentation: VentureScreenPresentation, changeTrigger: Int, reduceMotion: Bool) {
    self.presentation = presentation
    self.changeTrigger = changeTrigger
    self.reduceMotion = reduceMotion
    _displayedPresentation = State(initialValue: presentation)
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      ChapterSignalMotif(chapter: displayedPresentation.chapterNumber)
        .opacity(revealPhase == .closing ? 0.35 : 1)
        .scaleEffect(revealPhase == .closing && !reduceMotion ? 0.97 : 1)
        .accessibilityHidden(true)

      Text("\(displayedPresentation.chapterNumber)")
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
        .opacity(showsChapterLabel ? 1 : 0)
        Text(displayedPresentation.chapterTitle)
          .font(.title.bold())
          .contentTransition(.interpolate)
          .opacity(showsTitle ? 1 : 0)
        Text(displayedPresentation.chapterDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .opacity(showsDetail ? 1 : 0)
        Text("IN PROGRESS")
          .font(.caption2.weight(.black))
          .tracking(1)
          .foregroundStyle(SoloTheme.amber)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(SoloTheme.amber.opacity(0.12), in: .capsule)
          .opacity(showsDetail ? 1 : 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .frame(minHeight: 190)
    .ventureHeroSurface(accent: SoloTheme.amber)
    .opacity(revealPhase == .closing ? 0.72 : 1)
    .offset(y: reduceMotion ? 0 : verticalOffset)
    .animation(reduceMotion ? .easeOut(duration: 0.16) : VentureMotion.standard, value: revealPhase)
    .onChange(of: presentation) { _, newValue in
      guard newValue.chapterNumber == displayedPresentation.chapterNumber else { return }
      guard revealPhase == .settled else { return }
        displayedPresentation = newValue
    }
    .onChange(of: changeTrigger) { _, _ in runChapterTransition(to: presentation) }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Chapter \(displayedPresentation.chapterNumber), \(displayedPresentation.chapterTitle). \(displayedPresentation.chapterDetail). \(displayedPresentation.chapterProgressLabel)")
  }

  private var showsChapterLabel: Bool {
    revealPhase != .closing
  }

  private var showsTitle: Bool {
    revealPhase == .title || revealPhase == .detail || revealPhase == .settled
  }

  private var showsDetail: Bool {
    revealPhase == .detail || revealPhase == .settled
  }

  private var verticalOffset: CGFloat {
    switch revealPhase {
    case .settled: 0
    case .closing: -7
    case .chapter: 10
    case .title: 5
    case .detail: 1
    }
  }

  private func runChapterTransition(to newValue: VentureScreenPresentation) {
    transitionCycle += 1
    let cycle = transitionCycle
    if reduceMotion {
      withAnimation(.easeOut(duration: 0.12)) { revealPhase = .closing }
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(120))
        guard transitionCycle == cycle else { return }
        displayedPresentation = newValue
        withAnimation(.easeOut(duration: 0.16)) { revealPhase = .settled }
      }
      return
    }
    withAnimation(VentureMotion.fast) { revealPhase = .closing }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(180))
      guard transitionCycle == cycle else { return }
      displayedPresentation = newValue
      withAnimation(VentureMotion.fast) { revealPhase = .chapter }
      try? await Task.sleep(for: .milliseconds(170))
      guard transitionCycle == cycle else { return }
      withAnimation(VentureMotion.standard) { revealPhase = .title }
      try? await Task.sleep(for: .milliseconds(170))
      guard transitionCycle == cycle else { return }
      withAnimation(VentureMotion.standard) { revealPhase = .detail }
      try? await Task.sleep(for: .milliseconds(280))
      guard transitionCycle == cycle else { return }
      revealPhase = .settled
    }
  }

  private var chapterSymbol: String {
    switch displayedPresentation.chapterNumber {
    case 1: "hammer.fill"
    case 2: "person.2.wave.2.fill"
    case 3: "megaphone.fill"
    default: "arrow.up.right"
    }
  }

  @ViewBuilder
  private var chapterHeader: some View {
    Label("CHAPTER \(displayedPresentation.chapterNumber)", systemImage: chapterSymbol)
      .font(.caption.weight(.black))
      .tracking(1.2)
      .foregroundStyle(SoloTheme.amber)
      .fixedSize(horizontal: false, vertical: true)
    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
    Text(displayedPresentation.chapterProgressLabel)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

private enum ChapterRevealPhase: Equatable {
  case settled
  case closing
  case chapter
  case title
  case detail
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
  var changeTrigger: Int
  var reduceMotion: Bool
  @State private var displayedProgress: Double
  @State private var completionStage: ObjectiveCompletionStage
  @State private var sweepProgress = 0.0
  @State private var completionCycle = 0
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  init(objective: VentureScreenPresentation.Objective, changeTrigger: Int, reduceMotion: Bool) {
    self.objective = objective
    self.changeTrigger = changeTrigger
    self.reduceMotion = reduceMotion
    _displayedProgress = State(initialValue: objective.progress)
    _completionStage = State(initialValue: objective.isComplete ? .resolved : .active)
  }

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

      ObjectiveProgressTrack(
        progress: displayedProgress,
        sweepProgress: completionStage == .sweeping && !reduceMotion ? sweepProgress : nil
      )

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
    .onChange(of: changeTrigger) { _, _ in
      let oldValue = displayedProgress
      let newValue = objective.progress
      guard oldValue != newValue else { return }
      if newValue < oldValue {
        displayedProgress = newValue
        completionStage = objective.isComplete ? .resolved : .active
        return
      }
      withAnimation(reduceMotion ? .easeOut(duration: 0.15) : VentureMotion.progress) {
        displayedProgress = newValue
      }
      guard newValue >= 1, oldValue < 1 else { return }
      runCompletionSequence()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Venture objective, \(objective.title). \(objective.detail)")
    .accessibilityValue("\(objective.percentage) percent complete. Reward: \(objective.reward)")
  }

  @ViewBuilder
  private var objectiveHeader: some View {
        Label("VENTURE OBJECTIVE", systemImage: completionStage == .resolved ? "checkmark.seal.fill" : "target")
          .font(.caption.weight(.black))
          .tracking(1.1)
          .foregroundStyle(SoloTheme.mint)
          .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
          .fixedSize(horizontal: false, vertical: true)
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Text("\(displayedPercentage)%")
          .font(.title3.weight(.black).monospacedDigit())
          .foregroundStyle(completionStage == .resolved ? SoloTheme.mint : .primary)
          .contentTransition(.numericText(value: Double(displayedPercentage)))
  }

  @ViewBuilder
  private var objectiveFooter: some View {
        if completionStage == .resolved {
          Text("OBJECTIVE COMPLETE")
            .font(.caption.weight(.black))
            .tracking(0.9)
            .foregroundStyle(SoloTheme.mint)
            .transition(.opacity)
        } else {
          Text("\(displayedPercentage)% COMPLETE")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Label(
          completionStage == .resolved ? "\(objective.reward) · APPLIED" : objective.reward,
          systemImage: "gift.fill"
        )
          .font(.caption.weight(.bold))
          .fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(rewardEmphasized ? .black : SoloTheme.mint)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(rewardEmphasized ? SoloTheme.mint : SoloTheme.mint.opacity(0.1), in: .capsule)
          .scaleEffect(completionStage == .reward && !reduceMotion ? 1.045 : 1)
          .animation(reduceMotion ? .easeOut(duration: 0.14) : VentureMotion.fast, value: completionStage)
  }

  private var displayedPercentage: Int {
    Int((displayedProgress * 100).rounded())
  }

  private var rewardEmphasized: Bool {
    completionStage == .reward || completionStage == .resolved
  }

  private func runCompletionSequence() {
    completionCycle += 1
    let cycle = completionCycle
    if reduceMotion {
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(160))
        guard completionCycle == cycle else { return }
        withAnimation(.easeOut(duration: 0.18)) { completionStage = .resolved }
      }
      return
    }
    completionStage = .finishing
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(430))
      guard completionCycle == cycle else { return }
      sweepProgress = 0
      completionStage = .sweeping
      withAnimation(.easeOut(duration: 0.28)) { sweepProgress = 1 }
      try? await Task.sleep(for: .milliseconds(300))
      guard completionCycle == cycle else { return }
      withAnimation(VentureMotion.fast) { completionStage = .reward }
      try? await Task.sleep(for: .milliseconds(210))
      guard completionCycle == cycle else { return }
      withAnimation(VentureMotion.fast) { completionStage = .resolved }
    }
  }
}

private enum ObjectiveCompletionStage: Equatable {
  case active
  case finishing
  case sweeping
  case reward
  case resolved
}

private struct ObjectiveProgressTrack: View {
  var progress: Double
  var sweepProgress: Double?

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.1))
        Capsule()
          .fill(LinearGradient(colors: [SoloTheme.cyan, SoloTheme.mint], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(8, proxy.size.width * progress))
        if let sweepProgress {
          Capsule()
            .fill(.white.opacity(0.75))
            .frame(width: 32)
            .blur(radius: 5)
            .offset(x: (proxy.size.width - 32) * sweepProgress)
            .accessibilityHidden(true)
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
  var changeTrigger: Int
  var reduceMotion: Bool
  @State private var changeActive = false
  @State private var displayedName: String
  @State private var displayedDetail: String

  init(name: String, detail: String, changeTrigger: Int, reduceMotion: Bool) {
    self.name = name
    self.detail = detail
    self.changeTrigger = changeTrigger
    self.reduceMotion = reduceMotion
    _displayedName = State(initialValue: name)
    _displayedDetail = State(initialValue: detail)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      ZStack {
        Circle().fill(SoloTheme.cyan.opacity(0.11))
        Image(systemName: "compass.drawing")
          .font(.title2)
          .foregroundStyle(SoloTheme.cyan)
          .rotationEffect(.degrees(changeActive && !reduceMotion ? 10 : 0))
      }
      .frame(width: 48, height: 48)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 6) {
        Text("ACTIVE THESIS")
          .font(.caption.weight(.black))
          .tracking(1)
          .foregroundStyle(SoloTheme.cyan)
        Text(displayedName).font(.title3.bold())
          .contentTransition(.interpolate)
          .fixedSize(horizontal: false, vertical: true)
        Text(displayedDetail).font(.callout).foregroundStyle(.secondary)
          .contentTransition(.opacity)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(18)
    .ventureSystemSurface(accent: SoloTheme.cyan)
    .onChange(of: changeTrigger) { _, _ in
      withAnimation(reduceMotion ? .easeOut(duration: 0.14) : VentureMotion.fast) {
        displayedName = name
        displayedDetail = detail
        changeActive = true
      }
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(280))
        withAnimation(VentureMotion.fast) { changeActive = false }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Active thesis: \(displayedName). \(displayedDetail)")
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
        .fixedSize(horizontal: false, vertical: true)

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) { pressureCosts }
        VStack(spacing: 10) { pressureCosts }
      }

      Text(pressure.milestoneStatus)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
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
      .fixedSize(horizontal: false, vertical: true)
  }
}

private struct PressureCost: View {
  var title: String
  var value: Int
  var symbol: String
  var emphasized: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    .scaleEffect(emphasized && !reduceMotion ? 1.015 : 1)
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
  @State private var revealStage = 3

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: consequence.symbol)
        .font(.headline)
        .foregroundStyle(consequence.kind == .companyStandard ? SoloTheme.cyan : SoloTheme.amber)
        .frame(width: 28, height: 28)
        .opacity(revealStage >= 1 ? 1 : 0)
        .contentTransition(.symbolEffect(.replace))
      VStack(alignment: .leading, spacing: 4) {
        Text(consequence.title).font(.subheadline.bold()).opacity(revealStage >= 2 ? 1 : 0)
        Text(consequence.detail).font(.caption).foregroundStyle(.secondary).opacity(revealStage >= 3 ? 1 : 0)
        Text(consequence.status.uppercased())
          .font(.caption2.weight(.black))
          .tracking(0.6)
          .foregroundStyle(consequence.kind == .companyStandard ? SoloTheme.cyan : SoloTheme.amber)
          .opacity(revealStage >= 3 ? 1 : 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(.white.opacity(0.035), in: .rect(cornerRadius: 12))
    .overlay(alignment: .leading) {
      Capsule()
        .fill(consequence.kind == .companyStandard ? SoloTheme.cyan : SoloTheme.amber)
        .frame(width: 2)
        .opacity(isNew && revealStage >= 2 ? 1 : 0.3)
    }
    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .leading)))
    .onChange(of: isNew, initial: true) { _, newValue in
      guard newValue else { revealStage = 3; return }
      runUnlockSequence()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Company consequence: \(consequence.title). \(consequence.detail). \(consequence.status)")
  }

  private func runUnlockSequence() {
    if reduceMotion {
      revealStage = 0
      withAnimation(.easeOut(duration: 0.2)) { revealStage = 3 }
      return
    }
    revealStage = 0
    Task { @MainActor in
      withAnimation(VentureMotion.fast) { revealStage = 1 }
      try? await Task.sleep(for: .milliseconds(150))
      withAnimation(VentureMotion.fast) { revealStage = 2 }
      try? await Task.sleep(for: .milliseconds(180))
      withAnimation(VentureMotion.standard) { revealStage = 3 }
    }
  }
}

private struct GarageInfrastructureSection: View {
  var upgrades: [VentureScreenPresentation.Upgrade]
  var newlyInstalledIDs: Set<String>
  var reduceMotion: Bool

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
            GarageUpgradeRow(
              upgrade: upgrade,
              isNew: newlyInstalledIDs.contains(upgrade.id),
              reduceMotion: reduceMotion
            )
          }
        }
      }
    }
    .ventureSupportingSection()
  }
}

private struct GarageUpgradeRow: View {
  var upgrade: VentureScreenPresentation.Upgrade
  var isNew: Bool
  var reduceMotion: Bool
  @State private var installed = true

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: upgrade.symbol)
        .foregroundStyle(SoloTheme.cyan)
        .frame(width: 26)
        .opacity(installed ? 1 : 0)
        .scaleEffect(installed || reduceMotion ? 1 : 0.92)
      VStack(alignment: .leading, spacing: 2) {
        Text(upgrade.name.uppercased()).font(.subheadline.weight(.bold))
        Text("INSTALLED · ACTIVE")
          .font(.caption2.weight(.black))
          .tracking(0.6)
          .foregroundStyle(SoloTheme.cyan)
      }
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(SoloTheme.cyan)
        .opacity(installed ? 1 : 0)
    }
    .padding(12)
    .background(SoloTheme.cyan.opacity(installed && isNew ? 0.12 : 0.055), in: .rect(cornerRadius: 11))
    .overlay(alignment: .bottom) {
      Capsule()
        .fill(SoloTheme.cyan.opacity(isNew ? 0.8 : 0.24))
        .frame(height: 2)
        .scaleEffect(x: installed ? 1 : 0, anchor: .leading)
        .accessibilityHidden(true)
    }
    .onChange(of: isNew, initial: true) { _, newValue in
      guard newValue else { installed = true; return }
      installed = false
      withAnimation(reduceMotion ? .easeOut(duration: 0.18) : VentureMotion.standard) { installed = true }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(upgrade.name), installed and active")
  }
}

private struct FounderDoctrineCard: View {
  var doctrine: VentureScreenPresentation.Doctrine
  var changeTrigger: Int
  var reduceMotion: Bool
  @State private var identityActive = false
  @State private var displayedDoctrine: VentureScreenPresentation.Doctrine

  init(
    doctrine: VentureScreenPresentation.Doctrine,
    changeTrigger: Int,
    reduceMotion: Bool
  ) {
    self.doctrine = doctrine
    self.changeTrigger = changeTrigger
    self.reduceMotion = reduceMotion
    _displayedDoctrine = State(initialValue: doctrine)
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      DoctrineNetworkMotif(connected: identityActive && !reduceMotion).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 10) {
        Label("FOUNDER DOCTRINE", systemImage: "network")
          .font(.caption.weight(.black))
          .tracking(1.1)
          .foregroundStyle(SoloTheme.purple)
          .fixedSize(horizontal: false, vertical: true)
        Text(displayedDoctrine.name)
          .font(.title.bold())
          .opacity(identityActive ? 1 : 0.96)
          .contentTransition(.interpolate)
          .fixedSize(horizontal: false, vertical: true)
        Text(displayedDoctrine.summary)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Divider().overlay(.white.opacity(0.1))
        Label(displayedDoctrine.consequenceStatement, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
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
    .onChange(of: changeTrigger) { _, _ in
      identityActive = false
      withAnimation(reduceMotion ? .easeOut(duration: 0.18) : VentureMotion.milestone) {
        displayedDoctrine = doctrine
        identityActive = true
      }
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(760))
        withAnimation(VentureMotion.fast) { identityActive = false }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Founder doctrine: \(displayedDoctrine.name). \(displayedDoctrine.summary). \(displayedDoctrine.consequenceStatement)")
  }
}

private struct DoctrineNetworkMotif: View {
  var connected: Bool

  var body: some View {
    ZStack {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .stroke(SoloTheme.purple.opacity(0.08 + Double(index) * 0.03), lineWidth: 1)
          .frame(width: CGFloat(48 + index * 34), height: CGFloat(48 + index * 34))
          .scaleEffect(connected ? 1 : 0.96)
          .opacity(connected ? 1 : 0.72)
      }
      Circle().fill(SoloTheme.cyan.opacity(connected ? 0.55 : 0.25)).frame(width: 7, height: 7)
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
