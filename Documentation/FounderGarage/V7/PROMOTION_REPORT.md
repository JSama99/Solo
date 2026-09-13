# Founder Garage V7 exterior promotion and environmental presentation

Status: V7 is integrated and four-state rendering is implemented. Final human visual acceptance remains open; the complete Definition of Done is not claimed.

## Baseline and scope

The supplied brief described V4. Static inspection found the dirty worktree already requested V6, with four time states and a DEBUG menu. This pass extends that implementation. V4 and V6 packages/descriptors remain reference assets; failed V7 integrity, loading or spatial validation restores the procedural Garage. The existing renderer selection remains unchanged (RealityKit is selected through the existing development launch configuration); this does not switch the release SwiftUI renderer.

## Production package

- Historical baseline: `App/RealityKit/FounderGarage/founder_garage_v4.usdz`.
- Previous requested world in this worktree: `founder_garage_v6.usdz`.
- New RealityKit requested world: `App/RealityKit/FounderGarage/founder_garage_v7.usdz`.
- Source: `/Users/jermainenelson/Founder's Garage v7_.usdc`.
- Source SHA-256: `7b22868b58886a9f62738ec7fe2e73355d09ad65c245a523e4619e2bf3f868ed`.
- Packaged SHA-256: `1d1a831f75212a5d378cfa73c5cd32c0d2d94d82db45854f7f7a3fcb75fcf25e`.
- Package size: 2,339,585 bytes.
- Root/default prim: `/root`; root transform operations: none.
- Source axis: Z; packaged axis: Y; metres per unit: 1.
- OpenUSD comparison confirms axis metadata is the only stage change. Texture dependencies are packaged and resolve.
- `usdchecker`: success, with installed tool's duplicate behavior-registration diagnostics.

## Spatial authority and anchors

Interior stays 5.00 × 5.50 × 2.70 m. +X right, +Y up, +Z Garage mouth/exterior; floor Y=0; metre-native scale; origin unchanged. No geometry rotation, recentering, scaling or runtime axis compensation.

20 expected anchors, 20 imported, 0 renamed, 0 missing. V4-to-V7 full world matrices match exactly; maximum packaged-stage Euclidean drift is **0 m**. The canonical runtime tolerance remains **0.001 m**. The runtime validates native exterior bounds [-40, -0.24, -30] to [40, 7.9, 26] without normalizing them.

## Actual exterior hierarchy

The audited USD hierarchy and required runtime names include:

- `Driveway` / `Driveway_Slab`, `DrivewayApron_CurbCut`, `Driveway_Joint`.
- `Threshold_Apron` / `ThresholdPlate`.
- `FrontLawn_L`, `FrontLawn_R`, `FrontYard_L`, `FrontYard_R`, `LandscapeStrip_L/R`.
- `Background/LotGround`, `FarGround`.
- `Curb`, `Curb_L`, `Curb_R`, `Sidewalk`.
- `Street` / `Street_Surface`.
- `ExteriorFacade`, `Facade_Siding_L/R`, `Facade_Fascia`, `Downspout_01`.
- `ExteriorLight_01` / `ExteriorLight_01_Lens`.
- `Landscape`, `Tree_L/R` with trunk/canopy children, `Shrub_01` through `Shrub_04`.
- `Props/Mailbox` with post, flag and box; `UtilityBox`.
- Side fences and surrounding `Blocker_House_*` / `Blocker_Far_*` building forms.
- A separate root-level `RoofCap` survives import and explains the V7 Overview adjustment.

Full semantic paths and bounds are in `package-audit.json`. Driveway begins at Z=2.90 and its top is Y=0; threshold extends to approximately Z=2.895. The intervening 5 mm is backed by the authored lot ground; no runtime geometry repair was made. Lawn, curb and street extend into +Z; large background ground also extends under and behind the Garage below its floor.

All exterior geometry remains loaded independently of door state. Structural input, collision and physics-body components are stripped recursively; imported preview lights and IBL receivers are stripped so runtime presentation owns lighting. No new exterior interaction exists.

## Door and cameras

All five door section transforms and the handle match V4. The animation algorithm, reversal cancellation, 1.2-second timing, exact closed restoration and Reduce Motion endpoint are unchanged. Door state is session-only and changing time does not alter it. Accessibility ID remains `founderGarage.realityKit.garageDoor.toggle`.

