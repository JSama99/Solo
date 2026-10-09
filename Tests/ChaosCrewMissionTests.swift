import XCTest
import CryptoKit
@testable import Solo_Unicorn_Run

// Test tooling only. No implementation of simulation eligibility or resolution.
private struct ChaosMission: Codable, Equatable {
  var schemaVersion = "1"
  var missionVersion = "1"
  let missionId: String
  let seed: UInt64
  let actionBudget: Int
  var initialStateContract = "ordinary startCareer; no installed preparation or resource fixtures"
  var targetSystem = "GameStore"
  let objective: String
  let sourceFingerprint: String
  var relevantCanonRecords = ["rule.determinism", "rule.save_compatibility", "rule.chaos_observation_only", "rule.simulation_authority"]
  var relevantFailurePrecedents = ["FL-001", "FL-002", "FL-003", "FL-004", "FL-005"]
  var invariants = ["attention_bounds", "rejection_scope", "preparation_single_use", "launch_prerequisites", "product_identity", "finance_dedup", "save_version", "save_reload", "seeded_replay", "review_once", "venture_scope", "public_allowlist", "lab_isolation"]
  var allowedActions = ChaosActionKind.allCases.map(\.rawValue)
  var successCondition = "resolved launch or completed bounded search"
  var failureCondition = "source-backed invariant violation; exhaustion is inconclusive"
  var scenarioId: String { "\(missionId)-v\(missionVersion)-s\(seed)" }
}

private enum ChaosActionKind: String, Codable, CaseIterable {
  case assign, delegate, review, approve, commit, route, reload
  case beginLaunch, decisions, release, publicity, execute, resolve, finishLaunch, focus, advance
}
private struct ChaosAction: Codable, Equatable {
  let action: ChaosActionKind
  var taskID: String? = nil
  var agentID: String? = nil
  var option: Int = 0
}
private struct ChaosStep: Codable, Equatable {
  let input: ChaosAction
  let result: String
  let beforeFingerprint: String
  let afterFingerprint: String
  // An explicit public allowlist. Never serialize TaskResult, agents or raw saves here.
  let venture: Int
  let sprint: Int
  let attentionRemaining: Int
  let preparationTracks: [String]
  let launched: Bool
  let operationState: String?
  let violations: [String]
}
private struct ChaosReplay: Codable, Equatable {
  var schemaVersion = "1"
  let mission: ChaosMission
  var simulatorModel = "iPhone 17 Pro Max"
  let runtime: String
  let labID: String
  let initialStateFingerprint: String
  let steps: [ChaosStep]
  let finalStateFingerprint: String
  let classification: String
  var replayFingerprint: String { (try? ChaosEncoding.hash(self)) ?? "ENCODING_ERROR" }
}
private enum ChaosEncoding {
  static func bytes<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    let object = try JSONSerialization.jsonObject(with: encoder.encode(value), options: [.fragmentsAllowed])
    return try JSONSerialization.data(withJSONObject: normalize(object), options: [.sortedKeys, .fragmentsAllowed])
  }
  // Only documented Set fields are sorted. Ordered action, task and finance arrays stay ordered.
  static let setKeys: Set<String> = ["restingAgentIDs", "companyFlags", "completedObjectives", "completedVentureObjectives", "exposedRivalIDs", "processedCoverageEventIDs", "appliedTransactionIDs", "expiredFundingOpportunityIDs", "selectedPerks", "seenConversationIDs", "productTypes", "requiredFlags", "excludedFlags", "unrevealedVarianceAgentIDs", "topicTags", "fitTags", "categories"]
  static func normalize(_ value: Any, key: String = "") -> Any {
    if let dict = value as? [String: Any] { return dict.reduce(into: [String: Any]()) { result, pair in result[pair.key] = normalize(dict[pair.key]!, key: pair.key) } }
    if let array = value as? [Any] {
      let values = array.map { normalize($0) }
      if setKeys.contains(key) { return values.sorted { String(describing: $0) < String(describing: $1) } }
      return values
    }
    return value
  }
  static func hash<T: Encodable>(_ value: T) throws -> String { SHA256.hash(data: try bytes(value)).map { String(format: "%02x", $0) }.joined() }
}

