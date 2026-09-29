# Shipathon S5 — Bounded City Life

Status: **S5 — OWNER REVISE; Mara reference-based Blender Gate 1 ACCEPTED for shape and wardrobe, Gate 2 pending.** The prior procedural C candidate is superseded for production-visible characters. S2/S3/S4 production values remain locked.

## Starting ratchets and baseline

Recovery checkout `/private/tmp/solo-shipathon-recovery-s3`, branch `codex/shipathon-recovery-s5`, HEAD `45301e34e9af4d04fa6c1db6c618007ccad46789`. The accepted S4 no-flag route reaches the peer area at approximately `(-823.7, 8.38, 939.6)` at 1.4 m/s. [Shot 4](Captures/S4-Production-iPhone/827009D3-098D-4013-B731-E1A803A4A8C2.png), [walking Shot 5](Captures/S4-Production-iPhone/EDBFB459-CFA1-46CD-87E7-1B10B5530F41.png), [stopped Spire](Captures/S4-Production-iPhone/9DE6490D-0971-452E-8D39-271421E3F726.png), and [peer endpoint](Captures/S4-Production-Route-iPhone/E0F918F9-2A59-4C17-838B-F9F1ABB52592.png) are the production baseline. The endpoint shows an unmarked paved walkway with no visible peer; the first street has no human-scale activity. These are the first S5 credibility breaks.

Accepted hashes: Founder District USDZ `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10`; Atlantis manifest `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`. Save version 20. S4 C2 camera, Material B, A2 daylight, Atmosphere A, route, and Founder rig are frozen.

Baseline full-route iPhone 17 Pro Max iOS 26.5: Founder District load 1.756 s; 6,651 `SceneEvents.Update` samples; mean 17.56 ms; p95 33.27 ms; longest 33.48 ms; zero over 50 ms; route memory 201.5→247.1 MB. These are simulator callback and memory measurements, not GPU FPS.

## Ownership map — completed before S5 production edits

| Concern | Existing owner and inspected behavior | S5 boundary |
| --- | --- | --- |
| Player position, heading, traversal, collision | `AtlantisRealityWorld` in `App/AtlantisRealityScene.swift`; canonical movement 1.4 m/s | Read position for presentation radius only. No movement or collision edits. |
| District load/unload | `AtlantisStreamingCoordinator`, `AtlantisDistrictLoader`, and `loader.onInstall/onWillUnload` in `AtlantisRealityWorld` | Activity must release when Founder District unloads. No package or manifest edit. |
| Ambient entities | `AtlantisLivingWorldDistrictPopulation` and pooled `AtlantisAmbientActor`; deterministic seed, route interpolation, LOD, budgets; currently enabled only by `--atlantis-living-world*` | Reuse with a production Founder hero-route mode capped at a few visible actors; avoid enabling other districts. |
| Public world cues | `AtlantisWorldReactionAdapter` and `AtlantisPublicDisplay` consume `AtlantisWorldSignalSnapshot`; currently gated with debug living world and placed near the legacy Founder route at z≈850 | Reuse only public projection if it produces a small, route-readable cue. No hidden truth or new narrative state. |
| Named peer | `AtlantisNamedNPCDefinition` places Mara Chen of Quarry Labs near `(-825, 8.375, 940)`; `AtlantisNamedEncounterDirector` is currently debug-gated and owns interaction availability | S5 can borrow public identity and stage a visual presence. Encounter activation and response remain S6 work. |
| World consequences | `AtlantisWorldConsequenceDirector` attaches public state to imported semantic anchors, including FounderGarageSlot; debug-gated | Keep disabled for S5; broad consequence staging is outside the route-only candidate. |
| Public media | `SignalTVModels` supplies canonical public events; `FounderGarageRealityView` forwards a public snapshot to the living director | No GameStore mutation, media event creation, or Coverage change. |
| Accessibility | `FounderGarageRealityView` receives `accessibilityReduceMotion` and calls `setFounderReduceMotion` | Propagate to ambient presentation; freeze decorative continuous motion while preserving static presence. |

The Founder District runtime manifest exposes `FounderGarageSlot` as its only imported semantic anchor. The relocated peer position already exists in the named NPC definition, so S5 need not edit USDZ or the manifest. A separate generalized city-life subsystem would duplicate the existing director and is rejected.

