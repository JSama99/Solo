# Build 12.1 Remediation Design

## Review reachability

Build 12 treated the Garage’s suggested next object as the only tappable object. At the same time, `GameStore.sprintPhase` only entered review after a review existed, while assigned reports immediately became `awaitingReview`. The combined rules made every assigned station untappable and made Founder Review unreachable.

## Gating and highlighting

Garage stations are unavailable only during the founder dilemma. From commitment selection onward every station accepts taps, matching the previous Command Deck control reachability. `stationIsHighlighted` separately identifies unassigned stations during assignment and awaiting-review stations during review/commit, so visual guidance never removes an action path.

## News publication

Presentation events accumulate only for the active venture/sprint. Tech.com publishes the complete event batch at the sprint boundary, so the engine’s per-sprint cap and quiet-cycle trend fill run against the same shape in production and tests. Closing sprint headlines retain the pre-commit venture and sprint identifiers.
