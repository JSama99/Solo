# Founder Character Pass A.1 — Repair

Final classification (2026-09-17): **NO-GO for production promotion**. The four blockers received direct repair or measurement, but the physical iPad production traversal fails, seated eye/camera co-location remains incomplete, and facial quality has not received human acceptance. Production Founder remains unchanged; Pass B has not begun. Save version remains 20. No commit, stage, push, merge, reset, clean, or rebase was performed.

## Pre-edit diagnosis (2026-09-17)

Read-only Blender/USD inspection: `Source/inspect_repair.py`, results `Evidence/A1/root_cause.json`. This diagnosis was recorded before editing the Blender source.

| Blocker | Confirmed origin | Repair plan |
| --- | --- | --- |
| Jaw seam | Source mesh partition cuts across jaw at 1.5568–1.5721 m. 84 coincident boundary vertices are independently smoothed; normal disagreement reaches 30.8802°. Both pieces use identical skin material, no UVs, no normal maps, no custom normals, and only an armature modifier. Thus texture/material/subdivision differences are excluded. | Weld the existing source surface, preserve skin weights, move the head partition below the visible neck into the shirt, and preserve common-surface normals at the new junction. Verify head movement and independent masking. |
| Face | Source uses flat constant skin, no lip/eyebrow color, solid-color iris without pupils, sparse cap hair. Facial masks are centered at hardcoded heights inconsistent with actual eye pivots (1.66819 m versus blink center 1.683 m). | Refine existing forms and eye/lid placement; add restrained portable surface color and eyebrows/pupils; refit facial masks to actual geometry. Keep semantic eyes and nine target names. |
| Seated alignment | Fixture uses identical local-X rotations despite mirrored, non-axis-aligned limb bases, fixed root offset, and π facing. Canonical chair faces −Z while canonical camera aims diagonally toward the monitor. Pose was not fitted to actual chair/desk geometry. | Author a target-based Blender validation pose using each bone's rest basis, floor/seat targets, and arm reach. Export local transforms as debug validation data and measure actual skinned contact landmarks. Preserve canonical camera. |
| Device cost | Prior samples measured asset import during first renderer initialization; no warmed production Garage baseline, peak sampling, stable frame series, or presented-frame evidence. Runtime has ten identical skeleton copies, seven materials, nine morph targets, and hidden body geometry. | Profile the existing Garage world before/after candidate insertion in one session; cache references, strip truly covered geometry, retain required bones, and report measured incremental cost and measurement limits. Do not label an unmeasured root cause as proven. |

Actual Garage v8 bounds: chair overall x=0.0225…0.6575, y=0.004…1.065, z=−0.5458…0.1437 m; backrest x=0.11…0.57, y=0.565…1.065, z=−0.0276…0.1437. Desk top y=0.7575, desk footprint x=−0.05…1.95, z=−1.475…−0.625. Monitor display x=1.0575…1.7825, y=1.101…1.499, z≈−1.079. Canonical seated root is (0.34,0,−0.22); camera eye is (0.34,1.18,−0.22), targeting (1.42,1.30,−1.08). Neither anchor nor camera will be changed.

## Implemented repair

The repair script loads the retained Pass A Blender file, not a replacement character. It welds the 84 former partition duplicates, makes restrained nose/cheek refinements, and moves the head/body split below the visible neck under the shirt. Common-surface custom normals are retained. The source audit finds **zero open jaw boundary edges and zero jaw corner-normal disagreement**. The separate head remains necessary for first-person masking; the new body partition ends at 1.47001 m.

Existing skin weights are retained on the repaired surface; there was no broad repaint or replacement rig. New eyebrows follow the head and facial targets; pupils remain attached to the independently addressable eye modules. Hidden body faces under the current outfit are removed. Future outfits exposing those regions must restore them from the retained full surface. The canonical 55 bone names, hierarchy, and rest matrices are unchanged within 1e-6. No control/IK bones were added to the export.

The face now has pupils, projected eyebrow geometry, smoother hair silhouette, adjusted forms, and a single 1024² skin color map with restrained variation. Skin roughness is 0.68; no costly subsurface shader or normal map is shipped. Left eyebrow winding was corrected after RealityKit exposed backface culling not evident in Blender. Neutral facial weights are explicitly zero. Blink uses actual eye landmarks. JawOpen uses the pinned upstream sculpted target mapped onto the same candidate surface: all 13,464 original vertex samples matched exactly before mapping. No teeth, tongue, gaze controller, or lip-sync system was added.

The nine shipped targets remain `Blink_L`, `Blink_R`, `JawOpen`, `Smile`, `Frown`, `BrowRaise`, `BrowLower`, `MouthNarrow`, and `MouthWide`. Blender blink/jaw-open renders exercise those deformations; runtime tests verify their import, not a complete facial animation performance.

