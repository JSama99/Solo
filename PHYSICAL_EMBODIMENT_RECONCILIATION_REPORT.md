# SOLO: UNICORN RUN — Physical Embodiment & Layered Motion Reconciliation

Date: 2026-08-24  
Starting `HEAD`: `915174a57d4a8788b2fe220c175a87237a5601c5`  
Latest implementation baseline found at start: `f0aad01` plus exhaustive-role fix `62b708f`  
Physical-embodiment implementation commit: `71c0e87`  
Ending evidence/report commit: reported in the final delivery because a commit cannot contain its own hash.

## 1. Starting point and retained architecture

The pass continued from the actual current Build 32.5.x tree, not the older `f3ef006` implementation. It retains:

- One continuous `FounderEnvironmentScreen` for Computer Focus and Free Look.
- The same canonical `FounderComputerScreen` mounted inside one physical monitor.
- Existing mode-exclusive gesture and hit-testing ownership.
- The panoramic world projection and stable environment anchors.
- The five existing camera, ambient, activity, condition, and event-emphasis channels.
- Sanitized `LivingAgentProjection` inputs and canonical step-five reveal boundary.
- Deterministic simulation, RNG order, saves, progression, RevenueCat, Evidence, Hindsight, Founder Review, resolution, and sprint commit behavior.

No parallel simulation, agent lifecycle, save state, broad frame clock, or rendering dependency was introduced.

## 2. Exact files changed

