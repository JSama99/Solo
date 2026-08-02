import Foundation
import Observation

@MainActor
@Observable
final class GameStore {
  enum Stage: Equatable {
    case title
    case setup
    case game
    case outcome
  }

  var stage: Stage = .title
  var founderName = ""
  var selectedDoctrine: FounderDoctrine = .guided
  var doctrine: FounderDoctrine = .guided
  var sprint = 1
  var venture = 1
  private(set) var intent: SprintIntent = .build
  var stats = FounderStats()
  var agents = GameStore.initialAgents
  var tasks: [SoloTask] = []
  var evidence: [EvidenceEntry] = []
  var report: SprintReport?
  var careerOutcome: CareerOutcome?
  var alertMessage: String?
  var randomNumberGenerator = SeededRandomNumberGenerator(seed: 0)
  var correlatedFailureEvent: CorrelatedFailureEvent?
  var pendingEffects: [ScheduledEffect] = []
  var reportCache: [CachedTaskReport] = []

  var hasSave: Bool {
    UserDefaults.standard.data(forKey: Self.saveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v3SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.v2SaveKey) != nil
      || UserDefaults.standard.data(forKey: Self.legacySaveKey) != nil
  }

  var attentionMaximum: Int {
    doctrine == .guided ? 4 : 3
  }

  var attentionRemaining: Int {
    max(0, attentionMaximum - tasks.filter(\.isReviewed).count)
  }

  var averageDrift: Int {
    guard !agents.isEmpty else { return 0 }
    return Int(agents.map(\.drift).reduce(0, +) / Double(agents.count))
  }

  var garageCondition: String {
    if averageDrift >= 60 || stats.trust <= 24 { return "Critical" }
    if averageDrift >= 35 || stats.energy <= 38 { return "Strained" }
    return "Steady"
  }

  func beginSetup() {
    founderName = ""
    selectedDoctrine = .guided
    stage = .setup
  }

  func startCareer(seed: UInt64? = nil) {
    doctrine = selectedDoctrine
    founderName = founderName.trimmingCharacters(in: .whitespacesAndNewlines)
    if founderName.isEmpty { founderName = "Founder" }
    sprint = 1
    venture = 1
    intent = .build
    stats = FounderStats()
    agents = Self.initialAgents
    evidence = []
    careerOutcome = nil
    report = nil
    pendingEffects = []
    reportCache = []
    randomNumberGenerator = SeededRandomNumberGenerator(seed: seed ?? UInt64.random(in: .min ... .max))
    if doctrine == .trust {
      stats.trust += 12
      stats.momentum -= 4
    } else if doctrine == .guided {
      stats.energy += 5
    }
    prepareSprint()
    stage = .game
    sanitizeState()
    save()
  }

