# Atlantis Phase 14 — Reactive Living World Layer

## Recommendation

**GO**

Atlantis now visibly changes in response to a read-only projection of SOLO's existing public simulation state. The same Startup Row view presents four distinct stories: baseline activity, a company/media spotlight, a public Pallas AI surge, and public scrutiny. Population remains bounded and pooled, Phase 13 canonical routes remain intact, physical probes completed without thermal escalation, canonical simulation did not change, the save schema remains version 19, and Atlantis remains compiled only under `#if DEBUG`.

Human acceptance remains necessary for traversal feel, VoiceOver phrasing, largest Dynamic Type, Reduce Motion perception, and visual quality on the physical screens. Automated tests and traces cannot establish those subjective properties.

## Architecture

The dependency path is one-way:

```text
GameStore public values
  -> AtlantisWorldSignalSnapshot
  -> AtlantisLivingWorldDirector
  -> AtlantisDistrictReaction
  -> population, displays, encounters, LOD, diagnostics
  -> RealityKit entities
```

`AtlantisWorldSignalSnapshot.read(_:)` is the sole canonical boundary. It admits company Trust, Momentum, Coverage, venture progression, and each Tech.com rival's public name and claimed Momentum. It does not admit agent truth, actual rival values, rival verification/overclaim state, save payloads, simulation RNG, or a mutable `GameStore` reference.

`AtlantisLivingWorldDirector` owns the derived presentation configuration and coordinates the lower systems. It never retains `GameStore` and has no write-back path. Reactions, fixtures, encounter cooldowns, LOD state, and display content are presentation-only and are not persisted.

The director runs decisions at 2 Hz. Actor motion remains in the scene update, while mid-tier motion updates every 200 ms. Central thresholds are 220 m for near and 450 m for mid; far districts have no individual actor behavior. Near districts receive their full derived population, mid districts receive at most two pedestrians and no vehicles, and far districts receive no actors.

The normal global budget is 10 pedestrians and 2 vehicles. The explicit density profiler may request up to 20 pedestrians and 2 vehicles. Reconciliation recycles all excess actors before allocating replacements, clamps profiler inputs, and immediately restores the normal budget when the profiler is cleared. Repeated district transitions reuse the same pool.

Pedestrian and vehicle routes use explicit district-owned waypoint data on walkable geometry. All route segment samples were tested against walkable triangles and building barriers. Actors now traverse routes out and back, avoiding endpoint teleportation. Pedestrians and vehicles have no collision components and cannot become Phase 13 interaction targets.

Each resident district receives one reusable, collision-free public display. Displays use cheap unlit material changes and regenerated static text only when public content changes. There is no video playback or independent display timer. Rival Watch uses public Tech.com claims only.

The encounter prototype contains three deterministic, presentation-only archetypes:

- Founder rumor: public rival activity.
- Reporter presence: elevated public Coverage.
- Customer reaction: public Trust/coverage state.

Encounters require proximity within 22 m, remain visible for 6 seconds, have a 30-second per-archetype cooldown, disappear when the player leaves or the district unloads, and never mutate gameplay.

## Deterministic scenarios

All four fixtures bypass save state and feed the same read-only snapshot type used by live presentation.

| Scenario | Startup pedestrians | Display | Encounter activation |
| --- | ---: | --- | --- |
| A — Baseline | 5 | Gray `STARTUP · DAILY WIRE` | 0 |
| B — High Momentum + positive Coverage | 10 | Cyan `SIGNAL TV · SPOTLIGHT` | Reporter |
| C — public Pallas surge | 8 | Purple `RIVAL WATCH`, public Momentum 90 | Founder rumor |
| D — negative public state | 4 | Orange `SIGNAL TV · SCRUTINY` | Customer reaction |

The comparison uses one Startup Row camera and identical lighting. Screenshot evidence:

- iPhone 17 Pro Max simulator: [baseline](Phase14Evidence/reactive-scenarios/iphone-17-pro-max/baseline.png), [spotlight](Phase14Evidence/reactive-scenarios/iphone-17-pro-max/spotlight.png), [Pallas surge](Phase14Evidence/reactive-scenarios/iphone-17-pro-max/pallas-surge.png), [scrutiny](Phase14Evidence/reactive-scenarios/iphone-17-pro-max/scrutiny.png)
- iPad Air 11-inch (M4) simulator: [baseline](Phase14Evidence/reactive-scenarios/ipad-air-11-m4/baseline.png), [spotlight](Phase14Evidence/reactive-scenarios/ipad-air-11-m4/spotlight.png), [Pallas surge](Phase14Evidence/reactive-scenarios/ipad-air-11-m4/pallas-surge.png), [scrutiny](Phase14Evidence/reactive-scenarios/ipad-air-11-m4/scrutiny.png)

## Physical-device results

The final reactive build was installed and run on:

- iPhone 16 Pro, iOS 26.7.
- iPad Air 11-inch (M4), iPadOS 26.6.2.

Both in-app profile reports contain zero errors. All 12 Founder/Startup/Commerce streaming transitions passed on each device with no duplicate actors. Both remained at nominal thermal state through the staged 0/5/10/20/mixed probes. The density profiler allocated at most 20 pedestrians and 2 vehicles; its final normal state contained 2 active pedestrians, 18 pooled pedestrians, and 2 pooled vehicles, with zero destroyed entities.

