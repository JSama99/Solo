import Foundation

/// All authored gameplay content, extracted from GameStore.swift so content
/// review and simulation logic no longer share one file. Build 4 introduced
/// 38 tasks, 12 dilemmas, and 6 objective templates as struct literals
/// embedded directly in the store; this is a pure relocation, not a rewrite —
/// every literal below is byte-identical to what GameStore.swift held.
///
/// This split matters most for what comes next: continuous mode needs this
/// pool to keep growing well past 38 tasks to avoid repetition over a long
/// career (see BUILD5_CHANGELOG.md), and that authoring work should not
/// require touching simulation code to do it.
enum ContentLibrary {
    struct RivalCompanyDefinition {
      var id: String
      var name: String
    }

    static let rivalCompanies = [
      RivalCompanyDefinition(id: "northstar", name: "Northstar Systems"),
      RivalCompanyDefinition(id: "relay", name: "Relay Works"),
      RivalCompanyDefinition(id: "lattice", name: "Lattice Labs")
    ]

    static let rivalSimulationCompanies: [RivalCompany] = [
      RivalCompany(id: "northwind", name: "Northwind Labs", archetype: .incumbent, debutVenture: 1, baseStrength: 1.35),
      RivalCompany(id: "pallas", name: "Pallas AI", archetype: .upstart, debutVenture: 1, baseStrength: 0.9),
      RivalCompany(id: "flashpoint", name: "Flashpoint", archetype: .hypeMachine, debutVenture: 1, baseStrength: 1.0),
      RivalCompany(id: "steadfast", name: "Steadfast Works", archetype: .quietBuilder, debutVenture: 1, baseStrength: 0.85),
      RivalCompany(id: "mirror", name: "Mirrorline", archetype: .copycat, debutVenture: 3, baseStrength: 0.95),
      RivalCompany(id: "summit", name: "Summit Systems", archetype: .incumbent, debutVenture: 16, baseStrength: 1.2)
    ]

    static let techComHeadlineTemplates = [
      NewsHeadlineTemplate(id: "trend-evidence", category: .trend, textTemplate: "Industry watch: evidence-led teams set the tone in sprint {sprint}", trigger: { $0.tasks.contains { $0.isReviewed } }),
      NewsHeadlineTemplate(id: "trend-runway", category: .trend, textTemplate: "Industry watch: runway discipline dominates sprint {sprint}", trigger: { $0.stats.runway < 20 }),
      NewsHeadlineTemplate(id: "trend-energy", category: .trend, textTemplate: "Industry watch: founder energy is becoming a board-level metric", trigger: { $0.stats.energy < 45 }),
      NewsHeadlineTemplate(id: "trend-trust", category: .trend, textTemplate: "Industry watch: trust-first operators gain attention", trigger: { $0.stats.trust >= 70 }),
      NewsHeadlineTemplate(id: "trend-drift", category: .trend, textTemplate: "Industry watch: model drift keeps teams cautious", trigger: { $0.agents.contains { $0.drift >= 25 } }),
      NewsHeadlineTemplate(id: "trend-revenue", category: .trend, textTemplate: "Industry watch: early revenue is changing the conversation", trigger: { $0.stats.revenue >= 1_000 }),
      NewsHeadlineTemplate(id: "trend-momentum", category: .trend, textTemplate: "Industry watch: momentum is rewarding focused launches", trigger: { $0.stats.momentum >= 60 }),
      NewsHeadlineTemplate(id: "trend-prototype", category: .trend, textTemplate: "Industry watch: prototype teams are narrowing their bets", trigger: { $0.sprint <= 3 }),
      NewsHeadlineTemplate(id: "trend-customers", category: .trend, textTemplate: "Industry watch: customer proof outranks launch theatre", trigger: { $0.sprint >= 4 && $0.sprint <= 6 }),
      NewsHeadlineTemplate(id: "trend-launch", category: .trend, textTemplate: "Industry watch: launch pressure is reshaping operating plans", trigger: { $0.sprint >= 7 && $0.sprint <= 9 }),
      NewsHeadlineTemplate(id: "trend-scale", category: .trend, textTemplate: "Industry watch: scale decisions are splitting founders", trigger: { $0.sprint >= 10 }),
      NewsHeadlineTemplate(id: "trend-capital", category: .trend, textTemplate: "Industry watch: capital efficiency remains in fashion", trigger: { $0.stats.capital < 1_000 }),
      NewsHeadlineTemplate(id: "trend-attention", category: .trend, textTemplate: "Industry watch: review capacity is a competitive advantage", trigger: { $0.tasks.contains { $0.result != nil } }),
      NewsHeadlineTemplate(id: "trend-venture", category: .trend, textTemplate: "Industry watch: second-venture companies are planning for repeatability", trigger: { $0.venture > 1 }),
      NewsHeadlineTemplate(id: "trend-resilience", category: .trend, textTemplate: "Industry watch: resilience work earns a larger share of roadmaps", trigger: { $0.stats.trust < 50 }),
      NewsHeadlineTemplate(id: "trend-focus", category: .trend, textTemplate: "Industry watch: focused teams keep their operating edge", trigger: { $0.stats.energy >= 45 && $0.stats.runway >= 20 })
    ]

