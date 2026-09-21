# Founder Character Pass C2 — Chair Interaction Fidelity Report

Date: `2026-09-19`

## 1. Executive result

**Engineering classification: `GO WITH HUMAN ACCEPTANCE`.**

The production Garage now runs one deterministic chair interaction pipeline:

`Standing → Approach → Stop → Align → Sit → Seated Hold → Stand → Depart`

All automated C2 scenarios pass, the broader Founder/Garage regression set passes, the Founder asset hash is unchanged, and no save, simulation, entitlement, target-membership, or project-file change was required. Human simulator acceptance remains required for body/chair contact, foot planting, perceived weight, and camera comfort; automated results do not certify those qualities.

## 2. Coordinator architecture

`FounderInteractionCoordinator` is a session-only `@Observable` sequencer owned by `FounderGarageRealityWorld`. Its stable phases are:

`idle`, `approaching`, `stopping`, `aligning`, `sitting`, `seated`, `standing`, `departing`, `recovering`.

The coordinator consumes the immutable C1 Chair contract and advances around the existing camera and locomotion controllers. `FounderGarageRealityWorld.advanceSession(deltaTime:)` performs the order: coordinator prepare, camera advance, traversal diagnostics, locomotion update, coordinator completion. The legacy `pass6Prototype` specification has no C1 Chair contract, so it receives a dormant coordinator with a `nil` target rather than synthesized geometry.

## 3. Ownership model

- `FounderGarageCameraController` remains the canonical player position, heading, velocity, stance, and navigation-mode authority.
- `FounderLocomotionController` remains the presentation/motion authority. Its accepted nine-state topology is unchanged.
- `FounderInteractionCoordinator` sequences intent and validates phase boundaries only. It does not mutate `GameStore`, save data, or simulation truth.
- SwiftUI exposes `RETURN TO DESK`, `EXPLORE`, and in-progress phase labels; it is not a movement or simulation authority.

No root-motion authority was added. The standing visual endpoint follows the camera-owned spatial endpoint during the accepted stand transition.

## 4. Approach behavior

The Chair contract is unchanged:

- ID: `facilityTier0.chair`
- Approach: `[-0.301470, 0, 0.290800]`
- Seated endpoint: `[0.34, 0, -0.22]`
- Position tolerance: `0.08 m`
- Facing tolerance: `0.14 rad`

Approach begins only from `idle` while the Founder is already in walking navigation. It feeds a local directional intent into the existing acceleration/collision path. It does not teleport to the approach point. A deterministic braking-distance test requests stop before the endpoint; a bounded 12-second guard recovers if progress cannot complete.

## 5. Stop/alignment behavior

Stop waits for planar speed at or below `0.01 m/s`. If the stopped position is not within the contract tolerance plus a small `0.025 m` acquisition margin, approach resumes through normal walking.

Alignment is a camera-owned bounded correction:

- Maximum translation: `0.42 m/s`
- Maximum rotation: `2.4 rad/s`
- Final measured gate: `0.0025 m` and `0.0025 rad`
- Vertical translation: none
- Walkability: revalidated for every translation step

Sit cannot begin until the endpoint gate is satisfied and locomotion has reached `standingIdle`.

## 6. Sit behavior

After alignment, the coordinator requests the existing seated endpoint and waits for `FounderLocomotionController` to reach `seatedIdle`. No new sit animation or IK system was introduced. Sit remains `0.42 s`; Reduce Motion remains `0.08 s`. Seat endpoint error is sampled only when the seated boundary is reached. The camera stays in a third-person observation composition, including while the Founder is seated at the computer.

## 7. Seated hold

The `seated` phase is stable and unbounded: no timer automatically ejects the Founder. The camera remains in canonical seated navigation, locomotion remains `seatedIdle`, and an explicit `EXPLORE` request starts standing. A cancellation from seated uses the same safe stand boundary before control is released.

## 8. Stand/depart behavior

Standing installs the exact C1 authored approach pose through `FounderGarageCameraController.beginInteractionStanding`. The visual root interpolates from the seated endpoint to that camera-owned standing endpoint for the human-selected Variant B duration of `0.68 s`; Sit remains `0.42 s` and Reduce Motion remains `0.08 s`. The coordinator waits for `standingIdle`, verifies standing endpoint error, then holds `departing` for the existing `0.24 s` transition blend before restoring free walking.

No hidden post-cycle snap, new clip, root-motion path, or alternate camera choreography was added.

## 9. Interruption policy

| Phase | Policy |
| --- | --- |
| `approaching`, `stopping`, `aligning` | Clear movement intent immediately, enter `recovering`, and release only after the existing locomotion graph reaches stable standing idle. |
| `sitting` | Defer cancellation to the seated safe boundary, then perform the accepted stand transition and recover. |
| `seated` | Start the accepted stand transition immediately, then recover at stable standing idle. |
| `standing` | Finish the stand safe boundary, then recover instead of departing. |
| `departing` | Enter recovery immediately; no seated transition is replayed. |
| `idle`, `recovering` | Cancellation is an idempotent no-op. |

