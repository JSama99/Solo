import XCTest
import SwiftUI
import UIKit
@testable import Solo_Unicorn_Run

/// Controlled production-engine studies plus an explicitly guarded lab-career cohort.
final class CustomerTractionChaosStudy: XCTestCase {
  @MainActor
  func testIsolatedCareerSurvivalCohort() throws {
    // Refuse hosted GameStore mutations on any owner review device.
    guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == "3258DE0B-CF26-492B-9E65-6A56DCAE1EEC" else {
      throw XCTSkip("GameStore cohort requires the dedicated SOLO Reconstruction iPhone Lab simulator")
    }
    let strategies = ["grow", "improveProduct", "monetize", "researchMarket", "rotation", "adaptive"]
    let fixtures: [(String, ProductLaunchFixture)] = [("weakProduct", .strongMarketWeakProduct), ("mixed", .strongProductWeakGrowth), ("strong", .strongPreparation)]
    var csv = "strategy,seed,product,scenario,doctrine,cycle,customers,paying,revenue,cost,cash,runway,fit,confidence,alive,outcome\n"
    for type in ProductType.allCases { for (scenario, fixture) in fixtures { for doctrine in [FounderDoctrine.pure, .guided] { for seed in 1...2 { for strategy in strategies {
      let store = GameStore()
      store.resetCareer()
      store.selectedProductType = type
      store.selectedDoctrine = doctrine
      store.startCareer(seed: UInt64(seed))
      store.confirmVentureThesisIfNeeded()
      var operation = fixture.operation
      operation.id = "cohort-\(scenario)-\(seed)"
      operation.deterministicSeed = UInt64(seed)
      store.installProductLaunchOperationForTesting(operation)
      XCTAssertTrue(store.selectProductLaunchReleasePosture(.conservative))
      XCTAssertTrue(store.selectProductLaunchPublicPosture(.evidenceLed))
      XCTAssertTrue(store.executeProductLaunch()); XCTAssertTrue(store.resolveProductLaunch())
      var used: [ProductFocus: Int] = [:]
      for cycle in 1...12 {
        guard store.careerOutcome == nil else { break }
        let product = try XCTUnwrap(store.launchedProduct)
        let card = try XCTUnwrap(store.productTraction)
        let last = product.history.last
        let focus: ProductFocus
        switch strategy {
        case "grow": focus = .grow
        case "improveProduct": focus = .improveProduct
        case "monetize": focus = .monetize
        case "researchMarket": focus = .researchMarket
        case "rotation": focus = [.grow, .monetize, .improveProduct, .researchMarket][(cycle-1)%4]
        default:
          if card.confidence == "Low" {
            focus = product.history.suffix(3).count == 3 && product.history.suffix(3).allSatisfy { $0.focus == .researchMarket } ? .grow : .researchMarket
          }
          else if let last, last.retained + last.churned > 0, last.observedRetention < 74 { focus = .improveProduct }
          else if let last, last.activated <= last.churned { focus = .grow }
          else if store.finance.cash < 1000 { focus = .monetize }
          else { focus = [.grow, .monetize, .improveProduct, .researchMarket].min { (used[$0] ?? 0) < (used[$1] ?? 0) }! }
        }
        used[focus, default: 0] += 1
        XCTAssertTrue(store.selectProductFocus(focus, expectedCycle: product.nextCycle))
        if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
        // Shared ordinary operating policy: one assignment per agent, first available tasks;
        // remaining Attention reviews/approves work, then normal sprint commit.
        for agent in store.agents {
          if let task = store.tasks.first(where: { $0.assignedAgentID == nil }) { store.assign(agentID: agent.id, to: task.id) }
        }
        for task in store.tasks where task.assignedAgentID != nil {
          if store.attentionRemaining > 0 { store.review(taskID: task.id); store.resolveReviewedTask(taskID: task.id, choice: .approve) }
        }
        XCTAssertNil(store.commitBlockerMessage)
        store.commitSprint()
        store.finishReport()
        if store.pendingChapterMilestone != nil { store.dismissChapterMilestone() }
        let visible = try XCTUnwrap(store.productTraction)
        let period = store.launchedProduct?.history.last
        csv += [strategy,String(seed),type.rawValue,scenario,doctrine.rawValue,String(cycle),String(visible.customers),String(visible.payingCustomers),String(visible.revenue),String(period?.operatingCost ?? 0),String(store.finance.cash),String(store.stats.runway),visible.fit.rawValue,visible.confidence,store.careerOutcome == nil ? "true" : "false",store.careerOutcome?.kind.rawValue ?? "none"].joined(separator: ",") + "\n"
      }
      store.resetCareer()
    } } } } }
    let attachment = XCTAttachment(data: Data(csv.utf8), uniformTypeIdentifier: "public.comma-separated-values-text")
    attachment.name = "career-survival.csv"; attachment.lifetime = .keepAlways; add(attachment)
  }

  func testProductionBalanceStudy() throws { try runStudy(seedCount: 32) }
  func testTuningSearch() throws { try runStudy(seedCount: 4) }
  func testTuningConfirmation() throws { try runStudy(seedCount: 16) }

