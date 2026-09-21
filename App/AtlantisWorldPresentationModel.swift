import Foundation
import simd

/// Session-only opt-in; never stored in settings, GameStore, or a career save.
enum AtlantisRendererConfiguration {
  static let launchArgument = "--atlantis-realitykit"
  static func resolve(arguments: [String], environment: [String: String], allowed: Bool) -> Bool {
    allowed && (arguments.contains(launchArgument) || environment["SOLO_ATLANTIS_RENDERER"]?.lowercased() == "realitykit")
  }
  static var active: Bool { resolve(arguments: ProcessInfo.processInfo.arguments, environment: ProcessInfo.processInfo.environment, allowed: true) }
}

enum AtlantisImportExperiment {
  static let batchedFounderArgument = "--atlantis-batched-founder"
  static let baselineAssetsArgument = "--atlantis-baseline-assets"
  static let batchedAssetsArgument = "--atlantis-batched-assets"

  enum AssetMode: String, Codable {
    case baseline
    case batched
  }

  static func assetMode(arguments: [String]) -> AssetMode {
    if arguments.contains(baselineAssetsArgument) { return .baseline }
    if arguments.contains(batchedAssetsArgument) || arguments.contains(batchedFounderArgument) { return .batched }
    return .baseline
  }

  static func useBatchedFounder(arguments: [String]) -> Bool {
    assetMode(arguments: arguments) == .batched
  }

  static func package(
    for district: AtlantisDistrict,
    manifest: AtlantisAssetManifest,
    arguments: [String]
  ) -> String {
    let baseline = manifest.districts[district.rawValue]?.package ?? "missing"
    guard assetMode(arguments: arguments) == .batched else { return baseline }
    return manifest.experiments?[district.rawValue + "Batched"]?.package ?? baseline
  }
}

enum AtlantisDistrict: String, CaseIterable, Codable, Identifiable, Sendable {
  case founderDistrict = "FounderDistrict", startupRow = "StartupRow", commerceDistrict = "CommerceDistrict"
  case ventureDistrict = "VentureDistrict", mediaDistrict = "MediaDistrict", techCore = "TechCore", unicornHeights = "UnicornHeights"
  var id: String { rawValue }
  var title: String {
    switch self {
    case .founderDistrict: "Founder"
    case .startupRow: "Startup"
    case .commerceDistrict: "Commerce"
    case .ventureDistrict: "Venture"
    case .mediaDistrict: "Media"
    case .techCore: "Tech Core"
    case .unicornHeights: "Unicorn Heights"
    }
  }
}

enum AtlantisDistrictLoadState: Equatable {
  case unloaded, loading, loaded, failed(String)
  var label: String { switch self { case .unloaded: "unloaded"; case .loading: "loading"; case .loaded: "loaded"; case .failed(let reason): "failed: \(reason)" } }
}

enum AtlantisLocomotionState: String, Codable { case standing, walking }

enum AtlantisInteractionIntent: Equatable, Sendable {
  case enterFounderGarage
  case openTechCom
  case openVenture
  case openSignalTV
  case inspectRival(rivalID: String)
  case inspectPlayerHQ
  case talkNamedNPC(npcID: String)
}

enum AtlantisInteractionAvailability: Equatable, Sendable {
  case available
  case unavailable(String)
}

struct AtlantisInteractionDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let district: AtlantisDistrict
  let anchorName: String
  let intent: AtlantisInteractionIntent
  let activationPosition: SIMD3<Float>
  let activationRadius: Float
  let minimumFacingDot: Float?
  let priority: Int
  let accessibilityLabel: String
  var availability: AtlantisInteractionAvailability = .available

  static let all: [Self] = [
    .init(id:"atlantis.interaction.founderGarage",district:.founderDistrict,anchorName:"FounderGarageSlot",intent:.enterFounderGarage,activationPosition:[-875,8,1030],activationRadius:12,minimumFacingDot:0.35,priority:300,accessibilityLabel:"Enter Founder Garage"),
    .init(id:"atlantis.interaction.techCom",district:.mediaDistrict,anchorName:"TechComTower",intent:.openTechCom,activationPosition:[835,14.7,-184],activationRadius:4,minimumFacingDot:nil,priority:200,accessibilityLabel:"Open Tech.com"),
    .init(id:"atlantis.interaction.ventureHall",district:.ventureDistrict,anchorName:"VentureHall",intent:.openVenture,activationPosition:[-520,14.7,-66],activationRadius:4,minimumFacingDot:nil,priority:250,accessibilityLabel:"Enter Venture Hall"),
    .init(id:"atlantis.interaction.signalTV",district:.mediaDistrict,anchorName:"SignalTV",intent:.openSignalTV,activationPosition:[860,14.7,-428],activationRadius:4,minimumFacingDot:nil,priority:200,accessibilityLabel:"Inspect Signal TV"),
    .init(id:"atlantis.interaction.pallasAI",district:.techCore,anchorName:"PallasAIHQ",intent:.inspectRival(rivalID:"pallas"),activationPosition:[220,15,-268],activationRadius:6,minimumFacingDot:nil,priority:100,accessibilityLabel:"Inspect Pallas AI"),
    .init(id:"atlantis.interaction.northwindLabs",district:.techCore,anchorName:"NorthwindLabsHQ",intent:.inspectRival(rivalID:"northwind"),activationPosition:[-100,15,-486],activationRadius:6,minimumFacingDot:nil,priority:100,accessibilityLabel:"Inspect Northwind Labs"),
    .init(id:"atlantis.interaction.flashpoint",district:.commerceDistrict,anchorName:"FlashpointHQ",intent:.inspectRival(rivalID:"flashpoint"),activationPosition:[476,14.7,252],activationRadius:5,minimumFacingDot:nil,priority:100,accessibilityLabel:"Inspect Flashpoint"),
    .init(id:"atlantis.interaction.playerHQ",district:.unicornHeights,anchorName:"PlayerUnicornHQSlot",intent:.inspectPlayerHQ,activationPosition:[970,85,-850],activationRadius:8,minimumFacingDot:nil,priority:100,accessibilityLabel:"Inspect Future Unicorn HQ")
  ]

  static func definitions(for district: AtlantisDistrict) -> [Self] { all.filter {$0.district == district} }
}

struct AtlantisInteractionCandidateScore: Equatable, Sendable {
  let id: String
  let priority: Int
  let distance: Float
}

enum AtlantisInteractionSelectionPolicy {
  static func select(_ candidates: [AtlantisInteractionCandidateScore]) -> String? {
    candidates.sorted {
      if $0.priority != $1.priority {return $0.priority > $1.priority}
      if $0.distance != $1.distance {return $0.distance < $1.distance}
      return $0.id < $1.id
    }.first?.id
  }
}

