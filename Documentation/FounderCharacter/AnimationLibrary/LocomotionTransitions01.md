# Founder locomotion transitions 01 — owner review

**Walking target:** Founder Natural Walk Candidate 02 — OWNER MOTION ACCEPTED, 2026-09-28.
**New transition set:** pending four separate owner motion decisions.

## Review

Open [the synchronized review page](OriginalFounder/Transitions01/index.html).
It contains seven sequences, each with side/front/three-quarter MP4s, normal-speed playback,
slow motion, frame stepping, and matched key stills. On narrow screens, use the View selector.
The full reel plays each chain once; only the standalone idle is intended to loop.

| Sequence | Duration | Authored segment within preview |
| --- | --- | --- |
| Standing idle | 4.0 s | frames 1–120; duplicate seam key 121 |
| Idle → start → Candidate 02 | 3.8 s | start 19–54; walking begins 55 |
| Candidate 02 → stop → idle | 4.0 s | stop 61–96; idle begins 97 |
| Idle → left turn → idle | 3.0 s | turn 16–69; idle begins 70 |
| Idle → right turn → idle | 3.0 s | turn 16–69; idle begins 70 |
| Left turn → start → Candidate 02 | 5.5 s | turn 16–69; start 70–105; walk 106 |
| Right turn → start → Candidate 02 | 5.5 s | turn 16–69; start 70–105; walk 106 |

The render manifest maps all 21 MP4s and 81 PNGs to their exact frames. Key stills include
anticipation, first contact, walking/heading handoff, and final settle where applicable.
A transition into walking has no final standing settle; its accepted walking pose is shown instead.

## Source and clip contract

Source: `OriginalFounder/Transitions01/Founder_LocomotionTransitions_01.blend`
SHA-256: `b8b85937502fdf475d56bb4db6e0c2106cae003e478e5e3c347f1820fc0579c8`.
All five retained Actions share this source. Blender 5.2.1 LTS through Higgsfield use Blender MCP 0.2.2.
Original textured Founder, unchanged visible topology, 55-bone study skeleton.
All clips: 30 FPS, Root translation **0 m**, Root rotation **0 rad**.
Frame ranges include the endpoint used to phase-match the next segment; previews omit duplicate endpoints.

| Action | Keys | Duration | Contact intervals (inclusive) | Loop |
| --- | --- | --- | --- | --- |
| `STUDY_Founder_StandingIdle_01` | 1–121 | 4.00 s | {'L': [[1, 121]], 'R': [[1, 121]]} | Yes, 121 = 1 |
| `STUDY_Founder_WalkStart_01` | 1–37 | 1.20 s | {'L': [[1, 13], [37, 37]], 'R': [[1, 37]]} | No |
| `STUDY_Founder_WalkStop_01` | 1–37 | 1.20 s | {'L': [[1, 37]], 'R': [[1, 4], [22, 37]]} | No |
| `STUDY_Founder_TurnInPlace_01_Left` | 1–55 | 1.80 s | {'L': [[1, 8], [25, 55]], 'R': [[1, 28], [45, 55]]} | No |
| `STUDY_Founder_TurnInPlace_01_Right` | 1–55 | 1.80 s | {'R': [[1, 8], [25, 55]], 'L': [[1, 28], [45, 55]]} | No |

Standing idle has restrained breathing, slight weight bias, shoulder asymmetry, relaxed elbows
and head/neck micro-motion. The feet remain planted. Start uses right support, left release,
a first stride and exact convergence to Candidate 02. Stop enters on left contact, brings the
right foot into a shortened final step, then settles. Turns place the leading foot first and
trailing foot second; pelvis leads, torso/shoulders follow, and the head adds small anticipation.

## Phase matching

| Boundary | Entry / exit | Walk phase | Support | Measured transform delta |
| --- | --- | --- | --- | --- |
| Idle → start | idle 1 / start 1 | none | both → right | 0 |
| Start → walk | start 37 / walk 1 | left contact, frame 1 | right → left | 0 |
| Walk → stop | walk 1 / stop 1 | left contact, frame 1 | left | 0 |
| Stop → idle | stop 37 / idle 1 | none | both | 0 |
| Left turn → idle/start | turn 55 / next 1 | none | both | <0.00018 mm joint-position error |
| Right turn → idle/start | turn 55 / next 1 | none | both | <0.00018 mm joint-position error |

`audit.json` reports pelvis position/orientation, torso rotation, shoulders, arms, feet and head
separately. Start/stop boundary poses have zero measured differences in each category.
Turn-to-idle comparison accounts for the external ±90° heading handoff; rotation deltas are zero.
The final-frame leg-rotation change is approximately 0.003° after the correction below.
Pose equality alone is not proof of natural pacing or matching velocity.

