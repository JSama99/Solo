# Build 27 — Visible Gameplay Motion

## Purpose

The deterministic simulation creates a `TaskResult` synchronously during assignment. The Founder Computer now stages that already-computed result through a separate, in-memory presentation lifecycle so normal gameplay visibly communicates work without changing result timing, RNG consumption, saves, or career rules.

## Presentation Lifecycle

`PresentationCoordinator.AgentPresentation` is ephemeral and keyed by agent. Its phases are:

1. `assignmentReceived` — 300 ms handoff and task-arrival badge.
2. `working` — 2,000 ms presentation-only progress with an agent-specific live workspace.
3. `workComplete` — 450 ms completion pulse while the canonical result remains hidden.
4. `awaitingReview` — the existing canonical report becomes visible and Review activates.
5. `reviewing` — 250 ms card focus followed by five facts at 120 ms intervals.
6. `reviewed` — verification is visible and founder resolution is available.
7. `resolving` — 550 ms selected-choice lock choreography.
8. `resolved` — locked choice and canonical consequences are visible.

Assignment tasks are centrally owned and cancelled on removal, replacement, sprint-presentation cleanup, or when the canonical assignment no longer matches. Navigating away does not destroy the sequence because the coordinator is owned by `GameDashboard`, not a card view.

## Workspace Language

- Aurora scans evidence nodes with a purple/cyan traveling line.
- Stacks illuminates build blocks and runs a cyan processor sweep.
- Brio animates coral campaign bars and expanding signal rings.
- Idle surfaces retain a much weaker low-frequency version of their visual language.

## Review and Consequences

Founder Review reveals Reported Quality, Evidence, Verification State, Verified Actual, and Operational Risk in order. Confirmed/Verified states use a professional mint ring, icon impact, numeric transition, and success haptic. Resolution keeps all choices visible while the selected action lifts and alternatives fade, then replaces them with the locked result. HUD metrics own their animation independently, and Evidence uses a count transition, icon impact, glow, and rising `+N Evidence` label.

## Reduce Motion

Reduce Motion removes travel, loop, scale, offset, and glow animation while retaining the same presentation phases, content gating, final values, and actionable states.

## DEBUG Motion QA

Debug builds show a waveform toolbar button on the Founder Computer. It opens a presentation-only verification sheet for Agent Selection, Aurora Idle/Working/Completion, Stacks Working, Brio Working, Founder Review, Verified, Resolution, HUD Change, and Evidence Arrival. It never receives a `GameStore` and cannot mutate or save a career.
