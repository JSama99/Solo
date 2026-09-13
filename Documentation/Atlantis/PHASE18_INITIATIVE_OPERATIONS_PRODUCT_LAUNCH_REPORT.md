# SOLO Atlantis — Phase 18: Initiative Operations — Product Launch

Date: 2026-09-13  
Verdict: **GO WITH HUMAN ACCEPTANCE**

Phase 18 adds the first dedicated major-initiative execution authority. Product Launch now begins only after the existing Strategy Board preparation gate succeeds, commits the prepared sprint once, freezes launch inputs, accepts two consequential founder decisions, resolves three distinct outcome dimensions deterministically, applies supported canonical consequences once, persists every interruption point, and returns the founder to the Strategy Board only after the outcome is acknowledged.

Automated architecture, regression, accessibility-path, build, and device-launch checks pass. Human acceptance remains for launch feel, pacing, animation, audio/haptics, and physical-device readability. The implementation intentionally defers launch cost, Revenue/customer changes, Hindsight, Track Record, and bespoke named-NPC aftermath because the current repository does not provide a trustworthy Product Launch API for those consequences.

## Architecture

### Canonical authority

`ProductLaunchOperation` is a small, launch-specific canonical model in `App/SimulationModels.swift`. It owns:

- the bounded lifecycle state;
- the founder-known preparation snapshot;
- separately persisted resolution truth;
- the deterministic seed;
- release and public-posture decisions;
- the resolved three-dimension result; and
- duplicate-protection diagnostics.

`ProductLaunchResolutionPolicy` is pure. It receives one operation and returns one resolution without mutating `GameStore`, consuming the canonical runtime RNG, reading presentation state, or calling Atlantis.

`GameStore` remains the mutable simulation authority. `beginProductLaunch()` owns the one-time Strategy Board handoff and sprint commit. `resolveProductLaunch()` is the single authorized consequence boundary. SwiftUI displays state and forwards intent; it does not calculate or apply canonical outcomes.

### Lifecycle

```text
Strategy Board PLAN + PREPARE
              ↓
          committed
              ↓
         Launch Check
              ↓
      Founder Decisions
              ↓
     Launch In Progress
              ↓
          resolving
              ↓
           Outcome
              ↓
      explicit Return to World
```

The underlying states are `notStarted`, `committed`, `launchCheck`, `founderDecision`, `executing`, `resolving`, and `resolved`. Guards prevent skipped stages, repeated execution, repeated resolution, and rollback after resolution. A resolved operation remains saved until the founder explicitly returns to the world, so an interrupted outcome can be recovered without applying consequences again.

### Strategy Board integration

The ready Product Launch action now calls `GameStore.beginProductLaunch()` instead of ending after `commitSprint()`. That method:

1. rejects an active or duplicate launch;
2. reuses `canCommitSprint` and its canonical blocker message;
3. requires reviewed, resolution-locked Aurora, Stacks, and Brio work with ledger evidence;
4. captures launch preparation before the sprint advances;
5. creates and persists the operation;
6. calls the existing `commitSprint()` exactly once; and
7. advances the operation to Launch Check.

The player does not repeat agent work, evidence review, or sprint preparation inside the launch operation.

### Decision model

The operation has two decisions. A third Founder Intervention decision was deferred because no existing review API could safely spend Attention and reduce uncertainty without creating a Product Launch-specific truth shortcut.

| Decision | Choices | Tradeoff | Resolution effect |
| --- | --- | --- | --- |
| Release posture | Ship Now; Conservative Release | Ship Now preserves the market window and Momentum upside while known reliability concerns carry more weight. Conservative Release reduces technical exposure while lowering reach and Momentum potential. | Technical adjustment; market reach adjustment; Momentum delta. |
| Public posture | Bold; Evidence-Led; Quiet | Bold maximizes reach and has sharp downside when support is weak. Evidence-Led rewards reviewed evidence with lower volatility. Quiet limits exposure and immediate reach. | Market reach; public adjustment; Coverage delta. |