@MainActor
private final class ChaosProductionAdapter {
  // Positive isolation: only this freshly created disposable C1 lab may construct a store.
  static let labID = "40D4F1B3-092A-4E6F-9251-7A686A734B55"
  static func verifyIsolation() throws {
    guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == labID else {
      throw XCTSkip("C1 requires its dedicated lab ID; no GameStore or save action was constructed")
    }
  }
  var store: GameStore
  let mission: ChaosMission
  var steps: [ChaosStep] = []
  let initialFingerprint: String
  let injectedDefect: Bool
  var reviewAttempts: [String: Int] = [:]
  init(mission: ChaosMission, injectedDefect: Bool = false) throws {
    try Self.verifyIsolation()
    self.mission = mission
    self.injectedDefect = injectedDefect
    store = GameStore()
    store.resetCareer() // Positively identified disposable lab only.
    store.founderName = "C1 Lab"
    store.selectedDoctrine = FounderDoctrine.allCases[Int(mission.seed % 3)]
    store.selectedProductType = ProductType.allCases[Int(mission.seed % 4)]
    store.startCareer(seed: mission.seed)
    initialFingerprint = try Self.fingerprint(store)
  }
  // Full private values are hashed only; output includes hashes and public counters.
  private struct State: Encodable {
    let sprint: Int; let venture: Int; let attention: Int; let stage: String
    let stats: FounderStats; let finance: CompanyFinance; let calendar: OperatingCalendar
    let tasks: [SoloTask]; let agents: [SoloAgent]; let evidence: [EvidenceEntry]
    let preparations: ProductLaunchPreparationState; let operation: ProductLaunchOperation?
    let product: LaunchedProductState?; let rng: SeededRandomNumberGenerator
    let sessions: [WorkSessionRecord]; let persistedPayloadHash: String?
  }
  static func fingerprint(_ s: GameStore) throws -> String {
    let raw = UserDefaults.standard.data(forKey: GameStore.saveKey)
    let envelope = try raw.map { try JSONDecoder().decode(SaveEnvelope.self, from: $0) }
    return try ChaosEncoding.hash(State(sprint: s.sprint, venture: s.venture, attention: s.founderAttentionSpent,
      stage: String(describing: s.stage), stats: s.stats, finance: s.finance, calendar: s.operatingCalendar,
      tasks: s.tasks, agents: s.agents, evidence: s.evidence, preparations: s.productLaunchPreparationState,
      operation: s.productLaunchOperation, product: s.launchedProduct, rng: s.randomNumberGenerator, sessions: s.workSessions, persistedPayloadHash: try envelope.map { try ChaosEncoding.hash($0) }))
  }
  private func coreHash() throws -> String {
    // Excludes intentional launch diagnostic counters and action-local Work Session staging.
    try ChaosEncoding.hash([try ChaosEncoding.hash(store.stats), try ChaosEncoding.hash(store.finance),
      try ChaosEncoding.hash(store.tasks), try ChaosEncoding.hash(store.agents), try ChaosEncoding.hash(store.evidence),
      try ChaosEncoding.hash(store.launchedProduct), try ChaosEncoding.hash(store.productLaunchPreparationState),
      String(store.founderAttentionSpent), String(store.sprint), String(store.venture), String(store.randomNumberGenerator.state)])
  }
  @discardableResult func apply(_ input: ChaosAction) throws -> ChaosStep {
    try autoreleasepool { try perform(input) }
  }
  private func perform(_ input: ChaosAction) throws -> ChaosStep {
    guard steps.count < mission.actionBudget else { throw NSError(domain: "C1.action_budget", code: 1) }
    let before = try Self.fingerprint(store), core = try coreHash()
    let taskID = UUID(uuidString: input.taskID ?? "00000000-0000-0000-0000-000000000000")!
    let taskBefore = store.tasks.first { $0.id == taskID }
    let prepBefore = store.canonicalProductLaunchPreparations
    let operationBefore = store.productLaunchOperation
    let productBefore = store.launchedProduct
    let financeBefore = store.finance
    var accepted = false, unavailable = false, violations: [String] = []
    switch input.action {
    case .assign:
      store.assign(agentID: input.agentID, to: taskID)
      accepted = taskBefore != nil && taskBefore?.isReviewed == false && store.tasks.first { $0.id == taskID }?.assignedAgentID == input.agentID
    case .delegate: accepted = store.delegateWorkSession(taskID: taskID)
    case .review:
      store.review(taskID: taskID)
      accepted = taskBefore?.isReviewed == false && store.tasks.first { $0.id == taskID }?.isReviewed == true
    case .approve:
      store.resolveReviewedTask(taskID: taskID, choice: .approve)
      accepted = taskBefore?.resolutionLocked == false && store.tasks.first { $0.id == taskID }?.resolutionLocked == true
    case .commit:
      let sprint = store.sprint, venture = store.venture
      let outcomeBefore = store.careerOutcome
      store.commitSprint()
      accepted = store.sprint != sprint || store.venture != venture || (outcomeBefore == nil && store.careerOutcome != nil)
    case .route:
      // Actual presentation commands; no eligibility mutation.
      store.finishReport()
      if store.awaitingThesisSelection { store.selectThesisAndBegin() }
      if store.pendingChapterMilestone != nil { store.dismissChapterMilestone() }
      if let choices = store.activeDilemma?.choices, !choices.isEmpty { store.selectDilemmaChoice(choices[input.option % choices.count].id) }
      accepted = true
    case .reload:
      guard let raw = UserDefaults.standard.data(forKey: GameStore.saveKey) else { unavailable = true; break }
      let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: raw)
      if envelope.version != 20 { violations.append("save_version") }
      let restored = GameStore(); restored.continueCareer()
      // Compare persisted state, rather than ephemeral UI routing or a non-saved clock update.
      let old = try ChaosEncoding.hash(envelope.career)
      // A real production save command (posture selection) is not introduced for observation.
      // Verify the full loaded payload at its stable public value seams below.
      if restored.sprint != envelope.career.sprint || restored.venture != envelope.career.venture || restored.finance != envelope.career.finance || restored.launchedProduct != envelope.career.launchedProduct || restored.productLaunchPreparationState != envelope.career.productLaunchPreparationState || restored.founderAttentionSpent != envelope.career.founderAttentionSpent { violations.append("save_reload") }
      // Compare every directly stored Codable career field, including hidden state,
      // by hashes only. Derived doctrineProfile/unicornIdentity use explicit sources.
      let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: restored).children.compactMap { child -> (String, Any)? in
        guard let label = child.label else { return nil }
        return (label.hasPrefix("_") ? String(label.dropFirst()) : label, child.value)
      })
      for field in Mirror(reflecting: envelope.career).children {
        guard let key = field.label else { continue }
        let current: Any
        if key == "outcome" { current = restored.careerOutcome as Any }
        else if key == "doctrineProfile" { current = Optional(restored.currentDoctrineProfile) as Any }
        else if key == "unicornIdentity" { current = restored.careerOutcome?.unicornIdentity as Any }
        else if let value = fields[key] { current = value }
        else { violations.append("save_reload_unobserved_field:" + key); continue }
        if let a = field.value as? AnyHashable, let b = current as? AnyHashable {
          if a != b { violations.append("save_reload:" + key) }
          continue
        }
        if let a = field.value as? any Encodable, let b = current as? any Encodable {
          // Standalone Set values have no key context; canonicalize this known field explicitly.
          let av = try JSONSerialization.jsonObject(with: JSONEncoder().encode(a), options: [.fragmentsAllowed])
          let bv = try JSONSerialization.jsonObject(with: JSONEncoder().encode(b), options: [.fragmentsAllowed])
          let ad = try JSONSerialization.data(withJSONObject: ChaosEncoding.normalize(av, key: key), options: [.sortedKeys, .fragmentsAllowed])
          let bd = try JSONSerialization.data(withJSONObject: ChaosEncoding.normalize(bv, key: key), options: [.sortedKeys, .fragmentsAllowed])
          if ad != bd { violations.append("save_reload:" + key) }
        } else { violations.append("save_reload_unencoded_field:" + key) }
      }
      if violations.contains("save_reload:evidence") {
        func paths(_ a: Any, _ b: Any, _ path: String = "evidence") -> [String] {
          if let a = a as? [String: Any], let b = b as? [String: Any] {
            return Set(a.keys).union(b.keys).sorted().flatMap { k in
              guard let av = a[k], let bv = b[k] else { return [path + "." + k] }
              return paths(av, bv, path + "." + k)
            }
          }
          if let a = a as? [Any], let b = b as? [Any] {
            guard a.count == b.count else { return [path + ".count"] }
            return a.indices.flatMap { paths(a[$0], b[$0], path + "[\($0)]") }
          }
          return String(describing: a) == String(describing: b) ? [] : [path]
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("C11-Private-Evidence")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let beforeData = try ChaosEncoding.bytes(envelope.career.evidence)
        let afterData = try ChaosEncoding.bytes(restored.evidence)
        try beforeData.write(to: directory.appendingPathComponent("serialized-evidence.json"))
        try ChaosEncoding.bytes(store.evidence).write(to: directory.appendingPathComponent("live-evidence.json"))
        try afterData.write(to: directory.appendingPathComponent("restored-evidence.json"))
        try ChaosEncoding.bytes(envelope.career.workSessions).write(to: directory.appendingPathComponent("sessions.json"))
        let changed = paths(try JSONSerialization.jsonObject(with: beforeData), try JSONSerialization.jsonObject(with: afterData))
        let publicDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("C1-Evidence")
        try ChaosEncoding.bytes(changed).write(to: publicDirectory.appendingPathComponent("c11-evidence-changed-paths.json"))
      }
      _ = old
      store = restored; accepted = true
    case .beginLaunch:
      accepted = store.beginProductLaunch()
      if accepted {
        if Set(prepBefore.map(\.agentID)) != Set(["aurora", "stacks", "brio"]) { violations.append("launch_prerequisites") }
        if !store.productLaunchPreparationState.records.isEmpty { violations.append("preparation_single_use") }
      }
    case .decisions: accepted = store.advanceProductLaunchToDecisions()
    case .release: accepted = store.selectProductLaunchReleasePosture(input.option % 2 == 0 ? .shipNow : .conservative)
    case .publicity: accepted = store.selectProductLaunchPublicPosture([.bold, .evidenceLed, .quiet][input.option % 3])
    case .execute: accepted = store.executeProductLaunch()
    case .resolve:
      accepted = store.resolveProductLaunch()
      if operationBefore?.state == .resolved && (store.finance != financeBefore || store.launchedProduct != productBefore) { violations.append("finance_dedup") }
      if accepted && store.productLaunchOperation?.canonicalEffectApplicationCount != 1 { violations.append("preparation_single_use") }
    case .finishLaunch: accepted = store.finishProductLaunchPresentation()
    case .focus:
      if let p = store.launchedProduct { accepted = store.selectProductFocus(ProductFocus.allCases[input.option % ProductFocus.allCases.count], expectedCycle: p.nextCycle + (input.option > 4 ? 1 : 0)) } else { unavailable = true }
    case .advance:
      store.advanceOperatingTime(hours: input.option % 3 == 0 ? 0 : 24)
      accepted = input.option % 3 != 0
    }
    if store.founderAttentionSpent < 0 || store.founderAttentionSpent > store.attentionMaximum { violations.append("attention_bounds") }
    if store.productLaunchPreparationState.records.values.contains(where: { $0.venture != store.venture }) { violations.append("venture_scope") }
    if let previous = productBefore, let current = store.launchedProduct, previous.id != current.id { violations.append("product_identity") }
    let coreAfter = try coreHash()
    if taskBefore?.resolutionLocked == true && input.action == .approve && coreAfter != core { violations.append("review_once") }
    if !accepted && !unavailable && input.action != .reload && coreAfter != core { violations.append("rejection_scope") }
    if injectedDefect && input.action == .review {
      let key = input.taskID ?? "missing"
      reviewAttempts[key, default: 0] += 1
      // Deliberately defective test-only observer: it claims a duplicate review
      // was accepted. GameStore itself is not changed. Never enabled in studies.
      if reviewAttempts[key] == 2 { violations.append("synthetic_duplicate_review") }
    }
    let step = ChaosStep(input: input, result: violations.isEmpty ? (unavailable ? "unavailable" : (accepted ? "accepted" : "rejected_by_design")) : "invariant_violation", beforeFingerprint: before, afterFingerprint: try Self.fingerprint(store), venture: store.venture, sprint: store.sprint, attentionRemaining: store.attentionRemaining, preparationTracks: store.canonicalProductLaunchPreparations.map(\.agentID), launched: store.launchedProduct != nil, operationState: store.productLaunchOperation.map { String(describing: $0.state) }, violations: violations)
    steps.append(step); return step
  }
  func replay() throws -> ChaosReplay {
    let classification = steps.contains { !$0.violations.isEmpty } ? "INVARIANT_FAILURE" : (store.launchedProduct != nil ? "REACHABLE" : (store.careerOutcome != nil ? "VALIDLY_BLOCKED" : "SEARCH_EXHAUSTED"))
    return ChaosReplay(mission: mission, runtime: ProcessInfo.processInfo.operatingSystemVersionString, labID: Self.labID, initialStateFingerprint: initialFingerprint, steps: steps, finalStateFingerprint: try Self.fingerprint(store), classification: classification)
  }
  func fuzz() throws {
    try launchRoute()
    var generator = SeededRandomNumberGenerator(seed: mission.seed ^ 0xC1F00D)
    var stale: [String] = steps.compactMap { $0.input.taskID }
    while steps.count < mission.actionBudget {
      let slot = Int(generator.next() % UInt64(ChaosActionKind.allCases.count))
      let kind = ChaosActionKind.allCases[slot]
      let current = store.tasks.map { $0.id.uuidString }
      let candidates = steps.count % 5 == 0 ? stale : current
      let id = candidates.isEmpty ? nil : candidates[Int(generator.next() % UInt64(candidates.count))]
      let agents = store.agents.map(\.id).sorted()
      let agent = agents.isEmpty ? nil : agents[Int(generator.next() % UInt64(agents.count))]
      try apply(.init(action: kind, taskID: id, agentID: agent, option: Int(generator.next() % 8)))
      if let id, !stale.contains(id) { stale.append(id) }
    }
  }
  func launchRoute() throws {
    try apply(.init(action: .route))
    let order = mission.seed % 2 == 0 ? ["aurora", "stacks", "brio"] : ["brio", "aurora", "stacks"]
    for (offset, agent) in order.enumerated() {
      if offset == 2 { try apply(.init(action: .reload)); try apply(.init(action: .commit)); try apply(.init(action: .route, option: Int(mission.seed % 2))) }
      let role: AgentRole = agent == "aurora" ? .research : (agent == "stacks" ? .engineering : .marketing)
      let available = store.tasks.filter { $0.assignedAgentID == nil && !$0.isReviewed }
      guard let task = available.first(where: { $0.role == role && $0.urgency != .critical }) ?? available.first else { break }
      try apply(.init(action: .assign, taskID: task.id.uuidString, agentID: agent))
      if mission.seed % 3 != 1 && store.workSessionFamily(taskID: task.id) != nil { try apply(.init(action: .delegate, taskID: task.id.uuidString)) }
      try apply(.init(action: .review, taskID: task.id.uuidString)); try apply(.init(action: .approve, taskID: task.id.uuidString))
    }
    try apply(.init(action: .reload))
    if try apply(.init(action: .beginLaunch)).result == "accepted" {
      try apply(.init(action: .decisions)); try apply(.init(action: .release, option: Int(mission.seed % 2)))
      try apply(.init(action: .publicity, option: Int(mission.seed % 3))); try apply(.init(action: .execute))
      try apply(.init(action: .reload)); try apply(.init(action: .resolve)); try apply(.init(action: .resolve))
      try apply(.init(action: .finishLaunch)); try apply(.init(action: .route))
    }
  }
}

