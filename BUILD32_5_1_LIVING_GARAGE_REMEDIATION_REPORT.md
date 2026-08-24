# Build 32.5.1 — Living Founder Garage Remediation Report

Date: 2026-08-24  
Canonical starting commit: `f3ef006f2ec1fde01fdb7a52c993fc01bdee7205`  
Implementation commits: `ec49de4`, `62b708f`, `f0aad01`  
Final evidence/report commit: reported in the delivery message because a commit cannot contain its own hash.

## Result

The five-layer presentation architecture, production integration, sanitized role-specific workflows, localized lighting, accessibility motion policy, deterministic tests, and simulator screenshot catalog are implemented. Automated acceptance passes completely. Screenshot acceptance passes for the continuous physical-monitor relationship and independent Garage states.

Overall acceptance remains **incomplete** because this Bitrig built-in simulator session exposes screenshot and interaction controls but no uninterrupted video-recording/export API. No MP4 was fabricated from still images. Under the prompt's explicit completion gate, visual acceptance is therefore marked **FAILED (video evidence unavailable)** even though the inspected still catalog and tests pass.

## Exact production and verification files changed

- `App/FounderGarageMotionPresentation.swift`
- `App/FounderEnvironmentScreen.swift`
- `App/MotionVerificationScreen.swift` (DEBUG verification catalog only)
- `Tests/Build32_4SpatialCausalityTests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- `VisualProof/Build32_5_1_LivingGarage/*.png`
- This report

`appStoreConnect/lock.json` appears in an earlier shared commit but is unrelated user/App Store work and is not part of the Living Garage implementation.

## Architecture introduced and reused

`FounderGarageMotionPresentation` is a pure presentation projection built only from sanitized `FounderEnvironmentProjection` values, environment camera mode, scene activity, Reduce Motion, and already-visible event identity. It has no `GameStore`, save, purchase, scoring, or RNG dependency.

The existing architecture remains authoritative:

- `FounderEnvironmentScreen` remains the single continuous root.
- The same stable `FounderComputerScreen` subtree remains mounted inside `FounderPhysicalMonitorView` in both camera modes.
- Existing Computer Focus/Free Look hit-testing and relative camera-drag policies remain unchanged.
- Existing `PresentationCoordinator` supplies visible event identity only; the Garage never inspects raw task results.
- Company Command's existing viewport clock remains isolated inside the computer. No outer full-screen clock was added.

## Five motion layers

1. **Camera motion** — Existing camera state drives one physical monitor from close Computer Focus to pulled-back Free Look. Geometry, bezel, desk, and Garage reveal spatially; there is no screen route or crossfade replacement.
2. **Ambient motion** — Low-amplitude station LEDs, monitor luminance, and local equipment fans use lightweight state-driven animation. They stop when backgrounded and under Reduce Motion.
3. **Agent activity motion** — Each sanitized agent lifecycle independently selects a role workflow and activity intensity. Aurora uses scan/evidence nodes, Stacks uses staged build modules, and Brio uses distribution paths/audience signals.
4. **Agent condition presentation** — Activity and condition stay independent. Only visible-safe focused, stressed, and overloaded conditions affect pre-review presentation. Post-review conditions are admitted only at canonical reveal step five.
5. **Event emphasis** — Finite, prioritized cues cover review-required, result-returned, sprint-commit, visible runway pressure, milestone, infrastructure, and HQ progression. Review-required outranks simultaneous lower-priority cues; emphasis returns to ambient state.

## Computer Focus / Free Look continuity

The canonical computer is never conditionally replaced. Focus changes only frame, scale, offset, hit testing, accessibility exposure, monitor glow, and physical environment emphasis. Computer input is enabled only in Computer Focus; the Free Look drag surface exists only in Free Look; the bounded monitor return target exists only in Free Look. This preserves computer view identity and canonical presentation state.

## Environmental lighting

Lighting is derived from visible energy, runway, trust, momentum, sanitized station activity, and visible event emphasis. It controls monitor glow, local role illumination, practical-light intensity, equipment intensity, and restrained warning intensity. Low runway produces a localized desk clock/indicator and warm pressure treatment rather than a full-room red wash.

## Agent-specific motion

- **Aurora:** cyan scanning line, source/evidence nodes, relationship formation, verification-array response.
- **Stacks:** amber sequential build modules, compile pulse, engineering-rig response.
- **Brio:** coral audience nodes, distribution paths, campaign-studio response.

The stations animate independently from their own sanitized projections. Static portraits remain undeformed character anchors behind station consoles.

## Hidden-truth safeguards

The projection accepts no hidden result payload. Through review steps one to four, tests confirm it cannot surface actual quality, verification, drift, overclaim, incomplete evidence, or correlated failure via workflow, light, event cue, or accessibility description. Step five admits only the existing canonical visible condition. Presentation determinism is tested using identical visible inputs and never consumes simulation RNG.

## Reduce Motion and lifecycle behavior

Reduce Motion preserves camera endpoints and information while disabling continuous ambient/station loops and making focus/camera changes immediate through the existing environment policy. Background scene state also pauses continuous Garage decoration. Increased Contrast and the existing environment accessibility tree remain intact.

## Interaction-safety verification

Code inspection and focused tests verify mode-exclusive computer hit testing, Free Look gestures, monitor-return policy, relative drag accumulation, stable camera bounds, and stable computer identity. Existing canonical duplicate review, resolution, and commit protections pass in the full suite. The production simulator visibly launched on **iPhone 17 Pro, iOS 26.5** and showed the canonical computer embedded in the Garage plus Free Look.

The available canonical save was in Planning and did not contain a review-ready task, so a live five-step canonical Founder Review was not claimed. The DEBUG catalog supplements visible review-required presentation only; it is not described as canonical action proof.

## Simulator evidence

Inspected files under `VisualProof/Build32_5_1_LivingGarage/`:

1. `01_PRODUCTION_COMPUTER_FOCUS.png` — production canonical computer and physical frame
2. `02_PRODUCTION_PULLED_BACK_MONITOR.png` — production pulled-back physical monitor
3. `03_PRODUCTION_FREE_LOOK_GARAGE.png` — production Garage surrounding the same monitor
4. `04_DEBUG_AURORA_ACTIVE.png` — production component, immutable DEBUG visible-state fixture
5. `05_DEBUG_STACKS_ACTIVE.png` — production component, immutable DEBUG visible-state fixture
6. `06_DEBUG_BRIO_ACTIVE.png` — production component, immutable DEBUG visible-state fixture
7. `07_DEBUG_FOUNDER_REVIEW_REQUIRED.png` — sanitized DEBUG review-required state
8. `08_DEBUG_IDLE_GARAGE.png` — quiet Garage state
9. `09_DEBUG_LOW_RUNWAY_RESPONSE.png` — localized visible runway response

The production and DEBUG provenance is encoded in filenames and visible in the DEBUG catalog header.

## Video evidence

No simulator MP4 is included. The built-in Bitrig simulator available in this session did not expose video recording/export, and its device was not addressable through the command-line simulator recorder. A slideshow assembled from screenshots would not prove spatial continuity or interaction, so none was created.

To close this one remaining gate, run the existing production route in an Xcode Simulator that is visible to `simctl`, then use `xcrun simctl io booted recordVideo` while performing Computer Focus → Look Around → observe stations → tap the physical monitor → interact inside Company Command. The app implementation itself requires no alternate route or mock.

## Automated verification

Executed on iPhone 17 Pro Simulator, iOS 26.5, using the repository's local RevenueCat Swift package:

- Focused `Build32_5FounderEnvironmentTests`: **33 executed, 33 passed, 0 failed, 0 skipped**.
- Full XCTest suite: **396 executed, 396 passed, 0 failed, 0 skipped**.
- Focused result: `LivingGarageFinalFocused2.xcresult`.
- Full result: `LivingGarageFinalFull.xcresult`.

The focused suite protects the five layers, independent station activity, role-specific workflows, finite event priority, localized lighting, foreground/background pause, Reduce Motion endpoints, camera isolation, determinism, and secrecy through step four/canonical admission at step five.

## Regressions and limitations

- No canonical simulation, persistence, progression, purchase, RevenueCat, task, scoring, Evidence, Hindsight, review, resolution, or commit code was changed.
- Stacks' central station is intentionally visually occluded by the foreground Founder monitor more than the side stations; this reinforces the first-person desk relationship but reduces full station visibility in the compact DEBUG catalog.
- Static portrait assets limit character embodiment and animation range.
- No physical-device, spoken VoiceOver, Instruments, or video-recording session is claimed.

## Evidence-based visual-direction estimate

**83%**. This is based on the inspected production and DEBUG simulator screenshots: the Garage clearly surrounds one physical computer, role stations and lighting communicate independently, and the monitor/desk relationship is continuous. It is not rated higher because the mandatory motion video is absent, Stacks is compositionally dense behind the monitor, and character assets remain static.
