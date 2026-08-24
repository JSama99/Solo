# Test Report — Build 32.5.2

Date: 2026-08-24  
Simulator destination: iPhone 17 Pro, iOS 26.5 (23F77), arm64

## Automated results

### Final focused Founder environment suite

- Executed: 22
- Passed: 22
- Failed: 0
- Skipped: 0
- Result: Passed
- Result bundle: `Build32_5_2_Focused_Final/Logs/Test/Test-Solo Unicorn Run-2026.08.24_06-47-14--0400.xcresult`

Coverage includes world projection, zone visibility, distinct bounds, camera clamping, relative and consecutive dragging, focus/free-look policies, monitor return, computer hit testing, Reduce Motion endpoints, stable anchors, all five upgrade mappings and four states, secrecy/accessibility sanitization, seeded parity, duplicate guards, legacy saves, RevenueCat configuration, and negotiated audio-buffer compatibility.

### Full XCTest suite

- Executed: 385
- Passed: 385
- Failed: 0
- Skipped: 0
- Result: Passed
- Result bundle: `Build32_5_2_Full_Final/Logs/Test/Test-Solo Unicorn Run-2026.08.24_07-19-38--0400.xcresult`

This full suite was rerun after the final accessibility-size Look Around adjustment.

## RevenueCat package resolution

The project already uses the intended local package at `Packages/purchases-ios-spm`. The failure mode was a missing shared scheme/test action, which could make a test invocation resolve incorrectly or execute zero tests. A shared scheme now includes the app and test targets. No RevenueCat source, import, test membership, or monetization behavior changed.

## Build and manual interaction

- Clean BitRig production build and visible launch: passed.
- Computer Focus scroll: passed with a direct drag inside the canonical computer.
- Canonical Evidence action: passed; the three-entry ledger expanded.
- Enter Free Look without navigation: passed.
- Left, Center, and Right controls: passed.
- Physical monitor tap return: passed.
- Post-return computer scroll and Evidence interaction: passed.
- Accessibility tree in Free Look: sanitized room summary and named camera/return actions present; computer content absent.
- Canonical Founder Review: unavailable in the current resolved/commit-ready save; not claimed.

## Proof limits

Unit tests validate policies and pure projections, not real SwiftUI hit testing. The simulator interactions above provide the hit-testing evidence. The requested uninterrupted video remains blocked because no recorder/export capability is exposed for the built-in simulator; no MP4 or timestamp map is claimed.
