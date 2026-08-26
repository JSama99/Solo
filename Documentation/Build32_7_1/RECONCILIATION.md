# Build 32.7.1 Reconciliation

## Baseline

- Inspected revision: `783da9282c94319eb046a8206758480325baeba4`
- Architecture found: `FounderDeskWorkspace` with stable mounted feature screens and `FounderDeskNavigationState`; retained environment camera/control architecture in `FounderEnvironmentScreen`.

## Navigation parity

| Physical object | Canonical destination |
| --- | --- |
| Founder Computer | `FounderComputerScreen` |
| Tech.com iPhone | `TechComScreen` |
| Venture iPad | `VentureScreen` |
| Company Server | `CompanyServerScreen` |

Server inventory remains complete: Evidence Ledger, Agent Operations, Achievements, Headquarters Progress, Company Story, Solo Pro, Settings, How to Play, and Restart Career. Existing Evidence/Agent Operations handoffs still target canonical Founder Computer modules.

## State and truth boundary

The existing `GameStore`, `PresentationCoordinator`, `FounderProgressionStore`, `AchievementStore`, feature views, and gameplay actions are reused. The presentation coordinator is the expanded `FounderDeskNavigationState`, which owns selection plus the existing camera value. `FounderDeskPreviewInput` remains the narrow visible-state boundary; lighting, rack state, previews, colors, icons, and accessibility descriptions derive only from that contract.

## Removed obsolete behavior

The workspace's synthetic always-free-look camera and disconnected noninteractive overview projection were removed. The visible tab bar remains absent; no parallel route/store/camera system was added.

## Changed production files

- `App/FounderDeskWorkspace.swift`
- `App/FounderDeskWorkspaceModel.swift`
- `App/FounderEnvironmentScreen.swift`
- `Tests/FounderDeskWorkspaceTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`
- `Project.json`
- `SoloUnicornRun.xcodeproj/project.pbxproj`

Build version is 32.7.1 (32701). Visual-direction estimate: **98%**.