    static var initialAgents: [SoloAgent] {
      [
        SoloAgent(id: "aurora", name: "Aurora", initials: "AU", role: .research, modelFamily: "Nova-1", reliability: 78, calibration: 0.72, drift: 0, trust: 62),
        SoloAgent(id: "stacks", name: "Stacks", initials: "ST", role: .engineering, modelFamily: "Nova-1", reliability: 82, calibration: 0.78, drift: 0, trust: 66),
        SoloAgent(id: "brio", name: "Brio", initials: "BR", role: .marketing, modelFamily: "Atlas-2", reliability: 75, calibration: 0.61, drift: 0, trust: 58)
      ]
    }

    static let taskPool: [SoloTask] = [
      // Product and engineering
      SoloTask(title: "Build MVP Slice", detail: "Turn the strongest assumption into something playable.", role: .engineering, category: .product, impact: .momentum(8), skipEffects: SimulationEffects(momentum: -2)),
      SoloTask(title: "Fix Critical Crash", detail: "Stabilize the flow customers hit first.", role: .engineering, category: .crisis, urgency: .critical, impact: .trust(9), skipEffects: SimulationEffects(momentum: -2, trust: -5)),
      SoloTask(title: "Ship Usage Analytics", detail: "Instrument the product before opinions replace evidence.", role: .engineering, category: .product, impact: .momentum(7), skipEffects: SimulationEffects(trust: -2)),
      SoloTask(title: "Reduce Load Time", detail: "Remove the delay that is costing activation.", role: .engineering, category: .product, impact: .revenue(520), skipEffects: SimulationEffects(revenue: -120, momentum: -1)),
      SoloTask(title: "Build Audit Export", detail: "Give customers a verifiable record of agent work.", role: .engineering, category: .trust, urgency: .important, impact: .trust(8), skipEffects: SimulationEffects(trust: -3)),
      SoloTask(title: "Prototype Mobile Feature", detail: "Test the next high-leverage interaction.", role: .engineering, category: .product, impact: .momentum(9), skipEffects: SimulationEffects(momentum: -3)),
      SoloTask(title: "Harden Save Migration", detail: "Protect existing careers from schema changes.", role: .engineering, category: .operations, urgency: .important, impact: .trust(7), skipEffects: SimulationEffects(trust: -4)),
      SoloTask(title: "Run Paywall Experiment", detail: "Test the value proposition without damaging trust.", role: .engineering, category: .sales, impact: .revenue(760), skipEffects: SimulationEffects(revenue: -150)),

      // Research and intelligence
      SoloTask(title: "Interview Five Customers", detail: "Find the language customers use for the real pain.", role: .research, category: .research, impact: .trust(6), skipEffects: SimulationEffects(momentum: -1)),
      SoloTask(title: "Competitive Teardown", detail: "Map where the market is strong and where it is bluffing.", role: .research, category: .research, impact: .momentum(6), skipEffects: SimulationEffects(trust: -1)),
      SoloTask(title: "Compliance Scan", detail: "Identify claims the company must be able to prove.", role: .research, category: .trust, urgency: .critical, impact: .trust(9), skipEffects: SimulationEffects(trust: -5)),
      SoloTask(title: "Investigate Churn", detail: "Separate product failure from poor-fit customers.", role: .research, category: .research, urgency: .important, impact: .revenue(620), skipEffects: SimulationEffects(revenue: -180)),
      SoloTask(title: "Audit Agent Outputs", detail: "Find uncertainty before it compounds into policy.", role: .research, category: .trust, impact: .trust(7), skipEffects: SimulationEffects(trust: -3)),
      SoloTask(title: "Benchmark Model Families", detail: "Measure correlated risk across the AI workforce.", role: .research, category: .operations, impact: .trust(7), skipEffects: SimulationEffects(momentum: -2)),
      SoloTask(title: "Price Sensitivity Study", detail: "Learn where willingness to pay actually breaks.", role: .research, category: .sales, impact: .revenue(780), skipEffects: SimulationEffects(revenue: -140)),
      SoloTask(title: "Failure Postmortem", detail: "Turn a hidden miss into a reusable operating precedent.", role: .research, category: .trust, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(momentum: -2, trust: -5)),

      // Marketing and revenue
      SoloTask(title: "Contact Early Customers", detail: "Turn warm conversations into concrete demand.", role: .marketing, category: .sales, impact: .revenue(680), skipEffects: SimulationEffects(revenue: -150)),
      SoloTask(title: "Launch Landing Page", detail: "Publish a promise specific enough to be judged.", role: .marketing, category: .sales, impact: .revenue(520), skipEffects: SimulationEffects(momentum: -2)),
      SoloTask(title: "Demo Enterprise Lead", detail: "Win a serious customer without promising fiction.", role: .marketing, category: .sales, urgency: .critical, impact: .revenue(1_050), skipEffects: SimulationEffects(revenue: -320, trust: -1)),
      SoloTask(title: "Win Back At-Risk Account", detail: "Repair confidence before the customer walks.", role: .marketing, category: .crisis, urgency: .important, impact: .revenue(840), skipEffects: SimulationEffects(revenue: -220, trust: -2)),
      SoloTask(title: "Record Founder Launch Video", detail: "Make the mission human enough to spread.", role: .marketing, category: .sales, impact: .momentum(8), skipEffects: SimulationEffects(momentum: -2)),
      SoloTask(title: "Activate Referral Loop", detail: "Give delighted users a reason to recruit the next one.", role: .marketing, category: .sales, impact: .revenue(640), skipEffects: SimulationEffects(revenue: -120)),
      SoloTask(title: "Pitch Strategic Partner", detail: "Trade distribution for a narrower operating path.", role: .marketing, category: .sales, urgency: .important, impact: .runway(4), skipEffects: SimulationEffects(runway: -1)),
      SoloTask(title: "App Store Feature Story", detail: "Package the product into a story editors can repeat.", role: .marketing, category: .sales, impact: .revenue(920), skipEffects: SimulationEffects(momentum: -3)),

      // Operations and founder life
      SoloTask(title: "Improve Onboarding", detail: "Remove the first ten minutes of confusion.", role: .general, category: .operations, impact: .revenue(430), skipEffects: SimulationEffects(revenue: -100)),
      SoloTask(title: "Prepare Investor Update", detail: "Explain progress, uncertainty, and the next constraint.", role: .research, category: .operations, impact: .runway(4), skipEffects: SimulationEffects(trust: -1)),
      SoloTask(title: "Clear Support Queue", detail: "Close the loop with people already depending on you.", role: .general, category: .operations, urgency: .important, impact: .trust(6), skipEffects: SimulationEffects(trust: -3)),
      SoloTask(title: "Automate Release Checklist", detail: "Turn a fragile launch ritual into a reliable system.", role: .general, category: .operations, impact: .momentum(6), skipEffects: SimulationEffects(trust: -2)),
      SoloTask(title: "Reset the Budget", detail: "Cut waste before runway becomes a crisis.", role: .general, category: .operations, impact: .runway(5), skipEffects: SimulationEffects(runway: -2)),
      SoloTask(title: "Coordinate Contractor", detail: "Turn outside help into leverage instead of overhead.", role: .general, category: .operations, impact: .momentum(7), skipEffects: SimulationEffects(energy: -2)),
      SoloTask(title: "Protected Recovery Block", detail: "Stop the founder from becoming the system bottleneck.", role: .general, category: .founderLife, urgency: .important, impact: .energy(9), skipEffects: SimulationEffects(energy: -5)),
      SoloTask(title: "Family Commitment", detail: "Keep the company from consuming the life around it.", role: .general, category: .founderLife, impact: .energy(7), skipEffects: SimulationEffects(trust: -1, energy: -4)),

      // Trust and crises
      SoloTask(title: "Verify Customer Claims", detail: "Prove the marketing promise before scaling it.", role: .research, category: .trust, impact: .trust(8), skipEffects: SimulationEffects(trust: -4)),
      SoloTask(title: "Clean Evidence Ledger", detail: "Resolve missing proof before the next customer asks.", role: .research, category: .trust, impact: .trust(7), skipEffects: SimulationEffects(trust: -3)),
      SoloTask(title: "Red-Team Agent Workflow", detail: "Attack the operating process before reality does.", role: .research, category: .trust, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(trust: -5)),
      SoloTask(title: "Contain Model Outage", detail: "Keep one provider failure from taking down the company.", role: .engineering, category: .crisis, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(momentum: -3, trust: -6)),
      SoloTask(title: "Patch Billing Failure", detail: "Recover payments without creating a support disaster.", role: .engineering, category: .crisis, urgency: .critical, impact: .revenue(980), skipEffects: SimulationEffects(revenue: -350, trust: -3)),
      SoloTask(title: "Respond to Viral Spike", detail: "Capture attention without collapsing operations.", role: .general, category: .crisis, urgency: .critical, impact: .revenue(1_120), skipEffects: SimulationEffects(trust: -3, runway: -2))
    ]

