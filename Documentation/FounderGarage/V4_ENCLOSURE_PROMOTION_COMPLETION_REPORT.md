# Founder Garage V4 Enclosure Promotion Completion Report

Date: 2026-09-08  
Branch: `codex-solo-next`  
Revision inspected: `2fb1cef` plus the existing uncommitted RealityKit work

## Production promotion

The previous production path loaded `founder_garage_v3.usdz`. The production RealityKit view now requests `founder_garage_v4.usdz` with a dedicated V4 descriptor. V3 remains bundled as a rollback/reference asset, and controlled V4 load or validation failure still restores the existing procedural Garage.

The supplied source was `Founder's Garage v4_EnclosureRepair.usdc` (1,731,604 bytes, SHA-256 `2ce07cc2545e6f8a6cdf718795414be735dcadff1280e8f53c6feca858648868`). Its geometry and metadata use the established Y-up coordinates, but the raw stage header was stamped Z-up. The production package changes only that stage declaration to Y-up and includes the four referenced textures.

Production package:

- File: `App/RealityKit/FounderGarage/founder_garage_v4.usdz`
- Size: 2,278,669 bytes
- SHA-256: `15732cfff3a98bebbd9fa528853292572f7f2cb30ad35f7d72faf206a7566f4e`
- Default/root prim: `root`
- Root transform ops: none
- Stage up-axis: Y
- Metres per unit: 1
- `usdchecker`: success; the installed USD tool emitted its known duplicate behavior-registration diagnostics before the successful result

## Spatial contract and anchors

V4 retains the Facility Tier 0 contract: 5.00 m wide, 5.50 m deep, 2.70 m high; Y-up; +X right; +Z toward the Garage mouth; floor at Y = 0; native scale 1.0. The runtime applies no root scale, translation, or orientation compensation.

- Expected canonical anchors: 20
- Imported canonical anchors: 20
- Renamed: 0
- Deleted: 0
- Maximum Euclidean transform drift: 0.000000234 m (`Anchor_Camera_Iso`), consistent with exporter-level Float precision
- Runtime acceptance tolerance: 0.001 m

## Enclosure and visibility

The production hierarchy contains and renders the completed `Garage_RightWall`, `Ceiling`, `GarageDoor_Panel`, header, left/right frames, seals, jamb returns, and left/right vertical, curved, and horizontal tracks. The normal Founder POV, free-look, Whiteboard, FrontBay, Garage Door, and Front views retain the full enclosure. Garage Overview alone hides `Garage_RightWall` and `Ceiling` through one centralized camera-specific visibility function so the exterior isometric camera can read the room. Door geometry and tracks remain visible in the Overview.

Direct RealityKit bounds and material assertions cover the right wall, ceiling, door panel, and right track. Device captures show no missing, transparent, black, or unintended default material on those surfaces. The inspected views show no obvious wall/floor, wall/ceiling, door/frame, or track shadow artifact. Exact visual and shadow quality remains a simulator/device acceptance judgment rather than a unit-test claim.

## Garage door operation

After the V4 promotion brief was supplied, the user explicitly requested that the door open and close. That later direction expands the original brief's animation exclusion.

The production door now has session-only `closed` and `open` presentation states. An accessible control appears in Garage Door View and Front View. Opening moves all five independent authored sections from the vertical opening onto the horizontal overhead tracks and moves the handle with section 02. The frame, header, seals, and tracks remain static. Closing restores every authored local transform exactly. A new request stops the prior playback before reversing, and Reduce Motion applies the destination transforms without interpolation.

The door state does not enter `GameStore`, saves, progression, or simulation. It resets to closed when the V4 architecture is installed. The control has a 44-point minimum target, explicit Open/Close label, current Open/Closed accessibility value, hint, and stable identifier `founderGarage.realityKit.garageDoor.toggle`.

## Navigation discovered and validated

The current production implementation contains Founder POV, bounded yaw/pitch free-look, recenter, Garage Overview, Whiteboard View, FrontBay View, Garage Door View, Front View, and presentation-only seated player-root state. `standing` and `walking` remain future enum values without production controllers. There is no locomotion, player collision, proximity activation, exterior traversal, or player-height motion in the current code. The static walkable-region and semantic-zone contracts do not implement movement.

Because walking and player collision do not exist, walking routes, right-wall blocking, closed-door blocking, ceiling collision, and navigation-trap claims are not applicable to this revision. No locomotion or collision architecture was added during the V4 pass.

