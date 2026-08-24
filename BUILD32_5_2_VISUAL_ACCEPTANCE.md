# Build 32.5.2 Visual Acceptance

## Production proof

Simulator: iPhone 17 Pro, iOS 26.5 (23F77), portrait.

Fresh production screenshots inspected at phone scale:

- `BUILD32_5_2_PRODUCTION_COMPUTER_FOCUS.png`
- `BUILD32_5_2_PRODUCTION_FREE_LOOK_CENTER.png`
- `BUILD32_5_2_PRODUCTION_FREE_LOOK_LEFT.png`
- `BUILD32_5_2_PRODUCTION_FREE_LOOK_RIGHT.png`
- `BUILD32_5_2_PRODUCTION_RETURNED_TO_COMPUTER.png`

The catalog is in `VisualProof/Build32_5_2/`. These are production gameplay captures, not DEBUG fixtures.

## Observed acceptance

- Left, center, and right are materially different and contain their intended agent/station.
- The center monitor is supported by a stand and physically occluded by the Founder desk.
- Free Look controls sit in a compact lower rail and do not cover the primary portrait or monitor content.
- Canonical computer scrolling worked before and after Free Look.
- Tapping the centered physical monitor returned to Computer Focus.
- Evidence expanded successfully after return, proving canonical computer input was restored.
- Free Look accessibility exposed the sanitized room summary and named Left, Center, Right, Up, Down, and Return actions.
- Increased Contrast and Accessibility Extra Large were exercised. The focused Look Around control uses an icon-only visual at accessibility sizes while retaining its full accessibility label.
- Reduce Motion endpoint behavior is covered by deterministic tests; the built-in setting tool did not expose a Reduce Motion switch.

## Not verified

- Founder Review was not available in the current canonical save, so no new canonical five-step Review capture was claimed.
- No spoken VoiceOver rotor, physical device, Instruments, gyroscope, or production Loft session was performed.
- No uninterrupted MP4 was exported. The available BitRig simulator tools have no recording API and the built-in simulator is not attached to `simctl`.

## Direction estimate

- Spatial architecture: 90
- Garage composition and character embodiment: 76
- Interaction correctness: 84
- Simulation/secrecy safety: 95
- Accessibility and performance policy: 80

`90 × 0.25 + 76 × 0.30 + 84 × 0.20 + 95 × 0.15 + 80 × 0.10 = 84.35%`

The estimate remains below 85% because uninterrupted video, canonical Founder Review proof, physical-device validation, and advanced character/environment rendering are absent.
