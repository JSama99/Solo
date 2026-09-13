# SOLO Atlantis — Phase 19: Agent Operations Economy

Date: 2026-09-13  
Verdict: **GO WITH HUMAN ACCEPTANCE**

Phase 19 adds one persisted Agent Operations authority for Aurora, Stacks, and Brio. The founder can allocate bounded capacity, preserve headroom, choose autonomy, respond to one agent-specific decision per sprint, or let the agent decide. Assignment load contributes to effective workload, and sustained effects resolve once at the existing sprint boundary.

The implementation reuses canonical agent reliability, calibration, drift, trust, relationship, stress, task assignment, Evidence, Founder Attention, Product Launch, and Strategy Board state. It introduces no duplicate quality, drift, trust, workload, finance, Atlantis, or task authority.

## Architecture

### Authority and timing

`AgentOperationsState` is the canonical persisted operations authority. It owns per-agent capacity allocations, autonomy, bounded intervention history, pending delayed effects, overload streak, and deduplicated decision records. `GameStore` remains the only mutable simulation authority.

`AgentOperationsPolicy` is pure and deterministic. It derives:

- assignment load and effective workload;
- workload bands;
- founder-visible decision requests;
- autonomous decisions from a local seeded generator;
- assignment-time agent input adjustments;
- sprint-boundary effects; and
- bounded Product Launch quality context.

The policy does not mutate the store, consume the canonical gameplay RNG, call a network service, or manipulate Atlantis. `GameStore.resolveAgentOperationsAtSprintBoundary()` applies effects once per career sprint immediately before the existing unassigned-agent recovery step.

### Allocation model

Each agent has capacity 100. Balanced defaults allocate 75 and leave 25 headroom. Values cannot be negative, assigned to another agent's domain, or make the total exceed capacity. Assignment urgency adds temporary load of 15, 20, or 25 without becoming another stored workload truth.

Workload is classified as Light, Healthy, High, Overloaded, or Critical. Headroom can reduce stress and drift pressure. Critical load adds stress, reliability pressure, and drift pressure at the sprint boundary.

### Assignment integration

The existing `GameStore.assign` lifecycle and `SimulationEngine.makeResult` remain canonical. Agent Operations supplies a bounded adjusted copy of the assigned agent to that existing pure resolution call. The actual canonical agent, task, expense, result cache, review lifecycle, and RNG ordering remain owned by their established systems.

### Autonomy and decisions

Every profile supports Founder Controlled, Guided, and Autonomous behavior. Founder Controlled adds calibration context while reducing throughput. Autonomous mode can improve throughput when calibration is strong and adds risk when calibration or workload is weak. Guided is the version-19 compatibility behavior.

Each agent exposes one stable decision request per venture/sprint. `Let Agent Decide` costs no Attention and resolves with the saved career seed, current agent state, workload, and operations state. Founder intervention costs one Attention. An unnecessary override only receives a micromanagement penalty when calibration, reliability, workload, and undisclosed canonical conditions all qualify; a low-calibration intervention instead queues a small calibration benefit.

Decision effects and micromanagement effects are queued and applied at the sprint boundary. Repeated resolution of the same request is rejected.

### Persistence and migration

Agent Operations choices are canonical, so Phase 19 increments the save format from **19 to 20**. `CareerSave.agentOperations` persists the complete state. Allocation dictionaries encode as raw-value-sorted records to preserve byte-for-byte deterministic save output.

`GameStore.continueCareer()` has an explicit v19 → v20 path. A v19 career receives balanced allocations and Guided autonomy for every agent, then is rewritten to the v20 key. All older migration paths remain intact. The v19 key is included in both save and reset purge lists.

### Phase 17 and Phase 18 integration

The Strategy Board reads only founder-known operations projections. It can report excessive workload and inadequate Stacks reliability allocation; it never reads or names hidden drift or actual quality.

Product Launch retains its Phase 18 preparation and resolution gates. Its frozen hidden resolution truth receives a bounded operations adjustment based on the prepared agent's allocation, autonomy, and workload. Founder-visible launch risks describe workload and neglected operational focus without revealing hidden truth.

