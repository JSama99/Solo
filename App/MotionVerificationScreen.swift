#if DEBUG
import SwiftUI

/// Immutable, production-component visual verification catalog. It owns no
/// GameStore, coordinator, persistence, RNG, purchase, or network dependency.
struct MotionVerificationScreen: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var fixtureID: LivingCompanyFixture.ID
  @State private var isPlayingCausalProof = false

  init(initialFixture: LivingCompanyFixture.ID = .idleOverview) {
    _fixtureID = State(initialValue: initialFixture)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text("Production Company Command rendered from immutable, visible-safe fixtures. Career state is never read or changed.")
            .font(.caption)
            .foregroundStyle(.secondary)

          Picker("Visual fixture", selection: $fixtureID) {
            ForEach(LivingCompanyFixture.ID.allCases) { id in
              Text(id.rawValue).tag(id)
            }
          }
          .pickerStyle(.menu)
          .buttonStyle(.borderedProminent)

          fixtureViewport

          HStack {
            Button("Previous", systemImage: "chevron.left") { fixtureID = fixtureID.previous }
            Spacer()
            Text("\(fixtureID.index + 1) / \(LivingCompanyFixture.ID.allCases.count)")
              .font(.caption.monospacedDigit().weight(.bold))
            Spacer()
            Button("Next", systemImage: "chevron.right") { fixtureID = fixtureID.next }
          }
          .buttonStyle(.bordered)

          Label("Production component · DEBUG fixture", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(SoloTheme.mint)
          Text("Current state: \(fixtureID.rawValue)")
            .font(.caption.weight(.black))
            .foregroundStyle(SoloTheme.cyan)
            .accessibilityIdentifier("motion-qa-current-state")
          if isPlayingCausalProof {
            Label("Uninterrupted causal proof playback", systemImage: "record.circle")
              .font(.caption.weight(.bold))
              .foregroundStyle(SoloTheme.coral)
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .task {
        guard ProcessInfo.processInfo.arguments.contains("--motion-qa-sequence") else { return }
        isPlayingCausalProof = true
        try? await Task.sleep(for: .seconds(1))
        for id in LivingCompanyFixture.causalProofSequence {
          guard !Task.isCancelled else { return }
          fixtureID = id
          try? await Task.sleep(for: .milliseconds(1_100))
        }
        isPlayingCausalProof = false
      }
      .navigationTitle("Motion QA")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var fixtureViewport: some View {
    let fixture = LivingCompanyFixture.make(fixtureID)
    return CompanyCommandViewport(
      agents: fixture.agents,
      atmosphere: fixture.atmosphere,
      infrastructure: fixture.infrastructure,
      sprintPhase: fixture.sprintPhase,
      focus: fixture.focus,
      agentAvailability: fixture.availability,
      founderSummary: fixture.founderSummary,
      reduceMotion: fixture.forceReduceMotion || systemReduceMotion,
      forceIncreasedContrast: fixture.increasedContrast,
      onFocus: { _ in },
      onAssign: { _ in },
      onReview: { _ in },
      onRest: { _ in },
      onSkipAgentPresentation: { _ in },
      onOpenFullWorkstation: { _ in },
      onCommit: {},
      onVisibilityChange: { _ in }
    )
    .environment(\.dynamicTypeSize, fixture.accessibilityLarge ? .accessibility3 : .large)
  }
}

struct LivingCompanyFixture: Equatable, Sendable {
  enum ID: String, CaseIterable, Identifiable, Sendable {
    case idleOverview = "Idle overview"
    case auroraAssignment = "Aurora assignment received"
    case auroraWorking = "Aurora working"
    case stacksWorking = "Stacks working"
    case brioWorking = "Brio working"
    case multipleWorking = "Multiple agents working"
    case workComplete = "Work complete"
    case awaitingReview = "Awaiting Founder review"
    case reviewStep1 = "Review step one"
    case reviewStep2 = "Review step two"
    case reviewStep3 = "Review step three"
    case reviewStep4 = "Review step four"
    case reviewStep5 = "Review step five"
    case verified = "Verified"
    case overclaimed = "Overclaimed"
    case driftDetected = "Drift detected"
    case evidenceIncomplete = "Evidence incomplete"
    case stressed = "Stressed"
    case overloaded = "Overloaded"
    case resting = "Resting"
    case levelUp = "Level-up"
    case resolving = "Resolving"
    case resolved = "Resolved"
    case planningPhase = "Planning phase"
    case workingPhase = "Working phase"
    case reviewPhase = "Review phase"
    case resolutionPhase = "Resolution phase"
    case commitReady = "Commit-ready phase"
    case blockedCommit = "Blocked commit"
    case uninstalledInfrastructure = "Uninstalled infrastructure"
    case installationSequence = "Installation sequence"
    case installedInfrastructure = "Installed infrastructure"
    case activeInfrastructure = "Relevant-active infrastructure"
    case founderGarage = "Founder Garage"
    case founderLoft = "Founder Loft"
    case highEnergy = "High Energy"
    case lowEnergy = "Low Energy"
    case healthyRunway = "Healthy Runway"
    case lowRunway = "Low Runway"
    case highTrust = "High Trust"
    case lowTrust = "Low Trust"
    case lowMomentum = "Low Momentum"
    case highMomentum = "High Momentum"
    case reduceMotion = "Reduce Motion endpoints"
    case accessibilityLarge = "Accessibility Extra Large"
    case increasedContrast = "Increased Contrast"

    var id: Self { self }
    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var previous: Self { Self.allCases[(index - 1 + Self.allCases.count) % Self.allCases.count] }
    var next: Self { Self.allCases[(index + 1) % Self.allCases.count] }
  }

  var id: ID
  var agents: [LivingAgentProjection]
  var atmosphere: CompanyAtmosphere
  var infrastructure: [InfrastructureVisual]
  var sprintPhase: SprintPhase
  var focus: CompanyCommandFocus?
  var availability: [String: CompanyCommandAgentAvailability]
  var founderSummary: CompanyCommandFounderSummary
  var forceReduceMotion: Bool
  var accessibilityLarge: Bool
  var increasedContrast: Bool

  static var causalProofSequence: [ID] {
    [
      .planningPhase,
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
      .resolved,
      .commitReady
    ]
  }

  static func make(_ id: ID) -> Self {
    var agents = baseAgents
    var stats = FounderStats()
    var facility = FacilityTier.founderGarage
    var sprintPhase = SprintPhase.assignTeam
    var focus: CompanyCommandFocus?
    var purchased = Set(FacilityUpgradeID.allCases)
    var installing = Set<FacilityUpgradeID>()
    var canCommit = false
    var reviewCount = 0
    var resolutionCount = 0
    var nextAction = "Choose a task and assign the right agent."

    func stage(_ agentID: String, activity: LivingAgentActivity, progress: Double, conditions: Set<LivingAgentCondition> = [], emphasis: LivingPresentationEmphasis = .normal, reviewStep: Int = 0) {
      guard let index = agents.firstIndex(where: { $0.agentID == agentID }) else { return }
      agents[index].activity = activity
      agents[index].progress = progress
      agents[index].conditions = conditions
      agents[index].emphasis = emphasis
      agents[index].reviewRevealStep = reviewStep
      agents[index].taskID = activity == .idle || activity == .resting ? nil : UUID(uuidString: "32000000-0000-0000-0000-00000000000\(index + 1)")
      agents[index].taskTitle = activity == .idle || activity == .resting ? nil : taskTitle(for: agentID)
      agents[index].needsFounderAttention = [.workComplete, .awaitingReview, .reviewing].contains(activity)
      agents[index].isResting = activity == .resting
    }

    switch id {
    case .auroraAssignment:
      stage("aurora", activity: .assignmentReceived, progress: 0.08, conditions: [.focused], emphasis: .selected); focus = .agent("aurora")
    case .auroraWorking, .workingPhase:
      stage("aurora", activity: .working, progress: 0.58, conditions: [.focused]); nextAction = "Watch research evidence accumulate."
    case .stacksWorking:
      stage("stacks", activity: .working, progress: 0.66, conditions: [.focused])
    case .brioWorking:
      stage("brio", activity: .working, progress: 0.72, conditions: [.focused])
    case .multipleWorking:
      stage("aurora", activity: .working, progress: 0.52, conditions: [.focused]); stage("stacks", activity: .working, progress: 0.67, conditions: [.focused]); stage("brio", activity: .working, progress: 0.41, conditions: [.focused])
    case .workComplete:
      stage("stacks", activity: .workComplete, progress: 1, emphasis: .founderAttention); reviewCount = 1
    case .awaitingReview, .reviewPhase:
      stage("aurora", activity: .awaitingReview, progress: 1, emphasis: .founderAttention); reviewCount = 1; sprintPhase = .reviewAndResolve; nextAction = "Inspect the completed artifact."
    case .reviewStep1, .reviewStep2, .reviewStep3, .reviewStep4, .reviewStep5:
      let step = [ID.reviewStep1: 1, .reviewStep2: 2, .reviewStep3: 3, .reviewStep4: 4, .reviewStep5: 5][id] ?? 1
      stage("aurora", activity: .reviewing, progress: 1, conditions: step == 5 ? [.verified] : [], emphasis: .inspection, reviewStep: step); reviewCount = 1; sprintPhase = .reviewAndResolve
    case .verified:
      stage("aurora", activity: .reviewed, progress: 1, conditions: [.verified]); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .overclaimed:
      stage("aurora", activity: .reviewed, progress: 1, conditions: [.overclaimed]); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .driftDetected:
      stage("brio", activity: .reviewed, progress: 1, conditions: [.drifting]); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .evidenceIncomplete:
      stage("aurora", activity: .reviewed, progress: 1, conditions: [.evidenceIncomplete]); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .stressed:
      agents[1].conditions = [.stressed]; agents[1].stressLabel = "Pressured"
    case .overloaded:
      agents[1].conditions = [.stressed, .overloaded]; agents[1].stressLabel = "Overloaded"
    case .resting:
      stage("brio", activity: .resting, progress: 0); agents[2].conditions = [.stressed]
    case .levelUp:
      agents[1].level = 4; agents[1].emphasis = .levelUpCelebration; focus = .agent("stacks")
    case .resolving, .resolutionPhase:
      stage("aurora", activity: .resolving, progress: 1, conditions: [.verified], emphasis: .decisionLock, reviewStep: 5); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .resolved:
      stage("aurora", activity: .resolved, progress: 1, conditions: [.verified], emphasis: .decisionLock, reviewStep: 5); sprintPhase = .readyToCommit; canCommit = true; nextAction = "Founder response returned. Commit the sprint."
    case .commitReady:
      sprintPhase = .readyToCommit; canCommit = true; nextAction = "All work handled. Commit Sprint."
    case .blockedCommit:
      sprintPhase = .readyToCommit; reviewCount = 1; nextAction = "Founder review remains before commit."
    case .uninstalledInfrastructure:
      purchased = []
    case .installationSequence:
      purchased = []; installing = [.developmentRig]
    case .installedInfrastructure:
      break
    case .activeInfrastructure:
      stage("stacks", activity: .working, progress: 0.64, conditions: [.focused])
    case .founderGarage:
      facility = .founderGarage
    case .founderLoft:
      facility = .founderLoft
    case .highEnergy:
      stats.energy = 96
    case .lowEnergy:
      stats.energy = 22
    case .healthyRunway:
      stats.runway = 48
    case .lowRunway:
      stats.runway = 5
    case .highTrust:
      stats.trust = 94
    case .lowTrust:
      stats.trust = 18
    case .lowMomentum:
      stats.momentum = 6
    case .highMomentum:
      stats.momentum = 91
    case .planningPhase:
      sprintPhase = .assignTeam
    case .idleOverview, .reduceMotion, .accessibilityLarge, .increasedContrast:
      break
    }

    let atmosphere = CompanyAtmosphere.derive(stats: stats, facility: facility, venture: 1)
    let summary = CompanyCommandFounderSummary(
      sprintPhase: sprintPhase,
      workInProgressCount: agents.filter { [.assignmentReceived, .working, .workComplete].contains($0.activity) }.count,
      reviewCount: reviewCount,
      resolutionCount: resolutionCount,
      attentionRemaining: 2,
      attentionMaximum: 2,
      canCommit: canCommit,
      nextAction: nextAction
    )
    let infrastructure = InfrastructureVisual.map(purchased: purchased, facility: facility, agents: agents, sprint: 3, installing: installing)
    let availability = Dictionary(uniqueKeysWithValues: agents.map { agent in
      (agent.agentID, CompanyCommandAgentAvailability(
        canAssign: sprintPhase == .assignTeam && agent.taskID == nil,
        canReview: agent.activity == .awaitingReview,
        canRest: sprintPhase == .assignTeam,
        canSkipPresentation: [.assignmentReceived, .working, .workComplete, .reviewing, .resolving].contains(agent.activity),
        requiresResolution: [.reviewed, .resolving].contains(agent.activity)
      ))
    })
    return Self(
      id: id,
      agents: agents,
      atmosphere: atmosphere,
      infrastructure: infrastructure,
      sprintPhase: sprintPhase,
      focus: focus,
      availability: availability,
      founderSummary: summary,
      forceReduceMotion: id == .reduceMotion,
      accessibilityLarge: id == .accessibilityLarge,
      increasedContrast: id == .increasedContrast
    )
  }

  private static var baseAgents: [LivingAgentProjection] {
    [
      projection("aurora", "Aurora", "AU", .research),
      projection("stacks", "Stacks", "ST", .engineering),
      projection("brio", "Brio", "BR", .marketing)
    ]
  }

  private static func projection(_ id: String, _ name: String, _ initials: String, _ role: AgentRole) -> LivingAgentProjection {
    LivingAgentProjection(
      agentID: id,
      name: name,
      initials: initials,
      role: role,
      taskID: nil,
      taskTitle: nil,
      activity: .idle,
      conditions: [],
      emphasis: .normal,
      progress: 0,
      reviewRevealStep: 0,
      stressLabel: "Focused",
      trustLabel: "Trusted",
      level: 3,
      needsFounderAttention: false,
      isResting: false
    )
  }

  private static func taskTitle(for agentID: String) -> String {
    switch agentID {
    case "aurora": "Validate launch evidence"
    case "stacks": "Stabilize deployment rail"
    default: "Run trust-led campaign"
    }
  }
}
#endif
