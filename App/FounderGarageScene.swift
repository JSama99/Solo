import SwiftUI

/// A live, interactive visual map of the founder's garage.
struct FounderGarageScene: View {
  var stations: [AgentStationViewModel]
  var facility: FacilityTier
  var stats: FounderStats
  var attentionRemaining: Int
  var attentionMaximum: Int
  var store: GameStore?
  var progression: FounderProgressionStore?
  var presentation: PresentationCoordinator?
  var motion: GarageMotionPolicy
  var date: Date
  @Binding var selectedStation: AgentStationViewModel?

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  @State private var focusedAgentID: String?
  @State private var deskPresented = false
  @State private var stationPresented: AgentStationViewModel?

  private var gate: GarageTurnGate { GarageTurnGate(phase: store?.sprintPhase ?? .founderEvent) }

  var body: some View {
    VStack(spacing: 14) {
      commandHeader
      sprintControls
      garageCanvas
        .frame(height: 430)
      evidenceControl
      commandDeck
      founderReview
      founderMetrics
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(red: 0.055, green: 0.067, blue: 0.09), in: .rect(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
    .sheet(isPresented: $deskPresented) { GarageDeskSheet(store: store, progression: progression, presentation: presentation) }
    .sheet(item: $stationPresented) { station in
      GarageStationSheet(station: station, store: store, presentation: presentation)
    }
  }

  private var commandHeader: some View {
    HStack(spacing: 0) {
      Text("SOLO").font(.title2.weight(.black)).padding(.trailing, 16)
      commandMetric("RUNWAY", value: "\(stats.runway)d", symbol: "dollarsign.circle", color: .green)
      commandMetric("ENERGY", value: "\(Int(stats.energy))%", symbol: "bolt.fill", color: SoloTheme.cyan)
      commandMetric("TRUST", value: "\(Int(stats.trust))%", symbol: "heart", color: .purple)
      commandMetric("SPRINT", value: String(format: "%02d", store?.sprint ?? 1), symbol: "rocket.fill", color: .orange)
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity)
    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 22))
  }

