import Foundation
import Observation
import RevenueCat

/// Source of truth for entitlement state.
///
/// Build 3 change: `packages` no longer filters the current offering against a
/// hardcoded product-identifier list. Whatever the offering contains is what the
/// player sees. Access is decided by the entitlement alone.
@MainActor
@Observable
final class SubscriptionStore: NSObject, PurchasesDelegate, EntitlementProviding {
  static let shared = SubscriptionStore()

  private(set) var customerInfo: CustomerInfo?
  private(set) var currentOffering: Offering?
  private(set) var isLoading = false
  private(set) var purchasingPackageID: String?
  private(set) var lastRefreshFailed = false
  var errorMessage: String?

  private var isConfigured = false

  /// The one question the rest of the app asks.
  var isPro: Bool {
    customerInfo?.entitlements[RevenueCatConfiguration.entitlementIdentifier]?.isActive == true
  }

  /// `EntitlementProviding`. Named for the product, not the plumbing.
  var hasFounderPass: Bool { isPro }

  /// Every package in the current offering, unfiltered — see the type doc.
  var packages: [Package] {
    currentOffering?.availablePackages ?? []
  }

  /// Structured diagnosis so a misconfiguration is legible instead of silent.
  var configurationStatus: PurchaseConfigurationStatus {
    let key = RevenueCatConfiguration.apiKey
    if RevenueCatConfiguration.isSecretKey(key) { return .secretKeyOnDevice }
    if key.isEmpty { return .missingAPIKey }
    #if !DEBUG
    if RevenueCatConfiguration.isTestStoreKey(key) { return .testKeyInReleaseBuild }
    #endif
    guard isConfigured else { return .notConfigured }
    guard let offering = currentOffering else { return .noCurrentOffering }
    guard !offering.availablePackages.isEmpty else { return .offeringHasNoPackages }
    return .ready(packageCount: offering.availablePackages.count)
  }

  func configure() {
    guard !isConfigured else { return }
    let apiKey = RevenueCatConfiguration.apiKey

    guard !RevenueCatConfiguration.isSecretKey(apiKey) else {
      errorMessage = "A RevenueCat secret key was found in the app bundle. Remove and rotate it."
      return
    }
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

    Task { await refresh() }
  }

  func refresh() async {
    guard isConfigured else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let info = Purchases.shared.customerInfo()
      async let offerings = Purchases.shared.offerings()
      apply(try await info)
      let resolved = try await offerings
      // Fall back to a named offering if none is marked Current — a very common
      // dashboard omission that otherwise presents as an empty paywall.
      currentOffering = resolved.current
        ?? resolved.offering(identifier: RevenueCatConfiguration.defaultOfferingIdentifier)
      lastRefreshFailed = false
      errorMessage = nil
    } catch {
      lastRefreshFailed = true
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
      if !result.userCancelled { errorMessage = nil }
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
      errorMessage = isPro ? nil : "No previous Founder Pass purchase was found on this Apple Account."
    } catch {
      errorMessage = "Restore failed: \(error.localizedDescription)"
    }
  }

  func apply(_ customerInfo: CustomerInfo) {
    self.customerInfo = customerInfo
  }

  nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    Task { @MainActor in self.apply(customerInfo) }
  }
}