## First hypothesis

The hero route feels empty because its existing presentation system is disabled and its Founder ambient route is approximately 190 m south of the Garage/Shot 5 corridor. Try a small number of deterministic, collision-free human-scale cues along the walked route and a public founder identity near peer staging. Compare each bounded layer at matched production-camera points before keeping it.

## S5.1 street presence — first comparison

An opt-in use of the existing ambient actor pool was placed on the walked Founder Street. The [first Shot 4](Captures/S5-Ambient-iPhone/4BABEEE3-3017-4930-869E-960DCA8E8D3C.png) adds a person at the frame edge; [walking Shot 5](Captures/S5-Ambient-iPhone/559D2C3D-EC1F-4F7E-BADC-9837BC676DDF.png) adds a second person ahead; the [stopped Spire](Captures/S5-Ambient-iPhone/1CABF5B1-A8A2-47F3-8C95-5A5B4BC344C6.png) remains legible. The initial bright, bare block silhouettes looked like temporary markers and are **rejected**. The same layer is being revised with muted clothing, head/limb proportions, and only two street people. The peer person is reserved for the peer-arrival layer, so its distant dot does not enter the street comparison. Focused bounded-policy and first iPhone key-frame tests passed; visual judgment drove the revision.

The revised two-person study passed the focused policy and iPhone key-frame tests. [Shot 4](Captures/S5-Ambient-Revised-iPhone/6E57798A-491A-4CB9-9393-8F46E7138836.png) retains the accepted centered view with one quiet silhouette off to the side; [walking Shot 5](Captures/S5-Ambient-Revised-iPhone/E20BB693-0169-441F-BCEC-F141F827BDB4.png) has one human-scale presence ahead; the [stopped Spire](Captures/S5-Ambient-Revised-iPhone/F6EBD72E-D206-4592-9A19-154C36607BE4.png) stays clear. This is the retained street layer for the full candidate, still pending owner judgment. The silhouettes are intentionally simple and distant; close-up character fidelity is outside S5.

## S5.2 startup identity cue — peer approach

The existing public display entity was scaled into a collision-free Quarry Labs marker using Mara Chen's already-public name, founder role, and affiliation. No media event or new story state was created. The first [peer endpoint](Captures/S5-PeerSign-iPhone/47D05B48-AEFD-4331-9F9B-C481E9BEE761.png) showed an unreadable board back at the far frame edge. A facing and placement correction produced a [larger blank board obstructing the arrival](Captures/S5-PeerSign-Revised-iPhone/FC7BB75A-4171-47C9-BF3F-1CA18BE52903.png). Both 3D sign variants are **rejected** and removed from the candidate code.

The retained hypothesis uses a small, noninteractive, VoiceOver-readable route cue in the existing Atlantis HUD. It projects only Mara's public name, founder role, and Quarry Labs affiliation from the existing named NPC definition. It appears within 45 m of the staging position while Founder District is resident, then clears outside that range. The [matched iPhone peer frame](Captures/S5-PeerCue-iPhone/A3FCAE01-17C6-4869-860C-1A55CBE6E735.png) is readable and leaves the camera view clear. The focused policy test and full iPhone route passed. No menu or hidden simulation value is involved.

## S5.3 peer staging — destination presence

The first named-NPC staging study reused the existing visual entity but exposed its debug cyan box and clipped world text at the [peer endpoint](Captures/S5-Candidate-iPhone/7A81CEB2-61EA-4BCF-B5A2-06F1A1F314A4.png). That visual is **rejected**. A restrained clothing palette and simple limbs replaced the debug appearance for this S5-only presentation. The next [peer frame](Captures/S5-Candidate-Revised-iPhone/44C5499D-303D-4F36-8B0D-47751E3D5BBA.png) hid the figure behind the approach geometry, and the following [frame](Captures/S5-Candidate-Final-iPhone/02BC1A88-E72C-44A2-A077-48B2679CF9D6.png) showed overlap with the Founder. Both placements were **rejected**. The initial candidate moved the figure one meter farther left. The 3D nameplate was hidden; the accessible HUD cue carried the public identity.

