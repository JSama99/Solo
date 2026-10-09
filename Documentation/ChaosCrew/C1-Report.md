# Chaos Crew C1 report

**C1 COMPLETE — READY FOR C2**

Worktree: `/Users/jermainenelson/Documents/Solo-Reconstruction`. Branch: `codex/controlled-reconstruction`.
Baseline: `817b67cb7ee439711af200ddaef541e6c8bf0364` (unchanged).
Tested source fingerprint: `1cd8603413402d400770cbb0be73ba1798445640df10ceaa26f1eca329f20c7a`.

## Gates and production authority

A: ordinary startCareer, legitimate GameStore assignments, reviews and sprint commits reached launch with two Attention per sprint; seeded direct-review and Work Session routes. No installed preparation fixtures.
B: small four-seed exploration passed before the full bounded study. Sixteen production commands, seeded ordering, explicit rejection classification and source-backed observers.
C: deterministic deletion minimization, full/minimized replay preservation, exact F1 schema and precedent retrieval. A test-only duplicate-review observer defect minimized to two actions; segregated from genuine findings.
D: all 200 primary scenarios replayed identically, followed by focused regressions, independent artifact audit and existing Loop verification.

## Current study

Seeds 18180–18279 for each mission. 100 launch scenarios: 100 REACHABLE. 100 fuzz scenarios: 98 REACHABLE (bounded search completed), 2 INVARIANT_FAILURE. Zero SEARCH_EXHAUSTED, VALIDLY_BLOCKED or HARNESS_BLOCKED classifications.
22,511 primary attempted actions and 22,511 exact replay actions. 9,280 accepted, 13,229 rejected by design, 2 invariant violations. 1,753 reload operations; 241 distinct observed public state transitions. Study elapsed 685.445 seconds, excluding compilation and other tests.

## Candidate finding

`CF-c1-ca78b88c9c0e`: save_reload:tasks, fuzz seeds 18195 and 18279. The representative sequence minimized to 17 actions and reproduced identically. Full original traces remain in Evidence. The sequence reassigns a task after a completed delegated Work Session and then reloads; persisted task state changes. Static inspection identifies restoreLegacyWorkSessionCausalQuality as a plausible cause: it reapplies completed session values by assignment ID. Root cause remains a candidate for explicit review; no production repair was made. Public artifacts contain task/action identifiers and state hashes, not hidden simulation values.

## Verification

- Final iPhone XCTest run: 120 tests, zero failures; includes five C1 tests and 115 relevant regressions. Both iPhone and iPad builds passed.
- Canon: 357 tests; validator 45 records, zero errors. Failure Ledger: 34 tests, validator 14 incidents/12 rules. New Python contracts: seven tests.
- Source manifest equality, raw hashes of 200 replay files, public allowlist and exact F1 candidate validation passed.
- git diff --check passed. No App source, formulas, save version 20, assets, Canon or historical Ledger records changed.

## Existing Loop integration and review boundary

The initial architecture inspection and generated coverage report describe the absent runner inside this checkout. That availability limitation is superseded by discovery of the existing globally installed solo-loop package at `/Users/jermainenelson/Documents/solo-loop-system-v3-v3.1-preview`.
The checked-in C1-Loop.json graph reuses that runner; it verifies already completed study evidence, rather than claiming Loop launched the simulator study. Four command nodes passed. Run `solo-chaos-crew-c1-verification-192c4f14ef` paused at its human gate. Evidence chain verified: `b9d428ed1561eb448a8fcac7c679a2be4f7d2405388230feb99b748b5415d1a3`. No approve command or promotion ran. The graph's future logical acceptance node cannot promote F1 findings or authorize gameplay fixes.

## Isolation and limitations

Hosted tests used only fresh lab iPhone `40D4F1B3-092A-4E6F-9251-7A686A734B55`; iPad build destination `37C6DF3F-87F5-4F57-A882-B4B7D11A12F5`. Exact lab guard precedes GameStore reset/construction. Owner review devices and saves were not accessed. Protected source fingerprints matched for 248 original and 210 Narrative files except an existing original Xcode UserInterfaceState user-state difference; its origin is unverified and C1 did not write it.
Exploration covers initial careers, authored capabilities and 16 commands, not all game states. Venture-transition oracle is conditional; no comprehensive transition claim. Minimization capped at 256 trials per representative invariant; extra minimizer/replay actions are excluded from primary counts and not separately instrumented. Peak memory not measured; per-action autoreleasepool bounds transient Foundation allocations. No visual acceptance claim.
Canonical Coverage authority and Cash/Runway unresolved decisions remain unchanged. This pass does not prove SOLO bug-free.

## Harness corrections during development

Bounded repairs addressed test target ID collision, throwing Swift expression, Set canonicalization, and JSON-only save observer false positives (typed equality now primary). Lab startup and a tool timeout required retry; final raw xcodebuild completed successfully. Collector rejects stale retained artifacts by exact tested source fingerprint. No discovered gameplay bug was repaired.

## Files and durable checkpoint

FullChangedFileInventory.json lists every C1 file, hash and generated Loop artifact; the two inherited Canon cache files are excluded. Primary changes: Tests/ChaosCrewMissionTests.swift, four test-membership lines in project.pbxproj, Tools/ChaosCrew/c1.py, Tools/ChaosCrew/tests/test_c1.py, C1-Architecture.md, C1-Loop.json, this report, one F1 candidate, and generated evidence/reports.
Independent backup: `/Users/jermainenelson/Documents/Solo-Reconstruction-Backups/ChaosCrew-C1-20261008`. It preserves final xcresult, raw logs, evidence and a verified C1 source/artifact overlay archive. Restore the overlay onto baseline 817b67c in a new checkout; do not overlay a dirty owner checkout. Backup manifest supplies archive SHA256 and member hashes.
All changes remain uncommitted. No push, merge, C2 or C3 work occurred.

Next bounded milestone: explicitly review the reproduced save/reload candidate and Loop handoff before authorizing a separate gameplay repair or C2.
