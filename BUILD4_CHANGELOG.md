# SOLO: UNICORN RUN — Build 4 Change Log

Build 4 is the **Founder Drama and Decision Pass**. It addresses the central
playability problem in Build 3: the simulation was thoughtful, but the repeated
player action was mostly assign, review, and commit.

## 1. Five-option sprint draft

- Every sprint deterministically generates five distinct opportunities.
- Three begin as active commitments; two remain in the backlog.
- Before work begins, the player can swap any backlog opportunity into the
  active set.
- Every ignored opportunity carries visible `skipEffects`, so prioritization has
  consequences.
- The authored pool expands from nine repeating tasks to 38 tasks across seven
  categories and three urgency levels.

## 2. Founder dilemmas

- Every sprint now includes a required founder dilemma with three responses.
- Twelve authored dilemmas cover customer pressure, investor demands, founder
  life, agent behavior, model-provider risk, trust, and growth decisions.
- Choices apply immediate effects, delayed effects, and agent relationship
  changes.
- The selected choice is recorded in the sprint report and persisted in the
  career save.

## 3. Founder Review now changes the current result

A review is no longer an informational dead end. After reviewing, the player
must choose one resolution before the sprint can commit:

- **Approve** — accept the result as reported and verified.
- **Rework** — spend one additional Founder Attention, four Energy, and one
  Runway to improve current quality and evidence.
- **Ship Anyway** — increase immediate payoff by 20% while adding delayed Trust
  and Momentum risk.
- **Cross-check** — spend one additional Founder Attention to improve evidence,
  reduce uncertainty, and remove a correlated model-family failure marker.

The previous bypass — review, learn the truth, and commit without acting — is
closed by `resolutionLocked` validation.

## 4. Scarce Founder Attention

- Pure Agent and Trust-First receive two Founder Attention actions per sprint.
- Human-Guided receives three.
- Review, Rework, and Cross-check all consume attention.
- This replaces the old system where the player could routinely review all
  three tasks and solve the run through a fixed pattern.

## 5. Agent personality and relationships

Aurora, Stacks, and Brio now carry persistent character data:

- Archetype
- Two traits
- Personal ambition
- Stress trigger
- Founder relationship score
- Contextual sprint dialogue

Dilemma choices and founder review decisions can alter relationships. The agent
screens and living garage surface the new data.

## 6. Venture chapters and optional objectives

Each twelve-sprint venture is divided into:

1. Prototype
2. First Customers
3. Launch Pressure
4. Survival or Scale

Six deterministic optional objective templates add short-term goals and rewards,
including evidence, trust, revenue, role diversity, low-energy operation, and
review discipline.

## 7. Visible garage evolution

Five progression rewards now appear in the garage and Headquarters summary:

- Strategy Wall
- Customer Map
- Evidence Shelf
- Operations Rack
- Recovery Corner

These are lightweight overlays on the existing approved garage art, so the pass
adds visible progress without replacing the environment or introducing a new 3D
runtime dependency.

## 8. Expanded sprint report

The report now records:

- Venture chapter
- Ignored opportunities and their consequences
- Founder dilemma and chosen response
- Optional objective success or failure
- Existing metric, evidence, drift, and task-resolution results

## 9. Save schema v6 and build metadata

- `CareerSave` gains backlog, Founder Attention usage, active dilemma, selected
  dilemma choice, and current objective.
- All new fields decode with defaults so older careers remain loadable.
- Explicit migration accepts v1, v2, v3, v4, and v5 saves and rewrites them to
  the v6 key.
- Build number is updated to **1.0 (3)** in `Project.json`, `App/Info.plist`, and
  Debug/Release Xcode project settings.

## Modified files

- `App/GameModels.swift`
- `App/SimulationModels.swift`
- `App/GameStore.swift`
- `App/ContentView.swift`
- `App/FounderEnvironmentScreen.swift`
- `App/FounderGarageEnvironment.swift`
- `Tests/GameStoreTests.swift`
- `Tests/HindsightTests.swift`
- `Tests/FounderPassGateTests.swift`
- `Project.json`
- `App/Info.plist`
- `SoloUnicornRun.xcodeproj/project.pbxproj`

## New documentation

- `BUILD4_READ_ME_FIRST.md`
- `BUILD4_CHANGELOG.md`
- `BUILD4_GAMEPLAY_DESIGN.md`
- `TEST_REPORT_BUILD4.md`
