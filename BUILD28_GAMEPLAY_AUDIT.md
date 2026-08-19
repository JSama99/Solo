# Build 28 Gameplay Audit

Build 28 remediates two verified gameplay defects without changing simulation
randomness, authored content, Hindsight matching, or career progression rules.

## Fixed

- `resetCareer()` now purges the same v1-v15 legacy save keys as
  `saveCareer()`. A regression test locks the lists together and verifies an
  explicit reset leaves `hasSave == false`.
- Verified-evidence and completed-objective score accumulation is capped at
  5,000 points per component. The bounded-career maxima remain below the cap,
  while venture progression remains deliberately uncapped.

## Deliberately unchanged

These require separate design, monetization, or migration decisions and are
not treated as bugs in this remediation build:

1. Live in-sprint Hindsight Recall remains Founder Pass gated even though the
   Records screen is free.
2. `commitSprint` continues to permit newly hired agents to remain unassigned
   or unrested once the minimum assignment requirement is met.
3. `TechComEngine` continues to use non-deterministic `UUID()` values. They
   consume no seeded draws and currently affect neither score nor simulation,
   while changing them would require a persisted-data migration decision.
4. `GameStore.totalVentures` remains available despite having no callers.
