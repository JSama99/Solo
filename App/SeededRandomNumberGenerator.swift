import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator, Codable, Equatable {
  private(set) var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    return value ^ (value >> 31)
  }

  mutating func integer(in range: ClosedRange<Int>) -> Int {
    guard range.lowerBound < range.upperBound else { return range.lowerBound }
    let width = UInt64(range.upperBound - range.lowerBound + 1)
    return range.lowerBound + Int(next() % width)
  }

  mutating func probability() -> Double {
    Double(next() >> 11) / Double(1 << 53)
  }

  static func mixed(_ key: UInt64) -> UInt64 {
    var value = key &* 0x9E3779B97F4A7C15
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    return value ^ (value >> 31)
  }
}
