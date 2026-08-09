import Foundation

struct FounderProgressionSave: Codable, Equatable {
  var version: Int
  var currentFacility: FacilityTier
  var ownedFacilities: Set<FacilityTier>
  var highestTrackRecord: Int
  var completedCareerCount: Int
  var activeCareerID: UUID?
  var recordedCareerIDs: Set<UUID>

  var purchasedUpgrades: Set<FacilityUpgradeID>

  static let currentVersion = 2

  static var initial: Self {
    Self(
      version: currentVersion,
      currentFacility: .founderGarage,
      ownedFacilities: [.founderGarage],
      highestTrackRecord: 0,
      completedCareerCount: 0,
      activeCareerID: nil,
      recordedCareerIDs: [],
      purchasedUpgrades: []
    )
  }

  enum CodingKeys: String, CodingKey {
    case version, currentFacility, ownedFacilities, highestTrackRecord, completedCareerCount
    case activeCareerID, recordedCareerIDs, purchasedUpgrades
  }

  init(
    version: Int,
    currentFacility: FacilityTier,
    ownedFacilities: Set<FacilityTier>,
    highestTrackRecord: Int,
    completedCareerCount: Int,
    activeCareerID: UUID?,
    recordedCareerIDs: Set<UUID>,
    purchasedUpgrades: Set<FacilityUpgradeID>
  ) {
    self.version = version
    self.currentFacility = currentFacility
    self.ownedFacilities = ownedFacilities
    self.highestTrackRecord = highestTrackRecord
    self.completedCareerCount = completedCareerCount
    self.activeCareerID = activeCareerID
    self.recordedCareerIDs = recordedCareerIDs
    self.purchasedUpgrades = purchasedUpgrades
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    currentFacility = try container.decodeIfPresent(FacilityTier.self, forKey: .currentFacility) ?? .founderGarage
    ownedFacilities = try container.decodeIfPresent(Set<FacilityTier>.self, forKey: .ownedFacilities) ?? [.founderGarage]
    highestTrackRecord = try container.decodeIfPresent(Int.self, forKey: .highestTrackRecord) ?? 0
    completedCareerCount = try container.decodeIfPresent(Int.self, forKey: .completedCareerCount) ?? 0
    activeCareerID = try container.decodeIfPresent(UUID.self, forKey: .activeCareerID)
    recordedCareerIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .recordedCareerIDs) ?? []
    purchasedUpgrades = try container.decodeIfPresent(Set<FacilityUpgradeID>.self, forKey: .purchasedUpgrades) ?? []
  }
}
