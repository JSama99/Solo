# Founder Character Production Promotion Report

## 1. Promotion Result

`PROMOTED`

The normal production Garage now loads the exact human-approved Founder candidate. The accepted asset, world geometry, camera physics, traversal, simulation, and save schema were not modified. Founder Character Pass B did not begin.

## 2. Accepted Candidate Identity

| Field | Value |
| --- | --- |
| Production path | `App/RealityKit/FounderCharacter/founder_candidate_a.usdz` |
| Expected SHA-256 | `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |
| Pre-promotion SHA-256 | `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |
| Post-promotion production SHA-256 | `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5` |
| File size | 2,657,535 bytes |

The intermediate accepted runtime artifact has the same SHA-256. No asset copy, regeneration, geometry change, texture rebake, morph edit, skeleton edit, material edit, or optimization occurred.

## 3. Production Wiring

The previous normal production reference was `FounderVisualSource.procedural`. The normal `FounderGarageRealityView` task now calls `FounderGarageRealityWorld.requestProductionFounder()`, which validates the bundled asset hash and passes `FounderVisualSource.bundledUSDZ(name: "founder_candidate_a")` through the existing `USDZFounderVisualAdapter`.

The loader architecture was reused. Its descriptor was extended to apply the already accepted seated validation pose, standing rest normalization, and the six-part first-person head mask. Camera-owned spatial state and the existing locomotion graph remain authoritative. The procedural adapter remains available as a non-active fallback/rollback surface; the production contract proves it is detached after a successful accepted-asset load. The QA/debug route remains available but is no longer necessary for normal production selection. No feature flag was added.

Promotion implementation/evidence files:

- `App/FounderCharacterContract.swift`
- `App/FounderGarageRealityScene.swift`
- `App/FounderGarageRealityView.swift`
- `Tests/FounderCharacterContractTests.swift`
- `Documentation/FounderCharacter/Evidence/A2/production_promotion_plan.json`
- `Documentation/FounderCharacter/Evidence/A2/production_visual_regression.json`
- `Documentation/FounderCharacter/PASS_A2_EVIDENCE_LEDGER.md`
- `Documentation/FounderCharacter/FOUNDER_CHARACTER_PRODUCTION_PROMOTION_REPORT.md`

The USDZ, Xcode project, shared scheme, Garage/Atlantis geometry, and traversal implementation were not changed by the promotion.

## 4. Visual Contract Verification

| Contract | Result |
| --- | --- |
| Founder POV ownership | PASS — remains `FounderGarageCameraConfiguration` |
| Seated eye/camera fit | PASS — 4.319 mm vertical, 1.326 mm horizontal |
| Chair, floor, knee, and hand fit | PASS — accepted A.2 validation pose unchanged |
| Standing scale | PASS — approximately 1.792 m; no global seated-fit scaling |
| Skeleton | PASS — exactly 55 canonical deform joints; hierarchy/rest audit unchanged |
| Facial targets | PASS — exact nine-target set |
| Jaw | PASS — 0 boundary edges and 0 maximum normal split |
| Materials/textures | PASS — references preserved by the byte-identical USDZ |
| First-person mask | PASS — six head modules hidden independently while body remains visible |
| Attachments | PASS — HairSlot, TopSlot, BottomSlot, ShoeSlot, AccessorySlot resolve |
| Deterministic captures | PASS — immutable eight-view hashes recorded; no baseline updated |

The deterministic comparison uses identity-and-runtime-contract equivalence: production consumes the byte-identical accepted USDZ, exact accepted pose file, unchanged materials/morph data, and accepted camera/mask contracts. The front, three-quarter left/right, profile, seated, standing, blink, and jaw-open baseline files remain unchanged. See `Evidence/A2/production_visual_regression.json`.

## 5. Runtime Verification

