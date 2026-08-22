# Test Report — Build 32

Date: 2026-08-21  
SDK: iOS 26.5  
Destination: iPhone 17 Pro Simulator

## Automated results

| Run | Result |
| --- | --- |
| Build 32 focused tests | PASS — 14 tests |
| Existing GameplayMotionTests + PresentationMappingTests | PASS — 36 tests |
| Full XCTest suite | PASS — 295 test methods |
| Clean iPhone Simulator build | PASS — no diagnostics |
| Bitrig build and simulator launch | PASS — no diagnostics |

Focused coverage includes activity derivation, independent condition derivation, resting/overload precedence, fifth-step hidden-truth sanitization, accessibility secrecy, viewport ID mapping, stable infrastructure slots, active-upgrade relevance, Garage/Loft mapping, skip parity, Reduce Motion final-state parity, duplicate review prevention, duplicate resolution prevention, and legacy save decoding. Existing seeded-presentation parity and duplicate-commit tests pass in the full suite.

## Simulator verification

Verified on the canonical built-in iPhone simulator:

- Build and launch
- New title composition with Aurora, Stacks, and Brio
- Founder Event viewport in Founder Garage
- Founder foreground anchor and three identifiable stations
- Viewport Aurora selection scrolling to the canonical Aurora workstation
- Aurora working, Stacks working, and Brio working role surfaces in Motion QA
- Work completion and awaiting-Founder-review treatments in Motion QA
- Five-part Founder Review fixture, verified treatment, and resolution lock in Motion QA
- Default portrait crops and Brio dark-frame integration
- Vertical scrolling, tab-bar clearance, Motion QA sheet presentation, and portrait/landscape rotation
- Accessibility Extra Large and Increased Contrast
- VoiceOver accessibility tree for HUD, viewport container, canonical workstations, Evidence, Hindsight, and tab bar

The built-in simulator control API did not expose a Reduce Motion toggle, and the Bitrig simulator is not registered as a booted `simctl` device. Reduce Motion was therefore verified through the runtime policy paths, static viewport fallback implementation, and automated final-state parity tests rather than claimed as a simulator toggle capture.

## Not captured as canonical simulator saves

The available persisted simulator career opened on a Founder Event. Multiple simultaneous assignments, overclaim/drift, Sprint Ready, Sprint Outcome, resting/overloaded agents, installed-upgrade Garage, and Founder Loft were validated by deterministic projection/unit coverage or existing canonical screens, but were not falsely reported as newly captured canonical simulator states in this run.

## Performance findings

- One viewport clock replaces any need for per-agent clocks.
- Clock pauses for offscreen, background, and Reduce Motion conditions.
- Stable canonical IDs back all viewport `ForEach` and selection mapping.
- Presentation work is cancellation-aware and scoped per agent.
- No animation state is persisted or routed into `GameStore`.
- Runtime portraits use downsampled scale variants; original assets remain preserved.
- Gradients, shadows, and blur are contained to the hero viewport rather than repeated across every card.
- No Instruments metrics are claimed.

## Files changed

- `App/CompanyCommandViewport.swift`
- `App/LivingCompanyPresentation.swift`
- `App/AgentVisualState.swift`
- `App/FounderComputerScreen.swift`
- `App/PresentationCoordinator.swift`
- `App/AppSettingsStore.swift`
- `App/HeadquartersProgressScreen.swift`
- `App/VentureScreen.swift`
- `App/ContentView.swift`
- Three portrait image sets and nine optimized renditions
- Three preserved originals under `ReferenceAssets/OriginalPortraits`
- `Tests/Build32LivingCompanyTests.swift`
- `Tests/PresentationMappingTests.swift`
- `SoloUnicornRun.xcodeproj/project.pbxproj`
- Build 32 documentation files

## Known limitations

- No production Rive assets exist; the native renderer boundary is ready for a later licensed asset pipeline.
- Brio's source portrait has no alpha; black is intentionally treated as monitor material.
- Runtime performance was visually inspected in Simulator and reviewed code-first, but not profiled with Instruments in this pass.
- Built-in simulator automation could not toggle Reduce Motion or manufacture every requested canonical career state without mutating persisted gameplay; those uncaptured states are explicitly listed above.

Git commit hash: recorded in the final Build 32 handoff after this report is committed.

Canonical visual-direction estimate: **85%**.
