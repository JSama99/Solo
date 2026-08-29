# Signal TV reconciliation

Starting `HEAD`: `f641e75d2ff99ff019d075dda64eea701f01eca8` (Build 32.7.5). Final commit is recorded in the handoff commit.

Signal TV is one physical, wall-mounted 16:9 chassis anchored at `.signalTV` in the rear/upper wall layer. The same world anchor is projected through the compact iPhone cockpit and regular iPad establishing composition; the iPhone may crop it and Free Look exposes it naturally. `SignalTVView` draws the chassis, bezel, glass, mount, thickness, shadow, local cool spill, ident, lower third, ticker, qualitative chart, portraits/waveform, and five canonical programs: Market Pulse, Tech.com Live, Rival Watch, Breaking, and Founder Spotlight.

The TV is passive by default, with a selectable Free Look hotspot. Tapping the physical chassis opens `SignalTVViewer`, a compact current-story / Market Pulse / Rival Watch / Recent Headlines reader. Tech.com remains the active publication surface. Both surfaces consume the same public event identity and never apply a second Coverage delta.

Coverage is a persisted `FounderStats` value clamped to `-100...100`, defaulting to zero for old saves. `GameStore.applyPublicMediaEvent` is the only mutating authority; each public event has a stable ID and an idempotence ledger. Deltas are centrally bounded to `-15...15`, preserve Trust independently, and are reflected in the Founder workstation HUD with restrained signed motion, haptic, and positive/negative audio cues. Existing opportunity pricing can read Coverage; a larger scrutiny subsystem and optional drift-to-zero decay are intentionally deferred because neither has a safe canonical target in this architecture.

Public events are the only Signal TV input. Hidden task quality, correctness, verification, evidence completeness, overclaim, agent drift, and unrevealed outcomes have no representation in `PublicMediaEvent`. Founder Review cannot produce a public result story; only a public announcement/headline can. Decorative Timeline/ticker/chart timing is derived from elapsed time and does not touch simulation RNG. Save version 18 migrates version 17 and defaults absent media fields safely.

Audio uses the existing synthesized feedback path and adds `SignalTVAudioFocus` hook values: command focus `0.12`, Free Look `0.32`, major story `0.48`. There is no voice-acting or streaming pipeline. Reduce Motion freezes the ticker into readable cycling text and completes chart/logo transitions with minimal motion. The TV is one combined accessibility element; ticker fragments are hidden, while the hotspot has a single actionable label/value.

Evidence captured in this pass:

- `Evidence/iPhone/iphone-centered-signal-tv.png`
- `Evidence/iPhone/iphone-command-focus-coverage.png`
- Production iPad Free Look and selectable viewer verified in the Bitrig simulator (the viewer accessibility tree exposes `signal-tv-hotspot`, `signal-tv-section-picker`, Coverage, and Close).

Focused SignalTVTests passed. The complete XCTest suite passed with exit code 0 after the legacy purge-key assertion was updated for save version 18. A simulator service interruption produced a non-test xcodebuild failure during an earlier attempt; the escalated rerun completed successfully.

Remaining limitation: the current repository has no video-capture artifact or spoken broadcast bed; the implementation provides the production visual runtime and audio focus/cue hooks without introducing a heavyweight media subsystem.
