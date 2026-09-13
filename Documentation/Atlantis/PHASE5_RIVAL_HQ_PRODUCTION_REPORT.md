# Atlantis Phase 5 — Rival HQ production report

Date: 2026-09-10. Scope: three canonical rival headquarters and a new Phase 5 Blender masterplan. No runtime integration.

The final HQs use source-informed architectural reconstruction in Blender. The generated GLBs are preserved as references; their original noisy surfaces and 4K textures are not used in the final exports. This is reconstruction, not a claim of lossless decimation or unchanged generated topology.

## Phase 4 contracts and final placement

| Company | Canonical slot / district | World origin (m) | Initial maximum (m) | Final dimensions (m) | Growth envelope (m) |
|---|---|---|---|---|---|
| Pallas AI | RivalHQ_Slot_04 / TechCore | [220, 300, 14] | 60 × 42 | 58 × 40 × 160 | 64 × 44 × 180 |
| Northwind Labs | RivalHQ_Slot_03 / TechCore | [-100, 520, 14] | 58 × 52 | 56 × 50 × 115 | 65 × 60 × 150 |
| Flashpoint | RivalHQ_Slot_05 / CommerceDistrict | [430, -240, 14] | 40 × 32 | 38 × 30 × 75 | 42 × 34 × 90 |

Approved final height ranges are Pallas 120–170 m, Northwind 100–130 m and Flashpoint 55–90 m; exact chosen targets are 160, 115 and 75 m respectively.

Each production root remains parented to its original canonical semantic locator and slot. One Blender unit is one metre. Standalone pivots are the footprint center at ground elevation (0,0,0); all final object rotations are zero and scales are (1,1,1). Main facades face −Y in Blender / +Z in glTF. No parcel moved.

## Generation and source audit

Generation order was Pallas → accepted → Northwind → accepted → Flashpoint. Pallas and Flashpoint each needed two candidates; Northwind needed one. An initial Pallas prompt exceeded the 1,024-character service limit and failed before creating a candidate. The five actual candidate jobs completed.

| Source | Bytes | Source dimensions (arbitrary units) | Meshes / triangles / materials | Textures | Non-manifold edges after seam weld |
|---|---:|---|---|---|---:|
| PallasAI/PallasAI_Higgsfield_Raw.glb | 4,876,700 | 0.759097 × 0.853845 × 0.985041 | 1 / 21,204 / 1 | 3 × 4096² RGBA | 29 |
| PallasAI/PallasAI_Higgsfield_Raw_candidate2.glb | 3,542,132 | 0.913662 × 0.75404 × 0.978843 | 1 / 19,129 / 1 | 3 × 4096² RGBA | 8 |
| NorthwindLabs/NorthwindLabs_Higgsfield_Raw.glb | 3,958,344 | 0.688423 × 0.98095 × 0.707832 | 1 / 20,579 / 1 | 3 × 4096² RGBA | 44 |
| Flashpoint/Flashpoint_Higgsfield_Raw.glb | 3,337,236 | 0.981053 × 0.618645 × 0.556464 | 1 / 20,950 / 1 | 3 × 4096² RGBA | 83 |
| Flashpoint/Flashpoint_Higgsfield_Raw_candidate2.glb | 4,047,908 | 0.495399 × 0.431925 × 0.980225 | 1 / 19,150 / 1 | 3 × 4096² RGBA | 46 |

All raw sources import as a single unparented mesh at object origin (0,0,0), zero rotation and unit scale, with arbitrary centered geometry bounds rather than a ground pivot. Exact bounds, component sizes, hierarchy and texture names are retained in each source_audit JSON. All source audits found zero zero-area faces. Each source has color, normal and ORM maps: approximately 192 MiB decoded RGBA total, excluding mipmaps and GPU compression. These maps have distinct roles, not duplicate image copies.

Pallas candidate 1 had an oversized campus, ornate crown and detached sign. Candidate 2 supplied the disciplined tower, bronze fins and restrained crown direction. A uniformly scaled and rotated tower cleanup study was attempted, but corrugation remained; the final tower was rebuilt with planar tapered rings, formal podium, fins, crown and entrance. The repaired study is retained only in hidden staging.

Northwind candidate 1 supplied the pale frame, cool glazing, technical roof and connected research wing. Its campus footprint was too broad at the target height. Reconstruction retained that composition in a 56 × 50 m foundation, with modular floor bands and an offset research tower.

Flashpoint candidate 1 generated a two-building streetscape with trees, road, vehicle and oversized billboard panels, so its concept was rejected. The selected second candidate and the final reconstruction are described in Flashpoint/Source/production_notes.md.

