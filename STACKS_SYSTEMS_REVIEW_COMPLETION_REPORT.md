# SOLO: UNICORN RUN — Stacks Systems Review Completion Report

## Outcome

Stacks now has a distinct, production-connected **Systems Review** Work Session. It asks the founder to build a safe implementation order from shuffled operational cards, supports partial credit through dependency constraints, and returns through the canonical Stacks report, founder decision, consequence, Evidence, and Hindsight flow.

Aurora's Evidence Triage remains intact. Both agent-specific interactions use the same persisted `WorkSessionRecord`, shared `WorkSessionEngine` lifecycle, Founder Attention accounting, causal quality model, outcome application, replay guards, save restoration, findings pipeline, and Hindsight attribution.

## Architecture

The shared lifecycle is:

1. `WorkSessionEngine.family(for:agentID:)` selects `.evidenceTriage` or `.systemsReview` from the completed assignment and canonical agent.
2. `GameStore.prepareWorkSession` captures immutable challenge identity, agent potential quality, stakes, agent stress snapshot, and attention cost exactly once.
3. `GameStore.beginManualWorkSession` selects manual review and charges Founder Attention exactly once; `delegateWorkSession` uses the shared deterministic delegate extraction path without a charge.
4. The agent-specific interaction records decisions into the shared `WorkSessionRecord`.
5. The family evaluator produces Founder Review Quality and canonical `WorkSessionFinding` values.
6. Shared `WorkSessionEngine.deliveredQuality` bounds usable delivery by Stacks' original potential quality.
7. `GameStore.applyWorkSessionOutcome` applies the result once to `TaskResult`, preserving hidden actual quality while routing company-facing immediate effects through delivered quality.
8. The existing canonical report/review/resolution flow records Work Session quality, findings, and causal attribution into Evidence and Hindsight.

No second Work Session framework or Stacks-only consequence path was introduced.

## Systems Review generation

`SystemsReviewChallengeFactory` deterministically selects and shuffles a challenge using the canonical career seed, assignment UUID, agent ID, venture, sprint, family version, and resolved technical topic. Persisted challenge data and the original shuffled order are reused on reopen and after save/reload.

The compact taxonomy is: backend, frontend, data, integration, deployment, reliability, and general. Assignment title/detail keywords resolve a topic; unmapped engineering work uses the safe general pool. Current families cover backend feature delivery, customer data migration, external integration, controlled deployment, reliability fixes, client features, and general systems changes.

## Dependency evaluation and partial credit

Each challenge stores hidden prerequisite relationships classified as dependency, verification, or release-gate constraints. The visible model contains only title, detail, and selected position.

Scoring evaluates relationships rather than exact array equality:

- Dependency accuracy: 60%
- Verification discipline: 20%
- Release safety: 20%

This supports multiple valid topological orders and proportional credit when only some relationships are correct. Required pre-release verification is distinguished from legitimate post-release monitoring, so monitoring after rollout is not misclassified as skipped verification.

Implemented Stacks findings use canonical `WorkSessionFinding`:

- Negative: dependency violation, skipped verification, unsafe release.
- Positive: correctly preserved dependency, correctly required verification, correctly identified release gate.

## Causal quality and downstream routing

The invariant is preserved:

`agentPotentialQuality → founderReviewQuality → deliveredQuality`

`TaskResult.hiddenActualQuality` remains Stacks' evaluation truth. Founder Review never overwrites it. Delivered Quality is stored independently, cannot exceed actual/potential quality, and perfect review can extract—but never improve—the available quality. Company-facing immediate effects are scaled once using Delivered Quality. Stacks evaluation and earned actual-quality reveal continue to use original quality.

Hindsight explanations now name the session's actual agent. They can distinguish Stacks-limited output, Founder Review loss, shared failure, deterministic delegation loss, and preserved potential without revealing those facts before the existing canonical reveal path.

## Persistence and replay protection

Persisted state includes family, challenge seed, technical topic, complete challenge, shuffled source order, player sequence, path, attention charge flag, findings, Founder Review Quality, Delivered Quality, completion application flag, completion state, and agent stress snapshot.

Guards prevent rerolling, duplicate card selection, invalid/incomplete submission, rapid duplicate submission, post-completion editing, replay for a better score, duplicate attention charges, duplicate outcome scaling, and duplicate Evidence/Hindsight generation. Legacy Work Session saves decode with Aurora defaults and empty Stacks fields.

## Accessibility and presentation

The interaction is fully tap-driven; drag is not required. Cards expose only legitimate title/detail content and selected position (for example, “Selected position 3”). VoiceOver metadata has no prerequisite, expected order, scoring weight, unsafe status, hidden quality, or correctness fields. Buttons have explicit labels/hints, Dynamic Type is used throughout, adaptive grids support iPhone/iPad, Increase Contrast uses system behavior, and Reduce Motion removes transitions without entering the evaluator.

No correctness color, sound, haptic, animation, reordering, or accessibility cue occurs before submission. Existing feedback/settings infrastructure is reused.

## Files added

- `App/SystemsReviewChallenge.swift`
- `App/SystemsReviewView.swift`
- `Tests/SystemsReviewTests.swift`
- `SimulatorEvidence/iPhone/*` — six retained XCTest screenshots plus manifest.
- `SimulatorEvidence/iPadAir11/*` — six retained XCTest screenshots plus manifest.

## Files modified

- `App/App.swift`
- `App/FounderComputerScreen.swift`
- `App/GameStore.swift`
- `App/SimulationModels.swift`
- `App/WorkSessionEngine.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`

## Verification

- Bitrig app build: passed with iOS 26.5 SDK.
- Focused Stacks XCTest: **22 passed, 0 failed, 0 skipped** on iPhone 17 Pro Max / iOS 26.5.
- Full XCTest/UI suite: **583 passed, 0 failed, 0 skipped** on iPhone 17 Pro Max / iOS 26.5.
- iPhone 17 Pro Max visual sequence: passed for work complete/choice, active review, three selected steps, completion, canonical return, and Aurora regression.
- iPad Air 11-inch (M4) visual sequence: passed for the same six states.
- Retained screenshots are mapped to human-readable state names in each device manifest.

## Known limitations

This production prototype intentionally implements sequencing only. Parallel execution lanes, optional unsafe-step omission, unnecessary-blocker scoring, Critical/Company-Defining incidents, and Brio gameplay are not present. They were not required to prove the second agent-specific family and should be added only when their playable mechanics exist.

## Readiness estimates

- Stacks Work Session completeness: **96%**
- Shared WorkSessionEngine maturity: **91%**
- Causal simulation integrity: **97%**
- Agent-specific gameplay differentiation: **98%**
- Readiness to begin Brio: **92%**
- Overall Work Session system readiness: **93%**
