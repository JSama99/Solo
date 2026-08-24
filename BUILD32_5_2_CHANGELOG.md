# Build 32.5.2 Changelog

Date: 2026-08-24  
Canonical implementation commit: `9f1268e`

## Changed

- Replaced independent screen-relative room offsets with one deterministic `FounderEnvironmentLayout` world and world-to-viewport projection.
- Built materially different left, center, and right Garage zones around the unchanged `FounderComputerScreen`.
- Grounded the Founder monitor on a foreground desk with stand, keyboard, pointing device, review tray, mug, cabling, and floor perspective.
- Added large, role-specific Aurora, Stacks, and Brio station silhouettes using the existing portraits.
- Replaced tiny upgrade markers with physical silhouettes for Development Rig, Verification Array, Campaign Studio, Recovery Corner, and Founder Command Desk.
- Replaced “3D Look Around” with “Look Around” and moved Free Look controls to a compact bottom rail.
- Preserved Free Look-only room dragging, relative drag accumulation, bounded camera state, monitor-only return interaction, and canonical computer identity.
- Added a shared XCTest scheme that resolves the existing local RevenueCat Swift package without changing monetization code or target membership.
- Added deterministic panoramic layout tests and fresh production screenshots.

## Files

- `App/FounderEnvironmentScreen.swift`
- `Tests/Build32_4SpatialCausalityTests.swift`
- `SoloUnicornRun.xcodeproj/xcshareddata/xcschemes/Solo Unicorn Run.xcscheme`
- `VisualProof/Build32_5_2/`
- Build 32.5.2 documentation files

## Preserved

No simulation, seeded RNG, scoring, evidence, save schema, Founder Review, resolution, duplicate-action, Tech.com, Hindsight, facility-bonus, or RevenueCat behavior was changed.

## Completion status

Source, build, automated tests, screenshot catalog, and manual interaction acceptance passed. The requested MP4 is not present because BitRig's built-in simulator exposes screenshots and interaction controls but no recording/export API, and it is not attached to `simctl`. Build 32.5.2 therefore remains incomplete against the user's explicit video gate.
