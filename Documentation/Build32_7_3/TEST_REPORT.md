# Build 32.7.3 Test Report

Date: 2026-08-27  
SDK/runtime: iOS 26.5

| Scope | Configuration | Result |
| --- | --- | --- |
| Founder Desk focused | iPhone 17 Pro | 39/39 passed |
| Spatial causality / hidden truth | iPhone 17 Pro | 26/26 passed |
| Full XCTest | iPhone 17 Pro | 471/471 passed |
| Production device continuity | iPhone 17 Pro | 1/1 passed |
| Production device continuity | iPad Pro 11-inch (M5) | 1/1 passed |
| Idle Garage no-action hold | iPad Pro 11-inch (M5) | 1/1 passed |

The full-suite first run exposed `testStacksObservationIsReadableBesideFounderMonitor`. The compact Stacks anchor was corrected to maintain more than 90 points of separation from the foreground monitor; the complete suite was then rerun and passed 471/471. No assertion was weakened or removed.

Focused coverage added for compact versus regular composition, cockpit peripheral discovery, monitor proportion, deterministic ambient baseline, unsynchronized rhythms, Reduce Motion static-state preservation, ambient audio hooks, and hidden-truth invariance.

Production automation verifies no tab bar, LOOK OUT, drag and manual camera controls, left/center/right views, all four device focus paths, stateful returns, all nine server destinations, and minimum close-control targets.

