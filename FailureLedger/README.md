# SOLO Failure Ledger v1

Developer-only historical intelligence. Canon answers authority questions; this ledger supplies historical precedents and reviewed development prevention rules. It does not override Canon, authorize gameplay changes, expose runtime state, or promote observations automatically.

## Use

From the repository root:

```sh
python3 -B Tools/FailureLedger/validate.py
python3 -B Tools/FailureLedger/build_registry.py --check
python3 -B Tools/FailureLedger/build_registry.py --task "Modify Product Launch readiness"
python3 -B Tools/SoloCanon/codex_preflight.py --task "Modify Product Launch readiness"
python3 -B -m unittest discover -s Tools/FailureLedger/tests -v
```

Registry generation is read-only unless `--write` is explicit. It produces `FailureLedger/registry/DO_NOT_DO.md` and `Documentation/FailureLedger/FailedFixes.md`. Results use exact lexical/system tags, stable score/ID ordering and no network or embeddings. The existing Canon pack, manifest, runtime projection and runtime gateway are unchanged. Only the developer Codex preflight artifact gains a separately labelled `failure_precedents` section and its fingerprint.

## Knowledge and acceptance

- Every mandatory field is explicit. `null` means unknown, never a guessed date or cause; `unknownInformation` explains limitations.
- Observation, incident confirmation, cause confidence, lesson acceptance and prevention-rule acceptance are separate fields. Confirmed incidents can have unknown causes.
- F1 engineering review accepts narrowly scoped development prevention rules supported by inspected evidence. This is **not Canon promotion**. Canon conflicts require an authority decision.
- Candidates cannot support accepted registry rules. Proposed lessons/rules remain separate from accepted rules. A resolved incident does not automatically accept a lesson.
- Evidence IDs resolve to repository-relative safe paths, complete file SHA256 hashes, kinds and locators. Current source describes current implementation; historical reports/patches are historical test evidence, not fresh passes. Source changes require deliberate evidence review and fingerprint refresh; stale hashes block preflight rather than silently trusting outdated precedents.
- Specific root causes and failed attempts are included only where surviving evidence supports them. Weight painting is not banned. Cash/Runway mechanics are not changed.

## Chaos candidate contract

`schemas/candidate.schema.json` defines a development-side observation interchange format. `candidates/example.json` is a synthetic format example, not a discovered failure or a C1 run. It requires mission/scenario, seed, source fingerprint, ordered action trace, expected/observed behavior, nullable invariant violation, evidence locators/hashes and reproduction status. Review status is **CANDIDATE only**, authority is **observation_only**. Reproduced is not accepted. No candidate-ingestion promotion exists. Explicit engineering review must create a separately evidenced FailureRecord and reviewed rule; Canon promotion remains governed by existing Canon rules.

Candidate files are schema-checked and their evidence hashes are verified; their findings never enter accepted retrieval/rules automatically. The example fingerprint is explicitly synthetic. Future emitters must supply their actual source fingerprint and real evidence. No mission runner, simulation engine, simulator operation or runtime dependency is introduced.

## Failure safety

Missing/corrupt schema, record, rule or evidence files; duplicate IDs; unsafe paths; stale evidence; invalid enum values; unknown references; unsupported schema features; or candidate promotion block clearly with exit code 2. Legacy Canon roots lacking both the integration tool and ledger retain their previous preflight behavior. Installed F1 roots cannot silently ignore a missing ledger. Tooling uses Python standard library only, including an explicit subset validator for the checked-in JSON Schemas.
