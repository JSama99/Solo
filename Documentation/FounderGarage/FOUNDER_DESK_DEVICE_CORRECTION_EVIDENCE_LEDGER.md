# Founder Desk Device Correction Evidence Ledger

| Contract | Evidence | Result |
|---|---|---|
| Pre-change source | V8 USD inspection found `FounderLaptop`, `Laptop_Lid`, and `Laptop_Display`; canonical runtime phone/tablet were disabled for imported architecture | Root cause confirmed |
| No extra laptop | V8 runtime contract asserts `FounderLaptop.isEnabled == false` | Pass |
| Stable device identity | Existing `FounderGarageEntityRegistry.iPhone` and `.iPad` IDs retained across presentation updates | Pass |
| iPad geometry | `0.48 × 0.024 × 0.34 m`, landscape, one flat slab plus inset screen, no hinge/base | Pass |
| iPhone geometry | `0.16 × 0.018 × 0.32 m`, portrait, separate from iPad and keyboard | Pass |
| Hit targets | Each device has one root `InputTargetComponent`, bounded collision, and native accessibility activation | Pass |
| Interaction mapping | Computer → `.openFounderComputer`; iPhone → `.openFounderPhone`; iPad → `.openFounderTablet` | Pass |
| Canonical navigation | Workspace callbacks call existing `select(.computer)`, `select(.phone)`, and `select(.tablet)` | Pass |
| Destination ownership | Existing `TechComScreen(store:)` and `VentureScreen(store:)` remain authoritative | Pass |
| Navigation isolation | No new destination screen or navigation state introduced | Pass |
| Simulation isolation | Canonical `GameStore` snapshot unchanged by device construction/selection contract | Pass |
| Save compatibility | `GameStore.saveVersion == 20` | Pass |
| Related regression suite | 151 Garage + 74 Desk Workspace tests | 225/225 passed |
| Final focused contracts | Identity, geometry, navigation isolation, V8 replacement | 4/4 passed |
| iPhone visual | [iPhone 17 Pro Max Founder view](FounderDeskDeviceCorrection/iphone-17-pro-max-founder-view.png) | Pass; human acceptance pending |
| iPad visual | [iPad Air 11-inch (M4) Founder view](FounderDeskDeviceCorrection/ipad-air-11-m4-founder-view.png) | Pass; human acceptance pending |
| iPhone build | iPhone 17 Pro Max, iOS 26.5 | Pass |
| iPad build | iPad Air 11-inch (M4), iOS 26.5 | Pass |
| Founder asset ratchet | `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` | Unchanged |
| V8 asset ratchet | `d297d7a144ab3fc8e5b917226d492c4b2d6de3d05f4e46c3419895e3712450a4` | Unchanged |

## Test records

- Related result bundle: `/tmp/solo-device-correction-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-14-28--0400.xcresult`
- Final focused result bundle: `/tmp/solo-device-correction-focused/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-16-05--0400.xcresult`

## Human gate

Direct physical-device taps remain a human Simulator acceptance step. Choose exactly one: `ACCEPT`, `REJECT WITH SPECIFIC DEVICE DEFECT`, or `REQUEST CONTROLLED VARIANTS`.