### Deferred boundaries

Technical Debt is an allocation focus that influences existing reliability and drift; no separate technical-debt resource was created. Customer counts, bespoke Hindsight precedents, Signal TV programming, and Phase 20 physical-agent behavior were not added because the current repository lacks a safe dedicated canonical boundary for those extensions.

## Agent matrices

### Aurora

| Operational category | Canonical system influenced | Tradeoff | Potential risk |
| --- | --- | --- | --- |
| Market Research | Existing research assignment input | Faster market read | Less verification headroom |
| Evidence Verification | Existing calibration and drift | Better evidence posture | Slower primary research emphasis |
| Competitor Intelligence | Existing research execution context | Better external awareness | Less continuous monitoring |
| Continuous Monitoring | Existing overload/drift protection | Earlier operating awareness | Less concentrated primary output |

### Stacks

| Operational category | Canonical system influenced | Tradeoff | Potential risk |
| --- | --- | --- | --- |
| Product Development | Existing engineering assignment input | More shipping throughput | Reliability pressure when safeguards are low |
| Reliability | Existing reliability and Product Launch context | Stronger delivery resilience | Less feature capacity |
| Technical Debt | Existing reliability/drift pressure | Sustained technical health | Slower immediate shipping |
| Experimental R&D | Existing engineering execution context | Exploration upside | Less near-term delivery and safeguards |

### Brio

| Operational category | Canonical system influenced | Tradeoff | Potential risk |
| --- | --- | --- | --- |
| Acquisition | Existing marketing assignment input | More reach and throughput | Public-response coverage can weaken |
| Retention | Existing growth execution context | More durable customer posture | Less new acquisition |
| Brand | Existing calibration and Trust context | Stronger message discipline | Less direct growth capacity |
| Public Response | Existing calibration, Trust, and launch context | Better response resilience | Less acquisition throughput |

## Autonomy matrix

| Autonomy level | Founder Attention impact | Agent discretion | Risk |
| --- | --- | --- | --- |
| Founder Controlled | Intervention still costs one Attention | Low | Lower throughput; calibration can improve |
| Guided | Intervention costs one Attention; letting decide costs none | Shared | Balanced compatibility behavior |
| Autonomous | Let Agent Decide costs no Attention | High | Weak calibration or high workload can increase drift pressure |

## Decision matrix

| Agent | Decision | Let Agent Decide behavior | Founder intervention behavior | Potential micromanagement effect |
| --- | --- | --- | --- | --- |
| Aurora | Verification depth versus market read | Deterministically selects Evidence Verification or Market Research | Founder chooses deeper verification or trusts the market read | Strong, well-calibrated Aurora can lose Trust/relationship from an unnecessary override |
| Stacks | Reliability versus speed | Deterministically selects Reliability or Product Development | Founder prioritizes reliability or speed | Strong, well-calibrated Stacks can receive the contextual penalty |
| Brio | Acquisition versus public response | Deterministically selects Public Response or Acquisition | Founder prioritizes acquisition or public response | Strong, well-calibrated Brio can receive the contextual penalty |

## Fixtures

Nine deterministic DEBUG fixtures cover Balanced, Stacks Overloaded, Reliability Neglected, Aurora Verification Emphasis, Brio Acquisition Heavy, High Calibration Autonomy, High Calibration Founder Override, Low Calibration Intervention, and Hidden Drift. The Hidden Drift fixture changes canonical hidden state while keeping the player surface and request founder-safe.

## User interface and accessibility

The existing production `AIOperationsFloor` inside the Founder Computer now expands each established portrait card into its agent-specific operations controls. It shows effective workload, workload band, canonical visible reliability/calibration/trust, overload guidance, four distinct allocation rows, headroom, presets, autonomy, and a decision request.

Allocation rows provide 44-point plus/minus controls and a VoiceOver adjustable action. Controls have stable accessibility identifiers, meaningful values and hints, and do not rely on color alone. The tested route honors Reduce Motion and remains operable at the largest Dynamic Type category on both compact and regular-width simulators. DEBUG diagnostics include every requested operational field while reporting drift only as “detected through review” or “not disclosed.”

