import SwiftUI

struct HowToPlayContent {
  struct Section: Identifiable { var id: String; var title: String; var symbol: String; var body: String }
  static var phases: [(SprintPhase, String)] { SprintPhase.allCases.map { phase in (phase, phaseDescription(phase)) } }
  static var sections: [Section] { [
    .init(id: "verification", title: "Verification is the Game", symbol: "checkmark.shield.fill", body: "Agents report a quality estimate, but review reveals the actual result when evidence supports it. Founder Attention pays for reviews; unreviewed work is a bet that can add drift and hide risk."),
    .init(id: "agents", title: "Your Agents", symbol: "person.3.fill", body: "Research finds evidence, Engineering ships systems, and Marketing creates demand. Trust affects reliability; drift raises uncertainty. Agents sharing a model family can fail together, creating correlated risk."),
    .init(id: "garage", title: "The Garage", symbol: "house.fill", body: "Tap the desk for the founder dilemma, sprint intent, objective, and commit action. Tap stations to assign agents, swap a draft from the backlog before work begins, inspect reports, and review work."),
    .init(id: "tech", title: "Tech.com", symbol: "newspaper.fill", body: "Your Company records your real operating events. Trends are industry texture. Rivals make claims you can verify with Founder Attention. Rankings compare SOLO with rivals by track record, revenue, or momentum."),
    .init(id: "setup", title: "Setup Choices", symbol: "slider.horizontal.3", body: "Career Length selects a bounded, continuous, or daily run. Doctrine sets how much Founder Attention you receive, how costly review is, how quickly neglected work drifts, and any starting adjustment."),
    .init(id: "progression", title: "Progression", symbol: "chart.line.uptrend.xyaxis", body: "Sprints advance ventures. Every era raises runway and energy pressure while correlated-failure risk grows. Headquarters purchases use capital for persistent operating improvements.")
  ] }
  static func phaseDescription(_ phase: SprintPhase) -> String { switch phase { case .founderEvent: "Resolve the founder dilemma at the desk."; case .chooseCommitments: "Choose the sprint’s three commitments and optional backlog swap."; case .assignTeam: "Assign agents to committed tasks at their stations."; case .reviewAndResolve: "Review reports, spend Attention, then lock a founder resolution."; case .readyToCommit: "All required decisions are locked; commit the sprint at the desk." } }
  static func doctrineDescription(_ doctrine: FounderDoctrine) -> String { let p = DoctrineProfile.profile(for: doctrine); return "\(doctrine.name): \(p.attentionMaximum) Attention, reviews cost \(p.reviewEnergyCost) Energy, neglect adds \(p.neglectDriftIncrease.formatted()) Drift, quality bonus \(p.actualQualityBonus), starting effects \(p.startingStatAdjustment.conciseLossLabel)." }
}

struct HowToPlayScreen: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        DisclosureGroup { VStack(alignment: .leading, spacing: 10) { ForEach(HowToPlayContent.phases, id: \.0.id) { phase, detail in Label { Text("\(phase.title) — \(detail)") } icon: { Image(systemName: phase.symbol).foregroundStyle(SoloTheme.cyan) } } }.padding(.top, 8) } label: { Label("The Sprint Loop", systemImage: "arrow.triangle.2.circlepath") }.soloCard()
        ForEach(HowToPlayContent.sections) { section in
          DisclosureGroup {
            if section.id == "setup" { VStack(alignment: .leading, spacing: 8) { Text(section.body); ForEach(FounderDoctrine.allCases) { Text(HowToPlayContent.doctrineDescription($0)).font(.caption).foregroundStyle(.secondary) } }.padding(.top, 8) }
            else if section.id == "progression" { VStack(alignment: .leading, spacing: 8) { Text(section.body); ForEach(VentureEra.allCases) { era in Text("\(era.name): \(era.newForce) -\(era.runwayBurnPerSprint) Runway, -\(era.energyCostPerSprint) Energy per sprint.").font(.caption).foregroundStyle(.secondary) } }.padding(.top, 8) }
            else { Text(section.body).padding(.top, 8) }
          } label: { Label(section.title, systemImage: section.symbol) }.soloCard()
        }
      }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }.navigationTitle("How to Play")
  }
}
