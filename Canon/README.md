# SOLO Canon v0.1 / C4

Canon is the project's reviewed knowledge authority: a small set of stable, sourced claims about where current SOLO truth lives and what contracts it carries. It guides Codex, visual and narrative work, and future context packs. Production Swift remains the authority for executable behavior. Report a conflict between a record and source code; do not silently rewrite either.

Canon is not `GameStore`, career save data, runtime simulation state, chat history, an LLM memory dump, embeddings, or automatically trusted AI output. C0 makes no gameplay or network calls.

## Record contract

JSON records live under `records/`. Their IDs survive file moves, use lowercase namespace-like names, and never encode display titles or incidental versions. The checked schema files document the envelope; the standard-library validator enforces the schema and cross-record constraints. `type` is extensible by a reviewed schema/validator change. Relationships use the bounded predicate vocabulary in the schema and must target another record ID. `sources` locate authoritative files or commits; `evidence` lists IDs of Canon `evidence` records. No seed record claims a P0 owner lock.

Loop V3 artifacts are a separate verification evidence system under `.solo-loop/`, not in-game `EvidenceEntry` records. A record may use `external_evidence` to point to a generated Loop run ledger by repository-relative path, SHA-256, run ID, graph ID, and final ledger head. The validator checks those identifiers and bytes when the artifact is present. A generated artifact may be absent from a fresh checkout; its locator remains valid for later audit, but the absent evidence is not treated as locally verified. Do not copy Loop ledgers into Canon or create mirror evidence records. The current Loop tree contains graph JSON, run state/result JSON, hash-chained JSONL ledgers, adapter outputs, and artifact manifests; it is untracked in this worktree.

## Lifecycle and authority

Lifecycle describes what happened to a claim. Authority ranks applicability independently of relevance. C0 permits the following level/status pairings (or `blocked` at any level to preserve a rejected attempt):

| Level | Kind | Normal status | Meaning |
| --- | --- | --- | --- |
| P0 | owner_locked | canonical | Explicit owner lock on current truth |
| P1 | production_canon | canonical | Current production truth |
| P2 | accepted | accepted | Owner/team accepted, awaiting or accompanying implementation |
| P3 | implemented | implemented | Implemented without owner lock |
| P4 | proposed | proposed | Candidate requiring promotion |
| P5 | experimental | experimental | Study or variant; cannot outrank production |
| P6 | historical | historical | Previously valid, retained for history |
| P7 | deprecated | deprecated | Superseded and invalid for new work |

`blocked` means an attempt/result must not be interpreted as accepted. P0/P1/P2 records require provenance. Authority never implies permission to disclose a record. Lower-authority experimental or historical material cannot override an applicable P0/P1 claim, regardless of textual or semantic relevance.

## Promotion and history

The controlled flow is **observation → proposal → evidence → validation → acceptance/promotion → Canon**. AI consumers may read authorized records, query them, derive context packs, create observations and proposals, and attach evidence. They may not promote themselves to P0/P1, replace owner locks, rewrite production Canon based on generated answers, or disclose restricted records. C0 promotion is manual. A promotion changes a reviewed record with its provenance and passes validation.

`valid_from` and `valid_until` are ISO calendar dates; `null` means open ended. Supersession uses reciprocal `supersedes` and `superseded_by` IDs. Retain superseded records and close their validity rather than deleting them. For exact competing claims, use `facts.truth_key` and `facts.truth_value`; the validator rejects distinct active P0/P1 values under one key. Human review remains necessary for semantic contradictions that do not share a key.

Seed records use 2026-10-03 as the verified C0 snapshot date. This does not claim the underlying feature first appeared on that date.

## Visibility

Scopes are explicit and nonhierarchical: `developer`, `simulation_internal`, `founder_known`, `agent_known`, `public`, `media`, `rival`, and `runtime_safe`. Multiple scopes may appear. A future consumer must be given an allowed scope set and only receive records with an explicitly allowed scope. `runtime_safe` is an affirmative grant, not a synonym for public. C0 began with no runtime-safe records; C7 explicitly reviewed seven for projection. Founder-facing and public consumers must also honor the game's reveal rules; the mere presence of `founder_known` does not reveal hidden simulation fields. Restricted values stay in production code and career state rather than copied into Canon summaries.

