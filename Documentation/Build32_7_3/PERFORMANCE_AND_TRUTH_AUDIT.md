# Performance, RNG, and Hidden-Truth Audit

## Performance

- No new `TimelineView`, shader, blur stack, duplicate feature render, or simulation loop.
- Ambient effects use lightweight SwiftUI transforms, gradients, opacity, masks, and existing phase animation.
- Fixed rhythm profiles avoid per-frame random work.
- Aurora, Stacks, and Brio physical views are not mounted when substantially outside the projected camera margin.
- Canonical device surfaces remain stably mounted in `FounderDeskWorkspace` to preserve local state.
- Compressed simulator evidence is stored instead of raw recordings.

## Deterministic RNG

Ambient channel timing is a pure enum-to-profile mapping. Tests snapshot `SystemRandomNumberGenerator`-independent presentation output and assert repeat derivation equality. No calls to canonical random sources were added. Same-seed simulation parity remains covered and passing.

## Hidden truth

New fan speed, LEDs, screen luminance, agent posture, monitor spill, server behavior, lighting drift, audio hooks, and accessibility exposure use only lifecycle state already visible to the Founder. They do not inspect quality, correctness, verification, drift, overclaim, evidence completeness, hidden risk, or outcome.

The concealed-condition regression now compares ambient and audio-hook projections in addition to existing station/camera presentation. Neutral and concealed inputs produce identical ambient output before canonical reveal.

## Accessibility

- Device controls retain projected 44-point minimum hit regions.
- Offscreen physical controls are not exposed as floating accessibility targets.
- Explicit camera alternatives remain available without drag.
- Decorative chassis, fan, light shaft, LEDs, reflections, and shadows remain excluded from accessibility order.
- Dynamic Type does not alter physical world geometry; the established accessibility equipment fallback remains intact.

