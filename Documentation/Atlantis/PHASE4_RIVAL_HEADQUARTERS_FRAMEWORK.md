# Atlantis Phase 4 — Canonical Rival Headquarters Framework

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
| RivalHQ_Slot_01 | StartupRow | [-610, -360, 14] | [52, 60] | RivalHQ_Small / [15, 30] | Unassigned |
| RivalHQ_Slot_02 | VentureDistrict | [-350, 300, 14] | [65, 60] | RivalHQ_Medium / [40, 90] | Unassigned |
| RivalHQ_Slot_03 | TechCore | [-100, 520, 14] | [65, 60] | RivalHQ_Major / [100, 180] | Northwind Labs |
| RivalHQ_Slot_04 | TechCore | [220, 300, 14] | [65, 60] | RivalHQ_Major / [100, 180] | Pallas AI |
| RivalHQ_Slot_05 | CommerceDistrict | [430, -240, 14] | [75, 60] | RivalHQ_Medium / [40, 90] | Flashpoint |

All rotations are zero, with Blender -Y public front / glTF +Z. Full audit, including original Phase0 visibility notes and fresh Phase3 camera samples, is in `slot_audit.json`.

| Slot | Nearest road / centre / edge distance m | Spire m | Venture Hall m | Tech.com m | Signal TV m |
|---|---|---|---|---|---|
| RivalHQ_Slot_01 | StartupRow_CrossStreet / 20.00 / 13.00 | 1021.76 | 478.54 | 1557.06 | 1683.24 |
| RivalHQ_Slot_02 | Venture_Boulevard / 40.97 / 28.97 | 417.61 | 254.95 | 1187.70 | 1220.53 |
| RivalHQ_Slot_03 | Tech_Ring / 70.05 / 57.05 | 180.28 | 586.94 | 981.95 | 961.87 |
| RivalHQ_Slot_04 | TechCore_CrossStreet / 30.00 / 23.00 | 208.09 | 764.00 | 620.18 | 659.70 |
| RivalHQ_Slot_05 | Commerce_Boulevard / 38.58 / 26.58 | 761.58 | 1012.42 | 612.88 | 821.52 |

## Assignment and placement

| Rival | Canonical slot / semantic locator | District | Tier | Current height | Future max | Current footprint | Identity |
|---|---|---|---|---|---|---|---|
| Pallas AI | RivalHQ_Slot_04 / RivalHQ_PallasAI | TechCore | 3 | 160 m | 180 m | 60×42 m | Monumental composed taper, paired crown blades, formal compact podium |
| Northwind Labs | RivalHQ_Slot_03 / RivalHQ_NorthwindLabs | TechCore | 2/3 | 115 m | 150 m | 58×52 m | Offset technical tower, low research wing, modular structural frame |
| Flashpoint | RivalHQ_Slot_05 / RivalHQ_Flashpoint | CommerceDistrict | 2 | 75 m | 90 m | 40×32 m | Asymmetric stepped wedge, sharp launch-facing podium |

**Pallas / slot04:** prime southeastern Tech Core parcel, 208.09 m from The Spire, visible from Media and a clear cross-core view at Venture's eastern edge. Its southern podium addresses the Tech Ring approach; the north side sits alongside the existing cross street. The original 65×60 m rectangle reaches into the cross-street setback, so actual building and growth footprints are smaller. The tall composed crown reads as established power without duplicating Venture Hall's broad institutional form.

**Northwind / slot03:** northwestern research edge of Tech Core, 180.28 m from The Spire, with more road and neighboring-building clearance than Pallas. The asymmetrical research podium and lab wing support a campus interpretation. The south facade retains the canonical slot orientation; northern service/research access can later address the ring without rotating or relocating the parcel. It has a clear technical approach between existing towers, though not every district view sees it.

