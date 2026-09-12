# Atlantis Phase 10 — RealityKit Runtime + Performance Spike

## Executive result

**GO WITH OPTIMIZATION for continued development. Production promotion is not approved by this spike.**

Seven independent USDZ district roots load, render, unload and reload in the debug-only route. Founder-to-Startup controller traversal succeeds. Full-city simulator update cadence is near 60 callbacks/second, with measurable loading hitches. The inherited Tech Core bridge fails the bounded movement policy and needs a later geometry repair. The source masterplan and canonical SOLO simulation remain protected.

Evidence was collected September 10–11, 2026. These are Debug builds, short samples and SceneEvents.Update measurements. They are **not GPU-presented FPS**, sustained thermal results, a leaks profile, or proof of performance on the oldest supported hardware. The physical iPhone 16 Pro benchmark completed after unlocking. It confirms loaded-scene and bounded-controller feasibility, but **112.33 seconds of incremental district loading** is a P1 production blocker. Hardware measurements below supersede the earlier locked-device limitation.

## Source audit

The read-only spatial authority is `Assets/Atlantis/Phase9/UnicornHeights/Blender/Atlantis_Phase9_Masterplan.blend`. Audit: `Assets/Atlantis/Phase10/RuntimeSpike/source_audit.json`.

Blender 5.2.1 reports METRIC units, scale 1.0, 1,556 visible objects, 1,318 visible mesh objects and 127,315 mesh triangles before text conversion/exclusions. District collections, parent transforms, semantic roots, material names and packed-image inventory are recorded. Eighteen authoring images exist, but no image-texture nodes are active on exported materials. No source file was saved by the audit or export.

The source is Z-up. Conversion is applied once by the exporter: **Blender `(x, y, z)` → RealityKit `(x, z, -y)`**, a proper rotation preserving handedness. Runtime +X remains source east/right; runtime +Y is height; source north/+Y maps to runtime −Z. One unit is one meter. Origin stays `(0,0,0)`; district roots have identity transforms. Water spans roughly 3 km × 3 km; the highest Spire point is approximately Y=294 m (280 m above its 14 m base). No floating-origin system was needed for these coordinates.

Reference runtime positions (meters): Founder Garage `(-875,8,1030)`; Startup core `(-500,15.4,365)` from the Phase 6 site plan; Commerce hero/core anchor `(430,14,240)`; Tech Core uses the Spire anchor `(50,14,-420)`; Unicorn uses the player parcel anchor `(970,85,-850)`. These anchors are documented references, not newly invented district centers.

## Export pipeline

`export_districts.py` reads Blender and writes USDC stages plus self-contained USDZ packages using Blender’s bundled OpenUSD. This gives explicit ownership, hierarchy, units and material bindings without requiring Reality Composer Pro. Only USDZ packages and the compact manifest are app resources; USDC files remain reproducible inspection intermediates.

Seven district packages own their terrain/roads/bridges and named heroes. A separate **WorldContext** owns only the central peninsula and bay: two meshes, 60 triangles. It is independently removable and is not a monolithic city package. Founder owns the main Startup bridge, Media owns its headland bridge, and Unicorn owns the inherited Tech Core bridge. No hero is loaded twice.

Authoring boundaries, hidden staging, lights and cameras are excluded. Font geometry is converted to meshes. Parent transforms are retained, with a single axis conversion in the export. Static UsdPreviewSurface base color, roughness, metallic and emission are translated; this is not a general Blender node-graph, transmission, animation or texture-baking pipeline. Texture-bearing exports fail explicitly instead of silently dropping image dependencies.

`validate_exports.py` passed **80/80 package checks**: open, Y-up, meters, identity root, mesh/material counts, landmarks, dependencies, hashes and self-contained package structure. Runtime imports additionally validate bounds within 5 cm and landmark positions within 1 cm.

| District/package | Bytes | Meshes | Triangles | Material definitions | Textures |
| --- | --- | --- | --- | --- | --- |
| FounderDistrict | 362055 | 464 | 46032 | 15 | 0 |
| StartupRow | 252021 | 150 | 32056 | 14 | 0 |
| CommerceDistrict | 266685 | 217 | 35659 | 21 | 0 |
| VentureDistrict | 26801 | 49 | 1824 | 9 | 0 |
| MediaDistrict | 28551 | 63 | 1620 | 15 | 0 |
| TechCore | 39572 | 78 | 2852 | 22 | 0 |
| UnicornHeights | 114020 | 271 | 10212 | 12 | 0 |
| WorldContext | 3111 | 2 | 60 | 2 | 0 |
| Total | 1092816 | 1294 | 130315 | 110 | 0 |

