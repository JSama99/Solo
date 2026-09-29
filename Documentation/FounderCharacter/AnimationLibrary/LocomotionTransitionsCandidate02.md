# Founder locomotion transitions — revision 02

**Status:** Owner motion accepted on 2026-09-28. Standing Idle 01, Walk Start 01, Natural Walk Candidate 02, Walk Stop Revision 02, and both Turn In Place Revision 02 Actions are locked. This acceptance covers the Blender motions, not production transfer or deformation.

## Controlled variant decisions

| Variant | Internal decision | Finding |
|---|---|---|
| STOP-A — smaller final step / narrower settle | REJECT | The accepted walk entry, fixed support contact, and accepted idle endpoint fix the final shoe positions. Its in-air swing adjustment did not actually narrow the final planted stance. Narrowing it would require a new idle endpoint or support-foot drift. |
| STOP-B — pelvis/torso absorption | RETAIN | More gradual settling, with entry and idle handoffs unchanged. |
| STOP-C — shoulder/arm decay | RETAIN | Upper body follows the deceleration later without changing foot contacts. |
| TURN-A — shorter duration | RETAIN | 1.50 s on both sides, within the requested 1.3–1.6 s study range. |
| TURN-B — overlapping body phases | RETAIN | Pelvis/torso and trailing-foot responses overlap more; no dual-air support gap. |
| TURN-C — head anticipation | RETAIN | Earlier, smaller head response; final heading handoff unchanged. |
| TURN-D — reduced placement pause | REJECT | It lifted both shoes more than 2 mm at once (left frame 23; right frames 23–24). TURN-B already reduces the visible gap without this defect. |

The accepted composite uses **STOP-B+C** and **TURN-A+B+C**. “Retain” in the table records the earlier internal study decision; the owner subsequently accepted the composite Actions on 2026-09-28. [Variant comparisons](OriginalFounder/Transitions02/Variants/index.html) include each family against the previous transition.

## Candidate and review

- [Editable Blender candidate](OriginalFounder/Transitions02/Founder_LocomotionTransitions_Candidate02.blend)
- [Review page](OriginalFounder/Transitions02/index.html): five complete chains, normal and slow playback, frame stepping, previous three-quarter baseline, matched key stills, and front/side views where support or stance needs inspection.
- [Render manifest](OriginalFounder/Transitions02/render_manifest.json) and [pose/contact audit](OriginalFounder/Transitions02/audit.json).

The Stop action remains **1.20 s**; each Turn action is **1.50 s**. All run at **30 FPS** on the original textured Higgsfield Founder. Saved actions have zero root translation and zero baked root rotation. The review fixture alone supplies 1.4 m/s steady-walk travel, deceleration, and ±90° heading. Candidate 02, Idle 01, and Start 01 source actions were not edited.

The maximum checked joint-position mismatch at an action handoff is **0.00000027 m**, with zero angular mismatch. Turn planted-sole movement stays below **0.31 mm**; both turns retain at least one shoe within 2 mm of the floor. No ground penetration was measured. The stop preserves the previous support-contact schedule and has planted-sole movement below **0.39 mm**.

**Known review limits:** The stop's final planted stance width remains the accepted idle width; a narrower endpoint conflicts with the locked idle and fixed planted support. The stop audit flags both soles above 2 mm in frames 1–5; direct comparison with the previous stop shows the same opening sole heights, inherited from the locked walk entry. The revision does not introduce those frames. This study mesh is not proof of production deformation.

No export, RealityKit integration, app-asset replacement, sit/stand work, or Mara/NPC propagation was performed. The owner's 2026-09-28 ACCEPT locks Walk Stop Revision 02 and both Turn In Place Revision 02 Actions.

## Higgsfield authoring path

All scene edits, animation sampling, auditing, previews, and `.blend` saves in this pass ran through **Higgsfield use Blender MCP**. That MCP executes Blender operations; it does not generate motion by itself. Higgsfield's native `3d_rigging` model currently accepts a `model_url` and preset `animation_action_id`, so it is a separate rig/clip generation path rather than an in-place edit of these locked Actions. No paid generation was submitted for this constrained polish pass.
