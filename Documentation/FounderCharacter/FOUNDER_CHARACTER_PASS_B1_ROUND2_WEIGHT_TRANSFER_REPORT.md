# Founder Character Pass B.1 Round 2 — Lateral Weight Transfer & Inertia

Date: 2026-09-19

Status: `READY FOR HUMAN SELECTION`

## Question

Which option makes the Founder feel most naturally weighted and grounded without introducing unwanted sway or instability?

Round 1 Variant C is frozen beneath all four options. In this round, `Baseline` means accepted Round 1 Variant C with no added weight-transfer layer.

## Bounded implementation

One continuous deterministic support signal is derived from the existing gait phase. It drives only:

- local pelvis lateral translation;
- pelvis roll;
- opposing torso counterbalance;
- smaller shoulder compensation.

The layer is recomputed additively each frame, multiplied by the existing gait blend envelope, and suppressed under Reduce Motion. It does not modify the Founder anchor, world translation, cadence, stride, phase profile, start/stop timing, turning authority, locomotion topology, chair geometry, Garage↔Atlantis ownership, `GameStore`, or save schema.

Production remains on Round 2 `Baseline` until explicit human selection.

## Machine-readable profiles

| Option | Pelvis lateral | Pelvis roll | Torso factor | Shoulder factor |
| ------ | -------------- | ----------- | ------------ | --------------- |
| Baseline | 0.000 m | 0.000 rad | 0.00 | 0.00 |
| Variant A | 0.010 m | 0.012 rad | 0.45 | 0.20 |
| Variant B | 0.016 m | 0.018 rad | 0.55 | 0.26 |
| Variant C | 0.022 m | 0.026 rad | 0.65 | 0.32 |

Canonical fixture: `Evidence/B/pass_b1_round2_weight_transfer.json`.

## Objective verification

- Focused Founder motion and four GL-WT scenarios: 22/22 passed.
- Founder + Garage + Atlantis + desk regression: 291/291 passed.
- Debug simulator build and launch: passed.
- iPhone 17 Pro Max evidence framing and iPad Air 11-inch (M4) smoke framing: passed with the full Founder visible.
- Foot-slide ratio remained ≤0.02.
- Gait-cycle distance remained 0.78 m.
- Root motion remained disabled; the Founder root matched camera-owned spatial position.
- Support weights remained within 0...1; support bias remained within -1...1 and was zero-mean over a full sampled cycle.
- Pelvis, torso, shoulder, root, and sampled joint transforms remained finite and within the declared bounds.
- Long traversal produced no accumulated local or root drift.
- Start/stop behavior remained enveloped, and the layer resolved to zero under Reduce Motion.
- Save version remained 20.
- Founder asset SHA-256 remained `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.

Focused result bundle:

`~/Library/Developer/XcodeBuildMCP/workspaces/Solo-90e048df17cb/result-bundles/test_sim_2026-09-20T00-47-38-447Z_pid91996_4006926d.xcresult`

Related regression result bundle:

`~/Library/Developer/XcodeBuildMCP/workspaces/Solo-90e048df17cb/result-bundles/test_sim_2026-09-20T00-47-58-290Z_pid91996_51ecab33.xcresult`

The first focused run exposed two test-fixture pre-roll defects: long traversal measured during the existing stand transition, and moving-turn velocity compared before steady walking. The fixture boundaries were corrected without changing motion code; the second run passed 22/22.

## Human evidence

Primary straight-walk clips:

- `PassB1Round2/Baseline_Straight_iPhone17ProMax.mp4`
- `PassB1Round2/Variant_A_Straight_iPhone17ProMax.mp4`
- `PassB1Round2/Variant_B_Straight_iPhone17ProMax.mp4`
- `PassB1Round2/Variant_C_Straight_iPhone17ProMax.mp4`

Mild moving-turn regression clips:

- `PassB1Round2/Baseline_MildTurn_iPhone17ProMax.mp4`
- `PassB1Round2/Variant_A_MildTurn_iPhone17ProMax.mp4`
- `PassB1Round2/Variant_B_MildTurn_iPhone17ProMax.mp4`
- `PassB1Round2/Variant_C_MildTurn_iPhone17ProMax.mp4`

Matching straight-route stills are stored beside the clips, including `Variant_C_Straight_iPadAir11M4.png`. The full body remains visible in the reviewed captures. Still frames confirm framing and load integrity; motion quality remains a human video-review decision.

## Gate

Choose exactly one: `Baseline`, `Variant A`, `Variant B`, or `Variant C`.

Until that choice is explicit:

- no Round 2 weight-transfer profile is promoted;
- the accepted Round 1 Variant C gait remains production locomotion;
- C2 corrected human re-review remains paused;
- C3 does not begin.