Material totals count package-local definitions, including names repeated across packages. They are not a measured count of GPU shader programs or draw calls. Exported textures consume zero asset-image memory; the runtime creates a small 32×16 environment source whose derived RealityKit lighting resources are included only in process memory measurements. Runtime material bindings loaded successfully; exact GPU material residency was not captured.

| Semantic landmark | Owner | Runtime position |
| --- | --- | --- |
| FounderGarageSlot | FounderDistrict | -875.000, 8.000, 1030.000 |
| FlashpointHQ | CommerceDistrict | 430.000, 14.000, 240.000 |
| VentureHall | VentureDistrict | -520.000, 14.000, -110.000 |
| TechComTower | MediaDistrict | 835.000, 14.000, -220.000 |
| SignalTV | MediaDistrict | 860.000, 14.000, -460.000 |
| TheSpire | TechCore | 50.000, 14.000, -420.000 |
| PallasAIHQ | TechCore | 220.000, 14.000, -300.000 |
| NorthwindLabsHQ | TechCore | -100.000, 14.000, -520.000 |
| PlayerUnicornHQSlot | UnicornHeights | 970.000, 85.000, -850.000 |

### Package SHA-256

| Package | SHA-256 |
| --- | --- |
| founder_district.usdz | 4f43a8635fc3330f1f487d182f7a4400208517f03f2fbe1c6c4a88f1f8863573 |
| startup_row.usdz | dbefe47bc52fcc4e174b6c9eb1650d963ff2541fad0cc08ef058c6714884a796 |
| commerce_district.usdz | d872cb7eb4b2a4172addbeb65305c5885faef62092d3ea5cba9c9d0eaa07858e |
| venture_district.usdz | 1b33e463f957e5b4c1801ac91a41b4dadbbb6542175273d1ad8abdb248892150 |
| media_district.usdz | 887aec0ba517758985a89ba8d7e444caff51eb83b518cbac78cbb92dbe26cb32 |
| tech_core.usdz | 6b3418b382066c5822140c94dbf7af59c484d1f5b99613ac3db820d7a3365760 |
| unicorn_heights.usdz | 84ed0ce7937567f5b5ae8e96d6773b978ae5aa7a8001b9e355bd770a8cab8775 |
| world_context.usdz | 38ce0f74c46baf4cb8b6e2fed0284517790e81c663e72f00673a5514e46c26d5 |

### Instancing and material findings

Repeated mesh variants are present in Founder (23), Startup (8), Commerce (8) and Unicorn (8). The baseline expands each source object into its own USD mesh payload; it does not claim preserved USD/native GPU instancing. The complete compressed package set is only about 1.09 MB, but 1,294 mesh entities and per-object bindings can still carry CPU/draw overhead. A bounded shared-mesh/material experiment is more justified than a wholesale pipeline rewrite.

The white bay/coastal terrain is an inherited material-authoring inconsistency: source viewport colors are blue/green, while the connected Principled base colors are `(0.8,0.8,0.8)`. `material_audit.json` confirms this. Export preserves the shader values. Choosing viewport colors as authoritative should be a deliberate later material pass.

## Runtime architecture

- `AtlantisWorldPresentationModel.swift`: session-only debug configuration, semantic districts, spatial contract, fixed camera recipes and manifest models. `AtlantisPresentationAdapter` accepts only the existing visible day-phase value.
- `AtlantisDistrictLoader.swift`: stable world root; per-district unloaded/loading/loaded/failed states; joining duplicate requests; token invalidation; cancellation and obsolete-completion rejection; independent unload/retry. No store or save reference.
- `AtlantisRealityScene.swift`: stable presentation root, directional/environment lighting, camera rig, bounded movement and benchmark collection.
- `AtlantisRealityView.swift`: separate debug viewport and accessible controls. Buttons have minimum 44-point targets, text uses semantic fonts, HUD scrolls, actions have labels. Camera/lighting switches are immediate and introduce no Reduce Motion-dependent animation. Full VoiceOver/Dynamic Type acceptance remains human verification.

The only navigation integration is an opt-in branch in `App/App.swift` inside `#if DEBUG`. Launch with `--atlantis-realitykit` or `SOLO_ATLANTIS_RENDERER=realitykit`. Add `--atlantis-benchmark` for the scripted measurements. No configuration is persisted. The production default, Garage runtime, simulation mutations, RNG, financial ledger, Coverage, entitlements, hidden truth and version-19 save migration chain are unchanged.