GI-11 verifies immediate approach recovery. GI-12 verifies the seated safe-boundary policy.

## 10. Deterministic signatures

The diagnostic signature is ordered and fixed:

`chair|d|p|y|v|at|ar|sit|seat|stand|standing|depart|recover|drift(position,yaw)|invalid|cycles`

It records `approachDistance`, `approachPositionError`, `approachYawError`, `stopVelocity`, `alignmentTranslation`, `alignmentRotation`, `sitDuration`, `seatEndpointError`, `standDuration`, `standingEndpointError`, `departTransitionTime`, `interruptRecoveryTime`, `cyclePositionDrift`, `cycleYawDrift`, `invalidTransformCount`, and `completedCycleCount`, formatted to four decimal places. GI-02 ratchets this exact 50-cycle Reduce Motion signature:

`chair|d=0.0000|p=0.0000|y=0.0000|v=0.0000|at=0.0000|ar=0.0000|sit=0.1000|seat=0.0000|stand=0.1000|standing=0.0000|depart=0.2500|recover=0.0000|drift=0.0000,0.0000|invalid=0|cycles=50`

## 11. Drift/repetition results

GI-02 executes 50 complete Reduce Motion cycles from the exact authored approach endpoint. Results:

- Completed cycles: `50`
- Invalid transforms: `0`
- Seat endpoint error: `0.0000 m`
- Standing endpoint error: `0.0000 m`
- Cycle position drift: `0.0000 m`
- Cycle yaw drift: `0.0000 rad`

Fifty cycles satisfy the required repetition minimum. The loop is deterministic and does not accumulate positional or angular drift.

## 12. Runtime impact

The pass adds one small session coordinator and constant-time planar vector/yaw calculations per active frame. It adds no assets, animation clips, IK solvers, persistence writes, simulation mutations, timers, or per-frame collections. GI-02's 50-cycle automated fixture completed in approximately `0.124 s` in the focused run. This is test-runtime evidence, not an Instruments performance certification.

## 13. Pass B regression results

- Focused C2 scenarios GI-01, GI-02, GI-03, GI-04, GI-11, GI-12: `6 executed, 0 failures`.
- Focused result bundle: `/tmp/solo-c2-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.19_14-04-21--0400.xcresult`.
- Final broader Founder/Garage/Atlantis set: `207 executed, 0 failures`.
- Final broader result bundle: `/tmp/solo-c2-third-person-broad3.xcresult`.
- Accepted locomotion topology: `9` states, unchanged.
- Save version: `20`, unchanged.
- Founder asset SHA-256: `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`, unchanged.
- iPhone 17 Pro Max, iOS 26.5 scheme build: succeeded (`/tmp/solo-c2-human-phone`).
- iPad Air 11-inch (M4), iOS 26.5 scheme build: succeeded (`/tmp/solo-c2-human-ipad`).

One existing Swift concurrency warning remains in `FounderGarageRealityTests.swift` at the `GameStore.saveVersion` XCTest autoclosure; it is a warning under the current language mode and did not fail the gate.

## 14. Human acceptance state

**Re-review pending after objective correction attempts.** The first human review was rejected because the production route showed only the Founder Computer and Funding Board; no Founder was visible. A later review found that Stand completed too quickly and that walking through the Garage exit switched to first-person while a second Founder remained visible in the Garage.

The bounded correction keeps camera ownership unchanged and makes every Founder route third-person: seated computer use, focus/recenter, Explore, chair interaction, and Atlantis traversal. The Garage transfers the same presentation rig and locomotion controller into the already-composed Atlantis world, suspends the Garage-side update while Atlantis owns them, and restores that same rig on return. No duplicate Founder remains behind. Stand uses the selected `0.68 s` Variant B timing, while Sit remains `0.42 s`.

Final corrected verification completed with `207/207` relevant unit tests passing and two production UI flows passing on each required device class. Visual captures show the Founder behind the desk and the same third-person Founder outside in Atlantis:

- iPhone 17 Pro Max: `/tmp/iphone-founder-pov-initial.png`, `/tmp/iphone-garage-to-atlantis.png`
- iPad Air 11-inch (M4): `/tmp/ipad-founder-pov-initial.png`, `/tmp/ipad-garage-to-atlantis.png`
- UI result bundles: `/tmp/solo-c2-third-person-ui-iphone2.xcresult`, `/tmp/solo-c2-third-person-ui-ipad.xcresult`

Required re-review checks on both form factors:

1. Approach reads as forward travel through the same Garage scene, not a scene swap or sideways slide.
2. Braking and final alignment are visible but not robotic or snap-like.
3. Pelvis/chair contact, feet, knees, and torso do not visibly intersect or float.
4. Stand has credible weight transfer and lands on the authored approach point.
5. Camera height/orientation and Reduce Motion are comfortable.
6. Cancelling during approach and seated hold produces understandable recovery.

Automated tests cannot certify these visual and perceptual outcomes.

## 15. Evidence ledger