- Seated: accepted joint pose is installed by the normal production adapter.
- Standing and locomotion: the existing state graph remains unchanged; the presentation-only rig blends from accepted seated joints to authored rest without taking spatial authority.
- Blink and jaw open: production-path test drives `Blink_L`, `Blink_R`, and `JawOpen` successfully.
- First person: independent head modules disable; the body remains enabled.
- Duplicate/legacy check: the accepted USDZ adapter is active and the procedural normalization root has no parent. Only one Founder is active.
- Attachments: all five accepted named slots are present in the exact runtime artifact.

The production integration was completed in one implementation attempt. A first focused-test invocation exposed only an invalid test-fixture property reference; correcting it did not change production code. A later named-simulator invocation selected an unavailable `latest` runtime; the exact simulator-ID retry passed.

## 6. Physical Verification

| Gate | iPhone 16 Pro | iPad Air 11-inch (M4) |
| --- | --- | --- |
| Signed Debug production build/install/launch | PASS through physical UI run | PASS through physical UI run |
| Signed Release install/launch | PASS | PASS |
| Canonical Garage → Atlantis promotion smoke | 3/3 | 3/3 |

Each smoke used `Explore → Open Garage Door → drag upward and hold → Atlantis` and asserted the Atlantis root and controls after the handoff. The prior 10/10 per-device traversal qualification remains authoritative. Physical visual acceptance is supported by the already accepted device captures plus the production identity/runtime proof; tests alone are not represented as a new subjective visual approval.

## 7. Performance Regression

The accepted reference medians remain iPhone 40.078 MiB / 1.902 s and iPad 46.188 MiB / 1.784 s. Promotion did not alter the USDZ, package layout, loader/import algorithm, or asynchronous loading policy. The production graph test proves the procedural Founder is detached when the accepted adapter becomes active, eliminating simultaneous legacy/accepted character rendering. Physical launches and six consecutive traversal smokes completed without a load timeout or observed scene-update stall. No promotion-specific regression was found, so the rejected packaging optimization experiment was not reopened.

## 8. Regression Suite

| Gate | Result |
| --- | --- |
| Founder Character contracts | 7/7 passed |
| Founder/Garage/Atlantis subsystem gate | 189/189 passed |
| Complete unit target | 912/912 passed, 0 failed, 0 skipped |
| Unit-count change | +1 meaningful production-loader integration test from the 911 baseline |
| Simulator production continuity UI smoke | 1/1 passed |
| Physical production continuity UI smoke | iPhone 3/3; iPad 3/3 |
| Debug | PASS; signed physical UI builds installed/launched on both devices |
| Release | PASS; signed app installed/launched on both devices |
| Scoped `git diff --check` | PASS for all promotion files |
| Repository-wide `git diff --check` | Only seven pre-existing trailing-whitespace findings in `Tests/FounderDeskWorkspaceTests.swift` |

The source/runtime audits also passed: canonical rest matrices unchanged, jaw boundary count 0, maximum jaw normal split 0, sole error approximately 0, and accepted eye tolerances retained.

## 9. Rollback Plan

The immediate rollback is to remove the normal-route `requestProductionFounder()` call from `App/FounderGarageRealityView.swift`; production then retains its previous procedural Founder selection. A complete code rollback additionally restores the authored-pose, production descriptor/hash validation, and modular masking additions in `App/FounderGarageRealityScene.swift` and `App/FounderCharacterContract.swift`. The accepted USDZ may remain bundled and the QA route may remain intact. No asset deletion, save migration, project regeneration, or traversal change is required.

## 10. Repository State

| Field | Value |
| --- | --- |
| Branch | `visual-fidelity-track` |
| HEAD | `efd67e77f99dacf9e86e9cc71469cff713ada395` |
| Save version | `20` |
| Working tree | Dirty before and after promotion; unrelated and earlier traversal/visual-fidelity changes preserved |
| Commit/push | None |
| Pass B | Not started |

The working tree is intentionally left available for review.
