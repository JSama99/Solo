import SwiftUI

/// Presentation-only composition for the Founder Computer. It projects the
/// existing simulation into one readable operating loop; it has no persistence
/// or mutation authority.
struct AIOperationsFloor: View {
  var agents: [LivingAgentProjection]
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
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var expandedStationID: String?

  private var isWide: Bool { horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize }
  private var motionReduced: Bool { reduceMotion || systemReduceMotion }
  private var projection: AIOperationsFloorProjection {
    .derive(agents: agents, summary: summary, finance: finance, calendar: calendar)
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      if isWide { wideFloor }
      compactFloor
    }
    .padding(14)
    .background(floorBackground)
    .clipShape(.rect(cornerRadius: 26))
    .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.13), lineWidth: 1) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("AI Operations Floor")
    .accessibilityValue("\(summary.nextAction). Company day \(calendar.totalDays), \(calendar.period.title).")
  }

  private var compactFloor: some View {
    VStack(alignment: .leading, spacing: 14) {
      floorHeader
      console
      reviewQueue
      ForEach(orderedAgents) { agent in
        station(agent)
      }
      persistentAction
    }
  }

  private var wideFloor: some View {
    VStack(alignment: .leading, spacing: 14) {
      floorHeader
      console
      HStack(alignment: .top, spacing: 14) {
        VStack(spacing: 12) { station(agent(id: "aurora")); station(agent(id: "stacks")) }
        VStack(spacing: 12) { reviewQueue; station(agent(id: "brio")); persistentAction }
      }
    }
  }

  private var floorHeader: some View {
    Label("AI OPERATIONS FLOOR", systemImage: "cpu.fill")
      .font(.caption.weight(.black))
      .foregroundStyle(.secondary)
      .accessibilityAddTraits(.isHeader)
  }

  private var floorBackground: some View {
    ZStack {
      LinearGradient(colors: [.black, Color(red: 0.025, green: 0.05, blue: 0.08), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
      GeometryReader { proxy in
        ForEach(0..<5, id: \.self) { index in
          Capsule().fill(.white.opacity(0.035)).frame(width: proxy.size.width * 0.62, height: 1)
            .rotationEffect(.degrees(-18)).offset(x: CGFloat(index - 2) * 92, y: CGFloat(index) * 70)
        }
      }.allowsHitTesting(false)
    }
  }

  private var console: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Label("FOUNDER COMMAND CONSOLE", systemImage: "command")
          .font(.headline.weight(.black)).foregroundStyle(SoloTheme.amber)
        Spacer()
        Label("DAY \(calendar.totalDays) · \(calendar.period.title.uppercased())", systemImage: calendar.period.symbol)
          .font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      Text(objective).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
      Text("Venture \(venture) · Sprint \(sprint) · Day \(calendar.dayOfSprint) of 7")
        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: isWide ? 5 : 2), spacing: 8) {
        metric("Cash", finance.cash.formatted(.currency(code: "USD").precision(.fractionLength(0))), "banknote.fill")
        metric("Revenue", finance.lifetimeRevenue.formatted(.currency(code: "USD").precision(.fractionLength(0))), "dollarsign")
        metric("Net burn", finance.recentDailyNetBurn.formatted(.currency(code: "USD").precision(.fractionLength(0))), "flame.fill")
        metric("Runway", finance.runwayLabel(fallbackDailyBurn: 120), "calendar")
        metric("Energy", "\(stats.energy)", "battery.75percent")
        metric("Momentum", "\(stats.momentum)", "arrow.up.right")
        metric("Trust", "\(stats.trust)", "checkmark.shield")
        metric("Coverage", signed(stats.coverage), "antenna.radiowaves.left.and.right")
        metric("Attention", "\(summary.attentionRemaining)/\(summary.attentionMaximum)", "eye")
      }
      Button { onOpenDetail(.founder) } label: {
        Label(summary.nextAction, systemImage: summary.canCommit ? "checkmark.seal.fill" : "arrow.right.circle.fill")
          .font(.subheadline.weight(.semibold)).foregroundStyle(summary.canCommit ? SoloTheme.mint : .primary)
          .padding(10).frame(maxWidth: .infinity, alignment: .leading)
          .background(.black.opacity(0.34), in: .rect(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .accessibilityHint("Opens the canonical Founder decision surface.")
    }
    .padding(14).background(SoloTheme.amber.opacity(0.10), in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(SoloTheme.amber.opacity(0.55), lineWidth: 1.5) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder Command Console. Objective: \(objective)")
  }

  private var reviewQueue: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack { Label("FOUNDER REVIEW QUEUE", systemImage: "tray.full.fill").font(.subheadline.weight(.black)); Spacer(); Text("\(projection.queue.count)").font(.headline.monospacedDigit()).foregroundStyle(SoloTheme.amber) }
      if projection.queue.isEmpty {
        Text("No packets awaiting review. The floor will route reported outputs here.").font(.caption).foregroundStyle(.secondary)
      } else {
        ForEach(projection.queue) { item in
          Button { onReview(item.agentID) } label: {
            HStack(spacing: 9) {
              Image(systemName: item.symbol).foregroundStyle(item.accent)
              VStack(alignment: .leading, spacing: 1) { Text(item.title).font(.caption.weight(.bold)); Text(item.detail).font(.caption2).foregroundStyle(.secondary) }
              Spacer(); Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 8)
          }.buttonStyle(.plain).disabled(!item.isReviewable)
        }
      }
    }
    .padding(12).background(.white.opacity(0.055), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(projection.queue.isEmpty ? .white.opacity(0.12) : SoloTheme.amber.opacity(0.65), lineWidth: 1) }
    .accessibilityLabel("Founder Review Queue, \(projection.queue.count) items")
  }

  @ViewBuilder private func station(_ agent: LivingAgentProjection?) -> some View {
    if let agent { OperationsStationCard(agent: agent, availability: availability[agent.agentID] ?? .init(), expanded: expandedStationID == agent.agentID, reduceMotion: motionReduced, onToggle: { withAnimation(.smooth) { expandedStationID = expandedStationID == agent.agentID ? nil : agent.agentID } }, onAssign: { onAssign(agent.agentID) }, onReview: { onReview(agent.agentID) }, onOpenDetail: { onOpenDetail(.agent(agent.agentID)) }) }
  }
  private var orderedAgents: [LivingAgentProjection] { [agent(id: "aurora"), agent(id: "stacks"), agent(id: "brio")].compactMap { $0 } }
  private func agent(id: String) -> LivingAgentProjection? { agents.first { $0.agentID == id } }
  private var persistentAction: some View { Group { if summary.canCommit { Button("COMMIT SPRINT", systemImage: "arrow.forward.square.fill", action: onCommit).font(.subheadline.weight(.black)).frame(maxWidth: .infinity, minHeight: 48).background(SoloTheme.amber, in: .rect(cornerRadius: 13)).foregroundStyle(.black).buttonStyle(.plain).accessibilityHint("Commits the canonical sprint simulation, including its associated operating time.") } } }
  private func metric(_ label: String, _ value: String, _ symbol: String) -> some View { Label { VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(.secondary); Text(value).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75) } } icon: { Image(systemName: symbol).foregroundStyle(SoloTheme.amber) }.frame(maxWidth: .infinity, alignment: .leading).padding(8).background(.black.opacity(0.28), in: .rect(cornerRadius: 9)) }
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
  private var workSurface: String { agent.role == .research ? "Sources · contradictions · confidence" : agent.role == .engineering ? "Modules · tests · deployment gates" : "Audience · variants · public response" }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button(action: onToggle) { HStack(spacing: 10) { portrait; VStack(alignment: .leading, spacing: 2) { Text(agent.name.uppercased()).font(.subheadline.weight(.black)); Text(specialty).font(.caption2.weight(.bold)).foregroundStyle(accent); Text(agent.activity.label).font(.caption.weight(.semibold)).foregroundStyle(.primary) }; Spacer(); Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary) } }.buttonStyle(.plain)
      HStack(spacing: 6) { statusChip(agent.activity.label, agent.activity == .awaitingReview || agent.activity == .workComplete ? "tray.full.fill" : "waveform.path.ecg"); ForEach(agent.conditions.sorted { $0.rawValue < $1.rawValue }, id: \.self) { statusChip($0.label, "checkmark.shield") } }
      handoffStrip
      Text(agent.taskTitle ?? "No assigned objective — available for a Founder priority.").font(.caption).foregroundStyle(.secondary).lineLimit(expanded ? nil : 2)
      if expanded { expandedSurface }
    }
    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    .background(accent.opacity(expanded ? 0.13 : 0.075), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(expanded ? 0.82 : 0.42), lineWidth: expanded ? 1.5 : 1) }
    .accessibilityElement(children: .contain).accessibilityLabel("\(agent.name), \(specialty)").accessibilityValue(agent.accessibilityValue)
  }
  private var portrait: some View { ZStack { Circle().fill(accent.opacity(0.2)); if let asset = AgentPortraitAsset.name(for: agent.agentID) { Image(asset).resizable().scaledToFill() } else { Text(agent.initials).font(.headline.weight(.black)) } }.frame(width: 48, height: 48).clipShape(.circle).overlay { Circle().stroke(accent.opacity(0.8), lineWidth: 1.5) } }
  private var handoffStrip: some View {
    let handoff = switch agent.activity {
    case .assignmentReceived: "FOUNDER  →  \(agent.name.uppercased()) · assignment packet received"
    case .working: "\(agent.name.uppercased()) · work surface active"
    case .workComplete, .awaitingReview: "\(agent.name.uppercased())  →  FOUNDER REVIEW · reported artifact docked"
    case .reviewing: "FOUNDER REVIEW  →  \(agent.name.uppercased()) · evidence inspection"
    case .reviewed, .resolving, .resolved: "FOUNDER REVIEW  →  COMPANY SYSTEM · decision path"
    case .idle, .resting: "OPERATIONAL LINK · standing by"
    }
    return Label(handoff, systemImage: "arrow.right.doc.on.clipboard")
      .font(.caption2.weight(.semibold)).foregroundStyle(accent)
      .frame(maxWidth: .infinity, alignment: .leading).padding(7)
      .background(accent.opacity(0.10), in: .rect(cornerRadius: 8))
      .accessibilityLabel(handoff)
  }
  private var expandedSurface: some View { VStack(alignment: .leading, spacing: 9) { Label(workSurface, systemImage: agent.role.symbol).font(.caption.weight(.bold)); ProgressView(value: agent.progress).tint(accent).accessibilityLabel("Reported work progress").accessibilityValue("\(Int((agent.progress * 100).rounded())) percent") ; HStack { Text("Trust \(agent.trustLabel)").font(.caption2); Spacer(); Text("Level \(agent.level)").font(.caption2) }; Divider(); HStack { if availability.canAssign { Button("Assign", systemImage: "arrow.down.doc", action: onAssign).buttonStyle(.bordered).tint(accent) }; if availability.canReview { Button("Review", systemImage: "eye", action: onReview).buttonStyle(.borderedProminent).tint(accent) }; Button("Details", systemImage: "rectangle.expand.vertical", action: onOpenDetail).buttonStyle(.bordered) }.font(.caption.weight(.bold)) }.padding(10).background(.black.opacity(0.28), in: .rect(cornerRadius: 10)) }
  private func statusChip(_ title: String, _ symbol: String) -> some View { Label(title, systemImage: symbol).font(.caption2.weight(.semibold)).lineLimit(1).padding(.horizontal, 7).padding(.vertical, 4).background(.black.opacity(0.28), in: .capsule) }
}

