# Build 8 3D Founder Garage Prototype

`FounderGarage3DPrototype.swift` is intentionally asset-free: room, console,
workstations, robots, and status lights are RealityKit primitive geometry.

To replace the robots with rigged USDZ assets later, load each asset with
`Entity(named:in:)` or `Entity.load(named:)` in `GarageRobot`, add it below the
robot entity, and keep the outer entity and `statusLight` unchanged. The outer
entity owns placement and Reduce Motion behavior, while `statusLight` continues
to visualize `AgentVisualState`.

Do not move game logic into the scene. Pass only derived `AgentVisualState`
values from `GameStore`, as this prototype does today.
