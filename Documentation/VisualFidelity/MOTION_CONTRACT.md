# SOLO Founder Motion Contract

## Founder Motion Identity

- Pass B classification: `GO`
- Human motion acceptance: `ACCEPTED`
- Acceptance date: `2026-09-19`
- Founder SHA-256: `6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5`
- Reviewed evidence: `Documentation/FounderCharacter/Evidence/B/HumanMotionReview/`
- Deterministic fixture and motion signature: `Documentation/FounderCharacter/Evidence/B/pass_b_motion_contract.json`
- Selected parameter set: unchanged production baseline; no controlled variant was generated or selected

The SHA-256 hashes of the approved evidence clips are:

| Evidence | SHA-256 |
| --- | --- |
| A · Seated Idle · iPhone | `eed426bc4b5797652726d7856a756d795b8b0c85a4aac8204e3aab295fc419cd` |
| B · Standing Idle · iPhone | `e3b02cb2c5033922e0deb3eec126e316e3234b73e1c8a885e6fae1d67a632171` |
| C · Sit → Stand · iPhone | `3af67023941d5e4e6e67bad3893ca48f2f6ed9e4cad294a44b4b230c4f11be60` |
| D · Stand → Sit · iPhone | `a6799bcd6e2ee436287097e396d9250067121543c51ea979099b66e7e5e48d7f` |
| E · Walk Start · iPhone | `6837f876408cebe6c7272877d238b56617efb3a45c5759d0d324c85e61312266` |
| F · Continuous Walk · iPhone | `4b07ccded633d775fd97239af7e9fb12c8b70b93fb4299f9ad257fc8e4136ef4` |
| F · Continuous Walk · iPad | `94c0dcce43d9ac98ce0000afa7a6307fc66d6d94aba19c50ca4a8081df8d2947` |
| G · Walk Stop · iPhone | `bd51cc79be9979a05ad95774842ab5c7379a329cd40153513f837a0c3116c40e` |
| H · Turn In Place · iPhone | `c5e287117db8f05690faea057c1ad0c93fa6ef4c1ad2520f6832968023fc8ac2` |
| I · Walk + Turn · iPhone | `4450ceeaaa31733e626d31cfc73cab32f8d61ad052be0ceddfe9be82a3671a2f` |

## Protected Engineering Contracts

- Seated pelvis, hands, and feet remain anchored within their existing tolerances.
- Standing pelvis and feet remain anchored during additive idle motion.
- Locomotion cadence remains derived from world displacement; root motion remains presentation-only and cannot become spatial authority.
- Sit/stand endpoints converge to the accepted poses, including under Reduce Motion.
- Start/stop blend weights remain monotonic and finite.
- Stationary and moving turn velocity remain bounded; first-person head masking remains intact.
- Camera Physics, graph topology, Garage/Atlantis traversal, `GameStore`, save schema, and save version remain unchanged.

## Protected Human Baseline

The accepted baseline includes the reviewed breathing amount, restrained seated and standing idle character, focused gaze behavior, sit/stand weight, purposeful gait and arm/torso character, start/stop feel, and turn anticipation. These subjective qualities are protected by the approved evidence rather than converted into synthetic numerical taste tests.

Future changes require new evidence, deliberate human review, and explicit approval. Do not silently regenerate the evidence or motion signature.
