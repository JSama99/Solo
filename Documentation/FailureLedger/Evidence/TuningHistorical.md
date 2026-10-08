# P3 Slice 1 — Bounded tuning pass

Date: 2026-10-05. Candidate: uncommitted `codex/loop-v3-integration`; exact source fingerprints and evidence are in [provenance.json](provenance.json).

| Gate | Engineering classification |
| --- | --- |
| FIT TUNING | **PASS** |
| GROW BALANCE | **PASS** within the tested 12-cycle scenarios |
| RESEARCH LOW-CAPABILITY | **PASS** |
| CASH ↔ RUNWAY | **DESIGN DECISION REQUIRED**; investigation only |
| Overall | **READY FOR OWNER ACCEPTANCE** of the bounded T1–T3 pass |

Slice 1 is **not owner-accepted**. Slice 2 remains unopened. No Venture 2 purchase or additional owner sprint is needed. The owner's review simulators, career and accepted visual baselines were untouched. Cash/Runway changes require a separate design decision and were not implemented.

## T1 — Fit aggregation and readability

`ProductTractionEngine.presentation` now calculates recent retention as total retained / total retention-eligible customer observations across the existing three-period window. It reads canonical period counts only; hidden quality, alignment and value never enter presentation. Old period records and their stored percentages are not rewritten.

For the owner's observed history, 0/1 plus 13/16 becomes **13/17 = 76%**, rather than the equal-period mean of 40%. With positive observed growth that history projects Promising, still with **Low** confidence. A one-customer loss remains in the denominator. Equal-exposure samples retain equivalent weighting, subject to final integer rounding.

Confidence previously required two measured periods and Research, but did not count customer exposure. Moderate now additionally requires at least **20 retention-eligible observations**; this is an explicit conservative evidence floor, separate from Fit thresholds. Existing Weak/Declining and Strong/Breakout rules otherwise remain intact. The observation text now displays the weighted repeat-retention percentage and exposure count. These observations can include the same customer over several periods; they are not claimed to be unique customers.

Focused tests cover tiny versus large cohorts, equal exposure, weak/declining outcomes, growth without healthy Fit, hidden-truth invariance, preserved old history, and version-20 decoding. Isolated matched search results show fewer A→B→A reversals for Always Improve (68→44) and Monetize (316→312), with Grow and No Focus unchanged (12 and 220). Research also decreases (68→56), although its actual progress was corrected at the same time. **This is not a claim that all label oscillation disappears**: the three-period net-growth window still responds to actual Focus cadence, and adaptive branches can change trajectories. That behavior has not been artificially suppressed.

## T2 — Grow candidate selection

One acquisition lever was investigated while keeping cost, activation, retention and Brio capability conversion unchanged:

| Candidate | Matched search result | Decision |
| --- | --- | --- |
| Unchanged Grow bonus, with T1/T3 corrections | Grow beats rotation in ending customers/revenue/cash in every cell | Baseline |
| Halve the additional Grow bonus | Grow still beats rotation in customers/revenue in every cell; cash win rate 89.4% | Rejected |
| Divide additional bonus by 1 + Grow uses in the last three cycles | Contextual cash/revenue and later-customer tradeoffs emerge | Selected |

The selected rule uses existing observed Focus history. It adds no simulation authority, cooldown state or save field. An occasional Grow has the **same full acquisition bonus as before**. Repeated recent use reduces only extra reach; base acquisition continues. Three other cycles restore the full bonus. Counting recent uses prevents immediate full reset through Grow/no-focus alternation. The player-facing tradeoff states that recent Grow cycles reduce extra reach.

### Larger confirmation

**19,008 trajectories**, 1,728 per policy, 12 cycles each: all four ProductTypes × three existing launch fixtures × low/medium/high agent capabilities × three production allocation presets × seeds 1–16 × 11 policies. This is half the prior full-study size. Each of the three search cohorts used seeds 1–4 and 4,752 trajectories. Seeds are paired blocks, not independent repetitions across every product/capability cell.

