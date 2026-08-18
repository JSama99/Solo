import SwiftUI
import XCTest
@testable import Solo_Unicorn_Run

/// The Garage animation layer, tested where it can be tested: the pure
/// derivations behind each animation.
///
/// A SwiftUI animation itself is only provable in the Simulator, but everything
/// that decides *whether* and *how* it plays is an ordinary value — a phase
/// table, a scale, a formatted string, a state mapping. Those are the parts
/// that can silently regress, so those are the parts pinned here.
///
/// The two invariants that matter most:
///
/// 1. Every animation is driven by real sprint state, not by a timer or a demo
///    flag. `AgentWorkIndicator.Activity.derive` is checked against a store the
///    tests actually play.
/// 2. Deriving that state never touches the seeded generator, so watching the
///    animations cannot change the run.
@MainActor
final class GameplayAnimationTests: XCTestCase {
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  // ── Working state derivation ────────────────────────────────────────

  func testRestingOutranksEveryOtherActivity() {
    for task in [nil, SoloTask?.some(makeTask(reviewed: true, locked: true))] {
      XCTAssertEqual(AgentWorkIndicator.Activity.derive(task: task, isResting: true), .resting)
    }
  }

  func testNoTaskIsIdle() {
    XCTAssertEqual(AgentWorkIndicator.Activity.derive(task: nil, isResting: false), .idle)
  }

  func testAssignedButUnreviewedWorkIsWorking() {
    let task = makeTask(reviewed: false, locked: false)
    XCTAssertEqual(AgentWorkIndicator.Activity.derive(task: task, isResting: false), .working)
  }

  func testReviewedWorkAwaitsTheFoundersDecision() {
    let task = makeTask(reviewed: true, locked: false)
    XCTAssertEqual(AgentWorkIndicator.Activity.derive(task: task, isResting: false), .awaitingDecision)
  }

  func testALockedResolutionSettles() {
    let task = makeTask(reviewed: true, locked: true)
    XCTAssertEqual(AgentWorkIndicator.Activity.derive(task: task, isResting: false), .settled)
  }

  /// The one that actually matters: a real assignment in a real store must land
  /// on `.working`, because that is the animation the founder is meant to see
  /// for the whole assign phase.
  func testAStoreAssignmentProducesTheWorkingActivity() throws {
    let store = makeStore(seed: 90_210)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents[0]

    XCTAssertEqual(activity(for: agent.id, in: store), .idle)

    store.assign(agentID: agent.id, to: task.id)
    XCTAssertEqual(activity(for: agent.id, in: store), .working)

    store.review(taskID: task.id)
    XCTAssertEqual(activity(for: agent.id, in: store), .awaitingDecision)

    store.resolveReviewedTask(taskID: task.id, choice: .approve)
    XCTAssertEqual(activity(for: agent.id, in: store), .settled)
  }

  func testRestingAnAgentReadsAsRecovering() throws {
    let store = makeStore(seed: 5_150)
    let agent = store.agents[1]
    store.restAgent(agentID: agent.id)
    XCTAssertEqual(activity(for: agent.id, in: store), .resting)
  }

  func testOnlyLiveActivitiesAdvertiseContinuousMotion() {
    XCTAssertEqual(
      Set(AgentWorkIndicator.Activity.allCases.filter(\.isLive)),
      [.working, .awaitingDecision],
      "idle, resting, and settled cards must be still"
    )
  }

  func testEveryActivityHasItsOwnCaption() {
    let captions = AgentWorkIndicator.Activity.allCases.map(\.caption)
    XCTAssertEqual(Set(captions).count, captions.count)
  }

  /// Reading the indicator's state must be free: no randomness, no mutation.
  func testDerivingActivityDoesNotConsumeSimulationRandomness() throws {
    let quiet = try fingerprint(seed: 31_337, derivingActivity: false)
    let animated = try fingerprint(seed: 31_337, derivingActivity: true)
    XCTAssertEqual(animated, quiet)
  }

  // ── Selection feel ──────────────────────────────────────────────────