The final [iPhone peer frame](Captures/S5-Final-iPhone/299AC2FB-D051-4B80-AD0B-8E32A94EAB1C.png) separates Mara from the Founder on the left side of the arrival, and the startup cue remains legible. The figure is deliberately simple and remains subject to owner visual judgment. The peer director's S5-only staging mode attaches Mara within the existing 45 m policy, without enabling an encounter, dialogue, collision, or canonical writeback. Other named NPCs are absent in this mode. The focused policy test passed. No save, RNG, finance, Coverage, or hidden truth path changed.

## Final candidate and production-camera comparisons

The candidate combines the two muted, deterministic street actors, one public Quarry Labs HUD cue, and one visual-only Mara staging presence. It is enabled only by `--shipathon-s5-candidate` for review; accepted production behavior remains unchanged until the owner chooses. [iPhone garage exit](Captures/S5-Final-iPhone/600DDEC9-E992-4ED5-B76E-D1722EE09C5D.png), [Shot 4](Captures/S5-Final-iPhone/BAFBEDF7-4E45-4327-B8AC-3EB2557ABB6D.png), [walking Shot 5](Captures/S5-Final-iPhone/D521C1B6-B50D-4DB3-8DFB-E213499C63F6.png), [stopped Spire](Captures/S5-Final-iPhone/9D080687-2475-45D0-99E3-9B50DF18B118.png), [restart](Captures/S5-Final-iPhone/5B448B7F-3537-47E0-81D3-42FFB66FC0BA.png), and [peer endpoint](Captures/S5-Final-iPhone/299AC2FB-D051-4B80-AD0B-8E32A94EAB1C.png) are production-camera captures. The S4 C2 keyframe UI assertions passed for centered walking, stopped yaw 0.75, restart/reverse/recenter, and unblocked route. The continuous route again reached `(-823.7, 8.38, 939.6)` at 1.4 m/s.

## Runtime budget

| iPhone 17 Pro Max iOS 26.5 route | Accepted S4 no-flag | S5 final candidate |
| --- | ---: | ---: |
| Founder District load | 1.756 s | 1.679 s |
| `SceneEvents.Update` samples | 6,651 | 6,590 |
| Mean callback interval | 17.56 ms | 17.72 ms |
| p95 callback interval | 33.27 ms | 33.33 ms |
| Longest callback interval | 33.48 ms | 33.45 ms |
| Intervals >50 ms | 0 | 0 |
| Route memory start → end | 201.5 → 247.1 MB | 200.0 → 203.0 MB |

These are simulator callback and process-footprint samples, not GPU frame rate. Run-to-run memory variance makes the endpoint memory comparison directional; there was no runaway growth in the S5 run. At Shot 4 and Shot 5, two ambient actors (14 child/root entities) are active; near the peer they release and one named peer (11 child/root entities) is active. Vehicles remain zero. The living director totals 18 scene entities at Shot 4/5 and 15 at the peer, including four pre-existing director roots. The cue is SwiftUI presentation, not a scene entity. [Final route diagnostics](Captures/S5-Final-iPhone/EBB95941-184A-4555-9481-9124547DADE7.txt) and [Shot 5 diagnostics](Captures/S5-Final-iPhone/E717EA07-69D4-4C9A-8087-6AB0562EADAB.txt) are attached.

## iPad comparison and baseline limitation

On iPad Air 11-inch (M4), iOS 26.5, the candidate [Shot 4](Captures/S5-Final-iPad/F018843A-506D-4700-BE72-B7DC61848776.png), [walking Shot 5](Captures/S5-Final-iPad/D5194F35-EA5F-48CA-891D-45C23391E526.png), [stopped Spire](Captures/S5-Final-iPad/B2D5E67F-DCBA-4F42-AC22-B399034B3F3F.png), [restart](Captures/S5-Final-iPad/A64C677E-D3EA-438F-B624-03FFB770CBDD.png), and [reverse](Captures/S5-Final-iPad/FA594074-E926-43A5-B817-63F51505227C.png) passed the S4 C2 keyframe assertions. The optional full iPad walk stopped with `Blocked: missing ground` at `(-823.5, 8.20, 985.8)`, before the cue/peer activation range; diagnostics show zero ambient, zero peer, zero cue, and four director roots. The [no-flag production route](Captures/S5-iPad-NoFlag-Baseline/ED2ED707-D493-43EB-B380-35895548E0A5.txt) reproduced the same stop at `(-823.5, 8.20, 985.7)`. Thus the current iPad full-route failure is present without S5. The S5 peer endpoint could not be visually judged on iPad by this route. This contradicts the historical S4 acceptance claim of an iPad route pass and warrants a separate traversal investigation before any broader iPad completion claim; S5 did not alter grounding, collision, or movement.

