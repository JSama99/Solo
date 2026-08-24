# Build 32.5 Changelog

## Founder Environment

- Replaced the root-only navigation wrapper with one persistent `FounderEnvironmentScreen`.
- Embedded the existing `FounderComputerScreen` inside a physical monitor, with the Garage or Loft rendered outside it.
- Added presentation-only Computer Focus and Free Look camera modes. No game, save, purchase, or RNG state participates.
- Added a native 2.5D renderer boundary (`FounderEnvironmentRendererKind.native2D`) for a future RealityKit replacement.

## Input and safety

- Computer Focus leaves the canonical computer fully interactive and leaves all decorative layers noninteractive.
- Free Look disables embedded-computer hit testing and accessibility, enables the room camera, and allows a monitor tap to return.
- Camera values are bounded to horizontal `-1...1` and vertical `-0.30...0.30`.
- Environment accessiblity uses only visible work activity plus focused/stressed/overloaded conditions.

## Visual direction

The native 2.5D pass establishes the physical Garage / Loft, desk, monitor, stations, equipment, and visible-safe operational atmosphere around Company Command. Honest direction estimate: **84%** toward the target; bespoke character assets, physical-device verification, and a more advanced renderer remain required to exceed 86%.
