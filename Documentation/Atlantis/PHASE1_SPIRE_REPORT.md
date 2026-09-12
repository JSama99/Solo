# Atlantis Phase 1 — The Spire

## Result

The Higgsfield → GLB → Blender → independent GLB pipeline is validated. One completed Tripo candidate supplied the taper and asymmetric crown. Blender replaced noisy generated facade topology with a measured, source-derived architectural envelope and built a bounded podium and vertical fins. This is a deliberately simple real-time exterior hero asset; it is not a direct untouched AI mesh or a detailed architectural model.

## Slot and placement

| Property | Value |
|---|---|
| Canonical anchor | Landmark_TheSpire, preserved |
| World origin | (50, 420, 14) metres, foundation center |
| Rotation / scale | (0°, 0°, 0°) / (1, 1, 1) |
| Forward | Blender −Y; GLB +Z after standard Y-up conversion |
| Slot footprint / height | 70 × 70 m; target 280–350 m; maximum 350 m |
| Final bounding box | 68 × 67 × 280 m |
| Final world bounds | (16, 386, 14) to (84, 453, 294) m |
| Podium | Lower 68 × 66 × 4 m; upper 62 × 58 × 6 m |
| Founder Garage distance | 1720 m horizontally |
| Founder angular height | 9.29° full geometric height; lower shaft partly occluded |
| Nearest generic tower | TechCore_Block_011, 71.15 m center-to-center horizontally |

The initial 330 m design aim was reduced to the canonical minimum of 280 m to preserve the generated shaft proportions and fit the parcel. Raw source dimensions were 0.377139 × 0.380766 × 1.0 units. The oversized generated base below Z −0.4 was removed. The remaining 0.9-unit shaft was scaled uniformly by 300 to 270 m and placed on a 10 m podium. No non-uniform whole-asset stretch was used. The replacement envelope follows measured angular sections of that normalized shaft.

## Generation

Model: `tripo_3d`, one completed candidate. Meshy was attempted first but failed CLI validation before returning a job or asset. Tripo was selected because its generated taper, continuous vertical form, and sloping asymmetric crown suited the brief. No further candidates were purchased. The full prompt and returned source URL are preserved in Source/generation_result.json.

Command parameters: `higgsfield generate create tripo_3d --prompt <recorded prompt> --negative_prompt <recorded exclusions> --face_limit 20000 --pbr true --texture true --wait --wait-timeout 20m --wait-interval 10s --json`.

## Cleanup and metrics

| Metric | Raw GLB | Clean GLB |
|---|---:|---:|
| Meshes | 1 | 13 |
| Triangles | 16,164 | 972 |
| Materials referenced by GLB | 1 | 4 |
| Embedded images | 3 | 0 |
| File bytes | 1,682,968 | 60,232 |
| Triangle reduction | — | 93.99% |

Cleanup removed the original broad podium, tiny disconnected components, degenerate geometry, and pinched seams. An intermediate decimation still produced rippled facade highlights; final source-derived retopology replaced that surface with 32 angular samples across measured height sections. Caps and normals were rebuilt. Purposeful podium/shaft and fin intersections remain as separate closed architectural components, not duplicate coincident skins. There are no interiors.

Four clean material categories: blue glazing, satin titanium, limestone podium, and restrained teal emissive. The final asset uses constant PBR materials and zero image textures. Raw source contains three 2048 × 2048 embedded images: base color in sRGB, normal and ORM in Non-Color. Imported alpha mode was CHANNEL_PACKED; the clean materials are opaque with no alpha maps. Generated maps remain preserved in raw source and hidden staging, but are not exported with the clean asset. Render Result and Viewer Node entries in source_audit.json are Blender buffers, not source textures.

## Integration and preservation

The separate Phase1 masterplan contains Atlantis / Districts / TechCore / HeroLandmarks / TheSpire. TheSpire_AssetRoot supplies world placement. Hidden raw source is retained under Atlantis / AssetStaging / TheSpire_Source. Only the temporary Spire Massing, Crown, and Needle meshes were disabled for viewport/render. The canonical anchor, parcel, original 110 × 110 m plaza, all other slots, seven districts, three bridges, roads, water, geography and original cameras were preserved. No nearby placeholder height adjustments were needed.