  private func runStudy(seedCount: Int) throws {
    let strategies = ["grow", "improveProduct", "monetize", "researchMarket", "rotation", "adaptive", "maintain", "research1Grow", "research3Grow", "improve1Grow", "improve3Grow"]
    let fixtures: [(String, ProductLaunchFixture)] = [("weakProduct", .strongMarketWeakProduct), ("mixed", .strongProductWeakGrowth), ("strong", .strongPreparation)]
    let presets: [(String, AgentOperationsPreset)] = [("balanced", .balanced), ("primary", .primary), ("safeguard", .safeguard)]
    var csv = "strategy,seed,product,scenario,capability,operations,cycle,day,focus,before,acquired,activated,churned,retained,customers,paying,revenue,cost,cash,fit,confidence,retention,researchSupport,productSupport,acquisitionSupport,retentionSupport,qualityDiagnostic,alignmentDiagnostic,valueDiagnostic,unitRevenueDiagnostic,companyAlive,companyRunway\n"
    var launches = "seed,product,scenario,launchOutcome,technical,market,auroraTruth\n"
    var count = 0
    for type in ProductType.allCases { for (scenario, fixture) in fixtures { for capability in ["low", "medium", "high"] { for (presetName, preset) in presets { for seed in 1...seedCount {
      var operation = fixture.operation
      operation.id = "chaos-\(scenario)-\(seed)"
      operation.deterministicSeed = UInt64(seed)
      operation.releasePosture = .conservative
      operation.publicPosture = .evidenceLed
      let result = try XCTUnwrap(ProductLaunchResolutionPolicy.resolve(operation))
      let initial = try XCTUnwrap(ProductTractionEngine.launched(operation: operation, result: result, type: type, day: 1))
      launches += "\(seed),\(type.rawValue),\(scenario),\(result.overall.rawValue),\(result.technicalScore),\(result.marketScore),\(operation.resolutionTruth.auroraQuality)\n"
      var agents = ContentLibrary.initialAgents
      // Valid production fields, using existing AgentOperationsFixture representative values.
      for index in agents.indices {
        if capability == "low" { agents[index].reliability = 58; agents[index].calibration = 0.48; agents[index].drift = 18 }
        if capability == "high" { agents[index].reliability = 91; agents[index].calibration = 0.92; agents[index].drift = 4 }
      }
      var operations = AgentOperationsState.balanced
      for agent in agents { var profile = operations.profile(for: agent.id); profile.applyPreset(preset); operations.update(profile) }
      let support = ProductTractionSupport(agents: agents, operations: operations, tasks: [])
      for strategy in strategies {
        var state = initial
        var finance = CompanyFinance(cash: 2500, lifetimeRevenue: 0)
        var used: [ProductFocus: Int] = [:]
        for cycle in 1...12 {
          let visible = ProductTractionEngine.presentation(state)
          let last = state.history.last // Customer observations are player-visible Evidence.
          let focus: ProductFocus?
          switch strategy {
          case "grow": focus = .grow
          case "improveProduct": focus = .improveProduct
          case "monetize": focus = .monetize
          case "researchMarket": focus = .researchMarket
          case "rotation": focus = [.grow, .monetize, .improveProduct, .researchMarket][(cycle - 1) % 4]
          case "research1Grow": focus = cycle <= 1 ? .researchMarket : .grow
          case "research3Grow": focus = cycle <= 3 ? .researchMarket : .grow
          case "improve1Grow": focus = cycle <= 1 ? .improveProduct : .grow
          case "improve3Grow": focus = cycle <= 3 ? .improveProduct : .grow
          case "adaptive":
            // Tooling-only safeguard: collect customer observations after three
            // research cycles instead of waiting indefinitely for confidence.
            if visible.confidence == "Low" {
              focus = state.history.suffix(3).count == 3 && state.history.suffix(3).allSatisfy { $0.focus == .researchMarket } ? .grow : .researchMarket
            }
            else if let last, last.retained + last.churned > 0, last.observedRetention < 74 { focus = .improveProduct }
            else if let last, last.activated <= last.churned { focus = .grow }
            else if finance.cash < 1000 { focus = .monetize }
            else { focus = [.grow, .monetize, .improveProduct, .researchMarket].min { (used[$0] ?? 0) < (used[$1] ?? 0) } }
          default: focus = nil
          }
          if let focus { used[focus, default: 0] += 1 }
          state.pendingFocus = focus
          let before = state.customers
          let day = state.nextCycleDay
          let next = try XCTUnwrap(ProductTractionEngine.step(state, day: day, support: support))
          XCTAssertEqual(next, ProductTractionEngine.step(state, day: day, support: support))
          XCTAssertNil(ProductTractionEngine.step(next, day: day, support: support))
          XCTAssertTrue((0...ProductTractionTuning.maximumCustomers).contains(next.customers))
          // Exercise production Codable without touching any career save.
          state = try JSONDecoder().decode(LaunchedProductState.self, from: JSONEncoder().encode(next))
          XCTAssertEqual(state, next)
          let period = try XCTUnwrap(state.history.last)
          let id = ProductTractionEngine.periodID(state, day: day)
          // Isolated Garage operating ledger: use production daily costs. Cash zero is NOT career death.
          for elapsed in (day - 6)...day {
            for (category, amount) in [(ExpenseCategory.aiWorkforce, agents.count * OperatingCostTuning.dailyAIWorkforcePerAgent), (.infrastructure, OperatingCostTuning.dailyInfrastructure), (.operations, OperatingCostTuning.dailyOperations)] {
              _ = finance.apply(.init(id: "\(elapsed)-\(category.rawValue)", kind: .expense, amount: amount, category: category, simulationDay: elapsed, source: "Chaos isolated operating costs", isRecurring: true, agentID: nil, headquarters: nil))
            }
          }
          let revenue = FinancialTransaction(id: id + "-revenue", kind: .revenue, amount: period.revenue, category: nil, simulationDay: day, source: "Product customers", isRecurring: true, agentID: nil, headquarters: nil)
          XCTAssertTrue(finance.apply(revenue)); XCTAssertFalse(finance.apply(revenue))
          _ = finance.apply(.init(id: id + "-focus", kind: .expense, amount: period.operatingCost, category: focus == .grow ? .growth : .operations, simulationDay: day, source: "Product focus", isRecurring: false, agentID: nil, headquarters: nil))
          let card = ProductTractionEngine.presentation(state)
          let fields = [strategy, String(seed), type.rawValue, scenario, capability, presetName, String(cycle), String(day), focus?.rawValue ?? "none", String(before), String(period.acquired), String(period.activated), String(period.churned), String(period.retained), String(period.customers), String(period.payingCustomers), String(period.revenue), String(period.operatingCost), String(finance.cash), card.fit.rawValue, card.confidence, String(period.observedRetention), String(support.research), String(support.product), String(support.acquisition), String(support.retention), String(state.quality), String(state.problemAlignment), String(state.priceValue), String(state.revenuePerCustomer), "NA", "NA"]
          csv += fields.joined(separator: ",") + "\n"
        }
        count += 1
      }
    } } } } }
    XCTAssertEqual(count, 4 * 3 * 3 * 3 * seedCount * strategies.count)
    for (name, contents) in [("traction-cycles.csv", csv), ("launches.csv", launches)] {
      let attachment = XCTAttachment(data: Data(contents.utf8), uniformTypeIdentifier: "public.comma-separated-values-text")
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
  }
}

final class CompanyFinanceTests: XCTestCase {
  func testRevenueAndCapitalRaisedRemainDistinct() {
    var finance = CompanyFinance(cash: 100, capitalRaised: 100, lifetimeRevenue: 0)
    XCTAssertTrue(finance.apply(.init(id: "fund", kind: .capitalRaised, amount: 500, category: nil, simulationDay: 1, source: "Seed", isRecurring: false, agentID: nil, headquarters: nil)))
    XCTAssertTrue(finance.apply(.init(id: "sale", kind: .revenue, amount: 75, category: nil, simulationDay: 1, source: "Customer", isRecurring: false, agentID: nil, headquarters: nil)))
    XCTAssertEqual(finance.cash, 675)
    XCTAssertEqual(finance.capitalRaised, 600)
    XCTAssertEqual(finance.lifetimeRevenue, 75)
  }

