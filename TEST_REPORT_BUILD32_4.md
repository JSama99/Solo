# Test Report — Build 32.4

Date: 2026-08-22. SDK: iOS Simulator 26.5. Destination: iPhone 17 Pro.

| Run | Executed | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: | ---: |
| Build 32.4 focused (post audio fix) | 21 | 21 | 0 | 0 |
| Build 32–32.4 presentation and motion | 114 | 114 | 0 | 0 |
| Full XCTest suite (post audio fix) | 358 | 358 | 0 | 0 |

Focused coverage includes automatic focus/navigation isolation; causal identity, kind, endpoint, Reduce Motion, and skip parity; review visual/accessibility secrecy; facility structure; five infrastructure locations and four states; visible-only atmosphere; user-focus stability; explicit workstation navigation; duplicate protections; same-seed parity; legacy decode; safe character input; native fallback without Rive assets; and multichannel feedback-buffer compatibility.

Build verification: clean iPhone 17 Pro simulator build and launch completed successfully after the final source changes. Presentation performance verification confirmed one shared viewport timeline, precomputed scene projection/indexing, clipped localized effects, no per-agent timers, no visual RNG, no `GameStore` animation state, and endpoint-only Reduce Motion. Instruments was not run.

Known limitation: bespoke production character animation remains pending real licensed `.riv` assets; the production-ready native replacement boundary ships and fails safely without them. No canonical limitation or regression is known.
