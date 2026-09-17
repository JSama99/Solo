import CryptoKit
import UIKit
import XCTest
@testable import Solo_Unicorn_Run

/// BUILD-BLUEPRINT-00-fixtures — generates the pre-change baseline for the
/// Blueprint series from the current, unmodified build.
///
/// The generator is compiled out unless `BLUEPRINT_FIXTURES` is set — see the
/// gate above it — so a routine `xcodebuild test`, CI included, never executes
/// it. Promoting a generated run into `Tests/Fixtures/Blueprint/` is a
/// deliberate copy on top of that. Regenerating a golden fixture after a change
/// proves nothing, so this must be run and committed before any Blueprint
/// commit lands.
///
/// The four trace seeds mirror `splitmix64_vectors.json`. The two fixtures are a
/// matched pair drawn from one of them (`pairedSeed`): `pre_blueprint_save.json`
/// is that seed's day-0 save, and its day-200 counterpart is that same seed's
/// run inside `pre_blueprint_state_200.json`. Both fixtures verified
/// byte-identical across independent simulator processes on iPhone 17 / iOS 27.0.
///
/// `testDriverIsReproducibleWithinAProcess` is not gated: it is an assertion,
/// not a generator, and runs in the ordinary suite.
@MainActor
final class BlueprintFixtureDriver: XCTestCase {

  /// Matches the four seeds pinned in `Tests/Fixtures/Blueprint/splitmix64_vectors.json`.
  private static let seeds: [UInt64] = [0, 1, 2, .max]

  /// The run length is measured in simulated operating days, not sprint
  /// indices. `commitSprint()` advances the calendar 7 days at a time, so the
  /// store's observable state only changes on 7-day boundaries.
  private static let targetDays = 200

  /// The two fixtures are a matched pair from ONE seed: `pre_blueprint_save.json`
  /// is this seed's day-0 save, and its day-200 counterpart is this seed's run
  /// in `pre_blueprint_state_200.json`. BP-M-012 loads the save, runs the ticks,
  /// and compares against that trace — so both halves must come from the same
  /// run or the check is meaningless.
  ///
  /// Chosen from the four trace seeds because a paired fixture requires a seed
  /// that actually reaches the 200-day target. Seed 2 terminates in victory at
  /// day 155 and the spec's `0xC0FFEE` terminates in victory at day 78, so
  /// neither can produce the day-200 half at all. Of the three that qualify
  /// (0, 1, .max), this one leans least on the survival floor: 46.5% of advances
  /// floored on runway and 53.5% on energy, against 84.4% and 55.3%/57.9% for
  /// seeds 0 and 1.
  private static let pairedSeed: UInt64 = .max

  /// The driver clamps the three loss stats before each commit, exactly as the
  /// repo's own `ContinuousModeTests.playToVentureEnd` does. Without it a run
  /// dies of bankruptcy long before day 200 and the trace stops being a
  /// determinism baseline. Recorded in the fixture so the intervention is never
  /// mistaken for natural play.
  private static let survivalFloor = (runway: 80, energy: 80, trust: 60)

  /// The exhaustive description of the intervention, embedded in both fixtures.
  /// `clampedValues` is the complete list — nothing else in the store, on the
  /// agents, or in `finance` is touched by the driver.
  private static let floorDescription = SurvivalFloorDescription(
    rule: "value = max(value, floor), applied to each listed value immediately "
      + "before every commitSprint(). A value already at or above its floor is "
      + "left untouched; a value below it is raised to exactly the floor. The "
      + "floor is never applied after the commit, so the sampled state reflects "
      + "the sprint's own outcome.",
    clampedValues: [
      "stats.runway floored at 80",
      "stats.energy floored at 80",
      "stats.trust floored at 60",
    ],
    notClamped: [
      "stats.revenue", "stats.momentum", "stats.capital", "stats.trackRecord",
      "stats.coverage", "finance.cash", "agents[].drift", "agents[].trust",
      "agents[].calibration", "agents[].relationship",
    ],
    rationale: "resolvedOutcome() (App/GameStore.swift:3848) ends a career on "
      + "runway <= 0, energy <= 0, or trust <= 0. Those are the only three loss "
      + "conditions, so those are the only three values floored.",
    precedent: "Mirrors ContinuousModeTests.playToVentureEnd in the existing suite."
  )

  private static let stepCap = 400

