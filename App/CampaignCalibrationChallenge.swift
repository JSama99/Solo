import Foundation

enum CampaignCategory: String, Codable, CaseIterable, Hashable {
  case acquisition
  case retention
  case launch
  case conversion
  case community
  case partnership
  case awareness
  case general
}

enum CampaignSlot: String, Codable, CaseIterable, Identifiable, Hashable {
  case audience
  case message
  case channel

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

struct CampaignSelection: Codable, Equatable, Hashable {
  var audienceID: String?
  var messageID: String?
  var channelID: String?

  var isComplete: Bool { audienceID != nil && messageID != nil && channelID != nil }

  subscript(slot: CampaignSlot) -> String? {
    get {
      switch slot {
      case .audience: audienceID
      case .message: messageID
      case .channel: channelID
      }
    }
    set {
      switch slot {
      case .audience: audienceID = newValue
      case .message: messageID = newValue
      case .channel: channelID = newValue
      }
    }
  }
}

/// UI-safe campaign option. Compatibility tags, objective weights, and claim
/// support deliberately remain outside this presentation boundary.
struct CampaignOptionPresentation: Identifiable, Equatable, Hashable {
  var id: String
  var slot: CampaignSlot
  var title: String
  var detail: String

  var accessibilityLabel: String { "\(slot.title) option: \(title). \(detail)" }
}

struct CampaignPreviewPresentation: Equatable, Hashable {
  var objective: String
  var audience: CampaignOptionPresentation
  var message: CampaignOptionPresentation
  var channel: CampaignOptionPresentation
}

private enum CampaignFitTag: String, Codable, Hashable {
  case education
  case proof
  case directResponse
  case customerSuccess
  case belonging
  case launchStory
  case credibility
  case reengagement
  case partnership
}

private enum CampaignClaimRisk: String, Codable, Hashable {
  case supported
  case aspirational
  case unsupported
}

struct CampaignOption: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var detail: String
  private var fitTags: Set<CampaignFitTag>
  private var categories: Set<CampaignCategory>
  private var claimRisk: CampaignClaimRisk?

  fileprivate init(
    id: String,
    title: String,
    detail: String,
    fitTags: Set<CampaignFitTag>,
    categories: Set<CampaignCategory>,
    claimRisk: CampaignClaimRisk? = nil
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.fitTags = fitTags
    self.categories = categories
    self.claimRisk = claimRisk
  }

  func presentation(slot: CampaignSlot) -> CampaignOptionPresentation {
    .init(id: id, slot: slot, title: title, detail: detail)
  }

  fileprivate func supports(_ category: CampaignCategory) -> Bool {
    categories.contains(category) || categories.contains(.general)
  }

  fileprivate func compatibility(with other: CampaignOption) -> Double {
    switch fitTags.intersection(other.fitTags).count {
    case 2...: 1
    case 1: 0.75
    default: 0.2
    }
  }

  fileprivate var risk: CampaignClaimRisk { claimRisk ?? .supported }
}

struct CampaignCalibrationChallenge: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var objective: String
  var context: String
  var category: CampaignCategory
  var audiences: [CampaignOption]
  var messages: [CampaignOption]
  var channels: [CampaignOption]

  func presentations(for slot: CampaignSlot) -> [CampaignOptionPresentation] {
    options(for: slot).map { $0.presentation(slot: slot) }
  }

  func contains(optionID: String, for slot: CampaignSlot) -> Bool {
    options(for: slot).contains(where: { $0.id == optionID })
  }

  func preview(for selection: CampaignSelection) -> CampaignPreviewPresentation? {
    guard
      let audience = option(id: selection.audienceID, in: audiences),
      let message = option(id: selection.messageID, in: messages),
      let channel = option(id: selection.channelID, in: channels)
    else { return nil }
    return .init(
      objective: objective,
      audience: audience.presentation(slot: .audience),
      message: message.presentation(slot: .message),
      channel: channel.presentation(slot: .channel)
    )
  }

  fileprivate func resolvedOptions(for selection: CampaignSelection) -> (CampaignOption, CampaignOption, CampaignOption)? {
    guard
      let audience = option(id: selection.audienceID, in: audiences),
      let message = option(id: selection.messageID, in: messages),
      let channel = option(id: selection.channelID, in: channels)
    else { return nil }
    return (audience, message, channel)
  }

  private func options(for slot: CampaignSlot) -> [CampaignOption] {
    switch slot {
    case .audience: audiences
    case .message: messages
    case .channel: channels
    }
  }

  private func option(id: String?, in options: [CampaignOption]) -> CampaignOption? {
    guard let id else { return nil }
    return options.first(where: { $0.id == id })
  }
}

