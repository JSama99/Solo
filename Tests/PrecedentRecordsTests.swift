import XCTest
@testable import Solo_Unicorn_Run

final class PrecedentRecordsTests: XCTestCase {
  func testFiltersUseRealOutcomeFields() {
    let flagged = makePrecedent(outcome: PrecedentOutcome(overclaimsSurfaced: 1))
    let trust = makePrecedent(outcome: PrecedentOutcome(trustDelta: -6))
    let neutral = makePrecedent(outcome: PrecedentOutcome())

    XCTAssertEqual([flagged, trust, neutral].filter(PrecedentRecordsFilter.flagged.includes), [flagged])
    XCTAssertEqual([flagged, trust, neutral].filter(PrecedentRecordsFilter.trustImpact.includes), [trust])
  }

  func testExpansionStateIsStableAndIsolatedByPrecedentID() {
    let first = makePrecedent(sprint: 1)
    let second = makePrecedent(sprint: 2)
    var expansion = PrecedentExpansionState()

    expansion.toggle(first.id)
    XCTAssertTrue(expansion.isExpanded(first.id))
    XCTAssertFalse(expansion.isExpanded(second.id))

    expansion.toggle(second.id)
    XCTAssertTrue(expansion.isExpanded(first.id))
    XCTAssertTrue(expansion.isExpanded(second.id))
  }

  func testFiftyPrecedentsBeginCompact() {
    let precedents = (1...50).map { makePrecedent(sprint: $0) }
    let expansion = PrecedentExpansionState()

    XCTAssertEqual(precedents.count, 50)
    XCTAssertTrue(precedents.allSatisfy { !expansion.isExpanded($0.id) })
  }

  private func makePrecedent(sprint: Int = 1, outcome: PrecedentOutcome = PrecedentOutcome()) -> Precedent {
    Precedent(
      id: UUID(),
      venture: 1,
      sprint: sprint,
      context: PrecedentContext(
        doctrine: .guided,
        intent: .build,
        driftBand: .medium,
        runwayBand: .medium,
        unverifiedBand: .medium
      ),
      decisionSummary: "Committed work.",
      outcome: outcome
    )
  }
}
