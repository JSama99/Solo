import XCTest
@testable import Solo_Unicorn_Run

final class OutcomeBackdropMotionTests: XCTestCase {
  func testBreatheReturnsRestingAtAnyTimeUnderReduceMotion() {
    for time in [-100.0, 0, 1.25, 10_000] {
      XCTAssertEqual(
        OutcomeBackdropMotion.breathe(
          time: time,
          cycle: 7,
          reduceMotion: true,
          resting: 0.37
        ),
        0.37
      )
    }
  }

  func testBreatheDefaultsRestingToOne() {
    XCTAssertEqual(OutcomeBackdropMotion.breathe(time: 4, cycle: 7, reduceMotion: true), 1)
  }

  func testBreatheStaysWithinUnitRangeAcrossAFullCycle() {
    let values = (0...700).map {
      OutcomeBackdropMotion.breathe(time: Double($0) / 100, cycle: 7, reduceMotion: false)
    }
    XCTAssertTrue(values.allSatisfy { (0...1).contains($0) })
  }

  func testBreatheStartsAtMidpoint() {
    XCTAssertEqual(OutcomeBackdropMotion.breathe(time: 0, cycle: 7, reduceMotion: false), 0.5)
  }

  func testBreatheIsPeriodic() {
    let first = OutcomeBackdropMotion.breathe(time: 1.75, cycle: 7, reduceMotion: false)
    let repeated = OutcomeBackdropMotion.breathe(time: 8.75, cycle: 7, reduceMotion: false)
    XCTAssertEqual(first, repeated, accuracy: 1e-12)
  }

  func testBreatheHandlesZeroAndNegativeCycles() {
    XCTAssertEqual(OutcomeBackdropMotion.breathe(time: 2, cycle: 0, reduceMotion: false), 1)
    XCTAssertEqual(
      OutcomeBackdropMotion.breathe(time: 2, cycle: -3, reduceMotion: false, resting: 0.4),
      0.4
    )
  }

  func testSweepStaysWithinHalfOpenUnitRange() {
    let values = (-500...500).map {
      OutcomeBackdropMotion.sweep(time: Double($0) / 100, cycle: 2.5)
    }
    XCTAssertTrue(values.allSatisfy { $0 >= 0 && $0 < 1 })
  }

  func testSweepIsPeriodic() {
    XCTAssertEqual(
      OutcomeBackdropMotion.sweep(time: 0.75, cycle: 5),
      OutcomeBackdropMotion.sweep(time: 5.75, cycle: 5),
      accuracy: 1e-12
    )
  }

  func testSweepIsSafeAtZeroCycle() {
    XCTAssertEqual(OutcomeBackdropMotion.sweep(time: 12, cycle: 0), 0)
  }

  func testTremorIsSilencedUnderReduceMotion() {
    XCTAssertEqual(
      OutcomeBackdropMotion.tremor(time: 0.25, rate: 3.2, amplitude: 1.4, reduceMotion: true),
      0
    )
  }

  func testTremorStaysWithinAmplitude() {
    let amplitude = 1.4
    let values = (0...1_000).map {
      OutcomeBackdropMotion.tremor(
        time: Double($0) / 100,
        rate: 3.2,
        amplitude: amplitude,
        reduceMotion: false
      )
    }
    XCTAssertTrue(values.allSatisfy { abs($0) <= amplitude })
  }

  func testTremorStartsStill() {
    XCTAssertEqual(
      OutcomeBackdropMotion.tremor(time: 0, rate: 3.2, amplitude: 1.4, reduceMotion: false),
      0
    )
  }
}
