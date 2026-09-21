# SOLO Visual Fidelity Contract

These are ratcheted production invariants. They may change only with explicit evidence and review; snapshot baselines never update automatically.

- The canonical Founder POV is owned by `FounderGarageCameraConfiguration`; character assets fit that camera, never the reverse.
- The authored seated eye midpoint stays within 15 mm vertically and 25 mm horizontally of the canonical POV.
- The Founder standing mesh remains approximately 1.792 m tall. Seated fitting must not use global character scaling.
- The canonical deform skeleton contains exactly 55 named joints and preserves its hierarchy and rest matrices.
- The runtime face exposes exactly nine nonempty targets: `Blink_L`, `Blink_R`, `JawOpen`, `Smile`, `Frown`, `BrowRaise`, `BrowLower`, `MouthNarrow`, and `MouthWide`.
- The repaired jaw has no open boundary through the visible jaw and no split corner-normal discontinuity there.
- First-person head masking keeps the body visible and independently disables `HeadMesh`, `HairMesh`, both eyes, and both irises.
- `HairSlot`, `TopSlot`, `BottomSlot`, `ShoeSlot`, and `AccessorySlot` remain valid attachment references.
- Approved deterministic snapshots must record fixture configuration. A changed implementation does not authorize replacing a baseline.
- Garage and Atlantis remain mounted in one composed `RealityView`; the Garage root remains mounted through handoff.
- Explore availability depends only on production Garage readiness.
- Garage-door availability depends on composed Founder exterior readiness. Distant Atlantis support assets do not block Garage exploration.

## Founder Facial Baseline

- Human facial acceptance was recorded on September 18, 2026 for runtime candidate SHA-256 `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.
- The approved evidence set is `Documentation/FounderCharacter/Evidence/A2/FacialAcceptance/`: front, 3/4 left, 3/4 right, profile, seated, standing, blink, and jaw-open captures, supported by the corresponding physical-device captures in `Documentation/FounderCharacter/Evidence/A2/Physical/`.
- Protected objective properties are the accepted facial silhouette and landmark placement, jaw continuity, mouth proportions, clean blink and jaw-open deformation, and the accepted neck/head relationship, together with the existing nine-target, hierarchy, masking, material, and attachment contracts.
- The approved captures are regression baselines. Changing the facial baseline or its protected properties requires explicit human approval; baseline captures must not update automatically.

## Founder Motion Baseline

- Human motion acceptance was recorded on September 19, 2026 for the unchanged production Founder with SHA-256 `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`.
- The approved evidence set is `Documentation/FounderCharacter/Evidence/B/HumanMotionReview/`, covering seated idle, standing idle, sit/stand, walk start, continuous walk, walk stop, turn in place, and walk + turn.
- The accepted implementation and deterministic signature are protected by `Documentation/VisualFidelity/MOTION_CONTRACT.md` and `Documentation/FounderCharacter/Evidence/B/pass_b_motion_contract.json`.
- Changing breathing, idle, gait, start/stop, sit/stand, turn, or gaze character requires new comparison evidence and explicit human approval. Approved motion evidence and signatures must not update automatically.
