# SOLO: UNICORN RUN — Atlantis Phase 12

## Production Streaming + Traversal Architecture Report

**Date:** September 12, 2026  
**Branch:** `atlantis-phase0-masterplan`  
**Result:** **GO WITH OPTIMIZATION**

## Executive Result

Phase 12 establishes a bounded, debug-only RealityKit streaming and traversal foundation from Founder Garage to the Player Unicorn HQ parcel. The runtime keeps a `previous + current + next` residency window, prefetches from measured physical-device import times, protects the current and return-path districts, retains independent traversal support, atomically swaps a lightweight Spire proxy, and invalidates semantic entity handles before unload.

The primary 3.947 km progression route completes without a controller rejection or position reset in the automated test. The inherited Tech Core bridge is replaced at runtime by a 13 m-wide switchback with a 5.792% maximum grade. The former bridge meshes remain in the batched Unicorn package for preservation, but are explicitly visual-only and disabled when Unicorn installs.

Physical iPhone 16 Pro evidence supports continuing production work: all four representative transitions completed before boundary arrival, the three-cycle loop ended below its initial memory, and the scene produced 670 Core Animation present requests over 11.15 seconds during a bounded steady-state Metal trace. Transition callback intervals still reached 43.227 ms and human device traversal remains open, so Atlantis should remain debug-only.

## Scope and Ownership

Canonical simulation remains `GameStore → presentation adapter → Atlantis runtime`. Phase 12 does not read or mutate progression, economy, Trust, Momentum, Evidence, rivals, agent systems, entitlements, RNG, or career saves. `GameStore.swift` is unchanged and `GameStore.saveVersion` remains 19.

RealityKit owns only district residency, spatial presentation, grounding/collision presentation, camera hierarchy, day-phase application, semantic entity handles, and debug diagnostics. Atlantis still requires the explicit `--atlantis-realitykit` launch argument.

## Runtime Architecture

### Geography-derived adjacency

Phase 12 derives this symmetric graph from inspection of Phase 0 road and boundary geography, and the exporter records it explicitly:

```text
Founder ↔ Startup
Startup ↔ Commerce, Venture, Tech
Commerce ↔ Venture, Tech, Media
Venture ↔ Tech
Tech ↔ Unicorn
```

The machine-readable graph lives in both runtime and export manifests. Narrative proximity alone is not treated as adjacency.

### Residency policy evaluation

| Policy | Evidence | Memory/residency effect | Transition behavior | Decision |
| --- | --- | --- | --- | --- |
| A: current + next | Physical transition snapshots exercised two loaded districts | 226.345–235.361 MiB in the four forward boundaries | Forward crossing passes; immediate return may require import | Too aggressive for production candidate |
| B: previous + current + next | Physical loop, unit tests, and iPhone/iPad UI state | Up to 3 districts; sampled peak 248.985 MiB | Forward prefetch plus immediate return support | **Selected** |
| C: current + all adjacent | Phase 11B full-city comparison and adjacency cardinality audit | Can retain up to 5 districts; Phase 11B full-city peak 247.173 MiB and 29.248 s background load | Broad continuity, but imports unlikely destinations | Rejected for excess residency/load work |

Policy B is a bounded set. During a transition, the current district and the loaded previous district remain protected while the next district imports. A district becomes eligible for unload only after it leaves that plan. The permanent `TechUnicornBridge` and `PrimaryRouteSupport` contract is independent of district unloads. Debug teardown may explicitly unload everything.

### Prefetch policy

The trigger is calculated as:

```text
prefetchDistance = max(1 second, measuredLoadSeconds) × 1.4 m/s × 1.5 safety factor
```

The coordinator prefers the latest successful device measurement and falls back to the physical Phase 11B times embedded in the manifest. Only the route's next adjacent district is prefetched. A failed prefetch retains the current district and remains retryable. A nonadjacent transition is rejected with a debug status. If a boundary is reached before readiness, the current explicit ground remains resident and movement cannot resolve onto absent ground.

### Semantic anchor lifecycle

District install registers only manifest-declared semantic entities. The loader invokes invalidation before removing a district root. The Commerce `RivalHQ_Slot_05` test confirms that a handle exists while resident and disappears on unload. The registry is rebuilt from the reloaded entity tree, preventing stale actionable references.

### Far landmarks

