# Build 26 — Offline Toolchain

Build 26 uses Approach A: the resolved RevenueCat 5.43 package is vendored at `Packages/purchases-ios-spm` and the Xcode project uses `XCLocalSwiftPackageReference`. The app target necessarily depends on the package graph, so removing UI imports alone could not make test builds offline.

Offline verification: run `xcodebuild -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run Tests" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -derivedDataPath <writable-path> test CODE_SIGNING_ALLOWED=NO`. The package resolver reports the local RevenueCat path and does not contact GitHub. Use the corresponding `build` command with the app scheme to validate the linked application.

RevenueCat remains linked to the app target and entitlement behavior is unchanged. The import-boundary test prevents new non-subscription code from importing it.
