"""Generate the handoff from current saved-scene measurements and assertions."""
from pathlib import Path
import json,math,collections,hashlib
R=Path(__file__).resolve().parent
P=json.loads((R/'site_plan.json').read_text());A=json.loads((R/'build_audit.json').read_text());V=json.loads((R/'verification.json').read_text());assert all(V['checks'].values())
roles={'EnterpriseOffice':'Customer-facing enterprise offices','Hotel':'Visiting customers, founders and conference guests','ServiceTower':'Business and professional services','MixedUse':'Retail/services with commercial offices','Conference':'Product showcases, summits and partnership events','Retail':'Support services and small commercial frontage','BusinessAnchor':'Generic established business anchor'}
groups={k:[a for a in P['sites'] if k in a['typology']] for k in roles}
rows=[]
for key,sites in groups.items():
 heights=[V['building_measured_heights'][a['id']] for a in sites];rows.append(f"| {key} | {len(sites)} | {min(heights):.2f}–{max(heights):.2f} m | {roles[key]} | Yes |")
metrics='\n'.join(f"| {k.replace('_',' ')} | {V['phase7_metrics'][k]:,} | {V['phase8_metrics'][k]:,} | {V['phase8_metrics'][k]-V['phase7_metrics'][k]:+,} |" for k in V['phase7_metrics'])
flash=(430,-240);dist={k:math.dist(flash,p) for k,p in {'Startup core':(-460,-340),'Tech Core center':(30,330),'Media center':(800,325),'Tech Core boundary':(355,25),'Media boundary':(615,110)}.items()}
filelist=sorted(str(p.relative_to(Path.cwd())) for p in R.rglob('*') if p.is_file())
report=f'''# Atlantis Phase 8 — Commerce District + Flashpoint Growth Corridor

Blender world-production pass. Date: 2026-09-10.

## Result

Commerce now has 15 authored supporting buildings across ten reusable types, plus the unchanged Flashpoint HQ: 16 visible district buildings in total. Three hotels, a broad conference shell, enterprise offices, service/mixed-use buildings, retail podiums and two taller anchors establish a commercial district around the existing roads. The customer plaza and Flashpoint forecourt are joined by a connected pedestrian network.

{len(V['checks'])}/{len(V['checks'])} current static checks pass. {V['protected_file_count']} protected files have unchanged SHA-256 hashes. Phase 7 was not overwritten. No app, simulation or RealityKit integration was performed. Human visual acceptance and future runtime performance remain separate.

## Initial audit

Commerce occupies X 50…550, Y −360…−20: 500 × 340 m, on the Central Peninsula at terrain Z=14 m. The input scene had 13 generic towers, 13 associated podium meshes and an 85 × 75 m low plaza block. Actual tower heights were 29.70–77.57 m. The original plaza was centered at (220, −170), partly crossing the cross-street footprint, with its surface below the road/pedestrian datum.

The canonical 24 m Commerce Boulevard already runs from (−190, −270) through (200, −340), (500, −150), (420, 40) to (0, 100), approximately 1,381.8 m overall. The Commerce cross street is 14 m wide and 450 m long at Y=−190. Commerce_Link is a 14 m secondary connection from (300, −190) to (420, 40). These existing road objects retain their geometry, transforms, materials and metadata.

Flashpoint remains at (430, −240, 14), facing −Y, within its 75 × 60 m reserved parcel. Its approved architectural footprint remains approximately 40 × 32 m, with the existing 75 m height. Its separate main sign, launch display, ticker and presentation profile remain canonical. The district sits on the peninsula rather than a new waterfront platform; the bay, shoreline, bridges and terrain remain unchanged.

The audit found broad massing and disconnected pedestrian space, rather than an established commercial frontage network. Only the 13 placeholder towers, their 13 podiums and the old Commerce plaza display are hidden in the new scene. All remain traceable; no original object was deleted or remodeled.

## Building strategy

| Type | Count | Measured height range above entrance | Primary role | Reusable? |
| --- | ---: | ---: | --- | --- |
'''+ '\n'.join(rows)+f'''

The dominant office/hotel/mixed-use range is 28.4–72.4 m. Two low retail shells are 12 m and the conference venue is 19.75 m. The northern business anchor and premium hotel reach 96.4 and 108.4 m, including roof equipment. Flashpoint remains noticeable at 75 m without becoming the tallest Commerce building. Every addition stays well below Pallas AI at 160 m and The Spire at 280 m.

Ten kit types are preserved in Commerce_KitLibrary: EnterpriseOffice_A/B, Hotel_A/B, ServiceTower_A, MixedUse_A/B, ConferenceCenter, RetailPodium_A and BusinessAnchor_A. {A['authored_components']:,} authored building components use {A['shared_box_modules']} shared dimension/material box modules. New buildings consolidate architecture and occupied surfaces while retaining signage objects separately. Repeated office bands, hotel window grids, facade fins, lobby podiums, canopies and roof components provide reuse; no new rival identity is introduced.

The palette uses limestone-like stone, silver metal, blue glazing, restrained warm hotel panels, neutral paving and small planting accents. Hotels have individual window rhythms and generic HOTEL lettering. The conference shell is 68 × 42 m, lower and broader than the towers, with roof spans, a clerestory and an event marquee. Ground floors have glazed storefront rhythms and entrance aprons at the public walking datum. These are exterior shells with no interiors.

## Public space and corridor

| Space | Approximate dimensions | Function | Connected streets |
| --- | --- | --- | --- |
| Customer Plaza | 82 × 70 m | Meetings, arrivals, networking and gathering | Commerce cross street; MarketWalk to Commerce_Link |
| Flashpoint Forecourt / Corridor | 142 × 22 m forecourt; 355.1 m diagonal boulevard segment | Launch/customer frontage and commercial growth context | Commerce Boulevard; Flashpoint approach to cross street |
| Event Venue Forecourt | 66 × 20 m | Conference arrivals and spill-out | Commerce cross street |

The 355.1 m growth segment runs between (200, −340) and (500, −150), beside Flashpoint. Offices and hotels frame this approach; Flashpoint retains its more dynamic silhouette and concentrated orange accent. The new forecourt ends outside the approved parcel. A graded 4 m approach meets its eastern edge at the existing 14.6 m parcel-surface datum. The original HQ, parcel mesh and display targets are not merged into Commerce geometry.

Customer Plaza uses simple seating with supports, planters and restrained fixture geometry. It is smaller and less ceremonial than Venture Hall's public space. Six raised crossing zones connect the arrival side, hotels, conference frontage, central market walk and Flashpoint side. Vehicle approach ramps are 6 m long, with maximum rise 0.25 m (4.17%); this is static geometry, not traffic behavior.

## Measurements and district transitions

- Primary boulevard: 24 m, unchanged.
- Secondary streets: 14 m, unchanged.
- Sidewalks: 4–5 m; plaza approach: 6 m.
- New walking segments: maximum 5% grade; all at least 4 m wide.
- Public walking datum: Z=15.4 m, with the graded Flashpoint parcel approach.
- Startup Row core → Flashpoint: {dist['Startup core']:.1f} m.
- Flashpoint → Tech Core center: {dist['Tech Core center']:.1f} m; nearest district boundary: {dist['Tech Core boundary']:.1f} m.
- Flashpoint → Media center: {dist['Media center']:.1f} m; nearest district boundary: {dist['Media boundary']:.1f} m.

Distances are horizontal straight-line measurements, not walking itineraries. Centers are Startup (−460, −340), Tech Core (30, 330) and Media (800, 325).

**Startup → Commerce:** the existing boulevard carries the approach from the Startup/progression side into wider commercial frontage, hotels and larger floorplates. Added sidewalks follow that road's immediate right-of-way rather than relocating city roads. Startup's buildings, five progression locations and pedestrian layout remain unchanged.

**Commerce → Tech Core:** taller, calmer Commerce anchors sit on the northern side; the existing boulevard continues toward the city-leading skyline. The new Tech Core review camera is near the northern Commerce edge, clear of nearby facades. The Spire remains the dominant distant landmark.

**Commerce → Media:** the boulevard/Commerce_Link approaches the unchanged Bridge_Media at (420, 40), leading to the Media Boulevard at (640, 110). Tech.com and Signal TV remain unchanged. No bridge, media district geometry or broadcast surface is modified.

**Commerce → Venture:** the established west junction at (−190, −270) connects with Venture Boulevard. Capital allocation and institutional space remain visually separate from Commerce's hotel, storefront and customer activity. Venture Hall and its plaza are unchanged.

These are current district connections and future routing foundations. The new Commerce pedestrian surfaces form one connected planar network; a continuous playable city-wide route, bridge-side collision details and inter-district locomotion are not implemented or certified.

## Human-scale and visual review

Thirteen review images cover Atlantis aerial, Commerce aerial, the Startup entry, main boulevard, Flashpoint corridor and close context, customer plaza, conference venue, hotel corridor, Tech Core direction, Media direction and matching day/night previews. Eleven new camera objects are present, including all eight requested names; existing cameras are preserved exactly. Street cameras generally sit at Z=17.1 m, 1.7 m above the public walking surface.

Review corrections included two disconnected sidewalk branches (now joined by raised crossings), a planter and pole intruding into a frontage path, a diagonal approach overlapping Flashpoint's parcel edge, camera/mesh name collisions, a Tech Core camera too close to a facade, and overlapping coplanar paving. Paving tops are consolidated with Blender's constrained triangulator, preserving grades and skirts while eliminating duplicate top faces. Review cameras now assert CAMERA type, not just name existence.

The commercial reading comes from repeated glazed offices, distinct hotel window grids, a broad conference entrance, storefront podiums and customer space. Flashpoint is framed by supporting development rather than isolated among blank Commerce blocks. Prior districts' remaining skyline placeholders are intentionally preserved; they remain visible in some distant views.

Night readiness is represented by separate hotel-window, lobby, storefront, signage and plaza-fixture surfaces. The Blender night preview retains occupied commercial entries and Flashpoint's unchanged orange identity. No runtime time phases, actual light scheduling or comparison of device illumination is claimed.

## Performance: saved Phase 7 → saved Phase 8

| Metric | Phase 7 | Phase 8 | Delta |
| --- | ---: | ---: | ---: |
{metrics}
| Commerce supporting buildings | 13 placeholders | 15 authored | +2 |
| Commerce reusable building types | 0 authored | 10 | +10 |
| Commerce shared box modules | 0 | {A['shared_box_modules']} | +{A['shared_box_modules']} |

Scene mesh/triangle/material counts include all visible districts and exclude hidden placeholders and staging libraries. Text-curve lettering is not included in mesh triangle counts; an eventual export must account for its tessellation. Public-space counts refer to Commerce meshes only. The original scene has one plaza display mesh; the final count includes walks, consolidated paving, skirts, ramps, markings, seats, planters and fixtures. These are Blender geometry metrics, not GPU draw calls, load-time or frame-rate measurements.

## Preservation and verification

All {len(V['checks'])} checks in verification.json pass on the saved Phase 8 file. Original object signatures cover geometry, transforms, parenting and metadata. Additional comparisons cover original material node values, visibility/collection membership outside the authorized placeholder changes, and camera settings. Flashpoint and RivalHQ_Slot_05 objects receive an explicit exact-preservation check.

The Spire (280 m), Venture Hall (41.4 m), Tech.com (145 m), Signal TV (47 m), Pallas AI (160 m), Northwind Labs (115 m), Flashpoint (75 m), Founder District, Startup Row, progression locations, three bridges, district boundaries, bay/water and other district geometry remain unchanged. Six protected Spire crown-sample counts remain 36/38/43/39/39/45; Startup-to-Flashpoint remains 10 of 12 samples. These are selected regression viewpoints, not every possible future camera.

{V['protected_file_count']} source files match the pre-pass SHA-256 baseline, including App, tests, the Xcode project/shared scheme, earlier Atlantis phases and Garage assets/documentation. Existing dirty worktree changes remain untouched. No commit or push was made.

Blender was run with approved access outside the sandbox because sandbox startup is unreliable in this environment. The reused material helper emits the existing Blender 6.0 use_nodes deprecation warning. Intermediate failed checks were fixed; final acceptance uses explicit assertions rather than Blender's exit code alone, which can remain zero after a Python assertion.

No Xcode build, XCTest, XCUITest or simulator run was performed for this explicitly Blender-only pass. Runtime walking, navmesh, collision, transit, NPCs, vehicles, district streaming, RealityKit performance, device memory and day/night scheduling remain untested and unimplemented. GameStore, save version 19, simulation/RNG, rival state and Garage runtime are unchanged.

## Future readiness and final assessment

1. **Does Commerce function as Atlantis's customer, enterprise, partnerships and commercial-growth center? Yes at the authored world-planning level.** Its office/hotel/event/service mix and central customer space establish that role.
2. **Does Flashpoint fit the ecosystem without an HQ redesign? Yes.** The corridor, forecourt and supporting buildings give context while its approved asset, transform, materials and signage remain unchanged.
3. **Does Startup → Commerce → Tech Core reinforce building → selling/scaling → competing at scale? Yes in the reviewed compositions.** Floorplates, hospitality, customer frontage and the rising skyline distinguish the stages.
4. **Is Commerce suitable for future walking, loading and day/night presentation? Yes as a spatial foundation.** Broad connected walking surfaces, graded crossings, preserved road capacity, separate district collections and semantic surfaces support later integration. Device performance and playable traversal require their own implementation and acceptance pass.

The editable Blender masterplan is the deliverable for this phase; the optional review GLB is omitted. Final human visual acceptance remains with the user.

## Files added in Phase 8

'''+ '\n'.join('- '+p for p in filelist)+'''
- Documentation/Atlantis/PHASE8_COMMERCE_DISTRICT_REPORT.md

All files changed by this pass are within Assets/Atlantis/Phase8/CommerceDistrict and this report. Earlier phases and runtime files were read only.
'''
Path('Documentation/Atlantis/PHASE8_COMMERCE_DISTRICT_REPORT.md').write_text(report)
print('Report generated from',len(V['checks']),'passing checks')
