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
          .milestoneReveal(order: 0)

          if let grade = checkpoint.grade {
            VStack(alignment: .leading, spacing: 8) {
              Label("\(grade.overall) venture grade", systemImage: "graduationcap.fill")
                .font(.headline)
                .foregroundStyle(SoloTheme.mint)
                .symbolEffect(.bounce, value: grade.overall)
              Text(grade.identity).font(.title3.bold())
              Text("Revenue \(grade.revenue) • Verification \(grade.verification) • Evidence \(grade.evidence) • Sustainability \(grade.sustainability) • Trust \(grade.trust)")
                .font(.caption).foregroundStyle(.secondary)
            }
            .soloCard()
            .milestoneReveal(order: 1)
          }

          VStack(alignment: .leading, spacing: 8) {
            Label("Next: Venture \(checkpoint.venture + 1)", systemImage: "arrow.forward.circle.fill").font(.headline)
            Text("\(checkpoint.nextEraName ?? VentureEra.era(for: checkpoint.venture + 1).name) era").font(.title3.bold())
            Text(checkpoint.nextEraForce ?? VentureEra.era(for: checkpoint.venture + 1).newForce).font(.caption).foregroundStyle(.secondary)
            if checkpoint.crossesEraBoundary { Label("Era transition — the operating rules intensify here.", systemImage: "exclamationmark.triangle.fill").font(.caption.weight(.semibold)).foregroundStyle(SoloTheme.amber) }
            Text("Objective revealed: \(checkpoint.nextObjectiveTitle ?? "???")").font(.caption.weight(.semibold)).foregroundStyle(SoloTheme.cyan)
            Text("Carries forward: \(checkpoint.precedentsBanked) new precedents • agent relationships average \(checkpoint.averageRelationship)").font(.caption).foregroundStyle(.secondary)
            ForEach(checkpoint.obligations) { obligation in
              Text("\(obligation.title) — caused by \(obligation.sourceDecision)").font(.caption)
            }
            if !checkpoint.companyFlags.isEmpty { Text("Company flags: \(checkpoint.companyFlags.map(\.name).joined(separator: ", "))").font(.caption).foregroundStyle(.secondary) }
          }
          .soloCard()
          .milestoneReveal(order: 2)

          VStack(alignment: .leading, spacing: 10) {
            Text("This venture's numbers")
              .font(.headline)
            checkpointRow("chart.line.uptrend.xyaxis", "Track Record earned", "+\(checkpoint.trackRecordEarned)", checkpoint.trackRecordEarned)
            checkpointRow("dollarsign.circle.fill", "Revenue", "$\(checkpoint.revenue)", checkpoint.revenue)
            checkpointRow("shield.fill", "Trust", "\(checkpoint.trust)", checkpoint.trust)
            checkpointRow("bolt.fill", "Momentum", "\(checkpoint.momentum)", checkpoint.momentum)
            checkpointRow(
              "brain.head.profile", "Precedents banked this venture", "\(checkpoint.precedentsBanked)",
              checkpoint.precedentsBanked
            )
          }
          .soloCard()
          .milestoneReveal(order: 3)

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
          .milestoneReveal(order: 4)

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
          .milestoneReveal(order: 5)
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

  /// `amount` is the raw number behind the formatted string, so the numeric
  /// content transition has something to interpolate between when the summary
  /// is re-rendered.
  private func checkpointRow(_ symbol: String, _ title: String, _ value: String, _ amount: Int) -> some View {
    HStack {
      Label(title, systemImage: symbol)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.subheadline.bold())
        .foregroundStyle(SoloTheme.amber)
        .contentTransition(.numericText(value: Double(amount)))
        .gameplayMotion(.celebration, value: amount)
    }
    .accessibilityElement(children: .combine)
  }
}
