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
  /// Role-matched XP multiplier (Founder Garage equipment).
  var agentXPBonusMultiplier = 1.0
  /// XP multiplier that applies regardless of role fit (Small Company
  /// Building). Kept separate from `agentXPBonusMultiplier` because the two
  /// have different application conditions and compound multiplicatively when
  /// both are owned: role-matched work at a Company Building earns 1.1 x 1.2.
  var agentXPAnyRoleMultiplier = 1.0
  var stressAccumulationMultiplier = 1.0
  /// Extra roster slots beyond the base five (Small Office Room).
  var talentSlotBonus = 0
  /// Energy shaved off each founder review (Office Suite). Applied with a
  /// floor of 1 so it can never make review free, which would erase the
  /// doctrine differentiation that `reviewEnergyCost` carries.
  var reviewEnergyDiscount = 0
  /// Fraction of a rival move's negative pressure on the founder's own stats
  /// that is absorbed (Unicorn Headquarters). 0 = none, 0.5 = halved.
  var rivalPressureResistance = 0.0

  static let none = Self()
}