  func testSelectedCardsGrowAndPressedCardsCompress() {
    XCTAssertEqual(AgentCardPressStyle.scale(pressed: false, selected: false), 1)
    XCTAssertEqual(AgentCardPressStyle.scale(pressed: false, selected: true), AgentCardPressStyle.selectedScale)
    XCTAssertEqual(AgentCardPressStyle.scale(pressed: true, selected: false), AgentCardPressStyle.pressedScale)
    XCTAssertEqual(
      AgentCardPressStyle.scale(pressed: true, selected: true),
      AgentCardPressStyle.pressedScale,
      "a press always reads as a press, even on the selected card"
    )
  }

  func testSelectionScaleIsVisibleButRestrained() {
    XCTAssertGreaterThan(AgentCardPressStyle.selectedScale, 1.02, "selection must be noticeable")
    XCTAssertLessThan(AgentCardPressStyle.selectedScale, 1.06, "selection must not shove the layout")
    XCTAssertLessThan(AgentCardPressStyle.pressedScale, 1)
  }

  // ── Assignment acknowledgement ──────────────────────────────────────

  func testAssignmentAcknowledgementStartsAndEndsAtRestingSize() {
    typealias Phase = AssignmentAcknowledgementModifier.Phase
    XCTAssertEqual(Phase.rest.cardScale, 1)
    XCTAssertEqual(Phase.bloom.cardScale, 1)
    XCTAssertGreaterThan(Phase.impact.cardScale, 1, "the card must visibly take the hit")
  }

  func testAssignmentRingBloomsOutwardThenDissolves() {
    typealias Phase = AssignmentAcknowledgementModifier.Phase
    XCTAssertEqual(Phase.rest.ringOpacity, 0)
    XCTAssertGreaterThan(Phase.impact.ringOpacity, 0.5)
    XCTAssertEqual(Phase.bloom.ringOpacity, 0)
    XCTAssertLessThan(Phase.rest.ringScale, Phase.impact.ringScale)
    XCTAssertLessThan(Phase.impact.ringScale, Phase.bloom.ringScale)
  }

  // ── Founder resolution feedback ─────────────────────────────────────

  func testOnlyApproveReadsAsPositive() {
    for choice in TaskResolutionChoice.allCases {
      let feedback = ResolutionFeedback(choice: choice, count: 1)
      XCTAssertEqual(
        feedback.kind,
        choice == .approve ? .positive : .restrained,
        "\(choice) should be \(choice == .approve ? "celebrated" : "acknowledged, not celebrated")"
      )
      XCTAssertEqual(feedback.symbol, choice.symbol)
    }
  }

  func testFeedbackCountDrivesRepeatedResolutions() {
    let first = ResolutionFeedback(choice: .approve, count: 1)
    let second = ResolutionFeedback(choice: .approve, count: 2)
    XCTAssertNotEqual(first, second, "a second identical call must still re-trigger the animation")
  }

  func testResolutionFeedbackOpensAndClosesInvisible() {
    typealias Phase = ResolutionFeedbackModifier.Phase
    XCTAssertEqual(Phase.rest.ringOpacity, 0)
    XCTAssertEqual(Phase.rest.sealOpacity, 0)
    XCTAssertEqual(Phase.settle.ringOpacity, 0)
    XCTAssertEqual(Phase.settle.sealOpacity, 0)
  }

  /// The seal has to stay up long enough to be read, or the founder's decision
  /// gets no answer at all.
  func testResolutionFeedbackHoldsLongEnoughToBeRead() {
    typealias Phase = ResolutionFeedbackModifier.Phase
    XCTAssertGreaterThan(Phase.hold.sealOpacity, 0.6)
    XCTAssertGreaterThan(Phase.hold.ringOpacity, 0.4)
    XCTAssertEqual(Phase.allCases.first, .rest)
    XCTAssertEqual(Phase.allCases.last, .settle)
  }

  func testRestrainedFeedbackNudgesSidewaysAndReturns() {
    typealias Phase = ResolutionFeedbackModifier.Phase
    XCTAssertEqual(Phase.rest.nudge, 0)
    XCTAssertEqual(Phase.hold.nudge, 0)
    XCTAssertEqual(Phase.settle.nudge, 0, "the panel must end exactly where it started")
    XCTAssertLessThan(Phase.strike.nudge, 0)
    XCTAssertGreaterThan(Phase.counter.nudge, 0)
    for phase in Phase.allCases {
      XCTAssertLessThanOrEqual(abs(phase.nudge), 10, "a rejection nudges the panel; it does not shake the screen")
    }
  }

