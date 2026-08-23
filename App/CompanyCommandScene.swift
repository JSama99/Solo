import SwiftUI

// MARK: - Responsive header composition

/// Build 32.4 header layout. Four independent regions stop the connection
/// indicator, the title, the facility subtitle, and the phase/action from
/// competing for the same horizontal space at any Dynamic Type size.
struct ViewportHeaderComposition: Equatable, Sendable {
  enum Layout: String, Equatable, Sendable {
    /// Status, title, and phase share one row.
    case inline
    /// Phase and secondary instruction move to their own line.
    case stacked
  }

  var layout: Layout
  var showsStatusText: Bool
  var showsPriorityLine: Bool
  var collapsesPhaseToIcon: Bool

  /// The top-leading corner is reserved for the connection indicator so no
  /// title glyph can ever be overdrawn there.
  static let statusRegionWidth: CGFloat = 22

  static func derive(
    width: CGFloat,
    dynamicTypeSize: DynamicTypeSize,
    hasFocusAction: Bool
  ) -> Self {
    let reserved = statusRegionWidth + (hasFocusAction ? 48 : 6)
    let available = width - reserved
    if dynamicTypeSize.isAccessibilitySize {
      return Self(layout: .stacked, showsStatusText: false, showsPriorityLine: false, collapsesPhaseToIcon: false)
    }
    if available < 252 {
      return Self(layout: .stacked, showsStatusText: false, showsPriorityLine: false, collapsesPhaseToIcon: false)
    }
    if dynamicTypeSize >= .xxLarge || available < 300 {
      return Self(layout: .inline, showsStatusText: false, showsPriorityLine: false, collapsesPhaseToIcon: available < 272)
    }
    return Self(layout: .inline, showsStatusText: true, showsPriorityLine: true, collapsesPhaseToIcon: false)
  }
}

// MARK: - Stable scene anchors

/// Every causal path resolves from one of these stable anchors. They are keyed
/// by canonical agent and upgrade identity, never by a transient global screen
/// coordinate, so a path stays correct across layout, focus, and Dynamic Type.
enum CompanySceneAnchor: Hashable, Sendable {
  case founderCommand
  case founderTray
  case station(String)
  case roleMonitor(String)
  case companySystem(InfrastructurePhysicalLocation)

  var accessibilityName: String {
    switch self {
    case .founderCommand: "Founder Command"
    case .founderTray: "Founder review tray"
    case .station(let id): "\(id.capitalized) workstation"
    case .roleMonitor(let id): "\(id.capitalized) role monitor"
    case .companySystem(let location): location.accessibilityName
    }
  }
}

/// The dedicated viewport coordinate space. Rendering and choreography read the
/// same anchors, so a travelling object always lands on the object it targets.
struct CompanySceneLayout: Equatable, Sendable {
  var size: CGSize
  var agentOrder: [String]
  var structure: FacilityStructureProjection

  init(size: CGSize, agentOrder: [String], structure: FacilityStructureProjection) {
    self.size = size
    self.agentOrder = agentOrder.isEmpty ? ["aurora", "stacks", "brio"] : agentOrder
    self.structure = structure
  }

  /// The band above the workstations where facility structure reads: garage
  /// rails, conduit, and practical lights, or loft window bays and skyline.
  var structureBandHeight: CGFloat { size.height * 0.155 }
  var bayTopY: CGFloat { structureBandHeight }
  var bayHeight: CGFloat { size.height * 0.505 }
  var bayCenterY: CGFloat { bayTopY + bayHeight / 2 }

  /// The vertical gaps between workstation bays, where structural rails and
  /// mullions stay visible instead of being hidden behind a bay.
  func gapX(_ index: Int) -> CGFloat {
    CGFloat(index + 1) * size.width / CGFloat(max(1, agentOrder.count))
  }

  var gapCount: Int { max(0, agentOrder.count - 1) }
  var floorY: CGFloat { size.height * 0.70 }
  /// Role equipment stands on the floor at the foot of its own bay, clear of
  /// the Founder foreground panel.
  var equipmentRowY: CGFloat { size.height * 0.715 }
  var founderDeskY: CGFloat { size.height * 0.895 }
  var founderPanelWidth: CGFloat { min(size.width * 0.68, 244) }

