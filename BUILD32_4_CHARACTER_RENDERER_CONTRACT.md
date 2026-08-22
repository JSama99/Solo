# Build 32.4 Character Renderer Contract

## Shipped renderer

A repository-wide asset audit found no production `.riv` files. Build 32.4 therefore ships the native `LivingAgentCharacterView` renderer behind `LivingAgentRendererKind.nativePortrait`. No Rive dependency, generated placeholder, or production-Rive claim was added. A native renderer remains the required fallback if a future asset cannot load.

## Accepted input

`LivingAgentCharacterInput` accepts only:

- stable agent role
- presentation activity
- visible condition modifiers
- presentation emphasis
- Reduce Motion
- one-shot level-up trigger

It cannot receive `GameStore`, raw task results, hidden actual quality, RNG, persistence, action availability, or purchase state. Activity, conditions, and emphasis remain independent axes. Rest controls activity without deleting visible conditions.

## Native behavior and Reduce Motion

The native renderer provides restrained breathing depth, crop parallax, assignment acknowledgment, work-direction posture, Founder-review attention, local stress/overload treatment, resting settlement, and one-shot level-up response. It does not deform faces or continuously bounce portraits. Reduce Motion removes continuous travel and depth motion while retaining endpoint, symbol, text, condition, and already-determined canonical state.

## Future bespoke assets

Aurora, Stacks, and Brio each require a production-authored `.riv` file with a documented state machine that accepts the six presentation-safe inputs above, deterministic role-specific artboards, one-shot completion acknowledgments, accessible native fallback parity, and licensed production provenance. Runtime integration must remain behind this boundary and must not read simulation state directly.

