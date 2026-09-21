# Founder First-Person Access Correction Evidence Ledger

| Contract | Evidence | Result |
|---|---|---|
| Founder camera mode | Non-walking navigation uses the canonical seated-eye camera and first-person avatar mask | Pass |
| First-person seating invariant | First-person synchronously resolves `seatedIdle`, zero movement, and canonical chair anchoring | Pass |
| Eye-camera occlusion | Complete local Founder visual is suppressed in first person; torso and transition geometry cannot enter the lens | Pass |
| Chair transition boundary | Sitting remains visible in third person and changes to first person only at the seated animation endpoint | Pass |
| Explore camera mode | `.walking` restores the existing third-person observation camera | Pass |
| Explore free look | Established drag gesture remains active while walking; look orientation drives the third-person camera | Pass |
| Locomotion isolation | Existing acceleration, deceleration, collision, gait, and return-to-desk paths remain authoritative | Pass |
| Variant B isolation | No Founder Character motion or weight-transfer implementation changed | Pass |
| Computer activation | Direct control requires canonical presentation availability plus seated Founder mode, not transient entity availability | Pass |
| Computer round trip | `OPEN COMPUTER` opens the production Founder Computer and returning restores the Founder controls | Pass on iPhone and iPad |
| iPhone access | Workstation menu invokes existing `.phone` selection | Pass |
| iPad access | Workstation menu invokes existing `.tablet` selection | Pass |
| Server access | RealityKit callback invokes existing `.server` selection | Pass |
| Funding Board access | RealityKit callback invokes the existing Funding Board viewer | Pass |
| Access boundary | Workstation controls are hidden while Explore is active | Pass |
| Navigation isolation | No second navigation model or duplicate destination screen introduced | Pass |
| Simulation isolation | Camera and device selection remain presentation-only | Pass |
| Save compatibility | `GameStore.saveVersion == 20` contract remains green | Pass |
| Focused camera/access contracts | Founder first person, Explore third person, seated origin, display composition, free look, and navigation isolation | 6/6 passed |
| Related regression suites | Founder Garage Reality, Founder Desk Workspace, and Founder Character contracts | 255/255 passed |
| iPhone production UI | First-person controls, Computer open, Computer return, screenshot attachment | 1/1 passed |
| iPad production UI | First-person controls, Computer open, Computer return, screenshot attachment | 1/1 passed |
| iPhone visual | [iPhone 17 Pro Max first-person Founder view](FounderFirstPersonAccessCorrection/iphone-17-pro-max-founder-first-person.png) | Pass; human acceptance pending |
| iPad visual | [iPad Air 11-inch (M4) first-person Founder view](FounderFirstPersonAccessCorrection/ipad-air-11-m4-founder-first-person.png) | Pass; human acceptance pending |
| Task-scoped diff hygiene | `git diff --check` on the five source/test files | Pass |

## Test records

- Focused camera/access result bundle: `/tmp/solo-founder-perspective/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-41-22--0400.xcresult`
- iPhone production UI result bundle: `/tmp/solo-founder-perspective/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-44-29--0400.xcresult`
- Corrected legacy expectation check: `/tmp/solo-founder-perspective/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-47-48--0400.xcresult`
- Complete related regression result bundle: `/tmp/solo-founder-perspective/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-48-17--0400.xcresult`
- iPad production UI result bundle: `/tmp/solo-founder-perspective-ipad/Logs/Test/Test-Solo Unicorn Run-2026.09.20_19-48-59--0400.xcresult`
- Seated first-person focused contracts: `/tmp/solo-founder-seated-pov/Logs/Test/Test-Solo Unicorn Run-2026.09.21_04-47-03--0400.xcresult`
- Seated first-person complete related regression: `/tmp/solo-founder-seated-pov/Logs/Test/Test-Solo Unicorn Run-2026.09.21_04-51-47--0400.xcresult`
- Final corrected iPhone production UI: `/tmp/solo-founder-seated-pov/Logs/Test/Test-Solo Unicorn Run-2026.09.21_04-52-23--0400.xcresult`
- Final corrected iPad production UI: `/tmp/solo-founder-perspective-ipad/Logs/Test/Test-Solo Unicorn Run-2026.09.21_04-53-25--0400.xcresult`

## Evidence provenance

Both PNGs were exported from the successful UI-test attachment named `FOUNDER_FIRST_PERSON_WORKSTATION`. The attachment is captured after returning from the production Founder Computer, so it verifies the restored first-person controls rather than a static launch screen.

## Human gate

Simulator interaction remains a human acceptance step. Choose exactly one: `ACCEPT`, `REJECT WITH SPECIFIC CAMERA OR ACCESS DEFECT`, or `REQUEST CONTROLLED VARIANTS`.
