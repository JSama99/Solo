import Foundation

enum PrecedentRecordsFilter: String, CaseIterable, Identifiable {
  case all
  case flagged
  case trustImpact

  var id: Self { self }

  var title: String {
    switch self {
    case .all: "All"
    case .flagged: "Flagged"
    case .trustImpact: "Trust"
    }
  }

  func includes(_ precedent: Precedent) -> Bool {
    switch self {
    case .all: true
    case .flagged: precedent.isFlagged
    case .trustImpact: precedent.outcome.trustDelta != 0
    }
  }
}

struct PrecedentExpansionState: Equatable {
  private(set) var expandedIDs: Set<UUID> = []

  mutating func toggle(_ id: UUID) {
    if expandedIDs.contains(id) {
      expandedIDs.remove(id)
    } else {
      expandedIDs.insert(id)
    }
  }

  func isExpanded(_ id: UUID) -> Bool {
    expandedIDs.contains(id)
  }
}

extension Precedent {
  var isFlagged: Bool {
    outcome.overclaimsSurfaced > 0
      || outcome.driftDetections > 0
      || outcome.unverifiedCommitted > 0
  }
}
