# Build 32.2 Living Simulation Design

## Architecture

The simulation remains authoritative. `LivingAgentProjection`, `CompanyAtmosphere`, `InfrastructureVisual`, and `CompanyPhaseHierarchy` sanitize canonical values into immutable visible inputs. `CompanyCommandViewport` renders those inputs and emits existing actions through closures; it never mutates simulation state.

Activity, condition, and emphasis remain independent. Activity answers what an agent is doing, condition answers how the station is operating, and emphasis answers where the player's attention should land. Precedence is explicit: rest controls activity; post-review truth is gated until reveal step five; inspection and decision lock are presentation emphasis; a level-up celebration is short-lived and does not alter progression.

## Causal language

The scene uses stable `agentID` and `taskID` values for packet and artifact identity. Assignment travels Founder-to-station, work artifacts accumulate in role-specific equipment, completion travels station-to-Founder, review connects the artifact to an inspection beam, and a locked resolution sends a response Founder-to-company. Presentation reconciliation derives from canonical state on return, so stale decorative tasks cannot create duplicate work, tray items, review, resolution, or commit actions.

Skipping remains presentation-only. It calls the existing presentation coordinator endpoint, never `GameStore`, and lands on the same visible endpoint used by reduced-motion fixtures.

## Character and station language

- Aurora: restrained portrait depth, source nodes, connection paths, evidence accumulation, and verification preparation.
- Stacks: processor blocks, staged modules, compile/deploy rails, and stable incremental output.
- Brio: campaign channels, signal distribution, audience response, and expanding reach paths.
- Rest: dimmed station, recovery symbol and text, softened light, zero visible task progress.
- Pressure: stress reduces motion confidence; overload adds slower response, warning frame, strain symbol, and text without flash or shake.
- Reviewed truth: verified becomes stable mint; overclaim uses report/actual mismatch bars; drift uses a deviating signal; incomplete evidence uses a broken evidence path.

## Phase hierarchy

- Planning prioritizes assignments and readiness.
- Working prioritizes active stations and work artifacts.
- Review prioritizes Founder attention and inspection while preserving legibility elsewhere.
- Resolution prioritizes reviewed work and decision lock without consequence preview.
- Commit prioritizes readiness, blocker, completed work, and commit action.
- Outcome remains the existing `SprintOutcomeScreen` and canonical report order.

## Infrastructure and facilities

Development Rig, Verification Array, Campaign Studio, Recovery Corner, and Founder Command Desk each render reserved, installing, installed, and relevant-active states. Relevance comes only from existing work/bonus context.

Garage presentation uses warm exposed rails, compact industrial spacing, and improvised framing. Loft presentation uses cleaner window bays, purple/cyan architecture, refined spacing, softer lighting, and organized infrastructure. No facility rule or bonus changed.

## Motion and performance policy

The viewport owns one shared 18 Hz timeline. No per-agent timeline or timer was added. It pauses offscreen, in background, and under Reduce Motion. Frame input is immutable presentation state; agent indexing, surrounding-agent lookup, active counts, and hierarchy are precomputed outside the timeline closure. Reduce Motion removes continuous travel/parallax while retaining final visual state.
