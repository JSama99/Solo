# Atlantis Phase 6 — Startup Row

Blender/world-production milestone. No app/runtime integration.

## Prior state inspected

Phase 5 contained 13 visible Startup building masses: eight generic StartupRow_Block objects, four Startup_Block_A–D module masses, and the unassigned RivalHQ_Slot_01 mass. The latter is a legacy planning reservation, not a fourth canonical rival. Its locator remains preserved, with no invented company assignment. Existing module and rival parcel display meshes are hidden in Phase 6; their geometry and metadata remain intact.

The eight generic blocks measured 32 × 27.2 m and approximately 13.83–29.97 m high. The four module masses measured 35.75 × 29.25 m at 22, 27, 32 and 37 m. Their reserved parcels are 55 × 45 m. The legacy rival mass measured 33.8 × 39 × 24 m on a 52 × 60 m reservation. Exact object inventory, transforms and bounds are in prior_state.json.

Startup Row bounds remain X −720…−200 m, Y −540…−140 m: 520 × 400 m, 208,000 m². Terrain stays at Z=14 m. Existing road surfaces are raised approximately 15.15–16.35 m; new building entrance levels are Z=15.4 m, with foundations reaching the existing terrain. New sidewalks and paths have solid bases rather than floating slabs.

## Founder → Startup → Tech route

The original bending route is preserved: Founder Garage (−875,−1030,8) → local neighborhood spine → connector at (−790,−660) → main bridge → Startup arrival (−610,−490) → boulevard bend (−460,−400) → eastern junction (−190,−270) → Tech approach (−170,−80) → (0,100) → (50,300). No bridge, original road mesh or Founder building was altered. The approach itself already provided the non-straight connection; Phase 6 makes the destination and architectural progression legible.

Arrival has four/five-story brick and mixed-use contexts plus a café. Coworking glazing, storefront canopies, maker doors and a pocket park create the next step. The cross street supports a shared-office core. The research lane leads to three moderate anchors and the premium Big Building planning context. More restrained brick and concrete give way to pale concrete, larger shared floorplates and upper setbacks. Tech Core remains substantially taller beyond the district.

| Road / walk | Width | Treatment |
|---|---:|---|
| Preserved Startup progression boulevard | 26 m | Original geometry and bends; new bounded side walks |
| Preserved Startup cross street and link | 14 m | Original geometry; crossing marks and curb transitions |
| New research lane and north access | 12 m | Limited access to maker, incubator and office frontage |
| New southern local lane | 10 m | Short bent access for southern lots; no major-network change |
| New road-side sidewalks | 5 m | Trees toward curb side, clear central walking area |
| Building frontage paths | 3 m | Routed around neighboring footprints, grades ≤5% |

The 26 m main boulevard remains wider than local streets. It does not widen further inside Tech Core in this pass: the existing road hierarchy is preserved. The transition is expressed through architecture and the increasing presence of Tech Core, rather than an unauthorized road redesign.

## Building kit and block organization

| Reusable typology | Realized buildings | Architectural role |
|---|---:|---|
| Startup_AnchorMidrise | 2 | Nine/twelve-story anchor with upper setback |
| Startup_Cafe | 3 | One-story public-facing meeting shell |
| Startup_Cowork_A | 4 | Broad glazing, upper setback and terrace |
| Startup_Cowork_B | 2 | Taller shared-office variant with accessible lobby cue |
| Startup_Incubator | 1 | Eight-story event/research anchor with broad side glazing |
| Startup_LabSmall | 3 | Compact technical workspace exterior |
| Startup_MakerSpace | 1 | Six-metre ground-floor volume, workshop doors and rooflights |
| Startup_MixedUse_A | 8 | Brick edge with storefront awnings |
| Startup_MixedUse_B | 2 | Six-story mixed-use startup frontage |
| Startup_Office_A | 10 | Compact four/five-story office rhythm |
| Startup_Office_B | 2 | Seven-story office frontage |

