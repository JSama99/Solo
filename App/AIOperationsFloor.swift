import SwiftUI

/// Presentation-only Founder Computer composition. It reads canonical state and
/// owns only disclosure state; simulation, finance and calendar mutations stay in GameStore.
struct AIOperationsFloor: View {
  var agents: [LivingAgentProjection]
  var tasks: [SoloTask]
  var summary: CompanyCommandFounderSummary
  var objective: String
  var venture: Int
  var sprint: Int
  var finance: CompanyFinance
  var calendar: OperatingCalendar
  var stats: FounderStats
  var availability: [String: CompanyCommandAgentAvailability]
  var reduceMotion: Bool
  var onAssign: (String) -> Void
  var onReview: (String) -> Void
  var onOpenDetail: (CompanyCommandFocus) -> Void
  var onCommit: () -> Void

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var expandedStationID: String?

  private var isWide: Bool { horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize }
  private var motionReduced: Bool { reduceMotion || systemReduceMotion }
  private var projection: AIOperationsFloorProjection {
    .derive(agents: agents, tasks: tasks, summary: summary, finance: finance, calendar: calendar)
  }

  var body: some View {
    Group { if isWide { wideFloor } else { compactFloor } }
      .padding(isWide ? 18 : 14)
      .background(floorBackground)
      .clipShape(.rect(cornerRadius: 26))
      .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.13), lineWidth: 1) }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("ai-operations-floor")
  }

  private var compactFloor: some View {
    LazyVStack(alignment: .leading, spacing: 14) {
      floorHeader
      console
      reviewQueue
      ForEach(orderedAgents) { station($0) }
      persistentAction
    }
  }

  private var wideFloor: some View {
    VStack(alignment: .leading, spacing: 16) {
      floorHeader
      HStack(alignment: .top, spacing: 16) {
        console.frame(maxWidth: .infinity)
        reviewQueue.frame(width: 360)
      }
      HStack(alignment: .top, spacing: 14) {
        ForEach(orderedAgents) { station($0).frame(maxWidth: .infinity) }
      }
      persistentAction
    }
  }

  private var floorHeader: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Label("AI OPERATIONS FLOOR", systemImage: "cpu.fill").font(.caption.weight(.black))
      Spacer(minLength: 8)
      Text("FOUNDER COMPUTER · V\(venture) S\(sprint)").font(.caption2.weight(.bold))
    }
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
    .accessibilitySortPriority(50)
  }

  private var floorBackground: some View {
    ZStack {
      LinearGradient(colors: [.black, Color(red: 0.025, green: 0.05, blue: 0.08), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
      GeometryReader { proxy in
        ForEach(0..<5, id: \.self) { index in
          Capsule().fill(.white.opacity(0.035)).frame(width: proxy.size.width * 0.62, height: 1)
            .rotationEffect(.degrees(-18)).offset(x: CGFloat(index - 2) * 92, y: CGFloat(index) * 70)
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }

  private var console: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 10) {
        Label("FOUNDER COMMAND CONSOLE", systemImage: "command").font(.headline.weight(.black)).foregroundStyle(SoloTheme.amber)
        Spacer(minLength: 8)
        Label("DAY \(calendar.totalDays) · \(calendar.period.title.uppercased())", systemImage: calendar.period.symbol)
          .font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text("CURRENT COMPANY OBJECTIVE").font(.caption2.weight(.black)).foregroundStyle(.secondary)
        Text(objective).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
        Text("Venture \(venture) · Sprint \(sprint) · Day \(calendar.dayOfSprint) of 7")
          .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      }
      nextActionSurface
      if dynamicTypeSize.isAccessibilitySize {
        companyStatus
        founderCondition
        companyTrajectory
      } else {
        companyStatus
        HStack(alignment: .top, spacing: 10) {
          founderCondition.frame(maxWidth: .infinity)
          companyTrajectory.frame(maxWidth: .infinity)
        }
      }
    }
    .padding(isWide ? 18 : 14)
    .background(SoloTheme.amber.opacity(0.10), in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.amber.opacity(0.55), lineWidth: 1.5) }
    .accessibilityElement(children: .contain)
    .accessibilitySortPriority(40)
    .accessibilityIdentifier("founder-command-console")
  }

  private var nextActionSurface: some View {
    Button { onOpenDetail(.founder) } label: {
      HStack(spacing: 10) {
        Image(systemName: projection.nextAction.symbol).font(.title3.weight(.bold)).foregroundStyle(projection.nextAction.color)
        VStack(alignment: .leading, spacing: 2) {
          Text(projection.nextAction.eyebrow).font(.caption2.weight(.black)).foregroundStyle(projection.nextAction.color)
          Text(projection.nextAction.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
          Text(projection.nextAction.detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 4)
        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      .padding(12).frame(maxWidth: .infinity, alignment: .leading)
      .background(projection.nextAction.color.opacity(0.12), in: .rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(projection.nextAction.color.opacity(0.55), lineWidth: differentiateWithoutColor ? 2 : 1) }
    }
    .buttonStyle(.plain)
    .accessibilityHint("Opens the canonical Founder decision surface.")
    .accessibilityIdentifier("founder-next-action")
  }

  private var companyStatus: some View {
    metricGroup("COMPANY STATUS", symbol: "building.2.fill", accent: SoloTheme.amber) {
      metricRow("Cash", finance.cash.formatted(.currency(code: "USD").precision(.fractionLength(0))), "banknote.fill")
      metricRow("Revenue", finance.lifetimeRevenue.formatted(.currency(code: "USD").precision(.fractionLength(0))), "dollarsign")
      metricRow("Net burn", finance.recentDailyNetBurn.formatted(.currency(code: "USD").precision(.fractionLength(0))), "flame.fill")
      metricRow("Runway", finance.runwayLabel(fallbackDailyBurn: 120), "calendar")
    }
  }

  private var founderCondition: some View {
    metricGroup("FOUNDER CONDITION", symbol: "person.crop.circle.fill", accent: SoloTheme.cyan) {
      metricRow("Energy", "\(stats.energy)", "battery.75percent")
      metricRow("Attention", "\(summary.attentionRemaining)/\(summary.attentionMaximum)", "eye.fill")
    }
  }

  private var companyTrajectory: some View {
    metricGroup("COMPANY TRAJECTORY", symbol: "chart.xyaxis.line", accent: SoloTheme.coral) {
      metricRow("Momentum", "\(stats.momentum)", "arrow.up.right")
      metricRow("Trust", "\(stats.trust)", "checkmark.shield")
      metricRow("Coverage", signed(stats.coverage), stats.coverage < 0 ? "arrow.down.right" : "antenna.radiowaves.left.and.right")
        .accessibilityLabel("Coverage, \(stats.coverage > 0 ? "positive" : stats.coverage < 0 ? "negative" : "neutral") \(abs(stats.coverage))")
    }
  }

  private func metricGroup<Content: View>(_ title: String, symbol: String, accent: Color, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol).font(.caption2.weight(.black)).foregroundStyle(accent)
      content()
    }
    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
    .background(.black.opacity(0.28), in: .rect(cornerRadius: 11))
  }

  private func metricRow(_ label: String, _ value: String, _ symbol: String) -> some View {
    HStack(spacing: 7) {
      Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 14)
      Text(label).foregroundStyle(.secondary)
      Spacer(minLength: 4)
      Text(value).fontWeight(.bold).monospacedDigit()
    }
    .font(.caption).contentTransition(.numericText()).accessibilityElement(children: .combine)
  }

  private var reviewQueue: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("FOUNDER REVIEW QUEUE", systemImage: "tray.full.fill").font(.subheadline.weight(.black))
        Spacer()
        Text("\(projection.queue.count)").font(.headline.monospacedDigit()).foregroundStyle(projection.queue.first?.priority.color ?? .secondary)
      }
      if projection.queue.isEmpty {
        Label {
          Text(AIOperationsFloorProjection.emptyQueueText).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        } icon: { Image(systemName: "tray").foregroundStyle(.secondary) }
          .padding(.vertical, 4).accessibilityIdentifier("founder-review-empty-state")
      } else {
        ForEach(projection.queue) { queueItem($0) }
      }
    }
    .padding(12).background(.white.opacity(0.055), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(projection.queue.first?.priority.color.opacity(0.7) ?? .white.opacity(0.12), lineWidth: projection.queue.isEmpty ? 1 : 1.5) }
    .accessibilitySortPriority(30).accessibilityIdentifier("founder-review-queue")
  }

  private func queueItem(_ item: AIOperationsFloorProjection.QueueItem) -> some View {
    let enabled = AIOperationsFloorProjection.queueActionEnabled(item: item, availability: availability[item.agentID])
    return Button {
      item.action == .review ? onReview(item.agentID) : onOpenDetail(.agent(item.agentID))
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Image(systemName: item.symbol).foregroundStyle(item.priority.color)
          Text(item.priority.title.uppercased()).font(.caption2.weight(.black)).foregroundStyle(item.priority.color)
          Text("· \(item.agentName.uppercased())").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
          Spacer(minLength: 4)
          Text(item.reviewability).font(.caption2.weight(.semibold)).foregroundStyle(enabled ? item.priority.color : .secondary)
        }
        Text(item.title).font(.caption.weight(.bold))
        Text(item.decisionSummary).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 10) {
          Label(item.lifecycle, systemImage: "point.3.connected.trianglepath.dotted")
          Label(item.implication, systemImage: "clock.badge.exclamationmark")
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.caption2.weight(.bold))
        }
        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
      }
      .padding(9).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
      .background(item.priority.color.opacity(item.priority == .critical ? 0.12 : 0.07), in: .rect(cornerRadius: 10))
      .overlay { RoundedRectangle(cornerRadius: 10).stroke(item.priority.color.opacity(0.35), lineWidth: 1) }
    }
    .buttonStyle(.plain).disabled(!enabled)
    .accessibilityLabel(item.accessibilityLabel)
    .accessibilityHint(enabled ? item.action.accessibilityHint : "This packet is visible but its state cannot be invoked again.")
  }

  private func station(_ agent: LivingAgentProjection) -> some View {
    OperationsStationCard(agent: agent, availability: availability[agent.agentID] ?? .init(), expanded: expandedStationID == agent.agentID, reduceMotion: motionReduced) {
      withAnimation(motionReduced ? nil : .smooth) { expandedStationID = expandedStationID == agent.agentID ? nil : agent.agentID }
    } onAssign: { onAssign(agent.agentID) } onReview: { onReview(agent.agentID) } onOpenDetail: { onOpenDetail(.agent(agent.agentID)) }
  }

  private var orderedAgents: [LivingAgentProjection] {
    ["aurora", "stacks", "brio"].compactMap { id in agents.first { $0.agentID == id } }
  }

  private var persistentAction: some View {
    Button { summary.canCommit ? onCommit() : onOpenDetail(.founder) } label: {
      Label(summary.canCommit ? "COMMIT SPRINT" : "NEXT · \(projection.nextAction.shortTitle.uppercased())", systemImage: summary.canCommit ? "arrow.forward.square.fill" : projection.nextAction.symbol)
        .font(.subheadline.weight(.black)).frame(maxWidth: .infinity, minHeight: 48)
        .background(summary.canCommit ? SoloTheme.amber : .white.opacity(0.08), in: .rect(cornerRadius: 13))
        .foregroundStyle(summary.canCommit ? .black : .primary)
        .overlay { if !summary.canCommit { RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.16), lineWidth: 1) } }
    }
    .buttonStyle(.plain)
    .accessibilityHint(summary.canCommit ? "Commits the canonical sprint and advances its operating time." : "Opens the current canonical Founder action. This does not commit or end the day.")
    .accessibilitySortPriority(10).accessibilityIdentifier("operations-floor-persistent-action")
  }

  private func signed(_ value: Int) -> String { "\(value > 0 ? "+" : "")\(value)" }
}