Every choice changes the deterministic result. Tests compare alternative choices against the same fixture and seed.

### Resolution policy

The policy resolves three scores independently:

- **Technical** is primarily Stacks delivered quality plus release posture, known reliability exposure, and bounded deterministic variance.
- **Market** combines Aurora and Brio delivered quality, public posture reach, release timing, public rival pressure, and bounded deterministic variance.
- **Public** combines reviewed evidence completeness, committed Trust, committed Coverage, Brio delivered quality, claim support, public posture, and bounded deterministic variance.

Scores are clamped to `0...100` and classified as `failure`, `weak`, `mixed`, `strong`, or `exceptional`. The overall class is bounded to `failure`, `weak`, `mixed`, `strong`, or `breakout`, using the average and weakest dimension so one high score cannot conceal a serious launch weakness.

Sprint success is therefore not launch success. A strong market signal can coexist with weak technical delivery; a strong product can receive limited market traction; and weak evidence can reduce public reception even when product and market preparation are strong.

### Canonical resolution boundary

`GameStore.resolveProductLaunch()` performs the complete supported mutation in one synchronous path:

1. verifies the operation is executing;
2. advances it to `resolving`;
3. resolves the pure deterministic result;
4. applies Momentum and Trust through the existing `apply(_:)` authority;
5. applies Coverage and creates one deduplicated public Signal TV event through `applyPublicMediaEvent(..., persist: false)`;
6. stores the result and one effect-application receipt;
7. marks the operation resolved;
8. sanitizes state; and
9. saves once.

Calling the method again changes no canonical stat and creates no second media event. The duplicate attempt is recorded only as DEBUG-visible diagnostic state.

### Save and recovery behavior

`CareerSave` now has an additive optional `productLaunchOperation` field. Its custom decoder uses `decodeIfPresent`, so a version-19 save created before Phase 18 decodes with no active launch. Save version remains **19** and no migration is required.

All interactive stages save after valid transitions and choices. A launch interrupted while committed, at Launch Check, after founder decisions, while executing, or after resolution restores its exact operation state. A restored resolved operation contains its result and cannot reapply effects.

### Public-world integration

Resolution publishes a `PublicMediaEvent` with a stable operation-derived ID, public headline, public market/public ratings, tone, and Coverage delta. Signal TV and downstream world presentation consume that existing canonical public state. Product Launch does not call Atlantis, its presentation model, the World Consequence Director, or named-NPC presentation directly.

No separate Atlantis launch truth was introduced. Bespoke NPC dialogue and world-event staging were deferred; the existing public event and Coverage changes remain eligible for normal public-world reactions.

## Resolution inputs

| Input | Canonical source | Founder-visible? | Resolution dimension affected |
| --- | --- | --- | --- |
| Aurora visible preparation | Reviewed Aurora `SoloTask.result`, using revealed actual quality when Founder Review exposed it, otherwise reported quality | Yes | Launch Check and founder risk context |
| Aurora delivered quality | Existing `TaskResult.deliveredQualityForSimulation` frozen in resolution truth | No unless already revealed | Market; public claim support |
| Stacks visible preparation and known risk | Reviewed Stacks result, verification state, evidence completeness, and `knownOperationalRisk` | Yes | Launch Check; release-risk context |
| Stacks delivered quality | Existing `TaskResult.deliveredQualityForSimulation` frozen in resolution truth | No unless already revealed | Technical; public claim support |
| Brio visible preparation | Reviewed Brio result and evidence completeness | Yes | Launch Check and founder risk context |
| Brio delivered quality | Existing `TaskResult.deliveredQualityForSimulation` frozen in resolution truth | No unless already revealed | Market; public |
| Evidence state | Existing Evidence Ledger membership plus each reviewed result's evidence completeness | Yes | Public and Bold/Evidence-Led support |
| Known risks | Existing reviewed task `knownOperationalRisk` values | Yes | Technical release adjustment and explanation |
| Founder Attention | `GameStore.attentionRemaining` at commit | Yes | Informational Launch Check snapshot; no score mutation in Phase 18 |
| Runway | `FounderStats.runway` at commit | Yes | Informational Launch Check snapshot; no launch cost exists |
| Cash | `CompanyFinance.cash` at commit | Yes | Informational Launch Check snapshot; no launch cost exists |
| Trust | `FounderStats.trust` at commit | Yes | Public |
| Momentum | `FounderStats.momentum` at commit | Yes | Informational Launch Check snapshot; result applies a bounded Momentum delta |
| Coverage | `FounderStats.coverage` at commit | Yes | Public baseline and resulting Coverage delta |
| Public rival pressure | Maximum public `TechComRival.claimedMomentum` | Yes as public rival context | Market |
| Release posture | Founder decision persisted on the operation | Yes | Technical; market; Momentum |
| Public posture | Founder decision persisted on the operation | Yes | Market; public; Coverage |
| Deterministic seed | Mixed from the saved canonical RNG state and committed venture/sprint/preparation values without advancing that RNG | No in production UI | Bounded variance in all three dimensions |