## Cleanup and final independent exports

| HQ | Chosen source height → final height | Source → final triangles | Reduction* | Meshes | Materials | Textures | GLB bytes |
|---|---|---|---:|---:|---:|---:|---:|
| PallasAI | 0.978843 → 160 m | 19,129 → 572 | 97.0% | 8 | 8 | 0 | 47,440 |
| NorthwindLabs | 0.707832 → 115 m | 20,579 → 708 | 96.6% | 7 | 7 | 0 | 57,152 |
| Flashpoint | 0.980225 → 75 m | 19,150 → 420 | 97.8% | 7 | 7 | 0 | 36,940 |

*Reduction compares source and reconstructed triangle counts; it is not a decimation quality metric.

The final meshes have outward closed component geometry, no non-manifold edges after UV-seam welding, no zero-area faces, positive signed volume and clean transforms. Architectural components deliberately overlap at structural joints; this is not a Boolean-unioned watertight building solid. Reconstructed geometry removes generated disconnected junk, streetscape props, irregular facade surfaces and unnecessary subdivisions. Flat architectural faces avoid damaged source smoothing. No displacement or normal textures remain.

Each GLB was exported and freshly reimported. Final .blend files were saved from these independent imports. The final exports contain no textures and therefore no unused or duplicate texture maps. Original 4K maps remain in raw sources and hidden source staging in the authoring master, which is not a mobile runtime payload.

## Semantic targets and lighting

- PallasAI: `PallasAI_CrownMark`, `PallasAI_LobbyDisplay`, `PallasAI_Signage_Main`.
- NorthwindLabs: `NorthwindLabs_LabDisplay`, `NorthwindLabs_Signage_Main`.
- Flashpoint: `Flashpoint_LaunchDisplay`, `Flashpoint_Signage_Main`, `Flashpoint_Ticker`.

Material families:

- PallasAI: PallasAI_ArchitecturalGlow, PallasAI_Bronze, PallasAI_CrownMark, PallasAI_LobbyDisplay, PallasAI_PodiumGlass, PallasAI_PodiumStone, PallasAI_Signage_Main, PallasAI_RefinedTowerGlass.
- NorthwindLabs: NorthwindLabs_LabDisplay, NorthwindLabs_LabGlow, NorthwindLabs_PaleStructure, NorthwindLabs_ResearchGlazing, NorthwindLabs_RoofLouvers, NorthwindLabs_Signage_Main, NorthwindLabs_Silver.
- Flashpoint: Flashpoint_DarkGlazing, Flashpoint_LaunchDisplay, Flashpoint_MomentumAccent, Flashpoint_PodiumConcrete, Flashpoint_Signage_Main, Flashpoint_StructuralSilver, Flashpoint_Ticker.

Targets retain separate objects, material families, UV maps and semantic_target / dynamic_material_target metadata. The old hidden blockouts retain their original names; where Blender assigns a .001 suffix to a new master object, semantic_target carries the exact canonical name. Standalone GLBs and .blend files use exact unsuffixed names. Displays are blank and no permanent text is required for architectural identity.

Pallas uses controlled warm lobby/crown identity; Northwind uses restrained cool lab and entrance illumination; Flashpoint uses concentrated warm accent and launch/podium activity. Day and night Blender renders were visually reviewed. Material families support future light changes for morning/noon/evening/night, but no time system, rival state behavior, animation or simulation authority is implemented.

## Future growth capacity

| HQ | Additional width / depth / height available (m) | Unoccupied growth-envelope plan area (m²) |
|---|---|---:|
| PallasAI | 6 × 4 × 20 | 496 |
| NorthwindLabs | 9 × 10 × 35 | 1100 |
| Flashpoint | 4 × 4 × 15 | 288 |

These are bounding-envelope differences, not promises of usable construction area or a specific upgrade design. Existing Phase 4 road and neighbor clearances remain applicable because all initial assets fit inside the original approved footprints and all growth envelopes and roads remain unchanged.

## Sightlines and skyline

The table below records sampled visibility from fixed review cameras: Strong = at least 6/12 samples, Partial = 1–5, Hidden = zero. These samples are a reproducible visibility aid; visual review remains necessary and does not guarantee visibility from every position in a district.