  private func commandMetric(_ title: String, value: String, symbol: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(title, systemImage: symbol).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
      Text(value).font(.title3.weight(.heavy)).foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 12)
    .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 40) }
  }

  private var evidenceControl: some View {
    Button { deskPresented = true } label: {
      Label("EVIDENCE", systemImage: "doc.text")
        .font(.headline.weight(.bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(red: 0.03, green: 0.09, blue: 0.12), in: RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Evidence and sprint controls")
  }

  private var commandDeck: some View {
    HStack(spacing: 10) {
      ForEach(stations) { station in
        Button { focusedAgentID = station.id; stationPresented = station } label: {
          VStack(alignment: .leading, spacing: 6) {
            Image(systemName: station.semanticState.glyph).font(.title2).foregroundStyle(SoloTheme.cyan)
            Text(station.name).font(.caption.weight(.bold)).lineLimit(1)
            Text("LV \(station.progression.level)").font(.caption2.monospaced()).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
          .padding(10)
          .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(station.name) task controls")
      }
    }
  }

  private var founderReview: some View {
    HStack(spacing: 14) {
      Image(systemName: "crown.fill").font(.title2).foregroundStyle(.yellow)
      VStack(alignment: .leading, spacing: 3) {
        Text("FOUNDER REVIEW").font(.caption.weight(.heavy)).foregroundStyle(.yellow)
        Text(store?.activeDilemma?.setup ?? "Review evidence before committing the next move.").font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
      Spacer()
      Button { deskPresented = true } label: { Image(systemName: "checkmark").font(.title3.weight(.bold)).padding(12).background(.yellow, in: RoundedRectangle(cornerRadius: 12)) }
        .buttonStyle(.plain).accessibilityLabel("Open founder review")
    }
    .padding(14)
    .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 18))
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Label("FOUNDER GARAGE · LIVE VIEW", systemImage: facility.symbol)
        .font(.caption.weight(.bold))
        .foregroundStyle(SoloTheme.cyan)
    }
    .accessibilityElement(children: .combine)
  }

  private var usesIllustratedScene: Bool {
    let ids = Set(stations.map { $0.agentID.lowercased() })
    return stations.count <= 3 && ids.isSubset(of: ["aurora", "stacks", "brio"])
  }

  /// The illustrated scene uses the source art's fixed 1600×900 canvas. The
  /// generic layout retains its flexible width for expanded rosters.
  private var canvasWidth: CGFloat {
    usesIllustratedScene
      ? GarageBayLayout.canvasHeight * (1600 / 900)
      : GarageBayLayout(stationCount: stations.count).canvasWidth
  }

  private var garageCanvas: some View {
    ScrollView(.horizontal) {
      GeometryReader { proxy in
        let layout = GarageBayLayout(stationCount: stations.count)
        ZStack {
          if usesIllustratedScene {
            FounderGarageIllustration(
              stations: stations,
              date: date,
              motion: motion,
              gate: gate,
              focusedAgentID: focusedAgentID,
              deskIsPrimary: gate.primary == .desk,
              differentiateWithoutColor: differentiateWithoutColor,
              onSelectStation: { station in
                focusedAgentID = station.id
                stationPresented = station
              },
              onSelectDesk: { deskPresented = true }
            )
          } else {
            garageShell
            ceilingBeams
            warmLighting
            deskControl
              .frame(width: layout.deskFrame.width, height: layout.deskFrame.height)
              .position(x: layout.deskFrame.midX, y: layout.deskFrame.midY)

            ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
              GarageBayStation(
                station: station,
                accent: accent(for: station, index: index),
                icon: bayIcon(for: station, index: index),
                date: date,
                motion: motion,
                isDimmed: focusedAgentID != nil && focusedAgentID != station.id || !gate.stationIsActionable(station),
                isActionable: gate.stationIsActionable(station),
                isHighlighted: gate.stationIsHighlighted(station),
                differentiateWithoutColor: differentiateWithoutColor
              ) {
                focusedAgentID = station.id
                stationPresented = station
              }
              .frame(width: layout.bays[index].frame.width, height: layout.bays[index].frame.height)
              .position(layout.bays[index].center)
            }
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .bottomLeading) {
          Label("Swipe to explore · Tap a station to assign or review", systemImage: "hand.draw.fill")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.72))
            .padding(9)
            .background(.black.opacity(0.28), in: Capsule())
            .padding(12)
        }
        .overlay {
          RoundedRectangle(cornerRadius: 18)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .onChange(of: selectedStation) { _, next in
          if next == nil { focusedAgentID = nil }
        }
      }
      .frame(width: canvasWidth, height: GarageBayLayout.canvasHeight)
    }
    .scrollIndicators(.visible)
    .frame(height: 650)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder Garage live workforce map")
    .accessibilityHint("Swipe horizontally to explore the full garage")
  }

  private var garageShell: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.13, green: 0.15, blue: 0.19), Color(red: 0.055, green: 0.065, blue: 0.085)],
        startPoint: .top,
        endPoint: .bottom
      )
      VStack(spacing: 0) {
        Rectangle().fill(Color.clear).frame(height: 0)
        Spacer()
        Rectangle()
          .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.15), Color(red: 0.035, green: 0.045, blue: 0.06)], startPoint: .top, endPoint: .bottom))
          .frame(height: 112)
      }
      RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 90, endRadius: 310)
    }
  }

  private var ceilingBeams: some View {
    VStack(spacing: 27) {
      Rectangle().fill(Color(red: 0.16, green: 0.12, blue: 0.09)).frame(height: 7)
      Rectangle().fill(Color(red: 0.12, green: 0.09, blue: 0.07)).frame(height: 5)
      Spacer()
    }
    .opacity(0.8)
  }

  private var warmLighting: some View {
    HStack(spacing: 0) {
      ForEach(0..<4, id: \.self) { _ in
        VStack(spacing: 0) {
          Capsule().fill(Color(red: 0.9, green: 0.8, blue: 0.65)).frame(width: 22, height: 6)
          Circle().fill(Color.orange.opacity(0.14)).frame(width: 125, height: 80).blur(radius: 18)
        }
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
    .padding(.top, 12)
  }

  private var founderDesk: some View {
    VStack(spacing: 0) {
      Spacer()
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(red: 0.035, green: 0.055, blue: 0.075))
          .frame(width: 150, height: 86)
          .overlay {
            RoundedRectangle(cornerRadius: 5)
              .fill(Color(red: 0.06, green: 0.11, blue: 0.15))
              .padding(5)
              .overlay(alignment: .topLeading) {
                Capsule().fill(SoloTheme.cyan).frame(width: 31, height: 3).padding(13)
              }
          }
        VStack {
          Spacer().frame(height: 89)
          Rectangle().fill(Color(red: 0.13, green: 0.15, blue: 0.18)).frame(width: 18, height: 16)
          Capsule().fill(Color(red: 0.18, green: 0.21, blue: 0.25)).frame(width: 68, height: 6)
        }
      }
      GarageDeskShape()
        .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.28, blue: 0.17), Color(red: 0.20, green: 0.13, blue: 0.08)], startPoint: .top, endPoint: .bottom))
        .frame(height: 43)
        .padding(.horizontal, 42)
        .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
    }
    .padding(.bottom, 18)
  }

  private var deskControl: some View {
    Button { deskPresented = true } label: {
      founderDesk
        .opacity(1)
        .overlay {
          RoundedRectangle(cornerRadius: 18)
            .stroke(SoloTheme.cyan, lineWidth: gate.primary == .desk ? 2 : 1)
            .shadow(color: SoloTheme.cyan.opacity(gate.primary == .desk ? 0.75 : 0), radius: 12)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Founder desk")
    .accessibilityHint("Opens sprint controls")
  }

  private var sprintControls: some View {
    HStack(spacing: 10) {
      Label(store?.sprintPhase.title ?? "Founder Event", systemImage: store?.sprintPhase.symbol ?? "circle")
        .font(.caption.weight(.bold))
        .foregroundStyle(SoloTheme.cyan)
      Spacer()
      Label("\(attentionRemaining)/\(attentionMaximum)", systemImage: "eye.fill")
        .font(.caption.weight(.bold))
        .foregroundStyle(SoloTheme.amber)
      Button("Desk", systemImage: "desktopcomputer") { deskPresented = true }
        .buttonStyle(.bordered)
    }
    .padding(10)
    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
  }

  private var founderMetrics: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("FOUNDER METRICS")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.bottom, 7)
      ForEach(Array(metrics.enumerated()), id: \.element.label) { index, metric in
        GarageMetricRow(metric: metric)
        if index < metrics.count - 1 {
          Divider().overlay(Color.white.opacity(0.08))
        }
      }
    }
    .padding(12)
    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
  }

  private var metrics: [GarageMetric] {
    [
      GarageMetric(label: "Capital", value: stats.capital.formatted(.currency(code: "USD").precision(.fractionLength(0))), symbol: "dollarsign.circle.fill", color: SoloTheme.mint),
      GarageMetric(label: "Runway", value: "\(stats.runway)d", symbol: "calendar", color: .primary),
      GarageMetric(label: "Attention", value: "\(attentionRemaining)/\(attentionMaximum)", symbol: "eye.fill", color: SoloTheme.amber),
      GarageMetric(label: "Revenue", value: stats.revenue.formatted(.currency(code: "USD").precision(.fractionLength(0))), symbol: "chart.line.uptrend.xyaxis", color: SoloTheme.cyan),
      GarageMetric(label: "Momentum", value: "\(stats.momentum)", symbol: "bolt.fill", color: SoloTheme.amber),
      GarageMetric(label: "Trust", value: "\(stats.trust)", symbol: "checkmark.shield.fill", color: SoloTheme.mint),
      GarageMetric(label: "Energy", value: "\(stats.energy)", symbol: "battery.75percent", color: SoloTheme.cyan),
      GarageMetric(label: "Track", value: "\(stats.trackRecord)", symbol: "chart.bar.fill", color: .primary)
    ]
  }

  private func accent(for station: AgentStationViewModel, index: Int) -> Color {
    switch station.agentID.lowercased() {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: accentColor(for: index)
    }
  }

  private func bayIcon(for station: AgentStationViewModel, index: Int) -> String {
    switch station.agentID.lowercased() {
    case "aurora": "waveform.path.ecg"
    case "stacks": "server.rack"
    case "brio": "megaphone.fill"
    default: GarageBayPresentation.icon(for: index)
    }
  }

  private func accentColor(for index: Int) -> Color {
    switch GarageBayPresentation.accentToken(for: index) {
    case "amber": SoloTheme.amber
    case "coral": SoloTheme.coral
    case "mint": SoloTheme.mint
    case "purple": SoloTheme.purple
    default: SoloTheme.cyan
    }
  }
}

