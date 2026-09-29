# Gate 2 topology follow-up: corrected diagnostics

**Status: topology repair incomplete; neither character is ready for weight fine-tuning or Gate 2 acceptance.**

All scene operations used Higgsfield use Blender MCP 0.2.2 with Blender 5.2.1 LTS. No Swift, runtime asset, accepted source, material source, or animation was changed.

## Correction to earlier evidence

The previous arms-raised pose used local Euler X rotation without compensating for bone roll, producing crossed hands. Corrected diagnostics convert explicit armature-space axes into bone-local quaternion axes. Raised arms now abduct outward. Elbows use 90-degree flexion. Knee flexion bends backward. The corrected matrix contains all 11 requested pose families.

Counts below include **every nonzero edge**, unlike earlier audits that excluded posed edges shorter than 12 mm. These counts must not be directly compared with those older filtered numbers. World contact is not fitted: seated, deep-hip, and knee tests retain standing root height, so floating in those tests is expected and proves nothing about seated contact.

## Rejected repair studies

- Mara F removed 55 faces selected by conflicting original arm/leg weight labels. It produced visible trouser holes. This is rejected: inconsistent weight labels do not establish an anatomical cut boundary. Counts: 8,567 vertices, 16,861 triangles, 365 boundary edges, 377 nonmanifold edges.
- Mara G welded 29 vertices in a 1.5 mm radius confined to the left sleeve microgap. Counts: 8,552 vertices, 16,921 triangles, 277 boundary edges, 291 nonmanifold edges. The old arm-raise peak strain increased from 30.61 to 36.29, and matched renders show no meaningful deformation improvement. Rejected.

The small local operations do not deliver the requested deformation loops. No premium candidate has been produced. F and G are retained only as rejected evidence; use the unchanged device-free modeling sources for further work.

## Corrected E matrix

### Mara

| Pose | Edges >1.3× | Edges >1.6× | Worst ratio |
| --- | ---: | ---: | ---: |
| neutral | 0 | 0 | 1.00 |
| relaxed | 78 | 5 | 1.97 |
| arms | 1503 | 1042 | 17.38 |
| arms-raised | 2218 | 1753 | 28.17 |
| elbows | 985 | 606 | 8.97 |
| seated-forward | 182 | 86 | 2.62 |
| deep-hip | 234 | 116 | 2.98 |
| stride-forward | 87 | 34 | 23.77 |
| stride-back | 90 | 35 | 22.69 |
| knees | 51 | 24 | 3.10 |
| wrists | 35 | 7 | 2.54 |

Renders and joint endpoints: `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE`.

### Founder

| Pose | Edges >1.3× | Edges >1.6× | Worst ratio |
| --- | ---: | ---: | ---: |
| neutral | 0 | 0 | 1.00 |
| relaxed | 325 | 38 | 2.39 |
| arms | 2377 | 1848 | 18.78 |
| arms-raised | 3203 | 2654 | 30.41 |
| elbows | 2035 | 1592 | 13.58 |
| seated-forward | 698 | 392 | 4.15 |
| deep-hip | 874 | 550 | 5.02 |
| stride-forward | 489 | 205 | 5.64 |
| stride-back | 432 | 155 | 6.48 |
| knees | 100 | 44 | 3.93 |
| wrists | 557 | 327 | 3.63 |

Renders and joint endpoints: `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE`.

## Visual findings and limits

Inspected corrected Mara raised-arm, elbow, and seated renders, and Founder raised-arm, elbow, seated, knee, and wrist renders. Both characters show large sheets of stretched garment/limb geometry under arm articulation. Founder retains wrist/hand spikes and knee collapse. Mara has pinching at the knees. Other generated matrix frames are not yet individually visually accepted. Self-intersections were not exhaustively measured. Open-edge components were localized but not fully classified as intentional or accidental.

The evidence demonstrates defective surface-to-bone ownership and deformation, but does not by itself prove that every affected surface is geometrically fused. The original position-threshold weights are an unreliable guide for topology cuts. Further repair needs anatomical surface tracing, explicit sleeve/body and hand/trouser separation where real fusion is confirmed, and rebuilt continuous loops. No more weight smoothing or indiscriminate seam deletion is justified.

## Verification

MCP operations and renders completed. No export or RealityKit integration was performed. No new Xcode build was run for this isolated diagnostic pass; the earlier successful build does not validate these assets. All owner acceptance remains pending.

## Files added by the interrupted topology pass and this continuation

- `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate2_ContactSeamStudyF.blend`
  SHA-256: `1563d90a1d05e2d1927af1265e65a0bc9178c775fbea86e914b03ad929f762ee`
- `Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate2_SleeveSeamStudyG.blend`
  SHA-256: `cf4d2fc2faffc9d40e18df45f618aee1effd19b4849114393c60c57a3616e8b3`
- `Assets/Atlantis/Characters/MaraChen/Gate2/ContactSeamStudyF/arms.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/ContactSeamStudyF/neutral.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/ContactSeamStudyF/seated-forward.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/arms-raised.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/arms.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/deep-hip.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/elbows.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/knees.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/metrics.json`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/neutral.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/relaxed.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/seated-forward.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/stride-back.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/stride-forward.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/CorrectedPoseMatrixE/wrists.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/TopologyComparisonE/arms-raised.png`
- `Assets/Atlantis/Characters/MaraChen/Gate2/TopologyComparisonG/arms-raised.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/arms-raised.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/arms.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/deep-hip.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/elbows.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/knees.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/metrics.json`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/neutral.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/relaxed.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/seated-forward.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/stride-back.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/stride-forward.png`
- `Documentation/FounderCharacter/ReferenceRevision/Gate2/CorrectedPoseMatrixE/wrists.png`
- `Documentation/Shipathon/S5_Gate2_BoundaryComponents_Founder.json`
- `Documentation/Shipathon/S5_Gate2_BoundaryComponents_Mara.json`
- `Documentation/Shipathon/S5_Gate2_TopologyAudit_FounderD.json`
- `Documentation/Shipathon/S5_Gate2_TopologyAudit_FounderE.json`
- `Documentation/Shipathon/S5_Gate2_TopologyAudit_MaraD.json`
- `Documentation/Shipathon/S5_Gate2_TopologyAudit_MaraE.json`
- `Documentation/Shipathon/S5_Gate2_TopologyAudit_MaraG.json`
