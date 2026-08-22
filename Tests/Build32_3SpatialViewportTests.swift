import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build32_3SpatialViewportTests: XCTestCase {
  func testOverviewAndExplicitFocusHierarchy() {
    let idle = projection(id: "aurora", phase: .idle)
    XCTAssertNil(CompanyPhaseHierarchy.dominantAgentID(agents: [idle], explicitFocus: nil))
    XCTAssertEqual(CompanyPhaseHierarchy.dominantAgentID(agents: [idle], explicitFocus: .agent("aurora")), "aurora")
  }

  func testDominantActiveStationSelectionIsStableAndNotEqualBrightness() {
    let aurora = projection(id: "aurora", phase: .working, progress: 0.35)
    let stacks = projection(id: "stacks", phase: .working, progress: 0.78)
    let brio = projection(id: "brio", phase: .idle)
    XCTAssertEqual(
      CompanyPhaseHierarchy.dominantAgentID(agents: [aurora, stacks, brio], explicitFocus: nil),
      "stacks"
    )
    XCTAssertEqual(
      CompanyPhaseHierarchy.dominantAgentID(agents: [brio, stacks, aurora], explicitFocus: nil),
      "stacks"
    )
  }

  func testReviewResolutionAndCommitHierarchy() {
    let review = projection(id: "aurora", phase: .reviewing, revealStep: 3)
    XCTAssertEqual(hierarchy(phase: .reviewAndResolve, agents: [review], reviews: 1).priority, .review)
    let resolution = projection(id: "aurora", phase: .resolving)
    XCTAssertEqual(hierarchy(phase: .reviewAndResolve, agents: [resolution], resolutions: 1).priority, .resolution)
    XCTAssertEqual(hierarchy(phase: .readyToCommit, agents: []).priority, .commit)
  }

  func testCausalObjectTypesAreDistinct() throws {
    let assignment = try XCTUnwrap(CompanyCausalObject.project(
      agent: projection(id: "aurora", phase: .assignmentReceived),
      reduceMotion: false
    ))
    let completion = try XCTUnwrap(CompanyCausalObject.project(
      agent: projection(id: "aurora", phase: .workComplete),
      reduceMotion: false
    ))
    let resolution = try XCTUnwrap(CompanyCausalObject.project(
      agent: projection(id: "aurora", phase: .resolving),
      reduceMotion: false
    ))
    XCTAssertEqual(Set([assignment.kind, completion.kind, resolution.kind]).count, 3)
    XCTAssertEqual(Set([assignment.id, completion.id, resolution.id]).count, 3)
  }

  func testAssignmentArtifactAndResolutionIdentityRemainStable() throws {
    for phase in [
      PresentationCoordinator.AgentPhase.assignmentReceived,
      .workComplete,
      .resolving
    ] {
      let agent = projection(id: "aurora", phase: phase)
      let normal = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: false))
      let reduced = try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: true))
      XCTAssertEqual(normal.id, reduced.id)
      XCTAssertEqual(normal.taskID, reduced.taskID)
      XCTAssertFalse(normal.atEndpoint)
      XCTAssertTrue(reduced.atEndpoint)
    }
  }

  func testSettledCausalEndpointsMatchSkipAndReduceMotionPolicy() throws {
    for phase in [
      PresentationCoordinator.AgentPhase.awaitingReview,
      .reviewed,
      .resolved
    ] {
      let agent = projection(id: "aurora", phase: phase)
      XCTAssertTrue(try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: false)).atEndpoint)
      XCTAssertTrue(try XCTUnwrap(CompanyCausalObject.project(agent: agent, reduceMotion: true)).atEndpoint)
    }
  }

  func testReviewStepSecrecyAndVisualDistinctionMapping() {
    let hiddenConditions: Set<LivingAgentCondition> = [.overclaimed]
    XCTAssertEqual(ReviewResultVisual.map(conditions: hiddenConditions, revealStep: 4), .pending)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.verified], revealStep: 5), .verified)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.overclaimed], revealStep: 5), .overclaimed)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.drifting], revealStep: 5), .driftDetected)
    XCTAssertEqual(ReviewResultVisual.map(conditions: [.evidenceIncomplete], revealStep: 5), .evidenceIncomplete)
    XCTAssertEqual(
      Set(ReviewResultVisual.allCases.filter { $0 != .pending }.map(\.rawValue)).count,
      4
    )
  }

  func testInfrastructurePhysicalLocationsAreCompleteAndUnique() {
    let locations = FacilityUpgradeID.allCases.map(InfrastructurePhysicalLocation.map)
    XCTAssertEqual(Set(locations.map(\.rawValue)).count, FacilityUpgradeID.allCases.count)
    XCTAssertEqual(InfrastructurePhysicalLocation.map(.developmentRig), .stacksBuildRail)
    XCTAssertEqual(InfrastructurePhysicalLocation.map(.verificationArray), .auroraFounderVerificationBridge)
    XCTAssertEqual(InfrastructurePhysicalLocation.map(.campaignStudio), .brioBroadcastRail)
    XCTAssertEqual(InfrastructurePhysicalLocation.map(.recoveryCorner), .recoverySideBay)
    XCTAssertEqual(InfrastructurePhysicalLocation.map(.founderCommandDesk), .founderForegroundDesk)
  }

  func testInfrastructureFourStateMapping() throws {
    let activeStacks = projection(id: "stacks", phase: .working)
    let mapped = InfrastructureVisual.map(
      purchased: [.developmentRig, .campaignStudio],
      facility: .founderGarage,
      agents: [activeStacks],
      sprint: 1,
      installing: [.verificationArray]
    )
    XCTAssertEqual(try item(.developmentRig, in: mapped).state, .active)
    XCTAssertEqual(try item(.campaignStudio, in: mapped).state, .installed)
    XCTAssertEqual(try item(.verificationArray, in: mapped).state, .installing)
    XCTAssertEqual(try item(.recoveryCorner, in: mapped).state, .uninstalled)
  }

  func testGarageAndLoftIdentityIsStructuralNotAtmosphereColor() {
    XCTAssertEqual(CompanySpatialPresentation.map(.founderGarage), .improvisedGarage)
    XCTAssertEqual(CompanySpatialPresentation.map(.founderLoft), .elevatedLoft)
    XCTAssertNotEqual(
      CompanySpatialPresentation.map(.founderGarage),
      CompanySpatialPresentation.map(.founderLoft)
    )
  }

  func testLocalizedAtmosphereMapping() {
    XCTAssertEqual(atmosphere(runway: 7).localizedReaction, .runwayDepletion)
    XCTAssertEqual(atmosphere(energy: 30).localizedReaction, .selectivePowerDown)
    XCTAssertEqual(atmosphere(trust: 20).localizedReaction, .publicSignalInterference)
    XCTAssertEqual(atmosphere(momentum: 70).localizedReaction, .connectedMomentum)
    XCTAssertEqual(atmosphere().localizedReaction, .stable)
  }

  func testTextPriorityProjectionRetainsOnlySafeOverviewStrings() {
    let text = ViewportTextPriorityProjection.build32_3
    XCTAssertEqual(text.visibleOverviewFields, [
      "agentName", "safeActivity", "taskTitle", "primaryAction", "criticalWarning"
    ])
    XCTAssertFalse(text.visibleOverviewFields.contains("actualQuality"))
    XCTAssertTrue(text.focusOnlyFields.contains("stress"))
    XCTAssertTrue(text.accessibilityOnlyFields.contains("causalJourney"))
  }

  func testAccessibilityStringsRemainVisibleSafeBeforeFinalReveal() {
    let concealed = projection(id: "aurora", phase: .reviewing, revealStep: 4)
    XCTAssertFalse(concealed.accessibilityValue.localizedCaseInsensitiveContains("actual quality"))
    XCTAssertFalse(concealed.accessibilityValue.localizedCaseInsensitiveContains("overclaim"))
    XCTAssertFalse(concealed.name.isEmpty)
    XCTAssertFalse(concealed.activity.label.isEmpty)
  }

  func testFocusAndFullWorkstationBehaviorRemainIndependent() {
    var state = CompanyCommandInteractionState()
    state.toggleFocus(.agent("stacks"))
    XCTAssertNil(state.navigationRequest)
    state.requestFullWorkstation(.agent("stacks"))
    XCTAssertEqual(state.focus, .agent("stacks"))
    XCTAssertEqual(state.navigationRequest?.target.scrollID, "stacks")
  }

  func testSameSeedAndSaveCompatibilityAreUnaffectedByPresentationProjection() throws {
    let first = makeStore(seed: 32_300)
    let second = makeStore(seed: 32_300)
    _ = CompanyPhaseHierarchy.dominantAgentID(agents: [], explicitFocus: .founder)
    XCTAssertEqual(first.tasks, second.tasks)
    XCTAssertEqual(first.agents, second.agents)
    XCTAssertEqual(first.stats, second.stats)

    let legacy = """
      {"version":1,"currentFacility":0,"ownedFacilities":[0],"highestTrackRecord":4,"completedCareerCount":0,"recordedCareerIDs":[]}
      """.data(using: .utf8)!
    XCTAssertNoThrow(try JSONDecoder().decode(FounderProgressionSave.self, from: legacy))
  }

  private func item(
    _ id: FacilityUpgradeID,
    in items: [InfrastructureVisual]
  ) throws -> InfrastructureVisual {
    try XCTUnwrap(items.first { $0.id == id })
  }

  private func atmosphere(
    runway: Int = 42,
    energy: Int = 82,
    trust: Int = 68,
    momentum: Int = 18
  ) -> CompanyAtmosphere {
    var stats = FounderStats()
    stats.runway = runway
    stats.energy = energy
    stats.trust = trust
    stats.momentum = momentum
    return CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1)
  }

  private func projection(
    id: String,
    phase: PresentationCoordinator.AgentPhase,
    progress: Double = 0.5,
    revealStep: Int = 0
  ) -> LivingAgentProjection {
    let role: AgentRole = id == "stacks" ? .engineering : (id == "brio" ? .marketing : .research)
    let agent = SoloAgent(
      id: id,
      name: id.capitalized,
      initials: String(id.prefix(2)).uppercased(),
      role: role,
      modelFamily: "Visible Family",
      reliability: 82,
      calibration: 0.76,
      drift: 0,
      trust: 72
    )
    let taskID = UUID(uuidString: "32300000-0000-0000-0000-000000000001")!
    let task = SoloTask(
      id: taskID,
      title: "Visible Task",
      detail: "Visible task detail.",
      role: role,
      impact: .momentum(4),
      assignedAgentID: id,
      isReviewed: [.reviewing, .reviewed, .resolving, .resolved].contains(phase),
      result: TaskResult(
        actualQuality: 72,
        reportedQuality: 74,
        evidenceCompleteness: 90,
        correlatedFailureIdentifier: nil,
        immediateEffects: SimulationEffects(),
        delayedEffects: SimulationEffects(),
        confidenceLowerBound: 68,
        confidenceUpperBound: 80,
        knownOperationalRisk: "Visible risk"
      ),
      resolutionLocked: phase == .resolved
    )
    let presentation = PresentationCoordinator.AgentPresentation(
      taskID: taskID,
      agentID: id,
      taskTitle: task.title,
      phase: phase,
      progress: progress,
      reviewRevealStep: revealStep,
      sequenceID: UUID(uuidString: "32300000-0000-0000-0000-000000000002")!
    )
    return LivingAgentProjection.derive(
      agent: agent,
      task: task,
      presentation: presentation,
      isResting: false,
      isSelected: false,
      founderStats: FounderStats()
    )
  }

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func hierarchy(
    phase: SprintPhase,
    agents: [LivingAgentProjection],
    reviews: Int = 0,
    resolutions: Int = 0
  ) -> CompanyPhaseHierarchy {
    CompanyPhaseHierarchy.derive(
      sprintPhase: phase,
      agents: agents,
      founderSummary: CompanyCommandFounderSummary(
        sprintPhase: phase,
        workInProgressCount: 0,
        reviewCount: reviews,
        resolutionCount: resolutions,
        attentionRemaining: 2,
        attentionMaximum: 2,
        canCommit: phase == .readyToCommit,
        nextAction: "Visible action"
      )
    )
  }
}
