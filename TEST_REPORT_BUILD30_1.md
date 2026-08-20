# Build 30.1 Validation Report

Date: 2026-08-20  
Baseline: `fd7aa82a8e14b1340c8ee66d6e6c5d3eee20ffd2`  
SDK / simulator: iOS 26.5, iPhone 17 Pro

## Reused architecture

- `PresentationCoordinator.commit(in:progression:)` remains the sole presentation commit entry.
- `GameStore.commitSprint()` remains the sole simulation resolver. It now returns the same canonical `SprintReport` it creates so terminal handoffs can complete their reveal without resolving again.
- `GameDashboard` retains the report-driven sheet lifecycle.
- `VisibleSimulationProjection` remains the fog-safe mapper for live task and sprint results.
- `GameStore.finishReport()` and `PresentationCoordinator.clearSprintPresentation()` remain the dismissal path.
- `GameStore.Stage`, `careerOutcome`, and the post-commit stage remain the canonical destination state.
- Persisted `Precedent`, `PrecedentOutcome`, Evidence, and divergence records remain Hindsight's only historical facts.
- `AccessibilityNotification.Announcement` and `PresentationPolicy` / `accessibilityReduceMotion` remain the accessibility and motion mechanisms.

## Navigation and interaction

The immutable reveal action is derived after the single canonical resolver call. Verified route identities: next sprint, chapter milestone, next-venture thesis, continuous venture checkpoint, Founder Pass unlock, and career outcome. Career outcome takes precedence over stage. The action is available independently of reveal animation and is guarded in both the view and coordinator. Repeated dismissal/handoff calls are idempotent.

## Historical outcomes

Hindsight remains directly below Evidence. Persisted consequential precedents now open a read-only Historical Outcome screen with decision, context, observed consequence, and an optional recorded rival branch. The screen explicitly states that transient timing, full metric snapshots, and hidden unverified truth are unavailable rather than reconstructing them. No live commit or sprint control is present.

## Readability, copy, motion, and accessibility

The live reveal now places completion/context, operating result, and the three largest absolute metric changes ahead of full metrics, agent results, Evidence/risk consequences, and the action. All canonical destinations have specific labels and hints. Live and historical outcomes have distinct accessibility labels. The next action no longer waits for animation. Reduce Motion still resolves all reveal information immediately through the existing policy.

## Automated validation

- Untouched baseline: 247 executed, 247 passed, 0 failed, 0 skipped.
- Focused Build 30.1 suites: 55 executed, 55 passed, 0 failed, 0 skipped.
- Full regression: 249 executed, 249 passed, 0 failed, 0 skipped.

Focused coverage includes duplicate canonical commit rejection, idempotent outcome completion, exact Attention preservation, assignment preservation, all post-commit route identities, career-route precedence, visible projection secrecy, Reduce Motion policy, Hindsight persistence/read-only derivation, and hidden-truth protection.

## Simulator observations

Observed on the rebuilt iPhone 17 Pro app: Founder Computer relaunch, Evidence followed immediately by Hindsight, Hindsight archive opening, predictable back navigation to the Founder Computer, empty-history copy, review/evidence feedback, Accessibility XXXL text, Increased Contrast, and restoration to standard settings. Accessibility content remained reachable and the archive remained scrollable.

The available Bitrig simulator controls did not expose VoiceOver or Reduce Motion toggles. Spoken VoiceOver output and live system Reduce Motion behavior were therefore not verified and are not claimed. The accessibility tree and automated Reduce Motion policy were verified, but do not substitute for those two live checks. A saved run did not contain a historical precedent, and the session was not driven to every terminal route; those routes are regression-tested rather than claimed as visually observed.

## Scope review

No RNG, seeded simulation, scoring, resource formula, assignment mutation, Evidence timing, hidden truth, progression, save schema, migration, or eligibility logic changed. No new history store, simulation result, or presentation-driven source of truth was added.

Visual-direction estimate: 95%.