| Landmark | Far representation | Full asset owner | Swap tested? | Duplicate-safe? |
| --- | --- | --- | --- | --- |
| The Spire | 2,038-byte, 8-sided, 280 m silhouette at `(50, 14, -420)` | Tech Core | Unit + iPhone/iPad UI | Yes, atomic enable/disable |
| Tech.com | None; not justified for this route | Media | Full asset preservation tests | Single owner |
| Pallas AI | None; not justified | Tech Core | Full asset preservation tests | Single owner |
| Northwind | None; not justified | Tech Core | Full asset preservation tests | Single owner |
| Flashpoint | None; not justified | Commerce | Full asset preservation tests | Single owner |

The proxy remains visible while Tech Core is unloaded or importing. The Tech install callback applies lighting first and disables the proxy in the same main-actor install operation. The unload callback restores the proxy before the full Tech root is removed.

## Traversal Architecture

The player hierarchy is:

```text
AtlantisPlayerRoot             translation and grounding
└── BodyHeadingRoot            body yaw
    └── CameraRig              future head look
        └── Camera
```

Presentation locomotion has `standing` and `walking` states. Walking remains 1.4 m/s with bounded debug turning. Camera transforms no longer serve as the locomotion authority.

Ground queries accept only surfaces explicitly classified `walkable` or `collisionOnly`. Visual-only upward geometry, including Central Peninsula terrain and the inherited bridge, cannot become ground. Overlapping Phase 12 traversal support wins ownership, and height selection tracks the closest valid surface to the player's current height instead of choosing the highest upward triangle.

The final manifest contains 87 walkable surfaces, 28 collision-only primary-route segments, and 19 visual-only surfaces. Rendering stays batched. The 3 m-wide `PrimaryRouteSupport` triangles provide simplified collision/grounding coverage along the validation route without restoring per-building render meshes.

The canonical route contains 29 control points and measures 3,946.937 m:

```text
FounderGarageSlot → driveway → Founder sidewalks/connectors → Startup core
→ Commerce/Flashpoint corridor → Tech approach/core → repaired bridge
→ Unicorn approach → PlayerUnicornHQSlot
```

| Segment | Automated | Human | Grounding | Collision | Result |
| --- | --- | --- | --- | --- | --- |
| Garage → Founder | Pass | Open | Explicit | Primary route support | Automated pass |
| Founder → Startup | Pass | Open | Explicit | Primary route support | Automated pass |
| Startup core | Pass | Open | Explicit | Primary route support | Automated pass |
| Startup → Commerce | Pass | Open | Explicit | Primary route support | Automated pass |
| Commerce → Tech | Pass | Open | Explicit | Primary route support | Automated pass |
| Tech → Unicorn | Pass | Open | Explicit repaired bridge | Bridge + route support | Automated pass |
| Unicorn → Player HQ | Pass | Open | Explicit | Primary route support | Automated pass |

The controller test drives the same `move()` path used by the UI at fixed 0.1-second simulation steps, without resetting position between segments. It is accelerated automated evidence, not a substitute for a person walking the route on hardware.

## Tech Core Bridge Repair

The Phase 9 masterplan remains read-only. The derivative source and audit live under `Assets/Atlantis/Phase12/TraversalRepair/`; the runtime package is `tech_unicorn_bridge_repaired.usdz`.

The repair preserves the 71 m rise and endpoints, routes the climb through five long switchback legs, adds continuous entry/exit landings, and uses a 13 m ribbon. The exporter is deterministic: it normalizes USD source timestamps, and two consecutive builds produced identical USDZ SHA-256 values.

| Metric | Phase 10 | Phase 12 |
| --- | ---: | ---: |
| Grade | 18.861% | **5.792% maximum** |
| Rise | ~71 m | 71 m |
| Discontinuities | 3 | 0 on automated route |
| Max mismatch | 12.687 m | 0 m at controller endpoint |
| Entry rejection | Yes | No in automated controller |
| Walkable | No | **Yes, comfortable classification** |

The grade is below the Phase 12 8% locomotion threshold. Final accessibility design should still assess landings, turning radii, route length, and an eventual elevator/transit alternative.

## Physical iPhone Streaming Evidence

Device: unlocked iPhone 16 Pro, model `iPhone17,1`, A18 Pro, iOS 26.7. Configuration: Debug batched assets. Scene update callback intervals are reported as hitches, not FPS.

