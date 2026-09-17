# Blueprint — Series Changelog

## BUILD-BLUEPRINT-00-fixtures

Commit 0 of the Blueprint series. Scoped to fixtures only: it generates the pre-change baseline
from the current, unmodified build and changes no simulation behavior. `BlueprintTypes.swift` and
`BlueprintEngine.swift` are deliberately withheld until Commit 1; their absence from the project at
this commit is expected, not a defect.

**No GENOME BREAK.** No PRNG, hashed constant, or save schema was changed. `SaveEnvelope` remains
version 20.

### Shipped

- Added `Tests/BlueprintFixtureDriver.swift`, a seeded policy driver that plays the store for 200
  simulated operating days and records a hashed state trace.
- Added `Tests/Fixtures/Blueprint/pre_blueprint_save.json` and
  `Tests/Fixtures/Blueprint/pre_blueprint_state_200.json`, a matched day-0 / day-200 pair for
  BP-M-012's golden-run backward-compatibility check.
- Registered the driver in `project.pbxproj` (build file, file reference, Tests group, test target
  Sources — four lines).

### The driver

Every decision — which tasks to assign, which agent, verify or skip, resolution choice, dilemma
answer — is drawn from `SeededRandomNumberGenerator`, seeded per run off the run seed. The store's
own generator is never read by the policy, so policy draws cannot perturb simulation draws.

Run length is measured in operating days, not sprint indices. The trace records one entry per driver
step with `stateHash`, and `rollingHash[i] = SHA256(rollingHash[i-1] ‖ stateHash[i])`, so a future
regression reports the day it diverged rather than "the blob differs". Every `Double` that reaches a
hash — agent `drift`, `trust`, `calibration` — is pinned to 6 decimal places.

**A driver step is not the same thing as a sprint advance, and the distinction matters when reading
the tables below.** A step is one pass of the policy loop. Only a pass that actually commits a
sprint moves the calendar: `commitSprint()` returns early when `commitBlockerMessage` is non-nil
(`App/GameStore.swift:1846`), and only a committing pass reaches
`advanceOperatingTime(hours: 7 * 24)` (`App/GameStore.swift:1992`). That call always yields exactly
7 days — `OperatingCalendar.advance(hours:)` computes `days = (startHour + elapsed) / 24`, which for
`hour = 9` and `elapsed = 168` is 7 (`App/CompanyFinance.swift:603`).

So the governing relation is `finalDay == 1 + 7 × committingAdvances`, never `1 + 7 × driverSteps`.
Every seed reconciles against it: seeds 0, 1 and `UInt64.max` each committed 29 advances for day 204
(`1 + 7×29`) while taking 32, 38 and 43 steps respectively, and seed 2 committed 22 for day 155
(`1 + 7×22`) across 37 steps. Both counts are recorded per seed in each fixture as `driverSteps` and
`committingAdvances`, so the arithmetic is checkable without this document.

Generated on iPhone 17 / iOS 27.0, recorded in the fixture's `environment` field. Regenerate with:

```
xcodebuild test -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:"Solo Unicorn Run Tests/BlueprintFixtureDriver" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) BLUEPRINT_FIXTURES'
```

### Seed selection

Trace seeds are `0`, `1`, `2`, `UInt64.max`, mirroring the four already pinned in
`splitmix64_vectors.json`.

The tech spec named `0xC0FFEE` for the save fixture. **It was dropped, and the reason is
structural, not preferential:** under this driver `0xC0FFEE` terminates in a victory outcome at day
78, so no day-200 state is obtainable from it and the second half of the pair cannot be produced at
all. Seed `2` is disqualified for the same reason, terminating in victory at day 155. Of the three
seeds that reach the target — `0`, `1`, `UInt64.max` — `UInt64.max` leans least on the survival
floor (46.5% of driver steps floored on runway, 53.5% on energy, against 84.4% for seed 0 and
55.3%/57.9% for seed 1), and is therefore the most naturally representative baseline. The ranking is
not an artifact of the denominator: measured per committing advance instead, the same three read
93.1%, 72.4% and 69.0% on runway, and `UInt64.max` is still lowest.

An earlier revision of the driver silently defaulted the save fixture to seed `0`, the most
floor-dependent of the four. That was never a decision; it was the first element of the seed array.
It is recorded here because the substitution reached generated fixtures before it was caught.

### The matched pair

`pre_blueprint_save.json` is the day-0 half and the `UInt64.max` run inside
`pre_blueprint_state_200.json` is the day-200 half. The save is read from the paired seed's own
store **before that store is driven**, inside the same loop iteration that produces its trace, so
the two halves are the same run by construction rather than by coincidence. Reading `UserDefaults`
does not perturb the store; this was confirmed empirically, since all four trace hashes are
unchanged from runs generated before the day-0 capture existed.

The pairing is checkable: the save's `_normalization.pairing.counterpartTraceHash` equals the
trace's `traceHash` (`1efd39a5…`).

Naming precision: the calendar labels the day-0 state **day 1**. `OperatingCalendar.totalDays`
initialises to 1 (`App/CompanyFinance.swift:594`). "Day 0" means pre-first-advance.

