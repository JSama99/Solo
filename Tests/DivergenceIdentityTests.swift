import XCTest
@testable import Solo_Unicorn_Run

final class DivergenceIdentityTests: XCTestCase {
  func testKnownBehaviorVectorsRevealExpectedDoctrine() {
    let pure = DoctrineProfile(verificationRate: 0.1, unverifiedShipRate: 0.9, roleFitDiscipline: 0.5, restDiscipline: 0.2, evidenceThreshold: 0.3, relationshipInvestment: 0.3)
    let guided = DoctrineProfile(verificationRate: 0.6, unverifiedShipRate: 0.3, roleFitDiscipline: 0.7, restDiscipline: 0.5, evidenceThreshold: 0.6, relationshipInvestment: 0.6)
    let trust = DoctrineProfile(verificationRate: 0.9, unverifiedShipRate: 0.05, roleFitDiscipline: 0.9, restDiscipline: 0.9, evidenceThreshold: 0.9, relationshipInvestment: 0.9)

    XCTAssertEqual(pure.revealed, .pure)
    XCTAssertEqual(guided.revealed, .guided)
    XCTAssertEqual(trust.revealed, .trust)
    XCTAssertLessThan(trust.gap(from: .trust), trust.gap(from: .pure))
  }

  func testUnicornIdentitySignaturesAndTieBreakAreDeterministic() {
    let trust = DoctrineProfile(verificationRate: 1, unverifiedShipRate: 0, roleFitDiscipline: 1, restDiscipline: 1, evidenceThreshold: 1, relationshipInvestment: 1)
    XCTAssertEqual(UnicornIdentity.derive(flags: [.acquisitionAccepted], profile: trust, revenue: 0), .boughtOut)
    XCTAssertEqual(UnicornIdentity.derive(flags: [.evidenceLedClaims, .publicTransparency], profile: trust, revenue: 0), .trustMachine)

    let neutral = DoctrineProfile.neutral
    let first = UnicornIdentity.derive(flags: [], profile: neutral, revenue: 0)
    for _ in 0..<20 {
      XCTAssertEqual(UnicornIdentity.derive(flags: [], profile: neutral, revenue: 0), first)
    }
  }

  func testLegacyCareerOutcomeDecodesWithoutIdentity() throws {
    let data = try XCTUnwrap("{\"kind\":\"victory\",\"title\":\"Done\",\"summary\":\"Legacy\",\"score\":42}".data(using: .utf8))
    let outcome = try JSONDecoder().decode(CareerOutcome.self, from: data)
    XCTAssertNil(outcome.unicornIdentity)
    XCTAssertNil(outcome.doctrineProfile)
  }
}
