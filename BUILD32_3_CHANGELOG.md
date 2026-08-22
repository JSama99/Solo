# Build 32.3 Changelog

## Outcome

Company Command is now a layered first-person company scene instead of three equal profile cards. Founder Command leads the foreground, workstation bays occupy the middle plane, facility structure sits behind them, and installed equipment appears at its physical point of use.

## Production changes

- Preserved `CompanyCommandViewport`, `LivingAgentProjection`, all canonical handlers, stable IDs, secrecy, deterministic simulation, save schema, RevenueCat, and the single paused-aware 18 Hz clock.
- Increased the standard overview from 258 to 336 points and focus from 458 points only when needed; accessibility uses 430/600 points. The viewport remains above the workstation stack.
- Added deterministic dominant-station selection. Selected/recent active work leads; other active work follows; idle and background systems recede.
- Rebuilt overview stations as recessed bays with role material, monitor overlap, console silhouettes, equipment rails, depth lighting, and facility-specific placement.
- Added three stable causal object families: role-colored assignment document, mint completed artifact, and purple decision response. Focus no longer hides an in-flight assignment.
- Added a large Founder inspection composition with five purpose-specific layers and four visually distinct final outcomes.
- Installed Development Rig, Verification Array, Campaign Studio, Recovery Corner, and Founder Command Desk into their canonical scene locations while retaining the compact status index.
- Made Garage and Loft structurally different: exposed asymmetric rails/cabling versus wide window bays, skyline structure, cleaner spacing, and organized mounting.
- Replaced the global atmosphere chip/filter treatment with localized low-energy lighting, runway depletion, external-display trust interference, and connected momentum paths.
- Kept only name, safe state, task/attention, primary phase, and essential warning text in overview. Role, level, detailed progress, trust/stress, and full actions remain in focus; equipment names are accessibility-only.
- Clamped spatial labels to Extra Large while canonical workstation content remains unrestricted, preventing viewport collisions at Accessibility Extra Large.
- Added a DEBUG-only, immutable production-component proof runner with a manual/external causal trigger. It never reads or mutates career state.

## Files changed

- `App/CompanyCommandViewport.swift`
- `App/LivingCompanyPresentation.swift`
- `App/MotionVerificationScreen.swift`
- `App/App.swift`
- `Tests/Build32_3SpatialViewportTests.swift`
- `Tests/Build32LivingCompanyTests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `VisualProof/Build32_3/*`
- Build 32.3 documentation files

## Direction estimate

Revised visual-direction estimate: **84%** toward “The Sims for AI solo founders.” It is intentionally not rated above 85% before bespoke Rive character animation, physical-device accessibility verification, and metric-backed Instruments profiling.
