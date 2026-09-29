# Mara Chen — S5 Gate 0 asset contract

Status: **Gate 0 defined; Gate 1 image-driven Blender graybox ACCEPTED by the owner for shape and wardrobe. Gate 2 remains pending.** The earlier Founder-derived graybox is rejected. The accepted Founder USDZ and S2–S4 visual locks are immutable inputs.

## Source and runtime authority

- Current Gate 1 source: `Blender/MaraChen_Gate1_Source.blend`; source reconstruction input: `Source/mara_chen_multiview_candidate.fbx`; four review views: `Graybox/Review/`. This scene contains the image-driven Mara mesh, a packed copy of the approved sheet, and a neutral review studio. Earlier `Blender/MaraChen.blend` and `build_anatomical_graybox.py` are rejected historical studies.
- Proposed final resource: `App/RealityKit/Atlantis/Characters/mara_chen.usdz`. It is **not** emitted or added to the app until the graybox is approved and the export has been audited.
- `AtlantisNamedNPCDefinition` retains public identity and staging. `AtlantisNamedEncounterDirector` retains its 45 m resident policy, noninteraction, no collision, no canonical writeback, and district unload. Blender owns visible character geometry, UVs, materials, skeleton, and clips. RealityKit loads and selects authored presentation.
- Owner picture: `Reference/mara_chen_reference.png`, SHA-256 `4ae2ade09b9d1c1087c279e87791e74b49bc4e869252964e40e595fd970bda0f`. It is the sole visual source of truth; text on that picture is treated as art context, not gameplay or implementation instruction.
- The current mesh was reconstructed from cropped front, side, and back views of the approved sheet with one Higgsfield Tripo H3.1 multiview job, then imported, aligned, saved, and rendered through the Higgsfield use Blender MCP. The provider returned FBX bytes behind a `.glb` URL; the preserved source has the actual `.fbx` extension. The Founder source is not used in the current Gate 1 mesh. The accepted Founder source and USDZ remain untouched.

## Coordinate and import contract

- Blender scene: meters, Z-up, character forward −Y, root at world origin, soles at Z=0; applied object scales before export.
- USD export: Y-up, forward +Z, via Blender orientation conversion with `NEGATIVE_Z` forward and `Y` up. No mirrored or negative-scale root. Runtime wrapper handles Atlantis placement without rebaking the asset.
- PBR: base color, metallic, roughness and normal/atlas textures that survive USDZ/RealityKit import; no Blender-only nodes or runtime cloth/hair physics.
- Final asset target: 8k–18k triangles, one primary skinned character where RealityKit import allows, modest material count, at most one 1024² atlas unless measured import quality requires another arrangement. Measure actual output and revise this target only for visible quality.

## Shape and identity target

Mara is a distinct modern technical founder: provisional target standing height **1.68 m**, shorter than the 1.79 m player Founder. Primary read is at approximately **3–15 m** on the matched iPhone peer approach, with a closer medium-distance check before approval. The picture specifies an oval East Asian face, dark high loose bun with face-framing strands, olive cropped jacket with raised collar over a black fitted top, high-waist charcoal straight trousers, chunky light sneakers, dark wristwatch, and slim tablet. The image does not establish an absolute height, so 1.68 m remains provisional. The teal shirt/gray trouser Founder outline must not be duplicated. Gate 1 matches the major silhouette and outfit blocks; its face is low-definition and the footwear reads more like a plain boot than the reference sneaker. These remain explicit owner review points.

## Rig and clips for the finished asset

- Lightweight hierarchy: Root → Hips → Spine → Chest → Neck → Head; Chest → shoulder/upper arm/lower arm/hand on each side; Hips → thigh/calf/foot on each side. Optional single toe joint if necessary. No finger, cloth, hair, or facial simulation rig.
- Authored clips: `idle`, `deviceIdle`, `noticeFounder`. Reduce Motion holds a stable authored pose. No procedural head/body rotation in Swift for the production asset.
- Export audit must record dimensions, meshes, vertices, triangles, materials, texture resolution/count, joints, clip names/durations, USDZ bytes/SHA-256, and RealityKit load/import behavior. Check visible animation names in RealityKit rather than assuming Blender actions survived export.

## Approval sequence

1. Four-view Blender clay graybox: front, back, side, three-quarter. Human owner accepts/revises proportions before texturing.
2. Finished Blender asset: materials, facial detail, rig, three clips, measured asset audit.
3. RealityKit import and matched production-route captures, load/cadence/memory measurement.
4. Only after Mara approval, author one reusable ambient base for the two existing bounded street people.

The current Gate 1 mesh is 1.683 m tall, 46,554 vertices and 93,004 triangles, with one clay material, no rig, and no clips. The 8k–18k triangle target is a **final runtime** budget requiring retopology. The owner accepted this graybox as the shape and wardrobe direction; facial identity, sneaker detail, materials, rig, clips, export, and runtime presentation remain unapproved. The graybox does not replace the rejected procedural Mara in the runtime candidate or establish S5 visual acceptance.


## Owner source selection — original Higgsfield models (2026-09-27)

The owner selected the original Higgsfield model after rejecting the procedural rebuilds. RetopoA, RetopoB and RetopoC are rejected historical studies and must not become active visual or production sources. The accepted Gate 1 source listed above is the visual source of truth; the unchanged device-free original derivative remains available for the previously specified empty-hand requirement. Preserve original shape, face, hair, wardrobe and proportions. No further procedural character reconstruction is authorized by this selection.

This is source selection, not validation of the generated topology for animation or replacement of the current production runtime asset. See `Documentation/Shipathon/S5_Original_Higgsfield_Source_Selection.json` for exact source paths and verified hashes.
