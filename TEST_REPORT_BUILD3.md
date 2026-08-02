# SOLO: UNICORN RUN — Build 3 Test Report

Date: 2026-08-02

Branch: `build3-founder-pass`

SDK: iOS Simulator 26.5

## Result

- XCTest: **98 passed, 0 failed, 0 skipped**
- Skipped tests: **none**
- Debug clean build: **succeeded, 0 warnings, 0 errors**
- Release clean build: **succeeded, 0 warnings, 0 errors**
- Built identity: `com.talonsight.solounicornrun`, version **1.0 (3)**
- Local App Store listing validation: **valid, 0 diagnostics**

Final XCTest result bundle:

`~/Library/Developer/Xcode/DerivedData/SoloUnicornRun-hbybbadhhkdtfsbviemwugtlovfs/Logs/Test/Test-Solo Unicorn Run-2026.08.02_17-34-01--0400.xcresult`

## Commands executed

```sh
git fetch origin
git fetch https://github.com/JSama99/Solo.git \
  build3-founder-pass:refs/remotes/github/build3-founder-pass \
  main:refs/remotes/github/main
git switch -c build3-founder-pass --no-track \
  refs/remotes/github/build3-founder-pass
git status -sb
git log --oneline main..HEAD

xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Debug \
  test \
  CODE_SIGNING_ALLOWED=NO \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"

xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Debug \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"

xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Release \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  -xcconfig Configuration/ReleaseSecrets.xcconfig \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"
```

Bitrig's project builder was also run after authoritative `Project.json` edits.
The local App Store listing validator and built-product `plutil` inspections were
run without publishing metadata or printing a key.

## Regression inventory

The passing suite covers v1–v5 save decoding/migration, a real v4 payload,
existing Venture 2 saves, the free Venture 1 loop, exact boundary pause,
relaunch while gated, purchase/restore idempotency, cancellation/failure safety,
held-state mutation rejection, RevenueCat key classes, Current/default offering
resolution, empty offerings, identifier consistency, Hindsight entitlement and
determinism, RNG stability, non-prescriptive recall, hidden quality, correlated
failure identifiers, visible projection boundaries, founder progression
separation, completed-run idempotency, Reduced Motion, lifecycle policy, and
privacy-manifest bundle contents.

## Release artifact inspection

The Release simulator app was built with a local ignored validation-only
`.xcconfig`. Without printing its value, the built Info.plist reported a nonblank
`appl_`-class value of length 42. This proves the injection and validation path;
it is **not** the production key and must be replaced at archive time.

Both Debug and Release bundles contain `PrivacyInfo.xcprivacy`. The built manifest
reports tracking `false`, an empty tracking-domain array, and UserDefaults reason
`CA92.1`. RevenueCat dependency manifests coexist in their resource bundles.

## Simulator inspection

Visually and through the accessibility tree on iPhone 17 Pro Max:

- Launch/continue, living Founder Garage, agent assignment, Founder Review,
  Evidence Ledger, Venture record, Headquarters Progress, Founder Pass packages,
  failed purchase, cancelled purchase, and Restore Purchases were exercised.
- Hidden actual quality appeared only after Founder Review.
- Failed/cancelled purchase preserved the career; restore with no entitlement
  gave a clear message.
- Accessibility Extra Large plus Increased Contrast kept package and Restore
  controls reachable by scrolling, with no clipped action.
- Backgrounding to Home and reopening the current installed app returned to the
  same Founder Pass screen.
- No uncontrolled flashing or background animation was observed.

The iPhone 17 standard build launched successfully, but Bitrig's inspection
bridge returned “does not support simulator state,” so its visuals could not be
truthfully certified. The Venture 1 completion gate, entitled Hindsight screen,
career restart, and Reduced Motion were covered by tests but were not all reached
manually in this simulator session.

## Release blocker: RevenueCat Test Store configuration

RevenueCat dashboard tools were unavailable, so production dashboard state could
not be verified. The connected Debug Test Store returned three generic products
(`monthly`, `yearly`, and `lifetime`) rather than evidence of the expected
`com.talonsight.solounicornrun.founderpass` catalog setup. A simulated valid
Lifetime purchase did **not** activate `solo_unicorn_run_pro`, and Restore then
reported no previous Founder Pass purchase.

The client code and unit tests correctly use the expected identifiers, but this
external configuration result blocks a release-safe end-to-end Founder Pass
claim. Before archive, complete `REVENUECAT_SETUP.md`, verify the production
Current or `default` offering contains the expected non-consumable, and perform a
successful Apple sandbox purchase and cross-install restore.

## App Store Connect work still required

- Inject the real public Apple `appl_` key only at archive time.
- Verify and publish the RevenueCat product/entitlement/offering configuration.
- Add the Founder Pass review screenshot and confirm the IAP is Ready to Submit.
- Apply the validated local listing edits.
- Complete Purchase History privacy disclosures for App Functionality and
  Analytics and confirm linkage against the final RevenueCat setup.
- Perform Apple sandbox purchase/restore on physical devices.
