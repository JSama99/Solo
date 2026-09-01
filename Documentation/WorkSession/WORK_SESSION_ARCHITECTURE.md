# Aurora Work Session — Production Architecture

## Canonical flow

`SimulationEngine.makeResult` remains the only authority that decides how well Aurora performed. When Aurora is assigned eligible Research & Evidence work, `TaskResult` already contains canonical hidden actual quality before any founder interaction occurs.

The Work Session adds a bounded operationalization layer:

1. `agentPotentialQuality` snapshots that canonical hidden result when the stable assignment session is created.
2. `founderReviewQuality` is computed only from the founder's persisted Evidence Triage decisions. Delegation deliberately has no manual-review score.
3. `deliveredQuality` applies a deterministic extraction tier and is clamped to `agentPotentialQuality`.
4. `TaskResult.applyWorkSessionOutcome` stores Founder Review and Delivered Quality beside the untouched hidden actual quality. It scales the already-created immediate company effect downward but never rewrites Aurora's truth or adds quality.
5. SOLO's existing review, resolution, Evidence, consequence, and Hindsight paths resume afterward.

The three values are separate fields in both `WorkSessionRecord` and canonical `TaskResult`. When the sprint Evidence ledger is written, it snapshots all three values plus causal attribution and typed findings so later Hindsight does not depend on live task state.

## Causal consumer routing

Delivered Quality controls company output:

- `TaskResult.immediateEffects` is proportionally bounded when the Work Session completes.
- sprint revenue, momentum, trust, energy, and runway application consumes that bounded effect.
- facility revenue multipliers and commercial-revenue accounting consume the same bounded effect.
- projected precedent effects consume the bounded effect.
- sprint `strongOutcomes` uses delivered strength rather than Aurora's underlying strength.

Original Agent Quality continues to control Aurora evaluation and truth:

- verification, overclaim, and earned actual-quality reveal
- agent strong/risky classification
- agent XP, stress, reliability/trust, and recovery inputs
- Work Session potential and Hindsight attribution

Delayed effects remain based on the original canonical result. They encode latent evidence/correlation exposure, including negative risk, rather than the size of the immediate usable payoff; scaling them down after a poor review could incorrectly erase risk. Latent-defect creation likewise remains evidence-completeness/correlation based. These are the only semantically ambiguous consumers found in the audit, and both intentionally retain their pre-existing meaning.

## Reusable foundation

`WorkSessionEngine` models agent identity, assignment identity, family, stakes, path (`manualReview`, `delegate`, future `autoReview`), stable challenge seed, potential, cards, decisions, review quality, delivered quality, typed findings, Attention charge, and idempotent completion state.

Only `.evidenceTriage` is playable. Stacks, Brio, progression-tree UI, and Auto Review are intentionally outside this build. The data model does not require replacement to add them.

`WorkSessionStakes` remains a compact persisted input (`routine`, `important`, `critical`, `companyDefining`). It is positioned beside family and assignment identity, allowing future generators, Attention policy, consequence routing, and Hindsight significance to consume it without migrating decisions or challenge identity. This pass intentionally adds no timers, card-count inflation, or multi-stage critical flow.

## Determinism

Challenge identity is derived from:

- canonical career seed
- venture and sprint
- stable task UUID
- agent ID
- versioned Evidence Triage salt

Cards are selected and ordered by stable mixed hashes from a twelve-card pool; neither Swift global randomness nor the simulation RNG stream is consumed. Aurora's observable stress band is snapshotted at creation and may increase the set from six to seven cards. Later agent-state changes do not regenerate an in-flight session.

Evidence templates carry lightweight retention, pricing, market, product, customer, competition, growth, and operations tags. `SoloTask` can provide an explicit topic; a conservative title/detail mapper handles obvious existing assignments. Tagged sessions deterministically reserve at least half of the normal selection for matching templates when available, then preserve stable hash order. Untagged sessions use the original twelve-card pool and original seed identity exactly, so existing generic generation does not change.

Delegation uses the same challenge seed for a bounded 75–79% extraction baseline. Equivalent state, assignment, seed, and choice therefore produce equivalent output.

## Hidden-truth boundary

`EvidenceTriageCard` owns private ideal action, weight, contradiction truth, and topic tags. Views receive only `EvidenceCardPresentation`, which contains source text, headline, detail, provenance, position, and count. It contains no correctness, tags, score, Agent Quality, Founder Review Quality, Delivered Quality, drift, overclaim, or verification state.

The UI uses neutral card materials and does not change color, sound, haptic, animation, order, accessibility value, or label based on hidden correctness. Classification feedback acknowledges input only. Immediate completion reports a qualitative Founder Review label and operational counts; it never displays potential, delivered, or hidden actual quality.

Automated tests reflect over presentation fields and inspect VoiceOver metadata for protected terms.

## Save, replay, and duplicate safety

`CareerSave.workSessions` decodes to an empty array for legacy saves. Each record uses the task UUID as assignment authority and stores generated cards and every decision.

- Challenge preparation returns the existing record instead of rerolling.
- Manual Attention is charged behind `founderAttentionCharged` exactly once.
- Each card ID accepts one decision in sequence.
- Completion requires every card and is one-way.
- Delivery mutation is guarded by `completionApplied`.
- Canonical review and Evidence recording retain their existing duplicate guards.
- Completed records remain in the career ledger for later Hindsight.
- App interruption, backgrounding, navigation, and process termination restore the exact card order, decisions, Attention cost, and completion state.
- Legacy records decode the former `mistakes` arrays into typed findings. If a first-prototype save contains a completed session whose TaskResult actual quality was destructively reduced, load repair restores the original value from persisted `agentPotentialQuality`, records the other causal values, and deliberately does not scale company effects twice.

## Findings and Hindsight

`WorkSessionFinding` gives each observation an explicit positive or negative polarity. Negative findings include accepted weak evidence, rejected strong evidence, failed ambiguity verification, and over-verification. Positive findings include correctly detected contradictions, correctly flagged high-risk ambiguity, and correctly preserved strong evidence.

The record derives whether constrained delivery primarily reflects Aurora's output, Founder Review, both, delegation, or preserved potential. Findings and that attribution generate factual Hindsight notes, including recognition of strong founder judgment. `EvidenceEntry` persists the original Agent Quality, Founder Review Quality, Delivered Quality, typed findings, attribution, and notes. None is added to current Evidence or Work Session presentation; existing earned-reveal timing remains authoritative.

## Accessibility and feedback

Evidence Triage is untimed. Large buttons provide the complete Reject / Verify / Use path on iPhone and iPad; no swipe or reaction-speed requirement exists. Dynamic Type uses flexible stacks and `ViewThatFits`. VoiceOver reads only visible evidence content and neutral instructions. Reduce Motion removes travel transitions but is absent from simulation and scoring APIs. Audio and haptics reuse existing settings-aware infrastructure and never signal correctness.

## Known limitations

- Aurora Research & Evidence assignments only, by scope.
- Auto Review is modeled but not exposed.
- Swipe classification is not included; buttons are the primary and complete path.
- Hindsight explanations are persisted in canonical Evidence now; a future earned-reveal screen may choose when to surface them.
- Task-aware selection has an explicit/inferred topic foundation and a small tagged pool; broad authored coverage for every assignment remains future content work.
- Challenge stakes and Aurora condition affect stored metadata and overloaded card count; broader stakes-specific pools belong to later balancing, not this causal pass.

Estimated completeness relative to the intended Aurora-first canonical Work Session design: **94%**.
