# Look Out Restoration Design

## Failure reconciled

Build 32.7 retained `FounderEnvironmentMode`, `FounderEnvironmentCameraState`, `FounderEnvironmentControlLayer`, and the environment gestures, but `FounderDeskWorkspace` rendered a separately computed `.freeLook` camera as a hit-testing-disabled background. Device selection lived in `FounderDeskNavigationState`; the established player-facing camera controls lived in the now-orphaned environment screen. The result looked spatial but could not enter production free-look from the computer.

## Single coordination path

`FounderDeskNavigationState` now owns the workspace selection and the one `FounderEnvironmentCameraState` used by the renderer. It maps:

- overview to `.freeLook`
- computer focus to `.computerFocused`
- LOOK OUT to `.transitioningToFreeLook`, then `.freeLook`
- monitor/return selection to `.transitioningToComputerFocus`, then `.computerFocused`
- phone, tablet, and server to their already-mounted canonical screens

Camera gestures and manual camera commands are accepted only when selection is overview and camera mode is stable `.freeLook`. Secondary focus leaves the camera untouched, so close restores the prior orientation. Reduced Motion retains the same endpoints with a crossfade/direct completion instead of camera travel.

No gameplay mutation moved into presentation. `GameStore`, `PresentationCoordinator`, feature screens, camera state, and selection state each retain one owner.

## Accessibility

LOOK OUT has a descriptive label and hint. Look Left, Center, Look Right, and Return remain native buttons; named camera accessibility actions remain on the workspace. Invisible/out-of-frame physical equipment is removed from accessibility and hit testing. Accessibility text sizes use the readable equipment-list fallback with all four devices and camera/return actions.

