# Atlantis Phase 11B — District Batching + Hardware Validation

## Executive Result

**GO WITH OPTIMIZATION.** Physical iPhone 16 Pro evidence confirms that independent mesh-entity count is the dominant Atlantis import bottleneck and that district-specific static batching is the correct runtime export strategy.

On the same iPhone 16 Pro, Founder import fell from a **40.040 s median to 0.783 s**, a **51.1× speedup** and **39.256 s absolute saving**. Founder became playable in **0.868 s median**, down from **40.163 s**. The final seven-district batched benchmark reduced summed background loading from **112.327 s to 29.248 s** and sampled peak resident memory from **293.861 MiB to 247.173 MiB**.

The optimization preserves every district's triangle and material totals, named landmarks, required semantic roots, traversal anchors, Y-up/meter convention, and world bounds within a maximum floating-point drift of 0.000031 m. Atlantis remains debug-only. `GameStore`, simulation rules, RNG ordering, save version 19, canonical Garage runtime, Phase 0–9 Blender milestones, bridge geometry, and locomotion scope were not changed.

## Founder Hardware Validation

The A/B comparison used the same unlocked iPhone 16 Pro (`iPhone17,1`), iOS 26.7, Debug configuration, benchmark bundle identifier, runtime route, validation, and instrumentation. Each variant ran three times with explicit launch selection:

```text
--atlantis-realitykit --atlantis-founder-profile --atlantis-baseline-assets
--atlantis-realitykit --atlantis-founder-profile --atlantis-batched-assets
```

| Metric | Baseline Founder | Batched Founder |
| --- | ---: | ---: |
| Package size | 362,055 bytes | 1,566,454 bytes |
| Mesh entities | 464 | 15 |
| Triangles | 46,032 | 46,032 |
| Materials | 15 | 15 |
| Import, min / median / max | 40.026 / 40.040 / 40.120 s | 0.750 / 0.783 / 1.098 s |
| Validation, min / median / max | 0.121 / 0.131 / 0.149 ms | 0.095 / 0.103 / 0.156 ms |
| Scene install, min / median / max | 5.293 / 5.465 / 5.748 ms | 1.363 / 1.411 / 1.464 ms |
| Total load, min / median / max | 40.045 / 40.047 / 40.134 s | 0.753 / 0.786 / 1.103 s |
| Sampled peak memory, min / median / max | 275.485 / 276.001 / 278.220 MiB | 252.282 / 254.345 / 255.470 MiB |
| First SceneEvents.Update, min / median / max | 0.154 / 0.157 / 0.398 s | 0.150 / 0.152 / 0.160 s |
| Founder visible, median | 40.163 s | 0.868 s |
| Founder playable, min / median / max | 40.108 / 40.163 / 40.570 s | 0.837 / 0.868 / 1.220 s |

The first SceneEvents.Update callback is a startup responsiveness marker. It is not a presented GPU frame and is not reported as FPS. Memory-before values varied materially among cold launches, so the Founder-only memory result is limited to the sampled peaks and does not establish a standalone residency delta.

The promotion gate passed on both percentage and user impact: median import was reduced by **98.04%**, total load by **39.261 s**, and time to playable by **39.295 s**, without a geometry, semantics, memory-peak, or stability failure.

## District Batching

The exporter batches static render meshes by district and compatible material while retaining lightweight semantic structure. It does not simplify geometry or consolidate materials.

| District | Batchable geometry | Preserved separately |
| --- | --- | --- |
| Founder | All static render geometry grouped by material | `FounderGarageSlot` anchor |
| Startup | Building architecture and public background | Progression corridor, route/cross-street meshes, building identities, signage |
| Commerce | Supporting architecture, props, and static route surfaces | Flashpoint hierarchy, all top-level anchors, signs, labels, occupied surfaces |
| Tech Core | Supporting blocks, podiums, plaza, and static roads | The Spire, Pallas AI HQ, Northwind Labs HQ, all top-level anchors |
| Unicorn | Campus architecture, repeated landscaping, static public geometry | Player HQ slot, all top-level anchors, campus identity and occupied surfaces |
| Venture | Supporting blocks, landscape, and public geometry | Venture Hall and all top-level anchors |
| Media | Supporting blocks, landscape, waterfront, and route geometry | Tech.com, Signal TV, and all top-level anchors |

