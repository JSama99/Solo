# Build 32.8 Full Regression Test Report

## Baseline

Canonical revision `10288cf6ad683a9337875bf296015445101161de` built successfully. Untouched suite: **462 unit + 1 UI = 463 passed**, 0 failures, 0 skipped, iPhone 17 Pro / iOS 26.5. Bundle: `/Users/jermainenelson/Library/Bitrig/Users/22715/Builds/80acfced-dd48-4885-a7e0-e64b166053b5/Build32_8_Baseline_2.xcresult`.

The first shell attempt was denied by filesystem sandboxing before tests ran; the authorized rerun passed. This was not a repository baseline failure.

## Build 32.8

**481 unit + 1 UI = 482 passed**, 0 failures, 0 skipped. Bundle: `/Users/jermainenelson/Library/Bitrig/Users/22715/Builds/80acfced-dd48-4885-a7e0-e64b166053b5/Build32_8_Full.xcresult`.

The UI test exercised the production Founder Desk, confirmed no tab bar, focused and returned from Founder Computer, verified Look Out, Look Left/Center/Look Right, opened and closed Tech.com iPhone, Venture iPad, and Company Server, and captured five screenshots in the xcresult bundle. The 19 added tests increased—not replaced—coverage. Existing navigation, secrecy, state continuity, gameplay, save migration, motion, Tech.com, Venture, and spatial-causality suites all remained green.