| Camera | Result | V7 adjustment | Reason |
|---|---|---|---|
| Founder POV | Canonical composition retained | None | Computer remains centered |
| Garage Overview | Captured on iPhone/iPad; readable | [7, 2.5, 9] → [0, 1, 1.5], FOV 62 | Original elevated view was obstructed by RoofCap |
| Whiteboard | Captured on iPhone/iPad; readable | None | Preserve interior viewpoint |
| FrontBay | Captured on iPhone/iPad; readable | None | Preserve interior viewpoint |
| Garage Door | Outward inspection | [0.2, 1.45, -2.2] → [0, 1.1, 6], FOV 88 | Show the physical threshold-to-street connection from inside |
| Front | Exterior facade inspection | None | Existing view remains useful |

Overview continues to hide only `Garage_RightWall` and `Ceiling`. RoofCap and exterior geometry are not hidden. Camera changes apply only to V7; fallback/reference camera recipes remain available.

Free-look keeps yaw ±80°, pitch −18°…+12°, sensitivity π/900 radians per point, neutral eye and recenter behavior. This bounded seated range does **not** face directly outward; the outward Garage Door camera supplies that inspection. No walking or player translation was added.

## Time and lighting

`FounderEnvironmentTimeState`, `FounderEnvironmentLightingPreset`, and `FounderEnvironmentLightingConfiguration` live in `App/FounderWorldPresentationModel.swift`. `FounderGarageRealityWorld.environmentTimeState` owns the session value. Default is day. The existing DEBUG-only menu selects explicit states. No persistence, clock, random selection, continuous sun loop or weather exists.

Layers are authored geometry/materials, a resolved centralized time preset, and room presentation intensity. A future weather overlay can compose a resolved preset without introducing another simulation authority.

