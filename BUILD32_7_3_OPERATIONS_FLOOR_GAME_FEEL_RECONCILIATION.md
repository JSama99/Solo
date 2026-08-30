# Build 32.7.3 — AI Operations Floor Game-Feel Pass

## Scope and ownership

The Founder Computer now has one primary `AIOperationsFloor`: header, Founder Command Console, Founder Review Queue, the Aurora/Stacks/Brio stations, and a persistent action area. `GameStore` remains the canonical owner of game, agent, finance, and calendar state; `PresentationCoordinator` owns presentation lifecycle; `CompanyFinance`, `OperatingCalendar`, and `FounderStats` provide their respective canonical values. Founder review routes through `GameStore.review` and the existing resolution path. `AppSettingsStore` provides feedback audio, while SwiftUI accessibility semantics remain presentation-owned.

## Reconciliation

- The floor uses a priority-first next action: review/resolution beats assignment, and assignment beats sprint commit.
- The console groups company status, founder condition, and company trajectory instead of presenting nine equivalent tiles. Coverage stays signed and semantically distinct from Trust and Momentum.
- Queue rows state agent, reported lifecycle, priority, implication, reviewability, and canonical destination. The empty state explains where future outputs will appear.
- Aurora, Stacks, and Brio have evidence, pipeline, and public-signal work surfaces respectively. Their visual activity is explicitly reported activity, never verification.
- Assignment now has a state-changing confirmation with canonical cost preview, calendar implication, expected benefit, uncertainty, and duplicate-tap protection. Resolution feedback distinguishes approval, revision, verification request, and ship-anyway outcomes.
- The iPad layout uses a console/queue anchor with separated stations; compact layouts remain a vertical command rhythm. Large accessibility type stacks the three console groups. No periodic timer or invented progress was introduced.

## Finance, truth, and accessibility audit

The floor reads `CompanyFinance` directly and does not mutate finance or calendar during presentation. It displays finance-derived runway; `FounderStats.runway` is a legacy separate stat and remains a known model-level mismatch, not a new floor mutation. Pre-review language, accessibility labels, queue destinations, colors, and progress avoid hidden-quality claims. Accessibility order is Console → Queue → Aurora → Stacks → Brio → actions; stable identifiers and focused tests guard one primary surface per owner.

## Verification and evidence

- Focused Operations Floor suite: **12 passed, 0 failed, 0 skipped**.
- Complete XCTest suite: **518 passed, 0 failed, 0 skipped**, iPad Air 11-inch (M4), iOS 26.5.
- iPhone 17 Pro Max and iPad Air 11-inch (M4), iOS 26.5, exercised Founder Computer focus and LOOK OUT/Free Look continuity. The final iPad visual attachment is in `RuntimeEvidence/after/ipad-final3-attachments`; final iPhone continuity attachments and video are in `RuntimeEvidence/after`.

## Evidence boundary and remaining limitations

Visual evidence confirms the floor opening, empty queue, single console/station composition, responsive iPhone/iPad hierarchy, and focus return. Automated tests cover assignment, review, resolution, hidden-truth, finance/calendar, and reduced-motion endpoints. This revision does **not** contain runtime screenshots for every live assignment/review outcome, a system Reduce Motion capture, or audible ducking; those visual/audio acceptance points remain unconfirmed rather than inferred. The canonical decision vocabulary has approve, rework, cross-check, and ship-anyway; no synthetic “reject” action was added.
