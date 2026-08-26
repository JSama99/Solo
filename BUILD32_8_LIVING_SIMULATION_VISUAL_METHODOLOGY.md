# Living Simulation Visual Methodology

## Canonical audit

- Revision inspected: `10288cf6ad683a9337875bf296015445101161de`.
- Lifecycle presentation states: idle, assignment received, working, work complete, awaiting review, reviewing, reviewed, resolving, resolved, resting.
- Independent condition layer: focused, stressed, overloaded, drifting, verified, overclaimed, evidence incomplete. The last four are admitted only at the canonical reveal boundary.
- Independent emphasis layer: normal, selected, Founder attention, inspection, decision lock, level-up celebration.
- Canonical actions remain `PresentationCoordinator.assign/review/resolve/commit` delegating to `GameStore`; approve, rework, ship anyway, and escalate/cross-check remain `TaskResolutionChoice` paths.
- Desk navigation remains `FounderDeskSelection.overview/device`, with `FounderEnvironmentCameraState` controlling free look and focus transitions.
- Physical previews accept only `FounderDeskPreviewInput`: sprint, venture, phase, visible work/review counts, published evidence/headline/rank, visible objective/readiness, facility, achievements, and owned facilities.
- Hidden truth remains gated through `reviewRevealStep` and `VisibleSimulationProjection`; result quality, correctness, drift, overclaim, evidence completeness, and latent risk are absent from desk input.
- Reduce Motion remains driven by SwiftUI accessibility environment values, `MotionKind.resolved`, `SoloMotion.resolved`, and desk crossfade policy.
- Facility presentation remains derived from canonical `FacilityTier`, progression store, and owned infrastructure.

## Pipeline

`GameStore` → existing `PresentationCoordinator`/desk state → pure `LivingAgentProjection`, `FounderGarageMotionPresentation`, and `LivingMotionPriorityPolicy` values → SwiftUI → truth-safe labels, announcements, and Reduce Motion endpoints.

Presentation selects activity, visible condition, emphasis, signature, phase, intensity, endpoint, and description. It cannot write results, evidence, risk, attributes, metrics, obligations, or sprint state. Canonical actions are executed first; animation is then derived from the resulting state.

## Visual grammar

Every event uses a compact anticipation/action/confirmation/consequence grammar. Assignment dispatch targets the selected agent; completion returns a neutral document to review; resolution uses a choice-specific route; a causal recap names the action, visible metric deltas, visible relationship response, and follow-up device. No animation independently computes an outcome.

Aurora uses a deliberate evidence sweep and connected-source iconography. Stacks uses sequential assembly and compilation/build blocks. Brio uses ordered campaign lanes and an outward response wave. Identity never depends on color alone.

## Supported social presence

The canonical model supports agent relationship/trust/stress presentation and the existing cross-check verification bridge. Build 32.8 visualizes those known values and cross-check routing. The repository has no general task-dependency/conversation graph, so no invented conversations, conflicts, memories, or prerequisite exchanges were added.