@MainActor
final class ChaosCrewMissionTests: XCTestCase {
  private func mission(_ seed: UInt64 = 18_180, id: String = "launch", budget: Int = 200) throws -> ChaosMission {
    try ChaosProductionAdapter.verifyIsolation()
    let fingerprint = ProcessInfo.processInfo.environment["C1_SOURCE_FINGERPRINT"] ?? ""
    guard fingerprint.count == 64 && fingerprint.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw XCTSkip("Run with the C1 source manifest fingerprint") }
    return ChaosMission(missionId: id, seed: seed, actionBudget: budget, objective: id == "launch" ? "normal Product Launch reachability" : "bounded production action exploration", sourceFingerprint: fingerprint)
  }
  func testGateAVerticalSliceAndReplay() throws {
    let spec = try mission()
    let client = try ChaosProductionAdapter(mission: spec)
    try client.launchRoute()
    let first = try client.replay()
    XCTAssertEqual(first.classification, "REACHABLE")
    XCTAssertTrue(first.steps.allSatisfy { $0.violations.isEmpty })
    let second = try ChaosProductionAdapter(mission: spec)
    for step in first.steps { try second.apply(step.input) }
    XCTAssertEqual(try second.replay().replayFingerprint, first.replayFingerprint)
    try write(first, name: "gate-a.json")
  }
  private func reproduce(_ replay: ChaosReplay, injected: Bool = false) throws -> ChaosReplay {
    let client = try ChaosProductionAdapter(mission: replay.mission, injectedDefect: injected)
    for step in replay.steps { try client.apply(step.input) }
    return try client.replay()
  }
  private func minimize(_ replay: ChaosReplay, invariant: String, injected: Bool = false) throws -> ChaosReplay {
    var actions = replay.steps.map(\.input)
    var chunk = max(1, actions.count / 2)
    var attempts = 0
    while chunk >= 1 && attempts < 256 {
      var index = 0, changed = false
      while index < actions.count && attempts < 256 {
        let candidate = Array(actions[..<index]) + Array(actions[min(actions.count, index + chunk)...])
        let client = try ChaosProductionAdapter(mission: replay.mission, injectedDefect: injected)
        for action in candidate { try client.apply(action) }
        attempts += 1
        if client.steps.contains(where: { $0.violations.contains(invariant) }) {
          actions = candidate; changed = true
        } else { index += chunk }
      }
      if chunk == 1 && !changed { break }
      chunk = max(1, chunk / 2)
    }
    let client = try ChaosProductionAdapter(mission: replay.mission, injectedDefect: injected)
    for action in actions { try client.apply(action) }
    let minimized = try client.replay()
    // Preserve original if the target disappeared; additional classifications are retained.
    return minimized.steps.contains { $0.violations.contains(invariant) } ? minimized : replay
  }

  func testC11EvidencePersistenceReview() throws {
    let repaired = ProcessInfo.processInfo.environment["C11_EVIDENCE_REPAIRED"] == "1"
    let actions = try JSONDecoder().decode([ChaosAction].self, from: Data(#"[{"action":"route","option":0},{"action":"assign","agentID":"brio","option":0,"taskID":"D02A17E6-DBC0-212F-E1E7-AC85897F2213"},{"action":"review","option":0,"taskID":"D02A17E6-DBC0-212F-E1E7-AC85897F2213"},{"action":"approve","option":0,"taskID":"D02A17E6-DBC0-212F-E1E7-AC85897F2213"},{"action":"assign","agentID":"aurora","option":0,"taskID":"540AD56C-AF98-5DC8-A92C-F2D2F457014D"},{"action":"review","option":0,"taskID":"540AD56C-AF98-5DC8-A92C-F2D2F457014D"},{"action":"approve","option":0,"taskID":"540AD56C-AF98-5DC8-A92C-F2D2F457014D"},{"action":"commit","option":0},{"action":"route","option":1},{"action":"assign","agentID":"stacks","option":0,"taskID":"98B47F9D-00FA-DA58-DEDC-C2D7ED2968FA"},{"action":"review","option":0,"taskID":"98B47F9D-00FA-DA58-DEDC-C2D7ED2968FA"},{"action":"approve","option":0,"taskID":"98B47F9D-00FA-DA58-DEDC-C2D7ED2968FA"},{"action":"beginLaunch","option":0},{"action":"route","option":0},{"action":"assign","agentID":"aurora","option":4,"taskID":"40A3AA9D-6509-92C9-81E0-D5B8F8CB2BFF"},{"action":"commit","agentID":"stacks","option":6,"taskID":"D52F0D6E-E42B-0BE9-5269-36895886E43F"},{"action":"route","agentID":"brio","option":7,"taskID":"D52F0D6E-E42B-0BE9-5269-36895886E43F"},{"action":"assign","agentID":"aurora","option":5,"taskID":"766939C0-0B24-DE1F-3A79-A4A22C1358EA"},{"action":"delegate","agentID":"stacks","option":2,"taskID":"766939C0-0B24-DE1F-3A79-A4A22C1358EA"},{"action":"assign","agentID":"stacks","option":3,"taskID":"766939C0-0B24-DE1F-3A79-A4A22C1358EA"},{"action":"review","agentID":"aurora","option":0,"taskID":"766939C0-0B24-DE1F-3A79-A4A22C1358EA"},{"action":"reload","agentID":"aurora","option":4,"taskID":"766939C0-0B24-DE1F-3A79-A4A22C1358EA"}]"#.utf8))
    let client = try ChaosProductionAdapter(mission: mission(18_279, id: "fuzz"))
    for action in actions { try client.apply(action) }
    let replay = try client.replay()
    XCTAssertEqual(replay.steps.contains { $0.violations.contains("save_reload:evidence") }, !repaired)
    XCTAssertEqual(try reproduce(replay), replay)
    try write(replay, name: repaired ? "c11-evidence-after.json" : "c11-evidence-before.json")
  }

  private func c11Actions() throws -> [ChaosAction] {
    return try JSONDecoder().decode([ChaosAction].self, from: Data(#"[{"action":"route","option":0},{"action":"assign","agentID":"brio","option":0,"taskID":"59EAD5DD-6E46-AB33-D6F0-180F0A3E1478"},{"action":"review","option":0,"taskID":"59EAD5DD-6E46-AB33-D6F0-180F0A3E1478"},{"action":"approve","option":0,"taskID":"59EAD5DD-6E46-AB33-D6F0-180F0A3E1478"},{"action":"assign","agentID":"aurora","option":0,"taskID":"3EBC8DFF-76D8-AF00-853F-51C3092A2DBF"},{"action":"review","option":0,"taskID":"3EBC8DFF-76D8-AF00-853F-51C3092A2DBF"},{"action":"approve","option":0,"taskID":"3EBC8DFF-76D8-AF00-853F-51C3092A2DBF"},{"action":"commit","option":0},{"action":"route","option":1},{"action":"assign","agentID":"stacks","option":0,"taskID":"666204BD-A45D-8780-3D67-E14B51D72718"},{"action":"review","option":0,"taskID":"666204BD-A45D-8780-3D67-E14B51D72718"},{"action":"approve","option":0,"taskID":"666204BD-A45D-8780-3D67-E14B51D72718"},{"action":"beginLaunch","option":0},{"action":"assign","agentID":"brio","option":7,"taskID":"D467893F-D5E4-CA9D-7A11-E80816B202B5"},{"action":"delegate","agentID":"stacks","option":7,"taskID":"D467893F-D5E4-CA9D-7A11-E80816B202B5"},{"action":"assign","agentID":"stacks","option":3,"taskID":"D467893F-D5E4-CA9D-7A11-E80816B202B5"},{"action":"reload","agentID":"aurora","option":3,"taskID":"666204BD-A45D-8780-3D67-E14B51D72718"}]"#.utf8))
  }


  func testC11CompletedAndLegacySessions() throws {
    let client = try ChaosProductionAdapter(mission: mission(18_195, id: "fuzz"))
    for action in try c11Actions().prefix(15) { try client.apply(action) }
    let taskID = UUID(uuidString: "D467893F-D5E4-CA9D-7A11-E80816B202B5")!
    try client.apply(.init(action: .review, taskID: taskID.uuidString))
    let session = try XCTUnwrap(client.store.workSession(for: taskID))
    XCTAssertTrue(session.completed && session.completionApplied)
    let raw = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: raw)
    let canonical = try XCTUnwrap(envelope.career.tasks.first { $0.id == taskID }?.result)
    try client.apply(.init(action: .reload))
    XCTAssertTrue(client.steps.last!.violations.isEmpty)
    XCTAssertEqual(client.store.tasks, envelope.career.tasks)
    // Emulate the documented prototype representation: delivered quality replaced potential,
    // optional canonical quality fields absent. Existing effects are already adjusted.
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
    var career = try XCTUnwrap(object["career"] as? [String: Any])
    var tasks = try XCTUnwrap(career["tasks"] as? [[String: Any]])
    let index = try XCTUnwrap(tasks.firstIndex { $0["id"] as? String == taskID.uuidString })
    func legacy(_ object: Any?) throws -> [String: Any] {
      var result = try XCTUnwrap(object as? [String: Any])
      result["hiddenActualQuality"] = session.deliveredQuality
      result.removeValue(forKey: "hiddenDeliveredQuality")
      result.removeValue(forKey: "hiddenFounderReviewQuality")
      return result
    }
    tasks[index]["result"] = try legacy(tasks[index]["result"]); career["tasks"] = tasks
    var cache = try XCTUnwrap(career["reportCache"] as? [[String: Any]])
    for i in cache.indices where cache[i]["taskID"] as? String == taskID.uuidString && cache[i]["agentID"] as? String == session.agentID {
      cache[i]["result"] = try legacy(cache[i]["result"])
    }
    career["reportCache"] = cache
    var legacyEvidence = try XCTUnwrap(career["evidence"] as? [[String: Any]])
    let evidenceIndex = try XCTUnwrap(legacyEvidence.firstIndex { $0["taskInstanceID"] as? String == taskID.uuidString })
    for key in ["workSessionAgentQuality", "workSessionFounderReviewQuality", "workSessionDeliveredQuality"] { legacyEvidence[evidenceIndex].removeValue(forKey: key) }
    career["evidence"] = legacyEvidence; object["career"] = career
    UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: object), forKey: GameStore.saveKey)
    let loaded = GameStore(); loaded.continueCareer()
    let restored = try XCTUnwrap(loaded.tasks.first { $0.id == taskID }?.result)
    XCTAssertEqual(restored.workSessionPotentialQuality, session.agentPotentialQuality)
    XCTAssertEqual(restored.deliveredQualityForSimulation, session.deliveredQuality)
    XCTAssertEqual(restored.immediateEffects, canonical.immediateEffects, "Migration must not rescale already adjusted effects")
    XCTAssertEqual(restored.founderReviewQualityForSimulation, session.founderReviewQuality)
    XCTAssertTrue(restored.hasCanonicalWorkSessionOutcome)
    let restoredEvidence = try XCTUnwrap(loaded.evidence.first { $0.taskInstanceID == taskID.uuidString })
    XCTAssertEqual(restoredEvidence.workSessionAgentQuality, session.agentPotentialQuality)
    XCTAssertEqual(restoredEvidence.workSessionDeliveredQuality, session.deliveredQuality)
    let again = GameStore(); again.continueCareer()
    XCTAssertEqual(again.tasks, loaded.tasks)
    XCTAssertEqual(again.reportCache, loaded.reportCache)
    XCTAssertEqual(again.workSessions, loaded.workSessions)
    XCTAssertEqual(try ChaosEncoding.hash(again.evidence), try ChaosEncoding.hash(loaded.evidence))
    XCTAssertEqual(try JSONDecoder().decode(SaveEnvelope.self, from: XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))).version, 20)
  }

  func testC11PersistenceReview() throws {
    let repaired = ProcessInfo.processInfo.environment["C11_EXPECT_REPAIRED"] == "1"
    let actions = try c11Actions()
    let client = try ChaosProductionAdapter(mission: mission(18_195, id: "fuzz"))
    for action in actions.dropLast() { try client.apply(action) }
    let live = client.store.tasks
    let raw = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: raw)
    XCTAssertEqual(live, envelope.career.tasks, "Serialization must preserve live task state")
    try client.apply(try XCTUnwrap(actions.last))
    let restored = client.store.tasks
    XCTAssertEqual(restored == live, repaired, "Before/after gate must match explicit repair expectation")
    func fields(_ task: SoloTask) throws -> [String: Any] {
      try XCTUnwrap(JSONSerialization.jsonObject(with: ChaosEncoding.bytes(task)) as? [String: Any])
    }
    func differences(_ a: Any, _ b: Any, _ path: String = "") -> [String] {
      if let a = a as? [String: Any], let b = b as? [String: Any] {
        return Set(a.keys).union(b.keys).sorted().flatMap { k in
          guard let av = a[k], let bv = b[k] else { return [path + "." + k] }
          return differences(av, bv, path + "." + k)
        }
      }
      if let a = a as? [Any], let b = b as? [Any] {
        guard a.count == b.count else { return [path + ".count"] }
        return a.indices.flatMap { differences(a[$0], b[$0], path + "[\($0)]") }
      }
      return String(describing: a) == String(describing: b) ? [] : [path]
    }
    let paths = try live.indices.flatMap { i in try differences(fields(live[i]), fields(restored[i]), "tasks[\(i)]") }
    struct Review: Encodable { let repaired: Bool; let changedPaths: [String]; let liveHash: String; let serializedHash: String; let restoredHash: String }
    try write(Review(repaired: repaired, changedPaths: paths, liveHash: ChaosEncoding.hash(live), serializedHash: ChaosEncoding.hash(envelope.career.tasks), restoredHash: ChaosEncoding.hash(restored)), name: repaired ? "c11-after-review.json" : "c11-before-review.json")
    // Private controlled lab inputs, segregated from public evidence and player-facing output.
    let privateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("C11-Private")
    try FileManager.default.createDirectory(at: privateDirectory, withIntermediateDirectories: true)
    try ChaosEncoding.bytes(live).write(to: privateDirectory.appendingPathComponent("live-tasks.json"))
    try ChaosEncoding.bytes(envelope.career.tasks).write(to: privateDirectory.appendingPathComponent("serialized-tasks.json"))
    try ChaosEncoding.bytes(restored).write(to: privateDirectory.appendingPathComponent("restored-tasks.json"))
    try ChaosEncoding.bytes(envelope.career.workSessions).write(to: privateDirectory.appendingPathComponent("sessions.json"))
    let repeatClient = try ChaosProductionAdapter(mission: mission(18_195, id: "fuzz"))
    for action in actions { try repeatClient.apply(action) }
    XCTAssertEqual(try repeatClient.replay(), try client.replay())
    for seed in [UInt64(18_195), UInt64(18_279)] {
      let original = try ChaosProductionAdapter(mission: mission(seed, id: "fuzz")); try original.fuzz()
      let replay = try original.replay()
      XCTAssertEqual(replay.steps.contains { $0.violations.contains("save_reload:tasks") }, !repaired)
      XCTAssertEqual(try reproduce(replay), replay)
      try write(replay, name: "c11-\(repaired ? "after" : "before")-seed-\(seed).json")
    }
  }

  func testSaveObserverSemanticDiagnosis() throws {
    let client = try ChaosProductionAdapter(mission: mission(18_183))
    try client.apply(.init(action: .route))
    let task = try XCTUnwrap(client.store.tasks.first { $0.id.uuidString == "326E8B33-2BB7-FD92-47A8-D9A810CE70E0" })
    try client.apply(.init(action: .assign, taskID: task.id.uuidString, agentID: "brio"))
    try client.apply(.init(action: .delegate, taskID: task.id.uuidString))
    let saved = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: saved)
    let restored = GameStore(); restored.continueCareer()
    XCTAssertTrue(restored.workSessions == envelope.career.workSessions)
    let left = try ChaosEncoding.bytes(envelope.career.workSessions)
    let right = try ChaosEncoding.bytes(restored.workSessions)
    func differingPaths(_ a: Any, _ b: Any, _ path: String = "") -> [String] {
      if let a = a as? [String: Any], let b = b as? [String: Any] {
        return Set(a.keys).union(b.keys).sorted().flatMap { key in
          guard let av = a[key], let bv = b[key] else { return [path + "." + key] }
          return differingPaths(av, bv, path + "." + key)
        }
      }
      if let a = a as? [Any], let b = b as? [Any] {
        if a.count != b.count { return [path + ".count"] }
        return a.indices.flatMap { differingPaths(a[$0], b[$0], path + "[" + String($0) + "]") }
      }
      return String(describing: a) == String(describing: b) ? [] : [path]
    }
    let paths = differingPaths(try JSONSerialization.jsonObject(with: left), try JSONSerialization.jsonObject(with: right))
    // Diagnostic paths only; no private values in exports.
    try write(paths, name: "observer-differing-paths.json")
    struct Diagnosis: Encodable { let typedEqual: Bool; let encodedEqual: Bool; let differingPaths: [String] }
    try write(Diagnosis(typedEqual: restored.workSessions == envelope.career.workSessions, encodedEqual: left == right, differingPaths: paths), name: "observer-diagnosis.json")
  }
  func testGateBSmallExploration() throws {
    for seed in UInt64(18_180)..<18_184 {
      let client = try ChaosProductionAdapter(mission: mission(seed, id: "fuzz"))
      try client.fuzz()
      let trace = try client.replay()
      XCTAssertEqual(trace.steps.count, 200)
      XCTAssertEqual(try reproduce(trace).replayFingerprint, trace.replayFingerprint)
      try write(trace, name: "smoke-\(seed).json")
    }
  }
  func testContractBudgetAndControlledDefectMinimization() throws {
    let spec = try mission(budget: 10)
    let client = try ChaosProductionAdapter(mission: spec, injectedDefect: true)
    try client.apply(.init(action: .route))
    let task = try XCTUnwrap(client.store.tasks.first)
    try client.apply(.init(action: .assign, taskID: task.id.uuidString, agentID: "aurora"))
    try client.apply(.init(action: .review, taskID: task.id.uuidString))
    try client.apply(.init(action: .reload))
    try client.apply(.init(action: .review, taskID: task.id.uuidString))
    let original = try client.replay()
    XCTAssertTrue(original.steps.contains { $0.violations.contains("synthetic_duplicate_review") })
    let minimal = try minimize(original, invariant: "synthetic_duplicate_review", injected: true)
    XCTAssertEqual(minimal.steps.count, 2)
    XCTAssertEqual(try reproduce(minimal, injected: true), minimal)
    XCTAssertEqual(try minimize(original, invariant: "synthetic_duplicate_review", injected: true), minimal)
    XCTAssertEqual(try mission(), try mission())
    let bounded = try ChaosProductionAdapter(mission: mission(budget: 1))
    try bounded.apply(.init(action: .review))
    XCTAssertEqual(bounded.steps.first?.result, "rejected_by_design")
    XCTAssertThrowsError(try bounded.apply(.init(action: .route)))
    try write(original, name: "controlled-defect-original.json")
    try write(minimal, name: "controlled-defect-minimized.json")
  }
  func testGateDFullBoundedStudy() throws {
    guard ProcessInfo.processInfo.environment["C1_FULL_STUDY"] == "1" else { throw XCTSkip("Explicit bounded study opt-in required") }
    let start = ProcessInfo.processInfo.systemUptime
    var runs: [ChaosReplay] = []
    var minimizedInvariants: Set<String> = []
    for id in ["launch", "fuzz"] {
      for seed in UInt64(18_180)..<18_280 {
        let client = try ChaosProductionAdapter(mission: mission(seed, id: id))
        if id == "launch" { try client.launchRoute() } else { try client.fuzz() }
        let trace = try client.replay()
        let repeated = try reproduce(trace)
        guard repeated.replayFingerprint == trace.replayFingerprint else {
          try write(trace, name: trace.mission.scenarioId + "-replay-expected.json")
          try write(repeated, name: trace.mission.scenarioId + "-replay-observed.json")
          throw NSError(domain: "C1.replay_mismatch." + trace.mission.scenarioId, code: 1)
        }
        let name = trace.mission.scenarioId
        try write(trace, name: name + ".json")
        for invariant in Set(trace.steps.flatMap(\.violations)).subtracting(minimizedInvariants).sorted() {
          minimizedInvariants.insert(invariant)
          let minimal = try minimize(trace, invariant: invariant)
          XCTAssertEqual(try reproduce(minimal).replayFingerprint, minimal.replayFingerprint)
          try write(minimal, name: name + "-min-" + invariant.replacingOccurrences(of: ":", with: "_") + ".json")
        }
        runs.append(trace)
      }
    }
    struct Summary: Encodable {
      let schemaVersion = "1"
      let scenarios: Int; let launchScenarios: Int; let fuzzScenarios: Int
      let attemptedActions: Int; let replayedActions: Int; let elapsedSeconds: Double
      let sourceFingerprint: String; let replayFingerprints: [String: String]
    }
    try write(Summary(scenarios: runs.count, launchScenarios: 100, fuzzScenarios: 100, attemptedActions: runs.reduce(0) { $0 + $1.steps.count }, replayedActions: runs.reduce(0) { $0 + $1.steps.count }, elapsedSeconds: ProcessInfo.processInfo.systemUptime - start, sourceFingerprint: try mission().sourceFingerprint, replayFingerprints: Dictionary(uniqueKeysWithValues: runs.map { ($0.mission.scenarioId, $0.replayFingerprint) })), name: "study-summary.json")
  }
  private func write<T: Encodable>(_ value: T, name: String) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("C1-Evidence")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try ChaosEncoding.bytes(value).write(to: directory.appendingPathComponent(name), options: .atomic)
  }
}
