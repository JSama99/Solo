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

## RevenueCat and App Store follow-up verification

The production RevenueCat App Store app now has Apple purchase validation,
App Store Connect catalog credentials, and a public Apple SDK key. The key is
stored only in the ignored release configuration. A clean Release build verified
the injected value matched, was nonblank and `appl_`-class, without printing it.

App Store Connect directly reports the production Founder Pass as a $9.99
non-consumable with worldwide availability and en-US metadata. An App Review
screenshot of the actual Founder Pass entry was uploaded successfully, moving
the product from `MISSING_METADATA` to `READY_TO_SUBMIT`.

The remaining RevenueCat blocker is identifier alignment: the client correctly
requires `solo_unicorn_run_pro`, while the earlier Test Store configuration used
the display-style key `Solo: Unicorn Run Pro`. Create the exact production
entitlement, attach the Founder Pass to it and to the Lifetime package in
`default`, then perform a physical-device sandbox purchase and restore.

## App Store Connect work still required

- Include the first in-app purchase with the app-version submission.
- Complete Purchase History privacy disclosures for App Functionality and
  Analytics and confirm linkage against the final RevenueCat setup.
- Perform Apple sandbox purchase/restore on physical devices.
