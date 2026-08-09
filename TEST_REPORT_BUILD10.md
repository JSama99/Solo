# Build 10 Test Report

## Xcode validation

- Toolchain: Xcode with iOS 26.5 Simulator SDK.
- Project: `SoloUnicornRun.xcodeproj`.
- Scheme: `Solo Unicorn Run`.
- Destination: iPhone 17 Pro Simulator (`BB7F5B18-B85E-4DA2-BBE2-999B432E9916`).
- Command: `xcodebuild test -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,id=BB7F5B18-B85E-4DA2-BBE2-999B432E9916'`.

## Results

- Build: passed.
- XCTest: 144 executed, 144 passed, 0 failures, 0 unexpected failures, 0 skipped.
- App launch: passed. The resulting debug build was installed and launched on the iPhone 17 Pro Simulator.

## Project membership correction

The Xcode project had stale source membership for Build 10 files and several already-present sources. The project was updated so Xcode compiles the same app and test sources as the Bitrig project build.