## Verification and boundaries

- Three focused `AtlantisRuntimeTests` passed: deterministic bounded ambient life and Reduce Motion travel freeze, 45 m public cue policy, and proximity-bound noninteractive peer staging. The policy tests also verify zero vehicles, no out-of-route population, no peer encounter candidate, and no canonical writeback.
- The final iPhone 17 Pro Max iOS 26.5 full-route and keyframe UI tests passed. The iPad Air 11-inch (M4) keyframe UI test passed. The additional iPad full-route test failed as described above, and the no-flag control reproduced it.
- The `Solo Unicorn Run` scheme build passed. `git diff --check` passed. The Xcode project and shared scheme have no diff. Accepted USDZ and manifest hashes remain `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10` and `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`; save version remains 20.
- Reduce Motion freezes added ambient travel and decorative named head motion in code; the focused ambient test passed. A human device check is still needed for visual motion, popping, audio, and haptics. The full suite was not rerun because the focused S5 policy, scheme build, and required route captures cover this bounded presentation change; previously accepted S2/S3/S4 evidence remains historical.

S5 work modified `App/AtlantisRealityScene.swift`, `App/AtlantisWorldPresentationModel.swift`, `App/FounderGarageRealityView.swift`, `Tests/AtlantisRuntimeTests.swift`, and `UITests/Build32_6_1ProductionContinuityUITests.swift`. It added this report and `Documentation/Shipathon/Captures/S5-*` evidence. Other dirty files in the recovery checkout belong to accepted S2/S3/S4 recovery and were preserved. No commit, push, reset, clean, save migration, simulation rule, imported asset, manifest, project file, or scheme edit was made for S5. The candidate remains opt-in pending the owner gate.

## Initial owner gate — superseded by REVISE

**S5 CANDIDATE READY — OWNER ACCEPT / REVISE / REJECT**

The owner judged the figure too placeholder-like, the destination insufficiently anchored, and the HUD too prominent. The decision was **S5 — REVISE**, not acceptance. The revision record follows.

## S5-R1 — owner REVISE record

The owner kept S5's bounded architecture, two street people, peer policy, 45 m activation, no-writeback/no-interaction boundary, route, S4 C2 camera, S3 visual locks, save version 20, accepted assets, and performance behavior. The rejected [initial endpoint](Captures/S5-Final-iPhone/299AC2FB-D051-4B80-AD0B-8E32A94EAB1C.png) had a box-built Mara, grass-side staging without a Quarry Labs anchor, a mission-like company/name HUD card, and a persistent `ATLANTIS Founder` card. This revision changes only Mara's presentation, the small destination marker, and the local HUD hierarchy.

### Mara fidelity audit and bounded path

The repository's only complete authored humanoid asset is `founder_candidate_a.usdz`, the accepted textured, rigged Founder. A second use would visibly duplicate the player identity and add an authored skeletal character to a presentation-only peer. The existing named NPC director already owns Mara's public definition, lifecycle, resident radius, and no-interaction staging. The smallest viable path was to improve that one entity's low-cost geometry: rounded torso/hip/shoulder forms, segmented upper/lower arms and legs, hands, shoes, neck, hair crown/back/bun, restrained jacket and trouser materials, and a held device. The head makes a slow deterministic glance toward the approach; Reduce Motion holds a static phone-looking pose. Neither player rig nor accepted Founder asset changed.