struct AIOperationsFloorProjection: Equatable {
  struct QueueItem: Identifiable, Equatable { var id: String { agentID }; var agentID: String; var title: String; var detail: String; var symbol: String; var accent: Color; var isReviewable: Bool }
  var queue: [QueueItem]
  static func primaryStationIDs(from agents: [LivingAgentProjection]) -> [String] {
    ["aurora", "stacks", "brio"].filter { id in agents.contains { $0.agentID == id } }
  }
  static func derive(agents: [LivingAgentProjection], summary: CompanyCommandFounderSummary, finance: CompanyFinance, calendar: OperatingCalendar) -> Self {
    let items = agents.compactMap { agent -> QueueItem? in
      guard [.workComplete, .awaitingReview, .reviewing, .reviewed, .resolving].contains(agent.activity) else { return nil }
      let reviewable = agent.activity == .awaitingReview || agent.activity == .workComplete
      return QueueItem(agentID: agent.agentID, title: "\(agent.name) · \(reviewable ? "reported output" : agent.activity.label)", detail: reviewable ? "Inspect evidence, assumptions, uncertainty, cost and consequences." : "Founder decision is in progress.", symbol: reviewable ? "doc.text.magnifyingglass" : "hourglass", accent: agent.role == .research ? SoloTheme.cyan : agent.role == .engineering ? SoloTheme.amber : SoloTheme.coral, isReviewable: reviewable)
    }
    return Self(queue: items)
  }
}