| Fixed camera | Pallas | Northwind | Flashpoint |
|---|---|---|---|
| Founder_To_City | Hidden | Hidden | Hidden |
| TheSpire_StartupSightline | Strong | Hidden | Hidden |
| VentureHall_ToSpire | Strong | Strong | Hidden |
| MediaDistrict_ToSpire | Strong | Hidden | Strong |
| TechCore_Skyline | Partial | Hidden | Hidden |
| UnicornHeights_View | Strong | Strong | Strong |
| Venture_Pallas | Strong | Hidden | Hidden |
| Northwind_TechApproach | Hidden | Strong | Hidden |
| StartupRow_Flashpoint | Hidden | Hidden | Strong |
| Media_RivalSkyline | Strong | Hidden | Hidden |
| TechCore_Rivals_Aerial | Strong | Strong | Hidden |

Visual review supplements the sampled table: Pallas shows a partial crown/edge from Founder even though its centerline sample rays miss the exposed sliver. Flashpoint is Partial in the additional Commerce approach and Tech approach views, while Strong from the Startup approach. Northwind is Hidden from the fixed Startup/Media ground views and Strong at the research edge. No existing buildings were moved to force visibility.

The Spire remains the 280 m primary landmark. Pallas is an important 160 m corporate tower, visibly credible from Venture, with a shorter and distinct bronze crown. Northwind is a 115 m research tower on the research edge; existing foreground towers obscure it from some distant ground-level views. Flashpoint remains a 75 m Commerce company near the startup progression route. The 145 m Tech.com Tower, 47 m Signal TV and 41.4 m Venture Hall keep their existing geometry, placement and roles. Media retains rival skyline presence without moving its landmarks.

| Established Spire view | Phase 4 visible crown samples | Phase 5 visible crown samples |
|---|---:|---:|
| Founder_To_City | 36 | 36 |
| TheSpire_StartupSightline | 38 | 38 |
| VentureHall_ToSpire | 43 | 43 |
| MediaDistrict_ToSpire | 39 | 39 |
| TechCore_Skyline | 39 | 39 |
| UnicornHeights_View | 45 | 45 |

Crown samples use actual upper Spire surface points, including correct orthographic ray origins and exclusion of hidden staging/blockouts. Founder-to-Spire and the five other established views are not worsened. The pre-existing support massing still occludes parts of the lower Spire; this pass does not redesign that composition.

## Validation and preservation

22/22 combined checks passed; 258 protected file hashes match the baseline. Every original Phase 4 object retains its local transform, parent, custom metadata, mesh geometry and material references. Only the three old HQ blockout mesh visibility flags are disabled in the new master after the rival-specific checks passed.

Phase 0 geography, terrain, bay, roads, bridges, district boundaries, Founder Garage slot, Player Unicorn slot, The Spire, Venture Hall, Tech.com and Signal TV are preserved. Phase 0–4 files were not edited. Garage V7, app/runtime, GameStore and save version 19 were untouched. Existing unrelated dirty app, test, project and scheme changes were preserved. No commits or pushes were made.

This is a Blender-only asset pass: no Xcode build, XCTest, simulator or device run was performed. Blender visual review does not establish RealityKit performance or on-device correctness. Simulator/device verification remains a later human acceptance step; these GLBs are not yet promoted to RealityKit production.

## Six final acceptance answers

1. **Yes** — Pallas reads as an established global AI powerhouse through its height, formal podium, disciplined taper and bronze crown.
2. **Yes** — Northwind reads as technically rigorous and research-driven through its modular frame, offset tower and connected lab podium.
3. **Yes** — Flashpoint reads as an aggressive high-growth rival through its asymmetric silhouette, sharper rhythm and concentrated launch-facing accent.
4. **Yes** — all three are distinguishable without text labels in the same-scale architecture comparison.
5. **Yes** — the assets fit their approved parcels and preserve the masterplan and Founder-to-Spire sightline.
6. **Yes** — Atlantis can now represent its three canonical rivals as distinct physical companies in the city.

These are visual production judgments supported by the saved review renders and geometry/placement checks, not runtime or user acceptance claims.

## Created / changed Phase 5 files

All paths below are relative to the repository. Intermediate candidates, preservation snapshots, raw sources and review renders are retained for traceability. The final deliverables are the three Atlantis_*_HQ_v1 pairs and Blender/Atlantis_Phase5_Masterplan.blend.

