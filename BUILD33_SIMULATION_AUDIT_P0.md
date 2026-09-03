# Simulation Design Audit — P0 Remediation

Three P0 findings from the gameplay/simulation audit, scoped against Build 32
(`WorkSessionEngine`, `CompanyFinance`, and the Living Company visual layer).
Each task shipped independently with tests and was confirmed before the next
began.

**Status:** complete. Build clean, 634 tests, 0 failures.

| Commit | Task | Change |
| --- | --- | --- |
| `645d2b4` | 1 | Delegate costs 1 Attention; manual Work Session flat 2; Guided 3 → 2 |
| `3177add` | 1 | Delegated work excluded from the career-score quality bonus |
| `c7405a0` | 2 | Facility upgrades carry forward across headquarters moves |
| `261cd17` | 2 | Four tier payloads, monthly obligations, sixth roster slot |
| `529d9a5` | 3 | Seeded, no-immediate-repeat venture objectives |
| `d335e76` | 2 | Monthly obligations proven against the financial ledger |

`c7405a0` was committed from a parallel conversation sharing this working tree
while Task 2 was in progress. It contains the prerequisite carry-forward fix
and is counted as part of Task 2.

---

## Task 1 — Delegation was a free bypass of the game's core scarcity

### What was wrong

`delegateWorkSession` never charged `founderAttentionSpent`. A delegated
session still satisfied `review()`'s free path (`if completedWorkSession == nil`),
so the task ended fully `isReviewed` at zero cost. The UI chain — Delegate →
Continue → `finishWorkSessionReview` → `store.review` — reached that state in a
single tap, on the only forward exit from the sheet.

The extraction curve was never the problem. Delegate resolves to 0.75–0.79 of
potential quality; manual review ranges 0.60 → 1.00 by review quality, breaking
even near 75. That is the intended "mediocre but safe" shape and was left alone.

The cost side was the bug, and it was worse than scoped:

```swift
var workSessionAttentionCost: Int { min(3, attentionMaximum) }
```

A manual session consumed the **entire** sprint budget — 3 of 3 under Guided,
2 of 2 under Pure/Trust. With three tasks per sprint a player could not
manually review more than one work-session task even if they wanted to. For
tasks two and three, Delegate was not merely dominant, it was the only option.

Compounding it, `protectFounder` (`founderAttentionSpent <= 1`) was satisfied
for free by delegating everything — an objective designed to reward review
restraint, cleared by the action that avoided review entirely.

### What changed

| | Before | After |
| --- | --- | --- |
| Delegate | 0 | **1** |
| Manual Work Session | `min(3, attentionMaximum)` | **flat 2** |
| Guided `attentionMaximum` | 3 | **2** |

Decoupling the manual cost from `attentionMaximum` fixed a second latent
defect: the Founder Command Desk grants +1 Attention every third sprint, but
under the old formula the manual cost scaled with the budget and consumed the
bonus on exactly the sprints it applied to. The upgrade paid for nothing.

Delegation is charged once at the point of delegation, guarded against
insufficient budget, and writes its real cost back onto the session record so
the summary stops reporting the manual price.

Delegated work is now a **distinct, lesser verification tier**. It still clears
the neglect penalty — it remains a legitimate safety valve — but does not
satisfy `evidenceFirst`, `repairTrust`, or the `verifiedEvidence` career-score
bonus. This is derived from the already-persisted work-session `path`, so it
adds **no save state and no migration**.

`protectFounder` kept its `<= 1` threshold. The delegation charge flows through
`founderAttentionSpent`, so the objective became meaningful again without
touching it.

### Resulting tradeoff

Three eligible tasks, 2 Attention:

- **Delegate ×2** — budget exhausted, third task neglected. `evidenceFirst` ✗,
  `protectFounder` ✗.
- **Manual ×1** — one task genuinely founder-verified, two neglected.
  `evidenceFirst` ✗ (needs two).
- **Delegate ×1** — one task safe, `protectFounder` ✓, one Attention in hand.

Every row now costs something and forfeits something.

---

## Task 2 — Facility tiers 3–6 were priced, gated, and empty

### What was wrong

Two defects sat on top of each other.

**The tiers were unreachable.** `purchaseResult` hard-blocked on
`environmentAvailable`, which is `false` for all four. Every purchase returned
`.futureEnvironment`. No payload would ever have been reachable regardless of
what was attached to it.

**Moving up a tier deleted every upgrade you owned.** `bonuses` filtered active
upgrades with `requiredFacility == currentFacility`, and all five upgrades
declare `requiredFacility: .founderGarage`. Measured, with all five purchased:

```
garage → engineeringQuality 4, auroraEvidence 8, marketingRevenue 1.1,
         sprintEnergyRecovery 3, periodicAttention 1, agentXP 1.1
loft   → engineeringQuality 0, auroraEvidence 0, marketingRevenue 1.0,
         sprintEnergyRecovery 0, periodicAttention 0, agentXP 1.0
```

