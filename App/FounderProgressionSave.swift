import Foundation

struct FounderProgressionSave: Codable, Equatable {
  var version: Int
  var currentFacility: FacilityTier
  var ownedFacilities: Set<FacilityTier>
  var highestTrackRecord: Int
  var completedCareerCount: Int
  var activeCareerID: UUID?
  var recordedCareerIDs: Set<UUID>

  static let currentVersion = 1

  static var initial: Self {
    Self(
      version: currentVersion,
      currentFacility: .founderGarage,
      ownedFacilities: [.founderGarage],
      highestTrackRecord: 0,
      completedCareerCount: 0,
      activeCareerID: nil,
      recordedCareerIDs: []
    )
  }
}
