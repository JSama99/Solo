import Foundation

struct VentureObjective: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var framing: String
  var minimumEra: VentureEra?
  var revenueTarget: Int
  var trustTarget: Int
  var evidenceTarget: Int
  var completedObjectivesTarget: Int
  var maximumObligations: Int
  var rewardLabel: String
  var reward: SimulationEffects

  func progress(revenue: Int, trust: Int, evidence: Int, completedObjectives: Int, obligations: Int) -> Double {
    let checks = [
      revenueTarget == 0 ? 1 : min(1, Double(revenue) / Double(revenueTarget)),
      trustTarget == 0 ? 1 : min(1, Double(trust) / Double(trustTarget)),
      evidenceTarget == 0 ? 1 : min(1, Double(evidence) / Double(evidenceTarget)),
      completedObjectivesTarget == 0 ? 1 : min(1, Double(completedObjectives) / Double(completedObjectivesTarget)),
      maximumObligations == Int.max ? 1 : (obligations <= maximumObligations ? 1 : 0)
    ]
    return min(1, max(0, checks.reduce(0, +) / Double(checks.count)))
  }

  func isMet(revenue: Int, trust: Int, evidence: Int, completedObjectives: Int, obligations: Int) -> Bool {
    progress(revenue: revenue, trust: trust, evidence: evidence, completedObjectives: completedObjectives, obligations: obligations) == 1
  }

  static func selected(for venture: Int) -> VentureObjective {
    let era = VentureEra.era(for: venture)
    let eligible = all.filter { $0.minimumEra == nil || $0.minimumEra!.rawValue <= era.rawValue }
    return eligible[(venture * 7 + era.rawValue * 3) % eligible.count]
  }

  static let all: [VentureObjective] = [
    .init(id: "pmf", title: "Reach Product-Market Fit", framing: "Turn recurring proof into a repeatable business.", minimumEra: nil, revenueTarget: 1_500, trustTarget: 70, evidenceTarget: 4, completedObjectivesTarget: 0, maximumObligations: Int.max, rewardLabel: "+$250 revenue", reward: .init(revenue: 250)),
    .init(id: "proof", title: "Build the Proof Loop", framing: "Make verified evidence a company habit.", minimumEra: nil, revenueTarget: 0, trustTarget: 72, evidenceTarget: 8, completedObjectivesTarget: 0, maximumObligations: Int.max, rewardLabel: "+6 Trust", reward: .init(trust: 6)),
    .init(id: "durable", title: "Protect the Founder", framing: "Make growth sustainable enough to repeat.", minimumEra: nil, revenueTarget: 1_000, trustTarget: 65, evidenceTarget: 3, completedObjectivesTarget: 0, maximumObligations: 1, rewardLabel: "+8 Energy", reward: .init(energy: 8)),
    .init(id: "retention", title: "Earn Customer Confidence", framing: "Compound trust before turning up the pace.", minimumEra: .traction, revenueTarget: 2_000, trustTarget: 78, evidenceTarget: 6, completedObjectivesTarget: 1, maximumObligations: Int.max, rewardLabel: "+5 Momentum", reward: .init(momentum: 5)),
    .init(id: "repeatable", title: "Repeat the Win", framing: "Show that the company can reproduce results.", minimumEra: .traction, revenueTarget: 2_500, trustTarget: 74, evidenceTarget: 7, completedObjectivesTarget: 1, maximumObligations: 2, rewardLabel: "+3 Runway", reward: .init(runway: 3)),
    .init(id: "signal", title: "Own the Signal", framing: "Use evidence to keep the market narrative honest.", minimumEra: .scale, revenueTarget: 3_000, trustTarget: 80, evidenceTarget: 10, completedObjectivesTarget: 2, maximumObligations: Int.max, rewardLabel: "+8 Trust", reward: .init(trust: 8)),
    .init(id: "scale", title: "Scale Without Drift", framing: "Expand while verification stays ahead of risk.", minimumEra: .scale, revenueTarget: 4_000, trustTarget: 76, evidenceTarget: 12, completedObjectivesTarget: 2, maximumObligations: 2, rewardLabel: "+6 Momentum", reward: .init(momentum: 6)),
    .init(id: "public", title: "Stand Up to Scrutiny", framing: "Keep customer trust under public attention.", minimumEra: .marketLeader, revenueTarget: 5_000, trustTarget: 82, evidenceTarget: 14, completedObjectivesTarget: 3, maximumObligations: 2, rewardLabel: "+$400 revenue", reward: .init(revenue: 400)),
    .init(id: "resilient", title: "Build a Resilient Company", framing: "Keep pressure from consuming the operating core.", minimumEra: .marketLeader, revenueTarget: 5_500, trustTarget: 78, evidenceTarget: 15, completedObjectivesTarget: 3, maximumObligations: 1, rewardLabel: "+10 Energy", reward: .init(energy: 10)),
    .init(id: "portfolio", title: "Compound the Portfolio", framing: "Convert a deep record into durable momentum.", minimumEra: .empire, revenueTarget: 6_500, trustTarget: 80, evidenceTarget: 18, completedObjectivesTarget: 4, maximumObligations: 2, rewardLabel: "+5 Runway", reward: .init(runway: 5)),
    .init(id: "legacy", title: "Set the Standard", framing: "Make your company the evidence-backed reference.", minimumEra: .empire, revenueTarget: 7_500, trustTarget: 85, evidenceTarget: 20, completedObjectivesTarget: 5, maximumObligations: 1, rewardLabel: "+10 Trust", reward: .init(trust: 10)),
    .init(id: "dynasty", title: "Secure the Dynasty", framing: "Leave a company that can survive its own scale.", minimumEra: .dynasty, revenueTarget: 9_000, trustTarget: 88, evidenceTarget: 24, completedObjectivesTarget: 6, maximumObligations: 2, rewardLabel: "+8 Momentum", reward: .init(momentum: 8))
  ]
}

struct VentureGrade: Codable, Hashable { var revenue: String; var verification: String; var evidence: String; var sustainability: String; var trust: String; var overall: String; var identity: String }

enum VentureGrader {
  static func grade(revenue: Int, attention: Int, reviews: Int, overclaimsCaught: Int, evidence: Int, energy: Int, obligations: Int, trust: Int, flags: Set<CompanyFlag>) -> VentureGrade {
    func letter(_ score: Int) -> String { switch score { case 90...: "A"; case 80...: "B"; case 70...: "C"; case 60...: "D"; default: "F" } }
    let revenueScore = min(100, revenue / 75)
    let verificationScore = min(100, reviews * 12 + overclaimsCaught * 8 + attention * 4)
    let evidenceScore = min(100, evidence * 8)
    let sustainabilityScore = max(0, min(100, energy - obligations * 10))
    let trustScore = trust
    let overall = (revenueScore + verificationScore + evidenceScore + sustainabilityScore + trustScore) / 5
    let identity: String
    if flags.contains(.evidenceLedClaims) || flags.contains(.evidenceDifferentiation) { identity = "Evidence-Driven Growth Company" }
    else if flags.contains(.protectedFounderHealth) { identity = "Sustainable Execution Company" }
    else if flags.contains(.hypeFirst) || flags.contains(.competitorRace) { identity = "High-Pressure Market Company" }
    else { identity = "Deliberate Builder Company" }
    return .init(revenue: letter(revenueScore), verification: letter(verificationScore), evidence: letter(evidenceScore), sustainability: letter(sustainabilityScore), trust: letter(trustScore), overall: letter(overall), identity: identity)
  }
}
