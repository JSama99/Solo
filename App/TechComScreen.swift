import SwiftUI

struct TechComScreen: View {
  var store: GameStore
  @State private var metric: TechComRankingMetric = .trackRecord

  private var snapshot: TechComSnapshot {
    TechComSnapshot(founderName: store.founderName, venture: store.venture, sprint: store.sprint, stats: store.stats, agents: store.agents, tasks: store.tasks, dilemmaChoice: store.selectedDilemmaChoice)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Tech.com").font(.largeTitle.bold())
          Text("The signal behind the startup noise.").foregroundStyle(.secondary)
          section("Your Company", symbol: "building.2.fill") {
            headlines(category: .ownCompany, empty: "Your company moves will appear here as the sprint unfolds.")
          }
          section("Trends", symbol: "waveform.path.ecg") {
            headlines(category: .trend, empty: "Industry watch is gathering signal.")
          }
          section("Rivals", symbol: "person.3.fill") {
            ForEach(store.techComRivals) { rival in
              rivalRow(rival)
            }
          }
          section("Talent Board", symbol: "person.crop.circle.badge.plus") {
            talentBoard
          }
          section("Rankings", symbol: "list.number") {
            Picker("Ranking metric", selection: $metric) {
              ForEach(TechComRankingMetric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(Array(TechComEngine.rankings(snapshot: snapshot, rivals: store.techComRivals, metric: metric).enumerated()), id: \.element.id) { offset, entry in
              HStack { Text("\(offset + 1)").foregroundStyle(.secondary).frame(width: 20); Text(entry.name).fontWeight(entry.isPlayer ? .bold : .regular); Spacer(); Text(value(entry.value)).foregroundStyle(entry.isPlayer ? SoloTheme.cyan : .primary) }
                .font(.subheadline)
            }
          }
          section("Market Share", symbol: "chart.pie.fill") {
            ForEach(store.rivalStandings) { standing in
              HStack {
                Text(standing.name).fontWeight(standing.isPlayer ? .bold : .regular)
                Spacer()
                Text(standing.archetype?.label ?? "Your company").foregroundStyle(.secondary)
                Text(standing.marketShare, format: .percent.precision(.fractionLength(0))).foregroundStyle(standing.isPlayer ? SoloTheme.cyan : .primary)
              }
              .font(.caption)
            }
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Tech.com")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol).font(.headline).foregroundStyle(SoloTheme.cyan)
      content()
    }
    .soloCard()
  }

  @ViewBuilder private func headlines(category: TechComHeadlineCategory, empty: String) -> some View {
    let items = store.techComHeadlines.filter { $0.category == category }
    if items.isEmpty { Text(empty).font(.caption).foregroundStyle(.secondary) }
    else { ForEach(items) { item in Text(item.text).font(.subheadline).accessibilityLabel(item.text); if item.id != items.last?.id { Divider() } } }
  }

  private func rivalRow(_ rival: TechComRival) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack { Text(rival.name).font(.subheadline.weight(.bold)); Spacer(); Text(rival.verificationState.label).font(.caption.weight(.semibold)).foregroundStyle(rival.isVerified ? SoloTheme.mint : SoloTheme.amber) }
      Text("Claimed: record \(rival.claimedTrackRecord) • $\(rival.claimedRevenue) • momentum \(rival.claimedMomentum)").font(.caption).foregroundStyle(SoloTheme.cyan)
      if rival.isVerified { VStack(alignment: .leading, spacing: 3) { Label("Verified: record \(rival.actualTrackRecord) • $\(rival.actualRevenue) • momentum \(rival.actualMomentum)", systemImage: "checkmark.seal.fill").foregroundStyle(SoloTheme.mint); if rival.overclaimAmount > 0 { Text("Track-record overclaim +\(rival.overclaimAmount)").foregroundStyle(SoloTheme.amber) } }.font(.caption.weight(.semibold)) }
      else { Button("Verify claim • 1 Attention", systemImage: "eye.fill") { _ = store.verifyTechComRival(id: rival.id) }.buttonStyle(.bordered).tint(SoloTheme.purple).disabled(store.attentionRemaining == 0).accessibilityHint("Reveals all claimed rival metrics") }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder private var talentBoard: some View {
    if let gate = store.talentBoardGateMessage {
      Text(gate).font(.caption).foregroundStyle(.secondary)
    } else {
      Text("Hire your \(store.nextTalentSlot == 4 ? "fourth" : "fifth") AI teammate. Different model families reduce shared exposure.")
        .font(.caption).foregroundStyle(.secondary)
      ForEach(store.talentBoardCandidates) { candidate in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Label(candidate.name, systemImage: candidate.role.symbol).font(.subheadline.weight(.bold))
            Spacer()
            Text("$\(candidate.price)").font(.caption.weight(.bold)).foregroundStyle(SoloTheme.cyan)
          }
          Text("\(candidate.role.rawValue) • \(candidate.modelFamily)").font(.caption).foregroundStyle(.secondary)
          Text(candidate.pitch).font(.caption)
          Button("Hire \(candidate.name)", systemImage: "person.badge.plus") { store.hire(candidate) }
            .buttonStyle(.borderedProminent).tint(SoloTheme.purple).disabled(store.stats.capital < candidate.price)
        }
        .padding(.vertical, 4)
        if candidate.id != store.talentBoardCandidates.last?.id { Divider() }
      }
      if store.agents.count >= 4 {
        Button("Refresh listings • $\(TalentBoard.refreshCost)", systemImage: "arrow.clockwise") { store.refreshTalentBoard() }
          .buttonStyle(.bordered).disabled(store.stats.capital < TalentBoard.refreshCost)
      }
    }
  }

  private func value(_ value: Int) -> String { metric == .revenue ? "$\(value)" : "\(value)" }
}
