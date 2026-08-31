#if DEBUG
import Dispatch
import SwiftUI

private let motionQAProofNotification = Notification.Name("SOLOMotionQAPlayProof")
private let motionQAProofDarwinName = "com.talonsight.solounicornrun.motion-qa-play" as CFString
private let motionQAProofCallback: CFNotificationCallback = { _, _, _, _, _ in
  DispatchQueue.main.async {
    NotificationCenter.default.post(name: motionQAProofNotification, object: nil)
  }
}

/// Immutable, production-component visual verification catalog. It owns no
/// GameStore, coordinator, persistence, RNG, purchase, or network dependency.
struct MotionVerificationScreen: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var fixtureID: LivingCompanyFixture.ID
  @State private var isPlayingCausalProof = false
  @State private var showsPhysicalEnvironment: Bool
  @State private var proofMode: FounderEnvironmentMode
  @State private var lightingPeriod: OperatingCalendar.Period = .morning

  private var isCommandFocusProof: Bool {
    ProcessInfo.processInfo.arguments.contains("--motion-qa-command-focus-proof")
  }

  private var isAgentCohesionProof: Bool {
    ProcessInfo.processInfo.arguments.contains("--motion-qa-agent-cohesion-sequence")
  }

  init(initialFixture: LivingCompanyFixture.ID = .idleOverview) {
    _fixtureID = State(initialValue: initialFixture)
    let physical = ProcessInfo.processInfo.arguments.contains("--motion-qa-physical")
      || ProcessInfo.processInfo.arguments.contains("--motion-qa-agent-cohesion-sequence")
    let commandFocusProof = ProcessInfo.processInfo.arguments.contains("--motion-qa-command-focus-proof")
    _showsPhysicalEnvironment = State(initialValue: physical)
    let startsInFreeLook = physical || ProcessInfo.processInfo.arguments.contains("--motion-qa-agent-cohesion-sequence")
    _proofMode = State(initialValue: startsInFreeLook || !physical || commandFocusProof ? .freeLook : .computerFocused)
  }

  var body: some View {
    Group {
      if isCommandFocusProof || isAgentCohesionProof {
        fixtureEnvironment(LivingCompanyFixture.make(fixtureID), fixedHeight: nil)
          .overlay(alignment: .topTrailing) {
            Text(isAgentCohesionProof ? "DEBUG · AGENT LIFECYCLE PROOF" : "DEBUG · CONTINUITY PROOF")
              .font(.caption2.monospaced().weight(.black))
              .foregroundStyle(SoloTheme.mint)
              .padding(.horizontal, 8)
              .frame(height: 26)
              .background(.black.opacity(0.76), in: Capsule())
              .padding(8)
              .allowsHitTesting(false)
          }
      } else {
        verificationCatalog
      }
    }
    .task {
      if isAgentCohesionProof {
        // External recorder launch settles before the four-state proof begins.
        try? await Task.sleep(for: .seconds(3))
        await playAgentCohesionProof()
      } else if ProcessInfo.processInfo.arguments.contains("--motion-qa-sequence")
        || ProcessInfo.processInfo.environment["SOLO_MOTION_QA_SEQUENCE"] == "1" {
        try? await Task.sleep(for: .milliseconds(650))
        await playCausalProof()
      }
    }
    .onAppear {
      CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        nil,
        motionQAProofCallback,
        motionQAProofDarwinName,
        nil,
        .deliverImmediately
      )
    }
    .onDisappear {
      CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        nil,
        CFNotificationName(motionQAProofDarwinName),
        nil
      )
    }
    .onReceive(NotificationCenter.default.publisher(for: motionQAProofNotification)) { _ in
      Task { await playCausalProof() }
    }
  }

  @MainActor
  private func playAgentCohesionProof() async {
    let lifecycle: [(LivingCompanyFixture.ID, Duration)] = [
      (.idleOverview, .seconds(2)),
      (.auroraAssignment, .seconds(2)),
      (.auroraWorking, .seconds(3)),
      (.awaitingReview, .seconds(3))
    ]
    for _ in 0..<4 {
      for (id, hold) in lifecycle {
        guard !Task.isCancelled else { return }
        fixtureID = id
        try? await Task.sleep(for: hold)
      }
    }
  }

  private var verificationCatalog: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          Label("Production component · DEBUG fixture", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(SoloTheme.mint)
            .padding(.trailing, 72)

          Picker("Verification surface", selection: $showsPhysicalEnvironment) {
            Text("Company Command").tag(false)
            Text("Physical Garage").tag(true)
          }
          .pickerStyle(.segmented)

          if showsPhysicalEnvironment {
            Picker("Garage lighting", selection: $lightingPeriod) {
              ForEach(OperatingCalendar.Period.allCases, id: \.self) { period in
                Text(period.title).tag(period)
              }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("motion-qa-garage-lighting")
          }

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

          Button("Play causal proof", systemImage: "play.fill") {
            Task { await playCausalProof() }
          }
          .buttonStyle(.bordered)
          .disabled(isPlayingCausalProof)

          Picker("Visual fixture", selection: $fixtureID) {
            ForEach(LivingCompanyFixture.ID.allCases) { id in
              Text(id.rawValue).tag(id)
            }
          }
          .pickerStyle(.menu)
          .buttonStyle(.borderedProminent)
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
      Button("Done") { dismiss() }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
        .padding(.top, 10)
      }
  }

  @MainActor
  private func playCausalProof() async {
    guard !isPlayingCausalProof else { return }
    isPlayingCausalProof = true
    if showsPhysicalEnvironment {
      fixtureID = .planningPhase
      proofMode = .computerFocused
      try? await Task.sleep(for: .milliseconds(900))
      proofMode = .transitioningToFreeLook
      try? await Task.sleep(for: .milliseconds(520))
      proofMode = .freeLook
      try? await Task.sleep(for: .milliseconds(700))
      fixtureID = .auroraWorking
      try? await Task.sleep(for: .milliseconds(900))
      fixtureID = .stacksWorking
      try? await Task.sleep(for: .milliseconds(900))
      fixtureID = .brioWorking
      try? await Task.sleep(for: .milliseconds(900))
      fixtureID = .stacksWorking
      try? await Task.sleep(for: .milliseconds(650))
      proofMode = .transitioningToComputerFocus
      try? await Task.sleep(for: .milliseconds(520))
      proofMode = .computerFocused
      try? await Task.sleep(for: .milliseconds(950))
      fixtureID = .awaitingReview
      try? await Task.sleep(for: .milliseconds(850))
      fixtureID = .reviewStep1
      try? await Task.sleep(for: .milliseconds(650))
      fixtureID = .reviewStep5
      try? await Task.sleep(for: .milliseconds(850))
      proofMode = .transitioningToFreeLook
      try? await Task.sleep(for: .milliseconds(520))
      proofMode = .freeLook
      fixtureID = .stacksWorking
      try? await Task.sleep(for: .milliseconds(1_000))
      proofMode = .transitioningToComputerFocus
      try? await Task.sleep(for: .milliseconds(520))
      proofMode = .computerFocused
      fixtureID = .commitReady
      try? await Task.sleep(for: .milliseconds(1_200))
      isPlayingCausalProof = false
      return
    }
    for id in LivingCompanyFixture.causalProofSequence {
      guard !Task.isCancelled else { return }
      fixtureID = id
      try? await Task.sleep(for: .milliseconds(1_550))
    }
    if showsPhysicalEnvironment {
      try? await Task.sleep(for: .milliseconds(650))
      proofMode = .transitioningToComputerFocus
      try? await Task.sleep(for: .milliseconds(520))
      proofMode = .computerFocused
      try? await Task.sleep(for: .milliseconds(1_150))
    }
    isPlayingCausalProof = false
  }

  @ViewBuilder
  private var fixtureViewport: some View {
    let fixture = LivingCompanyFixture.make(fixtureID)
    if showsPhysicalEnvironment {
      fixtureEnvironment(fixture)
    } else {
      companyCommandViewport(fixture)
    }
  }

  private func companyCommandViewport(_ fixture: LivingCompanyFixture) -> some View {
    CompanyCommandViewport(
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

  private func fixtureEnvironment(
    _ fixture: LivingCompanyFixture,
    fixedHeight: CGFloat? = 620
  ) -> some View {
    GeometryReader { proxy in
      let camera = fixtureEnvironmentCamera(fixture, mode: proofMode)
      let projection = FounderEnvironmentProjection(
        facility: fixture.atmosphere.facility,
        atmosphere: fixture.atmosphere,
        infrastructure: fixture.infrastructure,
        agents: fixture.agents,
        period: lightingPeriod
      )
      let motion = FounderGarageMotionPresentation.derive(
        environment: projection,
        camera: camera,
        reduceMotion: fixture.forceReduceMotion || systemReduceMotion,
        sceneActive: true
      )
      let layout = FounderEnvironmentLayout(viewportSize: proxy.size)
      let monitorPosition = layout.viewportPosition(
        for: .founderMonitor,
        camera: camera,
        layer: .foreground
      )
      let monitorOffset = CGSize(
        width: monitorPosition.x - proxy.size.width / 2,
        height: monitorPosition.y - proxy.size.height / 2
      )
      let monitorSize = FounderCommandFocusLayout.monitorSize(
        viewport: proxy.size,
        mode: proofMode,
        accessibilitySize: fixture.accessibilityLarge
      )
      let targetsComputerFocus = proofMode.targetsComputerFocus

      ZStack {
        FounderEnvironmentRendererView(
          projection: projection,
          camera: camera,
          motion: motion,
          increasedContrast: fixture.increasedContrast
        )
        FounderPhysicalMonitorView(
          focused: targetsComputerFocus,
          width: monitorSize.width,
          height: monitorSize.height,
          commandViewportSize: proxy.size,
          camera: camera,
          worldOffset: targetsComputerFocus
            ? .zero
            : CGSize(width: monitorOffset.width, height: monitorOffset.height + 42),
          increasedContrast: fixture.increasedContrast,
          monitorGlowIntensity: motion.lighting.founderMonitorGlow,
          notificationIntensity: motion.lighting.founderNotificationIntensity,
          eventToken: motion.event.token,
          reduceMotion: fixture.forceReduceMotion || systemReduceMotion
        ) {
          companyCommandViewport(fixture)
            .allowsHitTesting(false)
        }
        if motion.camera.showsDeskHardware {
          FounderGarageForegroundFramingView(
            camera: camera,
            monitorOffset: CGSize(width: monitorOffset.width, height: monitorOffset.height + 42),
            monitorSize: monitorSize,
            increasedContrast: fixture.increasedContrast
          )
          .allowsHitTesting(false)
          .accessibilityHidden(true)
        }
        FounderEnvironmentControlLayer(
          mode: proofMode,
          reduceMotion: fixture.forceReduceMotion || systemReduceMotion,
          onLookAround: {},
          onFocusComputer: {},
          onLook: { _, _ in },
          onCenter: {}
        )
        .allowsHitTesting(false)
      }
      .clipped()
      .animation(
        fixture.forceReduceMotion || systemReduceMotion ? nil : .smooth(duration: 0.38),
        value: proofMode
      )
      .animation(
        fixture.forceReduceMotion || systemReduceMotion ? nil : .smooth(duration: 0.62),
        value: fixture.id
      )
    }
    .frame(height: fixedHeight)
    .environment(\.dynamicTypeSize, fixture.accessibilityLarge ? .accessibility3 : .large)
    .accessibilityLabel("Physical Founder Garage DEBUG fixture. \(fixture.id.rawValue)")
  }

  private func fixtureEnvironmentCamera(
    _ fixture: LivingCompanyFixture,
    mode: FounderEnvironmentMode
  ) -> FounderEnvironmentCameraState {
    let active = fixture.agents.filter {
      ![.idle, .resting, .resolved].contains($0.activity)
    }
    let horizontal: Double
    if active.count == 1, active[0].agentID == "aurora" {
      horizontal = -1
    } else if active.count == 1, active[0].agentID == "brio" {
      horizontal = 1
    } else {
      horizontal = 0
    }
    return FounderEnvironmentCameraState(horizontalLook: horizontal, mode: mode)
  }
}

struct LivingCompanyFixture: Equatable, Sendable {
  enum ID: String, CaseIterable, Identifiable, Sendable {
    case idleOverview = "Idle overview"
    case auroraFocus = "Aurora user focus"
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
    case combinedPressure = "Combined company pressure"
    case userFocusAurora = "User-initiated Aurora focus"
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
    case .auroraFocus:
      focus = .agent("aurora")
    case .auroraAssignment:
      // Build 32.4: assignment presentation stays in the overview scene. The
      // fixture no longer opens the agent-focus layout.
      stage("aurora", activity: .assignmentReceived, progress: 0.08, conditions: [.focused], emphasis: .selected)
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
      stage("aurora", activity: .reviewed, progress: 1, conditions: [.verified], reviewStep: 5); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .overclaimed:
      stage("aurora", activity: .reviewed, progress: 1, conditions: [.overclaimed], reviewStep: 5); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .driftDetected:
      stage("brio", activity: .reviewed, progress: 1, conditions: [.drifting], reviewStep: 5); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .evidenceIncomplete:
      stage("aurora", activity: .reviewed, progress: 1, conditions: [.evidenceIncomplete], reviewStep: 5); resolutionCount = 1; sprintPhase = .reviewAndResolve
    case .stressed:
      agents[1].conditions = [.stressed]; agents[1].stressLabel = "Pressured"
    case .overloaded:
      agents[1].conditions = [.stressed, .overloaded]; agents[1].stressLabel = "Overloaded"
    case .resting:
      stage("brio", activity: .resting, progress: 0); agents[2].conditions = [.stressed]
    case .levelUp:
      agents[1].level = 4; agents[1].emphasis = .levelUpCelebration
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
      // Momentum strengthens the path between active stations and Founder
      // Command, so the fixture needs an active station to connect.
      stats.momentum = 91
      stage("aurora", activity: .working, progress: 0.46, conditions: [.focused])
      stage("brio", activity: .working, progress: 0.62, conditions: [.focused])
    case .combinedPressure:
      // Build 32.4 treatments are independent axes, so all four coexist.
      stats.energy = 22; stats.runway = 5; stats.trust = 18; stats.momentum = 91
      stage("stacks", activity: .working, progress: 0.5, conditions: [.focused])
    case .userFocusAurora:
      // The only path into the focus layout is an explicit user interaction.
      focus = .agent("aurora")
    case .planningPhase:
      sprintPhase = .assignTeam
    case .reduceMotion:
      // All three causal families held at their endpoints: the assignment
      // docked at its agent, completed work in the Founder tray, and the
      // resolution response settled in its company system.
      stage("aurora", activity: .assignmentReceived, progress: 0.1, conditions: [.focused])
      stage("stacks", activity: .awaitingReview, progress: 1, emphasis: .founderAttention)
      stage("brio", activity: .resolved, progress: 1, conditions: [.verified], emphasis: .decisionLock, reviewStep: 5)
      reviewCount = 1
      sprintPhase = .reviewAndResolve
      nextAction = "Reduce Motion shows every causal endpoint without travel."
    case .idleOverview, .accessibilityLarge, .increasedContrast:
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
