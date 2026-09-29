# SOLO Core Experience Pass 1 — Baseline Report

Status: **AUDIT COMPLETE — implementation not started**  
Branch: `core-experience-pass1`  
Production baseline: merged `main` after PR #91  
Save version: **20**

## Executive finding

SOLO already contains most of the systems required for its strongest market position: **founder judgment under uncertainty with persistent AI agents**. The main risk is not missing simulation breadth. It is that the player-facing causal chain is not yet proven to make those systems feel like one memorable founder story.

The production code already distinguishes reported quality from actual quality, preserves hidden truth before review, models evidence completeness, overclaiming, drift detection, agent trust/calibration/drift, delayed effects, persistent company flags and obligations, public coverage, rivals, Hindsight precedents, seeded randomness, and multiple career structures. The highest-leverage work is therefore **integration of consequence, readability, and history into the decision loop**, not another broad feature layer.

The first implementation pass should target one deterministic founder-decision scenario and make its full consequence chain readable before adding content breadth.

---

## 1. Current gameplay loop

The canonical sprint structure is:

`Founder Event → Choose Commitments → Assign Team → Review and Resolve → Commit Sprint`

The player selects a founder dilemma response, chooses three commitments from a larger opportunity set, assigns agents, receives generated reports, optionally spends Founder Attention to review work, resolves reviewed tasks with Approve / Rework / Ship Anyway / Cross-Check, and commits the sprint.

This already contains the skeleton of the intended founder loop, but the current phase contract is broader than the target emotional loop:

`Assignment → Agent Work → Report → Uncertainty/Deception → Evidence → Founder Judgment → Consequence → World Reaction → Hindsight → Next Decision`

The first five links are substantially represented. The final five are present as separate systems but are not yet contractually required to appear as one causal story.

### Baseline assessment

**Strong:** assignment, hidden truth, review cost, resolution choice, seeded determinism.  
**Weak:** readable causality across delayed consequences and future decisions.  
**Risk:** the player can experience the sprint as procedural task completion rather than a trust judgment.

---

## 2. Current agent decision model

### Existing strengths

The production model already separates several important states that must remain distinct:

- reported quality versus actual quality;
- unverified/reported work;
- evidence-incomplete review;
- confirmed/verified work;
- overclaimed work;
- drift-detected work;
- agent trust;
- calibration;
- drift;
- relationship;
- model-family correlated failures;
- workload/operations allocation;
- persistent Work Session records.

Current tests prove that identical seeds reproduce the same task result, different seeds can differ, actual quality remains hidden before review, overclaims are detectable, incomplete evidence can prevent actual-quality revelation, correlated model-family failures can affect multiple agents, and cached reports cannot be rerolled by reassignment or relaunch.

### Main defect

The simulation knows more about agent reliability than the **player's decision context visibly remembers**.

Hindsight currently matches primarily on sprint-level conditions: doctrine, intent, drift band, runway band, and unverified load. That is useful but does not yet make a decision strongly agent-specific. A player deciding whether to trust Stacks should be able to feel that Stacks's particular history matters without being handed a single reliability number that solves the choice.

### Core opportunity

Make the next judgment depend on **behavioral history**, not just present report state. Examples of useful history classes:

- repeated overclaim under launch pressure;
- strong performance when evidence completeness is high;
- drift after sustained workload;
- poor calibration in a particular task family;
- successful autonomy after prior founder non-intervention;
- degraded autonomy after repeated unnecessary overrides.

Do not expose these as a universal score. Surface them through context, precedent, language, evidence, and consequences.

---

## 3. Current consequence propagation

SOLO already has the parts needed for multi-system consequence:

- immediate and delayed simulation effects;
- latent defects and scheduled effects;
- Evidence Ledger;
- company flags;
- recurring obligations;
- Tech.com/public media events;
- coverage;
- rival standings and rival moves;
- Signal TV presentation;
- Hindsight precedents;
- persistent decision history;
- career and venture outcomes.

The weakness is contractual rather than architectural: a major founder decision is not currently required to generate a readable chain across these systems.

### Current pattern

`Decision → task resolution → simulation effects`

Additional systems may react, but the player is not guaranteed to receive a single causal narrative tying them together.

### Target pattern

`Decision → agent state → evidence state → company state → public/world reaction → future constraint → precedent → changed next decision`

### Highest-risk gap

