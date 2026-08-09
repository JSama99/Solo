import XCTest
@testable import Solo_Unicorn_Run

final class GarageVisualizationTests: XCTestCase {
  func testTrustBandBoundaries() {
    XCTAssertEqual(AgentStationViewModel.TrustBand(trust: 64), .coral)
    XCTAssertEqual(AgentStationViewModel.TrustBand(trust: 65), .amber)
    XCTAssertEqual(AgentStationViewModel.TrustBand(trust: 84), .amber)
    XCTAssertEqual(AgentStationViewModel.TrustBand(trust: 85), .teal)
  }

  func testAnimationProfilesMapEverySemanticState() {
    XCTAssertEqual(
      GarageAnimationProfile.profile(for: .idle, motion: .active),
      GarageAnimationProfile(
        avatarPose: .breathing,
        monitorBehavior: .dim,
        ringBehavior: .steady,
        particleCount: 0,
        allowsLoop: true,
        transition: .none
      )
    )
    XCTAssertEqual(GarageAnimationProfile.profile(for: .working, motion: .active).monitorBehavior, .activity)
    XCTAssertEqual(GarageAnimationProfile.profile(for: .awaitingReview, motion: .active).ringBehavior, .pendingPulse)
    XCTAssertEqual(GarageAnimationProfile.profile(for: .drifting, motion: .active).transition, .warning)
    XCTAssertEqual(GarageAnimationProfile.profile(for: .overloaded, motion: .active).monitorBehavior, .warm)
    XCTAssertEqual(GarageAnimationProfile.profile(for: .verified, motion: .active).transition, .confirmation)
  }

  func testPhaseOffsetsAreStableForStationIdentity() {
    XCTAssertEqual(
      GaragePhase.offset(identity: "aurora", index: 0),
      GaragePhase.offset(identity: "aurora", index: 0)
    )
    XCTAssertNotEqual(
      GaragePhase.offset(identity: "aurora", index: 0),
      GaragePhase.offset(identity: "stacks", index: 1)
    )
  }

  func testReduceMotionUsesStaticProfilesWithoutParticlesOrLoops() {
    for state in AgentStationViewModel.SemanticState.allCases {
      let profile = GarageAnimationProfile.profile(for: state, motion: .staticPose)
      XCTAssertFalse(profile.allowsLoop)
      XCTAssertEqual(profile.particleCount, 0)
      XCTAssertEqual(profile.avatarPose, .still)
      XCTAssertEqual(profile.transition, .none)
    }
  }

  func testStationDerivationRetainsBoundTaskWithoutMutatingDomainValues() {
    let agent = SoloAgent(
      id: "aurora",
      name: "Aurora",
      initials: "AU",
      role: .research,
      modelFamily: "Scout",
      reliability: 80,
      calibration: 0.7,
      drift: 4,
      trust: 85
    )
    let task = SoloTask(
      title: "Research retention",
      detail: "Read-only test task.",
      role: .research,
      impact: .trust(4),
      assignedAgentID: agent.id
    )

    let station = AgentStationViewModel.derive(agent: agent, task: task, founderStats: FounderStats())

    XCTAssertEqual(station.agentID, agent.id)
    XCTAssertEqual(station.taskTitle, task.title)
    XCTAssertEqual(station.semanticState, .working)
    XCTAssertEqual(agent.assignment, nil)
    XCTAssertEqual(task.assignedAgentID, agent.id)
  }

  func testInactivePolicyDisablesAmbientMotion() {
    XCTAssertFalse(PresentationPolicy(reduceMotion: false, applicationActivity: .inactive).allowsAmbientMotion)
    XCTAssertFalse(PresentationPolicy(reduceMotion: false, applicationActivity: .background).allowsAmbientMotion)
    XCTAssertFalse(PresentationPolicy(reduceMotion: true, applicationActivity: .active).allowsAmbientMotion)
  }
}
