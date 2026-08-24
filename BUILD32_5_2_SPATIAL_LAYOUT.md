# Build 32.5.2 Spatial Layout

## Pure projection boundary

`FounderEnvironmentLayout` is a value-only presentation model. It defines a 1360 × 760 world, normalized camera bounds, stable world anchors, layer parallax factors, camera clamping, visible-world bounds, and a pure world-to-viewport projection.

It has no reference to `GameStore`, progression, RNG, scoring, purchases, persistence, or action handlers.

## Stable anchors

- Entrance and storage: left architecture
- Aurora and Verification Array: left operating zone
- Stacks and Development Rig: central operating zone
- Brio, Campaign Studio, and Recovery Corner: right operating zone
- Founder desk, monitor, and Founder Command Desk: foreground center

All rendering layers derive movement from the same clamped camera value. Background, middle-ground, and foreground use different factors from that shared transformation; individual views do not invent independent camera offsets.

## Viewpoints

- Left endpoint exposes Aurora, verification equipment, entrance, and storage.
- Center exposes the Founder desk/monitor and Stacks while retaining peripheral zone hints.
- Right endpoint exposes Brio, campaign equipment, recovery equipment, and the room edge.

Horizontal values clamp to `-1...1`; vertical values clamp to `-0.30...0.30`. Reduce Motion uses the same endpoints without animated interpolation.

## Input ownership

- Computer Focus installs no room drag recognizer and no parent monitor tap recognizer.
- Free Look disables embedded-computer hit testing, installs the bounded room drag surface, and enables the physical-monitor return region.
- Dragging records a gesture-start camera snapshot, adds viewport-normalized translation, and clamps the result. Consecutive drags therefore accumulate without jumping to center.
- The compact rail exposes Left, Center, Right, and Computer. Up and Down remain named accessibility actions.

Mode changes alter only view-local camera and interaction policy. The canonical computer subtree keeps stable identity and state.
