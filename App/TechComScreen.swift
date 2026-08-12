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
      HStack { Label("Claimed \(rival.claimedTrackRecord)", systemImage: "doc.text.magnifyingglass").foregroundStyle(SoloTheme.cyan); Spacer(); Text("Momentum \(rival.claimedMomentum)").foregroundStyle(.secondary) }.font(.caption)
      if rival.isVerified { HStack { Label("Verified actual \(rival.actualTrackRecord)", systemImage: "checkmark.seal.fill").foregroundStyle(SoloTheme.mint); if rival.overclaimAmount > 0 { Spacer(); Text("Overclaim +\(rival.overclaimAmount)").foregroundStyle(SoloTheme.amber) } }.font(.caption.weight(.semibold)) }
      else { Button("Verify claim • 1 Attention", systemImage: "eye.fill") { _ = store.verifyTechComRival(id: rival.id) }.buttonStyle(.bordered).tint(SoloTheme.purple).disabled(store.attentionRemaining == 0).accessibilityHint("Reveals the rival’s actual track record") }
    }
    .padding(.vertical, 4)
  }

  private func value(_ value: Int) -> String { metric == .revenue ? "$\(value)" : "\(value)" }
}