## Contacts, seams and retained correction

- No evaluated transition mesh vertex penetrated the ground; minimum was approximately **0.105 mm** above it.
- Whole-sole contact motion: idle <0.001 mm; start support foot **0.189 mm**;
  stop support foot **0.385 mm**; turns <0.002 mm. Rolling a shoe changes its sole centroid slightly;
  these are conservative centroid-motion measures, not a claim that every heel/toe point is fixed.
- `contact_action_audit.json` contains every-frame heel/toe heights and centers, including lift/replant.
- Idle mesh loop-seam difference: **0.00072 mm**. Left/right heading-handoff differences:
  **0.00075 / 0.00084 mm**. Root translation and rotation remain zero in saved Actions.
- Saved Action playback agrees with baked render poses within **0.0041 mm** at the joints;
  that small difference comes from unkeyed floating-point translation residue outside Hips.
- **REJECTED:** initial turn solver held leg roll in the original heading, causing an approximately
  90° local-axis correction at the final frame. `Rejected/TurnLegOrientation_00.blend` preserves it.
- **INTERNALLY RETAINED:** heading-aware leg orientation. Foot paths, timing, upper-body timing,
  accepted walk and cameras were held fixed. Final step falls to ~0.003° and the mesh handoff passes.
  This is a concrete rig-orientation repair, not owner acceptance of turn naturalness.

## Review fixture and immutable baseline

The saved source has no animated object/world translation. Render-only fixtures demonstrate
simulation-owned displacement and the post-turn heading transfer, then disappear with the MCP session.
The start fixture covers **0.315 m**, smoothly reaching 1.4 m/s; the stop covers **0.385 m**,
smoothly leaving 1.4 m/s. These are study envelopes, not a gameplay-speed or runtime-controller change.
Continuous walking remains 1.00 s, 30 frames, left/right contacts 1/16 and 1.40 m per cycle.
The current vertical excursion and complete accepted walking Action are unchanged.
Camera positions, orthographic 2.02 m framing, lights, scale and 30 FPS match across every variant.
Renders are 480×640 (higher raster resolution than the earlier 360×480 previews).
Camera and lighting translate with the review fixture; their relative setup remains fixed.

Candidate 02 SHA-256 remains byte-identical:
`fa705b09bd550b17266a5ecc74869e52f1db51759dfcf80afafe7fa4390f757e`.

## Motion and deformation limits

The start deliberately spends ~0.4 s anticipating before the stepping foot releases. The stop
has a relatively brisk ~0.55 s travel deceleration with later upper-body/idle settlement.
The two-step 1.8 s turns are restrained and deliberate. These timing choices require owner review
in the complete chains at normal speed, especially the first stride and stop absorption.
No transition is being approved from stills or contact metrics alone.

This remains the coarse transferred-weight study mesh. Finger articulation is incomplete;
hip/crotch, knees, shoulders and jacket folds need a separate production deformation gate.
The previously accepted walk excursion remains visible. These sources are not production
skinning proof, seated-fit proof, or device/RealityKit acceptance.

## Verification and boundaries

All 21 MP4s passed container checks for 30 FPS, expected frame count, duration and 480×640 resolution.
All 81 key stills exist. Authored Actions, actual skinned soles, loop/heading seams and phase
boundaries were audited through MCP. Playback checks and sampled moving frames supplement those
measurements; owner naturalness acceptance remains pending.

No USD/USDZ export, app integration, Swift, RealityKit, Xcode, production asset, gameplay speed,
Mara/NPC or sit/stand changes were made. No iOS build or simulator run was relevant to this isolated
Blender study. Existing unrelated worktree changes were preserved.

## Owner decisions

- **FOUNDER STANDING IDLE — OWNER ACCEPT / REVISE / REJECT: PENDING**
- **FOUNDER WALK START — OWNER ACCEPT / REVISE / REJECT: PENDING**
- **FOUNDER WALK STOP — OWNER ACCEPT / REVISE / REJECT: PENDING**
- **FOUNDER TURN IN PLACE — OWNER ACCEPT / REVISE / REJECT: PENDING**

## Files

New scripts: `build_transitions.py`, `render_transition_reviews.py`, `audit_transition_actions.py`,
`verify_transition_package.py`. New report: `LocomotionTransitions01.md`.
Updated status documents: `README.md`, `NaturalWalkCandidate02.md`.
New source, review page, poses, audits, manifests, MP4s and PNGs are under `OriginalFounder/Transitions01/`.
`created_files.json` provides the complete per-file inventory, byte sizes and SHA-256 hashes.
