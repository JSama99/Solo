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

          TechComRivalMovesFeed(headlines: rivalHeadlines)

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

  private var rivalHeadlines: [TechComHeadline] {
    store.techComHeadlines.filter { $0.category == .rival }
  }

  private var playerMarketPosition: Int? {
    guard let index = store.rivalStandings.firstIndex(where: \.isPlayer) else { return nil }
    return index + 1
  }
}

private struct TechComRivalMovesFeed: View {
  var headlines: [TechComHeadline]

  var body: some View {
    TechComEditorialSurface(
      eyebrow: "COMPETITIVE INTELLIGENCE",
      title: "Rival Moves",
      symbol: "bolt.fill",
      accent: SoloTheme.amber
    ) {
      if headlines.isEmpty {
        Text("No rival has made a notable move yet — check back after your next sprint.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(headlines.enumerated()), id: \.element.id) { index, headline in
            TechComStoryRow(headline: headline, isLead: index == 0)
            if headline.id != headlines.last?.id {
              Divider().opacity(0.55)
            }
          }
        }
      }
    }
  }
}
