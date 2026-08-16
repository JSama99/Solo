import SwiftUI

/// First-person founder computer. It translates existing game state into the
/// playable garage surface without owning any simulation state.
struct FounderComputerScreen: View {
  var store: GameStore
  var presentation: PresentationCoordinator
  var stations: [AgentStationViewModel]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var selectedAgentID = "aurora"
  @State private var evidenceExpanded = false

  private var selectedStation: AgentStationViewModel {
    stations.first { $0.agentID == selectedAgentID } ?? stations.first ?? AgentStationViewModel(agentID: "aurora", name: "Aurora", initials: "A", role: .research, modelFamily: "", trust: 0, taskTitle: nil, semanticState: .idle, mood: "Ready")
  }

  private var selectedTask: SoloTask? {
    store.tasks.first { $0.assignedAgentID == selectedStation.agentID } ?? store.tasks.first { $0.assignedAgentID == nil }
  }

  var body: some View {
    VStack(spacing: 12) {
      CompanyHUD(stats: store.stats, sprint: store.sprint)
      monitor
      EvidenceDrawer(entries: store.evidence, isExpanded: $evidenceExpanded)
      AgentCommandDeck(station: selectedStation, task: selectedTask, store: store, presentation: presentation)
      FounderReviewStrip(store: store, presentation: presentation)
    }
    .padding(12)
    .frame(maxWidth: .infinity)
    .background(Color(red: 0.012, green: 0.022, blue: 0.038))
    .animation(reduceMotion ? nil : .smooth, value: selectedAgentID)
  }

  private var monitor: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 26).fill(.black).overlay { RoundedRectangle(cornerRadius: 26).stroke(.cyan.opacity(0.28), lineWidth: 2) }
      LinearGradient(colors: [.black, Color(red: 0.02, green: 0.05, blue: 0.09)], startPoint: .top, endPoint: .bottom).clipShape(RoundedRectangle(cornerRadius: 22)).padding(7)
      HStack(spacing: 5) {
        ForEach(stations) { station in
          AgentWorkspaceCard(station: station, isSelected: station.agentID == selectedAgentID, reduceMotion: reduceMotion) {
            selectedAgentID = station.agentID
          }
        }
      }
      .padding(11)
    }
    .frame(height: 360)
    .overlay(alignment: .bottom) { Capsule().fill(.black.opacity(0.75)).frame(width: 240, height: 10).offset(y: 13) }
  }
}

private struct CompanyHUD: View {
  var stats: FounderStats
  var sprint: Int
  var body: some View {
    HStack(spacing: 8) {
      Text("SOLO").font(.title3.weight(.black))
      metric("RUNWAY", "\(stats.runway)d", "dollarsign.circle", .green)
      metric("ENERGY", "\(stats.energy)%", "bolt.fill", .cyan)
      metric("TRUST", "\(stats.trust)%", "heart", .purple)
      metric("SPRINT", String(format: "%02d", sprint), "rocket.fill", .orange)
    }
    .padding(10).background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 18))
  }
  private func metric(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
    VStack(alignment: .leading, spacing: 1) { Label(title, systemImage: symbol).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary); Text(value).font(.caption.weight(.heavy)).foregroundStyle(color) }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct AgentWorkspaceCard: View {
  var station: AgentStationViewModel
  var isSelected: Bool
  var reduceMotion: Bool
  var action: () -> Void
  private var color: Color { station.agentID == "aurora" ? .purple : station.agentID == "stacks" ? .cyan : .orange }
  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        Label(station.name.uppercased(), systemImage: station.role.symbol).font(isSelected ? .headline.weight(.black) : .caption.weight(.bold)).lineLimit(1)
        ZStack {
          Circle().fill(color.opacity(0.16)).frame(width: isSelected ? 120 : 68, height: isSelected ? 120 : 68)
          Circle().fill(color.opacity(0.86)).frame(width: isSelected ? 70 : 42, height: isSelected ? 70 : 42)
          Text(station.initials.prefix(1)).font(isSelected ? .largeTitle.weight(.black) : .title3.weight(.black)).foregroundStyle(.black.opacity(0.7))
        }
        Text(stateTitle).font(.caption2.weight(.bold)).foregroundStyle(color).lineLimit(2).multilineTextAlignment(.center)
        Spacer(minLength: 0)
        if isSelected { visualSignal }
      }
      .padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(color.opacity(isSelected ? 0.15 : 0.05), in: RoundedRectangle(cornerRadius: 16))
      .overlay { RoundedRectangle(cornerRadius: 16).stroke(color.opacity(isSelected ? 0.95 : 0.28), lineWidth: isSelected ? 2 : 1) }
    }
    .buttonStyle(.plain).accessibilityLabel("\(station.name), \(stateTitle)")
  }
  private var stateTitle: String { switch station.semanticState { case .idle: "SEATED IDLE"; case .working: station.agentID == "aurora" ? "RESEARCHING" : station.agentID == "stacks" ? "BUILDING" : "TESTING"; case .awaitingReview: "WAITING FOR REVIEW"; case .verified: "VERIFIED"; case .drifting: "DRIFTING"; case .overloaded: "OVERLOADED" } }
  private var visualSignal: some View { Group { if station.agentID == "aurora" { Image(systemName: "point.3.connected.trianglepath.dotted") } else if station.agentID == "stacks" { Image(systemName: "cube.transparent") } else { Image(systemName: "chart.line.uptrend.xyaxis") } }.font(.title2).foregroundStyle(color).opacity(reduceMotion ? 0.72 : 1) }
}

