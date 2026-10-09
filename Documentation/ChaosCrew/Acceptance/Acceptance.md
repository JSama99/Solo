# C1 / C1.1 engineering acceptance and publication inventory

Owner acceptance: 2026-10-09, explicitly scoped in OwnerDecision.md.
Accepted gameplay/test fingerprint: `46d66dc70899c33d900c232e735b89670c5cb7ed8ff6c8620d3070db811dccb9`.
Acceptance metadata fingerprint: `13e49a24605263882b8dd2cd778ff55f86c68bd9138596aa6c443f8341d2ee01`. The difference is solely Failure Ledger evidence, the reviewed FL-015 record and its record-count test; every production Swift file, C1 Swift test, save model, asset integration and prevention rule matches the accepted source.

FL-015 is explicitly reviewed and RESOLVED with established root cause and correction, using the existing FailureRecord schema. AUTHORITY_CONFLICT describes stale session state overwriting current assignment authority. The original candidate remains observation_only/CANDIDATE; its reviewed and original bytes remain preserved. No binding lesson, prevention rule or new required gate was created.

Current technical evidence: 157 Swift regressions, 200 exact scenario replays (22,511 primary actions, 22,511 replay actions, zero invariant violations), 357 Canon tests, 34 Failure Ledger tests, seven C1 tooling tests, iPhone/iPad builds. Hosted tests were not rerun for metadata-only acceptance processing. Python tests and validators were rerun after FL-015 review.

The owner-authorized C1.1 Loop gate passed. Its original run hit the configured seven-step limit after all nodes passed/promoted. That evidence was preserved; a separate graph with an eight-step budget completed using the same existing runner, source, evidence and authorization. LoopAcceptance.json supplies both verified chain heads. No Loop engine changes. The earlier C1 run remains a historical record; this acceptance applies to corrected C1.1 source and verification evidence.

StagingInventory.json is the exact file list. Only source, project membership, relevant tests, reviewed Ledger metadata, documentation, compact source hashes, summaries and curated public 17/22-action reproduction traces are included. Full 200-scenario replay sets, raw archives, private controlled simulation values, simulator data, xcresults, logs and generated caches are excluded. They remain in independent C1 and C1.1 backups. Historical Loop study graphs require the retained full evidence set to be restored for reexecution; the public summaries do not substitute for those files.

Prior verified checkpoints: ChaosCrew-C1-20261008 archive SHA256 a0a56b2ea9bd0d6fa750194446e496d61f4073a2226dc1794560fe4f8499dff8; ChaosCrew-C1.1-20261009 archive SHA256 b76cc325b05099907014e7dd43c59acdd613638a46352e6f79f51e4415b230aa. Both independently preserved and reverified.

Publication is authorized only on codex/controlled-reconstruction, parent 817b67cb7ee439711af200ddaef541e6c8bf0364, normal fast-forward to JSama99/Solo. No main merge, additional gameplay or C2.
