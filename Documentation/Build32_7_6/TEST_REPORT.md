# Build 32.7.6 Test Report

## Counts

- Baseline XCTest suite: 523 passed, 0 failed.
- Final XCTest suite: 529 passed, 0 failed (`/private/tmp/build-3276-current-full.xcresult`).
- Focused visual/motion suite: 47 passed, 0 failed (`/private/tmp/build-3276-current-focused.xcresult`).
- UI continuity and evidence: 3 distinct tests passed on iPhone and the same 3 passed on iPad; 6 device/test combinations, 0 failed.

The complete suite includes Operations Floor, Founder Desk/Garage, hidden-truth, deterministic RNG, saves/migrations, finance, calendar, and the added motion/audio/accessibility checks. New coverage verifies lifecycle mapping, distinct role profiles, choreography phases, ambient phase separation, door visibility and geometry parity, Garage-only presentation, period lighting, audio contexts/ducking, Reduce Motion, Increased Contrast/accessibility stability, focus round trips, and inactive/offscreen throttling.

## Runtime matrix

- iPhone 17 Pro Max, iOS 26.5: continuity, idle hold, authored motion/lighting evidence passed.
- iPad Air 11-inch (M4), iOS 26.5: continuity, idle hold, authored motion/lighting evidence passed.
- Corrected physical-Garage result bundles: `/private/tmp/build-3276-visual-iphone-physical-2.xcresult` and `/private/tmp/build-3276-visual-ipad-physical-2.xcresult`.

Build 32.7.6 also compiled and launched successfully in Bitrig with no reported diagnostics.
