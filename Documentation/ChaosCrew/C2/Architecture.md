# Chaos Crew C2 — Agent Laboratory

C2 extends the accepted C1 test-side GameStore adapter, mission envelope, replay encoding, deletion minimizer and F1 exporter. Production gameplay and save version 20 are unchanged. No second simulation engine, new app source, target membership, Canon mutation or accepted Ledger mutation.

## Contracts and production seams

The version-2 AgentScenario is nested in ChaosMission. Seed, scenario identity, ordinary initial career, source fingerprint, allowed actions, applicable records/precedents and 80-action budget remain in the existing envelope. The nested profile records authored participating agents and workload/assignment/review/evidence scope with four maximum sprint commitment attempts. Choices use a separate seeded generator and public task/agent identifiers. Wall time only terminates the study; it never selects gameplay actions.

C1's original 16-action generator and v1 encoding remain intact. C2 additionally calls prepareWorkSession, beginManualWorkSession, classifyEvidence, selectSystemsReviewStep, selectCampaignOption, submitSystemsReview, submitCampaignCalibration, setAgentOperationsAllocation, applyAgentOperationsPreset, setAgentOperationalAutonomy, resolveAgentOperationalDecision, resolveReviewedTask and ordinary resetCareer/startCareer. No capability, Attention, result or finance fixture is installed. The legacy C1.1 compatibility fixture remains segregated in its existing regression test.

| Gate | Source-backed assertion |
|---|---|
| Assignment identity | GameStore.assign and syncAssignments: each agent owns at most one current task; task has one optional canonical owner |
| Stale session completion | A newly applied session outcome must belong to the current task's assigned agent; UUID alone is insufficient |
| Evidence provenance | GameStore.recordEvidence key uses venture/sprint/task/agent; session-derived fields must come from that agent |
| Workload boundary | Production profile allocations are nonnegative and sum to at most profile.capacity; rejected changes preserve profile |
| Agent metrics | sanitizeState: reliability/trust/drift within 0–100; calibration within 0–1 |
| Explicit metric causes | Assignment, preparation, session operations and allocation commands cannot themselves update agent metrics; review/resolution/sprint causes remain production-owned |
| Review accounting | review costs one Attention unless production detects a completed session; repeated/rejected review preserves metrics and Evidence |
| Attention | Rejected operations and assignments do not consume Attention; completed-session delegation charges once |
| Hidden truth | Unreviewed/incomplete Evidence cannot expose actualQuality; output uses hashes and explicitly allowlisted public labels |
| Persistence | Existing C1 full CareerSave field observer checks actual save and continueCareer, with accepted C1.1 task/cache/Evidence identity correction |
| Career isolation | Ordinary career reset clears Evidence and Work Sessions; old task references reject |
| Replay | Same source/seed/action sequence reproduces every step, ownership/Evidence/metric/session hashes and full canonical persisted fingerprints |

Mission A emphasizes repeated ownership/reassignment and both incomplete and completed stale sessions. Mission B exercises all initial agents, direct/delegated/manual reviews, resolutions and workload/autonomy decisions. Mission C begins with the existing canonical multi-agent Product Launch route, then varies agent order and uses the shared Evidence Ledger. Each mission has a distinct deterministic search salt. Mission D includes interrupted sessions, sprint commits, stale references and an ordinary new-career transition.

Each primary scenario is replayed exactly. One representative per diagnostic category and per persisted save field is minimized with the original C1 256-trial bound. The target string contains the original task/agent causal identity, so a different instance of the same category cannot satisfy deletion. Originals survive. F1 candidates are observation_only/CANDIDATE and require separate review; none are promoted. A controlled test-only provenance observer defect exercises the same oracle, minimizer, replay and F1 schema without changing gameplay.

## Safe execution

Only C1's positively identified dedicated lab 40D4F1B3-092A-4E6F-9251-7A686A734B55 may construct the adapter. Owner simulator IDs and save domains remain outside test destinations. Build checks use that iPhone lab and dedicated iPad Build Lab 37C6DF3F-87F5-4F57-A882-B4B7D11A12F5. Parallel hosted tests are disabled. No owner career or backup is erased or replaced.

Generate Tools/ChaosCrew/c2.py manifest before testing; install its sourceFingerprint in the generated xctestrun EnvironmentVariables as C1_SOURCE_FINGERPRINT. Set C11_EXPECT_REPAIRED and C11_EVIDENCE_REPAIRED for the accepted before/after regression gates. C2_FULL_STUDY=1 explicitly enables the 400-primary-scenario study; its wall ceiling is 2400 seconds. Export C1-Evidence from the dedicated app container, preserve the matching manifest, then run c2.py summarize. That command checks exact current source, replay hashes, action chains, counts and allowlists before F1 export.

## Observability and coverage limits

Raw private task results, agent metrics and CareerSave payloads are only hashed inside the lab. Public artifact checks do not establish rendered UI disclosure safety. No visual/animation work or acceptance is claimed. Lifecycle labels describe gameplay task flags, not presentation motion.

Production has no direct agent-to-agent command seam. Coordination opportunities remain unimplemented capabilities, not defects. Initial authored capabilities vary naturally through gameplay; exhaustive talent-market/low-capability fixtures and guaranteed poor/overclaim/underclaim outcomes are not claimed. Trust/reliability formulas are never invented or copied into a second evaluator. Qualitative balance expectations remain observations.

Natural venture completion, long career histories and delayed consequences are covered only where production actions reach them; ordinary career reset is a separate isolation test. Process memory is not measured. Every action and four sprint commit attempts are bounded; manual decisions use public option IDs. Invalid and unavailable operations remain legitimate observations, not automatically violations. SEARCH_EXHAUSTED remains inconclusive.