The light Venture and Media packages use minimal eight-batch layouts. Tech Core remains conservative with three generic-support batches and intact hero landmark subtrees. Startup, Commerce, and Unicorn use finer selective groups because their route, signage, occupied-surface, and campus contracts require more runtime identity.

### Entity and geometry results

| District | Baseline meshes | Batched meshes | Reduction | Triangles | Materials | Preserved? |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Founder | 464 | 15 | 96.8% | 46,032 | 15 | Yes |
| Startup | 150 | 56 | 62.7% | 32,056 | 14 | Yes |
| Commerce | 217 | 54 | 75.1% | 35,659 | 21 | Yes |
| Tech Core | 78 | 31 | 60.3% | 2,852 | 22 | Yes |
| Unicorn | 271 | 28 | 89.7% | 10,212 | 12 | Yes |
| Venture | 49 | 12 | 75.5% | 1,824 | 9 | Yes |
| Media | 63 | 23 | 63.5% | 1,620 | 15 | Yes |

### Physical import results

Founder and Startup values are medians from three runs per variant. Later districts use the Phase 10 baseline and one sequential Phase 11B candidate/final run because the gate was applied district by district.

| District | Baseline import | Batched import | Speedup | Saved |
| --- | ---: | ---: | ---: | ---: |
| Founder | 40.040 s | 0.783 s | 51.11× | 39.256 s |
| Startup | 13.503 s | 5.030 s | 2.68× | 8.473 s |
| Commerce | 18.723 s | 7.541 s | 2.48× | 11.183 s |
| Tech Core | 6.871 s | 3.703 s | 1.86× | 3.167 s |
| Unicorn | 23.158 s | 6.789 s | 3.41× | 16.368 s |
| Venture | 4.335 s | 1.834 s | 2.36× | 2.501 s |
| Media | 5.484 s | 2.799 s | 1.96× | 2.685 s |

All districts materially improve in absolute or cumulative startup terms. Founder, Startup, Commerce, and Unicorn produce the largest product impact. Tech Core should retain its conservative landmark structure. Venture and Media benefit enough to keep their minimal batching, while their landmark hierarchies remain granular.

### Package size

| District | Baseline bytes | Batched bytes | Delta |
| --- | ---: | ---: | ---: |
| Founder | 362,055 | 1,566,454 | +1,204,399 (+332.7%) |
| Startup | 252,021 | 270,828 | +18,807 (+7.5%) |
| Commerce | 266,685 | 324,135 | +57,450 (+21.5%) |
| Tech Core | 39,572 | 40,336 | +764 (+1.9%) |
| Unicorn | 114,020 | 129,232 | +15,212 (+13.3%) |
| Venture | 26,801 | 27,554 | +753 (+2.8%) |
| Media | 28,551 | 28,921 | +370 (+1.3%) |

Compressed size increases, especially for the aggressive Founder batch. The hardware saving shows that fewer RealityKit entities outweigh the package-size cost for this workload. Package size remains a distribution tradeoff to track in production packaging.

## Progressive Boot

The measured production-style sequence is WorldContext → batched Founder → Founder playable → batched Startup prefetch → remaining districts in later stages. It does not block play on the full city.

Startup's three-run comparison was:

| Metric | Baseline Startup path | Batched Startup path |
| --- | ---: | ---: |
| Startup import, min / median / max | 13.499 / 13.503 / 13.505 s | 4.879 / 5.030 / 5.112 s |
| Startup total load, min / median / max | 13.509 / 13.510 / 13.511 s | 4.885 / 5.033 / 5.117 s |
| Founder playable, median | 40.165 s | 1.228 s |
| Startup ready, min / median / max | 53.664 / 53.689 / 53.755 s | 5.718 / 6.293 / 6.503 s |
| Longest prefetch update interval, median | 32.832 ms | 29.644 ms |
| Sampled peak memory, median | 275.048 MiB | 254.017 MiB |

