import Foundation

enum GarageEquipmentStage: Int, CaseIterable, Equatable {
  case startup
  case operating
  case established

  static func derive(venture: Int, trackRecord: Int, capital: Int) -> Self {
    if trackRecord >= 18 || capital >= 7_000 { return .established }
    if venture >= 2 || trackRecord >= 8 || capital >= 4_000 { return .operating }
    return .startup
  }
}

enum CareerEnvironmentTreatment: Hashable {
  case victory
  case bankruptcy
  case burnout
  case trustCollapse

  init(_ kind: CareerOutcomeKind) {
    switch kind {
    case .victory: self = .victory
    case .bankruptcy: self = .bankruptcy
    case .burnout: self = .burnout
    case .trustCollapse: self = .trustCollapse
    }
  }
}
