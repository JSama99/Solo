# Build 32.7.5 Performance and Truth Audit

- Presentation inputs are limited to public device state, visible lifecycle projections, safe-pending flags, scene/visibility state, and visible event tokens.
- No new canonical data, navigation ownership, save data, RevenueCat path, or simulation dependency was introduced.
- No new code consumes simulation RNG. Rhythms and traces are fixed, repeatable presentation profiles.
- Particle count is unchanged. No physics system, duplicate screen tree, or per-device timeline was introduced.
- Offscreen device life is throttled; inactive scenes and Reduce Motion stop decorative travel and rotation while retaining status.
- Task and result artifacts encode direction/lifecycle only, never correctness, quality, verification, drift, or outcome.
