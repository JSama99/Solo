import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class TalentBoardTests: XCTestCase {
  func testSlotsUseDocumentedPriceBandsAndDistinctCandidates() {
    let existing: Set<String> = ["aurora", "stacks", "brio"]
    let fourth = TalentBoard.candidates(for: 4, excluding: existing, refresh: 0)
    let fifth = TalentBoard.candidates(for: 5, excluding: existing, refresh: 0)
    XCTAssertEqual(Set(fourth.map(\.id)).count, fourth.count)
    XCTAssertTrue(fourth.allSatisfy { TalentBoard.fourthSlotPriceRange.contains($0.price) })
    XCTAssertTrue(fifth.allSatisfy { TalentBoard.fifthSlotPriceRange.contains($0.price) })
  }

  func testCareerFourthSlotUnlocksAfterFirstCheckpoint() {
    let store = GameStore()
    store.startCareer(seed: 16)
    XCTAssertNotNil(store.talentBoardGateMessage)
    store.venture = 2
    XCTAssertNil(store.talentBoardGateMessage)
  }

  func testHiringAddsCandidateToRosterAndDeductsCapital() throws {
    let store = GameStore()
    store.startCareer(seed: 16)
    store.venture = 2
    let candidate = try XCTUnwrap(store.talentBoardCandidates.first)
    let capital = store.stats.capital
    store.hire(candidate)
    XCTAssertEqual(store.agents.count, 4)
    XCTAssertEqual(store.stats.capital, capital - candidate.price)
    XCTAssertTrue(store.agents.contains { $0.id == candidate.id })
  }
}
