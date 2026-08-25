# Build 32.6 — Founder Garage Environmental Cinematic Depth

## Reconciliation

1. **Actual starting commit:** `9257dc3cc519a4b541ca800e4b2f77d19374dbba` on `main`. The work continued from the repository's latest Build 32.5.x implementation; no earlier Build 32.5 commit was restored.
2. **Ending commit:** the self-referential final commit hash is recorded in Git history and the Bitrig delivery directive; this document is part of that commit.
3. **Files changed:** `App/App.swift`, `App/FounderEnvironmentScreen.swift`, `App/FounderGarageMotionPresentation.swift`, `App/FounderGaragePhysicalComponents.swift`, `App/MotionVerificationScreen.swift`, `Tests/Build32_4SpatialCausalityTests.swift`, this report, and the evidence in `VisualProof/Build32_6/`.
4. **Perspective/depth:** stations, infrastructure, the Founder desk, floor, and contact shadows use deterministic depth scaling. Rear-wall, middle-ground, and foreground camera layers use factors `0.52`, `0.80`, and `1.12` respectively. Floor seams converge at a defined horizon.
5. **Foreground framing:** a noninteractive chair arm, rack edge with equipment indicators, cable, and desk lip now occlude deeper layers without covering primary controls.
6. **Floor/materials:** a dedicated lightweight Canvas draws concrete variation, converging seams, scuffs, screen-light spill, and surface contact. Desk and station legs visibly meet the floor.
7. **Wall/environment:** the graphical rear wall is replaced by layered painted panels, structure seams, raceway, shelves, acoustic/tool treatment, subtle wear, overhead fixtures, and canonically gated infrastructure detail.
8. **Aurora:** an organized research station combines cyan practical light, an evidence display, desk, chair, notebook, drive, equipment backboard, monitor support, cables, and localized scanner behavior.
9. **Stacks:** an asymmetric hardware-heavy station combines amber light, physical engineering display, housed fan, technical modules, tool, mount, supports, cabling, chair, and denser equipment treatment.
10. **Brio:** a coral-lit campaign/presentation station combines physical playback hardware, communication display, mount, desk, chair, cabling, and distinct wall treatment.
11. **Agent embodiment:** portraits sit on lit and shadowed planes inside station architecture; restrained phase motion, workstation spill, depth scaling, and local contrast preserve identity while avoiding cutout-card travel.
12. **Occlusion:** physical displays, desk equipment, and desk edges cover lower torsos while faces remain readable. Foreground equipment creates further room-scale occlusion.
13. **Contact shadows:** founder hardware, station desks, agents, supports, racks, and physical props use soft, depth-weighted grounding shadows.
14. **Local lighting:** cyan, amber, and coral pools remain spatially bounded to Aurora, Stacks, and Brio. The Founder monitor uses a neutral-cool desk spill.
15. **Practical lighting:** overhead LED fixtures, local strip lights, monitor emission, fan/rack indicators, and purposeful equipment LEDs explain the visible illumination.
16. **Atmosphere:** a low-opacity depth gradient, restrained shafts, contrast falloff, and nine tiny independently phased dust motes separate planes without full-screen blur or fog.
17. **Clutter:** notebook, cup, sticky note, keyboard, mouse, drive, tool, hardware modules, cables, and storage details tell the startup-Garage story without adding HUD.
18. **Progression:** environment detail is derived only from visible owned facilities and infrastructure. Higher canonical ownership adds cleaner raceways, storage, panels, and practical equipment; no progression state was invented.
19. **Parallax:** the accepted camera remains intact; foreground response exceeds middle-ground response, which exceeds rear-wall response. Existing pan bounds and interaction ownership are preserved.
20. **Camera settling:** the existing spring-based focus/free-look transitions and camera easing remain. Reduce Motion selects the static transition policy and disables decorative phase movement.
21. **Performance:** the room uses one wall Canvas, one floor Canvas, transforms, masks, static gradients, and small local phase animations. No new TimelineView, observer, full-screen runtime blur, particle system, dynamic shadow engine, or offscreen compositing stack was added.
22. **Reduce Motion:** static depth, occlusion, materials, shadows, lighting, and canonical environment information remain; parallax response, portrait/particle drift, camera settling, and continuous decorative motion are removed or reduced.
23. **Accessibility:** decorative depth layers are hidden from accessibility and hit testing. The meaningful environment remains one clear adjustable Free Look surface, the computer retains its interactive identity, faces and labels retain contrast, and Increase Contrast strengthens material edges and lowers haze.
24. **Hidden-truth audit:** lighting, shadows, environment detail, and motion consume only visible facility ownership, visible infrastructure ownership, visible workflow state, scene activity, and accessibility settings. No correctness, failure, drift, verification, overclaim, evidence completeness, outcome quality, simulation RNG, persistence, purchase, or network state is read.
25. **Focused XCTest:** 59 tests passed, 0 failed in `/tmp/Build326Focused.xcresult`.
26. **Full XCTest:** the repository baseline was verified as 417/417 before changes. Final suite: **422/422 passed, 0 failed** in `/tmp/Build326FullFinal3.xcresult` using the iOS 26.5 SDK.
27. **Screenshots:** 15 final artifacts are in `VisualProof/Build32_6/`: ten production Garage views, production Command Focus, production LOOK OUT result, returned production Free Look, plus explicitly watermarked DEBUG active and low-runway canonical fixtures.
28. **Runtime video:** `BUILD32_6_UNINTERRUPTED_DEBUG_DEPTH_PROOF.mp4` is a 32.595-second, 1206×2622 uninterrupted recording of the production renderer through the visibly watermarked DEBUG continuity harness: Command Focus → LOOK OUT → Garage reveal → Aurora → Stacks → Brio → independent equipment motion/parallax → Founder Computer → Command Focus. A production-save interactive recording could not be captured through the available automation surface, so this is not represented as production-state video.
29. **Remaining limitations:** production screenshots are complete, but the mandatory uninterrupted video is DEBUG-provenance. Environmental audio was not expanded because this screen has no suitable existing audio infrastructure; future hook points are the visible `FounderGarageStationWorkflow` transitions and Founder Computer focus events. Physical-device GPU profiling and spoken VoiceOver traversal were not available in this environment.
30. **Final commit hash:** emitted by Bitrig after the successful commit because a commit cannot contain its own hash.
31. **Visual-direction score:** **94%**. The physical depth, grounding, workstation integration, material hierarchy, lighting, occlusion, clutter, and parallax merit a material increase from 91%; the score remains below 95% because the required uninterrupted production-save video was not obtainable.

## Acceptance answers

- The Founder Computer reads as physical foreground hardware with desk contact, input equipment, spill, glass, and occlusion.
- Aurora, Stacks, and Brio occupy distinct built workstations rather than floating cards.
- Foreground, middle-ground, and background are immediately identifiable in the centered and panned evidence.
- Desks, supports, equipment, and agents are grounded with contact geometry and shadows.
- Lighting belongs to overhead fixtures, monitors, station strips, and practical equipment indicators.
- Free Look now carries environmental storytelling and independent activity without new HUD.

## Evidence index

- `01` centered production Free Look
- `02` left-biased production Aurora
- `03` production Stacks center
- `04` right-biased production Brio
- `05` production Founder Computer depth
- `06` production floor/contact shadows
- `07` production local lighting
- `08` production agent occlusion
- `09` production environmental detail
- `10` production idle Garage
- `11` watermarked DEBUG active Garage
- `12` watermarked DEBUG canonical low-runway state
- `13` production Command Focus
- `14` production LOOK OUT result
- `15` returned production Free Look
- `BUILD32_6_UNINTERRUPTED_DEBUG_DEPTH_PROOF.mp4` uninterrupted final-renderer continuity proof