| Metric | iPhone 16 Pro | iPad Air 11-inch (M4) |
| --- | ---: | ---: |
| Max population-update p95 | 0.523 ms | 0.454 ms |
| Max spawn/reconcile hitch | 6.942 ms | 6.731 ms |
| Population callback p95 range | 16.807–16.965 ms | 16.825–17.310 ms |
| Profile CPU range | 35.27–41.93% | 34.22–38.64% |
| Sampled peak memory | 249.31 MiB | 295.80 MiB |
| Reactive callback p95 max | 18.379 ms | 18.024 ms |
| Reactive state-change cost max | 20.861 ms | 16.502 ms |
| Reactive steady decision sample, non-baseline max | 0.542 ms | 0.332 ms |

The baseline scenario's final sampled decision was 10.403 ms on iPhone and 9.074 ms on iPad. This isolated sample did not recur in the other scenarios, did not cause thermal escalation, and the reactive callback p95 remained below 18.4 ms. It should be watched if display presentation becomes more complex.

Fresh Game Performance traces were attached to the final reactive Startup presentation:

| Metric | iPhone 16 Pro | iPad Air 11-inch (M4) |
| --- | ---: | ---: |
| Retained trace span | 6.650 s | 7.533 s |
| Drawable-request rate | 59.851/s | 60.003/s |
| Top-level GPU work interval mean | 1.131 ms | 0.991 ms |
| Top-level GPU work interval p95 | 3.204 ms | 2.812 ms |
| Top-level GPU work interval maximum | 3.309 ms | 4.209 ms |

Top-level Metal work intervals may overlap and are not per-frame GPU time or utilization. Drawable requests are not proof of displayed FPS. The traces are bounded steady-state captures, not sustained traversal captures. Exact machine-readable evidence is in [physical-game-performance-summary.json](Phase14Evidence/physical-game-performance-summary.json), [iphone16pro-living-world-profile.json](Phase14Evidence/iphone16pro-living-world-profile.json), and [ipad-air-m4-living-world-profile.json](Phase14Evidence/ipad-air-m4-living-world-profile.json).

## Verification

- Focused `AtlantisRuntimeTests`: **46 passed, 0 failed, 0 skipped** on iPhone 17 Pro Max simulator, iOS 26.5.
- Complete `Solo Unicorn Run Tests` target: **830 passed, 0 failed, 0 skipped** on iPhone 17 Pro Max simulator, iOS 26.5.
- Reactive-scenario UI test: **1 passed** on iPhone 17 Pro Max simulator and **1 passed** on iPad Air 11-inch (M4) simulator.
- Full Atlantis UI run: founder load/walking, streaming, all canonical Phase 13 interactions, and reactive scenarios passed. Two menu-driven automation cases initially failed because Xcode 26 exposed SwiftUI menu items as `PopUpButton` rather than the queried `Button`. Direct DEBUG controls replaced those menu dependencies; the two corrected cases then passed **2/2**. No product assertion failed.
- Generic physical iOS Debug build: passed with the `Solo Unicorn Run` scheme.
- Generic physical iOS Release build: passed, verifying the Atlantis sources remain excluded by their DEBUG compile boundary.
- `git diff --check` and staged diff whitespace check: passed.

The final evidence is split between the full Atlantis run and the 2/2 corrected rerun. The direct-control change is confined to the DEBUG-only Atlantis validation surface.

## Changed files

- `App/AtlantisWorldPresentationModel.swift`: read-only snapshot, fixtures, district reactions, centralized LOD tuning, route corrections, deterministic presentation definitions.
- `App/AtlantisRealityScene.swift`: director, reusable displays, deterministic proximity encounters, pooled actor/vehicle orchestration, route motion, diagnostics, physical benchmark scenarios.
- `App/AtlantisRealityView.swift`: one snapshot bridge, scenario controls, diagnostics, Reduce Motion propagation, DEBUG validation controls.
- `Tests/AtlantisRuntimeTests.swift`: isolation, reaction, determinism, encounter, LOD, pool-bound, save-version, and walkable-route tests.
- `UITests/AtlantisRuntimeUITests.swift`: same-viewpoint scenarios plus population, interaction, and direct validation controls.
- `Documentation/Atlantis/PHASE14_LIVING_WORLD_LAYER_REPORT.md`: this report.
- `Documentation/Atlantis/Phase14Evidence/`: device JSON, final traces, metric summary, and scenario screenshots.

The Xcode project and shared scheme were not changed by Phase 14. Existing unrelated Founder Desk, shared-scheme, scratch, and workspace changes remain untouched.

## Git checkpoint

Branch: `atlantis-phase0-masterplan`, tracking `origin/atlantis-phase0-masterplan`.

The five Atlantis code/test files, this report, three compact metric JSON files, and eight scenario screenshots are staged. The unrelated `ContentView`, Founder Desk, shared scheme, Founder Desk tests, production-continuity UI tests, local tooling, scratch content, and older asset directories remain unstaged/untracked. Four raw Instruments trace directories and the older UI screenshot directory also remain local and unstaged because they are large binary evidence; the compact parsed summary is staged. No commit or push was made.

## Remaining acceptance and next phase

The visuals deliberately remain lightweight blockout presentation. Physical-screen visual review, continuous hands-on traversal, VoiceOver, largest Dynamic Type, and Reduce Motion perception remain human acceptance items. The fresh GPU traces cover a stable reactive scene, while sustained transition tracing remains an optimization follow-up rather than a release blocker for this DEBUG-only layer.

The next planned milestone is **Phase 15 — Founder Encounters & Named NPCs**. Phase 14 does not add branching dialogue, persistent NPC identity, schedules, relationships, or gameplay consequences.
