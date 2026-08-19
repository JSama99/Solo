# Build 28.1 Founder Command Parity

This matrix records the production command deck audit performed before its visible UI was removed. All new controls call the same closures and canonical `PresentationCoordinator` / `GameStore` methods previously used by the deck.

| Command | Former deck location | In-card location | Enabled states | Disabled states | Side effects preserved | Accessibility label | Verified parity |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Assign | Selected agent deck | Expanded card → Founder Actions | Choose Commitments, Assign Team | Founder Event, Review and Resolve, Ready to Commit | Existing assignment sheet, `presentation.assign`, assignment handoff, HUD announcement | Assign | Yes |
| Review | Selected agent deck | Expanded card → Founder Actions, primary while awaiting review | Review and Resolve + result + awaiting review + Attention > 0 | Every other lifecycle/phase, reviewed work, no Attention | `presentation.review`, Founder Review choreography, verification impact, Evidence/HUD feedback | Review | Yes |
| Rest | Selected agent deck | Expanded card → Founder Actions | Choose Commitments, Assign Team, not already resting | Founder Event, review/commit phases, already resting | Existing destructive confirmation, assignment clearing, rest simulation action, announcement | Rest / Resting | Yes |
| Resolve | Existing reviewed-result controls | Expanded card → Founder Actions → Founder Resolution | Reviewed, unlocked result, not resolving | Before review, resolving, resolved/locked | `presentation.resolve`, resource costs, resolution choreography, haptic, announcement | Canonical choice title | Yes |

The former deck exposed no cancel or inspect command. Reassignment remains available through the same Assign sheet while assignment controls are enabled. The phase blocker remains conveyed by each disabled in-card action’s accessibility hint.