## Manifest and validation

`manifests/canon-manifest.json` is generated, checked in, and compared byte for byte. It indexes record IDs, metadata, and SHA-256 hashes of normalized record JSON, so a fact edit changes the manifest fingerprint. It is not an authority or embedding store. Paths are repository relative. Generate after a reviewed record edit, then validate:

```bash
python3 Tools/SoloCanon/validate_canon.py --write-manifest
python3 Tools/SoloCanon/validate_canon.py
python3 Tools/SoloCanon/validate_canon.py --record system.signal_tv
python3 -m unittest discover -s Tools/SoloCanon/tests -v
```

The validator sorts files, errors, visibility, and manifest entries. It has no network dependency. The manifest does not recursively define truth: records are the input, and a stale manifest fails validation.

## Deterministic retrieval

```bash
python3 -B Tools/SoloCanon/canon_query.py id system.signal_tv
python3 -B Tools/SoloCanon/canon_query.py search coverage --type mechanic --format json
python3 -B Tools/SoloCanon/canon_query.py resolve coverage
python3 -B Tools/SoloCanon/canon_query.py search camera --as-of 2026-09-20 --include-historical
python3 -B Tools/SoloCanon/canon_query.py id system.signal_tv --related-depth 1
python3 -B Tools/SoloCanon/canon_pack.py --consumer codex --task "Implement Signal TV media narrative integration"
python3 -B Tools/SoloCanon/canon_pack.py --consumer codex --task "Implement Signal TV media narrative integration" --format json --max-records 12
```

`id`, `search`, and `resolve` accept `--visibility`, `--as-of`, `--include-historical`, `--type`, `--status`, `--authority`, and `--tag`. Filters compose with AND. `--related-depth` is bounded to 0–2. Default direct CLI scope is `developer`; a record must explicitly contain the requested scope. Packs use fixed `codex`, `visual`, `narrative`, `chaos`, and `runtime` profiles. A pack's optional `--visibility` can only narrow its profile. Profile type preferences break close lexical ties; they never grant access. Since C7, the runtime Pack profile uses only `runtime_safe` and reads the reduced projection rather than full Canon records.

The effective default date is the later of the host date and the verified C0 snapshot floor, 2026-10-03. Use `--as-of` for an exact reproducible date. Future records are excluded; expired records appear only for a date inside their interval or with `--include-historical`. Search lowercases and splits on non-alphanumeric boundaries, including dots and underscores. It searches ID, title, tags, summary, facts, constraints, source paths, and visible relationship edges. Scores are additive: exact ID 1000, exact title 90, ID token 70, title token 35, tag token 25, summary token 12, fact or constraint token 8, source token 3, relationship token 2. Ranking uses authority level, status, score, then ID. Visibility and temporal checks run before scoring or graph traversal. The same checks filter every expanded target.

`resolve` reports an explicit P0/P1 `truth_key` conflict when applicable values disagree without valid supersession. It also reports the documented Coverage policy ambiguity without choosing an interpretation. Semantic contradictions without a structured key or ambiguity marker still require human review. Exit codes are 0 success, 1 no applicable result, 2 malformed invocation or invalid Canon, and 3 conflict or ambiguity.

Packs contain bounded records, reasons, concise facts, source paths, and any selected ambiguity. JSON and Markdown are canonical and contain no timestamp. Every query and pack includes the SHA-256 of the checked manifest plus a query fingerprint covering tool version, normalized query, effective date, scopes, filters, traversal depth, limit, consumer, and manifest hash. No embeddings, database, network, or LLM are used.

## Codex preflight (C2)

For substantial SOLO work, run the offline adapter before editing:

```bash
python3 -B Tools/SoloCanon/codex_preflight.py --task "Implement Signal TV media narrative integration"
python3 -B Tools/SoloCanon/codex_preflight.py --task "Implement Signal TV media narrative integration" --format json
python3 -B Tools/SoloCanon/codex_preflight.py --task-file /tmp/solo-task.txt --require system.signal_tv --require mechanic.coverage
python3 -B Tools/SoloCanon/codex_preflight.py --task "Implement Signal TV media narrative integration" --write-evidence
```

The explicit command always runs; its deterministic keyword classifier merely labels substantial task categories for future workflow use. The adapter identifies the current Git worktree, branch, HEAD, and short status, validates Canon and its manifest, then calls the C1 Codex Pack builder. It reports selected IDs, known conflicts and ambiguities, and a sorted, deduplicated source inspection plan. Inspect the listed source files before changing production behavior. `--require` checks exact IDs against the Codex profile and effective date; unavailable IDs block the preflight. Required IDs are recorded separately from the C1 lexical Pack, so the Pack bytes remain identical to direct C1 output.

Default text or JSON output is read only. `--write-evidence` creates a unique directory under `.solo-loop/evidence/canon-preflight/` with `codex-preflight.json`, `canon-pack.json`, and `canon-pack.md`. These are preflight handoff artifacts for Loop V3; the adapter does not append to a Loop run's hash-chained ledger or claim a verification result. A later Loop run may reference the artifact and add its own verification evidence. The Pack and preflight fingerprint exclude timestamps and Git state. The JSON wrapper includes those run-specific fields and may change between runs.

`INFO` covers dirty worktrees; `WARNING` covers known Canon conflicts or ambiguities that require inspection; `BLOCKING` covers invalid Canon, stale manifest, unavailable required records, or unknown Git state. Exit 0 means preflight passed, including warnings. Exit 2 means blocked; no trusted Pack or evidence artifact is written. The adapter does not resolve the documented Coverage mutation-authority ambiguity.

## Visual preflight (C3)

Run the offline visual adapter before character, environment, lighting, camera, material, animation, or world-presentation work:

```bash
python3 Tools/SoloCanon/visual_preflight.py --task "Improve Founder character animation fidelity"
python3 Tools/SoloCanon/visual_preflight.py --task "Improve Atlantis Founder District lighting" --format json
python3 Tools/SoloCanon/visual_preflight.py --task-file /tmp/visual-task.txt --require asset.founder.production
python3 Tools/SoloCanon/visual_preflight.py --task "Improve Founder Garage lighting" --write-evidence
```

The visual profile permits only `developer` and `founder_known` records. The adapter uses C1 validation, visibility, date filtering, and retrieval, then narrows the lexical result to visual topics and injects exact visible character, asset, location, and rule anchors. It classifies character, environment, lighting, camera, animation, materials, interior, asset, and presentation tasks with deterministic keywords. A Founder District lighting task is treated as an Atlantis environment task, not a Founder character task. Motion and camera tasks require `rule.reduce_motion_visual`. `--require` adds exact IDs and blocks on missing, invisible, or inactive records.

The Pack orders visual authority as P0 owner lock, P1 production, P2 owner accepted, P3 implemented, P4 proposed, P5 study, then P6/P7 historical. A blocked or experimental record is labeled `DO NOT USE AS TARGET` and excluded from `target_record_ids`; it may remain in the Pack as negative history. Production asset paths and reported hashes are references, not new hash verification. The accepted shoulder R1 is reference-only and does not replace the production Founder. Mara's Gate 1 shape and wardrobe are owner accepted; her runtime character is not. The Mara reference image path is recorded in the contract but absent from this checkout, so the adapter warns rather than treating it as a verified local file.

The source inspection list is sorted, deduplicated, and scoped to the task. For shared rules it selects the topic's relevant references. The Pack contains constraints from applicable target records and separate production assets, accepted references, and blocked studies. P0/P1 visual identity or production asset contradictions block the task. A request to replace an accepted Founder or Mara identity from scratch also blocks pending a new owner decision. Automated tests remain engineering evidence and never imply owner visual acceptance.

