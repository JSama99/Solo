# Brio Campaign Calibration Completion Report

## Architecture summary

Brio now uses `WorkSessionFamily.campaignCalibration` inside the canonical `WorkSessionEngine`. The shared engine still owns eligibility, lifecycle, deterministic identity, Founder Attention, delegation, quality extraction, completion application, persistence, replay protection, findings, and Hindsight attribution. Brio contributes only its campaign challenge factory, relational evaluator, presentation boundary, and Campaign Calibration UI.

The three production families remain mechanically distinct:

- Aurora — Evidence Triage: credibility and evidence judgment.
- Stacks — Systems Review: dependency and release sequencing.
- Brio — Campaign Calibration: audience, message, and channel coherence.

## Files added

- `App/CampaignCalibrationChallenge.swift`
- `App/CampaignCalibrationView.swift`
- `Tests/CampaignCalibrationTests.swift`
- `VisualProof/CampaignCalibration/iPhone/*`
- `VisualProof/CampaignCalibration/iPadAir11/*`
- `BRIO_CAMPAIGN_CALIBRATION_COMPLETION_REPORT.md`

## Files modified

- `App/App.swift`
- `App/FounderComputerScreen.swift`
- `App/GameStore.swift`
- `App/WorkSessionEngine.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`

## Shared-engine integration

Eligible completed, unreviewed Brio marketing assignments at Routine or Important stakes resolve to `campaignCalibration`. `GameStore.prepareWorkSession` creates and persists the Brio record through the same family switch used by Aurora and Stacks. The standard Work Complete sheet presents Review Work or Delegate; manual review charges the canonical Attention cost once; completion applies the shared outcome exactly once; the Founder Computer then resumes the canonical Brio report and decision path.

The persisted record adds only family data: resolved campaign category, selected challenge, and the three optional selection IDs. Old saves decode those fields to safe defaults, preserving existing migration behavior.

## Challenge generation

The deterministic factory combines assignment UUID, Brio identity, family, simulation seed, venture, sprint, and inferred campaign category. It chooses a category-matched template and independently seed-ranks audience, message, and channel options. Reopening or restoring uses the stored challenge and option order rather than regenerating it.

The authored pool covers acquisition, retention, launch, conversion, community, partnership, awareness, and a safe general fallback. Existing assignment language maps into the smallest useful category taxonomy; unrecognized tasks use the general campaign pool.

## Compatibility, scoring, and partial credit

Campaign options carry private fit tags, objective categories, and message claim risk. The evaluator scores:

- Audience ↔ Message fit: 25%
- Audience ↔ Channel fit: 20%
- Message ↔ Channel fit: 15%
- Objective fit across the assembled campaign: 20%
- Claim discipline: 10%
- Whole-campaign coherence bonus: 10%

Shared tags provide full or partial relational compatibility. This permits multiple 100-quality campaign systems in one challenge and gives mixed combinations proportional credit without exact tuple comparison. The market outcome is not an input to Founder Review scoring.

## Findings

All findings use canonical `WorkSessionFinding` and its shared polarity model.

Negative:

- Audience Mismatch
- Channel Mismatch
- Weak Campaign Coherence
- Overclaimed Message

Positive:

- Strong Audience Match
- Strong Message Fit
- Strong Channel Fit
- Coherent Campaign
- Disciplined Claim

Neutral:

- Aspirational Positioning

Each finding has a causal Hindsight explanation. No separate Brio mistake store exists.

## Quality preservation and downstream routing

`agentPotentialQuality` is captured before Founder Review and never mutated. `founderReviewQuality` is produced only by the campaign evaluator. Shared quality extraction stores `deliveredQuality` separately and clamps it at Brio's original potential. A 100 review extracts all available quality; poor review reduces extraction; perfect play cannot upgrade weak Brio work.

The shared completion gate routes Delivered Quality into company-facing simulation fields and report cache exactly once. Agent evaluation retains original Actual/Potential Quality. Evidence and Hindsight receive all three layers plus canonical findings and attribution, allowing Brio failure, Founder Review failure, shared limitation, delegation, and preserved potential to remain distinguishable.

## Save and replay protections

- Objective, option order, selections, category, seed, quality layers, findings, path, charge state, completion state, and application state are Codable.
- Existing records are reused on prepare/reopen; state changes cannot reroll them.
- Manual review is idempotent and Attention is charged once.
- Invalid option IDs are rejected.
- Submit requires a complete valid selection and is rejected after completion.
- Completed selections cannot be edited or reset.
- Shared `completionApplied` prevents duplicate quality/consequence routing.
- Delegation is deterministic, costs no Attention, and cannot replay.

## Accessibility and hidden truth

The complete interaction uses buttons; drag is absent. Dynamic Type and accessibility text sizes reflow through a vertical ScrollView and adaptive grid on iPhone and iPad. Reduce Motion removes campaign transitions without changing evaluator inputs. Increase Contrast remains system-controlled.

Presentation structs contain only option ID, slot, title, and detail. Compatibility tags, categories, claim risk, scores, weights, agent quality, and hidden market truth remain private. VoiceOver labels identify only the legitimate option and slot. Tests verify hidden terms and scoring fields are absent and accessibility configuration cannot alter achievable quality.

## Verification results

- Compile: iOS Simulator SDK 26.5 — passed.
- Focused Brio XCTest: 24/24 passed.
- Full unit XCTest suite: 602/602 passed, 0 failures, 0 skipped.
- iPhone 17 Pro Max, iOS 26.5 UI proof: passed all eight captured states.
- iPad Air 11-inch (M4), iOS 26.5 UI proof: passed all eight captured states.
- The same production UI test explicitly relaunched Aurora Evidence Triage and Stacks Systems Review on both device classes.
- Visual inspection confirmed the Campaign Preview fits and remains fully actionable on both device classes.

Evidence manifests:

- `VisualProof/CampaignCalibration/iPhone/manifest.json`
- `VisualProof/CampaignCalibration/iPadAir11/manifest.json`

Captured states include Work Complete/Review-or-Delegate, audience choices, message choices, assembled channel/preview, completion, canonical Founder Computer return, Aurora regression, and Stacks regression.

## Known limitations

- Timing is intentionally not a fourth campaign dimension in this prototype; Audience, Message, and Channel form the complete production interaction.
- Critical and Company-Defining campaign incidents remain outside scope.
- The initial taxonomy is keyword-mapped to current authored assignment text rather than adding speculative campaign metadata to every task model.
- Market response remains intentionally uncertain and downstream; Campaign Calibration measures founder judgment, not eventual luck.

## Readiness estimates

- Brio Work Session completeness: **98%**
- Agent-specific gameplay differentiation: **100%**
- Shared WorkSessionEngine maturity: **96%**
- Causal simulation integrity: **98%**
- Task-aware challenge maturity: **91%**
- Readiness for a Work Session progression/meta-system: **92%**
- Overall Work Session system readiness: **96%**

Final commit: recorded in the delivery message after verification and commit.
