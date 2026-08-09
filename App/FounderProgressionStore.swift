import Foundation
import Observation

@MainActor
@Observable
final class FounderProgressionStore {
  enum PurchaseResult: Equatable {
    case purchased(cost: Int)
    case alreadyOwned
    case predecessorRequired
    case trackRecordRequired(Int)
    case completedCareersRequired(Int)
    case insufficientCapital(Int)
    case futureEnvironment
    case facilityRequired(FacilityTier)
  }

  private(set) var save: FounderProgressionSave
  var configuration: FacilityProgressionConfiguration

  private var defaults: UserDefaults
  private var saveKey: String

  init(
    defaults: UserDefaults = .standard,
    saveKey: String = "solo-unicorn-run-founder-progression-v1",
    configuration: FacilityProgressionConfiguration = .build10
  ) {
    self.defaults = defaults
    self.saveKey = saveKey
    self.configuration = configuration
    if let data = defaults.data(forKey: saveKey),
       let decoded = try? JSONDecoder().decode(FounderProgressionSave.self, from: data),
       decoded.version <= FounderProgressionSave.currentVersion {
      save = decoded
    } else {
      save = .initial
    }
    sanitize()
  }

  var currentFacility: FacilityTier { save.currentFacility }
  var ownedFacilities: Set<FacilityTier> { save.ownedFacilities }
  var highestTrackRecord: Int { save.highestTrackRecord }
  var completedCareerCount: Int { save.completedCareerCount }
  var purchasedUpgrades: Set<FacilityUpgradeID> { save.purchasedUpgrades }

  var bonuses: FacilityBonuses {
    var bonuses = FacilityBonuses.none
    let activeUpgrades = save.purchasedUpgrades.filter {
      FacilityUpgradeDefinition.definition(for: $0)?.requiredFacility == save.currentFacility
    }
    if activeUpgrades.contains(.developmentRig) { bonuses.engineeringQualityBonus = 4 }
    if activeUpgrades.contains(.verificationArray) { bonuses.auroraEvidenceBonus = 8 }
    if activeUpgrades.contains(.campaignStudio) { bonuses.marketingRevenueMultiplier = 1.1 }
    if activeUpgrades.contains(.recoveryCorner) { bonuses.sprintEnergyRecovery = 3 }
    if activeUpgrades.contains(.founderCommandDesk) { bonuses.periodicAttentionBonus = 1 }
    if save.currentFacility == .founderLoft { bonuses.ventureEnergyBonus = 5 }
    return bonuses
  }

  func beginCareer() {
    save.activeCareerID = UUID()
    persist()
  }

  func ensureCareerIdentity() {
    guard save.activeCareerID == nil else { return }
    save.activeCareerID = UUID()
    persist()
  }

  @discardableResult
  func recordCareerCompletion(trackRecord: Int) -> Bool {
    ensureCareerIdentity()
    guard let careerID = save.activeCareerID,
          !save.recordedCareerIDs.contains(careerID) else { return false }
    save.recordedCareerIDs.insert(careerID)
    save.completedCareerCount += 1
    save.highestTrackRecord = max(save.highestTrackRecord, trackRecord)
    persist()
    return true
  }

  func observe(trackRecord: Int) {
    guard trackRecord > save.highestTrackRecord else { return }
    save.highestTrackRecord = trackRecord
    persist()
  }

  func purchaseResult(for tier: FacilityTier, availableCapital: Int) -> PurchaseResult {
    if save.ownedFacilities.contains(tier) { return .alreadyOwned }
    guard tier.rawValue > 0,
          save.ownedFacilities.contains(FacilityTier(rawValue: tier.rawValue - 1) ?? .founderGarage) else {
      return .predecessorRequired
    }
    let requirement = configuration.requirement(for: tier)
    guard requirement.environmentAvailable else { return .futureEnvironment }
    guard save.highestTrackRecord >= requirement.minimumTrackRecord else {
      return .trackRecordRequired(requirement.minimumTrackRecord)
    }
    guard save.completedCareerCount >= requirement.completedCareers else {
      return .completedCareersRequired(requirement.completedCareers)
    }
    guard availableCapital >= requirement.capitalCost else {
      return .insufficientCapital(requirement.capitalCost)
    }
    return .purchased(cost: requirement.capitalCost)
  }

  @discardableResult
  func purchase(_ tier: FacilityTier, availableCapital: Int) -> PurchaseResult {
    let result = purchaseResult(for: tier, availableCapital: availableCapital)
    guard case .purchased = result else { return result }
    save.ownedFacilities.insert(tier)
    save.currentFacility = tier
    persist()
    return result
  }

  @discardableResult
  func activate(_ tier: FacilityTier) -> Bool {
    guard save.ownedFacilities.contains(tier) else { return false }
    save.currentFacility = tier
    persist()
    return true
  }

  func upgradePurchaseResult(for id: FacilityUpgradeID, availableCapital: Int) -> PurchaseResult {
    guard let definition = FacilityUpgradeDefinition.definition(for: id) else { return .futureEnvironment }
    if save.purchasedUpgrades.contains(id) { return .alreadyOwned }
    guard save.ownedFacilities.contains(definition.requiredFacility) else {
      return .facilityRequired(definition.requiredFacility)
    }
    guard availableCapital >= definition.cost else { return .insufficientCapital(definition.cost) }
    return .purchased(cost: definition.cost)
  }

  @discardableResult
  func purchaseUpgrade(_ id: FacilityUpgradeID, availableCapital: Int) -> PurchaseResult {
    let result = upgradePurchaseResult(for: id, availableCapital: availableCapital)
    guard case .purchased = result else { return result }
    save.purchasedUpgrades.insert(id)
    persist()
    return result
  }

  private func sanitize() {
    save.version = FounderProgressionSave.currentVersion
    save.ownedFacilities.insert(.founderGarage)
    if !save.ownedFacilities.contains(save.currentFacility) {
      save.currentFacility = .founderGarage
    }
    save.highestTrackRecord = max(0, save.highestTrackRecord)
    save.completedCareerCount = max(save.recordedCareerIDs.count, save.completedCareerCount)
    save.version = FounderProgressionSave.currentVersion
  }

  private func persist() {
    sanitize()
    if let data = try? JSONEncoder().encode(save) {
      defaults.set(data, forKey: saveKey)
    }
  }
}