## Canonical isolation

```text
New canonical resources: AgentOperationsState and its per-agent profiles; no new currency/stat resource
Existing resources reused: assignments, TaskResult, reliability, calibration, drift, trust, relationship, stress, Attention, Evidence, Product Launch, Strategy Board
Save migration: explicit v19 -> v20 balanced compatibility migration
Save version: 20
Direct Atlantis manipulation: none
Hidden truth exposures: none found in player-facing operations or Strategy Board projections
Runtime LLM/network agent: none
Runtime random source: local SeededRandomNumberGenerator only; canonical RNG ordering preserved
```

No new Swift source file or project membership change was required. Phase 19 did not edit the Xcode project or shared scheme.

## Verification

All final results below are from the version-20 revision.

| Verification | Result |
| --- | --- |
| Focused `AgentOperationsEconomyTests` | **15/15 passed** |
| Determinism follow-up plus focused Phase 19 | **16/16 passed** |
| Agent Operations + Strategy Board + Product Launch + Garage + Atlantis grouped regression | **276/276 passed** (34 AIOperationsFloor + 59 Atlantis Runtime + 74 Founder Desk/Strategy + 97 Founder Garage Reality + 12 Product Launch) |
| Complete unit target | **878/878 passed** |
| Phase 19 UI, iPhone 17 Pro Max simulator | **2/2 passed** |
| Phase 19 UI, iPad Air 11-inch (M4) simulator | **2/2 passed** |
| Debug generic iOS Simulator build | **BUILD SUCCEEDED** |
| Release generic iOS Simulator build | **BUILD SUCCEEDED** |
| Physical iPhone 16 Pro signed Debug build | **BUILD SUCCEEDED** |
| Physical iPad Air 11-inch (M4) signed Debug build | **BUILD SUCCEEDED** |
| Physical iPhone 16 Pro install and fixture launch | **Passed**; bundle `com.talonsight.solounicornrun` launched |
| Physical iPad Air 11-inch (M4) install and fixture launch | **Passed**; bundle `com.talonsight.solounicornrun` launched |
| Whitespace validation | `git diff --check` **passed** |

The first complete suite detected nondeterministic JSON bytes from enum-keyed allocation dictionaries. Stable sorted allocation records fixed it. After the save migration was made explicit, one complete run found outdated save-version assertions and another found the outdated legacy-key count. Those expectations were corrected; the final complete run passed 878/878.

Initial iPad UI runs exposed XCUITest targeting limits around an expanded three-column card. Live Simulator inspection confirmed the production card expanded correctly. The final automation exercises the primary 44-point allocation controls directly and passes on both device classes. Preset behavior is covered by focused unit tests.

Physical probes prove signing, build, installation, and process launch with the deterministic Phase 19 fixture. They do not establish visual, interaction, VoiceOver, animation, audio, haptic, or gameplay feel.

## Human acceptance

Review these subjective items on both physical devices:

- whether capacity and headroom are understood without explanation;
- whether each agent feels operationally distinct;
- whether the number density remains readable on iPhone;
- whether presets and plus/minus controls feel fast enough;
- whether Let Agent Decide is tempting at useful moments;
- whether intervention cost and micromanagement penalties feel fair;
- whether overload and recovery cadence feel balanced over several sprints;
- VoiceOver order and adjustable-control feedback;
- largest Dynamic Type reachability and truncation;
- Reduce Motion transitions;
- audio and haptic timing; and
- portrait personality and card hierarchy during repeated use.

## Git ownership

Phase 19 modified these existing files:

- `App/AIOperationsFloor.swift`
- `App/App.swift`
- `App/FounderComputerScreen.swift`
- `App/FounderDeskWorkspaceModel.swift`
- `App/GameModels.swift`
- `App/GameStore.swift`
- `App/SimulationModels.swift`
- `Tests/AtlantisRuntimeTests.swift`
- `Tests/DivergenceSystemTests.swift`
- `Tests/FounderDeskWorkspaceTests.swift`
- `Tests/GameStoreTests.swift`
- `Tests/GameplayMotionTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`

