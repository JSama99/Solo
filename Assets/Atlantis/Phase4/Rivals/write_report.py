import json,pathlib,math
R=pathlib.Path(__file__).resolve().parent;root=R.parents[3];v=json.load(open(R/'verification.json'));data=json.load(open(R/'rival_profiles.json'));ps=data['profiles'];audit=json.load(open(R/'slot_audit.json'));assert all(v['checks'].values())
contracts=[]
for p in ps:
 n=p['semanticID'];contracts.append({'canonicalCompanyID':p['canonicalCompanyID'],'displayName':p['displayName'],'slotID':p['slotID'],'semanticLocator':'RivalHQ_'+n,'district':p['district'],'worldPosition':p['position'],'worldRotationDegrees':[0,0,0],'forward':p['forward'],'units':'metres; 1 Blender unit = 1 metre','origin':'footprint centre at ground/base; local (0,0,0)','targetHeight':p['currentHeight'],'finalHeightRange':p['targetHeightRange'],'initialMaximumFootprint':p['footprint'],'absoluteUpgradeEnvelope':p['futureUpgradeEnvelope'],'signageObject':n+'_Signage_Main','prompt':f"Create a standalone {p['displayName']} headquarters for Atlantis, approximately {p['currentHeight']} metres tall, fitting a {p['footprint'][0]} by {p['footprint'][1]} metre footprint including podium, projections and roof elements. {p['architecturalLanguage']}. Materials: {p['primaryMaterialFamily']}. Accents: {p['accentLanguage']}. {p['signageStrategy']}, reserve a blank architectural signage surface. Night identity: {p['nightIdentity']}. Main public facade faces south (-Y in Blender). Foundation-centred ground pivot. Credible contemporary architecture with clean mobile-friendly silhouette. No surrounding city, terrain, streets, unrelated structures, giant billboards, permanent text, floating parts, or fantasy crown. Keep the building subordinate to the 280 metre Spire.",'delivery':'Standalone raw GLB retained; normalize uniformly; clean/reconstruct in Blender as required; independently export and reimport; validate original slot, roads and established sightlines; do not change runtime.', 'lodPlan':'Keep hero root independent for future LOD0/LOD1/LOD2. LOD assets and runtime switching are not authored in Phase4.'})
(R/'future_higgsfield_contracts.json').write_text(json.dumps(contracts,indent=2))
r='''# Atlantis Phase 4 — Canonical Rival Headquarters Framework

## Result

Northwind Labs, Pallas AI and Flashpoint each have one traceable canonical HQ assignment, company-specific planning massing, reserved growth envelope, semantic signage and a future standalone generation contract. The new master is `Assets/Atlantis/Phase4/Rivals/Blender/Atlantis_Phase4_Masterplan.blend`; Phase3 was not overwritten. The optional world-positioned review GLB contains only the three rival blockouts.

These are lightweight **blockouts, not final hero buildings**. No Higgsfield jobs were submitted and no generation credits were spent in Phase4. No app files or simulation models were added.

## Canonical identity and source boundary

`App/ContentLibrary.swift:20` defines `northwind` → Northwind Labs, `pallas` → Pallas AI and `flashpoint` → Flashpoint. Those IDs are referenced in planning JSON and Blender custom properties. The canonical simulation remains authoritative.

The current runtime definitions give Northwind an incumbent archetype/baseStrength1.35, Pallas an upstart archetype/baseStrength0.9 and Flashpoint a hypeMachine archetype/baseStrength1.0. The brief's Pallas prestige ranking is implemented strictly as **visual direction**. No strength, archetype, progression, debut, balance or public/hidden state is inferred or changed to match architecture.

`rival_profiles.json` is a planning schema, not a second rival model. It contains canonicalCompanyID, displayName, district, slotID, hqTier, targetHeightRange, footprint, architecturalLanguage, primaryMaterialFamily, accentLanguage, signageStrategy, nightIdentity, visibilityPriority and futureUpgradeEnvelope. A separate `Atlantis_RivalProfiles` collection holds planning empties; semantic asset roots carry the same metadata. Future state-driven visuals must consume canonical visible projections, not introduce new rival state or expose hidden truth.

## Tier framework

| Tier | Planning height | Form |
|---|---|---|
| 1 — Emerging | 15–35 m | compact office / small campus |
| 2 — Established | 40–100 m | mid-rise, podium/tower, public signage |
| 3 — Major | 100–180 m | premium skyline HQ and distinctive crown |

Northwind's requested Tier2/3 remains an explicit transitional presentation label. Its selected major slot has a 100 m lower target, so the executable final range is 100–130 m (intersection of the brief's 80–130 m preference and existing slot contract). Flashpoint's final range is 55–90 m, respecting its slot's 90 m maximum instead of stretching to the brief's preferred95. All rivals remain below The Spire's280 m.

## Original slot audit

All five original locators, parcel meshes, stored transforms and custom properties remain intact. The three assigned generic masses are disabled in the new master, not deleted. Unassigned slots01/02 remain generic planning reservations, not extra canonical companies.

| Original slot | District | Origin m | Parcel m | Original height class/range m | Assignment |
|---|---|---|---|---|---|
'''
assign={p['slotID']:p['displayName'] for p in ps}
for q in audit:
 s=q['contract'];r+=f"| {s['id']} | {s['district']} | {s['origin']} | {s['footprint_m']} | {s['kind']} / {s['target_height_m']} | {assign.get(s['id'],'Unassigned')} |\n"
