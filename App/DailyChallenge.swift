import Foundation
import Observation

enum DailyChallenge {
  static let sprintsPerRun = 5

  static func dayKey(for date: Date = Date()) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return (components.year ?? 2026) * 10_000 + (components.month ?? 1) * 100 + (components.day ?? 1)
  }

  static func seed(for date: Date = Date()) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in String(dayKey(for: date)).utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100000001b3
    }
    return hash
  }
}

struct DailyChallengeSave: Codable, Equatable {
  var dayKey: Int?
  var score: Int?
  var bestScore: Int
  var currentStreak: Int
  var longestStreak: Int
  var lastCompletedDayKey: Int?
}

@Observable
final class DailyChallengeStore {
  private static let key = "solo-daily-v1"
  private(set) var save: DailyChallengeSave
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.key),
       let decoded = try? JSONDecoder().decode(DailyChallengeSave.self, from: data) {
      save = decoded
    } else {
      save = DailyChallengeSave(dayKey: nil, score: nil, bestScore: 0, currentStreak: 0, longestStreak: 0, lastCompletedDayKey: nil)
    }
  }

  var isCompletedToday: Bool { save.dayKey == DailyChallenge.dayKey() && save.score != nil }

  func record(score: Int, date: Date = Date()) {
    let today = DailyChallenge.dayKey(for: date)
    guard save.dayKey != today || save.score == nil else { return }
    let calendar = Calendar(identifier: .gregorian)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: date).map(DailyChallenge.dayKey(for:))
    save.dayKey = today
    save.score = score
    save.bestScore = max(save.bestScore, score)
    save.currentStreak = save.lastCompletedDayKey == yesterday ? save.currentStreak + 1 : 1
    save.longestStreak = max(save.longestStreak, save.currentStreak)
    save.lastCompletedDayKey = today
    persist()
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(save) {
      defaults.set(data, forKey: Self.key)
    }
  }
}