  func testTransactionIdentityPreventsDuplicateCharge() {
    var finance = CompanyFinance(cash: 100)
    let charge = FinancialTransaction(id: "assignment-1", kind: .expense, amount: 29, category: .aiWorkforce, simulationDay: 1, source: "Aurora scan", isRecurring: false, agentID: "aurora", headquarters: nil)
    XCTAssertTrue(finance.apply(charge))
    XCTAssertFalse(finance.apply(charge))
    XCTAssertEqual(finance.cash, 71)
  }

  func testCalendarAdvancesAcrossDaysAndPeriods() {
    var calendar = OperatingCalendar(totalDays: 1, dayOfSprint: 6, hour: 20)
    calendar.advance(hours: 8)
    XCTAssertEqual(calendar.totalDays, 2)
    XCTAssertEqual(calendar.dayOfSprint, 7)
    XCTAssertEqual(calendar.period, .night)
  }

  func testRunwayIsFiniteForLossMakingCompany() {
    var finance = CompanyFinance(cash: 1_000)
    XCTAssertTrue(finance.apply(.init(id: "hosting", kind: .expense, amount: 200, category: .infrastructure, simulationDay: 1, source: "Hosting", isRecurring: true, agentID: nil, headquarters: nil)))
    XCTAssertEqual(finance.runwayLabel(fallbackDailyBurn: 100), "4 days")
  }

  func testPositiveCashFlowDoesNotProduceInfiniteRunway() {
    var finance = CompanyFinance(cash: 1_000)
    XCTAssertTrue(finance.apply(.init(id: "sale", kind: .revenue, amount: 400, category: nil, simulationDay: 1, source: "Customer", isRecurring: false, agentID: nil, headquarters: nil)))
    XCTAssertEqual(finance.runwayLabel(fallbackDailyBurn: 0), "Cash-flow positive")
  }

  func testLegacyFinanceDecodesWithEmptyFundingApplications() throws {
    let legacy = """
    {
      "cash": 900,
      "capitalRaised": 1200,
      "lifetimeRevenue": 300,
      "revenueToday": 0,
      "revenueThisSprint": 0,
      "transactions": [],
      "appliedTransactionIDs": []
    }
    """
    let finance = try JSONDecoder().decode(CompanyFinance.self, from: Data(legacy.utf8))
    XCTAssertEqual(finance.cash, 900)
    XCTAssertTrue(finance.fundingApplications.isEmpty)
    XCTAssertTrue(finance.expiredFundingOpportunityIDs.isEmpty)
  }

