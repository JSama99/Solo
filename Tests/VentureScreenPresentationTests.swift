import XCTest
@testable import Solo_Unicorn_Run

final class VentureScreenPresentationTests: XCTestCase {
  func testSprintProgressAlwaysBuildsTwelveSegments() {
    let segments = VentureScreenPresentation.sprintSegments(currentSprint: 4, total: 12)
    XCTAssertEqual(segments.count, 12)
    XCTAssertEqual(segments.map(\.number), Array(1...12))
  }

  func testSprintSegmentsIdentifyCompletedCurrentAndUpcomingStates() {
    let segments = VentureScreenPresentation.sprintSegments(currentSprint: 4, total: 12)
    XCTAssertEqual(segments.filter { $0.state == .completed }.map(\.number), [1, 2, 3])
    XCTAssertEqual(segments.filter { $0.state == .current }.map(\.number), [4])
    XCTAssertEqual(segments.filter { $0.state == .upcoming }.map(\.number), Array(5...12))
  }

  func testObjectiveCompletionStateIsClampedAndDerivedFromProgress() {
    let complete = makePresentation(objectiveProgress: 1.4)
    XCTAssertEqual(complete.objective.progress, 1)
    XCTAssertEqual(complete.objective.percentage, 100)
    XCTAssertTrue(complete.objective.isComplete)

    let active = makePresentation(objectiveProgress: 0.42)
    XCTAssertEqual(active.objective.percentage, 42)
    XCTAssertFalse(active.objective.isComplete)
  }

  func testOperatingPressurePresentationUsesCanonicalEraValues() {
    let presentation = makePresentation(era: .scale)
    XCTAssertEqual(presentation.pressure.eraName, VentureEra.scale.name)
    XCTAssertEqual(presentation.pressure.detail, VentureEra.scale.newForce)
    XCTAssertEqual(presentation.pressure.runwayCost, VentureEra.scale.runwayBurnPerSprint)
    XCTAssertEqual(presentation.pressure.energyCost, VentureEra.scale.energyCostPerSprint)
  }

  func testConsequencePresentationIncludesPersistentFlagsAndActiveObligations() {
    let obligation = CompanyObligation(
      id: "provider-lock",
      title: "Provider Lock-In",
      detail: "Migration work consumes capacity.",
      sourceDecision: "Chose the fastest provider",
      remainingSprints: 2,
      effectsPerSprint: SimulationEffects(energy: -2)
    )
    let presentation = makePresentation(
      flags: [.evidenceLedClaims],
      obligations: [obligation]
    )

    XCTAssertEqual(presentation.consequences.count, 2)
    XCTAssertEqual(presentation.consequences.first?.title, CompanyFlag.evidenceLedClaims.name)
    XCTAssertEqual(presentation.consequences.first?.kind, .companyStandard)
    XCTAssertEqual(presentation.consequences.last?.title, obligation.title)
    XCTAssertEqual(presentation.consequences.last?.status, obligation.durationLabel)
    XCTAssertEqual(presentation.consequences.last?.kind, .activeObligation)
  }

  func testDoctrinePresentationPreservesCanonicalIdentityAndContext() {
    let presentation = makePresentation(
      doctrineName: "Pure Agent",
      doctrineSummary: "Deep automation with concentrated operational risk.",
      founderName: "Jsama"
    )
    XCTAssertEqual(presentation.doctrine.name, "Pure Agent")
    XCTAssertEqual(presentation.doctrine.summary, "Deep automation with concentrated operational risk.")
    XCTAssertEqual(presentation.doctrine.consequenceStatement, "Jsama’s company is a chain of decisions and consequences.")
  }

  func testCurrentChapterPresentationUsesCanonicalChapterCopy() {
    let presentation = makePresentation(sprint: 5, chapter: .firstCustomers)
    XCTAssertEqual(presentation.chapterNumber, 2)
    XCTAssertEqual(presentation.chapterTitle, VentureChapter.firstCustomers.name)
    XCTAssertEqual(presentation.chapterDetail, VentureChapter.firstCustomers.subtitle)
    XCTAssertEqual(presentation.chapterProgressLabel, "Sprint 5 · 2 of 3 in chapter")
  }

