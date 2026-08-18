import Foundation

/// RevenueCat configuration.
///
/// DESIGN RULE — and the reason Build 2's paywall rendered empty:
/// access is gated on the ENTITLEMENT only. The app never filters, matches, or
/// branches on store product identifiers. Build 2 hardcoded
/// `["lifetime", "yearly", "monthly"]` and filtered the current offering against
/// that list, so the single configured App Store product
/// (`com.talonsight.solounicornrun.founderpass`) never matched, `packages` was
/// always empty, the paywall showed "Offering Not Ready", and nothing could be
/// purchased.
///
/// Whatever packages the current offering contains are now displayed as-is, so
/// the dashboard catalog can be renamed, re-priced, or restructured without an
/// app update. That is the entire point of remote offerings.
enum RevenueCatConfiguration {
  /// The single entitlement that unlocks paid content. This identifier — and
  /// only this identifier — must match the RevenueCat dashboard exactly.
  static let entitlementIdentifier = "Solo: Unicorn Run Pro"
  static let entitlementDisplayName = "Founder Pass"

  /// The App Store Connect product configured for this app.
  ///
  /// Informational only: used for setup diagnostics and support copy. Nothing
  /// in the purchase path depends on it, so a mismatch here can never again
  /// produce an unbuyable paywall.
  static let expectedStoreProductIdentifier = "com.talonsight.solounicornrun.founderpass.lifetime"

  /// Offering identifier RevenueCat serves when none is explicitly requested.
  static let defaultOfferingIdentifier = "default"

  static var apiKey: String {
    #if DEBUG
    if let override = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
       !override.isEmpty {
      return override
    }
    return ""
    #else
    return Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
    #endif
  }

  static func isTestStoreKey(_ key: String) -> Bool { key.hasPrefix("test_") }

  /// A public Apple SDK key, the only kind valid for a Release build.
  static func isAppleProductionKey(_ key: String) -> Bool { key.hasPrefix("appl_") }

  /// Guards against the classic shipping mistake: a secret key on device.
  static func isSecretKey(_ key: String) -> Bool { key.hasPrefix("sk_") }
}

/// Machine-checkable diagnosis of the purchase stack.
///
/// Exists because the Build 2 failure was silent: the paywall looked "loading",
/// not "misconfigured". Every state below names the fix.
enum PurchaseConfigurationStatus: Equatable {
  case notConfigured
  case missingAPIKey
  case secretKeyOnDevice
  case testKeyInReleaseBuild
  case noCurrentOffering
  case offeringHasNoPackages
  case ready(packageCount: Int)

  var isBlocking: Bool {
    if case .ready = self { return false }
    return true
  }

  var headline: String {
    switch self {
    case .notConfigured: "Purchases not configured"
    case .missingAPIKey: "Missing RevenueCat API key"
    case .secretKeyOnDevice: "Secret key detected"
    case .testKeyInReleaseBuild: "Test key in a Release build"
    case .noCurrentOffering: "No current offering"
    case .offeringHasNoPackages: "Offering has no packages"
    case .ready: "Ready to purchase"
    }
  }

  /// The exact next action. Written for whoever is staring at the dashboard.
  var remedy: String {
    switch self {
    case .notConfigured:
      "Call SubscriptionStore.configure() at launch."
    case .missingAPIKey:
      "Set the RevenueCatAPIKey Info.plist value from the REVENUECAT_API_KEY build setting."
    case .secretKeyOnDevice:
      "Remove the sk_ key immediately and rotate it. Ship only the public appl_ key."
    case .testKeyInReleaseBuild:
      "Replace the test_ key with the public Apple SDK key beginning with appl_."
    case .noCurrentOffering:
      "In RevenueCat: Offerings → mark one offering Current. Without a current offering the SDK returns nothing."
    case .offeringHasNoPackages:
      "In RevenueCat: add a package to the current offering and attach the product \(RevenueCatConfiguration.expectedStoreProductIdentifier)."
    case .ready(let count):
      "\(count) package\(count == 1 ? "" : "s") available."
    }
  }
}