Default text or JSON output is read only. `--write-evidence` writes `visual-preflight.json` and deterministic `visual-pack.json` to a unique `visual-*` directory under `.solo-loop/evidence/canon-preflight/`. A policy-blocked request can write its reviewable artifact; invalid Canon or an unavailable required record cannot generate a trusted Pack. The visual Pack, query fingerprint, and visual preflight fingerprint exclude timestamps, paths used for output, and Git run metadata. The wrapper records the current branch, HEAD, short status, timestamp, notices, and result. It is a Loop V3 preflight handoff, not a run-ledger verification event. Exit 0 passes, including warnings; exit 2 blocks.

## Narrative Director preflight (C4)

The Narrative Director is **accepted P2 architecture**, not an implemented runtime system. It alone decides importance, reveal timing, audience, pacing, and narrative intent. Signal TV, Tech.com, rival, agent-dialogue, and continuity workers may later draft or check candidate expression; they cannot reveal hidden truth, change narrative state, promote Canon, decide an event's importance, or publish. Generated copy is never Canon. Current `PublicMediaEvent`, Signal TV, Tech.com, rival claims, Founder review, and Hindsight remain their separate P1 production systems.

```bash
python3 Tools/SoloCanon/narrative_preflight.py --task "Create a Signal TV story about a failed product launch" --channel signal_tv
python3 Tools/SoloCanon/narrative_preflight.py --task "Have a rival expose a hidden weakness" --channel rival --format json
python3 Tools/SoloCanon/narrative_preflight.py --task-file /tmp/narrative-task.txt --channel founder --require rule.hidden_truth
python3 Tools/SoloCanon/narrative_preflight.py --task "Report public Coverage" --channel signal_tv --write-evidence
```

The explicit channel choices are `director_internal`, `founder`, `signal_tv`, `tech_com`, `venture`, `rival`, and `agent_dialogue`. Director inspection may retrieve developer and internal scopes for control decisions. Channel disclosure is checked separately: Founder and Venture use `founder_known` plus `public`; Signal TV and Tech.com use `public` plus `media`; rival uses `rival` plus `public`; agent dialogue uses `agent_known` plus `public`. The internal channel is inspection only, not a publishing route. Relationship expansion and exact required IDs still pass Canon visibility and effective-date checks. The adapter never treats a developer-readable record as automatically revealable.

The Director Pack separates selected internal Canon, channel-revealable records, withheld records, conditional fact classes, withheld fact classes, continuity constraints, source inspection, and a limited future-worker handoff. That handoff contains allowed public fact **classes**, no hidden fact payload, and no Canon or publication authority. A public launch-outcome class is only conditionally usable: a current `isPublic` event must be confirmed in career state before publication. Static Canon cannot establish a particular launch failure, Founder review reveal, or historical event occurrence. A task that asks to disclose an unverified defect, drift, or hidden weakness blocks; a task that supplies hidden context while requesting only public coverage may pass with the hidden class withheld. Coverage tasks keep the mutation-authority ambiguity as a warning.

Task categories are deterministic: media story, rival story, agent dialogue, Founder feedback, continuity, reveal, event summary, and narrative arc. The Pack and narrative preflight fingerprint omit timestamps, run IDs, output paths, and Git metadata. Default output is read only. `--write-evidence` writes `narrative-preflight.json` and `narrative-pack.json` under a unique `narrative-*` directory in `.solo-loop/evidence/canon-preflight/`. A policy-blocked disclosure can be recorded for review; invalid Canon and unavailable required records cannot produce a trusted Pack. Exit 0 passes with possible warnings; exit 2 blocks. These artifacts are Director handoff evidence, not proof that copy was correct or published.

## Chaos Crew preflight (C5)

Chaos Crew is accepted P2 headless experiment architecture. C5 implements only its offline control contract. Production `GameStore` and `SimulationEngine` remain P1 simulation authority. Chaos may inspect permitted simulation Canon, specify deterministic experiments, and later submit observations, reproducible evidence, or proposals. It cannot mutate live player saves, change production formulas, publish narrative truth, rewrite Canon, or promote its own findings.