r+='\nAll rotations are zero, with Blender -Y public front / glTF +Z. Full audit, including original Phase0 visibility notes and fresh Phase3 camera samples, is in `slot_audit.json`.\n\n| Slot | Nearest road / centre / edge distance m | Spire m | Venture Hall m | Tech.com m | Signal TV m |\n|---|---|---|---|---|---|\n'
for q in audit:
 road=q['roads'][0];d=q['landmark_distances'];r+=f"| {q['contract']['id']} | {road['name']} / {road['center_distance']:.2f} / {road['edge_distance']:.2f} | {d['Spire']:.2f} | {d['VentureHall']:.2f} | {d['TechCom']:.2f} | {d['SignalTV']:.2f} |\n"
r+='''
## Assignment and placement

| Rival | Canonical slot / semantic locator | District | Tier | Current height | Future max | Current footprint | Identity |
|---|---|---|---|---|---|---|---|
'''
for p in ps:r+=f"| {p['displayName']} | {p['slotID']} / RivalHQ_{p['semanticID']} | {p['district']} | {p['hqTier']} | {p['currentHeight']} m | {p['futureUpgradeEnvelope'][2]} m | {p['footprint'][0]}×{p['footprint'][1]} m | {p['architecturalLanguage']} |\n"
r+='''
**Pallas / slot04:** prime southeastern Tech Core parcel, 208.09 m from The Spire, visible from Media and a clear cross-core view at Venture's eastern edge. Its southern podium addresses the Tech Ring approach; the north side sits alongside the existing cross street. The original 65×60 m rectangle reaches into the cross-street setback, so actual building and growth footprints are smaller. The tall composed crown reads as established power without duplicating Venture Hall's broad institutional form.

**Northwind / slot03:** northwestern research edge of Tech Core, 180.28 m from The Spire, with more road and neighboring-building clearance than Pallas. The asymmetrical research podium and lab wing support a campus interpretation. The south facade retains the canonical slot orientation; northern service/research access can later address the ring without rotating or relocating the parcel. It has a clear technical approach between existing towers, though not every district view sees it.

**Flashpoint / slot05:** Commerce growth corridor linked to the Startup progression road through Commerce Boulevard. This is the brief's allowed Commerce/Tech transition option, rather than a claim that the parcel physically adjoins Startup Row. It gives street presence and a smaller, energetic skyline form. The existing Startup slot01 is only15–30 m and already meets a road setback, so it would not support55–95 m without changing its contract. Flashpoint is legible from Startup's southeastern edge along a clear perspective view. The narrow safe footprint responds to the diagonal boulevard; no roads were moved.

## Style bibles and blockouts

'''
for p in ps:
 n=p['semanticID'];g=v['metrics'][n];emotion={'PallasAI':'Established power','NorthwindLabs':'Disciplined intelligence','Flashpoint':'Velocity and pressure'}[n]
 r+=f"### {p['displayName']} — {emotion}\n\nSilhouette: {p['architecturalLanguage']}. Materials: {p['primaryMaterialFamily']}. Accent: {p['accentLanguage']}. Signage: {p['signageStrategy']}. Night: {p['nightIdentity']}.\n\n"
 if n=='PallasAI':r+='The160 m tapered tower has paired bronze crown blades, a54×36×10 m glazed podium, restrained stone base and small integrated entry mark. Use composed vertical proportion and premium quiet surfaces in Phase5; avoid financial-temple colonnades, aggressive neon or a fantasy crown.\n\n'
 elif n=='NorthwindLabs':r+='The115 m modular technical tower is offset west of a54×46×10 m research podium, with an eastern lab wing, pale structural bands and a cool readout grid. Phase5 should develop lab credibility and precision, not turn the campus into a financial institution.\n\n'
 else:r+='The75 m asymmetrical wedge rises above a36×28×6 m launch podium and lower side wing. Offset facade fins and a concentrated orange edge imply pace without relying on logo text. Phase5 should retain sharp street frontage and youthful market energy; avoid oversized billboards or casino-like lighting.\n\n'
 r+=f"Blockout metrics: {g['triangles']} triangles, {g['meshes']} mesh objects, {g['materials']} planning materials, zero textures; dimensions {g['dimensions']}. Root world position {p['position']}, rotation zero, metre scale. Geometry is deliberately simple closed massing with intentional component intersections, not an interior or collision-ready union.\n\n"
