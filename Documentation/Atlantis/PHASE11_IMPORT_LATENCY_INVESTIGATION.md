# Atlantis Phase 11 — Import Latency Investigation

## Status

**Optimization candidate validated on simulator; physical before/after comparison is pending reconnection of the iPhone 16 Pro.**

Phase 10 proved that Atlantis loads and remains responsive after loading, but the physical iPhone 16 Pro spent 112.33 seconds importing the seven districts. This bounded investigation separates file resolution, read, checksum, RealityKit import, validation, and scene installation. It also tests one Founder-only static batching candidate without changing the production/default package or the Phase 9 Blender source.

Atlantis remains a debug-only presentation route. GameStore, simulation, RNG, saves, Garage runtime, Phase 0–9 sources, walking policy, and bridge geometry are outside this pass.

## Diagnosis

RealityKit entity construction is the measured bottleneck. On the iPhone baseline, district time tracks mesh-entity count at approximately 0.086–0.090 seconds per mesh:

| District/stage | USDZ bytes | Meshes | Physical load | Seconds/mesh |
| --- | ---: | ---: | ---: | ---: |
| Founder | 362,055 | 464 | 40.142 s | 0.0865 |
| Startup | 252,021 | 150 | 13.519 s | 0.0901 |
| Commerce | 266,685 | 217 | 18.724 s | 0.0863 |
| Tech Core | 39,572 | 78 | 6.887 s | 0.0883 |
| Venture + Media + Unicorn | 169,372 | 383 | 33.057 s | 0.0863 |

File size is not the useful predictor: Founder and Commerce differ by only 95 KB but by 21.4 seconds; Tech Core is 40 KB yet needs 6.9 seconds. Triangle count also does not explain the near-linear relationship as directly as mesh count. This makes per-mesh RealityKit import/entity construction the leading evidence-backed cause.

The new simulator phase measurements reinforce that conclusion:

| Founder phase, normal package | Measured time |
| --- | ---: |
| Resolve bundle URL/manifest entry | 0.016 ms |
| Mapped file read | 0.104 ms |
| SHA-256 | 0.201 ms |
| RealityKit `Entity(contentsOf:)` | 980.165 ms |
| Bounds + landmark validation | 0.119 ms |
| Scene install + IBL receiver | 3.795 ms |

The checksum, runtime validation, and scene installation do not justify removal for speed. Retain them while optimizing imported entity structure.

Raw baseline phase evidence: `Phase11-simulator-import-profile.json`.

## Bounded batching experiment

`build_import_batch_experiment.py` reads the validated Phase 10 Founder USDC. It bakes existing transforms into world-space vertices, groups static faces by their already-bound material, and writes one mesh per material. It preserves:

- the identity `FounderDistrict` root;
- one-meter, Y-up spatial contract;
- 46,032 triangles;
- all 15 material definitions;
- Founder bounds within the Phase 10 5 cm tolerance;
- the semantic `FounderGarageSlot` at `(-875, 8, 1030)`.

It deliberately does not modify the Blender masterplan or the normal `founder_district.usdz`. The runtime selects the experiment only with `--atlantis-batched-founder`; normal Atlantis and production launch behavior remain unchanged.

| Founder package | Meshes | Triangles | Bytes | Simulator RealityKit import | Stage total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Phase 10 normal | 464 | 46,032 | 362,055 | 980.165 ms | 986.030 ms |
| Batched experiment | 15 | 46,032 | 1,566,454 | 76.561 ms | 77.693 ms |
| Change | −96.8% | unchanged | +332.6% | **−92.2%** | **−92.1%** |

The second normal Founder import measured 1.011 seconds and the first batched import 75.250 ms, so the result is not dependent on choosing only the favorable sample. The imported full city also rendered at the fixed aerial view on iPhone 17 Pro Max simulator.

Raw comparison evidence: `Phase11-simulator-batched-import-profile.json`. Focused validation passed 14 Atlantis tests. The final combined regression passed **111 tests**: 14 Atlantis and 97 protected Garage tests, with zero failures or skips, in `/private/tmp/solo-atlantis-phase11-combined-tests.xcresult`.

## Tradeoffs and production boundary

The candidate demonstrates that entity count is actionable, but it is not ready to replace the normal package:

- Static per-building mesh hierarchy is flattened into material batches. This would prevent building-level visibility, interaction, damage, or LOD control for those objects unless semantic/interactive roots are excluded from batching.
- Geometry is duplicated between material groups when one source mesh uses multiple materials. This contributes to the 1.57 MB package, 4.33 times the normal compressed size.
- World-space baking prevents direct reuse of the original local transforms and source-instance relationships.
- Only Founder has been compared. Batching every district without preserving its interaction and streaming contract would repeat the flattening mistake the district-root architecture was designed to avoid.
- Simulator improvement predicts a large device improvement, and the physical baseline’s seconds-per-mesh relationship supports that prediction, but no physical optimized time is claimed until it is measured.

The smallest production-shaped next experiment is selective batching:

1. Preserve named heroes, Garage slot, progression locations, player/rival parcels, interactive buildings, roads needed as traversal surfaces, and any future visibility/LOD roots.
2. Batch only repeated, noninteractive static background geometry by material within each district.
3. Avoid duplicating complete point arrays per material by generating indexed material batches directly from used vertices.
4. Compare hierarchy counts, package size, import time, memory, materials, bounds, and visual output on the physical iPhone.
5. Promote no package until physical import time and semantic-retention tests pass.

## Verification notes

The first new assertion had a missing parenthesis and was corrected before tests ran. The first batched-package test then failed because the package was not in the explicit Xcode resource list; one precise file reference/build-resource entry was added, with no project regeneration or scheme edit. The final focused run passed 14/14 tests; the combined Atlantis/Garage run passed 111/111. The project also built successfully for the simulator.

The connected iPhone became unavailable to both Xcode and CoreDevice before the instrumented build could be installed. The original isolated app and its Phase 10 results remain valid. A hardware comparison requires the iPhone to reconnect and stay unlocked; this is the only outstanding measurement for this bounded investigation.

## Current conclusion

The Phase 10 load delay is not caused by the checksum, file read, bounds checks, SwiftUI observation, or scene installation. It is overwhelmingly inside RealityKit package import and scales with the number of mesh entities emitted by the baseline exporter. Founder material batching cuts simulator import by about 92%, proving an optimization direction.

Adopt **selective semantic batching** as the Phase 11 implementation direction after the physical Founder comparison. Do not ship the current fully flattened experiment as production content.
