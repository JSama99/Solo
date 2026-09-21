# Founder Character Pass B — Animation Fidelity Report

## 1. Executive Result

`GO`

`HUMAN MOTION ACCEPTANCE: ACCEPTED`

The production Founder now has deterministic seated and standing micro-motion, bounded sit/stand body mechanics, cadence-matched gait presentation, blended starts/stops, and bounded turn anticipation. Engineering contracts, regression suites, signed builds, and physical production-route smokes pass. The reviewer explicitly accepted the complete unchanged production motion baseline on September 19, 2026.

The accepted Founder USDZ, face, skeleton, materials, seated fit, camera relationship, state topology, traversal architecture, `GameStore`, and save version were not changed.

## 2. Baseline Architecture

The retained graph is:

```text
SeatedIdle → StandingUp → WalkStart → Walking → WalkStop → StandingIdle
     ↑             │                                      │
     └── SittingDown ←────────────────────────────────────┘
                         StandingIdle → TurnInPlace
```

All nine canonical states remain: `seatedIdle`, `seatedTurn`, `standingUp`, `standingIdle`, `walkStart`, `walking`, `walkStop`, `turnInPlace`, and `sittingDown`.

- Gameplay clips before/after: 0 / 0.
- Blends: 0.16 s start, 0.24 s stop/general, 0.42 s sit/stand, 0.08 s Reduce Motion transition.
- Root-motion authority: disabled before and after.
- Spatial authority: `FounderGarageCameraController` before and after.
- Base poses: exact accepted A.2 seated pose and imported standing rest.
- New layer: deterministic additive local-joint presentation inside the existing `FounderAuthoredPoseRig`.

The baseline audit is in `PASS_B_ANIMATION_BASELINE.md`.

## 3. Seated Idle

Baseline issue: the promoted rig was perfectly static. The accepted solution applies two mixed breathing periods (4.8 s and 7.3 s) to spine/chest/clavicles plus an 11 s sparse gaze envelope to the head. Pelvis, hands, legs, and feet are not modified.

Measurements over 900 deterministic 60 Hz samples:

- head angular delta: greater than 0.002 rad and below 0.08 rad;
- pelvis local drift: at most 1 µm;
- each hand local drift: at most 1 µm;
- each foot local drift: at most 1 µm;
- seated anchor error: 0 m;
- all transforms finite.

This preserves desk interaction readiness and the accepted camera/eye relationship while removing robotic stillness. The reviewed amount is now part of the protected human motion baseline.

## 4. Standing Idle

Baseline issue: the imported rest pose was frozen. The accepted engineering solution adds low-amplitude chest breathing, a long-period torso posture change, and restrained head compensation without translating the pelvis or changing leg/foot joints.

Measurements over 720 deterministic 60 Hz samples:

- chest angular delta: greater than 0.003 rad and below 0.02 rad;
- pelvis and foot local drift: at most 1 µm;
- the 4.8 s sample and later mixed-period sample are not identical;
- all transforms finite.

This produces motion without repeated hip rocking or foot sliding. The reviewed stance personality is accepted.

## 5. Sit/Stand

The existing 0.42 s state transitions and graph were retained. A sinusoidal overlay adds forward spine preparation, chest counter-motion, small arm balance, and head stabilization. The overlay is exactly zero at both endpoints, so it cannot replace the accepted poses.

- standing rest convergence: translation within 1 µm and rotation within 0.0011 rad;
- seated pose convergence: translation within 1 µm and rotation within 0.0011 rad;
- seated anchor error: 0 m;
- camera state mutation: none;
- Reduce Motion: additive motion disabled and transition remains 0.08 s.

Intermediate trajectories are deterministic and sampled at start, 25%, 50%, 75%, and settle points. The reviewed transition weight and timing are accepted.

## 6. Locomotion

The promoted rig previously had zero visual stride while its camera-owned anchor moved at up to 1.22 m/s. Pass B adds presentation-only thigh swing, knee flexion, foot counter-rotation, arm counter-swing, chest counter-rotation, and an 11 mm maximum vertical gait offset.

- gait-cycle distance: 0.78 m;
- phase advance is derived from actual movement speed;
- per-frame animated phase travel/world horizontal displacement mismatch: at most 2% in the deterministic fixture;
- start blend weights increase monotonically over 0.16 s;
- stop blend weights decrease monotonically over 0.24 s;
- invalid transform count: 0;
- root motion remains disabled.

Turn-in-place preserves its graph state. The first measured large turn exposed a real 0.1975 rad first-frame snap. The correction caps stationary presentation yaw at 2.4 rad/s and moving yaw at 5 rad/s, with bounded torso/head anticipation below 0.10 rad. First-person head masking remains intact through the turn.

