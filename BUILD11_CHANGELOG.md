# Build 11 Changelog

## AI workforce evolution

- Added persistent per-agent XP, a 15-level curve, stress, specialization perks, ambition counters, and completion state to `SoloAgent`.
- Added active gameplay effects for stress, Aurora evidence and research perks, and Stacks engineering perks without adding RNG calls.
- Added role-matched task XP, high-quality and verified-work XP, bounded stress accumulation, rest recovery, and Founder Loft stress reduction.
- Added Garage-only workstation upgrade XP acceleration and kept all facility bonuses tied to the active headquarters.
- Added Level, XP, stress, specialization, perks, and ambition status to roster and agent-detail surfaces; specialization choices are available from Agent Operations.
- Added Build 11 workforce achievements and status dialogue for level, specialization, and stress milestones.

## Compatibility and limits

- Career save schema is now v9. Existing v8 careers decode agent progression safely with zero XP, focused stress, and no perks.
- Daily Challenge begins from the standardized level-one workforce, so account progression cannot change seeded scoring.
- No new agents, facilities, network calls, or external dialogue generation were added.
