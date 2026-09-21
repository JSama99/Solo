# Animation Pass A — Founder Locomotion Graph

## Decision

**GO WITH HUMAN ACCEPTANCE**

The deterministic locomotion architecture and procedural validation motion are complete. Production humanoid clips, skeletal foot motion, and final visual tuning still require authored animation assets and hands-on inspection.

## Architecture

`FounderAvatarController` owns the replaceable avatar boundary and contains one shared `FounderLocomotionController`. The locomotion controller consumes `FounderCameraSpatialState`; it never writes to the camera controller, collision system, `GameStore`, persistence, or simulation time.

The explicit graph is:

```text
seatedIdle ↔ seatedTurn
seatedIdle/seatedTurn → standingUp → standingIdle/walkStart
standingIdle → walkStart → walking → walkStop → standingIdle
standingIdle → turnInPlace → standingIdle
standing/walking/stop → sittingDown → seatedIdle
```

Transitions use centralized timing. Reduce Motion shortens stand/sit and blend transitions and removes cyclic walking weight shift while retaining visible state and exact placement.

## Authoritative movement and root motion

Camera Physics remains authoritative for position, facing input, horizontal velocity, movement magnitude, stance, navigation mode, collision response, and normalized intent. The Founder visual root follows that state. Animation never advances the player position, performs collision tests, or applies root motion to navigation.

Walking playback speed is derived from actual horizontal velocity and clamps to a safe visual range. A blocked collision is treated as zero animation speed, which moves the graph toward walk stop instead of visually walking through geometry. Direction changes use bounded visual orientation catch-up; stationary large facing deltas use turn-in-place.

Chair return requires the camera-owned seated position to be within 0.45 metres of the authored seat. Sitting interpolates from the last visual position and resolves exactly to the seated anchor. The original seated body/head transforms are cached before standing and restored after sitting so existing typing, review, low-energy, and stressed presentations remain intact.

## Avatar and asset audit

The current production fallback is the existing cached procedural torso/head rig. No production humanoid skeletal clips or named stand, walk, stop, turn, or sit resources are present. `USDZFounderVisualAdapter` reports available animation resources but does not yet provide a named locomotion clip map.

Animation Pass A therefore uses restrained procedural validation motion:

- forward center-of-mass shift during stand/sit
- velocity-scaled walking weight transfer
- eased root orientation catch-up
- deterministic start, stop, and turn states

The same controller accepts replacement rig adapters, so future male and female Founder avatars share the graph. Missing production work is authored/mocap stand-up, walk-start, in-place walk, walk-stop, small/large turns, and sit-down clips plus a clip-name binding contract. Foot IK, hand IK, gaze, reactions, and object interaction remain outside this pass.

## Camera and visibility

The avatar anchor activates when scene updates begin. The complete visual root is hidden in first-person Founder POV to prevent head or torso intersection with the camera. It becomes visible in alternate Garage cameras, preserving a persistent world character without adding a third-person gameplay camera.

## Performance and accessibility

The graph performs constant-time math against cached rig entities. It does no per-frame entity search, resource creation, animation-controller recreation, or SwiftUI state mutation. Debug diagnostics refresh at 4 Hz and expose current/previous locomotion state, navigation mode, velocity, movement magnitude, target/avatar facing, procedural animation, playback speed, blend progress, seat error, and root error. Release builds exclude the diagnostics block.

VoiceOver controls remain unchanged. Animation conveys no exclusive gameplay state, and Reduce Motion preserves navigation and avatar correctness.

## Verification

- Focused `FounderGarageRealityTests`: **115 passed, 0 failed**.
- Complete unit target: **896 passed, 0 failed**.
- iPhone 17 Pro Max simulator production camera/locomotion flow: passed.
- iPad Air 11-inch (M4) simulator production camera/locomotion flow: passed.
- Debug simulator compilation: passed through focused and full test builds.
- Release simulator build: passed.
- Save version: **20**, unchanged.
- Xcode project and shared scheme: unchanged.
- `git diff --check`: passed.

Signed Debug builds compiled, installed, and launched on the connected iPhone 16 Pro and physical iPad Air 11-inch (M4). The iPad hardware run used the production Founder Desk, RealityKit Garage, and camera diagnostics launch fixture.

## Human acceptance

Inspect on physical hardware before promoting beyond **GO WITH HUMAN ACCEPTANCE**:

- stand-up and sit-down believability
- placeholder foot skating and body floating
- chair and desk clipping
- wall/door traversal continuity
- visual root/camera divergence
- turn-in-place weight and orientation
- first-person clipping
- alternate-camera visibility
- Reduce Motion pacing

The procedural rig has no legs or skeleton, so final foot-skating quality cannot be accepted until production humanoid clips exist. Animation Pass B — Micro-Behaviors & Gaze was not started.
