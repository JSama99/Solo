# SOLO: UNICORN RUN — Build 2 Change Log

## Release metadata

- Marketing version remains `1.0`.
- Build number is `2` in `Project.json`, `App/Info.plist`, and both Xcode target configurations.
- Bundle identifier remains `com.talonsight.solounicornrun`.
- Deployment target remains iOS 18 and iPhone portrait remains the supported interface orientation.

## Living Founder Garage

- Replaced the static garage dashboard with a reusable `FounderEnvironmentScreen` and a SwiftUI-native 2.5D `FounderGarageEnvironment`.
- Added proportional cyan, amber, coral, and founder-desk overlays; agent presence markers; assignment paths; Founder Review scans; evidence receipts; verified, overclaim, drift, and load treatments; and visible equipment stages.
- Added restrained numeric transitions for company and agent metrics.
- Added staged, presentation-only sprint results and distinct venture-completion, victory, bankruptcy, burnout, and trust-collapse treatments.
- Kept simulation assignment, review, commit, evidence, and outcomes synchronous. Presentation events are ephemeral and are not encoded in career saves.

## Approved garage asset

- Preserved the exact approved 3840×2160 PNG at `ReferenceAssets/FounderGarage-4K.png` (SHA-256 `0ab4b85dda7f57228413ee83477a52c223e7678b7dcb8b31796b69e7062fa6f7`).
- Replaced the former JPEG asset with 480×270, 960×540, and 1440×810 PNG catalog renditions.
- The 4K source is outside `App/` and is not bundled. The compiled `Assets.car` is 3.4 MiB; the largest garage rendition has an approximately 4.45 MiB RGBA decode footprint instead of approximately 31.64 MiB for the 4K source.

## Headquarters progression

- Added all six ordered facility tiers and centralized the approved track-record, capital, and completed-career requirements.
- Added a Headquarters Progress screen with current tier, next-tier progress, requirements, and locked Future Environment states.
- Added a separately versioned founder-progression save with owned facilities, current facility, highest track record, completed career count, active career identity, and recorded career identities.
- Career completion recording is idempotent. Career restart does not clear founder progression.
- Purchase eligibility and transaction foundation is deterministic and consumes no simulation RNG. Future-environment purchases remain unavailable in Build 2 and no facility bonuses were added.

## Hidden-information boundary

- Added `VisibleSimulationProjection` as the presentation boundary for task and sprint displays.
- Visible models omit correlated-failure identifiers, the canonical correlated-failure event, hidden actual quality, and canonical strong/risky flags.
- Actual quality is visible only when the existing verification state permits it. Evidence-incomplete results cannot contribute to verified-strong counts.
- Visible risk counts use only review states and operational risks already visible to the player. Correlated-failure presentation is permitted only after drift detection.

## Accessibility and lifecycle

- Added semantic environment summaries, agent state values, metric values, non-color symbols, and clear verification labels.
- Decorative garage layers are hidden from VoiceOver.
- Reduced Motion replaces staged movement with immediate state presentation.
- Ambient motion is disabled while inactive or backgrounded and resumes without invoking simulation actions.
- Increased Contrast and accessibility Dynamic Type were inspected in the iPhone simulator.

## Added files

- `App/AgentVisualState.swift`
- `App/CareerOutcomeEnvironmentBackdrop.swift`
- `App/EnvironmentPresentation.swift`
- `App/FacilityProgressionConfiguration.swift`
- `App/FacilityTier.swift`
- `App/FounderEnvironmentScreen.swift`
- `App/FounderGarageEnvironment.swift`
- `App/FounderProgressionSave.swift`
- `App/FounderProgressionStore.swift`
- `App/HeadquartersProgressScreen.swift`
- `App/PresentationCoordinator.swift`
- `App/PresentationPolicy.swift`
- `App/VisibleSimulationProjection.swift`
- `Tests/FacilityProgressionTests.swift`
- `Tests/PresentationMappingTests.swift`
- `ReferenceAssets/FounderGarage-4K.png`

## Modified files

- `App/App.swift`
- `App/ContentView.swift`
- `App/Assets.xcassets/FounderGarage.imageset/Contents.json`
- `App/Info.plist`
- `Project.json`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `Tests/GameStoreTests.swift`

## Remaining limitations and next pass

- Founder Loft and later environments remain intentionally locked until approved references are supplied.
- Build 2 does not expose a facility-purchase control because no available environment can be purchased yet.
- Process-wide Instruments profiling was not available in the built-in simulator; asset dimensions, compiled resource size, decode bounds, device builds, and interactive scrolling were verified instead.
- Reduced Motion behavior was executed through deterministic policy tests; the simulator connector did not expose the system Reduce Motion switch for a manual visual toggle.
- The recommended next environment pass is Founder Loft: supply portrait-safe wide reference art plus workstation coordinates, equipment stages, lighting palette, accessibility description, and ending variants before enabling the Loft purchase.
