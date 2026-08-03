# RevenueCat Release Setup — SOLO: UNICORN RUN

Build 3 uses RevenueCat for one non-consumable Founder Pass. Venture 1 remains
fully playable without RevenueCat; an unavailable purchase service leaves the
resolved career safely paused at the Venture 1 boundary with a visible Retry
and Restore Purchases path.

## Identifiers

- Bundle ID: `com.talonsight.solounicornrun`
- Product: `com.talonsight.solounicornrun.founderpass`
- Entitlement: `solo_unicorn_run_pro`
- Preferred offering: whichever offering RevenueCat marks Current
- Fallback offering: `default`
- Package type: Lifetime / `$rc_lifetime` (the product is non-consumable)

The client renders every package RevenueCat returns for the resolved offering.
It does not assume a package count or gate access by product identifier.

## Release key injection

The production key is not stored in source control. Copy the checked-in example
and edit only the ignored local file:

```sh
cp Configuration/ReleaseSecrets.xcconfig.example \
  Configuration/ReleaseSecrets.xcconfig
```

Set `RC_RELEASE_KEY` to RevenueCat's public Apple SDK key beginning with
`appl_`, then archive with the configuration file:

```sh
xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Release \
  -xcconfig Configuration/ReleaseSecrets.xcconfig \
  archive
```

`REVENUECAT_API_KEY` expands into `RevenueCatAPIKey` in the built Info.plist.
The real configuration path refuses blank values, `test_` keys, `sk_` secret
keys, and values that do not begin with `appl_` in Release. Debug builds may use
the RevenueCat Test Store key. Never print, screenshot, or commit the real key.

## RevenueCat dashboard status

The production App Store app now exists for `com.talonsight.solounicornrun`.
Its Apple In-App Purchase key, App Store Connect API key, vendor number, and
public Apple SDK key are configured. The public key is present only in the
ignored release configuration and has passed a redacted Release-build check.

Still required in RevenueCat:

1. Create entitlement identifier `solo_unicorn_run_pro`. Do not substitute the
   display-style `Solo: Unicorn Run Pro` key used by the earlier Test Store setup.
2. Attach `com.talonsight.solounicornrun.founderpass` to that entitlement.
3. Attach the production product to the Lifetime package in the Current
   `default` offering while preserving Test Store products for Debug.
4. Confirm the production app resolves that offering to one purchasable package.
5. Test purchase, cancellation, failure, and restore on an Apple sandbox device.

## App Store Connect checklist

1. The non-consumable Founder Pass is verified **Ready to Submit**, priced at
   $9.99 in the USA, available worldwide, localized in en-US, and has its App
   Review screenshot.
2. Confirm the Paid Applications agreement, banking, and tax setup are active.
3. Submit the in-app purchase with the app version when required.
4. Under App Privacy, disclose Purchase History for App Functionality and
   Analytics. Mark tracking as No. Confirm whether it is linked to identity
   against the final RevenueCat configuration; this app requires no account and
   does not add advertising identifiers or tracking.
5. Test purchase and Restore Purchases using Apple's sandbox, including restore
   on a second device or clean installation.

## App Review and Shipathon access

No review bypass, embedded credential, or hardcoded entitlement exists. Reviewers
and judges can play Venture 1 to its completion gate, purchase Founder Pass in
Apple's sandbox without a real charge, then continue into Venture 2. Restore
Purchases is prominent on both Founder Pass screens. If faster legitimate access
is needed, issue an official App Store promo code or grant a temporary
RevenueCat promotional entitlement to the reviewer's supplied app user ID, then
revoke it after review; never commit the code or ID.

## What Founder Pass unlocks

- Venture 2
- Hindsight Recall, which reports historical precedents without advice
- The complete career conclusion

The resolved Venture 1 state is saved before the gate. Relaunch returns to that
gate, and entitlement refresh, purchase, and restore all use the same idempotent
resume operation so the career can advance only once.
