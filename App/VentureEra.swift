import Foundation

enum VentureEra: Int, CaseIterable, Identifiable, Codable {
  case garage, traction, scale, marketLeader, empire, dynasty

  var id: Self { self }

  static let venturesPerEra = 10
  static let empireVentureCap = 60

  static func era(for venture: Int) -> VentureEra {
    let index = max(0, (max(1, venture) - 1) / venturesPerEra)
    return VentureEra(rawValue: min(index, allCases.count - 1)) ?? .dynasty
  }

  var milestoneVenture: Int { (rawValue + 1) * Self.venturesPerEra }

  var name: String {
    switch self {
    case .garage: "Garage"
    case .traction: "Traction"
    case .scale: "Scale"
    case .marketLeader: "Market Leader"
    case .empire: "Empire"
    case .dynasty: "Dynasty"
    }
  }

  var newForce: String {
    switch self {
    case .garage: "Learn the loop. Baseline pressure."
    case .traction: "A recurring competitor shadows your moves."
    case .scale: "Market shocks hit without warning; burn rises."
    case .marketLeader: "Public scrutiny audits your claims in the open."
    case .empire: "Agent fatigue and correlated-failure risk climb."
    case .dynasty: "Legacy stakes make every offer and miss echo."
    }
  }

  var runwayBurnPerSprint: Int { 3 + rawValue }
  var energyCostPerSprint: Int { 2 + rawValue / 2 }
  var correlatedFailureBaseProbability: Double { 0.24 + Double(rawValue) * 0.03 }
  var correlatedFailureExtraPenalty: Int { rawValue * 3 }
}
