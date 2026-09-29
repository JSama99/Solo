# SOLO Core Experience Pass 1 — Founder Decision Loop Fixture

Status: **DEFINITION ONLY — no production behavior changed**

## Purpose

Provide a deterministic fixture that can verify the complete founder-decision chain rather than only final stat totals.

The fixture must answer one question:

> When the founder trusts a confident agent under pressure, can SOLO prove exactly how that judgment propagates through the simulation and becomes future meaning?

## Canonical scenario shape

Use a fixed seed and a controlled launch-pressure state.

Suggested narrative context:

- Agent: Stacks
- Task family: engineering / launch readiness
- Stacks reports high confidence and strong reported quality
- Actual quality is materially weaker
- Evidence completeness is insufficient to make the decision trivial before founder action
- Brio has already committed public launch pressure
- Aurora has evidence that is relevant but not conclusive
- Runway is constrained
- Founder Attention is insufficient to simply verify everything

The fixture should make at least two actions plausible:

1. trust/ship now;
2. intervene/cross-check/rework.

No option should be globally dominant by construction.

## Required recorded fields

Record every step with stable identifiers:

- seed
- venture
- sprint/day
- task instance ID
- assignment
- agent ID
- agent confidence / reported quality
- actual quality / hidden truth
- evidence completeness
- correlated failure identifier if any
- founder action
- immediate agent-state changes
- immediate company-state changes
- delayed scheduled effects
- latent defect creation/resolution
- Evidence Ledger mutation
- public media / coverage event
- rival reaction if present
- Signal TV program/tone if present
- Hindsight precedent creation/update
- next available founder decision
- any company flag / obligation created

## Event trace schema

Each trace item should contain:

`index | venture | sprint | eventID | eventType | sourceDecisionID | system | summary | stateDelta`

The important field is `sourceDecisionID`. Delayed effects must remain attributable to the founder judgment that created them.

## Expected chain contract

The target fixture should eventually prove a chain like:

`Stacks high-confidence report`
→ `Founder ships without sufficient verification`
→ `unverified/overclaimed work committed`
→ `latent defect or delayed risk recorded`
→ `defect surfaces later`
→ `trust / runway / momentum consequence`
→ `public coverage reaction`
→ `future launch/reputation pressure changes`
→ `Hindsight precedent records the observed outcome`
→ `similar later decision can surface the precedent`

The exact numbers are not specified in Pass 1. They must be measured from production behavior rather than invented for the audit.

## First-divergence rule

For every expected trace, compare actual and expected events in order.

Stop comparison at the first mismatch in:

- event identity;
- event ordering;
- source decision attribution;
- hidden/visible information boundary;
- state mutation;
- downstream system participation.

Do not diagnose from the final sprint/career totals when an earlier event differs.

## Fixture invariants

The fixture must preserve:

- identical seed → identical trace;
- save/load → identical remaining trace;
- cached report cannot reroll;
- hidden truth remains hidden until canonical reveal conditions;
- Evidence Ledger keeps original reported quality;
- Hindsight consumes no simulation RNG;
- no visual-fidelity accepted-state regression;
- save version remains 20 unless a later approved pass explicitly requires migration.

## Pass/fail quality

A fixture passes only when the event chain is structurally correct.

Weak assertion:

`trust == 61`

Strong assertion:

`decision D17 → latent defect L4 → defect discovered → trust loss → critical public coverage → precedent P2 → later recall references P2`

## Pass 1 result

Fixture architecture is defined, but the audit does **not** claim that production currently satisfies the full expected chain. The next implementation pass should create observability first, then measure where the existing chain stops or loses attribution.