Phase 19 added this report. Several modified files already contained uncommitted Phase 14–18 work, which was preserved. The pre-existing shared-scheme modification was not changed by Phase 19. Nothing was staged, committed, pushed, reset, or discarded.

Existing staged Phase 14 report/evidence and mixed staged/unstaged Atlantis files remain present. Phase 15–18 reports and evidence remain untracked or modified as they were at Phase 19 inspection. Phase 19 changes are the files listed above plus this report.

Final `git status --short --branch`:

```text
## atlantis-phase0-masterplan...origin/atlantis-phase0-masterplan
 M App/AIOperationsFloor.swift
 M App/App.swift
MM App/AtlantisRealityScene.swift
MM App/AtlantisRealityView.swift
MM App/AtlantisWorldPresentationModel.swift
 M App/ContentView.swift
 M App/FounderComputerScreen.swift
 M App/FounderDeskWorkspace.swift
 M App/FounderDeskWorkspaceModel.swift
 M App/FounderGaragePhysicalComponents.swift
 M App/GameModels.swift
 M App/GameStore.swift
 M App/SimulationModels.swift
A  Documentation/Atlantis/PHASE14_LIVING_WORLD_LAYER_REPORT.md
A  Documentation/Atlantis/Phase14Evidence/ipad-air-m4-living-world-profile.json
A  Documentation/Atlantis/Phase14Evidence/iphone16pro-living-world-profile.json
A  Documentation/Atlantis/Phase14Evidence/physical-game-performance-summary.json
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/baseline.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/pallas-surge.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/scrutiny.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/ipad-air-11-m4/spotlight.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/baseline.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/pallas-surge.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/scrutiny.png
A  Documentation/Atlantis/Phase14Evidence/reactive-scenarios/iphone-17-pro-max/spotlight.png
 M "SoloUnicornRun.xcodeproj/xcshareddata/xcschemes/Solo Unicorn Run.xcscheme"
MM Tests/AtlantisRuntimeTests.swift
 M Tests/DivergenceSystemTests.swift
 M Tests/FounderDeskWorkspaceTests.swift
 M Tests/GameStoreTests.swift
 M Tests/GameplayMotionTests.swift
MM UITests/AtlantisRuntimeUITests.swift
 M UITests/Build32_6_1ProductionContinuityUITests.swift
?? .agents/
?? .mcp.json
?? Assets/Atlantis/Phase0/
?? Assets/Atlantis/Phase1/
?? Assets/Atlantis/Phase2/
?? Assets/Atlantis/Phase3/
?? Assets/Atlantis/Phase4/
?? Assets/Atlantis/Phase5/
?? Assets/Atlantis/Phase6/
?? Assets/Atlantis/Phase7/
?? Assets/Atlantis/Phase8/
?? Assets/Atlantis/Phase9/
?? CLAUDE.md
?? Documentation/Atlantis/PHASE15_FOUNDER_ENCOUNTERS_REPORT.md
?? Documentation/Atlantis/PHASE16_WORLD_CONSEQUENCE_LAYER_REPORT.md
?? Documentation/Atlantis/PHASE17_FOUNDER_STRATEGY_BOARD_REPORT.md
?? Documentation/Atlantis/PHASE18_INITIATIVE_OPERATIONS_PRODUCT_LAUNCH_REPORT.md
?? Documentation/Atlantis/PHASE19_AGENT_OPERATIONS_ECONOMY_REPORT.md
?? Documentation/Atlantis/Phase14Evidence/ipad-air-m4-game-performance.trace/
?? Documentation/Atlantis/Phase14Evidence/ipad-air-m4-reactive-final.trace/
?? Documentation/Atlantis/Phase14Evidence/iphone16pro-game-performance.trace/
?? Documentation/Atlantis/Phase14Evidence/iphone16pro-reactive-final.trace/
?? Documentation/Atlantis/Phase14Evidence/ui-screenshots/
?? Documentation/Atlantis/Phase16Evidence/
?? Documentation/Atlantis/Phase17Evidence/
?? Documentation/Atlantis/Phase18Evidence/
?? Solo/
?? skills-lock.json
?? skills/
```
