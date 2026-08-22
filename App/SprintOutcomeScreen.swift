import SwiftUI

struct SprintOutcomeScreen: View {
  var report: SprintReport
  var result: VisibleSprintResult
  var onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(AppSettingsStore.self) private var settings
  @State private var revealedStep = 0
  @State private var deliveredRevenueFeedback = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          completionHeader
          if revealedStep >= 1 { operatingResult }
          if revealedStep >= 2 { metricChanges }
          if revealedStep >= 3 { assignmentResults }
          if revealedStep >= 4 {
            evidenceAndRisk
            rivalMoveCard
            nextAction
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Sprint Complete")
      .navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled()
      .onAppear(perform: deliverRevenueFeedback)
      .task(id: result.id, reveal)
    }
  }

  private var completionHeader: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("SPRINT COMPLETE", systemImage: "checkmark.seal.fill")
        .font(.caption.weight(.black))
        .tracking(1.8)
        .foregroundStyle(SoloTheme.mint)
      Text("Venture \(result.venture) · Sprint \(result.sprint)")
        .font(.largeTitle.bold())
        .minimumScaleFactor(0.8)
      Text(report.chapterName.isEmpty ? "Operating cycle recorded" : report.chapterName)
        .font(.headline)
        .foregroundStyle(.secondary)
      Text("The Founder commitment is locked. The company record now reflects this sprint.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private var operatingResult: some View {
    outcomeCard {
      Text("OPERATING RESULT").font(.caption2.weight(.black)).foregroundStyle(.secondary)
      Label(result.headline, systemImage: operatingSymbol)
        .font(.title2.bold())
      HStack(spacing: 12) {
        outcomeCount("Verified", result.verifiedStrongOutcomes, "checkmark.shield.fill")
        outcomeCount("Known risks", result.visibleRiskFlags, result.visibleRiskFlags == 0 ? "shield.fill" : "exclamationmark.triangle.fill")
        outcomeCount("Reviewed", result.reviewsCompleted, "eye.fill")
      }
    }
  }

  private var metricChanges: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("COMPANY METRICS").font(.caption.weight(.black)).foregroundStyle(SoloTheme.cyan)
      LazyVGrid(columns: metricColumns, spacing: 10) {
        metric("Runway", before: result.before.runway, after: result.after.runway, unit: "d", symbol: "calendar")
        metric("Energy", before: result.before.energy, after: result.after.energy, symbol: "battery.75percent")
        metric("Momentum", before: result.before.momentum, after: result.after.momentum, symbol: "arrow.up.right")
        metric("Company Trust", before: result.before.trust, after: result.after.trust, symbol: "checkmark.shield")
        metric("Revenue", before: result.before.revenue, after: result.after.revenue, currency: true, symbol: "dollarsign")
        metric("Capital", before: result.before.capital, after: result.after.capital, currency: true, symbol: "banknote")
        metric("Track Record", before: result.before.trackRecord, after: result.after.trackRecord, symbol: "trophy.fill")
      }
    }
  }

  private var assignmentResults: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("WORK COMPLETED").font(.caption.weight(.black)).foregroundStyle(SoloTheme.cyan)
      if result.assignments.isEmpty {
        Text("No agent assignments were committed this sprint.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .soloCard()
      } else {
        ForEach(result.assignments) { assignment in
          AssignmentOutcomeCard(assignment: assignment)
        }
      }
    }
  }

  private var evidenceAndRisk: some View {
    outcomeCard {
      Text("EVIDENCE & RISK").font(.caption.weight(.black)).foregroundStyle(SoloTheme.cyan)
      Label(
        result.evidenceRecorded == 0 ? "No new Evidence Ledger entries" : "\(result.evidenceRecorded) Evidence Ledger entr\(result.evidenceRecorded == 1 ? "y" : "ies") recorded",
        systemImage: result.evidenceRecorded == 0 ? "tray" : "checkmark.seal.fill"
      )
      .font(.headline)
      Label(
        result.visibleRiskFlags == 0 ? "No visible risk flags in completed work" : "\(result.visibleRiskFlags) visible risk flag\(result.visibleRiskFlags == 1 ? "" : "s") require attention",
        systemImage: result.visibleRiskFlags == 0 ? "shield.fill" : "exclamationmark.triangle.fill"
      )
      .font(.subheadline)
      if report.skippedTasks > 0 {
        Label("\(report.skippedTasks) opportunit\(report.skippedTasks == 1 ? "y was" : "ies were") not pursued", systemImage: "arrow.uturn.forward")
          .font(.subheadline)
      }
      if let dilemmaSummary = report.dilemmaSummary {
        Divider()
        Text("FOUNDER DECISION").font(.caption2.weight(.black)).foregroundStyle(SoloTheme.amber)
        Text(dilemmaSummary).font(.subheadline)
      }
      if let objectiveTitle = report.objectiveTitle {
        Label("\(objectiveTitle): \(report.objectiveCompleted ? "Completed" : "Not completed")", systemImage: report.objectiveCompleted ? "target" : "circle.dashed")
          .font(.subheadline.weight(.semibold))
      }
    }
  }

  private var nextAction: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("NEXT").font(.caption.weight(.black)).foregroundStyle(.secondary)
      Label(nextMessage, systemImage: nextSymbol).font(.headline)
      Button(nextButtonTitle, systemImage: nextButtonSymbol, action: onContinue)
        .buttonStyle(SoloPrimaryButtonStyle())
        .accessibilityHint(nextMessage)
    }
    .padding(.top, 4)
  }

  @ViewBuilder
  private var rivalMoveCard: some View {
    if let rivalMoveSummary = report.rivalMoveSummary {
      outcomeCard {
        Text("WHILE YOU WERE HEADS DOWN")
          .font(.caption2.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Label(rivalMoveSummary, systemImage: "bolt.fill")
          .font(.subheadline)
      }
      .transition(.move(edge: .top).combined(with: .opacity))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("While you were heads down. \(rivalMoveSummary)")
    }
  }

  private var metricColumns: [GridItem] {
    dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
  }

  private func metric(
    _ title: String,
    before: Int,
    after: Int,
    unit: String = "",
    currency: Bool = false,
    symbol: String
  ) -> some View {
    let delta = after - before
    let direction = delta > 0 ? "Increased" : delta < 0 ? "Decreased" : "Unchanged"
    let directionSymbol = delta > 0 ? "arrow.up.right" : delta < 0 ? "arrow.down.right" : "minus"
    return VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: symbol).font(.caption.weight(.bold)).foregroundStyle(.secondary)
      Text("\(formatted(before, unit: unit, currency: currency)) → \(formatted(after, unit: unit, currency: currency))")
        .font(.headline.monospacedDigit())
        .contentTransition(.numericText(value: Double(after)))
      Label("\(direction) \(signed(delta, unit: unit, currency: currency))", systemImage: directionSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(delta == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(delta > 0 ? SoloTheme.mint : SoloTheme.amber))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(SoloTheme.card, in: .rect(cornerRadius: 14))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title). Before \(formatted(before, unit: unit, currency: currency)), after \(formatted(after, unit: unit, currency: currency)). \(direction) \(signed(delta, unit: unit, currency: currency)).")
  }

  private func outcomeCount(_ label: String, _ value: Int, _ symbol: String) -> some View {
    Label("\(value) \(label)", systemImage: symbol)
      .font(.caption.weight(.semibold))
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func outcomeCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10, content: content)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(SoloTheme.card, in: .rect(cornerRadius: 18))
      .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08), lineWidth: 1) }
  }

  private var operatingSymbol: String {
    result.visibleRiskFlags > 0 ? "exclamationmark.triangle.fill" : result.verifiedStrongOutcomes > 0 ? "checkmark.seal.fill" : "building.2.fill"
  }

  private var nextMessage: String {
    switch result.transition {
    case .nextSprint: "Sprint \(result.sprint) is recorded. Continue to plan Sprint \(result.sprint + 1)."
    case .ventureCompleted: "Venture \(result.venture) is complete. Continue to the existing venture handoff."
    case .careerEnded: "The career outcome is ready. Continue to view the final company record."
    }
  }

  private var nextButtonTitle: String {
    switch result.transition {
    case .nextSprint: "PLAN NEXT SPRINT"
    case .ventureCompleted: "CONTINUE VENTURE HANDOFF"
    case .careerEnded: "VIEW CAREER OUTCOME"
    }
  }

  private var nextSymbol: String {
    switch result.transition {
    case .nextSprint: "arrow.right.square.fill"
    case .ventureCompleted: "flag.checkered"
    case .careerEnded: "trophy.fill"
    }
  }

  private var nextButtonSymbol: String { nextSymbol }

  private func formatted(_ value: Int, unit: String, currency: Bool) -> String {
    currency ? value.formatted(.currency(code: "USD").precision(.fractionLength(0))) : "\(value)\(unit)"
  }

  private func signed(_ value: Int, unit: String, currency: Bool) -> String {
    let magnitude = formatted(abs(value), unit: unit, currency: currency)
    return value > 0 ? "+\(magnitude)" : value < 0 ? "−\(magnitude)" : "0\(unit)"
  }

  private func deliverRevenueFeedback() {
    guard report.revenueDelta > 0, !deliveredRevenueFeedback else { return }
    deliveredRevenueFeedback = true
    RevenueCelebrationFeedback.play(isEnabled: settings.soundEffectsEnabled)
  }

  private func reveal() async {
    if reduceMotion {
      revealedStep = 4
      return
    }
    for step in 1...4 {
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled else { return }
      withAnimation(.smooth(duration: 0.22)) { revealedStep = step }
    }
    AccessibilityNotification.Announcement("Sprint \(result.sprint) outcome recorded. \(result.headline)").post()
  }
}

