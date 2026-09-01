# Aurora Work Session — Production Architecture

## Canonical flow

`SimulationEngine.makeResult` remains the only authority that decides how well Aurora performed. When Aurora is assigned eligible Research & Evidence work, `TaskResult` already contains canonical hidden actual quality before any founder interaction occurs.

The Work Session adds a bounded operationalization layer:

1. `agentPotentialQuality` snapshots that canonical hidden result when the stable assignment session is created.
2. `founderReviewQuality` is computed only from the founder's persisted Evidence Triage decisions. Delegation deliberately has no manual-review score.
3. `deliveredQuality` applies a deterministic extraction tier and is clamped to `agentPotentialQuality`.
4. `TaskResult.applyWorkSessionDelivery` scales the already-created deliverable and immediate effects downward when review loses potential. It can never add quality.
5. SOLO's existing review, resolution, Evidence, consequence, and Hindsight paths resume afterward.

The three values are separate fields in `WorkSessionRecord` and are directly unit tested.

## Reusable foundation

`WorkSessionEngine` models agent identity, assignment identity, family, stakes, path (`manualReview`, `delegate`, future `autoReview`), stable challenge seed, potential, cards, decisions, review quality, delivered quality, mistake classes, Attention charge, and idempotent completion state.

Only `.evidenceTriage` is playable. Stacks, Brio, progression-tree UI, and Auto Review are intentionally outside this build. The data model does not require replacement to add them.

## Determinism

Challenge identity is derived from:

- canonical career seed
- venture and sprint
- stable task UUID
- agent ID
- versioned Evidence Triage salt

Cards are selected and ordered by stable mixed hashes from a twelve-card pool; neither Swift global randomness nor the simulation RNG stream is consumed. Aurora's observable stress band is snapshotted at creation and may increase the set from six to seven cards. Later agent-state changes do not regenerate an in-flight session.

Delegation uses the same challenge seed for a bounded 75–79% extraction baseline. Equivalent state, assignment, seed, and choice therefore produce equivalent output.

## Hidden-truth boundary

`EvidenceTriageCard` owns private ideal action, weight, and contradiction truth. Views receive only `EvidenceCardPresentation`, which contains source text, headline, detail, provenance, position, and count. It contains no correctness, score, hidden quality, drift, overclaim, or verification state.

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

## Mistakes and Hindsight

The session persists accepted weak evidence, rejected strong evidence, failed ambiguity verification, over-verification, and correctly detected contradictions. Explanations are generated from the stored classifications, copied into the canonical `EvidenceEntry`, and remain available to future Hindsight presentation without revealing card truth during play.

## Accessibility and feedback

Evidence Triage is untimed. Large buttons provide the complete Reject / Verify / Use path on iPhone and iPad; no swipe or reaction-speed requirement exists. Dynamic Type uses flexible stacks and `ViewThatFits`. VoiceOver reads only visible evidence content and neutral instructions. Reduce Motion removes travel transitions but is absent from simulation and scoring APIs. Audio and haptics reuse existing settings-aware infrastructure and never signal correctness.

## Known limitations

- Aurora Research & Evidence assignments only, by scope.
- Auto Review is modeled but not exposed.
- Swipe classification is not included; buttons are the primary and complete path.
- Hindsight explanations are persisted in canonical Evidence now; a future earned-reveal screen may choose when to surface them.
- Challenge stakes and Aurora condition affect stored metadata and overloaded card count; broader stakes-specific pools belong to later balancing, not this prototype.

Estimated completeness relative to the intended Aurora-first canonical Work Session design: **91%**.