  func testFundingApplicationLifecycleIsStableAndIdempotent() {
    var finance = CompanyFinance()
    XCTAssertTrue(finance.beginFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 1))
    XCTAssertFalse(finance.beginFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 1))
    XCTAssertEqual(finance.fundingApplications.first?.status, .pursuing)
    XCTAssertTrue(finance.resolveFundingApplication(
      opportunityID: "pioneer-ai-grant",
      careerSprint: 2,
      outcome: .awarded,
      reason: "Every visible requirement remained met."
    ))
    XCTAssertFalse(finance.resolveFundingApplication(
      opportunityID: "pioneer-ai-grant",
      careerSprint: 2,
      outcome: .awarded,
      reason: "Duplicate"
    ))
    XCTAssertEqual(finance.fundingApplications.first?.status, .resolved)
    XCTAssertEqual(finance.fundingApplications.first?.outcome, .awarded)
  }

  func testFundingBoardUsesOnlyVisibleMetricsAndFixedCareerWindows() throws {
    let snapshot = FundingBoardSnapshot(
      revenue: 500,
      trust: 68,
      momentum: 18,
      coverage: 0,
      venture: 1,
      evidenceCount: 0,
      careerSprint: 1,
      attentionRemaining: 2
    )
    let first = FundingBoardEngine.presentations(snapshot: snapshot, applications: [])
    let second = FundingBoardEngine.presentations(snapshot: snapshot, applications: [])
    XCTAssertEqual(first, second)
    XCTAssertEqual(try XCTUnwrap(first.first(where: { $0.id == "pioneer-ai-grant" })).status, .eligible)
    XCTAssertEqual(try XCTUnwrap(first.first(where: { $0.id == "garage-innovation-fund" })).status, .locked)

    var late = snapshot
    late.careerSprint = 9
    XCTAssertEqual(
      try XCTUnwrap(FundingBoardEngine.presentations(snapshot: late, applications: []).first(where: { $0.id == "garage-innovation-fund" })).status,
      .expired
    )
  }

  func testTerminalExpirationPersistsAndPreventsLaterApplication() throws {
    var finance = CompanyFinance()
    XCTAssertTrue(finance.expireFundingOpportunity(opportunityID: "pioneer-ai-grant"))
    XCTAssertFalse(finance.expireFundingOpportunity(opportunityID: "pioneer-ai-grant"))
    XCTAssertFalse(finance.beginFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 9))

    let decoded = try JSONDecoder().decode(CompanyFinance.self, from: JSONEncoder().encode(finance))
    XCTAssertTrue(decoded.expiredFundingOpportunityIDs.contains("pioneer-ai-grant"))
    let snapshot = FundingBoardSnapshot(
      revenue: 99_000,
      trust: 100,
      momentum: 100,
      coverage: 100,
      venture: 8,
      evidenceCount: 100,
      careerSprint: 9,
      attentionRemaining: 3
    )
    let presentation = try XCTUnwrap(FundingBoardEngine.presentations(
      snapshot: snapshot,
      applications: decoded.fundingApplications,
      expiredOpportunityIDs: decoded.expiredFundingOpportunityIDs
    ).first(where: { $0.id == "pioneer-ai-grant" }))
    XCTAssertEqual(presentation.status, .expired)
  }

  func testDeadlinePresentationUsesRemainingCanonicalSprints() throws {
    let snapshot = FundingBoardSnapshot(
      revenue: 500,
      trust: 68,
      momentum: 18,
      coverage: 0,
      venture: 1,
      evidenceCount: 0,
      careerSprint: 2,
      attentionRemaining: 2
    )
    let opportunity = try XCTUnwrap(FundingBoardEngine.presentations(
      snapshot: snapshot,
      applications: []
    ).first(where: { $0.id == "pioneer-ai-grant" }))
    XCTAssertEqual(opportunity.deadlineRemainingLabel, "Deadline: 2 sprints")
  }

  func testLegacyResolvedApplicationRemainsSuccessfulWithoutExplicitOutcome() throws {
    let application = FundingApplicationRecord(
      opportunityID: "pioneer-ai-grant",
      status: .resolved,
      appliedCareerSprint: 1,
      resolvedCareerSprint: 2
    )
    let decoded = try JSONDecoder().decode(
      FundingApplicationRecord.self,
      from: JSONEncoder().encode(application)
    )
    let snapshot = FundingBoardSnapshot(
      revenue: 0,
      trust: 0,
      momentum: 0,
      coverage: 0,
      venture: 1,
      evidenceCount: 0,
      careerSprint: 2,
      attentionRemaining: 0
    )
    let presentation = try XCTUnwrap(FundingBoardEngine.presentations(
      snapshot: snapshot,
      applications: [decoded]
    ).first(where: { $0.id == application.opportunityID }))
    XCTAssertEqual(presentation.status, .awarded)
  }

  func testFundingMilestoneResolvesExactlyOnceAndSurvivesCoding() throws {
    let obligation = FundingMilestoneObligation(
      metric: .revenue,
      target: 6_000,
      createdCareerSprint: 7,
      dueCareerSprint: 11,
      missedTrustConsequence: 6,
      status: .active,
      resolvedCareerSprint: nil
    )
    var finance = CompanyFinance(fundingApplications: [FundingApplicationRecord(
      opportunityID: "founder-conviction-round",
      status: .resolved,
      appliedCareerSprint: 6,
      resolvedCareerSprint: 7,
      outcome: .funded,
      outcomeReason: "Visible requirements remained met.",
      milestoneObligation: obligation
    )])
    XCTAssertTrue(finance.resolveFundingMilestone(
      opportunityID: "founder-conviction-round",
      status: .met,
      careerSprint: 9
    ))
    XCTAssertFalse(finance.resolveFundingMilestone(
      opportunityID: "founder-conviction-round",
      status: .missed,
      careerSprint: 11
    ))
    let decoded = try JSONDecoder().decode(CompanyFinance.self, from: JSONEncoder().encode(finance))
    XCTAssertEqual(decoded.fundingApplications.first?.milestoneObligation?.status, .met)
    XCTAssertEqual(decoded.fundingApplications.first?.milestoneObligation?.resolvedCareerSprint, 9)
  }

  func testPursuingOpportunityBecomesResolvableOnlyAfterNextSprint() throws {
    let application = FundingApplicationRecord(
      opportunityID: "pioneer-ai-grant",
      status: .pursuing,
      appliedCareerSprint: 1,
      resolvedCareerSprint: nil
    )
    var snapshot = FundingBoardSnapshot(
      revenue: 500,
      trust: 68,
      momentum: 18,
      coverage: 0,
      venture: 1,
      evidenceCount: 0,
      careerSprint: 1,
      attentionRemaining: 1
    )
    let sameSprint = try XCTUnwrap(FundingBoardEngine.presentations(snapshot: snapshot, applications: [application]).first)
    XCTAssertEqual(sameSprint.status, .pursuing)
    XCTAssertFalse(sameSprint.canResolve)
    snapshot.careerSprint = 2
    let nextSprint = try XCTUnwrap(FundingBoardEngine.presentations(snapshot: snapshot, applications: [application]).first)
    XCTAssertTrue(nextSprint.canResolve)
  }
}

@MainActor
final class ProductTractionTests: XCTestCase {
  func testCaptureNewProductCardAtStandardAndAccessibilitySizes() throws {
    var state = try product()
    for _ in 0..<3 {
      state.pendingFocus = .researchMarket
      state = try XCTUnwrap(ProductTractionEngine.step(state, day: state.nextCycleDay, support: support))
    }
    let width: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 780 : 398
    for accessibility in [false, true] {
      let card = ProductTractionCard(product: ProductTractionEngine.presentation(state),
        attentionRemaining: 1, canChoose: true, onFocus: { _ in })
        .environment(\.dynamicTypeSize, accessibility ? .accessibility3 : .large)
        .environment(\.colorScheme, .dark)
        .frame(width: width).fixedSize(horizontal: false, vertical: true)
        .padding(16).background(SoloTheme.background)
      let renderer = ImageRenderer(content: card)
      renderer.scale = 2
      let image = try XCTUnwrap(renderer.uiImage)
      let attachment = XCTAttachment(image: image)
      attachment.name = "ProductTraction-\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")-\(accessibility ? "Accessibility" : "Normal")"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    for key in GameStore.resetCareerPurgeKeys { UserDefaults.standard.removeObject(forKey: key) }
    super.tearDown()
  }