Existing Garage patterns informed entity loading, lighting values and lifecycle handling; its room/camera/navigation code was not copied into a competing gameplay route. RealityKit frame callbacks modify only camera/presentation measurements. `playerRoot → CameraRig → Camera` is separate from simulation state. There is no autonomous day progression.

## Camera and visual inspection

Near plane is 0.2 m; far plane 8,000 m; street eye height is 1.7 m. Camera recipes are fixed in the source and identical across runs. Positions and targets below are runtime meters; orientation is the look-at quaternion generated from them.

| Camera | Position | Target | FOV degrees |
| --- | --- | --- | --- |
| founderStreet | [-875, 9.73, 1040.1] | [-825, 11, 970] | 65 |
| startupBoulevard | [-500, 17.7, 340] | [-300, 30, 270] | 65 |
| commerceFlashpoint | [388, 17.1, 303] | [435, 44, 235] | 65 |
| techCoreSkyline | [0, 35, -190] | [50, 150, -420] | 65 |
| unicornOverlook | [548, 87.3, -832] | [40, 140, -350] | 65 |
| atlantisAerial | [2700, 2900, 3600] | [0, 0, -100] | 55 |

All six views were captured and inspected on both simulator sizes. Aerial includes all seven districts; Founder shows the Startup corridor and the Spire when Tech Core is resident. Tech Core and Commerce heroes are identifiable. No district-axis reversal, recentering or missing hero was observed. Screenshots are under `Phase10/phone` and `Phase10/pad`.

Visible issue: Startup boulevard curb/paving edges show sawtooth artifacts consistent with overlapping/coplanar surfaces and/or depth precision. Location is the fixed Startup camera near `(-500,17.7,340)`, looking toward `(-300,30,270)`. Do not claim kilometer-scale depth precision is solved; the far/near ratio is 40,000 and street surfaces need a focused depth/mesh audit. Still screenshots cannot certify animation, audio, haptics or motion quality.

## Performance

The benchmark first loads Founder, then resets the presentation tree for staged reloads. These are warm-process measurements with importer/OS caches potentially retained, **not cold-launch times**. Stage duration includes requested district imports/validation/install but excludes the separately awaited WorldContext and deliberate sample waits. The “full-city total” is the sum of incremental stage durations, not the benchmark’s wall-clock duration.

Memory uses `task_vm_info.phys_footprint` / 1,048,576 (MiB, labeled MB in JSON). The periodic peak is sampled every 30 callbacks and can miss short spikes. Update cadence uses `SceneEvents.Update.deltaTime`; approximately two-second fixed-view windows and one-second LOD/lighting windows are short and noisy. A callback is not a GPU present. No authoritative Atlantis frame-rate budget was found: **60 FPS ideal / 30 FPS minimum** are recommendations for later hardware acceptance, not existing canon.

### iPhone 17 Pro Max simulator

Debug, iOS 26.5; all seven districts loaded with no recorded load error. Incremental load sum **2.839 s**; periodic peak **179.30 MiB**.

| Stage | Incremental seconds | Before MiB | After MiB | Load callbacks | Longest load interval ms |
| --- | --- | --- | --- | --- | --- |
| Founder only | 1.021 | 83.17 | 90.56 | 56 | 66.34 |
| Founder + Startup | 0.336 | 92.49 | 98.61 | 19 | 32.97 |
| + Commerce | 0.438 | 99.94 | 110.35 | 23 | 40.49 |
| + Tech Core | 0.245 | 109.49 | 114.75 | 15 | 22.30 |
| Full Atlantis | 0.799 | 114.63 | 132.67 | 46 | 40.79 |

| Fixed view | Callbacks/s | Mean ms | p95 ms | Longest ms | MiB |
| --- | --- | --- | --- | --- | --- |
| founderStreet | 60.0 | 16.67 | 16.72 | 23.48 | 129.00 |
| startupBoulevard | 60.2 | 16.67 | 16.70 | 26.74 | 129.00 |
| commerceFlashpoint | 58.5 | 17.07 | 16.73 | 42.51 | 129.02 |
| techCoreSkyline | 58.7 | 17.07 | 16.76 | 34.16 | 129.00 |
| unicornOverlook | 58.8 | 16.94 | 18.30 | 36.63 | 129.05 |
| atlantisAerial | 59.5 | 16.80 | 16.71 | 42.15 | 132.52 |

### iPad Air 11-inch (M4) simulator

