# Build 18 Test Report

Feed tests cover deterministic generation without RNG consumption and Statement/coverage behavior.

- `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` — PASS
- `xcodebuild ... test CODE_SIGNING_ALLOWED=NO` — PASS

Only existing duplicate-file-reference warnings were emitted.