enum AtlantisCanonicalRoute: Identifiable, Equatable, Sendable {
  case founderGarage, techCom, venture, signalTV, rival(String), playerHQ
  var id: String {
    switch self {
    case .founderGarage: "founderGarage"
    case .techCom: "techCom"
    case .venture: "venture"
    case .signalTV: "signalTV"
    case .rival(let id): "rival.\(id)"
    case .playerHQ: "playerHQ"
    }
  }
  static func resolve(_ intent: AtlantisInteractionIntent, availableRivalIDs: Set<String>) -> Self? {
    switch intent {
    case .enterFounderGarage: .founderGarage
    case .openTechCom: .techCom
    case .openVenture: .venture
    case .openSignalTV: .signalTV
    case .inspectRival(let rivalID): availableRivalIDs.contains(rivalID) ? .rival(rivalID) : nil
    case .inspectPlayerHQ: .playerHQ
    case .talkNamedNPC: nil
    }
  }
}

struct AtlantisResidencyPlan: Equatable {
  let previous: AtlantisDistrict?
  let current: AtlantisDistrict
  let next: AtlantisDistrict?
  var residents: Set<AtlantisDistrict> { Set([previous, current, next].compactMap { $0 }) }
  func protects(_ district: AtlantisDistrict) -> Bool { residents.contains(district) }
}

struct AtlantisStreamingPolicy {
  let adjacency: [AtlantisDistrict: Set<AtlantisDistrict>]
  let safetyFactor: Double
  let walkingSpeed: Float

  func areAdjacent(_ lhs: AtlantisDistrict, _ rhs: AtlantisDistrict) -> Bool {
    adjacency[lhs]?.contains(rhs) == true && adjacency[rhs]?.contains(lhs) == true
  }

  func plan(previous: AtlantisDistrict?, current: AtlantisDistrict, next: AtlantisDistrict?) -> AtlantisResidencyPlan {
    AtlantisResidencyPlan(
      previous: previous.flatMap { areAdjacent($0, current) ? $0 : nil },
      current: current,
      next: next.flatMap { areAdjacent(current, $0) ? $0 : nil }
    )
  }

  func prefetchDistance(measuredLoadSeconds: Double) -> Float {
    walkingSpeed * Float(max(1, measuredLoadSeconds) * safetyFactor)
  }
}

struct AtlantisWorldPresentationModel: Equatable {
  var dayPhase: FounderEnvironmentTimeState = .day
}

enum AtlantisAmbientActorKind: String, Codable, Sendable { case pedestrian, vehicle }
enum AtlantisAmbientBehavior: String, CaseIterable, Codable, Sendable { case walk, idle, phoneIdle, talkGesture }
enum AtlantisActivityType: String, Codable, Sendable { case passThrough, smallGathering, standingPair, arrivalDeparture }

struct AtlantisLivingWorldProfile: Equatable, Sendable {
  let pedestrians: Int
  let vehicles: Int
  let language: String
}

struct AtlantisActivityAnchorDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let district: AtlantisDistrict
  let type: AtlantisActivityType
  let position: SIMD3<Float>
  let radius: Float
  let maximumActors: Int
  let priority: Int
}

struct AtlantisAmbientRoute: Identifiable, Equatable, Sendable {
  let id: String
  let district: AtlantisDistrict
  let kind: AtlantisAmbientActorKind
  let points: [SIMD3<Float>]
}

enum AtlantisLivingWorldPresentationAdapter {
  static let pedestrianBudget = 10
  static let vehicleBudget = 2

  static func profile(district: AtlantisDistrict, phase: FounderEnvironmentTimeState) -> AtlantisLivingWorldProfile {
    let counts: [FounderEnvironmentTimeState:(Int,Int)]
    let language: String
    switch district {
    case .founderDistrict: counts=[.morning:(3,0),.day:(4,0),.evening:(3,0),.night:(1,0)];language="low, neighborhood"
    case .startupRow: counts=[.morning:(6,0),.day:(10,0),.evening:(8,0),.night:(3,0)];language="high founder energy"
    case .commerceDistrict: counts=[.morning:(7,1),.day:(10,2),.evening:(8,2),.night:(4,1)];language="high commercial movement"
    case .ventureDistrict: counts=[.morning:(4,0),.day:(6,0),.evening:(5,0),.night:(2,0)];language="moderate, formal"
    case .mediaDistrict: counts=[.morning:(5,0),.day:(8,0),.evening:(6,0),.night:(2,0)];language="medium-high public frontage"
    case .techCore: counts=[.morning:(4,0),.day:(6,0),.evening:(5,0),.night:(2,0)];language="moderate technical"
    case .unicornHeights: counts=[.morning:(2,0),.day:(3,0),.evening:(2,0),.night:(1,0)];language="low, intentional"
    }
    let value=counts[phase] ?? (0,0)
    return .init(pedestrians:value.0,vehicles:value.1,language:language)
  }

  static let activityAnchors: [AtlantisActivityAnchorDefinition] = [
    .init(id:"atlantis.activity.founderPlaza",district:.founderDistrict,type:.passThrough,position:[-875,8.8,850],radius:70,maximumActors:4,priority:20),
    .init(id:"atlantis.activity.startupPlaza",district:.startupRow,type:.smallGathering,position:[-460,15,340],radius:115,maximumActors:20,priority:100),
    .init(id:"atlantis.activity.commerceCustomerPlaza",district:.commerceDistrict,type:.arrivalDeparture,position:[300,14.8,190],radius:110,maximumActors:12,priority:90),
    .init(id:"atlantis.activity.ventureForecourt",district:.ventureDistrict,type:.standingPair,position:[-490,14.8,-180],radius:80,maximumActors:6,priority:60),
    .init(id:"atlantis.activity.mediaFrontage",district:.mediaDistrict,type:.smallGathering,position:[800,14.8,-325],radius:90,maximumActors:8,priority:70),
    .init(id:"atlantis.activity.techPlaza",district:.techCore,type:.passThrough,position:[30,14.8,-330],radius:100,maximumActors:6,priority:50),
    .init(id:"atlantis.activity.unicornArrival",district:.unicornHeights,type:.arrivalDeparture,position:[710,86,-850],radius:100,maximumActors:3,priority:30)
  ]

