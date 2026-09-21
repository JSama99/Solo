# Visual Pass B — Camera Physics

## Scope

This pass changes only the Founder Garage RealityKit presentation layer. `GameStore`, simulation engines, saves, Agent Operations, Strategy Board, Product Launch, Atlantis, lighting, and materials are unchanged. Save version remains 20. Founder locomotion animation is intentionally deferred.

## Baseline audit

| View | Position / target authority | FOV | Previous transition | Input / collision / Reduce Motion |
|---|---|---:|---|---|
| Founder POV | seated Founder anchor + 1.18 m eye offset / monitor face | 56° | exact 0.30 s fade bridge | bounded drag look; no walking integration; immediate Reduce Motion endpoint |
| Garage Overview | authored camera anchor, with V7 exterior override | 62° | 0.30 s fade | authored inspection |
| Whiteboard | seated eye / whiteboard face | 52° | 0.30 s fade | authored inspection |
| Front Bay | seated eye / agent desk surface | 58° | 0.30 s fade | authored inspection |
| Garage Door | door-relative exterior recipe; V7 override | 64° (88° V7) | 0.30 s fade | authored inspection; door state already canonical presentation state |
| Front | door mouth + exterior offset / door mouth | 64° | 0.30 s fade | authored inspection |

The existing `FounderGarageCameraController` was already the transform authority, but it applied endpoints directly and the SwiftUI bridge faded every semantic transition. The spatial contract already exposed the facility boundary and effective imported/procedural occupied bounds. There was no production walking camera integrator.

The continuation audit found that the first Camera Physics implementation had survived the integration merge: walking controls, elapsed-time movement, basic transition classes, collision projection, Reduce Motion, the locomotion sample type, and Debug diagnostics were present and compiling. The remaining incomplete pieces were angular-velocity modeling, a working Interaction Focus API, fixed-substep use, complete drift/focus diagnostics, a read-only future-animation state projection, and explicit transition-time movement cancellation. The continuation completed those pieces without rebuilding the controller or changing `ContentView`.

## Implementation

`FounderGarageCameraController` now owns target look, linear and angular velocity, movement intent, physical transition progress, collision response, Interaction Focus, Reduce Motion policy, and diagnostics. Scene updates use elapsed time, a 0.10 s hitch clamp, and fixed subdivisions no larger than 1/120 second. Garage walking uses a 1.22 m/s exploration speed, 4.8 m/s² acceleration, 6.4 m/s² deceleration, restrained angular acceleration capped at 2.2 rad/s, a 1.66 m standing eye height, zero roll, and the existing yaw/pitch bounds. No rhythmic bob or seated wobble was added because either would destabilize the monitor before locomotion animation supplies a real step phase.

Short transitions use 0.28 s smoothstep interpolation, Front Bay uses a 0.42 s medium transition, and Overview/Door/Front preserve the interrupt-safe fade. Reduce Motion installs endpoints immediately. Every return to the desk reinstalls the authored seated player state and exact Founder POV transform, preventing accumulated drift.

Walking collision samples the existing effective occupied bounds and facility boundary with a 0.23 m player radius. Axis projection permits stable wall sliding; blocked corners zero velocity. A closed door remains blocked. When open, the existing door mouth permits a bounded six-metre exterior corridor and re-entry.

The touch movement pad, accessibility step actions, Explore/Return control, and DEBUG diagnostics all feed the same controller. A transparent foreground routing layer prevents a RealityKit monitor tap behind a HUD control from stealing the event. The future animation boundary is `FounderLocomotionCameraSample` (body position, heading, velocity, optional step phase, stance); it contains no animation or simulation authority.

Interaction Focus supports computer, phone, tablet, Strategy Board, Signal TV, and server targets. The first focus request stores one prior valid camera state; focus-to-focus retargets preserve that original return point, and restore is idempotent. Walking rejects focus requests. `FounderCameraSpatialState` exposes position, facing, horizontal velocity, movement magnitude, stance, navigation mode, normalized intent, and optional step phase as read-only presentation data for Animation Pass A.

## Automated evidence

- Generic iOS Simulator Debug build: passed.
- Generic iOS Simulator Release build: passed.
- Focused Garage suite: 107 tests passed with zero failures, including exact 100-cycle endpoint return, free-look drift/roll checks, acceleration/cruise/deceleration, 30/60/120 Hz consistency, hitch clamping, collision/corner response, interaction focus enter/retarget/restore, transition interruption and movement cancellation, Reduce Motion, and established Garage regressions.
- Full unit suite: 888 tests passed with zero failures.
- Production UI fixture: passed on iPhone 17 Pro Max and iPad Air 11-inch (M4) simulators, covering Explore, movement pad, exact desk return, and Founder Computer continuity.
- Signed Debug builds compiled, installed, and launched on the connected iPhone 16 Pro and iPad Air 11-inch (M4).
- Save schema: version 20 unchanged.

Physical-device motion feel, visual exposure continuity while crossing the door, and subjective comfort remain human acceptance checks. The final fixture is installed and launched on the connected iPhone 16 Pro and iPad Air 11-inch (M4); inspect normal and Reduce Motion behavior on both before calling the pass visually accepted.