- `Assets/Atlantis/Phase5/RivalHQs/Blender/Atlantis_Phase5_Masterplan.blend`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Blender/Atlantis_Flashpoint_HQ_v1.blend`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Blender/Before_Flashpoint.blend`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Blender/Integration_Candidate.blend`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Export/Atlantis_Flashpoint_HQ_v1.glb`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/Flashpoint_Day.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/Flashpoint_Night.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/Media_RivalSkyline.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/Source_Candidate.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/Source_Candidate_candidate2.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/StartupRow_Flashpoint.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/TechCore_Rivals_Aerial.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Review/UnicornHeights_View.png`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/Flashpoint_Higgsfield_Raw.glb`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/Flashpoint_Higgsfield_Raw_candidate2.glb`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/candidate1_rejection.md`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/generation.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/generation_candidate1.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/generation_candidate2.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/production_notes.md`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/slot_contract.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/source_audit.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/Source/source_audit_candidate2.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/acceptance.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/export_verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/final_metrics.json`
- `Assets/Atlantis/Phase5/RivalHQs/Flashpoint/integration_verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Blender/Atlantis_NorthwindLabs_HQ_v1.blend`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Blender/Before_Northwind.blend`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Blender/Integration_Candidate.blend`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Export/Atlantis_NorthwindLabs_HQ_v1.glb`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/Media_RivalSkyline.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/NorthwindLabs_Day.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/NorthwindLabs_Night.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/Northwind_TechApproach.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/Source_Candidate.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/TechCore_Rivals_Aerial.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Review/UnicornHeights_View.png`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Source/NorthwindLabs_Higgsfield_Raw.glb`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Source/generation.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Source/production_notes.md`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Source/slot_contract.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/Source/source_audit.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/acceptance.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/export_verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/final_metrics.json`
- `Assets/Atlantis/Phase5/RivalHQs/NorthwindLabs/integration_verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/PROGRESS.md`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Blender/Atlantis_PallasAI_HQ_v1.blend`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Blender/PallasAI_Integration_Candidate.blend`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Blender/cleanup_audit.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Export/Atlantis_PallasAI_HQ_v1.glb`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/Media_RivalSkyline.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/PallasAI_Day.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/PallasAI_Night.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/Source_Candidate.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/Source_Candidate_candidate2.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/TechCore_Rivals_Aerial.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/UnicornHeights_View.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Review/Venture_Pallas.png`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/PallasAI_Higgsfield_Raw.glb`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/PallasAI_Higgsfield_Raw_candidate2.glb`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/candidate1_rejection.md`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/generation.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/generation_candidate1.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/generation_candidate2.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/production_notes.md`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/slot_contract.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/source_audit.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/Source/source_audit_candidate2.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/acceptance.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/export_verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/final_metrics.json`
- `Assets/Atlantis/Phase5/RivalHQs/PallasAI/integration_verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Atlantis_Master_Aerial.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Flashpoint_CommerceApproach.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Flashpoint_TechApproach.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Media_RivalSkyline.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Northwind_TechApproach.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Rivals_Architecture_Day.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Rivals_Architecture_Night.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/StartupRow_Flashpoint.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/TechCore_Rivals_Aerial.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/UnicornHeights_View.png`
- `Assets/Atlantis/Phase5/RivalHQs/Review/Venture_Pallas.png`
- `Assets/Atlantis/Phase5/RivalHQs/acceptance.json`
- `Assets/Atlantis/Phase5/RivalHQs/build_flashpoint.py`
- `Assets/Atlantis/Phase5/RivalHQs/build_northwind.py`
- `Assets/Atlantis/Phase5/RivalHQs/build_pallas.py`
- `Assets/Atlantis/Phase5/RivalHQs/final_metrics.json`
- `Assets/Atlantis/Phase5/RivalHQs/finalize_exports.py`
- `Assets/Atlantis/Phase5/RivalHQs/inspect_source.py`
- `Assets/Atlantis/Phase5/RivalHQs/integrate_flashpoint.py`
- `Assets/Atlantis/Phase5/RivalHQs/integrate_northwind.py`
- `Assets/Atlantis/Phase5/RivalHQs/integrate_pallas.py`
- `Assets/Atlantis/Phase5/RivalHQs/pallas_probe.py`
- `Assets/Atlantis/Phase5/RivalHQs/preservation_baseline.json`
- `Assets/Atlantis/Phase5/RivalHQs/review_final.py`
- `Assets/Atlantis/Phase5/RivalHQs/review_next.py`
- `Assets/Atlantis/Phase5/RivalHQs/review_pallas.py`
- `Assets/Atlantis/Phase5/RivalHQs/source_preservation.json`
- `Assets/Atlantis/Phase5/RivalHQs/verification.json`
- `Assets/Atlantis/Phase5/RivalHQs/verify_final.py`
- `Assets/Atlantis/Phase5/RivalHQs/write_report.py`
- `Documentation/Atlantis/PHASE5_RIVAL_HQ_PRODUCTION_REPORT.md`
