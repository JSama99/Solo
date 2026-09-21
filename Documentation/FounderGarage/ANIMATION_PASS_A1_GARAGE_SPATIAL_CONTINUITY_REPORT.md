# Animation Pass A.1 — Garage Spatial Continuity Repair

**Status: GO WITH HUMAN ACCEPTANCE**  
**Date:** September 14, 2026  
**Branch:** `visual-fidelity-track`  
**Save version:** 20

## Scope

This bounded repair addresses the three defects found after Animation Pass A:

1. seated Founder Free Look could not inspect the Garage behind the chair;
2. Explore started from an invalid chair-overlapping position, did not face the exit, and the Garage scene ended at a short frontage corridor;
3. the production Garage asset did not contain the intended right-side personnel door.

Animation Pass B was not started.

## Defect 1 — seated spatial inspection

### Root cause

The canonical Founder POV, seated Free Look, and desktop-origin camera path shared a centralized yaw clamp of **−80°...+80°**. This range was appropriate for a narrow desk inspection cone but prevented rear Garage inspection. Gesture response also used a fixed **π/900 radians per point**, so the physical rotation produced by the same normalized drag varied with viewport width.

The camera controller already owned seated eye position, orientation clamping, interpolation, recentering, and roll-free transforms. No second camera authority was needed.

### Repair

- The exact authored Founder POV remains unchanged.
- Seated yaw is now **−175°...+175°**, wide enough to inspect both rear quadrants while avoiding the discontinuity at exactly ±180°.
- Pitch remains **−18°...+12°**.
- The player root and chair position remain fixed during seated look.
- Recenter still resolves to the exact authored Founder POV and zero look orientation.
- Drag response is now viewport-normalized at **0.85π radians per full viewport**, producing the same angular response on iPhone and iPad.
- Existing Founder Computer hit routing remains active during valid seated Free Look.
- Reduce Motion continues to use immediate endpoint resolution.

The Founder body is not rotated with the broad camera look. Higher-quality head and torso following remains Animation Pass B scope.

## Defect 2 — Garage and Atlantis traversal

### Root causes

Two separate restrictions combined to produce the frontage-only experience:

1. Explore initialized the standing player at the canonical seated anchor, which overlaps the authored chair/desk exclusion. The collision solver therefore began from an invalid point and could repeatedly reject otherwise valid movement.
2. The production Garage and Atlantis were separate RealityKit roots. Garage walking permitted only a short doorway corridor and had no handoff into the existing Atlantis streaming runtime. Increasing the local Garage bounds would have created an empty duplicate exterior instead of loading the authored city.

The spatial audit confirmed both systems use meters with +X right, +Y up, and the Garage +Z axis pointing through the sectional door. The existing Atlantis Founder Garage landmark is at `[-875, 8, 1030]`; the Garage driveway is already part of the Atlantis traversal geometry.

### Repair

- Explore now resolves the chair-overlapping seated anchor to the nearest deterministic walkable standing sample and faces the Garage exit before movement begins.
- Existing rectangular room bounds, authored obstacle volumes, stable axis-separated sliding, and door-state collision remain authoritative inside the Garage.
- A closed sectional door continues to block the doorway.
- When the door is open, the valid exterior corridor overlaps the radius-inset room boundary and extends to a handoff boundary at local Garage `z = 3.85 m`, just beyond the sectional door.
- Crossing that boundary while walking creates a presentation-only handoff containing the player position and facing.
- Atlantis maps the local pose to its existing Founder Garage world anchor, enters walking mode on the authored driveway, resolves ground/collision, and immediately uses the existing district loader and streaming coordinator.
- Atlantis district movement, resident/prefetch protection, collision, grounding, landmarks, interactions, and batching remain the existing implementations. No second city movement or streaming system was added.
- Approaching the existing Founder Garage interaction in Atlantis dismisses the city surface and returns to the authored Garage doorway approach. The chair route still ends at the exact canonical Founder POV.
- The covered Garage world is retained and parked at its authored interior approach, preventing accumulated coordinate drift across repeated scene swaps.
- GameStore, simulation time, finance, progression, and save state are not mutated by camera movement or the handoff.

The RealityKit Garage, Garage-to-city handoff, Atlantis district loader, streaming runtime, world presentation model, and traversal controls now compile in Release and form the default production route. The legacy SwiftUI Garage remains available only through the explicit `--founder-garage-legacy` test/fallback argument. While Explore is active, the movement pad owns its drag gesture so the full-screen seated Free Look recognizer cannot consume locomotion input.

## Defect 3 — right-side personnel door

### Root cause

The V7 USDZ hierarchy contained `Garage_RightWall` as a solid wall and did not contain a right-side door entity, hidden door, misplaced transform, or runtime-culled door. The omission was in the authored production package rather than the presentation visibility code.

### Asset repair

A new rollback-safe V8 production asset was promoted instead of overwriting V7:

- `App/RealityKit/FounderGarage/founder_garage_v8.usdz`
- SHA-256: `d297d7a144ab3fc8e5b917226d492c4b2d6de3d05f4e46c3419895e3712450a4`
- deterministic source overlay: `Documentation/FounderGarage/AnimationPassA1/founder_garage_v8_overlay.usda`
- deterministic rebuild script: `Documentation/FounderGarage/AnimationPassA1/build_v8.py`

V8 preserves the complete V7 hierarchy, scale, cameras, lights, sectional door, materials, and all canonical anchors. It adds `RightSideAccessDoor` under the authored Shell with a 2.1 m class panel, dark jambs/header, threshold, handle plate, and cylindrical handle. Its measured visual center is approximately `[2.43, 1.08, 0.78]` meters in Garage space. The door is static by design for this pass.