  static let routes: [AtlantisAmbientRoute] = [
    .init(id:"PedestrianRoute_Founder_01",district:.founderDistrict,kind:.pedestrian,points:[[-940,8.45,850],[-810,8.45,850]]),
    .init(id:"PedestrianRoute_Startup_01",district:.startupRow,kind:.pedestrian,points:[[-478,14.45,340],[-460,14.45,340],[-442,14.45,340]]),
    .init(id:"PedestrianRoute_Startup_02",district:.startupRow,kind:.pedestrian,points:[[-478,14.45,336],[-460,14.45,336],[-442,14.45,336]]),
    .init(id:"PedestrianRoute_Commerce_01",district:.commerceDistrict,kind:.pedestrian,points:[[280,14.45,190],[300,14.45,190],[320,14.45,190]]),
    .init(id:"PedestrianRoute_Venture_01",district:.ventureDistrict,kind:.pedestrian,points:[[-650,14.45,-180],[-490,14.45,-180],[-325,14.45,-180]]),
    .init(id:"PedestrianRoute_Media_01",district:.mediaDistrict,kind:.pedestrian,points:[[645,14.45,-325],[800,14.45,-325],[950,14.45,-325]]),
    .init(id:"PedestrianRoute_Tech_01",district:.techCore,kind:.pedestrian,points:[[-250,14.45,-330],[30,14.45,-330],[310,14.45,-330]]),
    .init(id:"PedestrianRoute_Unicorn_01",district:.unicornHeights,kind:.pedestrian,points:[[680,85.6,-775],[710,85.6,-775],[740,85.6,-775]]),
    .init(id:"VehicleRoute_Commerce_01",district:.commerceDistrict,kind:.vehicle,points:[[270,14.45,184],[300,14.45,184],[330,14.45,184]]),
    .init(id:"VehicleRoute_Commerce_02",district:.commerceDistrict,kind:.vehicle,points:[[330,14.45,196],[300,14.45,196],[270,14.45,196]])
  ]

  static func routes(district: AtlantisDistrict,kind: AtlantisAmbientActorKind) -> [AtlantisAmbientRoute] {
    routes.filter{$0.district==district && $0.kind==kind}
  }
}

// Values admitted at the single canonical boundary. No agent or actual rival
// metrics, save payload, RNG, or mutable store reference crosses this boundary.
struct AtlantisPublicRivalSignal: Equatable {
  let id: String
  let name: String
  let claimedMomentum: Int
}

struct AtlantisWorldSignalSnapshot: Equatable {
  let trust: Int
  let momentum: Int
  let coverage: Int
  let venture: Int
  let rivals: [AtlantisPublicRivalSignal]
  let facilityTier: FacilityTier

  init(trust:Int,momentum:Int,coverage:Int,venture:Int,rivals:[AtlantisPublicRivalSignal],facilityTier:FacilityTier = .founderGarage) {
    self.trust=trust;self.momentum=momentum;self.coverage=coverage;self.venture=venture;self.rivals=rivals;self.facilityTier=facilityTier
  }

  @MainActor static func read(_ store: GameStore) -> Self {
    .init(trust:store.stats.trust,momentum:store.stats.momentum,coverage:store.stats.coverage,
          venture:store.venture,rivals:store.techComRivals.sorted{$0.id<$1.id}.map {
      .init(id:$0.id,name:$0.name,claimedMomentum:$0.claimedMomentum)
    },facilityTier:store.progressionStore?.currentFacility ?? .founderGarage)
  }
}

enum AtlantisLivingWorldFixture: String, CaseIterable, Identifiable {
  case baseline = "A · Baseline"
  case spotlight = "B · Momentum + Coverage"
  case rivalSurge = "C · Pallas public surge"
  case scrutiny = "D · Negative public state"
  var id: String {rawValue}
  var accessibilityID: String {
    switch self {
    case .baseline: "baseline"
    case .spotlight: "spotlight"
    case .rivalSurge: "rivalSurge"
    case .scrutiny: "scrutiny"
    }
  }
  var snapshot: AtlantisWorldSignalSnapshot {
    let rival=AtlantisPublicRivalSignal(id:"pallas",name:"Pallas AI",claimedMomentum:self == .rivalSurge ? 90:35)
    switch self {
    case .baseline,.rivalSurge: return .init(trust:60,momentum:45,coverage:0,venture:1,rivals:[rival])
    case .spotlight: return .init(trust:85,momentum:90,coverage:80,venture:4,rivals:[rival])
    case .scrutiny: return .init(trust:20,momentum:25,coverage:-80,venture:1,rivals:[rival])
    }
  }
}

enum AtlantisNamedNPCRole: String, CaseIterable, Sendable {
  case founder, investor, reporter, customer, rivalEmployee
  var title: String {
    switch self {
    case .founder: "Founder"
    case .investor: "Investor"
    case .reporter: "Reporter"
    case .customer: "Customer"
    case .rivalEmployee: "Rival employee"
    }
  }
}

enum AtlantisNamedNPCPresentationArchetype: String, Sendable {
  case peerFounder, capitalPartner, fieldReporter, customerOperator, rivalOperator
}

enum AtlantisNamedNPCLifecycle: String, Sendable {
  case eligible, spawned, available, engaged, coolingDown, despawned
}

enum AtlantisNamedEncounterArchetype: String, CaseIterable, Sendable {
  case founderRumor, founderAdvice, investorInterest, investorSkepticism
  case reporterQuestion, customerPraise, customerComplaint, rivalSignal
}

enum AtlantisEncounterConsequence: String, Sendable {
  case presentationOnly, existingCanonicalAction, deferredConsequence
  var label: String {
    switch self {
    case .presentationOnly: "Presentation only"
    case .existingCanonicalAction: "Existing canonical action"
    case .deferredConsequence: "Future consequence integration deferred"
    }
  }
}

struct AtlantisNamedEncounterResponse: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let acknowledgment: String
  let consequence: AtlantisEncounterConsequence
}