| Transition | Prefetch start | Ready before boundary? | Hitch | Memory delta | Result |
| --- | ---: | --- | ---: | ---: | --- |
| Founder → Startup | 11.281 m | Yes | 30.873 ms | +1.375 MiB | Pass |
| Startup → Commerce | 15.864 m | Yes | 32.520 ms | +6.281 MiB | Pass |
| Commerce → Tech Core | 7.776 m | Yes | 43.227 ms | −9.016 MiB | Pass with hitch optimization |
| Tech Core → Unicorn | 14.428 m | Yes | 32.994 ms | +1.984 MiB | Pass with hitch optimization |

| State | Resident districts | Memory | Player district | Notes |
| --- | --- | ---: | --- | --- |
| Founder start | Founder; Startup prefetch follows | 223.532 MiB | Founder | Founder package installed in 1.252 s |
| Founder + Startup | Founder, Startup | 229.079 MiB | Startup | Ready before boundary |
| Startup + Commerce | Startup, Commerce | 235.361 MiB | Commerce | Largest positive boundary delta |
| Commerce + Tech | Commerce, Tech Core | 226.345 MiB | Tech Core | Largest callback interval: 43.227 ms |
| Tech + Unicorn | Tech Core, Unicorn Heights | 228.329 MiB | Unicorn Heights | Repaired bridge support remains resident |
| after unload cycle | Founder, Startup | 229.548 MiB | Founder | End of cycle 3; 5 stable scene roots |

Three `Founder → Startup → Commerce → Startup → Founder` cycles completed with two district residents and five total runtime roots at every end point:

| Cycle | Before | After | Wall time |
| ---: | ---: | ---: | ---: |
| 1 | 235.111 MiB | 230.798 MiB | 9.143 s |
| 2 | 230.798 MiB | 229.829 MiB | 9.151 s |
| 3 | 229.829 MiB | 229.548 MiB | 9.135 s |

No memory growth, duplicate-root growth, load-time degradation, stale-anchor failure, or Spire swap failure was recorded. Re-entry imports stayed stable: Commerce was 7.543–7.577 s and Founder was 1.227–1.228 s after the initial pass.

### Performance summary

- Founder playable and visible: 2.224 s, including context, Founder, and small support-package startup work.
- Founder installed memory: 223.532 MiB.
- Sampled streaming peak: 248.985 MiB.
- Sustained loop end: 229.548 MiB, 5.563 MiB below loop start.
- Maximum load-period `SceneEvents.Update` interval: 43.227 ms.
- Maximum transition/unload wall interval: 2.907 ms.
- All four adjacent districts were ready before the synthetic boundary crossing.

### Metal trace

A physical 11.15-second post-stream steady-state trace contains 670 Core Animation present requests, or 60.087 requests/s. Present-request interval p95 was 18.028 ms and maximum was 23.086 ms. The target process recorded 597 Metal driver intervals totaling 210.975 ms; interval p95 was 0.481 ms and maximum 0.595 ms. The trace exported 4,351 CPU time samples, but the export classified 4,349 as `Unknown`, so it does not support a defensible CPU utilization percentage.

This capture proves physical Metal activity and presentation cadence for a bounded steady state. It does not expose GPU-utilization percentage or a thermal-sensor value, and it was captured after the streaming loop rather than across a district import. No thermal warning or runtime error appeared. A transition-spanning GPU/thermal capture remains acceptance work.

## Simulator and Visual Evidence

Simulator results are kept separate from hardware evidence. The earlier Phase 12 simulator streaming profile completed every boundary and three cycles with no errors; its 25 m prefetch field predates the final hardware-derived trigger and is retained as historical diagnostic evidence only.

The current UI suite retained ten iPhone 17 Pro Max screenshots and one iPad Air 11-inch M4 screenshot. Inspection found the intended districts and landmarks present in the six benchmark cameras, a stable Spire silhouette at Founder distance, the full Spire in Tech, consistent evening lighting on late-loaded Tech, and no obvious duplicate Spire. The debug HUD fits on both devices, although the long district-state line horizontally clips on iPhone; this is a P2 debug-tool issue. The streamed Tech screenshot intentionally keeps the Founder camera and therefore is state/swap evidence, not a close visual comparison of proxy versus full geometry.

Human review on a physical device remains open for batch seams, aliasing, bridge appearance, proxy pop, movement feel, clipping, camera stability, VoiceOver, Dynamic Type, and Reduce Motion. A physical iPad was unavailable.

## Verification

