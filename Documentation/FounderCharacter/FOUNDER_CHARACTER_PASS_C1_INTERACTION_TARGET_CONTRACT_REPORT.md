# Founder Character Pass C1 — Interaction Target Contract Report

Date: `2026-09-19`

Status: `IMPLEMENTED — PRESENTATION CONTRACT ONLY`

Pass C1 adds immutable interaction target geometry for the three production targets authorized by C0: Chair, Founder Computer, and Whiteboard. It does not add a runtime interaction coordinator, animation, inverse kinematics, camera focus, input routing, simulation mutation, persistence, or save migration.

## Integration seam

The contract is attached directly to `FacilityTier0InteractionZone`. This preserves the existing production spatial registry and prevents a second target database.

`FounderInteractionTargetContract` records:

- stable target identity and semantic object;
- interaction type;
- approach and interaction poses;
- gaze target;
- optional preferred hand and hand pose;
- positional and angular tolerances.

`FacilityTier0InteractionSpace` exposes a stable, ID-sorted target list and semantic lookup. Reading the contract has no runtime side effects.

## Accepted targets

| Target | ID | Type | Approach position (m) | Interaction position (m) | Gaze target (m) | Position / facing tolerance |
| --- | --- | --- | --- | --- | --- | --- |
| Chair | `facilityTier0.chair` | `seat` | `[-0.301470, 0, 0.290800]` | `[0.34, 0, -0.22]` | `[0.34, 0.455, -0.22]` | `0.08 m / 0.14 rad` |
| Founder Computer | `facilityTier0.founderComputer` | `seatedWorkstation` | `[-0.301470, 0, 0.290800]` | `[0.34, 0, -0.22]` | `[1.42, 1.30, -1.08]` | `0.08 m / 0.14 rad` |
| Whiteboard | `facilityTier0.whiteboard` | `standingObservation` | `[-1.15, 0, -0.40]` | `[-1.15, 0, -0.40]` | `[-2.42, 1.52, -0.40]` | `0.18 m / 0.21 rad` |

The chair/computer approach is derived from the accepted seat-to-monitor facing vector `[0.782280, 0, -0.622927]` at a measured `0.82 m` from the seat. The point lies outside the chair and desk exclusions and is accepted by production walkability. The seated interaction pose remains exactly the pre-C1 Founder pose.

The Whiteboard retains the C0-audited authored face and existing walkable standing position. Its approach and interaction poses intentionally match because C1 describes a stationary observation endpoint, not a reach or contact action.

No preferred hand or hand target is asserted in C1. Authoring those without a runtime contact/reach contract would create false precision.

## Deferred targets

The following are classified `TARGET-AUTHORING GAP` and have no Founder interaction contract:

- iPhone;
- iPad;
- Signal TV;
- Funding/Strategy Board.

Their current production path lacks sufficiently authoritative V8 target anchors/entities for contact authoring. Garage Door and Second Workstation also remain ordinary spatial zones without C1 Founder contracts because they are outside this pass.

## Preservation boundaries

- `FounderLocomotionState` remains the accepted nine-state Pass B graph.
- No animation clips, pose overlay, procedural reach, or IK were added.
- No camera state, focus recipe, or navigation behavior was changed.
- `GameStore` and save payloads were not changed; `GameStore.saveVersion` remains `20`.
- Founder runtime asset bytes and rig/skeleton contracts were not edited.
- Xcode project and scheme changes were not required for C1.

## Verification

Focused XCTest execution on `iPhone 17 Pro Max`, iOS `26.5`:

- 6 tests executed;
- 0 failures;
- result bundle: `/tmp/solo-pass-c1-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.19_13-33-36--0400.xcresult`.

The tests prove stable/unique IDs, bounded target membership, finite contract values, positive tolerances, walkable approaches, accepted endpoint preservation, gaze/facing agreement, deferred-target absence, unchanged motion states, and save version `20`.

Broader relevant regression on the same device:

- complete `FounderGarageRealityTests` plus `FounderCharacterContractTests`;
- 139 tests executed (127 Garage + 12 Founder contract/motion);
- 0 failures;
- result bundle: `/tmp/solo-pass-c1-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.19_13-35-40--0400.xcresult`.

The `Solo Unicorn Run` scheme also built successfully for both required device classes:

- iPhone 17 Pro Max, iOS 26.5;
- iPad Air 11-inch (M4), iOS 26.5.

The accepted Founder USDZ was rehashed after implementation and remains exactly `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.

This pass makes no visual, animation, contact, audio, or haptic correctness claim. Those require later implementation and human simulator acceptance. Pass C2 has not begun.
