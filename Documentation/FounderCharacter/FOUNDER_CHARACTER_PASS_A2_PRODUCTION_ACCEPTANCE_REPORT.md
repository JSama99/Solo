# Founder Character Pass A.2 — Production Acceptance Report

## Executive Result

**Classification: GO**

All engineering gates for Founder Character Pass A.2 pass, and the human reviewer explicitly accepted the prepared facial review package on September 18, 2026. The candidate is eligible for production promotion but has **not** been promoted to the production Founder, and Pass B has not begun.

- Promotion status: eligible, not performed; promotion requires a separate explicit instruction.
- Technical blockers: none found.
- Human facial status: `HUMAN FACIAL ACCEPTANCE: ACCEPTED`.
- Performance decision: `ACCEPTABLE` for Pass A.2 under the existing asynchronous load path.

## Traversal

Traversal remains the previously accepted, locked state and was not modified by the remaining character work.

- The first proven physical divergence was collision slide-axis selection at an obstacle corner.
- The later proven failure was readiness-related: walking could start against provisional Garage bounds before Garage v8 became ready.
- The final visual-continuity repair keeps Garage and Atlantis inside one composed `RealityView`; Atlantis is spatially beyond the doorway and the Garage root remains mounted through handoff.
- Canonical physical route: iPhone 16 Pro `10/10`; iPad Air 11-inch (M4) `10/10`.
- The final production-continuity UI smoke passed and asserted that the Garage root remained present after the handoff.

## Seated Fit

The accepted correction fits the Founder to the existing camera, chair, desk, and Garage without moving or scaling those systems.

| Measurement | Baseline | Accepted |
| --- | ---: | ---: |
| Eye midpoint vertical error | +79.279 mm | 4.319 mm |
| Eye midpoint horizontal error | 124.539 mm | 1.326 mm |
| Pelvis above cushion | 82.239 mm | 42.239 mm |
| Minimum knee-joint clearance | — | >208 mm |
| Foot-to-floor error | 0 mm | <0.001 mm |
| Hands above desktop | 17.124 mm | <=10.5 mm |
| Standing mesh height | 1.792 m | 1.792 m |

The accepted iteration translated the pelvis 66.231 mm laterally, 105.467 mm toward the chair back, and 40 mm down in authored space. A two-bone solve returned both ankles to their original contacts. Residual upper-body corrections were bounded to 12 degrees: Spine01 `(-2, -4.5, 0)`, Spine02 `(0, 11, 0)`, Chest `(-3, 0, 0)`, and Neck `(12, 12, 12)` degrees. Hip/leg placement was solved through the pelvis translation and exact ankle-preserving leg solve; no broad skeleton rewrite or global scale change was used.

The numerical fixture and controlled views show believable chair contact and seated balance, clear knees, grounded feet, useful hand height, a natural head/neck result, and unchanged standing proportions. Jaw and locomotion contracts remain intact. **Seated fit: accepted and locked for Pass A.2.**

## Facial Acceptance

Objective validation passes:

- Source jaw audit reports 0 boundary edges and 0 maximum corner-normal disagreement at the repaired jaw.
- Exactly 9 required facial targets remain present.
- Direct runtime driving of `Blink_L`, `Blink_R`, and `JawOpen` passes.
- Required facial hierarchy, independent head masking, material/texture reference, and attachment-slot contracts pass.
- Deterministic captures cover front, 3/4 left, 3/4 right, profile, seated views, standing, blink, and jaw-open states.
- Physical iPhone 16 Pro and iPad Air 11-inch (M4) captures cover face, head-left, head-right, profile, seated, standing, blink, and jaw-open states.

No aesthetic selection variants were generated because the remaining decision is the acceptance of the current repaired face, not a localized aesthetic parameter with an objective defect. Codex does not self-certify premium aesthetic quality.

- Jaw status: objective repair retained.
- Blink status: functional on both physical devices.
- Jaw-open status: functional on both physical devices.
- Human acceptance: `HUMAN FACIAL ACCEPTANCE: ACCEPTED` on September 18, 2026.

Review evidence is stored in `Documentation/FounderCharacter/Evidence/A2/FacialAcceptance/` and `Documentation/FounderCharacter/Evidence/A2/Physical/`.

The reviewer accepted the current candidate after reviewing the controlled front, 3/4 left, 3/4 right, profile, seated, standing, blink, and jaw-open board. No variants were requested and no asset changes were required. The accepted runtime candidate SHA-256 is `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`; the app and intermediate packages remain byte-for-byte identical. The existing technical regression result remains valid because the acceptance gate changed documentation only.

## Performance

The current modular runtime package is 2,657,535 bytes. The one-skeleton experiment was 2,656,750 bytes, a reduction of only 785 bytes. It was rejected before physical profiling because RealityKit collapsed ten independently controllable model entities to one, exposed zero head modules, and failed 3 of 5 mandatory contracts. Measuring an already-disqualified package on hardware would not change the product decision.