The authored seated pose respects each bone's rest basis, replacing the fixture's arbitrary shared local-X angles. A small bundled validation JSON carries local transforms and measurements. The debug fixture loads the actual Garage v8 world through its existing adapter, preserves the canonical POV, and caches model, rest-pose, head-mask, and joint references instead of recursively finding them every frame. The export omits the unused Blender environment light/map. Ten identical canonical skeleton copies remain in the established module packaging, enabling independently addressable RealityKit models; their isolated cost was not measured.

## Asset budget and technical contract

| Measure | Repaired candidate |
| --- | ---: |
| Triangles | 29,488 (was 37,148; 20.6% reduction) |
| Body / head triangles | 9,232 / 9,000 |
| Top / bottom / shoes triangles | 3,420 / 2,624 / 1,200 |
| Hair / both eyes / both irises+pupils | 1,072 / 1,440 / 1,500 |
| Rendered models / unique materials | 10 / 7 |
| Unique canonical joints / packaged copies | 55 / 10 |
| Facial targets | 9 |
| Evaluated standing height | 1.79207 m |
| Runtime USDZ | 2,657,448 bytes |
| Texture | One RGB PNG, 1024², 881,298 bytes |
| Estimated decoded texture | 4 MiB RGBA base; about 5.33 MiB with full mip chain |

Texture figures are storage estimates, not measured GPU allocation. There are no duplicate skin maps or unused environment textures in the runtime package. GPU draw calls were not instrumented; ten models/seven materials must not be reported as an exact draw-call count.

Final runtime SHA-256: `dc4b61bbea22a8a4470cc88deaefeb5ae7458c82cbee8c9644ba76b5b1a90a36`. The packaged resource matches the audited runtime USDZ. [USD audit](Intermediate/usd_audit.json), [runtime audit](Intermediate/runtime_audit.json), and [source repair audit](Evidence/A1/source_repair_audit.json) pass their technical invariants. Appearance acceptance is separate.

## Seated fit and remaining spatial limitation

The root uses the existing seat (0.34, 0, −0.22), a vertical offset of −0.408907443 m, and π rotation about runtime Y. The following heights include that offset; source coordinates use Z-up.

| Landmark | Measured height |
| --- | ---: |
| Pelvis joint | 0.532239 m |
| Both knees | 0.516479 m |
| Both ankle joints | 0.072142 m |
| Evaluated shoe soles | 0.000000238 m |
| Both hand joints | 0.774624 m |
| Desk surface | 0.757500 m |
| Both eye joints | 1.259279 m |
| Canonical POV | 1.180000 m |

The legs are now symmetric and soles meet the floor. The source head turns toward the actual monitor. Runtime seated captures show the body on the chair and knees below the desk; this is not a numerical mesh penetration/contact proof. Fine cushion/backrest fit and natural hand reach remain human acceptance items. A separate torso-rotation stress capture was not completed; seated, standing, head-turn/tilt, blink, and jaw-open coverage must not be represented as exhaustive deformation validation.

**The eyes remain 79.28 mm above the canonical POV**, with about 125 mm horizontal eye-center offset after the authored head turn. Consequently strict avatar/camera co-location has not passed. The camera was deliberately preserved. First-person masking removes all six head modules while retaining the body; captures show a clear, monitor-dominant view without head/shoulder obstruction. Tests verify camera coordinates and mask state, not human acceptance of the seated body.

## Before/after visual evidence

| Inspection | Before | After |
| --- | --- | --- |
| Face/jaw | [Pass A close-up](Evidence/A1/Before/iPhone17ProMax_CloseUp.png) | [Physical iPhone face](Evidence/A1/Physical_iPhone16Pro_Face.png) |
| Seated | [Pass A iPad](Evidence/A1/Before/iPadAirM4_Seated.png) | [Physical iPad seated](Evidence/A1/Physical_iPadAirM4_Seated.png) |
| Standing | [Pass A standing](Evidence/A1/Before/iPhone17ProMax_Standing.png) | [Physical iPhone standing](Evidence/A1/Physical_iPhone16Pro_Standing.png) |
| Head turn | [Source baseline](Evidence/A1/Before/E_HeadTurn.png) | [Left](Evidence/A1/iPadAirM4_HeadLeft.png), [right](Evidence/A1/iPhone17ProMax_HeadRight.png) |
| Head tilt | — | [Down](Evidence/A1/iPhone17ProMax_HeadDown.png), [up](Evidence/A1/iPadAirM4_HeadUp.png) |
| First person | — | [Physical iPad POV](Evidence/A1/Physical_iPadAirM4_POV.png), [head mask](Evidence/A1/iPhone17ProMax_HeadHidden.png) |