The first A capture exposed a lifecycle scale reset, yielding an [oversized sphere](Captures/S5-R1-A-iPhone/313ECCD2-0254-4FF1-8C2D-60628C7ED360.png); that implementation defect was rejected and a focused torso-scale assertion added. The corrected [A study](Captures/S5-R1-A2-iPhone/A9F6B61D-DDF8-4787-9A68-DBDA57A53972.png) was human but too padded at the shoulders and chest; that proportion study was rejected. The settled [A endpoint](Captures/S5-R1-A3-iPhone/689A5AD1-E380-4615-BEFA-DED9EDC46660.png) is more coherent, but the open grass still lacks a company destination. These captures use the real S4 camera and `(-823.7, 8.38, 939.6)` endpoint.

### A/B/C controlled comparison

| Study | Change over previous | Matched iPhone peer frame | Judgment |
| --- | --- | --- | --- |
| A | Improved Mara only; original HUD | [A](Captures/S5-R1-A3-iPhone/689A5AD1-E380-4615-BEFA-DED9EDC46660.png) | Mara reads as a person, but the destination remains unmarked; reject as final. |
| B | Add narrow, collision-free Quarry Labs marker from Mara's public affiliation | [B first marker](Captures/S5-R1-B-iPhone/D241ABA3-5BD1-43CF-B96B-66E369DBAD08.png) | First letter hides behind Mara; reject that placement. A raised [B marker](Captures/S5-R1-B2-iPhone/AC91B301-5D03-4073-8DC0-82835A3C06D7.png) clears the name, but that route ended 2 m left of the matched endpoint and is not used for composition comparison. |
| C | Retain raised marker; show only Mara's name/role in HUD and let local destination context replace the broad area card | [C](Captures/S5-R1-C-iPhone/B671CE3F-C90F-41B6-BE63-05EDA8F28CF1.png) | Strongest hierarchy and destination readability at the matched endpoint; retain for owner review. |

The marker is a slim wayfinding plaque behind Mara, not the rejected large 3D billboard. It has no collision, activates only with the existing peer presence, and leaves the 1.4 m/s approach lane clear. Variant C uses Mara's existing public name, role, and affiliation. The world carries `QUARRY LABS`; the HUD gives the smaller `Mara Chen / Founder` confirmation. The broad area card remains elsewhere and is absent only while this local destination presentation is active. C remains an opt-in study (`--shipathon-s5-revision-c`) pending owner acceptance; A/B flags remain available as comparison fixtures.

### Final production-route evidence

The final C source uses the affiliation in the existing public Mara definition for the plaque text. The iPhone 17 Pro Max, iOS 26.5, continuous route passed and reached `(-823.7, 8.38, 939.6)` at the unchanged 1.4 m/s walk rate. Its [Garage](Captures/S5-R1-Final-iPhone/1A6EB012-3506-4EA2-A7FD-C31BF0F67810.png), [threshold](Captures/S5-R1-Final-iPhone/81BA8841-DCA8-4130-8DB3-6FB092E075A5.png), [Shot 4](Captures/S5-R1-Final-iPhone/BC6DB1FF-E156-4224-A699-EBE733CF3491.png), [walking Shot 5](Captures/S5-R1-Final-iPhone/D6D0D2D9-F58E-479B-B1A5-9BE092237AF7.png), and [peer endpoint](Captures/S5-R1-Final-iPhone/677E805B-BBE7-4EAF-A300-CD475CC6B172.png) are the final source captures. The peer frame keeps Mara, the wayfinding plaque, and the compact public HUD cue separated and legible. The S4 C2 [stop](Captures/S5-R1-Final-iPhone/23B72656-6DDC-4551-AE0E-C6E66CB76443.png), [restart](Captures/S5-R1-Final-iPhone/063EFCFA-9F16-4F8F-834D-5CB6A3F222A4.png), and [reverse](Captures/S5-R1-Final-iPhone/DFBD01CE-2A30-4433-8913-5DDAA3395521.png) keyframes also passed.

The iPad Air 11-inch (M4), iOS 26.5, C keyframe test passed at [Garage](Captures/S5-R1-Final-iPad/B4D1D7D2-470F-4FA5-878C-B9FCC534A8A0.png), [Shot 4](Captures/S5-R1-Final-iPad/BE695E9C-3565-42F8-99F2-48E443F6FE99.png), [walking Shot 5](Captures/S5-R1-Final-iPad/5E2D19B7-27E8-45E8-8E9E-847E1B3A411B.png), [stop](Captures/S5-R1-Final-iPad/FAB69C20-5252-4383-B018-52FDCCEEF854.png), [restart](Captures/S5-R1-Final-iPad/478DEF77-8374-4CF3-86F4-574C0715A08B.png), and [reverse](Captures/S5-R1-Final-iPad/C98AFB94-2514-4960-8082-18BB16984FBC.png). The pre-existing no-flag iPad full-route control stopped at z≈985.7 with `Blocked: missing ground`; the original S5 candidate stopped at z≈985.8 before peer activation. The revised iPad endpoint was therefore not visually verified. This remains a separate traversal defect and a limit on S5 acceptance evidence.