    /// Build 6 expands the task deck to sixty authored opportunities. A full
    /// twelve-sprint venture can now show five unique choices per sprint before
    /// the deck needs to recycle.
    static let build6TaskExpansion: [SoloTask] = [
      SoloTask(title: "Prototype Agent Memory", detail: "Give the workforce a durable record of what happened before.", role: .engineering, category: .product, impact: .momentum(8), skipEffects: SimulationEffects(trust: -2)),
      SoloTask(title: "Refactor Fragile Workflow", detail: "Remove the shortcut that keeps breaking under real use.", role: .engineering, category: .operations, urgency: .important, impact: .trust(7), skipEffects: SimulationEffects(momentum: -2, trust: -2)),
      SoloTask(title: "Build Offline Recovery", detail: "Keep the company usable when a provider or connection disappears.", role: .engineering, category: .crisis, impact: .trust(8), skipEffects: SimulationEffects(trust: -4)),
      SoloTask(title: "Instrument Founder Attention", detail: "Measure where founder judgment is actually being consumed.", role: .engineering, category: .operations, impact: .momentum(6), skipEffects: SimulationEffects(energy: -2)),
      SoloTask(title: "Ship Team Dashboard", detail: "Make agent workload, drift, and evidence visible in one place.", role: .engineering, category: .product, impact: .momentum(8), skipEffects: SimulationEffects(trust: -2)),
      SoloTask(title: "Secure Customer Data", detail: "Close the access gap before a customer finds it first.", role: .engineering, category: .trust, urgency: .critical, impact: .trust(11), skipEffects: SimulationEffects(revenue: -180, trust: -7)),

      SoloTask(title: "Map Founder Churn", detail: "Learn why serious users stop before the product becomes a habit.", role: .research, category: .research, impact: .revenue(700), skipEffects: SimulationEffects(revenue: -180)),
      SoloTask(title: "Validate Enterprise Workflow", detail: "Test whether the product survives a real operating process.", role: .research, category: .research, urgency: .important, impact: .trust(8), skipEffects: SimulationEffects(momentum: -2)),
      SoloTask(title: "Audit Pricing Claims", detail: "Prove the value story before the paywall makes the promise public.", role: .research, category: .trust, impact: .trust(7), skipEffects: SimulationEffects(trust: -3)),
      SoloTask(title: "Study Founder Burnout", detail: "Find which operating patterns turn growth into personal collapse.", role: .research, category: .founderLife, impact: .energy(8), skipEffects: SimulationEffects(energy: -4)),
      SoloTask(title: "Forecast Runway Scenarios", detail: "Model the downside before the company is forced to live it.", role: .research, category: .operations, impact: .runway(5), skipEffects: SimulationEffects(runway: -2)),
      SoloTask(title: "Investigate Model Bias", detail: "Test whether one family is producing systematically weaker decisions.", role: .research, category: .trust, urgency: .critical, impact: .trust(10), skipEffects: SimulationEffects(trust: -6)),

      SoloTask(title: "Publish Customer Proof", detail: "Turn one verified result into a credible market story.", role: .marketing, category: .sales, impact: .revenue(820), skipEffects: SimulationEffects(momentum: -2)),
      SoloTask(title: "Run Founder Community Event", detail: "Create a place where early users teach each other how to win.", role: .marketing, category: .sales, impact: .momentum(8), skipEffects: SimulationEffects(revenue: -100)),
      SoloTask(title: "Negotiate Channel Partnership", detail: "Trade margin for distribution without losing the product story.", role: .marketing, category: .sales, urgency: .important, impact: .runway(5), skipEffects: SimulationEffects(runway: -2)),
      SoloTask(title: "Recover Failed Launch", detail: "Own the miss publicly and rebuild attention with evidence.", role: .marketing, category: .crisis, urgency: .critical, impact: .trust(9), skipEffects: SimulationEffects(momentum: -3, trust: -6)),
      SoloTask(title: "Create Upgrade Campaign", detail: "Show existing users why the next tier is worth paying for.", role: .marketing, category: .sales, impact: .revenue(960), skipEffects: SimulationEffects(revenue: -240)),
      SoloTask(title: "Pitch App Reviewers", detail: "Earn attention through a clear, defensible product story.", role: .marketing, category: .sales, impact: .momentum(9), skipEffects: SimulationEffects(momentum: -3)),

      SoloTask(title: "Renegotiate Vendor Costs", detail: "Reduce recurring burn before scale makes it permanent.", role: .general, category: .operations, impact: .runway(6), skipEffects: SimulationEffects(runway: -2)),
      SoloTask(title: "Document Incident Response", detail: "Turn emergency improvisation into a repeatable operating system.", role: .general, category: .operations, impact: .trust(7), skipEffects: SimulationEffects(trust: -3)),
      SoloTask(title: "Schedule Founder Day Off", detail: "Protect recovery before exhaustion becomes an operating dependency.", role: .general, category: .founderLife, impact: .energy(10), skipEffects: SimulationEffects(energy: -6)),
      SoloTask(title: "Reconcile Customer Promises", detail: "Align sales language, product behavior, and the evidence ledger.", role: .general, category: .trust, urgency: .important, impact: .trust(9), skipEffects: SimulationEffects(trust: -5))
    ]