**Flashpoint / slot05:** Commerce growth corridor linked to the Startup progression road through Commerce Boulevard. This is the brief's allowed Commerce/Tech transition option, rather than a claim that the parcel physically adjoins Startup Row. It gives street presence and a smaller, energetic skyline form. The existing Startup slot01 is only15–30 m and already meets a road setback, so it would not support55–95 m without changing its contract. Flashpoint is legible from Startup's southeastern edge along a clear perspective view. The narrow safe footprint responds to the diagonal boulevard; no roads were moved.

## Style bibles and blockouts

### Pallas AI — Established power

Silhouette: Monumental composed taper, paired crown blades, formal compact podium. Materials: Deep neutral glass, pale bronze metal, restrained stone. Accent: Warm restrained premium edges. Signage: Integrated understated podium mark. Night: Warm crown bars and lobby glow.

The160 m tapered tower has paired bronze crown blades, a54×36×10 m glazed podium, restrained stone base and small integrated entry mark. Use composed vertical proportion and premium quiet surfaces in Phase5; avoid financial-temple colonnades, aggressive neon or a fantasy crown.

Blockout metrics: 128 triangles, 10 mesh objects, 4 planning materials, zero textures; dimensions [60.0, 42.0, 160.0]. Root world position [220, 300, 14], rotation zero, metre scale. Geometry is deliberately simple closed massing with intentional component intersections, not an interior or collision-ready union.

### Northwind Labs — Disciplined intelligence

Silhouette: Offset technical tower, low research wing, modular structural frame. Materials: Cool blue glass and pale silver. Accent: Muted cyan technical grid. Signage: Small precise lobby plate. Night: Cool vertical laboratory grid.

The115 m modular technical tower is offset west of a54×46×10 m research podium, with an eastern lab wing, pale structural bands and a cool readout grid. Phase5 should develop lab credibility and precision, not turn the campus into a financial institution.

Blockout metrics: 216 triangles, 18 mesh objects, 4 planning materials, zero textures; dimensions [58.0, 52.0, 115.0]. Root world position [-100, 520, 14], rotation zero, metre scale. Geometry is deliberately simple closed massing with intentional component intersections, not an interior or collision-ready union.

### Flashpoint — Velocity and pressure

Silhouette: Asymmetric stepped wedge, sharp launch-facing podium. Materials: Dark glass with light structural metal. Accent: Concentrated warm orange-red accent. Signage: Visible south launch facade panel. Night: Energetic diagonal accent and brighter entry.

The75 m asymmetrical wedge rises above a36×28×6 m launch podium and lower side wing. Offset facade fins and a concentrated orange edge imply pace without relying on logo text. Phase5 should retain sharp street frontage and youthful market energy; avoid oversized billboards or casino-like lighting.

Blockout metrics: 136 triangles, 10 mesh objects, 4 planning materials, zero textures; dimensions [40.0, 32.0, 75.0]. Root world position [430, -240, 14], rotation zero, metre scale. Geometry is deliberately simple closed massing with intentional component intersections, not an interior or collision-ready union.

## Signage and event readiness

Each blockout has a blank independently named signage object: `PallasAI_Signage_Main` (14×3 m), `NorthwindLabs_Signage_Main` (12×2.5 m), `Flashpoint_Signage_Main` (24×3 m). Each has a UV map and a future-target custom property. Planning signage shares the company's accent material; Phase5 can split final signage materials where independent runtime binding requires it.

Pallas uses restrained crown points and warm entrance identity; Northwind uses cool vertical grid strips; Flashpoint uses the brighter diagonal edge and launch-facing sign. These are distinguishable without text in day/night studies. No logos, events or runtime behavior are implemented. Future launches, funding, crises, copycat coverage, public attention and milestones may drive bounded presentation changes from existing canonical systems. Morning/noon/evening/night synchronization remains future runtime work.

## Growth envelopes and measurements

All envelopes are local axis-aligned boxes around the existing ground-centred locator. They include every podium, projection, sign and roof element; they do not reserve new land outside the original parcel. Final hero generation must target the smaller initial footprint, not automatically fill the upgrade envelope.

