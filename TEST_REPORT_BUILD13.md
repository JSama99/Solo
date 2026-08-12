# Build 13 Test Report

## Final validation

- Toolchain: Xcode 17 with iOS 26.5 Simulator SDK.
- Project: `SoloUnicornRun.xcodeproj`.
- Scheme: `Solo Unicorn Run`.
- Destination: iPhone 17 Pro Simulator.
- Clean build command: `xcodebuild -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`.
- XCTest command: `xcodebuild -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test CODE_SIGNING_ALLOWED=NO`.
- Both commands completed successfully after compiling TechComEngine, TechComScreen, and the two Build 13 test suites.
