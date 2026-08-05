import SwiftUI

/// Shown when a venture completes in continuous mode. Unlike bounded mode's
/// forced ending at venture 2, this is a real beat with a real payoff that
/// does not stop the career — the player explicitly chooses to keep building
/// or to retire here, on their own terms. See CareerMode and
/// VentureCheckpoint in GameModels.swift, and BUILD5_CHANGELOG.md for why
/// this exists as a genuine choice rather than either a forced continuation
/// or a forced stop.
struct VentureCheckpointScreen: View {
  var store: GameStore

  private var checkpoint: VentureCheckpoint? { store.pendingVentureCheckpoint }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let checkpoint {
          VStack(alignment: .leading, spacing: 10) {
            Label(checkpoint.headline, systemImage: "flag.checkered")
              .font(.headline)
              .foregroundStyle(SoloTheme.mint)
            Text("Twelve sprints down. The record carries forward.")
              .font(.largeTitle.bold())
            Text("Venture \(checkpoint.venture + 1) starts with everything you've built so far — "
                 + "Track Record, agent relationships, and every precedent still on file.")
              .foregroundStyle(.secondary)
          }
          .soloCard()

          VStack(alignment: .leading, spacing: 10) {
            Text("This venture's numbers")
              .font(.headline)
            checkpointRow("chart.line.uptrend.xyaxis", "Track Record earned", "+\(checkpoint.trackRecordEarned)")
            checkpointRow("dollarsign.circle.fill", "Revenue", "$\(checkpoint.revenue)")
            checkpointRow("shield.fill", "Trust", "\(checkpoint.trust)")
            checkpointRow("bolt.fill", "Momentum", "\(checkpoint.momentum)")
            checkpointRow(
              "brain.head.profile", "Precedents banked this venture", "\(checkpoint.precedentsBanked)"
            )
          }
          .soloCard()

          VStack(alignment: .leading, spacing: 8) {
            Text("Your call")
              .font(.headline)
            Text("Continuous mode never forces an ending. Keep going for as long as it's still "
                 + "interesting, or stop here and let this be the record that stands.")
              .font(.callout)
              .foregroundStyle(.secondary)
            if !store.hasFounderPass {
              Label("Founder Pass is required only to continue. Retirement remains available.", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SoloTheme.amber)
            }
          }
          .soloCard()

          VStack(spacing: 10) {
            Button {
              store.continueFromCheckpoint()
            } label: {
              Label("Continue to Venture \(checkpoint.venture + 1)", systemImage: "arrow.right.circle.fill")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(SoloTheme.cyan)
            .controlSize(.large)

            Button(role: .none) {
              store.retireCareer()
            } label: {
              Label("Retire — end the career here", systemImage: "flag.fill")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }
        } else {
          // Defensive fallback: should be unreachable, since this screen only
          // ever presents when GameStore has just populated the checkpoint.
          ContentUnavailableView(
            "No venture summary available",
            systemImage: "exclamationmark.triangle",
            description: Text("Return to the garage and try again.")
          )
        }
      }
      .padding(18)
    }
    .background(SoloTheme.background)
  }

  private func checkpointRow(_ symbol: String, _ title: String, _ value: String) -> some View {
    HStack {
      Label(title, systemImage: symbol)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.subheadline.bold())
        .foregroundStyle(SoloTheme.amber)
    }
    .accessibilityElement(children: .combine)
  }
}