| Rival | Initial footprint | Safe maximum footprint | Final target range | Max future height | Growth-to-road edge clearance | Growth-to-neighbor block clearance |
|---|---|---|---|---|---|---|
| Pallas AI | [60, 42] m | [64, 44] m | [120, 170] m | 180 m | 1.00 m | 75.80 m to TechCore_Podium_016 |
| Northwind Labs | [58, 52] m | [65, 60] m | [100, 130] m | 150 m | 19.28 m | 57.00 m to TechCore_Podium_006 |
| Flashpoint | [40, 32] m | [42, 34] m | [55, 90] m | 90 m | 0.98 m | 39.00 m to CommerceDistrict_Podium_012 |

Pallas and Flashpoint have tight approximately1 m road-edge margins at their maximum envelopes. These are hard planning limits, not spare space for signage or overhangs. Northwind retains19.28 m to the nearest road at maximum footprint. Growth is capacity only: future increases still require silhouette and sightline review; no upgrade triggers or runtime tiers were implemented.

| Rival | Nearest rival / anchor distance | Nearest major road / centre / edge distance | Primary district landmark distance |
|---|---|---|---|
| Pallas AI | Northwind Labs / 388.33 m | Tech_Ring / 64.14 / 51.14 m | Spire 208.09 m |
| Northwind Labs | Pallas AI / 388.33 m | Tech_Ring / 70.05 / 57.05 m | Spire 180.28 m |
| Flashpoint | Pallas AI / 579.40 m | Commerce_Boulevard / 38.58 / 26.58 m | Commerce_CentralPlaza 221.36 m (public-space landmark; no Commerce hero exists) |

Road figures use the existing road centreline segments and half-widths; neighbor figures use conservative world-space bounding rectangles of existing district massing. No claim is made of pedestrian route length. No adjacent structure was modified for clearance.

## Sightlines and visual review

| View | Pallas | Northwind | Flashpoint |
|---|---|---|---|
| Founder District | Partial | Strong | Strong |
| Startup Row | Hidden | Hidden | Strong |
| Venture District | Strong | Hidden | Hidden |
| Tech Core | Strong | Strong | Hidden |
| Media District | Strong | Hidden | Hidden |
| Unicorn Heights | Strong | Strong | Strong |

Ratings are camera-specific sampled building visibility, supplemented by rendered inspection; they are not whole-district guarantees. Strong means at least6/12 vertical facade samples hit the rival, Partial1–5, Hidden0 (including outside frame). Startup's focused Flashpoint view does not frame the two Tech Core rivals; Venture's focused Pallas view similarly does not frame every rival. Media's current view sees Pallas but hides Northwind behind the core. These limitations remain explicit.

Camera positions: Founder_RivalSkyline(-875,-950,90) is an elevated composition study; StartupRow_Flashpoint(-220,-500,35) is a perspective study from Startup's southeastern edge; Venture_Pallas(-320,300,35) looks along the cross-core opening from Venture's eastern edge. The latter two were visually refined after centre-point ray samples overstated visibility through narrow gaps. Buildings and existing cameras were not moved to fix those views. The original Founder_To_City and TheSpire_StartupSightline cameras were also reviewed independently.

All ten required contextual views plus rival aerial and six isolated day/night views were rendered and inspected. The silhouettes are distinct without labels: composed crown/taper for Pallas, modular frame/research wing for Northwind, asymmetrical wedge/side wing for Flashpoint. The original280 m Spire remains dominant over Pallas160, Tech.com145, Northwind115, Flashpoint75, SignalTV47 and VentureHall41.4. Existing neighboring generic towers remain untouched and can occlude lower facades in some approaches.

The precise original Spire crown-point test can miss the asymmetric crown from some angles, so preservation was additionally checked against actual crown-surface samples on the same six established cameras in Phase3 and Phase4:

| Established view | Phase3 visible samples | Phase4 visible samples |
|---|---|---|
| Founder_To_City | 36 | 36 |
| TheSpire_StartupSightline | 38 | 38 |
| VentureHall_ToSpire | 43 | 43 |
| MediaDistrict_ToSpire | 39 | 39 |
| TechCore_Skyline | 39 | 39 |
| UnicornHeights_View | 45 | 45 |

No sampled crown visibility worsened in Founder, Startup, Venture, Media, Tech Core or Unicorn Heights views. This is geometric comparison plus visual inspection, not runtime camera/device acceptance.

## Future Higgsfield contracts

Full standalone prompts and exact machine-readable constraints are in `future_higgsfield_contracts.json`. No generation is triggered by these files. For each company:

### Pallas AI

Create a standalone Pallas AI headquarters for Atlantis, approximately 160 metres tall, fitting a 60 by 42 metre footprint including podium, projections and roof elements. Monumental composed taper, paired crown blades, formal compact podium. Materials: Deep neutral glass, pale bronze metal, restrained stone. Accents: Warm restrained premium edges. Integrated understated podium mark, reserve a blank architectural signage surface. Night identity: Warm crown bars and lobby glow. Main public facade faces south (-Y in Blender). Foundation-centred ground pivot. Credible contemporary architecture with clean mobile-friendly silhouette. No surrounding city, terrain, streets, unrelated structures, giant billboards, permanent text, floating parts, or fantasy crown. Keep the building subordinate to the 280 metre Spire.

Place at [220, 300, 14] using RivalHQ_Slot_04 → RivalHQ_PallasAI. Target160 m; accepted current range[120, 170] m; initial maximum footprint[60, 42] m; future absolute envelope[64, 44, 180] m. Export around local foundation centre, rotate zero, south-forward, unit scale. Preserve `PallasAI_Signage_Main` as a blank independently targetable final surface.

### Northwind Labs

Create a standalone Northwind Labs headquarters for Atlantis, approximately 115 metres tall, fitting a 58 by 52 metre footprint including podium, projections and roof elements. Offset technical tower, low research wing, modular structural frame. Materials: Cool blue glass and pale silver. Accents: Muted cyan technical grid. Small precise lobby plate, reserve a blank architectural signage surface. Night identity: Cool vertical laboratory grid. Main public facade faces south (-Y in Blender). Foundation-centred ground pivot. Credible contemporary architecture with clean mobile-friendly silhouette. No surrounding city, terrain, streets, unrelated structures, giant billboards, permanent text, floating parts, or fantasy crown. Keep the building subordinate to the 280 metre Spire.

Place at [-100, 520, 14] using RivalHQ_Slot_03 → RivalHQ_NorthwindLabs. Target115 m; accepted current range[100, 130] m; initial maximum footprint[58, 52] m; future absolute envelope[65, 60, 150] m. Export around local foundation centre, rotate zero, south-forward, unit scale. Preserve `NorthwindLabs_Signage_Main` as a blank independently targetable final surface.

### Flashpoint

Create a standalone Flashpoint headquarters for Atlantis, approximately 75 metres tall, fitting a 40 by 32 metre footprint including podium, projections and roof elements. Asymmetric stepped wedge, sharp launch-facing podium. Materials: Dark glass with light structural metal. Accents: Concentrated warm orange-red accent. Visible south launch facade panel, reserve a blank architectural signage surface. Night identity: Energetic diagonal accent and brighter entry. Main public facade faces south (-Y in Blender). Foundation-centred ground pivot. Credible contemporary architecture with clean mobile-friendly silhouette. No surrounding city, terrain, streets, unrelated structures, giant billboards, permanent text, floating parts, or fantasy crown. Keep the building subordinate to the 280 metre Spire.

Place at [430, -240, 14] using RivalHQ_Slot_05 → RivalHQ_Flashpoint. Target75 m; accepted current range[55, 90] m; initial maximum footprint[40, 32] m; future absolute envelope[42, 34, 90] m. Export around local foundation centre, rotate zero, south-forward, unit scale. Preserve `Flashpoint_Signage_Main` as a blank independently targetable final surface.

