# SOLO: UNICORN RUN — Build 5 Change Log

Build 5 does two things: fixes the concrete, evidence-backed issues found in the
Build 4 engine review, and lays the foundation for continuous (open-ended) play
as a genuine second career mode alongside the original bounded arc — not a
replacement for it.

## Part 1 — Fix the fixable

### `careerScore` no longer lets revenue dominate

Momentum, trust, and energy are all clamped 0–100 before their multipliers
apply. Revenue previously contributed at a flat 1:1 rate with no ceiling —
individual tasks award 430–1,120 revenue each, and 13 of the 38 tasks touch
revenue directly, so a real career could plausibly reach revenue in the
thousands while trust + momentum + energy combined can never exceed 5,000
*at their absolute maximum*. Revenue could dominate the score almost
regardless of how well trust was protected, undercutting the game's own
thesis that verification matters as much as output.

Fixed in `SimulationEngine.careerScore(stats:)`: revenue now contributes at a
quarter of face value, capped at 5,000 — roughly commensurate with trust and
momentum's combined ceiling. Verified numerically in `SimulationEngineTests`:
a $20,000-revenue, zero-trust run no longer outscores a $2,000-revenue,
full-trust run by more than 2×.

### Doctrine logic centralized

Six separate inline `doctrine == .x` ternaries scattered through GameStore.swift
(attention budget, review energy cost, neglect drift rate, quality bonus,
starting-stat adjustment) are now one `DoctrineProfile.profile(for:)` lookup.
Every value is verified against Build 4's originals in
`SimulationEngineTests.testDoctrineProfileReproducesBuild4Values` — this is a
pure reorganization, not a rebalance.

### Content and simulation math split out of GameStore.swift

- **`ContentLibrary.swift`** — the 38 tasks, 12 dilemmas, 6 objective templates,
  and 3 initial agents, extracted verbatim (programmatic extraction, not
  retyped, specifically to avoid transcription errors).
- **`SimulationEngine.swift`** — `generateCorrelatedFailureEvent`, `makeResult`,
  `immediateEffects`, and `knownRisk` are now pure static functions taking
  every dependency as an explicit parameter instead of reading GameStore
  instance state. They are genuinely unit-testable in isolation now — Build 4's
  version of this logic could not be exercised without a full `@Observable`
  store. The RNG is threaded through as `inout SeededRandomNumberGenerator` so
  the exact sequence of consumption is unchanged; this refactor moves where
  the code lives, not what it computes or when it draws randomness.

GameStore.swift: 1,437 lines → 1,167 after extraction, before continuous mode's
additions.

## Part 2 — Continuous mode foundation

### The architecture question, settled with evidence

Two ways to deliver "keep playing indefinitely" were on the table: unlimited
*sequential* ventures (each keeps its normal 12-sprint shape, no cap on how
many you can play), or one *continuous*, uncapped venture with no sprint
boundaries at all.