  func stationWidth(dominant: Bool) -> CGFloat {
    let share = size.width / CGFloat(max(1, agentOrder.count))
    let base = share * (dominant ? 0.98 : 0.90) * structure.stationSpacingRatio
    return min(dominant ? 138 : 120, max(84, base))
  }

  func stationX(_ agentID: String) -> CGFloat {
    let index = agentOrder.firstIndex(of: agentID) ?? 0
    return (CGFloat(index) + 0.5) * size.width / CGFloat(max(1, agentOrder.count))
  }

  /// Garage bays are mounted unevenly. The offset lives in the layout so the
  /// rendered bay and its anchors can never drift apart.
  func bayOffset(_ agentID: String) -> CGFloat {
    guard structure.railSymmetry == .asymmetric else { return 0 }
    let index = agentOrder.firstIndex(of: agentID) ?? 0
    return [7, -6, 10][index % 3]
  }

  func stationCenter(_ agentID: String) -> CGPoint {
    CGPoint(x: stationX(agentID), y: bayCenterY + bayOffset(agentID))
  }

  func point(_ anchor: CompanySceneAnchor) -> CGPoint {
    switch anchor {
    case .founderCommand:
      CGPoint(x: size.width / 2 - founderPanelWidth * 0.30, y: founderDeskY)
    case .founderTray:
      CGPoint(x: size.width / 2 + founderPanelWidth * 0.34, y: founderDeskY - 3)
    case .station(let id):
      stationCenter(id)
    case .roleMonitor(let id):
      // Tucked into the lower edge of the role-specific work surface, clear of
      // the task title line and the surface's own progress pips.
      CGPoint(x: stationX(id) + stationWidth(dominant: false) * 0.30, y: bayTopY + bayHeight * 0.965 + bayOffset(id))
    case .companySystem(let location):
      systemPoint(location)
    }
  }

  private func systemPoint(_ location: InfrastructurePhysicalLocation) -> CGPoint {
    switch location {
    case .auroraFounderVerificationBridge:
      CGPoint(x: stationX("aurora"), y: equipmentRowY)
    case .stacksBuildRail:
      CGPoint(x: stationX("stacks"), y: equipmentRowY)
    case .brioBroadcastRail:
      CGPoint(x: stationX("brio"), y: equipmentRowY)
    case .recoverySideBay:
      // A quiet corner bay in the foreground, clear of the role equipment row
      // and of the Founder Command panel.
      CGPoint(x: max(26, size.width * 0.07), y: size.height * 0.845)
    case .founderForegroundDesk:
      // The desk sits behind and beneath the Founder Command panel, so the
      // panel visibly rests on installed foreground furniture.
      CGPoint(x: size.width / 2, y: min(size.height - 14, founderDeskY + 13))
    }
  }

  func systemSize(_ location: InfrastructurePhysicalLocation) -> CGSize {
    switch location {
    case .founderForegroundDesk: CGSize(width: min(size.width * 0.76, 264), height: 26)
    case .recoverySideBay: CGSize(width: 46, height: 28)
    default: CGSize(width: min(72, stationWidth(dominant: false) * 0.70), height: 26)
    }
  }
}

extension InfrastructurePhysicalLocation {
  var accessibilityName: String {
    switch self {
    case .stacksBuildRail: "Stacks build rail"
    case .auroraFounderVerificationBridge: "Aurora verification bridge"
    case .brioBroadcastRail: "Brio broadcast rail"
    case .recoverySideBay: "Shared recovery bay"
    case .founderForegroundDesk: "Founder Command desk"
    }
  }

  /// The company system a Founder resolution response travels into.
  static func affectedSystem(forAgentID agentID: String) -> Self {
    switch agentID {
    case "aurora": .auroraFounderVerificationBridge
    case "stacks": .stacksBuildRail
    case "brio": .brioBroadcastRail
    default: .founderForegroundDesk
    }
  }
}

// MARK: - Structural facility identity

/// Facility identity expressed without any color. Garage and Loft must differ
/// on structure alone so the difference survives a palette or subtitle removal.
struct FacilityStructureProjection: Equatable, Sendable {
  enum RailSymmetry: String, Equatable, Sendable { case asymmetric, symmetric }
  enum MountStyle: String, Equatable, Sendable { case improvised, organized }
  enum DeskProfile: String, Equatable, Sendable { case compact, refined }
  enum LightCharacter: String, Equatable, Sendable { case warmPractical, softReflected }

