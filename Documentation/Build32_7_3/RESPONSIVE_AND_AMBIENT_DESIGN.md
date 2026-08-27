# Responsive First-Person and Ambient-Life Design

## Same Garage, different camera

`FounderEnvironmentComposition` resolves from viewport width and selects one of two projection strategies without duplicating state or feature screens.

- **Compact cockpit:** a tighter field of view centered on the taller Founder Computer with Stacks readable in the middle depth. The phone and tablet occupy immediate peripheral desk space; the server and side agents are intentionally explored through Free Look.
- **Regular establishing:** preserves the broad Build 32.7.2 room view, wider agent spacing, all-device separation, and atmospheric negative space.

Both strategies use the same world-anchor, camera, navigation, `GameStore`, and `PresentationCoordinator` owners. Device hit regions are projected from the visible hardware anchors and require at least a 44×44-point visible intersection before accessibility exposure.

## Founder monitor

The prior compact/regular screen bodies were approximately 1.95:1 and 2.29:1. Build 32.7.3 uses 250×158 and 390×244 point maxima (approximately 1.58:1 and 1.60:1). The change is physical, not a stretched bitmap: bezel, glass, support, base, shadow, local spill, Command clipping, and focus transitions share the new geometry.

## Ambient-life boundary

`FounderGarageMotionPresentation` remains a pure projection of visible environment, camera, scene activity, accessibility motion preference, and visible agent activity. `FounderGarageAmbientRhythm` supplies fixed duration, phase, and amplitude profiles. It never reads or advances simulation RNG.

The idle baseline exposes eight low-amplitude perceptible channels: ventilation, server cooling, server/network indicators, screen life, router activity, lighting drift, monitor spill, and unsynchronized agent presence. Aurora, Stacks, and Brio use different bounded phases and cadences. Working state strengthens only the related station hardware using canonical activity.

## Motion hierarchy

- Primary: device focus and canonical gameplay events.
- Secondary: related monitor/station wake response.
- Tertiary: ambient fan, LED, screen, light, and posture rhythms.
- Reaction: visible work state strengthens the owning station only.

Ambient amplitudes remain at or below five percent and never compete with player-facing events.

## Accessibility and Reduce Motion

Manual Look Left, Center, Look Right, Return to Computer, drag-to-look, and VoiceOver camera actions remain canonical. Decorative objects are accessibility-hidden. Under Reduce Motion, parallax, breathing displacement, fan travel, and light-shaft motion stop; safe screen state, device activity, LEDs, contrast, and physical layout remain.

## Audio hooks

The existing presentation hook model now identifies `garageVentilation`, `serverHum`, and `distantGarage` ambient cues. They are documentation-ready triggers only; audio playback remains deferred to the existing audio infrastructure rather than introducing a new framework.

