# SOLO: UNICORN RUN — Build 6 Verification Report

## Verification date

August 4, 2026

## Environment

- Swift 6.2.1
- Linux x86_64
- Xcode and the iOS SDK were not available in this environment

## Completed checks

### 1. Full Swift syntax parse

All production and XCTest Swift files passed:

```sh
swiftc -frontend -parse App/*.swift Tests/*.swift
```

Result: **passed**

This catches syntax and parser errors across the complete source tree, including SwiftUI files. It does not substitute for iOS framework type-checking.

### 2. Core simulation type-check

The Foundation-only model, content, simulation, Hindsight, entitlement, facility, and presentation-mapping layers passed Swift type-checking.

Result: **passed**

### 3. Linux-adapted XCTest run

A temporary validation package copied the production Foundation-only source and all test files. Only platform-specific annotations were removed in the temporary copies:

- `import Observation`
- `@Observable`
- `@MainActor`

No gameplay, save, scoring, content, entitlement, or test assertions were changed in that harness.

Result:

```text
Executed 133 tests, with 0 failures and 0 skipped.
```

Covered areas include:

- bounded and continuous careers
- Founder Pass gating and reload behavior
- deterministic simulation
- v1–v8 save migration paths
- task and dilemma decks
- persistent company state
- task review and resolution
- Hindsight precedents
- facility progression
- presentation mappings
- RevenueCat configuration constants
- detailed scoring

### 4. Deterministic Build 6 smoke run

A custom smoke harness completed the upgraded loop, generated persistent consequences, saved and reloaded, and compared the next content sequence.

Result:

```text
BUILD6_SMOKE_OK
flags=12 obligations=2
deterministicNextDraft=Build Audit Export | Build MVP Slice | Protected Recovery Block
```

### 5. Regression defects found and corrected during validation

- Incorrect `SimulationEffects` label order
- Stale RevenueCat display-name and product expectations
- Save/reload content sequence divergence
- Continuous checkpoint bypass before paywall
- Test teardown actor isolation
- A review test that assumed every first task had an exact specialist
- Founder Pass tests that silently skipped after random career loss
- A normal two-venture career test accidentally running without Founder Pass

## Required Xcode verification

I cannot confirm a complete iOS build, SwiftUI type-check, simulator launch, RevenueCat SDK link, or App Store archive from this Linux environment.

Run on macOS:

```sh
xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  CODE_SIGNING_ALLOWED=NO test
```

Then perform:

1. Clean build folder.
2. Run all 133 tests in Xcode.
3. Launch a new bounded career.
4. Launch a free continuous career and verify checkpoint-before-paywall behavior.
5. Reload a v7/Build 5 career and verify migration.
6. Test RevenueCat with the configured Test Store or sandbox account.
7. Archive with the correct Apple Developer team before upload.

## Confidence

- **Core gameplay and persistence logic:** high, based on type-checking, deterministic smoke testing, and 133 passing adapted tests.
- **SwiftUI/iOS integration:** moderate until Xcode test and simulator verification are completed.
- **Long-run game balance:** preliminary; mechanics are now structurally stronger, but real-player telemetry is still required.