  override func tearDown() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where key.hasPrefix("solo-unicorn-run-native-save-") {
      UserDefaults.standard.removeObject(forKey: key)
    }
    super.tearDown()
  }

  // MARK: - Generation

  // Gated at compile time, not at runtime. An earlier version gated on
  // ProcessInfo.environment["BLUEPRINT_FIXTURE_OUT"], which cannot work here:
  // xcodebuild does not forward the host environment into the sandboxed
  // simulator runner, so that read always came back nil and the generator was
  // unconditionally skipped. A build setting crosses that boundary, so the
  // generator is compiled out of an ordinary test build entirely and a routine
  // `xcodebuild test` — CI included — never pays for a fixture pass.
  //
  // To regenerate:
  //
  //   xcodebuild test -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" \
  //     -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  //     -only-testing:"Solo Unicorn Run Tests/BlueprintFixtureDriver" \
  //     SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) BLUEPRINT_FIXTURES'
  //
  // then copy the two printed files into Tests/Fixtures/Blueprint/.
  #if BLUEPRINT_FIXTURES
  func testGenerateBlueprintBaselineFixtures() throws {
    // The test runner is sandboxed and does not inherit the host environment,
    // so fixtures are written into the container and the caller copies them out
    // of the path printed below. Writing here never touches the committed
    // fixtures; promoting a run is always a deliberate copy.
    let outDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    var runs: [SeedRun] = []
    var floors: [SurvivalFloorAccounting] = []

    var saveData: Data?
    var pairedRun: SeedRun?
    var pairedFloor: SurvivalFloorAccounting?

    for seed in Self.seeds {
      let store = makeStore(seed: seed)
      // The day-0 slice is captured from the paired seed's own store, before it
      // is driven, so the save and the day-200 trace below are the same run by
      // construction rather than by coincidence. Reading UserDefaults does not
      // perturb the store, so the trace is identical either way.
      if seed == Self.pairedSeed {
        saveData = UserDefaults.standard.data(forKey: GameStore.saveKey)
      }
      let result = drive(store, seed: seed)
      runs.append(result.run)
      floors.append(result.floor)
      if seed == Self.pairedSeed {
        pairedRun = result.run
        pairedFloor = result.floor
      }
    }

    let saveResultRun = try XCTUnwrap(pairedRun, "paired seed produced no run")
    let saveResultFloor = try XCTUnwrap(pairedFloor, "paired seed produced no floor accounting")

    let fixture = StateFixture(
      schemaVersion: 1,
      saveVersion: GameStore.saveVersion,
      generatedFrom: "GameStore.commitSprint() — App/GameStore.swift",
      driver: "Tests/BlueprintFixtureDriver.swift",
      policy: "Every decision (assign / verify / resolve / dilemma) drawn from "
        + "SeededRandomNumberGenerator, seeded per run off the run seed. The store's "
        + "own generator is never read by the policy.",
      targetDays: Self.targetDays,
      normalization: StateNormalization(
        reason: "The trace itself needed no normalization: it is byte-identical "
          + "across independent processes as generated. The survival floor below "
          + "is an intervention by this driver, not behavior of the build under test.",
        applied: [],
        survivalFloor: Self.floorDescription,
        survivalFloorAccounting: floors
      ),
      pairedSeed: String(Self.pairedSeed),
      environment: "\(UIDevice.current.model) / iOS \(UIDevice.current.systemVersion)",
      note: "Trace is one entry per sprint-advance. The calendar moves 7 days per "
        + "advance, so day resolution equals sprint resolution. rollingHash[i] = "
        + "SHA256(rollingHash[i-1] || stateHash[i]), rollingHash[-1] = empty. "
        + "The run under pairedSeed is the day-200 half of a matched pair whose "
        + "day-0 half is pre_blueprint_save.json; both come from the same run.",
      runs: runs
    )

    let stateURL = outDirectory.appendingPathComponent("pre_blueprint_state_200.json")
    try canonicalJSON(fixture).write(to: stateURL)
    print("BLUEPRINT_FIXTURE_WROTE: \(stateURL.path)")

    let rawSave = try XCTUnwrap(saveData, "no save envelope was persisted for the save-fixture seed")
    let saveURL = outDirectory.appendingPathComponent("pre_blueprint_save.json")
    try normalizedSave(rawSave, floor: saveResultFloor, run: saveResultRun).write(to: saveURL)
    print("BLUEPRINT_FIXTURE_WROTE: \(saveURL.path)")

    for run in runs {
      print("BLUEPRINT_RUN seed=\(run.seed) steps=\(run.completedSteps) "
        + "day=\(run.finalDay) outcome=\(run.terminated ?? "none") trace=\(run.traceHash)")
    }
  }

  #endif

  /// Determinism guard that runs in a normal test pass: the same seed driven
  /// twice in one process must produce an identical trace hash. This one is
  /// deliberately not gated — it is a real assertion, not a generator.
  func testDriverIsReproducibleWithinAProcess() {
    let first = drive(makeStore(seed: 1), seed: 1).run
    let second = drive(makeStore(seed: 1), seed: 1).run
    XCTAssertEqual(first.traceHash, second.traceHash)
    XCTAssertEqual(first.completedSteps, second.completedSteps)
  }

  // MARK: - Driver

  private func makeStore(seed: UInt64) -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.entitlements = StaticEntitlementProvider(hasFounderPass: true)
    store.selectedCareerMode = .continuous
    store.startCareer(seed: seed)
    store.confirmVentureThesisIfNeeded()
    return store
  }

  private func drive(_ store: GameStore, seed: UInt64) -> (run: SeedRun, floor: SurvivalFloorAccounting) {
    var policy = SeededRandomNumberGenerator(seed: SeededRandomNumberGenerator.mixed(seed))
    var trace: [TraceEntry] = []
    var rolling = Data()
    var steps = 0
    var runwayFloored = 0
    var energyFloored = 0
    var trustFloored = 0

    while store.operatingCalendar.totalDays < Self.targetDays
      && store.careerOutcome == nil
      && !store.isVentureLocked
      && steps < Self.stepCap {
      steps += 1

      store.confirmVentureThesisIfNeeded()
      assignTasks(store, policy: &policy)
      verifyTasks(store, policy: &policy)
      resolveReviewedTasks(store, policy: &policy)
      answerDilemma(store, policy: &policy)

      if store.stats.runway < Self.survivalFloor.runway { runwayFloored += 1 }
      if store.stats.energy < Self.survivalFloor.energy { energyFloored += 1 }
      if store.stats.trust < Self.survivalFloor.trust { trustFloored += 1 }
      store.stats.runway = max(store.stats.runway, Self.survivalFloor.runway)
      store.stats.energy = max(store.stats.energy, Self.survivalFloor.energy)
      store.stats.trust = max(store.stats.trust, Self.survivalFloor.trust)

      store.commitSprint()
      store.report = nil

      if store.pendingVentureCheckpoint != nil { store.continueFromCheckpoint() }
      store.confirmVentureThesisIfNeeded()
      if store.stage == .chapterMilestone { store.dismissChapterMilestone() }

      let sample = sample(store)
      let stateHash = SHA256.hash(data: canonicalJSON(sample))
      rolling = Data(SHA256.hash(data: rolling + Data(stateHash)))
      trace.append(
        TraceEntry(
          step: steps,
          day: store.operatingCalendar.totalDays,
          venture: store.venture,
          sprint: store.sprint,
          attentionRemaining: store.attentionRemaining,
          stateHash: hex(stateHash),
          rollingHash: hex(rolling)
        )
      )
    }

    let run = SeedRun(
      seed: String(seed),
      completedSteps: steps,
      finalDay: store.operatingCalendar.totalDays,
      terminated: terminationReason(store),
      traceHash: hex(rolling),
      trace: trace,
      finalState: sample(store)
    )
    // A driver step is one pass of the policy loop. It does not always commit a
    // sprint: commitSprint() returns early when commitBlockerMessage is non-nil
    // (App/GameStore.swift:1846), and only a committing pass reaches
    // advanceOperatingTime(hours: 7 * 24) (App/GameStore.swift:1992). So
    // finalDay == 1 + 7 * committingAdvances, and NOT 1 + 7 * driverSteps.
    let committing = trace.reduce(into: (day: 1, count: 0)) { acc, entry in
      if entry.day > acc.day { acc.count += 1 }
      acc.day = entry.day
    }.count
    let floor = SurvivalFloorAccounting(
      seed: String(seed),
      driverSteps: steps,
      committingAdvances: committing,
      runwayFloored: runwayFloored,
      energyFloored: energyFloored,
      trustFloored: trustFloored,
      assessment: floorAssessment(
        steps: steps,
        runway: runwayFloored,
        energy: energyFloored,
        trust: trustFloored
      )
    )
    return (run, floor)
  }

  /// Says plainly how much of the run was held up by the floor rather than by
  /// the simulation, so a reader six months from now does not mistake a
  /// floor-held day-200 state for natural survival.
  private func floorAssessment(steps: Int, runway: Int, energy: Int, trust: Int) -> String {
    guard steps > 0 else { return "no driver steps" }
    let worst = max(runway, max(energy, trust))
    let share = (worst * 100) / steps
    let detail = "of \(steps) driver steps: runway \(runway), energy \(energy), trust \(trust)"
    switch share {
    case 0:
      return "floor never fired — this run survived to its end state unaided (\(detail))"
    case 1..<25:
      return "floor fired occasionally; end state is mostly simulation-driven (\(detail))"
    case 25..<75:
      return "floor fired on a substantial minority of advances; end state is "
        + "partly floor-held (\(detail))"
    default:
      return "floor fired on most advances — this run's end state is substantially "
        + "FLOOR-HELD, not naturally survived, and chiefly exercises the floor (\(detail))"
    }
  }

  private func terminationReason(_ store: GameStore) -> String? {
    if let outcome = store.careerOutcome { return String(describing: outcome.kind) }
    if store.isVentureLocked { return "ventureLocked" }
    return nil
  }

  // MARK: - Policy

  private func assignTasks(_ store: GameStore, policy: inout SeededRandomNumberGenerator) {
    guard !store.agents.isEmpty else { return }
    for task in store.tasks where task.assignedAgentID == nil {
      guard policy.probability() < 0.75 else { continue }
      let agent = store.agents[policy.integer(in: 0...(store.agents.count - 1))]
      store.assign(agentID: agent.id, to: task.id)
    }
    // commitSprint is blocked without at least one assignment, so a run that
    // drew all-skip still has to put one agent on the board.
    if !store.tasks.contains(where: { $0.assignedAgentID != nil }),
       let task = store.tasks.first {
      let agent = store.agents[policy.integer(in: 0...(store.agents.count - 1))]
      store.assign(agentID: agent.id, to: task.id)
    }
  }

  private func verifyTasks(_ store: GameStore, policy: inout SeededRandomNumberGenerator) {
    for task in store.tasks where task.assignedAgentID != nil && !task.isReviewed {
      guard store.attentionRemaining > 0 else { return }
      guard policy.probability() < 0.5 else { continue }
      store.review(taskID: task.id)
    }
  }

  private func resolveReviewedTasks(_ store: GameStore, policy: inout SeededRandomNumberGenerator) {
    let choices = TaskResolutionChoice.allCases
    for task in store.tasks where task.isReviewed && !task.resolutionLocked {
      let choice = choices[policy.integer(in: 0...(choices.count - 1))]
      store.resolveReviewedTask(taskID: task.id, choice: choice)
    }
  }

  private func answerDilemma(_ store: GameStore, policy: inout SeededRandomNumberGenerator) {
    guard let dilemma = store.activeDilemma, !dilemma.choices.isEmpty else { return }
    let choice = dilemma.choices[policy.integer(in: 0...(dilemma.choices.count - 1))]
    store.selectDilemmaChoice(choice.id)
  }

  // MARK: - Sampling

  private func sample(_ store: GameStore) -> StateSample {
    StateSample(
      stage: String(describing: store.stage),
      venture: store.venture,
      sprint: store.sprint,
      day: store.operatingCalendar.totalDays,
      attentionRemaining: store.attentionRemaining,
      attentionMaximum: store.attentionMaximum,
      runway: store.stats.runway,
      revenue: store.stats.revenue,
      momentum: store.stats.momentum,
      trust: store.stats.trust,
      energy: store.stats.energy,
      capital: store.stats.capital,
      trackRecord: store.stats.trackRecord,
      coverage: store.stats.coverage,
      cash: store.finance.cash,
      taskCount: store.tasks.count,
      assignedTaskCount: store.tasks.filter { $0.assignedAgentID != nil }.count,
      reviewedTaskCount: store.tasks.filter(\.isReviewed).count,
      evidenceCount: store.evidence.count,
      latentDefectCount: store.latentDefects.count,
      completedObjectives: store.completedObjectives,
      completedVentureObjectives: store.completedVentureObjectives,
      rngState: String(store.randomNumberGenerator.state),
      outcome: store.careerOutcome.map { String(describing: $0.kind) },
      agents: store.agents.map {
        AgentSample(
          id: $0.id,
          drift: Canonical6($0.drift),
          trust: Canonical6($0.trust),
          calibration: Canonical6($0.calibration),
          relationship: $0.relationship
        )
      }
    )
  }

  // MARK: - Save normalization

  /// The persisted envelope is not byte-stable across processes on the current
  /// build, so it cannot be diffed as-is. Two causes, both confirmed against
  /// source rather than inferred:
  ///
  /// - `Set` fields (`companyFlags`, `finance.appliedTransactionIDs`,
  ///   `finance.expiredFundingOpportunityIDs`) encode in Swift's unspecified
  ///   Set iteration order, which varies per process.
  /// - `TechComHeadline.id` is built with `UUID()` at GameStore.swift:3606,
  ///   while the same file already has `nextDeterministicUUID()` for task IDs.
  ///
  /// This normalizes those fields so the fixture is diffable, and records every
  /// normalization in the file. It deliberately does not change the engine —
  /// a baseline has to come from the unmodified build.
  private func normalizedSave(
    _ raw: Data,
    floor: SurvivalFloorAccounting,
    run: SeedRun
  ) throws -> Data {
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: raw) as? [String: Any],
      "save envelope was not a JSON object"
    )
    var applied: [String] = []
    var career = root["career"] as? [String: Any] ?? [:]

    // `applied` records what actually changed, not what was inspected. On an
    // early slice these collections are empty and every rule is a no-op, and
    // saying so is the difference between "this save needed normalizing" and
    // "this save was already stable".
    var checked: [String] = []

    checked.append("career.companyFlags (Set<CompanyFlag> iteration order)")
    if let flags = career["companyFlags"] as? [String], flags.sorted() != flags {
      career["companyFlags"] = flags.sorted()
      applied.append("career.companyFlags: sorted (Set<CompanyFlag> iteration order)")
    }
    if var finance = career["finance"] as? [String: Any] {
      for key in ["appliedTransactionIDs", "expiredFundingOpportunityIDs"] {
        checked.append("career.finance.\(key) (Set<String> iteration order)")
        if let ids = finance[key] as? [String], ids.sorted() != ids {
          finance[key] = ids.sorted()
          applied.append("career.finance.\(key): sorted (Set<String> iteration order)")
        }
      }
      career["finance"] = finance
    }
    checked.append("career.techComHeadlines[].id (ambient UUID() at GameStore.swift:3606)")
    if let headlines = career["techComHeadlines"] as? [[String: Any]], !headlines.isEmpty {
      career["techComHeadlines"] = headlines.enumerated().map { index, headline -> [String: Any] in
        var copy = headline
        copy["id"] = "normalized-\(index)"
        return copy
      }
      applied.append("career.techComHeadlines[].id: replaced with ordinal "
        + "(ambient UUID() at GameStore.swift:3606)")
    }

    root["career"] = career
    let floorJSON = try JSONSerialization.jsonObject(
      with: canonicalJSON(SurvivalFloorReport(survivalFloor: Self.floorDescription, run: floor))
    )
    root["_normalization"] = [
      "reason": applied.isEmpty
        ? "Nothing was normalized: on this slice every field below is empty, so "
          + "the envelope is exactly what the app wrote and is byte-stable as-is. "
          + "The rules still run because later slices are not stable — the build "
          + "persists Sets in per-process iteration order and a UUID()-keyed "
          + "headline list."
        : "The unmodified build does not persist a byte-stable envelope. The "
          + "fields under 'applied' are normalized so the baseline can be diffed; "
          + "everything else is exactly what the app wrote.",
      "applied": applied,
      "checked": checked,
      "survivalFloor": floorJSON,
      "pairing": [
        "seed": run.seed,
        "slice": "day 0 — the save as persisted immediately after career start "
          + "and thesis confirmation, before the first sprint-advance.",
        "counterpart": "pre_blueprint_state_200.json, the run with this same "
          + "seed. The two are the same run by construction: this save is read "
          + "from the paired seed's own store before that store is driven.",
        "counterpartFinalDay": run.finalDay,
        "counterpartAdvances": run.completedSteps,
        "counterpartOutcome": run.terminated ?? "none",
        "counterpartTraceHash": run.traceHash,
        "seedRationale": "0xC0FFEE (tech spec) terminates in victory at day 78 "
          + "and seed 2 at day 155, so neither can produce a day-200 counterpart. "
          + "Of the seeds that reach the target, this one leans least on the "
          + "survival floor.",
        "floorAppliesToCounterpartOnly": "This save predates every clamp: the "
          + "floor is applied before each commitSprint(), and no advance has run "
          + "at day 0. The accounting below describes the counterpart run.",
      ],
    ]
    return try JSONSerialization.data(
      withJSONObject: root,
      options: [.sortedKeys, .withoutEscapingSlashes]
    )
  }

  // MARK: - Canonical encoding

  private func canonicalJSON<T: Encodable>(_ value: T) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    // Force-try is confined to fixture generation: every type encoded here is a
    // local Codable struct with no throwing path.
    return try! encoder.encode(value)
  }

  private func hex(_ digest: SHA256.Digest) -> String {
    digest.map { String(format: "%02x", $0) }.joined()
  }

  private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - Fixture shape

