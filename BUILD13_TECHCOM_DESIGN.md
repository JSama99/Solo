# Build 13 Tech.com Design

## Core model

Tech.com is a presentation layer over the existing career truth. `PresentationCoordinator.Event` remains the only source for player-company activity; every presentation event is converted to one persisted `TechComHeadline`. Rival companies use the same claimed, actual, verification-state, and overclaim vocabulary as task results, but never affect simulation math.

## Publishing and throttling

`TechComEngine` is a pure resolver. It accepts a typed snapshot, the current sprint's presentation events, authored templates, and a seeded generator. Event headlines always retain their populated real-state slots. Trend publication is capped to fill quiet cycles; event-heavy cycles publish fewer trend items, preventing a sprint from becoming a noisy feed.

## Rivals and rankings

The authored rival roster has deterministic claimed and hidden actual scores generated from the career seed. Founder Attention verifies one rival claim at a time, exposing its actual score and any overclaim. Rankings compare the player's current stats with rival claimed scores by track record, revenue, or momentum.

## Persistence and compatibility

Career save schema v10 carries Tech.com headlines and rivals with safe empty defaults for v9 careers. The feature does not consume career simulation RNG and does not modify `SimulationEngine`.