  private let support = ProductTractionSupport(research: 60, product: 60, acquisition: 60, retention: 20)

  private func product() throws -> LaunchedProductState {
    var operation = ProductLaunchFixture.strongPreparation.operation
    operation.releasePosture = .conservative
    operation.publicPosture = .evidenceLed
    let result = try XCTUnwrap(ProductLaunchResolutionPolicy.resolve(operation))
    return try XCTUnwrap(ProductTractionEngine.launched(operation: operation, result: result, type: .saas, day: 1))
  }

  private func launchedStore() throws -> GameStore {
    let store = GameStore()
    store.resetCareer()
    store.startCareer(seed: 48_101)
    store.confirmVentureThesisIfNeeded()
    store.installProductLaunchOperationForTesting(ProductLaunchFixture.strongPreparation.operation)
    XCTAssertTrue(store.selectProductLaunchReleasePosture(.conservative))
    XCTAssertTrue(store.selectProductLaunchPublicPosture(.evidenceLed))
    XCTAssertTrue(store.executeProductLaunch())
    XCTAssertTrue(store.resolveProductLaunch())
    XCTAssertNotNil(store.launchedProduct)
    return store
  }

  func testSameSeedAndDecisionsProduceIdenticalBoundedHistory() throws {
    var first = try product()
    var second = first
    for cycle in 1...24 {
      let focus = ProductFocus.allCases[(cycle - 1) % 4]
      first.pendingFocus = focus; second.pendingFocus = focus
      first = try XCTUnwrap(ProductTractionEngine.step(first, day: first.nextCycleDay, support: support))
      second = try XCTUnwrap(ProductTractionEngine.step(second, day: second.nextCycleDay, support: support))
      XCTAssertEqual(first, second)
      XCTAssertLessThanOrEqual(first.history.count, ProductTractionTuning.historyLimit)
    }
  }

  private func observedPeriod(_ cycle: Int, retained: Int, churned: Int,
                              activated: Int = 30, paying: Int = 70) -> ProductTractionPeriod {
    .init(cycle: cycle, day: cycle * 7 + 1, focus: nil, acquired: activated,
      activated: activated, churned: churned, retained: retained,
      customers: retained + activated, payingCustomers: paying, revenue: paying * 12,
      operatingCost: 0, observedRetention: retained + churned == 0 ? 0 : retained * 100 / (retained + churned))
  }

  func testFitWeightsReturningCustomerExposureRatherThanCyclePercentages() throws {
    var state = try product(); state.completedCycles = 2; state.researchCycles = 2
    state.history = [observedPeriod(1, retained: 0, churned: 1, activated: 100),
                     observedPeriod(2, retained: 90, churned: 10)]
    let card = ProductTractionEngine.presentation(state)
    XCTAssertEqual(card.fit, .strong) // 90 / 101 = 89%; equal-period averaging was 45%.
    XCTAssertTrue(card.observation.contains("89% across 101"))
    XCTAssertEqual(card.confidence, "Moderate")
  }

  func testOwnerObservedHistoryBecomesPromisingButRemainsLowConfidence() throws {
    var state = try product(); state.completedCycles = 3; state.researchCycles = 2
    state.history = [observedPeriod(2, retained: 0, churned: 1, activated: 16, paying: 8),
                     observedPeriod(3, retained: 13, churned: 3, activated: 17, paying: 16)]
    XCTAssertEqual(ProductTractionEngine.presentation(state).fit, .promising)
    XCTAssertEqual(ProductTractionEngine.presentation(state).confidence, "Low")
  }

  func testEqualExposureMatchesMeanAndGrowthCannotFabricateHealthyFit() throws {
    var state = try product(); state.completedCycles = 2
    state.history = [observedPeriod(1, retained: 75, churned: 25), observedPeriod(2, retained: 85, churned: 15)]
    XCTAssertEqual(ProductTractionEngine.presentation(state).fit, .promising)
    XCTAssertTrue(ProductTractionEngine.presentation(state).observation.contains("80% across 200"))
    state.history = [observedPeriod(1, retained: 50, churned: 50, activated: 200), observedPeriod(2, retained: 50, churned: 50, activated: 200)]
    XCTAssertEqual(ProductTractionEngine.presentation(state).fit, .weak)
    state.history = [observedPeriod(1, retained: 50, churned: 50, activated: 1), observedPeriod(2, retained: 50, churned: 50, activated: 1)]
    XCTAssertEqual(ProductTractionEngine.presentation(state).fit, .declining)
  }

