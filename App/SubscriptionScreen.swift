import RevenueCat
import RevenueCatUI
import SwiftUI

struct SubscriptionScreen: View {
  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var showsCustomerCenter = false
  @State private var selectedPackageIdentifier: String?

  var body: some View {
    @Bindable var subscriptions = subscriptions

    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Label(
            subscriptions.isPro ? "Founder Pass active" : "Founder Pass",
            systemImage: subscriptions.isPro ? "checkmark.seal.fill" : "sparkles"
          )
          .font(.title2.bold())
          .foregroundStyle(subscriptions.isPro ? SoloTheme.mint : SoloTheme.cyan)
          Text(subscriptions.isPro
            ? "Venture 2 and Hindsight Recall are unlocked on this Apple Account."
            : "Choose monthly, annual, or lifetime access. Every plan unlocks Venture 2, Hindsight Recall, and the full career outcome.")
            .foregroundStyle(.secondary)
        }
        .soloCard()

        if subscriptions.isLoading && subscriptions.packages.isEmpty {
          ProgressView("Loading offerings…")
            .frame(maxWidth: .infinity)
            .soloCard()
        } else if subscriptions.packages.isEmpty {
          PurchaseDiagnosticsCard(status: subscriptions.configurationStatus)
        } else {
          VStack(spacing: 10) {
            ForEach(subscriptions.packages, id: \.identifier) { package in
              Button {
                withAnimation(.snappy) {
                  selectedPackageIdentifier = package.identifier
                }
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: isSelected(package.identifier) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                      isSelected(package.identifier)
                        ? AnyShapeStyle(SoloTheme.cyan)
                        : AnyShapeStyle(.secondary)
                    )
                  VStack(alignment: .leading, spacing: 3) {
                    Text(package.storeProduct.localizedTitle)
                      .font(.headline)
                    Text(FounderPassPlanKind(productIdentifier: package.storeProduct.productIdentifier).billingDescription)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(package.storeProduct.localizedPriceString)
                    .font(.headline.monospacedDigit())
                }
                .frame(maxWidth: .infinity)
                .padding(15)
                .background(
                  isSelected(package.identifier) ? SoloTheme.cyan.opacity(0.12) : SoloTheme.card,
                  in: .rect(cornerRadius: 14)
                )
                .overlay {
                  RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected(package.identifier) ? SoloTheme.cyan : .clear, lineWidth: 2)
                }
              }
              .buttonStyle(SoloPressStyle())
              .disabled(subscriptions.purchasingPackageID != nil)
              .accessibilityAddTraits(isSelected(package.identifier) ? .isSelected : [])
            }
          }
        }

        Button(purchaseButtonTitle, systemImage: "lock.open.fill") {
          guard let selectedPackage else { return }
          Task { await subscriptions.purchase(selectedPackage) }
        }
        .buttonStyle(SoloPrimaryButtonStyle())
        .disabled(selectedPackage == nil || subscriptions.purchasingPackageID != nil)

        Button("Restore Purchases", systemImage: "arrow.clockwise") {
          Task { await subscriptions.restorePurchases() }
        }
        .buttonStyle(SoloSecondaryButtonStyle())
        .disabled(subscriptions.isLoading)

        if subscriptions.isPro {
          Button("Manage Subscription", systemImage: "person.crop.circle") {
            showsCustomerCenter = true
          }
          .buttonStyle(SoloSecondaryButtonStyle())
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Solo Pro")
    .task {
      await subscriptions.refresh()
      selectDefaultPackageIfNeeded()
    }
    .refreshable {
      await subscriptions.refresh()
      selectDefaultPackageIfNeeded()
    }
    .onChange(of: subscriptions.packages.map(\.identifier)) { _, _ in
      selectDefaultPackageIfNeeded()
    }
    .sheet(isPresented: $showsCustomerCenter) {
      CustomerCenterView()
        .onCustomerCenterRestoreCompleted { customerInfo in
          subscriptions.apply(customerInfo)
        }
    }
    .alert("Purchase Status", isPresented: Binding(
      get: { subscriptions.errorMessage != nil },
      set: { if !$0 { subscriptions.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(subscriptions.errorMessage ?? "")
    }
  }

  private var selectedPackage: Package? {
    subscriptions.packages.first { $0.identifier == selectedPackageIdentifier }
  }

  private var purchaseButtonTitle: String {
    guard let selectedPackage else { return "Select a Founder Pass plan" }
    if subscriptions.purchasingPackageID == selectedPackage.identifier { return "Purchasing…" }
    return "Continue with \(selectedPackage.storeProduct.localizedTitle)"
  }

  private func isSelected(_ packageIdentifier: String) -> Bool {
    selectedPackageIdentifier == packageIdentifier
  }

  private func selectDefaultPackageIfNeeded() {
    guard selectedPackage == nil else { return }
    selectedPackageIdentifier = subscriptions.packages.first {
      FounderPassPlanKind(productIdentifier: $0.storeProduct.productIdentifier) == .annual
    }?.identifier ?? subscriptions.packages.first?.identifier
  }
}

enum FounderPassPlanKind: Equatable {
  case monthly
  case annual
  case lifetime
  case other

  init(productIdentifier: String) {
    if productIdentifier.hasSuffix(".monthly") {
      self = .monthly
    } else if productIdentifier.hasSuffix(".annual") {
      self = .annual
    } else if productIdentifier.hasSuffix(".lifetime") {
      self = .lifetime
    } else {
      self = .other
    }
  }

  var billingDescription: String {
    switch self {
    case .monthly: "Auto-renews monthly. Cancel anytime."
    case .annual: "Auto-renews yearly. Cancel anytime."
    case .lifetime: "One-time purchase. No renewal."
    case .other: "Founder Pass access."
    }
  }
}