Debug, iOS 26.5; all seven districts loaded with no recorded load error. Incremental load sum **2.656 s**; periodic peak **180.27 MiB**.

| Stage | Incremental seconds | Before MiB | After MiB | Load callbacks | Longest load interval ms |
| --- | --- | --- | --- | --- | --- |
| Founder only | 0.987 | 83.03 | 90.19 | 54 | 63.81 |
| Founder + Startup | 0.326 | 92.38 | 99.16 | 19 | 31.77 |
| + Commerce | 0.414 | 100.77 | 111.30 | 24 | 33.34 |
| + Tech Core | 0.167 | 109.96 | 115.11 | 9 | 32.75 |
| Full Atlantis | 0.762 | 114.88 | 133.74 | 44 | 43.05 |

| Fixed view | Callbacks/s | Mean ms | p95 ms | Longest ms | MiB |
| --- | --- | --- | --- | --- | --- |
| founderStreet | 59.6 | 16.80 | 16.71 | 38.83 | 129.27 |
| startupBoulevard | 59.5 | 16.81 | 17.24 | 42.64 | 129.25 |
| commerceFlashpoint | 59.8 | 16.67 | 18.56 | 25.44 | 129.25 |
| techCoreSkyline | 59.4 | 16.81 | 19.64 | 33.34 | 129.25 |
| unicornOverlook | 59.7 | 16.80 | 18.80 | 33.40 | 129.28 |
| atlantisAerial | 59.9 | 16.67 | 16.86 | 25.51 | 132.38 |

### Physical iPhone 16 Pro — completed

Development-signed Debug build, iPhone17,1, **iOS 26.7 (23H24)**, verified through CoreDevice and the runtime report. A separate app identifier (`com.talonsight.solounicornrun.atlantisspike`, “SOLO Atlantis Spike”) preserves the existing production installation and data. The older 26.6.1 inventory is superseded by the current device/runtime version.

The initial locked launch was resolved after the user unlocked the phone. Two incomplete attempts were restarted for diagnostics; their absence of a report was not treated as completion. Startup now logs context/Founder loading and writes a failure report if either fails. The final run completed every stage, all six views, four lighting phases, three shadow modes, three Unicorn unload/reload cycles, five LOD comparisons and all controller sweeps with **no report errors**. Raw evidence: `Phase10/iphone16pro-device-benchmark.json`.

**Incremental load sum: 112.33 s** (excludes initial Founder startup, WorldContext and deliberate sampling waits). **Periodic peak: 293.86 MiB.** These are warm-process results, making the physical import latency especially significant. A responsive frame callback during asynchronous import does not make a 40-second Founder load acceptable. Import/load latency needs profiling before production promotion; it is not an unrecoverable hang, and the root cause has not been established.

| Stage | Load seconds | Before MiB | After MiB | Load callbacks | Longest load interval ms |
| --- | --- | --- | --- | --- | --- |
| Founder only | 40.142 | 241.24 | 232.47 | 2404 | 74.28 |
| Founder + Startup | 13.519 | 232.27 | 232.70 | 809 | 44.67 |
| + Commerce | 18.724 | 236.41 | 243.03 | 1120 | 45.11 |
| + Tech Core | 6.887 | 246.33 | 252.56 | 411 | 31.80 |
| Full Atlantis | 33.057 | 248.34 | 268.97 | 1979 | 33.75 |

| View | Callbacks/s | Mean ms | p95 ms | Longest ms | MiB |
| --- | --- | --- | --- | --- | --- |
| founderStreet | 59.99 | 16.67 | 16.84 | 17.32 | 261.56 |
| startupBoulevard | 60.01 | 16.67 | 17.20 | 17.42 | 259.88 |
| commerceFlashpoint | 59.99 | 16.66 | 17.22 | 17.30 | 258.88 |
| techCoreSkyline | 59.99 | 16.67 | 16.81 | 17.32 | 258.28 |
| unicornOverlook | 59.99 | 16.66 | 17.22 | 17.33 | 261.84 |
| atlantisAerial | 59.99 | 16.67 | 17.26 | 17.31 | 263.09 |

All six views sustained approximately 60 scene-update callbacks/s in their short windows. These remain **update callbacks, not measured GPU presents**. No physical screenshots, Metal capture, sustained thermal test, or oldest-supported-device acceptance are claimed. Physical iPad execution remains untested; its required simulator configuration passed.

#### Physical unload/reload

