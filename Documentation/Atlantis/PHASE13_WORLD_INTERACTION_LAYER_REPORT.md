# SOLO: UNICORN RUN — Atlantis Phase 13 World Interaction Layer

## Executive Result

**GO WITH OPTIMIZATION**

Atlantis now has a bounded, presentation-only interaction layer that routes eight resident world anchors into existing SOLO destinations. The system keeps one deterministic candidate, stores return context only for the current session, freezes district streaming while a destination is presented, and restores the exact player transform, day phase, residency, and existing world root on return.

No new simulation authority, rival state, unlock state, interior, NPC, traffic, shop, elevator, or persistent navigation state was added. Atlantis remains behind the Debug-only `--atlantis-realitykit` opt-in. `GameStore` was not changed by Phase 13 and `GameStore.saveVersion` remains **19**.

The remaining optimization work is human prompt-distance/discoverability tuning, manual VoiceOver and largest Dynamic Type acceptance, and transition-spanning GPU/thermal profiling. These are acceptance and polish items; the architecture and measured interaction path are healthy.

## Architecture

The interaction flow is:

```text
resident semantic RealityKit entity
→ AtlantisInteractionTarget
→ AtlantisInteractionRegistry
→ one deterministic AtlantisInteractionIntent
→ existing canonical SOLO destination
→ session-only AtlantisInteractionReturnContext
→ exact Atlantis position/heading/phase/residency restore
```

`AtlantisInteractionDefinition` owns a stable ID, district, semantic anchor name, intent, activation position/radius, optional facing threshold, priority, accessibility label, and availability. It contains no simulation state.

`AtlantisInteractionRegistry` is district-scoped. District install registers targets by semantic anchor; unload removes the district's targets and clears its active prompt. Target entities are held weakly, so an unloaded RealityKit entity cannot be retained or activated. Registration replaces a district's prior entries before rebuilding them, preventing duplicate IDs on reload.

Candidate selection scans only the small resident registry, not the scene graph. It rejects missing entities, nonresident districts, unavailable targets, out-of-radius targets, and targets outside an optional facing threshold. It then orders by priority descending, distance ascending, and stable ID ascending. The active candidate refreshes after movement/camera changes and every 30 scene updates.

`AtlantisRealityView` bridges intents with the existing SwiftUI presentation path. While a canonical destination is open, locomotion stops and streaming is frozen. Dismissal verifies that the supporting district and ground remain valid, then restores the captured transform and phase without rebuilding the RealityKit root. Route failure clears the session state and leaves Atlantis usable.

## Canonical Integration

The following production implementations are reused directly:

- `FounderDeskWorkspace` for the Founder Garage and Founder Computer flow.
- `TechComScreen` for Tech.com and public rival inspection.
- `VentureScreen` for Venture Hall.
- `SignalTVViewer` with `SignalTVProgramming.ambientEvents` for Signal TV.
- `HeadquartersProgressScreen` for the reserved Player HQ parcel.

Rival intents use the existing `ContentLibrary.rivalCompanies` IDs: `pallas`, `northwind`, and `flashpoint`. Unknown IDs fail closed. Rival routes show `TechComScreen`, which uses canonical public/visible presentation; Atlantis does not read or render hidden quality, verification, drift, deception, or other unrevealed truth. Evidence Ledger and Founder review rules are unchanged.

## Interaction Inventory

Only these eight locations are interactive in Phase 13:

