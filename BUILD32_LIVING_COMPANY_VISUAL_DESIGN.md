# Build 32 Living Company Visual Design

## Intent

Build 32 keeps the Garage as a first-person Founder Computer and adds a compact living simulation layer. The viewport is an overview and navigation surface; the existing workstation cards remain the canonical place for assignment, review, resolution, rest, and sprint commitment.

## Architecture

`CompanyCommandViewport` accepts immutable visible projections. It cannot mutate the simulation. Its only actions select an existing workstation, select Founder command, or skip already-determined presentation choreography.

`LivingAgentProjection` separates three axes:

| Axis | Values |
| --- | --- |
| Activity | idle, assignment received, working, work complete, awaiting review, reviewing, reviewed, resolving, resolved, resting |
| Condition | focused, stressed, overloaded, drifting, verified, overclaimed, evidence incomplete |
| Emphasis | normal, selected, Founder attention, inspection, decision lock |

The native portrait implementation sits behind `LivingAgentCharacterView`. A future Rive renderer can replace `NativeAgentCharacterView` without changing simulation or viewport input models. No production `.riv` files were present, so no Rive dependency or placeholder was added.

## State-to-motion mapping

| State | Viewport presentation |
| --- | --- |
| Idle | restrained portrait breathing, dim monitor rail |
| Assignment received | task packet travels from Founder command to the stable agent ID |
| Working | role-specific station monitor and visible progress artifacts |
| Work complete | mint artifact returns toward the Founder tray |
| Awaiting review | contained amber Founder-attention treatment |
| Reviewing | selected inspection frame; unrelated agents remain readable but dimmed |
| Reviewed | report settles; truth treatment appears only after reveal step five |
| Resolving/resolved | selected resolution lock and stable mint decision state |
| Resting | dimmed station, bed symbol, no work animation |
| Overloaded | amber warning symbol and label without flashing or screen shake |

Reduce Motion pauses the shared clock and presents task/artifact endpoints immediately. `skipPresentation(for:)` and `skipAllPresentations()` cancel pending presentation tasks, retain canonical state, set final visible progress, and never call `GameStore`.

## Causal chain

1. Canonical assignment determines the result synchronously.
2. Presentation emits a stable task/agent event.
3. A task packet moves from Founder command to the selected station.
4. The role monitor activates and progress artifacts accumulate.
5. A completed artifact returns to Founder command.
6. Founder Review retains its five-step report sequence.
7. Resolution locks and visible metrics respond through existing canonical views.
8. Evidence and Tech.com continue to consume the existing canonical events.

No animation consumes RNG, delays the canonical result, changes scoring, or gates controls.

## Hidden-truth boundary

`LivingAgentProjection` admits verification conditions only when the task is canonically reviewed and either no staged presentation exists (restored save) or the active presentation has reached reveal step five/reviewed. Earlier stages expose assignment, progress, workload, stress, and Founder attention only. Accessibility values are built from the same sanitized projection, preventing VoiceOver leakage.

The coordinator now rejects duplicate review before calling `GameStore`, and rejects duplicate resolution before starting a new visual sequence. Duplicate commit continues to be rejected while an outcome is active.

## Facilities and infrastructure

Founder Garage uses warm industrial structure, amber rails, and upgrade slots. Founder Loft uses purple/cyan window structure and cleaner materials. Existing facility bonuses and activation rules are untouched.

Stable slots map exactly to Development Rig, Verification Array, Campaign Studio, Recovery Corner, and Founder Command Desk. Active state appears only while the owned upgrade's existing bonus context is relevant; no upgrade or bonus was invented.

## Operational atmosphere

- Low Energy reduces viewport lighting energy.
- Low Runway introduces restrained amber pressure.
- Low Trust uses coral instability signaling.
- Momentum increases confidence of ambient lighting, not simulation speed.
- Agent stress and overload affect only their station projection.
- Verification stabilizes the relevant station with text, symbol, and mint.

Meaning always combines text/symbol with color.

## Accessibility

- Agent and Founder controls meet a 44-point minimum target.
- Viewport stations expose labels, visible-safe values, hints, and canonical scroll actions.
- The viewport container includes named equivalent actions for Founder, Aurora, Stacks, and Brio.
- Dynamic Type raises viewport height to 280 points at accessibility sizes; canonical full cards remain vertically scrollable.
- Increased Contrast strengthens the viewport frame.
- Reduce Motion pauses all continuous viewport motion and uses immediate endpoints.
- Assignment, selection, review, resolution, rest, commit, and skip paths announce their outcomes.
- Audio honors the existing sound-effects setting; one synthesized feedback player stops the prior cue so causal events do not stack.

## Performance review

Code-first review found the primary risks were broad per-frame invalidation and 1254px portrait decoding. Build 32 uses one 18 Hz `TimelineView` scoped to the viewport, passes time into leaf stations, pauses for Reduce Motion/background/offscreen state, keeps simulation outside the loop, and uses stable domain IDs. No sorting/filtering is performed inside `ForEach` identity expressions.

The three original portraits (approximately 2.0–2.3 MB each) are preserved in `ReferenceAssets/OriginalPortraits`. Runtime asset renditions are now approximately 28–36 KB at 1x, 96–120 KB at 2x, and 204–252 KB at 3x. Aurora and Stacks retain usable alpha. Brio's source has no alpha, so its black field is intentionally integrated into the dark monitor frame rather than destructively removed.

No Instruments claim is made; verification in this pass is code audit, successful clean compilation, tests, simulator launch, scrolling, and visual inspection.

## Direction estimate

Build 32 places the complete game at **85%** of the intended “The Sims for AI solo founders” visual direction. Company state, work, review, facilities, and progression are now visibly embodied without compromising deterministic clarity. Remaining distance is primarily bespoke character animation/art production and broader canonical-state visual capture, not missing simulation architecture.