r+='''## Signage and event readiness

Each blockout has a blank independently named signage object: `PallasAI_Signage_Main` (14×3 m), `NorthwindLabs_Signage_Main` (12×2.5 m), `Flashpoint_Signage_Main` (24×3 m). Each has a UV map and a future-target custom property. Planning signage shares the company's accent material; Phase5 can split final signage materials where independent runtime binding requires it.

Pallas uses restrained crown points and warm entrance identity; Northwind uses cool vertical grid strips; Flashpoint uses the brighter diagonal edge and launch-facing sign. These are distinguishable without text in day/night studies. No logos, events or runtime behavior are implemented. Future launches, funding, crises, copycat coverage, public attention and milestones may drive bounded presentation changes from existing canonical systems. Morning/noon/evening/night synchronization remains future runtime work.

## Growth envelopes and measurements

All envelopes are local axis-aligned boxes around the existing ground-centred locator. They include every podium, projection, sign and roof element; they do not reserve new land outside the original parcel. Final hero generation must target the smaller initial footprint, not automatically fill the upgrade envelope.

| Rival | Initial footprint | Safe maximum footprint | Final target range | Max future height | Growth-to-road edge clearance | Growth-to-neighbor block clearance |
|---|---|---|---|---|---|---|
'''
for p in ps:
 n=p['semanticID'];g=v['metrics'][n];near=v['growth_neighbor_clearance'][n];r+=f"| {p['displayName']} | {p['footprint']} m | {p['futureUpgradeEnvelope'][:2]} m | {p['targetHeightRange']} m | {p['futureUpgradeEnvelope'][2]} m | {g['growth_road_edge_clearance']:.2f} m | {near[0]:.2f} m to {near[1]} |\n"
r+='\nPallas and Flashpoint have tight approximately1 m road-edge margins at their maximum envelopes. These are hard planning limits, not spare space for signage or overhangs. Northwind retains19.28 m to the nearest road at maximum footprint. Growth is capacity only: future increases still require silhouette and sightline review; no upgrade triggers or runtime tiers were implemented.\n\n| Rival | Nearest rival / anchor distance | Nearest major road / centre / edge distance | Primary district landmark distance |\n|---|---|---|---|\n'
for p in ps:
 q=next(x for x in audit if x['contract']['id']==p['slotID']);road=min([x for x in q['roads'] if x['class']=='PrimaryRoads'],key=lambda x:x['center_distance']);g=v['metrics'][p['semanticID']];land=f"Spire {g['spire_distance']:.2f} m" if p['district']=='TechCore' else f"Commerce_CentralPlaza {math.dist(p['position'][:2],[220,-170]):.2f} m (public-space landmark; no Commerce hero exists)";r+=f"| {p['displayName']} | {g['nearest_rival']['name']} / {g['nearest_rival']['distance']:.2f} m | {road['name']} / {road['center_distance']:.2f} / {road['edge_distance']:.2f} m | {land} |\n"