private struct AssignmentOutcomeCard: View {
  var assignment: VisibleAssignmentOutcome

  private var accent: Color {
    switch assignment.agentID {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: SoloTheme.mint
    }
  }

  private var verdictSymbol: String {
    switch assignment.result.verificationState {
    case .confirmed, .verified: "checkmark.seal.fill"
    case .overclaimed, .driftDetected, .evidenceIncomplete: "exclamationmark.triangle.fill"
    case .reported, .unverified: "questionmark.diamond.fill"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        Label(assignment.agentName, systemImage: "cpu.fill")
          .font(.headline)
          .foregroundStyle(accent)
        Spacer()
        Text(assignment.role).font(.caption).foregroundStyle(.secondary)
      }
      Text(assignment.taskTitle).font(.subheadline.weight(.semibold))
      Label(assignment.verdict, systemImage: verdictSymbol).font(.subheadline.weight(.bold))
      Text("Reported quality \(assignment.result.reportedQuality) · range \(assignment.result.confidenceRangeLabel)")
        .font(.caption)
        .foregroundStyle(.secondary)
      if let actual = assignment.result.actualQuality {
        Text("Verified actual quality \(actual)").font(.caption.weight(.semibold))
      }
      Text(assignment.evidenceConsequence).font(.caption).foregroundStyle(.secondary)
      Label(assignment.result.knownOperationalRisk, systemImage: assignment.result.hasVisibleRisk ? "exclamationmark.triangle" : "shield")
        .font(.caption)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(accent.opacity(0.08), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.45), lineWidth: 1) }
    .accessibilityElement(children: .combine)
  }
}
