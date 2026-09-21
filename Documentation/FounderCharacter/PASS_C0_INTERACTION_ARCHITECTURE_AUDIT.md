# Founder Character Pass C0 — Interaction Architecture Audit

Date: `2026-09-19`

Status: `C0 COMPLETE — INSPECTION ONLY`

No production behavior, animation, asset, project, scheme, simulation, camera, save, or baseline was changed during this audit.

## Architecture map

```text
SwiftUI intent / RealityKit tap
        │
        ├─ FounderDeskNavigationState ── device/sheet navigation only
        │
        └─ FounderGarageRealityView ─── Founder Computer tap only
                          │
                          ▼
             FounderGarageRealityWorld
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
 FounderGarageCameraController   FounderAvatarController
 camera + player spatial state        │
                                      ▼
                         FounderLocomotionController
                         Founder anchor/world pose
                                      │
                                      ▼
                         FounderAuthoredPoseRig
                         accepted pose + Pass B additive motion
```

`GameStore` does not own any of these presentation transforms. The Garage camera controller remains the player spatial authority; the locomotion controller copies that session-only state into the persistent Founder anchor. Root motion remains disabled.

## Existing interaction geometry

The production spatial contract already contains useful interaction vocabulary:

- `FacilityTier0InteractionZone` provides stable identity, semantic object, named anchor, object pose, approach pose, interaction distance, activation bounds, and availability.
- `FounderGarageSpatialSpecification` provides room geometry, walkability, occupied zones, workstation dimensions, production anchors, and a smaller legacy `InteractionApproaches` set.
- `FacilityTier0ResolvedAnchorMap` verifies the named anchors loaded from the production Garage USDZ.

The V8 asset exposes the production anchor contract used by the runtime, including `Anchor_Founder_Seat`, `Anchor_Desk_Surface`, `Anchor_Monitor_Face`, and `Anchor_Whiteboard_Face`. It also contains the physical `FounderChair`, `FounderMonitor`, `Monitor_Display`, `Keyboard`, `FounderMouse`, and `Whiteboard` entities.

| Target | Existing production geometry | Current limitation |
| --- | --- | --- |
| Chair | `Anchor_Founder_Seat`, `FounderChair`, chair bounds, accepted seated pose | No chair interaction target or walkable standing approach. The seat itself is inside the chair exclusion. |
| Founder Computer | `Anchor_Monitor_Face`, seated Founder anchor, display bounds, tappable monitor target | The current approach equals the seated endpoint, not a standing approach. Activation requires the Founder already be seated. |
| iPhone / iPad | Deterministic coordinates derived from the desk surface; camera-focus recipes exist | No named production USDZ anchors or production RealityKit interaction entities. The procedural device entities are disabled when V8 is active. |
| Whiteboard | Authored `Anchor_Whiteboard_Face`, physical `Whiteboard`, and a walkable approach | Semantic zone exists but is disabled. It is the strongest current standing-observation geometry. |
| Signal TV | Synthetic spatial pose and disabled semantic zone | No matching authored V8 entity/anchor; the active RealityKit route does not expose it as an interaction. |
| Funding/Strategy Board | Synthetic rear-wall pose and disabled funding zone | The production USDZ exposes a Whiteboard instead. The current Strategy Board is a SwiftUI viewer/hotspot, not a V8 world target. |

## Current callbacks and state ownership

- The production RealityKit scene recognizes only `FounderComputer.InteractionTarget`. A valid tap or accessibility activation calls `onOpenFounderComputer`.
- Computer activation is allowed only in Founder POV while the session player is seated. Walking explicitly disables it.
- Phone, tablet, Signal TV, and Strategy Board selection are implemented in the legacy/projected SwiftUI workspace. Those callbacks open focused device UI or sheets; they do not drive the Founder body in the production RealityKit world.
- `FounderGarageCameraController.focus(on:)` supports computer, phone, tablet, Strategy Board, Signal TV, and server camera recipes, but it is camera-only, rejects walking, and currently has no production call site outside tests.
- `beginWalking()` deterministically moves a seated player to a nearby walkable standing point. `endWalking()` restores the canonical seated player state directly. The Founder locomotion layer visually resolves back to the accepted seat, but there is no approach/alignment/interaction phase pipeline.
- The existing `.interacting` presentation enum case is not supported by `FounderPresentationIntent`; it is not an implemented interaction state.

## Animation and procedural capability

- `FounderLocomotionController` owns the accepted nine-state Pass B graph and the Founder anchor presentation.
- `FounderAuthoredPoseRig` blends the accepted seated and standing poses, then applies bounded Pass B motion to named joints.
- The production USDZ contains no gameplay animation clips. Interaction motion must therefore use a bounded deterministic layer unless separately authored assets are later justified.
- Named joint transforms and deterministic motion samples are already available for hands, arms, torso, head, pelvis, legs, and feet.
- No inverse-kinematics solver or hand-target correction system exists in the current production path.
- Current procedural support is direct bounded joint rotation/translation. There are no joint-limit, reachability, contact-window, or hand-orientation contracts yet.

## First divergences to solve

1. **Chair:** standing approach geometry is missing. The accepted seat is an interaction endpoint, not a walkable approach point.
2. **Computer:** approach, interaction, and seated transforms are conflated. They must become distinct without moving the accepted seated endpoint.
3. **Devices:** iPhone/iPad coordinates are presentation estimates, not authored V8 target anchors. Contact work would be premature until the visible production object relationship is explicit.
4. **Standing observation:** the authored Whiteboard is viable now; Signal TV and Funding Board are not yet production-world targets.
5. **Interruption:** camera focus has exact restore behavior, but no body interaction coordinator exists to cancel alignment, reach, hold, or release safely.

## Smallest integration seam

Evolve the existing `FacilityTier0InteractionZone` spatial language rather than creating a competing interaction architecture.

C1 should add a presentation-only contract that can be derived from or attached to each semantic zone and records:

- approach transform;
- interaction transform;
- interaction facing;
- gaze target;
- optional preferred hand and hand target;
- positional/angular tolerances;
- interaction type.

The contract should remain immutable geometry. A later session-only interaction coordinator can consume it alongside `FounderCameraSpatialState`; it must not enter `GameStore`, saves, Camera Physics ownership, or the Pass B locomotion graph.

For body presentation, the narrowest future seam is an interaction overlay adjacent to `FounderAuthoredPoseRig.apply(...)`, composed after the accepted base pose and before joint assignment. That overlay should be inactive outside interaction windows so the ratcheted Pass B signature remains byte-for-byte and behaviorally unchanged.

Do not add IK in C1. First prove target identity, approach walkability, facing, tolerances, and deterministic measurement.

## Recommended C1 boundary

Implement contracts only for geometry that is already trustworthy:

1. Chair: author a distinct walkable standing approach plus the unchanged accepted seat interaction transform.
2. Founder Computer: distinguish standing approach, seated interaction transform, and monitor gaze target.
3. Whiteboard: retain its authored face and walkable approach as the first standing-observation contract.

Defer iPhone, iPad, Signal TV, and Funding Board contact contracts until their production V8 target geometry is explicit. This is a target-authoring gap, not an animation defect.

## Verification implications

C1 can remain Tier 1/2 and presentation-only. Its initial tests should prove stable identifiers, finite transforms, walkable approach points, target-facing agreement, distinct chair/computer approach and interaction transforms, and unchanged production Founder hash. No build or test was run for this inspection-only C0 pass.
