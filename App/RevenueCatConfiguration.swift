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
  static let entitlementIdentifier = "solo_unicorn_run_pro"
  static let entitlementDisplayName = "Founder Pass"

  /// The App Store Connect product configured for this app.
  ///
  /// Informational only: used for setup diagnostics and support copy. Nothing
  /// in the purchase path depends on it, so a mismatch here can never again
  /// produce an unbuyable paywall.
  static let expectedStoreProductIdentifier = "com.talonsight.solounicornrun.founderpass"

  /// Offering identifier RevenueCat serves when none is explicitly requested.
  static let defaultOfferingIdentifier = "default"

  enum BuildChannel {
    case debug
    case release
  }

  enum KeyValidation: Equatable {
    case valid
    case missing
    case secret
    case testKeyInRelease
    case invalidApplePublicKey
  }

  static var apiKey: String {
    #if DEBUG
    if let override = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
       !override.isEmpty {
      return override.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return testStoreAPIKey
    #else
    return (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    #endif
  }

  /// RevenueCat Test Store key. Debug builds only; never shipped in Release.
  static let testStoreAPIKey = "test_soQsjOHWBteHDHRiLxIhVvRDZuu"

  static func isTestStoreKey(_ key: String) -> Bool { key.hasPrefix("test_") }

  /// A public Apple SDK key, the only kind valid for a Release build.
  static func isAppleProductionKey(_ key: String) -> Bool { key.hasPrefix("appl_") }

  /// Guards against the classic shipping mistake: a secret key on device.
  static func isSecretKey(_ key: String) -> Bool { key.hasPrefix("sk_") }

  static func validateAPIKey(_ rawKey: String, for channel: BuildChannel) -> KeyValidation {
    let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return .missing }
    guard !isSecretKey(key) else { return .secret }

    switch channel {
    case .debug:
      return isTestStoreKey(key) || isAppleProductionKey(key) ? .valid : .invalidApplePublicKey
    case .release:
      if isTestStoreKey(key) { return .testKeyInRelease }
      return isAppleProductionKey(key) ? .valid : .invalidApplePublicKey
    }
  }

  static var runtimeKeyValidation: KeyValidation {
    #if DEBUG
    validateAPIKey(apiKey, for: .debug)
    #else
    validateAPIKey(apiKey, for: .release)
    #endif
  }

  static func preferredOfferingIdentifier(
    currentIdentifier: String?,
    availableIdentifiers: Set<String>
  ) -> String? {
    if let currentIdentifier, availableIdentifiers.contains(currentIdentifier) {
      return currentIdentifier
    }
    if availableIdentifiers.contains(defaultOfferingIdentifier) {
      return defaultOfferingIdentifier
    }
    return nil
  }
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
  case invalidApplePublicKey
  case noCurrentOffering
  case offeringHasNoPackages
  case ready(packageCount: Int)

  var isBlocking: Bool {
    if case .ready = self { return false }
    return true
  }

  var headline: String {
    switch self {
    case .notConfigured, .missingAPIKey, .secretKeyOnDevice,
         .testKeyInReleaseBuild, .invalidApplePublicKey,
         .noCurrentOffering, .offeringHasNoPackages:
      "Founder Pass temporarily unavailable"
    case .ready: "Founder Pass options ready"
    }
  }

  /// Player-facing recovery guidance. Provider diagnostics belong in logs and
  /// release documentation, never in the production interface.
  var remedy: String {
    switch self {
    case .notConfigured, .missingAPIKey, .secretKeyOnDevice,
         .testKeyInReleaseBuild, .invalidApplePublicKey,
         .noCurrentOffering, .offeringHasNoPackages:
      "Founder Pass options are temporarily unavailable. Your career is safe. Try again later."
    case .ready(let count):
      "\(count) package\(count == 1 ? "" : "s") available."
    }
  }
}