private struct GarageBayStation: View {
  var station: AgentStationViewModel
  var accent: Color
  var icon: String
  var date: Date
  var motion: GarageMotionPolicy
  var isDimmed: Bool
  var isActionable: Bool
  var isHighlighted: Bool
  var differentiateWithoutColor: Bool
  var action: () -> Void

  private var motionOffset: CGFloat {
    guard motion == .active else { return 0 }
    let phase = GaragePhase.offset(identity: station.id, index: 0) * .pi * 2
    return CGFloat(sin(date.timeIntervalSinceReferenceDate * 1.8 + phase) * 2.5)
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        ZStack {
          Circle().fill(accent.opacity(0.22)).frame(width: 166, height: 142).blur(radius: 21)
          workstation
        }
        GarageStationTag(station: station, accent: accent, differentiateWithoutColor: differentiateWithoutColor)
      }
      .offset(y: motionOffset)
      .opacity(isDimmed ? 0.38 : 1)
      .overlay { if isHighlighted { RoundedRectangle(cornerRadius: 16).stroke(SoloTheme.cyan, lineWidth: 2).shadow(color: SoloTheme.cyan.opacity(0.7), radius: 10) } }
      .animation(.smooth, value: isDimmed)
    }
    .buttonStyle(.plain)
    .disabled(!isActionable)
    .accessibilityLabel("\(station.name), level \(station.progression.level), \(station.progression.stressBand.label) stress")
    .accessibilityValue(station.accessibilityValue)
    .accessibilityHint("Opens read-only agent details")
  }

  private var workstation: some View {
    ZStack(alignment: .bottom) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(red: 0.12, green: 0.14, blue: 0.17))
        .frame(width: 142, height: 14)
        .offset(y: 28)
      HStack(alignment: .bottom, spacing: 8) {
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.black.opacity(0.72))
          .frame(width: 68, height: 50)
          .overlay {
            RoundedRectangle(cornerRadius: 3)
              .fill(accent.opacity(station.semanticState == .idle ? 0.20 : 0.42))
              .padding(4)
              .overlay {
                Image(systemName: icon).font(.caption).foregroundStyle(accent)
              }
          }
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.black.opacity(0.68))
          .frame(width: 43, height: 39)
          .overlay { Image(systemName: "chart.line.uptrend.xyaxis").font(.caption2).foregroundStyle(accent.opacity(0.85)) }
      }
      .offset(y: -3)
      ZStack {
        Circle().stroke(accent.opacity(0.75), lineWidth: 2).frame(width: 60, height: 60)
        Circle().fill(accent).frame(width: 42, height: 42)
        Text(station.initials).font(.headline.weight(.heavy)).foregroundStyle(Color.black.opacity(0.75))
      }
      .offset(y: -17)
    }
  }
}

