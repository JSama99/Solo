import Foundation

struct TechComRivalMetric: Equatable, Identifiable {
  var id: String { title }
  var title: String
  var claimedValue: Int
  var actualValue: Int?
  var isCurrency: Bool
}

enum TechComCompanyAccent: String, Equatable {
  case solo
  case incumbent
  case upstart
  case hypeMachine
  case quietBuilder
  case copycat
  case neutral
}

struct TechComCompanyIdentity: Equatable {
  var monogram: String
  var accent: TechComCompanyAccent
}

enum TechComPresentation {
  static func rivalMetrics(for rival: TechComRival) -> [TechComRivalMetric] {
    [
      TechComRivalMetric(
        title: "Track Record",
        claimedValue: rival.claimedTrackRecord,
        actualValue: rival.isVerified ? rival.actualTrackRecord : nil,
        isCurrency: false
      ),
      TechComRivalMetric(
        title: "Revenue",
        claimedValue: rival.claimedRevenue,
        actualValue: rival.isVerified ? rival.actualRevenue : nil,
        isCurrency: true
      ),
      TechComRivalMetric(
        title: "Momentum",
        claimedValue: rival.claimedMomentum,
        actualValue: rival.isVerified ? rival.actualMomentum : nil,
        isCurrency: false
      )
    ]
  }

  static func archetype(for rivalID: String) -> RivalArchetype? {
    ContentLibrary.rivalSimulationCompanies.first { $0.id == rivalID }?.archetype
  }

  static func monogram(for name: String) -> String {
    let words = name.split(separator: " ")
    return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
  }

  static func companyIdentity(
    id: String,
    name: String,
    archetype: RivalArchetype?,
    isPlayer: Bool
  ) -> TechComCompanyIdentity {
    if isPlayer || id == "solo" {
      return TechComCompanyIdentity(monogram: "SO", accent: .solo)
    }
    let accent: TechComCompanyAccent = switch archetype ?? self.archetype(for: id) {
    case .incumbent: .incumbent
    case .upstart: .upstart
    case .hypeMachine: .hypeMachine
    case .quietBuilder: .quietBuilder
    case .copycat: .copycat
    case nil: .neutral
    }
    return TechComCompanyIdentity(monogram: monogram(for: name), accent: accent)
  }

  static func marketBarFraction(_ marketShare: Double) -> Double {
    min(1, max(0, marketShare))
  }

  static func gapToNextRank(entries: [TechComRankingEntry], playerIndex: Int) -> Int? {
    guard playerIndex > 0, playerIndex < entries.count else { return nil }
    return max(0, entries[playerIndex - 1].value - entries[playerIndex].value)
  }
}