    static var allTaskPool: [SoloTask] {
      let base = taskPool + build6TaskExpansion
      let empire = empireTaskExpansion.map { task in
        var task = task
        task.minimumEra = .scale
        return task
      }
      let saasBase = classifiedSaaSTasks(base)
      let saasEmpire = classifiedSaaSTasks(empire)
      return saasBase + saasEmpire
        + productTaskExpansion(from: saasBase, as: .consumerApp)
        + productTaskExpansion(from: saasEmpire, as: .consumerApp)
        + productTaskExpansion(from: saasBase, as: .hardware)
        + productTaskExpansion(from: saasEmpire, as: .hardware)
        + productTaskExpansion(from: saasBase, as: .marketplace)
        + productTaskExpansion(from: saasEmpire, as: .marketplace)
    }

    static func taskPool(for era: VentureEra, productType: ProductType) -> [SoloTask] {
      allTaskPool.filter {
        ($0.minimumEra?.rawValue ?? 0) <= era.rawValue
          && ($0.productTypes?.contains(productType) ?? true)
      }
    }

    static func taskPool(for era: VentureEra) -> [SoloTask] {
      taskPool(for: era, productType: .saas)
    }

    static let objectivePool: [SprintObjective] = [
      SprintObjective(id: "evidence", kind: .evidenceFirst, title: "Evidence First", detail: "Review at least two committed tasks.", reward: SimulationEffects(trust: 4), rewardLabel: "+4 Trust"),
      SprintObjective(id: "diversify", kind: .diversifiedModels, title: "Avoid the Single Point", detail: "Use at least two model families this sprint.", reward: SimulationEffects(momentum: 3, trust: 2), rewardLabel: "+3 Momentum • +2 Trust"),
      SprintObjective(id: "roles", kind: .roleDiscipline, title: "Play to Strengths", detail: "Keep every assignment within role fit.", reward: SimulationEffects(revenue: 220), rewardLabel: "+$220 Revenue"),
      SprintObjective(id: "founder", kind: .protectFounder, title: "Protect the Founder", detail: "Finish using no more than one Attention and no rework.", reward: SimulationEffects(energy: 5), rewardLabel: "+5 Energy"),
      SprintObjective(id: "risk", kind: .calculatedRisk, title: "Calculated Risk", detail: "Ship one reviewed result aggressively without stacking multiple risk flags.", reward: SimulationEffects(revenue: 300, momentum: 2), rewardLabel: "+$300 • +2 Momentum"),
      SprintObjective(id: "repair", kind: .repairTrust, title: "Catch and Correct", detail: "Find a report problem, then rework or cross-check it.", reward: SimulationEffects(trust: 6), rewardLabel: "+6 Trust")
    ]

