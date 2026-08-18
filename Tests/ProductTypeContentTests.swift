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

  /// A task the player reads as "Hardware: Audit Agent Outputs — Audit Agent
  /// Outputs" is a content bug, not flavor. Product localization only appends
  /// the source title when it actually differs from the localized one.
  func testNoProductTaskTitleRepeatsItself() {
    for type in ProductType.allCases {
      for task in ContentLibrary.allTaskPool where task.productTypes == [type] {
        XCTAssertFalse(
          hasRepeatedPhrase(in: task.title),
          "\(type) task title repeats itself: \(task.title)"
        )
      }
    }
  }

  func testConsumerAppContentIsAuthoredAndUnique() {
    let tasks = ContentLibrary.allTaskPool.filter { $0.productTypes == [.consumerApp] }
    XCTAssertEqual(tasks.count, 71)
    XCTAssertEqual(Set(tasks.map(\.detail)).count, tasks.count)
    XCTAssertTrue(tasks.allSatisfy { !hasRepeatedPhrase(in: $0.title) })
    let dilemmas = ContentLibrary.dilemmaPool.filter { $0.productTypes == [.consumerApp] }
    XCTAssertEqual(dilemmas.count, 12)
    XCTAssertEqual(Set(dilemmas.map(\.setup)).count, dilemmas.count)
    XCTAssertEqual(Set(dilemmas.map(\.choices)).count, dilemmas.count)
    XCTAssertTrue(dilemmas.allSatisfy { Set($0.choices.map(\.detail)).count == $0.choices.count && Set($0.choices.map(\.consequencePreview)).count == $0.choices.count })
    XCTAssertFalse(dilemmas.contains { consumer in
      ContentLibrary.dilemmaPool.contains { other in
        other.productTypes == [.saas] && other.id.hasSuffix(consumer.id.replacingOccurrences(of: "consumerApp-", with: "")) && other.choices == consumer.choices
      }
    })
  }

  func testProductTypeCompositionPreservesCountsAndUniversalDilemmas() {
    XCTAssertEqual(Set(ProductType.allCases.map { type in ContentLibrary.allTaskPool.filter { $0.productTypes?.contains(type) ?? true }.count }).count, 1)
    XCTAssertEqual(Set(ProductType.allCases.map { type in ContentLibrary.dilemmaPool.filter { $0.productTypes?.contains(type) ?? true }.count }).count, 1)
    let universal = FounderDilemma(id: "future-universal", title: "Universal", setup: "Universal future content.", chapter: .prototype, featuredAgentID: nil, choices: [])
    XCTAssertNil(ContentLibrary.classifiedDilemmas([universal]).first?.productTypes)
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
      store.confirmVentureThesisIfNeeded()
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
        store.confirmVentureThesisIfNeeded()
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

  private func hasRepeatedPhrase(in title: String) -> Bool {
    let words = title.lowercased().split { !$0.isLetter && !$0.isNumber }
    var phrases = Set<String>()
    for index in 0 ..< max(0, words.count - 1) {
      if !phrases.insert(words[index ... index + 1].joined(separator: " ")).inserted { return true }
    }
    return false
  }
}