There are 38 buildings: 35 workplace/mixed-use buildings plus three café shells. Most workplace contexts are 3–8 stories. The three anchors are 8, 9 and 12 stories, approximately 32.6, 36.6 and 48.6 m to the principal roof. Roof equipment is counted separately in conservative envelope checks. No new building approaches the 75 m Flashpoint or other rival HQ heights.

Measured building height above entrance ranges from 4.9 to 48.6 m including the highest modeled element.

The kit repeats 4 m floor heights, window bands, facade frames, storefronts, roof caps, canopies, terrace rails and signage. Maker ground-floor height is 6 m. Variation comes from finish, story count, setbacks, rooflights, awnings, gardens and orientation. There are no interiors, occupiable roof mechanics or unique hero assets. No Higgsfield jobs or credits were used.

Average realized building footprint: 30.0 × 22.7 m. This measures building footprints, not cadastral city blocks. The two northern rows form a research-lane band; a cross-street band forms the core; angled arrival frontage follows the boulevard; a small southern lane serves the southern band. The minimum gap between buffered building envelopes is 11.0 m.

## Public spaces and walking preparation

Four small spaces are provided: Arrival Forecourt (22 × 16 m), Core Courtyard (42 × 34 m), Pocket Park (44 × 40 m), and Launch Court (36 × 22 m). Each uses simple paving, seating and planting geometry. Café shells sit near arrival, the core and the eastern edge for future founder/investor meetings. No furniture micro-detail or café interiors were built.

All 38 frontages have recorded 3 m paths to a street-side walk, using footprint-aware routes and a maximum 5% new-path grade. Trees are placed toward the curb side of the 5 m sidewalk, keeping its central strip open. New paths and foundations address raised Phase 0 road elevations. Cross-street markings are flush overlays with short curb transitions. These are geometric planning checks, not a navmesh, collision simulation, accessibility certification or proof of continuous walking over every existing city surface. Existing bridge and Founder connector geometry remain unchanged and will need collision treatment when walking is implemented.

## Progression parcels — planning only

| Slot | Position (m) | Context / stories | Planning footprint | Placement reason |
|---|---|---|---|---|
| Progression_Loft | [-602, -444, 15.4] | Startup_MixedUse_A / 4 | 34 × 26 m | First professional address at bridge arrival |
| Progression_SmallOffice | [-620, -307, 15.4] | Startup_Office_A / 5 | 34 × 26 m | First formal cross-street office frontage |
| Progression_Office | [-450, -307, 15.4] | Startup_Cowork_B / 7 | 32 × 30 m | Core coworking and shared-service intersection |
| Progression_SmallBuilding | [-500, -220, 15.4] | Startup_AnchorMidrise / 9 | 42 × 34 m | Research lane anchor with an independent forecourt |
| Progression_BigBuilding | [-350, -220, 15.4] | Startup_AnchorMidrise / 12 | 42 × 34 m | Premium transition edge inside Startup, outside prime Tech Core |

### Full realized building placement table

