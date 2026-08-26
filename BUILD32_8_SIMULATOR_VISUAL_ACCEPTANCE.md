# Build 32.8 Simulator Visual Acceptance

Date: 2026-08-26. SDK/runtime: iOS/iPadOS 26.5.

## Verified

- iPhone 17 Pro portrait: Founder Desk loaded from a persisted career; computer remained dominant; phone, tablet, and floor server were reachable; all Look Out controls and physical-device hit regions were present in the accessibility tree.
- iPad portrait: Founder Desk loaded; all four devices and camera controls were reachable; physical previews remained one status plus compact identifying information.
- Accessibility Extra Large + Increased Contrast on iPad: the desk changed to the accessible-list layout; Look Left, Center, Look Right, Return to Founder Computer, and all four devices remained visible and selectable without precise camera gestures; critical text did not clip in the captured state.
- Production UI automation: computer focus/Look Out, camera controls, phone/tablet/server open-close-return continuity, and no `TabView` all passed.
- Run-state descriptions exposed only visible lifecycle, pressure, published Tech.com, objective, facility, evidence, and achievement information.

## Visual proof

- Repository image: `VisualProof/Build32_8/iPhone17Pro_FounderDesk.png`.
- Build artifacts: `/Users/jermainenelson/Library/Bitrig/Users/22715/Builds/80acfced-dd48-4885-a7e0-e64b166053b5/VisualProof/Build32_8/iPad_FounderDesk.png` and `iPad_AccessibilityXL_HighContrast.png`.
- Automated screenshots: `Build32_8_Full.xcresult`, attachments `01_FOUNDER_DESK_OVERVIEW` through `05_COMPANY_SERVER_FOCUSED`.

## Explicit limitations

- The connector does not expose VoiceOver or Reduce Motion toggles. Those runtime configurations were not manually claimed; truth-safe announcements, focus authority, and reduced-motion policies were verified in code/tests.
- The compact iPhone 17e relaunch became unavailable after the simulator device switch. The iPhone 17 Pro portrait and production UI test were verified; compact layout policy is covered by spatial/layout tests, but a 17e screenshot is not claimed.
- The persisted interactive careers did not expose every approve/rework/cross-check/ship option in one deterministic manual session. Their canonical mutations and distinct visual endpoints are covered by focused and existing integration tests.
- No Instruments/ETTrace capture was available. Performance verification was code-level plus runtime log/build inspection: no per-frame store mutation, no new independent forever animation, and off-focus 18/24 fps timelines pause.
