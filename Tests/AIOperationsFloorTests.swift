import XCTest
@testable import Solo_Unicorn_Run

final class AIOperationsFloorTests: XCTestCase {
  func testPortraitImageFramingNormalizesOnlyCanonicalAgentArtwork() {
    XCTAssertEqual(AIOperationsFloorProjection.portraitFootprint, 48)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageScale(agentID: "aurora"), 1, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageOffset(agentID: "aurora"), .zero)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageScale(agentID: "stacks"), 1.04, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageOffset(agentID: "stacks"), .zero)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageScale(agentID: "brio"), 1.05, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageOffset(agentID: "brio"), CGSize(width: 0, height: -0.7))
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageScale(agentID: "unknown"), 1, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitImageOffset(agentID: "unknown"), .zero)
  }

  func testPortraitFramingCannotDependOnLifecycleOutcomeWidthOrReduceMotion() {
    for agentID in ["aurora", "stacks", "brio"] {
      let scale = AIOperationsFloorProjection.portraitImageScale(agentID: agentID)
      let offset = AIOperationsFloorProjection.portraitImageOffset(agentID: agentID)
      for phase in LivingAgentActivity.allCases {
        var projection = agent(id: agentID, activity: phase, conditions: [.verified, .drifting, .overclaimed, .evidenceIncomplete])
        projection.reviewRevealStep = 5
        XCTAssertEqual(AIOperationsFloorProjection.portraitImageScale(agentID: projection.agentID), scale)
        XCTAssertEqual(AIOperationsFloorProjection.portraitImageOffset(agentID: projection.agentID), offset)
      }
    }
  }

  func testRegularWidthTunesOnlyExistingPortraitMotionAmplitudes() {
    for agentID in ["aurora", "stacks", "brio"] {
      XCTAssertEqual(AIOperationsFloorProjection.portraitWorkingTravel(isWide: false, agentID: agentID), 0.65, accuracy: 0.0001)
      XCTAssertEqual(AIOperationsFloorProjection.portraitCompletionScaleDelta(isWide: false, agentID: agentID), 0.025, accuracy: 0.0001)
    }
    XCTAssertEqual(AIOperationsFloorProjection.portraitWorkingTravel(isWide: true, agentID: "aurora"), 1.0, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitCompletionScaleDelta(isWide: true, agentID: "aurora"), 0.035, accuracy: 0.0001)
    for agentID in ["stacks", "brio"] {
      XCTAssertEqual(AIOperationsFloorProjection.portraitWorkingTravel(isWide: true, agentID: agentID), 1.2, accuracy: 0.0001)
      XCTAssertEqual(AIOperationsFloorProjection.portraitCompletionScaleDelta(isWide: true, agentID: agentID), 0.040, accuracy: 0.0001)
    }
  }

  private func observePortraits(_ agents: [LivingAgentProjection], visible: Set<String> = ["aurora", "stacks", "brio"], eligible: Bool = true, reduced: Bool = false, transitions: Bool = true, observed: inout [String: String], cues: inout [String: String]) {
    AIOperationsFloorProjection.reconcilePortraits(agents: agents, visibleIDs: visible, eligible: eligible, reduceMotion: reduced, allowTransitions: transitions, observed: &observed, cues: &cues)
  }

  private func observeOutcomes(_ agents: [LivingAgentProjection], visible: Set<String> = ["aurora", "stacks", "brio"], eligible: Bool = true, reduced: Bool = false, transitions: Bool = true, observed: inout [String: String], cues: inout [String: String]) {
    AIOperationsFloorProjection.reconcilePortraitOutcomes(agents: agents, visibleIDs: visible, eligible: eligible, reduceMotion: reduced, allowTransitions: transitions, observed: &observed, cues: &cues)
  }

  func testLiveAssignmentAndCompletionConsumeDistinctPhaseIdentitiesOnce() {
    var a = agent(id: "aurora", activity: .idle, conditions: [])
    a.presentationSequenceID = UUID()
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty)
    a.activity = .assignmentReceived
    observePortraits([a], observed: &observed, cues: &cues)
    let acknowledgment = cues["aurora"]
    XCTAssertEqual(acknowledgment, AIOperationsFloorProjection.portraitIdentity(a))
    a.activity = .working
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty)
    XCTAssertTrue(AIOperationsFloorProjection.portraitWorks(activity: a.activity, eligible: true, reduceMotion: false))
    a.activity = .workComplete
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertNotNil(cues["aurora"])
    XCTAssertNotEqual(cues["aurora"], acknowledgment)
    observePortraits([a], visible: [], observed: &observed, cues: &cues)
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty, "Remount cannot replay a consumed completion")
    a.activity = .awaitingReview
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty)
    XCTAssertFalse(AIOperationsFloorProjection.portraitWorks(activity: a.activity, eligible: true, reduceMotion: false))
  }

  func testInitialAndReloadedTransientOrDurablePhasesNeverReconstructCues() {
    for phase in [LivingAgentActivity.assignmentReceived, .workComplete, .awaitingReview] {
      var a = agent(id: "aurora", activity: phase, conditions: [])
      a.presentationSequenceID = UUID()
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observePortraits([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty, phase.rawValue)
      observePortraits([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty, phase.rawValue)
    }
  }

  func testHiddenTransitionsAreConsumedAcrossSceneFocusAndSheetReturn() {
    for phase in [LivingAgentActivity.assignmentReceived, .workComplete] {
      var a = agent(id: "stacks", activity: .idle, conditions: [])
      a.presentationSequenceID = UUID()
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observePortraits([a], observed: &observed, cues: &cues)
      a.activity = phase
      observePortraits([a], eligible: false, observed: &observed, cues: &cues)
      observePortraits([a], transitions: false, observed: &observed, cues: &cues)
      observePortraits([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty)
    }
  }

  func testBecomingVisibleInSameUpdateAsTransitionOnlyAdoptsBaseline() {
    var a = agent(id: "brio", activity: .working, conditions: [])
    a.presentationSequenceID = UUID()
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observePortraits([a], visible: [], observed: &observed, cues: &cues)
    a.activity = .workComplete
    observePortraits([a], transitions: false, observed: &observed, cues: &cues)
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty)
  }

  func testReduceMotionKeepsEveryLifecycleStaticAndConsumesTransitions() {
    for phase in LivingAgentActivity.allCases {
      XCTAssertFalse(AIOperationsFloorProjection.portraitWorks(activity: phase, eligible: true, reduceMotion: true))
      XCTAssertFalse(AIOperationsFloorProjection.portraitWorks(activity: phase, eligible: false, reduceMotion: false))
      XCTAssertEqual(AIOperationsFloorProjection.portraitWorks(activity: phase, eligible: true, reduceMotion: false), phase == .working)
      var a = agent(id: "aurora", activity: .idle, conditions: [])
      a.presentationSequenceID = UUID()
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observePortraits([a], observed: &observed, cues: &cues)
      a.activity = phase
      observePortraits([a], reduced: true, observed: &observed, cues: &cues)
      observePortraits([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty)
    }
  }

  func testReduceMotionToggleCancelsActiveCueWithoutReplayWhenDisabled() {
    for phase in [LivingAgentActivity.assignmentReceived, .workComplete] {
      var a = agent(id: "aurora", activity: .working, conditions: [])
      a.presentationSequenceID = UUID()
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observePortraits([a], observed: &observed, cues: &cues)
      a.activity = phase
      observePortraits([a], observed: &observed, cues: &cues)
      XCTAssertNotNil(cues[a.agentID])
      observePortraits([a], reduced: true, observed: &observed, cues: &cues)
      observePortraits([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty)
    }
  }

  func testConcurrentAgentTransitionsDoNotSuppressEachOther() {
    var agents = ["aurora", "stacks", "brio"].map { id in
      var a = agent(id: id, activity: .idle, conditions: [])
      a.presentationSequenceID = UUID()
      return a
    }
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observePortraits(agents, observed: &observed, cues: &cues)
    for i in agents.indices { agents[i].activity = .assignmentReceived }
    observePortraits(agents, observed: &observed, cues: &cues)
    XCTAssertEqual(cues.count, 3)
    for i in agents.indices { agents[i].activity = .working }
    observePortraits(agents, observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty)
    XCTAssertTrue(agents.allSatisfy { AIOperationsFloorProjection.portraitWorks(activity: $0.activity, eligible: true, reduceMotion: false) })
    agents[0].activity = .awaitingReview
    agents[1].activity = .workComplete
    agents[2].activity = .assignmentReceived
    observePortraits(agents, observed: &observed, cues: &cues)
    XCTAssertEqual(Set(cues.keys), ["stacks", "brio"])
    let stacksCue = cues["stacks"]
    observePortraits(agents, visible: ["stacks"], observed: &observed, cues: &cues)
    XCTAssertEqual(cues, ["stacks": stacksCue!])
  }

  func testReplacementAndRemovalCannotLeaveStalePortraitEffects() {
    var a = agent(id: "aurora", activity: .working, conditions: [])
    a.presentationSequenceID = UUID()
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observePortraits([a], observed: &observed, cues: &cues)
    a.activity = .workComplete
    observePortraits([a], observed: &observed, cues: &cues)
    let oldCue = cues[a.agentID]
    a.taskID = UUID(); a.presentationSequenceID = UUID(); a.activity = .assignmentReceived
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertNotNil(cues[a.agentID])
    XCTAssertNotEqual(cues[a.agentID], oldCue)
    a.activity = .idle; a.taskID = nil; a.presentationSequenceID = nil
    observePortraits([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty)
    observePortraits([], observed: &observed, cues: &cues)
    XCTAssertTrue(observed.isEmpty)
  }

  func testPortraitIdentityAndWorkingPolicyIgnoreOutcomeConditions() {
    var a = agent(id: "aurora", activity: .working, conditions: [])
    a.presentationSequenceID = UUID()
    let neutral = AIOperationsFloorProjection.portraitIdentity(a)
    a.conditions = [.verified, .overclaimed, .drifting, .evidenceIncomplete]
    a.reviewRevealStep = 5
    XCTAssertEqual(AIOperationsFloorProjection.portraitIdentity(a), neutral)
    XCTAssertTrue(AIOperationsFloorProjection.portraitWorks(activity: a.activity, eligible: true, reduceMotion: false))
  }

  func testOutcomeReactionStaysNeutralBeforeCanonicalRevealForEveryResultClass() {
    for condition in [LivingAgentCondition.verified, .evidenceIncomplete, .overclaimed, .drifting] {
      for phase in [LivingAgentActivity.assignmentReceived, .working, .workComplete, .awaitingReview] {
        var a = outcomeAgent(id: "aurora", activity: phase, condition: condition, revealStep: 5)
        XCTAssertNil(AIOperationsFloorProjection.portraitOutcomeReaction(a), "\(condition.rawValue) leaked during \(phase.rawValue)")
        a.reviewRevealStep = 0
        XCTAssertNil(AIOperationsFloorProjection.portraitOutcomeReaction(a))
      }
      let earlyReview = outcomeAgent(id: "aurora", activity: .reviewing, condition: condition, revealStep: 4)
      XCTAssertNil(AIOperationsFloorProjection.portraitOutcomeReaction(earlyReview), "\(condition.rawValue) leaked before step five")
    }
  }

  func testCanonicalRevealMapsExistingResultsWithoutInventingOutcomeSemantics() {
    let expected: [(LivingAgentCondition, ReviewResultVisual)] = [
      (.verified, .verified),
      (.evidenceIncomplete, .evidenceIncomplete),
      (.overclaimed, .overclaimed),
      (.drifting, .driftDetected)
    ]
    for (condition, result) in expected {
      let a = outcomeAgent(id: "aurora", activity: .reviewing, condition: condition, revealStep: 5)
      XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeReaction(a), result)
    }
  }

  func testLiveSameSequenceRevealProducesEachOutcomeCueOnce() {
    let expected: [(LivingAgentCondition, ReviewResultVisual)] = [
      (.verified, .verified),
      (.evidenceIncomplete, .evidenceIncomplete),
      (.overclaimed, .overclaimed),
      (.drifting, .driftDetected)
    ]
    for (condition, result) in expected {
      let taskID = UUID(), sequenceID = UUID()
      var a = outcomeAgent(id: "aurora", activity: .reviewing, condition: condition, revealStep: 4, taskID: taskID, sequenceID: sequenceID)
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observeOutcomes([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty)
      a.reviewRevealStep = 5
      observeOutcomes([a], observed: &observed, cues: &cues)
      XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeReaction(a), result)
      XCTAssertEqual(cues[a.agentID], AIOperationsFloorProjection.portraitOutcomeObservationIdentity(a))
      a.activity = .reviewed
      observeOutcomes([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty, "stable reviewed state must consume the trigger without creating a second one")
    }
  }

  func testInitialReviewedMountAndCardRemountNeverReplayOutcomeReaction() {
    let a = outcomeAgent(id: "aurora", activity: .reviewed, condition: .verified, revealStep: 5)
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observeOutcomes([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty, "restore/relaunch must adopt the reviewed baseline")
    observeOutcomes([a], visible: [], observed: &observed, cues: &cues)
    observeOutcomes([a], transitions: false, observed: &observed, cues: &cues)
    observeOutcomes([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty, "scroll or card remount must not reconstruct a reaction")
  }

  func testHiddenOrCoveredRevealIsConsumedInsteadOfQueued() {
    for (visible, eligible) in [(Set<String>(), true), (["aurora"], false)] {
      var a = outcomeAgent(id: "aurora", activity: .reviewing, condition: .evidenceIncomplete, revealStep: 4)
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observeOutcomes([a], visible: visible, eligible: eligible, observed: &observed, cues: &cues)
      a.reviewRevealStep = 5
      observeOutcomes([a], visible: visible, eligible: eligible, observed: &observed, cues: &cues)
      observeOutcomes([a], transitions: false, observed: &observed, cues: &cues)
      observeOutcomes([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty)
    }
  }

  func testReduceMotionConsumesEveryOutcomeAndCannotReconstructReaction() {
    for condition in [LivingAgentCondition.verified, .evidenceIncomplete, .overclaimed, .drifting] {
      var a = outcomeAgent(id: "aurora", activity: .reviewing, condition: condition, revealStep: 4)
      var observed: [String: String] = [:], cues: [String: String] = [:]
      observeOutcomes([a], observed: &observed, cues: &cues)
      a.reviewRevealStep = 5
      observeOutcomes([a], reduced: true, observed: &observed, cues: &cues)
      observeOutcomes([a], transitions: false, observed: &observed, cues: &cues)
      observeOutcomes([a], observed: &observed, cues: &cues)
      XCTAssertTrue(cues.isEmpty)
      XCTAssertNotNil(AIOperationsFloorProjection.portraitOutcomeReaction(a), "static condition semantics remain present")
    }
  }

  func testOutcomeReplacementClearsStaleCueAndNewSequenceCanReactLater() {
    let oldTask = UUID(), oldSequence = UUID()
    var a = outcomeAgent(id: "stacks", activity: .reviewing, condition: .overclaimed, revealStep: 4, taskID: oldTask, sequenceID: oldSequence)
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observeOutcomes([a], observed: &observed, cues: &cues)
    a.reviewRevealStep = 5
    observeOutcomes([a], observed: &observed, cues: &cues)
    XCTAssertNotNil(cues[a.agentID])

    let newTask = UUID(), newSequence = UUID()
    a = outcomeAgent(id: "stacks", activity: .reviewed, condition: .verified, revealStep: 5, taskID: newTask, sequenceID: newSequence)
    observeOutcomes([a], observed: &observed, cues: &cues)
    XCTAssertTrue(cues.isEmpty, "replacement cannot inherit or fabricate a reaction")
    a.activity = .reviewing
    a.reviewRevealStep = 4
    observeOutcomes([a], observed: &observed, cues: &cues)
    a.reviewRevealStep = 5
    observeOutcomes([a], observed: &observed, cues: &cues)
    XCTAssertNotNil(cues[a.agentID], "a later live reveal for the new sequence may react")
  }

  func testOutcomeReactionsRemainIndependentPerAgent() {
    var agents = [
      outcomeAgent(id: "aurora", activity: .reviewing, condition: .verified, revealStep: 4),
      outcomeAgent(id: "stacks", activity: .reviewing, condition: .evidenceIncomplete, revealStep: 4),
      outcomeAgent(id: "brio", activity: .reviewing, condition: .drifting, revealStep: 4)
    ]
    var observed: [String: String] = [:], cues: [String: String] = [:]
    observeOutcomes(agents, observed: &observed, cues: &cues)
    agents[0].reviewRevealStep = 5
    observeOutcomes(agents, observed: &observed, cues: &cues)
    XCTAssertEqual(Set(cues.keys), ["aurora"])
    agents[1].reviewRevealStep = 5
    observeOutcomes(agents, observed: &observed, cues: &cues)
    XCTAssertEqual(Set(cues.keys), ["stacks"])
    agents[2].reviewRevealStep = 5
    observeOutcomes(agents, observed: &observed, cues: &cues)
    XCTAssertEqual(Set(cues.keys), ["brio"])
    XCTAssertEqual(agents.map(AIOperationsFloorProjection.portraitOutcomeReaction), [.verified, .evidenceIncomplete, .driftDetected])
  }

  func testOutcomeMotionIsRestrainedAndKeepsTheFixedPortraitFootprint() {
    XCTAssertEqual(AIOperationsFloorProjection.portraitFootprint, 48)
    let positive = AIOperationsFloorProjection.portraitOutcomeOffset(.verified, phase: 1)
    let caution = AIOperationsFloorProjection.portraitOutcomeOffset(.evidenceIncomplete, phase: 1)
    let serious = AIOperationsFloorProjection.portraitOutcomeOffset(.overclaimed, phase: 1)
    XCTAssertEqual(positive, CGSize(width: 0, height: -1.4))
    XCTAssertEqual(caution, CGSize(width: 0.9, height: 0))
    XCTAssertEqual(serious, CGSize(width: 0, height: 1.2))
    XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeOffset(.driftDetected, phase: 1), serious)
    XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeScale(.verified, phase: 1), 1.025, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeScale(.evidenceIncomplete, phase: 1), 0.985, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeScale(.overclaimed, phase: 1), 0.975, accuracy: 0.0001)
    XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeOffset(.pending, phase: 1), .zero)
    XCTAssertEqual(AIOperationsFloorProjection.portraitOutcomeScale(.pending, phase: 1), 1)
  }

  func testReviewQueueProjectsReportedOutputWithoutVerifiedClaim() {
    let reported = agent(id: "aurora", activity: .awaitingReview, conditions: [.focused])
    let queue = AIOperationsFloorProjection.derive(
      agents: [reported], summary: summary(), finance: .init(), calendar: .init()
    ).queue
    XCTAssertEqual(queue.count, 1)
    XCTAssertTrue(queue[0].isReviewable)
    XCTAssertEqual(queue[0].lifecycle, "Reported output")
    XCTAssertFalse(queue[0].decisionSummary.localizedCaseInsensitiveContains("verified"))
  }

  func testQueueIdentityIsCanonicalAgentIdentityAndDoesNotDuplicate() {
    let agent = agent(id: "stacks", activity: .workComplete, conditions: [.focused])
    let queue = AIOperationsFloorProjection.derive(agents: [agent], summary: summary(), finance: .init(), calendar: .init()).queue
    XCTAssertEqual(queue.map(\.id), ["stacks"])
  }

  func testReviewedAndResolvingWorkCannotBeReinvokedFromQueue() {
    let items = AIOperationsFloorProjection.derive(
      agents: [agent(id: "brio", activity: .reviewed, conditions: []), agent(id: "aurora", activity: .resolving, conditions: [])],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue
    XCTAssertEqual(items.count, 2)
    XCTAssertTrue(items.allSatisfy { !$0.isReviewable })
  }

  func testPrimaryStationProjectionUsesEachCanonicalAgentOnce() {
    let agents = [
      agent(id: "aurora", activity: .idle, conditions: []),
      agent(id: "aurora", activity: .working, conditions: [.focused]),
      agent(id: "stacks", activity: .idle, conditions: []),
      agent(id: "brio", activity: .idle, conditions: [])
    ]
    let stationIDs = AIOperationsFloorProjection.primaryStationIDs(from: agents)
    XCTAssertEqual(stationIDs, ["aurora", "stacks", "brio"])
  }

  func testQueueActionRequiresCanonicalReviewAvailability() {
    let item = AIOperationsFloorProjection.derive(
      agents: [agent(id: "aurora", activity: .awaitingReview, conditions: [])],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue[0]
    XCTAssertFalse(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(canReview: false)))
    XCTAssertTrue(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(canReview: true)))
  }

  func testCriticalFounderDecisionOutranksInformationalTransition() {
    let queue = AIOperationsFloorProjection.derive(
      agents: [
        agent(id: "brio", activity: .resolving, conditions: []),
        agent(id: "aurora", activity: .awaitingReview, conditions: [])
      ],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue
    XCTAssertEqual(queue.map(\.agentID), ["aurora", "brio"])
    XCTAssertEqual(queue.map(\.priority), [.critical, .informational])
  }

  func testReviewedItemNavigatesToResolutionWithoutReinvokingReview() {
    let item = AIOperationsFloorProjection.derive(
      agents: [agent(id: "stacks", activity: .reviewed, conditions: [])],
      summary: summary(), finance: .init(), calendar: .init()
    ).queue[0]
    XCTAssertEqual(item.action, .resolve)
    XCTAssertFalse(item.isReviewable)
    XCTAssertFalse(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(canReview: true)))
    XCTAssertTrue(AIOperationsFloorProjection.queueActionEnabled(item: item, availability: .init(requiresResolution: true)))
  }

  func testEmptyQueueExplainsCanonicalRouting() {
    XCTAssertEqual(
      AIOperationsFloorProjection.emptyQueueText,
      "No reports awaiting Founder Review. Aurora, Stacks and Brio will route reported outputs here."
    )
  }

  func testPrimaryCompositionDeclaresOneConsoleQueueAndCanonicalStations() {
    let ids = AIOperationsFloorProjection.primarySurfaceIDs
    XCTAssertEqual(ids.count, 5)
    XCTAssertEqual(Set(ids).count, 5)
    XCTAssertEqual(ids.filter { $0 == "founder-command-console" }.count, 1)
    XCTAssertEqual(ids.filter { $0 == "operations-station-aurora" }.count, 1)
    XCTAssertEqual(ids.filter { $0 == "operations-station-stacks" }.count, 1)
    XCTAssertEqual(ids.filter { $0 == "operations-station-brio" }.count, 1)
  }

  func testReviewPrioritySuppressesCommitAsNextAction() {
    var founder = summary()
    founder.canCommit = true
    founder.reviewCount = 1
    let projection = AIOperationsFloorProjection.derive(
      agents: [agent(id: "aurora", activity: .awaitingReview, conditions: [])],
      summary: founder, finance: .init(), calendar: .init()
    )
    XCTAssertEqual(projection.nextAction.eyebrow, "FOUNDER REVIEW")
    XCTAssertNotEqual(projection.nextAction.shortTitle, "Commit Sprint")
  }

  func testProjectionDoesNotMutateCanonicalFinanceOrCalendar() {
    let finance = CompanyFinance(cash: 1_234, lifetimeRevenue: 432)
    let calendar = OperatingCalendar(totalDays: 91, dayOfSprint: 3, hour: 14)
    _ = AIOperationsFloorProjection.derive(
      agents: [agent(id: "aurora", activity: .working, conditions: [.focused])],
      summary: summary(), finance: finance, calendar: calendar
    )
    XCTAssertEqual(finance.cash, 1_234)
    XCTAssertEqual(finance.lifetimeRevenue, 432)
    XCTAssertEqual(calendar.totalDays, 91)
    XCTAssertEqual(calendar.dayOfSprint, 3)
    XCTAssertEqual(calendar.period, .afternoon)
  }

  func testReportedAccessibilityNeverClaimsVerification() {
    let reported = agent(id: "aurora", activity: .awaitingReview, conditions: [])
    let item = AIOperationsFloorProjection.derive(
      agents: [reported], summary: summary(), finance: .init(), calendar: .init()
    ).queue[0]
    XCTAssertTrue(item.accessibilityLabel.localizedCaseInsensitiveContains("reported"))
    XCTAssertFalse(item.accessibilityLabel.localizedCaseInsensitiveContains("verified"))
    XCTAssertFalse(reported.accessibilityValue.localizedCaseInsensitiveContains("verified"))
  }

  func testActiveFundingMilestoneAppearsInFounderCommandProjection() throws {
    let opportunity = try XCTUnwrap(FundingBoardCatalog.opportunities.first {
      $0.id == "founder-conviction-round"
    })
    let application = FundingApplicationRecord(
      opportunityID: opportunity.id,
      status: .resolved,
      appliedCareerSprint: 6,
      resolvedCareerSprint: 7,
      outcome: .funded,
      outcomeReason: "Every visible requirement remained met.",
      milestoneObligation: FundingMilestoneObligation(
        metric: .revenue,
        target: 6_000,
        createdCareerSprint: 7,
        dueCareerSprint: 11,
        missedTrustConsequence: 6,
        status: .active,
        resolvedCareerSprint: nil
      )
    )
    let presentations = FundingBoardEngine.presentations(
      snapshot: FundingBoardSnapshot(
        revenue: 4_200,
        trust: 70,
        momentum: 45,
        coverage: 10,
        venture: 1,
        evidenceCount: 2,
        careerSprint: 9,
        attentionRemaining: 2
      ),
      applications: [application]
    )
    let projection = AIOperationsFloorProjection.derive(
      agents: [],
      summary: summary(),
      finance: .init(),
      calendar: .init(),
      fundingOpportunities: presentations
    )
    let milestone = try XCTUnwrap(projection.fundingMilestone)

    XCTAssertTrue(milestone.title.contains(opportunity.name))
    XCTAssertTrue(milestone.progress.contains("$4,200"))
    XCTAssertTrue(milestone.progress.contains("$6,000"))
    XCTAssertTrue(milestone.deadline.contains("sprints remaining"))
    XCTAssertEqual(milestone.consequence, "If missed: Company Trust −6")

    for status: FundingMilestoneStatus in [.met, .missed] {
      var resolved = presentations
      let index = try XCTUnwrap(resolved.firstIndex { $0.id == opportunity.id })
      resolved[index].application?.milestoneObligation?.status = status
      XCTAssertNil(AIOperationsFloorProjection.derive(
        agents: [], summary: summary(), finance: .init(), calendar: .init(),
        fundingOpportunities: resolved
      ).fundingMilestone)
    }
  }

  private func agent(id: String, activity: LivingAgentActivity, conditions: Set<LivingAgentCondition>) -> LivingAgentProjection {
    LivingAgentProjection(agentID: id, name: id.capitalized, initials: String(id.prefix(1)).uppercased(), role: id == "aurora" ? .research : id == "stacks" ? .engineering : .marketing, taskID: UUID(), taskTitle: "Canonical task", activity: activity, conditions: conditions, emphasis: .normal, progress: 0.5, reviewRevealStep: 0, stressLabel: "Stable", trustLabel: "Trust 85 or higher", level: 1, needsFounderAttention: false, isResting: false)
  }

  private func outcomeAgent(
    id: String, activity: LivingAgentActivity, condition: LivingAgentCondition,
    revealStep: Int, taskID: UUID = UUID(), sequenceID: UUID = UUID()
  ) -> LivingAgentProjection {
    var value = agent(id: id, activity: activity, conditions: [condition])
    value.taskID = taskID
    value.presentationSequenceID = sequenceID
    value.reviewRevealStep = revealStep
    return value
  }

  private func summary() -> CompanyCommandFounderSummary {
    .init(sprintPhase: .reviewAndResolve, workInProgressCount: 0, reviewCount: 1, resolutionCount: 0, attentionRemaining: 2, attentionMaximum: 2, canCommit: false, nextAction: "Review work")
  }
}
