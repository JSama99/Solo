# Founder Garage Door

The Founder Garage includes a closed, rear-wall sectional Garage Door in the physical environment layer. It is separate from the Founder Computer, Signal TV, desk, and existing small side entrance.

## Presentation contract

- Six full-width powder-coated panels, horizontal seams, side rails and rollers, a top track/motor housing, bottom weather seal, and a centered handle/lock render as one physical object.
- The door shares the panoramic rear-wall transform and is reached by panning right in LOOK OUT / Free Look. `FounderGarageDoorLayout` is the single geometry contract for its visual placement and accessibility marker on iPhone and iPad.
- `OperatingCalendar.Period` is the sole time input. Morning and afternoon brighten the panels; evening dims them; night lowers panel exposure and increases blue exterior leakage around the closed frame and seams.
- The existing DEBUG Motion QA catalog exposes that same canonical period only for runtime visual inspection; it does not write a save or change gameplay time.
- The door is closed and presentation-only. It creates no action, resource cost, RNG event, save data, or gameplay state.
- Reduce Motion leaves the door static. Increased Contrast strengthens its structural edges. VoiceOver exposes a noninteractive `Garage Door`, value `Closed`, with identifier `garage-door`.

## Verification

- Unit coverage asserts rightward Free Look visibility on compact iPhone and regular iPad layouts, Morning/Night canonical-light mapping, and a Founder Computer focus round trip retaining the door's world state.
- Runtime visual evidence is captured from the built-in simulator after each visual pass; this file is not itself proof of visual acceptance.
