import Foundation

/// The single question the game asks about paid access.
///
/// Deliberately narrow: `GameStore` must be testable and deterministic without
/// linking RevenueCat, StoreKit, or the network. `SubscriptionStore` supplies
/// the real answer; tests supply a stub.
@MainActor
protocol EntitlementProviding: AnyObject {
  var hasFounderPass: Bool { get }
}

/// Default provider used before purchases are configured, and in previews.
@MainActor
final class StaticEntitlementProvider: EntitlementProviding {
  var hasFounderPass: Bool
  init(hasFounderPass: Bool = false) { self.hasFounderPass = hasFounderPass }
}