| Area | Baseline | Defect/Divergence | Classification | Hypothesis | Responsible Layer | Change | Measurement/Result | Runtime Result | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pipeline | C1 targets only; no runtime chair choreography | Chair interaction was not end-to-end | Missing behavior | Existing camera and locomotion authorities can be sequenced without new authority | Interaction coordinator | Added nine-phase session-only coordinator | GI-01 passed full phase chain | One continuous production Garage world | Accept |
| Approach | Existing bounded walking | Chair return previously jumped directly to seated state | Fidelity defect | Feed the authored approach into normal walking and braking | Camera + coordinator | Intent-driven approach with braking-distance stop | Position/yaw inside C1 tolerances; stop `≤ 0.01 m/s` | No endpoint teleport during approach | Accept, human feel pending |
| Alignment | C1 tolerance only | No final bounded correction | Missing behavior | Small camera-owned planar/yaw corrections can close residual error | Camera | Added bounded `alignStandingPlayer` API | Final gate `≤ 0.0025 m/rad` | Walkability remains authoritative | Accept |
| Transition | Sit `0.42 s`; original Stand `0.42 s`; Reduce Motion `0.08 s` | Human review found Stand too quick | Interaction fidelity defect | Isolate Stand timing without changing Sit or Reduce Motion | Locomotion + coordinator | Stand Variant B `0.68 s`; Sit `0.42 s`; Reduce Motion `0.08 s` | GI-03 timing tests pass | No new clips or root authority | Accept correction; human feel pending |
| Diagnostics attempt 1 | Metrics intended to describe approach boundary | Approach error continued sampling after sit and reported the seat-to-approach distance | Evidence instrumentation defect | Freeze approach measures when approach/alignment ends | Coordinator diagnostics | Limited sampling to approach/stop/align phases | All six focused scenarios passed after correction | Production choreography unchanged | Reject first sample; accept corrected evidence |
| Legacy prototype regression | `pass6Prototype` intentionally has no C1 target space | Initial required-target initialization trapped legacy world construction | Compatibility defect | Coordinator must be dormant when no authored target exists | World/coordinator composition | Made the chair target optional; did not synthesize fallback geometry | 145-test broader gate passed | Legacy/debug surface remains constructible | Accept correction |
| Repetition | C1 endpoint contracts | Potential accumulated seat/stand drift | Risk | Exact camera endpoints plus bounded presentation interpolation should close every cycle | Camera + locomotion | GI-02 repeated 50 full cycles | Zero endpoint error, drift, and invalid transforms | Stable deterministic loop | Accept |
| Interruptions | No C2 policy | Mid-transition cancellation could strand an invalid pose | Risk | Immediate recovery is safe before sit; sit/stand require safe boundaries | Coordinator | Phase-specific cancellation policy | GI-11 and GI-12 passed | Stable standing release | Accept |
| Human review attempt 1 | First-person `Founder View` hid the character rig | Reviewer saw only the Founder Computer and Funding Board; no Founder | Objective visibility defect | Camera-state name was incorrectly used as the visibility authority | Camera presentation + locomotion visibility input | Added camera-owned observation composition for Explore/chair interaction; actual perspective now controls rig visibility | GI-05 plus GI-01 and the 50-cycle ratchet pass | Founder visibly present standing and seated on iPhone and iPad | Reject original baseline; corrected baseline requires human re-review |
| Human review traversal correction | Garage exit previously changed presentation ownership and left a Garage Founder visible | Exterior became first-person while a duplicate Founder remained behind | Objective continuity defect | Traversal was transferring player position but not the single visible presentation rig | Garage/Atlantis presentation composition | Transfer the same rig and locomotion controller to Atlantis and restore them on return; all Founder camera recipes remain third-person | Atlantis handoff/restore test and 207-test gate pass | Phone and iPad captures show one visible third-person Founder outside | Accept objective correction; human re-review pending |

## 16. Repository state

C2 modifies:

- `App/FounderGarageRealityScene.swift`
- `App/FounderGarageRealityView.swift`
- `App/AtlantisRealityScene.swift`
- `Tests/FounderGarageRealityTests.swift`
- `Tests/FounderCharacterContractTests.swift`
- `Documentation/FounderCharacter/FOUNDER_CHARACTER_PASS_C2_CHAIR_INTERACTION_FIDELITY_REPORT.md`
- `Documentation/FounderCharacter/PASS_C_INTERACTION_EVIDENCE_LEDGER.md`

The worktree was already dirty with unrelated visual-fidelity work, including existing project and shared-scheme changes. C2 did not edit `SoloUnicornRun.xcodeproj/project.pbxproj`, the shared scheme, `GameStore`, save migrations, or the Founder USDZ. Repository-wide `git diff --check` is blocked by pre-existing trailing whitespace in `Tests/FounderDeskWorkspaceTests.swift`; the C2 files have no whitespace errors.

## 17. Recommended C3 boundary

Do not start C3 until the corrected all-third-person chair/traversal loop receives human acceptance on iPhone and iPad. After acceptance, constrain C3 to the Founder Computer interaction using the same coordinator/contract seam. Preserve camera and locomotion ownership, avoid hand/IK authoring until a validated target exists, and do not broaden the pass into simulation state, save data, or another scene transition.
