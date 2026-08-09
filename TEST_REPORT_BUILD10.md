# Build 10 Test Report

## Xcode validation

- Toolchain: Xcode with iOS 26.5 Simulator SDK.
- Project: `SoloUnicornRun.xcodeproj`.
- Scheme: `Solo Unicorn Run`.
- Destination: iPhone 17 Pro Simulator (`BB7F5B18-B85E-4DA2-BBE2-999B432E9916`).
- Command: `xcodebuild test -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,id=BB7F5B18-B85E-4DA2-BBE2-999B432E9916'`.

## Results

- Build: passed.
- XCTest: 167 executed, 167 passed, 0 failures, 0 unexpected failures, 0 skipped.
- App launch: not exercised in this validation pass.

## Post-merge validation

- Baseline after the Build 9/Build 10 restoration: 163 test functions.
- Post-merge fixes add four tests for facility rendering and command-deck commit behavior.
- The full XCTest suite was run after each of the five focused changes; the final run completed with 167 passing tests.

## Project membership correction

The Xcode project had stale source membership for Build 10 files and several already-present sources. The project was updated so Xcode compiles the same app and test sources as the Bitrig project build.
