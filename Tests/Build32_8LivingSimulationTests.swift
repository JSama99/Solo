import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build32_8LivingSimulationTests: XCTestCase {
  func testMotionPriorityIsDeterministicForIdenticalInput() {
    let candidates = fixtures
    XCTAssertEqual(
      LivingMotionPriorityPolicy.select(candidates),
      LivingMotionPriorityPolicy.select(candidates)
    )
  }

  func testConsequentialMotionSuppressesAmbientMotion() {
    let selection = LivingMotionPriorityPolicy.select([
      .init(kind: .roomAtmosphere, stableID: "room", agentID: nil),
      .init(kind: .rework, stableID: "resolution", agentID: "stacks")
    ])
    XCTAssertEqual(selection.dominant?.kind, .rework)
    XCTAssertEqual(selection.ambientIntensity, .paused)
    XCTAssertTrue(selection.suppressesAmbient)
  }

  func testOnlyOneConsequentialOrMilestoneEventDominates() {
    let selection = LivingMotionPriorityPolicy.select(fixtures)
    XCTAssertEqual(selection.dominant?.kind, .sprintCommitted)
    XCTAssertEqual(selection.ordered.filter { selection.intensity(for: $0) == .dominant }.count, 1)
  }

  func testSimultaneousEqualEventsUseCanonicalAgentOrder() {
    let selection = LivingMotionPriorityPolicy.select([
      .init(kind: .assignmentDispatch, stableID: "c", agentID: "brio"),
      .init(kind: .assignmentDispatch, stableID: "a", agentID: "aurora"),
      .init(kind: .assignmentDispatch, stableID: "b", agentID: "stacks")
    ])
    XCTAssertEqual(selection.ordered.compactMap(\.agentID), ["aurora", "stacks", "brio"])
  }

  func testAgentSignaturesAreDistinctWithoutColor() {
    let signatures = [
      AgentMotionSignature.derive(role: .research),
      AgentMotionSignature.derive(role: .engineering),
      AgentMotionSignature.derive(role: .marketing)
    ]
    XCTAssertEqual(Set(signatures.map(\.rhythm)).count, 3)
    XCTAssertEqual(Set(signatures.map(\.primarySymbol)).count, 3)
    XCTAssertEqual(Set(signatures.map(\.phaseCount)).count, 3)
  }

  func testRoleSignaturesDescribeCanonicalWorkLanguage() {
    XCTAssertTrue(AgentMotionSignature.derive(role: .research).accessibilityDescription.contains("evidence"))
    XCTAssertTrue(AgentMotionSignature.derive(role: .engineering).accessibilityDescription.contains("build"))
    XCTAssertTrue(AgentMotionSignature.derive(role: .marketing).accessibilityDescription.contains("Campaign"))
  }

  func testCompletedArtifactUsesNeutralPreReviewLanguage() throws {
    let object = try XCTUnwrap(causalObject(activity: .awaitingReview))
    XCTAssertEqual(object.kind, .completedArtifact)
    XCTAssertEqual(object.visualLanguage.tone, .neutralProcess)
    XCTAssertEqual(object.visualLanguage.symbol, "doc.text.fill")
    XCTAssertTrue(object.visualLanguage.accessibilityDescription.contains("correctness unknown"))
    XCTAssertFalse(object.visualLanguage.accessibilityDescription.localizedCaseInsensitiveContains("verified"))
  }

  func testPreReviewHiddenVariantsSelectIdenticalMotion() {
    let variants = [
      result(actual: 15, reported: 90, evidence: 20, verification: .overclaimed),
      result(actual: 95, reported: 95, evidence: 100, verification: .verified),
      result(actual: 40, reported: 60, evidence: 45, verification: .driftDetected),
      result(actual: nil, reported: 72, evidence: 22, verification: .evidenceIncomplete)
    ]
    let values = variants.map { hiddenResult in
      let projection = projection(
        activity: .awaitingReview,
        task: task(reviewed: false, result: hiddenResult),
        revealStep: 0
      )
      return (
        projection.activity,
        projection.conditions,
        FounderGarageStationMotion.derive(
          agent: projection,
          reduceMotion: false,
          sceneActive: true
        ).workflow,
        CompanyCausalObject.project(agent: projection, reduceMotion: false)?.visualLanguage
      )
    }
    for value in values.dropFirst() {
      XCTAssertEqual(value.0, values[0].0)
      XCTAssertEqual(value.1, values[0].1)
      XCTAssertEqual(value.2, values[0].2)
      XCTAssertEqual(value.3, values[0].3)
    }
  }

  func testReduceMotionPreservesAssignmentAndReturnEndpoints() throws {
    let assignment = try XCTUnwrap(causalObject(activity: .assignmentReceived, reduceMotion: true))
    let artifact = try XCTUnwrap(causalObject(activity: .workComplete, reduceMotion: true))
    XCTAssertTrue(assignment.atEndpoint)
    XCTAssertEqual(assignment.end, .roleMonitor("aurora"))
    XCTAssertTrue(artifact.atEndpoint)
    XCTAssertEqual(artifact.end, .founderTray)
  }

  func testApproveUsesCanonicalAffectedSystemPath() throws {
    let object = try XCTUnwrap(causalObject(activity: .resolving, choice: .approve))
    XCTAssertEqual(object.end, .companySystem(.auroraFounderVerificationBridge))
    XCTAssertEqual(object.visualLanguage.symbol, TaskResolutionChoice.approve.symbol)
  }

  func testReworkReturnsArtifactToResponsibleAgent() throws {
    let object = try XCTUnwrap(causalObject(activity: .resolving, choice: .rework, agentID: "stacks", role: .engineering))
    XCTAssertEqual(object.end, .roleMonitor("stacks"))
    XCTAssertEqual(object.visualLanguage.shapeName, "return arrow")
  }

  func testCrossCheckUsesCanonicalVerificationBridge() throws {
    let object = try XCTUnwrap(causalObject(activity: .resolving, choice: .escalate, agentID: "brio", role: .marketing))
    XCTAssertEqual(object.end, .companySystem(.auroraFounderVerificationBridge))
    XCTAssertEqual(object.visualLanguage.shapeName, "cross-check bridge")
  }

  func testShipAnywayUsesAffectedSystemAndOutboundShape() throws {
    let object = try XCTUnwrap(causalObject(activity: .resolving, choice: .shipAnyway, agentID: "brio", role: .marketing))
    XCTAssertEqual(object.end, .companySystem(.brioBroadcastRail))
    XCTAssertEqual(object.visualLanguage.shapeName, "outbound dispatch")
  }

  func testResolutionRecapIncludesOnlyKnownImmediateChanges() {
    var before = VisibleCompanySnapshot()
    before.energy = 80
    before.runway = 30
    var after = before
    after.energy = 76
    after.runway = 29
    let recap = LivingCausalRecap.derive(
      taskID: stableTaskID,
      taskTitle: "Build launch system",
      agentName: "Stacks",
      choice: .rework,
      before: before,
      after: after,
      relationshipBefore: 60,
      relationshipAfter: 62
    )
    XCTAssertEqual(recap.visibleConsequences, ["Energy -4", "Runway -1"])
    XCTAssertEqual(recap.agentReaction, "Stacks relationship +2")
    XCTAssertEqual(recap.followUpDevice, .computer)
    XCTAssertFalse(recap.accessibilityAnnouncement.localizedCaseInsensitiveContains("quality"))
    XCTAssertFalse(recap.accessibilityAnnouncement.localizedCaseInsensitiveContains("risk"))
  }

  func testResolutionRecapIsStableAcrossRepeatedDerivation() {
    let before = VisibleCompanySnapshot()
    let first = LivingCausalRecap.derive(
      taskID: stableTaskID,
      taskTitle: "Research",
      agentName: "Aurora",
      choice: .approve,
      before: before,
      after: before,
      relationshipBefore: 50,
      relationshipAfter: 50
    )
    let second = LivingCausalRecap.derive(
      taskID: stableTaskID,
      taskTitle: "Research",
      agentName: "Aurora",
      choice: .approve,
      before: before,
      after: before,
      relationshipBefore: 50,
      relationshipAfter: 50
    )
    XCTAssertEqual(first, second)
  }

  func testObscuredEnvironmentSuspendsContinuousMotion() {
    let projection = projection(activity: .working)
    let environment = FounderEnvironmentProjection(
      facility: .founderGarage,
      atmosphere: .derive(stats: FounderStats(), facility: .founderGarage, venture: 1),
      infrastructure: [],
      agents: [projection]
    )
    let motion = FounderGarageMotionPresentation.derive(
      environment: environment,
      camera: .init(mode: .computerFocused),
      reduceMotion: false,
      sceneActive: false
    )
    XCTAssertFalse(motion.ambient.continuousMotionEnabled)
    XCTAssertFalse(try! XCTUnwrap(motion.station(for: "aurora")).continuousMotionEnabled)
  }

  func testReducedMotionPausesContinuousStationAndAmbientMotion() {
    let projection = projection(activity: .working)
    let environment = FounderEnvironmentProjection(
      facility: .founderGarage,
      atmosphere: .derive(stats: FounderStats(), facility: .founderGarage, venture: 1),
      infrastructure: [],
      agents: [projection]
    )
    let motion = FounderGarageMotionPresentation.derive(
      environment: environment,
      camera: .init(mode: .freeLook),
      reduceMotion: true,
      sceneActive: true
    )
    XCTAssertFalse(motion.ambient.continuousMotionEnabled)
    XCTAssertFalse(try! XCTUnwrap(motion.station(for: "aurora")).continuousMotionEnabled)
  }

  func testPrioritySubordinatesNonDominantAgentMotion() {
    let agents = [
      projection(activity: .awaitingReview, agentID: "aurora", role: .research),
      projection(activity: .working, agentID: "stacks", role: .engineering),
      projection(activity: .working, agentID: "brio", role: .marketing)
    ]
    let environment = FounderEnvironmentProjection(
      facility: .founderGarage,
      atmosphere: .derive(stats: FounderStats(), facility: .founderGarage, venture: 1),
      infrastructure: [],
      agents: agents,
      visibleEvent: .review(id: stableTaskID, agentID: "aurora")
    )
    let motion = FounderGarageMotionPresentation.derive(
      environment: environment,
      camera: .init(mode: .freeLook),
      reduceMotion: false,
      sceneActive: true
    )
    XCTAssertEqual(motion.priority.dominant?.agentID, "aurora")
    XCTAssertFalse(try! XCTUnwrap(motion.station(for: "stacks")).continuousMotionEnabled)
    XCTAssertFalse(try! XCTUnwrap(motion.station(for: "brio")).continuousMotionEnabled)
  }

  func testPresentationProjectionCannotMutateCanonicalStore() {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: 32_800)
    store.confirmVentureThesisIfNeeded()
    let stats = store.stats
    let tasks = store.tasks
    let agents = store.agents
    _ = AgentMotionSignature.derive(role: .research)
    _ = LivingMotionPriorityPolicy.select(fixtures)
    _ = LivingCausalRecap.derive(
      taskID: stableTaskID,
      taskTitle: "Visible task",
      agentName: "Aurora",
      choice: .approve,
      before: .init(stats: store.stats),
      after: .init(stats: store.stats),
      relationshipBefore: 55,
      relationshipAfter: 55
    )
    XCTAssertEqual(store.stats, stats)
    XCTAssertEqual(store.tasks, tasks)
    XCTAssertEqual(store.agents, agents)
  }

  private var stableTaskID: UUID {
    UUID(uuidString: "32800000-0000-0000-0000-000000000001")!
  }

  private var fixtures: [LivingMotionCandidate] {
    [
      .init(kind: .roomAtmosphere, stableID: "room", agentID: nil),
      .init(kind: .assignmentDispatch, stableID: "assign", agentID: "aurora"),
      .init(kind: .rework, stableID: "resolve", agentID: "stacks"),
      .init(kind: .sprintCommitted, stableID: "sprint", agentID: nil)
    ]
  }

  private func causalObject(
    activity: LivingAgentActivity,
    choice: TaskResolutionChoice? = nil,
    agentID: String = "aurora",
    role: AgentRole = .research,
    reduceMotion: Bool = false
  ) -> CompanyCausalObject? {
    CompanyCausalObject.project(
      agent: projection(activity: activity, agentID: agentID, role: role, choice: choice),
      reduceMotion: reduceMotion
    )
  }

  private func projection(
    activity: LivingAgentActivity,
    agentID: String = "aurora",
    role: AgentRole = .research,
    choice: TaskResolutionChoice? = nil,
    task: SoloTask? = nil,
    revealStep: Int = 0
  ) -> LivingAgentProjection {
    if let task {
      let agent = SoloAgent(
        id: agentID,
        name: agentID.capitalized,
        initials: String(agentID.prefix(2)).uppercased(),
        role: role,
        modelFamily: "Visible",
        reliability: 80,
        calibration: 0.75,
        drift: 0,
        trust: 70
      )
      let phase: PresentationCoordinator.AgentPhase = switch activity {
      case .idle, .resting: .idle
      case .assignmentReceived: .assignmentReceived
      case .working: .working
      case .workComplete: .workComplete
      case .awaitingReview: .awaitingReview
      case .reviewing: .reviewing
      case .reviewed: .reviewed
      case .resolving: .resolving
      case .resolved: .resolved
      }
      return LivingAgentProjection.derive(
        agent: agent,
        task: task,
        presentation: .init(
          taskID: task.id,
          agentID: agentID,
          taskTitle: task.title,
          phase: phase,
          progress: activity == .working ? 0.5 : 1,
          reviewRevealStep: revealStep,
          resolutionChoice: choice
        ),
        isResting: activity == .resting,
        isSelected: false,
        founderStats: FounderStats()
      )
    }
    return LivingAgentProjection(
      agentID: agentID,
      name: agentID.capitalized,
      initials: String(agentID.prefix(2)).uppercased(),
      role: role,
      taskID: activity == .idle || activity == .resting ? nil : stableTaskID,
      taskTitle: activity == .idle || activity == .resting ? nil : "Visible task",
      activity: activity,
      conditions: activity == .working ? [.focused] : [],
      emphasis: activity == .awaitingReview ? .founderAttention : .normal,
      progress: activity == .working ? 0.5 : 1,
      reviewRevealStep: revealStep,
      stressLabel: "Stable",
      trustLabel: "Trusted",
      level: 2,
      needsFounderAttention: [.workComplete, .awaitingReview, .reviewing].contains(activity),
      isResting: activity == .resting,
      resolutionChoice: choice
    )
  }

  private func task(reviewed: Bool, result: TaskResult) -> SoloTask {
    SoloTask(
      id: stableTaskID,
      title: "Visible task",
      detail: "Visible process state",
      role: .research,
      impact: .trust(2),
      assignedAgentID: "aurora",
      isReviewed: reviewed,
      result: result
    )
  }

  private func result(
    actual: Int?,
    reported: Int,
    evidence: Int,
    verification: VerificationState
  ) -> TaskResult {
    TaskResult(
      actualQuality: actual ?? 0,
      reportedQuality: reported,
      verificationState: verification,
      evidenceCompleteness: evidence,
      correlatedFailureIdentifier: verification == .driftDetected ? "hidden" : nil,
      immediateEffects: SimulationEffects(),
      delayedEffects: SimulationEffects(),
      confidenceLowerBound: max(0, reported - 10),
      confidenceUpperBound: min(100, reported + 10),
      knownOperationalRisk: "Hidden until review"
    )
  }
}