Both requested simulators have nine runtime captures; each physical device has seated, standing, face, and POV captures. Blender validation retains the prior key/fill/rim lighting where practical. Runtime now uses the real Garage, so old fixture and new Garage images are not controlled lighting comparisons.

Agent visual inspection finds the old jaw seam absent in neutral/turned/tilted views, with a continuous jaw/neck transition and corrected eyebrow visibility. The face remains a simple stylized candidate: cap-like hair, residual reddish tint below the nose, and small dark specks visible in runtime captures deserve further review. Similar specks appear in the Garage-only view; their cause is not established. These observations do not constitute direct human approval or premium character-quality acceptance.

## Garage baseline vs Garage + Founder candidate

Each launch warms the actual Garage scene for 90 updates, captures baseline, samples 180 updates, imports the candidate asynchronously, captures it, warms 60 updates, then samples another 180 updates with cached pose assignment. Baseline and candidate use the same selected camera in one process. Unique run IDs prevent stale JSON from being accepted. Final seated measurements follow; per-view JSON files are retained alongside captures.

| Destination | Import ms | Baseline MiB | With Founder MiB | Increment MiB | Lifetime peak baseline → with MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Physical iPhone 16 Pro | 1,885.7 | 291.17 | 331.99 | 40.81 | 380.47 → 414.80 |
| Physical iPad Air M4 | 1,800.0 | 339.84 | 381.63 | 41.78 | 450.03 → 499.30 |
| iPhone 17 Pro Max simulator | 107.7 | 83.92 | 92.49 | 8.56 | 158.58 → 165.16 |
| iPad Air M4 simulator | 148.3 | 88.39 | 96.49 | 8.09 | 177.06 → 183.42 |

| Destination | Update interval p95 baseline → with ms | Mean cached pose assignment ms | Updates during import / max interval ms | First post-import update / completed capture ms from import start |
| --- | ---: | ---: | ---: | ---: |
| Physical iPhone | 16.96 → 16.92 | 0.101 | 113 / 48.25 | 1,934.5 / 2,030.7 |
| Physical iPad | 17.12 → 17.07 | 0.072 | 109 / 27.01 | 1,821.0 / 1,921.1 |
| iPhone simulator | 17.06 → 16.71 | 0.060 | 6 / 33.31 | 136.1 / 230.8 |
| iPad simulator | 17.25 → 16.70 | 0.053 | 9 / 32.71 | 185.7 / 289.4 |

Measurements are from the debug ARView validation fixture containing the existing Garage world, not the complete production RealityView/UI/gameplay workload. Memory endpoints approximate incremental process footprint; lifetime peak includes renderer initialization and cannot isolate candidate peak allocation. Scene update intervals are not GPU frame timings. Snapshot completion is an upper bound on captured appearance, not measured first display presentation. Pose assignment timing excludes GPU skinning, blending, and a future animation controller. These are single seated samples, not statistical performance certification.

Hardware updates continue during the roughly two-second import; no two-second scene-update stall was observed. Geometry was reduced and texture/material use is bounded, but this experiment cannot attribute the remaining ~41 MiB separately to skeleton duplication, geometry, morph buffers, textures, or engine caches. Performance is now measurable; cold-load latency remains material and product acceptance is pending.

## Verification results

| Check | Result |
| --- | --- |
| Focused Founder contract tests | 5 passed; includes authored seated transforms/floor and unchanged POV/mask |
| Complete unit suite, iPhone 17 Pro Max simulator | **909 passed, 0 failed, 0 skipped** |
| Debug simulator and signed physical-device builds | Passed |
| Final Release simulator build | Passed |
| Both requested simulators | Installed/launched and all nine candidate views captured |
| Physical iPhone 16 Pro | Installed/launched; candidate views captured; production UI **2 passed** |
| Physical iPad Air M4 | Installed/launched; candidate views captured; production UI **1 passed, 1 failed** |
| Unchanged iPad traversal-only retry | **1 failed** |
| Source / USD / packaged runtime audits | Passed |
| Repository `git diff --check` | Failed on seven pre-existing whitespace lines in FounderDeskWorkspaceTests.swift |

The full suite includes existing Garage, locomotion, Camera Physics, spatial continuity, Atlantis, and simulation tests. [Current unit summary](Evidence/A1/unit_summary.json) records 909 tests. Unit tests do not establish visual/audio/haptic correctness. No test was weakened.

