# Build 25.1 — Venture Remediation

Pending Thesis and chapter milestone state is saved explicitly and restored before gameplay. A thesis selection is an invariant: no sprint can commit while one is pending. Existing v14 careers migrate with no pending presentation and retain Sustainable as the established default thesis.

Customer loyalty is now a multiplier on positive trust effects, rather than an unconditional per-sprint grant. Sustainable is +4% and Viral is -2%; over twelve sprints the thesis-only spread is bounded by the trust gains actually earned, never the former 72 fixed points.

Correlated-failure deltas are applied deterministically at the GameStore call boundary without changing SimulationEngine internals. Garage desk geometry is calculated from canvas dimensions and explicitly positioned.