struct CampaignCalibrationAssessment: Equatable, Hashable {
  var reviewQuality: Int
  var audienceMessageFit: Int
  var audienceChannelFit: Int
  var messageChannelFit: Int
  var objectiveFit: Int
  var claimDiscipline: Int
  var findings: [WorkSessionFinding]
}

enum CampaignCalibrationEvaluator {
  static func evaluate(
    challenge: CampaignCalibrationChallenge,
    selection: CampaignSelection
  ) -> CampaignCalibrationAssessment? {
    guard let (audience, message, channel) = challenge.resolvedOptions(for: selection) else { return nil }

    let audienceMessage = audience.compatibility(with: message)
    let audienceChannel = audience.compatibility(with: channel)
    let messageChannel = message.compatibility(with: channel)
    let supportedCount = [audience, message, channel].filter { $0.supports(challenge.category) }.count
    let objective = Double(supportedCount) / 3
    let claim: Double = switch message.risk {
    case .supported: 1
    case .aspirational: 0.6
    case .unsupported: 0
    }
    let strongRelations = [audienceMessage, audienceChannel, messageChannel].filter { $0 >= 0.75 }.count
    let coherenceBonus: Double = switch strongRelations {
    case 3: 10
    case 2: 5
    default: 0
    }
    let raw = audienceMessage * 25
      + audienceChannel * 20
      + messageChannel * 15
      + objective * 20
      + claim * 10
      + coherenceBonus

    var findings: [WorkSessionFinding] = []
    if audience.supports(challenge.category) { findings.append(.strongAudienceMatch) }
    else { findings.append(.audienceMismatch) }
    if audienceMessage >= 0.75 && message.supports(challenge.category) { findings.append(.strongMessageFit) }
    if audienceChannel >= 0.75 && channel.supports(challenge.category) { findings.append(.strongChannelFit) }
    if strongRelations == 3 { findings.append(.coherentCampaign) }
    else if strongRelations <= 1 { findings.append(.weakCampaignCoherence) }
    if audienceChannel < 0.5 { findings.append(.channelMismatch) }
    switch message.risk {
    case .supported: findings.append(.disciplinedClaim)
    case .aspirational: findings.append(.aspirationalPositioning)
    case .unsupported: findings.append(.overclaimedMessage)
    }

    return .init(
      reviewQuality: min(100, max(0, Int(raw.rounded()))),
      audienceMessageFit: Int((audienceMessage * 100).rounded()),
      audienceChannelFit: Int((audienceChannel * 100).rounded()),
      messageChannelFit: Int((messageChannel * 100).rounded()),
      objectiveFit: Int((objective * 100).rounded()),
      claimDiscipline: Int((claim * 100).rounded()),
      findings: findings
    )
  }
}

extension SoloTask {
  var resolvedCampaignCategory: CampaignCategory? {
    let copy = "\(title) \(detail)".lowercased()
    let mappings: [(CampaignCategory, [String])] = [
      (.retention, ["retention", "at-risk", "churn", "renewal"]),
      (.launch, ["launch", "landing page", "app store feature", "keynote"]),
      (.conversion, ["conversion", "upgrade", "pricing", "free cohort"]),
      (.community, ["community", "referral", "ambassador"]),
      (.partnership, ["partner", "channel", "alliance"]),
      (.awareness, ["reviewer", "award", "report", "story", "rebrand", "category"]),
      (.acquisition, ["acquisition", "trial", "early customer", "prospect", "new region"])
    ]
    return mappings.first(where: { _, words in words.contains(where: copy.contains) })?.0
  }
}

enum CampaignCalibrationChallengeFactory {
  static func make(seed: UInt64, category: CampaignCategory?, stakes: WorkSessionStakes) -> CampaignCalibrationChallenge {
    let resolved = category ?? .general
    let matching = templates.filter { $0.category == resolved }
    let pool = matching.isEmpty ? templates.filter { $0.category == .general } : matching
    let index = Int(SeededRandomNumberGenerator.mixed(seed ^ 0xB410_CAFE) % UInt64(pool.count))
    var challenge = pool[index]
    challenge.audiences = ranked(challenge.audiences, seed: seed ^ 0xA11D)
    challenge.messages = ranked(challenge.messages, seed: seed ^ 0xBEEF)
    challenge.channels = ranked(challenge.channels, seed: seed ^ 0xC4A7)
    return challenge
  }

