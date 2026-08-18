import SwiftUI

struct PurchaseLegalDisclosure: View {
  private var privacyPolicyURL: URL { URL(string: "https://www.talonsight.com/privacy")! }
  private var termsURL: URL { URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")! }

  var body: some View {
    VStack(spacing: 6) {
      Text("Payment is charged to your Apple Account. Monthly and annual plans renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel subscriptions in your App Store account settings.")
        .multilineTextAlignment(.center)
      HStack(spacing: 12) {
        Link("Privacy Policy", destination: privacyPolicyURL)
        Link("Terms of Use", destination: termsURL)
      }
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }
}
