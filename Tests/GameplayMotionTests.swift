import AVFoundation
import SwiftUI
import XCTest
@testable import Solo_Unicorn_Run

/// Motion in SOLO has two hard rules, and both are testable:
///
/// 1. Reduce Motion is honored everywhere, because every gameplay animation is
///    resolved through `MotionKind` rather than written inline.
/// 2. Presentation never touches the simulation. Deriving what a screen shows —
///    station view models, visual states, visible sprint projections — must not
///    consume a single value from the seeded generator, or a run would stop
///    being reproducible the moment a view redrew.
@MainActor
final class GameplayMotionTests: XCTestCase {
  func testFeedbackPlaybackTrackerQueuesWithoutPrematureAmbienceRestore() {
    var tracker = FeedbackPlaybackTracker()
    tracker.schedule()
    tracker.schedule()
    XCTAssertEqual(tracker.buffersInFlight, 2)
    XCTAssertFalse(tracker.complete(), "The first completion must not restore ambience while another cue remains")
    XCTAssertEqual(tracker.buffersInFlight, 1)
    XCTAssertTrue(tracker.complete(), "The final completion may restore ambience")
    XCTAssertEqual(tracker.buffersInFlight, 0)
    XCTAssertTrue(tracker.complete(), "A duplicate completion must not underflow the queue")
  }

  func testEveryFeedbackKindProducesFiniteBoundedAudio() throws {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
    for kind in GameFeedbackKind.allCases {
      let buffer = try XCTUnwrap(FeedbackToneBuffer.make(kind: kind, format: format))
      XCTAssertGreaterThan(buffer.frameLength, 0)
      XCTAssertLessThanOrEqual(buffer.frameLength, AVAudioFrameCount(format.sampleRate * 0.12))
    }
  }

  func testRevenueCelebrationRespectsSettingsAndBackgroundContext() {
    XCTAssertTrue(RevenueCelebrationFeedback.shouldPlay(isEnabled: true, audioContext: .garage))
    XCTAssertTrue(RevenueCelebrationFeedback.shouldPlay(isEnabled: true, audioContext: .founderReview))
    XCTAssertFalse(RevenueCelebrationFeedback.shouldPlay(isEnabled: false, audioContext: .garage))
    XCTAssertFalse(RevenueCelebrationFeedback.shouldPlay(isEnabled: true, audioContext: .background))
  }

  func testAudioContextDucksAndSuspendsWithoutChangingSettings() {
    XCTAssertEqual(AppAudioContext.garage.musicGain, 1)
    XCTAssertEqual(AppAudioContext.companyCommand.musicGain, 0.35)
    XCTAssertEqual(AppAudioContext.founderReview.musicGain, 0.18)
    XCTAssertEqual(AppAudioContext.background.musicGain, 0)
    XCTAssertLessThan(AppAudioContext.companyCommand.ambienceGain, AppAudioContext.garage.ambienceGain)
    XCTAssertLessThan(AppAudioContext.founderReview.ambienceGain, AppAudioContext.companyCommand.ambienceGain)
    XCTAssertNotEqual(AppAudioContext.techCom, AppAudioContext.venture)
    XCTAssertNotEqual(AppAudioContext.techCom.ambienceGain, AppAudioContext.venture.ambienceGain)
    XCTAssertEqual(AppAudioContext.background.ambienceGain, 0)
  }

  func testGarageAmbienceIsDeterministicLoopSafeAndLocallySynthesized() throws {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
    let first = try XCTUnwrap(GarageAmbienceBuffer.make(format: format, duration: 0.1))
    let second = try XCTUnwrap(GarageAmbienceBuffer.make(format: format, duration: 0.1))
    XCTAssertEqual(first.frameLength, second.frameLength)
    XCTAssertEqual(first.frameLength, 4_410)
    let firstSamples = try XCTUnwrap(first.floatChannelData)
    let secondSamples = try XCTUnwrap(second.floatChannelData)
    for index in stride(from: 0, to: Int(first.frameLength), by: 137) {
      XCTAssertEqual(firstSamples[0][index], secondSamples[0][index], accuracy: 0.000_001)
      XCTAssertEqual(firstSamples[0][index], firstSamples[1][index], accuracy: 0.000_001)
    }
  }