private struct OperationsStationCard: View {
  var agent: LivingAgentProjection
  var availability: CompanyCommandAgentAvailability
  var expanded: Bool
  var reduceMotion: Bool
  var onToggle: () -> Void
  var onAssign: () -> Void
  var onReview: () -> Void
  var onOpenDetail: () -> Void

  private var accent: Color { agent.role == .research ? SoloTheme.cyan : agent.role == .engineering ? SoloTheme.amber : SoloTheme.coral }
  private var specialty: String { agent.role == .research ? "INTELLIGENCE · EVIDENCE" : agent.role == .engineering ? "ENGINEERING · DELIVERY" : "GROWTH · PUBLIC SIGNAL" }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button(action: onToggle) {
        HStack(spacing: 10) {
          portrait
          VStack(alignment: .leading, spacing: 2) {
            Text(agent.name.uppercased()).font(.subheadline.weight(.black))
            Text(specialty).font(.caption2.weight(.bold)).foregroundStyle(accent)
          }
          Spacer(minLength: 4)
          Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
        }.contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(agent.name), \(specialty). \(expanded ? "Collapse" : "Expand") station")
      statusLine
      Text(agent.taskTitle ?? "No assigned objective — available for a Founder priority.").font(.caption).foregroundStyle(.secondary).lineLimit(expanded ? nil : 2)
      roleSnapshot
      handoffStrip
      if expanded { expandedSurface }
      primaryAction
    }
    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    .background(accent.opacity(expanded ? 0.13 : 0.075), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke((agent.needsFounderAttention ? SoloTheme.amber : accent).opacity(expanded ? 0.9 : 0.48), lineWidth: agent.needsFounderAttention ? 2 : expanded ? 1.5 : 1) }
    .shadow(color: agent.needsFounderAttention ? accent.opacity(0.18) : .clear, radius: 10, y: 3)
    .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: agent.activity)
    .accessibilityElement(children: .contain).accessibilitySortPriority(accessibilityPriority)
    .accessibilityIdentifier("operations-station-\(agent.agentID)")
  }

  private var statusLine: some View {
    HStack(spacing: 6) {
      chip(agent.activity.label, activitySymbol, agent.needsFounderAttention ? SoloTheme.amber : accent)
      ForEach(agent.conditions.sorted { $0.rawValue < $1.rawValue }, id: \.self) { chip($0.label, conditionSymbol($0), conditionTint($0)) }
    }
  }

  @ViewBuilder private var roleSnapshot: some View {
    switch agent.role {
    case .research: StationPipeline(accent: accent, title: "RESEARCH PATH", labels: ["Question", "Sources", "Packet"], activeStep: pipelineStep, status: researchStatus, progress: agent.progress)
    case .engineering: StationPipeline(accent: accent, title: "BUILD PIPELINE", labels: ["Module", "Tests", "Gate"], activeStep: pipelineStep, status: engineeringStatus, progress: agent.progress)
    case .marketing: StationPipeline(accent: accent, title: "PUBLIC SIGNAL", labels: ["Message", "Audience", "Claim"], activeStep: pipelineStep, status: growthStatus, progress: agent.progress)
    case .general: StationPipeline(accent: accent, title: "GENERAL OPERATIONS", labels: ["Brief", "Work", "Handoff"], activeStep: pipelineStep, status: engineeringStatus, progress: agent.progress)
    }
  }

  private var handoffStrip: some View {
    Label(handoffText, systemImage: "arrow.right.doc.on.clipboard").font(.caption2.weight(.semibold)).foregroundStyle(accent)
      .frame(maxWidth: .infinity, alignment: .leading).padding(7).background(accent.opacity(0.10), in: .rect(cornerRadius: 8))
      .contentTransition(.interpolate).accessibilityLabel(handoffText)
  }

  private var expandedSurface: some View {
    VStack(alignment: .leading, spacing: 9) {
      roleDetails
      Divider()
      HStack { Label("Stress \(agent.stressLabel)", systemImage: "gauge.with.dots.needle.33percent"); Spacer(); Text("Level \(agent.level)") }.font(.caption2)
      Button("Open detailed workstation", systemImage: "rectangle.expand.vertical", action: onOpenDetail)
        .buttonStyle(.bordered).tint(accent).frame(minHeight: 44)
    }
    .padding(10).background(.black.opacity(0.28), in: .rect(cornerRadius: 10))
    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
  }

  @ViewBuilder private var roleDetails: some View {
    switch agent.role {
    case .research:
      detail("Evidence packet", "Source relationships and contradictions remain reported until Founder Review.", "link")
      detail("Verification path", "Inspect assumptions or request verification in the detailed workstation.", "checkmark.magnifyingglass")
    case .engineering:
      detail("Delivery surface", "Module stages, test output and deployment gates.", "shippingbox.fill")
      detail("Truth boundary", "Pipeline progress is activity, not verified correctness.", "shield.lefthalf.filled")
    case .marketing:
      detail("Campaign surface", "Audience response, variants and public-claim approval.", "megaphone.fill")
      detail("Coverage", "Public signal remains distinct from Trust and Momentum.", "antenna.radiowaves.left.and.right")
    case .general:
      detail("Operations surface", "Assignment progress and the canonical handoff path.", "square.grid.2x2.fill")
      detail("Truth boundary", "Activity never implies verified correctness.", "shield.lefthalf.filled")
    }
  }

  private func detail(_ title: String, _ text: String, _ symbol: String) -> some View {
    Label { VStack(alignment: .leading, spacing: 2) { Text(title).font(.caption.weight(.bold)); Text(text).font(.caption2).foregroundStyle(.secondary) } } icon: { Image(systemName: symbol).foregroundStyle(accent) }
  }

  private var primaryAction: some View {
    Button(action: primaryActionHandler) {
      Label(primaryActionTitle, systemImage: primaryActionSymbol).font(.caption.weight(.bold)).frame(maxWidth: .infinity, minHeight: 44)
        .background(primaryActionProminent ? accent : .white.opacity(0.08), in: .rect(cornerRadius: 10))
        .foregroundStyle(primaryActionProminent ? .black : .primary)
        .overlay { if !primaryActionProminent { RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.35), lineWidth: 1) } }
    }
    .buttonStyle(.plain).accessibilityHint(primaryActionHint)
  }

  private var primaryActionTitle: String {
    if availability.canReview { return "Open Founder Review" }
    if availability.requiresResolution { return "Resolve Founder Decision" }
    if availability.canAssign { return "Assign \(agent.name)" }
    return "Inspect \(agent.name)"
  }
  private var primaryActionSymbol: String { availability.canReview ? "eye.fill" : availability.requiresResolution ? "lock.open.fill" : availability.canAssign ? "arrow.down.doc.fill" : "rectangle.expand.vertical" }
  private var primaryActionProminent: Bool { availability.canReview || availability.requiresResolution || availability.canAssign }
  private var primaryActionHint: String {
    if availability.canReview { return "Opens canonical review. Reviewing costs one Founder Attention." }
    if availability.requiresResolution { return "Opens canonical resolution choices without repeating review." }
    if availability.canAssign { return "Shows canonical assignment cost and consequences before confirmation." }
    return "Opens the detailed workstation without changing company state."
  }
  private func primaryActionHandler() { if availability.canReview { onReview() } else if availability.requiresResolution { onOpenDetail() } else if availability.canAssign { onAssign() } else { onOpenDetail() } }

  private var pipelineStep: Int {
    switch agent.activity { case .idle, .resting: 0; case .assignmentReceived: 1; case .working: agent.progress < 0.58 ? 1 : 2; default: 3 }
  }
  private var researchStatus: String { status(idle: "Awaiting research question", assigned: "Research question received", working: "Collecting reported sources", output: "Evidence packet reported", reviewing: "Founder inspecting evidence", decided: "Review path recorded") }
  private var engineeringStatus: String { status(idle: "Build surface standing by", assigned: "Build brief received", working: "Module pipeline active", output: "Artifact reported at output dock", reviewing: "Founder inspecting test report", decided: "Delivery decision recorded") }
  private var growthStatus: String { status(idle: "Campaign surface standing by", assigned: "Campaign brief received", working: "Message variants in motion", output: "Public claim reported for review", reviewing: "Founder inspecting public signal", decided: "Campaign decision recorded") }
  private func status(idle: String, assigned: String, working: String, output: String, reviewing: String, decided: String) -> String {
    switch agent.activity { case .idle, .resting: idle; case .assignmentReceived: assigned; case .working: working; case .workComplete, .awaitingReview: output; case .reviewing: reviewing; case .reviewed, .resolving, .resolved: decided }
  }
  private var handoffText: String {
    switch agent.activity {
    case .assignmentReceived: "FOUNDER → \(agent.name.uppercased()) · assignment received"
    case .working: "\(agent.name.uppercased()) · work surface active"
    case .workComplete, .awaitingReview: "\(agent.name.uppercased()) → FOUNDER REVIEW · reported output docked"
    case .reviewing: "FOUNDER REVIEW → \(agent.name.uppercased()) · evidence inspection"
    case .reviewed: "FOUNDER REVIEW · resolution required"
    case .resolving, .resolved: "FOUNDER REVIEW → COMPANY SYSTEM · decision path"
    case .idle, .resting: "OPERATIONAL LINK · standing by"
    }
  }
  private var activitySymbol: String {
    switch agent.activity { case .idle: "pause.fill"; case .assignmentReceived: "arrow.down.doc.fill"; case .working: "waveform.path.ecg"; case .workComplete, .awaitingReview: "tray.full.fill"; case .reviewing: "eye.fill"; case .reviewed: "checkmark.shield.fill"; case .resolving: "lock.rotation"; case .resolved: "lock.fill"; case .resting: "moon.zzz.fill" }
  }
  private func conditionTint(_ condition: LivingAgentCondition) -> Color { condition == .verified ? SoloTheme.mint : condition == .focused ? accent : SoloTheme.coral }
  private func conditionSymbol(_ condition: LivingAgentCondition) -> String {
    switch condition { case .focused: "scope"; case .stressed: "gauge.with.dots.needle.67percent"; case .overloaded: "exclamationmark.triangle.fill"; case .drifting: "arrow.triangle.branch"; case .verified: "checkmark.seal.fill"; case .overclaimed: "quote.bubble.fill"; case .evidenceIncomplete: "doc.badge.ellipsis" }
  }
  private func chip(_ title: String, _ symbol: String, _ tint: Color) -> some View {
    Label(title, systemImage: symbol).font(.caption2.weight(.semibold)).lineLimit(1).padding(.horizontal, 7).padding(.vertical, 4).foregroundStyle(tint).background(.black.opacity(0.28), in: .capsule)
  }
  private var portrait: some View {
    ZStack {
      Circle().fill(accent.opacity(0.2))
      if let asset = AgentPortraitAsset.name(for: agent.agentID) { Image(asset).resizable().scaledToFill().accessibilityHidden(true) } else { Text(agent.initials).font(.headline.weight(.black)) }
      Circle().fill(agent.needsFounderAttention ? SoloTheme.amber : accent).frame(width: 9, height: 9).overlay { Circle().stroke(.black, lineWidth: 2) }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).accessibilityHidden(true)
    }
    .frame(width: 48, height: 48).clipShape(.circle).overlay { Circle().stroke(accent.opacity(0.8), lineWidth: 1.5) }
  }
  private var accessibilityPriority: Double { agent.agentID == "aurora" ? 23 : agent.agentID == "stacks" ? 22 : agent.agentID == "brio" ? 21 : 20 }
}

