# Founder locomotion chain review

**Study status:** Seven requested chains assembled from the six owner-accepted Actions without editing them. The motion and source files remain locked. Automated continuity checks pass; owner review of the continuous clips is pending. These are Blender studies, not Garage→Atlantis production-route evidence.

## Review clips

| Chain | S4 C2-style rear camera | Additional view |
| --- | --- | --- |
| A · idle → start → walk | [MP4](A-idle-start-walk-gameplay.mp4) | [Accepted start study](../OriginalFounder/Transitions01/Review/walkStart-Candidate02-three-quarter.mp4) |
| B · walk → stop → idle | [MP4](B-walk-stop-idle-gameplay.mp4) | [Accepted stop study](../OriginalFounder/Transitions02/Review/Candidate02-stop02-idle-three-quarter.mp4) |
| C · left turn → start → walk | [MP4](C-left-start-walk-gameplay.mp4) | [Accepted transition study](../OriginalFounder/Transitions02/Review/turn02-left-start01-Candidate02-three-quarter.mp4) |
| D · right turn → start → walk | [MP4](D-right-start-walk-gameplay.mp4) | [Accepted transition study](../OriginalFounder/Transitions02/Review/turn02-right-start01-Candidate02-three-quarter.mp4) |
| E · idle → start → walk → stop → idle | [MP4](E-forward-complete-gameplay.mp4) | [Three-quarter MP4](E-forward-complete-three-quarter.mp4) |
| F · idle → left turn → start → walk → stop → idle | [MP4](F-left-complete-gameplay.mp4) | [Three-quarter MP4](F-left-complete-three-quarter.mp4) |
| F · idle → right turn → start → walk → stop → idle | [MP4](F-right-complete-gameplay.mp4) | [Three-quarter MP4](F-right-complete-three-quarter.mp4) |

The [render manifest](render_manifest.json) records frame counts and clip segments. The S4 C2-style camera uses the production follow offset `(0.72, 1.72, 2.35)` and 70° FOV with a Blender turn-follow approximation. The plain review set contains no Atlantis geometry or production camera controller, so it cannot approve runtime camera comfort or route performance.

Standalone gameplay-style phases: [idle](S4C2-idle.mp4) · [start](S4C2-start.mp4) · [continuous walk](S4C2-continuous-walk.mp4) · [stop](S4C2-stop.mp4) · [left turn](S4C2-left-turn.mp4) · [right turn](S4C2-right-turn.mp4) · [full loop](E-forward-complete-gameplay.mp4). The six short phase files were trimmed from the chain renders without changing the Actions.

## Continuity and movement fixture

- Blender 5.2.1 LTS, 30 FPS; one-second Candidate 02 gait cycle; contact frames 1 and 16; expected world displacement 1.4 m/cycle at the unchanged 1.4 m/s gameplay speed.
- Accepted review acceleration covers 0.315 m in `walkStart`; deceleration covers 0.385 m in `walkStop`. A null parent supplies all review travel and post-turn heading. The saved Actions retain zero authored Root translation and rotation.
- [Per-boundary rates](continuity_audit.json) check pelvis, torso, shoulders, arms, legs/feet, and head. The largest local rotation pose delta across idle/start/walk/stop handoffs is below 0.0007 rad; local location delta is zero. At the turn boundary, local pose channels change by 90° because the external container takes over heading. The earlier evaluated-mesh turn→idle seam is below 1 µm after that handoff; start begins at the same accepted idle pose.
- Frame-strip inspection of [left turn](C-left-start-walk-sheet.png), [right full loop](F-right-complete-sheet.png), [complete gameplay loop](E-forward-complete-sheet.png), and [three-quarter loop](E-forward-complete-three-quarter-sheet.png) found no obvious framing or floor-contact break in the sampled frames. Continuous acceleration, stop absorption, foot release, arm/head behavior, and perceived bounce require owner playback review.
- Candidate 02's measured 106 mm head vertical range remains a runtime-view concern to inspect; this Blender approximation does not justify changing the accepted motion.

## Transfer gate

The [motion library manifest](motion_library_manifest.json) records every accepted Action and its source hash. The [skeleton compatibility report](skeleton_compatibility.md) classifies bone names/hierarchy/scale as PASS, rest and deform-role differences as ADAPTER REQUIRED, and the unrigged revised visual mesh as a BLOCKER. Candidate 02 copy-only retarget proof and the deformation gate were deferred by that compatibility result. No USD/USDZ export, RealityKit integration, Swift edit, production Founder edit, or Mara locomotion was performed.

Verification: Higgsfield Blender MCP completed all ten renders with the source hash unchanged. AVFoundation opened all 16 new MP4s, each with one video track and the expected duration. Python syntax, JSON, review links, and artifact SHA-256 values passed. Xcode tests and simulator captures were not run because no app source or runtime asset was changed, and this request explicitly stops before RealityKit integration. Device motion and camera acceptance remain open.

The [artifact manifest](artifact_manifest.json) lists every new or modified file in this pass with its absolute path and SHA-256.

**FOUNDER LOCOMOTION LIBRARY — CHAIN VALIDATION: automated PASS; owner visual review pending.**

**FOUNDER PRODUCTION TRANSFER READINESS — BLOCKED.**
