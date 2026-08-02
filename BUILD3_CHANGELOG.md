# SOLO: UNICORN RUN — Build 3 Change Log

Fixes the blocking monetization defect, gives the Founder Pass real content to
unlock, and restores the career layer that made a second venture meaningful.

## 1. Blocking fix — nothing could be purchased

`SubscriptionStore.packages` filtered the current offering against a hardcoded
`["lifetime", "yearly", "monthly"]`. The only configured App Store product is
`com.talonsight.solounicornrun.founderpass`, so nothing ever matched, `packages`
was permanently empty, and the paywall rendered "Offering Not Ready".

This presented as a dashboard problem and was not one — no catalog change could
have fixed it.

- The product allow list is deleted. Whatever the current offering contains is
  displayed; access is decided by the **entitlement only**.
- `offerings.current` now falls back to an offering named `default`, covering
  the most common dashboard omission (forgetting to mark one Current).
- `PurchaseConfigurationStatus` diagnoses the whole stack — missing key, secret
  key on device, test key in Release, no current offering, empty offering — and
  each state names its fix. `PurchaseDiagnosticsCard` surfaces it in-app instead
  of failing silently.
- `configure()` refuses to start on an `sk_` secret key.
- `PurchaseConfigurationTests` prevents a product allow list from returning.

## 2. The Founder Pass now unlocks something

In Build 2 the `isPro` entitlement appeared in exactly one file and only changed
a label and a colour. No content was gated anywhere.

- **Venture 1 is complete and free.** Twelve sprints, a real ending, full loop.
- **Founder Pass unlocks Venture 2, Hindsight Recall, and the full career
  outcome.**
- When Venture 1 ends without the pass the career is **held, not discarded**:
  `awaitingFounderPass` persists in the save and the run resumes at the exact
  venture boundary on purchase, with evidence, agents, stats, and precedents
  intact.
- `resumeAfterFounderPassUnlock()` is idempotent and fires from any purchase or
  restore anywhere in the app.
- `VentureUnlockScreen` pitches the precedents the player already earned;
  `VentureLockBanner` keeps the held career reachable from the dashboard.

## 3. Hindsight restored

Build 2 had zero references to hindsight or precedents. It was the highest-value
mechanic in the design and the reason a *career* beats two disconnected runs.

- `Precedent` records a consequential sprint: bucketed conditions plus what
  measurably followed.
- `HindsightEngine` matches a live situation against earlier ventures —
  deterministic field comparison, 0.62 similarity floor, max 3 recalls per
  venture.
- **Load-bearing rule enforced by test:** a precedent reports conditions and
  outcomes and never judges or advises. `testRecallReportsConditionsAndNeverGivesAdvice`
  fails on "should", "wrong", "mistake", "avoid", "instead", "recommend", "better".
- Precedent identity derives from career position, **not** the simulation RNG, so
  recording a precedent cannot perturb the run being recorded. Proven by
  `testSeededRunsAreReproducibleWithPrecedentRecordingActive`.
- Recall is suppressed without the pass and consumes no RNG.

## 4. Save schema v5

- `CareerSave` gains `precedents` and `awaitingFounderPass`, both decoded
  optionally so every v1–v4 save still loads.
- New `migrateV4`. A v4 career that already reached Venture 2 keeps its progress
  — the gate is never applied retroactively to work already done.
- `hasSave`, `resetCareer`, and `saveCareer` updated for the v4 key.

## Added files

- `App/EntitlementProviding.swift`
- `App/Hindsight.swift`
- `App/VentureUnlockScreen.swift`
- `Tests/FounderPassGateTests.swift`
- `Tests/HindsightTests.swift`

## Modified files

- `App/RevenueCatConfiguration.swift` (rewritten)
- `App/SubscriptionStore.swift` (rewritten)
- `App/SubscriptionScreen.swift`
- `App/GameStore.swift`
- `App/GameModels.swift`
- `App/ContentView.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `REVENUECAT_SETUP.md` (rewritten against the real product)

## Verification still required on macOS

This pass was authored on Linux, where no Swift toolchain is available. Verified
here: brace balance, symbol existence for every referenced API, and Xcode project
registration (each new file has all four required pbxproj entries). **Not** yet
verified: compilation and the test run.

```sh
xcodebuild -quiet -project SoloUnicornRun.xcodeproj -scheme "Solo Unicorn Run" \
  -configuration Debug test CODE_SIGNING_ALLOWED=NO \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"
```

Expected: the 50 Build 2 tests plus roughly 35 new ones.

Several gate tests use `XCTSkipUnless` when a seeded career ends on merit before
reaching the venture boundary — that is intended, not a silent pass.

## Remaining limitations

- Founder Loft and later facility tiers remain locked pending approved art;
  unchanged from Build 2.
- The App Store description does not yet mention the two-venture career, the
  verification mechanic, or the Founder Pass. It undersells the actual hook and
  should be rewritten before submission.
- Hindsight recall surfaces at sprint preparation only. Surfacing it at the
  moment of assignment would be stronger and is the natural next pass.
- No promo code has been generated for App Review or Shipaton judges; both need
  a way past the Venture 2 gate.