  func testGarageAudioCueDeduplicationPlaysOneCuePerEventAndDoesNotConsumeMissingCues() {
    let event = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    var policy = GarageAudioCueDeduplicator()
    XCTAssertFalse(policy.shouldPlay(token: nil, cue: .monitorWake))
    XCTAssertTrue(policy.shouldPlay(token: event, cue: .monitorWake))
    XCTAssertFalse(policy.shouldPlay(token: event, cue: .monitorWake))
    XCTAssertTrue(policy.shouldPlay(token: event, cue: .reviewReady))
    XCTAssertFalse(policy.shouldPlay(token: event, cue: .reviewReady))
  }

  func testEveryAudioContextHasAnIntentionalGarageAmbienceGain() {
    let active: [AppAudioContext] = [.garage, .companyCommand, .founderReview, .techCom, .venture, .companyServer]
    XCTAssertEqual(Set(active.map(\.ambienceGain)).count, active.count)
    XCTAssertTrue(active.allSatisfy { $0.ambienceGain > 0 })
    XCTAssertEqual(AppAudioContext.background.ambienceGain, 0)
  }
  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  // ── Reduce Motion policy ────────────────────────────────────────────

  func testEveryMotionKindResolvesToNothingUnderReduceMotion() {
    for kind in [MotionKind.state, .emphasis, .celebration, .impact] {
      XCTAssertNil(
        kind.resolved(reduceMotion: true),
        "\(kind) must produce no animation when Reduce Motion is on"
      )
    }
  }

  func testEveryMotionKindAnimatesWhenReduceMotionIsOff() {
    for kind in [MotionKind.state, .emphasis, .celebration, .impact] {
      XCTAssertEqual(kind.resolved(reduceMotion: false), kind.animation)
    }
  }

  func testMotionKindsAreDistinctSoTheyReadAsDifferentEvents() {
    XCTAssertNotEqual(MotionKind.state.animation, MotionKind.emphasis.animation)
    XCTAssertNotEqual(MotionKind.emphasis.animation, MotionKind.celebration.animation)
    XCTAssertNotEqual(MotionKind.state.animation, MotionKind.celebration.animation)
    XCTAssertNotEqual(MotionKind.impact.animation, MotionKind.emphasis.animation)
  }

  func testMotionKindsUseTheProjectsSpringVocabulary() {
    XCTAssertEqual(MotionKind.state.animation, .smooth)
    XCTAssertEqual(MotionKind.emphasis.animation, .snappy)
    XCTAssertEqual(MotionKind.celebration.animation, .bouncy)
  }

  func testEverySoloMotionTimingResolvesToNothingUnderReduceMotion() {
    let timings: [Animation] = [
      SoloMotion.press,
      SoloMotion.focus,
      SoloMotion.arrival,
      SoloMotion.impact,
      SoloMotion.settle
    ]
    for timing in timings {
      XCTAssertNil(SoloMotion.resolved(timing, reduceMotion: true))
    }
  }

  func testEverySoloMotionTimingResolvesToItselfOtherwise() {
    let timings: [Animation] = [
      SoloMotion.press,
      SoloMotion.focus,
      SoloMotion.arrival,
      SoloMotion.impact,
      SoloMotion.settle
    ]
    for timing in timings {
      XCTAssertEqual(SoloMotion.resolved(timing, reduceMotion: false), timing)
    }
  }

  func testSoloMotionPressTimingIsLocked() {
    XCTAssertEqual(SoloMotion.press, .easeOut(duration: 0.10))
  }

  func testSoloMotionSettleTimingIsLocked() {
    XCTAssertEqual(SoloMotion.settle, .smooth(duration: 0.24))
  }

  // ── Presentation must not consume simulation RNG ────────────────────

  /// Plays an identical scripted career in two stores from the same seed. The
  /// second store additionally derives every presentation value a view would
  /// derive, at every step. If any of that derivation reached into the seeded
  /// generator, the two runs would diverge.
  func testDerivingPresentationStateDoesNotConsumeSimulationRandomness() throws {
    let quiet = playScriptedCareer(seed: 4_242, derivingPresentation: false)
    let animated = playScriptedCareer(seed: 4_242, derivingPresentation: true)

    XCTAssertEqual(animated.venture, quiet.venture)
    XCTAssertEqual(animated.sprint, quiet.sprint)
    XCTAssertEqual(animated.stats, quiet.stats)
    XCTAssertEqual(animated.taskTitles, quiet.taskTitles)
    XCTAssertEqual(animated.evidenceIDs, quiet.evidenceIDs)
    XCTAssertEqual(animated.agentTrust, quiet.agentTrust)
    XCTAssertEqual(animated.reportSprints, quiet.reportSprints)
  }