```bash
python3 Tools/SoloCanon/chaos_preflight.py --task "Search for a deterministic strategy that increases Momentum without proportional cost." --seed 8349232
python3 Tools/SoloCanon/chaos_preflight.py --task "Stress test whether companies can survive indefinitely with zero revenue." --seed 8349232 --format json
python3 Tools/SoloCanon/chaos_preflight.py --task "Stress test Momentum and Trust for infinite-loop exploits" --seed 8349232 --require mechanic.trust --write-evidence
```

An explicit unsigned decimal UInt64 `--seed` is required; there is no random or implicit seed. This version specifies single-seed reproduction. Multi-seed exploration requires separately identified seed contracts and run evidence. Categories are deterministic keyword matches for balance, exploit, economy, agent behavior, progression, rival behavior, resource loop, save invariant, and determinism. Categories select relevant mechanics, source paths, and invariant guidance. The adapter starts with the C1 Chaos profile (`developer`, `simulation_internal`) but restricts selected records to simulation mechanics, systems, and governance rules. A developer-visible unrelated visual or narrative record is not included. `--require` cannot bypass that relevance check.

The Pack contains source-backed invariants only: seeded RNG ordering and cached outcomes on supported paths; Coverage clamping to -100 through 100; and current save envelope version 20 for save tasks. These are contract checks to investigate, not proof that a future run passes. Scenario parameters are explicitly `to_be_specified` until a runner supplies them. The preflight does not execute simulations, identify an exploit, or claim zero-revenue survival. A current repository HEAD is stored in the run wrapper, while the deterministic Pack and fingerprint bind task, seed, manifest, C1 query, selected records, sources, invariants, scenario, and notices. Reproduction claims need the same code revision, Canon, seed, and scenario.

Findings move through `observed`, `reproduced`, `verified`, `proposed`, `rejected`, and externally `promoted`. The preflight observation template begins `not_run`, has no finding, and grants Chaos at most `proposed`; `promoted` requires independent Canon governance. An observed exploit therefore never changes a P1 mechanic. Coverage carries its existing mutation-authority ambiguity. A bounded Coverage experiment warns; an exhaustive “every strategy” Coverage request blocks because its completeness cannot be established. Automatic formula/Canon rewrites and live save mutations block. Invalid or stale Canon, missing simulation authority, unavailable required records, and malformed seeds fail closed.

Default output is read only. `--write-evidence` creates a unique `chaos-*` directory under `.solo-loop/evidence/canon-preflight/` with `chaos-preflight.json` and deterministic `chaos-pack.json`. The wrapper records timestamp, Git state, status, and notices. The artifacts are a Loop V3 handoff for later verification and do not append to its run ledger. Exit 0 passes, including warnings; exit 2 blocks. A policy-blocked request may write a reviewable artifact; invalid Canon cannot produce a trusted Pack.

## Hybrid semantic candidates (C6)

C1 structured lookup, lexical search, graph traversal, and resolution remain the default and authoritative path. C6 adds **opt-in candidate discovery**. The offline `solo-local-concepts` provider (`solo-concepts-v1`, version `1.0`) produces sparse word and curated concept features; it is a deterministic semantic approximation, not a trained embedding model. No local embedding model or library was available in the inspected environment. C6 adds no dependency, network request, cloud API, or iOS code.

```bash
python3 -B Tools/SoloCanon/semantic_index.py build
python3 -B Tools/SoloCanon/semantic_index.py check
python3 -B Tools/SoloCanon/canon_query.py search "news reacting to the player's company" --semantic --semantic-limit 8 --semantic-threshold 0.18
python3 -B Tools/SoloCanon/canon_query.py search "Coverage" --semantic --semantic-required --format json
python3 -B Tools/SoloCanon/codex_preflight.py --task "news reacting to the player's company" --semantic
python3 -B Tools/SoloCanon/narrative_preflight.py --task "news reacting to the player's company" --channel signal_tv --semantic
python3 -B Tools/SoloCanon/evaluate_hybrid.py --write-report
```

