# Shipathon visual lock — S2/S3/S4 recovery checkout

## S4 camera accepted — C2 stopped Shot 5 reveal

On 2026-09-26 the owner answered **ACCEPT** to the revised C2 camera review. C2 is the production camera treatment: centered yaw through Garage handoff, Shot 4, and forward travel; a bounded 0.75 rad pan toward the Spire only after a brief stop in the Shot 5 window; centered recovery on restart, steering, reverse, or Reduce Motion. The 0.75 rad continuous walking-pan D study remains a comparison reference, not production control. The exterior follow offset `(0.72, 1.72, 2.35)`, 70° FOV, 1.4 m/s traversal, route, Founder asset, Material B, A2 daylight, Atmosphere A, and save version 20 remain locked.

The [S4 review](SHIPATHON_S4_MOVEMENT_CAMERA_REPORT.md#september-26-recovery-and-revised-c2-review) contains matched iOS 26.5 iPhone 17 Pro Max and iPad Air 11-inch (M4) key frames and simulator movement evidence. `--shipathon-s4-camera-a` retains the old centered camera for matched comparison; B and D remain opt-in study fixtures. Human acceptance covers the reviewed C2 camera composition and feel, not Founder gait naturalness or physical-device GPU performance. S5 has not begun.

## S3 lighting and atmosphere accepted — A2 + Atmosphere A

The owner accepted **A2** lighting after the local Shot 4 Garage exterior visual-family handoff repair cleared the stepped rendering artifact, then accepted **Atmosphere A** on 2026-09-25. Production daylight uses Atlantis sun direction `[-4.6, 7.0, 9.0]`, intensity `5,200`, RGB key `[1.00, 0.96, 0.89]`, environment exponent `−1.25`, and Atlantis directional shadows **off**. Production Atmosphere A uses exterior sky top `[0.22, 0.51, 0.77]`, bottom `[0.68, 0.82, 0.93]`, and the existing far Spire proxy's neutral IBL RGB `[0.98, 0.99, 1.00]` at exponent `−1.40`. The main district IBL remains `−1.25`. The sky treatment begins only after the accepted Atlantis camera handoff; foreground geometry and Material B are unchanged. `--s3-atmosphere-baseline` retains the pre-atmosphere A2 look for comparison, and Atmosphere B remains an unselected opt-in study. The Garage exterior ground visual scoping, S2 camera/material/route locks, Founder presentation, and save version 20 remain in force. [Matched atmosphere captures and verification](SHIPATHON_S3_LIGHTING_ATMOSPHERE_REPORT.md#current-s3-atmosphere-round-2026-09-25) support this lock. Physical-device visual review remains open because the paired iPad required unlock.

S1 route direction remains accepted: Founder Garage → first Founder Street corridor → Founder District peer area. The original S1 audit and decision are preserved verbatim in [SHIPATHON_S1_VISUAL_LOCK_PRESERVED.md](SHIPATHON_S1_VISUAL_LOCK_PRESERVED.md), copied from the Core Experience worktree with matching SHA-256. This S2 file records later owner decisions without replacing S1 history.

## S2 complete — hero environment accepted

- **Shot 3: ACCEPTED B.** Retained Garage camera through spatial clearance, original follow offset, 70° exterior FOV, scoped blocker hiding, and Reduce Motion immediate handoff.
- **Shot 4: ACCEPTED A / BEST-EFFORT LOCK.** The owner selected [production baseline A on iPhone](Captures/S2D/Shot4-iPhone/A-baseline.png), confirmed by the matched [iPad A](Captures/S2D/Shot4-iPad/A-baseline.png). The arrival remains sparse; [B at ~15°](Captures/S2D/Shot4-iPhone/B-built-side.png) and [C shoulder](Captures/S2D/Shot4-iPhone/C-shoulder.png) did not materially improve the primary frame. A small streetlight study was removed. Normal control alignment is preserved.
- **Shot 5: KEEP D visual direction.** Preserve the Spire hierarchy and layered skyline from the real route. The 43° yaw remains an opt-in study, not the production camera.
- **Material B: ACCEPTED.** Fifteen existing families, zero textures, and the road/walk/kerb/grass/façade/window differentiation remain unchanged.
- **Route: ACCEPTED for Shipathon staging.** Garage → Founder Street → relocated peer point near `(-825, 8.375, 940)` remains reachable in the measured production route.

The [S2D report](SHIPATHON_S2_HERO_ENVIRONMENT_REPORT.md#s2d-shot-4-composition-round-2026-09-23) records the matched comparison, geometry, and verification. The [four-frame S2 sequence](SHIPATHON_S2_HERO_ENVIRONMENT_REPORT.md#s2d-shot-4-composition-round-2026-09-23) is the baseline for S3 Lighting & Atmosphere. S3 should preserve this camera, material, route, and staging lock unless lighting reveals an objective defect.

## S2C owner choices — KEEP

- **Shot 3 threshold: B accepted.** Spatially delayed Garage→Atlantis camera handoff, original follow offset, 70° exterior FOV. [iPhone baseline/A/B](SHIPATHON_S2_HERO_ENVIRONMENT_REPORT.md#s2c-selected-result-2026-09-23) and [iPad B exterior](Captures/S2C/ThresholdB-iPad/0A4174A6-4F10-41EF-A9CE-5A7EA5A66C6F.png) support this selection. The selected treatment is the normal production path.
- **Founder District materials: B accepted.** Coherent stylized road, walk, kerb, grass, façade and window response; 15 material families, zero textures. [Shot 4 B](Captures/S2C/MaterialB-iPhone/766E6209-D93B-484B-9DA7-1E9B9015F4E8.png) and [Shot 5 B](Captures/S2C/MaterialB-iPhone/735D958A-E006-4B96-BD82-7707910A0D1A.png). The close foreground remains sparse and is a visible limitation of this S2C pass.
- **Shot 5 direction remains D.** Preserve the Spire and layered skyline at the real route position. D's 43° yaw remains an opt-in composition reference for S4 camera-feel review.

The sections below describe prior S2B decisions and open gates at that historical checkpoint. S2C final performance and S2D closure are tracked in the hero environment report. Do not read the S2B historical status text as the current S2 state.

## S2B shot intent

- **Shot 3 — Garage threshold:** physical Garage-to-city transition; no skyline requirement.
- **Shot 4 — first exterior:** credible, intentional immediate environment; no Spire requirement.
- **Shot 5 — Founder Street:** the accepted D-direction Spire and layered skyline hierarchy.

This shot split is the owner-supplied S2B intent. It is not acceptance of the current threshold, exterior, material, or gameplay-camera implementation.

## S2 Shot 5 direction — KEEP

On 2026-09-23 the owner chose **“keep shot 5”** after reviewing the real-route C/D comparison. This keeps **Variant D's Spire/skyline composition as the Shot 5 visual direction**, not the entire S2 environment or production camera implementation.

- Real production route: Garage handoff → street threshold `(−874.6, 8.03, 1040.6)` → east turn → ~21.5 m east to `(−853.1, 8.03, 1039.3)`.
- [iPhone 17 Pro Max D frame](Captures/S2/FirstStreet-CD-Fresh-iPhone/AA0424B4-038B-4C4E-A15C-5B7638D3D570.png) and [iPad Air 11-inch (M4) D frame](Captures/S2/FirstStreet-CD-iPad/679F8215-5FE3-4F7F-84CF-6ECB8AFCC4A7.png) are the visual references. [C at the same iPhone position](Captures/S2/FirstStreet-CD-Fresh-iPhone/2F9B5F5F-7212-4E7E-8598-485007DE5A96.png) lacks the landmark.
- D study state: production day lighting; accepted Founder asset and Garage; 70° vertical FOV; original `(0.72, 1.72, 2.35)` camera offset; up to 0.75 rad (~43°) street-only camera yaw. Only opt-in launch argument `--shipathon-s2-camera-d` enables it. No gameplay, collision, speed, or save changes.

The lock is to preserve the **landmark hierarchy and real-route viewpoint** through later work. The 43° off-axis control feel has not been human-tested and is **not** approved as the shipping control scheme. Shots 3–4 (threshold and first exterior) remain unresolved; material, façade, lighting, destination, and full-route acceptance remain open. Do not label S2 complete or start S3 from this direction-only acceptance.

## S2B continuation decision

The bounded 26° D1 camera study reached the same measured Shot 5 position but lost the Spire, so it is rejected as a substitute for the kept D composition. Its runtime flag was removed after capture; D remains a direction-only opt-in reference, not a production camera acceptance. The first-exterior blank mass is the retained Garage left wall seen by the follow camera before it clears the Garage, not missing Founder District geometry. Shot 3 and Shot 4 remain **REVISE**.

Normal-speed route evidence reached the main east corner and the cross-sidewalk at approximately `(-840, 959)`, but not the old peer zone at `(-840, 940)`. The latter has only visual-only terrain in the traversal manifest. The owner chose to move peer staging onto the existing main walkway near `(-825, 940)`; Mara's position is now `(−825, 8.375, 940)`. A fresh iPhone production-route UI test reached `(-823.8, 8.38, 939.5)` at unchanged 1.4 m/s without a blocked step, and its endpoint screenshot shows the paved walkway. This resolves the location/reachability gate; the production encounter itself remains disabled for S2. Composition/material acceptance gates remain open, so S2 is not complete and S3 is not ready.