  func testFitRecomputationDoesNotRewriteSavedHistoryOrConsultHiddenTruth() throws {
    var state = try product(); state.completedCycles = 2
    state.history = [observedPeriod(1, retained: 0, churned: 1), observedPeriod(2, retained: 90, churned: 10)]
    let encoded = try JSONEncoder().encode(state)
    let history = state.history; let visible = ProductTractionEngine.presentation(state)
    state.quality = 0; state.problemAlignment = 0; state.priceValue = 0
    XCTAssertEqual(ProductTractionEngine.presentation(state), visible)
    XCTAssertEqual(state.history, history)
    let legacy = try JSONDecoder().decode(LaunchedProductState.self, from: encoded)
    XCTAssertEqual(legacy.history, history)
    XCTAssertEqual(ProductTractionEngine.presentation(legacy), visible)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testSubIntegerResearchEffortAccumulatesAndZeroSupportDoesNot() throws {
    for effort in 0...14 {
      var state = try product(); state.problemAlignment = 10
      for _ in 0..<30 {
        state.pendingFocus = .researchMarket
        let previous = state
        state = try XCTUnwrap(ProductTractionEngine.step(previous, day: previous.nextCycleDay,
          support: .init(research: effort, product: 0, acquisition: 0, retention: 0)))
        XCTAssertEqual(state, ProductTractionEngine.step(previous, day: previous.nextCycleDay,
          support: .init(research: effort, product: 0, acquisition: 0, retention: 0)))
        XCTAssertEqual(state.history.last?.operatingCost, 18)
      }
      XCTAssertEqual(state.problemAlignment, 10 + effort * 2)
      XCTAssertEqual(state.researchCycles, effort == 0 ? 0 : 30)
    }
    let absent = ProductTractionSupport(agents: [], operations: .balanced, tasks: [])
    XCTAssertEqual(absent.research, 0)
  }

  func testResearchCapabilityRemainsMeaningfulAndAcquisitionSacrificePersists() throws {
    var low = try product(); low.problemAlignment = 10
    var high = low
    for _ in 0..<15 {
      low.pendingFocus = .researchMarket; high.pendingFocus = .researchMarket
      low = try XCTUnwrap(ProductTractionEngine.step(low, day: low.nextCycleDay,
        support: .init(research: 4, product: 0, acquisition: 30, retention: 0)))
      high = try XCTUnwrap(ProductTractionEngine.step(high, day: high.nextCycleDay,
        support: .init(research: 60, product: 0, acquisition: 30, retention: 0)))
    }
    XCTAssertEqual(low.problemAlignment, 14); XCTAssertEqual(high.problemAlignment, 70)
    var research = try product(); var grow = research
    research.pendingFocus = .researchMarket; grow.pendingFocus = .grow
    let researched = try XCTUnwrap(ProductTractionEngine.step(research, day: research.nextCycleDay, support: support))
    let grown = try XCTUnwrap(ProductTractionEngine.step(grow, day: grow.nextCycleDay, support: support))
    XCTAssertLessThan(researched.history.last!.acquired, grown.history.last!.acquired)
  }

  func testResearchCarriesExactChangingEffortAcrossLegacyDecodeAndReload() throws {
    let initial = try product()
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(initial)) as? [String: Any])
    object.removeValue(forKey: "researchEffortRemainder")
    var state = try JSONDecoder().decode(LaunchedProductState.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(state.researchEffortRemainder)
    state.problemAlignment = 10
    var effortTotal = 0
    for effort in [1, 8, 0, 5, 2, 0, 14, 1, 7] {
      state.pendingFocus = .researchMarket
      state = try XCTUnwrap(ProductTractionEngine.step(state, day: state.nextCycleDay,
        support: .init(research: effort, product: 0, acquisition: 0, retention: 0)))
      effortTotal += effort
      XCTAssertEqual(state.problemAlignment, 10 + effortTotal / 15)
      XCTAssertEqual(state.researchEffortRemainder ?? 0, effortTotal % 15)
      state = try JSONDecoder().decode(LaunchedProductState.self, from: JSONEncoder().encode(state))
    }
  }

  func testRecentGrowthLosesBonusWithoutBuyingRetentionAndRecoversAfterOtherWork() throws {
    var repeated = try product()
    for _ in 0..<3 {
      repeated.pendingFocus = .grow
      repeated = try XCTUnwrap(ProductTractionEngine.step(repeated, day: repeated.nextCycleDay, support: support))
    }
    repeated.pendingFocus = .grow
    var fresh = repeated; fresh.history = []
    let fourth = try XCTUnwrap(ProductTractionEngine.step(repeated, day: repeated.nextCycleDay, support: support))
    let freshResult = try XCTUnwrap(ProductTractionEngine.step(fresh, day: fresh.nextCycleDay, support: support))
    XCTAssertLessThan(fourth.history.last!.acquired, freshResult.history.last!.acquired)
    XCTAssertEqual(fourth.history.last!.observedRetention, freshResult.history.last!.observedRetention)
    XCTAssertEqual(fourth.quality, repeated.quality)
    // The saved observed history is the cooldown authority, not a new cursor.
    let restored = try JSONDecoder().decode(LaunchedProductState.self, from: JSONEncoder().encode(repeated))
    XCTAssertEqual(ProductTractionEngine.step(restored, day: restored.nextCycleDay, support: support), fourth)
    var rested = fourth
    for _ in 0..<3 {
      rested = try XCTUnwrap(ProductTractionEngine.step(rested, day: rested.nextCycleDay, support: support))
    }
    rested.pendingFocus = .grow
    var withoutHistory = rested; withoutHistory.history = []
    XCTAssertEqual(ProductTractionEngine.step(rested, day: rested.nextCycleDay, support: support)?.history.last?.acquired,
      ProductTractionEngine.step(withoutHistory, day: withoutHistory.nextCycleDay, support: support)?.history.last?.acquired)
  }

  func testFocusChoicesMateriallyChangeCustomersRetentionEvidenceAndRevenue() throws {
    var base = try product(); base.customers = 200; base.quality = 55; base.priceValue = 70
    var outputs: [ProductFocus: LaunchedProductState] = [:]
    for focus in ProductFocus.allCases {
      var input = base; input.pendingFocus = focus
      outputs[focus] = try XCTUnwrap(ProductTractionEngine.step(input, day: input.nextCycleDay, support: support))
    }
    let grow = try XCTUnwrap(outputs[.grow]?.history.last)
    let improve = try XCTUnwrap(outputs[.improveProduct]?.history.last)
    XCTAssertGreaterThan(grow.acquired, improve.acquired)
    XCTAssertGreaterThan(improve.observedRetention, grow.observedRetention)
    XCTAssertGreaterThan(grow.operatingCost, improve.operatingCost)
    XCTAssertEqual(outputs[.researchMarket]?.researchCycles, 1)
    XCTAssertGreaterThan(try XCTUnwrap(outputs[.monetize]).revenuePerCustomer, base.revenuePerCustomer)
    XCTAssertLessThan(try XCTUnwrap(outputs[.monetize]).priceValue, base.priceValue)
  }

