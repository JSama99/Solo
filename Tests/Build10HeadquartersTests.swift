import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class Build10HeadquartersTests: XCTestCase {
  func testDailyStreakUsesCalendarAcrossMonthBoundary() {
    let defaults = isolatedDefaults()
    let store = DailyChallengeStore(defaults: defaults)
    store.record(score: 10, date: date(2026, 1, 31))
    store.record(score: 12, date: date(2026, 2, 1))
    XCTAssertEqual(store.save.currentStreak, 2)
  }

  func testDailyStorePersistsToInjectedDefaults() {
    let defaults = isolatedDefaults()
    DailyChallengeStore(defaults: defaults).record(score: 42, date: date(2026, 2, 28))
    XCTAssertEqual(DailyChallengeStore(defaults: defaults).save.bestScore, 42)
  }

  func testDailyStreakUsesUTCAcrossDSTBoundary() {
    let store = DailyChallengeStore(defaults: isolatedDefaults())
    store.record(score: 10, date: Date(timeIntervalSince1970: 1_773_085_200))
    store.record(score: 12, date: Date(timeIntervalSince1970: 1_773_171_600))
    XCTAssertEqual(store.save.currentStreak, 2)
  }

  func testEveryFacilityUpgradeHasADefinition() {
    XCTAssertEqual(FacilityUpgradeDefinition.all.count, FacilityUpgradeID.allCases.count)
    XCTAssertEqual(FacilityUpgradeDefinition.definitions.count, FacilityUpgradeID.allCases.count)
  }

  func testFacilityPurchaseDeductsCapitalAndPersists() {
    let defaults = isolatedDefaults()
    let progression = FounderProgressionStore(defaults: defaults, saveKey: "progress")
    progression.observe(trackRecord: 8)
    let store = GameStore()
    store.progressionStore = progression
    store.finance = CompanyFinance(cash: OperatingCostTuning.founderLoftMoveIn + 500)
    store.stats.capital = store.finance.cash
    XCTAssertEqual(store.purchaseFacility(.founderLoft), .purchased(cost: OperatingCostTuning.founderLoftMoveIn))
    XCTAssertEqual(store.stats.capital, 500)
    XCTAssertEqual(store.finance.cash, 500)
    XCTAssertTrue(FounderProgressionStore(defaults: defaults, saveKey: "progress").ownedFacilities.contains(.founderLoft))
  }

  func testInsufficientCapitalAndDuplicatePurchasesFail() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "progress")
    XCTAssertEqual(progression.upgradePurchaseResult(for: .developmentRig, availableCapital: 799), .insufficientCapital(800))
    XCTAssertEqual(progression.purchaseUpgrade(.developmentRig, availableCapital: 800), .purchased(cost: 800))
    XCTAssertEqual(progression.purchaseUpgrade(.developmentRig, availableCapital: 800), .alreadyOwned)
  }

  func testInstalledGarageUpgradesCarryForwardAcrossFacilityMoves() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "progress")
    _ = progression.purchaseUpgrade(.developmentRig, availableCapital: 800)
    XCTAssertEqual(progression.bonuses.engineeringQualityBonus, 4)
    progression.observe(trackRecord: 8)
    _ = progression.purchase(.founderLoft, availableCapital: OperatingCostTuning.founderLoftMoveIn)
    XCTAssertEqual(progression.bonuses.engineeringQualityBonus, 4)
    XCTAssertEqual(progression.bonuses.ventureEnergyBonus, 5)
    XCTAssertTrue(progression.activate(.founderGarage))
    XCTAssertEqual(progression.bonuses.engineeringQualityBonus, 4)
  }

  // MARK: - Unbuilt facility tiers now carry real payloads (P0 audit, Task 2)

  /// Each of the four formerly-placeholder tiers must contribute something no
  /// lower tier does, and those contributions accumulate.
  func testEachUnbuiltTierAddsADistinctCumulativeBonus() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "tiers")
    progression.observe(trackRecord: 40)
    for _ in 0..<5 { progression.beginCareer(); _ = progression.recordCareerCompletion(trackRecord: 40) }

    XCTAssertEqual(progression.bonuses.talentSlotBonus, 0)
    XCTAssertEqual(progression.bonuses.reviewEnergyDiscount, 0)
    XCTAssertEqual(progression.bonuses.agentXPAnyRoleMultiplier, 1)
    XCTAssertEqual(progression.bonuses.rivalPressureResistance, 0)

    _ = progression.purchase(.founderLoft, availableCapital: 100_000)
    _ = progression.purchase(.smallOffice, availableCapital: 100_000)
    XCTAssertEqual(progression.bonuses.talentSlotBonus, 1, "Small Office seats a sixth teammate")
    XCTAssertEqual(progression.bonuses.reviewEnergyDiscount, 0)

    _ = progression.purchase(.officeSuite, availableCapital: 100_000)
    XCTAssertEqual(progression.bonuses.reviewEnergyDiscount, 1, "Office Suite discounts review Energy")
    XCTAssertEqual(progression.bonuses.talentSlotBonus, 1, "…without losing the Small Office slot")

    _ = progression.purchase(.companyBuilding, availableCapital: 100_000)
    XCTAssertEqual(progression.bonuses.agentXPAnyRoleMultiplier, 1.2)

    _ = progression.purchase(.unicornHeadquarters, availableCapital: 100_000)
    XCTAssertEqual(progression.bonuses.rivalPressureResistance, 0.5)
    // Everything below still applies.
    XCTAssertEqual(progression.bonuses.talentSlotBonus, 1)
    XCTAssertEqual(progression.bonuses.reviewEnergyDiscount, 1)
    XCTAssertEqual(progression.bonuses.agentXPAnyRoleMultiplier, 1.2)
    XCTAssertEqual(progression.bonuses.ventureEnergyBonus, 5)
  }

  /// The stacking rule, pinned explicitly: the Garage equipment bonus is
  /// role-matched, the Company Building training floor is not, and owning both
  /// compounds multiplicatively rather than one overriding the other.
  func testGarageAndCompanyBuildingXPBonusesCompoundMultiplicatively() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "xp-stack")
    progression.observe(trackRecord: 40)
    for _ in 0..<5 { progression.beginCareer(); _ = progression.recordCareerCompletion(trackRecord: 40) }
    _ = progression.purchaseUpgrade(.developmentRig, availableCapital: 100_000)
    XCTAssertEqual(progression.bonuses.agentXPBonusMultiplier, 1.1)
    XCTAssertEqual(progression.bonuses.agentXPAnyRoleMultiplier, 1)

    for tier in [FacilityTier.founderLoft, .smallOffice, .officeSuite, .companyBuilding] {
      _ = progression.purchase(tier, availableCapital: 100_000)
    }
    XCTAssertEqual(progression.bonuses.agentXPBonusMultiplier, 1.1, "Garage equipment carries forward")
    XCTAssertEqual(progression.bonuses.agentXPAnyRoleMultiplier, 1.2, "Training floor applies to all work")
    // Role-matched work with both owned: 1.1 x 1.2.
    let combined = progression.bonuses.agentXPBonusMultiplier * progression.bonuses.agentXPAnyRoleMultiplier
    XCTAssertEqual(combined, 1.32, accuracy: 0.0001)
  }

  /// The Office Suite discount must never make review free, which would erase
  /// the doctrine differentiation `reviewEnergyCost` carries.
  func testReviewEnergyDiscountIsFlooredAtOneForEveryDoctrine() {
    for doctrine in FounderDoctrine.allCases {
      let base = DoctrineRules.profile(for: doctrine).reviewEnergyCost
      let discounted = max(1, base - 1)
      XCTAssertGreaterThanOrEqual(discounted, 1, "\(doctrine) review must never be free")
    }
    XCTAssertEqual(max(1, DoctrineRules.profile(for: .pure).reviewEnergyCost - 1), 1)
    XCTAssertEqual(max(1, DoctrineRules.profile(for: .trust).reviewEnergyCost - 1), 1)
    XCTAssertEqual(max(1, DoctrineRules.profile(for: .guided).reviewEnergyCost - 1), 1)
  }

  /// Every tier above the Garage carries its own escalating monthly cost, and
  /// the Loft keeps its legacy transaction ID so existing saves are not
  /// re-charged for months they already paid.
  func testEveryOccupiedTierCarriesAnEscalatingMonthlyObligation() {
    XCTAssertEqual(FacilityTier.founderGarage.monthlyObligation, 0)
    let ordered: [FacilityTier] = [.founderLoft, .smallOffice, .officeSuite, .companyBuilding, .unicornHeadquarters]
    for (earlier, later) in zip(ordered, ordered.dropFirst()) {
      XCTAssertLessThan(earlier.monthlyObligation, later.monthlyObligation,
                        "\(later.name) should cost more to run than \(earlier.name)")
    }
    XCTAssertEqual(FacilityTier.founderLoft.monthlyObligation, OperatingCostTuning.founderLoftMonthlyObligation)
    XCTAssertEqual(FacilityTier.unicornHeadquarters.monthlyObligation, 9_000)
  }

  /// The sixth slot needs real candidates, not just a widened price band.
  func testSixthSlotHasItsOwnRealCandidates() {
    let sixth = TalentBoard.candidates.filter { TalentBoard.sixthSlotPriceRange.contains($0.price) }
    XCTAssertGreaterThanOrEqual(sixth.count, 3, "The sixth slot needs a real bench")
    XCTAssertTrue(sixth.allSatisfy { !$0.pitch.isEmpty && !$0.name.isEmpty })
    XCTAssertEqual(Set(sixth.map(\.id)).count, sixth.count, "Candidate IDs must be unique")
    // No candidate may straddle two slot bands.
    for candidate in TalentBoard.candidates {
      let bands = [TalentBoard.fourthSlotPriceRange, TalentBoard.fifthSlotPriceRange, TalentBoard.sixthSlotPriceRange]
        .filter { $0.contains(candidate.price) }
      XCTAssertEqual(bands.count, 1, "\(candidate.name) should belong to exactly one slot band")
    }
    let offered = TalentBoard.candidates(for: 6, excluding: [], refresh: 0)
    XCTAssertFalse(offered.isEmpty)
    XCTAssertTrue(offered.allSatisfy { TalentBoard.sixthSlotPriceRange.contains($0.price) })
  }

  func testLateTasksAreGatedFromGarageEra() {
    let garageTasks = ContentLibrary.taskPool(for: .garage).filter { ($0.minimumEra?.rawValue ?? 0) <= VentureEra.garage.rawValue }
    XCTAssertFalse(garageTasks.contains(where: { $0.title == "Shard the Data Layer" }))
    XCTAssertTrue(ContentLibrary.taskPool(for: .scale).contains(where: { $0.title == "Shard the Data Layer" && $0.minimumEra == .scale }))
  }

  func testAgentLevelCurveAndStressBandsAreCentralized() {
    XCTAssertEqual(AgentLevel.level(forXP: 0), 1)
    XCTAssertEqual(AgentLevel.level(forXP: 100), 2)
    XCTAssertEqual(AgentLevel.level(forXP: 700), 5)
    XCTAssertEqual(AgentStressBand.band(for: 24), .focused)
    XCTAssertEqual(AgentStressBand.band(for: 25), .stable)
    XCTAssertEqual(AgentStressBand.band(for: 75), .overloaded)
    XCTAssertEqual(AgentStressBand.band(for: 90), .critical)
  }

  func testAgentProgressionMigratesFromPreBuild11AgentData() throws {
    let json = """
    {"id":"aurora","name":"Aurora","initials":"AU","role":"Research","modelFamily":"Nova-1","reliability":78,"calibration":0.72,"drift":0,"trust":62}
    """
    let agent = try JSONDecoder().decode(SoloAgent.self, from: Data(json.utf8))
    XCTAssertEqual(agent.progression.xp, 0)
    XCTAssertEqual(agent.progression.stressLevel, 0)
    XCTAssertFalse(agent.progression.ambitionCompleted)
  }

  func testGarageUpgradeAndLoftWorkforceModifiersAccumulate() {
    let progression = FounderProgressionStore(defaults: isolatedDefaults(), saveKey: "workforce")
    _ = progression.purchaseUpgrade(.developmentRig, availableCapital: 800)
    XCTAssertEqual(progression.bonuses.agentXPBonusMultiplier, 1.1)
    XCTAssertEqual(progression.bonuses.stressAccumulationMultiplier, 1)
    progression.observe(trackRecord: 8)
    _ = progression.purchase(.founderLoft, availableCapital: OperatingCostTuning.founderLoftMoveIn)
    XCTAssertEqual(progression.bonuses.agentXPBonusMultiplier, 1.1)
    XCTAssertEqual(progression.bonuses.stressAccumulationMultiplier, 0.9)
  }

  func testAgentProgressionEarnsXPAndStressFromCommittedWork() {
    let store = GameStore()
    store.startCareer(seed: 99)
    store.confirmVentureThesisIfNeeded()
    let task = store.tasks[0]
    let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents[0]
    store.assign(agentID: agent.id, to: task.id)
    if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
    let before = store.agents.first(where: { $0.id == agent.id })!.progression
    store.commitSprint()
    let after = store.agents.first(where: { $0.id == agent.id })!.progression
    XCTAssertGreaterThan(after.xp, before.xp)
    XCTAssertGreaterThanOrEqual(after.stressLevel, 0)
    XCTAssertLessThanOrEqual(after.stressLevel, 100)
  }

  func testSpecializationRequiresLevelAndLocksToOneBranch() {
    let store = GameStore()
    store.startCareer(seed: 101)
    guard let index = store.agents.firstIndex(where: { $0.id == "aurora" }) else { return XCTFail("Missing Aurora") }
    store.selectAgentPerk(.sourceTriangulation, for: "aurora")
    XCTAssertTrue(store.agents[index].progression.selectedPerks.isEmpty)
    store.agents[index].progression.xp = 100
    store.selectAgentPerk(.sourceTriangulation, for: "aurora")
    store.selectAgentPerk(.signalDetection, for: "aurora")
    XCTAssertTrue(store.agents[index].progression.selectedPerks.contains(.sourceTriangulation))
    XCTAssertFalse(store.agents[index].progression.selectedPerks.contains(.signalDetection))
  }

  private func isolatedDefaults() -> UserDefaults {
    let suite = "Build10Tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
  }
}
