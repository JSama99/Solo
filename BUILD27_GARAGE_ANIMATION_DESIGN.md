# Build 27 — Founder Computer Animation Design

The Founder Computer told the player what had happened. It did not *show* it.
Selecting an agent swapped a border colour, assigning work swapped the word
`Idle` for `Working`, and a resource change swapped one integer for another.
Every one of those is a state change the player is supposed to feel.

This build gives the Garage a motion layer. Nothing here changes the
simulation: every animation reads state the simulation has already produced,
and the seeded generator is never touched by a redraw.

## Principles

1. **Motion reports; it never decides.** Animations are pure functions of
   sprint state. There is no timer that mutates the game, no random visual roll,
   no animation-only flag stored in the save.
2. **One vocabulary.** Timing goes through `MotionKind` (`.state` → `.smooth`,
   `.emphasis` → `.snappy`, `.celebration` → `.bouncy`), so a selection in the
   Garage feels like a selection everywhere else.
3. **Reduce Motion is a policy, not a call site.** `MotionKind.resolved(reduceMotion:)`
   returns `nil`, and every phase animator has a static branch. With Reduce
   Motion on, every state is still distinguishable — by colour, symbol, fill,
   and text — with no movement at all.
4. **Simplest API that produces the result.** `withAnimation`, `.animation(_:value:)`,
   `.transition`, `.contentTransition(.numericText)`, `.symbolEffect`, and
   `PhaseAnimator`. No keyframes were added for their own sake.

## The five animations

### 1. Agent card selection — `AgentCardPressStyle`

A `ButtonStyle` on the workspace card. Press compresses to `0.955`; the
selected card rests at `1.025` and carries a wider, brighter accent shadow
(radius 22 vs 6). Deselection is the same spring played backwards, so cards
trade places rather than blink.

Trigger: `selectedAgentID` on `FounderComputerScreen`.

### 2. Task assignment — `AssignmentAcknowledgement`

Five beats, in order:

1. The task row in the assignment sheet holds in a committed state for 320 ms
   so the tap has an answer before the sheet leaves.
2. The sheet dismisses and the agent card plays `rest → impact → bloom`: it
   takes a 1.045 hit, then an accent ring expands out of it and dissolves.
3. The card's status area transitions from `Standing by` to `Working`.
4. `AgentWorkIndicator` starts its continuous cycle.
5. `.sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: assignmentTick)`.

Trigger: the card's `task?.id` changing to a non-nil value, counted so a
reassignment to the same task still reads.

### 3. Working state — `AgentWorkIndicator`

`Activity.derive(task:isResting:)` maps the assignment facts to one of five
states — `resting`, `idle`, `working`, `awaitingDecision`, `settled` — and each
gets its own treatment:

| Activity | Dots | Rail |
| --- | --- | --- |
| `idle` | three dim | empty |
| `resting` | three dim | short static nub |
| `working` | one lit dot cycling (0.28 s) | accent gradient sweeping the rail (1.15 s) |
| `awaitingDecision` | three lit | full rail breathing 0.35 ↔ 1.0 (0.62 s) |
| `settled` | three lit | solid accent fill |

Working cards also breathe an accent ring (`workingGlow`, 1.1 s), so the state
is legible from the card's silhouette.

This derivation deliberately does **not** use `AgentStationViewModel.semanticState`.
That property folds in stress and drift and — because `GameStore.assign`
synthesises a `TaskResult` immediately — never reports `.working` at all. The
indicator reads the same raw facts the label reads; no simulation rule moved.

### 4. Founder review — `FounderResolutionPanel` + `ResolutionFeedback`

The panel is now the single resolution surface, at the top of the scroll rather
than buried in the command deck. It enters with an asymmetric transition
(`scale(0.9, anchor: .top)` + `move(edge: .top)` + `opacity`), sits on an accent
shadow (radius 26, y 14), and reveals its header, verdict, and four choices in
sequence via `milestoneReveal(order:)`.

Resolving plays `rest → strike → counter → hold → settle`. Approve blooms a
mint ring and a 78 pt seal that **holds** for 0.55 s before releasing — long
enough to read. Every other choice gets the restrained version: an amber ring
and an 8 pt lateral nudge of the panel that returns exactly to zero. The screen
never shakes. Approve additionally fires `.sensoryFeedback(.success)`.

Trigger: `resolutionTick`, incremented only when `resolutionLocked` actually
flips from false to true — so a rejected or blocked call animates nothing.

### 5. Resource changes — `ResourceMetricView`

All seven HUD values (Runway, Energy, Trust, Attention, Momentum, Revenue,
Capital) are tiles. On a change, a tile:

- rolls its digits with `.contentTransition(.numericText(value:))`,
- tints mint (up) or coral (down) across symbol, value, and background,
- grows to 1.07 from its leading edge,
- floats a signed delta chip with an **arrow**, so direction never depends on
  colour alone,
- settles back after 1.5 s with `.state` timing.

A change arriving during the emphasis window cancels the pending settle and
replaces it rather than queueing.

## What is deliberately not animated

- Simulation outcomes, RNG ordering, hidden truth, Evidence Ledger rules,
  Daily Challenge determinism, save format, RevenueCat, career progression.
- Gameplay randomness never drives a visual: the sweep is a fixed linear cycle.

## Tests

`Tests/GameplayAnimationTests.swift` pins the derivations behind each
animation: the activity mapping (including against a store the test actually
plays through assign → review → resolve), the press/selection scales, both
phase tables, the currency and unit formatting, and a two-run fingerprint
proving that deriving animation state consumes no simulation randomness.
