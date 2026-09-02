# Founder Garage Identity Reconciliation

## Outcome

The starting Founder Garage now reads as a working residential garage before color, copy, or gameplay context is considered. Its structural scenic language includes a room-scale sectional door, exposed ceiling joists, concrete wear and oil stains, utility shelving, a pegboard tool wall, and stacked tires. The former residential couch is replaced with a metal-framed recovery cot labeled as a recovery bay.

The Founder Loft remains deliberately distinct: it retains skyline windows, reflected lighting, refined framing, and residential seating. Garage-only props are derived from a pure `FounderGarageIdentityProjection`, making the distinction explicit and testable instead of relying on palette.

## Regression contract

- The Garage exposes five independent industrial cues.
- The Garage cannot use residential seating.
- The Loft inherits none of the Garage-only scenic cues.
- Existing camera anchors, environmental interactions, simulation state, persistence, RNG, and facility progression are unchanged.

Focused unit tests in `Build32_4SpatialCausalityTests` enforce this contract.