struct AtlantisNamedNPCDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let displayName: String
  let role: AtlantisNamedNPCRole
  let affiliation: String
  let homeDistrict: AtlantisDistrict
  let presentationArchetype: AtlantisNamedNPCPresentationArchetype
  let position: SIMD3<Float>
  let interactionRadius: Float
  let encounterCategories: Set<AtlantisNamedEncounterArchetype>
  let publicKnowledgeScope: String
  var interactionID: String { "atlantis.namedNPC.\(id)" }

  static let all: [Self] = [
    .init(id:"mara-chen",displayName:"Mara Chen",role:.founder,affiliation:"Quarry Labs",homeDistrict:.founderDistrict,presentationArchetype:.peerFounder,position:[-840,8.03,940],interactionRadius:7,encounterCategories:[.founderAdvice],publicKnowledgeScope:"Public company progress and founder ecosystem context"),
    .init(id:"eli-navarro",displayName:"Eli Navarro",role:.founder,affiliation:"Relay Foundry",homeDistrict:.startupRow,presentationArchetype:.peerFounder,position:[-460,14.45,340],interactionRadius:7,encounterCategories:[.founderRumor,.founderAdvice],publicKnowledgeScope:"Public rival claims and public Momentum"),
    .init(id:"nia-okafor",displayName:"Nia Okafor",role:.investor,affiliation:"Tideglass Ventures",homeDistrict:.ventureDistrict,presentationArchetype:.capitalPartner,position:[-490,14.45,-180],interactionRadius:7,encounterCategories:[.investorInterest,.investorSkepticism],publicKnowledgeScope:"Public Momentum, Coverage, Trust consequences, and Venture progression"),
    .init(id:"sloane-park",displayName:"Sloane Park",role:.reporter,affiliation:"Signal TV",homeDistrict:.mediaDistrict,presentationArchetype:.fieldReporter,position:[800,14.45,-325],interactionRadius:7,encounterCategories:[.reporterQuestion],publicKnowledgeScope:"Public Coverage and Trust consequences"),
    .init(id:"devon-reyes",displayName:"Devon Reyes",role:.customer,affiliation:"Harborline Systems",homeDistrict:.commerceDistrict,presentationArchetype:.customerOperator,position:[300,14.45,190],interactionRadius:7,encounterCategories:[.customerPraise,.customerComplaint],publicKnowledgeScope:"Public Trust and Momentum consequences"),
    .init(id:"iris-vale",displayName:"Iris Vale",role:.rivalEmployee,affiliation:"Pallas AI",homeDistrict:.techCore,presentationArchetype:.rivalOperator,position:[30,14.45,-330],interactionRadius:7,encounterCategories:[.rivalSignal],publicKnowledgeScope:"Tech.com-visible Pallas AI claims only")
  ]
}

struct AtlantisNamedEncounterDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let npcID: String
  let archetype: AtlantisNamedEncounterArchetype
  let priority: Int
  let allowedPhases: Set<FounderEnvironmentTimeState>
  let prompt: String
  let responses: [AtlantisNamedEncounterResponse]

  static let all: [Self] = [
    .init(id:"mara.peer-advice",npcID:"mara-chen",archetype:.founderAdvice,priority:40,allowedPhases:[.morning,.day,.evening],prompt:"Atlantis rewards focus. What are you protecting this sprint?",responses:[
      .init(id:"focus",title:"Protect the core",acknowledgment:"Mara nods. “Clear constraints travel fast.”",consequence:.presentationOnly),
      .init(id:"listen",title:"Ask what she sees",acknowledgment:"“Founders here notice steady delivery before bold claims.”",consequence:.presentationOnly)]),
    .init(id:"eli.ecosystem-rumor",npcID:"eli-navarro",archetype:.founderRumor,priority:90,allowedPhases:[.day,.evening,.night],prompt:"Pallas is recruiting again. Their public Momentum claim is getting attention.",responses:[
      .init(id:"source",title:"Ask what is public",acknowledgment:"“Only the Tech.com claim. I have no private read on it.”",consequence:.presentationOnly),
      .init(id:"move-on",title:"Move on",acknowledgment:"Eli lets the rumor pass.",consequence:.presentationOnly)]),
    .init(id:"eli.peer-reaction",npcID:"eli-navarro",archetype:.founderAdvice,priority:55,allowedPhases:[.morning,.day,.evening],prompt:"People on Startup Row are noticing your company’s public momentum.",responses:[
      .init(id:"credit",title:"Credit the team",acknowledgment:"“That answer will play well with other founders.”",consequence:.presentationOnly),
      .init(id:"work",title:"Get back to work",acknowledgment:"Eli smiles. “Consistent.”",consequence:.presentationOnly)]),
    .init(id:"nia.interest",npcID:"nia-okafor",archetype:.investorInterest,priority:80,allowedPhases:[.morning,.day,.evening],prompt:"Your public progress is creating a credible Venture conversation.",responses:[
      .init(id:"thesis",title:"Share the thesis",acknowledgment:"Nia listens, then asks you to keep the signal disciplined.",consequence:.presentationOnly),
      .init(id:"later",title:"Revisit later",acknowledgment:"“Good. Raise when the company is ready.”",consequence:.deferredConsequence)]),
    .init(id:"nia.skepticism",npcID:"nia-okafor",archetype:.investorSkepticism,priority:95,allowedPhases:[.morning,.day],prompt:"Coverage is outpacing confidence. How are you closing that gap?",responses:[
      .init(id:"evidence",title:"Point to public evidence",acknowledgment:"“Bring that discipline into the next update.”",consequence:.presentationOnly),
      .init(id:"defer",title:"Decline to speculate",acknowledgment:"Nia accepts the boundary.",consequence:.presentationOnly)]),
    .init(id:"sloane.spotlight",npcID:"sloane-park",archetype:.reporterQuestion,priority:90,allowedPhases:[.day,.evening],prompt:"Signal TV is covering your momentum. What should founders understand?",responses:[
      .init(id:"answer",title:"Answer directly",acknowledgment:"Sloane records the public statement and closes the interview.",consequence:.presentationOnly),
      .init(id:"brio",title:"Refer Sloane to Brio",acknowledgment:"“I’ll request a formal comment.”",consequence:.deferredConsequence),
      .init(id:"decline",title:"No comment",acknowledgment:"Sloane lowers the microphone.",consequence:.presentationOnly)]),
    .init(id:"sloane.scrutiny",npcID:"sloane-park",archetype:.reporterQuestion,priority:100,allowedPhases:[.morning,.day,.evening,.night],prompt:"Public confidence is under pressure. Can you address the concern?",responses:[
      .init(id:"facts",title:"Stay with public facts",acknowledgment:"“Understood. We’ll report the facts available.”",consequence:.presentationOnly),
      .init(id:"brio",title:"Refer Sloane to Brio",acknowledgment:"“We’ll seek the company’s formal response.”",consequence:.deferredConsequence),
      .init(id:"decline",title:"Decline",acknowledgment:"Sloane ends the question without speculation.",consequence:.presentationOnly)]),
    .init(id:"devon.praise",npcID:"devon-reyes",archetype:.customerPraise,priority:65,allowedPhases:[.morning,.day,.evening],prompt:"Your public progress has made our team more confident in the product.",responses:[
      .init(id:"learn",title:"Ask what helped",acknowledgment:"“Clear delivery and visible follow-through.”",consequence:.presentationOnly),
      .init(id:"thanks",title:"Thank Devon",acknowledgment:"Devon returns to the Commerce crowd.",consequence:.presentationOnly)]),
    .init(id:"devon.complaint",npcID:"devon-reyes",archetype:.customerComplaint,priority:110,allowedPhases:[.day,.evening],prompt:"The last update disrupted our workflow. I need the team to understand what happened.",responses:[
      .init(id:"details",title:"Ask what happened",acknowledgment:"Devon shares the visible symptoms. Investigation is deferred to a canonical Evidence flow.",consequence:.deferredConsequence),
      .init(id:"acknowledge",title:"Acknowledge the issue",acknowledgment:"“Thank you. I needed to know you heard it.”",consequence:.presentationOnly)]),
    .init(id:"iris.hiring",npcID:"iris-vale",archetype:.rivalSignal,priority:85,allowedPhases:[.day,.evening,.night],prompt:"Pallas is hiring around the momentum it reports publicly.",responses:[
      .init(id:"claim",title:"Ask about the claim",acknowledgment:"“The Tech.com number is the only figure I can discuss.”",consequence:.presentationOnly),
      .init(id:"leave",title:"End the conversation",acknowledgment:"Iris returns to Tech Core.",consequence:.presentationOnly)]),
    .init(id:"iris.positioning",npcID:"iris-vale",archetype:.rivalSignal,priority:80,allowedPhases:[.morning,.day,.evening],prompt:"Pallas is positioning its public Momentum as a market signal.",responses:[
      .init(id:"public",title:"Keep it to public facts",acknowledgment:"Iris repeats only the published claim.",consequence:.presentationOnly),
      .init(id:"pass",title:"Walk away",acknowledgment:"The competitor signal remains public context.",consequence:.presentationOnly)])
  ]
}