private struct StationPipeline: View {
  var accent: Color
  var title: String
  var labels: [String]
  var activeStep: Int
  var status: String
  var progress: Double
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack { Text(title).font(.caption2.weight(.black)).foregroundStyle(accent); Spacer(); Text(status).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
      HStack(spacing: 4) {
        ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
          VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(index < activeStep ? accent : .white.opacity(0.10)).frame(height: 4)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(index < activeStep ? .primary : .secondary)
          }
        }
      }
      ProgressView(value: progress).tint(accent).accessibilityLabel("Reported work progress").accessibilityValue("\(Int((progress * 100).rounded())) percent. Activity only; not verification.")
    }
    .padding(9).background(.black.opacity(0.24), in: .rect(cornerRadius: 10))
  }
}

struct AIOperationsFloorProjection: Equatable {
  enum Priority: Int, Comparable, Equatable {
    case informational, important, critical
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    var title: String { self == .critical ? "Critical" : self == .important ? "Important" : "Informational" }
    var color: Color { self == .critical ? SoloTheme.coral : self == .important ? SoloTheme.amber : SoloTheme.cyan }
  }
  enum QueueAction: Equatable {
    case review, resolve, inspect
    var accessibilityHint: String { self == .review ? "Opens the canonical Founder Review path." : self == .resolve ? "Opens the reviewed work for a Founder resolution." : "Inspects the current workflow state without repeating it." }
  }
  struct QueueItem: Identifiable, Equatable {
    var id: String { agentID }
    var agentID: String
    var agentName: String
    var title: String
    var lifecycle: String
    var decisionSummary: String
    var implication: String
    var reviewability: String
    var priority: Priority
    var action: QueueAction
    var symbol: String
    var isReviewable: Bool { action == .review }
    var accessibilityLabel: String { "\(priority.title) priority. \(agentName). \(title). \(lifecycle). \(decisionSummary). \(implication). \(reviewability)." }
  }
  struct NextAction: Equatable { var eyebrow: String; var title: String; var shortTitle: String; var detail: String; var symbol: String; var color: Color }
  var queue: [QueueItem]
  var nextAction: NextAction

