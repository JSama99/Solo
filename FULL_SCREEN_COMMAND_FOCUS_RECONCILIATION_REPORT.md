# Full-Screen Company Command Focus — Reconciliation Report

Date: 2026-08-24  
Starting commit: `46f5ee5fb163eb6cadda6ae2dabfafc4ea2be88f`  
Branch: `build32-5-1-living-garage-motion`  
Simulator: iPhone 17 Pro, iOS 26.5 (`BB7F5B18-B85E-4DA2-BBE2-999B432E9916`)

## Result

The Founder Computer remains one stable SwiftUI subtree in one continuous
`FounderEnvironmentScreen`. In stable Command Focus, its screen now covers the
usable viewport rather than remaining inside a large visible bezel. LOOK OUT
reverses that spatial presentation to Free Look. No sheet, cover, navigation
push, tab route, second `GameStore`, second `PresentationCoordinator`, or second
Company Command surface was introduced.

Runtime production inspection confirmed full-width readable Company Command,
vertical scrolling, LOOK OUT, Free Look camera controls, monitor return, retained
scroll position, and successful interaction with the app's bottom navigation
after returning. The currently persisted canonical career showed two
"Awaiting review" agents but did not expose an enabled review action, so a live
five-step canonical review could not honestly be claimed in this run. The DEBUG
immutable proof supplements that unavailable state with review-step visuals.

## Files changed

- `App/FounderEnvironmentScreen.swift`
- `App/FounderGarageMotionPresentation.swift`
- `App/FounderComputerScreen.swift`
- `App/MotionVerificationScreen.swift`
- `App/App.swift`
- `Tests/Build32_4SpatialCausalityTests.swift`
- `VisualProof/FullScreenCommandFocus/*`
- `FULL_SCREEN_COMMAND_FOCUS_RECONCILIATION_REPORT.md`

## Presentation and camera states

`FounderEnvironmentMode` now explicitly models:

1. `freeLook`
2. `transitioningToComputerFocus`
3. `computerFocused`
4. `transitioningToFreeLook`

The two transition states lock both interaction owners and reject competing
activation. Completion is tied to the 520 ms presentation transition, or to the
immediate endpoint under Reduce Motion. Camera state remains view-local,
nonpersistent, presentation-only state.

`FounderCommandFocusLayout` is a pure geometry policy. Stable focus expands the
physical monitor slightly beyond the viewport edge, removes meaningful bezel
inset, and produces 100% computed usable-area coverage. Free Look returns to the
panoramic world projection and physical monitor geometry.

## Shared Company Command identity and state

The same `FounderComputerScreen` is present across all four phases. Focus changes
only its frame, scale, clip, offset, hit testing, and accessibility exposure.
Its `ScrollPosition` is owned by the stable screen instance. Production proof
shows the physical monitor retaining the same scrolled Aurora/Stacks content
after LOOK OUT, and the expanded computer returning at the same scroll position.
Agent lifecycle and sanitized presentation inputs remain derived from canonical
state and are not replayed or reset by camera changes.

## Interaction ownership

- Command Focus: only Founder Computer hit testing is enabled; no room drag
  recognizer or monitor parent tap recognizer exists.
- Free Look: the Founder Computer is noninteractive and accessibility-hidden;
  the bounded room drag layer and bounded monitor-return hotspot are enabled.
- Transitions: a temporary interaction-lock surface prevents both ownership
  domains from firing until the geometry reaches its stable endpoint.
- LOOK OUT: a 44-point, explicitly labeled top control exists only in stable
  Command Focus and carries the hint "Pulls away from Company Command to observe
  the Founder Garage."

## Mobile layout and Stacks refinement

The environment navigation bar is removed so the canonical computer can use the
full game viewport between system and tab safe areas. The Company Command is not
image-scaled in final focus: its stable mobile layout receives the real focused
viewport. Free Look uses an aspect-fill transform of that same stable layout so
state and scroll ownership survive the physical-monitor presentation.

Stacks' world anchor moved toward the central operating area while retaining
foreground monitor occlusion. The center production view now identifies Stacks,
the engineering desk, fan, activity rail, and Development Rig without turning
the room into a symmetric showroom.

## Motion, accessibility, secrecy, and performance

- Existing camera, ambient, agent activity, condition, and finite event-emphasis
  layers remain intact.
- Existing station animation continues from canonical current state across focus
  changes; camera changes do not start a new lifecycle.
- Reduce Motion retains identical focus/free endpoints and replaces the 520 ms
  spatial travel with immediate completion.
- Accessibility focus transfers only at stable completion. Free Look hides the
  computer tree and exposes named left, center, right, up, down, and return
  actions. LOOK OUT is explicit and gesture-independent.
- The renderer continues to consume sanitized `LivingAgentProjection` data.
  Tests confirm camera phase cannot admit hidden quality, verification, drift,
  overclaim, or evidence truth.
- No new continuous clock, `TimelineView`, simulation observer, renderer
  dependency, or duplicate Founder Computer hierarchy was added. Existing
  localized `phaseAnimator` components remain state- and visibility-driven.
  The transition uses geometry, opacity, clipping, and a single 520 ms spring.

