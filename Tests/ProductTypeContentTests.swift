import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class ProductTypeContentTests: XCTestCase {
  func testEveryProductHasTasksAcrossErasAndUniqueTitles() {
    for type in ProductType.allCases {
      for era in VentureEra.allCases {
        let tasks = ContentLibrary.taskPool(for: era, productType: type)
        XCTAssertFalse(tasks.isEmpty, "\(type) starved in \(era)")
        XCTAssertEqual(Set(tasks.map(\.title)).count, tasks.count)
        XCTAssertFalse(tasks.contains { $0.title.contains("{") || $0.detail.contains("{") })
      }
    }
  }

  func testConsumerAppContentIsAuthoredAndUnique() {
    let tasks = ContentLibrary.allTaskPool.filter { $0.productTypes == [.consumerApp] }
    XCTAssertEqual(tasks.count, 70)
    XCTAssertEqual(Set(tasks.map(\.detail)).count, tasks.count)
    XCTAssertTrue(tasks.allSatisfy { task in
      let pieces = task.title.components(separatedBy: task.title)
      return pieces.count == 2
    })
    let dilemmas = ContentLibrary.dilemmaPool.filter { $0.productTypes == [.consumerApp] }
    XCTAssertEqual(dilemmas.count, 12)
    XCTAssertEqual(Set(dilemmas.map(\.setup)).count, dilemmas.count)
    XCTAssertFalse(dilemmas.contains { consumer in
      ContentLibrary.dilemmaPool.contains { other in
        other.productTypes == [.saas] && other.id.hasSuffix(consumer.id.replacingOccurrences(of: "consumerApp-", with: "")) && other.choices == consumer.choices
      }
    })
  }

  func testEveryProductHasDilemmasInEachChapter() {
    for type in ProductType.allCases {
      for chapter in VentureChapter.allCases {
        XCTAssertTrue(ContentLibrary.dilemmaPool.contains {
          $0.chapter == chapter && ($0.productTypes?.contains(type) ?? true)
        })
      }
    }
  }

  func testDraftsAndDilemmasRespectProductType() {
    for type in ProductType.allCases {
      let store = GameStore()
      store.resetCareer()
      store.selectedProductType = type
      store.startCareer(seed: 8_140)
      for _ in 0 ..< 4 {
        XCTAssertTrue(store.tasks.allSatisfy { $0.productTypes?.contains(type) ?? true })
        XCTAssertTrue(store.taskBacklog.allSatisfy { $0.productTypes?.contains(type) ?? true })
        XCTAssertTrue(store.activeDilemma.map { $0.productTypes?.contains(type) ?? true } ?? true)
        guard let task = store.tasks.first,
              let agent = store.agents.first(where: { $0.role == task.role }) ?? store.agents.first else { break }
        if let choice = store.activeDilemma?.choices.first { store.selectDilemmaChoice(choice.id) }
        store.assign(agentID: agent.id, to: task.id)
        store.commitSprint()
        store.finishReport()
      }
    }
  }

  func testV10MigrationDefaultsProductTypeToSaaS() throws {
    let source = GameStore()
    source.resetCareer()
    source.startCareer(seed: 14)
    let save = CareerSave(
      founderName: source.founderName, doctrine: source.doctrine, sprint: source.sprint,
      venture: source.venture, intent: source.intent, stats: source.stats, agents: source.agents,
      tasks: source.tasks, evidence: source.evidence, outcome: source.careerOutcome,
      randomNumberGenerator: source.randomNumberGenerator, correlatedFailureEvent: nil, pendingEffects: []
    )
    UserDefaults.standard.set(try JSONEncoder().encode(SaveEnvelope(version: 10, career: save)), forKey: "solo-unicorn-run-native-save-v10")
    let migrated = GameStore()
    migrated.continueCareer()
    XCTAssertEqual(migrated.productType, .saas)
  }
}
