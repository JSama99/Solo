# Headquarters Design

Capital creates a deliberate choice between immediate operating leverage and saving for the $4,000 Founder Loft. Purchases live in `FounderProgressionStore`, are persisted independently from the deterministic career RNG, and are active only when their required facility is selected.

The Garage provides specialized AI-workforce infrastructure. The Founder Loft shifts the company toward sustainable operations with a venture-start Energy bonus. The `FacilityTier` and `FacilityUpgradeDefinition` models are reusable for future facilities and upgrades without putting game rules in SwiftUI.