Each hero must be imported separately, normalized uniformly, cleaned and re-exported independently before replacing only its named blockout collection. Preserve the original generic locator parent and all other city objects. Future LOD0 hero, LOD1 simplified HQ and LOD2 skyline proxy remain separate assets under the same presentation root; none are authored here. Do not add simulation logic, runtime thresholds or hidden-state mappings during asset production.

## Validation and preservation

**27/27 checks pass. 228 protected file hashes are unchanged.**

- PASS — all original geometry transforms properties preserved
- PASS — three canonical ids
- PASS — one distinct slot each
- PASS — PallasAI geometry valid
- PASS — PallasAI fits parcel
- PASS — PallasAI height
- PASS — PallasAI locator traceable
- PASS — PallasAI signage
- PASS — PallasAI growth road clearance
- PASS — NorthwindLabs geometry valid
- PASS — NorthwindLabs fits parcel
- PASS — NorthwindLabs height
- PASS — NorthwindLabs locator traceable
- PASS — NorthwindLabs signage
- PASS — NorthwindLabs growth road clearance
- PASS — Flashpoint geometry valid
- PASS — Flashpoint fits parcel
- PASS — Flashpoint height
- PASS — Flashpoint locator traceable
- PASS — Flashpoint signage
- PASS — Flashpoint growth road clearance
- PASS — all protected files unchanged
- PASS — founder spire crown preserved
- PASS — startup spire crown preserved
- PASS — all six established spire views not worsened
- PASS — all growth envelopes clear neighbor blocks
- PASS — review glb reimport preserves world positions

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

- `Assets/Atlantis/Phase4/Rivals/Blender/Atlantis_Phase4_Masterplan.blend`
- `Assets/Atlantis/Phase4/Rivals/Export/Atlantis_Phase4_RivalBlockout.glb`
- `Assets/Atlantis/Phase4/Rivals/Review/Atlantis_Master_Aerial.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Flashpoint_Day.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Flashpoint_Night.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Founder_RivalSkyline.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Media_RivalSkyline.png`
- `Assets/Atlantis/Phase4/Rivals/Review/NorthwindLabs_Day.png`
- `Assets/Atlantis/Phase4/Rivals/Review/NorthwindLabs_Night.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Northwind_TechApproach.png`
- `Assets/Atlantis/Phase4/Rivals/Review/PallasAI_Day.png`
- `Assets/Atlantis/Phase4/Rivals/Review/PallasAI_Night.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Rivals_Aerial.png`
- `Assets/Atlantis/Phase4/Rivals/Review/StartupRow_Flashpoint.png`
- `Assets/Atlantis/Phase4/Rivals/Review/TechCore_Rivals_Aerial.png`
- `Assets/Atlantis/Phase4/Rivals/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase4/Rivals/Review/UnicornHeights_View.png`
- `Assets/Atlantis/Phase4/Rivals/Review/Venture_Pallas.png`
- `Assets/Atlantis/Phase4/Rivals/audit_slots.py`
- `Assets/Atlantis/Phase4/Rivals/build_rivals.py`
- `Assets/Atlantis/Phase4/Rivals/check_views.py`
- `Assets/Atlantis/Phase4/Rivals/future_higgsfield_contracts.json`
- `Assets/Atlantis/Phase4/Rivals/preservation_baseline.json`
- `Assets/Atlantis/Phase4/Rivals/review_rivals.py`
- `Assets/Atlantis/Phase4/Rivals/rival_profiles.json`
- `Assets/Atlantis/Phase4/Rivals/slot_audit.json`
- `Assets/Atlantis/Phase4/Rivals/verification.json`
- `Assets/Atlantis/Phase4/Rivals/verify_context.py`
- `Assets/Atlantis/Phase4/Rivals/write_report.py`
- `Documentation/Atlantis/PHASE4_RIVAL_HEADQUARTERS_FRAMEWORK.md`
