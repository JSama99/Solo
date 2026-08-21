# Build 30.3 Test Report

Date: 2026-08-20  
Simulator: iPhone 17 Pro, iOS 26.5

## Automated

- Focused suites: `TechComFeedTests`, `TechComEngineTests`, `TechComPresentationTests`, `RivalEngineTests`, and `TalentBoardTests` — 19 passed, 0 failed, 0 skipped.
- Full app XCTest suite — 253 passed, 0 failed, 0 skipped.
- Bitrig build and simulator launch — passed twice with no diagnostics.
- Added coverage for stable cross-surface company identity mapping and canonical archetype fallback.

Existing coverage continues to protect one-shot feed resolution, deterministic feed/Rival behavior, pre-verification hidden values, canonical post-verification disclosure, ranking ordering, proportional market-share mapping, and Talent Board unlock/economics.

## Manual simulator validation

Validated:

- Initial Tech.com load, tightened first viewport, and idle Your Company state.
- Full vertical scroll and bottom-tab clearance through the final Market Share row.
- Compact Rival cards, unverified state, verification interaction, canonical claimed-to-actual reveal, and overclaim treatment.
- Locked Talent dossier preview.
- Track Record, Revenue, and Momentum ranking views after a canonical verification reorder.
- Market Share labels, archetypes, monograms, differentiated accents, proportions, and SOLO prominence.
- Accessibility Extra Large reflow and Increased Contrast rendering.
- Accessibility tree grouping, ordering, status descriptions, control labels, and values.

## States not manually reachable

- The current save had no unresolved Decision Feed card and no populated Your Company story. Resetting or fabricating career state was intentionally avoided; unresolved/resolved feed behavior and populated headline derivation remain covered by deterministic focused tests.
- The unlocked Talent Board was not reachable without advancing or altering the current career; its canonical gate and economics remain covered by `TalentBoardTests`.
- The verification scan is shorter than simulator-tool screenshot latency. The interaction and final reveal were manually verified; scan structure and Reduce Motion fallback were code-reviewed.

## Environment limitations

- Bitrig does not expose a Reduce Motion simulator toggle or spoken VoiceOver playback. Reduce Motion branches were code-reviewed and shared motion-policy tests passed; VoiceOver semantics were inspected through the accessibility tree.

## Result

No known functional regressions. Deterministic simulation, hidden truth, save compatibility, and canonical calculations remain intact.
