# C1.1 Save/reload finding review and bounded repair

**C1.1 REPAIR VERIFIED — READY FOR OWNER ACCEPTANCE**

Worktree: `/Users/jermainenelson/Documents/Solo-Reconstruction`; branch `codex/controlled-reconstruction`; HEAD `817b67cb7ee439711af200ddaef541e6c8bf0364` unchanged. Original C1 evidence and independent checkpoint remain preserved.
Original C1 fingerprint: `1cd8603413402d400770cbb0be73ba1798445640df10ceaa26f1eca329f20c7a`.
Current tested fingerprint: `46d66dc70899c33d900c232e735b89670c5cb7ed8ff6c8620d3070db811dccb9`.

## Phase A — confirmed defect

Canon and Failure Ledger preflight passed. The C1 manifest and all 200 raw replay hashes matched before editing. Only diagnostic tests changed during Phase A; production App source remained byte-identical to C1.
The original traces for seeds 18195 and 18279 reproduced. The representative 17 actions reproduced deterministically twice. Live tasks matched serialized tasks; restored tasks differed in exactly `tasks[2].result.hiddenActualQuality` and `tasks[2].result.hiddenDeliveredQuality`. Private controlled lab snapshots of all three task states and completed sessions are segregated under backup PrivateLabInputs, not exported into public reports.
Task `D467893F-D5E4-CA9D-7A11-E80816B202B5` was reassigned from Brio to Stacks after completing Brio's delegated session. Its UUID remained stable. Assignment produced/saved a legitimate new Stacks report. During load, apply(CareerSave) loaded tasks, sessions and reportCache, then restoreLegacyWorkSessionCausalQuality selected the old completed session by task UUID alone. The missing canonical delivered marker on the new Stacks result caused it to be mistaken for a legacy Brio result. This is a verified production persistence defect, not a Set/JSON observer mismatch.
The regression gate on unchanged production source failed three assertions (minimal sequence plus both original seeds), while the legacy restoration gate passed. Initial diagnostic pass intentionally asserted the pre-repair mismatch. Raw logs and source manifests preserve both observations.

An intermediate fresh study after the task/cache guards found one residual save_reload:evidence failure in seed 18279. It minimized to 22 actions. A new lab diagnostic confirmed a Stacks Evidence entry was rewritten by an Aurora session: actualQuality and overclaimAmount changed. That before-repair 22-action trace and segregated private snapshots are preserved. The Evidence identity guard closes the same confirmed restoration cause without changing recordEvidence or review scheduling.

## Phase B — bounded correction

Only App/GameStore.swift production behavior changed: task restoration now requires assignedAgentID to match session.agentID; cached-report restoration matches both taskID and agentID; Evidence restoration maps session.agentID to the persisted canonical agent name, as existing legacy migration does, and matches that name plus taskInstanceID. Legacy conversion remains in its existing restoration order. Valid same-agent historical sessions restore their original potential/review/delivered quality without rescaling task effects.
No new save fields or migrations. Save version remains 20 and optional backward decoding is unchanged. No scheduling, Attention, financial, traction, media or Work Session lifecycle redesign. The bounded repair covers the confirmed assignment identity mismatch; it does not claim every possible historical-session ambiguity has been solved.
FailureLedger/evidence.json EV-006 is current-source evidence: its hash was deliberately refreshed for the edited GameStore. No historical incident, accepted rule or lesson changed.

## Phase C — fresh verification and comparison

157 Swift tests passed, zero failures: eight C1 tests, 115 gameplay/finance/launch/traction regressions and 34 Work Session tests. Includes 17-action replay, both original seeds, minimized 22-action Evidence replay, valid completed-session and legacy Evidence persistence, documented legacy representation, reload idempotence, duplicate actions, cross-sprint preparation and exact deterministic replay.
Fresh 100 launch + 100 fuzz scenarios, seeds 18180–18279: {'REACHABLE': 200}. Original C1 classifications: {'INVARIANT_FAILURE': 2, 'REACHABLE': 198}. Original save_reload:tasks occurrences: 2; current occurrences: 0. No unrelated C1 invariant violations in the fresh study.
Attempted actions: 22511; exact replay actions: 22511; reloads: 1753; action results: {'accepted': 9282, 'rejected_by_design': 13229}. Study elapsed 762.317 seconds, excluding compilation and other tests. Every primary replay hash and current source manifest was verified.
Canon 357 tests and 45-record validation passed. Failure Ledger 34 tests, validation and generated registry check passed. Seven C1 Python tests passed. iPhone test build and separate iPad build passed.
The first full-study attempt was deliberately interrupted in the dedicated lab after F1 tests exposed a missing-evidence fixture dependency. Tools/FailureLedger/tests/test_ledger.py now copies validated candidate evidence into its temporary repository. The intermediate 200-scenario run then exposed the residual Evidence defect; it is preserved and distinguished from final passing evidence. The final complete 200-scenario run used the corrected source fingerprint; interrupted evidence is not claimed as current passing evidence.

## Phase D — observation-only review

The original CF-c1-ca78b88c9c0e candidate is preserved byte-identically in Review/CF-c1-ca78b88c9c0e-original.json and the earlier independent C1 archive. Its original trace, seed, source fingerprint and REPRODUCED status remain historical facts. The current candidate adds hashed FindingReview and Comparison evidence and states that the bounded repair passed. reviewStatus remains CANDIDATE and authority remains observation_only. No incident, rule or Canon promotion occurred.

## Phase E — Loop, isolation and checkpoint

Existing solo-loop reused with C1.1-Loop.json. Canon, Ledger, Failure Ledger tests, C1 Python contracts and current study/source audit command nodes passed. Run `solo-chaos-crew-c11-verification-4ede4bf996` paused at explicit owner review. Ledger chain verified: `4b306cd74b56459588437ddef839a81461965ecd6680912c1f155946cd8a3af9`. No approve or promotion command ran; logical evidence acceptance never authorizes broader changes. The original C1 human gate also remains untouched.
All hosted tests ran on dedicated C1 iPhone lab `40D4F1B3-092A-4E6F-9251-7A686A734B55`; iPad build targeted dedicated lab `37C6DF3F-87F5-4F57-A882-B4B7D11A12F5`. No owner simulator/reset/save operations were used. All writes were confined to reconstruction, new independent backup and temporary verification output. No unrelated dirty checkout or asset writes.
Independent checkpoint: `/Users/jermainenelson/Documents/Solo-Reconstruction-Backups/ChaosCrew-C1.1-20261009`. Source-and-evidence overlay is restored onto exact baseline 817b67c in a new checkout; empty-directory extraction and all-member byte comparison passed. CheckpointManifest.json records archive and file hashes. Earlier C1 archive SHA256 a0a56b2ea9bd0d6fa750194446e496d61f4073a2226dc1794560fe4f8499dff8 reverified unchanged. Full inventory distinguishes C1.1 modifications from inherited uncommitted C1 files and two inherited caches.

## Limits and owner decision

The study covers bounded initial careers and 16 commands, not all gameplay states. Peak memory and extra minimizer trials are not separately measured. No visual/audio acceptance claim. Coverage authority and Cash/Runway unresolved design decisions remain unchanged.
Owner acceptance is pending. Recommended next step: review the narrow GameStore diff, candidate review and fresh comparison; decide whether to accept C1.1. No commits, pushes, merges, C2 or C3 occurred.