### Verification and performance

Four focused `AtlantisRuntimeTests` passed on the final source: bounded two-person ambient policy with Reduce Motion; 45 m public cue; proximity-bound noninteractive staging with torso-scale retention; and marker lifecycle, collision absence, Reduce Motion head pose, and no encounter/writeback. The iPhone full-route and S4 C2 keyframe UI tests passed. The iPad S4 C2 keyframe UI test passed. Human device acceptance remains needed for character quality, motion, audio, and haptics; automated tests do not establish those qualities.

| iPhone 17 Pro Max iOS 26.5 continuous route | Accepted S4 no-flag | Initial S5 candidate | Revised C |
| --- | ---: | ---: | ---: |
| Founder District load | 1.756 s | 1.679 s | 1.715 s |
| `SceneEvents.Update` samples | 6,651 | 6,590 | 6,556 |
| Mean callback interval | 17.56 ms | 17.72 ms | 17.81 ms |
| p95 callback interval | 33.27 ms | 33.33 ms | 33.33 ms |
| Longest callback interval | 33.48 ms | 33.45 ms | 33.49 ms |
| Intervals >50 ms | 0 | 0 | 0 |
| Route memory start → end | 201.5 → 247.1 MB | 200.0 → 203.0 MB | 202.7 → 204.7 MB |

The [final route diagnostics](Captures/S5-R1-Final-iPhone/5AF76AC0-F7D6-4163-BE3E-742A64D06DD6.txt) record one staged peer, one cue, no ambient actors at the endpoint, and 38 director entities. The additional geometry and marker increase local entity count from the initial S5 peer's 15 while remaining bounded by the existing 45 m lifecycle. These numbers measure simulator callback intervals and process footprint, not GPU frame rate. Run-to-run memory variance limits cross-run conclusions; the final C route showed no runaway growth. The broad suite was not rerun for this bounded presentation revision; focused policy, scheme build, and production-route tests are the current evidence.

The accepted Founder District USDZ hash is `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10`; Atlantis manifest hash is `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`. `GameStore.saveVersion` remains 20. The explicit final `Solo Unicorn Run` scheme build passed. Xcode project and shared scheme have no diff; `git diff --check` passes.

S5-R1 modified `App/AtlantisRealityScene.swift`, `App/FounderGarageRealityView.swift`, `Tests/AtlantisRuntimeTests.swift`, `UITests/Build32_6_1ProductionContinuityUITests.swift`, and this report, and added `Documentation/Shipathon/Captures/S5-R1-*` evidence. Earlier S2–S5 dirty work in the recovery checkout was preserved. No commit, push, reset, clean, save migration, simulation rule, imported asset, manifest, project-file, or scheme edit was made for S5-R1. Variant C is an opt-in owner review candidate; owner acceptance must precede any production lock or S6 work.

**S5 REVISED CANDIDATE READY — OWNER ACCEPT / REVISE / REJECT**

## S5-B1 — Blender character Gate 0 and Gate 1

The owner rejected the procedural Mara and all production-visible characters assembled from RealityKit primitives. The bounded S5 city-life and named-peer architecture remains the direction, but the character asset layer must be Blender-authored. The previous C runtime screenshot is historical rejection evidence, not a production candidate. No Swift, project membership, runtime USDZ, or ambient NPC visual was changed in S5-B1.

### Gate 0 — asset pipeline and contract

