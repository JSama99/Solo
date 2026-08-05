# SOLO: UNICORN RUN — Build 6 Change Log

## Purpose

Build 6 addresses the highest-priority findings from the Build 5 review:

- release-blocking Swift errors and stale tests
- save/reload determinism drift
- Founder Pass interrupting the continuous-mode checkpoint
- repeated tasks and chapter dilemmas
- founder choices that disappeared after one stat change
- agent relationships that did not influence output
- objectives that could be automatic, random, or impossible
- continuous careers that did not become meaningfully harder
- a command screen that did not communicate the sprint sequence

## Release reliability

### Fixed Swift argument-order failure

`DoctrineProfile.swift` now calls `SimulationEffects` with labels in declaration order:

```swift
SimulationEffects(momentum: -4, trust: 12)
```

The corresponding stale test construction was corrected.

### RevenueCat tests now match production configuration

Tests now verify:

- entitlement: `solo_unicorn_run_pro`
- display name: `Founder Pass`
- expected StoreKit product: `com.talonsight.solounicornrun.founderpass`

The removed hardcoded product allow-list is not referenced again.

### Test isolation repaired

Synchronous XCTest teardown methods no longer instantiate the `@MainActor` game store. They clear SOLO save keys directly. Founder Pass tests now deliberately protect the test career from random loss and no longer skip the behavior they are supposed to verify.

## Deterministic content decks

### Sixty-task venture deck

The content library expands from 38 to **60 unique tasks**. Each twelve-sprint venture displays exactly sixty opportunity cards:

```text
12 sprints × 5 opportunities = 60
```

The deck is seeded, shuffled, and consumed without recycling during the venture. The next venture reshuffles a new deterministic deck.

### Nonrepeating chapter dilemmas

Each chapter owns a seeded three-card dilemma deck. The three sprints in a chapter now receive each chapter dilemma once before the deck resets. This removes the previous 77.78% chance of a duplicate inside a three-sprint chapter.

### Persisted deck state

Save schema v8 stores:

- recent task titles
- remaining task-deck titles
- remaining dilemma-template identifiers
- current dilemma-deck chapter
- recent objective kinds

An uninterrupted run and a reloaded run now generate the same future draft and dilemma sequence from the same career state.

## Persistent company consequences

Build 6 adds **30 company flags**, active obligations, and a decision ledger.

Examples include:

- Custom Feature Debt
- Evidence-Led Claims
- Burnout Culture
- Paid Pilot
- Discount Dependency
- Annual Contracts
- Public Transparency
- Competitor Race
- Investor Control Rights
- Human Customer Success
- Agent-Only Company
- Acquisition Rejected
- Licensed Technology

Founder dilemma responses can now:

- create a permanent company flag
- create a recurring obligation for a defined number of sprints
- modify agent relationships
- apply recurring revenue, runway, trust, momentum, or energy effects
- record the choice in Company Story
- end the career through an accepted acquisition

The Records tab now includes **Company Story**, showing permanent flags, current obligations, and prior decisions.

## Agent mechanics

Relationship is no longer display-only. It now modifies actual task quality and evidence behavior.

- High relationship can improve quality and evidence completeness.
- Low relationship can reduce quality and weaken evidence.
- A highly trusted agent can voluntarily surface an evidence warning.

Archetypes now provide mechanical tendencies:

- **Aurora — The Analyst:** stronger research/trust work and evidence; weaker under aggressive selling pressure.
- **Stacks — The Builder:** stronger engineering and critical technical work.
- **Brio — The Promoter:** stronger marketing/sales output; greater evidence risk on critical sales work.

## Objective generation

Objectives are selected only after the five-task draft exists.

Build 6 checks feasibility before selecting objectives that depend on:

- exact role coverage
- model-family diversity
- an agent with recoverable drift

Recovery objectives now store a target agent. Live objective progress is visible on the command screen.

## Continuous-mode escalation

Later ventures now apply increasing operating pressure:

- Runway burn begins at 3 per sprint and scales up to 7.
- Founder Energy cost begins at 2 and scales up to 4.
- Correlated-failure probability rises by venture, with a bounded increase.
- Correlated-failure quality penalties grow by venture, with a cap.

Automatic fixed minimum recovery at a venture transition was removed. Recovery is now limited and earned from company trust, momentum, and agent relationships.

The Venture screen displays the current pressure tier.

## Continuous checkpoint and Founder Pass flow

A continuous venture now always reaches its checkpoint before monetization is evaluated.

- **Retire** remains available to every player.
- **Continue** is the action gated by Founder Pass after Venture 1.
- Purchasing returns to the held career and advances it.
- Checkpoint state remains saved until the player retires or continues.

Bounded mode retains its original Venture 2 gate and ending behavior.

## Scoring

The detailed career score now considers:

- verified evidence
- completed sprint objectives
- average agent relationship
- ventures completed
- unresolved obligations

This reduces the tendency for continuous score to become only a function of accumulated revenue or elapsed ventures.

## Sprint-flow presentation

The command screen now shows five explicit phases:

1. Founder Event
2. Choose Commitments
3. Assign Team
4. Review and Resolve
5. Commit Sprint

The phase tracker derives from actual store state rather than a manually advanced tutorial state.

## Save schema v7 → v8

`CareerSave` gains deterministic deck state and living-company state:

- `recentTaskTitles`
- `taskDeckTitles`
- `dilemmaDeckTemplateIDs`
- `dilemmaDeckChapter`
- `recentObjectiveKinds`
- `companyFlags`
- `activeObligations`
- `decisionHistory`
- `completedObjectives`

All fields decode defensively for older saves. The migration chain supports v1 through v7 and rewrites successfully loaded careers as v8.

## Version metadata

- Marketing version: **1.0**
- Build number: **4**
- Save schema: **8**