  // ── Resource tiles ──────────────────────────────────────────────────

  func testResourceFormatsMatchTheirUnits() {
    XCTAssertEqual(ResourceMetricView.Format.plain.string(42), "42")
    XCTAssertEqual(ResourceMetricView.Format.days.string(39), "39d")
    XCTAssertEqual(ResourceMetricView.Format.currency.string(723), "$723")
  }

  func testCurrencyCollapsesToThousandsWithoutLosingSign() {
    XCTAssertEqual(ResourceMetricView.Format.currencyString(0), "$0")
    XCTAssertEqual(ResourceMetricView.Format.currencyString(999), "$999")
    XCTAssertEqual(ResourceMetricView.Format.currencyString(2_600), "$2.6k")
    XCTAssertEqual(ResourceMetricView.Format.currencyString(10_400), "$10k")
    XCTAssertEqual(ResourceMetricView.Format.currencyString(-1_500), "-$1.5k")
    XCTAssertEqual(ResourceMetricView.Format.currencyString(-250), "-$250")
  }

  func testResourceEmphasisIsBriefButReadable() {
    XCTAssertGreaterThanOrEqual(ResourceMetricView.emphasisDuration, .milliseconds(800))
    XCTAssertLessThanOrEqual(ResourceMetricView.emphasisDuration, .seconds(3))
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  private struct Fingerprint: Equatable {
    var sprint: Int
    var stats: FounderStats
    var taskTitles: [String]
    var evidenceIDs: [UUID]
    var agentTrust: [Double]
  }

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func makeTask(reviewed: Bool, locked: Bool) -> SoloTask {
    SoloTask(
      title: "Ship the thing",
      detail: "A stand-in task for state derivation.",
      role: .engineering,
      impact: .momentum(4),
      isReviewed: reviewed,
      resolutionLocked: locked
    )
  }

  private func activity(for agentID: String, in store: GameStore) -> AgentWorkIndicator.Activity {
    AgentWorkIndicator.Activity.derive(
      task: store.tasks.first { $0.assignedAgentID == agentID },
      isResting: store.restingAgentIDs.contains(agentID)
    )
  }

  /// Plays the same scripted sprints twice, once while deriving every agent's
  /// animation state on each step. Identical fingerprints prove the animation
  /// layer is a reader.
  private func fingerprint(seed: UInt64, derivingActivity: Bool) throws -> Fingerprint {
    let store = makeStore(seed: seed)

    for _ in 0..<3 {
      guard store.careerOutcome == nil, store.pendingVentureCheckpoint == nil else { break }
      store.confirmVentureThesisIfNeeded()
      for (offset, task) in store.tasks.enumerated() {
        store.assign(agentID: store.agents[offset % store.agents.count].id, to: task.id)
        if derivingActivity { deriveActivities(in: store) }
      }
      if let dilemma = store.activeDilemma, let choice = dilemma.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      for task in store.tasks where task.result != nil {
        store.review(taskID: task.id)
        if derivingActivity { deriveActivities(in: store) }
      }
      store.stats.runway = max(store.stats.runway, 80)
      store.stats.energy = max(store.stats.energy, 80)
      store.commitSprint()
      store.report = nil
      if derivingActivity { deriveActivities(in: store) }
    }

    return Fingerprint(
      sprint: store.sprint,
      stats: store.stats,
      taskTitles: store.tasks.map(\.title),
      evidenceIDs: store.evidence.map(\.id),
      agentTrust: store.agents.map(\.trust)
    )
  }

  private func deriveActivities(in store: GameStore) {
    for agent in store.agents {
      let state = activity(for: agent.id, in: store)
      _ = state.caption
      _ = state.isLive
      _ = AgentCardPressStyle.scale(pressed: false, selected: true)
      _ = ResourceMetricView.Format.currency.string(store.stats.capital)
    }
  }
}
