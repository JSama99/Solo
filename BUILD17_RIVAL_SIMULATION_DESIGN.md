# Build 17 — Lightweight Rival Simulation

Rivals are computed purely from founder identity, product type, rival ID, venture, sprint, current stats, and company flags. They consume no shared simulation RNG and add no saved rival state.

Six competitors use incumbent, upstart, hype-machine, quiet-builder, and copycat curves. Market share normalizes the player and active field; positive revenue effects receive a bounded 0.85–1.15 multiplier. Tech.com now shows the active market-share field and each rival’s archetype.