Production UI tests are `Build32_6_2ProductionContinuityUITests.testRealityKitCameraPhysicsExploreAndExactDeskReturn` and `.testProductionGarageWalksThroughOpenDoorIntoAtlantis`. Both pass on iPhone. On iPad the Explore/exact desk-return test passes, but traversal fails at assertions 781–782: “Open-door traversal never entered Atlantis” and missing Atlantis movement pad. One unchanged traversal retry fails again. Candidate loading is disabled on this normal production route, so this is a separately observed production failure, not evidence that the new mesh causes it. The failure image shows walking mode remaining inside the Garage; gesture/orientation/camera-heading causes have not been conclusively diagnosed.

Evidence: [iPhone log](Evidence/A1/iPhone_UI.log), [iPhone summary](Evidence/A1/iPhone_UI_summary.json), [iPad initial summary](Evidence/A1/iPad_UI_summary.json), [iPad retry summary](Evidence/A1/iPad_UI_retry_summary.json), [failure image](Evidence/A1/Physical_iPadAirM4_TraversalFailure.png), [failure UI hierarchy](Evidence/A1/Physical_iPadAirM4_TraversalFailure_UI.txt). The iPhone summary is explicitly log-derived because Xcode rotated its original result bundle. An initial UI command used an incorrect test-target/class spelling and failed before executing tests; the command was corrected without scheme changes.

Current unit result: `/tmp/solo-founder-character/Logs/Test/Test-Solo Unicorn Run-2026.09.17_17-00-57--0400.xcresult`. Final Release log: `/tmp/founder-a1-release-final.log`; signed Debug log: `/tmp/founder-a1-device-build.log`. Build result excerpts are preserved in the evidence verification record. Repository whitespace failures are existing lines 1184, 1194, 1198, 1202, 1383, 1388, 1391 of `Tests/FounderDeskWorkspaceTests.swift`; unrelated work was preserved.

## Reproduction and changed-file inventory

Run Blender 5.2.1 in background with `--python Documentation/FounderCharacter/Source/repair_founder.py -- --render`, then the source audit, USD audit, runtime packager, and runtime audit scripts in that directory. Copy the regenerated runtime USDZ and validation JSON from `Intermediate/` to `App/RealityKit/FounderCharacter/` before rebuilding. `map_facial_target.py` regenerates the checked-in delta mapping using pinned MPFB commit `437dd513888a92399d1d3200d2e80859fae55abc`; normal repair uses the retained mapping. GPL tool and CC0 asset provenance from Pass A remains retained.

App/test/project changes in A.1:

- `App/FounderCharacterContract.swift`: authored-pose decoding, cached validation state, real Garage fixture, POV/head inspection, controlled profiling.
- `App/RealityKit/FounderCharacter/founder_candidate_a.usdz`: regenerated candidate.
- `App/RealityKit/FounderCharacter/founder_validation_pose.json`: new authored validation pose.
- `Tests/FounderCharacterContractTests.swift`: two added contract tests (five total).
- `SoloUnicornRun.xcodeproj/project.pbxproj`: precise resource reference/build membership for the new validation JSON; required so hardware receives the authored pose. No A.1 shared-scheme modification.

Documentation changes: this report; new `Source/inspect_repair.py`, `repair_founder.py`, `map_facial_target.py`, `audit_repair.py`, `capture_runtime.py`, `facial_target_a1.json`, `FounderSkin_A1_1K.png`; updated `Source/audit_founder.py`, `audit_runtime.py`, `founder_candidate_a.blend` and Blender backup; regenerated `Intermediate/` assets, contracts, audits, and texture; `Evidence/A1/` retained baseline, source measurements, Blender/runtime screenshots, per-capture metrics, unit/UI results, and verification record. The [artifact manifest](Evidence/A1/artifact_manifest.json) enumerates individual retained files with byte sizes and SHA-256 hashes, including earlier Pass A artifacts for provenance. Generic `*_metrics.json` without a case name are intermediate observations; the final tables use `*_Seated_metrics.json`.

Earlier dirty changes in App.swift, Garage/Atlantis implementation, WorkSessionEngine, tests, UI tests, and shared scheme were preserved. GameStore has no diff; no save migration was introduced. The production launch route and locomotion/camera ownership were not changed by this repair.

## Promotion decision

**NO-GO.** The jaw repair and technical asset contract pass available checks. Facial quality still needs direct human acceptance and refinement; seated eye/camera agreement is incomplete; hardware import is measurable but not yet accepted; production iPad Garage-to-Atlantis traversal fails twice. Do not promote this candidate or begin Pass B. The next bounded work should diagnose the reproducible iPad traversal failure, resolve the avatar/POV fit without shifting the canonical Garage, and obtain direct face/seated visual acceptance before considering promotion.