| Metric | Current Candidate | Reduced-Duplication Experiment | Delta |
| --- | ---: | ---: | ---: |
| iPhone memory | 40.078 MiB median | Not run; functionality gate failed | N/A |
| iPhone import time | 1.902 s median | Not run; functionality gate failed | N/A |
| iPad memory | 46.188 MiB median | Not run; functionality gate failed | N/A |
| iPad import time | 1.784 s median | Not run; functionality gate failed | N/A |
| Triangles | 29,488 | 29,488 | 0 |
| Joints | 55 | 55 | 0 |
| Facial targets | 9 | 9 | 0 |

The retained candidate preserves ten independently renderable modules, ten compatible skeleton instances, independent head masking, five attachment references, all nine morph targets, seated and standing poses, and locomotion compatibility. The experiment reduced USD skeleton ownership to one but broke the runtime hierarchy and masking contract. It was not a Pareto improvement, the original package was restored byte-for-byte, and no second experiment was justified.

Three physical samples per device showed no scene-update stall. Current absolute Garage-plus-Founder endpoint medians were 332.392 MiB on iPhone and 385.735 MiB on iPad. Performance is **ACCEPTABLE** for this pass.

## Permanent Contracts Added

- `FounderCharacterContractTests` now verifies the exact nine-target set, native-scale hierarchy, independent head masking, runtime blink/jaw-open driving, graph/clip declarations, seated pose contacts and camera tolerances, and canonical POV masking.
- `audit_repair.py` now enforces the 15 mm vertical and 25 mm horizontal eye limits alongside jaw, floor, scale, skeleton, material, and target checks.
- `measure_seated_fit.py` records the required world-space landmarks and derived clearances in machine-readable form.
- `render_acceptance_fixture.py` produces the controlled facial and pose review package and records its fixture configuration.
- `package_shared_skeleton_experiment.py` records the bounded packaging experiment.
- Deterministic A.2 review captures and structured physical metrics were added under `Evidence/A2`.
- `Documentation/VisualFidelity/VISUAL_CONTRACT.md` ratchets camera ownership, seated tolerances, standing scale, jaw continuity, 55 joints, 9 targets, masking, attachments, snapshot policy, shared-world ownership, and readiness gates.

## Regression Validation

- Source and USD/runtime package audits: passed.
- Founder character, Garage RealityKit, and Atlantis subsystem gate: 188 passed, 0 failed.
- Full unit target on iPad Air 11-inch (M4) simulator: 911 passed, 0 failed, 0 skipped. The prior count of 910 increased by exactly one for the new runtime blink/jaw-open contract.
- Production Garage-to-Atlantis continuity UI test on iPhone 17 Pro Max simulator: 1 passed, 0 failed.
- Debug build: passed; the signed physical Debug app installed, launched, and produced the complete acceptance capture set on both devices.
- Signed Release build: passed.
- Release install/launch: passed on physical iPhone 16 Pro and physical iPad Air 11-inch (M4).
- Existing physical traversal evidence: iPhone `10/10`; iPad `10/10`.
- Scoped `git diff --check`: passed. The repository-wide check continues to report only seven pre-existing trailing-whitespace lines in `Tests/FounderDeskWorkspaceTests.swift`.

Two command invocations failed for environment reasons, not test failures: the first continuity UI invocation was denied CoreSimulator/cache access by the sandbox and passed when rerun with approved simulator access; the first iPad full-suite invocation referenced a stale unavailable simulator UUID and passed after selecting the available iPad Air 11-inch (M4) destination. Neither failed invocation began a test case.

Simulator/device verification supports the engineering result but does not replace the required human aesthetic decision.

## Repository State

- Branch: `visual-fidelity-track`.
- HEAD: `efd67e77f99dacf9e86e9cc71469cff713ada395`.
- Save version: `20`, unchanged.
- Working tree: dirty before and after this pass; unrelated user changes were preserved. No commit, push, reset, rebase, clean, branch switch, or automatic production promotion was performed.
- Pass A.2 character files changed or added: `App/FounderCharacterContract.swift`; the Founder runtime USDZ and validation pose under `App/RealityKit/FounderCharacter/`; `Tests/FounderCharacterContractTests.swift`; the repair, audit, measurement, optimization, capture, fixture-render, and packaging scripts under `Documentation/FounderCharacter/Source/`; regenerated source/intermediate character artifacts; `Documentation/FounderCharacter/Evidence/A2/`; this report; the Pass A.2 evidence ledger; and `Documentation/VisualFidelity/VISUAL_CONTRACT.md`.
- The pre-existing traversal, Garage, Atlantis, project, scheme, and other dirty files were not attributed to the remaining character acceptance work.

## Production Decision

**GO**

Traversal remains reliable, seated fit passes, the jaw repair and facial runtime contracts pass, performance is accepted, regressions pass, save version remains 20, and human facial acceptance is explicit. The candidate is eligible for production promotion, but acceptance did not perform promotion. Do not promote the candidate or begin Founder Character Pass B without a separate explicit instruction.