| Building | Typology | Center XY (m) | Stories | Roof height above entrance (m) | Placement role |
|---|---|---|---:|---:|---|
| LoftContext | Startup_MixedUse_A | [-602, -444] | 4 | 17.9 | First professional address at bridge arrival |
| SmallOfficeContext | Startup_Office_A | [-620, -307] | 5 | 20.6 | First formal cross-street office frontage |
| OfficeContext | Startup_Cowork_B | [-450, -307] | 7 | 29.9 | Core coworking and shared-service intersection |
| SmallBuildingContext | Startup_AnchorMidrise | [-500, -220] | 9 | 36.6 | Research lane anchor with an independent forecourt |
| BigBuildingContext | Startup_AnchorMidrise | [-350, -220] | 12 | 48.6 | Premium transition edge inside Startup, outside prime Tech Core |
| IncubatorAnchor | Startup_Incubator | [-650, -220] | 8 | 33.9 | Western research lane meeting/event anchor |
| ArrivalCafe | Startup_Cafe | [-642, -456] | 1 | 4.9 | Small social shell at arrival |
| CoreCafe | Startup_Cafe | [-504, -371] | 1 | 4.9 | Founder/investor courtyard meeting shell |
| LaunchCafe | Startup_Cafe | [-306, -380] | 1 | 4.9 | Networking shell on the eastern progression edge |
| Building_00 | Startup_Cowork_A | [-566, -415] | 5 | 21.9 | Founder arrival frontage |
| Building_02 | Startup_Office_A | [-563, -509] | 4 | 16.6 | Founder arrival frontage |
| Building_03 | Startup_MixedUse_A | [-519, -485] | 4 | 17.9 | Founder arrival frontage |
| Building_04 | Startup_Cowork_B | [-473, -457] | 6 | 25.9 | Founder arrival frontage |
| Building_05 | Startup_MixedUse_A | [-670, -307] | 4 | 17.9 | Cross-street active frontage |
| Building_06 | Startup_Cowork_A | [-570, -307] | 5 | 21.9 | Cross-street active frontage |
| Building_07 | Startup_LabSmall | [-500, -307] | 5 | 20.6 | Cross-street active frontage |
| Building_08 | Startup_Office_A | [-400, -307] | 4 | 16.6 | Cross-street active frontage |
| Building_09 | Startup_MixedUse_A | [-350, -307] | 4 | 17.9 | Cross-street active frontage |
| Building_10 | Startup_MakerSpace | [-590, -220] | 3 | 15.6 | Research-lane workplace band |
| Building_12 | Startup_Office_B | [-446, -220] | 7 | 28.6 | Research-lane workplace band |
| Building_13 | Startup_Cowork_A | [-398, -220] | 5 | 21.9 | Research-lane workplace band |
| Building_14 | Startup_Office_A | [-695, -170] | 4 | 16.6 | Northern pedestrian research court |
| Building_15 | Startup_MixedUse_A | [-600, -170] | 4 | 17.9 | Northern pedestrian research court |
| Building_16 | Startup_Office_A | [-548, -170] | 4 | 16.6 | Northern pedestrian research court |
| Building_17 | Startup_MixedUse_A | [-495, -170] | 4 | 17.9 | Northern pedestrian research court |
| Building_18 | Startup_Office_A | [-442, -170] | 4 | 16.6 | Northern pedestrian research court |
| Building_19 | Startup_LabSmall | [-395, -170] | 5 | 20.6 | Northern pedestrian research court |
| Building_21 | Startup_MixedUse_A | [-685, -388] | 4 | 17.9 | Founder arrival frontage |
| Building_22 | Startup_Office_A | [-680, -470] | 4 | 16.6 | Founder arrival frontage |
| Building_23 | Startup_Office_A | [-405, -495] | 4 | 16.6 | Southern local-lane workplace band |
| Building_24 | Startup_MixedUse_B | [-350, -495] | 6 | 25.9 | Southern local-lane workplace band |
| Building_25 | Startup_Office_A | [-290, -495] | 4 | 16.6 | Southern local-lane workplace band |
| Building_26 | Startup_MixedUse_A | [-235, -495] | 4 | 17.9 | Southern local-lane workplace band |
| Building_27 | Startup_LabSmall | [-405, -437] | 5 | 20.6 | Southern local-lane workplace band |
| Building_28 | Startup_Cowork_A | [-350, -430] | 5 | 21.9 | Southern local-lane workplace band |
| Building_29 | Startup_Office_B | [-290, -438] | 7 | 28.6 | Southern local-lane workplace band |
| Building_30 | Startup_MixedUse_B | [-235, -425] | 6 | 25.9 | Southern local-lane workplace band |
| Building_31 | Startup_Office_A | [-250, -370] | 4 | 16.6 | Southern local-lane workplace band |

These empties are environmental reservations with planning_only=true and runtime_binding=none. They describe a building context, not a new unlock condition, player-owned asset or canonical progression rule. Founder Garage remains the starting location outside Startup Row. Big Building stays inside Startup Row, approximately 165 m south of the nearest Tech Core boundary, rather than occupying prime Tech Core.