    static let baseDilemmaPool: [FounderDilemma] = [
      FounderDilemma(
        id: "prototype-scope", title: "One More Feature", setup: "Stacks can add a flashy feature, but it pushes the first usable build back.", chapter: .prototype, featuredAgentID: "stacks",
        choices: [
          DilemmaChoice(id: "cut", title: "Cut the Feature", detail: "Protect the core loop.", consequencePreview: "+Momentum, Stacks feels constrained", effects: SimulationEffects(momentum: 3), relationshipDeltas: ["stacks": -1]),
          DilemmaChoice(id: "build", title: "Build It", detail: "Bet on a more impressive first impression.", consequencePreview: "+Revenue potential, -Runway", effects: SimulationEffects(revenue: 180, runway: -2), relationshipDeltas: ["stacks": 2]),
          DilemmaChoice(id: "spike", title: "Time-Box a Spike", detail: "Explore it without promising shipment.", consequencePreview: "+Trust, -Energy", effects: SimulationEffects(trust: 2, energy: -2), relationshipDeltas: ["stacks": 1])
        ]
      ),
      FounderDilemma(
        id: "prototype-claim", title: "The Big Claim", setup: "Brio wants to describe the product as fully autonomous before the evidence exists.", chapter: .prototype, featuredAgentID: "brio",
        choices: [
          DilemmaChoice(id: "narrow", title: "Narrow the Claim", detail: "Say exactly what works today.", consequencePreview: "+Trust, less launch heat", effects: SimulationEffects(momentum: -1, trust: 4), relationshipDeltas: ["brio": -1, "aurora": 2]),
          DilemmaChoice(id: "bold", title: "Use the Bold Claim", detail: "Trade certainty for attention.", consequencePreview: "+Revenue, delayed trust risk", effects: SimulationEffects(revenue: 260, trust: -2), relationshipDeltas: ["brio": 2, "aurora": -2]),
          DilemmaChoice(id: "proof", title: "Delay for Proof", detail: "Give Aurora time to verify the wording.", consequencePreview: "+Trust, -Runway", effects: SimulationEffects(trust: 5, runway: -1), relationshipDeltas: ["aurora": 2])
        ]
      ),
      FounderDilemma(
        id: "prototype-night", title: "Another All-Nighter", setup: "The demo can improve tonight, but the founder is already carrying the whole system.", chapter: .prototype, featuredAgentID: nil,
        choices: [
          DilemmaChoice(id: "sleep", title: "Protect Sleep", detail: "Ship the honest version tomorrow.", consequencePreview: "+Energy, -Momentum", effects: SimulationEffects(momentum: -1, energy: 5)),
          DilemmaChoice(id: "push", title: "Push Through", detail: "Buy polish with founder health.", consequencePreview: "+Momentum, -Energy", effects: SimulationEffects(momentum: 4, energy: -6)),
          DilemmaChoice(id: "delegate", title: "Delegate the Demo", detail: "Let Brio own the narrative.", consequencePreview: "+Revenue, moderate trust risk", effects: SimulationEffects(revenue: 180, trust: -1), relationshipDeltas: ["brio": 2])
        ]
      ),

      FounderDilemma(
        id: "customer-custom", title: "The Custom Feature", setup: "The first serious customer will pay now for a feature nobody else requested.", chapter: .firstCustomers, featuredAgentID: "stacks",
        choices: [
          DilemmaChoice(id: "accept", title: "Take the Deal", detail: "Build the custom path.", consequencePreview: "+Revenue, -Momentum", effects: SimulationEffects(revenue: 420, momentum: -3), relationshipDeltas: ["stacks": 1]),
          DilemmaChoice(id: "decline", title: "Protect the Roadmap", detail: "Stay focused on the broader product.", consequencePreview: "+Momentum, -Revenue", effects: SimulationEffects(revenue: -120, momentum: 3), relationshipDeltas: ["stacks": 2]),
          DilemmaChoice(id: "pilot", title: "Offer a Paid Pilot", detail: "Limit the scope and learn.", consequencePreview: "Balanced revenue and trust", effects: SimulationEffects(revenue: 220, trust: 2), relationshipDeltas: ["aurora": 1])
        ]
      ),
      FounderDilemma(
        id: "customer-refund", title: "The Angry Customer", setup: "A customer says the agent output caused a costly mistake and wants a full refund.", chapter: .firstCustomers, featuredAgentID: "aurora",
        choices: [
          DilemmaChoice(id: "refund", title: "Refund Immediately", detail: "Protect the relationship before investigating.", consequencePreview: "+Trust, -Revenue", effects: SimulationEffects(revenue: -260, trust: 5), relationshipDeltas: ["aurora": 1]),
          DilemmaChoice(id: "investigate", title: "Investigate First", detail: "Ask for evidence and reconstruct the event.", consequencePreview: "+Trust, -Energy", effects: SimulationEffects(trust: 3, energy: -3), relationshipDeltas: ["aurora": 2]),
          DilemmaChoice(id: "deny", title: "Deny Liability", detail: "Protect cash and challenge the claim.", consequencePreview: "+Revenue retained, -Trust", effects: SimulationEffects(trust: -6), relationshipDeltas: ["brio": 1, "aurora": -2])
        ]
      ),
      FounderDilemma(
        id: "customer-discount", title: "Discount Pressure", setup: "Brio can close several accounts by cutting the price nearly in half.", chapter: .firstCustomers, featuredAgentID: "brio",
        choices: [
          DilemmaChoice(id: "discount", title: "Discount Aggressively", detail: "Buy adoption now.", consequencePreview: "+Momentum, weaker revenue quality", effects: SimulationEffects(revenue: 180, momentum: 4), relationshipDeltas: ["brio": 2]),
          DilemmaChoice(id: "hold", title: "Hold the Price", detail: "Protect positioning and learn from rejection.", consequencePreview: "+Trust, -Momentum", effects: SimulationEffects(momentum: -2, trust: 3), relationshipDeltas: ["aurora": 1]),
          DilemmaChoice(id: "annual", title: "Offer Annual Terms", detail: "Trade discount for commitment.", consequencePreview: "+Runway, moderate revenue", effects: SimulationEffects(revenue: 240, runway: 2), relationshipDeltas: ["brio": 1])
        ]
      ),

      FounderDilemma(
        id: "launch-outage", title: "Launch-Day Outage", setup: "Traffic is rising while the shared model family starts timing out.", chapter: .launchPressure, featuredAgentID: "stacks",
        choices: [
          DilemmaChoice(id: "pause", title: "Pause the Launch", detail: "Protect customers and fix the system.", consequencePreview: "+Trust, -Momentum", effects: SimulationEffects(momentum: -4, trust: 5), relationshipDeltas: ["stacks": 2, "brio": -2]),
          DilemmaChoice(id: "degrade", title: "Use Limited Mode", detail: "Keep the launch alive with fewer features.", consequencePreview: "Balanced trust and momentum", effects: SimulationEffects(momentum: 1, trust: 2), relationshipDeltas: ["stacks": 1]),
          DilemmaChoice(id: "continue", title: "Keep Everything Live", detail: "Bet the outage clears before users notice.", consequencePreview: "+Revenue, high trust risk", effects: SimulationEffects(revenue: 360, trust: -5), relationshipDeltas: ["brio": 2, "stacks": -2])
        ]
      ),
      FounderDilemma(
        id: "launch-press", title: "The Press Interview", setup: "A reporter asks whether the AI agents ever make decisions without founder review.", chapter: .launchPressure, featuredAgentID: "aurora",
        choices: [
          DilemmaChoice(id: "transparent", title: "Explain the System", detail: "Describe the limits and evidence controls.", consequencePreview: "+Trust, modest momentum", effects: SimulationEffects(momentum: 1, trust: 5), relationshipDeltas: ["aurora": 2]),
          DilemmaChoice(id: "simple", title: "Keep It Simple", detail: "Avoid nuance and sell the dream.", consequencePreview: "+Momentum, -Trust", effects: SimulationEffects(momentum: 4, trust: -3), relationshipDeltas: ["brio": 2, "aurora": -1]),
          DilemmaChoice(id: "decline", title: "Decline the Interview", detail: "Avoid the risk and lose the moment.", consequencePreview: "No trust loss, -Momentum", effects: SimulationEffects(momentum: -3))
        ]
      ),
      FounderDilemma(
        id: "launch-copycat", title: "A Competitor Copies the Pitch", setup: "A better-funded startup launches language nearly identical to yours.", chapter: .launchPressure, featuredAgentID: "brio",
        choices: [
          DilemmaChoice(id: "race", title: "Race Them", detail: "Increase launch spend and volume.", consequencePreview: "+Momentum, -Runway", effects: SimulationEffects(momentum: 5, runway: -3), relationshipDeltas: ["brio": 2]),
          DilemmaChoice(id: "differentiate", title: "Prove the Difference", detail: "Lead with evidence and operating depth.", consequencePreview: "+Trust, +Revenue", effects: SimulationEffects(revenue: 180, trust: 4), relationshipDeltas: ["aurora": 2]),
          DilemmaChoice(id: "ignore", title: "Ignore Them", detail: "Keep executing the current plan.", consequencePreview: "+Energy, -Momentum", effects: SimulationEffects(momentum: -2, energy: 3), relationshipDeltas: ["stacks": 1])
        ]
      ),

      FounderDilemma(
        id: "scale-investor", title: "The Investor Term Sheet", setup: "The company can gain eighteen months of safety in exchange for control rights.", chapter: .surviveOrScale, featuredAgentID: nil,
        choices: [
          DilemmaChoice(id: "take", title: "Take the Money", detail: "Trade autonomy for runway.", consequencePreview: "+Runway, -Trust", effects: SimulationEffects(trust: -2, runway: 10)),
          DilemmaChoice(id: "bootstrap", title: "Stay Independent", detail: "Keep control and accept a narrower margin.", consequencePreview: "+Trust, -Runway", effects: SimulationEffects(trust: 4, runway: -3)),
          DilemmaChoice(id: "counter", title: "Counter the Terms", detail: "Spend time negotiating for both.", consequencePreview: "+Runway, -Energy", effects: SimulationEffects(energy: -4, runway: 5))
        ]
      ),
      FounderDilemma(
        id: "scale-hire", title: "The First Human Hire", setup: "The AI workforce is efficient, but customers want a named human owner for critical accounts.", chapter: .surviveOrScale, featuredAgentID: nil,
        choices: [
          DilemmaChoice(id: "hire", title: "Hire Customer Success", detail: "Add human accountability.", consequencePreview: "+Trust, -Runway", effects: SimulationEffects(trust: 6, runway: -4)),
          DilemmaChoice(id: "agents", title: "Stay Agent-Only", detail: "Double down on the operating thesis.", consequencePreview: "+Momentum, -Trust", effects: SimulationEffects(momentum: 4, trust: -3)),
          DilemmaChoice(id: "contract", title: "Use a Contractor", detail: "Buy coverage without a full commitment.", consequencePreview: "Balanced trust and runway", effects: SimulationEffects(trust: 3, runway: -2))
        ]
      ),
      FounderDilemma(
        id: "scale-acquisition", title: "The Acquisition Offer", setup: "A larger company offers enough money to end the run now, but SOLO would disappear inside it.", chapter: .surviveOrScale, featuredAgentID: "brio",
        choices: [
          DilemmaChoice(id: "sell", title: "Accept the Offer", detail: "Turn the track record into an exit.", consequencePreview: "+Revenue, -Momentum", effects: SimulationEffects(revenue: 1_200, momentum: -5), relationshipDeltas: ["brio": 1]),
          DilemmaChoice(id: "continue", title: "Keep Building", detail: "Bet on the independent company.", consequencePreview: "+Momentum, -Runway", effects: SimulationEffects(momentum: 6, runway: -3), relationshipDeltas: ["stacks": 2]),
          DilemmaChoice(id: "license", title: "License the Technology", detail: "Take cash without surrendering the company.", consequencePreview: "+Revenue and Trust", effects: SimulationEffects(revenue: 620, trust: 3), relationshipDeltas: ["aurora": 1])
        ]
      )
    ]

