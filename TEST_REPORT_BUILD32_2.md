# Build 32.2 Test Report

Date: 2026-08-21  
Toolchain: Xcode with iOS 26.5 Simulator, iPhone 17 Pro

## Executed results

| Run | Result | XCTest result bundle |
|---|---:|---|
| Build 32.2 focused suite | 15 passed, 0 failed | `DerivedData32_2/Logs/Test/Test-Solo Unicorn Run-2026.08.21_19-42-44--0400.xcresult` |
| Full XCTest suite, including Build 32/32.1, Presentation, Gameplay Motion, determinism, duplicate prevention, and save compatibility | 322 passed, 0 failed, 0 skipped | `DerivedData32_2/Logs/Test/Test-Solo Unicorn Run-2026.08.21_19-43-04--0400.xcresult` |
| Clean Bitrig simulator build and launch | Succeeded, no diagnostics | Built-in simulator build result |

The focused suite covers independent activity/condition/emphasis derivation, precedence, post-review condition distinctions, review-step secrecy and accessibility secrecy, stable task/artifact identity, resting behavior, phase hierarchy, four infrastructure states, installation completion, relevant-active mapping, facility mapping, independent atmosphere thresholds, Reduce Motion endpoint parity, and all required QA fixtures.

The full suite provides existing coverage for reassignment cancellation, skip parity, duplicate review/resolution/commit prevention, seeded deterministic parity, canonical handlers, persistence/save compatibility, gameplay motion, and presentation behavior. No test count was recorded until the run completed.

## Performance code review

- One shared viewport `TimelineView` exists at 18 Hz; no per-agent viewport clock was added.
- The viewport clock pauses under Reduce Motion, offscreen visibility, and background scene phase.
- No animation state enters `GameStore`.
- Agent map, indexed stations, surrounding stations, phase hierarchy, and active counts are precomputed outside the frame-driven closure.
- Stable agent/task IDs drive packets and artifacts.
- Existing optimized portrait assets and replaceable character renderer boundary remain intact.
- Decorative presentation tasks use cancellation/reconciliation in the existing coordinator; no simulation work is scheduled by the viewport clock.
- Blur, shadow, gradient, and glow remain clipped to the command viewport/stations.

No Instruments SwiftUI or Time Profiler trace was available during this pass. Therefore this report makes no metric-backed frame-time, CPU, memory, or energy claim.

## Verification not claimed

No physical-device run, VoiceOver rotor session, Instruments trace, or physical OS Reduce Motion toggle was performed. Reduce Motion, Extra Large Dynamic Type, and Increased Contrast evidence comes from production-component DEBUG policy fixtures; automated tests confirm endpoint and secrecy behavior.