private struct GarageDeskSheet: View {
  var store: GameStore?
  var progression: FounderProgressionStore?
  var presentation: PresentationCoordinator?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let store, store.sprintPhase == .founderEvent, let dilemma = store.activeDilemma {
            FounderDilemmaCard(dilemma: dilemma, selectedChoiceID: store.selectedDilemmaChoiceID, onSelect: store.selectDilemmaChoice)
          } else if let store, let dilemma = store.activeDilemma, let choice = store.selectedDilemmaChoice {
            ResolvedDilemmaSummary(dilemma: dilemma, choice: choice)
          }
          if let store {
            if let objective = store.currentObjective { SprintObjectiveCard(objective: objective, progress: store.objectiveProgressText) }
            Picker("Sprint intent", selection: Binding(get: { store.intent }, set: { store.setIntent($0) })) {
              ForEach(SprintIntent.allCases) { Label($0.name, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(store.tasks.contains { $0.assignedAgentID != nil })
            Button("Commit Sprint", systemImage: "bolt.fill") {
              if let progression, let presentation { presentation.commit(in: store, progression: progression) }
            }
            .buttonStyle(SoloPrimaryButtonStyle())
            .disabled(!store.canCommitSprint)
            if let blocker = store.commitBlockerMessage { Text(blocker).font(.caption).foregroundStyle(.secondary) }
          }
        }
        .padding(16)
      }
      .navigationTitle("Founder Desk")
    }
  }
}

