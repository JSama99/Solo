# Build 32.7 — Unified Founder Desk

## Canonical audit

Starting revision: `330a4af27373bd39cf8d8d0ceb24ee3cc689af62` (`main`, Build 32.6.2 merge).

The production shell was `GameDashboard` with one root-owned `GameStore`, one dashboard-owned `PresentationCoordinator`, and a four-item `TabView`: Garage → `FounderEnvironmentScreen`, Venture → `VentureScreen`, Tech.com → `TechComScreen`, More → `RecordsScreen`. Sprint divergence and outcome sheets were attached to that tab container. `FounderComputerScreen` already owned the canonical workforce, assignment, Founder review, Evidence drawer, Hindsight archive, Founder workstation, and sprint commit flows.

More contained, in order: Evidence Ledger, Agent Operations, Achievements, Headquarters Progress, Company Story, Solo Pro, Settings, How to Play, and Restart Career. Its links had counts for evidence, agents, achievements, owned facilities, decisions, plans, and settings; Restart Career was destructive. There was no separate More badge or deep-link router.

## Workspace architecture

`FounderDeskWorkspace` replaces only the conventional tab presentation. `GameDashboard` still owns the same `GameStore`, `PresentationCoordinator`, lock/recall banners, divergence sheet, and sprint outcome sheet. One explicit `FounderDeskNavigationState` selects `.overview` or exactly one `FounderDeskDevice` (`computer`, `phone`, `tablet`, `server`). It never mutates simulation state.

All four canonical focused views stay mounted in one stable `ZStack`; opacity, hit testing, and accessibility exposure change with selection. This retains the screens' existing local scroll, expansion, ranking metric, reveal, sheet, and navigation-stack state while moving between devices. No store, coordinator, RNG, action, or mutation path was duplicated.

Evidence and Agent Operations remain canonical Founder Computer modules. Their server cards are operational handoffs: they focus the already-mounted Founder Computer and send a presentation-only scroll request to the canonical Evidence drawer or Company Command viewport. The other seven former More destinations keep their existing views and actions inside the server's persistent `NavigationStack`.

## Spatial and progression treatment

The accepted native 2.5D headquarters renderer remains the room layer. The Computer is central and dominant; the phone rests left near the keyboard; the landscape tablet sits right; the rack server occupies the equipment side. Compact iPhone layouts prioritize touch size and focused readability. Regular-width iPad layouts expose substantially more room and use a wider focused device frame. Accessibility text or compact height changes the overview to a full-width, vertically scrolling equipment list.

The heading and server preview derive the environment identity from `FounderProgressionStore.currentFacility`; device identities do not change across Founder Garage, Founder Loft, Small Office, Office Suite, Company Building, or Unicorn Headquarters.

## Truth boundary

Desk chrome accepts a deliberately narrow `FounderDeskPreviewInput`. It has no actual-quality, correctness, overclaim, drift, hidden-risk, task-result, or evidence-completeness field. Computer signals use public sprint phase, visible assigned/review counts, and canonical commit readiness. Tech.com uses only an already-published headline and public ranking. Venture uses `VentureScreenPresentation`'s visible objective/completion state. Server uses recorded evidence count, achievements, owned facilities, and active facility. Device iconography and accessibility strings are derived by the same policy.

## Accessibility and motion

Every physical object is a named button with a device-specific label and focus hint. Focused devices have a persistent 48-point close bar before their canonical content. The spatial overview has deterministic VoiceOver order: heading, Computer, Server/phone/tablet according to visual layout; accessibility text uses the readable list order Computer, phone, tablet, Server. Increased Contrast strengthens device edges. Reduce Motion selects a short crossfade and removes camera-like scale travel. Normal mode uses a restrained smooth focus/lighting/scale transition. Device alerts use object-specific physical symbols instead of generic red dots.

## Performance boundary

No new renderer, timer, endless background animation, network source, or duplicated screen screenshot was added. Existing headquarters geometry is reused once. Focused screens stay alive for state retention but only the selected device is visible, hittable, and accessibility-exposed. The work adds bounded gradients, transforms, opacity, and native SwiftUI composition.
