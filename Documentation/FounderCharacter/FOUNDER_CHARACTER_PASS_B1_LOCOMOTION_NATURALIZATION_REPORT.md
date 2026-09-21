# Founder Character Pass B.1 — Locomotion Naturalization

Date: 2026-09-19

Status: `ROUND 1 ACCEPTED — VARIANT C PROMOTED`

## Decision question

Does phase-separated pelvis, torso, arms, legs, feet, and vertical center-of-mass timing make the accepted Founder walk materially more natural without changing speed, cadence, stride distance, world translation, camera ownership, or locomotion graph topology?

No engineering contract chose the answer. Baseline and Variants A–C were presented neutrally for human comparison. The reviewer explicitly selected Variant C on 2026-09-19, and Variant C is now the production default.

## Scope

Round 1 changes only gait-layer phase relationships. It does not change:

- walking speed, acceleration, deceleration, or stop behavior;
- the 0.78 m gait-cycle distance;
- joint-motion amplitudes or the accepted asset and materials;
- the nine-state locomotion graph;
- camera-owned world translation or collision;
- chair geometry, seated/standing endpoints, save data, or `GameStore.saveVersion`;
- Garage/Atlantis handoff ownership.

The profiles remain bounded timing sweeps. Variant C is the accepted Round 1 production constant; Baseline and Variants A/B remain available as review references. Round 2 lateral weight transfer remains a separate, not-yet-started pass.

## Implementation

- Added a presentation-only locomotion blackboard containing speed, normalized speed, gait phase, deterministic left/right foot phase, and review variant.
- Split the existing single gait wave into pelvis, thigh, knee, foot, torso, arm, and vertical center-of-mass phase channels while preserving every prior amplitude.
- Kept Baseline at zero offsets so its motion math remains equivalent to the accepted Pass B gait.
- Preserved explicit Baseline/A/B/C launch selection for review and promoted Variant C as the default in both Debug and Release behavior.
- Added a deterministic tracking review camera for translating review sections. This fixes the evidence defect where the Founder walked out of frame while world translation continued; gameplay camera behavior is unchanged.

## Objective verification

- Focused Founder suite: 16/16 passed.
- Variant C promotion checks: 21/21 passed (16 Founder motion contracts plus 5 root-motion, topology, chair, and Garage↔Atlantis handoff checks).
- Founder + Garage + Atlantis + desk regression: 285/285 passed.
- Debug scheme build: passed.
- `git diff --check` on changed implementation and test files: passed.
- iPhone 17 Pro Max and iPad Air 11-inch (M4): full Founder remained visible in the corrected review framing.
- Root motion remains disabled; sampled anchor translation equals camera-owned spatial position.
- Speed remains `FounderGarageCameraConfiguration.walkingSpeed` for every variant.
- Gait-cycle distance remains 0.78 m and measured foot-slide ratio remains at or below 0.02.
- All sampled root and joint transforms remained finite.
- Start/stop monotonicity, turn bounds, chair endpoints, Garage↔Atlantis same-rig handoff, and save version 20 remained green.
- A no-override iPhone 17 Pro Max smoke launch resolved to `Variant C` and retained full-body third-person review framing.

Test result bundle:

`/tmp/solo-b1-round1/Logs/Test/Test-Solo Unicorn Run-2026.09.19_20-20-40--0400.xcresult`

Promotion result bundle:

`/tmp/solo-b1-variant-c/VariantC-3.xcresult`

## Neutral human-review evidence

- `PassB1Round1/Baseline_iPhone17ProMax.mp4`
- `PassB1Round1/Variant_A_iPhone17ProMax.mp4`
- `PassB1Round1/Variant_B_iPhone17ProMax.mp4`
- `PassB1Round1/Variant_C_iPhone17ProMax.mp4`
- `PassB1Round1/Variant_B_iPadAir11M4.png`
- `PassB1Round1/Variant_C_iPhone17ProMax.png`

All four clips use the same production Founder, route, normal speed, cadence, joint amplitudes, world, lighting, field of view, and deterministic tracking-camera offset.

## Evidence hashes (SHA-256)

- Baseline: `27491e6cdfb860e5d9cf074145f15f24204a0cfeb9f68c0188dfbc2e05127cc2`
- Variant A: `a80a721a2f05a2621babaeff2369382ad3d20eb7822ea24ca108c015130c2427`
- Variant B: `cdcffdca9a39a72f3939077f570cea5be183f3c0a8da45ea23797671a7ae75d2`
- Variant C: `e282376d110006d3ed613d213a113f0eade5df5b9c763a40e2f235b6bd16b899`

## Human selection

The reviewer selected `Variant C` on 2026-09-19.

- Round 1 is complete and Variant C is promoted.
- Baseline and Variants A/B remain available for deterministic comparison.
- Round 2 lateral weight transfer has not begun.
- Pass C3 has not begun.