  var presentation: CompanySpatialPresentation
  /// Fraction of the wall band the built structure occupies. The Loft is taller.
  var structureHeightRatio: Double
  var bayCornerRadius: Double
  var railSymmetry: RailSymmetry
  var exposedConduitCount: Int
  var windowBayCount: Int
  var hasSkylineLayer: Bool
  var wallRecessCount: Int
  var mountStyle: MountStyle
  var founderDeskProfile: DeskProfile
  var lightCharacter: LightCharacter
  var stationSpacingRatio: Double
  var frameEdgeWeight: Double

  /// Color-free description used by tests and the design record.
  var structuralSignature: [String] {
    [
      "height:\(String(format: "%.2f", structureHeightRatio))",
      "corner:\(String(format: "%.1f", bayCornerRadius))",
      "rails:\(railSymmetry.rawValue)",
      "conduit:\(exposedConduitCount)",
      "windows:\(windowBayCount)",
      "skyline:\(hasSkylineLayer)",
      "recess:\(wallRecessCount)",
      "mount:\(mountStyle.rawValue)",
      "desk:\(founderDeskProfile.rawValue)",
      "light:\(lightCharacter.rawValue)",
      "spacing:\(String(format: "%.2f", stationSpacingRatio))",
      "edge:\(String(format: "%.1f", frameEdgeWeight))"
    ]
  }

  static func derive(_ presentation: CompanySpatialPresentation) -> Self {
    switch presentation {
    case .improvisedGarage:
      Self(
        presentation: presentation,
        structureHeightRatio: 0.74,
        bayCornerRadius: 6,
        railSymmetry: .asymmetric,
        exposedConduitCount: 5,
        windowBayCount: 0,
        hasSkylineLayer: false,
        wallRecessCount: 3,
        mountStyle: .improvised,
        founderDeskProfile: .compact,
        lightCharacter: .warmPractical,
        stationSpacingRatio: 0.94,
        frameEdgeWeight: 3
      )
    case .elevatedLoft:
      Self(
        presentation: presentation,
        structureHeightRatio: 1,
        bayCornerRadius: 18,
        railSymmetry: .symmetric,
        exposedConduitCount: 0,
        windowBayCount: 3,
        hasSkylineLayer: true,
        wallRecessCount: 0,
        mountStyle: .organized,
        founderDeskProfile: .refined,
        lightCharacter: .softReflected,
        stationSpacingRatio: 1.06,
        frameEdgeWeight: 1
      )
    }
  }

  static func derive(_ facility: FacilityTier) -> Self {
    derive(CompanySpatialPresentation.map(facility))
  }
}

// MARK: - Independent localized atmosphere

/// Every treatment is derived from its own player-visible canonical value and
/// can coexist with the others. Nothing here is a full-viewport color filter.
struct CompanyAtmosphereTreatment: Equatable, Sendable {
  var founderLightLevel: Double
  var ambientMovementConfidence: Double
  var runwayPressure: Double
  var externalSignalIntegrity: Double
  var momentumLinkStrength: Double
  var showsEnergyStatus: Bool
  var showsRunwayCountdown: Bool
  var showsTrustInterference: Bool
  var showsMomentumLinks: Bool

  var activeTreatmentCount: Int {
    [showsEnergyStatus, showsRunwayCountdown, showsTrustInterference, showsMomentumLinks]
      .filter { $0 }.count
  }

  static func derive(_ atmosphere: CompanyAtmosphere) -> Self {
    let runwayPressure = atmosphere.isLowRunway
      ? min(1, max(0.2, 1 - Double(max(0, atmosphere.runway)) / 8))
      : 0
    let signalIntegrity = atmosphere.isLowTrust
      ? min(1, max(0.18, Double(max(0, atmosphere.trust)) / 24))
      : 1
    return Self(
      founderLightLevel: atmosphere.isLowEnergy ? 0.42 : 1,
      ambientMovementConfidence: atmosphere.isLowEnergy ? 0.45 : 1,
      runwayPressure: runwayPressure,
      externalSignalIntegrity: signalIntegrity,
      momentumLinkStrength: atmosphere.isHighMomentum ? min(1, max(0.35, atmosphere.momentum)) : 0,
      showsEnergyStatus: atmosphere.isLowEnergy,
      showsRunwayCountdown: atmosphere.isLowRunway,
      showsTrustInterference: atmosphere.isLowTrust,
      showsMomentumLinks: atmosphere.isHighMomentum
    )
  }
}

