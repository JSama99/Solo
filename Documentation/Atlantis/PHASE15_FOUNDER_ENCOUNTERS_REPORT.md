# Atlantis Phase 15 — Founder Encounters & Named NPCs

## Verdict

**GO WITH HUMAN ACCEPTANCE**

The architecture, deterministic encounter behavior, simulator UI flows, canonical isolation, DEBUG boundary, and device launch probes pass. Physical-device dialogue readability, pacing, VoiceOver phrasing, and perceived motion still require human acceptance on the connected screens; those qualities are not claimed from automation.

## Architecture

- `AtlantisNamedNPCDefinition` is the six-person, data-driven identity registry.
- `AtlantisNamedEncounterDefinition` contains eleven short authored encounters and their explicitly classified responses.
- `AtlantisNamedEncounterPolicy` is a pure public-signal eligibility and deterministic selection layer.
- `AtlantisNamedEncounterDirector` is a session-only subordinate of `AtlantisLivingWorldDirector`. It owns physical named entities, lifecycle, one active session, cooldowns, duplicate diagnostics, and response counters.
- `AtlantisNamedDialogueCard` is a compact, scrollable SwiftUI overlay with Dynamic Type, semantic name/role/dialogue order, 44-point controls, and an always-available Leave/Return action.
- Phase 13 integration remains in `AtlantisRealityWorld.refreshInteractionCandidate()`. Building and named candidates pass through the same `AtlantisInteractionSelectionPolicy`; named targets do not create a second input authority.
- Named entity motion is updated centrally. Reduce Motion suppresses decorative head/glyph movement while keeping dialogue and encounter state.
- Cooldowns and physical presence are session-only. No save fields or migration were added.

## NPC roster

| Name | Role | Affiliation | Primary district | Encounter archetypes |
|---|---|---|---|---|
| Mara Chen | Founder | Quarry Labs | Founder District | founder advice |
| Eli Navarro | Founder | Relay Foundry | Startup Row | founder rumor, founder advice |
| Nia Okafor | Investor | Tideglass Ventures | Venture District | investor interest, investor skepticism |
| Sloane Park | Reporter | Signal TV | Media District | reporter question: spotlight and scrutiny |
| Devon Reyes | Customer | Harborline Systems | Commerce District | customer praise, customer complaint |
| Iris Vale | Rival employee | Pallas AI | Tech Core | hiring signal, public competitor positioning |

Each physical entity uses the stable identifier `atlantis.namedNPC.<npcID>`, appears only when its owned district is resident and an encounter is eligible, has no collision, and is visually distinct from pooled pedestrians through a unique color, white glyph, name, and role/affiliation plate.

## Encounter matrix

| NPC | Encounter | Eligibility | Responses | Classification |
|---|---|---|---|---|
| Mara | `mara.peer-advice` | baseline/moderate public Momentum; morning/day/evening | protect core; ask what she sees | presentation-only |
| Eli | `eli.ecosystem-rumor` | public rival claimed Momentum ≥ 70; day/evening/night | ask what is public; move on | presentation-only |
| Eli | `eli.peer-reaction` | public Momentum ≥ 70; morning/day/evening | credit team; return to work | presentation-only |
| Nia | `nia.interest` | public Momentum ≥ 70 or Venture ≥ 4 | share thesis; revisit later | presentation-only / deferred |
| Nia | `nia.skepticism` | material public Coverage and Trust < 50 | point to public evidence; decline speculation | presentation-only |
| Sloane | `sloane.spotlight` | Coverage ≥ 40 and Trust ≥ 50; day/evening | answer; refer to Brio; no comment | presentation-only / deferred |
| Sloane | `sloane.scrutiny` | Coverage ≤ -40 or Trust < 35 | public facts; refer to Brio; decline | presentation-only / deferred |
| Devon | `devon.praise` | Trust ≥ 75 | ask what helped; thank Devon | presentation-only |
| Devon | `devon.complaint` | explicit noncanonical UI fixture only | ask what happened; acknowledge | deferred / presentation-only |
| Iris | `iris.hiring` | public Pallas claimed Momentum ≥ 70; day/evening/night | ask about claim; end | presentation-only |
| Iris | `iris.positioning` | public Pallas claimed Momentum ≥ 70; morning/day/evening | keep to public facts; leave | presentation-only |

The Brio and Evidence references are deliberately deferred because Phase 15 found no existing canonical API that could safely execute those actions from this presentation layer.

## Canonical isolation

- GameStore direct mutations: **none**
- Canonical APIs invoked by named encounters: **none**
- Named canonical write-back counter: **0 by design**
- Save version: **19**
- Atlantis compile boundary: **`#if DEBUG`**
- Hidden-state exposures: **none**
- Public input boundary: `AtlantisWorldSignalSnapshot` only: Trust, Momentum, Coverage, Venture, and Tech.com-visible rival claims.
- Runtime generation/network dialogue: **none**