One neutral IBL resource is generated once per world and explicitly assigned to V7. This prevents RealityView's default environment from making night look like daylight. The IBL exponent varies by preset. This uses Apple's [ImageBasedLightComponent](https://developer.apple.com/documentation/RealityKit/ImageBasedLightComponent) and receiver APIs.

| State | Directional position → target | Sun intensity | IBL exponent | Hanging fill | Hanging practical | Desk practical | Exterior practical |
|---|---|---:|---:|---:|---:|---:|---:|
| Morning | [-5.8,4.6,10.5] → [0,0.65,1.1] | 4300 | -1.5 | 650 | 3000 | 1400 | 0 |
| Day | [-2.6,7.2,9.8] → [0,0.55,1] | 5600 | -1 | 450 | 2000 | 1000 | 0 |
| Evening | [7.5,3.2,10.8] → [0,0.6,1] | 2700 | -3.5 | 5000 | 8000 | 3500 | 1200 |
| Night | [-6,6.5,9.5] → [0,0.7,1] | 850 | -5 | 10000 | 12000 | 5000 | 3000 |

Morning is warm with softer ambient; day neutral and clearest; evening reduces ambient and warms sunlight; night has low ambient and warm practical dominance. Runtime intensities retain the existing quality scaling and room-presentation scaling for the four original lights. Exterior practical intensity uses quality scaling and a 5 m attenuation radius. Its position derives from the imported lens bounds plus 3.5 cm outward offset, keeping it spatially attached to the fixture. It does not light the entire street.

## Performance

| Metric | V4 package | V7 package | Delta |
|---|---:|---:|---:|
| Mesh prims | 106 | 165 | +59 |
| Triangles | 37,450 | 38,872 | +1,422 |
| Materials | 17 | 23 | +6 |
| Texture dependencies | 4 | 4 | 0 |
| Package bytes | 2,278,669 | 2,339,585 | +60,916 |

Actual packaged stages were measured, not embedded Blender audit strings. Active dynamic light count: morning/day 4; evening/night 5; plus one IBL component for all V7 states. No state rebuilds the world or light entities. In the final unit run the V4 load/validation test took about 0.33 s and V7 about 0.45 s. These are test-case durations, not isolated load benchmarks or frame-rate evidence.

## Preservation

This pass does not modify GameStore, save version 19, save payload/migrations, simulation rules, RNG, progression, Evidence Ledger, Venture, Tech.com, agents, finance, monetization or persistence. Founder Computer route and accessibility identifiers remain unchanged. Time switches preserve camera/player state and door state in tests. Procedural fallback remains available. No walking, standing controller, collision controller, exterior gameplay or weather was implemented.

## Files changed by this pass

- `App/FounderGarageRealityScene.swift`
- `App/FounderGarageRealityView.swift`
- `App/FounderWorldPresentationModel.swift`
- `App/RealityKit/FounderGarage/founder_garage_v7.usdz` (added)
- `Tests/FounderGarageRealityTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj` (four precise V7 resource membership lines)
- `Documentation/FounderGarage/V7/verify_package.py` (added)
- `Documentation/FounderGarage/V7/package-audit.json` (added)
- `Documentation/FounderGarage/V7/PROMOTION_REPORT.md` (added)

No deletions. Existing dirty changes, including the shared scheme, were preserved. No commit or push.


## Verification and evidence

- Final full unit suite: **784 passed**, zero failures/skips, `/private/tmp/solo-v7-final-unit.xcresult`.
- Focused `FounderGarageRealityTests`: **97 passed** within that final run. Earlier promotion-only focused run: 94 passed.
- Final four environment UI tests: **4 passed per device**, zero failures, split between `solo-v7-final-{phone,pad}-day-night.xcresult` and `solo-v7-final-{phone,pad}-morning-evening.xcresult` under `/private/tmp`.
- Final iPad navigation-continuity tests: **4 passed**, zero failures/skips, `/private/tmp/solo-v7-final-pad-continuity.xcresult`. Final iPhone navigation-continuity tests: **4 passed**, zero failures/skips, `/private/tmp/solo-v7-final-phone-continuity.xcresult`. Each device therefore passed 8 selected UI tests: four time-state capture tests and four navigation regressions.
- iPhone 17 Pro Max build: passed.
- iPad Air 11-inch (M4) build: passed.
- `git diff --check`: passed.
- Save version remains 19. Shared scheme matches pre-pass snapshot byte-for-byte.
- New compiler warnings: none reported. Initial clean compilation reported the pre-existing unused `taskID` warning at `Tests/WorkSessionEngineTests.swift:320`.
- OpenUSD verification passes, including actual Y-up/metre/root metadata, all texture paths, full anchor matrices, unchanged door transforms and metadata-only source comparison.
- Environment/tool incidents: initial macOS asset-inspection compile encountered an existing `/tmp` versus `/private/tmp` module-cache conflict; a fresh cache compiled successfully. Sandboxed RealityKit inspection exited 133; escalated inspection succeeded and confirmed V7 bounds. Two long UI tool calls timed out after 300 seconds, but their xcresult bundles recorded successful tests. The night tuning capture included a Simulator SpringBoard crash attachment; the SOLO UI test passed. These are not hidden as test failures or app crashes.
- An initial UI selection used the filename's `Build32_6_1` rather than the actual class `Build32_6_2`, and ran zero tests. It is excluded from pass counts.

Final image evidence: `/Users/jermainenelson/.codex/visualizations/2026/09/09/01a08568-8d29-7482-8608-00f03b3a0d0e/FounderGarageV7/`, with **44 PNGs each** in `iPhone/` and `iPad/`, plus `EVIDENCE.md`. Filenames encode state, camera, door state and free-look endpoint. Earlier tuning captures are retained in `/private/tmp` and are not presented as final.

## Visual assessment and remaining acceptance gaps

- Exterior: the outward Garage Door camera reveals connected driveway, lawn, curb, street and mailbox. No floating driveway, gross terrain intrusion or black doorway void appeared in inspected captures. However, the distant authored building forms remain conspicuously simple, and a flat horizon is visible between them. I cannot certify the brief's stronger “not an unfinished environment” art-quality criterion.
- Day/night: the four presets are visibly different. Morning has a softer warm source and long shadows; day is brightest and neutral; evening is dimmer with warm direction and practical fill; night has a dark exterior with warm occupied interior. Whiteboard and Front Bay remain legible at night. Physical device exposure/readability remains a human acceptance check.
- Founder POV: the Computer remains the dominant centered focal point in all four inspected states. The canonical seated direction does not show the door directly.
- Door: open and closed endpoints look coherent with V7 and the animation implementation is retained. Captures and automated endpoint tests do not prove every intermediate animation frame is artifact-free.
- Lighting continuity: the open threshold connects interior and exterior lighting without a state-driven exposure pop. The original directional shadow setup remains; exhaustive opaque-panel light-leak evaluation at every camera and motion frame is not certified.
- Free-look: preserved limits and recenter are verified. The requested “seated free-look facing exterior” capture cannot be fulfilled with the preserved ±80° range and canonical seated heading. Expanding it would violate the brief's instruction to preserve limits absent a clipping defect, so it remains unchanged.

### Final assessment questions

1. **V7 as the active RealityKit world with a coherent physical exterior?** Yes for the existing RealityKit route and spatial connection. Full exterior-art acceptance remains open; default/release renderer selection is unchanged.
2. **Four distinct production-usable states without simulation/persistence/navigation/door changes?** Distinct states and isolation are verified; final production visual acceptance is not asserted.
3. **Stable foundation for Seated → Standing and Walkable Garage?** The unchanged coordinate/anchor contract is a suitable spatial starting point. Walking, collision and traversal readiness are untested and not certified by this pass.

Consequently, this report does **not** mark all three answers unconditionally yes or declare the entire requested Definition of Done complete.
