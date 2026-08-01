# SOLO: UNICORN RUN — Upgrade Pass 5

## Reference-led Founder Garage

- Embedded the approved 3D Founder Garage reference directly in the standalone playable build, so it works offline without a separate asset download.
- Replaced the prior abstract CSS room with the actual reference environment: founder desk, three agent work zones, evidence wall, recovery chair, product lab, and infrastructure rack.
- Repositioned interactive hotspots over the physical room features. The central card wall now opens the Evidence Ledger; it still reveals no hidden truth before founder review.
- Preserved AI terminal state feedback, assignments, reviews, drift, overload, overclaims, cascading failures, and garage upgrade affordances on top of the physical environment.
- Tinted the reference only when real simulation state demands it: steady, strained, and critical operating states are still driven by drift, trust, energy, and cascade data.
- Migrated saves to version 6 and set the canonical `garageView` to `reference-3d`.

## Verification

`node --test SOLO_PASS5_TESTS.mjs`

Result: 42 tests passing.

## Current limitations

- This is a fixed-camera visual environment; it is not an explorable WebGL scene.
- The entire reference PNG is embedded for offline play, increasing the standalone HTML size.
- Counterfactual Hindsight attribution remains a later pure simulation-loop refactor.