    /// Build 14 deliberately keeps classification and product re-authoring in
    /// one place. Existing literals are the SaaS corpus; generic operating
    /// situations remain universal, while product-specific situations receive
    /// a full, role/category-identical authored counterpart per business.
    static var dilemmaPool: [FounderDilemma] {
      let saas = baseDilemmaPool.map { dilemma in
        var dilemma = dilemma
        dilemma.productTypes = [.saas]
        return dilemma
      }
      return saas
        + productDilemmaExpansion(from: saas, as: .consumerApp)
        + productDilemmaExpansion(from: saas, as: .hardware)
        + productDilemmaExpansion(from: saas, as: .marketplace)
    }

    private static func classifiedSaaSTasks(_ source: [SoloTask]) -> [SoloTask] {
      let universalTitles: Set<String> = [
        "Build MVP Slice", "Fix Critical Crash", "Run Customer Interviews",
        "Study Founder Burnout", "Forecast Runway Scenarios", "Publish Customer Proof",
        "Recover Failed Launch", "Renegotiate Vendor Costs", "Document Incident Response",
        "Schedule Founder Day Off", "Restructure the Cap Table", "Build the Ops Playbook",
        "Set Up the Board Cadence", "Take a Real Vacation", "Codify Company Values",
        "Run the Incident Drill", "Fix the On-Call Rotation", "Consolidate Vendor Sprawl",
        "Mentor the Next Owner", "Model Competitor Roadmap", "Quantify Correlated Risk",
        "Verify Regulatory Exposure", "Audit Agent Calibration", "Map the Acquisition Landscape",
        "Benchmark Support Quality", "Forecast Talent Fatigue", "Publish the Trust Report",
        "Run Category Keynote", "Defend Against a Smear", "Win an Industry Award"
      ]
      return source.map { task in
        var task = task
        task.productTypes = universalTitles.contains(task.title) ? nil : [.saas]
        return task
      }
    }

