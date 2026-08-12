# Build 19 — Garage Capacity P0 Fix

The Talent Board correctly added agents to `store.agents`, and the environment and scene correctly generated stations for every agent. The scene then collapsed indices 3 and 4 onto index 2 because its X/Y/width helpers clamped to a three-entry table. Those stacked stations were inaccessible, while the retired Command screen provided no live alternative.

Build 19 replaces that table with `GarageBayLayout`: an explicit, testable 3–5 station geometry that keeps every bay and the founder desk footprint separate. Four and five-agent maps expand horizontally instead of shrinking labels. The Garage caption and interaction language derive from the live station count.
