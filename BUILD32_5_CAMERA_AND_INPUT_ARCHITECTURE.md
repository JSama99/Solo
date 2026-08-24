# Build 32.5 Camera and Input Architecture

Camera state is local `@State` in `FounderEnvironmentScreen` and is never saved or passed to `GameStore`.

| Mode | Computer | Room camera | Return path |
| --- | --- | --- | --- |
| Computer Focus | Hit testing and accessibility enabled | Drag disabled | Look Around button |
| Free Look | Hit testing and accessibility disabled | Bounded drag and named controls enabled | Tap physical monitor or Return control |

The environment is behind the monitor and all decoration has hit testing disabled. No full-screen transparent overlay sits over Company Command in focus mode. Reduce Motion snaps camera commands to stable center/left/right/up/down endpoints and makes mode transitions immediate.

This preserves the embedded computer instance, so its scroll ownership, workstation expansion, current focus, and presentation phase survive camera changes.