| Comparison: Always Grow versus… | Grow wins ending customers | Grow wins cumulative revenue | Grow wins ending isolated cash |
| --- | ---: | ---: | ---: |
| Adaptive | 55.2% | 95.4% | 35.0% |
| Rotation | 100% | 59.0% | 43.6% |
| 1 Improve → Grow | 7.4% | 74.3% | 20.0% |
| 1 Research → Grow | 18.1% | 95.8% | 31.8% |

Ties account for the remaining share where neither policy wins. Grow remains attractive for early acquisition and often cumulative revenue; it no longer wins every major economic measure across most alternatives. Median ending customers are 36 for Grow and Adaptive, 37.5 for Improve→Grow, and 36.5 for Research→Grow. Median isolated cash is $138 for Grow, $204 for Adaptive and $162 for rotation. Improve→Grow reaches Strong/Breakout in 18.3%, versus Grow's 14.6%. Research→Grow reaches 14.8% and supplies research evidence/confidence. No equality of all strategies was forced.

Grow still does not modify product quality, alignment or retention. The focused weak-product test confirms identical retention to a paired no-Grow step. The first-use bonus is unchanged; its human meaningfulness needs confirmation only if the owner wishes to reassess it after this tuning. Cash here is an isolated operating ledger, **not a survival estimate**; T4 remains separate.

Full percentiles, scenario strata, churn, Fit distributions and pairwise results: [confirmation.json](confirmation.json). Search artifacts: [baseline.json](baseline.json), [grow-half.json](grow-half.json), [grow-recent.json](grow-recent.json).

## T3 — Research rounding and adaptive policy

Diagnosis: **C — both contribute.** Production rounded nonzero support below 15 to zero alignment progress forever. The study's adaptive policy also waited indefinitely for confidence, even when customer observations needed acquisition first.

Production now conserves fractional effort in one optional `LaunchedProductState.researchEffortRemainder` (0–14). Research adds legitimate nonnegative support, capped at the existing four-point-per-cycle maximum effort; each 15 effort units produces one alignment point and carries the remainder. Zero/absent support produces no progress and does not consume the carry. Variable support is conserved exactly; this avoids inventing progress from a research-count approximation.

This small persistence addition is necessary because past customer history does not record Aurora support. Using only the Research cycle count would not conserve changing effort. Synthesized optional decoding supplies nil for older version-20 products; nil means zero carry. **Save version remains 20, with no migration or old-history rewrite.** Newly accumulated effort survives normal Codable/save reload. Optional carry remains internal and is absent from the presentation projection.

Focused tests show support 1–14 produces exactly twice that support in alignment points over 30 cycles; support zero produces none. Support 4 yields four points over 15 cycles versus 60 support yielding 60 points. Variable effort and intermediate reloads conserve units without free gains. Research still halves immediate acquisition, costs $18 and consumes Founder Attention. Improve and Monetize formulas/costs were not changed.

Tooling-only adaptive correction: after three consecutive Research periods with Low confidence, choose Grow to gather customer observations. Both controlled and guarded career-study policies use this safeguard and only visible outcomes. This is not a new runtime Founder action or automatic assistant behavior.

In the confirmation cohort low-capability Adaptive ends at median **15 customers**, compared with zero in the earlier study; it researches 53.0% of periods instead of roughly 82%. These differences combine the production and tooling corrections and must not be attributed solely to fractional accumulation. Repeated Research is not a discovered dominant strategy; its median ending customers remain seven, versus Grow's 36. Very small legitimate effort can still need many cycles, and genuinely zero capability may remain ineffective.

## T4 — Cash/Runway audit: DESIGN DECISION REQUIRED

Static inspection confirms two separate meanings under the same displayed name:

| Source | Current authority/behavior |
| --- | --- |
| Canon `mechanic.runway` | FounderStats.runway; GameStore applies burn and Runway effects |
| `VentureEra.runwayBurnPerSprint`, How to Play | Explicit abstract per-sprint operating-pressure resource |
| `GameStore.commitSprint`, environmental actions | Decrease canonical Runway independently of cash |
| `GameStore.apply`, venture recovery | Apply explicit Runway effects and earned recovery; clamp to 0–365 |
| `recordRevenue`, traction resolution | Credit CompanyFinance and revenue mirror; no Runway recovery |
| Funding Board, `recordCapitalRaised` | Credit cash; no automatic canonical Runway recovery |
| Some strategic funding obligations/events | Carry explicit Runway effects separately from cash |
| Daily operating costs | Debit cash through CompanyFinance, not canonical Runway |
| `resolvedOutcome` | Bankruptcy at FounderStats.runway ≤ 0, regardless of positive cash |
| Founder Command metric | Displays CompanyFinance.runwayLabel with $120/day fallback under “Runway” |
| Strategy Board summary | Displays FounderStats.runway as days under “Runway” |

The abstract resource is explicitly implemented and taught, so this cannot safely be called an accidental formula omission. But the UI exposes both abstract Runway and a cash-derived financial estimate as if they were the same authority. Canon does not establish whether positive cash should rescue the operating resource. **There is an observable presentation/authority mismatch, and the intended economic relationship is ambiguous.** No automatic financial-to-Runway conversion was added.

Smallest proposed follow-up, pending design approval: choose whether Runway is an abstract operating budget or financial survival time. If abstract, consistently display canonical Runway, relabel cash/burn days as an estimate and explain that cash does not replenish the budget. If financial, define one GameStore-owned cash/burn projection and approved bankruptcy/funding interactions, preserving existing saves and deduplication. The latter is a separately scoped economy change, not a T1–T3 adjustment.

## Verification

- Codex and Chaos preflight: PASS; Chaos evidence directory recorded in provenance.
- Focused confirmation + finance, launch, preparation, traction and GameStore tests: **115 passed** on dedicated iPhone lab.
- Broader unit suite: **1,065 passed**, zero failures; study batches excluded because they ran separately.
- Relevant iPad lab regressions: **114 passed**, zero failures.
- Explicit iPhone and iPad scheme builds: **PASS**.
- Confirmation replay: **228,096 period rows byte-identical**, including focus decisions, counts, ledger effects and diagnostic fields.
- `git diff --check`: PASS.
- Normal and accessibility card fixture captures were rendered on both lab destinations. Normal-size artifacts were visually inspected for text wrapping/clipping. These are fixture renders, not proof of full-route human UX, VoiceOver/audio correctness or owner acceptance, and no accepted visual baseline was replaced.
- Xcode logged a nonfatal IOSurface notification warning during iPhone fixture rendering. Test/build gates passed. No test failure occurred in this tuning pass.

Result bundles/logs are under `/private/tmp/solo-tuning-*`; raw CSVs, source snapshot and lab-only card renders are preserved in [evidence.zip](evidence.zip). Exact revisions, SHA-256 fingerprints and command/result paths are in [provenance.json](provenance.json).

## Changed files and boundaries

Only `App/SimulationModels.swift` changed in production for this pass. Other changed/new files: `Tests/CompanyFinanceTests.swift`, `Tools/ChaosCrew/analyze_traction.py`, `Documentation/CustomerTraction/Slice1/GameplayAcceptance.md`, and these Tuning artifacts: `Report.md`, `baseline.json`, `grow-half.json`, `grow-recent.json`, `confirmation.json`, `provenance.json`, `evidence.zip`. New preflight evidence contains `chaos-preflight.json` and `chaos-pack.json` under the directory recorded in provenance.

All earlier dirty work was preserved. No GameStore, CompanyFinance, Product Launch, Media Narrative, accepted assets, project membership, shared scheme, commit or push changed in this pass. The owner alone selects the final A/B/C Slice 1 acceptance outcome.
