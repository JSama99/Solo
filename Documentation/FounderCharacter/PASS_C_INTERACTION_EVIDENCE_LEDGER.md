# Pass C Interaction Evidence Ledger

Date: `2026-09-19`

## C0 — Architecture audit

| Evidence | Result |
| --- | --- |
| Architecture audit | `PASS_C0_INTERACTION_ARCHITECTURE_AUDIT.md` |
| Production seam | `FacilityTier0InteractionZone` / `FacilityTier0InteractionSpace` |
| Runtime motion owner | `FounderLocomotionController` with accepted nine-state graph |
| Deferred authoring | iPhone, iPad, Signal TV, Funding/Strategy Board |

## C1 — Interaction target contract

| Evidence | Result |
| --- | --- |
| Production source | `App/FounderGarageRealityScene.swift` |
| Focused tests | `Tests/FounderGarageRealityTests.swift` |
| Contract targets | Chair, Founder Computer, Whiteboard only |
| Stable IDs | `facilityTier0.chair`, `facilityTier0.founderComputer`, `facilityTier0.whiteboard` |
| Standing approach | `[-0.301470, 0, 0.290800]`, derived `0.82 m` behind accepted seat along inverse seat facing |
| Accepted seat endpoint | `[0.34, 0, -0.22]`, unchanged |
| Monitor gaze | `[1.42, 1.30, -1.08]`, authored `Anchor_Monitor_Face` |
| Whiteboard gaze | `[-2.42, 1.52, -0.40]`, authored `Anchor_Whiteboard_Face` |
| Hand metadata | Deliberately `nil` for all C1 targets |
| Save boundary | `GameStore.saveVersion == 20` |
| Motion boundary | Nine accepted `FounderLocomotionState` cases unchanged |
| Focused test device | iPhone 17 Pro Max, iOS 26.5 |
| Focused test result | 6 executed, 0 failures |
| Result bundle | `/tmp/solo-pass-c1-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.19_13-33-36--0400.xcresult` |
| Broader relevant regression | 139 executed (127 Garage + 12 Founder contract/motion), 0 failures |
| Broader result bundle | `/tmp/solo-pass-c1-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.19_13-35-40--0400.xcresult` |
| iPhone scheme build | iPhone 17 Pro Max, iOS 26.5 — succeeded |
| iPad scheme build | iPad Air 11-inch (M4), iOS 26.5 — succeeded |
| Founder asset ratchet | SHA-256 unchanged: `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |

## C1 classification

`PASS — CONTRACT IMPLEMENTED; RUNTIME INTERACTION DEFERRED`

Pass C1 is deterministic presentation data only. It does not prove visual motion, contact quality, animation quality, camera choreography, audio, or haptics.

## Open evidence

- Human simulator acceptance is deferred until a later pass implements runtime interaction behavior.
- C1 does not require an iPad-specific behavioral test because its immutable world-space contract is device-independent; the required iPad scheme build passed.

## C2 — Chair end-to-end interaction pipeline

| Evidence | Result |
| --- | --- |
| Production source | `App/FounderGarageRealityScene.swift`, `App/FounderGarageRealityView.swift` |
| Coordinator | Session-only `FounderInteractionCoordinator`; nine stable phases |
| Chair contract | `facilityTier0.chair`; C1 approach, seat, and tolerances unchanged |
| Spatial authority | `FounderGarageCameraController` |
| Motion authority | `FounderLocomotionController`; nine-state topology unchanged |
| Sit/stand timing | Sit `0.42 s`; Stand Variant B `0.68 s`; Reduce Motion `0.08 s` |
| Focused scenarios | GI-01, GI-02, GI-03, GI-04, GI-11, GI-12 |
| Focused result | 6 executed, 0 failures |
| Focused result bundle | `/tmp/solo-c2-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.19_14-04-21--0400.xcresult` |
| Repetition | 50 complete cycles; zero position drift, yaw drift, endpoint error, or invalid transforms |
| Broader relevant regression | 207 Founder/Garage/Atlantis tests executed, 0 failures |
| Broader result bundle | `/tmp/solo-c2-third-person-broad3.xcresult` |
| Deterministic signature | `chair|d=0.0000|p=0.0000|y=0.0000|v=0.0000|at=0.0000|ar=0.0000|sit=0.1000|seat=0.0000|stand=0.1000|standing=0.0000|depart=0.2500|recover=0.0000|drift=0.0000,0.0000|invalid=0|cycles=50` |
| iPhone scheme build | iPhone 17 Pro Max, iOS 26.5 — succeeded |
| iPad scheme build | iPad Air 11-inch (M4), iOS 26.5 — succeeded |
| Save boundary | `GameStore.saveVersion == 20` |
| Founder asset ratchet | SHA-256 unchanged: `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |
| Full report | `FOUNDER_CHARACTER_PASS_C2_CHAIR_INTERACTION_FIDELITY_REPORT.md` |

## C2 classification

`GO WITH HUMAN ACCEPTANCE`

Mechanical and deterministic gates pass. Human simulator acceptance remains required for body/chair contact, foot planting, perceived weight, transition feel, and camera comfort. C3 has not started.

## C2 human review — objective correction attempt 1

| Area | Baseline | Defect/Divergence | Classification | Hypothesis | Responsible Layer | Change | Measurement/Result | Runtime Result | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Founder visibility | `founderPOV` supplied first-person presentation and hid the rig | Human reviewer saw only the Computer and Funding Board; the Founder was absent | Objective interaction-review blocker | Visibility was keyed to camera-state identity instead of actual perspective | Camera presentation and locomotion visibility input | Every Founder view now uses a close third-person composition, including seated computer use and Recenter | GI-05 and the 207-test regression gate pass | Founder visibly present seated and standing on both required devices | Original baseline rejected; corrected baseline awaiting human re-review |
| Stand timing | Stand shared the `0.42 s` Sit duration | Human reviewer reported that the Founder stood too quickly | Interaction fidelity defect | Stand needed an isolated longer timing without changing Sit | Locomotion timing | Selected Variant B: Stand `0.68 s`; Sit `0.42 s`; Reduce Motion `0.08 s` | Normal and Reduce Motion GI-03 tests pass | Longer visible weight-transfer window | Corrected; human re-review pending |
| Garage-to-Atlantis continuity | Player coordinates crossed worlds but presentation ownership did not | Exterior switched to first-person and a Founder remained visible in the Garage | Objective scene-continuity blocker | The visible rig was not transferred with the player | Garage/Atlantis presentation composition | Transfer and restore the same rig/controller; only the owning world updates it; all Founder routes remain third-person | Handoff/restore test plus phone and iPad production traversal UI tests pass | One visible Founder outside on both devices | Corrected; human re-review pending |

Correction verification:

- Founder/Garage/Atlantis regression gate: `207/207 passed`.
- iPhone 17 Pro Max production UI flows: `2/2 passed`; captures at `/tmp/iphone-founder-pov-initial.png` and `/tmp/iphone-garage-to-atlantis.png`.
- iPad Air 11-inch (M4) production UI flows: `2/2 passed`; captures at `/tmp/ipad-founder-pov-initial.png` and `/tmp/ipad-garage-to-atlantis.png`.
- C3 remains blocked pending human acceptance of the corrected interaction.

No chair contract, interaction phase topology, root-motion authority, asset, save, or simulation value changed. Stand timing alone changed from `0.42 s` to the selected `0.68 s` Variant B; Sit and Reduce Motion timing are unchanged.
