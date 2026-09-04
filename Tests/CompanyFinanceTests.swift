import XCTest
@testable import Solo_Unicorn_Run

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
  }

  func testFundingApplicationLifecycleIsStableAndIdempotent() {
    var finance = CompanyFinance()
    XCTAssertTrue(finance.beginFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 1))
    XCTAssertFalse(finance.beginFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 1))
    XCTAssertEqual(finance.fundingApplications.first?.status, .pursuing)
    XCTAssertTrue(finance.resolveFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 2))
    XCTAssertFalse(finance.resolveFundingApplication(opportunityID: "pioneer-ai-grant", careerSprint: 2))
    XCTAssertEqual(finance.fundingApplications.first?.status, .resolved)
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