enum AtlantisNamedEncounterFixture: String, CaseIterable, Identifiable {
  case founderPeer = "A · Founder peer"
  case reporterSpotlight = "B · Reporter spotlight"
  case reporterScrutiny = "C · Reporter scrutiny"
  case investorInterest = "D · Investor interest"
  case pallasSurge = "E · Pallas public surge"
  case customerComplaint = "F · Customer complaint · presentation fixture"
  var id: String {rawValue}
  var accessibilityID: String {
    switch self {
    case .founderPeer: "founderPeer"
    case .reporterSpotlight: "reporterSpotlight"
    case .reporterScrutiny: "reporterScrutiny"
    case .investorInterest: "investorInterest"
    case .pallasSurge: "pallasSurge"
    case .customerComplaint: "customerComplaint"
    }
  }
  var targetNPCID: String {
    switch self {
    case .founderPeer: "mara-chen"
    case .reporterSpotlight,.reporterScrutiny: "sloane-park"
    case .investorInterest: "nia-okafor"
    case .pallasSurge: "iris-vale"
    case .customerComplaint: "devon-reyes"
    }
  }
  var forcedEncounterID: String? {self == .customerComplaint ? "devon.complaint":nil}
  var snapshot: AtlantisWorldSignalSnapshot {
    let pallas=AtlantisPublicRivalSignal(id:"pallas",name:"Pallas AI",claimedMomentum:self == .pallasSurge ? 92:35)
    switch self {
    case .founderPeer: return .init(trust:60,momentum:45,coverage:0,venture:1,rivals:[pallas])
    case .reporterSpotlight: return .init(trust:85,momentum:90,coverage:80,venture:4,rivals:[pallas])
    case .reporterScrutiny: return .init(trust:20,momentum:25,coverage:-80,venture:1,rivals:[pallas])
    case .investorInterest: return .init(trust:75,momentum:85,coverage:20,venture:4,rivals:[pallas])
    case .pallasSurge: return .init(trust:60,momentum:45,coverage:0,venture:1,rivals:[pallas])
    case .customerComplaint: return .init(trust:60,momentum:45,coverage:0,venture:1,rivals:[pallas])
    }
  }
}

enum AtlantisNamedEncounterPolicy {
  static func eligible(_ encounter: AtlantisNamedEncounterDefinition,signals: AtlantisWorldSignalSnapshot,
                       phase: FounderEnvironmentTimeState,fixture: AtlantisNamedEncounterFixture?=nil) -> Bool {
    guard encounter.allowedPhases.contains(phase) else{return false}
    if let forced=fixture?.forcedEncounterID {return encounter.id == forced}
    switch encounter.id {
    case "mara.peer-advice": return signals.momentum < 70
    case "eli.ecosystem-rumor": return signals.rivals.contains{$0.claimedMomentum>=70}
    case "eli.peer-reaction": return signals.momentum>=70
    case "nia.interest": return signals.momentum>=70 || signals.venture>=4
    case "nia.skepticism": return abs(signals.coverage)>=40 && signals.trust<50
    case "sloane.spotlight": return signals.coverage>=40 && signals.trust>=50
    case "sloane.scrutiny": return signals.coverage <= -40 || signals.trust<35
    case "devon.praise": return signals.trust>=75
    case "devon.complaint": return false
    case "iris.hiring","iris.positioning": return signals.rivals.contains{$0.id=="pallas" && $0.claimedMomentum>=70}
    default: return false
    }
  }

  static func select(_ encounters:[AtlantisNamedEncounterDefinition],signals:AtlantisWorldSignalSnapshot,
                     phase:FounderEnvironmentTimeState,fixture:AtlantisNamedEncounterFixture?=nil,
                     cooling:Set<String>=[],seed:UInt64=0x534F4C4F)->AtlantisNamedEncounterDefinition? {
    encounters.filter{!cooling.contains($0.id) && eligible($0,signals:signals,phase:phase,fixture:fixture)}.sorted {
      if $0.priority != $1.priority{return $0.priority>$1.priority}
      let lhs=AtlantisPresentationSeed.value($0.id,index:0,seed:seed),rhs=AtlantisPresentationSeed.value($1.id,index:0,seed:seed)
      return lhs == rhs ? $0.id<$1.id:lhs<rhs
    }.first
  }
}

enum AtlantisWorldConsequenceSite: String, CaseIterable, Sendable {
  case founderHQ, pallasCampus, northwindCampus, flashpointCampus
}

enum AtlantisWorldConsequenceCategory: String, Sendable {
  case companyPresence, rivalCampus, publicEvent
}

enum AtlantisWorldConsequencePresentationState: String, Sendable {
  case baseline, growth, spotlight, scrutiny, surge, event
}

enum AtlantisWorldConsequenceEligibility: Equatable, Sendable {
  case always
  case founderGrowth
  case founderSpotlight
  case founderScrutiny
  case rivalClaim(rivalID:String,minimum:Int)
  case rivalEvent(rivalID:String,minimum:Int)
}

