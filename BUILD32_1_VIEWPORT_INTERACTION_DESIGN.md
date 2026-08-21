# Build 32.1 Viewport Interaction Design

## Root cause

Build 32 used `selectedAgentID` for three unrelated concepts: viewport emphasis, canonical card expansion, and `ScrollViewReader.scrollTo`. Viewport taps changed that value, and assignment events also changed it, so Company Command functioned as a large navigation menu.

## State ownership

`CompanyCommandInteractionState` now owns presentation-only viewport focus, user-focus priority, and explicit navigation requests. `expandedWorkstationAgentID` separately owns canonical card expansion. Assignment destination, review reveal, resolution emphasis, and rest confirmation retain their existing independent state.

| State | Owner | Simulation impact |
| --- | --- | --- |
| Viewport focus | `CompanyCommandInteractionState.focus` | None |
| User focus priority | `CompanyCommandInteractionState.userInitiatedFocus` | None |
| Full-workstation request | `CompanyCommandInteractionState.navigationRequest` | None |
| Canonical expansion | `expandedWorkstationAgentID` | None |
| Assignment/review/rest/resolve | Existing Founder Computer handlers | Existing canonical behavior |

Normal focus never creates a navigation request. Full Workstation creates a sequenced request with the canonical `founder`, `aurora`, `stacks`, or `brio` scroll ID, expands that card, scrolls, announces the move, and transfers accessibility focus.

## Agent focus

The selected character and role monitor become prominent while the other two agents remain visible as subdued transfer targets. The focus projection displays only immediate-decision information: name, role, sanitized status, task, work progress, stress band, trust band, level, attention requirement, and rest state.

`CompanyCommandAgentAvailability` is the single action-availability projection used by both viewport and canonical workstation call sites. Buttons invoke the same Founder Computer assignment sheet, review, rest confirmation, presentation skip, and explicit full-workstation handlers. Resolution remains in the full workstation to preserve readable canonical choices.

## Founder focus

Founder focus shows phase, active work, reviews, resolutions, Attention, and the highest-priority visible next action. Commit Sprint appears only when `GameStore.canCommitSprint` is true and still passes through the existing guarded commit handler.

## Hidden truth

Focus consumes `LivingAgentProjection`; no parallel focus model reads raw result truth. Verification, overclaiming, drift, evidence incompleteness, and correlated failures remain absent until the existing fifth review reveal. The same sanitized projection supplies visible status and accessibility values.

## Motion, accessibility, and performance

- Focus entry/transfer/exit use local smooth transitions of 280/280/220 ms; Reduce Motion makes the same state change without animation.
- One existing 18 Hz viewport `TimelineView` remains the only clock and still pauses offscreen, in background, and for Reduce Motion.
- Focus adds no task, timer, RNG, persistence, image load, or broad screen animation.
- All actions have 44-point minimum targets and text plus symbols.
- Named focus actions remain on the viewport; contextual buttons expose Assign, Review, Rest, Skip, Full Workstation, and Commit only when valid.
- Explicit navigation announces the destination and moves accessibility focus after scrolling.
- Compact scene typography is capped at XXX Large to prevent spatial labels from colliding; canonical detail cards remain unrestricted and scrollable.

## Visual direction estimate

Build 32.1 is estimated at **80%** toward the intended simulation-game visual direction. The viewport is now an independently useful observation and command surface rather than a shortcut launcher. Remaining distance is primarily bespoke character animation and deeper room/station art production.
