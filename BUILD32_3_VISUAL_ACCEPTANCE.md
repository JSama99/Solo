# Build 32.3 Visual Acceptance

## Device and provenance

- Device: iPhone 17 Pro simulator, iOS 26.5, portrait.
- Components: production `CompanyCommandViewport` and production character/station renderers.
- State source: immutable, visible-safe DEBUG fixtures; career save, RNG, purchases, and canonical progression are never read or changed.
- Build 32.2's 47 artifacts remain as the before baseline in `VisualProof/`. Build 32.3 proof is in `VisualProof/Build32_3/`.

## Screenshot inventory

There are 33 Build 32.3 PNGs at identical device scale. They cover equivalent Garage/Loft views; assignment; Aurora, Stacks, Brio, and multi-agent work; artifact return; review steps 1/3/5; Verified, Overclaimed, Drift Detected, and Evidence Incomplete; resolving/resolved/commit-ready; all four infrastructure states; Low Energy, Low Runway, Low Trust, High Momentum; resting, stressed, overloaded, level-up; Reduce Motion; Accessibility Extra Large; and Increased Contrast.

The corrected Loft frame is `02_DEBUG_FOUNDER_LOFT.png`; `01_DEBUG_FOUNDER_GARAGE.png` is its equivalent-state comparison. Both show the complete viewport and Previous/Next controls at the same scale, without the prior top black gap or clipped controls.

## Acceptance matrix

All 36 requested simulator categories are represented by the 46-state QA catalog. The 33 retained screenshots capture every visual family; adjacent review steps and healthy baseline atmosphere states were inspected live and are covered by deterministic fixture mappings/tests rather than duplicated near-identical files. Visible differences were checked at phone scale, not inferred from labels.

- Overview/focus: Founder overview, focused Aurora assignment, stable surrounding-agent transfer, Full Workstation action.
- Causality: dispatch document, station acknowledgement, role artifacts, artifact return/tray persistence, distinct resolution response.
- Conditions: idle, working, resting, stressed, overloaded, level-up.
- Review: all five transitions inspected; steps 1/3/5 retained; all four final outcomes retained.
- Hierarchy: planning, working, review, resolution, and commit each establish a different dominant region.
- Environment: five upgrades × four mapped states, Garage/Loft structure, four localized pressure reactions.
- Accessibility: default, XXX Large during live inspection, Accessibility Extra Large fixture, Reduce Motion, and Increased Contrast fixture.

## Causal recording

`BUILD32_3_DEBUG_CAUSAL_SEQUENCE.mp4` is **35.0 seconds** and begins on a stable in-app Planning frame—no Home Screen and no gray launch flash. It then shows assignment and acknowledgement, work, completion return, awaiting review, all five review layers, Verified settlement, resolution/response, and commit readiness. Opening and final frames were extracted and visually verified after export.

## Canonical versus DEBUG

The new complete causal sequence is explicitly DEBUG fixture proof using production components. A safe canonical save capable of reaching assignment through resolution was not available, so canonical progression was not mutated or falsified. Existing canonical Build 32.2 proof remains the canonical baseline but does not claim the new complete sequence.

## Known limitations

- Static portraits provide layered crop, rim light, state offset, acknowledgement, and settling—not fabricated facial animation.
- Physical-device VoiceOver/Dynamic Type verification remains outstanding; simulator accessibility verification passed.
- Instruments was unavailable in this environment. The performance section is a code/build audit, not a metric-backed FPS, CPU, energy, or memory claim.
