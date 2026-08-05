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
    case .founderGarage: "Warm industrial garage with research, verification, engineering, and founder workstations."
    case .founderLoft: "Future living and working loft environment."
    case .smallOffice: "Future dedicated early-company office."
    case .officeSuite: "Future multi-room office suite."
    case .companyBuilding: "Future established company building."
    case .unicornHeadquarters: "Future mature unicorn headquarters."
    }
  }

  var next: Self? {
    Self(rawValue: rawValue + 1)
  }
}