- `App/App.swift`
- `App/FounderEnvironmentScreen.swift`
- `App/FounderGarageMotionPresentation.swift`
- `App/FounderGaragePhysicalComponents.swift` (new)
- `App/MotionVerificationScreen.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `Tests/Build32_4SpatialCausalityTests.swift`
- `VisualProof/PhysicalEmbodiment/*`
- `PHYSICAL_EMBODIMENT_RECONCILIATION_REPORT.md`

## 3. Physical-depth techniques

Each station is now physical geometry rather than a single status card: vertical supports, a mounted cross rail, desk thickness, desk legs, primary and secondary displays, a cooling enclosure, cable curves, local cast-shadow approximation, wall light spill, equipment overlap, and floor-plane perspective. Portraits sit behind consoles and displays so foreground hardware occludes them naturally.

The panoramic room retains wall/floor separation, structural uprights, garage-door ribs, shelving, entrance, conduit, practical lights, physical infrastructure, and foreground Founder desk. Left, center, and right remain part of one world coordinate system.

## 4. Founder Computer improvements

The canonical Company Command subtree remains unchanged and singular. Its physical housing now adds:

- A rear casing/extrusion and side thickness.
- Gradient bezel material and stronger edge contrast.
- Local cast shadow and cyan screen spill.
- A restrained moving glass/luminance pass.
- Lower cooling vents.
- Existing event-driven status LED.
- Existing stand, support arm, desk contact, cable route, keyboard, pointing device, review tray, and desk occlusion.

Focused mode keeps the hardware edge perceptible. Free Look reveals that exact same view as a supported object in the Garage.

## 5. Aurora implementation

Aurora's station combines independently driven research rings/source nodes, a document/source-count secondary display, scanning line, desk scanner/equipment response, cooling module, cyan local spill, progress rail, portrait reflection, task artifact, and verification-array placement. Completion changes only to neutral returned-artifact/review-required presentation; it never claims verification or completeness.

## 6. Stacks implementation

Stacks uses terminal-line motion, sequential build modules, a diagnostic/bar secondary display, compile-stage progress rail, cooling fan, status LEDs, amber local spill, Development Rig, and task artifact. These communicate engineering activity—not correctness or build quality.

## 7. Brio implementation

Brio uses audience nodes, graph/path drawing, campaign-card-like secondary tiles, distribution activity, cooling/status hardware, coral local spill, Campaign Studio, and task artifact. It does not expose campaign performance before canonical outcomes.

## 8. Agent embodiment

Existing optimized portraits remain undeformed and replaceable. Active/idle agents gain a very small 0–1.5-point vertical settle, 0.35-point lateral drift, minute scale breathing, local screen-light reflection, shadow depth, and foreground console occlusion. There is no lip movement, facial warp, or cartoon bounce. Continuous portrait motion is disabled by Reduce Motion and while backgrounded.

## 9. Equipment micro-animation

Independent leaf components now include station cooling fans, primary-screen workflows, secondary-display updates, status LEDs, router/network lights, power-strip indicators, the Founder monitor scan pass, and existing infrastructure response. These run only on the relevant local subtree; none invalidates the full Founder Computer at frame rate.

## 10. Local lighting and luminance

Aurora, Stacks, and Brio each receive independent cyan, amber, and coral radial spill derived from their sanitized activity intensity. Portrait reflection, screen brightness, secondary display brightness, cooling color, and wall spill are separate values. The Founder monitor adds a restrained glass pass and desk/bezel spill. Low runway remains a localized warm warning near the Founder desk rather than a full-screen tint.

## 11. Physical task/result artifacts

`FounderGarageArtifactState` maps visible lifecycle only:

- `assignmentReceived` → neutral inbound task packet.
- `working` → neutral assembling artifact with visible progress.
- `workComplete` / `awaitingReview` → returned artifact at the Founder monitor/tray.
- All other states → no packet.

The packet uses a restrained curved route between the physical monitor and the agent station. It conveys workflow direction only, never result quality.

## 12. Free Look environmental value

Free Look now exposes active/idle brightness, role-specific screen behavior, returned artifacts, review indicators, local agent light, infrastructure state, network/equipment activity, and pressure cues without a floating gameplay HUD. The compact existing camera rail remains clear of primary station content.

## 13. Camera continuity

Camera ownership is unchanged. The proof fixture now supports an automated physical sequence using the production renderer and the same embedded Company Command component: focused monitor → spatial pullback → Garage lifecycle observation → focused monitor. This is DEBUG evidence plumbing only and owns no canonical state.

## 14. Reduce Motion

Reduce Motion preserves all state communication while disabling portrait settling, cooling rotation, continuous scan/workflow motion, artifact flourish, and monitor luminance travel. Camera endpoints remain identical and focus changes remain immediate through the existing policy. Backgrounding applies the same pause to physical-presence loops.

## 15. Secrecy audit

Every new visual input was audited. Physical presentation receives activity, sanitized condition set, safe progress, attention, role, event token, atmosphere, and owned infrastructure only. It does not receive raw task results, actual quality, verification, drift, overclaim, evidence completeness, correlated failure, RNG, or action handlers.

A dedicated test proves hidden `.verified`, `.drifting`, `.overclaimed`, and `.evidenceIncomplete` conditions through review step four produce the exact same physical presentation as neutral visible state. Existing step-five admission tests remain green.

## 16. Performance audit

Code-first findings:

- New outer-environment `TimelineView` count: **0**.
- Physical leaf `phaseAnimator` sites: **15** across monitor/station/equipment leaves.
- Outer environment `GeometryReader` count: **3**, all existing bounded layout/controls/renderer readers.
- Local physical/environment blur sites: **2**, both clipped/local light pools.
- No particle system, new engine, WebView, Canvas frame clock, oversized image decode, or full-screen compositing loop was added.
- Stable agent, infrastructure, and world-anchor identities remain in use.
- Scene phase and Reduce Motion stop continuous physical loops.

No Instruments or physical-device profile is claimed; the audit is source- and simulator-behavior-based.

## 17. Automated verification

Destination: **iPhone 17 Pro Simulator, iOS 26.5**. RevenueCat resolved from the repository's intended local Swift package.

- Focused `Build32_5FounderEnvironmentTests`: **40 executed, 40 passed, 0 failed, 0 skipped**.
- Full XCTest suite: **403 executed, 403 passed, 0 failed, 0 skipped**.
- Focused result bundle: `PhysicalEmbodimentFocused.xcresult`.
- Full result bundle: `PhysicalEmbodimentFull.xcresult`.

New coverage protects neutral artifact mapping, idle/working/awaiting-review transitions, station independence, Reduce Motion, background pause, camera-mode independence, and physical-presentation secrecy.

## 18. Screenshot evidence

Fresh catalog under `VisualProof/PhysicalEmbodiment/`:

1. `01_PRODUCTION_COMPUTER_FOCUS.png`
2. `02_PRODUCTION_PHYSICAL_PULLBACK.png`
3. `03_PRODUCTION_FREE_LOOK.png`
4. `04_DEBUG_AURORA_WORKING.png`
5. `05_DEBUG_STACKS_WORKING.png`
6. `06_DEBUG_BRIO_WORKING.png`
7. `07_DEBUG_MULTIPLE_ACTIVITY.png`
8. `08_DEBUG_FOUNDER_REVIEW_PENDING.png`
9. `09_DEBUG_IDLE_GARAGE.png`
10. `10_DEBUG_LOW_RUNWAY.png`
11. `11_DEBUG_ACTIVE_INFRASTRUCTURE.png`
12. `12_DEBUG_REDUCE_MOTION.png`

Production and DEBUG provenance is explicit in filenames and in the visible DEBUG fixture header. All active-role captures were inspected at phone scale.

## 19. Video evidence

`VisualProof/PhysicalEmbodiment/PHYSICAL_EMBODIMENT_RUNTIME_PROOF.mp4`

- Device/runtime: iPhone 17 Pro Simulator, iOS 26.5.
- Duration: **48.740 seconds**.
- Provenance: production renderer/components driven by immutable DEBUG visible-state fixtures.
- Capture method: app opened first at a stable Planning/Computer Focus endpoint; recording began; the built-in Darwin causal-playback notification then triggered the sequence. There is no Home Screen or launch flash.
- Contents: Computer Focus, physical pullback, Free Look, assignment/working/complete/awaiting-review lifecycle, distinct station motion and environmental micro-animation, review progression, resolution/commit-ready presentation, and return to Computer Focus.
- Opening, midpoint, and final frames were extracted with AVFoundation and visually inspected. The final state remains stable.

## 20. Interaction safety

The production app visibly launched and entered Computer Focus and Free Look on the built-in simulator after the changes. The outer drag surface remains conditional on Free Look, computer content remains hit-testable only in Computer Focus, and the bounded monitor target remains Free-Look-only. Existing canonical duplicate review, resolution, and commit guards all pass in the full suite.

The current canonical save did not provide a new assignable lifecycle from idle, so the complete lifecycle video is correctly labeled DEBUG fixture proof rather than canonical gameplay proof.

## 21. Known limitations

- Static portrait assets constrain body/posture animation and prevent bespoke seated character performance.
- Stacks is intentionally more occluded by the foreground Founder monitor in center view; this reinforces first-person depth but hides more of his desk than the side stations.
- The visual system remains native 2.5D rather than a perspective-correct 3D renderer.
- No physical-device, spoken VoiceOver, Instruments, gyroscope, or bespoke-character validation is claimed.

## 22. Evidence-based visual-direction estimate

**90%**.

This estimate is based on the inspected production/DEBUG screenshots and uninterrupted runtime video—not code existence alone. The pass materially improves physical depth, monitor hardware, agent presence, independent equipment activity, local light spill, screen behavior, task flow, camera continuity, and motion hierarchy. It is held at 90 rather than higher because character assets remain static portraits, center-station occlusion is dense, and there is no physical-device or advanced environment-renderer validation.