A consequence can be mechanically real but emotionally invisible. A delayed trust penalty or later media event is much weaker if the player cannot answer **“this happened because I trusted Stacks two decisions ago.”**

---

## 4. Current onboarding path

The new-career path is currently:

`Title → Choose Mode → Founder Setup → Product → Doctrine → Venture Thesis → Garage → Founder Event → Commitments → Assignment → Report/Review → Resolution → Commit`

The How to Play material explicitly explains verification, agents, the Garage, Tech.com, setup choices, and progression.

### Baseline defect

The player encounters several identity/configuration concepts before experiencing the core trust loop. Career mode, product type, doctrine, thesis, and the physical workspace all precede the first decisive moment of **“Do I trust this agent?”**

This does not prove the onboarding is too long in elapsed minutes; repository inspection cannot measure human reading speed or confusion. It does prove that the interaction path contains multiple conceptual gates before the first agent judgment.

### Onboarding baseline questions to measure on device

- first screen: Title;
- first required action: Choose Mode;
- first agent assignment: after setup/thesis and commitment selection;
- first report: after assignment;
- first evidence review: optional and Attention-gated;
- first founder judgment on agent work: reviewed-task resolution or deliberate unreviewed commit;
- first consequence: sprint commit/report;
- first multi-system visibility: after commit when report/media/evidence/world state can coexist.

### Recommended direction for later implementation

Do not explain more. Reach the first trust decision sooner, then teach surrounding systems as they become relevant.

---

## 5. Current progression structure

Six facility tiers exist:

1. Founder Garage
2. Founder Loft
3. Small Office Room
4. Office Suite
5. Small Company Building
6. Unicorn Headquarters

Current progression requirements use Track Record, capital cost, completed careers, and environment availability. Garage and Loft are currently environment-available; later facilities are still future environments.

### Baseline defect

Progression is stronger as an **unlock/economy ladder** than as a **founder-problem ladder**.

The desired stage questions are not yet encoded as progression contracts:

- Garage — Can I survive?
- Loft — Can I find product-market fit?
- Small Office — Can I delegate?
- Office — Can I build an organization?
- Small Building — Can I maintain quality while complexity grows?
- Big Building — Can I control an institution larger than myself?

### High-leverage direction

Before producing later facility environments, define the decision pressure each facility unlocks. A new headquarters should earn its existence by changing the decision model, not only the scenery or stat bonus.

---

## 6. Current Atlantis gameplay utility

Atlantis has substantial production infrastructure: shared-world traversal, district loading, interaction targets, living-world presentation, named NPC/encounter support, rivals, Tech.com/media context, and physical traversal continuity.

### Baseline assessment

Atlantis is **ahead in spatial infrastructure and behind in unique strategic necessity**.

The audit did not find a production contract requiring each district to offer a decision that cannot be performed more efficiently from the Founder Computer.

That makes further city expansion low-return until district-specific gameplay utility is defined.

### Required future contract

Every district must answer:

> Why would the founder physically come here?

Valid answers include investor access, rival observation, recruiting, customer evidence, hidden information, media opportunities, regulation, special events, or irreversible opportunities. “Because the district exists” is not sufficient.

---

## 7. Current replayability mechanisms

Existing replayability sources include:

- deterministic seeded simulation;
- Daily Challenge;
- bounded Career;
- continuous Empire mode;
- product type;
- founder doctrine;
- sprint intent;
- venture thesis;
- procedural task/report outcomes;
- rivals;
- correlated model-family failures;
- Divergence/fork system;
- persistent company flags and obligations;
- Hindsight precedents;
- headquarters progression;
- achievements;
- multi-venture comparison.

### Baseline risk

The number of variable systems is high, but **system count does not prove decision variety**.

The missing measurement is whether the same founder policy wins too consistently across seeds and contexts. In particular, the audit should assume possible dominant strategies around “review whenever possible,” “always choose the safest resolution,” or “optimize a single doctrine pattern” until repeated-seed traces prove otherwise.

### Required measurement

Track repeated-choice rate, dominant-strategy rate, multiple-plausible-action rate, and how often agent history changes the preferred action.

---

## 8. Current dominant and weak loops

### Strong loops

**Verification loop**  
Report → review cost → truth reveal or evidence insufficiency → resolution.

**Resource-pressure loop**  
Runway / Energy / Attention constrain how much certainty the founder can buy.

