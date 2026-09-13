# SOLO ATLANTIS — Phase 16 World Consequence Layer

## Verdict

**GO WITH HUMAN ACCEPTANCE**

Phase 16 adds a bounded, deterministic world-consequence projection beneath the existing living-world authority. Founder progress and public state now alter the Founder Garage frontage; Pallas's public claimed Momentum and public Coverage alter its campus. The same derived public snapshot also drives the Phase 14 district reaction and Phase 15 named-NPC eligibility. No city progression authority, save payload, or hidden rival value was added.

Automated tests and same-camera simulator captures pass. Physical visual quality, signage legibility, transition feel, and Reduce Motion perception still require human review on the connected devices.

## Architecture

- `AtlantisWorldSignalSnapshot` remains the single read-only boundary. It now includes the existing public facility tier alongside Trust, Momentum, Coverage, Venture progress, and public rival claimed Momentum.
- `AtlantisWorldConsequenceDirector` is owned by and subordinate to `AtlantisLivingWorldDirector`. It retains snapshots and presentation entities, never `GameStore`.
- `AtlantisWorldConsequencePolicy` derives one winning definition per site using fixed priority and explicit exclusive groups.
- `AtlantisWorldConsequenceDefinition` provides a nine-entry data registry with stable IDs, verified existing anchors, public-knowledge scopes, signage, activity modifiers, and bounded construction/event prop counts.
- Founder HQ supports baseline, growth, spotlight, and scrutiny.
- Pallas supports baseline, surge, and public event. Northwind and Flashpoint deliberately support baseline only in this slice.
- Each resident site uses one reusable RealityKit presentation root: one frontage base, one static sign, up to three construction props, up to five event props, and four occupied-zone strips. There are no collision shapes, dynamic lights, video surfaces, construction AI, or per-frame eligibility checks.
- Presentation roots attach to verified authored interaction anchors: `FounderGarageSlot`, `PallasAIHQ`, `NorthwindLabsHQ`, and `FlashpointHQ`.
- District unload detaches presentation roots. Reload locates the anchor and reconstructs the current derived state; entities are presentation memory only.
- The living-world reconciliation pass gives the consequence fixture's effective public snapshot to the Phase 14 reaction and Phase 15 encounter directors. A Pallas surge therefore produces the rival district reaction and Iris Vale eligibility from the same public input.
- Reduce Motion retains color, signage, occupancy, and prop distinctions. This layer introduces no decorative motion or independent transition loop.
- Seven DEBUG presentation fixtures provide deterministic validation without save mutation.

## Founder consequence matrix

| State | Eligibility | Physical changes | Presentation-only inputs |
| --- | --- | --- | --- |
| Baseline | Fallback | Gray modest frontage, baseline SOLO sign, two occupied strips | Explicit DEBUG fixture or current public snapshot |
| Growth | Existing facility tier is Loft or later, or public Momentum ≥ 70 | Mint frontage and sign, three expansion/delivery props, one event marker, four occupied strips | Existing facility tier/public Momentum; fixture can force the definition |
| Spotlight | Public Coverage ≥ 40 and Trust ≥ 35 | Cyan public-spolight sign, four event/media markers, four occupied strips | Public Coverage and Trust; fixture can force the definition |
| Scrutiny | Public Coverage ≤ -40 or Trust < 35 | Restrained orange public-update sign, one barrier, three press markers, minimum occupied presentation | Public Coverage and Trust; fixture can force the definition |

Priority is scrutiny (100), spotlight (80), growth (40), then baseline (10). Only one Founder HQ signage/event-zone definition can win.

## Rival consequence matrix

| Rival | Implemented state | Eligibility | Physical changes | Knowledge boundary |
| --- | --- | --- | --- | --- |
| Pallas AI | Baseline | Fallback | Gray campus frontage and normal sign | Public rival identity |
| Pallas AI | Surge | Public claimed Momentum ≥ 70 | Purple recruiting sign, two expansion props, two event markers, increased occupied strips | Claimed Momentum only |
| Pallas AI | Event | Public claimed Momentum ≥ 70 and public Coverage ≥ 40 | Pink public-launch sign, five media/event markers, increased occupied strips | Claimed Momentum and public Coverage only |
| Northwind Labs | Baseline | Fallback | Baseline campus sign/frontage | Public rival identity |
| Flashpoint | Baseline | Fallback | Baseline campus sign/frontage | Public rival identity |

