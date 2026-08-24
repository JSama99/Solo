# Build 32.5 Founder Environment Design

`FounderEnvironmentScreen` is the permanent Founder root. Its renderer owns immutable visible-safe room data, its physical monitor embeds the unchanged `FounderComputerScreen`, and its control layer owns only local camera state.

Garage and Loft are structural projections, not palette swaps: Garage uses concrete-door ribs, power panel, conduit, joists, and improvised stations; Loft uses tall window bays, skyline depth, refined supports, and a warmer organized desk.

The five existing upgrades are rendered at their existing locations: Stacks build rail, Aurora verification bridge, Brio broadcast rail, recovery side bay, and Founder foreground desk. The room never exposes gameplay controls or raw result data.

The renderer boundary accepts facility, `CompanyAtmosphere`, `InfrastructureVisual`, `LivingAgentProjection`, camera, and accessibility contrast. It receives no action closures, save writer, RNG, purchase writer, raw task result, or hidden verification value.