| Check | Result |
| --- | --- |
| Atlantis focused tests | 26/26 passed before final package normalization; final support/bridge tests 2/2 passed against normalized packages |
| Full unit suite, exact final package state | **810/810 passed**, 0 failures |
| Garage + Founder workspace focused regression | **163/163 passed**, 0 failures |
| Atlantis UI, iPhone 17 Pro Max simulator | **3/3 passed**, 10 retained captures |
| Streamed evening UI, iPad Air 11-inch M4 simulator | **1/1 passed**, 1 retained capture |
| iPhone Debug build | Passed |
| iPad Air 11-inch M4 Debug build | Passed |
| Physical iPhone 16 Pro Debug build/run | Passed; streaming profile has no errors |
| Release iPhone simulator build | Passed after final deterministic assets |
| `git diff --check` | Passed |
| Save compatibility | `GameStore.saveVersion == 19`; full migration tests passed |

The shared scheme already had unrelated formatting changes in the dirty worktree before Phase 12 and was not edited in this phase. The project-file change is limited to adding the repaired bridge and Spire proxy USDZ resources. No large reconciliation or project regeneration was run.

## Evidence and Reproduction

- Runtime/export generator: `Assets/Atlantis/Phase12/TraversalRepair/build_streaming_assets.py`
- Traversal/streaming audit: `Assets/Atlantis/Phase12/TraversalRepair/streaming_manifest.json`
- Bridge source: `Assets/Atlantis/Phase12/TraversalRepair/tech_unicorn_bridge_repaired.usda`
- Spire proxy source: `Assets/Atlantis/Phase12/TraversalRepair/spire_far_proxy.usda`
- Physical streaming profile: `Documentation/Atlantis/Phase12-iphone16pro-streaming-profile.json`
- Physical Metal trace: `Documentation/Atlantis/Phase12-iPhone16Pro-Metal.trace`
- Metal summary: `Documentation/Atlantis/Phase12-iPhone16Pro-Metal-summary.json`
- Trace summarizer: `Assets/Atlantis/Phase12/summarize_metal_trace.py`
- Simulator profile: `Documentation/Atlantis/Phase12-simulator-streaming-profile.json`
- Screenshot manifests: `Assets/Atlantis/Phase12/VisualReview/*/manifest.json`

### Phase 12 file inventory

Modified:

- `App/AtlantisDistrictLoader.swift`
- `App/AtlantisRealityScene.swift`
- `App/AtlantisRealityView.swift`
- `App/AtlantisWorldPresentationModel.swift`
- `App/RealityKit/Atlantis/atlantis_manifest.json`
- `App/RealityKit/Atlantis/unicorn_heights_batched.usdc`
- `App/RealityKit/Atlantis/unicorn_heights_batched.usdz`
- `Assets/Atlantis/Phase10/RuntimeSpike/export_manifest.json`
- `Assets/Atlantis/Phase11B/build_selective_district_batch.py`
- `Assets/Atlantis/Phase11B/unicorn_batch_manifest.json`
- `SoloUnicornRun.xcodeproj/project.pbxproj` (two precise resource additions)
- `Tests/AtlantisRuntimeTests.swift`
- `UITests/AtlantisRuntimeUITests.swift`

Created:

- `App/RealityKit/Atlantis/tech_unicorn_bridge_repaired.usdc`
- `App/RealityKit/Atlantis/tech_unicorn_bridge_repaired.usdz`
- `App/RealityKit/Atlantis/spire_far_proxy.usdc`
- `App/RealityKit/Atlantis/spire_far_proxy.usdz`
- `Assets/Atlantis/Phase12/TraversalRepair/build_streaming_assets.py`
- `Assets/Atlantis/Phase12/TraversalRepair/tech_unicorn_bridge_repaired.usda`
- `Assets/Atlantis/Phase12/TraversalRepair/spire_far_proxy.usda`
- `Assets/Atlantis/Phase12/TraversalRepair/streaming_manifest.json`
- `Assets/Atlantis/Phase12/summarize_metal_trace.py`
- `Assets/Atlantis/Phase12/VisualReview/iPhone17ProMax/` (10 retained PNGs and `manifest.json`)
- `Assets/Atlantis/Phase12/VisualReview/iPadAir11M4/` (one retained PNG and `manifest.json`)
- `Documentation/Atlantis/PHASE12_PRODUCTION_STREAMING_TRAVERSAL_REPORT.md`
- `Documentation/Atlantis/Phase12-iphone16pro-streaming-profile.json`
- `Documentation/Atlantis/Phase12-simulator-streaming-profile.json`
- `Documentation/Atlantis/Phase12-iPhone16Pro-Metal.trace/`
- `Documentation/Atlantis/Phase12-iPhone16Pro-Metal-summary.json`
- `Documentation/Atlantis/Phase12-iPhone16Pro-ca-client-present-request.xml`
- `Documentation/Atlantis/Phase12-iPhone16Pro-displayed-surfaces.xml`
- `Documentation/Atlantis/Phase12-iPhone16Pro-metal-driver.xml`
- `Documentation/Atlantis/Phase12-iPhone16Pro-metal-gpu-execution-points.xml`
- `Documentation/Atlantis/Phase12-iPhone16Pro-time-sample.xml`

