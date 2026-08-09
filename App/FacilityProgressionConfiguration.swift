import Foundation

struct FacilityProgressionConfiguration {
  struct Requirement: Equatable {
    var minimumTrackRecord: Int
    var capitalCost: Int
    var completedCareers: Int
    var environmentAvailable: Bool
  }

  var requirements: [FacilityTier: Requirement]

  func requirement(for tier: FacilityTier) -> Requirement {
    requirements[tier] ?? Requirement(
      minimumTrackRecord: .max,
      capitalCost: .max,
      completedCareers: .max,
      environmentAvailable: false
    )
  }

  static let build10 = Self(requirements: [
    .founderGarage: Requirement(minimumTrackRecord: 0, capitalCost: 0, completedCareers: 0, environmentAvailable: true),
    .founderLoft: Requirement(minimumTrackRecord: 8, capitalCost: 4_000, completedCareers: 0, environmentAvailable: true),
    .smallOffice: Requirement(minimumTrackRecord: 12, capitalCost: 5_000, completedCareers: 1, environmentAvailable: false),
    .officeSuite: Requirement(minimumTrackRecord: 15, capitalCost: 6_000, completedCareers: 2, environmentAvailable: false),
    .companyBuilding: Requirement(minimumTrackRecord: 18, capitalCost: 7_000, completedCareers: 3, environmentAvailable: false),
    .unicornHeadquarters: Requirement(minimumTrackRecord: 20, capitalCost: 8_000, completedCareers: 4, environmentAvailable: false)
  ])

  static let build2 = Self(requirements: [
    .founderGarage: Requirement(minimumTrackRecord: 0, capitalCost: 0, completedCareers: 0, environmentAvailable: true),
    .founderLoft: Requirement(minimumTrackRecord: 8, capitalCost: 4_000, completedCareers: 0, environmentAvailable: false),
    .smallOffice: Requirement(minimumTrackRecord: 12, capitalCost: 5_000, completedCareers: 1, environmentAvailable: false),
    .officeSuite: Requirement(minimumTrackRecord: 15, capitalCost: 6_000, completedCareers: 2, environmentAvailable: false),
    .companyBuilding: Requirement(minimumTrackRecord: 18, capitalCost: 7_000, completedCareers: 3, environmentAvailable: false),
    .unicornHeadquarters: Requirement(minimumTrackRecord: 20, capitalCost: 8_000, completedCareers: 4, environmentAvailable: false)
  ])
}
