# SOLO Core Experience Pass 1 — Consequence Chain Map

Status: **BASELINE MAP / AUDIT CONTRACT**

## Goal

Map the intended causal route for a major founder judgment and identify which links already exist in production versus which links still need an explicit contract.

## Chain

### 1. Assignment

**Existing production systems:** tasks, assigned agent, role fit, Work Session, seeded task result generation.

**Required observable:** stable task/agent identity and pre-decision context.

### 2. Agent work / report

**Existing production systems:** reported quality, evidence completeness, verification state, actual hidden quality, correlated failure identifiers.

**Required observable:** what the founder can see versus what remains hidden.

### 3. Uncertainty / deception class

**Existing production distinctions:** unverified/reported, evidence incomplete, overclaimed, drift detected, confirmed/verified.

**Audit concern:** these distinctions can still collapse into similar player behavior if their downstream consequences are not differentiated.

### 4. Evidence

**Existing production systems:** Evidence Ledger with reported value, optional actual value, review state, overclaim amount, evidence completeness, Work Session metadata.

**Required observable:** evidence available at decision time, not only after the fact.

### 5. Founder judgment

**Existing production choices:** approve, rework, ship anyway, cross-check; deliberate unreviewed commit is also possible when Attention is exhausted or withheld.

**Required observable:** one stable `sourceDecisionID` attached to downstream effects.

### 6. Agent consequence

**Existing production behavior:** review outcomes can mutate agent trust, relationship, calibration and drift.

**Gap:** downstream effects are not yet required to preserve a visible causal link back to the founder judgment.

### 7. Company state

**Existing production systems:** runway, revenue, momentum, trust, energy, capital, coverage, flags, obligations, latent defects, scheduled effects.

**Gap:** major decisions can change these values without a unified event-chain assertion.

### 8. Media / world reaction

**Existing production systems:** PublicMediaEvent, coverage deltas, Tech.com, Signal TV programming, rivals, Atlantis living-world presentation.

**Gap:** not every strategically major outcome is contractually required to produce an appropriate public/world reaction.

### 9. Future constraint

**Existing production systems:** recurring obligations, latent effects, lower resources, altered agent state, changed public coverage, rival context, company flags.

**Gap:** the next meaningful decision is not yet explicitly linked to the prior decision in an inspectable trace.

### 10. Hindsight / precedent

**Existing production systems:** deterministic precedent identity, contextual matching, recorded overclaims/drift/unverified load and trust/runway/momentum deltas.

**Gap:** precedent context is primarily sprint-level and does not yet strongly encode agent-specific behavioral history.

### 11. Next decision

**Target behavior:** player recognizes that the current choice has meaning because of remembered prior behavior and changed company/world conditions.

**Current risk:** the systems contain the history, but the live decision may still read as a fresh isolated choice.

---

## First-divergence point for Pass 1

The audit classifies the first major product-level divergence as the transition from **Founder Judgment** to **attributable multi-system consequence**.

Upstream contracts—seeded report generation, hidden truth, review, evidence and overclaim detection—already have direct tests. Downstream systems exist, but the repository does not yet contain one golden sequence proving that a single founder judgment remains attributable through delayed consequence, world/media response, precedent and the next decision.

## Next implementation boundary

Core Experience Pass 2A should not add a new major feature. It should add enough observability and narrowly scoped integration to prove one full chain using an existing production decision scenario.

The pass should be rejected if it only demonstrates a final stat delta.