## Remaining Risks

### P0

None found in automated or physical benchmark evidence.

### P1

- Human physical-device traversal of the entire route is still open. Automated controller success cannot validate movement feel, camera stability, clipping, or perceived scale.
- Load-period callback intervals reach 30.873–43.227 ms on iPhone 16 Pro. Prefetch hides import time before normal arrival, but transition-spanning Instruments work should identify remaining main-thread scheduling cost.
- Physical iPad acceptance is open because no physical iPad was available.

### P2

- Physical visual comparison of the Spire proxy/full swap and repaired bridge is open; simulator captures show stable ownership but do not measure perceptual pop.
- GPU utilization percentage, CPU utilization percentage, and thermal state were unavailable from the exported physical trace.
- The iPhone debug HUD's long district-state line clips horizontally. It does not affect production UI because Atlantis remains debug-only.
- Accessibility review of debug traversal controls remains a human acceptance step.

## Final Required Answers

**Can the player move across multiple Atlantis districts without requiring the entire city to remain resident?**  
Yes in automated controller and physical streaming benchmarks. The physical forward run held two loaded districts at each measured boundary, while the selected policy permits at most previous/current/next.

**Does district prefetch complete before normal boundary arrival?**  
Yes for all four measured iPhone 16 Pro transitions. Trigger distances are derived from measured import time, 1.4 m/s walking speed, and a 1.5 safety factor.

**Can old districts unload without removing player support or corrupting scene state?**  
Yes in unit, UI, and three-cycle physical evidence. Current/return-path districts are protected, permanent route support stays resident, roots remain stable, and semantic handles invalidate before removal.

**Does memory remain bounded over repeated traversal cycles?**  
Yes over the bounded three-cycle run: 235.111 MiB before cycle 1 and 229.548 MiB after cycle 3, with a 248.985 MiB sampled peak.

**Does The Spire remain a stable skyline anchor while Tech Core is unloaded?**  
Yes in unit and simulator visual evidence. Its proxy uses the exact anchor position and 280 m scale, remains through prefetch, and swaps atomically with the full asset.

**Can streamed districts immediately adopt the current sprint day phase?**  
Yes. Late-loaded districts passed evening and night assertions; the iPhone and iPad UI run also showed late-loaded Tech in evening.

**Is the Tech Core → Unicorn route now walkable?**  
Yes in the automated controller. Maximum grade is 5.792%, entry rejection is gone, and the route has no automated surface discontinuity. Human acceptance is open.

**Can the complete Founder Garage → Player Unicorn HQ progression route be traversed continuously?**  
Yes by the same locomotion controller used by the debug UI, across all 29 route points without a reset or rejected step. No exact automated blocker remains; manual traversal is open.

**Does hardware evidence support continued production development?**  
Yes, with optimization. Readiness, bounded memory, stable roots, Metal cadence, and clean failures support continued work; transition hitches and physical acceptance remain.

**Did all work leave canonical SOLO simulation and Garage runtime intact?**  
Yes. `GameStore` is unchanged, save version remains 19, the 810-test suite and 163 focused Garage/workspace tests pass, and Atlantis remains opt-in debug presentation.

## Phase 13 Recommendation

Proceed to **Phase 13 — Atlantis World Interaction Layer**, while carrying a bounded performance/acceptance lane for transition-spanning Instruments capture, physical route walkthrough, physical iPad, and Spire/bridge visual review. Phase 13 should connect manifest-backed interaction anchors for Tech.com, Signal TV, Venture Hall, rival HQ exteriors, and the Player HQ parcel without moving simulation authority into RealityKit.