The customer complaint has no corresponding public customer-incident value in the current snapshot. It is unavailable under live canonical state and is exposed only through fixture F, labeled `presentation fixture` in DEBUG UI.

## Diagnostics

The DEBUG HUD reports named NPC count and IDs, eligible encounter count, active NPC/archetype, cooldowns, public-signal classification, current district, duplicate violations, canonical writes, presentation responses, and decision cost. Session counters distinguish presentation-only and deferred responses.

## Performance and bounds

- Registry size: 6 named NPCs
- Encounter registry size: 11 authored encounters
- Maximum simultaneous encounter sessions: 1
- Maximum named NPCs physically possible under the three-district streaming residency plan: 3
- Named entity high-frequency loops: 0 per entity; motion is centralized under the existing scene update
- Network/LLM/pathfinding/facial simulation: none
- Duplicate violations in focused tests: 0
- Physical process stability: app remained running after flagged launch on iPhone 16 Pro and iPad Air M4
- Named update cost, dialogue activation latency, memory delta, drawable-request cadence, and thermal state were not captured as trustworthy numeric Phase 15 measurements. Phase 14 hardware measurements remain historical evidence and are not relabeled as Phase 15 results.

## Verification

| Check | Result |
|---|---|
| Focused Atlantis runtime tests, iPhone 17 Pro Max simulator iOS 26.5 | 53 passed, 0 failed, 0 skipped |
| Complete unit target, iPhone 17 Pro Max simulator iOS 26.5 | 837 passed, 0 failed, 0 skipped |
| Phase 15 named UI tests, iPhone 17 Pro Max simulator iOS 26.5 | 2 passed, 0 failed, 0 skipped |
| Phase 15 named UI tests, iPad Air 11-inch M4 simulator iOS 26.5 | 2 passed, 0 failed, 0 skipped |
| Phase 13 eight-route UI regression, iPhone simulator | 1 passed, 0 failed, 0 skipped |
| Debug simulator app build | passed |
| Generic iOS Release build | passed |
| Signed generic iOS Debug device build | passed |
| iPhone 16 Pro install / flagged launch / process-alive probe | passed; PID 5728 observed |
| iPad Air M4 install / flagged launch / process-alive probe | passed; PID 1486 observed |

The initial focused run had one failed assertion in named-dialogue dismissal. The named path was incorrectly using the building round-trip ground validator despite never moving the founder or camera. Dismissal now releases the frozen streaming state directly, applies cooldown, and refreshes the shared interaction candidate. The single failed test and then the entire focused suite passed after the fix.

## Human acceptance remaining

- Read dialogue on the physical iPhone and iPad at preferred Dynamic Type sizes.
- Navigate the card with VoiceOver and judge name/role/prompt/response phrasing.
- Judge the 10–30 second intended pacing and physical-world awareness.
- Judge visual distinction of the six lightweight placeholder figures and nameplates.
- Confirm the reduced-motion presentation feels calm while retaining encounter meaning.
- Exercise the response and cooldown controls manually on each physical screen.

## Phase 15 files

- `App/AtlantisWorldPresentationModel.swift`
- `App/AtlantisRealityScene.swift`
- `App/AtlantisRealityView.swift`
- `Tests/AtlantisRuntimeTests.swift`
- `UITests/AtlantisRuntimeUITests.swift`
- `Documentation/Atlantis/PHASE15_FOUNDER_ENCOUNTERS_REPORT.md`

No project file, shared scheme, save model, package, or production route was intentionally changed for Phase 15. No commit or push was performed.

## Completion git status

```text
## atlantis-phase0-masterplan...origin/atlantis-phase0-masterplan
MM App/AtlantisRealityScene.swift
MM App/AtlantisRealityView.swift
MM App/AtlantisWorldPresentationModel.swift
 M App/ContentView.swift
 M App/FounderDeskWorkspace.swift
 M App/FounderDeskWorkspaceModel.swift
A  Documentation/Atlantis/PHASE14_LIVING_WORLD_LAYER_REPORT.md
A  Documentation/Atlantis/Phase14Evidence/ (tracked Phase 14 evidence files)
 M SoloUnicornRun.xcodeproj/xcshareddata/xcschemes/Solo Unicorn Run.xcscheme
MM Tests/AtlantisRuntimeTests.swift
 M Tests/FounderDeskWorkspaceTests.swift
MM UITests/AtlantisRuntimeUITests.swift
 M UITests/Build32_6_1ProductionContinuityUITests.swift
?? Documentation/Atlantis/PHASE15_FOUNDER_ENCOUNTERS_REPORT.md
?? existing workspace support, Atlantis asset, raw trace, and scratch paths
```

`MM` reflects the already-staged Phase 14 checkpoint plus unstaged Phase 15 edits in the same Atlantis files. The Founder Desk, shared scheme, support files, asset directories, Phase 14 raw traces, and scratch paths were pre-existing and were not modified or staged by Phase 15.
