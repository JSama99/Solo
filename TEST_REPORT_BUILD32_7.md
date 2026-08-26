# Test Report — Build 32.7 Founder Desk

Date: 2026-08-26  
SDK/runtime: iOS 26.5

## Baseline

The inspected Build 32.6.2 reconciliation reported 432/432 full tests and 69/69 focused environment tests on iPhone 17 Pro / iOS 26.5. The canonical source was also built and manually observed before implementation: it launched the four-tab Garage/Venture/Tech.com/More shell and a full-screen Founder Computer by default.

## Focused XCTest

- Suite: `FounderDeskWorkspaceTests`
- Result: 21/21 passed, 0 failed, 0 skipped
- Device: iPhone 17 Pro, iOS 26.5 (23F77), arm64
- Coverage: default overview; all four selections/returns; exclusive selection; Reduce Motion transition; compact, regular, accessibility-text, and compact-height layout policies; complete nine-route server inventory; canonical Evidence/Agent Operations handoff targets; lifecycle-derived Computer alerts; canonical-published Tech.com signal; visible Venture objective signal; facility-derived Server signal; facility variation; truth-safe preview and accessibility strings.

## Full XCTest

- Result: 454/454 passed, 0 failed, 0 skipped, 0 expected failures
- Device: iPhone 17 Pro, iOS 26.5 (23F77), arm64
- Includes: 453 unit tests plus the production Founder Desk UI continuity test
- Result bundle: `FounderDeskFullFinal/Logs/Test/Test-Solo Unicorn Run-2026.08.26_04-55-17--0400.xcresult`
- Compact UI acceptance: 1/1 passed separately on iPhone 17e / iOS 26.5.

## Simulator acceptance

- iPhone built-in simulator: Desk Overview, all four device frames, close/return, Tech.com scroll retention after phone → desk → tablet → desk → phone, server inventory, server-to-canonical-Evidence handoff, Founder Computer Evidence/Hindsight presence, and no tab bar manually verified.
- iPad built-in simulator: native iPad target launch, regular-width Desk Overview with expanded room context, all four selectable objects in accessibility tree, and readable landscape-oriented Venture iPad focus manually verified.
- Accessibility Extra Large: focused Founder Computer remains scrollable; Desk Overview switches to vertically scrolling full-width equipment cards. The full-width vertical-card refinement was rebuilt and inspected.
- Increased Contrast: enabled and manually inspected; equipment boundaries strengthen without replacing state-driven color semantics.
- Compact portrait: the complete production UI continuity path passed on iPhone 17e / iOS 26.5.
- Reduce Motion: policy is covered by focused tests. The built-in simulator connector does not expose a Reduce Motion setting; manual runtime toggling is not claimed.

## Manual truth and parity audit

The fresh iPad Daily Challenge showed no Tech.com publication signal and the label “No new published stories.” Existing reviewed iPhone save content appeared only as already-published Tech.com history. Server exposed Evidence Ledger, Agent Operations, Achievements, Headquarters Progress, Company Story, Solo Pro, Settings, How to Play, and Restart Career. Evidence handoff focused the canonical expanded Evidence drawer beside Hindsight without creating a second ledger.