| Cycle | Before MiB | After unload MiB | After reload MiB | Root count |
| --- | --- | --- | --- | --- |
| 1 | 260.03 | 259.61 | 260.91 | 1 |
| 2 | 260.91 | 260.39 | 261.69 | 1 |
| 3 | 261.69 | 287.77 | 287.64 | 1 |

Each cycle leaves exactly one Unicorn root. **Useful immediate memory reclamation was not established on hardware**: the first two unloads reclaim only about 0.42/0.52 MiB, and the third rises by about 26 MiB. Runtime/importer caches and asynchronous memory activity may contribute; three cycles cannot establish a leak or dismiss one. A longer residency/leaks profile is required before choosing a memory budget.

#### Physical lighting, shadows and representative LOD

| Experiment | Callbacks/s | p95 ms | MiB |
| --- | --- | --- | --- |
| shadows-0 | 60.00 | 17.18 | 259.55 |
| shadows-1 | 60.01 | 17.16 | 260.34 |
| shadows-2 | 60.00 | 17.29 | 260.25 |
| lighting-morning | 59.99 | 17.11 | 260.27 |
| lighting-day | 60.01 | 17.22 | 260.02 |
| lighting-evening | 59.96 | 17.18 | 260.02 |
| lighting-night | 59.99 | 17.25 | 260.03 |
| collision-off | 59.99 | 16.81 | 289.53 |
| collision-on | 59.99 | 17.22 | 282.27 |

| Asset | Original triangles | Proxy triangles | Callbacks/s original→proxy | Δ MiB |
| --- | --- | --- | --- | --- |
| Startup_LoftContext | 432 | 12 | 59.96 → 59.96 | +0.02 |
| Commerce_Building_01 | 9916 | 12 | 60.01 → 60.01 | +0.00 |
| Founder_Building_00 | 440 | 12 | 59.99 → 60.03 | +2.77 |
| PallasAIHQ | 572 | 12 | 59.99 → 60.01 | -0.19 |
| TheSpire | 972 | 12 | 60.02 → 59.99 | +0.00 |

The box substitutions did not establish a callback-rate benefit on the phone. Originals remain allocated while disabled, so this is not an LOD memory-release experiment. Physical controller results match simulator evidence: 5,436 successful early-route steps, 4,756 Startup-core steps, and rejection at the inherited bridge entry. The complete bridge ground sweep again finds three discontinuities and a 12.687 m maximum mismatch. This is accelerated movement-function validation, not a human real-time walkthrough.

## Streaming

Full city remained resident for the short simulator benchmarks. This supports seven-district feasibility on these configurations, not a universal resident budget. Three Unicorn unload/reload cycles retained exactly one Unicorn root each time. Independent fake-loader tests cover racing requests, stale completion, failure/retry and released entities; real-import tests cover all seven districts.

iPhone 17 Pro Max simulator

| Cycle | Before MiB | After unload MiB | After reload MiB | Root count |
| --- | --- | --- | --- | --- |
| 1 | 132.24 | 127.92 | 130.13 | 1 |
| 2 | 130.13 | 128.00 | 136.61 | 1 |
| 3 | 136.61 | 128.05 | 136.56 | 1 |

iPad Air 11-inch (M4) simulator

| Cycle | Before MiB | After unload MiB | After reload MiB | Root count |
| --- | --- | --- | --- | --- |
| 1 | 132.58 | 128.17 | 130.53 | 1 |
| 2 | 130.53 | 128.35 | 136.96 | 1 |
| 3 | 136.96 | 128.39 | 136.96 | 1 |

Simulator unloading reclaims some process memory, but the physical result above does not establish useful immediate reclamation. Caches make readings non-monotonic and this is not a leaks certification. The three cycles are insufficient for long-session leak or thermal conclusions. Loading shows tens-of-milliseconds update delays; exact unload hitch intervals were not separately captured.

District boundaries align spatially, but manually unloading a visible district produces an abrupt disappearance. There is no masking/prefetch/distance policy yet. The Spire is absent if Tech Core is unloaded, even with Founder and Startup resident. Therefore a future landmark-visibility contract or a small far-skyline representation is justified independently of immediate triangle pressure.

Retain the small district-aware loader and add measured prefetch/visibility handling before production. Automatic distance-based streaming is a reasonable next prototype, but no particular distance/radius is justified by these short tests. Do not implement a second open-world simulation authority.

## LOD

Five semantic roots were replaced temporarily with a 12-triangle bounding box at a stable asset-relative camera, sampled for one second each, then restored. The originals remain allocated while disabled, so this measures render/visibility cost, **not memory reclamation**. A proxy’s apparent memory delta includes cache/noise and cannot estimate a packaged production LOD. These are representative simplification experiments, not completed distance-based LOD chains.

