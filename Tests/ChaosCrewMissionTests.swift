import XCTest
import CryptoKit
import RealityKit
import simd
import UIKit
import SwiftUI
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
  var agentScenario: AgentScenario? = nil
  var worldScenario: WorldScenario? = nil
  var allowedActions = ChaosActionKind.c1Kinds.map(\.rawValue)
  var successCondition = "resolved launch or completed bounded search"
  var failureCondition = "source-backed invariant violation; exhaustion is inconclusive"
  var scenarioId: String { "\(missionId)-v\(missionVersion)-s\(seed)" }
}

private enum ChaosActionKind: String, Codable, CaseIterable {
  case assign, delegate, review, approve, commit, route, reload
  case beginLaunch, decisions, release, publicity, execute, resolve, finishLaunch, focus, advance
  case prepare, manual, sessionStep, submitSession, allocation, preset, autonomy, agentDecision, taskResolution, newCareer
  static let c1Kinds: [Self] = [.assign, .delegate, .review, .approve, .commit, .route, .reload, .beginLaunch, .decisions, .release, .publicity, .execute, .resolve, .finishLaunch, .focus, .advance]
}
// Versioned profile nested in the C1 mission, not a second simulation contract.
private struct AgentScenario: Codable, Equatable {
  var version = "2"
  var participatingAgents = ["aurora", "stacks", "brio"]
  let workloadProfile: String
  let assignmentProfile: String
  let reviewProfile: String
  let evidenceProfile: String
  var maximumSprints = 4
}
private struct AgentObservation: Codable, Equatable {
  let ownershipFingerprint: String
  let evidenceProvenanceFingerprint: String
  let metricsFingerprint: String
  let sessionFingerprint: String
  let lifecycle: [String]
  let workloadBands: [String]
  let evidenceCount: Int
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
  var agentObservation: AgentObservation? = nil
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
  let injectedC2Defect: Bool
  var reviewAttempts: [String: Int] = [:]
  init(mission: ChaosMission, injectedDefect: Bool = false, injectedC2Defect: Bool = false) throws {
    try Self.verifyIsolation()
    self.mission = mission
    self.injectedDefect = injectedDefect
    self.injectedC2Defect = injectedC2Defect
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
  static func metricFingerprint(_ agents: [SoloAgent]) throws -> String {
    // Assignment display text is presentation, not an agent metric cause.
    struct Metrics: Encodable { let id: String; let reliability: Int; let calibration: Double; let trust: Double; let drift: Double; let relationship: Int }
    return try ChaosEncoding.hash(agents.map { Metrics(id: $0.id, reliability: $0.reliability, calibration: $0.calibration, trust: $0.trust, drift: $0.drift, relationship: $0.relationship) })
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
    let operationsBefore = store.agentOperations
    let agentsBefore = store.agents
    let evidenceBefore = store.evidence
    let sessionsBefore = store.workSessions
    let attentionBefore = store.founderAttentionSpent

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
    case .prepare: accepted = store.prepareWorkSession(taskID: taskID)
    case .manual: accepted = store.beginManualWorkSession(taskID: taskID)
    case .sessionStep:
      guard let session = store.workSession(for: taskID) else { break }
      switch session.family {
      case .evidenceTriage:
        accepted = store.classifyEvidence(taskID: taskID, action: EvidenceTriageAction.allCases[abs(input.option) % 3])
      case .systemsReview:
        let steps = session.systemsChallenge?.steps ?? []
        if !steps.isEmpty { accepted = store.selectSystemsReviewStep(taskID: taskID, stepID: steps[abs(input.option) % steps.count].id) }
      case .campaignCalibration:
        let slot = CampaignSlot.allCases[abs(input.option) % CampaignSlot.allCases.count]
        let options = session.campaignChallenge?.presentations(for: slot) ?? []
        if !options.isEmpty { accepted = store.selectCampaignOption(taskID: taskID, slot: slot, optionID: options[(abs(input.option) / 3) % options.count].id) }
      }
    case .submitSession:
      switch store.workSession(for: taskID)?.family {
      case .systemsReview: accepted = store.submitSystemsReview(taskID: taskID)
      case .campaignCalibration: accepted = store.submitCampaignCalibration(taskID: taskID)
      default: break
      }
    case .allocation:
      let domains = AgentOperationalDomain.domains(for: input.agentID ?? "")
      if let domain = domains.first { accepted = store.setAgentOperationsAllocation(agentID: input.agentID!, domain: domain, value: input.option) }
    case .preset: accepted = store.applyAgentOperationsPreset(agentID: input.agentID ?? "", preset: AgentOperationsPreset.allCases[abs(input.option) % 4])
    case .autonomy: accepted = store.setAgentOperationalAutonomy(agentID: input.agentID ?? "", autonomy: AgentOperationalAutonomy.allCases[abs(input.option) % 3])
    case .agentDecision: accepted = store.resolveAgentOperationalDecision(agentID: input.agentID ?? "", choice: AgentOperationalDecisionChoice.allCases[abs(input.option) % AgentOperationalDecisionChoice.allCases.count])
    case .taskResolution:
      let choices: [TaskResolutionChoice] = [.approve, .rework, .shipAnyway, .escalate]
      store.resolveReviewedTask(taskID: taskID, choice: choices[abs(input.option) % 4])
      accepted = taskBefore?.resolutionLocked == false && store.tasks.first { $0.id == taskID }?.resolutionLocked == true
    case .newCareer:
      store.resetCareer(); store.founderName = "C1 Lab"
      store.selectedDoctrine = FounderDoctrine.allCases[Int(mission.seed % 3)]
      store.selectedProductType = ProductType.allCases[Int(mission.seed % 4)]
      store.startCareer(seed: mission.seed &+ UInt64(abs(input.option) + 1)); accepted = true
      if !store.evidence.isEmpty || !store.workSessions.isEmpty { violations.append("career_isolation") }
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
    if mission.agentScenario != nil {
      for agent in store.agents {
        if !(0...100).contains(agent.reliability) || !(0...1).contains(agent.calibration) || !(0...100).contains(agent.trust) || !(0...100).contains(agent.drift) {
          violations.append("agent_metric_bounds:" + agent.id)
        }
        let owned = store.tasks.filter { $0.assignedAgentID == agent.id }
        if owned.count > 1 { violations.append("assignment_identity:" + agent.id) }
        let profile = store.agentOperationsProfile(for: agent.id)
        if profile.allocated > profile.capacity || profile.allocations.values.contains(where: { $0 < 0 }) { violations.append("workload_boundary:" + agent.id) }
      }
      if [.assign, .prepare, .manual, .sessionStep, .submitSession, .allocation, .preset, .autonomy, .delegate, .advance].contains(input.action), try Self.metricFingerprint(store.agents) != Self.metricFingerprint(agentsBefore) {
        violations.append("trust_without_cause")
      }
      if !accepted && store.agentOperations != operationsBefore { violations.append("rejected_operations") }
      if !accepted && store.founderAttentionSpent != attentionBefore { violations.append("rejected_attention") }
      if input.action == .assign && store.founderAttentionSpent != attentionBefore { violations.append("assignment_attention") }
      if input.action == .review && accepted {
        let completed = sessionsBefore.contains { $0.assignmentID == taskID && $0.completed }
        if store.founderAttentionSpent - attentionBefore != (completed ? 0 : 1) { violations.append("review_attention") }
      }
      if input.action == .delegate && accepted {
        let session = sessionsBefore.first { $0.assignmentID == taskID && $0.agentID == taskBefore?.assignedAgentID }
        if store.founderAttentionSpent - attentionBefore != (session?.founderAttentionCharged == true ? 0 : store.delegateAttentionCost) { violations.append("delegate_attention") }
      }
      for session in store.workSessions where session.completionApplied {
        if let previous = sessionsBefore.first(where: { $0.id == session.id }), !previous.completionApplied,
           let owner = taskBefore?.assignedAgentID, owner != session.agentID {
          violations.append("stale_session_application:" + session.assignmentID.uuidString + ":" + session.agentID + ":" + owner)
        }
      }
      let evidenceChanged = try ChaosEncoding.hash(store.evidence) != ChaosEncoding.hash(evidenceBefore)
      if [.review, .approve, .taskResolution].contains(input.action), !accepted,
         (store.agents != agentsBefore || evidenceChanged) {
        violations.append("duplicate_review:" + taskID.uuidString)
      }
      if [.review, .approve, .taskResolution, .commit].contains(input.action) {
        for entry in store.evidence where entry.productObservation == nil && entry.venture == store.venture && entry.sprint == store.sprint {
          if let task = store.tasks.first(where: { $0.id.uuidString == entry.taskInstanceID }),
             let owner = task.assignedAgentID,
             let name = store.agents.first(where: { $0.id == owner })?.name {
            if entry.agent != name { violations.append("evidence_source:" + entry.taskInstanceID) }
            // Observe raw history independently of the production getter being repaired.
            let history = store.workSessions.filter { $0.assignmentID == task.id }
            let matching = history.first { $0.agentID == owner }
            let session = matching ?? history.first
            let provenanceValid = entry.workSessionAgentQuality == nil || (matching != nil
              && entry.workSessionAgentQuality == matching?.agentPotentialQuality)
            // Delivery/review fields can be a legitimate earlier snapshot of this session.
            if !provenanceValid || (injectedC2Defect && input.action == .review && accepted) {
              violations.append((injectedC2Defect ? "synthetic_" : "") + "evidence_provenance:" + entry.taskInstanceID + ":" + (session?.agentID ?? "none") + ":" + owner)
            }
          }
        }
      }
      for entry in store.evidence where !entry.reviewAttempted || entry.verificationState == .evidenceIncomplete {
        if entry.actualQualityRevealed { violations.append("hidden_truth_disclosure:" + entry.taskInstanceID) }
      }
    }
    var step = ChaosStep(input: input, result: violations.isEmpty ? (unavailable ? "unavailable" : (accepted ? "accepted" : "rejected_by_design")) : "invariant_violation", beforeFingerprint: before, afterFingerprint: try Self.fingerprint(store), venture: store.venture, sprint: store.sprint, attentionRemaining: store.attentionRemaining, preparationTracks: store.canonicalProductLaunchPreparations.map(\.agentID), launched: store.launchedProduct != nil, operationState: store.productLaunchOperation.map { String(describing: $0.state) }, violations: violations)
    if mission.agentScenario != nil {
      step.agentObservation = AgentObservation(
        ownershipFingerprint: try ChaosEncoding.hash(store.tasks.map { [$0.id.uuidString, $0.assignedAgentID ?? "unassigned"] }),
        evidenceProvenanceFingerprint: try ChaosEncoding.hash(store.evidence.map { [$0.taskInstanceID, $0.agent, String($0.venture), String($0.sprint)] }),
        metricsFingerprint: try Self.metricFingerprint(store.agents), sessionFingerprint: try ChaosEncoding.hash(store.workSessions),
        lifecycle: store.tasks.map { $0.resolutionLocked ? "resolved" : ($0.isReviewed ? "reviewed" : ($0.assignedAgentID == nil ? "unassigned" : "awaiting_review")) },
        workloadBands: store.agents.map { store.agentOperationsWorkloadBand(for: $0.id).rawValue }, evidenceCount: store.evidence.count)
    }
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
      let slot = Int(generator.next() % UInt64(ChaosActionKind.c1Kinds.count))
      let kind = ChaosActionKind.c1Kinds[slot]
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
  private func reproduce(_ replay: ChaosReplay, injected: Bool = false, c2Injected: Bool = false) throws -> ChaosReplay {
    let client = try ChaosProductionAdapter(mission: replay.mission, injectedDefect: injected, injectedC2Defect: c2Injected)
    for step in replay.steps { try client.apply(step.input) }
    return try client.replay()
  }
  private func minimize(_ replay: ChaosReplay, invariant: String, injected: Bool = false, c2Injected: Bool = false) throws -> ChaosReplay {
    let causalStep = replay.steps.first { $0.violations.contains(invariant) }
    func preservesCause(_ steps: [ChaosStep]) -> Bool {
      guard let original = causalStep else { return false }
      return steps.contains { $0.violations.contains(invariant) && $0.input == original.input && $0.venture == original.venture && $0.sprint == original.sprint }
    }
    var actions = replay.steps.map(\.input)
    var chunk = max(1, actions.count / 2)
    var attempts = 0
    while chunk >= 1 && attempts < 256 {
      var index = 0, changed = false
      while index < actions.count && attempts < 256 {
        let candidate = Array(actions[..<index]) + Array(actions[min(actions.count, index + chunk)...])
        let client = try ChaosProductionAdapter(mission: replay.mission, injectedDefect: injected, injectedC2Defect: c2Injected)
        for action in candidate { try client.apply(action) }
        attempts += 1
        if preservesCause(client.steps) {
          actions = candidate; changed = true
        } else { index += chunk }
      }
      if chunk == 1 && !changed { break }
      chunk = max(1, chunk / 2)
    }
    let client = try ChaosProductionAdapter(mission: replay.mission, injectedDefect: injected, injectedC2Defect: c2Injected)
    for action in actions { try client.apply(action) }
    let minimized = try client.replay()
    // Preserve original if the target disappeared; additional classifications are retained.
    return preservesCause(minimized.steps) ? minimized : replay
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
  private func agentMission(_ seed: UInt64, id: String, budget: Int = 80) throws -> ChaosMission {
    var spec = try mission(seed, id: id, budget: budget)
    spec.missionVersion = "2"
    spec.agentScenario = AgentScenario(workloadProfile: "production allocations and urgency", assignmentProfile: "current and stale tasks; role match and mismatch", reviewProfile: "direct/delegate/manual/delayed/duplicate", evidenceProfile: "shared production ledger; no injected quality")
    spec.allowedActions = ChaosActionKind.allCases.map(\.rawValue)
    spec.relevantFailurePrecedents = ["FL-002", "FL-003", "FL-015"]
    spec.relevantCanonRecords += ["agent.aurora", "agent.stacks", "agent.brio", "system.work_sessions", "system.evidence", "rule.hidden_truth"]
    spec.invariants += ["assignment_identity", "stale_session_application", "evidence_provenance", "agent_metric_bounds", "trust_without_cause", "workload_boundary", "duplicate_review", "career_isolation"]
    return spec
  }
  private func exploreAgents(_ client: ChaosProductionAdapter) throws {
    if client.mission.missionId == "agent-evidence" { try client.launchRoute() }
    try client.apply(.init(action: .route))
    let agents = ["aurora", "stacks", "brio"]
    let offset = Int(client.mission.seed % 3)
    let order = (0..<3).map { agents[($0 + offset) % 3] }
    for agent in order {
      let role: AgentRole = agent == "aurora" ? .research : (agent == "stacks" ? .engineering : .marketing)
      let available = client.store.tasks.filter { !$0.isReviewed && $0.assignedAgentID == nil }
      guard let task = available.first(where: { $0.role == role }) ?? available.first else { continue }
      let id = task.id.uuidString
      try client.apply(.init(action: .preset, agentID: agent, option: Int(client.mission.seed % 4)))
      try client.apply(.init(action: .allocation, agentID: agent, option: 101))
      try client.apply(.init(action: .assign, taskID: id, agentID: agent))
      try client.apply(.init(action: .assign, taskID: id, agentID: agent))
      try client.apply(.init(action: .prepare, taskID: id))
      if client.mission.missionId == "agent-assignment" || client.mission.missionId == "agent-evidence" {
        if client.mission.seed % 2 == 0 { try client.apply(.init(action: .delegate, taskID: id)) }
        let other = agents[(agents.firstIndex(of: agent)! + 1) % 3]
        try client.apply(.init(action: .assign, taskID: id, agentID: other))
        // Incomplete old sessions and completed old sessions both remain authentic.
        try client.apply(.init(action: .delegate, taskID: id))
      } else if client.mission.seed % 2 == 0 {
        try client.apply(.init(action: .delegate, taskID: id))
      } else {
        try client.apply(.init(action: .manual, taskID: id))
        for option in 0..<6 { try client.apply(.init(action: .sessionStep, taskID: id, option: option)) }
        try client.apply(.init(action: .submitSession, taskID: id))
      }
      try client.apply(.init(action: .reload))
      try client.apply(.init(action: .review, taskID: id))
      try client.apply(.init(action: .review, taskID: id))
      try client.apply(.init(action: .taskResolution, taskID: id, option: Int(client.mission.seed % 4)))
      try client.apply(.init(action: .approve, taskID: id))
    }
    let salt: UInt64 = switch client.mission.missionId { case "agent-assignment": 0xA; case "agent-trust": 0xB; case "agent-evidence": 0xC; default: 0xD }
    var rng = SeededRandomNumberGenerator(seed: client.mission.seed ^ 0xC2A6E17 ^ salt)
    let stale = client.steps.compactMap { $0.input.taskID }
    let pool: [ChaosActionKind] = [.assign, .delegate, .review, .taskResolution, .prepare, .manual, .sessionStep, .submitSession, .allocation, .preset, .autonomy, .agentDecision, .reload, .commit, .route]
    var commits = client.steps.filter { $0.input.action == .commit }.count
    while client.steps.count < client.mission.actionBudget - 3 {
      var kind = pool[Int(rng.next() % UInt64(pool.count))]
      if kind == .commit { if commits >= 4 { kind = .reload } else { commits += 1 } }
      let ids = client.steps.count % 3 == 0 ? stale : client.store.tasks.map { $0.id.uuidString }
      let id = ids.isEmpty ? nil : ids[Int(rng.next() % UInt64(ids.count))]
      let agent = agents[Int(rng.next() % 3)]
      let option = kind == .allocation ? [-1, 0, 25, 100, 101][Int(rng.next() % 5)] : Int(rng.next() % 8)
      try client.apply(.init(action: kind, taskID: id, agentID: agent, option: option))
      if kind == .commit && client.steps.count < client.mission.actionBudget - 3 { try client.apply(.init(action: .route, option: Int(rng.next() % 2))) }
    }
    if client.mission.missionId == "agent-lifecycle" {
      try client.apply(.init(action: .newCareer, option: 1))
      try client.apply(.init(action: .review, taskID: stale.first))
    }
    try client.apply(.init(action: .reload))
  }
  func testC2NormalAssignmentWorkloadAndReviewIdempotence() throws {
    let client = try ChaosProductionAdapter(mission: agentMission(19_000, id: "agent-control", budget: 30))
    try client.apply(.init(action: .route))
    let task = try XCTUnwrap(client.store.tasks.first)
    let id = task.id.uuidString
    try client.apply(.init(action: .assign, taskID: id, agentID: "aurora"))
    XCTAssertEqual(client.store.tasks.first { $0.id == task.id }?.assignedAgentID, "aurora")
    let profile = client.store.agentOperationsProfile(for: "aurora")
    XCTAssertEqual(try client.apply(.init(action: .allocation, agentID: "aurora", option: 101)).result, "rejected_by_design")
    XCTAssertEqual(client.store.agentOperationsProfile(for: "aurora"), profile)
    XCTAssertEqual(try client.apply(.init(action: .allocation, agentID: "aurora", option: 25)).result, "accepted")
    try client.apply(.init(action: .delegate, taskID: id))
    try client.apply(.init(action: .review, taskID: id))
    let reviewed = try ChaosProductionAdapter.fingerprint(client.store)
    XCTAssertEqual(try client.apply(.init(action: .review, taskID: id)).result, "rejected_by_design")
    XCTAssertEqual(try ChaosProductionAdapter.fingerprint(client.store), reviewed)
    try client.apply(.init(action: .approve, taskID: id))
    try client.apply(.init(action: .approve, taskID: id))
    try client.apply(.init(action: .reload))
    let trace = try client.replay()
    XCTAssertTrue(trace.steps.allSatisfy { $0.violations.isEmpty })
    XCTAssertEqual(try reproduce(trace), trace)
    try write(trace, name: "c2-control.json")
  }
  func testC2ControlledProvenanceDefectAndMinimization() throws {
    let client = try ChaosProductionAdapter(mission: agentMission(19_000, id: "agent-controlled-defect", budget: 20), injectedC2Defect: true)
    try client.apply(.init(action: .route))
    let id = try XCTUnwrap(client.store.tasks.first).id.uuidString
    try client.apply(.init(action: .assign, taskID: id, agentID: "aurora"))
    try client.apply(.init(action: .review, taskID: id))
    try client.apply(.init(action: .reload))
    let trace = try client.replay()
    let invariant = try XCTUnwrap(trace.steps.flatMap(\.violations).first { $0.hasPrefix("synthetic_evidence_provenance") })
    let minimal = try minimize(trace, invariant: invariant, c2Injected: true)
    XCTAssertLessThan(minimal.steps.count, trace.steps.count)
    XCTAssertEqual(try reproduce(minimal, c2Injected: true), minimal)
    XCTAssertTrue(try reproduce(minimal).steps.allSatisfy { $0.violations.isEmpty })
    try write(trace, name: "c2-controlled-original.json")
    try write(minimal, name: "c2-controlled-minimized.json")
  }
  func testC2VerticalSliceExactReplay() throws {
    for id in ["agent-assignment", "agent-trust", "agent-evidence", "agent-lifecycle"] {
      let client = try ChaosProductionAdapter(mission: agentMission(19_000, id: id))
      try exploreAgents(client)
      let trace = try client.replay()
      XCTAssertEqual(try reproduce(trace), trace)
      try write(trace, name: "c2-slice-" + id + ".json")
    }
  }
  func testC2BoundedAgentStudy() throws {
    guard ProcessInfo.processInfo.environment["C2_FULL_STUDY"] == "1" else { throw XCTSkip("Explicit C2 bounded study opt-in required") }
    let started = ProcessInfo.processInfo.systemUptime
    var fingerprints: [String: String] = [:]
    var actions = 0
    var minimized: Set<String> = []
    for id in ["agent-assignment", "agent-trust", "agent-evidence", "agent-lifecycle"] {
      for seed in UInt64(19_000)..<19_100 {
        guard ProcessInfo.processInfo.systemUptime - started < 2400 else { throw NSError(domain: "C2.wall_budget", code: 1) }
        let client = try ChaosProductionAdapter(mission: agentMission(seed, id: id))
        try exploreAgents(client)
        let trace = try client.replay()
        let repeatTrace = try reproduce(trace)
        if repeatTrace != trace {
          try write(trace, name: trace.mission.scenarioId + "-expected.json")
          try write(repeatTrace, name: trace.mission.scenarioId + "-observed.json")
          throw NSError(domain: "C2.replay_mismatch", code: 1)
        }
        try write(trace, name: trace.mission.scenarioId + ".json")
        fingerprints[trace.mission.scenarioId] = trace.replayFingerprint
        actions += trace.steps.count
        for invariant in Set(trace.steps.flatMap(\.violations)).sorted() {
          // One representative per category, but minimization itself preserves exact task/agent causal identity.
          let parts = invariant.components(separatedBy: ":")
          let category = parts[0] == "save_reload" && parts.count > 1 ? "save_reload_" + parts[1] : parts[0]
          if minimized.insert(category).inserted {
            let minimal = try minimize(trace, invariant: invariant)
            XCTAssertEqual(try reproduce(minimal), minimal)
            try write(minimal, name: trace.mission.scenarioId + "-min-" + category + ".json")
          }
        }
      }
    }
    struct Summary: Encodable { let scenarios: Int; let attemptedActions: Int; let replayedActions: Int; let elapsedSeconds: Double; let sourceFingerprint: String; let replayFingerprints: [String: String] }
    try write(Summary(scenarios: fingerprints.count, attemptedActions: actions, replayedActions: actions, elapsedSeconds: ProcessInfo.processInfo.systemUptime - started, sourceFingerprint: try mission().sourceFingerprint, replayFingerprints: fingerprints), name: "c2-study-summary.json")
  }
  // C2.1 review captures are test-only and run only after the existing positive lab guard.
  func testC21OriginalCandidateCausalReview() throws {
    struct Original: Decodable { let id: String; let invariant: String; let original: ChaosReplay }
    let originals = try JSONDecoder().decode([Original].self, from: Data(#"[{"candidateSHA256": "f156a2ebceabcc941f89a44dc65488c041c7f1cfe199cf1ac8dd8b424f563838", "id": "CF-c2-95f4e5a6cf0f", "invariant": "save_reload:reportCache", "original": {"classification": "INVARIANT_FAILURE", "finalStateFingerprint": "6b4cbb90e29cf1a69229136d89e601d44c65abe1f2343e084fd37fad5dba7d65", "initialStateFingerprint": "ae20a2a47150f36ce0f51a2470e306e3b922f28e87dadb6795c2c932854b63e4", "labID": "40D4F1B3-092A-4E6F-9251-7A686A734B55", "mission": {"actionBudget": 80, "agentScenario": {"assignmentProfile": "current and stale tasks; role match and mismatch", "evidenceProfile": "shared production ledger; no injected quality", "maximumSprints": 4, "participatingAgents": ["aurora", "stacks", "brio"], "reviewProfile": "direct/delegate/manual/delayed/duplicate", "version": "2", "workloadProfile": "production allocations and urgency"}, "allowedActions": ["assign", "delegate", "review", "approve", "commit", "route", "reload", "beginLaunch", "decisions", "release", "publicity", "execute", "resolve", "finishLaunch", "focus", "advance", "prepare", "manual", "sessionStep", "submitSession", "allocation", "preset", "autonomy", "agentDecision", "taskResolution", "newCareer"], "failureCondition": "source-backed invariant violation; exhaustion is inconclusive", "initialStateContract": "ordinary startCareer; no installed preparation or resource fixtures", "invariants": ["attention_bounds", "rejection_scope", "preparation_single_use", "launch_prerequisites", "product_identity", "finance_dedup", "save_version", "save_reload", "seeded_replay", "review_once", "venture_scope", "public_allowlist", "lab_isolation", "assignment_identity", "stale_session_application", "evidence_provenance", "agent_metric_bounds", "trust_without_cause", "workload_boundary", "duplicate_review", "career_isolation"], "missionId": "agent-assignment", "missionVersion": "2", "objective": "bounded production action exploration", "relevantCanonRecords": ["rule.determinism", "rule.save_compatibility", "rule.chaos_observation_only", "rule.simulation_authority", "agent.aurora", "agent.stacks", "agent.brio", "system.work_sessions", "system.evidence", "rule.hidden_truth"], "relevantFailurePrecedents": ["FL-002", "FL-003", "FL-015"], "schemaVersion": "1", "seed": 19006, "sourceFingerprint": "2794faf488926ac52af08a87b31a949e09d60cdbd7f2ba6d79246d02f660bc04", "successCondition": "resolved launch or completed bounded search", "targetSystem": "GameStore"}, "runtime": "Version 26.5 (Build 23F77)", "schemaVersion": "1", "simulatorModel": "iPhone 17 Pro Max", "steps": [{"afterFingerprint": "b09f63c97ab1e78e8d94904686186f0b93089cd527ea4ba482898201d5d3146d", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "2754b6da3f603068aa2eed85502e5ca0f21333519decb6ef10f7c59e4b6c816b", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "ae20a2a47150f36ce0f51a2470e306e3b922f28e87dadb6795c2c932854b63e4", "input": {"action": "route", "option": 0}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "71f737ffc3e56fa0027f7381af7694f9397e18dbf78f149d8d43589b4921b82d", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "cf23054416f13b7532ee7dfce612f832d19212c6ed6f9469bd6e9bcf15a27a10", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "b09f63c97ab1e78e8d94904686186f0b93089cd527ea4ba482898201d5d3146d", "input": {"action": "assign", "agentID": "stacks", "option": 0, "taskID": "A9974718-7B4D-2B6F-F7C8-D42E07A9CB3D"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "503e694aa247cb9fff387fcab636b213b6ea1c2e648454cb041373ba38c77681", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "d597ac9f061296f9a2e65cf444264677d68fce89bde7ee6320f16ce52688540e", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "71f737ffc3e56fa0027f7381af7694f9397e18dbf78f149d8d43589b4921b82d", "input": {"action": "assign", "agentID": "brio", "option": 0, "taskID": "A9974718-7B4D-2B6F-F7C8-D42E07A9CB3D"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "624606d5cc3392cc4d0cc278bf6fb8e718da56f767d58c091042922f2fab9a08", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "d597ac9f061296f9a2e65cf444264677d68fce89bde7ee6320f16ce52688540e", "sessionFingerprint": "7176f080f7ed6b3197201b5c69f980d43427fa64f66bb4a209b2015c06cef723", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 1, "beforeFingerprint": "503e694aa247cb9fff387fcab636b213b6ea1c2e648454cb041373ba38c77681", "input": {"action": "delegate", "option": 0, "taskID": "A9974718-7B4D-2B6F-F7C8-D42E07A9CB3D"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "6b4cbb90e29cf1a69229136d89e601d44c65abe1f2343e084fd37fad5dba7d65", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "d597ac9f061296f9a2e65cf444264677d68fce89bde7ee6320f16ce52688540e", "sessionFingerprint": "7176f080f7ed6b3197201b5c69f980d43427fa64f66bb4a209b2015c06cef723", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 1, "beforeFingerprint": "624606d5cc3392cc4d0cc278bf6fb8e718da56f767d58c091042922f2fab9a08", "input": {"action": "reload", "option": 0}, "launched": false, "preparationTracks": [], "result": "invariant_violation", "sprint": 1, "venture": 1, "violations": ["save_reload:reportCache"]}]}, "traceSHA256": "1bb6e46662d9bf1ea531a16ca5a6b52ebc7d48968349e7aa8039736a4cbf7372"}, {"candidateSHA256": "b805f7262b7d8ad340b63b8d63f1eb231eb8ba8a1cbecb817009b5696efd23fe", "id": "CF-c2-c1c0dda08525", "invariant": "stale_session_application:53D316F2-9AF7-9FFA-A6FB-5D861FD1E233:brio:aurora", "original": {"classification": "INVARIANT_FAILURE", "finalStateFingerprint": "57e8c86753e82a7c40e834baa171817e0de0482c2be7e527725b69ebc527caf5", "initialStateFingerprint": "d084fb2e5f3744a0a14ba18de333d41837f2ae9c729aa13a4efc8c9ae263e892", "labID": "40D4F1B3-092A-4E6F-9251-7A686A734B55", "mission": {"actionBudget": 80, "agentScenario": {"assignmentProfile": "current and stale tasks; role match and mismatch", "evidenceProfile": "shared production ledger; no injected quality", "maximumSprints": 4, "participatingAgents": ["aurora", "stacks", "brio"], "reviewProfile": "direct/delegate/manual/delayed/duplicate", "version": "2", "workloadProfile": "production allocations and urgency"}, "allowedActions": ["assign", "delegate", "review", "approve", "commit", "route", "reload", "beginLaunch", "decisions", "release", "publicity", "execute", "resolve", "finishLaunch", "focus", "advance", "prepare", "manual", "sessionStep", "submitSession", "allocation", "preset", "autonomy", "agentDecision", "taskResolution", "newCareer"], "failureCondition": "source-backed invariant violation; exhaustion is inconclusive", "initialStateContract": "ordinary startCareer; no installed preparation or resource fixtures", "invariants": ["attention_bounds", "rejection_scope", "preparation_single_use", "launch_prerequisites", "product_identity", "finance_dedup", "save_version", "save_reload", "seeded_replay", "review_once", "venture_scope", "public_allowlist", "lab_isolation", "assignment_identity", "stale_session_application", "evidence_provenance", "agent_metric_bounds", "trust_without_cause", "workload_boundary", "duplicate_review", "career_isolation"], "missionId": "agent-assignment", "missionVersion": "2", "objective": "bounded production action exploration", "relevantCanonRecords": ["rule.determinism", "rule.save_compatibility", "rule.chaos_observation_only", "rule.simulation_authority", "agent.aurora", "agent.stacks", "agent.brio", "system.work_sessions", "system.evidence", "rule.hidden_truth"], "relevantFailurePrecedents": ["FL-002", "FL-003", "FL-015"], "schemaVersion": "1", "seed": 19001, "sourceFingerprint": "2794faf488926ac52af08a87b31a949e09d60cdbd7f2ba6d79246d02f660bc04", "successCondition": "resolved launch or completed bounded search", "targetSystem": "GameStore"}, "runtime": "Version 26.5 (Build 23F77)", "schemaVersion": "1", "simulatorModel": "iPhone 17 Pro Max", "steps": [{"afterFingerprint": "63411d177e0b616f744a3a44fafc35fb947f376415aac9efa7bdde1f09293b5e", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "6a765bf1e338e6f66dee814aac6c3700fdd2d304b57ca753ed9c30a220142fd1", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "d084fb2e5f3744a0a14ba18de333d41837f2ae9c729aa13a4efc8c9ae263e892", "input": {"action": "route", "option": 0}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "a44f29718742c23a262097a5e3aaa4bc5224777bc4e4042b3ee44bc6aa25a720", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "cb8b02f7e50741406575a6d963f96656c55c4819892b2187a7eb22b5b4b20286", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "high"]}, "attentionRemaining": 2, "beforeFingerprint": "63411d177e0b616f744a3a44fafc35fb947f376415aac9efa7bdde1f09293b5e", "input": {"action": "assign", "agentID": "brio", "option": 0, "taskID": "53D316F2-9AF7-9FFA-A6FB-5D861FD1E233"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "b9c48e0d8f33074f5c7f799854d83a8c4cda94f4573ea798cfb941a157eab681", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "cb8b02f7e50741406575a6d963f96656c55c4819892b2187a7eb22b5b4b20286", "sessionFingerprint": "0784de89f6de41567921e386a5f522a712875dc9c3cb74a83a9b1e29ad92fd4e", "workloadBands": ["healthy", "healthy", "high"]}, "attentionRemaining": 2, "beforeFingerprint": "a44f29718742c23a262097a5e3aaa4bc5224777bc4e4042b3ee44bc6aa25a720", "input": {"action": "prepare", "option": 0, "taskID": "53D316F2-9AF7-9FFA-A6FB-5D861FD1E233"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "8c9de2393da5750e4b77b09c27af760307255ab12c5d78f2806b755ebfd7c5c6", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "5b56581f52a5536f863bf5f4d366d72571ac9777cff01c75594465596a48cfa7", "sessionFingerprint": "0784de89f6de41567921e386a5f522a712875dc9c3cb74a83a9b1e29ad92fd4e", "workloadBands": ["high", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "b9c48e0d8f33074f5c7f799854d83a8c4cda94f4573ea798cfb941a157eab681", "input": {"action": "assign", "agentID": "aurora", "option": 0, "taskID": "53D316F2-9AF7-9FFA-A6FB-5D861FD1E233"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "57e8c86753e82a7c40e834baa171817e0de0482c2be7e527725b69ebc527caf5", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "5b56581f52a5536f863bf5f4d366d72571ac9777cff01c75594465596a48cfa7", "sessionFingerprint": "73071c62df5c08da8aff6963046d7aeca36d67062c5ab879b745be32c6c3393c", "workloadBands": ["high", "healthy", "healthy"]}, "attentionRemaining": 1, "beforeFingerprint": "8c9de2393da5750e4b77b09c27af760307255ab12c5d78f2806b755ebfd7c5c6", "input": {"action": "delegate", "option": 0, "taskID": "53D316F2-9AF7-9FFA-A6FB-5D861FD1E233"}, "launched": false, "preparationTracks": [], "result": "invariant_violation", "sprint": 1, "venture": 1, "violations": ["stale_session_application:53D316F2-9AF7-9FFA-A6FB-5D861FD1E233:brio:aurora"]}]}, "traceSHA256": "a47f82c7c0968f2d4b41a1c1be7dc2416f736ff3901b8ae799db706bd855b276"}, {"candidateSHA256": "5031c67ddd94aa472d3b2f8f1aa14fd4249f33b02061ddb67d73a91759ba9fa9", "id": "CF-c2-c83e56adeb2a", "invariant": "save_reload:evidence", "original": {"classification": "INVARIANT_FAILURE", "finalStateFingerprint": "f10dcef3147ee51123f3580209ec2cd3b73b686fbcd9a091445c632fb8ca0ed2", "initialStateFingerprint": "5942bb47a375083307f9f5409c70cd9f90bcf760dccf348c5eca6a00dae0d4c1", "labID": "40D4F1B3-092A-4E6F-9251-7A686A734B55", "mission": {"actionBudget": 80, "agentScenario": {"assignmentProfile": "current and stale tasks; role match and mismatch", "evidenceProfile": "shared production ledger; no injected quality", "maximumSprints": 4, "participatingAgents": ["aurora", "stacks", "brio"], "reviewProfile": "direct/delegate/manual/delayed/duplicate", "version": "2", "workloadProfile": "production allocations and urgency"}, "allowedActions": ["assign", "delegate", "review", "approve", "commit", "route", "reload", "beginLaunch", "decisions", "release", "publicity", "execute", "resolve", "finishLaunch", "focus", "advance", "prepare", "manual", "sessionStep", "submitSession", "allocation", "preset", "autonomy", "agentDecision", "taskResolution", "newCareer"], "failureCondition": "source-backed invariant violation; exhaustion is inconclusive", "initialStateContract": "ordinary startCareer; no installed preparation or resource fixtures", "invariants": ["attention_bounds", "rejection_scope", "preparation_single_use", "launch_prerequisites", "product_identity", "finance_dedup", "save_version", "save_reload", "seeded_replay", "review_once", "venture_scope", "public_allowlist", "lab_isolation", "assignment_identity", "stale_session_application", "evidence_provenance", "agent_metric_bounds", "trust_without_cause", "workload_boundary", "duplicate_review", "career_isolation"], "missionId": "agent-assignment", "missionVersion": "2", "objective": "bounded production action exploration", "relevantCanonRecords": ["rule.determinism", "rule.save_compatibility", "rule.chaos_observation_only", "rule.simulation_authority", "agent.aurora", "agent.stacks", "agent.brio", "system.work_sessions", "system.evidence", "rule.hidden_truth"], "relevantFailurePrecedents": ["FL-002", "FL-003", "FL-015"], "schemaVersion": "1", "seed": 19027, "sourceFingerprint": "2794faf488926ac52af08a87b31a949e09d60cdbd7f2ba6d79246d02f660bc04", "successCondition": "resolved launch or completed bounded search", "targetSystem": "GameStore"}, "runtime": "Version 26.5 (Build 23F77)", "schemaVersion": "1", "simulatorModel": "iPhone 17 Pro Max", "steps": [{"afterFingerprint": "0e2b66f9dc04e8045c30e610fc7eb5d274002f8434003a556ec2b592a614a3a5", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "2e1c7e2a8069b3f755301c97af60b0a3793e770e9fe4da8aaeef4d851020b8ba", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "5942bb47a375083307f9f5409c70cd9f90bcf760dccf348c5eca6a00dae0d4c1", "input": {"action": "route", "option": 0}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "8d94f46babdf448b6a607028ebd9b4a6b0737d322e7c713b2e599b896c1871d3", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "a379cccd03190a83a07cfb7ca403a7d8ef6e836df0c61483ca80a1a800d44ec8", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "0e2b66f9dc04e8045c30e610fc7eb5d274002f8434003a556ec2b592a614a3a5", "input": {"action": "assign", "agentID": "brio", "option": 0, "taskID": "A07EC251-8AC2-0282-BCD9-44BDF6F0416D"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "0ecf6e0cb8ff27d3d340d08b1806f1a9e590b43c56961094e0af7a64494e6580", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["awaiting_review", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "a379cccd03190a83a07cfb7ca403a7d8ef6e836df0c61483ca80a1a800d44ec8", "sessionFingerprint": "47b24a0e5155cff05ce416d103cbb8a02f3e94052cb59fe9cc835f698046ae28", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 1, "beforeFingerprint": "8d94f46babdf448b6a607028ebd9b4a6b0737d322e7c713b2e599b896c1871d3", "input": {"action": "delegate", "option": 0, "taskID": "A07EC251-8AC2-0282-BCD9-44BDF6F0416D"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "b2c3746ef51735cdd8c5d1b5c925ea04515d4334ef926fd895a883af5a5ae9b6", "agentObservation": {"evidenceCount": 1, "evidenceProvenanceFingerprint": "0299a7ef66a96018584725192c18d64fda87a9ddb44d143399af75e5ec8c284d", "lifecycle": ["reviewed", "unassigned", "unassigned"], "metricsFingerprint": "0b88f51a687f15e930a4df8527a923f6d4ff2d98c77d14b38aa19cb78f324e25", "ownershipFingerprint": "a379cccd03190a83a07cfb7ca403a7d8ef6e836df0c61483ca80a1a800d44ec8", "sessionFingerprint": "47b24a0e5155cff05ce416d103cbb8a02f3e94052cb59fe9cc835f698046ae28", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 1, "beforeFingerprint": "0ecf6e0cb8ff27d3d340d08b1806f1a9e590b43c56961094e0af7a64494e6580", "input": {"action": "review", "option": 0, "taskID": "A07EC251-8AC2-0282-BCD9-44BDF6F0416D"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "38ae5181049289b1fc8646114768cd0c0ee6eb922da823f51a9f9a9cd74803d8", "agentObservation": {"evidenceCount": 1, "evidenceProvenanceFingerprint": "0299a7ef66a96018584725192c18d64fda87a9ddb44d143399af75e5ec8c284d", "lifecycle": ["resolved", "unassigned", "unassigned"], "metricsFingerprint": "632fa1cab9634798f152b4dbaba9ea5e40dfae101494d7d0200f44f68a83f7cd", "ownershipFingerprint": "a379cccd03190a83a07cfb7ca403a7d8ef6e836df0c61483ca80a1a800d44ec8", "sessionFingerprint": "47b24a0e5155cff05ce416d103cbb8a02f3e94052cb59fe9cc835f698046ae28", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 0, "beforeFingerprint": "b2c3746ef51735cdd8c5d1b5c925ea04515d4334ef926fd895a883af5a5ae9b6", "input": {"action": "taskResolution", "option": 3, "taskID": "A07EC251-8AC2-0282-BCD9-44BDF6F0416D"}, "launched": false, "preparationTracks": ["brio"], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "f10dcef3147ee51123f3580209ec2cd3b73b686fbcd9a091445c632fb8ca0ed2", "agentObservation": {"evidenceCount": 1, "evidenceProvenanceFingerprint": "0299a7ef66a96018584725192c18d64fda87a9ddb44d143399af75e5ec8c284d", "lifecycle": ["resolved", "unassigned", "unassigned"], "metricsFingerprint": "632fa1cab9634798f152b4dbaba9ea5e40dfae101494d7d0200f44f68a83f7cd", "ownershipFingerprint": "a379cccd03190a83a07cfb7ca403a7d8ef6e836df0c61483ca80a1a800d44ec8", "sessionFingerprint": "47b24a0e5155cff05ce416d103cbb8a02f3e94052cb59fe9cc835f698046ae28", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 0, "beforeFingerprint": "38ae5181049289b1fc8646114768cd0c0ee6eb922da823f51a9f9a9cd74803d8", "input": {"action": "reload", "option": 0}, "launched": false, "preparationTracks": ["brio"], "result": "invariant_violation", "sprint": 1, "venture": 1, "violations": ["save_reload:evidence"]}]}, "traceSHA256": "864114dd3e970f088620ff3ecbf3777f3e50aa55dd6651a8261e43aecd982b65"}, {"candidateSHA256": "d25d895bf3fc10a3c11dc054316694ac9d03297c2bf25b13d06a17ee550c20d1", "id": "CF-c2-cf0e171ef9e7", "invariant": "evidence_provenance:90C6E0B3-217E-E71E-2C61-F1F636B453C5:stacks:brio", "original": {"classification": "INVARIANT_FAILURE", "finalStateFingerprint": "b06b59fbb971400c1d5baa4cde475b0c2dd9a1b3168a412a412c336c1552e725", "initialStateFingerprint": "ed98ac893acf84cabc4fc53068e98d6ff90403f0fc17ba8df4316871abe59ed3", "labID": "40D4F1B3-092A-4E6F-9251-7A686A734B55", "mission": {"actionBudget": 80, "agentScenario": {"assignmentProfile": "current and stale tasks; role match and mismatch", "evidenceProfile": "shared production ledger; no injected quality", "maximumSprints": 4, "participatingAgents": ["aurora", "stacks", "brio"], "reviewProfile": "direct/delegate/manual/delayed/duplicate", "version": "2", "workloadProfile": "production allocations and urgency"}, "allowedActions": ["assign", "delegate", "review", "approve", "commit", "route", "reload", "beginLaunch", "decisions", "release", "publicity", "execute", "resolve", "finishLaunch", "focus", "advance", "prepare", "manual", "sessionStep", "submitSession", "allocation", "preset", "autonomy", "agentDecision", "taskResolution", "newCareer"], "failureCondition": "source-backed invariant violation; exhaustion is inconclusive", "initialStateContract": "ordinary startCareer; no installed preparation or resource fixtures", "invariants": ["attention_bounds", "rejection_scope", "preparation_single_use", "launch_prerequisites", "product_identity", "finance_dedup", "save_version", "save_reload", "seeded_replay", "review_once", "venture_scope", "public_allowlist", "lab_isolation", "assignment_identity", "stale_session_application", "evidence_provenance", "agent_metric_bounds", "trust_without_cause", "workload_boundary", "duplicate_review", "career_isolation"], "missionId": "agent-assignment", "missionVersion": "2", "objective": "bounded production action exploration", "relevantCanonRecords": ["rule.determinism", "rule.save_compatibility", "rule.chaos_observation_only", "rule.simulation_authority", "agent.aurora", "agent.stacks", "agent.brio", "system.work_sessions", "system.evidence", "rule.hidden_truth"], "relevantFailurePrecedents": ["FL-002", "FL-003", "FL-015"], "schemaVersion": "1", "seed": 19000, "sourceFingerprint": "2794faf488926ac52af08a87b31a949e09d60cdbd7f2ba6d79246d02f660bc04", "successCondition": "resolved launch or completed bounded search", "targetSystem": "GameStore"}, "runtime": "Version 26.5 (Build 23F77)", "schemaVersion": "1", "simulatorModel": "iPhone 17 Pro Max", "steps": [{"afterFingerprint": "7c78c80b92206a43b25152d3b8c9fce24bf6d363364ac42abc01a57bf0598ca0", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "unassigned", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "c130ca036f039d1022c212e585c1108949386798114215ee309fd7a8796c0e3d", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "healthy", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "ed98ac893acf84cabc4fc53068e98d6ff90403f0fc17ba8df4316871abe59ed3", "input": {"action": "route", "option": 0}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "48405c94217400ea618503fa809c88cd575e3d794c2b3a72f604d6ffe26f466f", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "awaiting_review", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "d2e4a6a07a5bafb548d12bd07728c39de0d092f8ab1d188282d437669d3b6b3d", "sessionFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "workloadBands": ["healthy", "high", "healthy"]}, "attentionRemaining": 2, "beforeFingerprint": "7c78c80b92206a43b25152d3b8c9fce24bf6d363364ac42abc01a57bf0598ca0", "input": {"action": "assign", "agentID": "stacks", "option": 0, "taskID": "90C6E0B3-217E-E71E-2C61-F1F636B453C5"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "17f31cf7350a6f42fad6c95b7dcc4f91ce0fd96f6b2c6d1628d9e832cc7e2526", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "awaiting_review", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "d2e4a6a07a5bafb548d12bd07728c39de0d092f8ab1d188282d437669d3b6b3d", "sessionFingerprint": "4f0d40ef094d9028edd460c189aa0ad2c1851b8d640cab429ad38e4bb65a131e", "workloadBands": ["healthy", "high", "healthy"]}, "attentionRemaining": 1, "beforeFingerprint": "48405c94217400ea618503fa809c88cd575e3d794c2b3a72f604d6ffe26f466f", "input": {"action": "delegate", "option": 0, "taskID": "90C6E0B3-217E-E71E-2C61-F1F636B453C5"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "b2a65668c6548a770864545d90b4082ede16f4092f006ed6c34c252604aeaa5c", "agentObservation": {"evidenceCount": 0, "evidenceProvenanceFingerprint": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", "lifecycle": ["unassigned", "awaiting_review", "unassigned"], "metricsFingerprint": "c53f35e2367a77f17c180867f5e5835d4fb6f87c21c2244deec4be3c1e207bdb", "ownershipFingerprint": "7b1301a6be5198d7ba3942485ff1ad84ef348f1e943d3bbe3d47af4c4fac059c", "sessionFingerprint": "4f0d40ef094d9028edd460c189aa0ad2c1851b8d640cab429ad38e4bb65a131e", "workloadBands": ["healthy", "healthy", "high"]}, "attentionRemaining": 1, "beforeFingerprint": "17f31cf7350a6f42fad6c95b7dcc4f91ce0fd96f6b2c6d1628d9e832cc7e2526", "input": {"action": "assign", "agentID": "brio", "option": 0, "taskID": "90C6E0B3-217E-E71E-2C61-F1F636B453C5"}, "launched": false, "preparationTracks": [], "result": "accepted", "sprint": 1, "venture": 1, "violations": []}, {"afterFingerprint": "b06b59fbb971400c1d5baa4cde475b0c2dd9a1b3168a412a412c336c1552e725", "agentObservation": {"evidenceCount": 1, "evidenceProvenanceFingerprint": "07d412f10e40a7f9a2304e28a45ff15655cbdd57652f3df9d798f19b93413a52", "lifecycle": ["unassigned", "reviewed", "unassigned"], "metricsFingerprint": "0b88f51a687f15e930a4df8527a923f6d4ff2d98c77d14b38aa19cb78f324e25", "ownershipFingerprint": "7b1301a6be5198d7ba3942485ff1ad84ef348f1e943d3bbe3d47af4c4fac059c", "sessionFingerprint": "4f0d40ef094d9028edd460c189aa0ad2c1851b8d640cab429ad38e4bb65a131e", "workloadBands": ["healthy", "healthy", "high"]}, "attentionRemaining": 1, "beforeFingerprint": "b2a65668c6548a770864545d90b4082ede16f4092f006ed6c34c252604aeaa5c", "input": {"action": "review", "option": 0, "taskID": "90C6E0B3-217E-E71E-2C61-F1F636B453C5"}, "launched": false, "preparationTracks": [], "result": "invariant_violation", "sprint": 1, "venture": 1, "violations": ["evidence_provenance:90C6E0B3-217E-E71E-2C61-F1F636B453C5:stacks:brio"]}]}, "traceSHA256": "94f7b8f4a55e9856bf6bdaf0d16da7d34bf1a7ebdabab74788e43c083e909b33"}]"#.utf8))
    let repaired = ProcessInfo.processInfo.environment["C21_EXPECT_REPAIRED"] == "1"
    struct Snapshot: Encodable {
      let tasks: [SoloTask]; let agents: [SoloAgent]; let workSessions: [WorkSessionRecord]
      let reportCache: [CachedTaskReport]; let evidence: [EvidenceEntry]; let attentionSpent: Int
    }
    struct Finding: Encodable {
      let id: String; let originalSourceFingerprint: String; let executionSourceFingerprint: String
      let productionSourceSHA256: String; let target: String; let reproduced: Bool
      let trace: ChaosReplay; let privateSnapshotHashes: [String: String]
    }
    let phase = repaired ? "after" : "before"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("C21-Private-Evidence/" + phase)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for finding in originals {
      let spec = try agentMission(finding.original.mission.seed, id: finding.original.mission.missionId)
      let client = try ChaosProductionAdapter(mission: spec)
      var hashes: [String: String] = [:]
      func capture(_ suffix: String) throws {
        let snapshot = Snapshot(tasks: client.store.tasks, agents: client.store.agents, workSessions: client.store.workSessions, reportCache: client.store.reportCache, evidence: client.store.evidence, attentionSpent: client.store.founderAttentionSpent)
        let data = try ChaosEncoding.bytes(snapshot)
        let name = finding.id + "-" + suffix + "-live.json"
        try data.write(to: directory.appendingPathComponent(name))
        hashes[name] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let serialized = UserDefaults.standard.data(forKey: GameStore.saveKey) {
          let name = finding.id + "-" + suffix + "-serialized.json"
          try serialized.write(to: directory.appendingPathComponent(name))
          hashes[name] = SHA256.hash(data: serialized).map { String(format: "%02x", $0) }.joined()
        }
      }
      try capture("initial")
      for (index, step) in finding.original.steps.enumerated() {
        try capture("step-\(index)-pre")
        try client.apply(step.input)
        try capture("step-\(index)-" + (step.input.action == .reload ? "restored" : "post"))
      }
      let trace = try client.replay()
      let violated = trace.steps.contains { $0.violations.contains(finding.invariant) }
      XCTAssertEqual(violated, !repaired, finding.id)
      if !repaired {
        XCTAssertEqual(trace.initialStateFingerprint, finding.original.initialStateFingerprint)
        XCTAssertEqual(trace.steps, finding.original.steps, finding.id)
        XCTAssertEqual(trace.finalStateFingerprint, finding.original.finalStateFingerprint)
      } else {
        XCTAssertTrue(trace.steps.allSatisfy { $0.violations.isEmpty }, finding.id)
      }
      XCTAssertEqual(try reproduce(trace), trace, finding.id)
      let sourceHash = ProcessInfo.processInfo.environment["C21_GAMESTORE_SHA256"] ?? "unrecorded"
      try write(Finding(id: finding.id, originalSourceFingerprint: finding.original.mission.sourceFingerprint, executionSourceFingerprint: spec.sourceFingerprint, productionSourceSHA256: sourceHash, target: finding.invariant, reproduced: violated, trace: trace, privateSnapshotHashes: hashes), name: "c21-" + phase + "-" + finding.id + ".json")
    }
  }
  func testC21HistoryUsesCurrentOwnerAndPreservesSameAgentSessions() throws {
    guard ProcessInfo.processInfo.environment["C21_EXPECT_REPAIRED"] == "1" else { throw XCTSkip("C2.1 repaired-source gate") }
    for completed in [false, true] {
      let client = try ChaosProductionAdapter(mission: agentMission(19_001, id: "agent-c21-history", budget: 40))
      try client.apply(.init(action: .route))
      let id = "53D316F2-9AF7-9FFA-A6FB-5D861FD1E233"
      let taskID = try XCTUnwrap(UUID(uuidString: id))
      try client.apply(.init(action: .assign, taskID: id, agentID: "brio"))
      XCTAssertTrue(client.store.prepareWorkSession(taskID: taskID))
      if completed { XCTAssertTrue(client.store.delegateWorkSession(taskID: taskID)) }
      let original = try XCTUnwrap(client.store.workSession(for: taskID))
      let historyHash = try ChaosEncoding.hash(client.store.workSessions)
      try client.apply(.init(action: .assign, taskID: id, agentID: "aurora"))
      XCTAssertNil(client.store.workSession(for: taskID))
      XCTAssertEqual(try ChaosEncoding.hash(client.store.workSessions), historyHash)
      let currentResult = try ChaosEncoding.hash(client.store.tasks.first { $0.id == taskID }?.result)
      let attention = client.store.founderAttentionSpent
      XCTAssertFalse(client.store.submitCampaignCalibration(taskID: taskID))
      XCTAssertFalse(client.store.classifyEvidence(taskID: taskID, action: .use))
      XCTAssertFalse(client.store.delegateWorkSession(taskID: taskID), "Aurora cannot reuse Brio's campaign session")
      XCTAssertEqual(client.store.founderAttentionSpent, attention)
      XCTAssertEqual(try ChaosEncoding.hash(client.store.tasks.first { $0.id == taskID }?.result), currentResult)
      try client.apply(.init(action: .reload))
      XCTAssertTrue(client.steps.last!.violations.isEmpty)
      XCTAssertEqual(try ChaosEncoding.hash(client.store.workSessions), historyHash)
      try client.apply(.init(action: .assign, taskID: id, agentID: "brio"))
      XCTAssertEqual(try ChaosEncoding.hash(client.store.workSession(for: taskID)), try ChaosEncoding.hash(Optional(original)))
      if !completed { XCTAssertTrue(client.store.delegateWorkSession(taskID: taskID)) }
      XCTAssertFalse(client.store.delegateWorkSession(taskID: taskID))
      let count = client.store.evidence.count
      client.store.review(taskID: taskID)
      let metricHash = try ChaosProductionAdapter.metricFingerprint(client.store.agents)
      client.store.review(taskID: taskID)
      XCTAssertEqual(try ChaosProductionAdapter.metricFingerprint(client.store.agents), metricHash)
      XCTAssertLessThanOrEqual(client.store.evidence.count, count + 1)
      try client.apply(.init(action: .reload))
      XCTAssertTrue(client.steps.last!.violations.isEmpty)
      let stableHash = try ChaosProductionAdapter.fingerprint(client.store)
      try client.apply(.init(action: .reload))
      XCTAssertEqual(try ChaosProductionAdapter.fingerprint(client.store), stableHash)
      try client.apply(.init(action: .approve, taskID: id))
      try client.apply(.init(action: .commit))
      XCTAssertNil(client.store.tasks.first { $0.id == taskID })
      XCTAssertNotNil(client.store.workSession(for: taskID), "Expired work remains available as history")
      let historicalHash = try ChaosEncoding.hash(client.store.workSessions)
      let spent = client.store.founderAttentionSpent
      XCTAssertFalse(client.store.delegateWorkSession(taskID: taskID))
      XCTAssertFalse(client.store.submitCampaignCalibration(taskID: taskID))
      XCTAssertEqual(client.store.founderAttentionSpent, spent)
      XCTAssertEqual(try ChaosEncoding.hash(client.store.workSessions), historicalHash)
    }
  }
  private func write<T: Encodable>(_ value: T, name: String) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("C1-Evidence")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try ChaosEncoding.bytes(value).write(to: directory.appendingPathComponent(name), options: .atomic)
  }
}

// C3 extends the shared mission/encoding contracts. These types execute only in XCTest.
private struct WorldScenario: Codable, Equatable {
  var version = "3"
  var startingScene = "garage"
  let startingFounderPose: [Float]
  var cameraMode = "founderPOV"
  var movementInputProfile = "explicit fixed-step commands; authored endpoints separately labelled probes"
  var targetInteractions = ["computer", "phone", "tablet", "chair", "whiteboard", "door"]
  let deviceProfile: String
  let reduceMotionEnabled: Bool
  var maximumTransitions = 4
  var maximumFramesPerAction = 240
  var observationScope = "unrendered production RealityKit entities and exposed controllers; not SwiftUI/GPU proof"
}
private struct WorldAction: Codable, Equatable {
  let action: String
  var option = 0
  var frames = 1
  var lateral: Float = 0
  var forward: Float = 0
  var yaw: Float = 0
  static let commands = ["computer", "phone", "tablet", "walk", "move", "stop", "look", "camera", "recenter", "chair", "chairExit", "cancelChair", "whiteboard", "authoredWhiteboardProbe", "door", "requestTraversal", "enterHandoff", "returnGarage", "atlantisMove", "atlantisTurn", "teardown", "recreate", "saveReload", "invalidDestination"]
}
private struct WorldObservation: Codable, Equatable {
  let scene: String
  let founderPosition: [Float]
  let cameraPosition: [Float]
  let cameraRotation: [Float]
  let heading: Float
  let velocity: [Float]
  let cameraMode: String
  let cameraTransition: String?
  let reduceMotion: Bool
  let collision: String
  let motionState: String
  let navigationMode: String
  let interactionPhase: String
  let eligibility: [String: Bool]
  let architectureReady: Bool
  let founderReady: Bool
  let doorOpen: Bool
  let loadedDistricts: [String]
  let entityCounts: [String: Int]
  let handoffs: Int
  let finite: Bool
}
private struct WorldStep: Codable, Equatable {
  let input: WorldAction
  let result: String
  let beforeFingerprint: String
  let afterFingerprint: String
  let observation: WorldObservation
  let violations: [String]
}
private struct WorldReplay: Codable, Equatable {
  var schemaVersion = "1"
  let mission: ChaosMission
  let simulatorModel: String
  let runtime: String
  let labID: String
  let initialStateFingerprint: String
  let steps: [WorldStep]
  let finalStateFingerprint: String
  let classification: String
  var replayFingerprint: String { (try? ChaosEncoding.hash(self)) ?? "ENCODING_ERROR" }
}
@MainActor
private final class ChaosWorldAdapter {
  static let labs = [ChaosProductionAdapter.labID, "37C6DF3F-87F5-4F57-A882-B4B7D11A12F5"]
  let mission: ChaosMission
  var garage: FounderGarageRealityWorld
  var atlantis: AtlantisRealityWorld?
  var groundingProbe: AtlantisGrounding?
  var handoff: FounderAtlantisTraversalHandoff?
  var handoffs = 0
  var transitionCount = 0
  var steps: [WorldStep] = []
  var initial = ""
  let controlled: Bool
  var loadSeconds: Double = 0
  static func isolation() throws {
    guard labs.contains(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "") else { throw XCTSkip("C3 requires a positively identified dedicated lab; no world or store constructed") }
  }
  init(mission: ChaosMission, controlled: Bool = false) throws {
    try Self.isolation()
    self.mission = mission; self.controlled = controlled
    garage = FounderGarageRealityWorld()
  }
  var reduced: Bool { mission.worldScenario!.reduceMotionEnabled }
  func initialize() async throws {
    let started = ProcessInfo.processInfo.systemUptime
    await garage.requestGarageArchitecture(.bundledProductionAsset(name: "founder_garage_v8"), descriptor: .facilityTier0V8)?.value
    await (try garage.requestProductionFounder())?.value
    guard case .ready = garage.architectureLoadState, case .ready = garage.assetLoadState else { throw NSError(domain: "C3.HARNESS_BLOCKED.asset_readiness", code: 1) }
    garage.cameraController.transition(to: .founderPOV, reduceMotion: reduced)
    garage.configureAtlantisTraversal { [weak self] handoff in self?.handoff = handoff; self?.handoffs += 1 }
    garage.deferAtlantisCameraParking(true)
    loadSeconds += ProcessInfo.processInfo.systemUptime - started
    initial = try ChaosEncoding.hash(observe())
  }
  func observe() -> WorldObservation {
    let s = garage.cameraController.snapshot
    let isAtlantis = garage.isFounderPresentedInAtlantis
    let position = isAtlantis ? atlantis!.playerRoot.position : s.playerPosition
    let camera = isAtlantis ? atlantis!.camera : garage.entities.camera
    let cp = camera.position(relativeTo: isAtlantis ? atlantis!.root : garage.entities.root)
    let rotation = camera.orientation(relativeTo: isAtlantis ? atlantis!.root : garage.entities.root).vector
    let heading = isAtlantis ? atlantis!.heading : s.bodyHeading
    let values = [position.x, position.y, position.z, cp.x, cp.y, cp.z, rotation.x, rotation.y, rotation.z, rotation.w, heading, s.velocity.x, s.velocity.y, s.velocity.z]
    func safe(_ x: Float) -> Float { x.isFinite ? x : 0 }
    func count(_ e: Entity) -> Int { 1 + e.children.reduce(0) { $0 + count($1) } }
    func occurrence(_ e: Entity) -> Int { (e.id == garage.activeFounderVisualAdapter.rig.anchor.id ? 1 : 0) + e.children.reduce(0) { $0 + occurrence($1) } }
    let arch: Bool = { if case .ready = garage.architectureLoadState { return true }; return false }()
    let founder: Bool = { if case .ready = garage.assetLoadState { return true }; return false }()
    return WorldObservation(scene: isAtlantis ? "atlantisFounderOwnership" : "garageFounderOwnership", founderPosition: [position.x,position.y,position.z].map(safe), cameraPosition: [cp.x,cp.y,cp.z].map(safe), cameraRotation: [rotation.x,rotation.y,rotation.z,rotation.w].map(safe), heading: safe(heading), velocity: [s.velocity.x,s.velocity.y,s.velocity.z].map(safe), cameraMode: garage.cameraController.state.rawValue, cameraTransition: s.transition.map { String(describing: $0) }, reduceMotion: s.reduceMotion, collision: s.collision, motionState: garage.founderAvatarController.locomotion.state.rawValue, navigationMode: s.mode, interactionPhase: garage.interactionCoordinator.phase.rawValue, eligibility: ["computer":garage.interaction(for:garage.entities.founderComputerInteractionTarget) == .openFounderComputer,"phone":garage.interaction(for:garage.entities.iPhone) == .openFounderPhone,"tablet":garage.interaction(for:garage.entities.iPad) == .openFounderTablet,"chair":garage.chairInteractionAvailable,"whiteboard":garage.whiteboardInteractionFocused,"door":garage.garageDoorControlAvailable], architectureReady: arch, founderReady: founder, doorOpen: garage.garageDoorState.isOpen, loadedDistricts: atlantis?.loadedNames.sorted() ?? [], entityCounts: ["founderOccurrences":occurrence(garage.entities.root)+(atlantis.map { occurrence($0.root) } ?? 0),"garage":count(garage.entities.root),"atlantis":atlantis.map { count($0.root) } ?? 0], handoffs: handoffs, finite: values.allSatisfy(\.isFinite))
  }
  @discardableResult func apply(_ action: WorldAction) async throws -> WorldStep {
    guard steps.count < mission.actionBudget, action.option >= 0, action.frames >= 1, action.frames <= mission.worldScenario!.maximumFramesPerAction, [action.lateral,action.forward,action.yaw].allSatisfy(\.isFinite) else { throw NSError(domain:"C3.resource_budget",code:1) }
    let before = observe(), hash = try ChaosEncoding.hash(before)
    let saveBefore = UserDefaults.standard.data(forKey: GameStore.saveKey)
    let reduced = self.reduced
    var result = "accepted", diagnostics: [String] = []
    switch action.action {
    case "computer", "phone", "tablet":
      let entity = action.action == "computer" ? garage.entities.founderComputerInteractionTarget : action.action == "phone" ? garage.entities.iPhone : garage.entities.iPad
      let actual = garage.interaction(for: entity)
      let intended: FounderWorldInteraction = action.action == "computer" ? .openFounderComputer : action.action == "phone" ? .openFounderPhone : .openFounderTablet
      result = actual == nil ? "rejected_by_design" : "accepted"
      if let actual, actual != intended { diagnostics.append("INCORRECT_INTERACTION_TARGET") }
    case "walk":
      garage.cameraController.beginWalking(reduceMotion: reduced)
      result = garage.cameraController.snapshot.mode == "walking" ? "accepted" : "rejected_by_design"
    case "move", "stop":
      if garage.cameraController.snapshot.mode != "walking" { result = "rejected_by_design" }
      else {
        garage.cameraController.setMovementIntent(action.action == "stop" ? .idle : .init(lateral:action.lateral,forward:action.forward))
        for _ in 0..<action.frames { garage.advanceSession(deltaTime: TimeInterval(FounderGarageCameraConfiguration.fixedStep)) }
      }
    case "look": garage.cameraController.setLookOrientation(.init(yaw: action.yaw, pitch: 0)); for _ in 0..<action.frames { garage.advanceSession(deltaTime:TimeInterval(FounderGarageCameraConfiguration.fixedStep)) }
    case "camera": garage.cameraController.transition(to:FounderGarageCameraState.allCases[action.option % FounderGarageCameraState.allCases.count],reduceMotion:reduced); for _ in 0..<action.frames { garage.advanceSession(deltaTime:TimeInterval(FounderGarageCameraConfiguration.fixedStep)) }
    case "recenter": garage.cameraController.recenterFounderPOV(reduceMotion:reduced)
    case "chair": result = garage.requestChairInteraction(reduceMotion:reduced) ? "accepted" : "rejected_by_design"
    case "chairExit": result = garage.requestChairExit(reduceMotion:reduced) ? "accepted" : "rejected_by_design"
    case "cancelChair": garage.cancelChairInteraction()
    case "whiteboard": result = garage.requestWhiteboardObservation() ? "accepted" : "rejected_by_design"
    case "authoredWhiteboardProbe":
      guard let target = garage.spatialSpecification.facilityTier0InteractionSpace?.founderInteractionTarget(for:.whiteboard) else { result="unsupported_action"; break }
      result = garage.cameraController.beginInteractionStanding(at:target.approach,reduceMotion:reduced) ? "accepted" : "rejected_by_design"
    case "door": garage.setGarageDoor(action.option == 0 ? .closed : .open,reduceMotion:reduced)
    case "requestTraversal":
      let old = handoffs; garage.requestAtlantisTraversalIfNeeded(); result = old == handoffs ? "rejected_by_design" : "accepted_transition"
    case "enterHandoff":
      guard transitionCount < mission.worldScenario!.maximumTransitions else { throw NSError(domain:"C3.transition_budget",code:1) }
      guard let handoff, !garage.isFounderPresentedInAtlantis else { result="rejected_by_design"; break }
      let world: AtlantisRealityWorld
      if let current = atlantis { world = current } else { let manifest = try AtlantisAssetManifest.load(); world = AtlantisRealityWorld(manifest:manifest); groundingProbe=AtlantisGrounding(traversal:manifest.traversal); atlantis=world }
      let started = ProcessInfo.processInfo.systemUptime
      guard await world.prepareFounderGarageExterior() else { result="unsupported_action"; break }
      loadSeconds += ProcessInfo.processInfo.systemUptime-started
      world.enterFromFounderGarage(handoff); garage.transferFounderPresentation(to:world,reduceMotion:reduced)
      if simd_distance(world.playerRoot.position, AtlantisSpatialContract.fromFounderGarage(handoff.garagePosition)) > 0.0001 { diagnostics.append("INVALID_WORLD_TRANSITION") }
      transitionCount += 1; result="accepted_transition"
    case "returnGarage":
      guard let world=atlantis, garage.isFounderPresentedInAtlantis else { result="rejected_by_design"; break }
      guard transitionCount < mission.worldScenario!.maximumTransitions else { throw NSError(domain:"C3.transition_budget",code:1) }
      garage.restoreFounderPresentation(from:world); handoff=nil; transitionCount += 1; result="accepted_transition"
    case "atlantisMove":
      guard garage.isFounderPresentedInAtlantis, let world=atlantis else { result="rejected_by_design"; break }
      let p=world.playerRoot.position
      for _ in 0..<action.frames { world.move(input:action.forward,delta:Double(FounderGarageCameraConfiguration.fixedStep)) }
      if p == world.playerRoot.position, action.forward != 0 { result="rejected_by_design" }
      let next=world.playerRoot.position
      if let ground=groundingProbe?.height(at:next,loaded:world.loadedNames,referenceHeight:next.y), abs(ground-next.y)>0.0001 { diagnostics.append("COLLISION_OR_GROUNDING") }
    case "atlantisTurn": guard let world=atlantis, garage.isFounderPresentedInAtlantis else {result="rejected_by_design";break};world.turn(action.yaw)
    case "teardown": garage.stopCameraUpdates(); atlantis?.stop()
    case "recreate":
      if garage.isFounderPresentedInAtlantis, let world=atlantis { garage.restoreFounderPresentation(from:world) }
      garage.stopCameraUpdates();atlantis?.stop();atlantis=nil;garage=FounderGarageRealityWorld();handoff=nil;await (try garage.requestProductionFounder())?.value
      await garage.requestGarageArchitecture(.bundledProductionAsset(name:"founder_garage_v8"),descriptor:.facilityTier0V8)?.value
      garage.configureAtlantisTraversal { [weak self] h in self?.handoff=h;self?.handoffs += 1 };garage.deferAtlantisCameraParking(true)
      garage.cameraController.transition(to:.founderPOV,reduceMotion:reduced)
    case "saveReload", "invalidDestination": result="unsupported_action" // No public world persistence/request API; never fake a save or invalid request.
    default: result="unsupported_action"
    }
    let observed=observe()
    if !observed.finite { diagnostics.append("INVALID_MOVEMENT_STATE") }
    if observed.reduceMotion && observed.cameraTransition != nil { diagnostics.append("REDUCE_MOTION_VIOLATION") }
    if observed.entityCounts["founderOccurrences"] != 1 { diagnostics.append("DUPLICATE_SCENE_ENTITY") }
    if result == "rejected_by_design", action.action != "atlantisMove", hash != (try ChaosEncoding.hash(observed)) { diagnostics.append("REJECTED_WORLD_MUTATION") }
    if action.action == "stop", action.frames >= 120, garage.interactionCoordinator.phase == .idle, simd_length(garage.cameraController.snapshot.velocity)>0.001 { diagnostics.append("INVALID_MOVEMENT_STATE") }
    if UserDefaults.standard.data(forKey:GameStore.saveKey) != saveBefore { diagnostics.append("SAVE_RELOAD_WORLD_STATE") }
    if controlled && action.action == "computer" && result == "accepted" { diagnostics.append("synthetic_incorrect_interaction_target") }
    let step=WorldStep(input:action,result:diagnostics.isEmpty ? result : "invariant_violation",beforeFingerprint:hash,afterFingerprint:try ChaosEncoding.hash(observed),observation:observed,violations:diagnostics)
    steps.append(step);return step
  }
  func replay() throws -> WorldReplay {
    let cls = steps.contains{$0.result == "invariant_violation"} ? "INVARIANT_FAILURE" : steps.contains{$0.result == "accepted_transition"} || steps.contains{$0.input.action == "computer" && $0.result == "accepted"} ? "REACHABLE" : "SEARCH_EXHAUSTED"
    return WorldReplay(mission:mission,simulatorModel:mission.worldScenario!.deviceProfile,runtime:ProcessInfo.processInfo.operatingSystemVersionString,labID:ProcessInfo.processInfo.environment["SIMULATOR_UDID"]!,initialStateFingerprint:initial,steps:steps,finalStateFingerprint:try ChaosEncoding.hash(observe()),classification:cls)
  }
  func stop() { garage.stopCameraUpdates();atlantis?.stop() }
}

@MainActor
final class ChaosCrewWorldTests: XCTestCase {
  private func mission(_ seed: UInt64 = 20_000, id: String = "world-garage") throws -> ChaosMission {
    try ChaosWorldAdapter.isolation()
    let fp=ProcessInfo.processInfo.environment["C1_SOURCE_FINGERPRINT"] ?? ""
    guard fp.count == 64 else { throw XCTSkip("C3 source fingerprint required") }
    let pose=FounderGarageCameraConfiguration(spatial:.standard).seatedPlayerState.playerPose
    let lab=ProcessInfo.processInfo.environment["SIMULATOR_UDID"]!
    var m=ChaosMission(missionId:id,seed:seed,actionBudget:24,objective:"bounded production spatial contracts; rendering gaps explicit",sourceFingerprint:fp)
    m.missionVersion="3";m.targetSystem="FounderGarageRealityWorld/AtlantisRealityWorld";m.initialStateContract="production v8 Garage and production Founder loaded; canonical seated pose; no GameStore constructed"
    m.allowedActions=WorldAction.commands;m.invariants=["finite_spatial_state","interaction_target","rejection_scope","reduce_motion","handoff_transform","grounding","save_domain_isolation"]
    m.worldScenario=WorldScenario(startingFounderPose:[pose.position.x,pose.position.y,pose.position.z,pose.heading],deviceProfile:lab == ChaosProductionAdapter.labID ? "iPhone 17 Pro Max" : "iPad Air 11-inch (M4)",reduceMotionEnabled:seed % 2 == 0)
    m.relevantFailurePrecedents=["FL-002","FL-003","FL-010","FL-011","FL-014","FL-015"];m.relevantCanonRecords=["location.founder_garage","location.atlantis","rule.reduce_motion_visual","rule.presentation_separation","rule.determinism"]
    return m
  }
  private func run(_ m: ChaosMission, actions: [WorldAction], controlled: Bool = false) async throws -> WorldReplay {
    let w=try ChaosWorldAdapter(mission:m,controlled:controlled);defer{w.stop()};try await w.initialize()
    for a in actions {try await w.apply(a)}
    return try w.replay()
  }
  private func write<T: Encodable>(_ value: T, name: String) throws {
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent("C3-World-Evidence")
    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
    try ChaosEncoding.bytes(value).write(to:dir.appendingPathComponent(name),options:.atomic)
  }
  // C1's bounded deletion-search strategy adapted for asynchronous real asset initialization.
  // Keeps causal command, observed scene and exact diagnostic; same chunk schedule and bounded retries.
  private func minimize(_ original: WorldReplay, invariant: String, controlled: Bool = false) async throws -> WorldReplay {
    let causal=try XCTUnwrap(original.steps.first{$0.violations.contains(invariant)})
    var actions=original.steps.map(\.input), chunk=max(1,original.steps.count/2), attempts=0
    func preserves(_ r: WorldReplay)->Bool {r.steps.contains{$0.input == causal.input && $0.observation.scene == causal.observation.scene && $0.violations.contains(invariant)}}
    while chunk>=1 && attempts<64 {
      var index=0,changed=false
      while index<actions.count && attempts<64 {
        let next=Array(actions[..<index])+Array(actions[min(actions.count,index+chunk)...]);attempts += 1
        let candidate=try await run(original.mission,actions:next,controlled:controlled)
        if preserves(candidate){actions=next;changed=true}else{index += chunk}
      }
      if chunk == 1 && !changed{break};chunk=max(1,chunk/2)
    }
    let result=try await run(original.mission,actions:actions,controlled:controlled)
    return preserves(result) ? result : original
  }
  func testC3GarageVerticalSliceExactReplay() async throws {
    let m=try mission(),actions:[WorldAction]=[.init(action:"computer"),.init(action:"walk"),.init(action:"move",frames:120,forward:1),.init(action:"stop",frames:120),.init(action:"camera",option:1,frames:120),.init(action:"camera",frames:120)]
    let first=try await run(m,actions:actions),repeated=try await run(m,actions:actions)
    XCTAssertEqual(first,repeated);XCTAssertTrue(first.steps.allSatisfy{$0.violations.isEmpty});XCTAssertNotEqual(first.steps[1].observation.founderPosition,first.steps[2].observation.founderPosition)
    try write(first,name:"gate-a.json")
  }
  func testC3ControlledDefectMinimizesAndReplays() async throws {
    let m=try mission(),original=try await run(m,actions:[.init(action:"look",yaw:0.1),.init(action:"recenter"),.init(action:"computer"),.init(action:"camera",option:1)],controlled:true)
    let small=try await minimize(original,invariant:"synthetic_incorrect_interaction_target",controlled:true)
    XCTAssertEqual(small.steps.count,1);let reproduced=try await run(m,actions:small.steps.map(\.input),controlled:true);XCTAssertEqual(reproduced,small)
    try write(original,name:"controlled-original.json");try write(small,name:"controlled-minimized.json")
  }
  func testC3BudgetIsolationAndUnsupportedCoverage() async throws {
    let w=try ChaosWorldAdapter(mission:mission());defer{w.stop()};try await w.initialize()
    let before=UserDefaults.standard.data(forKey:GameStore.saveKey)
    let step=try await w.apply(.init(action:"saveReload"));XCTAssertEqual(step.result,"unsupported_action")
    do{_ = try await w.apply(.init(action:"move",frames:241));XCTFail("frame budget") }catch{XCTAssertTrue(w.steps.count == 1)}
    XCTAssertEqual(UserDefaults.standard.data(forKey:GameStore.saveKey),before)
    XCTAssertEqual(AtlantisS4CameraBias.heroPauseWindow(position:AtlantisSpatialContract.founderGarage,heading:0,reduceMotion:true),false)
  }
  func testC3BoundedWorldStudy() async throws {
    guard ProcessInfo.processInfo.environment["C3_FULL_STUDY"] == "1" else {throw XCTSkip("C3 full study explicit opt-in")}
    let started=ProcessInfo.processInfo.systemUptime
    let groups=["world-garage","world-traversal","world-camera","world-lifecycle"]
    var fingerprints:[String:String]=[:],actionsTotal=0,minimized=Set<String>()
    for group in groups {for seed in UInt64(20_000)..<20_100 {
      guard ProcessInfo.processInfo.systemUptime-started<3600 else {throw NSError(domain:"C3.study_time_budget",code:1)}
      let m=try mission(seed,id:group),w=try ChaosWorldAdapter(mission:m);try await w.initialize()
      var inputs:[WorldAction]
      switch group {
      case "world-garage":inputs=[.init(action:"computer"),.init(action:"phone"),.init(action:"tablet"),.init(action:"walk"),.init(action:"computer"),.init(action:"whiteboard"),.init(action:"move",frames:120,lateral:Float(Int(seed%3)-1),forward:Float(Int(seed%5)-2)/2),.init(action:"stop",frames:120),.init(action:"chair"),.init(action:"stop",frames:240),.init(action:"cancelChair"),.init(action:"authoredWhiteboardProbe"),.init(action:"whiteboard"),.init(action:"whiteboard")]
      case "world-traversal":inputs=[.init(action:"requestTraversal"),.init(action:"enterHandoff"),.init(action:"door",option:1),.init(action:"walk")]+Array(repeating:.init(action:"move",frames:240,forward:1),count:8)+[.init(action:"requestTraversal"),.init(action:"requestTraversal"),.init(action:"enterHandoff"),.init(action:"enterHandoff"),.init(action:"atlantisMove",frames:120,forward:seed%3 == 0 ? -1 : 1),.init(action:"atlantisTurn",yaw:Float(Int(seed%3)-1)*0.2),.init(action:"atlantisMove",frames:120,forward:1),.init(action:"returnGarage"),.init(action:"returnGarage")]
      case "world-camera":inputs=[.init(action:"look",frames:120,yaw:Float(Int(seed%9)-4)),.init(action:"recenter"),.init(action:"camera",option:Int(seed%6),frames:120),.init(action:"computer"),.init(action:"camera",frames:120),.init(action:"walk"),.init(action:"move",frames:120,forward:1),.init(action:"look",frames:120,yaw:0.2),.init(action:"stop",frames:120),.init(action:"move",frames:120,forward:-1),.init(action:"stop",frames:120),.init(action:"camera",frames:120)]
      default:inputs=[.init(action:"computer"),.init(action:"door",option:Int(seed%2)),.init(action:"walk"),.init(action:"move",frames:120,forward:1),.init(action:"teardown"),.init(action:"recreate"),.init(action:"computer"),.init(action:"saveReload"),.init(action:"invalidDestination"),.init(action:"teardown")]
      }
      for a in inputs {try await w.apply(a)}
      let first=try w.replay();let seconds=w.loadSeconds;w.stop()
      let second=try await run(m,actions:inputs)
      if first != second {try write(first,name:m.scenarioId+"-expected.json");try write(second,name:m.scenarioId+"-observed.json")}
      XCTAssertEqual(first,second,m.scenarioId)
      try write(first,name:m.scenarioId+".json")
      struct Performance:Encodable {let scenario:String;let unrenderedAssetLoadSeconds:Double;let processFootprintMB:Double;let observationScope:String}
      try write(Performance(scenario:m.scenarioId,unrenderedAssetLoadSeconds:seconds,processFootprintMB:AtlantisMemory.footprintMB(),observationScope:"simulator process sample; not peak physical-device memory, GPU FPS or rendered load"),name:m.scenarioId+"-performance.json")
      for diagnostic in Set(first.steps.flatMap(\.violations)).sorted() where minimized.insert(diagnostic).inserted {
        let small=try await minimize(first,invariant:diagnostic);let reproduced=try await run(m,actions:small.steps.map(\.input));XCTAssertEqual(reproduced,small);try write(small,name:m.scenarioId+"-min-"+diagnostic+".json")
      }
      fingerprints[m.scenarioId]=first.replayFingerprint;actionsTotal += first.steps.count
      print("C3_PROGRESS \(group) seed=\(seed) scenarios=\(fingerprints.count)")
    }}
    struct Summary:Encodable {let scenarios:Int;let attemptedActions:Int;let replayedActions:Int;let sourceFingerprint:String;let elapsedSeconds:Double;let replayFingerprints:[String:String]}
    try write(Summary(scenarios:fingerprints.count,attemptedActions:actionsTotal,replayedActions:actionsTotal,sourceFingerprint:try mission().sourceFingerprint,elapsedSeconds:ProcessInfo.processInfo.systemUptime-started,replayFingerprints:fingerprints),name:"study-summary.json")
  }
}

// C3.1 test-only rendered host. Production subscription handlers execute first;
// observation runs after each real SceneEvents.Update without a replacement update engine.
@MainActor
private final class C31ContactRecorder {
  var names: [String] = []
  var subscription: EventSubscription?
}
@MainActor
private final class C31RealityHost {
  let view: UIView
  let window: UIWindow
  let priorWindow: UIWindow?
  let recorder = C31ContactRecorder()
  var contacts: [String] {recorder.names}
  init(root: Entity, install: @escaping (RealityViewCameraContent) -> Void) throws {
    try ChaosWorldAdapter.isolation()
    let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first)
    priorWindow=scene.windows.first(where:{$0.isKeyWindow})
    window=UIWindow(windowScene:scene)
    let record=recorder
    let controller=UIHostingController(rootView:AnyView(RealityView { content in content.add(root);record.subscription=content.subscribe(to:CollisionEvents.Began.self) { event in record.names.append(event.entityA.name+" / "+event.entityB.name) };install(content) }))
    window.rootViewController=controller;view=controller.view;window.makeKeyAndVisible()
  }
  func close() {recorder.subscription?.cancel();window.isHidden=true;window.rootViewController=nil;priorWindow?.makeKey()}
  func capture(_ name: String, directory: URL) async throws {
    let image=UIGraphicsImageRenderer(bounds:window.bounds).image {_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)}
    guard let data=image.pngData() else {throw NSError(domain:"C31.HARNESS_BLOCKED.capture",code:1)}
    try data.write(to:directory.appendingPathComponent(name+".png"))
  }
}
private struct C31CameraFrame: Codable {
  let callback: Int; let elapsed: Double; let delta: Double; let phase: String
  let forward: Float; let turn: Float; let position: [Float]; let heading: Float
  let yaw: Float; let camera: [Float]; let sourcePauseWindow: Bool
}
@MainActor
final class ChaosCrewSpatialClosureTests: XCTestCase {
  private func directory() throws -> URL {
    try ChaosWorldAdapter.isolation()
    let d=FileManager.default.temporaryDirectory.appendingPathComponent("C31-Live-Evidence")
    try FileManager.default.createDirectory(at:d,withIntermediateDirectories:true);return d
  }
  private func mission(_ id: String, reduced: Bool) throws -> ChaosMission {
    let fp=ProcessInfo.processInfo.environment["C1_SOURCE_FINGERPRINT"] ?? ""
    guard fp.count==64 else {throw XCTSkip("C3.1 source manifest required")}
    let pose=FounderGarageCameraConfiguration(spatial:.standard).seatedPlayerState.playerPose
    var m=ChaosMission(missionId:id,seed:reduced ? 20100 : 20101,actionBudget:24,objective:"focused C3.1 real callback observation",sourceFingerprint:fp)
    m.missionVersion="3";m.targetSystem="FounderGarageRealityWorld/AtlantisRealityWorld";m.allowedActions=WorldAction.commands
    m.worldScenario=WorldScenario(startingFounderPose:[pose.position.x,pose.position.y,pose.position.z,pose.heading],deviceProfile:ProcessInfo.processInfo.environment["SIMULATOR_UDID"]==ChaosProductionAdapter.labID ? "iPhone 17 Pro Max" : "iPad Air 11-inch (M4)",reduceMotionEnabled:reduced)
    return m
  }
  private func wait(_ predicate: () -> Bool, seconds: Double, label: String) async throws {
    let start=ProcessInfo.processInfo.systemUptime
    while !predicate() {
      if ProcessInfo.processInfo.systemUptime-start>seconds {throw NSError(domain:"C31.HARNESS_BLOCKED.timeout."+label,code:1)}
      try await Task.sleep(for:.milliseconds(20))
    }
  }
  private func write<T:Encodable>(_ value:T,name:String) throws {try ChaosEncoding.bytes(value).write(to:directory().appendingPathComponent(name))}
  func testC31LiveCameraHeldReleasePauseRestart() async throws {try await camera(reduced:false)}
  func testC31LiveCameraReduceMotion() async throws {try await camera(reduced:true)}
  private func camera(reduced: Bool) async throws {
    let client=try ChaosWorldAdapter(mission:mission("world-camera-c31",reduced:reduced));defer{client.stop()};try await client.initialize()
    // Reuse the original C3 production command sequence to obtain a real handoff.
    try await client.apply(.init(action:"door",option:1));try await client.apply(.init(action:"walk"))
    for _ in 0..<8 {try await client.apply(.init(action:"move",frames:240,forward:1))}
    try await client.apply(.init(action:"requestTraversal"));try await client.apply(.init(action:"enterHandoff"))
    let world=try XCTUnwrap(client.atlantis);XCTAssertTrue(client.garage.isFounderPresentedInAtlantis)
    world.setFounderReduceMotion(reduced)
    var frames:[C31CameraFrame]=[], elapsed:Double=0, phase="ready", callback=0
    let host=try C31RealityHost(root:world.root) { content in world.subscribe { handler in content.subscribe(to:SceneEvents.Update.self) { event in
      handler(event);elapsed += event.deltaTime;callback += 1
      let p=world.playerRoot.position,c=world.camera.position(relativeTo:world.root)
      frames.append(.init(callback:callback,elapsed:elapsed,delta:event.deltaTime,phase:phase,forward:world.walkInput,turn:world.turnInput,position:[p.x,p.y,p.z],heading:world.heading,yaw:world.cameraYawOffset,camera:[c.x,c.y,c.z],sourcePauseWindow:AtlantisS4CameraBias.heroPauseWindow(position:p,heading:world.heading,reduceMotion:reduced)))
    }}}
    defer{host.close()}
    try await wait({callback>=5},seconds:15,label:"scene_callbacks")
    let route=try XCTUnwrap((try AtlantisAssetManifest.load()).traversal.routes.first{$0.name=="Founder_ToStartup_Walk"})
    let corner=SIMD3<Float>(route.points[0][0],route.points[0][1],route.points[0][2])
    func face(_ target: SIMD3<Float>) {let d=target-world.playerRoot.position;let requested=atan2(-d.x,-d.z);world.turn(atan2(sin(requested-world.heading),cos(requested-world.heading)))}
    phase="approach_source_corner";face(corner);world.setMovementIntent(forward:1,turn:0)
    try await wait({simd_length(SIMD2<Float>(world.playerRoot.position.x-corner.x,world.playerRoot.position.z-corner.z))<0.25},seconds:15,label:"source_corner")
    world.setMovementIntent(forward:0,turn:0)
    let a=SIMD3<Float>(route.points[0][0],route.points[0][1],route.points[0][2]),b=SIMD3<Float>(route.points[1][0],route.points[1][1],route.points[1][2])
    face(b);phase="held_forward";world.setMovementIntent(forward:1,turn:0)
    try await wait({AtlantisS4CameraBias.heroPauseWindow(position:world.playerRoot.position,heading:world.heading,reduceMotion:false)},seconds:30,label:"hero_window")
    // Remain held through actual callbacks in the accepted policy window.
    let heldStart=callback;try await wait({callback>=heldStart+10},seconds:5,label:"held_samples")
    phase="released";world.setMovementIntent(forward:0,turn:0);let releaseElapsed=elapsed
    try await wait({elapsed-releaseElapsed>=1.25},seconds:5,label:"pause_callbacks")
    try await host.capture(reduced ? "camera-reduce-motion-pause" : "camera-pause",directory:directory())
    phase="restart";world.setMovementIntent(forward:1,turn:0);let restartElapsed=elapsed
    try await wait({elapsed-restartElapsed>=0.5},seconds:5,label:"restart_callbacks")
    phase="stop_after_restart";world.setMovementIntent(forward:0,turn:0)
    let held=frames.filter{$0.phase=="held_forward" && $0.forward>0.1 && $0.sourcePauseWindow}
    let released=frames.filter{$0.phase=="released"}, restarted=frames.filter{$0.phase=="restart"}
    XCTAssertFalse(frames.isEmpty);XCTAssertTrue(frames.allSatisfy{($0.position+$0.camera+[$0.heading,$0.yaw]).allSatisfy(\.isFinite)})
    let epsilon=Float.ulpOfOne*64
    if reduced {XCTAssertTrue(frames.allSatisfy{abs($0.yaw)<=epsilon})}
    else {
      XCTAssertFalse(held.isEmpty);XCTAssertTrue(held.allSatisfy{abs($0.yaw)<=epsilon},"Active held input must remain centered")
      XCTAssertTrue(released.contains{abs($0.yaw-AtlantisS4CameraBias.contextualYaw)<=epsilon},"Source-defined pause endpoint")
      XCTAssertTrue(restarted.contains{abs($0.yaw)<=epsilon},"Source-defined centered restart endpoint")
      for (old,next) in zip(restarted,restarted.dropFirst()) {XCTAssertLessThanOrEqual(abs(next.yaw),abs(old.yaw)+epsilon)}
    }
    struct Result:Encodable {let sourceFingerprint:String;let lab:String;let scope:String;let reduced:Bool;let frames:[C31CameraFrame];let collisionContacts:[String];let handoffReplay:WorldReplay}
    try write(Result(sourceFingerprint:client.mission.sourceFingerprint,lab:ProcessInfo.processInfo.environment["SIMULATOR_UDID"]!,scope:"live test-hosted RealityView contract host; production callbacks/commands; not SwiftUI touch-phase proof",reduced:reduced,frames:frames,collisionContacts:host.contacts,handoffReplay:try client.replay()),name:reduced ? "camera-reduce-motion.json" : "camera-phases.json")
  }
  func testC31IdleWhiteboardMovementAndPhysicalObservations() async throws {
    let client=try ChaosWorldAdapter(mission:mission("world-whiteboard-c31",reduced:false));defer{client.stop()};try await client.initialize()
    let world=client.garage,target=try XCTUnwrap(world.spatialSpecification.facilityTier0InteractionSpace?.founderInteractionTarget(for:.whiteboard))
    XCTAssertEqual(world.interactionCoordinator.phase,.idle)
    var observations:[WorldObservation]=[],frames=0
    let host=try C31RealityHost(root:world.entities.root) { content in world.subscribeToCameraUpdates {handler in content.subscribe(to:SceneEvents.Update.self) {event in handler(event);frames += 1;if frames%6==0 {observations.append(client.observe())}}} };defer{host.close()}
    world.cameraController.beginWalking(reduceMotion:false)
    let started=ProcessInfo.processInfo.systemUptime
    // Controller-owned movement only. No pose consumption, walkability override or alignment.
    while ProcessInfo.processInfo.systemUptime-started<10 {
      let pose=world.cameraController.playerSpatialState.playerPose,d=target.approach.position-pose.position
      if simd_length(SIMD2<Float>(d.x,d.z))<target.positionToleranceMeters*0.5 {break}
      let right=SIMD3<Float>(cos(pose.heading),0,sin(pose.heading)),forward=SIMD3<Float>(sin(pose.heading),0,-cos(pose.heading))
      let velocity=simd_length(d)>0.0001 ? simd_normalize(d)*min(1,simd_length(d)) : .zero
      world.cameraController.setMovementIntent(.init(lateral:simd_dot(velocity,right),forward:simd_dot(velocity,forward)))
      try await Task.sleep(for:.milliseconds(30))
    }
    world.cameraController.setMovementIntent(.idle);let stop=frames;try await wait({frames>=stop+30},seconds:5,label:"whiteboard_stop")
    let pose=world.cameraController.playerSpatialState.playerPose
    let targetHeading=atan2(target.interaction.facingDirection.x,-target.interaction.facingDirection.z)
    world.cameraController.setLookOrientation(.init(yaw:atan2(sin(targetHeading-pose.heading),cos(targetHeading-pose.heading)),pitch:0))
    let look=frames;try await wait({frames>=look+60},seconds:5,label:"whiteboard_look")
    let eligible=world.whiteboardInteractionFocused,accepted=world.requestWhiteboardObservation()
    XCTAssertEqual(world.interactionCoordinator.phase,.idle);XCTAssertEqual(accepted,eligible)
    if accepted {world.cameraController.transition(to:.whiteboard,reduceMotion:false)}
    try await host.capture("whiteboard-idle-approach",directory:directory())
    func bodies(_ e:Entity)->Int {(e.components[PhysicsBodyComponent.self] == nil ? 0 : 1)+e.children.reduce(0){$0+bodies($1)}}
    struct Result:Encodable {let sourceFingerprint:String;let lab:String;let observations:[WorldObservation];let targetPosition:[Float];let targetHeading:Float;let tolerance:Float;let facingTolerance:Float;let eligible:Bool;let accepted:Bool;let phase:String;let contacts:[String];let physicsBodies:Int;let scope:String}
    try write(Result(sourceFingerprint:client.mission.sourceFingerprint,lab:ProcessInfo.processInfo.environment["SIMULATOR_UDID"]!,observations:observations,targetPosition:[target.approach.position.x,target.approach.position.y,target.approach.position.z],targetHeading:targetHeading,tolerance:target.positionToleranceMeters,facingTolerance:target.facingToleranceRadians,eligible:eligible,accepted:accepted,phase:world.interactionCoordinator.phase.rawValue,contacts:host.contacts,physicsBodies:bodies(world.entities.root),scope:"actual rendered contract host, canonical idle start and production movement/look/eligibility; no artificial successful pose or result"),name:"whiteboard-live.json")
  }
}