r+='''
Road figures use the existing road centreline segments and half-widths; neighbor figures use conservative world-space bounding rectangles of existing district massing. No claim is made of pedestrian route length. No adjacent structure was modified for clearance.

## Sightlines and visual review

| View | Pallas | Northwind | Flashpoint |
|---|---|---|---|
'''
for label,row in v['visibility'].items():r+='| '+label+' | '+' | '.join(row[n]['rating'] for n in ['Pallas AI','Northwind Labs','Flashpoint'])+' |\n'
r+='''
Ratings are camera-specific sampled building visibility, supplemented by rendered inspection; they are not whole-district guarantees. Strong means at least6/12 vertical facade samples hit the rival, Partial1–5, Hidden0 (including outside frame). Startup's focused Flashpoint view does not frame the two Tech Core rivals; Venture's focused Pallas view similarly does not frame every rival. Media's current view sees Pallas but hides Northwind behind the core. These limitations remain explicit.

Camera positions: Founder_RivalSkyline(-875,-950,90) is an elevated composition study; StartupRow_Flashpoint(-220,-500,35) is a perspective study from Startup's southeastern edge; Venture_Pallas(-320,300,35) looks along the cross-core opening from Venture's eastern edge. The latter two were visually refined after centre-point ray samples overstated visibility through narrow gaps. Buildings and existing cameras were not moved to fix those views. The original Founder_To_City and TheSpire_StartupSightline cameras were also reviewed independently.

All ten required contextual views plus rival aerial and six isolated day/night views were rendered and inspected. The silhouettes are distinct without labels: composed crown/taper for Pallas, modular frame/research wing for Northwind, asymmetrical wedge/side wing for Flashpoint. The original280 m Spire remains dominant over Pallas160, Tech.com145, Northwind115, Flashpoint75, SignalTV47 and VentureHall41.4. Existing neighboring generic towers remain untouched and can occlude lower facades in some approaches.

The precise original Spire crown-point test can miss the asymmetric crown from some angles, so preservation was additionally checked against actual crown-surface samples on the same six established cameras in Phase3 and Phase4:

| Established view | Phase3 visible samples | Phase4 visible samples |
|---|---|---|
'''
for n,x in v['spire_crown_surface_samples']['Phase3'].items():r+=f"| {n} | {x} | {v['spire_crown_surface_samples']['Phase4'][n]} |\n"
r+='''
No sampled crown visibility worsened in Founder, Startup, Venture, Media, Tech Core or Unicorn Heights views. This is geometric comparison plus visual inspection, not runtime camera/device acceptance.

## Future Higgsfield contracts

Full standalone prompts and exact machine-readable constraints are in `future_higgsfield_contracts.json`. No generation is triggered by these files. For each company:

'''
for c in contracts:r+=f"### {c['displayName']}\n\n{c['prompt']}\n\nPlace at {c['worldPosition']} using {c['slotID']} → {c['semanticLocator']}. Target{c['targetHeight']} m; accepted current range{c['finalHeightRange']} m; initial maximum footprint{c['initialMaximumFootprint']} m; future absolute envelope{c['absoluteUpgradeEnvelope']} m. Export around local foundation centre, rotate zero, south-forward, unit scale. Preserve `{c['signageObject']}` as a blank independently targetable final surface.\n\n"
r+='''Each hero must be imported separately, normalized uniformly, cleaned and re-exported independently before replacing only its named blockout collection. Preserve the original generic locator parent and all other city objects. Future LOD0 hero, LOD1 simplified HQ and LOD2 skyline proxy remain separate assets under the same presentation root; none are authored here. Do not add simulation logic, runtime thresholds or hidden-state mappings during asset production.

## Validation and preservation

'''
r+=f"**{len(v['checks'])}/{len(v['checks'])} checks pass. {v['protected_file_count']} protected file hashes are unchanged.**\n\n"+'\n'.join('- PASS — '+n.replace('_',' ') for n in v['checks'])+'\n'
r+='''
The combined review GLB was reimported into a fresh Blender scene and its three world-space bounding boxes matched the master. All blockout solids have manifold edges, positive volume and no zero-area faces. Original slot IDs, semantic-parent relationships, target heights and growth clearances were checked.

Phase0–3 files remain byte-for-byte unchanged. Within the new Phase4 master, every original object's geometry, local transform, parent, material assignments and custom properties remain unchanged. Only the render/viewport visibility of the three replaced generic rival masses is disabled. Seven territories, all three bridges, terrain, water, roads, all four existing hero landmarks and Player Unicorn HQ slot are preserved.

Garage RealityKit, GarageV7, GameStore, rival simulation, divergence, Venture, Tech.com, SignalTV, save version19, sprint timing and day-phase runtime were not edited. Existing unrelated dirty-worktree changes remain intact. No Xcode build or simulator run was performed because this pass has no app implementation changes. No commit or push.

## Final assessment

1. **Yes:** Northwind Labs, Pallas AI and Flashpoint each have a canonical physical home, tied to one existing company ID and distinct traceable slot.
2. **Yes:** placements, current scales, silhouettes and bounded growth capacities differ meaningfully; Northwind has the most breathing room, Pallas the prime formal core frontage, Flashpoint the compact market corridor.
3. **Yes:** the rival skyline reinforces the competitive ecosystem from reviewed Founder/Startup and district views while preserving all established landmarks and sampled Spire crown visibility. Visibility is partial in some directions as documented.
4. **Yes:** the three final-asset contracts now specify positions, orientations, current footprints, height ranges, upgrade caps, materials, signage and replacement boundaries precisely enough for a future Higgsfield pass.

Phase4 framework and blockout placement are complete. Final HQ generation, LOD production and runtime visual upgrades remain future work.

## Files created

'''
files=sorted(p for p in R.rglob('*') if p.is_file());r+='\n'.join('- `'+str(p.relative_to(root))+'`' for p in files)+'\n- `Documentation/Atlantis/PHASE4_RIVAL_HEADQUARTERS_FRAMEWORK.md`\n'
(root/'Documentation/Atlantis/PHASE4_RIVAL_HEADQUARTERS_FRAMEWORK.md').write_text(r)
print(len(v['checks']),v['protected_file_count'],root)
