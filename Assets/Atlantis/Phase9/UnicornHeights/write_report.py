"""Generate the Phase 9 handoff from measured verification data."""
from pathlib import Path
import json,math,hashlib
R=Path(__file__).resolve().parent;repo=R.parents[3];V=json.loads((R/'verification.json').read_text());A=json.loads((R/'build_audit.json').read_text());P=json.loads((R/'site_plan.json').read_text())
assert all(V['checks'].values())
report=repo/'Documentation/Atlantis/PHASE9_UNICORN_HEIGHTS_REPORT.md'
def link(p,label=None):return f'[{label or p.name}](<{p.resolve()}>)'
rows='\n'.join(f"| {a['id']} | {a['typology']} | {a['position'][0]}, {a['position'][1]} | {a['width']} × {a['depth']} | {V['measured_heights'][a['id']]:.2f} |" for a in P['sites'])
metrics='\n'.join(f"| {label} | {V['phase8_metrics'][key]:,} | {V['phase9_metrics'][key]:,} | {V['phase9_metrics'][key]-V['phase8_metrics'][key]:+,} |" for key,label in [('triangles','Visible scene triangles'),('meshes','Visible scene mesh objects'),('materials','Visible scene materials'),('vegetation_objects','Visible vegetation mesh objects')])
checks='\n'.join(f'- PASS — `{n}`' for n in V['checks'])
files=sorted(p for p in R.rglob('*') if p.is_file())+[report]
filelist='\n'.join('- '+link(p,str(p.relative_to(repo))) for p in files)
views=[('Atlantis_Master_Aerial','Whole-city progression; low-rise Founder and Startup districts transition to Commerce, dense Tech Core and the landscaped headland.'),('UnicornHeights_Aerial','Eight independent campuses, broad open ground, simple road and reserved player parcel.'),('Unicorn_Approach','Elevated view from the Tech Core bridge approach; shows the campus arrival sequence. This is not a walking camera.'),('UnicornHeights_Entry','Standing eye height: landscaped setback, restrained entry and road scale.'),('UnicornHeights_MainBoulevard','Standing eye height: clear 5 m walk, planted verge and 16 m road.'),('PlayerHQ_Slot_Hero','Empty 140 × 115 m reserved lawn beside Founder Plaza; no final HQ massing.'),('Unicorn_FounderPlaza','Standing eye height: open event floor, perimeter seating, campus entrances.'),('Unicorn_CampusReview','Standing eye height: modular facade, lobby and frontage scale.'),('Unicorn_ScenicOverlook','Standing eye height: The Spire remains the city anchor across the open foreground.'),('PlayerHQ_To_Spire','Standing eye height at the player frontage: readable Spire crown and Tech Core skyline.'),('Unicorn_To_TechCore','Standing eye height: denser city skyline seen from the landscaped district edge.'),('Unicorn_WalkingRoute','Standing eye height: connected plaza approach with fixtures outside the route.'),('Unicorn_Day','Day comparison from the night-preview camera.'),('Unicorn_Night','Restrained lobby glow and landscape fixtures; no animated or runtime lighting.')]
viewlist='\n'.join('- '+link(R/'Review'/f'{n}.png',n)+' — '+note for n,note in views)
text=f'''# Atlantis Phase 9 — Unicorn Heights and Player HQ reservation

Status: **complete as a bounded Blender world-production milestone**. Current verification: **{sum(V['checks'].values())}/{len(V['checks'])} checks passed**. Human simulator/device acceptance, runtime walking, and RealityKit performance remain untested.

Masterplan: {link(R/'Blender/Atlantis_Phase9_Masterplan.blend')}. Input: Phase 8 masterplan, preserved byte-for-byte. No runtime code, simulation, saves, entitlements, project membership, or scheme changes were introduced. No final player HQ, navmesh, LODs, GLB export, Higgsfield assets, or paid generation were created.

## Inspect and proposal

The inherited district is centered at (820, 960, 85), with Phase 0 bounds X 510–1130 and Y 760–1160: **620 × 400 m**, or 24.8 hectares. The existing raised headland has its plateau at Z 85 m and terrain bounds X 410–1240, Y 640–1270, Z −12–85. Its polygon is irregular; all new path surfaces and campus footprints were checked against the actual polygon and district bounds. Terrain and shoreline were not reshaped.

Prior massing comprised four generic blocks, three supporting HQ placeholders (117, 124 and 131 m), and one 155 m player placeholder. The existing player parcel was already 140 × 115 m at (970, 850, 85), with a 180 m maximum bounding-box height. The original 24 m Heights Boulevard followed a 580.5 m diagonal internal route; it did not provide the authored campus sidewalk/plaza network now present. Bridge_TechCore climbs from (360, 470, 15) to (600, 760, 86). Tech Core is southwest; the headland overlooks the city and bay.

The adopted proposal was eight generic campuses, seven reusable types, broad lawns, a simpler southern arrival boulevard, a separate Founder Plaza west of the player parcel, and an overlook on the southwest side. No new canonical rivals were named. The previous internal Heights Boulevard, eight old massings and four old parcel display meshes are retained with visibility disabled in Phase 9. All original geometry, transforms, hierarchy and custom properties are preserved; only these local visibility states change. Existing cameras are preserved.

## District and architecture

The campuses use restrained blue-green glass, pale stone podiums and vertical piers, muted metal floor bands, sheltered lobby entrances and planted roof planes. Seven parameterized kit types share one architectural family. CampusTower_A is reused twice; the other types vary footprint, height and proportions. This is exterior modular production geometry, not interior architecture or final photoreal art.

| Campus | Reusable type | World XY (m) | Podium footprint (m) | Measured height above Z 85.6 (m) |
|---|---|---|---|---|
{rows}

Six supporting buildings fall in the **40.24–76.24 m** range; the two supporting anchors are **112.24 and 124.24 m**. Roof planting adds 0.24 m to nominal kit height. All are below Pallas's 160 m asset height. The highest supporting roof is approximately Z 209.84; The Spire reaches Z 294 (280 m above its Z 14 base). Plateau elevation is included in this hierarchy assessment.

Combined campus footprint is **{V['campus_footprint_area_m2']:,} m²**, or **{V['campus_coverage_percent']:.2f}%** of district area. Minimum conservative footprint gap is **{V['minimum_campus_gap_m']:.2f} m**. Supporting density is 0.323 buildings/hectare. For comparison, the Phase 0 Tech Core inventory alone lists 19 generic buildings over 39.65 hectares, or 0.479/hectare, before its landmark/rival sites. The headland therefore achieves its identity through spacing, landscape and elevated views rather than taller or more numerous towers.

Landscape consists of an inset ground lawn, campus lawns, planted roof planes, **{A['vegetation_count']} trees** sharing one faceted canopy mesh, a 32 × 10 m reflecting-pool surround, seating and seven subtle landscape light targets. The lawn outline follows the headland rather than covering a rectangular area outside the land. Vegetation and fixtures avoid the defined pedestrian route centers; the tree canopies sit above walking height.

## Dimensions and movement

| Item | Dimension / placement |
|---|---|
| District bounds | X 510–1130; Y 760–1160 |
| Terrain plateau | Z 85 m; no terrain edits |
| Main pedestrian datum | Z 85.6 m |
| Arrival road | 16 m wide; 498 m main straight plus 15 m entry turn |
| Main boulevard walk | 5 m wide, north side of road |
| Campus spine / plaza approach | 6 m wide |
| Supporting frontage walks | 4 m wide; 6 × 3 m entry aprons |
| All authored path widths | 4–6 m |
| Founder Plaza | 80 × 70 m; center (850, 850, 85.6) |
| Scenic overlook | 44 × 32 m; center (560, 825, 85.6) |
| Reflecting pool | 32 × 10 m surround; 30 × 8 m water surface |
| Player parcel | 140 × 115 m; X 900–1040, Y 792.5–907.5 |
| Player growth envelope | 140 × 115 × 180 m; world Z 85–265 |
| Player → Spire origin | 1,015.53 m horizontal; approximately {math.dist((970,850,85),(50,420,14)):.2f} m in 3D |
| Player → Tech Core boundary | 651.50 m horizontal, nearest bounds corner (355, 635) |
| Player → Founder District boundary | 2,161.05 m horizontal, nearest bounds corner (−600, −635) |
| Player → Founder District center | 2,490.46 m horizontal |

Distances are straight-line planning distances, not walking-route lengths. The Founder side is part of the wider city relationship; the Garage itself is not promised to be recognizable from the player parcel at this distance.

The intended sequence is Tech Core bridge → landscaped district entry → southern boulevard → west-side Founder Plaza / south frontage → reserved HQ. The northern campus paths and western garden route connect every campus, the plaza, player frontage and overlook in one tested network. Campus paths are level except the bridge landing connector; all new pedestrian grades are under 5%. The short road landing drops 0.744 m over 15 m (4.96%). No gates or fenced compounds obstruct these routes.

The pedestrian bridge landing is matched to the actual tilted source deck at **({V['bridge_walk_landing'][0]:.3f}, {V['bridge_walk_landing'][1]:.3f}, {V['bridge_walk_landing'][2]:.3f})**, with a specific geometric alignment check. The original bridge still rises 71 m over approximately 376.43 horizontal metres: **18.86% grade**. That inherited condition remains unresolved for future controller, accessibility and traversal design. Local path connectivity and a matched landing do not certify citywide runtime walkability. The bridge and its piers were not altered.

## Canonical player HQ contract

`Player_UnicornHQ_Slot` retains world origin **(970, 850, 85)**, rotation **(0°, 0°, 0°)** and forward **−Y in Blender / +Z after glTF conversion**. One Blender unit is one metre. It remains the placement authority. The source parcel and old 155 m massing remain hidden for traceability; a removable reserved lawn occupies the footprint. No permanent supporting campus enters it.

The original 180 m cap is retained instead of increasing it to 220 m. A 220 m asset on this 85 m plateau would reach Z 305, above The Spire's Z 294 crown. Use approximately **140–180 m** for future design exploration, with **180 m including roof equipment, signage, crowns and upgrades** as this pass's maximum. A final asset must remain within X 900–1040, Y 792.5–907.5, Z 85–265 and undergo its own full skyline review. Current checks demonstrate the empty parcel's views, not a future tower's occlusion behavior.

Added planning children preserve the original slot metadata:

| Child | Local position (m) | Contract |
|---|---|---|
| PlayerHQ_Parcel | (0, 0, 0) | 140 × 115 m plan footprint |
| PlayerHQ_Forward | (0, −57.5, 0) | −Y entrance/frontage direction |
| PlayerHQ_PlazaAnchor | (−120, 0, 0.6) | Existing 80 × 70 m public plaza, outside the player parcel |
| PlayerHQ_SignageAnchor | (0, −54, 3) | Future identity target; nominal 18 × 0.2 × 2 m area |
| PlayerHQ_GrowthEnvelope | (0, 0, 90) | Center of the 140 × 115 × 180 m reserved volume |
| PlayerUnicornHQ_Signage_Main | Child of signage anchor | Empty locator for dynamic company identity |

These are semantic empties with metre-dimension properties; their small editor display cubes are not physical envelope geometry. A future importer must read the contract explicitly. The player parent is in the existing anchor collection; its new children belong to `Unicorn_PlayerContract`. A future district export must include the canonical parent with those children.

The footprint can accommodate a tower nested in a larger podium, an attached annex, forecourt, private garden and upgrades. Planning allowances stored on the growth anchor are a 64 × 58 m tower, 104 × 76 m podium, 28 × 44 m annex, 30 × 40 m garden and 110 × 22 m forecourt; these are design allowances to reconcile within the complete parcel, not independently packed fixed sub-parcels. The adjacent public plaza supplies additional event space. No final building shape is dictated by Phase 9.

Road access is from the southern boulevard; the 6 m south-frontage connector reaches the parcel at (970, 792.5, 85.6). A second 6 m pedestrian approach joins the west parcel edge at (900, 850, 85.6) from Founder Plaza. Future asset entrance floors should meet Z 85.6 while foundations use the Z 85 parcel origin. The building owns any remaining internal forecourt/ramp connection. Company name, founder name and logo are not baked into geometry.

Future state ownership can support empty → construction → completed → upgraded through this stable parent and reserved volume. No state machine or gameplay behavior is implemented. Every future variant must preserve the slot transform, public approaches, identity targets and height envelope.

## Review and preservation evidence

Fourteen images cover every requested category, including the additional district aerial and paired day/night views. Standing cameras use Z 87.3 m, approximately 1.7 m above the main pedestrian surface. The whole-city and district aerials use Workbench; perspective images use Cycles. The night comparison changes light energy in memory only, after saving the masterplan.

{viewlist}

The render review confirms a spacious campus district, readable facade/lobby scale, clear pedestrian corridors, an unbuilt endgame parcel and visible city hierarchy. Distant white/gray massing and the white plateau edge in perspective renders belong to the preserved masterplan; they are not new architecture. The Spire crown remains readable from the player frontage and scenic overlook. The original six protected camera sample counts are unchanged: 36 / 38 / 43 / 39 / 39 / 45. Startup Row's Flashpoint sample count remains 10. New player/overlook crown samples are {V['new_spire_views']['PlayerHQ_To_Spire']} / {V['new_spire_views']['Unicorn_ScenicOverlook']}.

Verification compares **{V['original_object_count']:,} original scene object signatures**: no geometry, transform, parent or custom-property changes. Original material node values and camera settings are checked. Only the named Unicorn placeholders, parcel displays and old internal boulevard change visibility. This preserves The Spire (280 m), Venture Hall (41.4 m), Tech.com (145 m), Signal TV (47 m), Pallas (160 m), Northwind (115 m), Flashpoint (75 m), Founder District, Startup Row, Commerce, Venture, Media, Tech Core, progression locations, bridges, water and city geography. There is no expansion into those districts.

**{V['protected_file_count']} protected files** were rehashed with SHA-256 and remained unchanged, including dirty app/test/project files and earlier Atlantis phases. Their pre-existing git changes are untouched. No commit or push was performed.

## Before / after efficiency

| Metric | Phase 8 | Phase 9 | Change |
|---|---:|---:|---:|
{metrics}
| Unicorn supporting buildings | 7 placeholder masses | 8 authored campuses | +1 |
| Player building masses visible | 1 placeholder | 0 | −1 |
| Unicorn building masses total | 8 | 8 | 0 |
| Unicorn reusable production types | 0 | 7 | +7 |
| Unicorn authored building components | 8 simple massing cubes | {A['authored_components']} kit components before consolidation | Different authoring detail |
| Unicorn production box module variants | 0 | {A['shared_box_modules']} | +{A['shared_box_modules']} |
| Unicorn vegetation meshes | 0 | {A['vegetation_count']*2} ({A['vegetation_count']} trunk/canopy pairs) | +{A['vegetation_count']*2} |

Whole-scene counts exclude hidden source placeholders and hidden kit prototypes. Triangle counts sum mesh polygon triangulations; they are not measured GPU cost. Vegetation counts include tree trunks/canopies and named shrubs consistently across phases. The 536 new campus components consolidate into architecture, lobby/occupied surfaces and semantic signage per campus: 24 independent campus render meshes. Previous district component inventories remain unchanged; the table isolates the authored Unicorn change instead of comparing Commerce's component count to a different district.

The scene adds approximately {(V['phase9_metrics']['triangles']/V['phase8_metrics']['triangles']-1)*100:.2f}% visible triangles. Trees share one canopy mesh and repeated boxes use cached geometry. Paving tops are unioned to remove coplanar overlap. Mesh count, material batches, collisions, loading latency, texture strategy and device GPU/memory behavior still require measurement in the separate RealityKit spike.

## Future runtime compatibility

The new hierarchy is nested under the existing `UnicornHeights` district as `Phase9_UnicornProduction`, with separate campuses, public realm, player contract, review cameras and hidden kit library. Supporting campuses have independent roots and local geometry; no cross-district parenting is introduced. Their shared material/mesh dependencies are local to the new kit. The canonical player parent remains an explicit export dependency as described above.

LOD0/LOD1/LOD2 can replace each campus independently; these LODs are not built. Day/night can target separate lobby surfaces and landscape fixtures. `Unicorn_CampusIdentity_01` through `_08` are generic semantic material targets; the player identity remains an empty locator. Morning/noon/evening can use the same non-baked materials and future environment lighting. Streaming requires export filtering to exclude hidden prototypes, source placeholders and review cameras. No RealityKit loader, runtime lighting, collision/navmesh, simulation authority or progression logic is added here.

## Validation results and limits

{checks}

During development the checks caught a northern route clipping a campus, an obstructing tree, and the need to align the landing to the tilted bridge rather than a bounding-box elevation; these were corrected. Image review caught obsolete diagonal internal-road geometry and poorly placed review cameras, which were corrected. The final file was reopened and checked. Blender 5.2.1 LTS emitted the inherited `Material.use_nodes` deprecation warning; it did not prevent saving, verification or rendering.

No Xcode build, XCTest, XCUITest, simulator, device, runtime walking, audio/haptics or RealityKit performance test was run for this Blender-only task. Visual judgments above are Blender image review, not human simulator acceptance.

## Required completion decisions

1. **Yes — credible endgame district.** Refined campus facades, low coverage, broad landscape, public arrival and elevated city views establish the endgame destination without new rival identities.
2. **Yes — more spacious and prestigious than Tech Core without competing with The Spire.** The district has eight well-separated campuses, a calm material palette and a lower supporting height range. Preserved city views and the world-elevation cap protect Spire dominance.
3. **Yes — precise enough for a future production HQ and progression states.** Position, forward direction, parcel, height limit, access floors, growth bounds and dynamic identity anchors are documented and saved. The exact HQ design remains open.
4. **Yes — full Founder Garage → Startup Row → Commerce → Tech Core → Unicorn Heights progression is visually supported.** The existing early and middle districts are preserved and the headland now supplies a clear final campus destination. This is a world-composition judgment, not certification of a traversable runtime route.
5. **Yes — structured enough to stop major Blender expansion and begin a separate RealityKit runtime/performance spike.** District separation, independent campus roots and measured geometry provide a concrete starting point. The spike must validate loading, traversal (especially the inherited bridge), collisions, LODs and device budgets before production integration.

## Phase 9 file inventory

All repository files added or modified by this pass are listed below. Earlier phase assets and app/project files were not modified.

{filelist}
'''
report.write_text(text)
print(report)
