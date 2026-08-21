# Test Report — Build 32.1

Date: 2026-08-21  
SDK: iOS 26.5  
Destination: iPhone 17 Pro Simulator

## Automated results

| Run | Result |
| --- | --- |
| Build 32.1 focused interaction tests | PASS — 14 tests |
| Build 32.1 + Build 32 + PresentationMapping + GameplayMotion | PASS — 64 tests |
| Full XCTest suite | PASS — 307 tests |
| Clean simulator build | PASS — no diagnostics |
| Bitrig build and simulator launch | PASS — no diagnostics |

The first full run exposed an existing async test that waited for eight scheduler yields rather than a state boundary. Under full-suite load it observed `workInProgress` before `awaitingReview`. The test now performs a bounded wait for the canonical presentation phase; the isolated test and subsequent full suite pass.

## Simulator acceptance

Verified on the built-in iPhone 17 Pro simulator:

1. Opened Garage at Company Command.
2. Tapped Stacks; viewport top and page scroll position remained fixed.
3. Confirmed centered Stacks focus, concise visible-safe status, role monitor, surrounding agents, close control, and valid action tray.
4. Tapped Aurora; focus transferred without scrolling.
5. Closed focus; full overview returned without scrolling.
6. Focused Stacks and selected Full Workstation; only that explicit action scrolled to the canonical Stacks card and selected its accessibility target.
7. Scrolled back, closed agent focus, focused Founder, and verified phase, work/review/resolution counts, Attention, blocker, and Full Founder Workstation.
8. Verified Accessibility Extra Large overview and agent focus with no viewport clipping; compact scene labels remain readable and the full cards remain scrollable.
9. Verified Increased Contrast strengthens the viewport boundary and preserves all text/symbol meaning.
10. Verified tab-bar clearance, vertical scrolling, focus transitions, no nested scroll, and no task/presentation loss.

Reduce Motion focus parity is covered by the focused interaction test and the existing presentation policy tests. The built-in simulator API does not expose a Reduce Motion toggle, so no runtime toggle capture is claimed. The accessibility tree and named action implementation were inspected; the simulator API does not expose the complete VoiceOver rotor action list, so a hardware VoiceOver rotor recording is not claimed.

## Hidden-truth and deterministic verification

- Focused stage-four review projections contain no verification, overclaim, drift, or evidence-incomplete condition.
- Focus accessibility values contain no overclaim or actual-quality language before stage five.
- Focus/toggle/navigation state does not mutate seeded stores; same-seed tasks, agents, and stats remain equal.
- Existing duplicate review, resolution, and commit guards pass in the full suite.
- Legacy Founder progression saves still decode unchanged.

## Performance findings

- The shared viewport clock remains singular; no focus-specific clock or repeating task was added.
- Focus state is narrow value state and does not enter `GameStore` observation.
- Stable agent IDs back overview, surrounding-station transfer, and canonical navigation.
- Focus layout uses the existing optimized portrait renditions; no additional decode path exists.
- No Instruments metrics are claimed.

## Files changed

- `App/CompanyCommandViewport.swift`
- `App/FounderComputerScreen.swift`
- `App/LivingCompanyPresentation.swift`
- `App/ContentView.swift`
- `Tests/Build32_1ViewportInteractionTests.swift`
- `Tests/GameplayMotionTests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- Build 32.1 documentation files

## Known limitations

- No production Rive assets exist; native character rendering remains behind the replacement boundary.
- Reduce Motion and the full VoiceOver rotor could not be toggled/recorded through Bitrig's simulator control API; automated parity and accessibility-tree/code verification are reported instead.
- No Instruments trace was captured, so findings are code-first and simulator-observed rather than metric-backed.

Git commit hash: recorded in the final handoff after commit.

Revised visual-direction estimate: **80%**.