| Target | District | Intent | Routes to canonical system? | Round trip? | Streaming-safe? |
| --- | --- | --- | --- | --- | --- |
| Founder Garage | Founder | Enter Founder Garage | Yes — `FounderDeskWorkspace` | Yes | Yes |
| Tech.com | Media | Open Tech.com | Yes — `TechComScreen` | Yes | Yes |
| Venture Hall | Venture | Open Venture | Yes — `VentureScreen` | Yes | Yes |
| Signal TV | Media | Inspect Signal TV | Yes — `SignalTVViewer` | Yes | Yes |
| Pallas AI | Tech Core | Inspect rival `pallas` | Yes — canonical public Tech.com surface | Yes | Yes |
| Northwind Labs | Tech Core | Inspect rival `northwind` | Yes — canonical public Tech.com surface | Yes | Yes |
| Flashpoint | Commerce | Inspect rival `flashpoint` | Yes — canonical public Tech.com surface | Yes | Yes |
| Player HQ | Unicorn Heights | Inspect future HQ | Yes — `HeadquartersProgressScreen` | Yes | Yes |

The Player HQ route reads current canonical progression. It does not add a final HQ model or new progression state.

## Garage ↔ Atlantis Contract

The Founder District `FounderGarageSlot` enables **Enter Founder Garage** within a 12 m radius and requires a forgiving 0.35 facing dot. Activation presents the existing `FounderDeskWorkspace`; it does not create a second Garage scene. The UI regression enters the Garage, focuses the existing Founder Computer through `founder-desk-device-computer`, uses the existing `founder-computer-look-out` action to return to the Garage, and then returns to Atlantis.

The Atlantis session retains the world instance throughout this flow. Return restores the transition-seam position, heading, day phase, and resident districts. Founder POV, camera/free-look, Garage Door, device navigation, progression, and save ownership remain in their existing implementations.

## Interaction Rules

- Founder Garage: 12 m radius, 0.35 minimum facing dot, direct-use priority 300.
- Venture Hall: 4 m radius, building priority 250.
- Tech.com and Signal TV: 4 m radius, building/media priority 200.
- Pallas AI and Northwind Labs: 6 m inspection radius, landmark priority 100.
- Flashpoint: 5 m inspection radius, landmark priority 100.
- Player HQ: 8 m inspection radius, landmark priority 100.

The system shows one explicit button prompt. Walking away removes the candidate; merely entering a radius never opens a destination. Two small collision-only approach pads were added for Pallas and Northwind because their semantic entrances did not have reliable walkable support. Surface metadata is now **87 walkable, 30 collision-only, and 19 visual-only** records.

## Accessibility Matrix

| Interaction | Label | Identifier | 44 pt control? | VoiceOver tested? |
| --- | --- | --- | --- | --- |
| Founder Garage | Enter Founder Garage | `atlantis.interaction.founderGarage` | Yes | Semantics/XCUI verified; manual VO pending |
| Tech.com | Open Tech.com | `atlantis.interaction.techCom` | Yes | Semantics/XCUI verified; manual VO pending |
| Venture Hall | Enter Venture Hall | `atlantis.interaction.ventureHall` | Yes | Semantics/XCUI verified; manual VO pending |
| Signal TV | Inspect Signal TV | `atlantis.interaction.signalTV` | Yes | Semantics/XCUI verified; manual VO pending |
| Pallas AI | Inspect Pallas AI | `atlantis.interaction.pallasAI` | Yes | Semantics/XCUI verified; manual VO pending |
| Northwind Labs | Inspect Northwind Labs | `atlantis.interaction.northwindLabs` | Yes | Semantics/XCUI verified; manual VO pending |
| Flashpoint | Inspect Flashpoint | `atlantis.interaction.flashpoint` | Yes | Semantics/XCUI verified; manual VO pending |
| Player HQ | Inspect Future Unicorn HQ | `atlantis.interaction.playerHQ` | Yes | Semantics/XCUI verified; manual VO pending |

The shared prompt uses a minimum 44 × 44 pt button frame, a semantic label, the button trait, and disabled state when no valid resident candidate exists. No animated prompt or camera fly-in was added, so Reduce Motion does not need a separate interaction path.

## Round-Trip Results

| Route | Position restored? | Heading restored? | Day phase preserved? | Duplicate world roots? | Result |
| --- | --- | --- | --- | --- | --- |
| Atlantis → Garage → Founder Computer → Garage → Atlantis | Yes, exact | Yes, exact | Yes | No | Pass |
| Atlantis → Tech.com → Atlantis | Yes, exact | Yes, exact | Yes | No | Pass |
| Atlantis → Venture → Atlantis | Yes, exact | Yes, exact | Yes | No | Pass |

