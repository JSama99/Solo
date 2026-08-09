import XCTest
@testable import Solo_Unicorn_Run

@MainActor
final class AchievementScreenTests: XCTestCase {
  private var defaults: UserDefaults!

  override func setUp() {
    defaults = UserDefaults(suiteName: "AchievementScreenTests")!
    defaults.removePersistentDomain(forName: "AchievementScreenTests")
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: "AchievementScreenTests")
    defaults = nil
  }

  func testLockedAchievementWithRealPartialProgressProvidesProgress() throws {
    let store = AchievementStore(defaults: defaults)
    let achievement = try XCTUnwrap(AchievementCatalog.by("objective-10"))
    let progress = store.progress(
      for: achievement,
      context: AchievementDisplayContext(
        venture: 1,
        careerScore: 0,
        completedObjectives: 4,
        currentRunOverclaims: 0,
        reviewRate: 0
      )
    )

    XCTAssertEqual(progress?.current, 4)
    XCTAssertEqual(progress?.target, 10)
  }

  func testRetroactiveUnlockRemainsNewUntilAchievementsIsViewed() throws {
    let store = AchievementStore(defaults: defaults)
    let retroactive = store.evaluateRetroactive(save: retroactiveCareerSave())
    let unlocked = try XCTUnwrap(retroactive.first)

    XCTAssertTrue(store.isRetroactivelyNew(unlocked.id))
    XCTAssertNil(store.latestUnlock, "Retroactive unlocks should not announce at launch")

    store.markRetroactiveUnlocksSeen()
    XCTAssertFalse(store.isRetroactivelyNew(unlocked.id))

    let relaunched = AchievementStore(defaults: defaults)
    XCTAssertFalse(relaunched.isRetroactivelyNew(unlocked.id))
  }

  func testBuild10AchievementSaveMigratesWithoutRetroactiveField() throws {
    let legacy = "{\"version\":1,\"unlocked\":{},\"totalXP\":0,\"doctrinesWon\":[],\"lifetimeOverclaimsCaught\":0,\"didEvaluateRetroactively\":false}"
    let save = try JSONDecoder().decode(AchievementSave.self, from: try XCTUnwrap(legacy.data(using: .utf8)))
    XCTAssertTrue(save.unseenRetroactiveUnlockIDs.isEmpty)
  }

  private func retroactiveCareerSave() -> CareerSave {
    CareerSave(
      founderName: "Founder",
      doctrine: .guided,
      sprint: 1,
      venture: 11,
      intent: .build,
      stats: FounderStats(),
      agents: [],
      tasks: [],
      evidence: [],
      outcome: nil,
      randomNumberGenerator: SeededRandomNumberGenerator(seed: 1),
      correlatedFailureEvent: nil,
      pendingEffects: []
    )
  }
}
