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
    XCTAssertEqual(calendar.period, .morning)
  }

  func testRunwayIsFiniteForLossMakingCompany() {
    var finance = CompanyFinance(cash: 1_000)
    XCTAssertTrue(finance.apply(.init(id: "hosting", kind: .expense, amount: 200, category: .infrastructure, simulationDay: 1, source: "Hosting", isRecurring: true, agentID: nil, headquarters: nil)))
    XCTAssertEqual(finance.runwayLabel(fallbackDailyBurn: 100), "5 days")
  }
}