| Consecutive progression locations | Direct center distance |
|---|---:|
| Progression_Loft → Progression_SmallOffice | 138.2 m |
| Progression_SmallOffice → Progression_Office | 170.0 m |
| Progression_Office → Progression_SmallBuilding | 100.3 m |
| Progression_SmallBuilding → Progression_BigBuilding | 150.0 m |

All pairwise progression distances are recorded in spatial_audit.json. These are direct distances, not computed walking-route lengths.

| Spatial relationship | Direct distance |
|---|---:|
| Founder Garage → Startup core | 763.5 m |
| Startup core → Tech Core center | 874.0 m |
| Startup core → nearest Tech Core boundary | 440.6 m |
| Startup core → Spire | 958.5 m |
| Startup core → Flashpoint | 938.4 m |

Startup core is defined at [-500, -365, 15.4]. The existing bent centerline from Garage to the Tech approach is approximately 1755.5 m, including the bridge; it is distinct from the direct distances above.

## Sightlines and visual review

| Established camera | Phase 5 Spire crown samples | Phase 6 samples |
|---|---:|---:|
| Founder_To_City | 36 | 36 |
| TheSpire_StartupSightline | 38 | 38 |
| VentureHall_ToSpire | 43 | 43 |
| MediaDistrict_ToSpire | 39 | 39 |
| TechCore_Skyline | 39 | 39 |
| UnicornHeights_View | 45 | 45 |

All six protected Spire views are unchanged. StartupRow_Flashpoint retains 10/12 visible samples: Strong. The canonical Founder and Startup views still show the Spire crown above the city. Pre-existing Tech Core blocks obscure portions of the lower Spire; Phase 6 does not claim a fully unobstructed tower or change those blocks.

The district is more urban than Founder through multi-story facades, defined sidewalks and social nodes, but remains less monumental than Tech Core. Flashpoint is a visible successful company beyond Startup Row from the eastern review view; it is not visible from every interior street. The Spire remains the primary distant aspiration. No text labels are needed to distinguish the low Founder massing, mid-rise startup district and taller corporate skyline.

New review cameras: StartupRow_Aerial, Founder_To_Startup, Startup_To_TechCore, Startup_MainBoulevard, Startup_Core, Startup_ProgressionParcels and Startup_NightPreview. Every original planning camera is preserved. Reviews cover Atlantis aerial, Founder arrival and protected corridor, main boulevard, core, Spire approach, progression parcels, Flashpoint and day/night. Night identity uses restrained lobby signs and selected office-window glow, with no runtime time-of-day system.

## Before / after technical metrics

| Metric | Phase 5 | Phase 6 |
|---|---:|---:|
| Visible masterplan triangles | 8,824 | 40,580 |
| Visible masterplan meshes | 368 | 493 |
| Startup building count | 13 masses | 38 buildings |
| Startup building meshes | 13 | 76 |
| Startup building triangles | 156 | 17,400 |
| New building material families | — | 9 |
| Full new district material families | — | 12 |
| New district textures | — | 0 |

Visible masterplan delta: +31,756 triangles. Hidden raw sources, old disabled blockouts and kit prototypes are excluded consistently from these visible-scene counts. Phase 5 including staging was 127,071 triangles; comparing that total with visible Phase 6 would be misleading.

The editable kit has 11 typologies and 157 reusable dimension/material components. Consolidation reduces 1450 building pieces to 76 objects while preserving a separate signage object per building. Repeated consolidated architecture shares 26 mesh datablocks; the complete building set uses 28 unique mesh datablocks including signage. Public geometry is grouped into 67 material/spatial cells. Hidden prototypes retain the original component construction.

The independent review GLB contains 31,972 triangles, 143 meshes, 12 materials, no textures, and 2,030,292 bytes. It includes only Phase 6 building/public-realm geometry and progression planning empties, not the entire city or original road surfaces. It preserves world placement and is a review asset, not RealityKit production output. Building roots remain independent for future LOD and district loading; no LODs were authored.

## Validation and preservation

21/21 automated checks passed across verification.json, export_verification.json and spatial_audit.json. 370 protected file hashes match the Phase 6 baseline. All original Phase 5 object geometry, local transforms, parent links, custom metadata and material references match. Only Startup placeholder/parcel display visibility changes; no old object is deleted.

