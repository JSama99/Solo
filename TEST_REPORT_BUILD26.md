# Build 26 Test Report

Offline dependency resolution passed: `xcodebuild` reported `Resolved source packages: RevenueCat: .../Packages/purchases-ios-spm @ local` with no network fetch.

Final offline command: `xcodebuild -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run Tests" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -derivedDataPath /Users/jermainenelson/Library/Bitrig/Users/22715/Builds/04f35a27-af69-4583-abb3-2d17e4965680/Build26 test CODE_SIGNING_ALLOWED=NO`.

Result: **PASS — 199 tests, 199 passed, 0 failed.** This is the standing report format for subsequent builds.

App verification: `xcodebuild -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -derivedDataPath /Users/jermainenelson/Library/Bitrig/Users/22715/Builds/04f35a27-af69-4583-abb3-2d17e4965680/Build26 build CODE_SIGNING_ALLOWED=NO` completed with `BUILD SUCCEEDED`; its output includes `RevenueCat_RevenueCat.bundle` and `RevenueCat_RevenueCatUI.bundle` in the app bundle.
