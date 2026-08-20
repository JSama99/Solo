import SwiftUI

struct ForkPromptView: View {
  var offer: DivergenceOffer
  var onChoose: (ForkChoice) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Label("Divergence", systemImage: "arrow.triangle.branch")
          .font(.caption.weight(.black))
          .tracking(2)
          .foregroundStyle(SoloTheme.cyan)
        Text("Two companies leave this sprint.")
          .font(.largeTitle.bold())
        Text("Choose the path SOLO takes. A rival will run the road you leave behind for a short, deterministic ghost horizon.")
          .foregroundStyle(.secondary)
        Text(offer.context.summary)
          .font(.caption.weight(.semibold))
          .foregroundStyle(SoloTheme.amber)

        choiceButton(.shipAll, symbol: "shippingbox.fill", detail: "Commit every assigned report, including anything still unverified.")
        choiceButton(.holdUnverified, symbol: "hand.raised.fill", detail: "Remove the assigned report with the least supporting evidence.")

        Label("You will only ever see one path play out. There is no rewind.", systemImage: "lock.fill")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(SoloTheme.background)
    .milestoneReveal(order: 0)
  }

  private func choiceButton(_ choice: ForkChoice, symbol: String, detail: String) -> some View {
    Button {
      onChoose(choice)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        Label(choice.title, systemImage: symbol)
          .font(.headline)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(SoloTheme.card, in: .rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(.white.opacity(0.1), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityHint(detail)
  }
}
