import XCTest
@testable import Solo_Unicorn_Run

final class InteractiveGarageTests: XCTestCase {
  private let idle = AgentStationViewModel(agentID: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Nova", trust: 80, taskTitle: nil, semanticState: .idle, mood: "Ready")
  private let awaitingReview = AgentStationViewModel(agentID: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Nova", trust: 80, taskTitle: "Audit", semanticState: .awaitingReview, mood: "Focused")

  func testPhaseActionabilityMapping() {
    XCTAssertEqual(GarageTurnGate(phase: .founderEvent).primary, .desk)
    XCTAssertEqual(GarageTurnGate(phase: .chooseCommitments).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .assignTeam).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .reviewAndResolve).primary, .stations)
    XCTAssertEqual(GarageTurnGate(phase: .readyToCommit).primary, .desk)
  }

  func testStationsAreReachableAfterFounderEventAndHighlightGuidesNextWork() {
    XCTAssertFalse(GarageTurnGate(phase: .founderEvent).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .assignTeam).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsActionable(idle))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsActionable(awaitingReview))
    XCTAssertTrue(GarageTurnGate(phase: .readyToCommit).stationIsActionable(awaitingReview))
    XCTAssertTrue(GarageTurnGate(phase: .reviewAndResolve).stationIsHighlighted(awaitingReview))
    XCTAssertTrue(GarageTurnGate(phase: .assignTeam).stationIsHighlighted(idle))
  }

  func testThreeToFiveBayLayoutsStayInBoundsAndNeverOverlapEachOtherOrDesk() {
    for count in 3...5 {
      let layout = GarageBayLayout(stationCount: count)
      let canvas = CGRect(x: 0, y: 0, width: layout.canvasWidth, height: GarageBayLayout.canvasHeight)
      XCTAssertEqual(layout.bays.count, count)
      XCTAssertTrue(canvas.contains(layout.deskFrame))
      for first in layout.bays.indices {
        XCTAssertFalse(layout.bays[first].frame.intersects(layout.deskFrame))
        for second in layout.bays.indices where second > first {
          XCTAssertFalse(layout.bays[first].frame.intersects(layout.bays[second].frame))
          XCTAssertNotEqual(layout.bays[first].center, layout.bays[second].center)
        }
      }
    }
  }

  func testFiveBayPresentationTokensAreDistinct() {
    XCTAssertEqual(Set((0..<5).map(GarageBayPresentation.accentToken)).count, 5)
    XCTAssertEqual(Set((0..<5).map(GarageBayPresentation.icon)).count, 5)
  }

  func testFiveAgentStationsRemainAssignableAndReviewable() {
    let agents = (0..<5).map { index in
      SoloAgent(id: "agent-\(index)", name: "Agent \(index)", initials: "A\(index)", role: .general, modelFamily: "Model \(index)", reliability: 75, calibration: 0.7, drift: 0, trust: 60)
    }
    let stations = agents.map { AgentStationViewModel.derive(agent: $0, task: nil, founderStats: FounderStats()) }
    XCTAssertEqual(stations.count, agents.count)
    XCTAssertTrue(stations.allSatisfy { GarageTurnGate(phase: .assignTeam).stationIsActionable($0) })
    XCTAssertTrue(stations.allSatisfy { GarageTurnGate(phase: .reviewAndResolve).stationIsActionable($0) })
  }

  // MARK: - Shared animation renderer

  func testMonitorTreatmentIsDistinctAcrossSemanticStates() {
    let accent = SoloTheme.coral
    var treatments: Set<String> = []
    for state in AgentStationViewModel.SemanticState.allCases {
      let profile = GarageAnimationProfile.profile(for: state, motion: .active)
      let color = GarageAnimationRenderer.monitorColor(profile: profile, accent: accent)
      let opacity = GarageAnimationRenderer.monitorOpacity(profile: profile, time: 0)
      treatments.insert("\(color)-\(opacity)")
    }
    XCTAssertGreaterThanOrEqual(treatments.count, 3)
  }

  func testMonitorColorPreservesAgentAccentButOverridesForIdleAndOverloaded() {
    let accent = SoloTheme.coral
    let working = GarageAnimationProfile.profile(for: .working, motion: .active)
    let idle = GarageAnimationProfile.profile(for: .idle, motion: .active)
    let overloaded = GarageAnimationProfile.profile(for: .overloaded, motion: .active)

    XCTAssertEqual(GarageAnimationRenderer.monitorColor(profile: working, accent: accent), accent)
    XCTAssertEqual(GarageAnimationRenderer.monitorColor(profile: idle, accent: accent), .gray)
    XCTAssertEqual(GarageAnimationRenderer.monitorColor(profile: overloaded, accent: accent), SoloTheme.amber)
  }

  func testBayRingPulsesOnlyWhileAwaitingReview() {
    let awaiting = GarageAnimationProfile.profile(for: .awaitingReview, motion: .active)
    let scales = stride(from: 0.0, to: 2.2, by: 0.1).map {
      GarageAnimationRenderer.bayRingScale(profile: awaiting, time: $0)
    }
    XCTAssertGreaterThan(Double(scales.max()! - scales.min()!), 0.05)

    for state in AgentStationViewModel.SemanticState.allCases where state != .awaitingReview {
      let profile = GarageAnimationProfile.profile(for: state, motion: .active)
      XCTAssertEqual(GarageAnimationRenderer.bayRingScale(profile: profile, time: 1.3), 1)
    }
  }

  func testAmbientWarningOffsetKeepsMovingForWarningStates() {
    let drifting = GarageAnimationProfile.profile(for: .drifting, motion: .active)
    XCTAssertEqual(drifting.transition, .warning)
    let offsets = stride(from: 0.0, to: 0.9, by: 0.05).map {
      GarageAnimationRenderer.ambientWarningOffset(profile: drifting, time: $0)
    }
    XCTAssertGreaterThan(Double(offsets.map(abs).max()!), 1.0)

    let working = GarageAnimationProfile.profile(for: .working, motion: .active)
    XCTAssertEqual(GarageAnimationRenderer.ambientWarningOffset(profile: working, time: 0.4), 0)
  }

  func testReduceMotionFreezesSharedRendererOutputs() {
    for state in AgentStationViewModel.SemanticState.allCases {
      let profile = GarageAnimationProfile.profile(for: state, motion: .staticPose)
      XCTAssertEqual(GarageAnimationRenderer.avatarOffset(profile: profile, time: 1.7), 0)
      XCTAssertEqual(GarageAnimationRenderer.avatarTilt(profile: profile, time: 1.7), 0)
      XCTAssertEqual(GarageAnimationRenderer.bayRingScale(profile: profile, time: 1.7), 1)
      XCTAssertEqual(GarageAnimationRenderer.ambientWarningOffset(profile: profile, time: 1.7), 0)
    }
  }

  func testStationTimeIsDeterministicAndPhaseShiftedPerStation() {
    let date = Date(timeIntervalSinceReferenceDate: 1_000)
    XCTAssertEqual(
      GarageAnimationRenderer.stationTime(date: date, identity: "aurora", index: 0),
      GarageAnimationRenderer.stationTime(date: date, identity: "aurora", index: 0)
    )
    XCTAssertNotEqual(
      GarageAnimationRenderer.stationTime(date: date, identity: "aurora", index: 0),
      GarageAnimationRenderer.stationTime(date: date, identity: "stacks", index: 1)
    )
  }

  func testStatusColorsCoverEverySemanticState() {
    let colors = AgentStationViewModel.SemanticState.allCases.map {
      GarageAnimationRenderer.statusColor(for: $0)
    }
    XCTAssertEqual(colors.count, AgentStationViewModel.SemanticState.allCases.count)
    XCTAssertGreaterThanOrEqual(Set(colors.map { "\($0)" }).count, 4)
  }

  @MainActor func testFullTurnKeepsStationsReachable() throws {
    let store = GameStore()
    store.selectedCareerMode = .bounded
    store.startCareer(seed: 321)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let presentation = PresentationCoordinator()
    for task in store.tasks {
      let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
      let station = AgentStationViewModel.derive(agent: agent, task: task, founderStats: store.stats)
      XCTAssertTrue(GarageTurnGate(phase: store.sprintPhase).stationIsActionable(station))
      presentation.assign(agentID: agent.id, to: task.id, in: store)
    }
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first(where: { $0.id == task.assignedAgentID }))
    XCTAssertTrue(GarageTurnGate(phase: store.sprintPhase).stationIsActionable(.derive(agent: agent, task: task, founderStats: store.stats)))
    presentation.review(taskID: task.id, in: store)
    store.resolveReviewedTask(taskID: task.id, choice: .approve)
    XCTAssertTrue(store.canCommitSprint == false || GarageTurnGate(phase: store.sprintPhase).stationIsActionable(.derive(agent: agent, task: task, founderStats: store.stats)))
  }
}