private struct GarageStationSheet: View {
  var station: AgentStationViewModel
  var store: GameStore?
  var presentation: PresentationCoordinator?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text(station.name).font(.title2.bold())
          if let store, let current = store.tasks.first(where: { $0.assignedAgentID == station.agentID }) {
            Label("Currently assigned: \(current.title)", systemImage: "person.badge.clock")
              .font(.subheadline.weight(.semibold)).foregroundStyle(SoloTheme.amber)
          }
          if let store, let task = task(for: store) {
            TaskCommandCard(task: task, agents: store.agents, founderStats: store.stats) { agentID in
              presentation?.assign(agentID: agentID, to: task.id, in: store)
            } onReview: {
              presentation?.review(taskID: task.id, in: store)
            } onResolution: { choice in
              store.resolveReviewedTask(taskID: task.id, choice: choice)
            }
            if store.sprintPhase != .reviewAndResolve, !store.taskBacklog.isEmpty {
              Menu("Swap draft from backlog", systemImage: "arrow.left.arrow.right") {
                ForEach(store.taskBacklog) { candidate in
                  Button(candidate.title) { _ = store.swapDraftTask(activeTaskID: task.id, backlogTaskID: candidate.id) }
                }
              }
              .disabled(store.tasks.contains { $0.assignedAgentID != nil })
            }
          } else {
            Text("No task is available for this station in the current phase.").foregroundStyle(.secondary)
          }
        }
        .padding(16)
      }
      .navigationTitle("Agent Station")
    }
  }

  private func task(for store: GameStore) -> SoloTask? {
    if store.sprintPhase == .reviewAndResolve {
      return store.tasks.first { $0.assignedAgentID == station.agentID && $0.result != nil }
    }
    return store.tasks.first { $0.assignedAgentID == station.agentID } ?? store.tasks.first { $0.assignedAgentID == nil }
  }
}

struct GarageStationTag: View {
  var station: AgentStationViewModel
  var accent: Color
  var differentiateWithoutColor: Bool

  var body: some View {
    VStack(spacing: 3) {
      HStack(spacing: 6) {
        Circle().fill(accent).frame(width: 7, height: 7)
        Text(station.name.uppercased()).font(.caption2.weight(.bold))
        Text("LV \(station.progression.level)").font(.caption2.monospaced())
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.black.opacity(0.72), in: Capsule())
      HStack(spacing: 4) {
        if differentiateWithoutColor { Image(systemName: stressSymbol) }
        Text(station.progression.stressBand.label.uppercased())
      }
      .font(.caption2.weight(.bold))
      .foregroundStyle(stressColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(.black.opacity(0.56), in: Capsule())
    }
  }

  private var stressColor: Color {
    switch station.progression.stressBand {
    case .focused: SoloTheme.mint
    case .stable: SoloTheme.cyan
    case .pressured: SoloTheme.amber
    case .overloaded: Color.orange
    case .critical: SoloTheme.coral
    }
  }

  private var stressSymbol: String {
    switch station.progression.stressBand {
    case .focused: "checkmark"
    case .stable: "circle"
    case .pressured: "exclamationmark.circle"
    case .overloaded, .critical: "exclamationmark.triangle"
    }
  }
}

private struct GarageMetric: Identifiable {
  var label: String
  var value: String
  var symbol: String
  var color: Color

  var id: String { label }
}

private struct GarageMetricRow: View {
  var metric: GarageMetric

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: metric.symbol)
        .frame(width: 18)
        .foregroundStyle(metric.color)
      Text(metric.label)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      Text(metric.value)
        .font(.subheadline.weight(.bold).monospacedDigit())
        .foregroundStyle(metric.color)
        .contentTransition(.numericText())
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
  }
}

private struct GarageDeskShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + 8, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
