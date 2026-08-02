# RevenueCat Setup — SOLO: Unicorn Run

## Implemented in the app

- Swift Package: `https://github.com/RevenueCat/purchases-ios-spm.git`
- Version rule: RevenueCat 5.43.0 up to the next major version
- Resolved SDK during integration: 5.83.0
- Package products: `RevenueCat` and `RevenueCatUI`
- Debug API key: the supplied RevenueCat Test Store public SDK key
- Release API key: read from the `REVENUECAT_API_KEY` build setting
- Entitlement identifier: `solo_unicorn_run_pro`
- Entitlement display name: `Solo: Unicorn Run Pro`
- Products: `lifetime`, `yearly`, and `monthly`
- Offering, purchase, restore, CustomerInfo, paywall, and Customer Center support

The Test Store key is compiled only in Debug. Before distributing a Release build, set `REVENUECAT_API_KEY` to the public Apple SDK key beginning with `appl_`. Never ship a `test_` key or embed a RevenueCat secret key.

## RevenueCat dashboard configuration

The RevenueCat plugin is installed and connected. Configure the catalog as follows:

1. Open the connected RevenueCat project and its Test Store.
2. Create a non-consumable product:
   - Identifier: `lifetime`
   - Display name: Lifetime
3. Create a one-year subscription:
   - Identifier: `yearly`
   - Display name: Yearly
4. Create a one-month subscription:
   - Identifier: `monthly`
   - Display name: Monthly
5. Create the entitlement:
   - Identifier: `solo_unicorn_run_pro`
   - Display name: Solo: Unicorn Run Pro
6. Attach all three products to the entitlement.
7. Create an offering with identifier `default` and make it the current offering.
8. Add packages to the offering:
   - Lifetime package → `lifetime`
   - Annual package → `yearly`
   - Monthly package → `monthly`
9. Create and publish a RevenueCat Paywall for the `default` offering. If no custom paywall is published, RevenueCatUI presents its default paywall using the offering packages.
10. Configure Customer Center. It appears in the app after the Pro entitlement becomes active.

RevenueCat plugin tools become available on the message after installation. Ask Codex to create this catalog in the connected RevenueCat project on the next turn.

## SwiftUI architecture

`SubscriptionStore` is the single source of truth for subscription state. It configures `Purchases` once, listens for `CustomerInfo` updates, fetches the current offering and customer, checks the entitlement, and exposes async purchase and restore methods with user-facing error handling.

`SubscriptionScreen` is available from More → Solo Pro. It:

- Lists configured packages and localized prices.
- Supports direct package purchases.
- Presents the remotely configured `PaywallView`.
- Restores purchases.
- Presents `CustomerCenterView` for active Pro customers.
- Refreshes CustomerInfo and offerings when opened or pulled to refresh.

## Customer identification

The current setup uses RevenueCat anonymous App User IDs, which is appropriate for an offline game without accounts. If authentication is added later, call `Purchases.shared.logIn(stableUserID)` after sign-in and `Purchases.shared.logOut()` after sign-out. Never use an email address as the App User ID unless the privacy model explicitly permits it.

## Test Store testing

1. Run the Debug app.
2. Open More → Solo Pro.
3. Open the RevenueCat Paywall or select a package.
4. The Test Store presents controls to simulate success, failure, or cancellation.
5. Confirm that successful purchases activate Solo: Unicorn Run Pro and reveal Customer Center.
6. Test Restore Purchases and error/cancellation paths.

Test Store purchases work in the built-in simulator. Real App Store sandbox purchases require the Apple products, agreements, tax/banking setup, a production `appl_` SDK key, and a real device or TestFlight.

## Production checklist

- Create the same product identifiers in App Store Connect under `com.talonsight.solounicornrun`.
- Use a non-consumable in-app purchase for `lifetime`.
- Put `yearly` and `monthly` in the same auto-renewable subscription group.
- Import the Apple products into RevenueCat and attach them to the same entitlement and offering packages.
- Add the public Apple SDK key to the Release `REVENUECAT_API_KEY` build setting.
- Configure App Store Server Notifications and RevenueCat's Apple credentials.
- Verify the Paid Applications Agreement, tax, and banking status.
- Test purchases with a Sandbox Apple Account on a physical device.
- Test restore, expiration, billing retry, cancellation, upgrades/downgrades, and lifetime ownership.
- Confirm Customer Center behavior and promotional offers before release.

## Best practices used

- Configure the shared Purchases SDK exactly once at app launch.
- Gate access by entitlement, not by individual product identifier.
- Let offerings control package availability remotely.
- Treat CustomerInfo as the authoritative subscription state.
- Refresh CustomerInfo on entry and after purchase or restore.
- Handle cancellation separately from purchase failures.
- Keep secret API keys off-device.
- Keep Test Store and production API keys separated by build configuration.
- Use Customer Center only for customers with active Pro access.