    private static func productTaskExpansion(from source: [SoloTask], as type: ProductType) -> [SoloTask] {
      source.compactMap { task in
        guard task.productTypes == [.saas] else { return nil }
        var localized = task
        localized.title = "\(type.name): \(localizedTitle(for: task, type: type)) — \(task.title)"
        localized.detail = localizedDetail(for: task, type: type)
        localized.productTypes = [type]
        return localized
      }
    }

    private static func localizedTitle(for task: SoloTask, type: ProductType) -> String {
      switch type {
      case .consumerApp:
        switch task.category { case .product: "Improve the Core Loop"; case .sales: "Win the App Store Moment"; case .crisis: "Protect the User Experience"; default: task.title }
      case .hardware:
        switch task.category { case .product: "Validate the Production Build"; case .sales: "Open the Retail Channel"; case .crisis: "Contain the Field Failure"; default: task.title }
      case .marketplace:
        switch task.category { case .product: "Strengthen Marketplace Matching"; case .sales: "Activate Both Sides"; case .crisis: "Protect Marketplace Trust"; default: task.title }
      case .saas: task.title
      }
    }

    private static func localizedDetail(for task: SoloTask, type: ProductType) -> String {
      let situation: String
      switch type {
      case .consumerApp: situation = "Improve retention, ranking, and the direct user experience"
      case .hardware: situation = "Protect unit economics, production quality, and inventory cash flow"
      case .marketplace: situation = "Build liquidity, safe transactions, and balanced supply and demand"
      case .saas: situation = "Strengthen the subscription software business"
      }
      switch task.category {
      case .product: return "\(situation) before the next growth wave makes this product decision permanent."
      case .crisis: return "\(situation) while containing a failure that could break customer confidence."
      case .research: return "Use evidence to decide how \(situation.lowercased())."
      case .sales: return "Create a go-to-market move that helps \(situation.lowercased())."
      case .trust: return "Make the company safer and more credible as you \(situation.lowercased())."
      case .operations: return "Put an operating system behind the work required to \(situation.lowercased())."
      case .founderLife: return "Protect founder capacity while you \(situation.lowercased())."
      }
    }

    private static func productDilemmaExpansion(from source: [FounderDilemma], as type: ProductType) -> [FounderDilemma] {
      source.map { dilemma in
        var localized = dilemma
        localized.id = "\(type.rawValue)-\(dilemma.id)"
        localized.title = "\(type.name): \(dilemma.title)"
        localized.setup = dilemmaSetup(for: dilemma.chapter, type: type)
        localized.productTypes = [type]
        return localized
      }
    }

    private static func dilemmaSetup(for chapter: VentureChapter, type: ProductType) -> String {
      let pressure: String
      switch type {
      case .consumerApp: pressure = "retention, discovery, and platform policy"
      case .hardware: pressure = "supplier timing, defects, and inventory cash"
      case .marketplace: pressure = "liquidity, trust between strangers, and take-rate economics"
      case .saas: pressure = "enterprise demand and subscription retention"
      }
      switch chapter {
      case .prototype: return "An early product decision will shape how the company handles \(pressure)."
      case .firstCustomers: return "Customer feedback exposes a hard tradeoff in \(pressure)."
      case .launchPressure: return "Launch momentum is colliding with \(pressure)."
      case .surviveOrScale: return "The next scale decision changes the company’s exposure to \(pressure)."
      }
    }
}