  func testGarageUpgradesArePresentedAsInstalledCapabilities() {
    let presentation = makePresentation(upgrades: [.strategyWall, .evidenceShelf])
    XCTAssertEqual(presentation.upgrades.map(\.name), ["Strategy Wall", "Evidence Shelf"])
    XCTAssertEqual(presentation.upgrades.map(\.symbol), [GarageUpgrade.strategyWall.symbol, GarageUpgrade.evidenceShelf.symbol])
  }

  func testMotionEventsDeriveOnlyForwardCompanyChanges() {
    let previous = VentureMotionSnapshot(makePresentation(
      sprint: 4,
      chapter: .firstCustomers,
      objectiveProgress: 0.62,
      flags: [],
      upgrades: []
    ))
    let current = VentureMotionSnapshot(makePresentation(
      sprint: 5,
      chapter: .firstCustomers,
      objectiveProgress: 0.74,
      flags: [.evidenceLedClaims],
      upgrades: [.evidenceShelf]
    ))

    let events = VentureMotionEvents(previous: previous, current: current)
    XCTAssertEqual(events.sprintAdvance, .init(from: 4, to: 5))
    XCTAssertTrue(events.objectiveProgressIncreased)
    XCTAssertFalse(events.objectiveCompleted)
    XCTAssertEqual(events.newConsequenceIDs, ["flag-evidenceLedClaims"])
    XCTAssertEqual(events.newUpgradeIDs, [GarageUpgrade.evidenceShelf.rawValue])
  }

  func testMotionEventsDetectObjectiveCompletionEdgeOnce() {
    let active = VentureMotionSnapshot(makePresentation(objectiveProgress: 0.99))
    let complete = VentureMotionSnapshot(makePresentation(objectiveProgress: 1))

    XCTAssertTrue(VentureMotionEvents(previous: active, current: complete).objectiveCompleted)
    XCTAssertFalse(VentureMotionEvents(previous: complete, current: complete).objectiveCompleted)
  }

  func testMotionEventsDoNotTreatNewVentureResetAsSprintOrObjectiveProgress() {
    var previous = VentureMotionSnapshot(makePresentation(sprint: 12, objectiveProgress: 1))
    var current = VentureMotionSnapshot(makePresentation(sprint: 1, objectiveProgress: 0.1))
    previous.venture = 1
    current.venture = 2

    let events = VentureMotionEvents(previous: previous, current: current)
    XCTAssertNil(events.sprintAdvance)
    XCTAssertFalse(events.objectiveProgressIncreased)
    XCTAssertFalse(events.objectiveCompleted)
  }

  private func makePresentation(
    sprint: Int = 4,
    chapter: VentureChapter = .firstCustomers,
    era: VentureEra = .garage,
    objectiveProgress: Double = 0.5,
    flags: Set<CompanyFlag> = [],
    obligations: [CompanyObligation] = [],
    upgrades: [GarageUpgrade] = [],
    doctrineName: String = "Balanced Builder",
    doctrineSummary: String = "A balanced operating system.",
    founderName: String = "Founder"
  ) -> VentureScreenPresentation {
    VentureScreenPresentation(
      venture: 1,
      sprint: sprint,
      totalSprints: 12,
      trackRecord: 3,
      evidence: 9,
      chapter: chapter,
      era: era,
      thesisName: "Sustainable",
      thesisDetail: "Protect energy and loyalty while growing deliberately.",
      objectiveTitle: "Build the Proof Loop",
      objectiveDetail: "Make verified evidence a company habit.",
      objectiveProgress: objectiveProgress,
      objectiveReward: "+6 Trust",
      flags: flags,
      obligations: obligations,
      upgrades: upgrades,
      doctrineName: doctrineName,
      doctrineSummary: doctrineSummary,
      founderName: founderName,
      careerMode: .bounded
    )
  }
}
