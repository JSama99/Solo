# Chaos Crew C1 — production action client

Developer observation tooling. Production remains authoritative. No App source, formula, save migration, asset, historical Failure Ledger record or Canon record is modified.

## Gate A

`Tests/ChaosCrewMissionTests.swift` contains a small version-1 mission contract, explicit action enum, and a GameStore adapter. GameStore's standard save domain requires a disposable hosted lab. Construction is guarded before any GameStore access by the exact fresh simulator ID `40D4F1B3-092A-4E6F-9251-7A686A734B55` (iPhone 17 Pro Max, iOS 26.5). Other destinations skip; no default selection is authorized. Rebinding this guard requires explicit lab creation and review. The scheme and app target stay unchanged; four precise test-target project entries include the new file.

Each career uses ordinary setup, startCareer, thesis confirmation, generated tasks and authored agents. No resource, result, quality or preparation fixtures are installed. Two preparations are reviewed/resolved in sprint one, the third after a production sprint commitment. Routes vary doctrine, product identity, review order, dilemma choice and direct/Work Session review. Initial agent capabilities are the production roster; no exhaustive talent-market exploration is claimed.

## Gate B

Sixteen commands invoke GameStore: assign, delegate, review, approve, commit, presentation routing, reload, begin launch, decisions, release/public posture, execute, resolve, finish presentation, Product Focus and operating-time advance. The seeded fuzzer includes a valid route prefix, then chooses current/stale task references and command options from a separate explicit seeded generator. Its RNG never replaces or advances the GameStore RNG. All attempts count toward the 200-action ceiling. Launch failures classify as SEARCH_EXHAUSTED unless a real terminal outcome establishes VALIDLY_BLOCKED. Exhaustion is not proof of unreachable gameplay.

Action results distinguish accepted, intentionally rejected, unavailable and invariant violation. Idempotent commands may be accepted without state change. Rejected commands compare unrelated canonical state, excluding action-local Work Session preparation and documented launch debug counters. A reload compares every persisted CareerSave field to production-restored state through reflection with explicit aliases for derived fields; typed Hashable equality is authoritative before canonical encoding fallback, and missing observation seams fail closed. Each action has an autorelease pool to release temporary Foundation JSON allocations during long studies. Current schema v20 is checked at reload. Canonical encoding sorts only enumerated Codable Set fields, preserving ordered arrays. Fingerprints include full persisted envelope plus live task/agent/finance/Attention/calendar/preparation/product/RNG/session state. Raw private values are hashed locally and never exported. State fingerprints do not claim to cover every transient presentation field.

### Source-backed oracles

| Oracle | Production contract |
|---|---|
| Attention bounds | GameStore review/delegate/focus charges and attentionMaximum |
| Rejection scope | Guarded action methods; documented diagnostic/staging exceptions |
| Preparation single use | beginProductLaunch clears retained records; canonical effects applied once |
| Launch prerequisites | canonicalProductLaunchPreparations and beginProductLaunch snapshot |
| Product identity | resolveProductLaunch creates a product only if nil |
| Finance deduplication | repeated resolution cannot alter finance or Product; finance transaction IDs |
| Save/reload | SaveEnvelope v20 and GameStore.apply/continueCareer |
| Seeded replay | Identical seed + exact command sequence and canonical fingerprints |
| Review once | locked task resolution guard |
| Venture scope | retained preparations must belong to current venture |
| Public observability | Explicit Codable/output field allowlists; no serialized private results |
| Isolation | Positive dedicated lab guard plus protected source manifests |

Conditional invariants only claim coverage when their precondition is observed. Broader existing tests establish additional transitions; C1 does not fabricate transition reachability by setting sprint or stats.

## Gate C

Deletion minimization preserves the complete original trace and target invariant, with at most 256 trials. One representative per invariant is minimized in the study; all scenario traces survive. The controlled defect is a deliberately incorrect test-only duplicate-review observer, never a production mutation and never enabled in either study mission. Its two-action minimal reproduction proves detection, deletion and deterministic replay.

`Tools/ChaosCrew/c1.py` supplies deterministic source manifests, allowlist auditing, coverage aggregation, existing Ledger precedent retrieval and the exact F1 candidate schema. Genuine findings go only to FailureLedger/candidates as observation_only/CANDIDATE. A controlled candidate example is segregated in C1 evidence, never promoted. Evidence hashes are checked by existing F1 validate_candidate. Historical records and registries are untouched.

Existing Canon chaos_preflight and codex_preflight are reused. The reconstructed checkout contains the Loop Canon contract and generated caches, but no executable Loop graph runner. C1 therefore exports source manifests and replay evidence for review; it does not invent a replacement Loop engine or claim dispatch through an unavailable runner. This integration limitation must remain explicit in handoff.

## Running

1. Run Canon/F1 preflight and positively verify the dedicated lab.
2. Generate a source manifest with `python3 -B Tools/ChaosCrew/c1.py manifest --output <path>`.
3. Pass its sourceFingerprint as `C1_SOURCE_FINGERPRINT` to the hosted test runner. Run the three small tests first, with parallel testing disabled.
4. Run `testGateDFullBoundedStudy` only with `C1_FULL_STUDY=1`. It runs seeds 18180–18279 for each mission, then exact replays, bounded representative minimization and confirms minimal replays.
5. Export only `<lab app data>/tmp/C1-Evidence`, never owner data. Put the matching source manifest beside it. Run the offline summarizer to audit fingerprints and emit exact F1 candidates.
6. Preserve raw verification artifacts in the independent durable backup. No commits, promotion, gameplay repairs or C2 are part of C1.