The accepted Founder source and export chain were inspected: `Documentation/FounderCharacter/Source/founder_candidate_a.blend`, `build_founder.py`, `package_runtime.py`, the source/contract audits, accepted `founder_candidate_a.usdz`, and the RealityKit loader. The Founder authoring source uses meters, Blender Z-up/−Y forward and exports USD Y-up/+Z forward. Its final runtime package contains a 55-joint skeleton copied into ten independently visible modules because a raw combined export did not keep all module visibility semantics in RealityKit. That is a technical reference, not a requirement to duplicate the Founder's appearance or cost for Mara. The exact Mara import contract must be proven at a later gate.

The [Mara asset contract](../../Assets/Atlantis/Characters/MaraChen/ASSET_CONTRACT.md) records a 1.68 m target, iPhone approach read at roughly 3–15 m, 8k–18k final triangle target, one 1024² atlas maximum initially, lightweight humanoid rig, three authored clips (`idle`, `deviceIdle`, `noticeFounder`), coordinate conversion, `AtlantisNamedEncounterDirector` runtime ownership, 45 m lifecycle, and zero collision/interaction/writeback. The accepted Founder source remains read-only. Its source SHA-256 is `d8be1e3e5cddfa69862a25ecb52f3ab95bb62d47b40364732480f5febe95843e`; bundled USDZ remains `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.

### Gate 1 — clay graybox for proportion review

The first all-loft clay attempt still read like assembled primitive geometry and was rejected during self-review before presentation. The next anatomical study used the Founder topology as a read-only template but invented a low ponytail and wardrobe; it was superseded when the owner supplied [Mara's visual reference](../../Assets/Atlantis/Characters/MaraChen/Reference/mara_chen_reference.png). Its SHA-256 is `4ae2ade09b9d1c1087c279e87791e74b49bc4e869252964e40e595fd970bda0f`. The picture, rather than the invented styling, now controls Gate 1. Its design evidence is the high loose bun, face-framing strands, raised olive cropped jacket, black top, high-waist charcoal trousers, chunky light sneakers, watch, and slim device. The reference picture's written biography and brand copy are not gameplay instructions.

The current editable [Mara Blender source](../../Assets/Atlantis/Characters/MaraChen/Blender/MaraChen.blend) and [rebuild script](../../Assets/Atlantis/Characters/MaraChen/Blender/build_anatomical_graybox.py) produce four Blender 5.2.1 LTS clay renders: [front](../../Assets/Atlantis/Characters/MaraChen/Graybox/mara_graybox_front.png), [back](../../Assets/Atlantis/Characters/MaraChen/Graybox/mara_graybox_back.png), [side](../../Assets/Atlantis/Characters/MaraChen/Graybox/mara_graybox_side.png), and [three-quarter](../../Assets/Atlantis/Characters/MaraChen/Graybox/mara_graybox_three-quarter.png). It uses the reference for the high bun, face-framing strands, raised collar, cropped upper layer, slimmer trouser outline, and light sneaker mass. The black inset top, watch, and held tablet were intentionally left out of this silhouette stage after early geometry looked like floating props; they remain required for a finished model.

The [graybox audit](../../Assets/Atlantis/Characters/MaraChen/asset_audit.json) records 16 meshes, 19,359 vertices, 37,716 triangles, five clay materials, zero textures, zero joints and zero clips. This exceeds the 8k–18k final mobile triangle target and **is not approved for export**. The graybox still reads too close to the Founder's face and anatomical source, with cut sleeve boundaries, simplified bun, and blocky shoes. My recommendation is **REVISE** before Gate 2 if the owner's goal is faithful resemblance to the picture; human judgment is the gate. No claim is made that this clay render is a finished premium character.

Gate 1 is intentionally the stop point. The existing procedural runtime Mara remains an opt-in rejected comparison fixture; no RealityKit import or route verification was attempted for this graybox. The separate iPad missing-ground route defect remains unchanged. `git diff --check` passed; accepted Founder District USDZ and Atlantis manifest hashes remain `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10` and `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`. Save version remains 20. S5-B1 added only `Assets/Atlantis/Characters/MaraChen/ASSET_CONTRACT.md`, `Reference/mara_chen_reference.png`, `Blender/build_anatomical_graybox.py`, `Blender/MaraChen.blend`, four `Graybox/mara_graybox_*.png` renders, `asset_audit.json`, and this report update. No commit or push.

The reference-based graybox above is the **Gate 1 owner comparison**. No texturing, rigging, authored clips, USDZ export, RealityKit integration, iPhone/iPad runtime claim, or ambient character conversion is authorized by this graybox alone. Owner ACCEPT / REVISE / REJECT remains pending.

## S5-B2 — image-driven Gate 0 / Gate 1 revision (2026-09-26)

The owner rejected the S5-B1 Founder-derived graybox and directed a reconstruction from the approved Mara Chen picture using Higgsfield use Blender MCP for scene operations. The [Gate 0 asset contract](../../Assets/Atlantis/Characters/MaraChen/ASSET_CONTRACT.md) now points to the separate image-driven source; the old script, blend, and renders remain historical rejected evidence. No Founder mesh is present in the delivered Gate 1 scene.

One multi-view reconstruction used front, side, and back crops of the approved sheet. Higgsfield's Tripo H3.1 returned FBX data, preserved as [source FBX](../../Assets/Atlantis/Characters/MaraChen/Source/mara_chen_multiview_candidate.fbx). Higgsfield use Blender MCP 0.2.2 imported it into Blender 5.2.1 LTS, set 1.683 m height and −Y forward, packed the reference, and saved the clean [Gate 1 Blender source](../../Assets/Atlantis/Characters/MaraChen/Blender/MaraChen_Gate1_Source.blend). MCP rendered the [front](../../Assets/Atlantis/Characters/MaraChen/Graybox/Review/front.png), [side](../../Assets/Atlantis/Characters/MaraChen/Graybox/Review/side.png), [back](../../Assets/Atlantis/Characters/MaraChen/Graybox/Review/back.png), and [three-quarter](../../Assets/Atlantis/Characters/MaraChen/Graybox/Review/three-quarter.png) 900 × 1200 review views. All four were visually inspected against the sheet. The bun, open cropped jacket, gathered sleeves, straight trousers, held slab, and broad trainer mass now read in silhouette. The face remains soft and the shoes lack the reference's sneaker paneling; these are explicit owner review points.

The [MCP audit](../../Assets/Atlantis/Characters/MaraChen/gate1_mcp_audit.json) records one mesh, 46,554 vertices, 93,004 triangles, one clay material, zero armatures and zero clips. This is **review geometry**, well over the 8k–18k final mobile target; Gate 2 requires retopology and visible facial/shoe refinement if the owner accepts the Gate 1 direction. The actual file and four PNG dimensions were checked, and the approved reference hash remains `4ae2ade09b9d1c1087c279e87791e74b49bc4e869252964e40e595fd970bda0f`. Accepted Founder District USDZ, Atlantis manifest and Founder USDZ hashes remain `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10`, `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`, and `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.