The founder-known snapshot has no fields named for actual quality, overclaim, drift, future outcome, or RNG. Canonical resolution truth is stored separately and never rendered. When unresolved hidden variance affects an outcome, founder-facing explanation says only that one source of variance is not yet fully understood.

## Fixture outcome matrix

These results use each deterministic fixture with **Ship Now + Evidence-Led**.

| Fixture | Technical | Market | Public | Overall | Canonical consequences |
| --- | --- | --- | --- | --- | --- |
| Strong preparation | Exceptional (85) | Exceptional (94) | Exceptional (84) | Breakout | Momentum +9; Trust +6; Coverage +10 |
| Technical risk | Weak (39) | Strong (81) | Exceptional (83) | Mixed | Momentum +7; Trust +2; Coverage +9 |
| Weak evidence | Exceptional (83) | Exceptional (82) | Mixed (52) | Strong | Momentum +7; Trust +3; Coverage +5 |
| Strong market / weak product | Weak (34) | Exceptional (86) | Exceptional (85) | Mixed | Momentum +8; Trust +1; Coverage +9 |
| Strong product / weak growth | Exceptional (92) | Mixed (56) | Strong (78) | Strong | Momentum +3; Trust +6; Coverage +5 |
| Hidden overclaim | Weak (49) | Exceptional (84) | Strong (81) | Strong | Momentum +7; Trust +2; Coverage +9 |
| Duplicate resolution | Exceptional (85) | Exceptional (89) | Exceptional (84) | Breakout | Momentum +8; Trust +6; Coverage +10; second resolution applies nothing |

The weak-evidence fixture keeps delivered product quality strong and weakens only claim support. The hidden-overclaim fixture shows optimistic founder-visible readiness while authorized delivered truth affects the result; neither the Launch Check nor its explanation names the hidden cause.

## Isolation

```text
New canonical resources: ProductLaunchOperation only; no new currency or resource stat
GameStore mutation boundary: GameStore.resolveProductLaunch()
Save schema change: additive optional CareerSave.productLaunchOperation
Save version: 19
Direct Atlantis calls: none
Hidden truth exposed to player: no
Runtime RNG: local SeededRandomNumberGenerator from a persisted operation seed; canonical RNG is not consumed and system randomness is not used
```

No production project-file or package change was required. No new Swift file was introduced, so target membership remained untouched.

## User interface and accessibility

The compact Strategy Board operation surface contains Launch Check, Founder Decisions, Launch In Progress, and Outcome stages. It presents agent-specific preparation, known risks, selected-state semantics, three outcome dimensions, canonical consequence deltas, and founder-safe causal explanations. It uses scrolling and scalable text for the largest Dynamic Type category, preserves minimum control sizes, exposes stable accessibility identifiers, and respects Reduce Motion in the tested route.