  func testMarketingCannotChangeWeakRetentionOrFabricateFit() throws {
    var weak = try product(); weak.customers = 1_000
    weak.quality = 15; weak.problemAlignment = 15; weak.priceValue = 15
    var market = weak; market.pendingFocus = .grow
    let grown = try XCTUnwrap(ProductTractionEngine.step(market, day: market.nextCycleDay, support: support))
    let baseline = try XCTUnwrap(ProductTractionEngine.step(weak, day: weak.nextCycleDay, support: support))
    XCTAssertEqual(grown.quality, weak.quality)
    XCTAssertEqual(grown.history.last?.observedRetention, baseline.history.last?.observedRetention)
    XCTAssertLessThan(grown.customers, weak.customers)
    XCTAssertGreaterThan(grown.history.last?.churned ?? 0, 0)
    for _ in 0..<4 {
      market.pendingFocus = .grow
      market = try XCTUnwrap(ProductTractionEngine.step(market, day: market.nextCycleDay, support: support))
    }
    XCTAssertEqual(ProductTractionEngine.presentation(market).fit, .declining)
  }

  func testStrongProductRetainsBetterButZeroGrowthDoesNotAcquireUnlimitedCustomers() throws {
    var weak = try product(); weak.customers = 100; weak.quality = 10; weak.problemAlignment = 20; weak.priceValue = 20
    var strong = weak; strong.quality = 95; strong.problemAlignment = 95; strong.priceValue = 95
    let inactive = ProductTractionSupport(research: 0, product: 0, acquisition: 0, retention: 0)
    let weakResult = try XCTUnwrap(ProductTractionEngine.step(weak, day: weak.nextCycleDay, support: inactive))
    let strongResult = try XCTUnwrap(ProductTractionEngine.step(strong, day: strong.nextCycleDay, support: inactive))
    XCTAssertGreaterThan(strongResult.history.last?.retained ?? 0, weakResult.history.last?.retained ?? 0)
    for _ in 0..<100 { strong = try XCTUnwrap(ProductTractionEngine.step(strong, day: strong.nextCycleDay, support: inactive)) }
    XCTAssertLessThan(strong.customers, 100)
  }

  func testStepEligibleExactlyOnceAndWrongDaysCannotResolve() throws {
    let input = try product()
    XCTAssertNil(ProductTractionEngine.step(input, day: input.nextCycleDay - 1, support: support))
    let next = try XCTUnwrap(ProductTractionEngine.step(input, day: input.nextCycleDay, support: support))
    XCTAssertNil(ProductTractionEngine.step(next, day: input.nextCycleDay, support: support))
    XCTAssertNil(ProductTractionEngine.step(next, day: next.nextCycleDay + 1, support: support))
  }

  func testQualifyingOutcomesAndRepeatedLaunchCannotReplaceCanonicalProduct() throws {
    var operation = ProductLaunchFixture.strongPreparation.operation
    operation.releasePosture = .conservative; operation.publicPosture = .evidenceLed
    var result = try XCTUnwrap(ProductLaunchResolutionPolicy.resolve(operation))
    for outcome in ProductLaunchOutcomeClass.allCases {
      result.overall = outcome
      XCTAssertEqual(ProductTractionEngine.launched(operation: operation, result: result, type: .saas, day: 1) != nil,
        [.mixed, .strong, .breakout].contains(outcome))
    }
    let store = try launchedStore()
    let first = store.launchedProduct
    XCTAssertFalse(store.resolveProductLaunch())
    XCTAssertTrue(store.finishProductLaunchPresentation())
    XCTAssertEqual(store.launchedProduct, first)
    store.installProductLaunchOperationForTesting(operation)
    XCTAssertTrue(store.selectProductLaunchReleasePosture(.conservative))
    XCTAssertTrue(store.selectProductLaunchPublicPosture(.evidenceLed))
    XCTAssertTrue(store.executeProductLaunch())
    XCTAssertTrue(store.resolveProductLaunch())
    XCTAssertEqual(store.launchedProduct, first)
  }

  func testFocusRapidTapsAndStaleCycleCannotChargeTwice() throws {
    let store = try launchedStore()
    let attention = store.attentionRemaining
    XCTAssertTrue(store.selectProductFocus(.grow, expectedCycle: 1))
    XCTAssertFalse(store.selectProductFocus(.monetize, expectedCycle: 1))
    XCTAssertFalse(store.selectProductFocus(.grow, expectedCycle: 0))
    XCTAssertEqual(store.attentionRemaining, attention - 1)
    store.advanceOperatingTime(hours: 168)
    XCTAssertFalse(store.selectProductFocus(.grow, expectedCycle: 1))
    XCTAssertEqual(store.launchedProduct?.completedCycles, 1)
    XCTAssertNil(store.launchedProduct?.pendingFocus)
  }

  func testCalendarChunkingAndStableFinanceIDsApplyRevenueExactlyOnce() throws {
    let store = try launchedStore()
    let initial = store.launchedProduct
    let lifetime = store.finance.lifetimeRevenue
    let statsRevenue = store.stats.revenue
    let rng = store.randomNumberGenerator
    let media = store.publicMediaEvents
    store.advanceOperatingTime(hours: 168)
    let after = try XCTUnwrap(store.launchedProduct)
    let cycle = try XCTUnwrap(after.history.last)
    XCTAssertEqual(store.finance.lifetimeRevenue, lifetime + cycle.revenue)
    XCTAssertEqual(store.stats.revenue, statsRevenue + cycle.revenue)
    let revenue = try XCTUnwrap(store.finance.transactions.first(where: { $0.id == "\(after.id)-day-\(cycle.day)-revenue" }))
    XCTAssertTrue(revenue.isRecurring)
    XCTAssertEqual(revenue.simulationDay, cycle.day)
    XCTAssertFalse(store.finance.apply(revenue))
    store.advanceOperatingTime(hours: 0)
    store.advanceOperatingTime(hours: -24)
    XCTAssertEqual(store.launchedProduct, after)
    XCTAssertEqual(store.randomNumberGenerator, rng)
    XCTAssertEqual(store.publicMediaEvents, media)
    let split = try launchedStore()
    XCTAssertEqual(split.launchedProduct, initial)
    for _ in 0..<7 { split.advanceOperatingTime(hours: 24) }
    XCTAssertEqual(split.launchedProduct, after)
  }

