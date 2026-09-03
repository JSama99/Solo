import Foundation

struct TalentCandidate: Codable, Identifiable, Hashable {
  var id: String
  var name: String
  var initials: String
  var role: AgentRole
  var modelFamily: String
  var pitch: String
  var price: Int

  func makeAgent() -> SoloAgent {
    SoloAgent(
      id: id,
      name: name,
      initials: initials,
      role: role,
      modelFamily: modelFamily,
      reliability: 76,
      calibration: 0.68,
      drift: 0,
      trust: 60,
      archetype: "New Hire",
      traits: ["Adaptive", "Independent"],
      ambition: "Earn a durable place in the company’s operating system.",
      stressTrigger: "Being assigned work without a clear owner."
    )
  }
}

enum TalentBoard {
  static let refreshCost = 600
  static let fourthSlotPriceRange = 1_200...1_800
  static let fifthSlotPriceRange = 2_500...3_500
  /// Unlocked by the Small Office Room, which is the only way to seat a sixth
  /// teammate. Priced above the fifth slot to match the tier's capital gate.
  static let sixthSlotPriceRange = 4_200...5_600

  static let candidates: [TalentCandidate] = [
    TalentCandidate(id: "quill", name: "Quill", initials: "QU", role: .research, modelFamily: "Helix-3", pitch: "Finds contradictions before a market narrative hardens.", price: 1_200),
    TalentCandidate(id: "forge", name: "Forge", initials: "FO", role: .engineering, modelFamily: "Vector-4", pitch: "Builds resilient paths when the operating surface gets messy.", price: 1_350),
    TalentCandidate(id: "lumen", name: "Lumen", initials: "LU", role: .marketing, modelFamily: "Orion-2", pitch: "Turns verified proof into a story customers repeat.", price: 1_500),
    TalentCandidate(id: "relay", name: "Relay", initials: "RE", role: .general, modelFamily: "Helix-3", pitch: "Keeps decisions moving when no one owns the handoff.", price: 1_650),
    TalentCandidate(id: "atlas", name: "Atlas", initials: "AT", role: .engineering, modelFamily: "Atlas-2", pitch: "Makes scale work without trading away operational clarity.", price: 2_600),
    TalentCandidate(id: "signal", name: "Signal", initials: "SI", role: .research, modelFamily: "Vector-4", pitch: "Separates durable demand from loud but fleeting attention.", price: 2_850),
    TalentCandidate(id: "cinder", name: "Cinder", initials: "CI", role: .general, modelFamily: "Orion-2", pitch: "Closes the gaps between customer promises and delivery.", price: 3_100),
    TalentCandidate(id: "harbor", name: "Harbor", initials: "HA", role: .marketing, modelFamily: "Helix-3", pitch: "Builds trust with the customers most likely to stay.", price: 3_400),
    TalentCandidate(id: "meridian", name: "Meridian", initials: "ME", role: .research, modelFamily: "Atlas-2", pitch: "Reads a market two quarters ahead and shows the working.", price: 4_400),
    TalentCandidate(id: "kiln", name: "Kiln", initials: "KI", role: .engineering, modelFamily: "Orion-2", pitch: "Turns brittle prototypes into systems that survive real load.", price: 4_800),
    TalentCandidate(id: "verity", name: "Verity", initials: "VE", role: .general, modelFamily: "Vector-4", pitch: "Holds the company to what it actually proved, not what it hoped.", price: 5_200),
    TalentCandidate(id: "cadence", name: "Cadence", initials: "CA", role: .marketing, modelFamily: "Atlas-2", pitch: "Finds the rhythm between shipping and telling people you shipped.", price: 5_500)
  ]

  static func priceRange(for slot: Int) -> ClosedRange<Int> {
    switch slot {
    case 4: fourthSlotPriceRange
    case 5: fifthSlotPriceRange
    default: sixthSlotPriceRange
    }
  }

  static func candidates(for slot: Int, excluding agentIDs: Set<String>, refresh: Int) -> [TalentCandidate] {
    let range = priceRange(for: slot)
    let eligible = candidates.filter { !agentIDs.contains($0.id) && range.contains($0.price) }
    guard !eligible.isEmpty else { return [] }
    let offset = refresh % eligible.count
    return Array((0 ..< min(3, eligible.count)).map { eligible[($0 + offset) % eligible.count] })
  }
}
