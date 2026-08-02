import SwiftUI

struct HeadquartersProgressScreen: View {
  @Environment(FounderProgressionStore.self) private var progression
  var availableCapital: Int

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        currentFacilityCard
        if let nextTier = progression.currentFacility.next {
          nextTierProgress(nextTier)
        }
        VStack(spacing: 10) {
          ForEach(FacilityTier.allCases) { tier in
            facilityRow(tier)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Headquarters")
  }

  private var currentFacilityCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CURRENT FACILITY")
        .font(.caption.weight(.black))
        .tracking(2)
        .foregroundStyle(SoloTheme.cyan)
      Label(progression.currentFacility.name, systemImage: progression.currentFacility.symbol)
        .font(.title2.bold())
      Text(progression.currentFacility.accessibilityDescription)
        .foregroundStyle(.secondary)
    }
    .soloCard()
  }

  private func nextTierProgress(_ tier: FacilityTier) -> some View {
    let requirement = progression.configuration.requirement(for: tier)
    return VStack(alignment: .leading, spacing: 12) {
      Text("Next tier progress").font(.headline)
      requirementProgress(
        title: "Track record",
        value: progression.highestTrackRecord,
        required: requirement.minimumTrackRecord
      )
      requirementProgress(
        title: "Available capital",
        value: availableCapital,
        required: requirement.capitalCost,
        currency: true
      )
      if requirement.completedCareers > 0 {
        requirementProgress(
          title: "Completed careers",
          value: progression.completedCareerCount,
          required: requirement.completedCareers
        )
      }
      Label("Future Environment", systemImage: "lock.fill")
        .font(.caption.weight(.bold))
        .foregroundStyle(SoloTheme.amber)
    }
    .soloCard()
  }

  private func requirementProgress(
    title: String,
    value: Int,
    required: Int,
    currency: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(title).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text(currency ? "$\(value.formatted()) / $\(required.formatted())" : "\(value) / \(required)")
          .font(.caption.weight(.bold).monospacedDigit())
      }
      ProgressView(value: Double(min(value, required)), total: Double(max(1, required)))
        .tint(value >= required ? SoloTheme.mint : SoloTheme.cyan)
    }
    .accessibilityElement(children: .combine)
  }

  private func facilityRow(_ tier: FacilityTier) -> some View {
    let requirement = progression.configuration.requirement(for: tier)
    let owned = progression.ownedFacilities.contains(tier)
    return HStack(spacing: 12) {
      Image(systemName: tier.symbol)
        .font(.title3)
        .foregroundStyle(owned ? SoloTheme.mint : .secondary)
        .frame(width: 40, height: 40)
        .background((owned ? SoloTheme.mint : Color.secondary).opacity(0.12), in: .rect(cornerRadius: 11))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(tier.name).font(.headline)
        if tier == .founderGarage {
          Text("Owned • Active environment")
        } else {
          Text("Track \(requirement.minimumTrackRecord) • $\(requirement.capitalCost.formatted())")
          Text(requirement.completedCareers == 0
            ? "Future Environment"
            : "\(requirement.completedCareers) completed career\(requirement.completedCareers == 1 ? "" : "s") • Future Environment")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      Spacer()
      Image(systemName: owned ? "checkmark.seal.fill" : "lock.fill")
        .foregroundStyle(owned ? SoloTheme.mint : SoloTheme.amber)
        .accessibilityHidden(true)
    }
    .soloCard()
    .accessibilityElement(children: .combine)
  }
}