| Asset | Original triangles | Proxy triangles | iPhone callbacks/s original→proxy | iPhone Δ MiB | iPad callbacks/s original→proxy | iPad Δ MiB |
| --- | --- | --- | --- | --- | --- | --- |
| Startup_LoftContext | 432 | 12 | 59.0 → 60.1 | +0.05 | 59.6 → 60.1 | +0.05 |
| Commerce_Building_01 | 9916 | 12 | 58.1 → 58.0 | +0.03 | 57.6 → 59.4 | +0.08 |
| Founder_Building_00 | 440 | 12 | 58.3 → 58.7 | +0.14 | 60.1 → 59.4 | +0.08 |
| PallasAIHQ | 572 | 12 | 59.1 → 57.6 | +0.08 | 58.1 → 57.0 | -0.41 |
| TheSpire | 972 | 12 | 58.7 → 58.6 | +0.03 | 58.7 → 59.1 | +0.03 |

Visual loss is substantial for every box: facade rhythm, entrances, crown and recognizable silhouette are removed; Spire/HQ identity is especially poor. Runtime boxes are not saved or shipped as replacement art. Most timing differences are small/noisy; Commerce is the largest candidate (9,916 triangles) and its iPad sample improved, but a single one-second comparison is not proof of production benefit. Prefer a measured Commerce representative and preserved-silhouette landmark experiment before building citywide LODs. A separate full far-district proxy was not needed to establish baseline feasibility; no costly distant-district failure was measured.

## Lighting and collision overhead

One directional sun plus a neutral environment source; no citywide point/spot light population. Existing morning/day/evening/night values are consumed through a debug hook. Emissive materials remain visible shader surfaces, not dynamic lights. Shadow modes are off, 120 m directional distance and 500 m directional distance. “Hero” mode is only a distance comparison, not a separate per-hero lighting rig.

iPhone 17 Pro Max simulator

| Experiment | Callbacks/s | p95 ms | MiB |
| --- | --- | --- | --- |
| shadows-0 | 57.5 | 20.55 | 132.49 |
| shadows-1 | 59.5 | 16.77 | 132.52 |
| shadows-2 | 58.6 | 20.82 | 132.50 |
| lighting-morning | 59.6 | 16.71 | 132.25 |
| lighting-day | 60.3 | 16.73 | 132.24 |
| lighting-evening | 58.7 | 16.80 | 132.25 |
| lighting-night | 59.3 | 16.73 | 132.24 |
| collision-off | 59.4 | 16.74 | 130.13 |
| collision-on | 58.8 | 16.74 | 130.19 |

iPad Air 11-inch (M4) simulator

| Experiment | Callbacks/s | p95 ms | MiB |
| --- | --- | --- | --- |
| shadows-0 | 58.6 | 16.72 | 132.53 |
| shadows-1 | 58.7 | 19.09 | 132.56 |
| shadows-2 | 59.5 | 19.48 | 132.56 |
| lighting-morning | 59.8 | 16.73 | 132.58 |
| lighting-day | 60.4 | 16.70 | 132.58 |
| lighting-evening | 58.8 | 16.85 | 132.58 |
| lighting-night | 59.1 | 16.74 | 132.58 |
| collision-off | 59.9 | 20.17 | 130.47 |
| collision-on | 58.6 | 30.52 | 130.55 |

No repeatable shadow win/loss is established by these simulator samples. Keep one directional strategy and profile hardware before selecting production shadow distance. The iPad collision-on p95 spike deserves a longer isolated run; do not attribute it conclusively to colliders from one short sample. Morning/day/evening/night compatibility was exercised; final artistic lighting and emissive readability still require human acceptance.

## Walking

Movement is a debug-only camera-root prototype at 1.4 m/s. It queries 941 exported upward triangles, snaps feet to the highest loaded surface and rejects missing ground or a >0.35 m step/drop. Ninety-two Founder/Startup building envelopes use rotation-aware plan AABBs plus a 0.25 m margin. RealityKit box collision components are installed for the experiment; movement collision resolution uses the bounded CPU envelope query. This is not a complete physics character controller, navmesh, capsule solver or final accessibility locomotion design. Trees, furniture and other districts do not have complete collision coverage.

Two complementary checks run: (1) sample route ground at 0.2 m spacing; (2) drive the same `move()` used by UI controls in accelerated fixed 0.1-second steps. The latter preserves per-step speed/ground/collision rules but is **not a human real-time end-to-end walk**. UI tests separately exercise live Forward/Pause controls.