// MARK: - Character renderer boundary

/// The complete, presentation-safe input a character renderer may read. It
/// deliberately carries no `GameStore`, task result, numeric quality, evidence
/// value, RNG, persistence handle, or canonical action availability.
struct CharacterRendererInput: Equatable, Sendable {
  enum ConditionModifier: String, CaseIterable, Hashable, Sendable {
    case stressed
    case overloaded
    case resting
    case focused
  }

  var agentID: String
  var initials: String
  var role: AgentRole
  var activity: LivingAgentActivity
  var conditionModifiers: Set<ConditionModifier>
  var emphasis: LivingPresentationEmphasis
  /// `.pending` until the canonical fifth reveal step admits the result.
  var postReviewSignal: ReviewResultVisual
  var reduceMotion: Bool
  /// Non-repeating one-shot. It changes only when a level-up is celebrated.
  var levelUpTrigger: Int

  static func derive(agent: LivingAgentProjection, reduceMotion: Bool) -> Self {
    var modifiers = Set<ConditionModifier>()
    if agent.conditions.contains(.stressed) { modifiers.insert(.stressed) }
    if agent.conditions.contains(.overloaded) { modifiers.insert(.overloaded) }
    if agent.conditions.contains(.focused) { modifiers.insert(.focused) }
    if agent.isResting || agent.activity == .resting { modifiers.insert(.resting) }
    return Self(
      agentID: agent.agentID,
      initials: agent.initials,
      role: agent.role,
      activity: agent.activity,
      conditionModifiers: modifiers,
      emphasis: agent.emphasis,
      postReviewSignal: ReviewResultVisual.map(
        conditions: agent.conditions,
        revealStep: agent.reviewRevealStep
      ),
      reduceMotion: reduceMotion,
      levelUpTrigger: agent.emphasis == .levelUpCelebration ? 1 : 0
    )
  }
}

enum CharacterRendererKind: String, Equatable, Sendable {
  case rive
  case native
}

/// The replacement boundary contract. Build 32.4 ships `.native` because no
/// production `.riv` asset exists in the repository; the resolver keeps the
/// swap honest for a future asset drop and always falls back to `.native`.
enum CharacterRendererContract {
  static let requiredRiveAssets = ["agent_aurora", "agent_stacks", "agent_brio"]

  static func bundledRiveAssetNames(in bundle: Bundle = .main) -> [String] {
    requiredRiveAssets.filter { bundle.url(forResource: $0, withExtension: "riv") != nil }
  }

  static func resolvedRenderer(in bundle: Bundle = .main) -> CharacterRendererKind {
    bundledRiveAssetNames(in: bundle).count == requiredRiveAssets.count ? .rive : .native
  }
}

// MARK: - Causal choreography plan

/// The presentation-only description of what the viewport is currently
/// animating. It is derived from immutable projections and can neither create
/// viewport focus nor request a workstation scroll.
struct CausalPresentationPlan: Equatable, Sendable {
  var objects: [CompanyCausalObject]
  /// Automatic choreography always plays in the overview scene.
  let createsFocus = false
  let requestsWorkstationNavigation = false
  let changesLayoutMode = false

  static func derive(agents: [LivingAgentProjection], reduceMotion: Bool) -> Self {
    Self(objects: agents.compactMap { CompanyCausalObject.project(agent: $0, reduceMotion: reduceMotion) })
  }

  func object(forTaskID taskID: UUID) -> CompanyCausalObject? {
    objects.first { $0.taskID == taskID }
  }

  /// Concurrent paths are separated by a stable per-agent lane so multiple
  /// active agents never produce a visually tangled overlap.
  func lane(forAgentID agentID: String, in order: [String]) -> Int {
    order.firstIndex(of: agentID) ?? 0
  }
}
