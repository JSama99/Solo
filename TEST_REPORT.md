# SOLO: UNICORN RUN — XCTest Report

## Final Result

- Date: August 1, 2026
- Build result: Succeeded
- Test result: Passed
- Tests passed: 25
- Tests failed: 0
- Tests skipped: 0
- Expected failures: 0
- Build warnings: 0
- Build errors: 0
- Test session duration: approximately 2.99 seconds

## Test Environment

- Simulator: iPhone 17 Pro Max
- Architecture: arm64
- iOS: 26.5 (build 23F77)
- Host: macOS 26.5.2
- Configuration: Debug
- Test target: Solo Unicorn Run Tests
- Test class: `GameStoreTests`

## Command

```shell
xcodebuild -project SoloUnicornRun.xcodeproj \
  -scheme "Solo Unicorn Run" \
  -configuration Debug \
  test CODE_SIGNING_ALLOWED=NO \
  -destination "platform=iOS Simulator,id=1E9DD15B-55DA-42A5-92F1-45F8C8AE4414"
```

## Tests Run

### Simulation progression and outcomes

- Passed — `testUnassignedSprintDoesNotAdvance`: Rejects a sprint commit when no agent is assigned.
- Passed — `testRunwayFailureEndsCareer`: Ends the career with bankruptcy when runway reaches zero.
- Passed — `testFinalSprintCompletesTwoVentureCareer`: Completes the career on Venture Two, Sprint 12.
- Passed — `testFullTwoVentureCompletion`: Completes all 24 sprints across both ventures.
- Passed — `testInvalidNumericStatesAreSanitized`: Clamps invalid founder, agent, and result values to safe finite ranges.

### Determinism and report integrity

- Passed — `testIdenticalSeedsProduceIdenticalResults`: Produces identical task results and RNG state for identical seeds.
- Passed — `testDifferentSeedsCanProduceDifferentResults`: Allows distinct seeds to produce distinct outcomes.
- Passed — `testIdenticalSeedsProduceIdenticalCompleteSimulationResults`: Produces byte-identical complete saved simulation state across 24 sprints for identical seeds.
- Passed — `testReassigningSameAgentRestoresReportWithoutAdvancingRNG`: Restores the cached report without rerolling or consuming RNG state.
- Passed — `testRelaunchCannotRerollCachedReport`: Preserves cached reports and RNG state through save and relaunch.
- Passed — `testCorrelatedFamilyFailureAffectsEveryLinkedAgent`: Applies one deterministic model-family failure to every linked assigned agent.

### Verification and disclosure

- Passed — `testActualQualityRemainsHiddenBeforeReview`: Keeps actual quality hidden until an eligible founder review.
- Passed — `testConfirmedReport`: Reveals actual quality for a confirmed report.
- Passed — `testOverclaimDetection`: Detects an overclaim and reveals the verified actual quality.
- Passed — `testEvidenceIncompleteReviewDoesNotRevealActualQuality`: Records the attempted review while keeping actual quality hidden when evidence is incomplete.
- Passed — `testReviewImprovesSpecialistForecast`: Improves calibration, reduces drift, and consumes Founder Attention and energy.

### Sprint intent integrity

- Passed — `testIntentCannotChangeAfterAssignment`: Rejects intent changes after a report-generating assignment.
- Passed — `testIntentCanChangeAfterAllAssignmentsAreCleared`: Allows intent changes after every assignment is cleared.

### Evidence Ledger integrity

- Passed — `testReviewCreatesEvidenceWithReportedAndActualValues`: Creates reviewed evidence preserving reported and verified values.
- Passed — `testLaterReviewPreservesOriginalEvidenceReport`: Updates the exact evidence record without replacing its original report.
- Passed — `testVentureTwoEvidenceCannotOverwriteVentureOneEvidence`: Keeps evidence identities isolated by venture and task instance.

### Save compatibility and migration

- Passed — `testLegacyTaskGainsTypedImpact`: Restores a typed task impact from a legacy task payload.
- Passed — `testV1CareerMigratesToVersionedSave`: Migrates a v1 career into the current versioned save.
- Passed — `testV2SaveMigratesExplicitlyToV4`: Migrates v2 simulation state into a v4 save.
- Passed — `testV3SaveMigratesExplicitlyToV4`: Migrates v3 reports, cache state, venture identity, and stable evidence identity into v4.

## Conclusion

The project built successfully and the complete XCTest suite passed. The final result bundle reported no failures, skipped tests, warnings, or build errors.
