# SOLO: UNICORN RUN — Codex Project Instructions

SOLO: UNICORN RUN is a native SwiftUI iOS simulation game.

## Canonical project

- Repository: `/Users/jermainenelson/Documents/Solo`
- Xcode project: `SoloUnicornRun.xcodeproj`
- Scheme: `Solo Unicorn Run`
- Primary app source: `App/`
- Unit tests: `Tests/`
- UI tests: `UITests/`

## Required workflow

For every substantial task:

1. PHASE 1 — Inspect
2. PHASE 2 — Propose
3. PHASE 3 — Implement
4. PHASE 4 — Test
5. PHASE 5 — Report

Never skip directly from a prompt to broad repository modification. Always inspect
the relevant implementation and `git status --short --branch` before editing.

## Architecture boundaries

- Preserve existing architecture before creating new architecture.
- Prefer small, bounded changes.
- `GameStore` is the mutable simulation authority. Reuse the existing pure engines
  and models rather than duplicating simulation rules.
- Keep game state separate from presentation state. `PresentationCoordinator`,
  camera state, selections, animation, and choreography must not become simulation
  authorities.
- Preserve deterministic simulation behavior, RNG ordering, cached outcomes, and
  stable replay behavior.
- Preserve hidden-truth and secrecy boundaries. Do not expose actual agent quality,
  verification, drift, overclaim, or other hidden simulation truth before canonical
  Founder review. Founder-facing UI must use visible projections and SOLO game fiction.
- Preserve save compatibility and the existing migration chain unless explicitly
  instructed otherwise.
- Preserve accessibility, Dynamic Type, VoiceOver, Reduce Motion endpoints, and
  minimum interaction targets.

## Canonical systems

Preserve and reuse the existing implementations for:

- Founder Garage and Free Look
- Founder Computer and Founder Desk Workspace
- Company Command / AI Operations Floor
- Aurora, Stacks, and Brio
- agent activity, condition, and presentation emphasis
- Evidence, Founder review, Work Sessions, and Hindsight
- Founder Attention, Founder Energy, Runway, Revenue, Momentum, Company Trust,
  Coverage, infrastructure, and progression
- Tech.com, Venture, and Signal TV
- RevenueCat and entitlement gating
- career saves, migrations, progression, achievements, and settings persistence
- audio, sensory feedback, animation, and accessibility

Important current ownership:

- `App/GameStore.swift`: simulation mutations and career persistence
- `App/SimulationEngine.swift`: pure simulation resolution
- `App/FounderDeskWorkspace.swift`: production Garage/device navigation
- `App/FounderComputerScreen.swift`: production Founder Computer
- `App/AIOperationsFloor.swift`: production Company Command viewport
- `App/LivingCompanyPresentation.swift`: visible agent activity/condition/emphasis
- `App/WorkSessionEngine.swift`: shared Aurora/Stacks/Brio Work Session rules
- `App/Hindsight.swift`: precedent and recall rules
- `App/SignalTVModels.swift`: public media event programming
- `App/SubscriptionStore.swift`: RevenueCat boundary
- `App/AppSettingsStore.swift`: app audio and settings authority

`CompanyCommandViewport.swift` and `CompanyCommandScene.swift` are legacy/debug
surfaces, not the production Company Command route. Do not expand them as competing
architecture without an explicit migration task.

`CompanyFinance` is the canonical financial ledger. `FounderStats.capital` is a
legacy compatibility mirror. Coverage mutations must flow through
`GameStore.applyPublicMediaEvent` so event deduplication remains intact.

## Xcode project safety

Do not modify SoloUnicornRun.xcodeproj/project.pbxproj or the shared
Solo Unicorn Run scheme unless the requested task genuinely requires
target membership, build settings, packages, or scheme changes.

If either file changes incidentally, restore it before completing the task.

The checked-in project uses explicit file membership and a local RevenueCat package.
`Project.json` does not currently describe that project structure exactly. Never run
large automatic project-file reconciliation or regenerate the Xcode project without
an explicit reconciliation task.

If a new Swift file is genuinely required, explain why before changing target
membership and make only precise project-file edits.

## Git safety

- Do not commit unless explicitly instructed.
- Do not push unless explicitly instructed.
- Do not reset, clean, rebase, force-push, or discard user changes.
- Preserve unrelated user changes in a dirty worktree.
- After editing, report every modified or newly created file.

## Verification

For implementation work:

1. Run focused tests related to the change.
2. Run `xcodebuild` for the `Solo Unicorn Run` scheme.
3. Run the broader test suite when practical.
4. Report failures exactly, including whether they are test, build, simulator, or
   environment failures.
5. Do not claim visual, audio, haptic, or animation correctness from tests alone.

For visual, layout, or presentation work, verify both iPhone 17 Pro Max and
iPad Air 11-inch (M4) simulators when those destinations are available.

Simulator or device verification remains a human acceptance step.

For inspection-only tasks, do not build or run commands that generate repository or
Xcode user-state files unless the user explicitly requests verification.

## Architecture handoff inspection

When asked for an architecture handoff, inspect without editing and report:

- canonical architecture and source-of-truth files
- dependencies between simulation, presentation, persistence, and entitlements
- duplicate or legacy architecture
- project-file and package risks
- fragile systems, especially determinism, hidden truth, saves, Attention, finance,
  Coverage, and presentation choreography
- XCTest and XCUITest target membership and coverage
- current source organization, `AGENTS.md`, git status, project structure, shared
  scheme, recent history, and recent test evidence
- recommended rules for future SOLO development passes

Clearly distinguish current static inspection from historical test reports, and do
not claim a current test pass unless the current revision was actually tested.
