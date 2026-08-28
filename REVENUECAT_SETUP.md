# RevenueCat Setup — SOLO: Unicorn Run

## Read this first: why Build 2's paywall was empty

Build 2 could not complete a purchase, and no dashboard change would have fixed it.

`SubscriptionStore.packages` filtered the current offering like this:

```swift
currentOffering?.availablePackages.filter {
  RevenueCatConfiguration.productIdentifiers.contains($0.storeProduct.productIdentifier)
}
```

`productIdentifiers` was `["lifetime", "yearly", "monthly"]`. The only product
configured in App Store Connect is `com.talonsight.solounicornrun.founderpass`.
Nothing matched, `packages` was always empty, and the UI rendered
"Offering Not Ready" — which reads like a dashboard problem but was a client bug.

**Build 3 removes the filter entirely.** Whatever the current offering contains
is shown, and access is decided by the entitlement alone. The dashboard catalog
can now be named anything.

## What must match exactly

Exactly one string is shared between the app and the dashboard:

| Thing | Value |
|---|---|
| Entitlement identifier | `Solo: Unicorn Run Pro` |

That's it. Product identifiers, package types, offering names, and prices are
all read at runtime and never hardcoded.

## Dashboard checklist

1. **Product** — Products → New. Import or create
   `com.talonsight.solounicornrun.founderpass`.
   Type: **non-consumable** (matches `appStoreConnect/inAppPurchases/…/inAppPurchase.json`,
   which declares `NON_CONSUMABLE` at $4.99).
2. **Entitlement** — Entitlements → New → identifier `Solo: Unicorn Run Pro`.
   Attach the product above. *This identifier must be exact.*
3. **Offering** — Offerings → New → identifier `default`.
4. **Package** — inside that offering, add a package. Type **Lifetime**
   (`$rc_lifetime`) is the correct fit for a non-consumable. Attach the product.
5. **Mark the offering Current.** This is the single most commonly missed step.
   Without a Current offering the SDK returns `offerings.current == nil` and the
   paywall has nothing to show. Build 3 also falls back to an offering literally
   named `default`, so either arrangement works.
6. **Paywall** (optional) — Paywalls → publish one for the offering. If none is
   published, RevenueCatUI renders its default paywall from the packages.

## Diagnosing it from inside the app

Build 3 ships `PurchaseConfigurationStatus`. The unlock screen and the Founder
Pass screen both render `PurchaseDiagnosticsCard` whenever the purchase stack is
not ready, and each state names the fix instead of failing silently:

| Status | Meaning | Fix |
|---|---|---|
| `notConfigured` | `configure()` never ran | Call it at launch |
| `missingAPIKey` | No key in Info.plist | Set `REVENUECAT_API_KEY` |
| `secretKeyOnDevice` | An `sk_` key is bundled | Remove and rotate immediately |
| `testKeyInReleaseBuild` | `test_` key in Release | Use the public `appl_` key |
| `noCurrentOffering` | No offering marked Current | Step 5 above |
| `offeringHasNoPackages` | Offering is empty | Step 4 above |
| `ready(packageCount:)` | Purchasable | — |

If the person configuring the dashboard reads one thing, make it this table.

## API keys

- **Debug:** falls back to the Test Store key, or an `RevenueCatAPIKey`
  Info.plist override if present.
- **Release:** read from `RevenueCatAPIKey` in Info.plist, populated from the
  `REVENUECAT_API_KEY` build setting. Must begin with `appl_`.
- **Never** ship an `sk_` secret key. `configure()` refuses to start if it finds one.

## What the purchase unlocks

The Founder Pass is a one-time non-consumable that unlocks:

- **Venture 2** — the second twelve-sprint venture of the career
- **Hindsight Recall** — precedents banked in Venture 1 resurfacing when
  structurally similar conditions repeat
- **The full career outcome** — the complete twenty-four-sprint track record

Venture 1 is complete and free. When it ends without the pass, the career is
**held**, not discarded: `awaitingFounderPass` persists in the save, and
purchasing resumes the exact same career at the venture boundary with all
evidence, agents, stats, and precedents intact. `resumeAfterFounderPassUnlock()`
is idempotent and safe to call on every entitlement change.

## Production checklist

- [ ] Paid Applications Agreement active; tax and banking complete
- [ ] `com.talonsight.solounicornrun.founderpass` approved in App Store Connect
- [ ] Product imported into RevenueCat and attached to `Solo: Unicorn Run Pro`
- [ ] Offering created, package attached, **offering marked Current**
- [ ] `REVENUECAT_API_KEY` set to the public `appl_` key for Release
- [ ] App Store Server Notifications configured
- [ ] Sandbox purchase tested on a physical device
- [ ] **Restore tested on a second device** — required for App Review
- [ ] Purchase-then-resume verified: buy at the gate, confirm Venture 2 begins
      with the same career intact

## Testing without the App Store

1. Run the Debug build (Test Store key is compiled in).
2. Play Venture 1 to completion, or use the Founder Pass screen directly.
3. The Test Store presents success / failure / cancellation controls.
4. Confirm: purchase → the held career resumes into Venture 2 automatically.
5. Confirm: Restore with no purchase shows the "no previous purchase" message.

## Architecture notes

- `SubscriptionStore` is the only RevenueCat-aware type in the game path.
- `GameStore` depends on `EntitlementProviding`, a two-line protocol, so the
  simulation is fully testable without RevenueCat, StoreKit, or a network.
  `StaticEntitlementProvider` supplies deterministic answers in tests.
- Gate access by entitlement, never by product identifier. That rule is enforced
  by `PurchaseConfigurationTests`.