Phase0 files remain byte-for-byte unchanged. The Phase1 scene retains the original world envelope including hidden retired placeholder (Z maximum 362 m); visible geometry now reaches Z 294 m. Land and water XY bounds are unchanged. No runtime export, app integration, Garage asset edit, GameStore change, or save-version change was made. The existing version-19 save system and V7 Garage remain untouched. Hash comparison of all baseline App files, project/scheme, and Phase0 files passed.

The added day/evening/night setup is Blender review lighting only. City context is rendered as a neutral clay study because the Phase0 materials were viewport blockout materials; it does not represent a new city material direction. Isolated hero/side/night captures temporarily hide context for review and do not remove it from the master scene.

## Validation and visual assessment

Eleven exported-asset/regression checks passed: 280 m height, foundation at zero, centered parcel fit, unit scale, closed topology after welding glTF shading seams, nonzero faces, outward winding, Founder sightline, Startup sightline, tallest visible mass, and unchanged protected files. The clean pre-export meshes also have zero non-manifold edges and zero-area faces. Export was reimported in a fresh Blender session and saved as a complete standalone .blend.

All requested view classes were rendered and inspected: aerial, Founder, Startup Row, Tech Core skyline and street approach, hero three-quarter, side, night, and Unicorn Heights. Extra Venture, Media, and evening views were inspected. Founder and Startup show the crown above neighboring masses, with the lower shaft partly occluded. Tech Core reveals the full taper and vertical fins. From Heights, the asymmetric crown remains distinct while foreground HQ parcels retain their elevated identity. Night retains a readable dark blue body with narrow teal accents; there is no all-facade glow.

**Is The Spire recognizable as the central landmark? Yes, at the intended skyline and exterior-game scale:** it is the tallest mass, with a taper, sloping asymmetric crown, silver vertical structure and restrained teal accents.

**Does it work as the first production-quality hero landmark and validate the pipeline? Yes, for this bounded low-poly exterior asset pass.** Geometry/export checks and visual review support that assessment. Final user art acceptance, actual device performance and RealityKit material behavior are not claimed; runtime integration was explicitly out of scope.

**Does the Founder sightline still communicate progression? Yes.** The distant crown remains visible above the lower Startup and Tech Core masses without enlarging the canonical parcel.

## Execution issues

Meshy failed on an unsupported CLI validation rule. Blender also crashed once during datablock-library writing; a fresh-process GLB reimport and normal scene save resolved standalone delivery. Intermediate mesh and sampling failures were corrected before final verification. No app builds or simulator runs were performed for this asset-only task.

## Files

- `Assets/Atlantis/Phase1/TheSpire/Blender/Atlantis_Phase1_Masterplan.blend`
- `Assets/Atlantis/Phase1/TheSpire/Blender/Atlantis_TheSpire_v1.blend`
- `Assets/Atlantis/Phase1/TheSpire/Export/Atlantis_TheSpire_v1.glb`
- `Assets/Atlantis/Phase1/TheSpire/Review/Atlantis_Master_Aerial.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/Founder_To_City.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/Source_Candidate.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TechCore_Skyline.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_EveningPreview.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_Hero.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_MediaSightline.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_NightPreview.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_Side.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_StartupSightline.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_TechCoreApproach.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/TheSpire_VentureSightline.png`
- `Assets/Atlantis/Phase1/TheSpire/Review/UnicornHeights_View.png`
- `Assets/Atlantis/Phase1/TheSpire/Source/TheSpire_Higgsfield_Raw.glb`
- `Assets/Atlantis/Phase1/TheSpire/Source/generation_result.json`
- `Assets/Atlantis/Phase1/TheSpire/Source/source_audit.json`
- `Assets/Atlantis/Phase1/TheSpire/build_spire.py`
- `Assets/Atlantis/Phase1/TheSpire/clean_audit.json`
- `Assets/Atlantis/Phase1/TheSpire/inspect_source.py`
- `Assets/Atlantis/Phase1/TheSpire/preservation_baseline.json`
- `Assets/Atlantis/Phase1/TheSpire/render_asset_reviews.py`
- `Assets/Atlantis/Phase1/TheSpire/slot_audit.json`
- `Assets/Atlantis/Phase1/TheSpire/verification.json`
- `Assets/Atlantis/Phase1/TheSpire/verify_export.py`
- `Documentation/Atlantis/PHASE1_SPIRE_REPORT.md` (this report)
