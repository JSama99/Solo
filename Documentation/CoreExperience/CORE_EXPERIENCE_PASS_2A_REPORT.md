# SOLO Core Experience Pass 2A — Consequence Chain Proof

Status: **COMPLETE**  
Baseline: `origin/core-experience-pass1`  
Save version: **20 (unchanged)**

## 1. Scenario selected

Stacks receives a critical engineering assignment, **Launch Readiness**. Stacks reports quality 86 with an 80–92 confidence range, while verifier-visible actual quality is 42 and evidence completeness is 30%. Founder review returns `evidenceIncomplete`, so actual quality remains hidden. The founder chooses **Ship Anyway**.

## 2. Why it was selected

This is the narrowest production path that tests SOLO's central question: whether to trust a confident agent under launch pressure. It already used canonical assignment, report, verification, Evidence, resolution, latent-defect, company-state, media, and Hindsight systems.

## 3. Baseline event chain

`Assignment → report → incomplete evidence → Ship Anyway → latent defect → later company-stat loss`

The upstream chain was already deterministic and secrecy-safe. The delayed failure ended as a stat mutation.

## 4. First divergence

`GameStore.commitSprint` removed surfaced defects before `prepareSprint`. The existing next-sprint defect-feed loop therefore could not observe them. No canonical `PublicMediaEvent` was produced, and the later Hindsight precedent described the current sprint rather than the originating founder decision.

## 5. Causal hypothesis

If the canonical `LatentDefect` retains the originating task, agent, and resolution, then its existing deterministic ID can carry attribution into one public projection and one factual Hindsight record without adding another event, evidence, or history system.

## 6. Smallest implementation change

- Added optional origin task/agent/resolution fields and a computed `sourceDecisionID` to `LatentDefect`.
- Projected a defect into the existing `PublicMediaEvent` ledger only when it surfaces.
- Passed surfaced defects into the existing precedent recorder and stored optional source identifiers.
- Added one deterministic test fixture and only the Xcode membership entries required for that file.

## 7. Final event chain

`Stacks assignment → quality-86 report → evidenceIncomplete review → Evidence retains report and hides actual quality → Ship Anyway → DEF-V1-S1-5c73a79e8a0555df → four-sprint delay → Momentum -6 / Trust -8 / Runway -4 → public Coverage -10 → Tech.com + Signal TV → factual Hindsight precedent → later context retains lower Stacks trust and negative Coverage`

## 8. Deterministic fixture

`Tests/CoreExperienceDecisionLoopTests.swift` records ten typed trace events. Every event includes an event ID, source-decision ID where applicable, owning system, summary, and state delta. Its comparator stops at and reports the first mismatched event. The fixture compares a fresh replay and a mid-chain save/load continuation against the first trace.

## 9. Hidden-truth protection

Before the defect surfaces, `.evidenceIncomplete` keeps `TaskResult.revealedActualQuality` and `EvidenceEntry.actualQuality` nil. The public event contains only the observed production failure. It contains no actual quality, overclaim amount, correlation ID, or private verification state.

## 10. Seeded RNG

No RNG draw was added. Defect, decision, media, Tech.com headline, and precedent identities derive from existing deterministic state. Fresh replay and restored continuation end with the same RNG state as the reference trace.

## 11. Hindsight

The precedent remains factual and non-prescriptive. It records that Stacks' launch-readiness work later failed after the founder shipped despite unresolved evidence, the measurable outcome, source decision ID, source agent ID, and delayed consequence ID. Existing deterministic precedent identity remains unchanged.

## 12. Public media

One surfaced defect creates one public event through `GameStore.applyPublicMediaEvent`. Tech.com reads that ledger through `mergedOwnCompanyHeadlines`; Signal TV reads the same event through `publicBroadcastEvents`. The stable event ID preserves deduplication.

## 13. Save compatibility

Save version remains 20. All new persisted fields are optional. The fixture decodes a pre-Pass-2A latent-defect payload with no attribution fields and proves a scheduled defect survives save/load with its remaining trace unchanged.

## 14. Tests run

- Pre-change baseline: Ship Anyway test plus Hindsight and Signal TV suites — 33 passed.
- Pass 2A focused fixture — 2 passed after one fixture-isolation correction.
- Tier 2 regression: consequence-loop, store, simulation, Hindsight, precedent, Signal TV, and Tech.com suites — 131 passed, 0 failed, 0 skipped on iPhone 17 Pro Max (iOS 26.5).
- `Solo Unicorn Run` scheme build for the generic iOS Simulator — passed. RevenueCat emitted existing Swift compiler warnings; no build error remained.

## 15. Rejected attempts

The first fixture compared cumulative Coverage exactly after save/load. It exposed an unrelated 6-point difference from ambient unresolved press-inquiry timing. That field was rejected as a gold-chain comparator; the fixture now asserts the defect event's exact Coverage delta and negative next-decision pressure. No production implementation alternative was required.

## 16. Remaining limitations

- Hindsight recall is still primarily sprint-context matching and does not yet surface agent-specific precedent directly at assignment/review time.
- Existing ambient feed penalties can differ around restoration independently of this chain and deserve a separate save-continuity audit.
- This pass proves one Stacks scenario; it does not generalize the contract across all tasks or failure classes.

## 17. Recommended Pass 2B classification

**Agent-specific decision-context integration.** Surface factual, ambiguity-preserving behavioral history at the next relevant assignment/review decision, without converting it into a universal reliability score.