Runtime enclosure visibility keeps the door paired with the right wall: visible in Founder and inspection views and hidden only when Garage Overview deliberately removes that wall for the existing cutaway.

The Xcode project change is limited to the four explicit file-reference/resource-membership entries required to copy V8 into the app bundle. The shared scheme was not changed.

## Device behavior and visual evidence

Both simulator form factors ran the same production Garage flows. Viewport normalization removed the prior iPad over-rotation: the 48%-width yaw gesture frames the personnel door on both devices, while repeated gestures reach the rear left and rear right views.

### iPhone 17 Pro Max simulator

- [evidence manifest](AnimationPassA1/iPhone17ProMaxFinal/manifest.json)
- [forward Founder POV](AnimationPassA1/iPhone17ProMaxFinal/361F0A7A-7C6A-4310-B5EF-16A03D2CB28D.png)
- [right-side door / single yaw gesture](AnimationPassA1/iPhone17ProMaxFinal/C1D91AFA-898F-4EA3-AEC9-CCCB81ACB1E4.png)
- [rear left inspection](AnimationPassA1/iPhone17ProMaxFinal/E9C27772-D41A-45E0-9C07-9BFD356B509D.png)
- [rear right inspection](AnimationPassA1/iPhone17ProMaxFinal/DE00BBC7-9A4D-424B-856E-06B81B6549CA.png)
- [exact recentered view](AnimationPassA1/iPhone17ProMaxFinal/41422660-877A-4EDB-A81E-CA5BA304BF39.png)

### iPad Air 11-inch (M4) simulator

- [evidence manifest](AnimationPassA1/iPadAir11M4Final/manifest.json)
- [forward Founder POV](AnimationPassA1/iPadAir11M4Final/41803105-DA73-44A3-AD59-CF8580253B1E.png)
- [right-side door / single yaw gesture](AnimationPassA1/iPadAir11M4Final/B292795C-DCDD-4B5C-8949-AC7CFD3B9841.png)
- [rear left inspection](AnimationPassA1/iPadAir11M4Final/9ED26840-4C1B-43BE-800A-6A9FE41FE6FD.png)
- [rear right inspection](AnimationPassA1/iPadAir11M4Final/07B2FE9E-5D2D-464F-82A5-D11C98C81600.png)
- [exact recentered view](AnimationPassA1/iPadAir11M4Final/5C7C4D63-CAAF-4F49-B0B4-1EA17F31724E.png)

Signed device builds were also installed and launched successfully on:

- physical iPhone 16 Pro (`iPhone17,1`)
- physical iPad Air 11-inch (M4) (`iPad16,8`), including the corrected Release build with no launch flags

Automated tests and successful launches do not establish final visual, touch, animation, or route quality on physical hardware.

## Verification

| Check | Result |
|---|---|
| V8 OpenUSD package validation | Passed (`usdchecker` success; hierarchy inspected with `usdtree`) |
| Focused Founder Garage RealityKit tests | **121 passed, 0 failed** |
| Complete unit target | **903 passed, 0 failed** |
| iPhone 17 Pro Max UI flows | **2 passed, 0 failed** |
| iPad Air 11-inch (M4) UI flows | **2 passed, 0 failed** |
| iPhone production Garage-to-Atlantis route | **1 passed, 0 failed** |
| iPad production Garage-to-Atlantis route | **1 passed, 0 failed** |
| Debug simulator build | Passed as part of focused, full-unit, and UI test runs |
| Signed Release device build with Atlantis enabled | Passed |
| Signed physical-device build | Passed |
| Physical iPhone install/launch | Passed |
| Physical iPad install/launch | Passed |
| `git diff --check` | Passed |
| Save version | **20** |

Focused coverage includes broad left/right and rear inspection, viewport-normalized gesture response, exact recenter, zero roll, 100-cycle drift protection, pitch clamps, fixed seated position, Reduce Motion, valid standing spawn, wall/desk/door collision, open-door handoff, Garage/Atlantis coordinate mapping, return placement, GameStore isolation, V8 integrity, and stable door visibility/transform. The full unit run also executes the existing Atlantis district identity, real asset load/unload, streaming protection, grounding, collision, continuous route, and canonical-state isolation tests.

Result bundles:

- focused: `/tmp/solo-a1-repair-focused-final/Logs/Test/Test-Solo Unicorn Run-2026.09.14_17-41-27--0400.xcresult`
- complete unit target: `/tmp/solo-city-full-unit-final.xcresult`
- iPhone UI: `/tmp/solo-a1-phone-ui-final2.xcresult`
- iPad UI: `/tmp/solo-a1-ipad-ui-final.xcresult`
- iPhone production Garage-to-Atlantis route: `/tmp/solo-city-iphone-handoff-final.xcresult`
- iPad production Garage-to-Atlantis route: `/tmp/solo-city-ipad-handoff-7.xcresult`

## Remaining human acceptance

The repair is classified **GO WITH HUMAN ACCEPTANCE** because these direct observations still require a person on both physical devices:

1. confirm the widest seated yaw has no body/chair clipping at intermediate angles;
2. walk the full route from chair through all Garage circulation areas, open the sectional door, enter Atlantis, deliberately leave the expected route, traverse connected districts, and return to the exact chair pose;
3. judge side-door proportion, material response, handle readability, and enclosure continuity under each time-of-day preset;
4. confirm long walking sessions and district streaming feel stable on hardware.

No commit, push, merge, reset, rebase, clean, or staging operation was performed.
