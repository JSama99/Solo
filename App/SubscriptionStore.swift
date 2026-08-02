import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionStore: NSObject, PurchasesDelegate {
  static let shared = SubscriptionStore()

  private(set) var customerInfo: CustomerInfo?
  private(set) var currentOffering: Offering?
  private(set) var isLoading = false
  private(set) var purchasingPackageID: String?
  var errorMessage: String?

  private var isConfigured = false

  var isPro: Bool {
    customerInfo?.entitlements[RevenueCatConfiguration.entitlementIdentifier]?.isActive == true
  }

  var packages: [Package] {
    currentOffering?.availablePackages.filter {
      RevenueCatConfiguration.productIdentifiers.contains($0.storeProduct.productIdentifier)
    } ?? []
  }

  func configure() {
    guard !isConfigured else { return }
    let apiKey = RevenueCatConfiguration.apiKey
    guard !apiKey.isEmpty else {
      errorMessage = "Add the production RevenueCat public SDK key before making a Release build."
      return
    }

    #if DEBUG
    Purchases.logLevel = .debug
    #else
    Purchases.logLevel = .warn
    #endif
    Purchases.configure(withAPIKey: apiKey)
    Purchases.shared.delegate = self
    isConfigured = true

    Task {
      await refresh()
    }
  }

  func refresh() async {
    guard isConfigured else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let customerInfo = Purchases.shared.customerInfo()
      async let offerings = Purchases.shared.offerings()
      apply(try await customerInfo)
      currentOffering = try await offerings.current
      errorMessage = nil
    } catch {
      errorMessage = "Unable to refresh purchases: \(error.localizedDescription)"
    }
  }

  func purchase(_ package: Package) async {
    guard isConfigured else { return }
    purchasingPackageID = package.identifier
    defer { purchasingPackageID = nil }
    do {
      let result = try await Purchases.shared.purchase(package: package)
      apply(result.customerInfo)
      if !result.userCancelled {
        errorMessage = nil
      }
    } catch {
      errorMessage = "Purchase failed: \(error.localizedDescription)"
    }
  }

  func restorePurchases() async {
    guard isConfigured else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      apply(try await Purchases.shared.restorePurchases())
      errorMessage = isPro ? nil : "No active Solo: Unicorn Run Pro purchase was found."
    } catch {
      errorMessage = "Restore failed: \(error.localizedDescription)"
    }
  }

  func apply(_ customerInfo: CustomerInfo) {
    self.customerInfo = customerInfo
  }

  nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    Task { @MainActor in
      self.apply(customerInfo)
    }
  }
}
