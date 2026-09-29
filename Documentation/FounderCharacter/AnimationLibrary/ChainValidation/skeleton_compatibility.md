# Founder locomotion transfer readiness

Inspected on 2026-09-28 with Higgsfield use Blender MCP / Blender 5.2.1 LTS. This is a read-only comparison of the accepted locomotion study with the current production Founder source and the [Gate 0 asset contract](../../ReferenceRevision/ASSET_CONTRACT.md). No animation was transferred.

| Interface | Result | Evidence |
| --- | --- | --- |
| Bone names | **PASS** | Both armatures contain the same 55 names; no missing or extra names. |
| Parent hierarchy | **PASS** | All 55 parent names match. |
| Armature object scale and height | **PASS** | Both armatures have scale `(1,1,1)` and bone Z extent approximately 0–1.7877 m; the production character contract is 1.79 m. |
| Rest positions | **ADAPTER REQUIRED** | Largest head delta is 0.3577 m and largest tail delta is 0.4139 m. The `Hand_L` head has the largest offset. |
| Rest orientations and lengths | **ADAPTER REQUIRED** | Eight bone directions differ by more than 10°; `LowerArm_L` differs by 54.59°. `Hand_L` length differs by 57.2 mm. Directly copying pose channels would not preserve the accepted hand/arm motion. |
| Deform roles | **ADAPTER REQUIRED** | 33 `use_deform` flags differ, including Root, finger chains, and eyes. Production requires those roles and the existing 55-joint package contract. |
| Production modular and facial interfaces | **ADAPTER REQUIRED** | Production source has 10 skinned meshes, nine named facial targets, and five attachment slots. The locomotion study uses one review mesh. Transfer must target the production skeleton and preserve the production mesh, slots, facial targets, and independently maskable head modules. |
| Revised visual mesh deformation | **BLOCKER** | The historical RetopoC study is unrigged (`joint_count: 0`), marked REVISE, and rejected as an active source. The owner-selected original visual source still needs accepted topology, skinning, facial targets, and deformation before this gate can run. |

The [Blender study audit](blender_audit.json) and [production source audit](production_rig_audit.json) contain the compared bone records. Source SHA-256: study `c9b2924556e79e75004d3a9aa15a7bb14d1a539195f13bb68c8eaa96ff56c7d0`; production `d8be1e3e5cddfa69862a25ecb52f3ab95bb62d47b40364732480f5febe95843e`.

**Decision:** Production transfer is **BLOCKED**. A rest-pose-aware adapter must first be demonstrated on a copy of the current production skeleton, then checked for Candidate 02 contacts, pelvis/torso/arm phase, head stabilization, and loop seam. The 33 deform-role differences must be resolved or explicitly mapped. The copy-only retarget proof was not performed because this compatibility gate is not yet sufficient for a meaningful motion-preservation claim. Do not transfer the remaining library, use the rejected RetopoC mesh, or run a deformation gate until a rigged candidate passes its topology gate.