**Persistence loop**  
Company flags, obligations, decisions, precedents, progression and save state allow choices to survive beyond a single screen.

**Seeded uncertainty loop**  
Reports are reproducible but not automatically truthful; reload/reroll exploits are already guarded.

### Weak loops

**Agent-history loop**  
History exists, but the live trust judgment is not yet strongly shaped by agent-specific precedent.

**Consequence-explanation loop**  
Multiple systems can react, but a full causal chain is not yet a verified gameplay contract.

**World-utility loop**  
Atlantis can be traversed and interacted with, but strategic reasons to leave the desk are not yet strong enough.

**Progression-problem loop**  
Facility progression changes access and bonuses more clearly than it changes the nature of founder judgment.

**Onboarding-core-loop loop**  
The player configures several systems before directly experiencing SOLO's sharpest differentiator.

---

## 9. Competitive-risk assessment

### Highest competitive risk: simulation breadth obscures the hook

SOLO has accumulated many competent systems. The commercial danger is becoming “a detailed startup sim with AI flavor” instead of “the game where you learn whether to trust persistent AI coworkers under pressure.”

### Second risk: numeric legibility solves uncertainty

If trust, drift, calibration, quality and evidence become too directly readable, the player performs arithmetic instead of judgment. Numbers should support interpretation, not replace it.

### Third risk: honest-assistant convergence

If Aurora, Stacks and Brio mostly announce uncertainty and request approval, their personalities and failure modes converge. Overclaiming, drift, miscalibration and honest uncertainty must lead to different decisions and different consequences.

### Fourth risk: consequences feel detached

Delayed effects create depth only if attribution survives the delay. Otherwise they feel random or unfair.

### Fifth risk: progression becomes cosmetic

Visual headquarters upgrades are not enough to sustain a long-form management game. Later stages must create qualitatively different information and delegation problems.

---

## 10. Top 10 highest-leverage improvements

Ranked by expected Core Experience value, not implementation convenience.

1. **Create a deterministic full decision-chain contract.** Prove one scenario from report through delayed consequence, media/world response, Hindsight, and changed future pressure.
2. **Make agent-specific history matter at the moment of judgment.** Preserve ambiguity; do not expose a single “correctness score.”
3. **Differentiate uncertainty, overclaim, drift and miscalibration in downstream consequences.** They should not collapse into the same review-and-fix response.
4. **Add causal attribution across delayed consequences.** The player should be able to trace an outcome back to the founder decision that caused it.
5. **Stress-test micromanagement versus autonomy.** “Let Stacks Decide” should sometimes be correct, and unnecessary intervention should have an understandable cost.
6. **Shorten conceptual distance to the first meaningful trust decision.** Teach setup systems after the player has experienced the core loop where possible.
7. **Define progression-stage decision contracts before building later environments.** Each facility must introduce new information/delegation failure modes.
8. **Measure dominant strategy across fixed seeds.** Do not assume the current option set produces meaningful tradeoffs.
9. **Give Atlantis district-specific strategic utility before visual expansion.** One unique decision opportunity is worth more than another decorative block.
10. **Create a mobile re-entry summary centered on causality and next action.** On return, the founder should quickly understand what happened, why, and what matters now.

---

## First-divergence conclusion

At the architecture level, the first major divergence between the intended experience and the verified baseline is **not report generation** and **not hidden truth**. Those are already well supported.

The first divergence is after founder judgment: the repository does not yet prove a mandatory, attributable, multi-system consequence chain that reaches world reaction, durable precedent, and changed future decision pressure.

That should be the starting point for the next implementation classification.

---

## Phase 1 stop condition status

- [x] Baseline audit
- [x] Deterministic decision-loop fixture definition
- [x] First-divergence observability contract
- [x] Consequence-chain map
- [x] Onboarding baseline
- [x] Replayability assessment
- [x] Top-priority defect ranking
- [x] Core Experience Baseline Report

**STOP:** Do not begin broad implementation automatically.

### Next-pass classification

Recommended next pass: **Core Experience Pass 2A — Consequence Chain Proof**.

Scope should be one deterministic scenario, one causal chain, no broad content expansion. It should prove that a founder judgment can propagate through agent state, evidence, company state, media/world feedback, future pressure, and Hindsight while preserving save version 20 and all accepted-state ratchets.