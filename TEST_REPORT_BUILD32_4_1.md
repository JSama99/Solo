# Build 32.4.1 Test Report

Environment: Xcode iPhoneSimulator 26.5 SDK, iPhone 17 Pro Simulator.

| Pass | Command scope | Result |
| --- | --- | --- |
| Focused spatial causality | `Build32_4SpatialCausalityTests` | 26 executed, 0 failures |
| Build 32–32.4 presentation and motion | Build 32, 32.1, 32.2, 32.3, 32.4, and `GameplayMotionTests` | 103 executed, 0 failures |
| Complete XCTest suite | `Solo Unicorn Run` | 363 executed, 0 failures |
| Clean simulator build / launch | Bitrig iPhone 17 Pro | succeeded |

The counts are fresh command output from this source; no prior counts were reused.

Source-only verification also confirmed the negotiated-channel `AVAudioPCMBuffer` path in `AppSettingsStore` and all Build 32.4 source safeguards enumerated in the reconciliation report.