Signal TV, Pallas, Northwind, Flashpoint, and Player HQ also passed the same UI round-trip helper. The runtime test changes the world to night before presentation and verifies the same night phase after return.

## Streaming and Stale-Reference Safety

The required sequence Founder → Startup → Commerce → Flashpoint inspection → return → Tech Core passes without changing canonical `GameStore` stats or RNG state. Streaming freezes while a routed screen is visible and resumes after the exact return context is restored.

The stale-reference regression loads Tech Core, registers Pallas, approaches it, unloads Tech Core, verifies that the prompt and target disappear and activation fails, then reloads Tech Core and verifies exactly two Tech Core interactions with no duplicate IDs. The registry also requires the semantic entity to be fully installed, so a prefetching district cannot expose a prompt.

## Runtime Metrics

The `--atlantis-interaction-profile` run performed Tech.com open/return ×5, Venture open/return ×5, and Garage open/return ×3. These measurements cover the world intent handoff and return contract; XCUITest separately proves the real canonical screens present and dismiss.

| Device | OS | Cycles | Candidate evaluations | Mean candidate cost | Mean intent dispatch | Mean return | First memory → final memory | Sampled peak | Invariants |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| iPhone 16 Pro | iOS 26.7 | 13 | 53 | 13.206 µs | 0.034 ms | 1.020 ms | 228.642 → 232.673 MiB | 235.798 MiB | 13/13 pass |
| iPad Air 11-inch (M4) | iPadOS 26.6.2 | 13 | 52 | 10.512 µs | 0.030 ms | 0.772 ms | 260.110 → 263.767 MiB | 269.939 MiB | 13/13 pass |

The end-to-end memory rise includes retaining the newly loaded Media and Venture districts for the bounded profile. Individual before/after cycle samples were stable: mean iPhone before and after memory were both 230.734 MiB; iPad changed by 0.001 MiB on average. There were no errors, stale candidates, lost transforms, residency changes, or duplicate roots. The measured candidate and return costs are negligible relative to a frame budget.

Evidence:

- `Phase13Evidence/iphone16pro-interaction-profile.json`
- `Phase13Evidence/ipad-air-m4-interaction-profile.json`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_Garage.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_TechCom.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_Venture.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_SignalTV.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_Pallas.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_Northwind.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_Flashpoint.png`
- `Phase13Evidence/ui-screenshots/Atlantis_Phase13_PlayerHQ.png`

## Verification

| Check | Result |
| --- | --- |
| Atlantis runtime tests | **31/31 passed** |
| Full unit suite | **815/815 passed** |
| Founder Garage + workspace focused regression | **163/163 passed** |
| Complete Atlantis iPhone UI suite | **4/4 passed** |
| Final eight-target interaction UI flow | **1/1 passed** on iPhone; includes Garage/Computer and all three rivals |
| iPad interaction UI flow | **1/1 passed** |
| iPhone Debug build | Pass |
| iPad Simulator Debug build | Pass |
| Physical iPhone 16 Pro Debug build/install/profile | Pass |
| Physical iPad Air 11-inch (M4) Debug build/install/profile | Pass |
| Release build, iPhone Simulator | Pass |
| Asset regeneration determinism | Pass; manifests and support USDZ SHA-256 values unchanged on repeat generation |
| `git diff --check` | Pass |

The Xcode `DebuggerVersionStore` emitted a nonfatal “no debugger version” diagnostic during UI launches; all affected UI tests completed successfully. The first physical iPad attempt could not mount its developer disk image while the device was only available/paired. After cable connection and unlock, the physical build, install, launch, and profile all passed.

Automated screenshot inspection found all canonical screens readable and the return control consistently discoverable. The large top-right return button can crowd an existing centered title on compact iPhone layouts; this is a P2 presentation polish item. Manual physical interaction review, manual VoiceOver, largest Dynamic Type, accidental-activation tuning, and GPU/thermal capture remain open and must not be inferred from test or screenshot evidence.

## Open Risks

- **P0:** None found. Canonical routing, hidden-truth boundaries, and simulation isolation passed inspection and regression.
- **P1:** None found in automated or physical profile evidence. Exact transform and streaming restoration passed every measured cycle.
- **P2:** Tune real-world prompt radii/facing with human walking; verify VoiceOver order and largest Dynamic Type; reduce compact-header crowding from the return control; complete transition-spanning GPU/thermal profiling.
- **P2:** The debug profiler measures intent dispatch and return infrastructure, while perceived canonical-screen transition latency still depends on each destination's SwiftUI rendering and should be sampled with Instruments before production promotion.

## Final Required Answers

**Can world-space Atlantis entities route cleanly into existing SOLO systems?** Yes. All eight stable targets route through canonical destinations and passed the final UI flow.

**Does the player return to the correct world position after leaving a canonical screen?** Yes. Position and heading restore exactly after ground/residency validation.

**Do interactions survive district streaming without stale or duplicate targets?** Yes. Unload invalidates weak targets and the active prompt; reload registers each stable ID once.

**Does Garage ↔ Atlantis work as a coherent round trip?** Yes. The tested flow includes the canonical Garage, Founder Computer, LOOK OUT return, and Atlantis return seam.

**Do Tech.com and Venture reuse their canonical production systems?** Yes. They present `TechComScreen` and `VentureScreen` directly.

**Do rival interactions preserve hidden-truth boundaries?** Yes. They use canonical rival IDs and the existing public Tech.com presentation; Atlantis adds no hidden-state projection.

**Does current day phase survive interaction round trips?** Yes. Unit tests and 26 physical-device cycles preserve the captured phase.

**Does interaction infrastructure add negligible runtime cost?** Yes in the measured CPU path: 10.512–13.206 µs mean candidate evaluation and 0.772–1.020 ms mean return work. GPU/thermal profiling remains an acceptance item.

**Did Phase 13 leave canonical simulation ownership intact?** Yes. `GameStore`, pure engines, finance, Coverage, progression, entitlements, Evidence, and save ownership remain canonical; save version is 19.

**Is Atlantis ready for a bounded living-world/NPC performance pass?** Yes, with a strict Phase 14 performance budget and small population prototype. Crowds, vehicles, and animation scale should remain gated on measured CPU, GPU, memory, and thermal evidence.

## Phase 14 Recommendation

Proceed to **Phase 14 — Atlantis Living World Layer** as a bounded performance experiment. Define budgets before adding content: cap simultaneously animated agents, update frequency, active animation controllers, draw-call/material additions, memory growth, and thermal duration. Begin with one district and one lightweight pedestrian cohort, measure on iPhone 16 Pro and iPad Air M4, and expand only if the previous/current/next residency envelope remains healthy.

## Phase 13 Files

Phase 13 modified:

- `App/AtlantisWorldPresentationModel.swift`
- `App/AtlantisRealityScene.swift`
- `App/AtlantisRealityView.swift`
- `App/RealityKit/Atlantis/atlantis_manifest.json`
- `Assets/Atlantis/Phase10/RuntimeSpike/export_manifest.json`
- `Assets/Atlantis/Phase12/TraversalRepair/build_streaming_assets.py`
- `Assets/Atlantis/Phase12/TraversalRepair/streaming_manifest.json`
- `Tests/AtlantisRuntimeTests.swift`
- `UITests/AtlantisRuntimeUITests.swift`

Phase 13 added this report, two physical-device JSON profiles, and eight named UI screenshots under `Documentation/Atlantis/Phase13Evidence/`. It did not modify `project.pbxproj`, the shared scheme, `GameStore.swift`, or any save schema. Other pre-existing worktree changes remain untouched.