Pallas priority is public event (90), surge (60), then baseline (10). Northwind and Flashpoint parity remains deferred.

## Public event matrix

| Event | District | Physical staging | Source signal | Duration/persistence |
| --- | --- | --- | --- | --- |
| Founder spotlight | Founder District | Public sign, media markers, occupied strips | Positive public Coverage with sufficient Trust | Derived while eligible; reconstructed on residency |
| Founder scrutiny | Founder District | Restrained sign, barrier, press markers | Negative public Coverage or low Trust | Derived while eligible; reconstructed on residency |
| Pallas public launch | Tech Core | Launch sign, five event/media markers, occupied strips | Public Coverage plus Pallas claimed Momentum | Derived while eligible; reconstructed on residency |

No canonical timers or event calendar were added.

## Canonical isolation

| Check | Result |
| --- | --- |
| GameStore direct mutations | None |
| New canonical progression values | None |
| New canonical city progression | None |
| Save migration | None |
| Save version | 19 |
| Atlantis compile boundary | DEBUG-only |
| Hidden-state exposures | None found; regression test changes actual/verified Pallas truth while keeping the public snapshot and derived presentation identical |
| RNG consumption | None |

## Runtime and bounds

| Measurement | Result |
| --- | --- |
| Active consequence entities | 15 per resident active site; structural maximum 60 across four sites |
| Maximum construction props | 3 per site definition |
| Maximum event props | 5 per site definition |
| Maximum active signage states | 1 per site; 4 across all resident sites |
| Reconciliation cadence | Snapshot, fixture, and residency reconciliation; no frame loop |
| Duplicate consequence violations | 0 in unit and UI reconstruction checks |
| Exclusive-group conflicts | 0 in all fixtures and both UI device classes |
| Consequence reconciliation cost | Exposed in DEBUG diagnostics; aggregate physical profile not captured |
| State-change hitch | Not captured |
| Memory delta | Not captured |
| Drawable-request cadence | Not captured |
| CPU impact | Not captured |
| Thermal result | Not captured |

The implementation allocates bounded roots lazily and reuses them across state changes and district reloads. It does not increase Phase 14 pedestrian or vehicle budgets; the shared-state test verifies population remains within the existing pedestrian budget during a Pallas surge.

## Verification

All commands ran against the final Phase 16 source state unless stated otherwise.

| Check | Passed | Failed | Skipped | Evidence |
| --- | ---: | ---: | ---: | --- |
| Focused `AtlantisRuntimeTests` | 59 | 0 | 0 | `Test-Solo Unicorn Run-2026.09.12_21-20-00--0400.xcresult`; 38.101 seconds test time |
| Complete unit target | 843 | 0 | 0 | `Test-Solo Unicorn Run-2026.09.12_21-21-35--0400.xcresult`; 52.877 seconds test time |
| Phase 16 UI tests, iPhone 17 Pro Max simulator | 2 | 0 | 0 | `Test-Solo Unicorn Run-2026.09.12_21-23-06--0400.xcresult`; 42.224 seconds |
| Phase 16 UI tests, iPad Air 11-inch (M4) simulator | 2 | 0 | 0 | `Test-Solo Unicorn Run-2026.09.12_21-24-24--0400.xcresult`; 41.151 seconds combined test time |
| Generic Release simulator build | 1 | 0 | 0 | `BUILD SUCCEEDED` |
| Signed generic iOS device build | 1 | 0 | 0 | `BUILD SUCCEEDED` |
| Physical iPhone 16 Pro install/flagged launch/process alive | 1 | 0 | 0 | Connected `iPhone17,1`; final-build process PID 6454 |
| Physical iPad Air 11-inch (M4) install/flagged launch/process alive | 1 | 0 | 0 | Connected `iPad16,8`; final-build process PID 1578 |

