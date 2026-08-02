import Foundation

enum RevenueCatConfiguration {
  static let entitlementIdentifier = "solo_unicorn_run_pro"
  static let entitlementDisplayName = "Solo: Unicorn Run Pro"
  static let productIdentifiers = ["lifetime", "yearly", "monthly"]

  static var apiKey: String {
    #if DEBUG
    "test_soQsjOHWBteHDHRiLxIhVvRDZuu"
    #else
    Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
    #endif
  }
}
