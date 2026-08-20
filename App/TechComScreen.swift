import SwiftUI

struct TechComScreen: View {
  var store: GameStore
  @State private var metric: TechComRankingMetric = .trackRecord

  private var snapshot: TechComSnapshot {
    TechComSnapshot(
      founderName: store.founderName,
      venture: store.venture,
      sprint: store.sprint,
      stats: store.stats,
      agents: store.agents,
      tasks: store.tasks,
      dilemmaChoice: store.selectedDilemmaChoice
    )
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          TechComMasthead(
            venture: store.venture,
            sprint: store.sprint,
            marketPosition: playerMarketPosition
          )

          TechComCompanyFeed(headlines: ownCompanyHeadlines)

          TechComDecisionFeed(store: store)

          TechComTrendSignal(headlines: trendHeadlines)

          TechComRivalBoard(store: store)

          TechComTalentBoard(store: store)

          TechComRankingBoard(
            metric: $metric,
            snapshot: snapshot,
            rivals: store.techComRivals
          )

          TechComMarketShareBoard(standings: store.rivalStandings)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("techcom-build-30-2")
      }
      .navigationTitle("Tech.com")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var ownCompanyHeadlines: [TechComHeadline] {
    store.techComHeadlines.filter { $0.category == .ownCompany }
  }

  private var trendHeadlines: [TechComHeadline] {
    store.techComHeadlines.filter { $0.category == .trend }
  }

  private var playerMarketPosition: Int? {
    guard let index = store.rivalStandings.firstIndex(where: \.isPlayer) else { return nil }
    return index + 1
  }
}