struct AtlantisWorldConsequenceDefinition: Identifiable, Equatable, Sendable {
  let id:String
  let site:AtlantisWorldConsequenceSite
  let district:AtlantisDistrict
  let targetAnchor:String
  let category:AtlantisWorldConsequenceCategory
  let state:AtlantisWorldConsequencePresentationState
  let priority:Int
  let exclusiveGroups:Set<String>
  let eligibility:AtlantisWorldConsequenceEligibility
  let signage:String
  let accessibilitySummary:String
  let constructionProps:Int
  let eventProps:Int
  let activityModifier:Int
  let publicKnowledgeScope:String

  static let all:[Self] = [
    .init(id:"founder.baseline",site:.founderHQ,district:.founderDistrict,targetAnchor:"FounderGarageSlot",category:.companyPresence,state:.baseline,priority:10,exclusiveGroups:["founderHQ.signage","founderHQ.eventZone"],eligibility:.always,signage:"SOLO · FOUNDER GARAGE",accessibilitySummary:"Founder company presence is quiet and early stage.",constructionProps:0,eventProps:0,activityModifier:0,publicKnowledgeScope:"Current public facility progression"),
    .init(id:"founder.growth",site:.founderHQ,district:.founderDistrict,targetAnchor:"FounderGarageSlot",category:.companyPresence,state:.growth,priority:40,exclusiveGroups:["founderHQ.signage","founderHQ.eventZone"],eligibility:.founderGrowth,signage:"SOLO · GROWING",accessibilitySummary:"Founder company frontage shows growth, deliveries, and expansion staging.",constructionProps:3,eventProps:1,activityModifier:2,publicKnowledgeScope:"Current facility tier or public Momentum"),
    .init(id:"founder.spotlight",site:.founderHQ,district:.founderDistrict,targetAnchor:"FounderGarageSlot",category:.publicEvent,state:.spotlight,priority:80,exclusiveGroups:["founderHQ.signage","founderHQ.eventZone"],eligibility:.founderSpotlight,signage:"SOLO · PUBLIC SPOTLIGHT",accessibilitySummary:"Founder company frontage has a public spotlight and media staging.",constructionProps:0,eventProps:4,activityModifier:2,publicKnowledgeScope:"Positive public Coverage"),
    .init(id:"founder.scrutiny",site:.founderHQ,district:.founderDistrict,targetAnchor:"FounderGarageSlot",category:.publicEvent,state:.scrutiny,priority:100,exclusiveGroups:["founderHQ.signage","founderHQ.eventZone"],eligibility:.founderScrutiny,signage:"SOLO · PUBLIC UPDATE",accessibilitySummary:"Founder company frontage is restrained under public scrutiny.",constructionProps:1,eventProps:3,activityModifier:-2,publicKnowledgeScope:"Negative public Coverage or low public Trust"),
    .init(id:"pallas.baseline",site:.pallasCampus,district:.techCore,targetAnchor:"PallasAIHQ",category:.rivalCampus,state:.baseline,priority:10,exclusiveGroups:["pallasHQ.signage","pallasHQ.eventZone"],eligibility:.always,signage:"PALLAS AI",accessibilitySummary:"Pallas AI campus presentation is at baseline.",constructionProps:0,eventProps:0,activityModifier:0,publicKnowledgeScope:"Public rival identity"),
    .init(id:"pallas.surge",site:.pallasCampus,district:.techCore,targetAnchor:"PallasAIHQ",category:.rivalCampus,state:.surge,priority:60,exclusiveGroups:["pallasHQ.signage","pallasHQ.eventZone"],eligibility:.rivalClaim(rivalID:"pallas",minimum:70),signage:"PALLAS AI · NOW HIRING",accessibilitySummary:"Pallas AI campus shows recruiting and activity around its public Momentum claim.",constructionProps:2,eventProps:2,activityModifier:2,publicKnowledgeScope:"Tech.com-visible claimed Momentum only"),
    .init(id:"pallas.event",site:.pallasCampus,district:.techCore,targetAnchor:"PallasAIHQ",category:.publicEvent,state:.event,priority:90,exclusiveGroups:["pallasHQ.signage","pallasHQ.eventZone"],eligibility:.rivalEvent(rivalID:"pallas",minimum:70),signage:"PALLAS AI · PUBLIC LAUNCH",accessibilitySummary:"Pallas AI campus has public launch and media staging.",constructionProps:0,eventProps:5,activityModifier:2,publicKnowledgeScope:"Public Coverage plus Tech.com-visible claimed Momentum"),
    .init(id:"northwind.baseline",site:.northwindCampus,district:.techCore,targetAnchor:"NorthwindLabsHQ",category:.rivalCampus,state:.baseline,priority:10,exclusiveGroups:["northwindHQ.signage","northwindHQ.eventZone"],eligibility:.always,signage:"NORTHWIND LABS",accessibilitySummary:"Northwind Labs campus is at baseline.",constructionProps:0,eventProps:0,activityModifier:0,publicKnowledgeScope:"Public rival identity"),
    .init(id:"flashpoint.baseline",site:.flashpointCampus,district:.commerceDistrict,targetAnchor:"FlashpointHQ",category:.rivalCampus,state:.baseline,priority:10,exclusiveGroups:["flashpointHQ.signage","flashpointHQ.eventZone"],eligibility:.always,signage:"FLASHPOINT",accessibilitySummary:"Flashpoint campus is at baseline.",constructionProps:0,eventProps:0,activityModifier:0,publicKnowledgeScope:"Public rival identity")
  ]
}

enum AtlantisWorldConsequenceFixture:String,CaseIterable,Identifiable {
  case founderBaseline="Founder A · Baseline · presentation fixture"
  case founderGrowth="Founder B · Growth · presentation fixture"
  case founderSpotlight="Founder C · Spotlight · presentation fixture"
  case founderScrutiny="Founder D · Scrutiny · presentation fixture"
  case pallasBaseline="Pallas A · Baseline · presentation fixture"
  case pallasSurge="Pallas B · Surge · presentation fixture"
  case pallasEvent="Pallas C · Event · presentation fixture"
  var id:String{rawValue}
  var accessibilityID:String {
    switch self {
    case .founderBaseline:"founderBaseline"
    case .founderGrowth:"founderGrowth"
    case .founderSpotlight:"founderSpotlight"
    case .founderScrutiny:"founderScrutiny"
    case .pallasBaseline:"pallasBaseline"
    case .pallasSurge:"pallasSurge"
    case .pallasEvent:"pallasEvent"
    }
  }
  var site:AtlantisWorldConsequenceSite {
    switch self {case .founderBaseline,.founderGrowth,.founderSpotlight,.founderScrutiny:.founderHQ;default:.pallasCampus}
  }
  var forcedDefinitionID:String {
    switch self {
    case .founderBaseline:"founder.baseline"
    case .founderGrowth:"founder.growth"
    case .founderSpotlight:"founder.spotlight"
    case .founderScrutiny:"founder.scrutiny"
    case .pallasBaseline:"pallas.baseline"
    case .pallasSurge:"pallas.surge"
    case .pallasEvent:"pallas.event"
    }
  }
  var snapshot:AtlantisWorldSignalSnapshot {
    let claimed=self == .pallasSurge || self == .pallasEvent ? 90:35
    let rival=AtlantisPublicRivalSignal(id:"pallas",name:"Pallas AI",claimedMomentum:claimed)
    switch self {
    case .founderBaseline,.pallasBaseline:return .init(trust:60,momentum:45,coverage:0,venture:1,rivals:[rival])
    case .founderGrowth:return .init(trust:75,momentum:85,coverage:10,venture:3,rivals:[rival],facilityTier:.founderLoft)
    case .founderSpotlight:return .init(trust:85,momentum:90,coverage:80,venture:4,rivals:[rival],facilityTier:.founderLoft)
    case .founderScrutiny:return .init(trust:20,momentum:25,coverage:-80,venture:1,rivals:[rival])
    case .pallasSurge:return .init(trust:60,momentum:45,coverage:0,venture:1,rivals:[rival])
    case .pallasEvent:return .init(trust:60,momentum:45,coverage:80,venture:1,rivals:[rival])
    }
  }
}

