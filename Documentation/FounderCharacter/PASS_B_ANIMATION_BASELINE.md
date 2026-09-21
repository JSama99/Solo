# Founder Character Pass B — Animation Baseline

## Production architecture

The production Founder uses the accepted `founder_candidate_a.usdz` through `USDZFounderVisualAdapter`. The package exposes ten independently maskable skinned model modules, 55 canonical joints, nine facial targets, and zero gameplay animation resources. `FounderAuthoredPoseRig` owns presentation-only joint transforms. `FounderGarageCameraController` remains the spatial authority; the character anchor follows its position and heading and never feeds root motion back into Camera Physics or `GameStore`.

```text
SeatedIdle ── stand ──> StandingUp ──> WalkStart ──> Walking
     ^                       │              │             │
     │                       └────────> StandingIdle <─ WalkStop
     │                                      │             ^
     └── SittingDown <── seated request ────┘             │
                              StandingIdle ── large yaw ─> TurnInPlace
```

The production graph topology is:

`seatedIdle`, `seatedTurn`, `standingUp`, `standingIdle`, `walkStart`, `walking`, `walkStop`, `turnInPlace`, `sittingDown`.

## Baseline state table

| Surface | Baseline |
| --- | --- |
| Clips | No authored gameplay clips; `FounderAnimationClipCatalog` returns `nil` for every state |
| Seated | Exact accepted A.2 pose, completely static |
| Standing | Imported skeleton rest pose, completely static |
| Sit/stand | Whole-skeleton seated/rest interpolation over 0.42 s (0.08 s with Reduce Motion) |
| Start | State delay of 0.16 s before walking; no body anticipation |
| Walk | Anchor follows camera at up to 1.22 m/s; accepted rig has no animated stride |
| Stop | State delay of 0.24 s; no settling pose |
| Turn | Anchor yaw eases toward camera heading; skeleton remains rigid |
| Root motion | Disabled; camera/world displacement is authoritative |
| Pose normalization | Accepted seated offset/orientation blends to standing normalization |
| Procedural overlays | Only legacy procedural proxy has a small whole-body sinusoid; promoted rig receives none |
| Gaze | None |
| Breathing | None on promoted rig |

## Initial measurements

The deterministic 60 Hz controller fixture gives the following baseline:

- stationary joint amplitude: `0 rad`
- stationary foot and pelvis animation drift: `0 m`
- world walking speed: `1.22 m/s`
- promoted-rig animated stride: `0 m`
- visual foot-slide mismatch while walking: effectively `100%`
- seated/rest transition duration: `0.42 s`
- seated anchor error after convergence: `0 m`
- gameplay animation resources: `0`

## First defect and bounded plan

The first defect is not the graph or spatial authority. It is the absence of production-rig body motion. The smallest safe change is a deterministic additive joint-pose layer inside `FounderAuthoredPoseRig` that:

1. preserves the exact seated and standing base poses at defined convergence points;
2. adds low-amplitude, aperiodically modulated idle breathing and sparse gaze;
3. adds phase-driven presentation-only walk, start, stop, and turn poses;
4. leaves the anchor, Camera Physics, state topology, accepted asset, and save schema unchanged;
5. exposes numerical samples for permanent root/contact/convergence tests.

No asset regeneration or new runtime path is planned.