  static var primarySurfaceIDs: [String] { ["founder-command-console", "founder-review-queue", "operations-station-aurora", "operations-station-stacks", "operations-station-brio"] }
  static var emptyQueueText: String { "No reports awaiting Founder Review. Aurora, Stacks and Brio will route reported outputs here." }
  static func primaryStationIDs(from agents: [LivingAgentProjection]) -> [String] { ["aurora", "stacks", "brio"].filter { id in agents.contains { $0.agentID == id } } }
  static func queueActionEnabled(item: QueueItem, availability: CompanyCommandAgentAvailability?) -> Bool {
    switch item.action { case .review: item.isReviewable && availability?.canReview == true; case .resolve: availability?.requiresResolution == true; case .inspect: true }
  }
  static func derive(agents: [LivingAgentProjection], tasks: [SoloTask] = [], summary: CompanyCommandFounderSummary, finance: CompanyFinance, calendar: OperatingCalendar) -> Self {
    let items = agents.compactMap { agent -> QueueItem? in
      guard [.workComplete, .awaitingReview, .reviewing, .reviewed, .resolving].contains(agent.activity) else { return nil }
      let title = tasks.first { $0.id == agent.taskID }?.title ?? agent.taskTitle ?? "Reported output"
      switch agent.activity {
      case .workComplete, .awaitingReview:
        return .init(agentID: agent.agentID, agentName: agent.name, title: title, lifecycle: "Reported output", decisionSummary: "Inspect evidence, assumptions and uncertainty before choosing a resolution.", implication: "Founder Attention 1", reviewability: "Review now", priority: .critical, action: .review, symbol: "doc.text.magnifyingglass")
      case .reviewed:
        return .init(agentID: agent.agentID, agentName: agent.name, title: title, lifecycle: "Reviewed", decisionSummary: "A Founder resolution is required before Sprint commit.", implication: "Blocks progression", reviewability: "Resolve now", priority: .critical, action: .resolve, symbol: "lock.open.fill")
      case .reviewing:
        return .init(agentID: agent.agentID, agentName: agent.name, title: title, lifecycle: "Founder reviewing", decisionSummary: "Evidence is being revealed through the canonical review sequence.", implication: "Decision in progress", reviewability: "Inspect", priority: .important, action: .inspect, symbol: "eye.fill")
      case .resolving:
        return .init(agentID: agent.agentID, agentName: agent.name, title: title, lifecycle: "Resolution locking", decisionSummary: "The selected Founder decision is being recorded in the company system.", implication: "State transition", reviewability: "Inspect", priority: .informational, action: .inspect, symbol: "lock.rotation")
      default: return nil
      }
    }.sorted { $0.priority != $1.priority ? $0.priority > $1.priority : $0.agentID < $1.agentID }
    return .init(queue: items, nextAction: deriveNextAction(summary: summary, finance: finance, calendar: calendar))
  }
  private static func deriveNextAction(summary: CompanyCommandFounderSummary, finance: CompanyFinance, calendar: OperatingCalendar) -> NextAction {
    if summary.resolutionCount > 0 { return .init(eyebrow: "BLOCKING DECISION", title: "Resolve the reviewed Founder decision", shortTitle: "Resolve decision", detail: "A reviewed output still needs an explicit consequence path before the Sprint can commit.", symbol: "lock.open.fill", color: SoloTheme.coral) }
    if summary.reviewCount > 0 { return .init(eyebrow: "FOUNDER REVIEW", title: "Review the highest-priority reported output", shortTitle: "Review output", detail: "Review costs one Founder Attention and reveals evidence through the canonical review path.", symbol: "doc.text.magnifyingglass", color: SoloTheme.amber) }
    if summary.workInProgressCount > 0 { return .init(eyebrow: "WORK ACTIVE", title: "Monitor the active assignment", shortTitle: "Monitor work", detail: "Agent progress is reported activity, not verified correctness. No action is required yet.", symbol: "waveform.path.ecg", color: SoloTheme.cyan) }
    if summary.canCommit { return .init(eyebrow: "COMMIT-READY", title: "Commit the Sprint", shortTitle: "Commit Sprint", detail: "This advances the canonical operating calendar and presents the Sprint outcome.", symbol: "arrow.forward.square.fill", color: SoloTheme.mint) }
    if finance.cash <= 500 || finance.runwayLabel(fallbackDailyBurn: 120) == "0 days" { return .init(eyebrow: "FINANCIAL PRESSURE", title: summary.nextAction, shortTitle: "Address pressure", detail: "Cash or derived runway is under immediate pressure on Company Day \(calendar.totalDays).", symbol: "exclamationmark.triangle.fill", color: SoloTheme.coral) }
    return .init(eyebrow: "NEXT FOUNDER ACTION", title: summary.nextAction, shortTitle: "Founder action", detail: "Open the canonical Founder surface to continue the current Sprint phase.", symbol: summary.sprintPhase.symbol, color: SoloTheme.amber)
  }
}