The numerical cadence contract substantially reduces the original skating condition. The reviewed visual grounding and stride character are accepted.

## 7. Gaze / Micro-Motion

A bounded presentation-only gaze was implemented. It uses a sparse, smooth 11 s envelope with maximum head yaw of 0.055 rad and a small downward pitch. Seated behavior favors the existing desk/monitor posture. It does not select AI targets, mutate simulation state, move the camera, or run under Reduce Motion. No full gaze system or fake typing loop was introduced.

Desk readiness is preserved by keeping both accepted seated hand transforms unchanged within 1 µm.

## 8. Selection Loops

No aesthetic variant set was presented. The implemented changes addressed objective defects—zero motion, zero stride, and a measured turn snap—using one restrained parameter set. The exact-equality test fixture was rejected after it treated a 0.0009766 rad quaternion representation difference as contact drift; it was replaced with physical translation/rotation tolerances without changing production motion.

A controlled start/stop round was requested during review, then explicitly stopped before variant evidence was generated. The reviewer subsequently accepted the unchanged baseline. No alternate parameter set was selected, and the accepted evidence was not regenerated.

## 9. Performance

| Metric | A.2 baseline | Pass B |
| --- | --- | --- |
| Gameplay animation resources | 0 | 0 |
| Founder USDZ bytes/hash | 2,657,535 / `6392eb1d…8171f5` | unchanged |
| Character package memory | accepted A.2 medians: 40.078 MiB iPhone, 46.188 MiB iPad | no new resource or duplicate instance |
| Joint-pose assignments | 550 base transforms/update already required by ten modular models | same 550 assignments plus bounded arithmetic on named joints |
| Assertion-heavy deterministic update fixture | not previously available | seated ≤0.57 ms/sample and standing ≤0.61 ms/sample using total XCTest duration as a conservative upper bound |
| Physical production route | accepted | passed on both devices without timeout or observed scene-update stall |

The timing upper bounds include asset setup and multiple XCTest assertions per frame, so they overstate production-only CPU cost. No promotion-specific memory resource, clip allocation, duplicate Founder, or material stall was introduced. The existing packaging experiment was not reopened.

## 10. Permanent Contracts

- `FounderMotionCaptureSample` records state, clip, state/sample time, root, required body joints, velocity, displacement, camera state, Founder position, Garage state, and frame index.
- Seated pelvis/hand/foot anchoring and bounded head motion.
- Standing pelvis/foot anchoring, bounded torso motion, and non-short-loop behavior.
- Exact seated and standing endpoint recovery under Reduce Motion.
- Camera and save authority isolation.
- Cadence/world-displacement agreement and monotonic start/stop blending.
- Finite transforms across sampled states.
- Bounded turn velocity, torso/head anticipation, and head masking.
- Existing 100-cycle seat/orientation drift, state topology, root authority, skeleton, morph, attachment, and asset identity tests remain active.

The machine-readable fixture and state/sample schedule are in `Evidence/B/pass_b_motion_contract.json`.

## 11. Regression Validation

| Gate | Result |
| --- | --- |
| Focused Founder/motion contracts | 12/12 passed |
| Founder/Garage/Atlantis subsystem | 194/194 passed |
| Complete unit target | 917/917 passed, 0 failed |
| Unit-count change | +5 meaningful motion contracts from the 912 Pass B baseline |
| Simulator production continuity | 1/1 passed |
| Physical iPhone 16 Pro production route | 1/1 passed after initial lock-screen retry |
| Physical iPad Air 11-inch (M4) production route | 1/1 passed after initial lock-screen retry |
| Debug signed build/install/launch | passed through physical UI runs on both devices |
| Release signed build | passed |
| Release install/launch | passed on both physical devices |
| Accepted asset SHA-256 | unchanged: `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |
| Save version | 20 |

The physical UI route verifies production loading, standing/start/walk behavior, first-person masking, locomotion, and Garage-to-Atlantis continuity. Human third-person motion acceptance was separately recorded from the review-board evidence on September 19, 2026.

## 12. Repository State

| Field | Value |
| --- | --- |
| Branch | `visual-fidelity-track` |
| HEAD | `efd67e77f99dacf9e86e9cc71469cff713ada395` |
| Save version | 20 |
| Working tree | Dirty before Pass B; unrelated and prior-pass changes preserved |
| Pass B implementation files | `App/FounderGarageRealityScene.swift`, `Tests/FounderCharacterContractTests.swift` |
| Pass B evidence files | baseline, evidence ledger, machine-readable motion contract, this report |
| Commit/push | none |
| Pass C | not started |

`git diff --check` is clean for all Pass B files. The repository-wide check continues to report only the seven pre-existing trailing-whitespace lines in `Tests/FounderDeskWorkspaceTests.swift`.