/// Doubles are platform-sensitive at the serialization boundary, so every
/// Double that reaches a hash is pinned to 6 decimal places.
private struct Canonical6: Codable {
  let raw: Double

  init(_ raw: Double) { self.raw = raw }

  init(from decoder: Decoder) throws {
    raw = try decoder.singleValueContainer().decode(Double.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode((raw * 1_000_000).rounded(.toNearestOrEven) / 1_000_000)
  }
}

private struct AgentSample: Codable {
  var id: String
  var drift: Canonical6
  var trust: Canonical6
  var calibration: Canonical6
  var relationship: Int
}

private struct StateSample: Codable {
  var stage: String
  var venture: Int
  var sprint: Int
  var day: Int
  var attentionRemaining: Int
  var attentionMaximum: Int
  var runway: Int
  var revenue: Int
  var momentum: Int
  var trust: Int
  var energy: Int
  var capital: Int
  var trackRecord: Int
  var coverage: Int
  var cash: Int
  var taskCount: Int
  var assignedTaskCount: Int
  var reviewedTaskCount: Int
  var evidenceCount: Int
  var latentDefectCount: Int
  var completedObjectives: Int
  var completedVentureObjectives: Int
  var rngState: String
  var outcome: String?
  var agents: [AgentSample]
}

private struct TraceEntry: Codable {
  var step: Int
  var day: Int
  var venture: Int
  var sprint: Int
  var attentionRemaining: Int
  var stateHash: String
  var rollingHash: String
}

private struct SeedRun: Codable {
  var seed: String
  var completedSteps: Int
  var finalDay: Int
  var terminated: String?
  var traceHash: String
  var trace: [TraceEntry]
  var finalState: StateSample
}

/// The save fixture carries only its own seed's accounting, since it is the
/// end-of-run save for exactly one seed.
private struct SurvivalFloorReport: Codable {
  var survivalFloor: SurvivalFloorDescription
  var run: SurvivalFloorAccounting
}

private struct SurvivalFloorDescription: Codable {
  var rule: String
  var clampedValues: [String]
  var notClamped: [String]
  var rationale: String
  var precedent: String
}

private struct SurvivalFloorAccounting: Codable {
  var seed: String
  /// Passes of the policy loop. The floor is evaluated once per pass, so this is
  /// the denominator for the floored counts below.
  var driverSteps: Int
  /// Passes that actually committed a sprint and moved the calendar. Each one
  /// advances exactly 7 days, so `finalDay == 1 + 7 * committingAdvances`.
  var committingAdvances: Int
  var runwayFloored: Int
  var energyFloored: Int
  var trustFloored: Int
  var assessment: String
}

private struct StateNormalization: Codable {
  var reason: String
  var applied: [String]
  var survivalFloor: SurvivalFloorDescription
  var survivalFloorAccounting: [SurvivalFloorAccounting]
}

private struct StateFixture: Codable {
  var schemaVersion: Int
  var saveVersion: Int
  var generatedFrom: String
  var driver: String
  var policy: String
  var targetDays: Int
  var normalization: StateNormalization
  var pairedSeed: String
  var environment: String
  var note: String
  var runs: [SeedRun]

  private enum CodingKeys: String, CodingKey {
    case schemaVersion, saveVersion, generatedFrom, driver, policy, targetDays
    case normalization = "_normalization"
    case pairedSeed, environment, note, runs
  }
}
