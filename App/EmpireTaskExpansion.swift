import Foundation

extension ContentLibrary {
  static let empireTaskExpansion: [SoloTask] = [
    SoloTask(title: "Shard the Data Layer", detail: "Split the database before growth turns latency into churn.", role: .engineering, category: .operations, urgency: .important, impact: .momentum(8), skipEffects: SimulationEffects(momentum: -3, trust: -2)),
    SoloTask(title: "Build Multi-Model Router", detail: "Route work across families so no single provider can stall the company.", role: .engineering, category: .trust, urgency: .important, impact: .trust(9), skipEffects: SimulationEffects(trust: -4)),
    SoloTask(title: "Ship Rollback System", detail: "Make every release reversible before a bad one reaches customers.", role: .engineering, category: .operations, impact: .trust(8), skipEffects: SimulationEffects(trust: -4)),
    SoloTask(title: "Add SSO and Audit Logs", detail: "Meet the enterprise security bar every large buyer now assumes.", role: .engineering, category: .sales, urgency: .important, impact: .revenue(1_080), skipEffects: SimulationEffects(revenue: -260)),
    SoloTask(title: "Cut Inference Costs", detail: "Trim the per-request bill that quietly eats the margin at scale.", role: .engineering, category: .operations, impact: .runway(6), skipEffects: SimulationEffects(runway: -2)),
    SoloTask(title: "Harden Rate Limits", detail: "Keep one abusive integration from degrading everyone's experience.", role: .engineering, category: .crisis, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(trust: -6)),
    SoloTask(title: "Build Sandbox Environment", detail: "Let customers test integrations without risking live data.", role: .engineering, category: .product, impact: .momentum(7), skipEffects: SimulationEffects(momentum: -2)),
    SoloTask(title: "Automate Regression Suite", detail: "Catch breakage before customers become the test harness.", role: .engineering, category: .operations, impact: .trust(8), skipEffects: SimulationEffects(trust: -3)),
    SoloTask(title: "Migrate to Region Failover", detail: "Survive a datacenter outage without a company-ending pause.", role: .engineering, category: .crisis, urgency: .critical, impact: .trust(11), skipEffects: SimulationEffects(momentum: -3, trust: -7)),
    SoloTask(title: "Open the Public API", detail: "Turn the product into a platform others build revenue on.", role: .engineering, category: .product, urgency: .important, impact: .revenue(940), skipEffects: SimulationEffects(momentum: -3)),

    SoloTask(title: "Model Competitor Roadmap", detail: "Anticipate the rival's next move instead of reacting to it.", role: .research, category: .research, impact: .momentum(7), skipEffects: SimulationEffects(momentum: -2)),
    SoloTask(title: "Quantify Correlated Risk", detail: "Measure how much of the workforce fails together under stress.", role: .research, category: .trust, urgency: .important, impact: .trust(9), skipEffects: SimulationEffects(trust: -5)),
    SoloTask(title: "Run Expansion Study", detail: "Find which adjacent market rewards the existing product first.", role: .research, category: .research, impact: .revenue(880), skipEffects: SimulationEffects(revenue: -200)),
    SoloTask(title: "Verify Regulatory Exposure", detail: "Know which claims must survive an outside audit before scrutiny arrives.", role: .research, category: .trust, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(trust: -6)),
    SoloTask(title: "Segment the Customer Base", detail: "Separate the accounts worth defending from the ones bleeding support.", role: .research, category: .research, impact: .revenue(720), skipEffects: SimulationEffects(revenue: -160)),
    SoloTask(title: "Audit Agent Calibration", detail: "Find where confidence has drifted away from real accuracy.", role: .research, category: .trust, impact: .trust(8), skipEffects: SimulationEffects(trust: -4)),
    SoloTask(title: "Study Retention Cohorts", detail: "Learn whether the newest customers stay longer than the last wave.", role: .research, category: .research, urgency: .important, impact: .revenue(760), skipEffects: SimulationEffects(revenue: -170)),
    SoloTask(title: "Map the Acquisition Landscape", detail: "Understand who would buy the company and what they value.", role: .research, category: .operations, impact: .momentum(6), skipEffects: SimulationEffects(momentum: -1)),
    SoloTask(title: "Benchmark Support Quality", detail: "Prove whether agent-run support holds up against human teams.", role: .research, category: .trust, impact: .trust(7), skipEffects: SimulationEffects(trust: -3)),
    SoloTask(title: "Forecast Talent Fatigue", detail: "Predict where sustained pressure will degrade the workforce first.", role: .research, category: .founderLife, impact: .energy(8), skipEffects: SimulationEffects(energy: -4)),

    SoloTask(title: "Land a Reference Customer", detail: "Convert one prestigious logo into market permission to win others.", role: .marketing, category: .sales, urgency: .important, impact: .revenue(1_100), skipEffects: SimulationEffects(revenue: -300, trust: -1)),
    SoloTask(title: "Publish the Trust Report", detail: "Make verification a public differentiator competitors can't fake.", role: .marketing, category: .trust, impact: .trust(9), skipEffects: SimulationEffects(trust: -2)),
    SoloTask(title: "Run Category Keynote", detail: "Define the category on stage before a rival names it first.", role: .marketing, category: .sales, urgency: .important, impact: .momentum(9), skipEffects: SimulationEffects(momentum: -3)),
    SoloTask(title: "Expand to New Region", detail: "Open a market the product already fits but no one is selling to.", role: .marketing, category: .sales, impact: .revenue(1_020), skipEffects: SimulationEffects(revenue: -280)),
    SoloTask(title: "Defend Against a Smear", detail: "Answer a viral accusation with evidence before it sets the story.", role: .marketing, category: .crisis, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(momentum: -2, trust: -6)),
    SoloTask(title: "Launch Partner Program", detail: "Let others sell the product in exchange for a share of the upside.", role: .marketing, category: .sales, urgency: .important, impact: .revenue(900), skipEffects: SimulationEffects(revenue: -200)),
    SoloTask(title: "Convert Free Cohort", detail: "Turn the most engaged non-payers into the next revenue wave.", role: .marketing, category: .sales, impact: .revenue(980), skipEffects: SimulationEffects(revenue: -220)),
    SoloTask(title: "Rebrand for Enterprise", detail: "Signal seriousness to buyers who won't touch a hobby project.", role: .marketing, category: .sales, impact: .momentum(8), skipEffects: SimulationEffects(momentum: -3)),
    SoloTask(title: "Win an Industry Award", detail: "Earn third-party credibility that shortens every future sales cycle.", role: .marketing, category: .sales, impact: .momentum(9), skipEffects: SimulationEffects(momentum: -2)),
    SoloTask(title: "Reactivate Dormant Accounts", detail: "Bring back customers who left before the product was ready for them.", role: .marketing, category: .crisis, urgency: .important, impact: .revenue(860), skipEffects: SimulationEffects(revenue: -180, trust: -2)),

    SoloTask(title: "Restructure the Cap Table", detail: "Fix ownership before the next raise makes it permanent.", role: .general, category: .operations, urgency: .important, impact: .runway(6), skipEffects: SimulationEffects(runway: -2)),
    SoloTask(title: "Build the Ops Playbook", detail: "Turn tribal knowledge into a system that runs without the founder.", role: .general, category: .operations, impact: .momentum(7), skipEffects: SimulationEffects(energy: -2)),
    SoloTask(title: "Negotiate Cloud Commit", detail: "Trade a usage commitment for the discount that saves the quarter.", role: .general, category: .operations, impact: .runway(6), skipEffects: SimulationEffects(runway: -2)),
    SoloTask(title: "Set Up the Board Cadence", detail: "Make investor oversight a rhythm instead of a recurring fire drill.", role: .general, category: .operations, impact: .trust(7), skipEffects: SimulationEffects(trust: -2)),
    SoloTask(title: "Take a Real Vacation", detail: "Prove the company survives a week without the founder in the loop.", role: .general, category: .founderLife, urgency: .important, impact: .energy(11), skipEffects: SimulationEffects(energy: -7)),
    SoloTask(title: "Codify Company Values", detail: "Write down what the company won't do before scale tests it.", role: .general, category: .operations, impact: .trust(7), skipEffects: SimulationEffects(trust: -2)),
    SoloTask(title: "Run the Incident Drill", detail: "Rehearse the worst day so the real one isn't the first attempt.", role: .general, category: .crisis, impact: .trust(8), skipEffects: SimulationEffects(trust: -3)),
    SoloTask(title: "Fix the On-Call Rotation", detail: "Stop the founder from being the permanent emergency contact.", role: .general, category: .founderLife, impact: .energy(9), skipEffects: SimulationEffects(energy: -5)),
    SoloTask(title: "Consolidate Vendor Sprawl", detail: "Cut the redundant tools quietly draining runway every month.", role: .general, category: .operations, impact: .runway(5), skipEffects: SimulationEffects(runway: -2)),
    SoloTask(title: "Mentor the Next Owner", detail: "Grow someone who can carry a domain the founder currently holds alone.", role: .general, category: .founderLife, impact: .momentum(7), skipEffects: SimulationEffects(energy: -3))
  ]
}
