# Build 30.2 — Tech.com Visual & Motion Pass

## Outcome

Tech.com now presents the existing canonical game state through three distinct visual classes:

- Editorial surfaces for company activity, public decisions, and trend signals.
- Entity surfaces for rivals and Talent Board candidates.
- Data surfaces for rankings and proportional market share.

The information architecture, bottom navigation, deterministic engines, FeedPost effects, Founder Attention costs, statement budget, ranking rules, and market-share calculations are unchanged.

## Presentation architecture

- `TechComScreen` is the composition root and supplies canonical `GameStore` state.
- `TechComComponents` contains the masthead, feed, decision, rival, verification, talent, ranking, and market-share views.
- `TechComPresentation` contains deterministic, side-effect-free mappings for rival disclosure, archetype identity, ranking gaps, monograms, and bar layout.

`TechComPresentation.rivalMetrics(for:)` deliberately returns no actual value until `TechComRival.isVerified` is true. This is covered by XCTest.

## Motion and feedback

- Company stories use stable identity and arrival transitions.
- Decisions use shared press feedback, a short processing state, canonical result settlement, numeric coverage transitions, and selection feedback.
- Rival verification uses a short inspection scan and the existing `VerificationImpact` component.
- Ranking rows retain stable identities and animate canonical reorderings.
- Market bars animate from their previously displayed canonical share.
- Every travel animation resolves immediately under Reduce Motion.

No animation reads or mutates simulation state, and no RNG calls were added.

## Accessibility

- Major cards expose descriptive VoiceOver labels and logical child ordering.
- Rival and market-share layouts adapt vertically at accessibility Dynamic Type sizes.
- Statuses always pair color with text and an SF Symbol.
- Increased Contrast strengthens the masthead divider and outline.
- Locked Talent Board preview content is hidden from VoiceOver; the canonical gate message is announced once.

## Compatibility

No save-schema changes or migrations were required. Older saved Tech.com rivals continue to display; archetype styling is applied only when a canonical rival ID maps to the current rival catalog.
