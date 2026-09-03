import Foundation

enum FacilityTier: Int, Codable, CaseIterable, Identifiable {
  case founderGarage
  case founderLoft
  case smallOffice
  case officeSuite
  case companyBuilding
  case unicornHeadquarters

  var id: Self { self }

  var name: String {
    switch self {
    case .founderGarage: "Founder Garage"
    case .founderLoft: "Founder Loft"
    case .smallOffice: "Small Office Room"
    case .officeSuite: "Office Suite"
    case .companyBuilding: "Small Company Building"
    case .unicornHeadquarters: "Unicorn Headquarters"
    }
  }

  var symbol: String {
    switch self {
    case .founderGarage: "door.garage.closed"
    case .founderLoft: "stairs"
    case .smallOffice: "person.2.fill"
    case .officeSuite: "building.2.fill"
    case .companyBuilding: "building.fill"
    case .unicornHeadquarters: "building.columns.fill"
    }
  }

  var accessibilityDescription: String {
    switch self {
    case .founderGarage: "Warm industrial garage with a Founder desk, recovery couch, workout bench, Signal TV, and practical equipment."
    case .founderLoft: "A playable living and working loft with sustainable operations space."
    case .smallOffice: "Dedicated early-company office with desk space for a sixth AI teammate. Costs \(OperatingCostTuning.smallOfficeMonthlyObligation) monthly."
    case .officeSuite: "Multi-room office suite with quiet review rooms that shave 1 Energy off every founder review. Costs \(OperatingCostTuning.officeSuiteMonthlyObligation) monthly."
    case .companyBuilding: "Established company building with a training floor that raises AI teammate experience 20 percent on all work, whatever the role. Costs \(OperatingCostTuning.companyBuildingMonthlyObligation) monthly."
    case .unicornHeadquarters: "Mature unicorn headquarters whose market standing absorbs half the pressure rival moves put on your own stats. Costs \(OperatingCostTuning.unicornHeadquartersMonthlyObligation) monthly."
    }
  }

  /// Recurring monthly cost of operating this headquarters, charged on the
  /// same 30-day cadence the Founder Loft established.
  var monthlyObligation: Int {
    switch self {
    case .founderGarage: 0
    case .founderLoft: OperatingCostTuning.founderLoftMonthlyObligation
    case .smallOffice: OperatingCostTuning.smallOfficeMonthlyObligation
    case .officeSuite: OperatingCostTuning.officeSuiteMonthlyObligation
    case .companyBuilding: OperatingCostTuning.companyBuildingMonthlyObligation
    case .unicornHeadquarters: OperatingCostTuning.unicornHeadquartersMonthlyObligation
    }
  }

  var next: Self? {
    Self(rawValue: rawValue + 1)
  }
}
