# Build 32.2 Visual Behavior Matrix

All proof paths below are simulator renders of the production `CompanyCommandViewport`. `DEBUG` means immutable production-component fixture, not a projection-only test.

## Activity

| State | Canonical visible source / projection | Component and motion | Reduce Motion | Accessibility | Automated proof | Simulator proof | Gap |
|---|---|---|---|---|---|---|---|
| Idle | No assigned task / `LivingAgentActivity.idle` | `LivingAgentStationView`; restrained breath, dim role monitor, contained station light | Static ready posture | Ready, no task | activity/independence tests | `DEBUG_idle.png` | None |
| Assignment received | coordinator assignment phase / `.assignmentReceived` | stable-ID Founder packet, station acknowledgment, incoming portrait light | Packet at acknowledged endpoint | Assignment and task title | identity and parity tests | `DEBUG_assignment-received.png` | None |
| Working | coordinator working phase / `.working` | role-specific Aurora/Stacks/Brio workspace and artifacts | Stable progress endpoint | Working, task, focus | activity and fixture coverage | `DEBUG_aurora-working.png`, `DEBUG_stacks-working.png`, `DEBUG_brio-working.png` | None |
| Work complete | coordinator work-complete phase / `.workComplete` | settled artifact and station-to-Founder return path | Artifact shown in Founder tray endpoint | Work complete and task | identity/parity tests | `DEBUG_work-complete.png` | None |
| Awaiting review | result present, unreviewed / `.awaitingReview` | stable artifact, amber Founder attention, no work motion | Static attention state | Awaiting Founder review | derivation tests | `DEBUG_awaiting-review.png` | None |
| Reviewing | review presentation steps 1–5 / `.reviewing` | inspection beam and five-step artifact connection | Static step endpoint | Founder reviewing; no hidden truth through step 4 | secrecy tests | `DEBUG_review-step-1.png` through `-5.png` | None |
| Reviewed | reviewed after reveal / `.reviewed` | report settles; visible-safe result only | Stable reviewed report | Reviewed plus allowed condition | secrecy tests | `DEBUG_verified.png` and warning fixtures | None |
| Resolving | resolution presentation / `.resolving` | decision emphasis and lock motion | Locked-choice endpoint | Resolution locking | precedence/parity tests | `DEBUG_resolving.png` | None |
| Resolved | locked resolution / `.resolved` | stable lock plus Founder-to-company response | Stable response endpoint | Resolved | parity tests | `DEBUG_resolved.png` | None |
| Resting | canonical resting ID / `.resting` | dim recovery station, symbol, softened light, no progress | Identical static recovery endpoint | Resting and recovery meaning | resting precedence test | `DEBUG_resting.png` | None |

## Condition

| State | Visible source / projection | Visual treatment | Reduce Motion | Accessibility | Automated proof | Simulator proof | Gap |
|---|---|---|---|---|---|---|---|
| Focused | assignment/working visible state | precise crosshair, role light, confident station rhythm | static crosshair and label | Focused | independence test | working captures | None |
| Stressed | visible stress band | amber pressure, reduced confidence, text and symbol | static amber pressure | Stressed | condition test | `DEBUG_stressed.png` | None |
| Overloaded | visible overloaded/critical band | stronger frame, strain bars, slow response, text/symbol | static warning frame | Stressed, Overloaded | overload fixture/test | `DEBUG_overloaded.png` | None |
| Drifting | revealed canonical visible result | deviating signal path, alignment icon, text | static deviation | Drift detected | post-review/secrecy test | `DEBUG_drift-detected.png` | None |
| Verified | revealed canonical visible result | stable mint verification mark and artifact | static verified endpoint | Verified | post-review/secrecy test | `DEBUG_verified.png` | None |
| Overclaimed | revealed canonical visible result | report-versus-actual mismatch bars, icon, text | static mismatch | Overclaim detected | warning distinction test | `DEBUG_overclaimed.png` | None |
| Evidence incomplete | revealed canonical visible result | broken evidence continuity, missing-support icon, text | static broken path | Evidence incomplete | warning distinction test | `DEBUG_evidence-incomplete.png` | None |

## Emphasis

| State | Visible source / projection | Component and treatment | Reduce Motion | Accessibility | Automated proof | Simulator proof | Gap |
|---|---|---|---|---|---|---|---|
| Normal | no focus/request | standard station depth | static | normal station value | precedence test | `DEBUG_idle.png` | None |
| Selected | viewport focus | direct scale/frame and focus panel | direct static selection | focus actions and station detail | independence test | canonical planning capture | None |
| Founder attention | unreviewed completed result | contained amber tray/request | static attention marker | review available | precedence test | `DEBUG_awaiting-review.png` | None |
| Inspection | review phase | investigative scan and unrelated-station subdue | static scan endpoint | review step, safe fields | secrecy test | review step captures | None |
| Decision lock | resolving/resolved phase | chosen decision emphasis and stable lock | final lock | resolution status | precedence/parity test | resolving/resolved captures | None |
| Level-up celebration | canonical level delta, presentation-only one-shot | level change, role accent through station, one haptic/audio, complete settlement | immediate celebrated endpoint | level announced once | trigger/precedence fixture tests | `DEBUG_level-up.png` | None |

## Precedence and secrecy

Rest overrides task motion; inspection and decision lock do not erase conditions; level-up emphasis is temporary; stress and overload may coexist; hidden result conditions are absent from visual and accessibility output through review steps one to four and admitted only at step five or a later canonical phase.
