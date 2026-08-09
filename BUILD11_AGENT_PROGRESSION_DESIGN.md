# Build 11 Agent Progression Design

## Core model

Each `SoloAgent` owns an `AgentProgressionState`. It persists XP, selected perks, numeric `stressLevel`, ambition counters, completion state, and seen-conversation capacity. Existing `stressTrigger` and `ambition` strings remain narrative descriptions; the mechanical values use distinct names.

## XP and levels

Every committed task grants 10 XP, +3 for role fit, +5 for a strong result, and +4 for verified work. Risky work still earns baseline experience. Levels use centralized thresholds: 0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3250, 3850, 4500, 5200, and 6000 XP.

## Branches and stress

Aurora chooses Evidence Architect or Market Oracle; Stacks chooses Rapid Builder or Reliability Engineer; Brio chooses Revenue Operator or Ethical Growth. A branch locks when its first Level-2 perk is selected. Stress bands are Focused (0–24), Stable (25–49), Pressured (50–74), Overloaded (75–89), and Critical (90–100). Stress affects quality deterministically and is clamped to 0...100. Unassigned agents recover each sprint; the active Founder Loft reduces new stress by 10%.

## Facilities, fairness, and determinism

Garage upgrade XP acceleration is active only while the Garage is the current HQ. The Loft has its own sustainable-operations stress modifier. Daily Challenge always initializes fresh level-one agents. Progression derives from already-generated results and does not consume or reorder gameplay RNG.
