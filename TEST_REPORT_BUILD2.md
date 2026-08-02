# SOLO: UNICORN RUN — Build 2 Verification Report

## Final result

- Date: August 2, 2026
- SDK and simulator OS: iOS 26.5
- Final test device: iPhone 17 Pro Max simulator
- Tests: 50 passed, 0 failed, 0 skipped, 0 expected failures
- Clean build: succeeded
- Compiler/build diagnostics: 0 warnings, 0 errors
- Build metadata: version 1.0 (2)

## Commands executed

```sh
xcodebuild -quiet -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" -configuration Debug test CODE_SIGNING_ALLOWED=NO -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"

xcodebuild -quiet -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" -configuration Debug clean build CODE_SIGNING_ALLOWED=NO -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"
```

The final XCTest result bundle reported 50 passed tests and a `Passed` result. The final test command and clean-build command both exited with status 0.

## Deterministic and compatibility verification

- All prior deterministic simulation, cached-report, hidden-quality, review, evidence, intent-locking, migration, venture, and career tests remain passing.
- An explicit Build 1 v4 compatibility test encoded and loaded a v4 career save without changing the career schema.
- Founder progression uses a separate v1 persistence key and survives career restart.
- Re-recording the same terminal career is idempotent; a new career can be counted once under a new identity.
- Facility eligibility and purchase foundation do not call simulation resolution or RNG.

## Hidden-information verification

- Pre-review task projection does not expose hidden actual quality or a correlated-failure identifier.
- A correlated failure becomes visually detectable only for a legitimate `.driftDetected` review.
- Evidence-incomplete projection retains a nil actual quality and does not count as verified strong.
- Sanitized sprint counts ignore canonical hidden strong/risky totals and are recomputed only from visible reviewed information.

## Accessibility, motion, and lifecycle verification

- Simulator accessibility inspection confirmed readable labels and values for company metrics, the garage summary, agent roles/states, Headquarters Progress, review controls, and sprint controls.
- Assignment and Founder Review were exercised in the simulator; confirmed actual quality appeared only after review and the evidence count updated.
- Accessibility Extra Large text and Increased Contrast were exercised; the primary action and semantic elements remained available.
- Reduced Motion and background policies passed pure deterministic tests. Reduced Motion disables ambient and staged animation; inactive/background state disables ambient motion.
- Home/background and foreground resume were exercised in the simulator without replaying a simulation action.
- No flashing or free-running timers were added.

## Performance and asset verification

- Large-device visual and scrolling interaction were exercised on iPhone 17 Pro Max; a standard iPhone 17 build also completed successfully.
- The garage uses proportional overlays and state-driven SwiftUI animation without SceneKit, RealityKit, SpriteKit, or third-party animation engines.
- Approved source: 3840×2160, 8.0 MiB, preserved outside the bundle.
- Bundled renditions: 480×270 (234 KiB), 960×540 (883 KiB), and 1440×810 (1.8 MiB).
- Compiled `Assets.car`: 3.4 MiB.
- Maximum garage pixel backing: approximately 4.45 MiB RGBA, an approximately 86% reduction from the 4K source's 31.64 MiB backing.
- Interactive garage/tab scrolling remained responsive during simulator inspection. No Instruments process-RSS or frame-time profile was available in the built-in simulator.

## Metadata verification

- `Project.json`: `CFBundleVersion` 2, `CURRENT_PROJECT_VERSION` 2, `MARKETING_VERSION` 1.0.
- `App/Info.plist`: `CFBundleVersion` 2, `CFBundleShortVersionString` 1.0.
- `project.pbxproj`: Debug and Release `CURRENT_PROJECT_VERSION` 2, `MARKETING_VERSION` 1.0.
- Built app Info.plist: bundle `com.talonsight.solounicornrun`, version 1.0 (2), minimum OS 18.0, portrait orientation.
