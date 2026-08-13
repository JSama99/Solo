# Build 19.1 Test Report

`xcodebuild -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO`

- 173 tests executed; 168 passed, 5 failed.
- All Build 19.1 garage and product-content assertions passed.
- The five failures are existing save-migration fixture lookups in `GameStoreTests` (v2/v3/v4/build6), unrelated to this change. The build also reports the pre-existing duplicate PBX file-reference warnings for AchievementStore, FacilityUpgrade, EmpireTaskExpansion, Build10HeadquartersTests, and ContentLibraryTests; they were not changed because they require project-file surgery outside this remediation.