  func continueCareer() {
    let decoder = JSONDecoder()
    var loadedSave: CareerSave?

    if let data = UserDefaults.standard.data(forKey: Self.saveKey),
       let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
       envelope.version == Self.saveVersion {
      loadedSave = envelope.career
    } else if let data = UserDefaults.standard.data(forKey: Self.v3SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 3 {
      loadedSave = migrateV3(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.v2SaveKey),
              let envelope = try? decoder.decode(SaveEnvelope.self, from: data),
              envelope.version == 2 {
      loadedSave = migrateV2(envelope.career)
    } else if let data = UserDefaults.standard.data(forKey: Self.legacySaveKey),
              let legacy = try? decoder.decode(CareerSave.self, from: data) {
      loadedSave = migrateV1(legacy)
    }

    guard let loadedSave else {
      beginSetup()
      return
    }
    apply(loadedSave)
    saveCareer()
  }

  @discardableResult
  func setIntent(_ newIntent: SprintIntent) -> Bool {
    guard newIntent != intent else { return true }
    guard tasks.allSatisfy({ $0.assignedAgentID == nil }) else {
      alertMessage = "Clear all assignments to change sprint intent."
      return false
    }
    intent = newIntent
    save()
    return true
  }

  func assign(agentID: String?, to taskID: UUID) {
    sanitizeState()
    guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    guard !tasks[taskIndex].isReviewed else {
      alertMessage = "Verified work is locked for this sprint."
      return
    }

    if let agentID {
      if let lockedTask = tasks.first(where: {
        $0.assignedAgentID == agentID && $0.isReviewed && $0.id != taskID
      }) {
        alertMessage = "\(lockedTask.title) has already been verified with this agent."
        return
      }
      for index in tasks.indices where tasks[index].assignedAgentID == agentID && index != taskIndex {
        tasks[index].assignedAgentID = nil
        tasks[index].result = nil
      }
      tasks[taskIndex].assignedAgentID = agentID
      if let agent = agents.first(where: { $0.id == agentID }) {
        if let cached = cachedReport(taskID: taskID, agentID: agentID) {
          tasks[taskIndex].result = cached
        } else {
          let result = makeResult(for: tasks[taskIndex], agent: agent)
          tasks[taskIndex].result = result
          reportCache.append(
            CachedTaskReport(
              venture: venture,
              sprint: sprint,
              taskID: taskID,
              agentID: agentID,
              intent: intent,
              result: result
            )
          )
        }
      }
    } else {
      tasks[taskIndex].assignedAgentID = nil
      tasks[taskIndex].result = nil
    }
    updateKnownOperationalRisks()
    syncAssignments()
    save()
  }

  func toggleReview(taskID: UUID) {
    review(taskID: taskID)
  }

  func review(taskID: UUID) {
    guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    guard !tasks[taskIndex].isReviewed else { return }
    guard attentionRemaining > 0 else {
      alertMessage = "No Founder Attention remains this sprint."
      return
    }
    guard
      let agentID = tasks[taskIndex].assignedAgentID,
      let agentIndex = agents.firstIndex(where: { $0.id == agentID }),
      var result = tasks[taskIndex].result
    else {
      alertMessage = "Assign an agent before reviewing its report."
      return
    }

    let state = result.verify()
    tasks[taskIndex].result = result
    tasks[taskIndex].isReviewed = true
    let reviewEnergy = doctrine == .guided ? 2 : 1
    stats.energy = clamped(stats.energy - reviewEnergy)
    agents[agentIndex].calibration = min(1, agents[agentIndex].calibration + 0.035)
    agents[agentIndex].drift = max(0, agents[agentIndex].drift - 9)
    switch state {
    case .confirmed:
      agents[agentIndex].trust = min(100, agents[agentIndex].trust + 5)
    case .verified:
      agents[agentIndex].trust = min(100, agents[agentIndex].trust + 2)
    case .overclaimed, .driftDetected:
      agents[agentIndex].trust = max(0, agents[agentIndex].trust - 2)
    case .evidenceIncomplete:
      agents[agentIndex].trust = max(0, agents[agentIndex].trust - 1)
    case .reported, .unverified:
      break
    }
    recordEvidence(task: tasks[taskIndex], agent: agents[agentIndex], result: result)
    sanitizeState()
    save()
  }

  func commitSprint() {
    sanitizeState()
    let assignedIndices = tasks.indices.filter { tasks[$0].assignedAgentID != nil }
    guard !assignedIndices.isEmpty else {
      alertMessage = "Assign at least one agent before committing the sprint."
      return
    }

    let dueEffects = pendingEffects.filter { $0.dueCareerSprint <= careerSprintIndex }
    pendingEffects.removeAll { $0.dueCareerSprint <= careerSprintIndex }
    var effects = dueEffects.reduce(SimulationEffects()) { $0 + $1.effects }
    effects.runway -= 4
    effects.energy -= 2
    switch intent {
    case .build:
      effects.momentum += 3
      effects.energy -= 1
    case .learn:
      effects.trust += 3
      effects.momentum -= 1
    case .sell:
      effects.revenue += 180
    }

    var strongOutcomes = 0
    var riskyOutcomes = 0
    for index in assignedIndices {
      guard
        let agentID = tasks[index].assignedAgentID,
        let agentIndex = agents.firstIndex(where: { $0.id == agentID }),
        var result = tasks[index].result
      else { continue }

      effects = effects + result.immediateEffects
      if result.delayedEffects != SimulationEffects() {
        pendingEffects.append(
          ScheduledEffect(
            dueCareerSprint: careerSprintIndex + 1,
            source: tasks[index].title,
            effects: result.delayedEffects
          )
        )
      }
      if tasks[index].isReviewed && result.isStrongForSimulation { strongOutcomes += 1 }
      if result.evidenceCompleteness < 45 || result.correlatedFailureIdentifier != nil {
        riskyOutcomes += 1
      }

      if result.correlatedFailureIdentifier != nil {
        agents[agentIndex].drift = min(100, agents[agentIndex].drift + 5)
        agents[agentIndex].trust = max(0, agents[agentIndex].trust - 2)
      }

      if !tasks[index].isReviewed {
        result.markUnverified()
        tasks[index].result = result
        let driftIncrease = doctrine == .pure ? 9.0 : 6.5
        agents[agentIndex].drift = min(100, agents[agentIndex].drift + driftIncrease)
        agents[agentIndex].trust = max(0, agents[agentIndex].trust - (result.isRiskyForSimulation ? 5 : 2))
        recordEvidence(task: tasks[index], agent: agents[agentIndex], result: result)
      }
    }

    apply(effects)
    sanitizeState()
    let reviewed = assignedIndices.filter { tasks[$0].isReviewed }.count
    report = SprintReport(
      sprint: sprint,
      headline: riskyOutcomes > 0
        ? "Progress carried hidden risk"
        : (strongOutcomes == assignedIndices.count ? "The team found its edge" : "Evidence shaped the outcome"),
      revenueDelta: effects.revenue,
      momentumDelta: effects.momentum,
      trustDelta: effects.trust,
      energyDelta: effects.energy,
      runwayDelta: effects.runway,
      reviewed: reviewed,
      strongOutcomes: strongOutcomes,
      riskyOutcomes: riskyOutcomes
    )

    careerOutcome = resolvedOutcome()
    if careerOutcome == nil && sprint == Self.sprintsPerVenture {
      sprint = 1
      venture += 1
      stats.trackRecord += max(8, (stats.momentum + stats.trust) / 8)
      stats.runway = max(stats.runway, 38)
      stats.energy = max(stats.energy, 72)
      prepareSprint()
    } else if careerOutcome == nil {
      sprint += 1
      prepareSprint()
    }
    saveCareer()
  }

  func finishReport() {
    report = nil
    if careerOutcome != nil {
      stage = .outcome
      saveCareer()
    }
  }

  func resetCareer() {
    UserDefaults.standard.removeObject(forKey: Self.saveKey)
    UserDefaults.standard.removeObject(forKey: Self.v3SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.v2SaveKey)
    UserDefaults.standard.removeObject(forKey: Self.legacySaveKey)
    careerOutcome = nil
    report = nil
    pendingEffects = []
    reportCache = []
    stage = .title
  }

  private func prepareSprint() {
    reportCache = []
    correlatedFailureEvent = generateCorrelatedFailureEvent()
    tasks = makeTasks()
    syncAssignments()
  }

  private func cachedReport(taskID: UUID, agentID: String) -> TaskResult? {
    reportCache.first(where: {
      $0.venture == venture
        && $0.sprint == sprint
        && $0.taskID == taskID
        && $0.agentID == agentID
        && $0.intent == intent
    })?.result
  }

  private func generateCorrelatedFailureEvent() -> CorrelatedFailureEvent? {
    guard randomNumberGenerator.probability() < 0.24 else { return nil }
    let families = Array(Set(agents.map(\.modelFamily))).sorted()
    guard !families.isEmpty else { return nil }
    let family = families[randomNumberGenerator.integer(in: 0 ... families.count - 1)]
    let eventCode = String(randomNumberGenerator.next(), radix: 16, uppercase: true)
    return CorrelatedFailureEvent(
      id: "V\(venture)-S\(sprint)-\(eventCode)",
      modelFamily: family,
      qualityPenalty: randomNumberGenerator.integer(in: 16 ... 24)
    )
  }

  private func makeResult(for task: SoloTask, agent: SoloAgent) -> TaskResult {
    let exactFit = agent.role == task.role
    let flexibleFit = agent.role == .general || task.role == .general
    let roleAdjustment = exactFit ? 14 : (flexibleFit ? 4 : -12)
    let intentAdjustment: Int
    switch (intent, task.role) {
    case (.build, .engineering), (.learn, .research), (.sell, .marketing):
      intentAdjustment = 6
    default:
      intentAdjustment = 0
    }
    let correlation = correlatedFailureEvent?.modelFamily == agent.modelFamily
      ? correlatedFailureEvent
      : nil
    let actualNoise = randomNumberGenerator.integer(in: -12 ... 12)
    let rawActual = Double(agent.reliability) * 0.55
      + agent.calibration * 18
      + agent.trust * 0.18
      - agent.drift * 0.35
      + Double(roleAdjustment + intentAdjustment + (doctrine == .pure ? 7 : 0) + actualNoise)
      - Double(correlation?.qualityPenalty ?? 0)
    let actualQuality = clamped(Int(rawActual.rounded()))

    let reportSpread = max(2, Int(((1 - agent.calibration) * 18 + agent.drift * 0.22).rounded()))
    let reportedQuality = clamped(
      actualQuality + randomNumberGenerator.integer(in: -reportSpread ... reportSpread)
    )
    let evidenceCompleteness = clamped(
      Int((agent.calibration * 70 + Double(agent.reliability) * 0.25 - agent.drift * 0.25).rounded())
        + randomNumberGenerator.integer(in: -10 ... 10)
    )
    let confidenceWidth = max(
      4,
      Int(((1 - agent.calibration) * 20 + Double(100 - evidenceCompleteness) * 0.1).rounded())
    )
    let immediate = immediateEffects(for: task.impact, actualQuality: actualQuality)
    var delayed = SimulationEffects()
    if actualQuality < 52 {
      delayed.trust -= 2
      delayed.momentum -= 1
    }
    if correlation != nil {
      delayed.trust -= 3
      delayed.momentum -= 3
    }

    return TaskResult(
      actualQuality: actualQuality,
      reportedQuality: reportedQuality,
      evidenceCompleteness: evidenceCompleteness,
      correlatedFailureIdentifier: correlation?.id,
      immediateEffects: immediate,
      delayedEffects: delayed,
      confidenceLowerBound: reportedQuality - confidenceWidth,
      confidenceUpperBound: reportedQuality + confidenceWidth,
      knownOperationalRisk: knownRisk(for: task, agent: agent, evidenceCompleteness: evidenceCompleteness)
    )
  }

  private func immediateEffects(for impact: TaskImpact, actualQuality: Int) -> SimulationEffects {
    let multiplier = Double(actualQuality) / 70
    switch impact {
    case .revenue(let amount):
      return SimulationEffects(revenue: Int((Double(amount) * multiplier).rounded()))
    case .momentum(let amount):
      return SimulationEffects(momentum: Int((Double(amount) * multiplier).rounded()))
    case .trust(let amount):
      return SimulationEffects(trust: Int((Double(amount) * multiplier).rounded()))
    case .runway(let amount):
      return SimulationEffects(runway: Int((Double(amount) * multiplier).rounded()))
    }
  }

  private func knownRisk(for task: SoloTask, agent: SoloAgent, evidenceCompleteness: Int) -> String {
    let familyAssignments = tasks.filter { assignedTask in
      guard let assignedID = assignedTask.assignedAgentID else { return false }
      return agents.first(where: { $0.id == assignedID })?.modelFamily == agent.modelFamily
    }.count
    if familyAssignments > 1 { return "Shared model-family exposure" }
    if agent.role != task.role && agent.role != .general && task.role != .general { return "Role mismatch" }
    if agent.drift >= 35 { return "Elevated operational drift" }
    if evidenceCompleteness < 45 { return "Limited supporting evidence" }
    return "Normal operational variance"
  }

  private func updateKnownOperationalRisks() {
    for index in tasks.indices {
      guard
        let agentID = tasks[index].assignedAgentID,
        let agent = agents.first(where: { $0.id == agentID }),
        var result = tasks[index].result
      else { continue }
      result.knownOperationalRisk = knownRisk(
        for: tasks[index],
        agent: agent,
        evidenceCompleteness: result.evidenceCompleteness
      )
      tasks[index].result = result
    }
  }

  private func recordEvidence(task: SoloTask, agent: SoloAgent, result: TaskResult) {
    if let index = evidence.firstIndex(where: {
      $0.venture == venture
        && $0.sprint == sprint
        && $0.taskInstanceID == task.id.uuidString
        && $0.agent == agent.name
    }) {
      guard result.verificationState.reviewAttempted else { return }
      let actual = result.revealedActualQuality
      evidence[index].actualQuality = actual
      evidence[index].reviewed = true
      evidence[index].evidenceVerified = result.verificationState.evidenceVerified
      evidence[index].verdict = result.verificationState.label
      evidence[index].verificationState = result.verificationState
      evidence[index].overclaimAmount = actual.map { max(0, evidence[index].reportedQuality - $0) } ?? 0
      evidence[index].correlatedFailureIdentifier = result.correlatedFailureIdentifier
      if let actual {
        evidence[index].note = "Reported \(evidence[index].reportedQuality); verified \(actual). Evidence \(evidence[index].evidenceCompleteness)%."
      } else {
        evidence[index].note = "Reported \(evidence[index].reportedQuality); review found incomplete evidence. Actual quality remains hidden."
      }
      return
    }
    let actual = result.revealedActualQuality
    let note: String
    if let actual {
      note = "Reported \(result.reportedQuality); verified \(actual). Evidence \(result.evidenceCompleteness)%."
    } else {
      note = "Reported \(result.reportedQuality); actual result remains unverified. Evidence \(result.evidenceCompleteness)%."
    }
    evidence.insert(
      EvidenceEntry(
        id: task.id,
        venture: venture,
        sprint: sprint,
        taskInstanceID: task.id.uuidString,
        task: task.title,
        agent: agent.name,
        reviewed: result.verificationState.reviewAttempted,
        evidenceVerified: result.verificationState.evidenceVerified,
        verdict: result.verificationState.label,
        note: note,
        reportedQuality: result.reportedQuality,
        actualQuality: actual,
        verificationState: result.verificationState,
        overclaimAmount: actual == nil ? 0 : result.overclaimAmount,
        evidenceCompleteness: result.evidenceCompleteness,
        correlatedFailureIdentifier: result.correlatedFailureIdentifier
      ),
      at: 0
    )
  }

  private func apply(_ effects: SimulationEffects) {
    stats.revenue = max(0, stats.revenue + effects.revenue)
    stats.momentum = clamped(stats.momentum + effects.momentum)
    stats.trust = clamped(stats.trust + effects.trust)
    stats.energy = clamped(stats.energy + effects.energy)
    stats.runway = max(0, stats.runway + effects.runway)
    stats.capital = max(0, stats.capital + effects.revenue / 4)
  }

  private func apply(_ save: CareerSave) {
    founderName = save.founderName
    doctrine = save.doctrine
    selectedDoctrine = save.doctrine
    sprint = min(Self.sprintsPerVenture, max(1, save.sprint))
    venture = min(Self.maximumVentures, max(1, save.venture))
    intent = save.intent
    stats = save.stats
    agents = save.agents
    tasks = save.tasks
    evidence = save.evidence
    careerOutcome = save.outcome
    randomNumberGenerator = save.randomNumberGenerator
    correlatedFailureEvent = save.correlatedFailureEvent
    pendingEffects = save.pendingEffects
    reportCache = save.reportCache
    if save.venture > Self.maximumVentures && careerOutcome == nil {
      careerOutcome = victoryOutcome()
    }
    if tasks.isEmpty && careerOutcome == nil {
      tasks = makeTasks()
    }
    sanitizeState()
    updateKnownOperationalRisks()
    syncAssignments()
    stage = careerOutcome == nil ? .game : .outcome
  }

  private func migrateV2(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.randomNumberGenerator = SeededRandomNumberGenerator(seed: legacySeed(for: legacy))
    migrated.correlatedFailureEvent = nil
    migrated.pendingEffects = []
    for index in migrated.tasks.indices {
      migrated.tasks[index].result = nil
      migrated.tasks[index].isReviewed = false
    }
    return migrateV3(migrated)
  }

  private func migrateV1(_ legacy: CareerSave) -> CareerSave {
    migrateV2(legacy)
  }

  private func migrateV3(_ legacy: CareerSave) -> CareerSave {
    var migrated = legacy
    migrated.reportCache = migrated.tasks.compactMap { task in
      guard
        let agentID = task.assignedAgentID,
        let result = task.result
      else { return nil }
      return CachedTaskReport(
        venture: migrated.venture,
        sprint: migrated.sprint,
        taskID: task.id,
        agentID: agentID,
        intent: migrated.intent,
        result: result
      )
    }
    for index in migrated.evidence.indices {
      if migrated.evidence[index].venture <= 0 {
        migrated.evidence[index].venture = max(1, migrated.venture)
      }
      if migrated.evidence[index].taskInstanceID.isEmpty {
        let entry = migrated.evidence[index]
        let currentTask = migrated.tasks.first { task in
          guard
            migrated.sprint == entry.sprint,
            task.title == entry.task,
            let agentID = task.assignedAgentID
          else { return false }
          return migrated.agents.first(where: { $0.id == agentID })?.name == entry.agent
        }
        migrated.evidence[index].taskInstanceID = currentTask?.id.uuidString
          ?? "legacy-\(entry.id.uuidString)"
      }
      if migrated.evidence[index].verificationState == .evidenceIncomplete {
        migrated.evidence[index].actualQuality = nil
        migrated.evidence[index].evidenceVerified = false
      } else {
        migrated.evidence[index].evidenceVerified = migrated.evidence[index].actualQuality != nil
      }
    }
    return migrated
  }

  private func legacySeed(for save: CareerSave) -> UInt64 {
    var value: UInt64 = 0xcbf29ce484222325
    for byte in save.founderName.utf8 {
      value ^= UInt64(byte)
      value &*= 0x100000001b3
    }
    value ^= UInt64(max(1, save.venture) * 100 + max(1, save.sprint))
    return value
  }

  private func syncAssignments() {
    for index in agents.indices {
      agents[index].assignment = tasks.first(where: {
        $0.assignedAgentID == agents[index].id
      })?.id
    }
  }

  private func makeTasks() -> [SoloTask] {
    let offset = ((venture - 1) * Self.sprintsPerVenture + sprint - 1) % Self.taskPool.count
    return (0..<3).map { index in
      var task = Self.taskPool[(offset + index * 3) % Self.taskPool.count]
      task.id = nextDeterministicUUID()
      task.assignedAgentID = nil
      task.isReviewed = false
      task.result = nil
      return task
    }
  }

  private func nextDeterministicUUID() -> UUID {
    let high = randomNumberGenerator.next()
    let low = randomNumberGenerator.next()
    return UUID(uuid: (
      UInt8(truncatingIfNeeded: high >> 56), UInt8(truncatingIfNeeded: high >> 48),
      UInt8(truncatingIfNeeded: high >> 40), UInt8(truncatingIfNeeded: high >> 32),
      UInt8(truncatingIfNeeded: high >> 24), UInt8(truncatingIfNeeded: high >> 16),
      UInt8(truncatingIfNeeded: high >> 8), UInt8(truncatingIfNeeded: high),
      UInt8(truncatingIfNeeded: low >> 56), UInt8(truncatingIfNeeded: low >> 48),
      UInt8(truncatingIfNeeded: low >> 40), UInt8(truncatingIfNeeded: low >> 32),
      UInt8(truncatingIfNeeded: low >> 24), UInt8(truncatingIfNeeded: low >> 16),
      UInt8(truncatingIfNeeded: low >> 8), UInt8(truncatingIfNeeded: low)
    ))
  }

  private func save() {
    guard stage == .game else { return }
    saveCareer()
  }

  private func saveCareer() {
    guard stage == .game || stage == .outcome else { return }
    let payload = CareerSave(
      founderName: founderName,
      doctrine: doctrine,
      sprint: sprint,
      venture: venture,
      intent: intent,
      stats: stats,
      agents: agents,
      tasks: tasks,
      evidence: evidence,
      outcome: careerOutcome,
      randomNumberGenerator: randomNumberGenerator,
      correlatedFailureEvent: correlatedFailureEvent,
      pendingEffects: pendingEffects,
      reportCache: reportCache
    )
    let envelope = SaveEnvelope(version: Self.saveVersion, career: payload)
    if let data = try? JSONEncoder().encode(envelope) {
      UserDefaults.standard.set(data, forKey: Self.saveKey)
      UserDefaults.standard.removeObject(forKey: Self.v3SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.v2SaveKey)
      UserDefaults.standard.removeObject(forKey: Self.legacySaveKey)
    }
  }

  private func sanitizeState() {
    stats.runway = min(365, max(0, stats.runway))
    stats.revenue = min(1_000_000_000, max(0, stats.revenue))
    stats.momentum = clamped(stats.momentum)
    stats.trust = clamped(stats.trust)
    stats.energy = clamped(stats.energy)
    stats.capital = min(1_000_000_000, max(0, stats.capital))
    stats.trackRecord = min(1_000_000, max(0, stats.trackRecord))
    for index in agents.indices {
      agents[index].reliability = clamped(agents[index].reliability)
      agents[index].calibration = safeUnitValue(agents[index].calibration)
      agents[index].drift = safePercentage(agents[index].drift)
      agents[index].trust = safePercentage(agents[index].trust)
    }
  }

  private func safeUnitValue(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  private func safePercentage(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(100, max(0, value))
  }

  private func resolvedOutcome() -> CareerOutcome? {
    if stats.runway <= 0 {
      return CareerOutcome(
        kind: .bankruptcy,
        title: "The runway ran out",
        summary: "The company reached the end of its operating time before finding a sustainable path.",
        score: careerScore
      )
    }
    if stats.energy <= 0 {
      return CareerOutcome(
        kind: .burnout,
        title: "The founder burned out",
        summary: "Oversight outpaced recovery. The company survived its systems, but not their human cost.",
        score: careerScore
      )
    }
    if stats.trust <= 0 {
      return CareerOutcome(
        kind: .trustCollapse,
        title: "Trust collapsed",
        summary: "Unverified work and accumulated drift made the company impossible to operate confidently.",
        score: careerScore
      )
    }
    if venture == Self.maximumVentures && sprint == Self.sprintsPerVenture {
      return victoryOutcome()
    }
    return nil
  }

  private func victoryOutcome() -> CareerOutcome {
    CareerOutcome(
      kind: .victory,
      title: "Two ventures. One track record.",
      summary: "You completed all 24 sprints and built a repeatable way to lead an AI-native company.",
      score: careerScore
    )
  }

  private var careerScore: Int {
    max(0, stats.trackRecord * 10 + stats.revenue + stats.momentum * 20 + stats.trust * 20 + stats.energy * 10)
  }

  private var careerSprintIndex: Int {
    (venture - 1) * Self.sprintsPerVenture + sprint
  }

  private func clamped(_ value: Int) -> Int {
    min(100, max(0, value))
  }

  private static let saveVersion = 4
  private static let saveKey = "solo-unicorn-run-native-save-v4"
  private static let v3SaveKey = "solo-unicorn-run-native-save-v3"
  private static let v2SaveKey = "solo-unicorn-run-native-save-v2"
  private static let legacySaveKey = "solo-unicorn-run-native-save-v1"
  private static let maximumVentures = 2
  private static let sprintsPerVenture = 12

  private static var initialAgents: [SoloAgent] {
    [
      SoloAgent(id: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Nova-1", reliability: 78, calibration: 0.72, drift: 0, trust: 62),
      SoloAgent(id: "stacks", name: "Stacks", initials: "ST", role: .engineering, modelFamily: "Nova-1", reliability: 82, calibration: 0.78, drift: 0, trust: 66),
      SoloAgent(id: "brio", name: "Brio", initials: "BR", role: .marketing, modelFamily: "Atlas-2", reliability: 75, calibration: 0.61, drift: 0, trust: 58)
    ]
  }

  private static let taskPool: [SoloTask] = [
    SoloTask(title: "Build MVP", detail: "Implement the next product slice.", role: .engineering, impact: .momentum(8)),
    SoloTask(title: "Review Market Research", detail: "Synthesize customer signals.", role: .research, impact: .trust(6)),
    SoloTask(title: "Launch Landing Page", detail: "Publish a sharper promise.", role: .marketing, impact: .revenue(500)),
    SoloTask(title: "Fix Critical Bug", detail: "Stabilize the product.", role: .engineering, impact: .trust(8)),
    SoloTask(title: "Contact Early Customers", detail: "Turn conversations into demand.", role: .marketing, impact: .revenue(650)),
    SoloTask(title: "Prepare Investor Update", detail: "Explain progress and risk.", role: .research, impact: .runway(4)),
    SoloTask(title: "Improve Onboarding", detail: "Reduce friction for new users.", role: .general, impact: .revenue(400)),
    SoloTask(title: "Audit Agent Outputs", detail: "Find uncertainty before it compounds.", role: .research, impact: .trust(7)),
    SoloTask(title: "Run Pricing Test", detail: "Test willingness to pay.", role: .marketing, impact: .revenue(800))
  ]
}
