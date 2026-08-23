# Build 32.4 Spatial Causality Design

## Stable scene contract

`CompanyCommandViewport` owns one scene coordinate space. `CompanyCommandInteractionState` separates user focus from automatic presentation: taps may focus an agent and the explicit Full Workstation action may request navigation, while `receiveAutomaticPresentationUpdate()` is deliberately non-mutating.

Each `CompanyCausalObject` carries a stable task ID, stable agent ID, distinct presentation kind, and explicit endpoint:

| Kind | Direction | Endpoint | Duration |
| --- | --- | --- | --- |
| Assignment document | Founder → agent | Role monitor | 700 ms |
| Completed artifact | Agent → Founder | Founder review tray | 820 ms |
| Resolution response | Founder → company | Affected company system | 750 ms |

The renderer resolves paths from viewport anchors, never scroll positions or global screen coordinates. Endpoint state persists. Reduce Motion and Skip Presentation select the same endpoint immediately and never gate or mutate `GameStore`.

## Facility identity

Garage projection uses a low, compressed frame, exposed asymmetric rails, visible conduit, improvised mounts, recessed wall sections, warmer practical fixtures, and a compact Founder desk. Loft projection uses taller window bays, exterior skyline depth, regular equipment mounting, wider station spacing, a refined desk, and cleaner reflected architectural surfaces. These structural fields remain different when palette fields are ignored.

## Infrastructure and atmosphere

Development Rig, Verification Array, Campaign Studio, Recovery Corner, and Founder Command Desk map to distinct scene anchors. Reserved, installing, installed, and relevant-active are deterministic presentation states. Energy, runway, trust, momentum, stress, and overload derive only from visible canonical projection fields and stay localized to their relevant scene regions.

## Secrecy and authority

The viewport consumes sanitized visible projections. Review steps one through four cannot expose actual quality, drift, overclaim, evidence failure, or correlated failure in visual or accessibility output. Step five admits only the canonical revealed condition. Presentation state contains no RNG and is never authoritative over gameplay.

