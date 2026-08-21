import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build32_2VisualBehaviorTests: XCTestCase {
  func testAllPostReviewConditionsDeriveIndependently() {
    let expected: [(VerificationState, LivingAgentCondition)] = [
      (.confirmed, .verified),
      (.verified, .verified),
      (.overclaimed, .overclaimed),
      (.driftDetected, .drifting),
      (.evidenceIncomplete, .evidenceIncomplete)
    ]
    for (verification, condition) in expected {
      let projection = derive(
        task: task(reviewed: true, result: result(verification: verification)),
        presentation: presentation(.reviewed, reviewStep: 5)
      )
      XCTAssertTrue(projection.conditions.contains(condition), "Missing \(condition) for \(verification)")
      XCTAssertEqual(projection.activity, .reviewed)
    }
  }

  func testActivityConditionAndEmphasisRemainIndependent() {
    var agent = makeAgent()
    agent.progression.stressLevel = 61
    let projection = LivingAgentProjection.derive(
      agent: agent,
      task: nil,
      presentation: nil,
      isResting: false,
      isSelected: true,
      founderStats: FounderStats()
    )
    XCTAssertEqual(projection.activity, .idle)
    XCTAssertEqual(projection.emphasis, .selected)
    XCTAssertEqual(projection.conditions, [.stressed])
  }

  func testEmphasisPrecedenceIsDeterministic() {
    let selectedReview = derive(task: task(reviewed: true), presentation: presentation(.reviewing, reviewStep: 4), selected: true)
    XCTAssertEqual(selectedReview.emphasis, .inspection)
    let attention = derive(task: task(), presentation: presentation(.awaitingReview), selected: true)
    XCTAssertEqual(attention.emphasis, .founderAttention)
    let decision = derive(task: task(reviewed: true), presentation: presentation(.resolving, reviewStep: 5), selected: true)
    XCTAssertEqual(decision.emphasis, .decisionLock)
    let celebration = derive(task: task(reviewed: true), presentation: presentation(.reviewing, reviewStep: 5), selected: true, levelUp: true)
    XCTAssertEqual(celebration.emphasis, .levelUpCelebration)
  }

  func testHiddenTruthAndAccessibilityStaySealedThroughFirstFourSteps() {
    for step in 1...4 {
      let projection = derive(
        task: task(reviewed: true, result: result(verification: .overclaimed)),
        presentation: presentation(.reviewing, reviewStep: step)
      )
      XCTAssertTrue(projection.conditions.intersection([.verified, .overclaimed, .drifting, .evidenceIncomplete]).isEmpty)
      XCTAssertFalse(projection.accessibilityValue.localizedCaseInsensitiveContains("overclaim"))
      XCTAssertFalse(projection.accessibilityValue.localizedCaseInsensitiveContains("actual"))
    }
  }

  func testTaskAndArtifactIdentityRemainStableAcrossCausalChain() {
    let taskID = UUID(uuidString: "32000000-0000-0000-0000-000000000099")!
    var assigned = presentation(.assignmentReceived, taskID: taskID)
    let packet = derive(task: task(id: taskID), presentation: assigned)
    assigned.phase = .awaitingReview
    assigned.progress = 1
    let artifact = derive(task: task(id: taskID), presentation: assigned)
    XCTAssertEqual(packet.taskID, taskID)
    XCTAssertEqual(artifact.taskID, taskID)
    XCTAssertEqual(packet.agentID, artifact.agentID)
  }

  func testRestingPrecedenceClearsVisibleProgressAndFocus() {
    let projection = LivingAgentProjection.derive(
      agent: makeAgent(),
      task: task(),
      presentation: presentation(.working),
      isResting: true,
      isSelected: true,
      founderStats: FounderStats()
    )
    XCTAssertEqual(projection.activity, .resting)
    XCTAssertEqual(projection.progress, 0)
    XCTAssertFalse(projection.conditions.contains(.focused))
    XCTAssertEqual(projection.emphasis, .selected)
  }

  func testPhaseHierarchyMapsPlanningWorkingReviewResolutionAndCommit() {
    let planning = hierarchy(agents: [fixtureProjection(activity: .idle)], phase: .assignTeam)
    let working = hierarchy(agents: [fixtureProjection(activity: .working)], phase: .assignTeam)
    let review = hierarchy(agents: [fixtureProjection(activity: .awaitingReview)], phase: .reviewAndResolve, reviews: 1)
    let resolution = hierarchy(agents: [fixtureProjection(activity: .reviewed)], phase: .reviewAndResolve, resolutions: 1)
    let commit = hierarchy(agents: [fixtureProjection(activity: .idle)], phase: .readyToCommit, canCommit: true)
    XCTAssertEqual([planning.priority, working.priority, review.priority, resolution.priority, commit.priority], [.planning, .working, .review, .resolution, .commit])
    XCTAssertEqual(planning.taskProminence, 1)
    XCTAssertEqual(working.stationProminence, 1)
    XCTAssertEqual(review.founderTrayProminence, 1)
    XCTAssertEqual(resolution.decisionProminence, 1)
    XCTAssertEqual(commit.commitProminence, 1)
  }

  func testInfrastructureSupportsAllFourStatesAndStableSlotOrder() {
    let working = fixtureProjection(id: "stacks", role: .engineering, activity: .working)
    let values = InfrastructureVisual.map(
      purchased: [.developmentRig, .campaignStudio],
      facility: .founderGarage,
      agents: [working],
      sprint: 2,
      installing: [.verificationArray]
    )
    XCTAssertEqual(values.map(\.id), FacilityUpgradeDefinition.all.map(\.id))
    XCTAssertEqual(values.first(where: { $0.id == .developmentRig })?.state, .active)
    XCTAssertEqual(values.first(where: { $0.id == .verificationArray })?.state, .installing)
    XCTAssertEqual(values.first(where: { $0.id == .campaignStudio })?.state, .installed)
    XCTAssertEqual(values.first(where: { $0.id == .recoveryCorner })?.state, .uninstalled)
  }

  func testInstallationCompletionTransitionsToInstalled() {
    let installing = InfrastructureVisual.map(purchased: [], facility: .founderGarage, agents: [], sprint: 1, installing: [.developmentRig])
    let installed = InfrastructureVisual.map(purchased: [.developmentRig], facility: .founderGarage, agents: [], sprint: 1)
    XCTAssertEqual(installing.first?.state, .installing)
    XCTAssertEqual(installed.first?.state, .installed)
  }

  func testEveryUpgradeRelevantActiveMappingUsesExistingContext() {
    let agents = [
      fixtureProjection(id: "aurora", role: .research, activity: .working),
      fixtureProjection(id: "stacks", role: .engineering, activity: .working),
      fixtureProjection(id: "brio", role: .marketing, activity: .working),
      fixtureProjection(id: "resting", role: .general, activity: .resting)
    ]
    let mapped = InfrastructureVisual.map(purchased: Set(FacilityUpgradeID.allCases), facility: .founderGarage, agents: agents, sprint: 3)
    XCTAssertTrue(mapped.allSatisfy { $0.state == .active })
    let loft = InfrastructureVisual.map(purchased: Set(FacilityUpgradeID.allCases), facility: .founderLoft, agents: agents, sprint: 3)
    XCTAssertTrue(loft.allSatisfy { $0.state == .installed })
  }

  func testAtmosphereThresholdsAreIndependentAndInclusive() {
    var stats = FounderStats()
    stats.energy = 38
    stats.runway = 8
    stats.trust = 24
    stats.momentum = 70
    let atmosphere = CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1)
    XCTAssertTrue(atmosphere.isLowEnergy)
    XCTAssertTrue(atmosphere.isLowRunway)
    XCTAssertTrue(atmosphere.isLowTrust)
    XCTAssertTrue(atmosphere.isHighMomentum)
    XCTAssertTrue(atmosphere.accessibilitySummary.contains("Low Runway"))
  }

  func testFacilityPresentationMappingDoesNotChangeAtmosphereSignals() {
    var stats = FounderStats()
    stats.energy = 20
    let garage = CompanyAtmosphere.derive(stats: stats, facility: .founderGarage, venture: 1)
    let loft = CompanyAtmosphere.derive(stats: stats, facility: .founderLoft, venture: 1)
    XCTAssertNotEqual(garage.facility, loft.facility)
    XCTAssertEqual(garage.isLowEnergy, loft.isLowEnergy)
    XCTAssertEqual(garage.isLowRunway, loft.isLowRunway)
  }

  #if DEBUG
  func testMotionQACoversEveryRequiredProductionFixture() {
    XCTAssertEqual(LivingCompanyFixture.ID.allCases.count, 46)
    XCTAssertEqual(Set(LivingCompanyFixture.ID.allCases.map(\.rawValue)).count, 46)
    for id in LivingCompanyFixture.ID.allCases {
      let fixture = LivingCompanyFixture.make(id)
      XCTAssertEqual(fixture.agents.map(\.agentID), ["aurora", "stacks", "brio"])
      XCTAssertEqual(fixture.infrastructure.map(\.id), FacilityUpgradeDefinition.all.map(\.id))
    }
    XCTAssertEqual(LivingCompanyFixture.causalProofSequence.first, .planningPhase)
    XCTAssertEqual(LivingCompanyFixture.causalProofSequence.last, .commitReady)
    XCTAssertTrue(Set([
      .auroraAssignment,
      .auroraWorking,
      .workComplete,
      .awaitingReview,
      .reviewStep1,
      .reviewStep2,
      .reviewStep3,
      .reviewStep4,
      .reviewStep5,
      .verified,
      .resolving,
      .resolved
    ]).isSubset(of: Set(LivingCompanyFixture.causalProofSequence)))
  }

  func testReduceMotionFixtureUsesSameVisibleEndpointAsResolvedFixture() {
    let fixture = LivingCompanyFixture.make(.reduceMotion)
    XCTAssertTrue(fixture.forceReduceMotion)
    XCTAssertTrue(fixture.agents.allSatisfy { $0.activity == .idle && $0.progress == 0 })
  }

  func testWarningFixturesRemainVisuallyAndSemanticallyDistinct() {
    let overclaim = LivingCompanyFixture.make(.overclaimed).agents.first(where: { $0.agentID == "aurora" })!
    let drift = LivingCompanyFixture.make(.driftDetected).agents.first(where: { $0.agentID == "brio" })!
    let incomplete = LivingCompanyFixture.make(.evidenceIncomplete).agents.first(where: { $0.agentID == "aurora" })!
    XCTAssertEqual(overclaim.conditions, [.overclaimed])
    XCTAssertEqual(drift.conditions, [.drifting])
    XCTAssertEqual(incomplete.conditions, [.evidenceIncomplete])
    XCTAssertNotEqual(overclaim.accessibilityValue, incomplete.accessibilityValue)
  }
  #endif

  private func derive(
    task: SoloTask?,
    presentation: PresentationCoordinator.AgentPresentation?,
    selected: Bool = false,
    levelUp: Bool = false
  ) -> LivingAgentProjection {
    LivingAgentProjection.derive(
      agent: makeAgent(),
      task: task,
      presentation: presentation,
      isResting: false,
      isSelected: selected,
      founderStats: FounderStats(),
      celebratingLevelUp: levelUp
    )
  }

  private func makeAgent() -> SoloAgent {
    SoloAgent(id: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Visible", reliability: 82, calibration: 0.78, drift: 0, trust: 74)
  }

  private func task(id: UUID = UUID(), reviewed: Bool = false, result: TaskResult? = nil) -> SoloTask {
    SoloTask(id: id, title: "Validate launch evidence", detail: "Visible task", role: .research, impact: .momentum(4), assignedAgentID: "aurora", isReviewed: reviewed, result: result ?? self.result(verification: reviewed ? .confirmed : .reported))
  }

  private func result(verification: VerificationState) -> TaskResult {
    TaskResult(actualQuality: 68, reportedQuality: verification == .overclaimed ? 82 : 70, verificationState: verification, evidenceCompleteness: verification == .evidenceIncomplete ? 30 : 88, correlatedFailureIdentifier: verification == .driftDetected ? "visible-drift" : nil, immediateEffects: SimulationEffects(), delayedEffects: SimulationEffects(), confidenceLowerBound: 62, confidenceUpperBound: 76, knownOperationalRisk: "Visible risk")
  }

  private func presentation(_ phase: PresentationCoordinator.AgentPhase, reviewStep: Int = 0, taskID: UUID = UUID()) -> PresentationCoordinator.AgentPresentation {
    PresentationCoordinator.AgentPresentation(taskID: taskID, agentID: "aurora", taskTitle: "Validate launch evidence", phase: phase, progress: phase == .idle ? 0 : 0.65, reviewRevealStep: reviewStep)
  }

  private func fixtureProjection(id: String = "aurora", role: AgentRole = .research, activity: LivingAgentActivity) -> LivingAgentProjection {
    LivingAgentProjection(agentID: id, name: id.capitalized, initials: String(id.prefix(2)).uppercased(), role: role, taskID: activity == .idle ? nil : UUID(), taskTitle: activity == .idle ? nil : "Visible task", activity: activity, conditions: [], emphasis: .normal, progress: activity == .working ? 0.5 : 0, reviewRevealStep: 0, stressLabel: "Focused", trustLabel: "Trusted", level: 2, needsFounderAttention: [.workComplete, .awaitingReview, .reviewing].contains(activity), isResting: activity == .resting)
  }

  private func hierarchy(agents: [LivingAgentProjection], phase: SprintPhase, reviews: Int = 0, resolutions: Int = 0, canCommit: Bool = false) -> CompanyPhaseHierarchy {
    CompanyPhaseHierarchy.derive(
      sprintPhase: phase,
      agents: agents,
      founderSummary: CompanyCommandFounderSummary(sprintPhase: phase, workInProgressCount: 0, reviewCount: reviews, resolutionCount: resolutions, attentionRemaining: 2, attentionMaximum: 2, canCommit: canCommit, nextAction: "Visible action")
    )
  }
}