  func testMultiplePeriodsResolveChronologicallyWithOneRevenuePerPeriod() throws {
    let store = try launchedStore()
    store.advanceOperatingTime(hours: 3 * 168)
    XCTAssertEqual(store.launchedProduct?.completedCycles, 3)
    let days = try XCTUnwrap(store.launchedProduct).history.map(\.day)
    XCTAssertEqual(days, [8, 15, 22])
    let revenue = store.finance.transactions.filter { $0.source.hasPrefix("Product customers") }
    XCTAssertEqual(revenue.count, 3)
    XCTAssertEqual(revenue.map(\.simulationDay), days)
    XCTAssertEqual(Set(revenue.map(\.id)).count, 3)
  }

  func testSaveReloadContinuesIdenticallyAndOldVersion20HasNoInventedProduct() throws {
    let original = try launchedStore()
    XCTAssertTrue(original.selectProductFocus(.researchMarket, expectedCycle: 1))
    original.advanceOperatingTime(hours: 168)
    XCTAssertTrue(original.selectProductFocus(.improveProduct, expectedCycle: 2))
    let saved = try XCTUnwrap(UserDefaults.standard.data(forKey: GameStore.saveKey))
    let restored = GameStore(); restored.continueCareer()
    XCTAssertEqual(restored.launchedProduct, original.launchedProduct)
    original.advanceOperatingTime(hours: 168)
    restored.advanceOperatingTime(hours: 168)
    XCTAssertEqual(restored.launchedProduct, original.launchedProduct)
    XCTAssertEqual(restored.finance, original.finance)
    XCTAssertEqual(restored.randomNumberGenerator, original.randomNumberGenerator)
    var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
    var career = try XCTUnwrap(envelope["career"] as? [String: Any])
    career.removeValue(forKey: "launchedProduct")
    envelope["career"] = career
    UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: envelope), forKey: GameStore.saveKey)
    let legacy = GameStore(); legacy.continueCareer()
    XCTAssertNil(legacy.launchedProduct)
    XCTAssertNotNil(legacy.productLaunchOperation?.result)
    XCTAssertEqual(GameStore.saveVersion, 20)
  }

  func testObservedFitAndEvidenceNeverExposeHiddenQualityOrMarketScores() throws {
    let store = try launchedStore()
    store.advanceOperatingTime(hours: 3 * 168)
    let visible = try XCTUnwrap(store.productTraction)
    let labels = Set(Mirror(reflecting: visible).children.compactMap(\.label))
    XCTAssertFalse(labels.contains("quality")); XCTAssertFalse(labels.contains("problemAlignment"))
    XCTAssertFalse(labels.contains("priceValue")); XCTAssertFalse(labels.contains("seed"))
    let observation = try XCTUnwrap(store.evidence.first(where: { $0.productObservation != nil }))
    XCTAssertNil(observation.actualQuality)
    XCTAssertFalse(observation.evidenceVerified)
    XCTAssertEqual(observation.verificationState, .reported)
    XCTAssertFalse(observation.note.contains("quality"))
    let encoded = try JSONEncoder().encode(observation)
    let decoded = try JSONDecoder().decode(EvidenceEntry.self, from: encoded)
    XCTAssertEqual(decoded.productObservation, observation.productObservation)
    XCTAssertEqual(decoded.id, observation.id)
    var hiddenChanged = try XCTUnwrap(store.launchedProduct)
    hiddenChanged.quality = 0; hiddenChanged.problemAlignment = 0; hiddenChanged.priceValue = 0
    XCTAssertEqual(ProductTractionEngine.presentation(hiddenChanged), visible)
  }

  func testAgentReliabilityAndAllocationsInfluenceDistinctSupportWithoutChangingAuthority() {
    let balanced = ProductTractionSupport(agents: ContentLibrary.initialAgents, operations: .balanced, tasks: [])
    var operations = AgentOperationsState.balanced
    var aurora = operations.profile(for: "aurora")
    aurora.allocations = [.marketResearch: 50, .evidenceVerification: 40]
    operations.update(aurora)
    var stacks = operations.profile(for: "stacks")
    stacks.allocations = [.reliability: 50, .technicalDebt: 40]
    operations.update(stacks)
    var brio = operations.profile(for: "brio")
    brio.allocations = [.acquisition: 60, .brand: 30]
    operations.update(brio)
    let focused = ProductTractionSupport(agents: ContentLibrary.initialAgents, operations: operations, tasks: [])
    XCTAssertGreaterThan(focused.research, balanced.research)
    XCTAssertGreaterThan(focused.product, balanced.product)
    XCTAssertGreaterThan(focused.acquisition, balanced.acquisition)
    var weakAgents = ContentLibrary.initialAgents
    for index in weakAgents.indices { weakAgents[index].reliability = 10; weakAgents[index].calibration = 0.2 }
    let weak = ProductTractionSupport(agents: weakAgents, operations: operations, tasks: [])
    XCTAssertLessThan(weak.product, focused.product)
    XCTAssertLessThan(weak.research, focused.research)
  }

  func testResetCareerRemovesProductAndNoProductHasNoExtraFinanceEffects() throws {
    let store = try launchedStore()
    store.resetCareer()
    XCTAssertNil(store.launchedProduct)
    store.startCareer(seed: 48_102)
    store.advanceOperatingTime(hours: 168)
    XCTAssertFalse(store.finance.transactions.contains { $0.source.hasPrefix("Product customers") })
  }
}
