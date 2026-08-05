import RevenueCat
import RevenueCatUI
import SwiftUI

/// Shown when Venture 1 is complete and the Founder Pass is not yet active.
///
/// The career is not over and nothing is discarded — the run is held at the
/// gate and resumes at exactly this point on unlock. The pitch is the
/// precedents the player already earned, which is the honest one: Venture 2 is
/// where a banked precedent can actually pay off.
struct VentureUnlockScreen: View {
  var store: GameStore
  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var showsPaywall = false

  private var precedentCount: Int { store.precedents.count }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 10) {
          Label("Venture \(store.venture) complete", systemImage: "checkmark.seal.fill")
            .font(.headline)
            .foregroundStyle(SoloTheme.mint)
          Text(store.careerMode == .continuous ? "Continue—or retire here." : "Two ventures. One track record.")
            .font(.largeTitle.bold())
          Text(store.careerMode == .continuous
               ? "The checkpoint is yours. Retirement is always available; Founder Pass unlocks the next venture."
               : "You finished twelve sprints and banked what they taught you. Venture 2 is where that record starts compounding.")
            .foregroundStyle(.secondary)
        }
        .soloCard()

        VStack(alignment: .leading, spacing: 12) {
          Label("\(precedentCount) precedent\(precedentCount == 1 ? "" : "s") recorded",
                systemImage: "brain.head.profile")
            .font(.headline)
            .foregroundStyle(SoloTheme.amber)
          Text(precedentCount > 0
               ? "Your decisions and what followed them are on file. In Venture 2, a structurally similar "
                 + "situation surfaces the matching precedent — the conditions and the outcome, never advice."
               : "Venture 2 records precedents from consequential sprints and recalls them when the "
                 + "conditions repeat.")
            .font(.callout)
            .foregroundStyle(.secondary)

          ForEach(store.precedents.prefix(3)) { precedent in
            VStack(alignment: .leading, spacing: 3) {
              Text(precedent.recallTitle)
                .font(.caption.bold())
                .foregroundStyle(SoloTheme.cyan)
              Text(precedent.context.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(SoloTheme.background.opacity(0.5), in: .rect(cornerRadius: 10))
          }
        }
        .soloCard()

        VStack(alignment: .leading, spacing: 10) {
          Text("Founder Pass unlocks")
            .font(.headline)
          unlockRow(
            "arrow.right.circle.fill",
            store.careerMode == .continuous ? "Venture \(store.venture + 1)" : "Venture 2",
            "Twelve more sprints, carrying this company and its obligations forward."
          )
          unlockRow("brain.head.profile", "Hindsight Recall", "Past precedents surface when the conditions repeat.")
          unlockRow("trophy.fill", "Full career outcome", "Complete the twenty-four-sprint track record.")
          Text("One purchase. No subscription.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .soloCard()

        if subscriptions.configurationStatus.isBlocking {
          PurchaseDiagnosticsCard(status: subscriptions.configurationStatus)
        }

        VStack(spacing: 10) {
          Button {
            showsPaywall = true
          } label: {
            Label("Unlock Venture \(store.venture + 1)", systemImage: "lock.open.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(SoloTheme.cyan)
          .controlSize(.large)

          Button("Restore Purchase") {
            Task { await subscriptions.restorePurchases() }
          }
          .buttonStyle(.bordered)
          .frame(maxWidth: .infinity)

          Button(store.pendingVentureCheckpoint == nil ? "Back to Garage" : "Back to Checkpoint") {
            store.reviewCompletedVenture()
          }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }

        if let error = subscriptions.errorMessage {
          Text(error)
            .font(.footnote)
            .foregroundStyle(SoloTheme.coral)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(18)
    }
    .background(SoloTheme.background)
    .sheet(isPresented: $showsPaywall) {
      PaywallView(displayCloseButton: true)
    }
    .task { await subscriptions.refresh() }
    .onChange(of: subscriptions.isPro) { _, isPro in
      if isPro { store.resumeAfterFounderPassUnlock() }
    }
  }

  private func unlockRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(SoloTheme.cyan)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.bold())
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// Surfaces a misconfigured purchase stack instead of failing silently.
struct PurchaseDiagnosticsCard: View {
  var status: PurchaseConfigurationStatus

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(status.headline, systemImage: "exclamationmark.triangle.fill")
        .font(.subheadline.bold())
        .foregroundStyle(SoloTheme.amber)
      Text(status.remedy)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .soloCard()
    .accessibilityElement(children: .combine)
  }
}