struct AtlantisWorldConsequenceState:Equatable,Sendable {
  let active:[AtlantisWorldConsequenceDefinition]
  var activeIDs:[String]{active.map(\.id).sorted()}
  func definition(site:AtlantisWorldConsequenceSite)->AtlantisWorldConsequenceDefinition?{active.first{$0.site==site}}
}

enum AtlantisWorldConsequencePolicy {
  static func eligible(_ definition:AtlantisWorldConsequenceDefinition,signals:AtlantisWorldSignalSnapshot)->Bool {
    switch definition.eligibility {
    case .always:return true
    case .founderGrowth:return signals.facilityTier.rawValue >= FacilityTier.founderLoft.rawValue || signals.momentum>=70
    case .founderSpotlight:return signals.coverage>=40 && signals.trust>=35
    case .founderScrutiny:return signals.coverage <= -40 || signals.trust<35
    case .rivalClaim(let rivalID,let minimum):return signals.rivals.contains{$0.id==rivalID && $0.claimedMomentum>=minimum}
    case .rivalEvent(let rivalID,let minimum):return signals.coverage>=40 && signals.rivals.contains{$0.id==rivalID && $0.claimedMomentum>=minimum}
    }
  }
  static func derive(signals:AtlantisWorldSignalSnapshot,fixture:AtlantisWorldConsequenceFixture?=nil)->AtlantisWorldConsequenceState {
    let selected=AtlantisWorldConsequenceSite.allCases.compactMap {site -> AtlantisWorldConsequenceDefinition? in
      let definitions=AtlantisWorldConsequenceDefinition.all.filter{$0.site==site}
      if let fixture,fixture.site==site {return definitions.first{$0.id==fixture.forcedDefinitionID}}
      return definitions.filter{eligible($0,signals:signals)}.sorted{if $0.priority != $1.priority{return $0.priority>$1.priority};return $0.id<$1.id}.first
    }
    return .init(active:selected)
  }
}

enum AtlantisLivingWorldLOD: String {case near, mid, far}
enum AtlantisLivingWorldTuning {
  static let nearRadius: Float = 220
  static let midRadius: Float = 450
  static let decisionInterval = 0.5
  static let midMotionInterval = 0.2
  static let encounterRadius: Float = 22
  static let encounterDuration = 6.0
  static let encounterCooldown = 30.0
  static func lod(distance: Float) -> AtlantisLivingWorldLOD {
    distance <= nearRadius ? .near:distance <= midRadius ? .mid:.far
  }
}

enum AtlantisPublicReaction: String {case ordinary, interest, scrutiny, rival}
enum AtlantisAmbientEncounter: String, CaseIterable {case founderRumor, reporter, customer}
struct AtlantisDistrictReaction: Equatable {
  let district: AtlantisDistrict
  let pedestrians: Int
  let vehicles: Int
  let reaction: AtlantisPublicReaction
  let headline: String
  let detail: String
  let encounter: AtlantisAmbientEncounter?
  let encounterLine: String
}

enum AtlantisWorldReactionAdapter {
  // Each district has its own signal emphasis; the city is not multiplied globally.
  static func derive(_ signal: AtlantisWorldSignalSnapshot,district: AtlantisDistrict,
                     phase: FounderEnvironmentTimeState) -> AtlantisDistrictReaction {
    let base=AtlantisLivingWorldPresentationAdapter.profile(district:district,phase:phase)
    let press=abs(signal.coverage)>=40,negative=signal.trust<35 || signal.coverage <= -40
    let momentum=signal.momentum>=70
    let rival=signal.rivals.filter{$0.claimedMomentum>=70}.sorted{$0.id<$1.id}.first
    let reaction:AtlantisPublicReaction
    if negative {reaction = .scrutiny}
    else if rival != nil && [.startupRow,.techCore].contains(district) {reaction = .rival}
    else if (press && [.founderDistrict,.startupRow,.mediaDistrict].contains(district)) ||
      (momentum && [.founderDistrict,.startupRow,.ventureDistrict].contains(district)) ||
      (signal.trust>=75 && district == .commerceDistrict) || (signal.venture>=4 && district == .unicornHeights) {reaction = .interest}
    else {reaction = .ordinary}
    let baseline=max(1,base.pedestrians/2)
    let count:Int
    switch reaction {
    case .ordinary: count=baseline
    case .interest: count=base.pedestrians
    case .rival: count=min(10,baseline+3)
    case .scrutiny: count=press && district == .mediaDistrict ? base.pedestrians:max(2,baseline-1)
    }
    let headline:String,detail:String,encounter:AtlantisAmbientEncounter?,line:String
    switch reaction {
    case .rival:
      headline="RIVAL WATCH";detail="\(rival!.name) · public Momentum \(rival!.claimedMomentum)"
      encounter = .founderRumor;line="Founder: \(rival!.name) is reporting stronger Momentum on Tech.com."
    case .scrutiny:
      headline=press ? "SIGNAL TV · SCRUTINY":"CUSTOMER VOICES"
      detail="Public confidence needs rebuilding"
      encounter = district == .mediaDistrict && press ? .reporter:.customer
      line=encounter == .reporter ? "Reporter: Public attention is critical. We are following the company.":"Customer: I need more confidence before recommending this company."
    case .interest:
      headline=district == .ventureDistrict ? "VENTURE · ARRIVALS":press ? "SIGNAL TV · SPOTLIGHT":"COMPANY · VISITORS"
      detail=district == .commerceDistrict ? "Customer confidence is strong":"Company activity is drawing attention"
      encounter=press && [.founderDistrict,.startupRow,.mediaDistrict].contains(district) ? .reporter:.customer
      line=encounter == .reporter ? "Reporter: The company is attracting public attention.":"Customer: The company's public progress looks encouraging."
    case .ordinary:
      headline="\(district.title.uppercased()) · DAILY WIRE";detail="Public activity · Venture \(signal.venture)"
      encounter=nil;line=""
    }
    return .init(district:district,pedestrians:count,vehicles:district == .commerceDistrict ? (reaction == .interest ? base.vehicles:min(1,base.vehicles)):0,
                 reaction:reaction,headline:headline,detail:detail,encounter:encounter,encounterLine:line)
  }
}

