# SOLO: UNICORN RUN — Build 6 Read Me First

## Build identity

- **Pass:** Build 6 — Living Company Pass
- **App version:** 1.0
- **Build number:** 4
- **Save schema:** v8
- **Starting project:** Build 5

Build 6 is a gameplay, persistence, balance, and reliability upgrade. It keeps the modern SwiftUI presentation, two-venture bounded mode, continuous mode, Hindsight, evidence ledger, deterministic simulation, facility progression, and RevenueCat Founder Pass integration.

The main change is that the company now carries decisions forward. Founder choices can create permanent company flags, temporary operating obligations, relationship effects, recurring costs, and an acquisition ending. The sprint flow also communicates its current phase instead of presenting one undifferentiated command screen.

## Open and run

1. Extract the bundle.
2. Open `SoloUnicornRun.xcodeproj` in Xcode.
3. Select the **Solo Unicorn Run** scheme.
4. Allow Swift Package Manager to resolve RevenueCat.
5. Select an iPhone simulator or a registered device.
6. Build and run.

Recommended test command on macOS with Xcode installed:

```sh
xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  CODE_SIGNING_ALLOWED=NO test
```

The simulator name can be replaced with any installed iPhone simulator.

## What to test manually first

1. Start a new bounded career and confirm the five-step sprint tracker advances as decisions are made.
2. Draft three commitments from five opportunities and confirm ignored work appears in the report.
3. Review a task and confirm commit remains blocked until Approve, Rework, Ship Anyway, or Cross-check is selected.
4. Choose several founder dilemmas and inspect **Records → Company Story** for flags, obligations, and decision history.
5. Save, close, and reload before the next sprint. Confirm the future task draft and dilemma sequence remain deterministic.
6. Complete Venture 1 in continuous mode without Founder Pass. Confirm the checkpoint appears before the paywall and that Retire remains available.
7. Continue into later ventures and confirm operating pressure and correlated-failure severity rise.
8. Confirm the RevenueCat entitlement remains `solo_unicorn_run_pro` and the expected StoreKit product remains `com.talonsight.solounicornrun.founderpass`.

## Important compatibility note

Build 6 writes save schema v8 and reads v1–v7 saves. Loading an older career migrates it to v8. Keep a copy of the previous build when testing production migration because a v8 save is not intended to be reopened by Build 5.

## Documents in this bundle

- `BUILD6_CHANGELOG.md` — implementation details
- `BUILD6_GAMEPLAY_DESIGN.md` — intended player experience and balance rules
- `TEST_REPORT_BUILD6.md` — completed validation and remaining Xcode verification
- `BUILD6_BUNDLE_MANIFEST.md` — bundle contents and release checklist
- `REVENUECAT_SETUP.md` — existing purchase configuration guide
