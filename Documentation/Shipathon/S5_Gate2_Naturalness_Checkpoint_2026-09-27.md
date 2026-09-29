# S5 Gate 2 naturalness checkpoint — 2026-09-27

Status: **work in progress; neither character is ready for Gate 2 owner review.**
All scene edits and renders in this checkpoint used the Higgsfield use Blender MCP.
No USD/USDZ export or RealityKit integration was performed.

## Owner direction

- Preserve both accepted Gate 1 character silhouettes.
- Make standing and motion presentation feel natural rather than stiff.
- A held device is optional; it must not dictate either character's pose.

## Accepted source locks

| Asset | Path | SHA-256 |
| --- | --- | --- |
| Founder Gate 1 revision D | `Documentation/FounderCharacter/ReferenceRevision/Blender/Founder_Gate1_HairRevision_D.blend` | `e8d96aa10d2524741e0cbc74d87bd5fd52440d1e5d4c81c98de87b6a0e02e00b` |
| Mara Gate 1 | `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate1_Source.blend` | `de5da5d7918af269791d29ca256f76cc92aca2043b279d9e34cca2cc95e98304` |
| Accepted production Founder USDZ | `App/RealityKit/FounderCharacter/founder_candidate_a.usdz` | `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |

## Current Blender studies

| Asset | Source | Metrics | Status |
| --- | --- | --- | --- |
| Founder rig study B | `Documentation/FounderCharacter/ReferenceRevision/Blender/Founder_Gate2_RigStudyB.blend` | 25,466 triangles; 12,786 vertices; 25 meshes; 55 joints; five named slots; zero facial targets | Structural study only. SHA-256 `2e0554d39ce19c871e872e8aa043f101d542638ae1f97c43f1ea4adcf6ee8430`. |
| Mara clip study | `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate2_ClipStudy.blend` | 17,039 triangles; 8,550 vertices; one mesh; one 1024² color atlas; 20 joints; actions `idle`, `deviceIdle`, `noticeFounder` | Timing study only. SHA-256 `8eca0358a37443a58c4fc49279fe57f923eaf326325d82585d3eba001f019746`. |
| Mara skin-weight study C | `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate2_RigStudyC.blend` | 566 texture-guided skin vertices reweighted | **Rejected**: arm bend exposes torn sleeves/hand-device geometry. SHA-256 `494d3e7ed096e3ef92824afac26e5f61fc41b9c28a0b8e1ebfaf45518b3b0420`. |

## Visual checks

- Founder standing pose C: `Documentation/FounderCharacter/ReferenceRevision/Gate2/NaturalPose/C-three-quarter.png`
- Mara standing pose C: `Assets/Atlantis/Characters/MaraChen/Gate2/NaturalPose/C-three-quarter.png`
- Mara `idle` and `noticeFounder` frame studies: `Assets/Atlantis/Characters/MaraChen/Gate2/ClipStudy/`
- Founder deformation failure: `Documentation/FounderCharacter/ReferenceRevision/Gate2/DeformationB/arms.png` and `seated.png`
- Mara deformation failure: `Assets/Atlantis/Characters/MaraChen/Gate2/DeformationC/arms.png`
- Face detail limits: each character's `Gate2/TextureStudy/face.png`

## Findings and next modeling pass

The earlier generated source meshes fused the device with the hand and nearby clothing. The later device-free rebuild below supersedes that topology study. The face textures still contain visible projection errors. Preserve the Gate 1 silhouettes and current shoe footprints. Recheck arms, seated and stride deformation before rendering a Gate 2 owner package.

Mara's three authored actions are available for timing inspection, but they are **not deformation approved**. Founder has not passed canonical clip, first-person mask, facial-target, or seated-fit checks. Neither Gate 2 source may be exported yet.

## Device-free image-driven remodel — latest work

The approved Founder and Mara reference sheets were converted into device-free front and side modeling references. Higgsfield Tripo H3.1 produced new 3D sources from those images. All import, scale, orientation, reduction, UV/bake, rigging studies, and rendering occurred through the Higgsfield use Blender MCP. Neither accepted Gate 1 source nor the production Founder USDZ was overwritten.

| Character | Current device-free modeling source | SHA-256 | Height | Vertices | Triangles | Character meshes | Materials | Textures | Rig/facial/actions |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Mara Chen | `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate2_DeviceFreeLOD.blend` | `535b01a7a72aca32485fe3c24ff4b1a503687b347faa7ecb5d8734d49adb02c5` | 1.68298 m | 8,581 | 16,940 | 1 | 1 | 1 × 1024² color atlas | 0 joints, 0 facial targets, 0 actions in this modeling source |
| Founder | `Documentation/FounderCharacter/ReferenceRevision/Blender/Founder_Gate2_DeviceFreeLODUV.blend` | `98d208c326515bcb5e9a968b8ffd35334f67295b088e82ad688d3127d1b40dfa` | 1.78989 m | 14,526 | 29,053 | 1 | 1 | 4 × 4096² source maps | 0 joints, 0 facial targets, 0 actions in this modeling source |

Matched front, side, back, and three-quarter review renders are under `Assets/Atlantis/Characters/MaraChen/Gate2/DeviceFreeReviewB/` and `Documentation/FounderCharacter/ReferenceRevision/Gate2/DeviceFreeReview/`. The higher detail review sources are `MaraChen_Gate2_DeviceFreeReviewB.blend` and `Founder_Gate2_DeviceFreeReview.blend`. The device-free modeling sources have empty relaxed hands. Shoes, clothing, bun, and tied loc shapes are visible, but facial likeness and material quality remain below final Gate 2 standard.

Separate rig experiments are `MaraChen_Gate2_DeviceFreeRigStudy.blend`, `Founder_Gate2_DeviceFreeRigStudy.blend`, and `MaraChen_Gate2_DeviceFreeVoxelRigStudy.blend`. Manual weights tear sleeves and hips during arms/seated poses. Mara's original reduced mesh has 302 open boundary edges and automatic bone heat assigned no weights. A 5 mm sealed voxel remesh removed all boundary edges, kept 16,900 triangles, and let bone heat assign 8,424 of 8,430 vertices. Its clay pose renders under `Assets/Atlantis/Characters/MaraChen/Gate2/DeviceFreeVoxelDeformation/` still show gaps and loss of face/shoe detail. This study is **rejected for production**. The separate rig studies do not change the counts in the modeling-source table.

**Gate 2 status: modeling source refreshed without devices; production rig, facial targets, actions, deformation, and final material optimization remain incomplete. No owner Gate 2 decision is requested yet.**

## 2026-09-27 follow-up — Mara local weight study D

All Blender scene operations in this follow-up used the local Higgsfield use Blender MCP (`fnf-blender-mcp` 0.2.2, Blender 5.2.1 LTS). The initial MCP launch crashed inside the command sandbox; the same MCP operation succeeded outside it. No accepted source or runtime asset was overwritten.

- New study: `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate2_DeviceFreeWeightStudyD.blend`, SHA-256 `7b07a86c3d90eb241a96ea9893d216f6e817f733dce40dc728f3f326e00c8806`.
- Matched arm-pose and seated diagnostic renders: `Assets/Atlantis/Characters/MaraChen/Gate2/DeviceFreeWeightStudyD/arms.png` and `seated.png`.
- The device-free LOD source has 8,581 vertices, 16,940 triangles, 302 boundary edges, 314 nonmanifold edges, and one large 8,427-vertex component plus small islands. This remains unchanged.
- The existing manual rig study had adjacent vertices only 3–5 mm apart assigned completely to different bones around the sleeves, hands, trouser sides, and hips. In the diagnostic arm pose, 527 edges stretched more than 1.6×, with a worst measured ratio of 46.25×. The mismatch explains the long triangular tears.
- Study D locally regularized weights around these high-stretch edges (1,839 affected vertices; 20 joints retained). The same arm-pose measurement dropped to 253 edges over 1.6×, worst 8.29×. Triangle and vertex counts stayed at 16,940 and 8,581. The arm render is visibly cleaner, but small side artifacts remain.
- The inherited `seated.png` diagnostic rotates both thighs backward under this rig's bone axes, so its severe trouser/hip ballooning is not a valid seated-fit verdict. A corrected forward-knee pose is captured in `seated-forward.png`. It gives a more plausible thigh shape, but a hip-side tear and missing seat/foot contact remain. Study D is **not accepted** for production or Gate 2 owner review.

Next: rebuild/retopologize the sleeve-to-hand and trouser-to-hip transitions as intentional deforming regions, preserve the accepted silhouette and shoe footprint, then repeat neutral/arm/seated/stride checks. Facial likeness, material cleanup, facial targets, and validated actions remain open for both characters. Do not export USD/USDZ or integrate into RealityKit before Gate 2 owner acceptance.

### Founder comparison study D

- New study: `Documentation/FounderCharacter/ReferenceRevision/Blender/Founder_Gate2_DeviceFreeWeightStudyD.blend`, SHA-256 `2ba0ad9be9d8073b371fbc851e9d42a4532609d9041b433671e9faf6c01aa2b1`.
- Diagnostic renders: `Documentation/FounderCharacter/ReferenceRevision/Gate2/DeviceFreeWeightStudyD/arms.png`, `seated.png`, and corrected `seated-forward.png`.
- The unchanged Founder device-free modeling mesh has 14,526 vertices, 29,053 triangles, 31 boundary edges, and 35 nonmanifold edges. The study retains 55 joints and five named slots, with no facial targets or actions.
- Local weight regularization affected 2,036 vertices. The matched arm-pose edge audit changed from 442 to 404 edges over 1.6× stretch, worst 61.69× to 12.13×. The arm render still has hand/garment artifacts. The seated render shows inflated hips, poor leg placement, and floating footwear; it is not seated-fit evidence.
- The inherited `seated.png` pose bends the knees backward and is not a valid seated-fit verdict. The corrected forward-knee `seated-forward.png` looks closer to a seated pose but retains knee/cloth tears, has no chair contact, and floats above the floor. This study is **not accepted** for production or Gate 2 owner review. Local weight cleanup alone has not solved the generated mesh's deformation topology. First-person masking, locomotion, facial targets, and source-map optimization remain unverified.

### Seated-weight study E

The corrected forward-knee pose motivated a second local weight pass on copies of study D. These are comparison studies, not accepted sources.

| Asset | Study E SHA-256 | Corrected seated pose: edges >1.6×, D → E | Worst seated edge, D → E | Arm pose: edges >1.6×, D → E |
| --- | --- | ---: | ---: | ---: |
| Mara `MaraChen_Gate2_DeviceFreeWeightStudyE.blend` | `c096ab6ca4268e30b3a5fbed893adfcb1eebe5aa6b86687f36e2ce0e63178b39` | 104 → 71 | 8.00× → 2.59× | 253 → 303 |
| Founder `Founder_Gate2_DeviceFreeWeightStudyE.blend` | `39921ada48719bcff4603b6a452c3d4e3b9986a1e4b00d8d37599ae33df41ba4` | 416 → 228 | 23.58× → 5.67× | 404 → 469 |

Matched E renders are under each character's `Gate2/DeviceFreeWeightStudyE/` (`arms.png`, `seated-forward.png`). The E seated metric improves, but the arm edge count regresses; visual differences are modest and remaining hand/cloth, thigh, and knee artifacts are visible. Keep D and E as diagnostic studies only. A future pass should separate real garment/limb regions and form suitable deformation loops, then tune weights against all required poses together. Do not stack more smoothing as a substitute for topology repair.

Verification: the `Solo Unicorn Run` scheme built successfully for generic iOS Simulator with DerivedData under `/private/tmp/solo-gate2-build`. No Blender character study was added to the Xcode target, exported, or exercised by that build. There are no focused XCTest cases for these isolated `.blend` studies. The accepted Gate 1 Mara, Gate 1 Founder revision D, production Founder USDZ, and both device-free modeling-source hashes still match the locks listed above.

## Corrected topology diagnostics follow-up

See `S5_Gate2_Topology_Followup_2026-09-27.md` for the latest evidence and file inventory. Mara F contact cuts and G sleeve weld are rejected. The old arms-raised local-Euler diagnostic was anatomically misleading; both characters now have a corrected 11-pose clay matrix under `Gate2/CorrectedPoseMatrixE/`, with explicit joint endpoints and unfiltered edge metrics. Those metrics use a different counting rule from the older length-filtered audits. Topology repair remains incomplete, with no new accepted candidate and no readiness for weight fine-tuning. Do not infer actual geometric fusion solely from the original inconsistent skin weights.