  /// The same guarantee stated at the unit level: projecting a task result is a
  /// pure function of the result it is handed.
  func testVisibleProjectionIsPureForAGivenResult() throws {
    let store = makeStore(seed: 7_777)
    let task = try XCTUnwrap(store.tasks.first)
    store.assign(agentID: store.agents[0].id, to: task.id)
    let result = try XCTUnwrap(store.tasks.first(where: { $0.id == task.id })?.result)

    let first = VisibleSimulationProjection.taskResult(from: result)
    let second = VisibleSimulationProjection.taskResult(from: result)

    XCTAssertEqual(first, second, "the same result must always project to the same visible values")
  }

  func testStationViewModelDerivationIsStableAcrossRepeatedRedraws() throws {
    let store = makeStore(seed: 1_212)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents[0]
    store.assign(agentID: agent.id, to: task.id)
    let assigned = store.tasks.first(where: { $0.id == task.id })

    let renders = (0..<25).map { _ in
      AgentStationViewModel.derive(agent: agent, task: assigned, founderStats: store.stats)
    }

    XCTAssertEqual(Set(renders.map(\.semanticState)).count, 1, "a redraw must not change semantic state")
    XCTAssertEqual(renders.first, renders.last)
  }

  // ── Presentation lifecycle ──────────────────────────────────────────

  func testAssignmentStagesWorkingBeforeAwaitingReviewWithoutChangingCanonicalResult() async throws {
    let store = makeStore(seed: 9_101)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents[0]
    let presentation = makeFastPresentation()

    presentation.assign(agentID: agent.id, to: task.id, in: store)
    let canonical = try XCTUnwrap(store.tasks.first(where: { $0.id == task.id })?.result)
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .assignmentReceived)