  private static func ranked(_ options: [CampaignOption], seed: UInt64) -> [CampaignOption] {
    options.enumerated().sorted { left, right in
      let l = SeededRandomNumberGenerator.mixed(seed ^ UInt64(left.offset + 1) &* 0x9E3779B97F4A7C15)
      let r = SeededRandomNumberGenerator.mixed(seed ^ UInt64(right.offset + 1) &* 0x9E3779B97F4A7C15)
      return l == r ? left.element.id < right.element.id : l < r
    }.map(\.element)
  }

  private static func option(
    _ id: String,
    _ title: String,
    _ detail: String,
    _ tags: Set<CampaignFitTag>,
    _ categories: Set<CampaignCategory>,
    risk: CampaignClaimRisk? = nil
  ) -> CampaignOption {
    .init(id: id, title: title, detail: detail, fitTags: tags, categories: categories, claimRisk: risk)
  }

  private static func challenge(
    id: String,
    title: String,
    objective: String,
    context: String,
    category: CampaignCategory,
    coreAudience: (String, String),
    alternateAudience: (String, String),
    coreMessage: (String, String),
    alternateMessage: (String, String),
    coreChannel: (String, String),
    alternateChannel: (String, String)
  ) -> CampaignCalibrationChallenge {
    .init(
      id: id,
      title: title,
      objective: objective,
      context: context,
      category: category,
      audiences: [
        option("core-audience", coreAudience.0, coreAudience.1, [.education, .belonging, .proof], [category]),
        option("alternate-audience", alternateAudience.0, alternateAudience.1, [.directResponse, .proof, .customerSuccess], [category]),
        option("adjacent-audience", "Startup operators", "Operators comparing practical tools for a growing team.", [.credibility, .customerSuccess], [.general, .awareness]),
        option("observer-audience", "Industry observers", "People following the category without an immediate buying need.", [.launchStory, .credibility], [.awareness])
      ],
      messages: [
        option("core-message", coreMessage.0, coreMessage.1, [.education, .belonging], [category]),
        option("alternate-message", alternateMessage.0, alternateMessage.1, [.directResponse, .proof, .customerSuccess], [category]),
        option("story-message", "Why we built it", "A founder story about the problem and the operating lesson behind the product.", [.education, .launchStory], [.awareness, .launch], risk: .aspirational),
        option("overclaim-message", "Guaranteed category leadership", "Promise that every team will outperform alternatives immediately.", [.directResponse, .launchStory], [category], risk: .unsupported)
      ],
      channels: [
        option("core-channel", coreChannel.0, coreChannel.1, [.education, .belonging], [category]),
        option("alternate-channel", alternateChannel.0, alternateChannel.1, [.directResponse, .proof, .customerSuccess], [category]),
        option("publication-channel", "Industry publication", "Reach broad category followers through an editorial placement.", [.credibility, .launchStory], [.awareness, .launch]),
        option("partner-channel", "Partner channel", "Reach an adjacent audience through a trusted operating partner.", [.partnership, .credibility], [.partnership, .general])
      ]
    )
  }

