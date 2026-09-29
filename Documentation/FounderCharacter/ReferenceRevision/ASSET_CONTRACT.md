# Founder reference revision — Gate 0 asset contract

Status: **Gate 0 defined; Founder Gate 1 revision D ACCEPTED by the owner on 2026-09-26. Gate 2 is authorized and unfinished.** This explicitly reopens the Founder's visual direction because the owner supplied a new approved picture. It does not revoke the accepted runtime asset before a replacement passes later gates.

## Visual source and purpose

- Sole visual target: `Reference/founder_reference.png`, SHA-256 `2b2730136bdd28ab7512f78653d8e7486dfc58cb73169066657abe5c54596c42`. Its captions and brand copy are visual context, not implementation or gameplay instructions.
- Distinctive shape: adult Black male founder, medium-brown skin, tied-back locs with loose strands, short beard and moustache; dark open collared jacket over black shirt, dark cargo trousers, thick light trainers, dark watch, subtle necklace, slim gray tablet/laptop.
- The front, side, back and three-quarter figures in the sheet control silhouette, pose and wardrobe. The close-up controls later face and hair refinement. Hidden details stay provisional for owner review.
- Production relevance: the same Founder appears in the Garage, first-person body presentation and Atlantis route. Primary visual reads range from a close Garage view to the exterior third-person follow camera; seated fit and locomotion must remain credible after the visual gate.

## Protected production baseline

- Accepted runtime resource: `App/RealityKit/FounderCharacter/founder_candidate_a.usdz`, SHA-256 `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.
- Accepted Blender source: `Documentation/FounderCharacter/Source/founder_candidate_a.blend`, SHA-256 `d8be1e3e5cddfa69862a25ecb52f3ab95bb62d47b40364732480f5febe95843e`.
- Current contract baseline: 1.79 m standing height; 10 source meshes, 29,488 triangles, 8 materials, one 1024² skin texture, 55 deform joints, nine facial targets, and five attachment slots. The runtime package uses independently maskable modules for first-person presentation.
- Preserve `FounderGarageRealityWorld` / `USDZFounderVisualAdapter` loading, Founder camera and locomotion ownership, existing save and simulation boundaries, seated fit, head mask, attachment slots and deterministic animation behavior. The new candidate may not enter the app before owner approval and import audits.

## Candidate authoring and final targets

- Accepted Gate 1 source: `Blender/Founder_Gate1_HairRevision_D.blend`, SHA-256 `e8d96aa10d2524741e0cbc74d87bd5fd52440d1e5d4c81c98de87b6a0e02e00b`; reconstructed source input: `Source/founder_multiview_candidate.fbx`; accepted review renders: `Graybox/RevisionD/{front,side,back,three-quarter}.png`. The earlier source and A–C revisions are historical studies.
- Blender units: metres, Z-up, soles at Z=0, forward −Y, no negative root scale. Keep the approved 1.79 m height unless image comparison reveals a reason to propose a change.
- Graybox: one image-driven form is acceptable for proportion review; clay materials and no rig/clips. The reference should be packed in the `.blend`. Do not derive the new appearance from the old teal-shirt Founder mesh or procedural Swift primitives.
- Finished mobile target: at or below the accepted 29,488 triangle baseline if fidelity allows, with bounded material/texture count and no new runtime draw-call or memory regression. Revision D has 95,945 review triangles and is not export-ready. Retopology and mesh separation are required to preserve facial targets, clothing attachments and first-person masking. Any increase must be justified with measured route benefit and performance evidence.
- Rig/export compatibility: preserve the 55-joint canonical hierarchy and required facial/mask/attachment interfaces, or propose a separately reviewed migration. Preserve authored seated, standing and locomotion presentation and Reduce Motion behavior. USD uses Y-up/+Z forward after tested conversion.

## Approval sequence

1. Gate 1: revision D front, side, back and three-quarter clay views accepted by the owner on 2026-09-26. This accepts the corrected hair direction and restored shoe footprint as a graybox baseline; the shoe still needs a reference-faithful technical sneaker treatment in Gate 2.
2. Gate 2: refine face/locs/shoes, retopologize, UV, material, rig, facial targets and deformation; audit metrics.
3. Gate 3: export to a candidate USD/USDZ path and validate mesh, joint, clip, texture and mask contracts without overwriting the accepted resource.
4. Gate 4–5: test import and the actual Garage→Atlantis route on iPhone 17 Pro Max and iPad Air 11-inch (M4), plus physical review when available; compare load, memory, hitches and visual reads.
5. Gate 6: owner acceptance before changing the normal production Founder resource.


## Owner source selection — original Higgsfield models (2026-09-27)

The owner selected the original Higgsfield model after rejecting the procedural rebuilds. RetopoA, RetopoB and RetopoC are rejected historical studies and must not become active visual or production sources. The accepted Gate 1 source listed above is the visual source of truth; the unchanged device-free original derivative remains available for the previously specified empty-hand requirement. Preserve original shape, face, hair, wardrobe and proportions. No further procedural character reconstruction is authorized by this selection.

This is source selection, not validation of the generated topology for animation or replacement of the current production runtime asset. See `Documentation/Shipathon/S5_Original_Higgsfield_Source_Selection.json` for exact source paths and verified hashes.
