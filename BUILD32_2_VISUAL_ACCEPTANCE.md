# Build 32.2 Visual Acceptance

## Evidence provenance

`VisualProof/BUILD32_2_CANONICAL_PLANNING.png` is a canonical gameplay state captured from Founder Computer in the built-in simulator. Every file prefixed `BUILD32_2_DEBUG_` is a production `CompanyCommandViewport` rendered by immutable DEBUG fixtures. These fixtures do not receive `GameStore`, persist, consume RNG, configure RevenueCat, or change Release behavior.

All 46 required fixture states were captured on an iPhone 17 Pro simulator running iOS 26.5. Captures include idle, assignment, three role-specific working states, multiple working, completion, awaiting review, each review step, four revealed outcomes, stress, overload, rest, level-up, resolving/resolved, every phase, blocked commit, all infrastructure states, both facilities, all atmosphere extremes, Reduce Motion, Extra Large, and Increased Contrast.

## Mandatory acceptance mapping

- Character work: `DEBUG_aurora-working`, `DEBUG_stacks-working`, `DEBUG_brio-working`.
- Conditions: `DEBUG_stressed`, `DEBUG_overloaded`, `DEBUG_resting`, `DEBUG_verified`, `DEBUG_overclaimed`, `DEBUG_drift-detected`, `DEBUG_evidence-incomplete`, `DEBUG_level-up`.
- Infrastructure: `DEBUG_upgrade-uninstalled`, `DEBUG_upgrade-installing`, `DEBUG_upgrade-installed`, `DEBUG_upgrade-active`.
- Facilities: `DEBUG_garage`, `DEBUG_founder-loft`.
- Atmosphere: `DEBUG_low-energy`, `DEBUG_low-runway`, `DEBUG_low-trust`, `DEBUG_high-momentum` plus healthy/high counterparts.
- Hierarchy: `DEBUG_planning`, `DEBUG_working-phase`, `DEBUG_review`, `DEBUG_resolution`, `DEBUG_commit-ready`, `DEBUG_blocked-commit`.
- Accessibility policy: `DEBUG_accessibility-extra-large`, `DEBUG_increased-contrast`, `DEBUG_reduce-motion`.
- Causal checkpoints: `DEBUG_assignment-received`, role working captures, `DEBUG_work-complete`, `DEBUG_awaiting-review`, `DEBUG_review-step-1`…`-5`, `DEBUG_resolving`, and `DEBUG_resolved`.

Pixel inspection confirmed that the role workspaces, warning treatments, facility architecture, infrastructure silhouettes, phase priority, and accessibility layout are visually rendered rather than label-only branches.

## Causal-chain status

The complete production-component chain is implemented and each checkpoint has simulator visual proof. `BUILD32_2_DEBUG_CAUSAL_SEQUENCE.mp4` is one uninterrupted DEBUG production-component recording driven by an autoplay list of immutable projections: planning, assignment receipt/dispatch, role work and artifacts, work completion/return, awaiting review, all five review steps, verified treatment, resolution lock, company response, and commit readiness. It does not mutate or impersonate canonical gameplay and is labeled DEBUG rather than canonical.

## Accessibility and hidden truth

Text, symbols, color, and motion/static posture communicate each operational state. Dynamic Type reaches an Extra Large fixture without removing station identity. Increased Contrast and Reduce Motion use production inputs. Review captures and tests confirm no verification/warning condition appears visually or in accessibility output during steps one through four; step five admits only canonical visible truth.

## Direction estimate

With production behavior, all fixture captures, phase/facility/infrastructure/atmosphere progression, uninterrupted production-component proof, and regression validation complete—but without a physical-device/VoiceOver/Instruments pass or a canonical-gameplay recording—the revised estimate is **83% toward the intended “The Sims for AI solo founders” direction**. No 85% claim is made.