## Automated verification

Focused command/environment suite:

- Command: `xcodebuild test ... -only-testing:'Solo Unicorn Run Tests/Build32_5FounderEnvironmentTests'`
- Result: **54 executed, 54 passed, 0 failed, 0 skipped**
- Result bundle: `/tmp/CommandFocusFocusedFinal.xcresult`

Complete suite:

- Command: `xcodebuild test -project SoloUnicornRun.xcodeproj -scheme 'Solo Unicorn Run' -destination 'platform=iOS Simulator,id=BB7F5B18-B85E-4DA2-BBE2-999B432E9916'`
- Result: **417 executed, 417 passed, 0 failed, 0 skipped**
- Result bundle: `/tmp/CommandFocusFullFinal.xcresult`

Focused coverage includes both transition directions, duplicate-transition
rejection, stable-mode interaction policies, LOOK OUT availability, 100% focus
coverage, physical monitor size, stable content geometry, Reduce Motion endpoint
parity, lifecycle continuity, Stacks observability, and hidden-truth invariance.
The complete suite retains deterministic RNG, duplicate review/resolution/commit,
legacy save, audio compatibility, and RevenueCat coverage.

## Production simulator acceptance

Verified through the title/Continue Career route in the built-in iPhone 17 Pro
simulator:

- visible production launch and canonical career load;
- edge-to-edge Command Focus with no meaningful Garage or bezel competition;
- vertical computer scroll;
- LOOK OUT exit to the same physical monitor;
- left, center, and right Free Look endpoints;
- Aurora, Stacks, and Brio discoverability;
- computer controls disabled while looking around;
- bounded monitor/Computer return;
- retained distant-monitor and expanded-computer scroll state;
- successful bottom-navigation interaction after returning;
- accessibility tree exposes LOOK OUT in focus and named camera/return controls
  in Free Look while hiding the computer tree.

The production career did not present an enabled Founder Review button despite
visible pending-review state. No claim of live canonical five-step review
activation is made for this acceptance run.

## Visual proof inventory

`VisualProof/FullScreenCommandFocus/` contains:

1. `01_PRODUCTION_FREE_LOOK_COMPLETE_COMPUTER.png`
2. `02_PRODUCTION_FREE_LOOK_AURORA.png`
3. `03_PRODUCTION_FREE_LOOK_STACKS.png`
4. `04_PRODUCTION_FREE_LOOK_BRIO.png`
5. `05_DEBUG_TRANSITION_BEGINNING.png`
6. `06_DEBUG_BEZEL_NEAR_VIEWPORT_EDGE.png`
7. `07_PRODUCTION_FINAL_COMMAND_FOCUS.png`
8. `08_PRODUCTION_COMMAND_FOCUS_SCROLLED.png`
9. `09_DEBUG_FOUNDER_REVIEW_FULL_SCREEN.png`
10. `10_PRODUCTION_LOOK_OUT_CONTROL.png`
11. `11_DEBUG_EXIT_TRANSITION_BEZEL_RETURNING.png`
12. `12_PRODUCTION_FINAL_FREE_LOOK.png`
13. `13_PRODUCTION_MONITOR_PRESERVES_COMMAND_STATE.png`
14. `14_PRODUCTION_RETURNED_TO_COMPUTER_STATE.png`

Every image was inspected at phone scale. Production and DEBUG provenance is in
the filename; DEBUG frames also carry an on-screen provenance badge.

## Video proof

`FULL_SCREEN_COMMAND_FOCUS_UNINTERRUPTED_DEBUG.mp4` is a fresh, uninterrupted,
17.000-second, 588×1280 H.264 simulator recording. It begins on a stable Planning
endpoint with no Home Screen or launch flash. Its built-in causal playback shows
Free Look, independently active stations, entry toward the same physical monitor,
Command Focus, review presentation, exit with Garage return, active workstation
observation, and a second entry. Opening (0.2 s), midpoint (8.0 s), exit region
(12.0 s), and final frame (16.0 s) were inspected after export.

This video is correctly labeled **DEBUG immutable fixture proof**. It proves
runtime motion and spatial continuity, but it is not represented as a production
touch recording and does not by itself prove canonical scrolling or action
activation. Those were manually verified in the production simulator and shown
in production stills. Because the required uninterrupted production interaction
capture could not be exported by the available built-in simulator tooling,
strict end-to-end visual acceptance remains **partially verified**, not complete.

## Limitations and direction estimate

- No physical-device, spoken VoiceOver rotor, Instruments, or landscape session
  was performed.
- Reduce Motion endpoint behavior is automated-test verified; the available
  built-in simulator settings do not expose a Reduce Motion toggle.
- Production Founder Review activation and uninterrupted production touch video
  remain unverified for the reasons above.

Evidence-based visual-direction estimate: **91%**. The production full-screen
focus, mobile readability, spatial return, Stacks visibility, and preserved
Garage embodiment support a material gain over the 88% baseline. The score stays
below the 92–94% target because the strict production interaction video and live
canonical Founder Review proof are absent.

The exact ending commit is reported after the repository commit is created.
