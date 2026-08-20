import XCTest
@testable import Solo_Unicorn_Run

final class DivergenceChaosTests: XCTestCase {
  func testLatentDefectsAreDeterministicAttributedAndInverseToEvidence() {
    let agent = SoloAgent(id: "stacks", name: "Stacks", initials: "ST", role: .engineering, modelFamily: "Nova", reliability: 80, calibration: 0.8, drift: 0, trust: 70)
    var lowCount = 0
    var highCount = 0
    for index in 0..<500 {
      let task = SoloTask(
        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
        title: "Payments integration \(index)",
        detail: "Test fixture",
        role: .engineering,
        impact: .revenue(100)
      )
      let low = result(evidence: 15)
      let high = result(evidence: 65)
      let defectA = SimulationEngine.latentDefect(careerSeed: 44, venture: 2, sprint: 4, careerSprint: 16, task: task, agent: agent, result: low)
      let defectB = SimulationEngine.latentDefect(careerSeed: 44, venture: 2, sprint: 4, careerSprint: 16, task: task, agent: agent, result: low)
      XCTAssertEqual(defectA, defectB)
      if let defectA {
        lowCount += 1
        XCTAssertTrue(defectA.receipt.contains("Payments integration"))
        XCTAssertTrue(defectA.receipt.contains("Stacks"))
        XCTAssertTrue(defectA.receipt.contains("15% evidence"))
        XCTAssertTrue((18...20).contains(defectA.surfacesAtCareerSprint))
      }
      if SimulationEngine.latentDefect(careerSeed: 44, venture: 2, sprint: 4, careerSprint: 16, task: task, agent: agent, result: high) != nil {
        highCount += 1
      }
    }
    XCTAssertGreaterThan(lowCount, highCount * 4)
  }

  func testExposureMechanicallyReducesRivalStrength() {
    let rival = RivalCompany(id: "hype", name: "Hype", archetype: .hypeMachine, debutVenture: 1, baseStrength: 3)
    let stats = FounderStats()
    let normal = RivalEngine.strength(of: rival, venture: 2, sprint: 3, careerSeed: 9, player: stats, playerFlags: [])
    let exposed = RivalEngine.strength(of: rival, venture: 2, sprint: 3, careerSeed: 9, player: stats, playerFlags: [], exposedRivalIDs: ["hype"])
    XCTAssertEqual(exposed, normal * 0.35, accuracy: 0.000_001)
  }

  private func result(evidence: Int) -> TaskResult {
    TaskResult(
      actualQuality: 55,
      reportedQuality: 60,
      evidenceCompleteness: evidence,
      correlatedFailureIdentifier: nil,
      immediateEffects: SimulationEffects(),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: 40,
      confidenceUpperBound: 70,
      knownOperationalRisk: "Limited supporting evidence"
    )
  }
}
