# Build 32.4.1 Visual Acceptance

The prior Build 32.4 proof was stale: its PNGs and causal video were copied from the prior visual-scene implementation and have been removed. Build 32.4.1 proof must be regenerated from the Claude `CompanyCommandScene` implementation.

Current fresh inventory:

- `VisualProof/Build32_4_1/01_FOUNDER_GARAGE.png` — iPhone 17 Pro simulator, production Founder Computer viewport.
- `VisualProof/Build32_4_1/BUILD32_4_1_DEBUG_CAUSAL_SEQUENCE.mov` — 26.618 seconds, iPhone 17 Pro Simulator, production `CompanyCommandViewport` with clearly visible DEBUG provenance.

The video was recorded from a stable Planning fixture already on screen; capture began before the DEBUG causal notification was sent at +0.5 seconds, avoiding a Home Screen or launch flash. The fixture playback then covered assignment, working activation, artifact return/settlement, review steps one through five, Verified, resolution response/settlement, and Commit-ready. The exported duration was read from the MOV with AVFoundation: 26.618 seconds. A post-record simulator capture confirmed the stable Commit-ready endpoint; it remained for approximately 2.87 seconds before the recording ended.

This is still an intentionally incomplete PNG inventory. No claim is made for Loft comparison, accessibility endpoints, or every infrastructure variant until the remaining fresh captures are exported from the DEBUG production-component fixture catalog. The catalog exposes all 49 immutable fixtures; it does not construct or mutate a `GameStore`, consume RNG, persist data, or configure RevenueCat.

Visual inspection of the one fresh production capture: the Garage reads structurally as a hanging-cable, three-bay space; systems are rendered at their scene locations; the header is collision-free; and automatic choreography remains overview-only. No visual-direction estimate is provided because one frame cannot honestly establish it.
