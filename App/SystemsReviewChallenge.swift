import Foundation

enum TechnicalTopic: String, Codable, CaseIterable, Hashable {
  case backend
  case frontend
  case data
  case integration
  case deployment
  case reliability
  case general
}

enum SystemsReviewConstraintKind: String, Codable, Hashable {
  case dependency
  case verification
  case releaseGate
}

/// UI-safe implementation step. Dependency truth is private and is never
/// projected into accessibility or presentation metadata.
struct SystemsReviewStep: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var detail: String
  private var prerequisites: [String]
  private var constraintKind: SystemsReviewConstraintKind

  init(
    id: String,
    title: String,
    detail: String,
    prerequisites: [String] = [],
    constraintKind: SystemsReviewConstraintKind = .dependency
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.prerequisites = prerequisites
    self.constraintKind = constraintKind
  }

  func presentation(selectedPosition: Int?) -> SystemsReviewStepPresentation {
    SystemsReviewStepPresentation(id: id, title: title, detail: detail, selectedPosition: selectedPosition)
  }

  fileprivate var constraints: [SystemsReviewConstraint] {
    prerequisites.map { .init(prerequisiteID: $0, dependentID: id, kind: constraintKind) }
  }
}

/// The only step representation supplied to the view or VoiceOver.
struct SystemsReviewStepPresentation: Identifiable, Equatable, Hashable {
  var id: String
  var title: String
  var detail: String
  var selectedPosition: Int?

  var accessibilityLabel: String {
    if let selectedPosition {
      return "\(title). \(detail). Selected position \(selectedPosition)."
    }
    return "\(title). \(detail). Not selected."
  }
}

struct SystemsReviewConstraint: Codable, Hashable {
  fileprivate var prerequisiteID: String
  fileprivate var dependentID: String
  fileprivate var kind: SystemsReviewConstraintKind
}

struct SystemsReviewChallenge: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var summary: String
  var topic: TechnicalTopic
  var steps: [SystemsReviewStep]

  var stepCount: Int { steps.count }

  func presentations(selection: [String]) -> [SystemsReviewStepPresentation] {
    steps.map { step in
      step.presentation(selectedPosition: selection.firstIndex(of: step.id).map { $0 + 1 })
    }
  }

  fileprivate var constraints: [SystemsReviewConstraint] { steps.flatMap(\.constraints) }
}

struct SystemsReviewAssessment: Equatable {
  var reviewQuality: Int
  var satisfiedDependencies: Int
  var dependencyCount: Int
  var satisfiedVerificationGates: Int
  var verificationGateCount: Int
  var releaseSafe: Bool
  var findings: [WorkSessionFinding]
}

enum SystemsReviewEvaluator {
  static func evaluate(challenge: SystemsReviewChallenge, sequence: [String]) -> SystemsReviewAssessment? {
    guard sequence.count == challenge.steps.count,
          Set(sequence).count == challenge.steps.count,
          Set(sequence) == Set(challenge.steps.map(\.id)) else { return nil }

    let positions = Dictionary(uniqueKeysWithValues: sequence.enumerated().map { ($1, $0) })
    let constraints = challenge.constraints
    let dependencyConstraints = constraints.filter { $0.kind == .dependency }
    let verificationConstraints = constraints.filter { $0.kind == .verification }
    let releaseConstraints = constraints.filter { $0.kind == .releaseGate }
    let satisfied: (SystemsReviewConstraint) -> Bool = { constraint in
      guard let prerequisite = positions[constraint.prerequisiteID],
            let dependent = positions[constraint.dependentID] else { return false }
      return prerequisite < dependent
    }
    let dependencyHits = dependencyConstraints.filter(satisfied).count
    let verificationHits = verificationConstraints.filter(satisfied).count
    let releaseHits = releaseConstraints.filter(satisfied).count
    let releaseSafe = releaseHits == releaseConstraints.count
    let releasePositions = releaseConstraints.compactMap { positions[$0.dependentID] }
    let releasePrerequisiteIDs = Set(releaseConstraints.map(\.prerequisiteID))
    let verificationStepIDs = Set(verificationConstraints.map(\.dependentID)).intersection(releasePrerequisiteIDs)
    let verificationOccurredAfterRelease = releasePositions.contains { releasePosition in
      verificationStepIDs.contains { verificationID in
        guard let verificationPosition = positions[verificationID] else { return false }
        return verificationPosition > releasePosition
      }
    }

    // Relationship scoring supports partial credit and multiple valid
    // topological orders. Verification and release gates carry extra weight.
    let dependencyPoints = dependencyConstraints.isEmpty ? 60.0 : 60.0 * Double(dependencyHits) / Double(dependencyConstraints.count)
    let verificationPoints = verificationConstraints.isEmpty ? 20.0 : 20.0 * Double(verificationHits) / Double(verificationConstraints.count)
    let releasePoints = releaseConstraints.isEmpty ? 20.0 : 20.0 * Double(releaseHits) / Double(releaseConstraints.count)
    let quality = min(100, max(0, Int((dependencyPoints + verificationPoints + releasePoints).rounded())))

    var findings: [WorkSessionFinding] = []
    if dependencyHits < dependencyConstraints.count { findings.append(.dependencyViolation) }
    if verificationHits < verificationConstraints.count || verificationOccurredAfterRelease { findings.append(.skippedVerification) }
    if !releaseSafe { findings.append(.unsafeRelease) }
    if dependencyHits > 0 { findings.append(.correctlyPreservedDependency) }
    if !verificationConstraints.isEmpty && verificationHits == verificationConstraints.count { findings.append(.correctlyRequiredVerification) }
    if !releaseConstraints.isEmpty && releaseSafe { findings.append(.correctlyIdentifiedReleaseGate) }

    return SystemsReviewAssessment(
      reviewQuality: quality,
      satisfiedDependencies: dependencyHits,
      dependencyCount: dependencyConstraints.count,
      satisfiedVerificationGates: verificationHits,
      verificationGateCount: verificationConstraints.count,
      releaseSafe: releaseSafe,
      findings: findings
    )
  }
}