### Findings against the current build

**1. The persisted save envelope is not byte-stable across processes.** A first generation differed
in 782 leaves between two runs. Confirmed against source, not inferred:

- `companyFlags` is a `Set<CompanyFlag>` (`App/GameStore.swift:169`), and
  `finance.appliedTransactionIDs` / `finance.expiredFundingOpportunityIDs` are `Set<String>`
  (`App/CompanyFinance.swift:466`, `:468`). Swift `Set` iteration order is unspecified and varies
  per process, so these serialize in a different order each run.
- `TechComHeadline` is built with ambient `UUID()` at `App/GameStore.swift:3606`, while the same
  file already has `nextDeterministicUUID()` (`:3573`) and uses it for task IDs (`:3418`, `:3463`).
  The inconsistency puts non-deterministic identifiers into persisted state.

These are normalized at the fixture boundary so the baseline is diffable, and every normalization is
recorded inside the file. **The engine was not changed** — a Commit 0 baseline has to come from the
unmodified build. The fix belongs in a later commit.

Note that the static auditor cannot catch the `UUID()` case: `GameStore` is not contracted as a pure
type, so no rule applies to it. Only the two-process byte diff found it.

**2. `splitmix64` folds the Genome; it is not the play-loop generator.** `BlueprintEngine.splitmix64`
is a single-shot fold producing one `UInt64` run seed, which is then handed to
`SeededRandomNumberGenerator(seed:)`. There is no interoperability requirement between them, and
`splitmix64_vectors.json` is correctly scoped to validate `BlueprintEngine`'s own math in isolation.
`init(seed:)` assigns the seed raw — it does not re-mix — and all mixing happens per draw
(`App/SeededRandomNumberGenerator.swift:36`):

```swift
init(seed: UInt64) {
    state = seed
}

mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    return value ^ (value >> 31)
}
```

Counterintuitive but true, and recorded so nobody builds on it: because `init` assigns raw and
`next()` adds gamma *before* mixing, the generator's **first draw is identical to
`splitmix64(seed)`** for all four pinned seeds. The chains then diverge completely — measured
overlap is 1 of 16 outputs per seed. The coincidence at index 0 is a property of the shared
construction, not a contract.

**3. `CLAUDE.md`'s build commands do not work as written.** The real scheme is `Solo Unicorn Run` and
the real unit test target is `Solo Unicorn Run Tests` — both contain spaces, and both lines in
`CLAUDE.md` are already marked `VERIFY`. No iPhone 16 simulator exists on the build machine; iPhone
17 / iOS 27.0 was used. The stated test floor of 686 is stale: the unit target now holds 907 tests.

**4. The UI test suite fails unstably on this branch.** Two full-suite runs of effectively identical
code produced 6 failures and then 14, all in `Solo Unicorn Run UI Tests`, as XCUITest waiter
timeouts against the Atlantis, FounderDesk, EvidenceTriage and FounderStrategyBoard surfaces that
the visual-fidelity work is actively modifying. A UI failure count is therefore not a reliable
baseline signal on this branch. The unit target was clean in both runs.

### Survival floor

The driver clamps three values immediately before every `commitSprint()`, mirroring the existing
`ContinuousModeTests.playToVentureEnd`. Without it a run dies of bankruptcy long before day 200.

- **Clamped, complete list:** `stats.runway` floored at 80, `stats.energy` at 80, `stats.trust` at 60.
- **Not clamped:** `revenue`, `momentum`, `capital`, `trackRecord`, `coverage`, `finance.cash`, and
  all four agent fields.
- **Rule:** `value = max(value, floor)`. A value at or above its floor is untouched; one below is
  raised to exactly the floor. Never applied after the commit, so sampled state reflects the
  sprint's own outcome.
- **Why these three:** `resolvedOutcome()` (`App/GameStore.swift:3848`) ends a career on exactly
  `runway <= 0`, `energy <= 0`, `trust <= 0`.

Fire counts, recorded per seed inside each fixture's `_normalization` block. The floor is evaluated
once per driver step, so `driverSteps` is the denominator for the floored counts; `committingAdvances`
is shown alongside because it, not `driverSteps`, determines the final day:

| seed | driver steps | committing advances | final day | runway | energy | trust |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 32 | 29 | 204 | 27 (84.4%) | 16 | 10 |
| 1 | 38 | 29 | 204 | 21 (55.3%) | 22 | 10 |
| 2 | 37 | 22 | 155 | 16 | 16 | 11 |
| `UInt64.max` | 43 | 29 | 204 | 20 (46.5%) | 23 | 15 |

The clamp fired dozens of times in every seed. Each fixture carries a prose `assessment` per seed
saying so outright, so a later reader cannot mistake a floor-held end state for natural survival.
The day-0 save itself predates every clamp, since the floor runs before each advance and no advance
has run at that point.

### Defect introduced and fixed within this commit