Free-look retains its previous limits, eye origin, no-roll behavior, no-translation behavior, drag gesture, and recenter. iPhone and iPad captures cover neutral, offset, yaw limit, both pitch limits, and recentered states. No V4-driven limit change was needed.

## Camera regression

| Camera | Result | V4 adjustment | Reason |
| --- | --- | --- | --- |
| Founder POV | Passed | None | Monitor remains centered and front-facing from the canonical seated eye; enclosure is visible without clipping. |
| Garage Overview | Passed | Right wall and ceiling hidden only in this view | The complete enclosure otherwise blocks the exterior isometric reading. |
| Whiteboard | Passed | None | Existing anchor and composition remain valid. |
| FrontBay | Passed | None | Existing anchor and composition remain valid. |
| Garage Door | Passed | Position, target, and FOV only | The old crop omitted parts of the repaired full door. New recipe: door anchor + `[2.50, 1.10, 8.80]`, target + `[0, 0.05, -0.05]`, FOV 64 degrees. |
| Front | Passed | Position, target, and FOV only | Centers the complete door straight-on. New recipe: door anchor + `[0, 0.25, 9.45]`, target + `[0, 0.05, -0.05]`, FOV 64 degrees. |

## Lighting and performance

The existing bounded production lighting remains usable with the new enclosure. Founder desk, monitor, rear wall, right wall, ceiling, whiteboard, FrontBay, and garage door remain legible in the tested views. No lighting intensity, monitor emission, or material override was changed.

Direct packaged-stage comparison:

| Metric | V3 | V4 | Delta |
| --- | ---: | ---: | ---: |
| Mesh prims | 84 | 106 | +22 |
| Triangulated faces | 35,986 | 37,450 | +1,464 |
| Materials | 17 | 17 | 0 |
| Texture files | 4 | 4 | 0 |
| Asset size | 2,240,820 B | 2,278,669 B | +37,849 B (1.7%) |

The old embedded V2 audit metadata reports historical source counts, so the table uses direct counts from the current packaged stages. Both device suites loaded V4 successfully. No standalone import-time or memory benchmark was added; test and build behavior did not expose a load failure or major regression.

## Preservation

This pass does not modify `GameStore`, save version 19, RNG ordering, simulation rules, progression, Evidence Ledger, Venture, Tech.com, agent state, monetization, or persistence. Founder Computer still uses the single canonical `openFounderComputer` route, its `Button` semantics, and `founderGarage.realityKit.founderComputer` identifier. The V4 adapter continues to strip input, collision, and physics components from architecture. Existing semantic interaction-zone positions remain anchored to the canonical coordinates.

The Xcode scheme is byte-for-byte unchanged from the pre-pass snapshot. The project-file delta is limited to one V4 file reference, one resource build entry, and membership in the App and Resources groups. Existing unrelated user changes remain untouched.

## Verification

- Focused `FounderGarageRealityTests`: 80 passed, 0 failed, 0 skipped
- Full `Solo Unicorn Run Tests`: 767 passed, 0 failed, 0 skipped
- iPhone 17 Pro Max production-continuity selection: 4 passed, 0 failed, 0 skipped
- iPad Air 11-inch (M4) production-continuity selection: 4 passed, 0 failed, 0 skipped
- iPhone 17 Pro Max scheme build: succeeded
- iPad Air 11-inch (M4) scheme build: succeeded
- `git diff --check`: passed
- Warning: existing unused `taskID` warning in `Tests/WorkSessionEngineTests.swift:320`

The selected UI regression set covers the canonical Founder Computer round trip, every authored RealityKit camera, door open and close, bounded free-look and recenter, and the legacy SwiftUI Garage fallback. Evidence is stored under `FounderGarageV4/iPhone` and `FounderGarageV4/iPad` in the task's visualization directory.

## Files changed in this pass

- `App/FounderGarageRealityScene.swift`
- `App/FounderGarageRealityView.swift`
- `App/FounderWorldPresentationModel.swift`
- `App/RealityKit/FounderGarage/founder_garage_v4.usdz`
- `Tests/FounderGarageRealityTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `Documentation/FounderGarage/V4_ENCLOSURE_PROMOTION_COMPLETION_REPORT.md`

## Visual result

Yes. V4 now behaves as the production Founder Garage while preserving the implemented navigation experience. The room is enclosed in normal views, Founder POV remains centered, all authored views remain selectable, bounded free-look and recenter remain stable, the Founder Computer route survives repeated round trips, and the completed sectional door now opens and closes.

The walking-specific success question is not applicable because production walking, player collision, and proximity movement are not implemented in this revision.