extension SoloTask {
  var resolvedTechnicalTopic: TechnicalTopic? {
    let copy = "\(title) \(detail)".lowercased()
    let mappings: [(TechnicalTopic, [String])] = [
      (.data, ["data", "database", "schema", "migration", "records", "analytics"]),
      (.deployment, ["deploy", "deployment", "release", "production", "staging"]),
      (.reliability, ["reliability", "incident", "outage", "failure", "critical bug", "monitor"]),
      (.integration, ["integration", "api", "webhook", "external", "connector"]),
      (.backend, ["backend", "server", "service", "endpoint"]),
      (.frontend, ["frontend", "client", "interface", "user interface", "onboarding"])
    ]
    return mappings.first(where: { _, words in words.contains(where: copy.contains) })?.0
  }
}

enum SystemsReviewChallengeFactory {
  static func make(seed: UInt64, topic: TechnicalTopic?, stakes: WorkSessionStakes) -> SystemsReviewChallenge {
    let resolvedTopic = topic ?? .general
    let matching = templates.filter { $0.topic == resolvedTopic }
    let pool = matching.isEmpty ? templates.filter { $0.topic == .general } : matching
    let templateIndex = Int(SeededRandomNumberGenerator.mixed(seed ^ 0x57AC_5EED) % UInt64(pool.count))
    var challenge = pool[templateIndex]
    challenge.steps = ranked(challenge.steps, seed: seed)
    return challenge
  }

  private static func ranked(_ steps: [SystemsReviewStep], seed: UInt64) -> [SystemsReviewStep] {
    steps.enumerated().sorted { left, right in
      let l = SeededRandomNumberGenerator.mixed(seed ^ UInt64(left.offset + 1) &* 0x9E3779B97F4A7C15)
      let r = SeededRandomNumberGenerator.mixed(seed ^ UInt64(right.offset + 1) &* 0x9E3779B97F4A7C15)
      return l == r ? left.element.id < right.element.id : l < r
    }.map(\.element)
  }

