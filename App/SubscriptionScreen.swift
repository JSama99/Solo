import RevenueCat
import RevenueCatUI
import SwiftUI

struct SubscriptionScreen: View {
  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var showsPaywall = false
  @State private var showsCustomerCenter = false

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
            : "One purchase, no subscription. Unlocks Venture 2, Hindsight Recall, and the full career outcome.")
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
                Task { await subscriptions.purchase(package) }
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(package.storeProduct.localizedTitle)
                      .font(.headline)
                    Text(package.storeProduct.productIdentifier)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  if subscriptions.purchasingPackageID == package.identifier {
                    ProgressView()
                  } else {
                    Text(package.storeProduct.localizedPriceString)
                      .font(.headline.monospacedDigit())
                  }
                }
                .frame(maxWidth: .infinity)
                .padding(15)
                .background(SoloTheme.card, in: .rect(cornerRadius: 14))
              }
              .buttonStyle(SoloPressStyle())
              .disabled(subscriptions.purchasingPackageID != nil)
            }
          }
        }

        Button("View RevenueCat Paywall", systemImage: "rectangle.portrait.and.arrow.right") {
          showsPaywall = true
        }
        .buttonStyle(SoloPrimaryButtonStyle())

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
    }
    .refreshable {
      await subscriptions.refresh()
    }
    .sheet(isPresented: $showsPaywall) {
      PaywallView()
        .onPurchaseCompleted { customerInfo in
          subscriptions.apply(customerInfo)
        }
        .onRestoreCompleted { customerInfo in
          subscriptions.apply(customerInfo)
        }
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
}