Execution uses a short controlled presentation transition. It does not claim real-time agent simulation and does not require real-world waiting.

## Verification

All passing counts below are from the final Phase 18 revision after the weak-evidence fixture correction.

| Verification | Result |
| --- | --- |
| Focused `ProductLaunchOperationTests` | **12/12 passed** |
| Strategy Board UI regression | **2/2 passed** (`testFounderStrategyBoardFixturesRoutesAndReturnContext`, `testFounderStrategyBoardDuplicateCommitAndPublicRiskBoundary`) |
| Garage + Atlantis unit regression | **156/156 passed** (97 Founder Garage Reality + 59 Atlantis Runtime) |
| Complete unit target | **863/863 passed** |
| Product Launch UI, iPhone 17 Pro Max simulator | **2/2 passed** |
| Product Launch UI, iPad Air 11-inch (M4) simulator | **2/2 passed** |
| Debug simulator build | **BUILD SUCCEEDED**; the final simulator tests recompiled the current Debug app on both simulator classes |
| Release generic iOS Simulator build | **BUILD SUCCEEDED** |
| Physical iPhone 16 Pro signed Debug build | **BUILD SUCCEEDED** |
| Physical iPad Air 11-inch (M4) signed Debug build | **BUILD SUCCEEDED** |
| Physical iPhone 16 Pro install / launch / process probe | **Passed**; PID 6836; one matching process |
| Physical iPad Air 11-inch (M4) install / launch / process probe | **Passed**; PID 1797; one matching process |

The first focused test invocation used the wrong displayed test-target name and exited 70. The corrected exact target passed. A later focused invocation encountered sandbox denial for CoreSimulator/cache access and exited 74; the same invocation rerun with the required environment access passed. Both were invocation/environment failures rather than test or build failures.

Physical-device evidence:

- iPhone 16 Pro: [install](Phase18Evidence/iphone16pro-install.json), [launch](Phase18Evidence/iphone16pro-launch.json), [process](Phase18Evidence/iphone16pro-process.json)
- iPad Air 11-inch (M4): [install](Phase18Evidence/ipad-air-m4-install.json), [launch](Phase18Evidence/ipad-air-m4-launch.json), [process](Phase18Evidence/ipad-air-m4-process.json)

The physical probes prove signed build, install, launch with Phase 18 fixture flags, and a live matching process on each connected device. They do not prove visual, animation, audio, haptic, or interaction quality.

## Human acceptance

Review these subjective items on both physical devices:

- Launch Check hierarchy and scan speed;
- decision tradeoff clarity before selection;
- selected-state clarity without relying on color;
- Launch In Progress pacing with Reduce Motion on and off;
- Outcome hierarchy and causal explanation clarity;
- largest Dynamic Type scrolling, reachability, and truncation;
- VoiceOver reading order and control labels;
- audio and haptic timing; and
- return-to-world context after acknowledging the outcome.

## Git status and ownership

Phase 18 modified these existing source and test files:

- `App/SimulationModels.swift`
- `App/GameStore.swift`
- `App/GameModels.swift`
- `App/FounderGaragePhysicalComponents.swift`
- `Tests/FounderDeskWorkspaceTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`

Phase 18 added this report and the six JSON files in `Documentation/Atlantis/Phase18Evidence/`. Some modified source files also contain earlier uncommitted phase work; Phase 18 preserved it. Nothing was staged, committed, or pushed by this phase.

The final worktree status is:

```text
## atlantis-phase0-masterplan...origin/atlantis-phase0-masterplan
 M App/App.swift
MM App/AtlantisRealityScene.swift
MM App/AtlantisRealityView.swift
MM App/AtlantisWorldPresentationModel.swift
 M App/ContentView.swift
 M App/FounderDeskWorkspace.swift
 M App/FounderDeskWorkspaceModel.swift
 M App/FounderGaragePhysicalComponents.swift
 M App/GameModels.swift
 M App/GameStore.swift
 M App/SimulationModels.swift
A  Documentation/Atlantis/PHASE14_LIVING_WORLD_LAYER_REPORT.md
A  Documentation/Atlantis/Phase14Evidence/ipad-air-m4-living-world-profile.json
A  Documentation/Atlantis/Phase14Evidence/iphone16pro-living-world-profile.json
A  Documentation/Atlantis/Phase14Evidence/physical-game-performance-summary.json
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/baseline.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/pallas-surge.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/scrutiny.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/spotlight.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/baseline.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/pallas-surge.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/scrutiny.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/spotlight.png
 M "SoloUnicornRun.xcodeproj/xcshareddata/xcschemes/Solo Unicorn Run.xcscheme"
MM Tests/AtlantisRuntimeTests.swift
 M Tests/FounderDeskWorkspaceTests.swift
MM UITests/AtlantisRuntimeUITests.swift
 M UITests/Build32_6_1ProductionContinuityUITests.swift
?? .agents/
?? .mcp.json
?? Assets/Atlantis/Phase0/
?? Assets/Atlantis/Phase1/
?? Assets/Atlantis/Phase2/
?? Assets/Atlantis/Phase3/
?? Assets/Atlantis/Phase4/
?? Assets/Atlantis/Phase5/
?? Assets/Atlantis/Phase6/
?? Assets/Atlantis/Phase7/
?? Assets/Atlantis/Phase8/
?? Assets/Atlantis/Phase9/
?? CLAUDE.md
?? Documentation/Atlantis/PHASE15_FOUNDER_ENCOUNTERS_REPORT.md
?? Documentation/Atlantis/PHASE16_WORLD_CONSEQUENCE_LAYER_REPORT.md
?? Documentation/Atlantis/PHASE17_FOUNDER_STRATEGY_BOARD_REPORT.md
?? Documentation/Atlantis/PHASE18_INITIATIVE_OPERATIONS_PRODUCT_LAUNCH_REPORT.md
?? Documentation/Atlantis/Phase14Evidence/ipad-air-m4-game-performance.trace/
?? Documentation/Atlantis/Phase14Evidence/ipad-air-m4-reactive-final.trace/
?? Documentation/Atlantis/Phase14Evidence/iphone16pro-game-performance.trace/
?? Documentation/Atlantis/Phase14Evidence/iphone16pro-reactive-final.trace/
?? Documentation/Atlantis/Phase14Evidence/ui-screenshots/
?? Documentation/Atlantis/Phase16Evidence/
?? Documentation/Atlantis/Phase17Evidence/
?? Documentation/Atlantis/Phase18Evidence/
?? Solo/
?? skills-lock.json
?? skills/
```

Ownership grouping:

- **Existing staged Phase 14 work:** the added Phase 14 report/evidence entries and the staged portions of the `MM` Atlantis source/test files.
- **Phase 15 work:** `PHASE15_FOUNDER_ENCOUNTERS_REPORT.md` plus shared source/test changes from that pass.
- **Phase 16 work:** `PHASE16_WORLD_CONSEQUENCE_LAYER_REPORT.md`, `Phase16Evidence/`, plus shared source/test changes.
- **Phase 17 work:** `PHASE17_FOUNDER_STRATEGY_BOARD_REPORT.md`, `Phase17Evidence/`, Strategy Board source/UI tests, and the pre-existing shared-scheme modification.
- **Phase 18 work:** the six source/test files listed above, this report, and `Phase18Evidence/`.
- **Unrelated or earlier repository work:** `.agents/`, `.mcp.json`, Phase 0–9 assets, `CLAUDE.md`, `Solo/`, `skills-lock.json`, `skills/`, and other shared app files not changed specifically for Phase 18.

## Next phase boundary

Phase 19 may add Agent Operations Economy through the canonical agent workload, capacity, autonomy, reliability, drift, and micromanagement systems. Phase 18 does not implement that work.
