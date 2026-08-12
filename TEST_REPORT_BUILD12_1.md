# Build 12.1 Test Report

## Final validation

- Toolchain: Xcode 17 with iOS 26.5 Simulator SDK.
- Project and scheme: `SoloUnicornRun.xcodeproj`, `Solo Unicorn Run`.
- Destination: iPhone 17 Pro Simulator.
- Build: `xcodebuild -quiet -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO` completed successfully.
- XCTest: `xcodebuild -quiet -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test CODE_SIGNING_ALLOWED=NO` completed successfully.
- Result: all XCTest methods in `Tests/` passed with 0 failures. Xcode emitted pre-existing duplicate project-reference warnings only.
