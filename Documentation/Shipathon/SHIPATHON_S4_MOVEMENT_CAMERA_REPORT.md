# Shipathon S4 — Movement & Camera Feel

Status: **C2 accepted by the owner on 2026-09-26 and promoted to the production camera path**. The recovery review below supersedes the earlier C walking-pan recommendation. The [visual lock](SHIPATHON_VISUAL_LOCK.md#s4-camera-accepted--c2-stopped-shot-5-reveal) records the new ratchet.

## September 26 recovery and revised C2 review

The original S3 worktree disappeared during the interruption. The accepted source changes were reconstructed in `/private/tmp/solo-shipathon-recovery-s3` from local session patch history, on branch `codex/shipathon-recovery-s4` based on `45301e3`. The main checkout and its unrelated dirt were left alone. The Founder District USDZ and runtime manifest match the accepted S3 SHA-256 values below exactly. The regenerated Phase 9 `.blend` is not byte-identical to the accepted source hash because Blender saves are nondeterministic; its exported runtime package is exact. Old capture links later in this report refer to files lost with the previous worktree and are retained only as historical account.

The C2 revision retains the 0.75 rad Spire composition **only after a brief stop at Shot 5**. Eastbound walking, the Garage threshold, and Shot 4 use centered yaw. Restart, steering, reverse, and Reduce Motion return the camera to zero yaw. It is now the production default; `--shipathon-s4-camera-a` retains the previous centered follow for comparison, while B and D remain opt-in studies. The earlier C walking-pan description and REVISE recommendation below are historical, not the current C2 implementation.

| Revised C2 evidence | iPhone 17 Pro Max, iOS 26.5 | iPad Air 11-inch (M4), iOS 26.5 |
| --- | --- | --- |
| Shot 4 | [frame](Captures/RecoveryS4-C2-iPhone/1E9C6115-CF66-4F97-8404-9D9FFCB15B49.png) | [frame](Captures/RecoveryS4-C2-iPad/639CDDAE-180C-4FAA-9FD0-2E21125B8382.png) |
| Shot 5 walk, centered | [frame](Captures/RecoveryS4-C2-iPhone/8F635420-3D94-4DA0-AF74-AC913C18D4B1.png) | [frame](Captures/RecoveryS4-C2-iPad/515040FE-862D-489F-AC8B-481502AD2729.png) |
| Stopped Spire composition | [frame](Captures/RecoveryS4-C2-iPhone/1BACDD2B-C4A9-4EB1-95A8-B3F47D426CB3.png) | [frame](Captures/RecoveryS4-C2-iPad/F00390E7-4931-4321-8711-CF11EBAE3260.png) |
| Reverse recovery | [frame](Captures/RecoveryS4-C2-iPhone/C2243771-5A38-4747-B527-B5A79602D2E4.png) | [frame](Captures/RecoveryS4-C2-iPad/15747222-5BED-413B-9BCD-3E31EB19EA18.png) |

[iPhone simulator motion review](Captures/S4/S4-C2-recovered-motion-review.mp4) · [iPhone attachment manifest](Captures/RecoveryS4-C2-iPhone/manifest.json) · [iPad attachment manifest](Captures/RecoveryS4-C2-iPad/manifest.json)

The iPhone diagnostics show yaw 0.03 rad at the end of the Shot 5 walk, 0.75 rad at the stopped composition, and 0 after restart, heading correction, and reverse. At the walking key frame the callback sample had 1,269 updates, mean 16.68 ms, p95 16.78 ms, longest 33.43 ms, and no update over 50 ms. This is `SceneEvents.Update` cadence, not GPU FPS. The two C2 UI key-frame tests passed on the named simulators (iPhone 62.009 s; iPad 63.700 s). Focused camera policy unit tests and the recovered S3 iPhone full route and iPad key-frame tests also passed. The iPhone route reached the peer target. A first iPhone route launch was blocked by a busy simulator UI runner; reboot and rerun passed. Full Xcode scheme builds occurred during these test actions. Human review of motion comfort, gait, and device feel remains necessary.

**Owner decision: ACCEPT C2.** The stopped Shot 5 pan has been selected for the production path. Human Founder-gait review and physical-device control/performance sanity remain open. S5 stays closed until separately requested.

### Accepted production-path verification

The no-flag C2 key-frame test passed on iPhone 17 Pro Max (63.029 s) and iPad Air 11-inch (M4) (65.580 s), both iOS 26.5. The full no-flag iPhone Garage-to-peer route passed (151.186 s), reaching `(-823.7, 8.38, 939.6)` at the unchanged 1.4 m/s without a blocked step. Its 6,651 `SceneEvents.Update` samples had mean 17.56 ms, p95 33.27 ms, longest 33.48 ms, and zero intervals over 50 ms; route memory rose from 201.5 to 247.1 MB. These are simulator callbacks and memory observations, not GPU frame-time or device FPS. The Xcode test actions built the app and UI test scheme.

| Production frame | iPhone 17 Pro Max | iPad Air 11-inch (M4) |
| --- | --- | --- |
| Shot 5 forward control | [centered walk](Captures/S4-Production-iPhone/EDBFB459-CFA1-46CD-87E7-1B10B5530F41.png) | [centered walk](Captures/S4-Production-iPad/80E49B9C-4767-4FC9-AAAE-A1A351469A7B.png) |
| Stopped Spire reveal | [0.75 rad composition](Captures/S4-Production-iPhone/9DE6490D-0971-452E-8D39-271421E3F726.png) | [0.75 rad composition](Captures/S4-Production-iPad/920093FB-4095-469C-8B80-8444999E8698.png) |
| Reverse recovery | [centered frame](Captures/S4-Production-iPhone/D61F00F2-ABF6-46D0-9B89-2EBFEAB332BF.png) | [centered frame](Captures/S4-Production-iPad/E538E1EC-BAC1-4CAA-B479-295BBAAAFF20.png) |
| Full route | [peer endpoint](Captures/S4-Production-Route-iPhone/E0F918F9-2A59-4C17-838B-F9F1ABB52592.png) | Key-frame verification only |

[iPhone key-frame manifest](Captures/S4-Production-iPhone/manifest.json) · [iPad key-frame manifest](Captures/S4-Production-iPad/manifest.json) · [full-route manifest](Captures/S4-Production-Route-iPhone/manifest.json). The iPad stopped screenshot shows a small transient loading indicator; camera yaw and landmark framing pass the captured assertions. Physical-device control and streaming presentation remain final human checks.

## Historical S4 study (before C2 revision)

## S3 checkpoint

- S4 branch: `codex/shipathon-atlantis-camera-s4`; starting HEAD `45301e34e9af4d04fa6c1db6c618007ccad46789`. S3's accepted worktree was dirty by design. Pre-S4 tracked checkpoint: `/private/tmp/solo-shipathon-s3-checkpoint.patch`; copies of the S3 report and visual lock are in `/private/tmp/`.
- S3 owner lock: [visual lock](SHIPATHON_VISUAL_LOCK.md); [S3 report](SHIPATHON_S3_LIGHTING_ATMOSPHERE_REPORT.md). Production is A2 daylight with Atlantis directional shadows off, Atmosphere A, and the scoped Shot 4 Garage exterior ground handoff. S2 threshold B, Shot 4 camera A, Material B, Founder rig, route, and peer staging remain locked.
- Save version: `GameStore.saveVersion = 20`. Founder District package SHA-256: `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10`; manifest SHA-256: `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`; pre-S4 visual-lock SHA-256: `a8898f3645cc4b9dfb18a089f75e69108c06a5627475dcd54acdfc1530609601`.
- The separate `visual-fidelity-track` checkout has unrelated Core Experience dirt and was not edited. Existing S2/S3 captures remain in place.

## Camera ownership and first break

The production movement pad in `FounderGarageRealityView` sends normalized forward/turn intent to `AtlantisRealityWorld.setMovementIntent`. In `AtlantisRealityWorld.update`, `turn` mutates canonical player `heading`, and `move` advances `playerRoot` through the existing terrain/collision guards at the unchanged 1.4 m/s. `bodyHeadingRoot` follows that heading. `cameraRig` and `PerspectiveCamera` are descendants of that root; `applyThirdPersonCamera` owns the accepted `(0.72, 1.72, 2.35)` follow offset and 70° FOV. `FounderAtlantisVisualHeading` adapts the canonical heading and displacement for the transferred Founder rig. `FounderGarageRealityView` owns the threshold visibility/camera handoff and scopes Garage exterior ground and S3 sky at that handoff.

The opt-in D study adds up to 0.75 rad to `cameraRig.orientation` from street X progress alone. It does not recenter on stop, steering, reversal, or leaving the east heading. Thus the first likely control break is persistent off-axis forward movement, not route/collision. S4 tests D in motion without changing its authored value.

## Controlled camera candidates

| Candidate | Status | Yaw | Activation | Recovery |
| --- | --- | --- | --- | --- |
| A — production centered | production baseline | 0 | always | none needed |
| D — kept composition reference | opt-in only | up to 0.75 rad / 43° | current X-progress ramp | none; diagnostic reference |
| B — bounded cinematic bias | opt-in S4 study | up to 0.52 rad / 30° | eastward forward movement in the Founder Street corridor, using the same X-progress ramp | smooth return on steering, reverse, heading change, leaving corridor, or after 0.6 s stopped; disabled by Reduce Motion |
| C — contextual hero bias | opt-in S4 study | up to 0.75 rad / 43° | the same eastbound corridor only | B's recovery rules, retaining D's kept Shot 5 composition; disabled by Reduce Motion |

B/C change only the existing `cameraRig` orientation. They do not change camera offset/FOV, player movement, collision, route, Founder asset, lighting, atmosphere, or save data. B enters at up to 0.65 rad/s; C at up to 0.9 rad/s; both return at up to 1.8 rad/s. The camera remains centered through the Garage and Shot 4. C was justified by B's matched Shot 5 frame, which pushed the Spire to the far left edge.

## Evidence and acceptance

All iPhone frames below use the same iOS 26.5 iPhone 17 Pro Max, S3 production visuals, Garage exit, threshold, Shot 4 at `(-874.8, 8.03, 1037.9)`, east turn, and Shot 5 at approximately `(-853.0, 8.03, 1040.7)`. The [A/D reference manifest](Captures/S4/CameraABD-iPhone/manifest.json) and [B/C final manifest](Captures/S4/CameraBC-iPhone/manifest.json) include sequential threshold, walk, stop, restart, heading correction, reverse, and spatial diagnostics. The initial A/D/B action recorded all frames but failed one B stopped-yaw assertion because the accessibility value had stopped updating when movement ended; the camera visibly recentered. The diagnostic observation was corrected, and the B/C iPhone action passed. No camera movement or visual judgment is inferred from that failed assertion alone.

Short simulator movement clips for human review: [B: east walk through reverse](Captures/S4/S4-B-motion.mp4) and [C: east walk through reverse](Captures/S4/S4-C-motion.mp4). C was recorded during a separate passing iPhone 17 Pro Max iOS 26.5 UI run on the final S4 code. The clips are simulator recordings; their existence does not establish comfort or gait naturalness.

| iPhone Shot 5 at matched route position | Walking | After stop | Finding |
| --- | --- | --- | --- |
| A — centered production | [frame](Captures/S4/CameraABD-iPhone/D6E28C91-CDA9-4B9D-A052-3F53EAD4757B.png) | [frame](Captures/S4/CameraABD-iPhone/67A00D81-B621-45C1-85C4-69EEEF2E367F.png) | yaw 0; aligned forward; Spire absent |
| D — original study | [frame](Captures/S4/CameraABD-iPhone/C45FEF50-BB51-4E7A-9C55-9218D1B1124C.png) | [frame](Captures/S4/CameraABD-iPhone/21A5730A-BD6E-45E4-8D6E-473517416AF3.png) | yaw 0.75 persists after stop and reverse; Spire centered |
| B — bounded | [frame](Captures/S4/CameraBC-iPhone/B11E5059-3F29-41BC-9128-0F5493135B15.png) | [frame](Captures/S4/CameraBC-iPhone/07AEB89F-2D1F-4C48-9CA6-546B3519E19B.png) | yaw 0.52 in walk, 0 after stop; Spire at far left edge |
| C — contextual | [frame](Captures/S4/CameraBC-iPhone/FF9D8FA2-B2B7-4721-A29C-C61DBA539BB6.png) | [frame](Captures/S4/CameraBC-iPhone/263F5BFB-B07E-4C2D-AAAB-DBCFB21D9DC8.png) | yaw 0.75 in walk, 0 after stop; D skyline retained |

The D diagnostic remains at 0.75 rad during reverse. B/C return to zero after stopping and after a small heading correction; after 0.7 s of reverse they are still partway back (B 0.24, C 0.34 rad), which is smooth but may feel slow. The current camera never changes canonical player heading. C's 43° walking offset still makes forward travel visibly diagonal; human comfort review is essential. The [iPad Air 11-inch (M4), iOS 26.5 C manifest](Captures/S4/CameraC-iPad/manifest.json) passed: [clean Shot 4](Captures/S4/CameraC-iPad/DD4B2118-F85B-449C-98D5-137828826491.png), [Spire Shot 5](Captures/S4/CameraC-iPad/746BDADB-9966-4974-8814-258048FBF46E.png), and zero yaw after stop and reverse recovery.

**Recommendation for the owner gate: REVISE.** C preserves the kept D skyline and restores alignment on stop/steering/reverse, but forward walking remains visibly diagonal at 43°. That misses the pass's control-alignment standard until the owner has judged it in motion. A is the production-safe choice if control comfort wins outright; B's 30° offset offers less landmark value while still offsetting forward control. No gait edit was made. Founder standing, walk start, sustained gait, stop, turn, side-rest arms, foot cadence/planting, and idle return require human viewing; stills and automated assertions cannot approve naturalness. The accepted 1.40 m gait cycle, eight poses, 1.4 m/s speed, arm overlay, and Founder USDZ are unchanged.

## Verification and limits

The current-revision focused S4 camera target-policy unit test passed on iOS 26.5. The B/C iPhone motion test passed; C passed again on iPhone during video recording; C iPad key frames and reverse recovery passed. The initial A/D/B iPhone action failed the one stale accessibility assertion described above, but all route captures completed. The iPhone and iPad actions built the `Solo Unicorn Run` scheme. These are opt-in candidate results; the default S3 camera was not replaced. `git diff --check` passed.

| iPhone east-street leg to Shot 5 | Samples | Founder District load | Mean update | p95 update | Longest | >50 ms | Route memory start→Shot 5 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1,270 | 1.651 s | 16.67 ms | 16.79 ms | 17.14 ms | 0 | 200.3→200.4 MB |
| B | 1,269 | 1.648 s | 16.68 ms | 16.77 ms | 33.30 ms | 0 | 201.9→202.8 MB |
| C | 1,270 | 1.729 s | 16.67 ms | 16.75 ms | 17.10 ms | 0 | 200.7→201.7 MB |

All three used the same movement holds and reached nearly the same Shot 5 coordinate without a blocked step. This short-leg sample shows no persistent callback hitch. The start-memory difference and simulator variability limit comparisons. `SceneEvents.Update` is callback cadence, **not GPU FPS**; a final owner-selected candidate still needs the full matched peer route and physical-device control check. Reduce Motion is honored by B/C's target function, and a live settings change zeros their camera yaw; initial and toggled Reduce Motion still need simulator/device observation. No wall or roof clipping is visible in these captured key frames, but live motion review remains open.

**S4 files changed:** `App/AtlantisRealityScene.swift`, `App/FounderGarageRealityView.swift`, `Tests/AtlantisRuntimeTests.swift`, `UITests/Build32_6_1ProductionContinuityUITests.swift`, this report, and new files under `Captures/S4/`. Other dirty paths are inherited S2/S3 work and were preserved. The S3 visual lock is unchanged. No `GameStore`, save schema, project file, scheme, materials, lighting, atmosphere, route, or asset was changed for S4.

**S4 remains open:** owner camera-feel selection, human Founder-gait review, Reduce Motion live review, full peer-route measurement for the selected camera, and physical-device sanity where practical. Do not begin S5 automatically.