| Route segment | Result | Evidence / issue | Severity |
| --- | --- | --- | --- |
| Garage driveway → sidewalk | PASS | Driveway 59 controller steps; apron 20; no rejection. | — |
| Founder neighborhood route | PASS | Included in 5,436-step Founder route; no missing ground or building obstruction. | — |
| Founder → Startup connector | PASS | Same continuous early-route run; maximum sampled height mismatch 0.04573 m near (-851.565,9.268,742.244). | P2 minor surface mismatch |
| Connector → Startup Row | PASS within defined route | Controller reaches (-625.443,16.440,488.676); no step rejection. | — |
| Startup Row core | PASS as separate source-route sweep | 4,756 controller steps from source route (-610,16,490) to (-170,14.65,80); source route height differs by up to 0.35001 m. The short join from the early-route endpoint to this separate route was not a single continuous controller run. | P2 route height/join acceptance |
| Steep bridge | NOT WALKABLE under current policy | 18.861% source grade, 71 m rise. Start at (360,14,-470) rejects first step; sweep finds 3 discontinuities and 12.687 m mismatch at (553.733,85,-704.095), where raised terrain intersects incline. | P1 repair before access |

The bridge classification is **needs geometry refinement before walking access**, with a steep source grade requiring a deliberate traversal design. It was not reshaped. No missing-ground teleport or elevated step allowance was added to conceal the failure. Stable grounded early-route movement supports the player-root architecture; it does not validate every city sidewalk or final locomotion.

## Regression and preservation

The baseline hashes 537 existing files. Validation reports 534 byte-identical, two intentional existing-file changes (`App/App.swift` and precise Xcode target/resource membership), and one generated Xcode UI-state file. Phase 0–9 assets, protected Garage source/assets, GameStore, simulation and save files match their baseline hashes. Pre-existing dirty files, including the shared scheme and Garage integration, were preserved rather than reset.

The added Swift files are genuinely separate debug runtime boundaries and need explicit target membership in this project; the unit/UI files and eight packages plus manifest were added precisely. No project regeneration or shared-scheme edit was performed by Phase 10. Release routing is compiled out, although the export resources are currently bundled by the shared resources phase (about 1.09 MB plus manifest); removing debug-only asset bytes from distribution is a future packaging choice.

Final iPhone verification passed **800/800 tests**; final iPad verification passed **113/113 tests**. The Release simulator build also succeeded. Test evidence and build status are recorded in `Phase10/verification.md`. iPad focused regression includes all 97 Garage tests, 12 Atlantis tests and four UI tests. Garage UI checks exercise default legacy behavior and the RealityKit Founder Computer round trip. Normal launch remains opt-in-free. No test alone certifies visual/audio/haptic/animation correctness.

Initial verification failures were resolved rather than hidden: an invocation used the wrong UI target name (`UITests` instead of `UI Tests`), and a new route required updating a stale count assertion from three to four. Blender’s sandboxed startup crashed; the same read-only audit succeeded outside the sandbox. Physical launch subsequently succeeded after unlocking; the complete hardware benchmark and 12 focused tests passed after adding startup diagnostics. The 800/113 broad simulator results precede this small diagnostic change; the focused 12-test run and device build verify the updated source.

## Open risks

| Priority | Risk | Smallest next action |
| --- | --- | --- |
| P0 | No current evidence of a severe architecture failure. | Keep default production routing protected. |
| P1 | Physical imports take 112.33 s total (Founder alone 40.14 s). | Profile USD import/validation/install separately; test bounded hierarchy/material/shared-mesh changes before production promotion. |
| P1 | Physical GPU/thermal/long-session memory acceptance remains incomplete; unload memory rises in cycle 3. | Capture GPU presents and a sustained residency/leaks profile; establish budgets from hardware evidence. |
| P1 | Tech Core bridge entry and raised-terrain intersection reject movement. | Repair the bounded source seam/landing in a new authorized geometry pass; re-export only dependent packages. |
| P1 | Debug movement is not complete city collision/navigation. | Define traversable surface ownership, bounded collision coverage and streaming-safe player placement. |
| P2 | Startup curb artifacts and source viewport/shader mismatch. | Audit coplanar surfaces/depth and choose authoritative material values; preserve source backups. |
| P2 | Mesh instancing expanded; Commerce representative has high triangle cost. | Measure one shared-mesh/material and one preserved-silhouette LOD experiment. |
| P2 | Load hitches, abrupt unload and skyline disappearance. | Prefetch adjacent districts and define independent far-landmark visibility. |
| P2 | One-/two-second samples, cache noise, no isolated unload hitch profile. | Repeat with longer windows and Instruments/Metal counters before setting budgets. |
| P2 | HUD scroll/accessibility and real-time traversal acceptance incomplete. | Human iPhone/iPad VoiceOver, Dynamic Type, Reduce Motion and walking acceptance. |