    try await Task.sleep(for: .milliseconds(35))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .working)
    XCTAssertEqual(store.tasks.first(where: { $0.id == task.id })?.result, canonical)

    try await Task.sleep(for: .milliseconds(115))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .workComplete)
    XCTAssertEqual(store.tasks.first(where: { $0.id == task.id })?.result, canonical)

    try await Task.sleep(for: .milliseconds(40))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .awaitingReview)
    XCTAssertEqual(store.tasks.first(where: { $0.id == task.id })?.result, canonical)
  }

  func testRemovingAssignmentCancelsPresentationSequence() async throws {
    let store = makeStore(seed: 9_102)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents[0]
    let presentation = makeFastPresentation()

    presentation.assign(agentID: agent.id, to: task.id, in: store)
    try await Task.sleep(for: .milliseconds(35))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .working)

    presentation.assign(agentID: nil, to: task.id, in: store)
    XCTAssertNil(presentation.presentation(for: agent.id))
    try await Task.sleep(for: .milliseconds(180))
    XCTAssertNil(presentation.presentation(for: agent.id))
    XCTAssertNil(store.tasks.first(where: { $0.id == task.id })?.result)
  }

  func testPresentationOverrideShowsWorkingAlthoughCanonicalResultAlreadyExists() throws {
    let store = makeStore(seed: 9_103)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents[0]
    store.assign(agentID: agent.id, to: task.id)
    let assigned = try XCTUnwrap(store.tasks.first(where: { $0.id == task.id }))
    XCTAssertNotNil(assigned.result)

    let canonicalStation = AgentStationViewModel.derive(agent: agent, task: assigned, founderStats: store.stats)
    let presentedStation = AgentStationViewModel.derive(
      agent: agent,
      task: assigned,
      founderStats: store.stats,
      presentationPhase: .working
    )

    XCTAssertEqual(canonicalStation.semanticState, .awaitingReview)
    XCTAssertEqual(presentedStation.semanticState, .working)
  }

  func testAuroraCompletedSessionRecoversAfterReloadWithoutAttentionOrReplay() throws {
    try assertCompletedSessionRecovery(agentID: "aurora", role: .research)
  }

  func testStacksCompletedSessionRecoversAfterReloadWithoutAttentionOrReplay() throws {
    try assertCompletedSessionRecovery(agentID: "stacks", role: .engineering)
  }

  func testBrioCompletedSessionRecoversAfterReloadWithoutAttentionOrReplay() throws {
    try assertCompletedSessionRecovery(agentID: "brio", role: .marketing)
  }

  private func assertCompletedSessionRecovery(agentID: String, role: AgentRole) throws {
    let store = makeStore(seed: 9_120)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    store.tasks[0].role = role
    store.tasks[0].urgency = .important
    let id = store.tasks[0].id
    store.assign(agentID: agentID, to: id)
    for agent in store.agents where agent.id != agentID { store.restAgent(agentID: agent.id) }
    XCTAssertTrue(store.prepareWorkSession(taskID: id))
    XCTAssertFalse(CompanyCommandAgentAvailability.derive(
      sprintPhase: store.sprintPhase, task: store.tasks[0], presentation: nil,
      isResting: false, attentionRemaining: 0, completedWorkSession: false
    ).canReview)
    XCTAssertTrue(store.pursueFundingOpportunity(id: "pioneer-ai-grant"))
    XCTAssertTrue(store.delegateWorkSession(taskID: id))
    XCTAssertEqual(store.attentionRemaining, 0)
    let rng = store.randomNumberGenerator
    let restored = GameStore()
    restored.continueCareer()
    let task = try XCTUnwrap(restored.tasks.first { $0.id == id })
    XCTAssertTrue(restored.workSession(for: id)?.completed == true)
    XCTAssertFalse(task.isReviewed)
    XCTAssertTrue(CompanyCommandAgentAvailability.derive(
      sprintPhase: restored.sprintPhase, task: task, presentation: nil,
      isResting: false, attentionRemaining: restored.attentionRemaining,
      completedWorkSession: restored.workSession(for: id)?.completed == true
    ).canReview)
    let presentation = PresentationCoordinator()
    presentation.review(taskID: id, in: restored)
    XCTAssertEqual(presentation.presentation(for: agentID)?.reviewRevealStep, 0)
    let projection = LivingAgentProjection.derive(
      agent: try XCTUnwrap(restored.agents.first { $0.id == agentID }),
      task: restored.tasks.first { $0.id == id }, presentation: presentation.presentation(for: agentID),
      isResting: false, isSelected: false, founderStats: restored.stats
    )
    XCTAssertTrue(projection.conditions.intersection([.verified, .overclaimed, .drifting, .evidenceIncomplete]).isEmpty)
    let event = presentation.latestEvent
    let energy = restored.stats.energy
    let evidence = restored.evidence.count
    presentation.review(taskID: id, in: restored)
    XCTAssertEqual(presentation.latestEvent, event)
    XCTAssertEqual(restored.evidence.count, evidence)
    XCTAssertEqual(restored.stats.energy, energy)
    XCTAssertEqual(restored.attentionRemaining, 0)
    XCTAssertEqual(restored.randomNumberGenerator, rng)
    XCTAssertEqual(GameStore.saveVersion, 19)
  }

  func testFounderReviewRevealsFiveFactsInOrder() async throws {
    let store = makeStore(seed: 9_105)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = store.agents[0]
    let presentation = makeFastPresentation()
    presentation.assign(agentID: agent.id, to: task.id, in: store)

    try await Task.sleep(for: .milliseconds(175))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .awaitingReview)
    presentation.review(taskID: task.id, in: store)
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .reviewing)
    XCTAssertEqual(presentation.presentation(for: agent.id)?.reviewRevealStep, 0)

    try await Task.sleep(for: .milliseconds(25))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.reviewRevealStep, 1)
    try await Task.sleep(for: .milliseconds(45))
    XCTAssertEqual(presentation.presentation(for: agent.id)?.reviewRevealStep, 5)
    XCTAssertEqual(presentation.presentation(for: agent.id)?.phase, .reviewed)
    XCTAssertTrue(try XCTUnwrap(store.tasks.first(where: { $0.id == task.id })).isReviewed)
  }

  func testFounderWorkstationSummaryTracksCanonicalReadinessLifecycle() async throws {
    let store = makeStore(seed: 9_106)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let presentation = PresentationCoordinator(timing: .immediate)

    presentation.assign(agentID: agent.id, to: task.id, in: store)
    XCTAssertEqual(
      FounderWorkstationSummary(store: store, presentation: presentation).readiness,
      .workInProgress
    )

    for _ in 0..<100 {
      guard presentation.presentation(for: agent.id)?.phase != .awaitingReview else { break }
      await Task.yield()
    }
    var summary = FounderWorkstationSummary(store: store, presentation: presentation)
    XCTAssertEqual(summary.reviewCount, 1)
    XCTAssertEqual(summary.readiness, .founderReviewPending)

    presentation.review(taskID: task.id, in: store)
    summary = FounderWorkstationSummary(store: store, presentation: presentation)
    XCTAssertEqual(summary.resolutionCount, 1)
    XCTAssertEqual(summary.readiness, .resolutionRequired)

    presentation.resolve(taskID: task.id, choice: .approve, in: store)
    if let choice = store.activeDilemma?.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
    summary = FounderWorkstationSummary(store: store, presentation: presentation)
    XCTAssertEqual(summary.resolutionCount, 0)
    XCTAssertEqual(summary.readiness, .ready)
    XCTAssertTrue(store.canCommitSprint)
  }

  func testSprintReadinessWithNoAssignmentKeepsWorkAndCommitIncomplete() {
    let store = makeStore(seed: 9_110)
    let summary = FounderWorkstationSummary(store: store, presentation: PresentationCoordinator())

    XCTAssertFalse(summary.hasAssignedWork)
    XCTAssertFalse(summary.agentWorkComplete)
    XCTAssertFalse(summary.founderReviewsHandled)
    XCTAssertFalse(summary.resolutionDecisionsLocked)
    XCTAssertFalse(summary.canonicalBlockersCleared)
    XCTAssertFalse(summary.canCommit)
    XCTAssertEqual(store.commitBlockerMessage, "Assign at least one agent before committing the sprint.")
  }

  func testSprintReadinessTracksAssignedWorkUntilPresentationCompletes() throws {
    let store = makeStore(seed: 9_111)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let presentation = PresentationCoordinator()

    presentation.assign(agentID: agent.id, to: task.id, in: store)
    var summary = FounderWorkstationSummary(store: store, presentation: presentation)
    XCTAssertTrue(summary.hasAssignedWork)
    XCTAssertFalse(summary.agentWorkComplete)
    XCTAssertEqual(summary.readiness, .workInProgress)
    XCTAssertFalse(summary.canCommit)

    presentation.skipPresentation(for: agent.id)
    summary = FounderWorkstationSummary(store: store, presentation: presentation)
    XCTAssertTrue(summary.agentWorkComplete)
    XCTAssertFalse(summary.founderReviewsHandled)
    XCTAssertEqual(summary.readiness, .founderReviewPending)
    XCTAssertFalse(summary.canCommit)
  }

  func testSprintReadinessShowsReviewHandledButResolutionUnlocked() throws {
    let store = makeStore(seed: 9_112)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    let presentation = PresentationCoordinator(timing: .immediate)
    presentation.assign(agentID: agent.id, to: task.id, in: store)
    presentation.skipPresentation(for: agent.id)
    presentation.review(taskID: task.id, in: store)

    let summary = FounderWorkstationSummary(store: store, presentation: presentation)
    XCTAssertTrue(summary.agentWorkComplete)
    XCTAssertTrue(summary.founderReviewsHandled)
    XCTAssertFalse(summary.resolutionDecisionsLocked)
    XCTAssertEqual(summary.readiness, .resolutionRequired)
    XCTAssertFalse(summary.canCommit)
  }

  func testSprintReadinessAllowsReviewExhaustionThroughCanonicalAttentionRule() throws {
    let store = makeStore(seed: 9_113)
    if let choice = store.activeDilemma?.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
    for (index, task) in store.tasks.enumerated() {
      store.assign(agentID: store.agents[index].id, to: task.id)
    }
    for task in store.tasks.prefix(store.attentionMaximum) {
      store.review(taskID: task.id)
      store.resolveReviewedTask(taskID: task.id, choice: .approve)
    }

    let summary = FounderWorkstationSummary(store: store, presentation: PresentationCoordinator())
    XCTAssertEqual(store.attentionRemaining, 0)
    XCTAssertGreaterThan(summary.reviewCount, 0)
    XCTAssertTrue(summary.founderReviewsHandled)
    XCTAssertTrue(summary.resolutionDecisionsLocked)
    XCTAssertTrue(summary.canonicalBlockersCleared)
    XCTAssertTrue(summary.canCommit)
  }

  func testSprintReadinessLocksResolutionAndBecomesFullyReady() throws {
    let store = makeStore(seed: 9_114)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    if let choice = store.activeDilemma?.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
    store.assign(agentID: agent.id, to: task.id)
    store.review(taskID: task.id)
    var summary = FounderWorkstationSummary(store: store, presentation: PresentationCoordinator())
    XCTAssertFalse(summary.resolutionDecisionsLocked)
    XCTAssertFalse(summary.canCommit)

    store.resolveReviewedTask(taskID: task.id, choice: .approve)
    summary = FounderWorkstationSummary(store: store, presentation: PresentationCoordinator())
    XCTAssertTrue(summary.agentWorkComplete)
    XCTAssertTrue(summary.founderReviewsHandled)
    XCTAssertTrue(summary.resolutionDecisionsLocked)
    XCTAssertTrue(summary.canonicalBlockersCleared)
    XCTAssertEqual(summary.readiness, .ready)
    XCTAssertTrue(summary.canCommit)
    XCTAssertTrue(store.canCommitSprint)
  }

  func testSprintReadinessRetainsCanonicalDilemmaBlocker() throws {
    let store = makeStore(seed: 9_115)
    let task = try XCTUnwrap(store.tasks.first)
    store.assign(agentID: store.agents[0].id, to: task.id)
    let summary = FounderWorkstationSummary(store: store, presentation: PresentationCoordinator())

    XCTAssertTrue(summary.agentWorkComplete)
    XCTAssertFalse(summary.canonicalBlockersCleared)
    XCTAssertFalse(summary.canCommit)
    XCTAssertEqual(store.commitBlockerMessage, "Choose a response to the founder dilemma before committing.")
  }

  func testFounderSummaryDerivationDoesNotMutateSimulation() throws {
    let store = makeStore(seed: 9_107)
    let presentation = PresentationCoordinator()
    let tasksBefore = store.tasks
    let statsBefore = store.stats
    let evidenceIDsBefore = store.evidence.map(\.id)

    _ = FounderWorkstationSummary(store: store, presentation: presentation)

    XCTAssertEqual(store.tasks, tasksBefore)
    XCTAssertEqual(store.stats, statsBefore)
    XCTAssertEqual(store.evidence.map(\.id), evidenceIDsBefore)
  }

  func testPresentationCoordinatorRejectsDuplicateCommitWhileOutcomeIsActive() async throws {
    let store = makeStore(seed: 9_108)
    let presentation = PresentationCoordinator(timing: .immediate)
    let task = try XCTUnwrap(store.tasks.first)
    let agent = try XCTUnwrap(store.agents.first)
    presentation.assign(agentID: agent.id, to: task.id, in: store)
    for _ in 0..<100 {
      guard presentation.presentation(for: agent.id)?.phase != .awaitingReview else { break }
      await Task.yield()
    }
    presentation.review(taskID: task.id, in: store)
    presentation.resolve(taskID: task.id, choice: .approve, in: store)
    if let choice = store.activeDilemma?.choices.first {
      store.selectDilemmaChoice(choice.id)
    }
    XCTAssertTrue(store.canCommitSprint)

    let progression = FounderProgressionStore(
      defaults: UserDefaults(suiteName: "presentation-commit-once")!,
      saveKey: "progress"
    )
    presentation.commit(in: store, progression: progression)
    let sprintAfterFirstCommit = store.sprint
    let reportID = try XCTUnwrap(store.report?.id)
    let eventID = presentation.latestEvent?.id

    presentation.commit(in: store, progression: progression)

    XCTAssertEqual(store.sprint, sprintAfterFirstCommit)
    XCTAssertEqual(store.report?.id, reportID)
    XCTAssertEqual(presentation.latestEvent?.id, eventID)
    XCTAssertEqual(presentation.visibleSprintResult?.id, reportID)
  }

  #if DEBUG
  func testDebugMotionPreviewDoesNotMutateGameStore() {
    let store = makeStore(seed: 9_104)
    let tasksBefore = store.tasks
    let agentsBefore = store.agents
    let statsBefore = store.stats
    let evidenceIDsBefore = store.evidence.map(\.id)
    let presentation = PresentationCoordinator()

    for phase in PresentationCoordinator.AgentPhase.allCases {
      presentation.stageDebug(phase, agentID: "aurora")
    }

    XCTAssertEqual(store.tasks, tasksBefore)
    XCTAssertEqual(store.agents, agentsBefore)
    XCTAssertEqual(store.stats, statsBefore)
    XCTAssertEqual(store.evidence.map(\.id), evidenceIDsBefore)
  }
  #endif

  // ── Helpers ─────────────────────────────────────────────────────────

  private struct CareerFingerprint {
    var venture: Int
    var sprint: Int
    var stats: FounderStats
    var taskTitles: [String]
    var evidenceIDs: [UUID]
    var agentTrust: [Double]
    var reportSprints: [Int]
  }

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func makeFastPresentation() -> PresentationCoordinator {
    PresentationCoordinator(timing: .init(
      assignmentAcknowledgement: .milliseconds(30),
      working: .milliseconds(100),
      progressTick: .milliseconds(20),
      workComplete: .milliseconds(30),
      reviewFocus: .milliseconds(20),
      reviewStagger: .milliseconds(10),
      resolution: .milliseconds(30)
    ))
  }

  private func playScriptedCareer(seed: UInt64, derivingPresentation: Bool) -> CareerFingerprint {
    let store = makeStore(seed: seed)
    var reportSprints: [Int] = []

    for _ in 0..<6 {
      guard store.careerOutcome == nil, store.pendingVentureCheckpoint == nil else { break }
      store.confirmVentureThesisIfNeeded()
      for (offset, task) in store.tasks.enumerated() {
        let agent = store.agents[offset % store.agents.count]
        store.assign(agentID: agent.id, to: task.id)
        if derivingPresentation { derivePresentation(in: store) }
      }
      if let dilemma = store.activeDilemma, let choice = dilemma.choices.first {
        store.selectDilemmaChoice(choice.id)
      }
      for task in store.tasks where task.result != nil {
        store.review(taskID: task.id)
        if derivingPresentation { derivePresentation(in: store) }
      }
      store.stats.runway = max(store.stats.runway, 80)
      store.stats.energy = max(store.stats.energy, 80)
      store.commitSprint()
      if let report = store.report {
        reportSprints.append(report.sprint)
        if derivingPresentation {
          _ = VisibleSimulationProjection.sprintResult(
            canonicalReport: report,
            venture: store.venture,
            tasks: store.tasks,
            statsBefore: store.stats,
            statsAfter: store.stats,
            evidenceBefore: 0,
            evidenceAfter: store.evidence.count,
            transition: .nextSprint
          )
        }
      }
      store.report = nil
    }

    return CareerFingerprint(
      venture: store.venture,
      sprint: store.sprint,
      stats: store.stats,
      taskTitles: store.tasks.map(\.title),
      evidenceIDs: store.evidence.map(\.id),
      agentTrust: store.agents.map(\.trust),
      reportSprints: reportSprints
    )
  }

  /// Everything a Garage redraw derives, exercised for its side effects — of
  /// which there must be none.
  private func derivePresentation(in store: GameStore) {
    for agent in store.agents {
      let task = store.tasks.first { $0.assignedAgentID == agent.id }
      _ = AgentVisualState.derive(agent: agent, task: task, founderStats: store.stats)
      let station = AgentStationViewModel.derive(agent: agent, task: task, founderStats: store.stats)
      _ = station.accessibilityValue
      _ = station.trustBand
      let gate = GarageTurnGate(phase: store.sprintPhase)
      _ = gate.primary
      _ = gate.stationIsActionable(station)
      _ = gate.stationIsHighlighted(station)
      _ = task?.result.map(VisibleSimulationProjection.taskResult)
    }
  }
}
