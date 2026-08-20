import Foundation

enum DrawChannel: String, Codable, Hashable {
  case quality, evidence, drift, correlation
}

struct DrawCoordinate: Codable, Hashable {
  var careerSeed: UInt64
  var venture: Int
  var sprint: Int
  var taskInstanceID: String
  var agentID: String
  var channel: DrawChannel
  var divergenceSalt: UInt64

  var key: UInt64 {
    var hash = careerSeed ^ UInt64(bitPattern: Int64(venture * 10_000 + sprint))
    for byte in "\(taskInstanceID)|\(agentID)|\(channel.rawValue)".utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100000001B3
    }
    return SeededRandomNumberGenerator.mixed(hash ^ divergenceSalt)
  }

  func replacing(channel: DrawChannel, divergenceSalt: UInt64? = nil) -> DrawCoordinate {
    var copy = self
    copy.channel = channel
    if let divergenceSalt { copy.divergenceSalt = divergenceSalt }
    return copy
  }
}

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
