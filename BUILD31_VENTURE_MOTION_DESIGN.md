# Build 31 — Venture Motion and Game Feel

## Intent

Venture motion reports canonical company change without participating in the
simulation. The layout and operating-board hierarchy remain unchanged.

## Event architecture

`VentureMotionSnapshot` captures only read-only presentation values.
`VentureMotionEvents` compares two snapshots and derives semantic events for
Sprint advancement, Evidence, Track Record, objective progress/completion,
Chapter advancement, consequences, infrastructure, thesis, and doctrine.

Snapshots and events are not persisted, Codable, or written back to `GameStore`.
They consume no random values and cannot alter outcome order or save data.

When Venture is off-screen, its snapshot stays at the last presented state.
Canonical changes are compared and choreographed when Venture becomes visible,
so tab re-entry is quiet when nothing changed and meaningful changes are not
spent behind another tab.

## Motion language

- Amber: Sprint resolution, marker advancement, and operating pressure.
- Mint/teal: Evidence, objective progress, completion, and installed capability.
- Cyan: Track Record and permanent company standards.
- Purple: founder doctrine and identity.
- Chapter sequence: close, chapter number, title, description, settle.

Shared `VentureMotion` tokens centralize fast, standard, progress, marker,
milestone, and stagger timing. All choreography is event-driven; there are no
render loops, animated gradients, particles, or per-frame state updates.

## Reduced Motion

Reduce Motion removes marker travel, chapter depth movement, objective sweep,
icon travel/scale, thesis rotation, and doctrine network movement. Crossfades,
numeric updates, progress resolution, semantic color, and brief opacity emphasis
remain so each state change is still communicated.

## Accessibility

Decorative timeline, sweep, motif, and indicator elements are hidden from
accessibility. Sprint, objective, pressure, consequence, infrastructure, thesis,
and doctrine surfaces expose coherent combined labels and values. Accessibility
Extra Large uses vertical reflow and multiline fixed-height text to avoid
temporary truncation. Increased Contrast continues to strengthen surface edges.

## Verification coverage

`VentureScreenPresentationTests` covers forward Sprint derivation, one-shot
objective completion edges, permanent consequence/infrastructure additions, and
Venture-reset suppression. Animation durations are intentionally not asserted.
