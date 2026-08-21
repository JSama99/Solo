import Foundation

/// Read-only UI data derived from the canonical game state for the Venture screen.
/// It is never persisted and contains no simulation decisions.
struct VentureScreenPresentation: Equatable {
  struct SprintSegment: Identifiable, Equatable {
    enum State: Equatable {
      case completed
      case current
      case upcoming
    }

    var id: Int { number }
    var number: Int
    var state: State
  }

  struct Objective: Equatable {
    var title: String
    var detail: String
    var progress: Double
    var percentage: Int
    var reward: String
    var isComplete: Bool
  }

  struct Pressure: Equatable {
    var eraName: String
    var detail: String
    var runwayCost: Int
    var energyCost: Int
    var milestoneStatus: String
  }

  struct Consequence: Identifiable, Equatable {
    enum Kind: Equatable {
      case companyStandard
      case activeObligation
    }

    var id: String
    var title: String
    var detail: String
    var status: String
    var symbol: String
    var kind: Kind
  }

  struct Upgrade: Identifiable, Equatable {
    var id: String
    var name: String
    var symbol: String
  }

  struct Doctrine: Equatable {
    var name: String
    var summary: String
    var consequenceStatement: String
  }

  var venture: Int
  var sprint: Int
  var totalSprints: Int
  var completedSprints: Int
  var sprintSegments: [SprintSegment]
  var trackRecord: Int
  var evidence: Int
  var chapterNumber: Int
  var chapterTitle: String
  var chapterDetail: String
  var chapterProgressLabel: String
  var thesisName: String
  var thesisDetail: String
  var objective: Objective
  var pressure: Pressure
  var consequences: [Consequence]
  var upgrades: [Upgrade]
  var doctrine: Doctrine
  var careerObjective: String

  @MainActor
  init(store: GameStore) {
    let objective = store.ventureObjective ?? VentureObjective.selected(for: store.venture)
    self.init(
      venture: store.venture,
      sprint: store.sprint,
      totalSprints: GameStore.sprintsPerVentureCount,
      trackRecord: store.stats.trackRecord,
      evidence: store.evidence.count,
      chapter: store.chapter,
      era: VentureEra.era(for: store.venture),
      thesisName: store.thesis.name,
      thesisDetail: store.thesis.summary,
      objectiveTitle: objective.title,
      objectiveDetail: objective.framing,
      objectiveProgress: store.ventureObjectiveProgress,
      objectiveReward: objective.rewardLabel,
      flags: store.companyFlags,
      obligations: store.activeObligations,
      upgrades: store.unlockedGarageUpgrades,
      doctrineName: store.doctrine.name,
      doctrineSummary: store.doctrine.summary,
      founderName: store.founderName,
      careerMode: store.careerMode
    )
  }

  init(
    venture: Int,
    sprint: Int,
    totalSprints: Int,
    trackRecord: Int,
    evidence: Int,
    chapter: VentureChapter,
    era: VentureEra,
    thesisName: String,
    thesisDetail: String,
    objectiveTitle: String,
    objectiveDetail: String,
    objectiveProgress: Double,
    objectiveReward: String,
    flags: Set<CompanyFlag>,
    obligations: [CompanyObligation],
    upgrades: [GarageUpgrade],
    doctrineName: String,
    doctrineSummary: String,
    founderName: String,
    careerMode: CareerMode
  ) {
    let clampedSprint = min(max(1, sprint), max(1, totalSprints))
    let clampedProgress = min(max(0, objectiveProgress), 1)
    self.venture = venture
    self.sprint = clampedSprint
    self.totalSprints = totalSprints
    self.completedSprints = max(0, clampedSprint - 1)
    self.sprintSegments = Self.sprintSegments(currentSprint: clampedSprint, total: totalSprints)
    self.trackRecord = trackRecord
    self.evidence = evidence
    self.chapterNumber = chapter.rawValue
    self.chapterTitle = chapter.name
    self.chapterDetail = chapter.subtitle
    self.chapterProgressLabel = Self.chapterProgressLabel(chapter: chapter, sprint: clampedSprint)
    self.thesisName = thesisName
    self.thesisDetail = thesisDetail
    self.objective = Objective(
      title: objectiveTitle,
      detail: objectiveDetail,
      progress: clampedProgress,
      percentage: Int((clampedProgress * 100).rounded()),
      reward: objectiveReward,
      isComplete: clampedProgress >= 1
    )
    self.pressure = Pressure(
      eraName: era.name,
      detail: era.newForce,
      runwayCost: era.runwayBurnPerSprint,
      energyCost: era.energyCostPerSprint,
      milestoneStatus: venture >= era.milestoneVenture
        ? "Milestone active: Venture \(era.milestoneVenture)"
        : "Milestone ahead: Venture \(era.milestoneVenture)"
    )
    let flagConsequences = flags.sorted { $0.name < $1.name }.map {
      Consequence(
        id: "flag-\($0.id)",
        title: $0.name,
        detail: $0.context,
        status: "Permanent company standard",
        symbol: "checkmark.seal.fill",
        kind: .companyStandard
      )
    }
    let obligationConsequences = obligations.map {
      Consequence(
        id: "obligation-\($0.id)",
        title: $0.title,
        detail: $0.detail,
        status: $0.durationLabel,
        symbol: "clock.badge.exclamationmark.fill",
        kind: .activeObligation
      )
    }
    self.consequences = flagConsequences + obligationConsequences
    self.upgrades = upgrades.map { Upgrade(id: $0.rawValue, name: $0.name, symbol: $0.symbol) }
    self.doctrine = Doctrine(
      name: doctrineName,
      summary: doctrineSummary,
      consequenceStatement: "\(founderName)’s company is a chain of decisions and consequences."
    )
    self.careerObjective = Self.careerObjectiveText(for: careerMode)
  }

  static func sprintSegments(currentSprint: Int, total: Int) -> [SprintSegment] {
    guard total > 0 else { return [] }
    return (1...total).map { number in
      let state: SprintSegment.State
      if number < currentSprint {
        state = .completed
      } else if number == currentSprint {
        state = .current
      } else {
        state = .upcoming
      }
      return SprintSegment(number: number, state: state)
    }
  }

  private static func chapterProgressLabel(chapter: VentureChapter, sprint: Int) -> String {
    let range: ClosedRange<Int>
    switch chapter {
    case .prototype: range = 1...3
    case .firstCustomers: range = 4...6
    case .launchPressure: range = 7...9
    case .surviveOrScale: range = 10...12
    }
    return "Sprint \(sprint) · \(max(0, sprint - range.lowerBound + 1)) of \(range.count) in chapter"
  }

  private static func careerObjectiveText(for careerMode: CareerMode) -> String {
    switch careerMode {
    case .daily:
      return "Complete today’s shared venture while protecting runway, trust, energy, and the company your decisions create."
    case .bounded:
      return "Complete two ventures and 24 sprints while protecting runway, trust, energy, and the company you create through persistent decisions."
    case .continuous:
      return "Build for as many ventures as you can sustain. Each checkpoint lets you retire, while operating pressure, obligations, and provider risk continue to rise."
    }
  }
}
