# Build 30 — Sprint Outcome Reveal & Next-Sprint Handoff

## Architecture

Build 30 keeps the canonical mutation path unchanged:

`FounderWorkstationCard → FounderComputerScreen.commit → PresentationCoordinator.commit → GameStore.commitSprint`

`PresentationCoordinator` snapshots presentation inputs before the single resolver call, then maps the canonical report and post-commit stats into `VisibleSprintResult`. While that result or its canonical report is active, a second coordinator commit is rejected. Dismissal continues through `GameStore.finishReport()` and `PresentationCoordinator.clearSprintPresentation()`.

No animation controls simulation, report dismissal, sprint advancement, venture completion, or career completion.

## Outcome surface

`SprintOutcomeScreen` replaces the aggregate result sheet with a large, stable operating-cycle record:

- Founder commitment and venture/sprint context
- Fog-safe operating headline and verified/risk/review counts
- Before → after company metrics with numeric deltas, directional icons, and text direction
- Agent-colored assignment summaries using only `VisibleTaskResult`
- Evidence, visible risk, skipped opportunity, dilemma, and objective consequences
- Transition-specific next action for next sprint, venture handoff, or career outcome

The four compact reveal stages are presentation-only. Reduce Motion resolves immediately to the complete information state.

## Hindsight placement

The compact `HindsightArchiveCard` now follows the Evidence Drawer on the Founder Computer. It previews the newest existing precedent or divergence and navigates directly to the existing `HindsightRecordsScreen`. The redundant More-tab link was removed. Existing records, filters, expansion state, persistence, recall rules, and detail presentation remain canonical.

## Accessibility

- Metric meaning is repeated in text and symbols; color is supplementary.
- Assignment verdicts, evidence state, risk, before/after values, and next-action state are readable by VoiceOver.
- Accessibility Dynamic Type changes metric grids to one column.
- The outcome remains scrollable with stable source-order focus.
- Hindsight arrival and result staging stop under Reduce Motion.
- The outcome cannot be interactively dismissed, leaving one explicit next action.

## Preserved systems

Simulation, RNG order, hidden truth, Evidence Ledger timing, assignment resolution, resource calculations, saves, migrations, scoring, achievements, progression, Founder Card logic, agent-card lifecycle, and existing motion verification remain unchanged.
