# Founder Character Pass B — Human Motion Review Board

Status: `HUMAN MOTION ACCEPTANCE: ACCEPTED`

Acceptance date: `2026-09-19`

This board presents the current engineering-approved Pass B baseline without motion tuning. The capture route is DEBUG-only and calls the production `FounderLocomotionController` with the accepted Founder and production V8 Garage. All clips use normal playback speed, stable production lighting, a fixed camera within each review category, no slow motion, and no cuts across a transition.

## Evidence conditions

- Founder: accepted `founder_candidate_a.usdz`
- Founder SHA-256: `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`
- Garage: bundled production V8
- device set: iPhone 17 Pro Max simulator; representative iPad Air 11-inch (M4) simulator
- close review camera: seated idle, standing idle, sit/stand, and turn
- wide review camera: walk start, continuous walk, walk stop, and walk + turn
- playback: normal production speed
- Reduce Motion: off for the primary evidence
- motion variants: none
- capture date: 2026-09-18

The five-second labeled lead-in is evidence staging only. Motion begins after the lead-in from a fresh deterministic fixture launch. The wide gait framing keeps feet, legs, arms, and world displacement visible for several stride cycles.

## Review clips

| Section | Evidence | Review focus | Decision |
| --- | --- | --- | --- |
| A · Seated Idle | [iPhone · 19 s](Evidence/B/HumanMotionReview/A_SeatedIdle_iPhone17ProMax.mp4) | respiration, torso, sparse gaze, repetition | Accepted |
| B · Standing Idle | [iPhone · 19 s](Evidence/B/HumanMotionReview/B_StandingIdle_iPhone17ProMax.mp4) | life vs restlessness, posture, head compensation | Accepted |
| C · Sit → Stand | [iPhone · 11 s](Evidence/B/HumanMotionReview/C_SitToStand_iPhone17ProMax.mp4) | preparation, lift, rise, settle, weight | Accepted |
| D · Stand → Sit | [iPhone · 11 s](Evidence/B/HumanMotionReview/D_StandToSit_iPhone17ProMax.mp4) | descent, chair approach, contact, accepted settle | Accepted |
| E · Walk Start | [iPhone · 11 s](Evidence/B/HumanMotionReview/E_WalkStart_iPhone17ProMax.mp4) | acceleration, first cycle, arm and torso transition | Accepted |
| F · Continuous Walk | [iPhone · 9 s](Evidence/B/HumanMotionReview/F_ContinuousWalk_iPhone17ProMax.mp4) · [iPad · 9 s](Evidence/B/HumanMotionReview/F_ContinuousWalk_iPadAir11M4.mp4) | feet, legs, arms, cadence, grounding, displacement | Accepted |
| G · Walk Stop | [iPhone · 11 s](Evidence/B/HumanMotionReview/G_WalkStop_iPhone17ProMax.mp4) | deceleration, foot phase, settle, momentum | Accepted |
| H · Turn In Place | [iPhone · 14 s](Evidence/B/HumanMotionReview/H_TurnInPlace_iPhone17ProMax.mp4) | small 25°, medium 90°, large 170°, anticipation | Accepted |
| I · Walk + Turn | [iPhone · 11 s](Evidence/B/HumanMotionReview/I_WalkAndTurn_iPhone17ProMax.mp4) | one-body heading adjustment during locomotion | Accepted |

## Review dimensions

Judge the visible result, not the numerical contracts:

1. stillness vs life
2. weight
3. grounding
4. gait character
5. arm motion
6. torso motion
7. head behavior
8. transition quality
9. visible repetition
10. overall focused-Founder character

## Neutral engineering context — read after viewing

- seated breathing periods: 4.8 s and 7.3 s
- sparse gaze envelope: 11 s
- seated head yaw maximum: approximately 0.055 rad
- walk cycle distance: 0.78 m
- walk-start blend: 0.16 s
- walk-stop blend: 0.24 s
- sit/stand blend: 0.42 s
- Reduce Motion transition: 0.08 s
- stationary presentation yaw cap: 2.4 rad/s
- moving yaw cap: 5 rad/s
- turn torso/head anticipation: less than 0.10 rad
- maximum gait vertical presentation offset: 11 mm

## Human outcome

`ACCEPT`

The reviewer explicitly accepted the unchanged production baseline on September 19, 2026. A controlled start/stop round was requested earlier, then stopped before any variant evidence was generated; no alternate parameter set was reviewed or selected.

Seated idle, standing idle, sit/stand, gait, start/stop, turn, and the overall package are accepted. The reviewed evidence and its existing deterministic motion signature are now the protected Pass B baseline. Pass B is `GO`; Pass C has not begun.