Preserved: Phase 0 geography and all district boundaries; bay/water; three bridges; every original road; Founder Garage slot; Spire; Venture Hall; Tech.com; Signal TV; Pallas; Northwind; Flashpoint; all other districts and player Unicorn slots. Phase 0–5 files remain untouched. Garage/app runtime, GameStore, progression rules and saves remain untouched. Existing dirty app/project/test changes were preserved. No commits or pushes.

An intermediate shared-datablock consolidation error was caught by failed geometry/sightline checks, corrected by copying the active mesh before joining, and rebuilt from Phase 5. The final checks and renders are from the corrected scene. Python site-planning issues were corrected before acceptance.

Verification is Blender geometry, spatial planning, GLB reimport and visual review. No Xcode build, XCTest, simulator or device run was performed for this asset-only task. Walking collisions, navigation, GPU performance and RealityKit loading remain future implementation/device acceptance work.

## Required acceptance answers

1. **Yes** — Startup Row now functions as a believable early-stage startup district at this exterior planning level: coworking, offices, maker/incubator spaces, mixed-use edges and social shells replace generic masses.
2. **Yes** — the Founder → Startup → Tech route communicates growth through increasingly urban frontage and rising architectural scale while retaining the Spire aspiration.
3. **Yes** — Loft, Small Office, Office, Small Building and Big Building have credible distinct planning contexts without new runtime progression logic.
4. **Yes** — the separable, efficient modular district is technically suitable as a basis for future walking, LODs and RealityKit loading. Those runtime systems are not implemented or performance-validated here.

## File inventory

- `Assets/Atlantis/Phase6/StartupRow/Blender/Atlantis_Phase6_Masterplan.blend`
- `Assets/Atlantis/Phase6/StartupRow/Export/Atlantis_Phase6_StartupRow_Review.glb`
- `Assets/Atlantis/Phase6/StartupRow/PROGRESS.md`
- `Assets/Atlantis/Phase6/StartupRow/Review/Atlantis_Master_Aerial.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Founder_To_Startup.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/StartupRow_Aerial.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/StartupRow_Flashpoint.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Startup_Core.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Startup_Day.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Startup_MainBoulevard.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Startup_Night.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Startup_ProgressionParcels.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/Startup_To_TechCore.png`
- `Assets/Atlantis/Phase6/StartupRow/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase6/StartupRow/__pycache__/inspect.cpython-314.pyc`
- `Assets/Atlantis/Phase6/StartupRow/acceptance.json`
- `Assets/Atlantis/Phase6/StartupRow/build.py`
- `Assets/Atlantis/Phase6/StartupRow/build_audit.json`
- `Assets/Atlantis/Phase6/StartupRow/connectivity.py`
- `Assets/Atlantis/Phase6/StartupRow/export_check.py`
- `Assets/Atlantis/Phase6/StartupRow/export_verification.json`
- `Assets/Atlantis/Phase6/StartupRow/inspect.py`
- `Assets/Atlantis/Phase6/StartupRow/optimization.json`
- `Assets/Atlantis/Phase6/StartupRow/optimize.py`
- `Assets/Atlantis/Phase6/StartupRow/plan.py`
- `Assets/Atlantis/Phase6/StartupRow/preservation_baseline.json`
- `Assets/Atlantis/Phase6/StartupRow/prior_state.json`
- `Assets/Atlantis/Phase6/StartupRow/review.py`
- `Assets/Atlantis/Phase6/StartupRow/site_plan.json`
- `Assets/Atlantis/Phase6/StartupRow/spatial_audit.json`
- `Assets/Atlantis/Phase6/StartupRow/spatial_audit.py`
- `Assets/Atlantis/Phase6/StartupRow/verification.json`
- `Assets/Atlantis/Phase6/StartupRow/verify.py`
- `Assets/Atlantis/Phase6/StartupRow/write_report.py`
- `Documentation/Atlantis/PHASE6_STARTUP_ROW_REPORT.md`