The bounded `Founder_ToStartup_Walk` route is 760.75 m. At the configured 1.4 m/s walking speed, natural arrival is about 543.4 s. Even the slowest optimized Startup-ready run finished at 6.503 s, leaving more than eight minutes of route time. Startup is therefore ready well before the player reaches its boundary under the current route contract.

| Metric | Physical baseline | Phase 11B optimized |
| --- | ---: | ---: |
| First SceneEvents.Update, median | 0.157 s | 0.152 s |
| Founder visible, median | 40.163 s | 0.868 s |
| Founder playable, median | 40.163 s | 0.868 s |
| Startup ready, median | 53.689 s | 6.293 s |
| Full city background complete | 112.327 s | 29.248 s |
| Sampled peak memory | 293.861 MiB | 247.173 MiB |
| Longest load-stage update interval | 74.279 ms | 39.027 ms |

The full-city figure is the sum of the sequential district stage loads. It improved **3.84×**, saving **83.079 s** or **73.96%**. This is a debug benchmark of the intended load architecture, not a claim that production streaming is already integrated.

## Memory and Hitch Behavior

The final optimized physical run sampled a 247.173 MiB peak, **46.688 MiB (15.9%) below** the 293.861 MiB Phase 10 baseline. The longest SceneEvents.Update interval during a load stage improved from 74.279 ms to 39.027 ms. Startup prefetch's median longest interval improved from 32.832 ms to 29.644 ms.

These are SceneEvents.Update intervals, not GPU frame times. Instruments/Metal GPU metrics were not captured. The optimized physical import-profile route exits after loading, so optimized post-unload residency was not measured; that remains open for the production residency policy. The Phase 10 baseline unload cycles are retained as historical evidence only.

## Correctness and Reproducibility

Every optimized package passed programmatic checks for Y-up, meter scale, identity root, bounds, triangle totals, material totals, named landmark transforms, preserved semantic roots, self-contained dependencies, and traversal metadata. Maximum bounds drift was 0.000031 m from floating-point serialization. Landmark transforms were exact.

Derived Phase 11B tooling reads the authorized runtime exports and does not modify Phase 0–9 canonical Blender milestones. Audit manifests record every source mesh, batch membership, preserved root, semantic anchor, triangle/material total, bounds, landmark, and package hash. The combined evidence is in `Assets/Atlantis/Phase11B/batch_validation.json`.

Two unchanged regeneration passes produced matching semantic hashes over full prim paths/types, transforms, mesh points/topology, and material bindings. Binary `.usdc`/`.usdz` hashes are not stable because crate/archive metadata changes, so binary identity is not claimed. The final physical benchmark preceded the last package regeneration; the regenerated resources have the same audited semantics and metrics and passed the current simulator tests and UI capture run.

## Visual Regression

The current batched packages completed matching automated simulator captures for Founder street, Startup boulevard, Commerce/Flashpoint, Tech Core skyline, Unicorn overlook, and Atlantis aerial. Automated structure, bounds, material-presence, and landmark checks passed.

Human comparison of the attachments for facade loss, material differences, missing geometry, normals, shading seams, and landmark appearance remains an acceptance step. Tests alone cannot certify visual, audio, haptic, or animation correctness. A physical iPad was unavailable; the iPad Air 11-inch (M4) simulator build passed, and physical iPad acceptance remains open.

## Traversal Regression

The existing bounded `FounderGarageSlot` → Startup route passed with zero missing-ground samples, obstructions, or rejected controller steps. Batching preserves the route/cross-street entities and the independent traversal manifest, so render batching did not change grounding, collision ownership, or route continuity. The known Tech Core bridge rejection remains isolated and unchanged, as required by scope.

## Tested Optimizations