Buying the Loft cost 7,500, destroyed 5,400 of upgrades, started a 3,400/month
rent, and returned a +5 energy bonus. It was a straight downgrade. This was a
previously known finding from the Build 31 audit; it resurfaced independently
here.

### What changed

**Upgrades carry forward.** The filter is now
`requiredFacility.rawValue <= currentFacility.rawValue`. Tier perks accumulate
for the same reason — you keep what you built.

**Ownership decoupled from rendering.** `environmentAvailable` is a fact about
art, not a purchase gate. A tier without built art can be owned, charges its
rent, and grants its payload, while `currentFacility` — which the entire Living
Company visual layer reads — never advances past a tier that has art. A new
`operatingTier` (highest owned) drives bonuses and obligations. The flag itself
was not flipped and no new environment is claimed.

**Four distinct payloads**, cumulative, on the axes capacity → attention
economy → compounding growth → defense:

| Tier | Cost | Payload | Monthly |
| --- | --- | --- | --- |
| Small Office | 5,000 | Sixth roster slot (`talentSlotBonus`) | 4,200 |
| Office Suite | 6,000 | −1 Energy per review, floored at 1 | 5,400 |
| Company Building | 7,000 | `agentXPAnyRoleMultiplier` 1.2 on all work | 6,800 |
| Unicorn HQ | 8,000 | Absorbs 50% of rival move pressure | 9,000 |

Three details worth recording:

- **The review discount can never reach zero.** Applied as
  `max(1, reviewEnergyCost - discount)`. `reviewEnergyCost` is one of only
  three numbers differentiating the doctrines, and Pure/Trust already sit at 1.
- **The XP bonuses compound multiplicatively.** The Garage bonus is
  role-matched, the Company Building's training floor is not, so they are
  separate fields. Role-matched work at a Company Building earns 1.1 × 1.2 =
  **1.32**.
- **Rival resistance touches `playerEffects` only.** Rival `strengthBonus` and
  the market-share math are untouched; damping a rival's own growth would be a
  different and much larger change. It does not interact with `exposedRivalIDs`,
  which scales *rival strength* rather than *player pressure* — different
  quantities, so no compounding.

**Sixth slot content.** Four new named candidates (Meridian, Kiln, Verity,
Cadence) in a dedicated 4,200–5,600 band, with real pitch copy. The hardcoded
"fourth/fifth" roster copy now reads from `nextTalentSlotLabel`.

**Monthly obligations** follow the Founder Loft precedent on a 30-day cadence.
The Loft keeps its legacy `loft-monthly-N` transaction ID so saves that already
paid a month are never re-charged; new tiers use `facility-N-monthly-M`.

### Ledger trace (30 operating days, fresh store)

```
Founder Garage     space=[none]                              30d expense= 1,980  cash 2500→520
Founder Loft       space=[loft-monthly-1        3,400]       30d expense= 5,380  cash 2500→0
Small Office Room  space=[facility-2-monthly-1  4,200]       30d expense= 6,180  cash 2500→0
Unicorn HQ         space=[facility-5-monthly-1  9,000]       30d expense=10,980  cash 2500→0
```

**The rent figures are not validated.** Cash reaches 0 within 30 days at every
tier including the Loft, and at the Garage — with no rent at all — 2,500 falls
to 520. Daily burn dominates early-career cash regardless of facility. This is
a fresh store rather than an Empire-era one with real revenue, so it is not
proof of a problem, but nothing here demonstrates the figures are affordable.
A 24-sprint probe never left venture 1, while these tiers gate on
trackRecord 12–20 *and* 1–4 completed careers. The escalation shape is right;
the magnitudes remain a playtesting question.

---

## Task 3 — Venture objectives were fully predictable

### What was wrong

```swift
eligible[(venture * 7 + era.rawValue * 3) % eligible.count]
```

A pure function of the venture number, identical in every career. Learn the
schedule once and predict it forever.

### What changed

Selection is seeded on `(careerSeed, venture)` with no immediate repeats.

**Approach: pure peek, not caching.** Selection draws from its own
deterministic hash channel — the pattern `RivalEngine.unitRoll` established —
rather than the shared `SeededRandomNumberGenerator`. Two consequences:

1. The checkpoint preview of venture N+1 **cannot** diverge from what venture
   N+1 actually selects, because both evaluate the same pure function on the
   same inputs. No cache, no reconciliation, no second save field.
2. The RNG draw sequence is **not touched anywhere**. Divergence, Daily
   Challenge, and `WorkSessionEngine` card generation are unaffected by
   construction rather than by careful ordering. The audit's requirement to
   confirm the draw sequence is unchanged is satisfied trivially: zero draws
   were added or moved.

### Call sites

Eight, not the seven scoped — and in three categories, not two:

| Sites | Category | Handling |
| --- | --- | --- |
| `GameStore:666`, `:1698` | Commit | Select and record in the window |
| `GameStore:1754` | Preview | Pure peek |
| `GameStore:1739`, `:1769`, `:2494`, `:2637`, `VentureScreenPresentation:83` | **Fallback read** | Pure peek |