The driver's generator was originally gated on `ProcessInfo.environment["BLUEPRINT_FIXTURE_OUT"]`.
That gate never worked: `xcodebuild` does not forward the host environment into the sandboxed
simulator runner, so the read always returned nil and the generator was **unconditionally skipped**.
Both the plain variable and the `TEST_RUNNER_`-prefixed form were tried and both logged a skip.

Removing the broken gate flipped the failure direction: the generator then ran **unconditionally**,
including on a routine `xcodebuild test`. This was confirmed, not assumed — the unfiltered
full-suite result bundle recorded `testGenerateBlueprintBaselineFixtures()` as a passing 1s test.

Fixed with a compile-time gate, `#if BLUEPRINT_FIXTURES`. A build setting crosses the sandbox
boundary that defeated the environment read, so the generator is compiled out of an ordinary test
build entirely and CI never pays for a fixture pass. Test plans were not used because this project
has none; it is target-based testing driven by the scheme, and restructuring that was out of scope
for Commit 0.

Confirmed in both directions: with no flag, only the determinism guard runs and the generator
appears zero times in the results with zero fixture writes; with the flag, the generator runs and
reproduces the committed fixtures byte-for-byte. `testDriverIsReproducibleWithinAProcess` is
deliberately left ungated — it is an assertion, not a generator.

### Verification

- **Unit target `Solo Unicorn Run Tests`: 907 total, 907 passed, 0 failed, 0 skipped.** The 686
  floor is not reduced. Net addition to routine runs is one test, the determinism guard; the
  generator does not count because it is compiled out.
- **Full suite including UI: 951 total, 937 passed, 14 failed, 0 skipped.** All 14 failures are in
  the UI target (see Finding 4); the unit target portion was 907/907.
- Both fixtures verified **byte-identical across independent simulator processes**, repeatedly, and
  after every change to the driver.

SHA-256 of the committed fixtures, as generated on iPhone 17 / iOS 27.0:

```
f32782c0850fa60c6388728a496e221bc0d449be9f44f5319f4ae569e8f208af  pre_blueprint_save.json
4565e7f4b975ea55dc4162570ebf052f65859d19225dc2bd5fe60105d3b05d23  pre_blueprint_state_200.json
b7c6521b9615d2f2dbacae64a37712aabec20b8d4bf7f8c208efcf61dee5d46b  splitmix64_vectors.json
```

`splitmix64_vectors.json` is unchanged by this commit; its hash is recorded so the whole fixture
directory is pinned.

- `audit_swift_purity.py Tests/BlueprintFixtureDriver.swift --strict` passes with 0 errors and
  0 warnings.
- `audit_swift_purity.py App/ --strict` **fails** with 9 errors and 6 warnings, all pre-existing and
  none introduced here: `PURITY-STATE` ×5 in `DoctrineProfile.swift`, `PURITY-NONDETERMINISM` ×2 in
  `TechComEngine.swift`, `VIEW-PURITY` ×2 in `WorkSessionEngine.swift`, plus `HASH-CANONICAL` ×5 and
  `DETERMINISM-ORDER` ×1 as warnings. The CLAUDE.md completion gate does not currently pass on this
  branch, independent of this commit.

**Auditable decision — the full suite was not re-run after the final driver edits.** The compiled-in
changes outside `#if BLUEPRINT_FIXTURES` are a private constant rename, `Codable` field names,
comments, and the body of `normalizedSave`. That function is declared at
`Tests/BlueprintFixtureDriver.swift:411`, outside the gate, but
`grep -n "normalizedSave" Tests/BlueprintFixtureDriver.swift` returns exactly one call site, line
179, which falls inside the gate's `#if` at line 110 and `#endif` at line 188 — so it is dead code
in an ordinary build. None is reachable from
`testDriverIsReproducibleWithinAProcess`, the only test in the file that executes in an ordinary
build, and that test ran and passed in the regeneration runs. Re-running the UI target to confirm a
binary-equivalence claim this specific was judged process for its own sake.

### Fixture self-description

Both fixtures document their own construction, because a baseline read six months from now has to be
interpretable without this changelog. `_normalization.applied` records only normalizations that
actually changed bytes; `checked` lists the paths inspected. On the day-0 save all four collections
are empty, so `applied` is empty and the file says plainly that it is byte-stable as-is — an earlier
revision listed all four as applied, which would have implied the save needed normalizing when it
did not.

### Unchanged safeguards

Simulation RNG, `commitSprint()` behavior, task eligibility, scoring, Evidence creation, Tech.com,
save schema and version, RevenueCat behavior, facilities, agents, and canonical review order are
unchanged. No file under `App/` was modified by this commit.

### Open items for Commit 1

- Assign a stable `BP-*` test ID to the determinism guard; it currently has none.
- Fix the non-determinism in Finding 1 — sort the `Set`-backed fields at the serialization boundary
  and replace the `UUID()` at `App/GameStore.swift:3606` with `nextDeterministicUUID()`. Both change
  persisted bytes, so both need their own commit and a re-baselined fixture.
- Correct the stale scheme, target, simulator, and test-floor lines in `CLAUDE.md`.
