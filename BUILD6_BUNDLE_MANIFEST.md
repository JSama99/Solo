# SOLO: UNICORN RUN — Build 6 Bundle Manifest

## Project

- `SoloUnicornRun.xcodeproj/`
- `Project.json`
- `App/`
- `Tests/`
- `ReferenceAssets/`
- `appStoreConnect/`

## Build 6 documentation

- `BUILD6_READ_ME_FIRST.md`
- `BUILD6_CHANGELOG.md`
- `BUILD6_GAMEPLAY_DESIGN.md`
- `TEST_REPORT_BUILD6.md`
- `BUILD6_BUNDLE_MANIFEST.md`

## Preserved prior documentation

- `BUILD2_CHANGELOG.md`
- `BUILD3_CHANGELOG.md`
- `BUILD4_CHANGELOG.md`
- `BUILD4_GAMEPLAY_DESIGN.md`
- `BUILD5_CHANGELOG.md`
- `REVENUECAT_SETUP.md`

## Main modified production files

- `App/GameModels.swift`
- `App/GameStore.swift`
- `App/ContentLibrary.swift`
- `App/SimulationEngine.swift`
- `App/DoctrineProfile.swift`
- `App/Hindsight.swift`
- `App/ContentView.swift`
- `App/VentureCheckpointScreen.swift`
- `App/VentureUnlockScreen.swift`
- `App/Info.plist`
- `Project.json`
- `SoloUnicornRun.xcodeproj/project.pbxproj`

## Modified test files

- `Tests/ContinuousModeTests.swift`
- `Tests/FounderPassGateTests.swift`
- `Tests/GameStoreTests.swift`
- `Tests/SimulationEngineTests.swift`

## Release checklist

- [x] Build number incremented to 4
- [x] Save schema incremented to v8
- [x] Build 5 saves supported
- [x] Deterministic deck state persisted
- [x] Founder Pass checkpoint flow corrected
- [x] RevenueCat configuration tests corrected
- [x] All Swift source parsed
- [x] Core source type-checked
- [x] 133 adapted tests passed with no skips
- [x] Deterministic smoke test passed
- [ ] Full Xcode/iOS test run
- [ ] Manual SwiftUI layout review
- [ ] RevenueCat sandbox purchase and restore test
- [ ] Signed archive validation
