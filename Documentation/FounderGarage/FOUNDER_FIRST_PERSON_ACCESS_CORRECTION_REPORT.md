# FOUNDER FIRST-PERSON ACCESS CORRECTION

Date: September 20, 2026  
Seated-view correction: September 21, 2026  
Status: Engineering complete; human Simulator acceptance pending

## 1. Executive result

The production RealityKit Founder Garage now has a clear two-mode camera contract:

- Founder/working mode is first-person from the canonical seated eye position.
- Explore mode is third-person, preserves existing collision and locomotion behavior, and accepts the established drag gesture for free look in any direction.

The Founder Computer can now be opened reliably from Founder mode. A seated `WORKSTATION` menu also exposes the existing iPhone, iPad, Company Server, and Funding Board destinations without introducing a second navigation authority.

## 2. Root cause

The camera controller previously used third-person observation framing for both the seated Founder state and Explore. The direct Computer action also depended on a transient scene-entity availability flag, so camera transitions could make the visible control reject an otherwise valid activation.

The production RealityKit callback surface covered the Computer, iPhone, and iPad, but did not expose direct Server or Funding Board callbacks even though both canonical destinations already existed in `FounderDeskWorkspace`.

## 3. Camera contract

`FounderGarageCameraController` now treats every non-walking navigation mode as first-person presentation. The seated camera originates at the existing canonical eye position, and the existing first-person avatar mask removes the Founder head/body obstruction without changing spatial authority.

First-person and seated state are now one enforced runtime invariant. A first-person update synchronously resolves the locomotion graph to `seatedIdle`, anchors the Founder at the canonical chair position, zeroes locomotion speed, and suppresses the complete local Founder visual. This prevents the torso or a standing/sitting transition from occupying the eye camera. Authored chair choreography remains third-person until the sitting animation reaches its seated endpoint; only then does the camera enter first person.

Entering Explore changes navigation mode to `.walking`, restores third-person presentation, and keeps the existing movement acceleration, collision resolution, gait, and desk-return behavior. The existing drag look gesture is now available while walking, allowing third-person turning without creating a second movement system.

## 4. Workstation access

The first-person Founder HUD contains:

- `OPEN COMPUTER`
- `WORKSTATION`
  - Open iPhone
  - Open iPad
  - Open Server
  - Open Funding Board

These controls are available only while the Founder is seated and not exploring. The Computer action is gated by canonical presentation availability and seated navigation state instead of the transient scene-entity flag.

Existing destination ownership is preserved:

- Computer → existing Founder Computer route
- iPhone → existing `.phone` / Tech.com route
- iPad → existing `.tablet` / Venture route
- Server → existing `.server` route
- Funding Board → existing Funding Board viewer

## 5. Architecture boundaries

- `GameStore` remains the simulation authority.
- Camera, free-look, selection, and workstation controls remain presentation state.
- No new destination screens or simulation mutations were added.
- Existing Explore collision, locomotion, and Variant B motion code were not changed.
- Save version remains `20`.
- No Founder or Garage asset bytes were changed.
- No project or shared-scheme change was required by this correction.

## 6. Accessibility

The direct Computer control and workstation menu use native SwiftUI button/menu semantics. Stable identifiers were added for the production UI contract:

- `founderGarage.openComputer`
- `founderGarage.workstationMenu`

The existing RealityKit device semantics remain intact.

## 7. Verification

- iPhone 17 Pro Max build: passed.
- Focused camera/access contracts: 6/6 passed.
- Related Garage, Desk Workspace, and Founder Character suites: 255/255 passed.
- iPhone 17 Pro Max production UI round trip: 1/1 passed.
- iPad Air 11-inch (M4) production UI round trip: 1/1 passed.
- Direct UI coverage confirms that the first-person controls appear, `OPEN COMPUTER` opens the production Founder Computer, and returning restores the controls.
- The iPhone and iPad attachments show first-person framing and both access controls without clipping.
- The September 21 iPhone attachment replaces the earlier evidence frame and confirms that no Founder torso or standing pose is visible from the seated first-person camera.

The first broad regression run exposed four assertions that still encoded the superseded third-person Founder contract. Only those test expectations were corrected; the implementation was unchanged by that correction. The complete related rerun then passed 254/254.

## 8. Visual evidence

- [iPhone 17 Pro Max first-person Founder view](FounderFirstPersonAccessCorrection/iphone-17-pro-max-founder-first-person.png)
- [iPad Air 11-inch (M4) first-person Founder view](FounderFirstPersonAccessCorrection/ipad-air-11-m4-founder-first-person.png)

## 9. Human acceptance

The current build is installed and launched on the iPhone 17 Pro Max simulator. Continue the saved Career and verify:

1. Founder View begins in first person.
2. `OPEN COMPUTER` opens the Founder Computer and returns cleanly.
3. `WORKSTATION` reaches iPhone, iPad, Server, and Funding Board.
4. `EXPLORE` changes to third person.
5. Movement and drag turning work in Explore.
6. Returning to the desk restores first-person Founder mode and workstation access.

Choose exactly one:

1. `ACCEPT`
2. `REJECT WITH SPECIFIC CAMERA OR ACCESS DEFECT`
3. `REQUEST CONTROLLED VARIANTS`

## 10. Evidence ledger

See [FOUNDER_FIRST_PERSON_ACCESS_CORRECTION_EVIDENCE_LEDGER.md](FOUNDER_FIRST_PERSON_ACCESS_CORRECTION_EVIDENCE_LEDGER.md).

## 11. Repository state

The branch was already dirty with unrelated and prior-pass work. This correction did not commit, push, reset, rebase, clean, regenerate the Xcode project, or discard any existing changes.

Task-scoped source and test files:

- `App/FounderGarageRealityView.swift`
- `App/FounderGarageRealityScene.swift`
- `App/FounderDeskWorkspace.swift`
- `Tests/FounderGarageRealityTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`

Task-scoped documentation and evidence:

- `Documentation/FounderGarage/FOUNDER_FIRST_PERSON_ACCESS_CORRECTION_REPORT.md`
- `Documentation/FounderGarage/FOUNDER_FIRST_PERSON_ACCESS_CORRECTION_EVIDENCE_LEDGER.md`
- `Documentation/FounderGarage/FounderFirstPersonAccessCorrection/`
