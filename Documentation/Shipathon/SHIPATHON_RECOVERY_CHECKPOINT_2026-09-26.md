# SOLO Shipathon recovery checkpoint — 2026-09-26

## State and owner gate

Recovery checkout: `/private/tmp/solo-shipathon-recovery-s3`, branch `codex/shipathon-recovery-s4`, based on `45301e3`. The original S3 worktree was unavailable after interruption. The main checkout's unrelated changes were not edited. S2/S3 accepted production presentation remains in place. On 2026-09-26 the owner accepted S4 C2, which was promoted to the production camera path. S5 has not begun. No commit or push was made.

The accepted Founder District USDZ SHA-256 is `a30983678741ed2cb232d4b480fc4d6f3dc53878ba2bcb45fd3e2e23b90a3f10`; the accepted runtime manifest SHA-256 is `740a59e76b7dbda1c29e23d62b9be40b4e7528c980e7c84c261affb24841a5dd`. Both were verified in the recovery checkout. Save version remains 20. The regenerated Phase 9 Blender source has a different byte hash because Blender saves are nondeterministic; the exported runtime package matches exactly. Do not treat the source `.blend` as a byte-for-byte recovery of the original accepted file.

Durable S3 checkpoint: `/Users/jermainenelson/.codex/visualizations/2026/09/24/01a0d296-087e-7fa2-bcbf-fc3a0898e177/shipathon-recovery-s3-2026-09-26.tar.gz` (SHA-256 `c761879b6b1625856400957941be80b5a2a834972dc6973bfcf17bc6835aeea1`). The final accepted S4 archive preserves the recovery checkout and new production captures; its path and hash are recorded with the delivery.

## Verification performed on this recovered revision

- Focused S3 lighting variant test passed on iOS 26.5.
- Recovered S3 production Garage-to-peer route passed on iPhone 17 Pro Max, iOS 26.5; iPad Air 11-inch (M4) production key frames passed. The first iPhone UI test launch hit a busy simulator runner; reboot and rerun passed.
- Focused S4 camera policy tests passed. C2 key-frame UI test passed on iPhone 17 Pro Max and iPad Air 11-inch (M4), both iOS 26.5, with matched Shot 4, walking Shot 5, stopped Spire, restart, steering, and reverse evidence. After promotion, the no-flag production C2 key-frame test passed on iPhone 17 Pro Max (63.029 s) and iPad Air 11-inch (M4) (65.580 s). The no-flag full iPhone Garage-to-peer route passed (151.186 s), reaching `(-823.7, 8.38, 939.6)` without a blocked step.
- These Xcode test actions built the `Solo Unicorn Run` scheme. `git diff --check` passed. No project file or shared scheme was changed.
- Simulator screenshots and callback diagnostics cannot accept physical-device control feel, gait naturalness, GPU frame rate, audio, or haptics. See the [S4 camera report](SHIPATHON_S4_MOVEMENT_CAMERA_REPORT.md) and [S3 visual lock](SHIPATHON_VISUAL_LOCK.md).

## Changed-file ledger

All changed tracked paths in this checkout, including reconstructed S2/S3 work:

- `App/AtlantisRealityScene.swift`
- `App/AtlantisRealityView.swift`
- `App/AtlantisWorldPresentationModel.swift`
- `App/FounderGarageRealityScene.swift`
- `App/FounderGarageRealityView.swift`
- `App/RealityKit/Atlantis/atlantis_manifest.json`
- `App/RealityKit/Atlantis/founder_district.usdc`
- `App/RealityKit/Atlantis/founder_district.usdz`
- `App/RealityKit/Atlantis/founder_district_batched.usdc`
- `App/RealityKit/Atlantis/founder_district_batched.usdz`
- `Assets/Atlantis/Phase10/RuntimeSpike/export_manifest.json`
- `Assets/Atlantis/Phase7/FounderDistrict/Blender/Atlantis_Phase7_Masterplan.blend`
- `Assets/Atlantis/Phase7/FounderDistrict/build.py`
- `Assets/Atlantis/Phase8/CommerceDistrict/Blender/Atlantis_Phase8_Masterplan.blend`
- `Assets/Atlantis/Phase9/UnicornHeights/Blender/Atlantis_Phase9_Masterplan.blend`
- `Tests/AtlantisRuntimeTests.swift`
- `Tests/FounderCharacterContractTests.swift`
- `UITests/Build32_6_1ProductionContinuityUITests.swift`

New `Documentation/Shipathon/` contains the recovered visual lock, S2/S3/S4 reports, this checkpoint, and curated S3/S4 simulator captures and motion review. The [complete changed-file ledger](SHIPATHON_CHANGED_FILE_LEDGER_2026-09-26.txt) lists every modified or newly created path, including individual capture files. The old S4 report's links under `Captures/S4/Camera*` are historical references whose original files were lost with the previous worktree; the new `Captures/RecoveryS4-C2-*` and `Captures/S4-Production-*` references are current.