## Final assessment — seven required answers

1. **Can Atlantis load successfully in RealityKit as district-based runtime content?** Yes: seven separate packages pass export and real-import validation on both simulator configurations.
2. **Can districts be independently loaded and unloaded without corrupting scene state?** Yes within tested scenarios: duplicate joins, stale cancellation, failure/retry and real district unloads pass; three Unicorn cycles preserve one root. Long-session leak certification is not implied.
3. **Is Founder District → Startup Row spatially correct at runtime?** Yes for the defined Phase 7 early route and shared world transforms; a small sampled surface mismatch and separately tested Startup core/join limits are documented.
4. **Can a bounded player-root walking prototype traverse the intended early route?** Yes: the same movement function completes 5,436 fixed steps without rejection. Live UI movement works. This is accelerated controller evidence, not full human route acceptance.
5. **Is full-city or near-full-city rendering technically viable on tested iPhone/iPad configurations?** Yes for the tested Debug simulator configurations and for loaded-scene update cadence on the physical iPhone 16 Pro. Actual GPU-present throughput and sustained thermal behavior remain unverified. Physical import latency is not production-ready.
6. **Are LOD and/or district streaming necessary?** District-aware loading is the appropriate production boundary; prefetch and far-landmark visibility need a next pass. Complete LOD chains are not yet justified by this baseline; a focused Commerce/landmark experiment is warranted.
7. **Did Atlantis integration leave the existing Founder Garage and canonical SOLO simulation untouched?** Yes relative to the pre-Phase-10 baseline, verified by protected-file hashes and Garage/simulation tests. The debug app branch and required project membership are the intentional integration changes.

## Recommended Phase 11

**Import-latency optimization, traversal and sustained hardware acceptance**, not additional city art: first profile the measured 112.33-second physical load path and investigate residency/caches with GPU and sustained memory evidence; repair the bridge entry/terrain intersection in a bounded derivative asset pass; verify the entire Garage-to-Startup-core join with a continuous real-time traversal; add adjacent-district prefetch and a far-landmark visibility contract. Measure one Commerce LOD/shared-mesh experiment only after those results. Keep Atlantis debug-only until hardware, collision, visual and accessibility acceptance are complete.

The import-latency follow-up is documented in [Phase 11 Import Latency Investigation](PHASE11_IMPORT_LATENCY_INVESTIGATION.md). Phase timing isolates `Entity(contentsOf:)` as the bottleneck, and a Founder-only material-batching experiment reduces simulator import by about 92%. Physical optimized timing remains pending device reconnection; the diagnostic package is not approved as a production replacement.

## Reproduction and evidence

- Launch Debug with `--atlantis-realitykit --atlantis-benchmark`. Results are written to the app Documents directory as `atlantis-benchmark.json`.
- Raw physical report: `Phase10/iphone16pro-device-benchmark.json`.
- Raw simulator reports: `Phase10/iphone-final-benchmark.json` and `Phase10/ipad-final-benchmark.json`.
- Source/export/validation/preservation artifacts: `Assets/Atlantis/Phase10/RuntimeSpike/`.
- LOD source counts: `Phase10/lod-source-metrics.json`.
- Every Phase 10 new/modified repository file is listed in `Phase10/changed-files.md`; pre-existing unrelated dirty files are not attributed to this phase.

Apple documents asynchronous entity loading and automatic offscreen mesh culling; no custom occlusion system was added based on assumptions. See [Entity loading](https://developer.apple.com/documentation/realitykit/entity), [reducing RealityKit CPU utilization](https://developer.apple.com/documentation/realitykit/reducing-cpu-utilization-in-your-realitykit-app), [RealityKit performance](https://developer.apple.com/documentation/realitykit/improving-the-performance-of-a-realitykit-app), [SceneEvents.Update](https://developer.apple.com/documentation/realitykit/sceneevents/update), and [Blender USD support](https://docs.blender.org/manual/en/latest/files/import_export/usd.html). These references inform the pipeline; local measured evidence determines this assessment.
