import Foundation

struct EraContext {
  var unverifiedCount: Int
  var averageDrift: Int
  var profile: DoctrineProfile
  var flags: Set<CompanyFlag>
}

protocol EraForce {
  func modify(_ effects: inout SimulationEffects, context: EraContext)
}

struct MechanicalEraForce: EraForce {
  var era: VentureEra

  func modify(_ effects: inout SimulationEffects, context: EraContext) {
    switch era {
    case .garage:
      break
    case .traction:
      if context.unverifiedCount >= 2 { effects.momentum -= 1 }
    case .scale:
      if context.averageDrift >= 35 { effects.runway -= 2 }
    case .marketLeader:
      if context.unverifiedCount > 0 { effects.trust -= context.unverifiedCount * 2 }
    case .empire:
      if context.profile.restDiscipline < 0.5 { effects.energy -= 2 }
    case .dynasty:
      if context.flags.contains(.publicTransparency) { effects.trust += 1 }
      if context.flags.contains(.featureDebt) { effects.runway -= 2 }
    }
  }
}

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
  var force: any EraForce { MechanicalEraForce(era: self) }
}
