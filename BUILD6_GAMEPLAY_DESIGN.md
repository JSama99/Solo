# SOLO: UNICORN RUN — Build 6 Gameplay Design

## Design objective

Build 6 moves SOLO from a sequence of independent startup decisions toward a company that remembers how it was built.

The player should feel three forms of pressure at the same time:

1. **Immediate:** Which three opportunities deserve attention this sprint?
2. **Operational:** Which reports deserve review, correction, or deliberate risk?
3. **Persistent:** What kind of company will this choice create several sprints from now?

## Sprint rhythm

### Phase 1 — Founder Event

The player responds to an authored founder dilemma. The decision can change current stats, relationships, persistent company identity, operating obligations, or the ending.

### Phase 2 — Choose Commitments

Five opportunities are presented. The player keeps three and leaves two behind. Build 6 uses a sixty-card venture deck, so every opportunity shown during the first twelve-sprint venture is unique.

### Phase 3 — Assign Team

The player considers role fit, intent fit, model family, agent reliability, drift, trust, relationship, and personality.

### Phase 4 — Review and Resolve

Founder Attention is spent selectively. A reviewed result must receive one explicit resolution:

| Resolution | Purpose | Cost or risk |
|---|---|---|
| Approve | Accept the reviewed result | No additional Attention |
| Rework | Improve current quality and evidence | Attention, Energy, and Runway |
| Ship Anyway | Increase immediate payoff | Delayed Trust and Momentum exposure |
| Cross-check | Independently verify and reduce cascade risk | Attention and an alternate model family |

### Phase 5 — Commit Sprint

The game applies current work, ignored opportunities, prior delayed effects, current obligations, founder intent, dilemma consequences, objective rewards, and venture operating pressure. The report then explains the visible result without revealing protected hidden truth.

## Persistent company model

### Company flags

Flags describe durable identity and prior choices. They are not generic achievements. They record how the founder operates, such as bootstrap independence, evidence differentiation, customer-first recovery, or burnout culture.

### Obligations

Obligations are time-bounded consequences that apply every sprint. Examples include technical-debt costs, payroll, support contracts, investor pressure, pricing commitments, and launch recovery.

### Decision history

Every persistent choice receives a record containing the dilemma, selected response, venture, sprint, and consequence summary. This gives the company a readable history rather than only a final score.

## Agent identity

Relationships and personalities must influence both story and simulation.

- Relationship affects output quality and evidence behavior.
- Archetype modifies role-specific performance.
- Dilemma decisions can strengthen or damage a relationship.
- Review resolutions can affect how an agent relates to the founder.

Future agent dialogue should use the same state rather than introducing a disconnected conversation system.

## Continuous-career pressure

Continuous mode should not be twelve easy sprints repeated forever.

Build 6 begins the escalation through:

- higher operating burn
- higher founder cost
- increasing correlated model-family risk
- stronger correlated-failure penalties
- limited earned recovery at checkpoints
- score penalties for unresolved obligations

The pressure is intentionally capped so later ventures become harder without becoming mathematically unwinnable solely because the venture number is high.

## Determinism rule

Every random decision that affects future gameplay must be represented by either:

- the seeded random-number-generator state, or
- persisted deck/history state that changes the candidate pool

Saving and reloading must never create a different future merely because in-memory repetition protection disappeared.

## Content rule

Random selection is not a substitute for content pacing.

- Tasks use a no-replacement venture deck.
- Dilemmas use a no-replacement chapter deck.
- Objectives are filtered for feasibility before selection.
- Acquisition acceptance can produce a real ending.

## What Build 6 intentionally does not claim to finish

- Company flags do not yet unlock full branching event chains.
- There are still 12 founder dilemmas; Build 6 fixes their pacing rather than authoring a larger story library.
- The garage remains primarily a layered presentation over the existing environment rather than a fully interactive 3D life simulation.
- Human hires and investors exist as persistent company consequences, not yet as controllable characters.
- Long-run balance still requires real-player telemetry.

Those are appropriate targets for a later narrative and environment pass after Build 6 proves the persistent mechanics are stable.
