import Foundation

enum FacilityUpgradeID: String, Codable, CaseIterable, Identifiable {
  case developmentRig
  case verificationArray
  case campaignStudio
  case recoveryCorner
  case founderCommandDesk

  var id: Self { self }
}

struct FacilityUpgradeDefinition: Identifiable, Equatable {
  var id: FacilityUpgradeID
  var title: String
  var detail: String
  var cost: Int
  var requiredFacility: FacilityTier
  var symbol: String

  static let all: [Self] = [
    Self(id: .developmentRig, title: "Development Rig", detail: "+4 Engineering task quality for Stacks.", cost: 800, requiredFacility: .founderGarage, symbol: "desktopcomputer"),
    Self(id: .verificationArray, title: "Verification Array", detail: "+8 evidence completeness for Aurora on research and verification work.", cost: 1_200, requiredFacility: .founderGarage, symbol: "checkmark.seal.fill"),
    Self(id: .campaignStudio, title: "Campaign Studio", detail: "+10% positive revenue from marketing and sales work.", cost: 1_000, requiredFacility: .founderGarage, symbol: "megaphone.fill"),
    Self(id: .recoveryCorner, title: "Recovery Corner", detail: "+3 Founder Energy after each completed sprint.", cost: 600, requiredFacility: .founderGarage, symbol: "sofa.fill"),
    Self(id: .founderCommandDesk, title: "Founder Command Desk", detail: "+1 temporary Founder Attention every third sprint.", cost: 1_800, requiredFacility: .founderGarage, symbol: "rectangle.3.group.fill")
  ]

  static func definition(for id: FacilityUpgradeID) -> Self? {
    definitions[id]
  }

  static let definitions = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

struct FacilityBonuses: Equatable {
  var engineeringQualityBonus = 0
  var auroraEvidenceBonus = 0
  var marketingRevenueMultiplier = 1.0
  var sprintEnergyRecovery = 0
  var periodicAttentionBonus = 0
  var ventureEnergyBonus = 0

  static let none = Self()
}
