# FOUNDER DESK DEVICE CORRECTION — iPAD + iPHONE

Date: September 20, 2026  
Status: Engineering complete; human acceptance pending

## 1. Executive result

The production RealityKit V8 Founder Desk now presents three distinct tools: the unchanged Founder Computer, a thin landscape iPad, and a separate portrait iPhone. The authored `FounderLaptop` is suppressed only at runtime when imported V8 is active. No USDZ bytes were changed and no duplicate product screen or simulation state was introduced.

## 2. Pre-change device audit

V8 contains `FounderLaptop`, `Laptop_Lid`, and `Laptop_Display`. Its root is centered at approximately `[0.60, 0.773, -1.15]`, with a `0.39 × 0.032 × 0.27 m` base and an upright lid. That is the laptop-looking side device seen in production.

The existing stable procedural `iPhone` and `iPad` entities already belonged to `FounderGarageEntityRegistry`, but `setProceduralEnvironmentVisible(false)` disabled both whenever an imported Garage was installed. Neither device had an input target, collision shape, accessibility action, or production callback. Canonical `.phone` and `.tablet` destinations already existed in `FounderDeskNavigationState` and `FounderDeskWorkspace`.

## 3. iPad correction

The existing stable iPad registry entity is retained. In V8 it replaces the misleading laptop at runtime and uses a single flat `0.48 × 0.024 × 0.34 m` landscape slab at `[0.64, 0.7695, -1.18]`. A bounded unlit inset screen makes the tablet face readable without adding a hinge, keyboard, base, or new app surface.

## 4. iPhone addition

The existing stable iPhone registry entity is now visible in V8 as a separate `0.16 × 0.018 × 0.32 m` portrait slab at `[0.35, 0.7665, -0.83]`. Its screen treatment is distinct from the iPad, and its final placement keeps the full silhouette visible from the canonical Founder camera.

## 5. Canonical navigation mapping

- Founder Computer: unchanged `.computer` selection and Company Command route.
- iPhone: existing `.phone` selection and `TechComScreen(store:)` route.
- iPad: existing `.tablet` selection and `VentureScreen(store:)` route.

`FounderDeskNavigationState` remains the only navigation authority. No duplicate Tech.com, Venture, or Computer screens were created.

## 6. Device geometry

The phone is portrait, the tablet is landscape, and both are less than ten percent as thick as their smaller face dimension. Their desk rectangles are separated on the Z axis, clear of the Computer keyboard, and visually distinct in both captured device classes. The imported laptop hierarchy remains present in the unchanged USDZ but is disabled in the active V8 runtime.

## 7. Hit-target behavior

Each root device owns one bounded collision shape and input target matching its visible slab. Descendant screen taps resolve by stable registry identity to the same root intent. Computer, phone, and tablet targets are distinct; non-desk entities still resolve to no desk-device intent. Interaction remains available only in the existing seated Founder camera state.

## 8. D1 feedback integration

D1 prompt/emphasis expansion was intentionally deferred. The correction uses direct native RealityKit taps and accessibility activation, avoiding unrelated feedback-state work.

## 9. Accessibility

Both devices now expose native RealityKit button semantics and activation actions:

- `Tech.com iPhone`
- `Venture iPad`

The existing Founder Computer semantics are unchanged.

## 10. Tests and builds

- 225/225 related `FounderGarageRealityTests` and `FounderDeskWorkspaceTests` passed on iPhone 17 Pro Max.
- 4/4 final correction contracts passed after the last placement adjustment.
- iPhone 17 Pro Max test build succeeded.
- iPad Air 11-inch (M4) build succeeded.
- V8 laptop suppression, device visibility, stable interaction identity, geometry, navigation isolation, `GameStore` non-mutation, and save version `20` are covered.
- Founder asset SHA-256 remains `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.
- V8 asset SHA-256 remains `d297d7a144ab3fc8e5b917226d492c4b2d6de3d05f4e46c3419895e3712450a4`.

## 11. Human acceptance

Review iPhone first, then iPad framing. Confirm that the side device reads as an iPad rather than a laptop, the iPhone is visible, all three devices are intentionally placed, and direct taps open Tech.com, Venture, and the unchanged Computer destination without target conflict.

Choose exactly one:

1. `ACCEPT`
2. `REJECT WITH SPECIFIC DEVICE DEFECT`
3. `REQUEST CONTROLLED VARIANTS`

## 12. Evidence ledger

See [FOUNDER_DESK_DEVICE_CORRECTION_EVIDENCE_LEDGER.md](FOUNDER_DESK_DEVICE_CORRECTION_EVIDENCE_LEDGER.md).

## 13. Repository state

The branch was already dirty with unrelated and prior-pass changes. This pass did not commit, push, reset, rebase, clean, switch branches, regenerate the project, or alter the V8/Founder assets. The existing project and shared-scheme modifications were left untouched.

Task-scoped source changes:

- `App/FounderWorldPresentationModel.swift`
- `App/FounderGarageRealityScene.swift`
- `App/FounderGarageRealityView.swift`
- `App/FounderDeskWorkspace.swift`
- `Tests/FounderGarageRealityTests.swift`

## 14. Deferred follow-ups

- Human direct-tap acceptance in Device Hub remains the final visual/interaction gate.
- D1 feedback for phone/tablet remains deferred unless human review identifies discoverability as an objective defect.
- No subsequent visual-fidelity pass begins automatically.