The focused suite covers derived state, all nine registry definitions, verified anchor names, deterministic priority, exclusive-group conflicts, hidden-truth isolation, save/RNG isolation, district reconstruction, Phase 14 population bounds, the Phase 14 rival reaction, and Phase 15 Iris Vale eligibility. Existing focused Atlantis interaction tests also passed, including canonical round-trip restoration and unload/reload registration.

The two UI scenarios exercise seven same-camera states per simulator class and assert zero exclusive-group conflicts. The Pallas scenario unloads Tech Core, verifies physical staging leaves while the derived state remains reproducible, reloads it, and verifies the event root returns once without duplicates.

Physical automation was limited to signed build installation, flagged launch, and process-alive verification. Physical interaction, visual, memory, CPU, hitch, and thermal measurements were not captured.

## Visual evidence

Same-camera engineering captures are stored under:

- `Documentation/Atlantis/Phase16Evidence/world-consequences/iphone-17-pro-max/`
- `Documentation/Atlantis/Phase16Evidence/world-consequences/ipad-air-11-m4/`

Each directory contains Founder baseline/growth/spotlight/scrutiny and Pallas baseline/surge/event. The captures show the world geometry changing in addition to the DEBUG diagnostic state. The validation controls occupy a substantial part of the capture and are not production UI.

## Human acceptance still required

- Judge whether Founder growth reads as meaningful at normal physical viewing distance.
- Judge whether Pallas surge and event make the campus feel more active and competitive.
- Confirm construction staging reads clearly rather than as generic props.
- Confirm signs remain legible and correctly oriented from normal approaches.
- Compare every state without relying on the DEBUG HUD.
- Review swaps during traversal for natural timing and visible geometry popping.
- Confirm visual density remains tasteful.
- Confirm VoiceOver phrasing communicates the equivalent public meaning.
- Confirm Reduce Motion remains calm while every state stays distinguishable.
- Observe physical-device thermal behavior and state-change smoothness during a longer traversal.

## Git state

Branch: `atlantis-phase0-masterplan` tracking `origin/atlantis-phase0-masterplan`.

```text
## atlantis-phase0-masterplan...origin/atlantis-phase0-masterplan
MM App/AtlantisRealityScene.swift
MM App/AtlantisRealityView.swift
MM App/AtlantisWorldPresentationModel.swift
 M App/ContentView.swift
 M App/FounderDeskWorkspace.swift
 M App/FounderDeskWorkspaceModel.swift
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
?? Documentation/Atlantis/Phase14Evidence/ipad-air-m4-game-performance.trace/
?? Documentation/Atlantis/Phase14Evidence/ipad-air-m4-reactive-final.trace/
?? Documentation/Atlantis/Phase14Evidence/iphone16pro-game-performance.trace/
?? Documentation/Atlantis/Phase14Evidence/iphone16pro-reactive-final.trace/
?? Documentation/Atlantis/Phase14Evidence/ui-screenshots/
?? Documentation/Atlantis/Phase16Evidence/
?? Solo/
?? skills-lock.json
?? skills/
```

Phase 14 remains staged in the three shared Atlantis source/test files, its report, profile JSON, and eight reactive-scenario PNGs. Phase 15 and Phase 16 remain unstaged in those shared files. Phase 16 adds:

- `App/AtlantisWorldPresentationModel.swift`
- `App/AtlantisRealityScene.swift`
- `App/AtlantisRealityView.swift`
- `Tests/AtlantisRuntimeTests.swift`
- `UITests/AtlantisRuntimeUITests.swift`
- `Documentation/Atlantis/PHASE16_WORLD_CONSEQUENCE_LAYER_REPORT.md`
- `Documentation/Atlantis/Phase16Evidence/`

Pre-existing unrelated unstaged changes remain in `ContentView.swift`, Founder Desk files/tests, the shared scheme, and `Build32_6_1ProductionContinuityUITests.swift`. Existing untracked Atlantis assets, raw traces, support/scratch files, and the Phase 15 report remain untouched. Nothing was staged, committed, pushed, reset, cleaned, or discarded during Phase 16.

## Next phase boundary

Phase 17 may add the Founder Strategy Board and a plan → prepare → execute → consequence loop. It is outside this implementation.
