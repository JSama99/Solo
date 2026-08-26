# Founder Desk Spatial Layout

All equipment uses `FounderEnvironmentLayout` projection on the foreground parallax layer. `FounderDeskEquipmentLayout` derives both the visible body position and its minimum 44-point hit region from the same anchor, preventing screen-space hit targets from drifting while the room moves.

| Element | World anchor | Placement |
| --- | ---: | --- |
| Founder Computer | `(680, 480)` | centered, stand contacting desk |
| Desk surface | `(680, 590)` | widened working plane |
| Tech.com iPhone | `(500, 600)` | left tabletop, −7° resting angle |
| Venture iPad | `(775, 600)` | right tabletop, landscape, 3° angle |
| Desk left edge | `(470, 650)` | widened support boundary |
| Desk right edge | `(840, 650)` | widened support boundary |
| Company Server | `(885, 660)` | right of desk, floor rack |
| Desk floor side | `(885, 710)` | server grounding reference |

The desk renderer now uses a 470×170 geometry with a 486-point ground shadow, two separated supports, a wider trapezoidal top/front, and a rebalanced keyboard/accessory layout. Compact layouts use smaller physical screens while preserving 44-point targets. Regular width uses a wider camera reference and larger inter-device spacing rather than scaling the compact scene.

Facility identity remains supplied by `FounderProgressionStore`; the device anchors stay stable as the surrounding headquarters presentation evolves.