  private static let templates: [CampaignCalibrationChallenge] = [
    challenge(id: "qualified-trials", title: "Qualified Trial Campaign", objective: "Increase qualified trial starts", context: "Brio has prepared a focused adoption campaign for the next sprint.", category: .acquisition, coreAudience: ("AI-native solo founders", "Founders already assembling work with AI tools."), alternateAudience: ("High-intent prospects", "Prospects who explored the product but have not started a trial."), coreMessage: ("Find the work your AI team is losing", "An educational view of coordination gaps and how to spot them."), alternateMessage: ("See the operating proof", "Show measured workflow gains from teams with similar needs."), coreChannel: ("Founder community", "Reach practitioners where they exchange operating lessons."), alternateChannel: ("Targeted outbound", "Reach prospects who already demonstrated category intent.")),
    challenge(id: "retention-engagement", title: "Retention Engagement", objective: "Improve engagement among customers showing churn risk", context: "Brio has prepared a customer campaign before the next renewal window.", category: .retention, coreAudience: ("Churn-risk users", "Customers whose recent usage has fallen."), alternateAudience: ("Existing active users", "Customers using the core workflow but missing newer value."), coreMessage: ("Get value from the workflow you already have", "Teach one practical habit that restores recurring value."), alternateMessage: ("Your unused wins are ready", "Use account evidence to show relevant features they have not adopted."), coreChannel: ("Customer community", "Reach customers through peer examples and guided discussion."), alternateChannel: ("Product email", "Use account-aware communication tied to actual usage.")),
    challenge(id: "launch-awareness", title: "Feature Launch", objective: "Build credible launch awareness", context: "Brio has assembled a launch campaign for a meaningful product capability.", category: .launch, coreAudience: ("AI-native solo founders", "Early adopters who follow new operating approaches."), alternateAudience: ("Technical buyers", "Evaluators looking for evidence before adoption."), coreMessage: ("A clearer way to run AI work", "Explain the new capability through the problem it resolves."), alternateMessage: ("Launch proof, not promises", "Demonstrate the capability with a measured customer workflow."), coreChannel: ("Founder newsletter", "Reach an audience already learning new operating practices."), alternateChannel: ("Launch page", "Give evaluators a durable demonstration and evidence trail.")),
    challenge(id: "upgrade-conversion", title: "Upgrade Campaign", objective: "Improve conversion from active use to paid adoption", context: "Brio has prepared a conversion campaign around demonstrated product value.", category: .conversion, coreAudience: ("Active free users", "People repeatedly reaching the limits of the free workflow."), alternateAudience: ("High-intent prospects", "Evaluators returning to pricing and proof materials."), coreMessage: ("Turn repeated work into a reliable system", "Explain the paid workflow through a familiar operating problem."), alternateMessage: ("The value is already visible", "Connect measured product usage to a specific paid outcome."), coreChannel: ("In-product education", "Reach users at the moment the workflow limit becomes relevant."), alternateChannel: ("Product email", "Follow up with evidence tied to recent intent.")),
    challenge(id: "community-loop", title: "Community Growth Loop", objective: "Grow qualified referrals through customer advocacy", context: "Brio has designed a community-led campaign grounded in existing customer value.", category: .community, coreAudience: ("Existing advocates", "Customers already sharing useful operating practices."), alternateAudience: ("AI-native solo founders", "Peers likely to learn through trusted founder examples."), coreMessage: ("Share the operating lesson", "Invite advocates to teach a useful workflow to peers."), alternateMessage: ("Proof from founders like you", "Show practical customer outcomes without promising identical results."), coreChannel: ("Founder community", "Create a peer-to-peer setting for practical examples."), alternateChannel: ("Referral program", "Give advocates a direct path to invite qualified peers.")),
    challenge(id: "partner-campaign", title: "Partner Campaign", objective: "Reach qualified operators through a credible partner", context: "Brio has prepared a shared campaign with an adjacent operating platform.", category: .partnership, coreAudience: ("Partner customers", "Operators already trusting an adjacent workflow provider."), alternateAudience: ("Small business operators", "Teams looking to connect fragmented operating tools."), coreMessage: ("One connected operating workflow", "Educate customers on the shared problem both products solve."), alternateMessage: ("Evidence across the handoff", "Show how the integration reduces a measured coordination gap."), coreChannel: ("Partner webinar", "Teach the joint workflow through both teams' expertise."), alternateChannel: ("Partner email", "Reach opted-in customers through the established relationship.")),
    challenge(id: "category-credibility", title: "Category Credibility", objective: "Establish credible market awareness", context: "Brio has prepared a broad campaign to explain the company's point of view.", category: .awareness, coreAudience: ("Startup operators", "Operators exploring how AI changes team management."), alternateAudience: ("Industry observers", "Writers and analysts following the category."), coreMessage: ("A practical guide to AI operations", "Teach the category through specific operating patterns."), alternateMessage: ("What the evidence says", "Lead with measured signals and careful category claims."), coreChannel: ("Founder newsletter", "Reach practitioners through an educational editorial format."), alternateChannel: ("Industry publication", "Reach category observers with evidence and context.")),
    challenge(id: "campaign-review", title: "Market Campaign", objective: "Generate qualified interest without weakening trust", context: "Brio has prepared a campaign brief for an unclassified growth assignment.", category: .general, coreAudience: ("AI-native solo founders", "Founders actively exploring AI operating systems."), alternateAudience: ("High-intent prospects", "Prospects already comparing solutions in the category."), coreMessage: ("A practical operating guide", "Teach the audience how to identify a recurring coordination problem."), alternateMessage: ("Measured product proof", "Connect a verified workflow result to the audience's need."), coreChannel: ("Founder community", "Reach practitioners in a learning-oriented environment."), alternateChannel: ("Targeted outbound", "Reach prospects with demonstrated category intent."))
  ]
}