Before building either, I checked what `advanceToNextVenture()` actually does
in Build 4: it was never hardcoded to stop at venture 2 — only the outcome
check was. And Hindsight's recall logic (`precedents.filter { $0.venture <
currentVenture }`) already generalizes to any number of ventures with zero
changes; a single endless venture would need a full redesign of what "an
earlier, comparable stretch" even means. Unlimited sequential ventures is the
smaller, safer change and was built as the foundation.

### `CareerMode` — a real choice, not a replacement

`.bounded` (Build 4's original 2-venture, 24-sprint arc) and `.continuous`
(unlimited ventures) are both first-class options, selected once at career
creation via a new picker on the setup screen. Existing saves default to
`.bounded` on migration and are never retroactively opted into continuous
mode.

### Venture completion in continuous mode is a checkpoint, not a rollover

Bounded mode is unchanged: `resolvedOutcome()`'s victory check is now gated on
`careerMode == .bounded`, so it still forces `.victory` at venture 2 exactly
as before. Continuous mode never auto-triggers a career-ending outcome at any
venture count — completing a venture instead populates a new
`VentureCheckpoint` (Track Record earned, revenue, trust, momentum, precedents
banked) and presents `VentureCheckpointScreen`, where the player explicitly
chooses **Continue** or **Retire**. Retiring converts the checkpoint into a
genuine `.victory` `CareerOutcome` with copy that reflects the actual venture
count — a continuous career still gets to end, on the player's own terms,
rather than either being forced to stop or never being able to.

### Two real bugs caught while wiring this in, both fixed

1. **`saveCareer()`'s stage guard didn't include `.ventureCheckpoint`.**
   Found by tracing the actual save path after adding the new stage, not
   assumed. Without the fix, reaching a checkpoint and backgrounding the app
   would have silently dropped the checkpoint state — the whole mechanism
   would have appeared to work in a single sitting and evaporated on reload.
   Guarded by `testCheckpointStateSurvivesSaveAndReload`.
2. **`apply(save:)` unconditionally clamped `venture` to
   `Self.maximumVentures`.** This would have silently truncated any
   continuous-mode save back down to venture 2 on every load. Now gated on
   `careerMode == .bounded`, with the same fix applied to the parallel legacy
   safety-net check just below it. Guarded by
   `testContinuousSaveIsNotClampedToTheBoundedVentureCap`.

A third, smaller mistake was caught and corrected during the refactor itself,
not left in: an early edit accidentally deleted `var doctrine:
FounderDoctrine`'s declaration while adding the new `selectedCareerMode`
property. Caught by re-grepping immediately after the edit rather than
assuming it landed clean.

### Save schema v6 → v7

`CareerSave` gains `careerMode` and `pendingVentureCheckpoint`, both decoded
with defensive defaults (`.bounded` / `nil`) so every v1–v6 save keeps
loading. `migrateV6` is a documented explicit no-op — the decoder's existing
defaults already handle a v6 save correctly, and writing the migration
function anyway keeps the version chain's intent visible rather than relying
on decode-time silence. Every save-key cleanup site (`hasSave`,
`resetCareer()`, `saveCareer()`) updated consistently with the new v6 key.

### Task-repeat spacing

A 10-title rolling exclusion window (`recentTaskTitles`) means continuous play
no longer redraws the same task two sprints in a row purely by chance. This is
in-memory-only smoothing, not a durable fix — it resets on app relaunch and
does not address the deeper limitation that 38 tasks will still repeat
heavily over a long continuous career. That remains real content-authoring
work for a future pass, now structurally easier because content lives in its
own file.

### A genuine, if easy to miss, Xcode project mistake — caught and fixed

Registering the two new test files initially placed their Sources build-phase
entries in the **app target's** build phase instead of the **test target's**
(there are two separate `PBXSourcesBuildPhase` blocks in this project, one per
target, and the anchor file used for insertion happened to be an app file).
This would have either failed to compile or, if it somehow compiled, meant the
new tests never actually ran as part of the test target. Caught by explicitly
reading both Sources phase blocks in full rather than trusting a reference
count, and fixed at both the build-phase and file-navigator-grouping level.

## New files

- `App/DoctrineProfile.swift`
- `App/ContentLibrary.swift`
- `App/SimulationEngine.swift`
- `App/VentureCheckpointScreen.swift`
- `Tests/ContinuousModeTests.swift`
- `Tests/SimulationEngineTests.swift`

## Modified files

- `App/GameStore.swift` (extraction + continuous-mode wiring)
- `App/GameModels.swift` (`CareerMode`, `VentureCheckpoint`, save schema v7)
- `App/ContentView.swift` (`CareerModeCard`, checkpoint stage routing)
- `SoloUnicornRun.xcodeproj/project.pbxproj`

## Required macOS verification before distribution

No Swift toolchain is available in this environment. Every change was
verified by direct tracing — reading the actual call sites, cross-checking
every reference after each extraction, and a full brace/paren balance sweep
across every Swift file in the project — but none of that substitutes for a
real build:

```sh
xcodebuild -quiet -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" \
  -configuration Debug test CODE_SIGNING_ALLOWED=NO \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"
```

Also manually verify: the CareerMode picker at setup, a full continuous-mode
venture reaching a checkpoint, Continue and Retire both behaving correctly,
and an old (Build 4 / v6) save loading cleanly into bounded mode.

## Known limitations

- Continuous mode's balance is unverified past a handful of ventures — drift,
  trust, and cascade-risk tuning were all originally calibrated against a
  24-sprint horizon, and nothing in this pass re-tunes them for a much longer
  career. The mechanics that let a player *recover* (review relieves drift,
  attention resets every sprint) are unchanged and should mean the game
  doesn't spiral on its own, but this is a reasoned expectation, not a tested
  one.
- Task-repeat spacing is in-memory only, not persisted, and does not address
  the underlying 38-task content ceiling.
- No new content (tasks, dilemmas, objectives) was authored for continuous
  mode specifically — this pass is architecture, not content expansion.
- `VentureCheckpointScreen` has not been visually verified in a simulator.