enum AtlantisPresentationSeed {
  static func value(_ id: String,index: Int,seed: UInt64=0x534F4C4F) -> UInt64 {
    var value=seed ^ UInt64(index &* 0x9E37)
    for byte in id.utf8 {value ^= UInt64(byte);value &*= 1_099_511_628_211}
    value ^= value >> 30;value &*= 0xBF58476D1CE4E5B9;value ^= value >> 27;value &*= 0x94D049BB133111EB;return value ^ (value >> 31)
  }
  static func unit(_ id: String,index: Int,seed: UInt64=0x534F4C4F) -> Float {
    Float(value(id,index:index,seed:seed)%10_000)/10_000
  }
}

/// Future GameStore adapter accepts only visible projections. The spike has no
/// store reference, mutator, timer-driven day advancement, or progression copy.
enum AtlantisPresentationAdapter {
  static func environment(_ phase: FounderEnvironmentTimeState) -> AtlantisWorldPresentationModel { .init(dayPhase: phase) }
}

enum AtlantisSpatialContract {
  static let metersPerUnit: Float = 1
  static let eyeHeight: Float = 1.7
  static let walkingSpeed: Float = 1.4
  static let founderGarage: SIMD3<Float> = [-875, 8, 1030]
  static let founderGarageFloorY: Float = 8.03
  static let spire: SIMD3<Float> = [50, 14, -420]
  static let playerHQ: SIMD3<Float> = [970, 85, -850]
  static func fromBlender(_ p: SIMD3<Float>) -> SIMD3<Float> { [p.x, p.z, -p.y] }

  /// Facility Tier 0 shares metre units and its +Z doorway axis with the
  /// Founder District Garage parcel. This keeps the driveway crossing spatially
  /// continuous while the existing district runtime assumes rendering authority.
  static func fromFounderGarage(_ local: SIMD3<Float>) -> SIMD3<Float> {
    [founderGarage.x + local.x, founderGarageFloorY, founderGarage.z + local.z]
  }
}

enum AtlantisBenchmarkCamera: String, CaseIterable, Identifiable, Codable {
  case founderStreet, startupBoulevard, commerceFlashpoint, techCoreSkyline, unicornOverlook, atlantisAerial
  var id: String { rawValue }
  var recipe: (position: SIMD3<Float>, target: SIMD3<Float>, fov: Float) {
    let b: (SIMD3<Float>, SIMD3<Float>, Float)
    switch self {
    case .founderStreet: b = ([-875,-1040.1,9.73],[-825,-970,11],65)
    case .startupBoulevard: b = ([-500,-340,17.7],[-300,-270,30],65)
    case .commerceFlashpoint: b = ([388,-303,17.1],[435,-235,44],65)
    case .techCoreSkyline: b = ([0,190,35],[50,420,150],65)
    case .unicornOverlook: b = ([548,832,87.3],[40,350,140],65)
    case .atlantisAerial: b = ([2700,-3600,2900],[0,100,0],55)
    }
    return (AtlantisSpatialContract.fromBlender(b.0), AtlantisSpatialContract.fromBlender(b.1), b.2)
  }
}

struct AtlantisAssetManifest: Decodable {
  struct Package: Decodable {
    let package: String; let bytes: Int; let meshes: Int; let triangles: Int; let materials: Int; let textures: Int
    let bounds: [[Float]]; let landmarks: [String: [Float]]; let sha256: String
  }
  struct Landmark: Decodable { let district: String; let position: [Float] }
  enum SurfaceClass: String, Decodable { case walkable, nonwalkable, collisionOnly, visualOnly }
  struct Triangle: Decodable { let district: String; let source: String; let surfaceClass: SurfaceClass?; let points: [[Float]] }
  struct Barrier: Decodable { let district: String; let name: String; let min: [Float]; let max: [Float] }
  struct Route: Decodable { let name: String; let points: [[Float]] }
  struct Surface: Decodable { let district: String; let source: String; let classification: SurfaceClass }
  struct Traversal: Decodable { let triangles: [Triangle]; let barriers: [Barrier]; let routes: [Route]; let surfaces: [Surface]? }
  struct SupportPackage: Decodable { let package: String; let bytes: Int; let sha256: String; let kind: String }
  struct TransitionRoute: Decodable { let from: String; let to: String; let boundary: [Float] }
  struct Streaming: Decodable {
    let policy: String; let adjacency: [String: [String]]; let prefetchSafetyFactor: Double
    let walkingSpeedMetersPerSecond: Float; let transitionRoutes: [TransitionRoute]
    let semanticAnchors: [String: [String]]; let hardwareLoadSeconds: [String: Double]?
  }
  let axis: String; let metersPerUnit: Float; let districts: [String: Package]; let experiments: [String: Package]?
  let landmarks: [String: Landmark]; let traversal: Traversal
  let supportPackages: [String: SupportPackage]?
  let streaming: Streaming?
  static func load(bundle: Bundle = .main) throws -> Self {
    guard let url = bundle.url(forResource: "atlantis_manifest", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }

  var streamingPolicy: AtlantisStreamingPolicy {
    let pairs: [(AtlantisDistrict, Set<AtlantisDistrict>)] = (streaming?.adjacency ?? [:]).compactMap { key, values in
      guard let district = AtlantisDistrict(rawValue: key) else { return nil }
      return (district, Set(values.compactMap(AtlantisDistrict.init(rawValue:))))
    }
    let graph = Dictionary(uniqueKeysWithValues: pairs)
    return AtlantisStreamingPolicy(
      adjacency: graph,
      safetyFactor: streaming?.prefetchSafetyFactor ?? 1.5,
      walkingSpeed: streaming?.walkingSpeedMetersPerSecond ?? AtlantisSpatialContract.walkingSpeed
    )
  }
}

extension Array where Element == Float {
  var vector3: SIMD3<Float> { precondition(count == 3); return [self[0],self[1],self[2]] }
}