The generated index is `.solo-loop/cache/canon-semantic/index.json`. It contains only Canon record ID, title, summary, tags, facts, constraints, and relationship labels projected into sparse features. Its metadata binds the checked Canon manifest SHA-256, provider ID/version/model, sorted record IDs, record content hashes, and index format version. It is disposable cache data, never Canon or Loop evidence. Rebuild it explicitly after a Canon change. A missing, stale, mismatched, or malformed index yields `semantic_status: unavailable` and structured fallback with a warning; `--semantic-required` blocks instead. Default commands remain structured and do not access the index.

Hybrid retrieval calls C1 visibility, date, status, and metadata filters **before** scoring candidates. It excludes applicable superseded records. It then combines C1 lexical/graph hits with above-threshold semantic candidates and ranks by authority and status before relevance. Exact ID, strong lexical, strong semantic, graph, and stable ID are distinct signals. Similarity never changes record authority, discloses an invisible record, resolves a conflict, or chooses a side of the Coverage ambiguity. Results carry separate lexical score, graph reasons, semantic similarity, and explicit candidate reasons. The default threshold is `0.18`, with at most eight semantic candidates. The threshold is provider-specific and intentionally modest; the small evaluation corpus, rather than a claim of general semantic quality, shows its effect.

Hybrid Packs record retrieval mode, provider/model, index manifest and SHA-256, semantic candidates, status, threshold, and a query fingerprint covering query, consumer, Canon manifest, scopes/filters, provider/model/version, index SHA, threshold, and mode. Codex and Narrative Director preflights opt in with `--semantic`; Visual and Chaos remain structured. Narrative channel disclosure remains a separate check after Director retrieval. Given the same saved index, manifest, query representation, and retrieval code, ranking and JSON output are stable. This does not promise byte-identical embeddings across hypothetical future provider/platform changes; version and index hashes make such changes visible.

The fixed C6 corpus and [evaluation report](evaluation/C6_HYBRID_EVALUATION.md) compare structured top eight, semantic candidates, hybrid top eight, recall, authority order, and visibility. In this local corpus, mean recall@8 rose from `0.682` to `0.909` with no measured authority-order or visibility violations. The narrative-writer paraphrase remained a miss at top eight; candidate discovery alone does not guarantee final inclusion under authority-first ranking. These results do not justify making hybrid the default.

## Runtime-safe projection (C7)

Future runtime AI must consume a compiled projection, never the developer Canon tree. The compiler is read-only by default:

```bash
python3 -B Tools/SoloCanon/runtime_projection.py build --as-of 2026-10-03
python3 -B Tools/SoloCanon/runtime_projection.py inspect --as-of 2026-10-03
python3 -B Tools/SoloCanon/runtime_projection.py build --as-of 2026-10-03 --output .solo-loop/cache/runtime-canon/projection.json
```

The compiler grants access only to a record explicitly marked `runtime_safe` **and** carrying an authored `runtime_projection` block. `public` alone is insufficient. The C1 `runtime` Pack profile is also restricted to that projection, so a runtime Pack cannot expose a mixed source record. Each block supplies the only title, summary, scalar facts, tags, and optional relationship edges that may be emitted. The compiler does not copy the source record's mixed facts, developer summary, constraints, status, authority, visibility, sources, evidence, external evidence, supersession metadata, or implementation paths. The field-by-field treatment is encoded in `runtime_projection.FIELDS`. Current safe blocks cover Aurora, Stacks, Brio, Signal TV, Tech.com, Founder Garage, and Atlantis; each contains stable world identity rather than a current career event or hidden simulation state.

The runtime projection schema is `Canon/schema/runtime-projection.schema.json`, smaller than the developer Canon schema. It allows an `audience` enum for future `runtime`, `aurora`, `stacks`, `brio`, `signal_tv`, `rival`, and `founder` projections, but C7 emits only the common `runtime` audience. This enum does not authorize those consumers. C8 applies the narrower consumer policy after C7. C7 reads no live career state.

