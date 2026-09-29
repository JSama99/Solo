# Founder Natural Walk Candidate 02 — owner motion accepted

**OWNER MOTION ACCEPTED — 2026-09-28.** The owner's transition-study request
accepts this exact source as the locked walking target. Its SHA-256 remains
`fa705b09bd550b17266a5ecc74869e52f1db51759dfcf80afafe7fa4390f757e`.
This acceptance covers the Blender motion study, not production deformation,
USDZ export or RealityKit integration. The observations below record the
original Candidate 02 review package.

## Locked foundation

Candidate 01 source SHA-256:
`72e1471861f4a330f82063f42afc5620c6f73b9cbe4064b82b823cff5cb5b3b6`.
The B/C/D2/E/F/G foundation was copied as an action and not overwritten. The
left/right contact frames remain 1 and 16, at 30 FPS and a 1.00 s cycle.
Expected gameplay displacement remains 1.40 m per cycle at 1.4 m/s, owned by
the simulation; armature Root translation is zero. D2's animated heel/toe pivot
remains in the source. All renders use the original textured Founder model, same
lights, orthographic camera positions, 360×480 image area, 30 FPS and two cycles.

## Separate H–M decisions

| Family | Internal decision | Check against Candidate 01 |
| --- | --- | --- |
| H — loading recovery | **Accept** | Longer support response near frames 5–7; checked head-height range stays 106.25 mm, essentially unchanged. No new shoe float. |
| I — pelvis roll | **Accept** | ~0.69° stance roll; hip lateral range remains 41.77 mm, with no added sway. |
| J — torso/shoulder | **Reject** | Chest increment turned the head too far; max yaw 0.0050 → 0.0134 rad. |
| J2 — corrected chain | **Accept** | Same torso/shoulder timing plus compensating head yaw; max yaw remains 0.0050 rad. No checked sleeve tear. |
| K — arm relaxation | **Accept** | Slightly wider arm arc and softer elbows/forearms; checked side/front frames show no hand-body collision. |
| L — ankle/push-off | **Accept** | Small extra toe-pivot rotation after D2; incoming contact matches and no checked foot float. Whole-sole rolling motion peaks at 5.41 mm versus 4.14 mm in Candidate 01. |
| M — neck/head lag | **Accept** | Very small delayed neck/head motion; max world head yaw 0.0039 rad, head-height range +0.22 mm. |

Each family has its own editable `.blend`, `audit.json`, `decision.json`,
matched stills and side/front/three-quarter MP4s under
`OriginalFounder/Polish/<family>/`. A rejected J study remains for traceability;
J2 alone is combined.

## Combined candidate

- Blender source:
  `OriginalFounder/Combined02/Founder_NaturalWalk_Candidate_02.blend`
  SHA-256 `fa705b09bd550b17266a5ecc74869e52f1db51759dfcf80afafe7fa4390f757e`.
- Action `Founder_NaturalWalk_Candidate_02` combines H, I, J2, K, L and M on
  Candidate 01. Accepted foundation and original textured mesh are preserved.
- `OriginalFounder/Combined02/Review/Candidate02-{side,front,three-quarter}.mp4`
  are 2.0 seconds each. Matched stills at frames 1 (contact), 9 (passing) and
  16 (opposite contact) are included, plus frames 6 and 14 for loading/push-off.
- Evaluated mesh frame-1/31 difference: 0.00062 mm; Root translation: 0.
  Lowest mesh point: 0.104 mm above ground. Rolling-sole horizontal displacement:
  left 5.41 mm, right 2.23 mm. The planted foot at the two contact frames is
  within ~0.002 mm of Candidate 01's ankle; the other foot differs by ~3.3 mm
  because of the extra toe-off.
- Head world yaw max 0.00394 rad. Hip lateral range unchanged at 41.77 mm.
  Head vertical range is 106.46 mm versus Candidate 01's 106.25 mm.

## Limits

The large ~106 mm vertical range comes from the already locked Candidate 01
stride/leg-reach geometry. H does not add a new range extreme on its own;
Candidate 02 changes the total range by ~0.21 mm. This number is a reason for
owner motion review and must not be described as proven naturalness. Rendered
stills were inspected, but continuous motion, full-turn deformation, seated fit,
first-person masking, game camera and device acceptance remain unverified.
This study mesh and transferred skin weights are not production deformation proof.

## Verification and boundaries

Higgsfield use Blender MCP / Blender 5.2.1 LTS authored and rendered every
variant. Python sources parsed, each standalone action's root/seam/ground audit
passed, and all three final MP4 containers were checked at exactly 2.0 seconds.
The original Founder and Mara sources, Candidate 01, and production Founder USDZ
retain their recorded SHA-256 hashes. Existing worktree changes outside this
animation library were preserved. No Xcode/simulator run was warranted because
no iOS asset or source was installed or changed. Do not export, integrate into
RealityKit, alter production assets or propagate this motion to Mara/NPCs before
owner acceptance and a separate production deformation gate.

`created_files.json` lists every animation-library file and SHA-256 hash.