| Optimization | Improvement | Correctness | Keep? |
| --- | --- | --- | --- |
| District-specific static batching | 51.11× Founder import; 3.84× full-city background load | Triangles, materials, bounds, landmarks, semantics, and traversal preserved | Yes |
| Founder-first progressive boot with Startup prefetch | Founder playable at 0.868 s median; Startup ready at 6.293 s median | Existing load authority and bounded route preserved | Yes |

Shared-mesh optimization and material consolidation were not tested independently. Material counts intentionally remained unchanged so this comparison isolates entity batching.

## Tests and Builds

Current revision verification:

- Atlantis tests: **20 passed**, zero failures, included in the full unit run.
- Focused Founder Garage and workspace tests: **163 passed**, zero failures.
- Full unit suite: **804 passed**, zero failures.
- Targeted UI continuity suite: **2 passed**, zero failures, including six Atlantis camera attachments.
- Debug build for the physical iPhone 16 Pro: passed during each benchmark deployment.
- Debug build for iPad Air 11-inch (M4) simulator: passed.
- Release build for generic iOS Simulator: passed.
- `git diff --check`: passed.

The first sandboxed iPad build attempt could not reach CoreSimulator or user build caches. The same command succeeded with the required Xcode permissions; this was an environment-access failure, not a source/build failure.

## Recommendation

**Export strategy: A — Promote batching.** Use district-specific static batching as Atlantis's runtime export strategy. Asset selection is confined to `#if DEBUG` benchmark code; the baseline and optimized resources are temporarily both present for A/B builds. Final Release resource pruning belongs with production streaming integration and human visual acceptance.

**Boot strategy:** adopt Founder-first progressive boot with immediate Startup prefetch as the next production architecture. Time to Founder playable is already in the brief's recommended “excellent” band, and Startup completes long before natural arrival.

**Phase 12: Production Streaming + Traversal Architecture.** Implement adjacency-driven prefetch, residency/unload policy, far-landmark handling, isolated bridge repair, and the production walking foundation. Keep instrumentation active and add Instruments/Metal and physical-iPad acceptance during that phase.

Atlantis has enough hardware evidence to move into Phase 12. It is not yet ready for production routing because full continuous traversal, human visual review, GPU frame profiling, optimized unload behavior, and physical iPad acceptance remain open.

## Final Required Answers

- **Did Founder batching reproduce its simulator speedup on iPhone 16 Pro?** Yes; the hardware effect was larger than the earlier simulator result.
- **Physical Founder import speedup?** 51.11× median, from 40.040 s to 0.783 s, saving 39.256 s.
- **Which districts materially benefit?** All seven measured districts; Founder, Startup, Commerce, and Unicorn deliver the largest absolute product gains.
- **Which districts remain more granular?** Tech Core keeps The Spire, Pallas AI, and Northwind intact; Unicorn keeps the player HQ and campus semantics; Venture and Media use minimal batches around intact landmark roots; all districts retain navigation, signage, occupied, progression, and gameplay anchors.
- **Are required anchors preserved?** Yes, by manifest, runtime loader tests, semantic hashes, exact landmark transforms, and traversal tests.
- **Optimized Founder playable time?** 0.868 s median, 0.837–1.220 s across three runs.
- **Is Startup ready before natural arrival?** Yes; 6.503 s worst measured versus about 543.4 s of bounded route travel at 1.4 m/s.
- **New full-city background time?** 29.248 s versus 112.327 s, a 3.84× speedup and 83.079 s saving.
- **New peak memory?** 247.173 MiB versus 293.861 MiB, 46.688 MiB lower.
- **Is entity count the dominant import bottleneck?** Yes for the measured Atlantis workload: triangle/material totals stayed fixed while large entity-count reductions produced large hardware gains.
- **Should batching become the production export strategy?** Yes, using the documented district-specific contracts.
- **Ready for production streaming and traversal work?** Yes. Phase 12 should begin there, while Atlantis itself remains debug-only until the remaining acceptance gates close.
