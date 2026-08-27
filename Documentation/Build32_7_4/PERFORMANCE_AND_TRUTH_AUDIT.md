# Performance, Truth, and RNG Audit

## Rendering delta from 32.7.3

- Animated additions: one primary guarded fan, one larger guarded server fan, one soft fan-shadow transform, seven bounded motes, one cable and one paper-edge transform, one light-shaft transform, and three independently phased local-light opacity changes.
- Static additions: deterministic Canvas wall/floor breakup and powder-coat overlays. These render from fixed integer formulas and generate no per-frame textures.
- No TimelineView, dynamic shadow simulation, full-screen filter, large blur stack, unbounded particle emitter, RealityKit/Rive dependency, or additional simulation clock was added.
- The existing room renderer remains the sole scene root. Scene/activity gates pause continuous work when inactive; Reduce Motion removes travel.
- iPhone and iPad production automation completed without visible frame instability, transition stalls, blank frames, or material pops. This is a visual/runtime comparison, not an Instruments FPS measurement.

## Hidden truth

Mechanical activity reads only public `LivingAgentActivity`, scene activity, and Reduce Motion. Lighting, materials, dust placement, cable motion, LEDs, and screen rhythms receive no success, failure, correctness, verification, drift, overclaim, evidence-quality, or outcome-quality value. Concealed-condition regression compares mechanical, ambient, environmental, lighting, station, and audio-hook projections and passes.

## Deterministic RNG isolation

Every ambient profile is an enum-to-constant mapping. Dust positions use fixed integer arithmetic. Fan, shaft, cable, LED, screen, and shadow phase arrays are presentation constants. There is no call to `SeededRandomNumberGenerator`, `SystemRandomNumberGenerator`, `GameStore`, or simulation mutation. Same-seed canonical simulation parity remains in the 474-test passing suite.

## Audio hooks

Presentation-only hooks are `garageVentilation`, `serverHum`, `equipmentCooling`, and `distantGarage`, alongside visible station cues. They identify future low-volume room-tone/cooling triggers but intentionally do not introduce playback infrastructure. Fan audio can follow the same public mechanical activity mapping; it has no hidden-outcome input.
