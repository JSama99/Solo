import SwiftUI

struct HeadquartersProgressScreen: View {
  var store: GameStore
  @Environment(FounderProgressionStore.self) private var progression
  @Environment(AppSettingsStore.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pendingPurchase: TreasuryPurchase?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        treasuryCard
        headquartersCard
        upgradesCard
        facilitySwitcher
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Company")
    .alert(item: $pendingPurchase) { purchase in
      Alert(
        title: Text("Confirm purchase"),
        message: Text("Spend \(purchase.cost.formatted(.currency(code: "USD").precision(.fractionLength(0)))) cash? You will have \((store.finance.cash - purchase.cost).formatted(.currency(code: "USD").precision(.fractionLength(0)))) remaining."),
        primaryButton: .default(Text(purchase.actionTitle)) { complete(purchase) },
        secondaryButton: .cancel()
      )
    }
  }

  private var treasuryCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("COMPANY CASH").font(.caption.weight(.black)).tracking(2).foregroundStyle(SoloTheme.cyan)
      Text(store.finance.cash, format: .currency(code: "USD").precision(.fractionLength(0)))
        .font(.largeTitle.bold().monospacedDigit())
        .contentTransition(.numericText(value: Double(store.finance.cash)))
        .gameplayMotion(.celebration, value: store.finance.cash)
      Text("Capital raised \(store.finance.capitalRaised.formatted(.currency(code: "USD").precision(.fractionLength(0)))) • Runway \(store.finance.runwayLabel(fallbackDailyBurn: 120))")
        .font(.caption.weight(.semibold)).foregroundStyle(SoloTheme.mint)
      Text("Cash is spendable. Capital Raised is financing history; it is not a second balance.")
        .font(.caption).foregroundStyle(.secondary)
    }
    .soloCard()
  }

  private var headquartersCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("HEADQUARTERS").font(.caption.weight(.black)).tracking(2).foregroundStyle(SoloTheme.cyan)
      Label(progression.currentFacility.name, systemImage: progression.currentFacility.symbol).font(.title3.bold())
        .contentTransition(.interpolate)
        .symbolEffect(.bounce, value: progression.currentFacility)
      Text(progression.currentFacility == .founderLoft
        ? "Sustainable founder operations: +5 Energy at the beginning of each venture."
        : "The original operating base. Garage upgrades are active while this headquarters is selected.")
        .font(.caption).foregroundStyle(.secondary)
      if let next = progression.currentFacility.next {
        let requirement = progression.configuration.requirement(for: next)
        Divider()
        Text("NEXT HQ").font(.caption.weight(.black)).foregroundStyle(SoloTheme.amber)
        Text(next.name).font(.headline)
        Text(next == .founderLoft ? "Move-in: $7,500 • Then $3,400/month lease + utilities • Track Record \(requirement.minimumTrackRecord)" : "Cost: \(requirement.capitalCost.formatted(.currency(code: "USD").precision(.fractionLength(0)))) • Track Record \(requirement.minimumTrackRecord)")
          .font(.caption).foregroundStyle(.secondary)
        if next == .founderLoft {
          let eligible = progression.purchaseResult(for: next, availableCapital: store.finance.cash)
          Button("Move Company", systemImage: "building.2.fill") {
            if case .purchased(let cost) = eligible { pendingPurchase = .facility(next, cost) }
            else { store.alertMessage = message(for: eligible) }
          }
          .buttonStyle(SoloPrimaryButtonStyle())
        }
      }
    }
    .soloCard()
    .gameplayMotion(.celebration, value: progression.currentFacility)
  }

  private var upgradesCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("INFRASTRUCTURE").font(.caption.weight(.black)).tracking(2).foregroundStyle(SoloTheme.cyan)
      ForEach(FacilityUpgradeDefinition.all) { upgrade in
        let owned = progression.purchasedUpgrades.contains(upgrade.id)
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Label(upgrade.title, systemImage: upgrade.symbol).font(.headline)
            Spacer()
            Text(owned ? "Owned" : upgrade.cost.formatted(.currency(code: "USD").precision(.fractionLength(0))))
              .font(.caption.weight(.bold)).foregroundStyle(owned ? SoloTheme.mint : SoloTheme.amber)
          }
          Text(upgrade.detail).font(.caption).foregroundStyle(.secondary)
          if owned {
            Text(upgrade.requiredFacility == progression.currentFacility ? "Active at this HQ" : "Inactive while another HQ is selected")
              .font(.caption2.weight(.semibold)).foregroundStyle(SoloTheme.cyan)
          } else {
            Button("Purchase", systemImage: "cart.fill") {
              let result = progression.upgradePurchaseResult(for: upgrade.id, availableCapital: store.finance.cash)
              if case .purchased(let cost) = result { pendingPurchase = .upgrade(upgrade.id, cost) }
              else { store.alertMessage = message(for: result) }
            }
            .buttonStyle(.bordered)
          }
        }
        .padding(12).background(.white.opacity(0.035), in: .rect(cornerRadius: 12))
        .gameplayMotion(.celebration, value: owned)
      }
    }
    .soloCard()
    .gameplayMotion(value: progression.purchasedUpgrades)
  }

  private var facilitySwitcher: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("OWNED FACILITIES").font(.caption.weight(.black)).tracking(2).foregroundStyle(SoloTheme.cyan)
      ForEach(FacilityTier.allCases.filter { progression.ownedFacilities.contains($0) }) { facility in
        FacilitySwitchRow(
          facility: facility,
          isActive: facility == progression.currentFacility,
          activate: { _ = progression.activate(facility) }
        )
      }
    }
    .soloCard()
    .gameplayMotion(value: progression.ownedFacilities)
  }

  private func complete(_ purchase: TreasuryPurchase) {
    var purchased = false
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      switch purchase {
      case .facility(let facility, _):
        if case .purchased = store.purchaseFacility(facility) { purchased = true }
      case .upgrade(let upgrade, _):
        if case .purchased = store.purchaseFacilityUpgrade(upgrade) { purchased = true }
      }
    }
    if purchased { settings.playFeedback(.infrastructureInstall) }
  }

  private func message(for result: FounderProgressionStore.PurchaseResult) -> String {
    switch result {
    case .alreadyOwned: "Already purchased."
    case .predecessorRequired: "Purchase the preceding headquarters first."
    case .trackRecordRequired(let value): "Track Record \(value) is required."
    case .completedCareersRequired(let value): "Complete \(value) career(s) first."
    case .insufficientCapital(let cost): "This requires \(cost.formatted(.currency(code: "USD").precision(.fractionLength(0))))."
    case .futureEnvironment: "This environment is not available yet."
    case .facilityRequired(let facility): "Requires \(facility.name)."
    case .purchased: "Ready to purchase."
    }
  }
}

private struct FacilitySwitchRow: View {
  var facility: FacilityTier
  var isActive: Bool
  var activate: () -> Void

  var body: some View {
    Button(action: activate) {
      HStack {
        Image(systemName: facility.symbol)
        Text(facility.name)
        Spacer()
        if isActive { Image(systemName: "checkmark").transition(.scale.combined(with: .opacity)) }
      }
    }
    .buttonStyle(.bordered)
    .tint(isActive ? SoloTheme.cyan : .secondary)
    .gameplayMotion(.emphasis, value: isActive)
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
  }
}

private enum TreasuryPurchase: Identifiable {
  case facility(FacilityTier, Int)
  case upgrade(FacilityUpgradeID, Int)

  var id: String {
    switch self {
    case .facility(let facility, _): "facility-\(facility.rawValue)"
    case .upgrade(let upgrade, _): "upgrade-\(upgrade.rawValue)"
    }
  }

  var cost: Int {
    switch self { case .facility(_, let cost), .upgrade(_, let cost): cost }
  }

  var actionTitle: String { "Purchase" }
}
