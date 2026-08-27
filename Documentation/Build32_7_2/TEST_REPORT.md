# Build 32.7.2 Test Report

## Canonical baseline

- Starting revision: `8f93d23d58bdcbc52893dfa8359804e44dbf3e65`
- Version: 32.7.1 (32701)
- XCTest baseline observed before production edits: 463 passed, 0 failed.

## Final automated results

- Founder Desk focused suite: 32 passed, 0 failed, 0 skipped; iPhone 17 Pro, iOS 26.5.
- Complete unit XCTest suite: 464 passed, 0 failed, 0 skipped; iPhone 17 Pro, iOS 26.5.
- iPhone production continuity UI test: passed. It selects all four physical devices, performs LOOK OUT drag and manual camera movement, verifies no tab bar, returns from each feature, and enumerates all nine server modules.
- iPad production continuity UI test: passed in 166.822 seconds on iPad Pro 13-inch (M5), iOS 26.5, with the same complete route and 0 failures.

## Added focused coverage

- Hardware silhouettes remain semantically distinct without labels in compact and regular compositions.
- Camera alternatives collapse after discovery but remain directly exposed at accessibility text sizes.
- Focused close/LOOK OUT controls settle at a minimum 44×44 accessibility frame on iPhone and iPad.

Existing selection, mounted state, camera ownership, tab absence, Reduce Motion, Increased Contrast, hidden-truth invariance, server parity, and canonical state-owner assertions remain intact.

## Manual and visual verification

- Fresh iPhone and iPad production stills were inspected at native simulator output.
- The phone reads as a portrait handset, Venture as a supported landscape tablet, Command as monitor-contained content, and the server as floor infrastructure without depending on labels.
- All equipment remains grounded and un-clipped in compact and regular compositions; agents remain readable in the midground.
- Accessibility Extra Large and Increased Contrast were applied in the built-in iPhone simulator. The simulator session confirmed readable, focusable controls; the desk-specific accessibility behavior is additionally covered by the direct fallback/chrome tests and production UI identifiers.
- Reduce Motion is covered by focused deterministic tests; the built-in setting surface does not expose a Reduce Motion toggle.

## Result bundles

Result bundles are retained in BitRig's build area as `Build3272FocusedFinal.xcresult`, `Build3272FullFinal.xcresult`, and `Build3272iPadUIFinal3.xcresult`.
