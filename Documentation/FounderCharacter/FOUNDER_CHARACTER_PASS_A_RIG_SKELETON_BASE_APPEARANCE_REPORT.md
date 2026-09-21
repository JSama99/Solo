# Founder Character Production Pass A — Rig, Skeleton & Base Appearance

Date: 2026-09-17. Branch: `visual-fidelity-track`. **Classification: NO-GO for production.**

The technical candidate imports into RealityKit with a complete 55-joint humanoid contract, finger chains, separate eyes, nine facial targets, and independently visible skinned modules. The current candidate does **not** meet the requested production appearance, seated deformation, or performance acceptance conditions. Pass A is incomplete; do not advance to Pass B or promote this asset into the production Founder.

## Delivered foundation and preserved ownership

Blender owns mesh, rig, skin weights, materials, and deformation test poses. A bounded Debug launch route, `--founder-character-qa`, loads the candidate. Normal production startup still uses the existing Founder. This pass does not integrate the candidate into Garage/Atlantis gameplay, replace procedural locomotion, or alter Camera Physics, GameStore, or save migrations. Save version remains 20.

`FounderAnimationClipCatalog` covers the existing nine states: `seatedIdle`, `seatedTurn`, `standingUp`, `standingIdle`, `walkStart`, `walking`, `walkStop`, `turnInPlace`, and `sittingDown`. All clip lookups return nil. The seven Blender pose actions are validation fixtures, not gameplay animation. Root motion is explicitly not spatial authority.

## Sources, provenance, and reproducibility

Free local tools used: Blender 5.2.1 LTS (build `9e2066aef7ef`), bundled OpenUSD, MPFB anatomy/rig data, Xcode, XCTest, and RealityKit. No paid generation service was used.

