# SOLO: UNICORN RUN — Build 3 Change Log

Build 3 completes the Founder Pass release path without changing the deterministic
simulation, hidden-truth boundaries, approved Founder Garage artwork, facility
progression foundation, or save compatibility established by Builds 1 and 2.

## Founder Pass and career boundary

- Venture 1 remains a complete free experience.
- Founder Pass unlocks Venture 2, Hindsight Recall, and the complete career
  outcome.
- The resolved Venture 1 state is persisted before the gate and restored to the
  same gate after relaunch.
- Purchase, restore, and repeated entitlement refreshes converge on one
  idempotent resume operation.
- Simulation mutations are rejected while the career is held, preventing
  duplicate rewards, evidence, sprint advancement, cached results, or RNG use.
- Existing Venture 2 saves remain ungated.
- Cancellation, failure, empty offerings, and service errors preserve all career
  state and expose Retry and Restore Purchases.

## RevenueCat readiness

- Exact entitlement: `solo_unicorn_run_pro`.
- Exact product: `com.talonsight.solounicornrun.founderpass`.
- Current offering is preferred; `default` is the fallback.
- Paywalls render the packages returned by RevenueCat and make no hard-coded
  package-count assumption.
- Release configuration accepts only public Apple `appl_` keys in the actual SDK
  setup path; blank, Test Store, secret, and malformed keys are refused.
- Production keys are injected through an ignored `.xcconfig`; only a placeholder
  example is checked in.
- Provider/developer wording was replaced with player-facing Founder Pass copy.

## Privacy and store readiness

- Added an app-level `PrivacyInfo.xcprivacy` with tracking disabled, no tracking
  domains, and UserDefaults required-reason code `CA92.1`.
- Updated App Review notes with the legitimate sandbox purchase and restore path.
- Updated English subtitle, description, and Founder Pass copy to accurately
  describe the living garage, AI workforce, evidence verification, two ventures,
  free experience, and non-advisory Hindsight Recall.
- Added exact manual RevenueCat and App Store privacy checklists.

## Regression coverage

- Expanded migration coverage through v5, including a real v4 payload and an
  already-started Venture 2 save.
- Added deterministic gate, relaunch, purchase, restore, failure, key validation,
  offering fallback, privacy manifest, and held-state mutation tests.
- Preserved hidden-information, correlated failure, Hindsight, progression,
  Reduced Motion, and lifecycle coverage.

## Build metadata

- Bundle ID: `com.talonsight.solounicornrun`
- Marketing version: `1.0`
- Build number: `3`

Submitted TestFlight Build 1 is unchanged.

## Remaining external work

- Attach the production Founder Pass to RevenueCat entitlement
  `solo_unicorn_run_pro` and to the Lifetime package in `default`.
- Perform a purchase and cross-install restore on a physical sandbox device.
- Publish the App Store privacy questionnaire and include the first in-app
  purchase with the app-version submission.
- Founder Loft and future headquarters tiers remain unavailable pending approved
  art and are not advertised as playable.
