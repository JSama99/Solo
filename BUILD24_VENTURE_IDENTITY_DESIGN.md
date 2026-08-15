# Build 24 — Venture Identity

Build 24 surfaces the existing `VentureEra` system; it introduces no second era system, no per-venture names, and no pacing changes. `VentureEra.era(for:)`, its ten-venture cadence, and its authored forces remain the sole era authority.

Each venture receives one deterministic, era-eligible objective. The next objective is deliberately revealed at the checkpoint so retirement is an informed choice. Objectives evaluate only accumulated GameStore state and grant their authored reward once, immediately before a checkpoint is captured.

Checkpoint grading is a pure `VentureGrader` calculation over a value snapshot. It reports revenue, verification, evidence, sustainability, and trust dimensions, plus a company identity derived from persistent flags. The forward preview names carried obligations, their source decisions, flags, precedents, and relationships.