Five of eight are `ventureObjective ?? selected(...)` fallbacks for the
*current* venture, firing only when the stored objective is nil. The original
scoping did not anticipate this category. The preview is at `:1754`, not the
`~1607` scoped.

### A flaw caught during implementation

The first implementation blocked the two most recent objectives
unconditionally. Real sequences collapsed:

```
Ada/saas:   pmf → durable → proof → pmf → durable → proof → …
Grace/mktp: durable → pmf → proof → durable → pmf → proof → …
```

Early eras offer only three eligible objectives, so blocking two left exactly
one legal pick — a rigid 3-cycle the seed merely phase-shifted. Still
predictable after three ventures, which is the failure this task exists to fix.

The rule now never narrows the pool below two genuine choices:

```
Ada/saas:   pmf → durable → proof → durable → proof → pmf → durable → proof → pmf → durable
Grace/mktp: durable → pmf → durable → proof → pmf → durable → pmf → proof → pmf → proof
Lin/saas:   proof → durable → pmf → proof → pmf → proof → durable → proof → pmf → durable
```

`testEarlyObjectiveSequenceIsNotAFixedCycle` pins the regression.

`CareerSave` gains `recentVentureObjectiveIDs`, decoded with
`decodeIfPresent ?? []` so existing saves migrate with zero data loss.

---

## Test coverage

**634 tests, 0 failures.** These six commits introduce 33 test functions, 4 of
which replace existing tests asserting behavior this audit deliberately
superseded — a net **+29**. The suite stood at 602 when the audit began; the
remaining growth comes from parallel Founder Garage work that landed on the
same branch. No assertion was loosened.

| Task | Added | Coverage |
| --- | --- | --- |
| 1 | 11 | Delegate cost and single-charge idempotency across all three eligible agents; manual cost holding at flat 2 on a Command-Desk-boosted sprint with the bonus still spendable; founder-verified vs delegated tier split; delegation costing real Attention under every doctrine; `protectFounder` surviving one delegation but not two, through the real evaluator via `commitSprint` |
| 2 | 13 | Per-tier cumulative bonuses; XP stacking pinned at 1.32 with both owned; review-energy floor across all doctrines; escalating obligations; obligation reaching the ledger with correct amount, attribution, and recurrence; Loft legacy transaction ID; sixth-slot candidates and band exclusivity; rendered facility never advancing to unbuilt art |
| 3 | 9 | Preview matching actual through the real checkpoint path; peeking side-effect-free across 12 forward ventures; no shared-RNG consumption; different seeds producing different sequences; no immediate repeats; no fixed 3-cycle; era gating; legacy save decode and round trip |

Rewritten: `testDelegateCostsNoAttentionAndIsIdempotent`, the Campaign and
Systems `…CostsNothing…` pair, the Guided-at-3 assertion in
`SimulationEngineTests`, and `testFutureEnvironmentBlocksBuild2Purchase`. Each
carries a comment explaining why and referencing its task.

---

## Out of scope — flagged, not actioned

1. **Work Session eligibility now excludes only Talent Board hires.** The audit
   asked whether Aurora/Stacks-only eligibility warranted a follow-up. That
   premise is stale: Brio became eligible in `bff2eef` via
   `campaignCalibration`. The real gap is that **no hired agent ever receives a
   Work Session** — including the four new sixth-slot candidates added in
   Task 2. Five named agents get the deep verification loop; every hire costing
   4,200–5,600 gets plain `review()`. This is narrower and more clearly worth
   doing than originally scoped, and it now interacts with a tier the player
   pays 5,000 plus 4,200/month to unlock. **Recommended as a follow-up order.**

2. **Delegated work still earns full agent XP and progression.** Task 1's
   lesser-tier treatment stops at objectives and career score. `evidenceVerified`
   also feeds agent XP (`GameStore:2236`), `verifiedTasks` (`:2243`), and
   Divergence (`Divergence.swift:180`), which were deliberately left untouched.
   Whether delegation should also be a lesser tier for *agent growth* is a
   design question, not a bug.

3. **`WorkSessionPath.autoReview` is dead.** Defined at
   `WorkSessionEngine.swift:12`, implemented at `:701` with extraction 0.86 —
   more generous than delegate — and referenced nowhere in production. Left
   exactly as-is by instruction.

4. **`migrateV12` now depends on `founderName`/`productType`** to derive the
   career seed when backfilling an objective. Harmless today since it is only a
   nil fallback, but worth knowing if migration logic changes.

5. **Facility monthly obligations stop being charged if a save's owned set is
   empty but `currentFacility` is not.** Not reachable through current code
   paths — `purchase` always inserts into `ownedFacilities` — but `operatingTier`
   falls back to `.founderGarage` (rent-free) rather than to `currentFacility`,
   so a hand-edited or corrupted save would silently stop paying rent.