private struct EvidenceDrawer: View {
  var entries: [EvidenceEntry]
  @Binding var isExpanded: Bool
  var body: some View { VStack(spacing: 8) { Button { isExpanded.toggle() } label: { HStack { Label("EVIDENCE", systemImage: "doc.text").font(.headline.weight(.bold)); Spacer(); Text("\(entries.count)").monospacedDigit(); Image(systemName: isExpanded ? "chevron.up" : "chevron.down") }.padding(15).frame(maxWidth: .infinity) }.buttonStyle(.plain); if isExpanded { ForEach(entries.suffix(3).reversed()) { entry in HStack { VStack(alignment: .leading) { Text(entry.task).font(.caption.weight(.semibold)); Text("\(entry.agent) • Sprint \(entry.sprint)").font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(entry.verificationState.label).font(.caption2.weight(.bold)).foregroundStyle(entry.evidenceVerified ? .green : .orange) }.padding(.horizontal, 15) } } }.padding(.vertical, 3).background(Color(red: 0.02, green: 0.08, blue: 0.12), in: RoundedRectangle(cornerRadius: 16)) }
}

private struct AgentCommandDeck: View {
  var station: AgentStationViewModel; var task: SoloTask?; var store: GameStore; var presentation: PresentationCoordinator
  var body: some View { HStack(spacing: 9) { VStack(alignment: .leading) { Text(station.name).font(.headline); Text("LV \(station.progression.level) • \(station.semanticState.label)").font(.caption).foregroundStyle(.secondary); Text(task?.title ?? "No assignment proposed").font(.caption.weight(.semibold)).lineLimit(2) }.frame(maxWidth: .infinity, alignment: .leading); action("ASSIGN", "play.fill") { if let task { presentation.assign(agentID: station.agentID, to: task.id, in: store) } }.disabled(task == nil || store.sprintPhase == .founderEvent); action("REVIEW", "checklist") { if let task { presentation.review(taskID: task.id, in: store) } }.disabled(task?.result == nil || store.attentionRemaining == 0); action("REST", "moon.zzz") {}.disabled(true) }.padding(10).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)) }
  private func action(_ label: String, _ symbol: String, perform: @escaping () -> Void) -> some View { Button(action: perform) { Label(label, systemImage: symbol).labelStyle(.iconOnly).frame(width: 48, height: 58).background(.tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain).accessibilityLabel(label) }
}

private struct FounderReviewStrip: View {
  var store: GameStore; var presentation: PresentationCoordinator
  var body: some View { HStack { Image(systemName: "crown.fill").foregroundStyle(.yellow).font(.title2); VStack(alignment: .leading) { Text("FOUNDER REVIEW").font(.caption.weight(.black)).foregroundStyle(.yellow); Text(store.activeDilemma?.setup ?? "Review verified evidence before committing.").font(.caption).lineLimit(2) }; Spacer(); Button("Approve", systemImage: "checkmark") { if let task = store.tasks.first(where: { $0.result != nil && !$0.isReviewed }) { presentation.review(taskID: task.id, in: store) } }.buttonStyle(.borderedProminent).tint(.yellow) }.padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18)) }
}