This pass changed only the Mara source/review artifacts, asset contract, and this report. It made no Swift, project, scheme, manifest, USDZ, save, or runtime integration change. An app build or simulator capture cannot validate a Blender-only graybox and was not run. The owner subsequently **ACCEPTED Gate 1 shape and wardrobe**. Facial identity, sneaker detail, materials, rig, clips, export, RealityKit import, and the S5 production visual remain pending later gates.

## S5-B3 — Founder Gate 1 revision D accepted (2026-09-26)

The owner first requested fuller, longer tied-back locs and a better sneaker read while approving the Founder body and wardrobe direction. The continuous outsole trial flattened and elongated the shoe, so it was removed. A segmented sole trial also failed visual inspection and was removed. The owner then **ACCEPTED the corrected revision D** with the original shoe footprint and the longer tied-back locs. Its [four matched clay views](../FounderCharacter/ReferenceRevision/GATE1_REVIEW.md) and [Blender audit](../FounderCharacter/ReferenceRevision/gate1_mcp_audit.json) are the Founder Gate 1 baseline. The accepted revision D `.blend` SHA-256 is `e8d96aa10d2524741e0cbc74d87bd5fd52440d1e5d4c81c98de87b6a0e02e00b`; the accepted production Founder USDZ remains `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` and was not touched.

Founder and Mara are both authorized for Gate 2 Blender refinement. Neither graybox is a finished or runtime-approved character. Founder revision D contains 95,945 triangles, no rig or animation, and the shoe still needs a reference-faithful trainer treatment. No Swift, USDZ, RealityKit, project, scheme, save or simulator change was made for this owner decision.