Only current canonical, accepted, or implemented records enter the projection. Historical, deprecated, experimental, blocked, expired, future, and applicable superseded records are excluded. An authored relationship must also exist in the source Canon relationship list. An optional edge to an ineligible target is omitted without emitting that target ID; a required edge to such a target blocks compilation. Malformed blocks, invalid Canon or manifest, duplicate projected IDs, unsupported edges, unsafe text, and schema/fingerprint mismatches fail closed. The current initial contract rejects developer paths and terms such as `GameStore`, `simulation_internal`, drift, overclaim, and latent defects as defense in depth; future public vocabulary changes require deliberate policy review.

Default `build` writes JSON to stdout. Only an explicit `--output` writes a generated artifact, preferably under `.solo-loop/cache/runtime-canon/`; it is cache data, not authoritative Canon or Loop evidence. Its SHA-256 covers policy version, Canon manifest, as-of date, sorted eligible IDs, and normalized projected content. It excludes timestamps. Repeating compilation with the same Canon, policy, and date yields identical bytes. The C6 developer semantic index is never included or shipped as runtime knowledge. Future runtime retrieval, if needed, must index this safe projection independently.

## Runtime Knowledge Gateway (C8)

C8 is an offline tooling boundary for future runtime AI. It is not connected to production Swift, `GameStore`, an LLM, or a live save. The gateway accepts only a validated C7 projection and an **already-authorized** state envelope matching `Canon/schema/runtime-state.schema.json`. It never reads the full Canon tree or the C6 semantic index. A caller must supply a current manifest SHA-256 or let the CLI hash the manifest file; a mismatched projection blocks. The projection date must equal `--as-of` when one is supplied.

```bash
python3 -B Tools/SoloCanon/runtime_gateway.py --consumer brio --state-fixture Tools/SoloCanon/tests/fixtures/runtime-state-before-review.json --format json
python3 -B Tools/SoloCanon/runtime_gateway.py --consumer signal_tv --state-fixture Tools/SoloCanon/tests/fixtures/runtime-state-before-review.json --audit --format json
```

State is a small list of `{id, kind, summary, visibility}` items, not a serialized `GameStore`. Labels are explicit and nonhierarchical. `public` reaches all seven consumers; `founder`, `aurora`, `stacks`, `brio`, `signal_tv`, `tech_com`, and `rival` reach only their named consumer. `agent_shared` reaches the three agents; `media_shared` reaches Signal TV and Tech.com. `simulation_internal` reaches none and may not be combined with another label. A self label never implies agent sharing, and Founder knowledge never implies public or media knowledge. Static Canon IDs are independently restricted by the consumer allowlists in `runtime_gateway.py`; those lists only remove records from C7. A projected relationship crossing that filter blocks instead of exposing its excluded target.

The gateway does not decide if a defect, event, or rival fact has been revealed. A future gameplay-owned projector must assign labels based on canonical review, public event, agent, and rival state. For example, only after Founder Review has authorized a finding may that item's input visibility gain `founder`. Changing this state envelope changes Founder context without modifying Canon. Production fields such as agent drift, actual quality, Work Session findings, and private runway must never be copied wholesale into the envelope. `PublicMediaEvent.isPublic` is a relevant production gate, but the C8 tooling does not independently verify the upstream projector.

Normal text and JSON include permitted Canon and state items, a count of withheld dynamic items, policy version, projection SHA-256, normalized state SHA-256, and a deterministic context fingerprint. They omit excluded IDs, reasons, and visibility labels. Explicit `--audit` adds those details for local developer inspection; do not send audit output to a runtime consumer. The state hash covers the entire authorized input envelope, including withheld items, so it is for reproducibility and should be treated as metadata rather than a content disclosure. The context fingerprint binds consumer, projection hash, state hash, policy version, as-of date, and included Canon/state IDs. Neither hash contains a timestamp. Schema failure, unknown consumer or visibility, duplicate ID, stale projection, and cross-policy relationship failure block without partial context.