Upstream: [MakeHuman Community MPFB2](https://github.com/makehumancommunity/mpfb2), pinned commit `437dd513888a92399d1d3200d2e80859fae55abc`. Local authoring checkout: `/tmp/solo-founder-mpfb`. Software and asset license copies are retained in `Source/MPFB_LICENSE.md` and `Source/MPFB_LICENSE_ASSETS.md`; the upstream software uses GPLv3 and the bundled asset data uses CC0. The checkout is external to this repository and must be restored at the pinned revision on another machine.

| Artifact | Location relative to this report |
| --- | --- |
| Editable authoring scene | `Source/founder_candidate_a.blend` |
| Blender save backup | `Source/founder_candidate_a.blend1` |
| Authoring script | `Source/build_founder.py` |
| Source contract | `Intermediate/blender_contract.json` |
| Raw Blender USD export | `Intermediate/founder_candidate_a.usdc` |
| Raw export package, not the bundled runtime candidate | `Intermediate/founder_candidate_a.usdz` |
| Modular runtime export | `Intermediate/founder_runtime_a.usdc` and `.usdz` |
| App resource | `../../App/RealityKit/FounderCharacter/founder_candidate_a.usdz` |
| Raw export audit | `Source/audit_founder.py`, `Intermediate/usd_audit.json` |
| Runtime packaging | `Source/package_runtime.py` |
| Final package audit | `Source/audit_runtime.py`, `Intermediate/runtime_audit.json` |

Run from the repository root with the pinned MPFB checkout available:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python Documentation/FounderCharacter/Source/build_founder.py -- --mpfb /tmp/solo-founder-mpfb --render
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python Documentation/FounderCharacter/Source/audit_founder.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python Documentation/FounderCharacter/Source/package_runtime.py
cp Documentation/FounderCharacter/Intermediate/founder_runtime_a.usdz App/RealityKit/FounderCharacter/founder_candidate_a.usdz
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python Documentation/FounderCharacter/Source/audit_runtime.py
```

Regeneration intentionally overwrites candidate outputs. The scripts make the procedure repeatable; byte-for-byte determinism across Blender/USD versions is not claimed. The sandboxed Blender launch crashed with exit 139 during the final audit; execution outside the sandbox is required in this environment.

## Skeleton, coordinates, and bind pose

The authoring scene uses an A-pose with relaxed bent elbows. Body height is 1.790 m; the exported mesh union including hair is 1.795996 m. Exact mesh bounds are audited separately from the conservative skeletal bounds (1.923901 m), which RealityKit may use for `visualBounds`.

One Blender armature defines the canonical skeleton. All 55 joints have semantic names:

```text
Root
└── Hips
    ├── Spine01 → Spine02 → Chest
    │   ├── Neck → Head → Eye_L / Eye_R
    │   └── Clavicle_L/R → UpperArm_L/R → LowerArm_L/R → Hand_L/R
    │       └── Thumb / Index / Middle / Ring / Pinky: 01 → 02 → 03 (each side)
    └── Thigh_L/R → Calf_L/R → Foot_L/R → Toe_L/R
```

Finger names use forms such as `Thumb01_L`, `Thumb02_L`, and `Thumb03_L`. The complete ordered list and parent relationships are in the contract/audit JSON files. No automatic `Bone.001` names form part of the contract.

Blender exports Y-up with `NEGATIVE_Z` forward. The root conversion maps Blender +X to runtime +X, Blender +Z to runtime +Y, and Blender −Y to runtime +Z. Stage units are meters, with positive transform determinants and no mirrored root. Runtime placement wraps the imported root in a separate `FounderPlacement` entity, preserving the authored conversion.

Weights are reduced to at most four influences, normalized per vertex, and checked for valid joint indices and complete bindings. These numeric checks do not prove visually acceptable weighting. Joint topology, bind matrices, and rest matrices are checked independently in USD.

## Modular hierarchy and importer findings

The raw Blender export has one armature and ten mesh objects: body, head, top, bottom, shoes, hair, two eyeballs, and two irises. RealityKit initially combined the meshes into one rendered model while retaining empty mesh-name entities. Simply toggling those empty names did not hide the head. That import behavior required a packaging change and stronger tests.

The runtime package now places each mesh below its own `<MeshName>Module` `SkelRoot`, with a copy of the same canonical 55-joint skeleton. Ten renderable `ModelEntity` instances survive import. This is a packaging workaround, not ten appearance-specific skeletal contracts. A future controller must distribute the shared pose to all modules; joint evaluation and memory costs need profiling before production approval.

`setHeadVisible` toggles the head, hair, eyeball, and iris module roots. Tests now require real rendered geometry under the head module and leave the body enabled. The hidden-head screenshot still exposes a chin/neck remnant in BodyMesh: the geometric split needs repair before first-person use. Upper-torso-only masking is not implemented.

| Slot | Intended joint | Blender bind-space position, meters |
| --- | --- | --- |
| HairSlot | Head | (0, 0, 1.78) |
| TopSlot | Chest | (0, 0, 1.40) |
| BottomSlot | Hips | (0, 0, 0.97) |
| ShoeSlot | Root | (0, 0, 0) |
| AccessorySlot | Hand_R | (−0.45, −0.18, 1.10) |

Slots are stable bind-space anchors with `follow_joint` metadata. They do not yet automatically follow posed bones in RealityKit. Modular replacement is structurally possible without replacing the entire Founder, but hot-swapping and joint-follow attachment behavior are not implemented or validated.

## Appearance, facial capability, and budgets

The neutral candidate has a teal fitted top, gray casual pants, white simple shoes, and short geometry hair. Seven materials use RealityKit-compatible PBR color/roughness values. No custom runtime shader or Blender-only procedural surface is required. Character materials reference no textures, so character texture allocation estimate is zero; renderer buffers, render targets, and framework memory are separate. The retained `Intermediate/textures/color_0C0C0C.exr` is a generated supporting artifact, not a character surface texture budget.

| Geometry | Triangles |
| --- | ---: |
| Body | 18,788 |
| Head | 7,968 |
| Top | 3,420 |
| Bottom | 2,624 |
| Shoes | 1,200 |
| Hair | 268 |
| Eyes and irises (four meshes) | 2,880 |
| **Total submitted character topology** | **37,148** |

The total includes body triangles occluded by clothing; it is not a GPU capture of visible triangles. The budget is below the suggested 40–80k starting range, which alone is neither a quality nor a performance result.

Separate `Eye_L` and `Eye_R` bones bind eyeballs and irises, preparing independent gaze. Nine nonempty head targets export and appear as RealityKit blendshape weights: `Blink_L`, `Blink_R`, `JawOpen`, `Smile`, `Frown`, `BrowRaise`, `BrowLower`, `MouthNarrow`, and `MouthWide`. Directional eye-look morphs are not authored; eye bones are the intended mechanism.

Facial targets currently use procedural masks. Their names, deltas, and import survive, but facial poses have not been visually accepted. In particular, masks need alignment against the final eye geometry and blink closure needs close inspection. No expression controller was added.

Shared upstream topology could support lean, average, athletic, and solid presets through coordinated reauthoring. Current top/bottom patches and skinning are fitted to this body. Applying extreme body-only morphs would risk clothing penetration and incorrect joint centers. Body, rig placement, clothes, and weights must be refitted together while preserving semantic names. No body Creator UI or validated alternative body preset was delivered. Separate mesh modules permit future LOD replacements; no LOD assets or switching have been authored.

## Visual and Garage-scale evidence

All seven Blender validation pose renders are retained under `Evidence/`. Their presence is not a production deformation pass:

| Evidence | Finding |
| --- | --- |
| `A_Neutral.png` | Full body and finger silhouette present; clothing fit, shoes, face, and hem remain rudimentary. |
| `B_ArmsRaised.png` | Arm raise fixture generated; shoulders require further close inspection and acceptance. |
| `C_Seated.png` | Deep seated Blender fixture generated; does not establish acceptable runtime chair alignment. |
| `D_Stride.png` | Leg bend and stride visible; no gait, floor-contact, or foot-roll validation. |
| `E_HeadTurn.png` | Large head-turn fixture generated; neck/head seam remains a blocker. |
| `F_Elbow.png` | Elbow/finger articulation visible; hand contact and deformation quality remain unaccepted. |
| `G_FingerCurl.png` | Finger chains articulate; no keyboard, phone, grasp, or thumb-opposition acceptance. |

Runtime captures: `iPhone17ProMax_Standing.png`, `iPhone17ProMax_Seated.png`, `iPhone17ProMax_CloseUp.png`, `iPhone17ProMax_HeadHidden.png`, `iPadAirM4_Standing.png`, `iPadAirM4_Seated.png`, and `iPadAirM4_CloseUp.png`.

The fixture uses production anchor coordinates and simple boxes for chair, desk, computer, door, floor, and ceiling. It is not the full production Garage scene. Strategy Board scale has not been validated. The standing candidate has plausible overall adult scale, but seated legs are uneven, one shoe sits under the chair, and seat/body intersections remain. Floor contact, knee clearance, and believable keyboard height are not established. The face has a mannequin appearance and a jagged chin/neck boundary. These defects require implementation repair, not merely human approval.

The screenshots can show different load values from the table below because each capture and the final metric file came from separate launches. No physical-device screenshots or human appearance acceptance were recorded.

## Performance measurements and limits

Latest single-launch samples from `Evidence/*metrics.json`. Footprints use the existing process-memory helper (MiB reported as MB in the fixture). Load time measures the awaited asset import. First scene update is a proxy event, not first visible pixel presentation.

| Destination | Load ms | Before MiB | Loaded MiB | Delta MiB | First scene update ms | First update MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| iPhone 17 Pro Max simulator | 222.47 | 42.36 | 55.78 | 13.42 | 238.52 | 55.94 |
| iPad Air 11-inch M4 simulator | 198.07 | 42.36 | 55.52 | 13.16 | 230.54 | 55.64 |
| Physical iPad Air M4 | 146.78 | 133.49 | 319.77 | 186.28 | 150.10 | 319.94 |
| Physical iPhone 16 Pro | 2,041.40 | 106.33 | 234.58 | 128.25 | 2,053.46 | 234.75 |

All four samples report ten model entities, 55 unique joint names, and nine facial weight names. Signed Debug builds were installed and launched on both physical devices. Those devices currently received the QA build, not a newly validated signed Release build.

Physical memory growth and iPhone load latency are unresolved. These measurements include process/framework activity around RealityKit initialization; the delta cannot be attributed solely to the asset. There is no controlled empty-scene comparison, repeated warm/cold sample series, peak-memory trace, steady-state endurance run, GPU triangle capture, or actual first-pixel latency measurement. Therefore the requested “no large memory spike/no severe load regression” gate has **not passed**. Simulator results cannot substitute for physical profiling.

## Automated verification and builds

The final implementation checkpoint on 2026-09-17 passed **907 unit tests, zero failures, zero skips** on iPhone 17 Pro Max, iOS Simulator 26.5. Persisted summary: `Evidence/full_unit_summary.json`. Original result bundle:

`/tmp/solo-founder-character/Logs/Test/Test-Solo Unicorn Run-2026.09.17_10-41-16--0400.xcresult`

The three new `FounderCharacterContractTests` cover import, required bones, materials, facial target names, independent rendered modules, slots, scale bounds, placement transform preservation, head visibility, and the unchanged nine-state clip mapping. The broader unit run includes the existing Garage, locomotion, Camera Physics, and traversal coverage; this report does not claim a fresh production-route UI test run or human acceptance.

Debug simulator, Release simulator, and signed Debug device builds passed at that checkpoint. Release/device builds emitted RevenueCat dependency warnings. Logs retained in `/tmp/founder-release.log` and `/tmp/founder-device.log`; those temporary files are not durable repository artifacts. Xcode used SDK 27.0 with simulator runtime 26.5.

For reproduction, the test target's exact name is `Solo Unicorn Run Tests` (including spaces):

```sh
xcodebuild -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,id=1E9DD15B-55DA-42A5-92F1-45F8C8AE4414' -derivedDataPath /tmp/solo-founder-character -only-testing:'Solo Unicorn Run Tests/FounderCharacterContractTests' test
xcodebuild -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,id=1E9DD15B-55DA-42A5-92F1-45F8C8AE4414' -derivedDataPath /tmp/solo-founder-character -only-testing:'Solo Unicorn Run Tests' test
xcodebuild -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/solo-founder-character build
```

An earlier invalid test filter omitted the space before `Tests`; that was a command error, not evidence of a broken shared scheme. This pass did not repair or regenerate the scheme.

Raw USD audit passed: root, units/axes, exact bone hierarchy, bind/rest transforms, weights, mesh/material binding, nine nonempty facial targets, slots, and exact mesh height. The separate final package audit checks matching canonical skeleton copies, bindings, relationship targets, weights, modules, facial target count, slots, and byte equality with the app resource. Neither audit certifies visual appearance.

Final package audit passed on 2026-09-17. Package size: 1,891,885 bytes. SHA-256: `b07ddd8438d09abe0277fda10a8302ca7f17c189bdff8c5d1b7d5d9ef13fbe77`. The final continuation added only this report and the standalone runtime audit/script result; app code and asset bytes were not changed after the 907-test checkpoint.

Repository-wide `git diff --check` fails on pre-existing trailing whitespace in `Tests/FounderDeskWorkspaceTests.swift` at lines 1184, 1194, 1198, 1202, 1383, 1388, and 1391. Those unrelated lines were preserved. Targeted tracked-file checks for `App/App.swift` and the project file pass. No existing regression test was weakened.

A separate text whitespace scan also found trailing spaces in the verbatim upstream `Source/MPFB_LICENSE.md` at lines 20, 45, 46, 63, and 74; that license copy was preserved. Authored pass source, tests, scripts, and this report pass the whitespace scan.

## Files changed by this pass

Existing tracked files modified:

- `App/App.swift`: opt-in Debug QA launch route.
- `SoloUnicornRun.xcodeproj/project.pbxproj`: precise membership for the contract source, contract test, and USDZ resource (IDs beginning `FC190000`). Existing unrelated project changes were preserved; no project regeneration.

New app/test files:

- `App/FounderCharacterContract.swift`.
- `Tests/FounderCharacterContractTests.swift`.
- `App/RealityKit/FounderCharacter/founder_candidate_a.usdz`.

New files under `Documentation/FounderCharacter/`:

- This report.
- `Source/build_founder.py`, `Source/audit_founder.py`, `Source/package_runtime.py`, `Source/audit_runtime.py`.
- `Source/founder_candidate_a.blend`, `Source/founder_candidate_a.blend1`.
- `Source/MPFB_LICENSE.md`, `Source/MPFB_LICENSE_ASSETS.md`.
- `Intermediate/blender_contract.json`, `Intermediate/usd_audit.json`, `Intermediate/runtime_audit.json`.
- `Intermediate/founder_candidate_a.usdc`, `Intermediate/founder_candidate_a.usdz`, `Intermediate/founder_runtime_a.usdc`, `Intermediate/founder_runtime_a.usdz`.
- `Intermediate/textures/color_0C0C0C.exr`.
- `Evidence/A_Neutral.png`, `Evidence/B_ArmsRaised.png`, `Evidence/C_Seated.png`, `Evidence/D_Stride.png`, `Evidence/E_HeadTurn.png`, `Evidence/F_Elbow.png`, `Evidence/G_FingerCurl.png`.
- `Evidence/iPhone17ProMax_Standing.png`, `Evidence/iPhone17ProMax_Seated.png`, `Evidence/iPhone17ProMax_CloseUp.png`, `Evidence/iPhone17ProMax_HeadHidden.png`.
- `Evidence/iPadAirM4_Standing.png`, `Evidence/iPadAirM4_Seated.png`, `Evidence/iPadAirM4_CloseUp.png`.
- `Evidence/iPhone17ProMax_metrics.json`, `Evidence/iPadAirM4_metrics.json`, `Evidence/Physical_iPhone16Pro_metrics.json`, `Evidence/Physical_iPadAirM4_metrics.json`.
- `Evidence/full_unit_summary.json`.

All other dirty/untracked repository work was preserved, including existing shared-scheme changes, Garage/Atlantis repairs, WorkSession changes, `.agents`, MCP configuration, and older evidence. No commit, staging, push, merge, reset, clean, or rebase was performed.

## Remaining Pass A work before production consideration

1. Repair the head/body split and normals, first-person chin remnant, face/eyebrow detail, hair silhouette, top hem, garment fit, and shoe shape to achieve the requested visual standard.
2. Correct side-specific runtime leg pose axes and seated alignment; inspect hips, knees, shoulders, neck, fingers, and floor contact against the actual Garage, including Strategy Board scale.
3. Refine and visually validate facial targets, especially blink closure, eye placement, and jaw behavior.
4. Measure isolated asset load/peak memory with controlled scene baselines, repeated device samples, and presented-frame timing; investigate skeleton-copy overhead and the physical iPhone latency.
5. Repeat affected contract/regression/build checks after repairs, then obtain human acceptance on iPhone and iPad. Human approval cannot substitute for the known defects above.

No clothing expansion, production locomotion clips, gaze controller, or production character replacement was started.
