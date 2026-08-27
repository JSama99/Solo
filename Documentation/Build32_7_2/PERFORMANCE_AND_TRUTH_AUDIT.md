# Build 32.7.2 Performance and Truth Audit

Physicality uses static SwiftUI shapes, gradients, masks, transforms, and localized shadows. There are no new stores, feature renderers, shaders, blurs, assets, timers, or duplicated canonical screens. Only one small server status LED uses a lightweight phase animation; Reduce Motion fixes its opacity and disables press-scale flourishes.

The existing narrow `FounderDeskPreviewInput` remains the sole source for desk screens, luminance emphasis, and server indicators. Chassis, glass, shadows, reflections, and cables are decorative and accessibility-hidden. No new presentation path reads correctness, quality, drift, overclaim, verification, outcome, hidden risk, or evidence completeness.

The four canonical feature surfaces remain permanently mounted. Only opacity, hit testing, scale, and z-order change during selection, preserving local scroll/selection state and the single `GameStore` / `PresentationCoordinator` ownership model.