  private static let templates: [SystemsReviewChallenge] = [
    .init(id: "backend-feature", title: "Backend Feature", summary: "Review the safest path from storage changes to a controlled release.", topic: .backend, steps: [
      .init(id: "schema", title: "Update Database Schema", detail: "Prepare the storage shape required by the feature."),
      .init(id: "logic", title: "Build Backend Logic", detail: "Implement the service behavior on the new schema.", prerequisites: ["schema"]),
      .init(id: "contract", title: "Confirm API Contract", detail: "Lock the interface the client will consume.", prerequisites: ["logic"]),
      .init(id: "client", title: "Connect Client", detail: "Wire the product experience to the confirmed interface.", prerequisites: ["contract"]),
      .init(id: "integration-test", title: "Run Integration Test", detail: "Exercise storage, service, and client together.", prerequisites: ["client"], constraintKind: .verification),
      .init(id: "release", title: "Release Feature", detail: "Enable the completed feature for customers.", prerequisites: ["integration-test"], constraintKind: .releaseGate)
    ]),
    .init(id: "data-migration", title: "Customer Data Migration", summary: "Protect customer records while moving production traffic.", topic: .data, steps: [
      .init(id: "backup", title: "Create Backup", detail: "Capture a recoverable production snapshot."),
      .init(id: "prepare", title: "Prepare Migration", detail: "Define transformations and rollback boundaries.", prerequisites: ["backup"]),
      .init(id: "migrate", title: "Run Migration", detail: "Transform the staged customer records.", prerequisites: ["prepare"]),
      .init(id: "validate", title: "Validate Records", detail: "Compare counts and critical fields after migration.", prerequisites: ["migrate"], constraintKind: .verification),
      .init(id: "switch", title: "Switch Production Read Path", detail: "Move live reads to the migrated records.", prerequisites: ["validate"], constraintKind: .releaseGate),
      .init(id: "monitor", title: "Monitor Data Health", detail: "Watch errors and record consistency after cutover.", prerequisites: ["switch"], constraintKind: .verification)
    ]),
    .init(id: "external-integration", title: "External Integration", summary: "Review the path from a third-party contract to production traffic.", topic: .integration, steps: [
      .init(id: "api-contract", title: "Confirm API Contract", detail: "Verify required inputs, outputs, and limits."),
      .init(id: "credentials", title: "Configure Credentials", detail: "Provision scoped access for the integration.", prerequisites: ["api-contract"]),
      .init(id: "adapter", title: "Build Adapter", detail: "Connect internal workflows to the external service.", prerequisites: ["api-contract"]),
      .init(id: "sandbox", title: "Test in Sandbox", detail: "Exercise authentication and failure handling safely.", prerequisites: ["credentials", "adapter"], constraintKind: .verification),
      .init(id: "production", title: "Enable Production", detail: "Route live traffic through the integration.", prerequisites: ["sandbox"], constraintKind: .releaseGate),
      .init(id: "errors", title: "Monitor Integration Errors", detail: "Track failures and rate-limit behavior after launch.", prerequisites: ["production"], constraintKind: .verification)
    ]),
    .init(id: "controlled-deployment", title: "Controlled Deployment", summary: "Review the release gates for a production build.", topic: .deployment, steps: [
      .init(id: "build", title: "Build Release", detail: "Create the production candidate."),
      .init(id: "tests", title: "Run Regression Check", detail: "Verify critical existing workflows.", prerequisites: ["build"], constraintKind: .verification),
      .init(id: "stage", title: "Stage Deployment", detail: "Deploy the candidate to a production-like environment.", prerequisites: ["tests"]),
      .init(id: "health", title: "Verify Health", detail: "Confirm availability and core transactions in staging.", prerequisites: ["stage"], constraintKind: .verification),
      .init(id: "production", title: "Release Production", detail: "Promote the verified candidate to customers.", prerequisites: ["health"], constraintKind: .releaseGate),
      .init(id: "monitor", title: "Monitor Release", detail: "Watch errors, latency, and customer impact.", prerequisites: ["production"], constraintKind: .verification)
    ]),
    .init(id: "reliability-fix", title: "Reliability Fix", summary: "Review how the failure is contained, tested, and released.", topic: .reliability, steps: [
      .init(id: "failure", title: "Identify Failure Point", detail: "Locate the operational condition causing the issue."),
      .init(id: "guardrail", title: "Implement Guardrail", detail: "Contain the failure without widening impact.", prerequisites: ["failure"]),
      .init(id: "failure-test", title: "Test Failure Case", detail: "Reproduce the issue and verify the guardrail.", prerequisites: ["guardrail"], constraintKind: .verification),
      .init(id: "deploy", title: "Deploy Fix", detail: "Release the verified protection.", prerequisites: ["failure-test"], constraintKind: .releaseGate),
      .init(id: "rate", title: "Monitor Error Rate", detail: "Confirm the failure rate returns to baseline.", prerequisites: ["deploy"], constraintKind: .verification)
    ]),
    .init(id: "client-feature", title: "Client Feature", summary: "Review a customer-facing change from contract to release.", topic: .frontend, steps: [
      .init(id: "contract", title: "Confirm Product Contract", detail: "Define supported states and expected behavior."),
      .init(id: "client", title: "Build Client Experience", detail: "Implement the customer-facing workflow.", prerequisites: ["contract"]),
      .init(id: "accessibility", title: "Verify Accessibility", detail: "Check navigation, labels, and text scaling.", prerequisites: ["client"], constraintKind: .verification),
      .init(id: "regression", title: "Run Regression Check", detail: "Verify existing customer workflows remain intact.", prerequisites: ["client"], constraintKind: .verification),
      .init(id: "flag", title: "Enable Feature Flag", detail: "Prepare a controlled customer rollout.", prerequisites: ["accessibility", "regression"], constraintKind: .releaseGate),
      .init(id: "monitor", title: "Monitor Adoption", detail: "Watch errors and customer completion after rollout.", prerequisites: ["flag"], constraintKind: .verification)
    ]),
    .init(id: "systems-change", title: "Systems Change", summary: "Review the implementation path and protect the release gate.", topic: .general, steps: [
      .init(id: "scope", title: "Confirm Change Scope", detail: "Define affected workflows and operating boundaries."),
      .init(id: "implement", title: "Implement Change", detail: "Build the scoped system update.", prerequisites: ["scope"]),
      .init(id: "test", title: "Run Regression Check", detail: "Verify critical workflows after the change.", prerequisites: ["implement"], constraintKind: .verification),
      .init(id: "stage", title: "Stage Release", detail: "Exercise the candidate in a production-like environment.", prerequisites: ["test"]),
      .init(id: "release", title: "Release", detail: "Promote the verified change to customers.", prerequisites: ["stage"], constraintKind: .releaseGate),
      .init(id: "monitor", title: "Verify Monitoring", detail: "Confirm health signals after release.", prerequisites: ["release"], constraintKind: .verification)
    ])
  ]
}
