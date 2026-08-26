# Accessibility and Reduce Motion Matrix

| Meaning | Default | Reduce Motion equivalent | Non-color/VoiceOver support |
|---|---|---|---|
| Camera focus/Look Out | Spatial travel | Existing crossfade/direct focus | Named Look Out/return controls; orientation restored |
| Assignment dispatch | Traveling packet | Founder source then agent destination highlight | Agent name, task icon, announcement |
| Work completion | Document return | Agent and review tray persistent highlight | “Ready for review,” document icon, announcement |
| Resolution | Choice-specific route | Source/destination endpoint highlight | Distinct symbol, shape, action name, recap |
| Role identity | Aurora sweep, Stacks assembly, Brio wave | Static distinct role/artifact symbols and text | Rhythm, icon, role, and name—not color alone |
| Pending attention | Bounded emphasis | Persistent border/status | Text and accessibility value |
| Milestone | Contained staged reveal | Immediate contained highlight | Milestone text announcement |
| Ambient room | Subtle shared phase | Static depth layers | No gameplay meaning depends on motion |

All custom actionable regions retain at least 44×44 points. Accessibility text sizes select the existing `accessibleList` desk layout, keeping camera controls and all physical-device destinations reachable without precise gestures. Focus is changed only by user navigation; automatic choreography cannot steal it. Increased Contrast uses borders, shapes, icons, and text in addition to color.

Automated policies prove semantic equivalence of travel and endpoint alternatives. Simulator evidence verifies Accessibility Extra Large plus Increased Contrast. The Bitrig simulator connector cannot toggle Reduce Motion or VoiceOver, so those runtime modes are not claimed as manually verified; their code paths and truth-safe strings are covered by tests.
