# Founder Character Pass B.2 Round 1 — Support-Leg Loading & Kinetic Chain

Date: 2026-09-20

Status: `ROUND 1 ACCEPTED — VARIANT B`

## Question

Which option makes the Founder feel most connected and naturally weighted through the pelvis, torso, shoulders, and arms during straight cruise?

Accepted Pass B.1 Round 1 Variant C is frozen beneath every option. Pass B.1 Round 2 remains unselected, so its production `Baseline` (zero lateral weight transfer) is also frozen beneath every option. In this round, `Baseline` means no added support-loading or kinetic-chain layer.

## Bounded implementation

The added layer is an analytic, deterministic function of the existing gait phase, phase rate, and gait blend envelope. It provides:

- support-aware vertical pelvis loading;
- delayed torso phase response;
- smaller delayed shoulder response;
- delayed arm follow-through.

Offsets are recomputed from canonical locomotion inputs each frame; there is no accumulated filter or physics history. The layer is suppressed under Reduce Motion. It does not modify speed, cadence, gait-cycle distance, root/world translation, foot-contact authority, start/stop endpoints, turn authority, locomotion topology, camera ownership, `GameStore`, save schema, or the Founder asset.

The reviewer selected `Variant B` on 2026-09-20. Production now uses that profile. Pass B.1 Round 2 remains on `Baseline`; no lateral weight-transfer profile was promoted.

## Machine-readable profiles

| Option | Support loading | Torso lag | Shoulder lag | Arm follow-through |
| ------ | --------------- | --------- | ------------ | ------------------ |
| Baseline | 0.0000 m | 0.000 s | 0.000 s | 0.000 s |
| Variant A | 0.0035 m | 0.018 s | 0.014 s | 0.024 s |
| Variant B | 0.0055 m | 0.030 s | 0.024 s | 0.040 s |
| Variant C | 0.0075 m | 0.042 s | 0.034 s | 0.056 s |

Canonical fixture: `Evidence/B/pass_b2_round1_kinetic_chain.json`.

## Objective verification

- Focused Founder character contracts and GK01–GK05 scenarios: 29/29 passed.
- Founder + Garage + Atlantis + desk related regression: 298/298 passed.
- Post-promotion focused verification: 29/29 passed.
- Post-promotion related regression: 298/298 passed.
- No-override production install and launch with Variant B: passed.
- Debug simulator build, install, and launch: passed.
- iPhone 17 Pro Max evidence framing and iPad Air 11-inch (M4) smoke framing: passed with the full Founder visible.
- Gait-cycle distance remained 0.78 m.
- Foot-slide ratio remained ≤0.02.
- Root motion remained disabled; sampled root translation matched canonical spatial position.
- Support values, transition rate, pelvis loading, torso/shoulder phase response, arm target/presented angles, and sampled transforms remained finite and bounded.
- Long traversal produced no accumulated local or root drift.
- Start and stop remained enveloped; standing endpoints were unchanged; the layer resolved to zero under Reduce Motion.
- Save version remained 20.
- Founder asset SHA-256 remained `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.

Focused result bundle:

`/tmp/solo-pass-b2-derived/Logs/Test/Test-Solo Unicorn Run-2026.09.19_22-30-23--0400.xcresult`

Related regression result bundle:

`/tmp/solo-pass-b2-derived/Logs/Test/Test-Solo Unicorn Run-2026.09.20_03-29-11--0400.xcresult`

Post-promotion focused result bundle:

`/tmp/solo-pass-b2-promotion-derived/Logs/Test/Test-Solo Unicorn Run-2026.09.20_04-03-05--0400.xcresult`

Post-promotion related regression result bundle:

`/tmp/solo-pass-b2-promotion-derived/Logs/Test/Test-Solo Unicorn Run-2026.09.20_04-03-41--0400.xcresult`

The first promotion verification run failed three assertions because the one-line default edit matched the adjacent B.1 weight-transfer enum: B.1 became `.b` while B.2 remained `.baseline`. The defaults were corrected explicitly to B.1 `.baseline` and B.2 `.b`; no motion profile values changed. The rerun passed 29/29, followed by 298/298 related tests.

The initial iPad screenshot landed behind an architectural column. A later frame from the same unchanged build, route, camera, and Variant C launch replaced that screenshot; motion code was not changed.

## Human evidence

Primary straight-cruise clips:

- `PassB2Round1/Baseline_Straight_iPhone17ProMax.mp4`
- `PassB2Round1/Variant_A_Straight_iPhone17ProMax.mp4`
- `PassB2Round1/Variant_B_Straight_iPhone17ProMax.mp4`
- `PassB2Round1/Variant_C_Straight_iPhone17ProMax.mp4`

Matching iPhone stills and `PassB2Round1/Variant_C_Straight_iPadAir11M4.png` are stored beside the clips. Stills confirm framing and load integrity; connectedness and natural weight remain human video-review decisions.

## Human decision

Selected: `Variant B`.

Production baseline is now:

`Pass B.1 Round 1 Variant C` + `Pass B.1 Round 2 Baseline` + `Pass B.2 Round 1 Variant B`.

The B.1 Round 2 lateral-transfer hypothesis is closed for this stage as `Baseline retained`: the selected kinetic-chain direction improved the targeted quality without requiring added lateral pelvis transfer. Its evidence remains preserved.

Pass B.2 Round 1 is complete. The next permitted experiment is the bounded Round 2 start/stop/turn kinetic-response pass using Variant B as the frozen cruise profile. C2 human re-review remains paused until that locomotion pass closes; C3 does not begin.
