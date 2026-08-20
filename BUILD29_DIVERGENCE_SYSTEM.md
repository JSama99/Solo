# Build 29 — The Divergence System

Build 29 extends SOLO's reported-truth/actual-truth thesis from individual tasks to whole sprints and the founder's identity.

## Player-facing systems

- Successful careers now resolve to one of seven `UnicornIdentity` outcomes. The career screen shows a separate, non-competitive identity grade and the measured gap between the founder's declared and revealed doctrine.
- Empire careers can encounter up to two consequential fork points per venture. Career mode receives one scripted fork at Venture 1, Sprint 6. Daily Challenge never forks.
- A fork is a commitment, not a save point. SOLO plays one path; a deterministically selected rival simulates the other for four sprints (three for the Career-mode teaching fork). No `CareerSave` snapshot exists inside a branch and no restore path accepts one.
- Collapsed branches appear in Hindsight/Garage Records as neutral, two-column factual records. The two branches share the exact same `PrecedentContext`, producing similarity 1.0.
- Low-evidence work can carry a deterministic delayed defect. Every surfaced defect includes the originating venture, sprint, task, agent, and evidence percentage.
- High-performing agents with neglected relationships can receive a rival offer. The Tech.com warning arrives one sprint early and can be countered with Founder Attention.
- Rival exposure, acquisition, pivot, and collapse events change the mechanical standings and are announced through Tech.com.
- Each `VentureEra` now has a deterministic rule delta in addition to runway and energy pressure.

## Determinism

`DrawCoordinate` hashes career seed, venture, sprint, task instance, agent, channel, and divergence salt through the existing SplitMix64 mixer. Canonical task reports use salt zero. At the fork, a ghost's salt is suppressed, making identical task/agent coordinates identical. `Divergence.pressure` then increases the share of salted draws from 0 to 1 across the horizon.

The ghost is a pure `SimulationEngine` operation. It performs at most 12 task resolutions for the standard horizon, performs no I/O, reads no `GameStore`, consumes no canonical RNG draws, and is run once when the fork is chosen.

## Save migration

The current envelope and key are v17. All Build 29 fields use `decodeIfPresent` defaults. The v16 migration is intentionally identity-preserving: it retains every old value, including `reportCache`, so reports already seen in an in-flight career do not reroll after the coordinate-hash transition.

`saveCareerPurgeKeys` and `resetCareerPurgeKeys` are covered by an equality test to prevent the key lists from drifting again.

## Verification

The Build 29 tests cover coordinate stability, fork-point equality, measured divergence growth, policy bands, copycat behavior, perfect Hindsight similarity, no-restorable-snapshot enforcement, v16-shaped decoding, report-cache preservation, identity derivation and deterministic tie-breaking, attributable latent defects, mechanical rival discontinuities, era rules, and save-key purge parity. The complete project suite is run on the iOS 26.5 iPhone 17 Pro simulator.
