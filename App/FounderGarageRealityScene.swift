import Foundation
import CryptoKit
import Observation
import RealityKit
import simd
import UIKit

enum FounderGarageRealityQuality: String, CaseIterable, Equatable, Sendable {
  case low
  case medium
  case high

  var lightScale: Float {
    switch self {
    case .low: 0.75
    case .medium: 1
    case .high: 1.18
    }
  }
}

/// Founder Garage world space uses meters in RealityKit's right-handed coordinates:
/// +X is right, +Y is up, and +Z runs from the rear wall toward the garage door.
/// A person entering through the door looks inward along -Z.
struct FounderGarageSpatialPose: Equatable {
  let position: SIMD3<Float>
  let facingDirection: SIMD3<Float>

  var transform: Transform {
    let planarFacing = SIMD3<Float>(facingDirection.x, 0, facingDirection.z)
    let rotation: simd_quatf
    if simd_length_squared(planarFacing) > 0.000_001 {
      rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(planarFacing))
    } else {
      rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    }
    return Transform(scale: .one, rotation: rotation, translation: position)
  }
}

struct FounderGaragePlanarBounds: Equatable {
  let center: SIMD2<Float>
  let size: SIMD2<Float>

  var minX: Float { center.x - size.x / 2 }
  var maxX: Float { center.x + size.x / 2 }
  var minZ: Float { center.y - size.y / 2 }
  var maxZ: Float { center.y + size.y / 2 }

  func contains(_ point: SIMD2<Float>, margin: Float = 0) -> Bool {
    point.x >= minX + margin && point.x <= maxX - margin
      && point.y >= minZ + margin && point.y <= maxZ - margin
  }

  func contains(_ other: FounderGaragePlanarBounds, margin: Float = 0) -> Bool {
    other.minX >= minX + margin && other.maxX <= maxX - margin
      && other.minZ >= minZ + margin && other.maxZ <= maxZ - margin
  }

  func expanded(by amount: Float) -> FounderGaragePlanarBounds {
    FounderGaragePlanarBounds(center: center, size: size + SIMD2<Float>(repeating: amount * 2))
  }
}

struct FounderGarageWalkableRegion {
  let boundary: FounderGaragePlanarBounds
  let exclusions: [FounderGaragePlanarBounds]

  func contains(_ point: SIMD2<Float>) -> Bool {
    boundary.contains(point) && !exclusions.contains { $0.contains(point) }
  }
}

enum FounderGarageInteractionDistance: Float, CaseIterable {
  case closePhysical = 0.75
  case desk = 1.10
  case wallObject = 1.50
}

struct FounderGarageInteractionApproach {
  let object: FounderGarageSpatialPose
  let approach: FounderGarageSpatialPose
  let distance: FounderGarageInteractionDistance
}

struct FounderGarageSpatialBounds: Equatable {
  let center: SIMD3<Float>
  let size: SIMD3<Float>

  var planarBounds: FounderGaragePlanarBounds {
    FounderGaragePlanarBounds(center: [center.x, center.z], size: [size.x, size.z])
  }
}

/// Presentation-only spatial language for future character focus and locomotion.
/// These zones never own simulation state or make an object interactive by themselves.
struct FacilityTier0InteractionZone: Equatable, Identifiable {
  enum SemanticObject: String, CaseIterable, Hashable {
    case founderComputer
    case whiteboard
    case garageDoor
    case signalTV
    case fundingSurface
    case secondWorkstation
  }

  let id: String
  let semanticObject: SemanticObject
  let anchorName: String
  let object: FounderGarageSpatialPose
  let approach: FounderGarageSpatialPose
  let interactionDistance: FounderGarageInteractionDistance
  let activationBounds: FounderGarageSpatialBounds
  let isEnabled: Bool
}

struct FacilityTier0OccupancyAnchor: Equatable, Identifiable {
  let id: String
  let anchorName: String
  let pose: FounderGarageSpatialPose
}

struct FacilityTier0InteractionSpace: Equatable {
  let zones: [FacilityTier0InteractionZone.SemanticObject: FacilityTier0InteractionZone]
  let agentSlots: [FacilityTier0OccupancyAnchor]

  var activeZones: [FacilityTier0InteractionZone] {
    zones.values.filter(\.isEnabled)
  }

  func zone(
    for semanticObject: FacilityTier0InteractionZone.SemanticObject
  ) -> FacilityTier0InteractionZone? {
    zones[semanticObject]
  }
}

struct FounderGarageSpatialSpecification {
  static let metersPerRealityKitUnit: Float = 1
  static let inwardDirection = SIMD3<Float>(0, 0, -1)

  enum ContractIdentity: String {
    case pass6Prototype
    case facilityTier0Production
  }

  struct Room {
    let width: Float
    let depth: Float
    let wallHeight: Float
    let ceilingHeight: Float
    let wallThickness: Float
    let floorThickness: Float
    let doorOpeningWidth: Float
    let doorOpeningHeight: Float
    let doorTravelDirection: SIMD3<Float>

    var interiorBounds: FounderGaragePlanarBounds {
      FounderGaragePlanarBounds(center: .zero, size: [width, depth])
    }
  }

  struct Workstation {
    let deskSize: SIMD3<Float>
    let desktopThickness: Float
    let legSize: SIMD3<Float>
    let legInset: Float
    let chairSeatSize: SIMD3<Float>
    let chairBackSize: SIMD3<Float>
    let chairSeatHeight: Float
    let monitorSize: SIMD3<Float>
    let monitorScreenSize: SIMD3<Float>
    let monitorStandSize: SIMD3<Float>
    let monitorBaseSize: SIMD3<Float>
    let monitorBottomClearance: Float
    let iPhoneSize: SIMD3<Float>
    let iPadSize: SIMD3<Float>

    var deskHeight: Float { deskSize.y }
    var desktopCenterHeight: Float { deskHeight - desktopThickness / 2 }
    var desktopSurfaceHeight: Float { deskHeight }
  }

  struct MediaDimensions {
    let signalTV: SIMD3<Float>
    let fundingBoard: SIMD3<Float>
  }

  struct HumanScaleEnvelope {
    let minimumStandingHeight: Float
    let maximumStandingHeight: Float
    let seatedHeadHeight: Float
  }

  struct ArchitectureAnchors {
    let floor: FounderGarageSpatialPose
    let rearWall: FounderGarageSpatialPose
    let leftWall: FounderGarageSpatialPose
    let rightWall: FounderGarageSpatialPose
    let ceilingBeam: FounderGarageSpatialPose
    let garageDoor: FounderGarageSpatialPose
  }

  struct Anchors {
    let desk: FounderGarageSpatialPose
    let chair: FounderGarageSpatialPose
    let founder: FounderGarageSpatialPose
    let founderComputer: FounderGarageSpatialPose
    let iPhone: FounderGarageSpatialPose
    let iPad: FounderGarageSpatialPose
    let signalTV: FounderGarageSpatialPose
    let fundingBoard: FounderGarageSpatialPose
    let camera: FounderGarageSpatialPose
    let cameraTarget: SIMD3<Float>
    let keyLight: FounderGarageSpatialPose
    let keyLightTarget: SIMD3<Float>
    let fillLight: FounderGarageSpatialPose
  }

  struct OccupiedZones {
    let founderWork: FounderGaragePlanarBounds
    let desk: FounderGaragePlanarBounds
    let chair: FounderGaragePlanarBounds
    let devices: FounderGaragePlanarBounds
    let wallMedia: FounderGaragePlanarBounds
    let garageDoorClearance: FounderGaragePlanarBounds
  }

  struct InteractionApproaches {
    let founderComputer: FounderGarageInteractionApproach
    let signalTV: FounderGarageInteractionApproach
    let fundingBoard: FounderGarageInteractionApproach
    let garageDoor: FounderGarageInteractionApproach
  }

  struct ProductionAnchorMap {
    let cameraIso: SIMD3<Float>
    let cameraFront: SIMD3<Float>
    let cameraLook: SIMD3<Float>
    let founderSeat: SIMD3<Float>
    let agentSlots: [SIMD3<Float>]
    let deskSurface: SIMD3<Float>
    let agentDeskSurface: SIMD3<Float>
    let monitorFace: SIMD3<Float>
    let whiteboardFace: SIMD3<Float>
    let posterFace: SIMD3<Float>
    let doorMouth: SIMD3<Float>
    let ceilingCenter: SIMD3<Float>
    let hangingLights: [SIMD3<Float>]
    let deskLamp: SIMD3<Float>
    let deskGlowVFX: SIMD3<Float>
    let doorLightVFX: SIMD3<Float>

    var namedPositions: [String: SIMD3<Float>] {
      [
        "Anchor_Camera_Iso": cameraIso,
        "Anchor_Camera_Front": cameraFront,
        "Anchor_Camera_Look": cameraLook,
        "Anchor_Founder_Seat": founderSeat,
        "Anchor_Agent_Slot_01": agentSlots[0],
        "Anchor_Agent_Slot_02": agentSlots[1],
        "Anchor_Agent_Slot_03": agentSlots[2],
        "Anchor_Agent_Slot_04": agentSlots[3],
        "Anchor_Desk_Surface": deskSurface,
        "Anchor_AgentDesk_Surface": agentDeskSurface,
        "Anchor_Monitor_Face": monitorFace,
        "Anchor_Whiteboard_Face": whiteboardFace,
        "Anchor_Poster_Face": posterFace,
        "Anchor_Door_Mouth": doorMouth,
        "Anchor_Ceiling_Center": ceilingCenter,
        "Anchor_Light_Hanging_01": hangingLights[0],
        "Anchor_Light_Hanging_02": hangingLights[1],
        "Anchor_Light_DeskLamp": deskLamp,
        "Anchor_VFX_DeskGlow": deskGlowVFX,
        "Anchor_VFX_DoorLight": doorLightVFX
      ]
    }
  }

  let room: Room
  let workstation: Workstation
  let media: MediaDimensions
  let humanScale: HumanScaleEnvelope
  let architecture: ArchitectureAnchors
  let anchors: Anchors
  let occupiedZones: OccupiedZones
  let walkableRegion: FounderGarageWalkableRegion
  let interactionApproaches: InteractionApproaches
  let facilityTier0InteractionSpace: FacilityTier0InteractionSpace?
  let contractIdentity: ContractIdentity
  let productionAnchors: ProductionAnchorMap?
  let cameraFieldOfViewDegrees: Float
  let cameraViewingRegion: FounderGaragePlanarBounds
  let ceilingBeamSize: SIMD3<Float>

  /// Historical Pass 6 dimensions retained for fixture normalization and migration tests.
  static let pass6Prototype: FounderGarageSpatialSpecification = {
    // A believable single-car startup Garage: compact enough to read as one room,
    // with enough side clearance for future locomotion and production assets.
    let room = Room(
      width: 5.8,
      depth: 6.4,
      wallHeight: 3.1,
      ceilingHeight: 3.1,
      wallThickness: 0.12,
      floorThickness: 0.10,
      doorOpeningWidth: 2.8,
      doorOpeningHeight: 2.35,
      doorTravelDirection: [0, 1, 0]
    )
    let workstation = Workstation(
      deskSize: [3.0, 0.78, 0.90],
      desktopThickness: 0.08,
      legSize: [0.10, 0.74, 0.10],
      legInset: 0.18,
      chairSeatSize: [0.66, 0.10, 0.62],
      chairBackSize: [0.64, 0.78, 0.12],
      chairSeatHeight: 0.46,
      monitorSize: [1.24, 0.72, 0.08],
      monitorScreenSize: [1.12, 0.62, 0.035],
      monitorStandSize: [0.08, 0.38, 0.08],
      monitorBaseSize: [0.54, 0.045, 0.24],
      monitorBottomClearance: 0.12,
      iPhoneSize: [0.16, 0.018, 0.32],
      iPadSize: [0.48, 0.024, 0.34]
    )
    let media = MediaDimensions(
      signalTV: [1.42, 0.80, 0.08],
      fundingBoard: [1.36, 0.86, 0.06]
    )
    let rearWallFrontZ = -room.depth / 2 + room.wallThickness
    let desk = FounderGarageSpatialPose(position: [0, 0, 0.35], facingDirection: [0, 0, 1])
    let chair = FounderGarageSpatialPose(position: [0, 0, 1.12], facingDirection: [0, 0, -1])
    let founder = FounderGarageSpatialPose(position: [0, 0, 1.05], facingDirection: [0, 0, -1])
    let computer = FounderGarageSpatialPose(position: [0, 0, 0.18], facingDirection: [0, 0, 1])
    let signalTV = FounderGarageSpatialPose(position: [-1.70, 1.88, rearWallFrontZ + media.signalTV.z / 2], facingDirection: [0, 0, 1])
    let fundingBoard = FounderGarageSpatialPose(position: [1.72, 1.88, rearWallFrontZ + media.fundingBoard.z / 2], facingDirection: [0, 0, 1])
    let garageDoor = FounderGarageSpatialPose(position: [0, 1.175, 3.14], facingDirection: [0, 0, -1])
    let wallInset = room.wallThickness / 2
    let interiorBoundary = FounderGaragePlanarBounds(
      center: .zero,
      size: [room.width - room.wallThickness * 2, room.depth - room.wallThickness * 2]
    )
    let deskZone = FounderGaragePlanarBounds(center: [desk.position.x, desk.position.z], size: [3.0, 0.90])
    let chairZone = FounderGaragePlanarBounds(center: [chair.position.x, chair.position.z], size: [0.76, 0.80])
    let doorClearance = FounderGaragePlanarBounds(center: [0, 2.25], size: [3.20, 1.70])

    return FounderGarageSpatialSpecification(
      room: room,
      workstation: workstation,
      media: media,
      humanScale: HumanScaleEnvelope(
        minimumStandingHeight: 1.52,
        maximumStandingHeight: 1.95,
        seatedHeadHeight: 1.68
      ),
      architecture: ArchitectureAnchors(
        floor: FounderGarageSpatialPose(position: [0, -room.floorThickness / 2, 0], facingDirection: [0, 1, 0]),
        rearWall: FounderGarageSpatialPose(position: [0, room.wallHeight / 2, -room.depth / 2 + wallInset], facingDirection: [0, 0, 1]),
        leftWall: FounderGarageSpatialPose(position: [-room.width / 2 + wallInset, room.wallHeight / 2, 0], facingDirection: [1, 0, 0]),
        rightWall: FounderGarageSpatialPose(position: [room.width / 2 - wallInset, room.wallHeight / 2, 0], facingDirection: [-1, 0, 0]),
        ceilingBeam: FounderGarageSpatialPose(position: [0, 3.00, -1.20], facingDirection: [0, -1, 0]),
        garageDoor: garageDoor
      ),
      anchors: Anchors(
        desk: desk,
        chair: chair,
        founder: founder,
        founderComputer: computer,
        iPhone: FounderGarageSpatialPose(position: [-1.08, 0.789, 0.50], facingDirection: [0, 1, 0]),
        iPad: FounderGarageSpatialPose(position: [1.02, 0.792, 0.43], facingDirection: [0, 1, 0]),
        signalTV: signalTV,
        fundingBoard: fundingBoard,
        camera: FounderGarageSpatialPose(position: [0, 1.95, 5.80], facingDirection: [0, 0, -1]),
        cameraTarget: [0, 1.15, -0.65],
        keyLight: FounderGarageSpatialPose(position: [-2.45, 3.85, 2.55], facingDirection: [0, -1, -1]),
        keyLightTarget: [0, 0.82, -0.35],
        fillLight: FounderGarageSpatialPose(position: [2.30, 2.18, 2.10], facingDirection: [0, 0, -1])
      ),
      occupiedZones: OccupiedZones(
        founderWork: FounderGaragePlanarBounds(center: [0, 0.52], size: [3.40, 2.25]),
        desk: deskZone,
        chair: chairZone,
        devices: FounderGaragePlanarBounds(center: [0, 0.38], size: [2.65, 0.58]),
        wallMedia: FounderGaragePlanarBounds(center: [0, -3.02], size: [4.60, 0.24]),
        garageDoorClearance: doorClearance
      ),
      walkableRegion: FounderGarageWalkableRegion(
        boundary: interiorBoundary,
        exclusions: [deskZone, chairZone]
      ),
      interactionApproaches: InteractionApproaches(
        founderComputer: FounderGarageInteractionApproach(
          object: computer,
          approach: FounderGarageSpatialPose(position: founder.position, facingDirection: [0, 0, -1]),
          distance: .desk
        ),
        signalTV: FounderGarageInteractionApproach(
          object: signalTV,
          approach: FounderGarageSpatialPose(position: [-1.70, 0, -2.10], facingDirection: [0, 0, -1]),
          distance: .wallObject
        ),
        fundingBoard: FounderGarageInteractionApproach(
          object: fundingBoard,
          approach: FounderGarageSpatialPose(position: [1.72, 0, -2.10], facingDirection: [0, 0, -1]),
          distance: .wallObject
        ),
        garageDoor: FounderGarageInteractionApproach(
          object: garageDoor,
          approach: FounderGarageSpatialPose(position: [0, 0, 2.20], facingDirection: [0, 0, 1]),
          distance: .closePhysical
        )
      ),
      facilityTier0InteractionSpace: nil,
      contractIdentity: .pass6Prototype,
      productionAnchors: nil,
      cameraFieldOfViewDegrees: 58,
      cameraViewingRegion: FounderGaragePlanarBounds(center: [0, 1.35], size: [5.4, 9.1]),
      ceilingBeamSize: [5.55, 0.14, 0.18]
    )
  }()

  /// Facility Tier 0 is authored in native meters by founder_garage.usdz.
  static let standard: FounderGarageSpatialSpecification = {
    let prototype = pass6Prototype
    let room = Room(
      width: 5.00,
      depth: 5.50,
      wallHeight: 2.70,
      ceilingHeight: 2.70,
      wallThickness: 0.12,
      floorThickness: 0.12,
      doorOpeningWidth: 3.00,
      doorOpeningHeight: 2.40,
      doorTravelDirection: [0, 1, 0]
    )
    let authored = ProductionAnchorMap(
      cameraIso: [5.40, 4.10, 6.30],
      cameraFront: [0.60, 2.60, 8.20],
      cameraLook: [0.45, 1.00, -0.35],
      founderSeat: [0.34, 0, -0.22],
      agentSlots: [
        [-1.75, 0, -0.40],
        [1.28, 0, 1.52],
        [-1.45, 0, -1.20],
        [0.35, 0, 2.05]
      ],
      deskSurface: [0.95, 0.7575, -1.05],
      agentDeskSurface: [1.62, 0.735, 0.85],
      monitorFace: [1.42, 1.30, -1.08],
      whiteboardFace: [-2.42, 1.52, -0.40],
      posterFace: [-2.42, 1.72, 1.55],
      doorMouth: [0, 1.20, 2.75],
      ceilingCenter: [0, 2.55, 0],
      hangingLights: [[-0.30, 2.04, -1.55], [1.10, 2.04, 0.05]],
      deskLamp: [0.175, 1.22, -1.185],
      deskGlowVFX: [0.95, 0.92, -1.05],
      doorLightVFX: [0, 2.00, 2.60]
    )
    let founderToMonitor = authored.monitorFace - authored.founderSeat
    let founderFacing = simd_normalize(SIMD3<Float>(founderToMonitor.x, 0, founderToMonitor.z))
    let founder = FounderGarageSpatialPose(position: authored.founderSeat, facingDirection: founderFacing)
    let desk = FounderGarageSpatialPose(
      position: [authored.deskSurface.x, 0, authored.deskSurface.z],
      facingDirection: [0, 0, 1]
    )
    let chair = FounderGarageSpatialPose(position: authored.founderSeat, facingDirection: founderFacing)
    let monitor = FounderGarageSpatialPose(position: authored.monitorFace, facingDirection: -founderFacing)
    let rearWallFrontZ = -room.depth / 2
    let wallInset = room.wallThickness / 2
    let interiorBoundary = FounderGaragePlanarBounds(center: .zero, size: [room.width, room.depth])
    let deskZone = FounderGaragePlanarBounds(center: [0.95, -1.05], size: [1.85, 0.80])
    let chairZone = FounderGaragePlanarBounds(center: [0.34, -0.22], size: [0.72, 0.72])
    let frontBayZone = FounderGaragePlanarBounds(center: [1.62, 0.85], size: [1.85, 0.75])
    let shelvingZone = FounderGaragePlanarBounds(center: [-2.20, -2.00], size: [0.50, 1.40])
    let doorClearance = FounderGaragePlanarBounds(center: [0, 2.20], size: [2.90, 1.00])
    let signalTV = FounderGarageSpatialPose(position: [-1.45, 1.70, rearWallFrontZ + 0.04], facingDirection: [0, 0, 1])
    let fundingBoard = FounderGarageSpatialPose(position: [1.55, 1.70, rearWallFrontZ + 0.03], facingDirection: [0, 0, 1])
    let door = FounderGarageSpatialPose(position: authored.doorMouth, facingDirection: [0, 0, -1])
    let secondWorkstationApproach = FounderGarageSpatialPose(
      position: authored.agentSlots[1],
      facingDirection: simd_normalize(SIMD3<Float>(
        authored.agentDeskSurface.x - authored.agentSlots[1].x,
        0,
        authored.agentDeskSurface.z - authored.agentSlots[1].z
      ))
    )
    let interactionSpace = FacilityTier0InteractionSpace(
      zones: [
        .founderComputer: FacilityTier0InteractionZone(
          id: "facilityTier0.founderComputer",
          semanticObject: .founderComputer,
          anchorName: "Anchor_Monitor_Face",
          object: monitor,
          approach: founder,
          interactionDistance: .desk,
          activationBounds: FounderGarageSpatialBounds(
            center: authored.monitorFace,
            size: [0.59, 0.34, 0.04]
          ),
          isEnabled: true
        ),
        .whiteboard: FacilityTier0InteractionZone(
          id: "facilityTier0.whiteboard",
          semanticObject: .whiteboard,
          anchorName: "Anchor_Whiteboard_Face",
          object: FounderGarageSpatialPose(position: authored.whiteboardFace, facingDirection: [1, 0, 0]),
          approach: FounderGarageSpatialPose(position: [-1.15, 0, -0.40], facingDirection: [-1, 0, 0]),
          interactionDistance: .wallObject,
          activationBounds: FounderGarageSpatialBounds(center: authored.whiteboardFace, size: [0.08, 1.30, 1.55]),
          isEnabled: false
        ),
        .garageDoor: FacilityTier0InteractionZone(
          id: "facilityTier0.garageDoor",
          semanticObject: .garageDoor,
          anchorName: "Anchor_Door_Mouth",
          object: door,
          approach: FounderGarageSpatialPose(position: [0, 0, 2.15], facingDirection: [0, 0, 1]),
          interactionDistance: .closePhysical,
          activationBounds: FounderGarageSpatialBounds(center: [0, 1.20, 2.20], size: [2.90, 2.40, 1.00]),
          isEnabled: false
        ),
        .signalTV: FacilityTier0InteractionZone(
          id: "facilityTier0.signalTV",
          semanticObject: .signalTV,
          anchorName: "future.SignalTV",
          object: signalTV,
          approach: FounderGarageSpatialPose(position: [-1.45, 0, -1.85], facingDirection: [0, 0, -1]),
          interactionDistance: .wallObject,
          activationBounds: FounderGarageSpatialBounds(center: signalTV.position, size: prototype.media.signalTV),
          isEnabled: false
        ),
        .fundingSurface: FacilityTier0InteractionZone(
          id: "facilityTier0.fundingSurface",
          semanticObject: .fundingSurface,
          anchorName: "future.FundingSurface",
          object: fundingBoard,
          approach: FounderGarageSpatialPose(position: [1.55, 0, -1.85], facingDirection: [0, 0, -1]),
          interactionDistance: .wallObject,
          activationBounds: FounderGarageSpatialBounds(center: fundingBoard.position, size: prototype.media.fundingBoard),
          isEnabled: false
        ),
        .secondWorkstation: FacilityTier0InteractionZone(
          id: "facilityTier0.secondWorkstation",
          semanticObject: .secondWorkstation,
          anchorName: "Anchor_AgentDesk_Surface",
          object: FounderGarageSpatialPose(position: authored.agentDeskSurface, facingDirection: [0, 0, 1]),
          approach: secondWorkstationApproach,
          interactionDistance: .desk,
          activationBounds: FounderGarageSpatialBounds(center: [1.62, 0.735 / 2, 0.85], size: [1.85, 0.735, 0.75]),
          isEnabled: false
        )
      ],
      agentSlots: authored.agentSlots.enumerated().map { index, position in
        let centerFacing = simd_normalize(SIMD3<Float>(-position.x, 0, -position.z))
        return FacilityTier0OccupancyAnchor(
          id: String(format: "facilityTier0.agentSlot%02d", index + 1),
          anchorName: String(format: "Anchor_Agent_Slot_%02d", index + 1),
          pose: FounderGarageSpatialPose(position: position, facingDirection: centerFacing)
        )
      }
    )

    return FounderGarageSpatialSpecification(
      room: room,
      workstation: Workstation(
        deskSize: [1.85, 0.7575, 0.80],
        desktopThickness: 0.045,
        legSize: [0.07, 0.7125, 0.07],
        legInset: 0.16,
        chairSeatSize: [0.64, 0.075, 0.64],
        chairBackSize: [0.52, 0.52, 0.08],
        chairSeatHeight: 0.455,
        monitorSize: [0.64, 0.375, 0.18],
        monitorScreenSize: [0.59, 0.34, 0.04],
        monitorStandSize: [0.06, 0.20, 0.06],
        monitorBaseSize: [0.30, 0.022, 0.22],
        monitorBottomClearance: 0.35,
        iPhoneSize: prototype.workstation.iPhoneSize,
        iPadSize: prototype.workstation.iPadSize
      ),
      media: prototype.media,
      humanScale: prototype.humanScale,
      architecture: ArchitectureAnchors(
        floor: FounderGarageSpatialPose(position: [0, -room.floorThickness / 2, 0], facingDirection: [0, 1, 0]),
        rearWall: FounderGarageSpatialPose(position: [0, room.wallHeight / 2, -room.depth / 2 - wallInset], facingDirection: [0, 0, 1]),
        leftWall: FounderGarageSpatialPose(position: [-room.width / 2 - wallInset, room.wallHeight / 2, 0], facingDirection: [1, 0, 0]),
        rightWall: FounderGarageSpatialPose(position: [room.width / 2 + wallInset, room.wallHeight / 2, 0], facingDirection: [-1, 0, 0]),
        ceilingBeam: FounderGarageSpatialPose(position: [0, 2.61, -0.80], facingDirection: [0, -1, 0]),
        garageDoor: door
      ),
      anchors: Anchors(
        desk: desk,
        chair: chair,
        founder: founder,
        founderComputer: monitor,
        iPhone: FounderGarageSpatialPose(position: [0.35, authored.deskSurface.y + 0.009, -1.00], facingDirection: [0, 1, 0]),
        iPad: FounderGarageSpatialPose(position: [0.63, authored.deskSurface.y + 0.012, -0.87], facingDirection: [0, 1, 0]),
        signalTV: signalTV,
        fundingBoard: fundingBoard,
        camera: FounderGarageSpatialPose(position: authored.cameraIso, facingDirection: simd_normalize(authored.cameraLook - authored.cameraIso)),
        cameraTarget: authored.cameraLook,
        keyLight: FounderGarageSpatialPose(position: authored.doorLightVFX, facingDirection: [0, -1, -1]),
        keyLightTarget: [0.95, 0.82, -1.05],
        fillLight: FounderGarageSpatialPose(position: authored.hangingLights[1], facingDirection: [0, -1, 0])
      ),
      occupiedZones: OccupiedZones(
        founderWork: FounderGaragePlanarBounds(center: [0.95, -0.70], size: [2.15, 1.50]),
        desk: deskZone,
        chair: chairZone,
        devices: FounderGaragePlanarBounds(center: [1.30, -1.12], size: [1.20, 0.55]),
        wallMedia: FounderGaragePlanarBounds(center: [-2.43, 0.58], size: [0.14, 4.15]),
        garageDoorClearance: doorClearance
      ),
      walkableRegion: FounderGarageWalkableRegion(
        boundary: interiorBoundary,
        exclusions: [deskZone, chairZone, frontBayZone, shelvingZone]
      ),
      interactionApproaches: InteractionApproaches(
        founderComputer: FounderGarageInteractionApproach(object: monitor, approach: founder, distance: .desk),
        signalTV: FounderGarageInteractionApproach(
          object: signalTV,
          approach: FounderGarageSpatialPose(position: [-1.45, 0, -1.85], facingDirection: [0, 0, -1]),
          distance: .wallObject
        ),
        fundingBoard: FounderGarageInteractionApproach(
          object: fundingBoard,
          approach: FounderGarageSpatialPose(position: [1.55, 0, -1.85], facingDirection: [0, 0, -1]),
          distance: .wallObject
        ),
        garageDoor: FounderGarageInteractionApproach(
          object: door,
          approach: FounderGarageSpatialPose(position: [0, 0, 2.15], facingDirection: [0, 0, 1]),
          distance: .closePhysical
        )
      ),
      facilityTier0InteractionSpace: interactionSpace,
      contractIdentity: .facilityTier0Production,
      productionAnchors: authored,
      cameraFieldOfViewDegrees: 52,
      cameraViewingRegion: FounderGaragePlanarBounds(center: [2.70, 2.70], size: [7.50, 12.00]),
      ceilingBeamSize: [5.24, 0.18, 0.14]
    )
  }()

  func isPointInsideFacility(_ point: SIMD2<Float>, margin: Float = 0) -> Bool {
    room.interiorBounds.contains(point, margin: margin)
  }

  func isPointInsideOccupiedZone(_ point: SIMD2<Float>) -> Bool {
    walkableRegion.exclusions.contains { $0.contains(point) }
  }

  func isPointWalkable(_ point: SIMD2<Float>) -> Bool {
    isPointInsideFacility(point) && !isPointInsideOccupiedZone(point)
  }

  var validationFailures: [String] {
    var failures: [String] = []
    let roomBounds = room.interiorBounds
    let objectPoints = [
      anchors.desk.position, anchors.chair.position, anchors.founder.position,
      anchors.founderComputer.position, anchors.iPhone.position, anchors.iPad.position,
      anchors.signalTV.position, anchors.fundingBoard.position
    ]
    if room.width <= 0 || room.depth <= 0 || room.wallHeight <= 0 { failures.append("room dimensions") }
    if !objectPoints.allSatisfy({ roomBounds.contains([$0.x, $0.z]) }) { failures.append("object outside room") }
    if workstation.deskHeight <= 0 || anchors.desk.position.y != 0 { failures.append("desk floor relationship") }
    let rearWallFrontZ = architecture.rearWall.position.z + room.wallThickness / 2
    if abs(anchors.signalTV.position.z - (rearWallFrontZ + media.signalTV.z / 2)) > 0.001
      || abs(anchors.fundingBoard.position.z - (rearWallFrontZ + media.fundingBoard.z / 2)) > 0.001 {
      failures.append("rear wall media")
    }
    if !cameraViewingRegion.contains([anchors.camera.position.x, anchors.camera.position.z]) {
      failures.append("camera viewing region")
    }
    if anchors.founder.position.y < 0 { failures.append("Founder below floor") }
    if abs(anchors.founderComputer.position.x - anchors.desk.position.x) > workstation.deskSize.x / 2
      || anchors.founderComputer.position.z < occupiedZones.desk.minZ
      || anchors.founderComputer.position.z > occupiedZones.desk.maxZ {
      failures.append("monitor desk relationship")
    }
    if abs(anchors.chair.position.x - anchors.desk.position.x) > workstation.deskSize.x / 2
      || abs(anchors.chair.position.z - anchors.desk.position.z) > 1.20 {
      failures.append("chair desk relationship")
    }
    if room.doorOpeningWidth >= room.width || room.doorOpeningHeight >= room.wallHeight {
      failures.append("garage door dimensions")
    }
    if !roomBounds.contains(occupiedZones.founderWork)
      || !roomBounds.contains(occupiedZones.garageDoorClearance) {
      failures.append("occupied zone outside architecture")
    }
    if humanScale.maximumStandingHeight >= room.ceilingHeight { failures.append("human ceiling clearance") }
    return failures
  }
}

enum FounderGarageArchitectureSource: Hashable, Sendable {
  case procedural
  case bundledProductionAsset(name: String)
}

struct FounderGarageArchitectureBounds: Equatable {
  let minimum: SIMD3<Float>
  let maximum: SIMD3<Float>

  var size: SIMD3<Float> { maximum - minimum }
  var center: SIMD3<Float> { (minimum + maximum) / 2 }

  static func canonical(for spatial: FounderGarageSpatialSpecification) -> Self {
    FounderGarageArchitectureBounds(
      minimum: [-spatial.room.width / 2, 0, -spatial.room.depth / 2],
      maximum: [spatial.room.width / 2, spatial.room.wallHeight, spatial.room.depth / 2]
    )
  }

  func approximatelyMatches(_ other: Self, tolerance: Float) -> Bool {
    simd_distance(minimum, other.minimum) <= tolerance
      && simd_distance(maximum, other.maximum) <= tolerance
  }
}

struct FounderGarageArchitectureNormalization {
  let nativeBounds: FounderGarageArchitectureBounds
  let targetBounds: FounderGarageArchitectureBounds
  let uniformScale: Float
  let orientationCorrection: simd_quatf
  let translationCorrection: SIMD3<Float>
  let resultingBounds: FounderGarageArchitectureBounds
}

struct FounderGarageArchitectureAssetDescriptor {
  enum ScalePolicy {
    case uniformlyFitCanonicalInterior
    case requireNativeBounds(FounderGarageArchitectureBounds)
  }

  let orientationCorrection: simd_quatf
  let maximumProportionVariance: Float
  let boundsTolerance: Float
  let scalePolicy: ScalePolicy
  let requiredEntityNames: Set<String>

  var usesModernHierarchy = false
  var isV4 = false
  var isV6 = false
  var isV7 = false

  static var facilityTier0V3: FounderGarageArchitectureAssetDescriptor {
    FounderGarageArchitectureAssetDescriptor(
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      maximumProportionVariance: 0.025,
      boundsTolerance: 0.025,
      scalePolicy: .requireNativeBounds(.init(minimum: [-2.66, -0.18, -2.91], maximum: [2.66, 2.70, 2.91])),
      requiredEntityNames: ["FounderGarage", "Shell", "Door", "Furniture", "Tech", "Clutter", "FrontBay", "WallDressing", "Lighting", "Anchors", "Floor", "RearWall", "FounderChair", "FounderDesk", "FounderMonitor", "Monitor_Display"],
      usesModernHierarchy: true
    )
  }

  static var facilityTier0V4: FounderGarageArchitectureAssetDescriptor {
    FounderGarageArchitectureAssetDescriptor(
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      maximumProportionVariance: 0.025,
      boundsTolerance: 0.025,
      scalePolicy: .requireNativeBounds(.init(
        minimum: [-2.66, -0.18, -2.91],
        maximum: [2.70, 2.88, 2.91]
      )),
      requiredEntityNames: [
        "FounderGarage", "Shell", "Door", "Furniture", "Tech", "Clutter",
        "FrontBay", "WallDressing", "Lighting", "Anchors", "Floor", "RearWall",
        "Garage_RightWall", "Ceiling", "GarageDoor_Panel", "GarageDoor_Header",
        "GarageDoor_Track_L", "GarageDoor_Track_R", "FounderChair", "FounderDesk",
        "FounderMonitor", "Monitor_Display"
      ],
      usesModernHierarchy: true,
      isV4: true
    )
  }

  static var facilityTier0V6: FounderGarageArchitectureAssetDescriptor {
    FounderGarageArchitectureAssetDescriptor(
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      maximumProportionVariance: 0.025,
      boundsTolerance: 0.025,
      scalePolicy: .requireNativeBounds(.init(
        minimum: [-40.0, -0.21, -30.0],
        maximum: [40.0, 7.9, 26.0]
      )),
      requiredEntityNames: [
        "FounderGarage", "Shell", "Door", "Furniture", "Tech", "Clutter",
        "FrontBay", "WallDressing", "Lighting", "Anchors", "Exterior", "Floor",
        "RearWall", "Garage_RightWall", "Ceiling", "GarageDoor_Panel",
        "GarageDoor_Header", "GarageDoor_Track_L", "GarageDoor_Track_R",
        "FounderChair", "FounderDesk", "FounderMonitor", "Monitor_Display",
        "Driveway", "LotGround", "Sidewalk", "DrivewayApron_CurbCut",
        "Curb_L", "Curb_R", "Street", "Facade_Fascia", "FrontYard_L",
        "FrontYard_R", "Mailbox", "Tree_L", "Tree_R"
      ],
      usesModernHierarchy: true,
      isV6: true
    )
  }

  static var facilityTier0V7: FounderGarageArchitectureAssetDescriptor {
    FounderGarageArchitectureAssetDescriptor(
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      maximumProportionVariance: 0.025,
      boundsTolerance: 0.025,
      scalePolicy: .requireNativeBounds(.init(
        minimum: [-40.0, -0.24, -30.0],
        maximum: [40.0, 7.9, 26.0]
      )),
      requiredEntityNames: [
        "FounderGarage", "Shell", "Door", "Furniture", "Tech", "Clutter",
        "FrontBay", "WallDressing", "Lighting", "Anchors", "Exterior", "Floor",
        "RearWall", "Garage_RightWall", "Ceiling", "GarageDoor_Panel",
        "GarageDoor_Header", "GarageDoor_Track_L", "GarageDoor_Track_R",
        "FounderChair", "FounderDesk", "FounderMonitor", "Monitor_Display",
        "Driveway", "LotGround", "Sidewalk", "DrivewayApron_CurbCut",
        "Curb_L", "Curb_R", "Street", "Facade_Fascia", "FrontYard_L",
        "FrontYard_R", "Mailbox", "Tree_L", "Tree_R", "FrontLawn_L", "FrontLawn_R",
        "Threshold_Apron", "ExteriorFacade", "ExteriorLight_01", "ExteriorLight_01_Lens"
      ],
      usesModernHierarchy: true,
      isV7: true
    )
  }

  static var canonicalAxes: FounderGarageArchitectureAssetDescriptor {
    FounderGarageArchitectureAssetDescriptor(
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      maximumProportionVariance: 0.05,
      boundsTolerance: 0.08,
      scalePolicy: .uniformlyFitCanonicalInterior,
      requiredEntityNames: []
    )
  }

  static var facilityTier0: FounderGarageArchitectureAssetDescriptor {
    FounderGarageArchitectureAssetDescriptor(
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      maximumProportionVariance: 0,
      boundsTolerance: 0.025,
      scalePolicy: .requireNativeBounds(
        FounderGarageArchitectureBounds(
          minimum: [-2.62, -0.12, -2.87],
          maximum: [2.62, 2.70, 2.89]
        )
      ),
      requiredEntityNames: [
        "FounderGarage", "Shell", "Door", "Furniture", "Tech", "Clutter",
        "FrontBay", "WallDressing", "Lighting", "Anchors",
        "Floor_Slab", "Wall_Back", "Wall_Right_Cutaway", "Header_Beam",
        "Door_Rolled", "Monitor_Screen"
      ]
    )
  }
}

@MainActor
struct FacilityTier0ResolvedAnchorMap {
  let cameraIso: Entity
  let cameraFront: Entity
  let cameraLook: Entity
  let founderSeat: Entity
  let agentSlots: [Entity]
  let deskSurface: Entity
  let agentDeskSurface: Entity
  let monitorFace: Entity
  let whiteboardFace: Entity
  let posterFace: Entity
  let doorMouth: Entity
  let ceilingCenter: Entity
  let hangingLights: [Entity]
  let deskLamp: Entity
  let deskGlowVFX: Entity
  let doorLightVFX: Entity
  let entitiesByName: [String: Entity]

  init(root: Entity) throws {
    func require(_ name: String) throws -> Entity {
      guard let entity = root.findEntity(named: name) else {
        throw FounderGarageArchitectureAdapterError.missingRequiredEntity(name)
      }
      return entity
    }

    let cameraIso = try require("Anchor_Camera_Iso")
    let cameraFront = try require("Anchor_Camera_Front")
    let cameraLook = try require("Anchor_Camera_Look")
    let founderSeat = try require("Anchor_Founder_Seat")
    let agentSlots = try (1...4).map { try require(String(format: "Anchor_Agent_Slot_%02d", $0)) }
    let deskSurface = try require("Anchor_Desk_Surface")
    let agentDeskSurface = try require("Anchor_AgentDesk_Surface")
    let monitorFace = try require("Anchor_Monitor_Face")
    let whiteboardFace = try require("Anchor_Whiteboard_Face")
    let posterFace = try require("Anchor_Poster_Face")
    let doorMouth = try require("Anchor_Door_Mouth")
    let ceilingCenter = try require("Anchor_Ceiling_Center")
    let hangingLights = try (1...2).map { try require(String(format: "Anchor_Light_Hanging_%02d", $0)) }
    let deskLamp = try require("Anchor_Light_DeskLamp")
    let deskGlowVFX = try require("Anchor_VFX_DeskGlow")
    let doorLightVFX = try require("Anchor_VFX_DoorLight")
    let all = [
      cameraIso, cameraFront, cameraLook, founderSeat
    ] + agentSlots + [
      deskSurface, agentDeskSurface, monitorFace, whiteboardFace, posterFace,
      doorMouth, ceilingCenter
    ] + hangingLights + [deskLamp, deskGlowVFX, doorLightVFX]

    self.cameraIso = cameraIso
    self.cameraFront = cameraFront
    self.cameraLook = cameraLook
    self.founderSeat = founderSeat
    self.agentSlots = agentSlots
    self.deskSurface = deskSurface
    self.agentDeskSurface = agentDeskSurface
    self.monitorFace = monitorFace
    self.whiteboardFace = whiteboardFace
    self.posterFace = posterFace
    self.doorMouth = doorMouth
    self.ceilingCenter = ceilingCenter
    self.hangingLights = hangingLights
    self.deskLamp = deskLamp
    self.deskGlowVFX = deskGlowVFX
    self.doorLightVFX = doorLightVFX
    entitiesByName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
  }

  func positions(relativeTo root: Entity) -> [String: SIMD3<Float>] {
    entitiesByName.mapValues { $0.position(relativeTo: root) }
  }
}

@MainActor
struct FacilityTier0LayerRegistry {
  let shell: Entity
  let door: Entity
  let furniture: Entity
  let tech: Entity
  let clutter: Entity
  let frontBay: Entity
  let wallDressing: Entity
  let lighting: Entity

  init(root: Entity) throws {
    func require(_ name: String) throws -> Entity {
      guard let entity = root.findEntity(named: name) else {
        throw FounderGarageArchitectureAdapterError.missingRequiredEntity(name)
      }
      return entity
    }
    shell = try require("Shell")
    door = try require("Door")
    furniture = try require("Furniture")
    tech = try require("Tech")
    clutter = try require("Clutter")
    frontBay = try require("FrontBay")
    wallDressing = try require("WallDressing")
    lighting = try require("Lighting")
  }
}

@MainActor
struct FacilityTier0MaterialAudit {
  enum Category: String, CaseIterable, Hashable {
    case floorSlab
    case plywood
    case studLumber
    case paintedSurfaces
    case metal
    case plastic
    case fabric
    case rug
    case monitorScreen
    case laptopScreen
    case whiteboard
    case pegboard
    case door
    case furniture
  }

  let entitiesByCategory: [Category: [Entity]]
  let overriddenEntityNames: Set<String>

  init(root: Entity) {
    let representativeNames: [Category: [String]] = [
      .floorSlab: ["Floor_Slab", "Floor_WornPatch"],
      .plywood: ["Desk_Top", "AgentDesk_Top"],
      .studLumber: ["Stud_Back_00", "Rafter_00"],
      .paintedSurfaces: ["Wall_Back", "Poster_Field"],
      .metal: ["Track_Vert_L", "Desk_Leg_00", "Tool_Wrench_Head"],
      .plastic: ["Keyboard", "Mouse", "Bin_00"],
      .fabric: ["Chair_Seat", "Pouf_Body"],
      .rug: ["Rug"],
      .monitorScreen: ["Monitor_Screen"],
      .laptopScreen: ["Laptop_Screen"],
      .whiteboard: ["Whiteboard_Surface"],
      .pegboard: ["Pegboard"],
      .door: ["Door_Slat_00", "Threshold"],
      .furniture: ["Desk_Top", "Chair_Seat", "Shelf_Deck_00", "AgentDesk_Top"]
    ]
    entitiesByCategory = representativeNames.mapValues { names in
      names.compactMap { root.findEntity(named: $0) }
    }
    overriddenEntityNames = []
  }
}

struct FacilityTier0ImportedOccupiedBounds: Equatable {
  let founderDesk: FounderGaragePlanarBounds
  let chair: FounderGaragePlanarBounds
  let frontBayDesk: FounderGaragePlanarBounds
  let shelving: FounderGaragePlanarBounds

  var all: [FounderGaragePlanarBounds] {
    [founderDesk, chair, frontBayDesk, shelving]
  }
}

struct FounderGarageArchitectureRig {
  let anchor: Entity
  let normalizationRoot: Entity
  let visualRoot: Entity
}

@MainActor
protocol FounderGarageArchitectureAdapter: AnyObject {
  var source: FounderGarageArchitectureSource { get }
  var rig: FounderGarageArchitectureRig { get }
  var normalization: FounderGarageArchitectureNormalization { get }
  var materialCount: Int { get }
}

@MainActor
final class ProceduralGarageArchitectureAdapter: FounderGarageArchitectureAdapter {
  let source = FounderGarageArchitectureSource.procedural
  let rig: FounderGarageArchitectureRig
  let normalization: FounderGarageArchitectureNormalization
  let materialCount: Int

  init(
    rig: FounderGarageArchitectureRig,
    bounds: FounderGarageArchitectureBounds,
    materialCount: Int
  ) {
    self.rig = rig
    self.materialCount = materialCount
    normalization = FounderGarageArchitectureNormalization(
      nativeBounds: bounds,
      targetBounds: bounds,
      uniformScale: 1,
      orientationCorrection: simd_quatf(angle: 0, axis: [0, 1, 0]),
      translationCorrection: .zero,
      resultingBounds: bounds
    )
  }
}

enum FounderGarageArchitectureAdapterError: Error, Equatable, LocalizedError {
  case unsupportedSource
  case invalidHierarchy
  case invalidBounds
  case incompatibleProportions
  case normalizedBoundsMismatch
  case nativeBoundsMismatch
  case floorMismatch
  case orientationMismatch
  case missingRequiredEntity(String)
  case productionAnchorCoordinateMismatch(String)
  case anchorMismatch

  var errorDescription: String? {
    switch self {
    case .unsupportedSource: "The requested Garage architecture source is unsupported."
    case .invalidHierarchy: "The Garage architecture contains no renderable model."
    case .invalidBounds: "The Garage architecture has invalid or empty bounds."
    case .incompatibleProportions: "The Garage architecture proportions do not match the spatial contract."
    case .normalizedBoundsMismatch: "The normalized Garage architecture does not satisfy the spatial contract."
    case .nativeBoundsMismatch: "The Garage architecture does not match the Facility Tier 0 native visual envelope."
    case .floorMismatch: "The Garage floor surface does not align to y = 0."
    case .orientationMismatch: "The Garage rear wall and doorway do not follow the -Z/+Z contract."
    case .missingRequiredEntity(let name): "The Garage architecture is missing required entity \(name)."
    case .productionAnchorCoordinateMismatch(let name): "The Garage architecture anchor \(name) does not match its production coordinate."
    case .anchorMismatch: "The Garage architecture adapter belongs to a different architecture anchor."
    }
  }
}

@MainActor
final class ImportedGarageArchitectureAdapter: FounderGarageArchitectureAdapter {
  let source: FounderGarageArchitectureSource
  let rig: FounderGarageArchitectureRig
  let normalization: FounderGarageArchitectureNormalization
  let materialCount: Int
  let renderableEntityCount: Int
  let preservedAnchorPositions: [String: SIMD3<Float>]
  let missingAnchorNames: Set<String>
  let usesAuthoredCutaway: Bool
  let resolvedAnchorMap: FacilityTier0ResolvedAnchorMap?
  let anchorMapResolutionCount: Int
  let layerRegistry: FacilityTier0LayerRegistry?
  let materialAudit: FacilityTier0MaterialAudit?
  let importedOccupiedBounds: FacilityTier0ImportedOccupiedBounds?

  init(
    source: FounderGarageArchitectureSource,
    loadedRoot: Entity,
    anchor: Entity,
    spatial: FounderGarageSpatialSpecification,
    descriptor: FounderGarageArchitectureAssetDescriptor
  ) throws {
    guard case .bundledProductionAsset = source else {
      throw FounderGarageArchitectureAdapterError.unsupportedSource
    }
    guard Self.containsRenderableModel(loadedRoot) else {
      throw FounderGarageArchitectureAdapterError.invalidHierarchy
    }

    for requiredName in descriptor.requiredEntityNames where loadedRoot.findEntity(named: requiredName) == nil {
      throw FounderGarageArchitectureAdapterError.missingRequiredEntity(requiredName)
    }

    let normalizationRoot = Entity()
    normalizationRoot.name = "GarageArchitecture.Normalization"
    normalizationRoot.orientation = descriptor.orientationCorrection
    normalizationRoot.addChild(loadedRoot)
    let measured = loadedRoot.visualBounds(relativeTo: normalizationRoot)
    let nativeBounds = FounderGarageArchitectureBounds(
      minimum: measured.min,
      maximum: measured.max
    )
    guard nativeBounds.size.x > 0,
          nativeBounds.size.y > 0,
          nativeBounds.size.z > 0 else {
      throw FounderGarageArchitectureAdapterError.invalidBounds
    }

    let targetBounds: FounderGarageArchitectureBounds
    let uniformScale: Float
    let translation: SIMD3<Float>
    switch descriptor.scalePolicy {
    case .uniformlyFitCanonicalInterior:
      targetBounds = .canonical(for: spatial)
      let axisScales = targetBounds.size / nativeBounds.size
      let smallestScale = min(axisScales.x, axisScales.y, axisScales.z)
      let largestScale = max(axisScales.x, axisScales.y, axisScales.z)
      guard (largestScale - smallestScale) / largestScale <= descriptor.maximumProportionVariance else {
        throw FounderGarageArchitectureAdapterError.incompatibleProportions
      }
      uniformScale = (axisScales.x + axisScales.y + axisScales.z) / 3
      translation = targetBounds.center - nativeBounds.center * uniformScale
    case .requireNativeBounds(let requiredBounds):
      targetBounds = requiredBounds
      guard nativeBounds.approximatelyMatches(requiredBounds, tolerance: descriptor.boundsTolerance) else {
        throw FounderGarageArchitectureAdapterError.nativeBoundsMismatch
      }
      uniformScale = 1
      translation = .zero
      guard let floor = loadedRoot.findEntity(named: descriptor.usesModernHierarchy ? "Floor" : "Floor_Slab"),
            abs(floor.visualBounds(relativeTo: normalizationRoot).max.y) <= descriptor.boundsTolerance else {
        throw FounderGarageArchitectureAdapterError.floorMismatch
      }
      guard let rearWall = loadedRoot.findEntity(named: descriptor.usesModernHierarchy ? "RearWall" : "Wall_Back"),
            let door = loadedRoot.findEntity(named: "Door"),
            rearWall.visualBounds(relativeTo: normalizationRoot).center.z < 0,
            door.visualBounds(relativeTo: normalizationRoot).center.z > 0 else {
        throw FounderGarageArchitectureAdapterError.orientationMismatch
      }
    }
    normalizationRoot.scale = .init(repeating: uniformScale)
    normalizationRoot.position = translation
    let resultingBounds = FounderGarageArchitectureBounds(
      minimum: nativeBounds.minimum * uniformScale + translation,
      maximum: nativeBounds.maximum * uniformScale + translation
    )
    guard resultingBounds.approximatelyMatches(
      targetBounds,
      tolerance: descriptor.boundsTolerance
    ) else {
      throw FounderGarageArchitectureAdapterError.normalizedBoundsMismatch
    }

    loadedRoot.name = loadedRoot.name.isEmpty ? "GarageArchitecture.ImportedVisual" : loadedRoot.name
    self.source = source
    rig = FounderGarageArchitectureRig(
      anchor: anchor,
      normalizationRoot: normalizationRoot,
      visualRoot: loadedRoot
    )
    normalization = FounderGarageArchitectureNormalization(
      nativeBounds: nativeBounds,
      targetBounds: targetBounds,
      uniformScale: uniformScale,
      orientationCorrection: descriptor.orientationCorrection,
      translationCorrection: translation,
      resultingBounds: resultingBounds
    )
    materialCount = Self.materialCount(in: loadedRoot)
    renderableEntityCount = Self.renderableEntityCount(in: loadedRoot)
    let expectedAnchors = spatial.productionAnchors?.namedPositions ?? [:]
    let requiresProductionContract: Bool
    switch descriptor.scalePolicy {
    case .requireNativeBounds:
      requiresProductionContract = true
    case .uniformlyFitCanonicalInterior:
      requiresProductionContract = false
    }
    if requiresProductionContract {
      let resolvedAnchorMap = try FacilityTier0ResolvedAnchorMap(root: loadedRoot)
      let resolvedPositions = resolvedAnchorMap.positions(relativeTo: loadedRoot)
      for (name, expectedPosition) in expectedAnchors {
        guard let resolvedPosition = resolvedPositions[name],
              simd_distance(resolvedPosition, expectedPosition) <= 0.001 else {
          throw FounderGarageArchitectureAdapterError.productionAnchorCoordinateMismatch(name)
        }
      }
      let layerRegistry = try FacilityTier0LayerRegistry(root: loadedRoot)
      let occupiedBounds = try Self.importedOccupiedBounds(
        in: loadedRoot,
        usesModernHierarchy: descriptor.usesModernHierarchy
      )
      guard occupiedBounds.all.allSatisfy({ spatial.room.interiorBounds.contains($0, margin: -0.03) }) else {
        throw FounderGarageArchitectureAdapterError.invalidBounds
      }
      self.resolvedAnchorMap = resolvedAnchorMap
      anchorMapResolutionCount = 1
      self.layerRegistry = layerRegistry
      materialAudit = FacilityTier0MaterialAudit(root: loadedRoot)
      importedOccupiedBounds = occupiedBounds
      preservedAnchorPositions = resolvedPositions
    } else {
      resolvedAnchorMap = nil
      anchorMapResolutionCount = 0
      layerRegistry = nil
      materialAudit = nil
      importedOccupiedBounds = nil
      preservedAnchorPositions = expectedAnchors.reduce(into: [:]) { result, expected in
        guard let entity = loadedRoot.findEntity(named: expected.key) else { return }
        result[expected.key] = entity.position(relativeTo: loadedRoot)
      }
    }
    missingAnchorNames = Set(expectedAnchors.keys).subtracting(preservedAnchorPositions.keys)
    if descriptor.isV4 || descriptor.isV6 || descriptor.isV7 {
      // Modern production assets ship as a complete enclosure. Camera-specific cutaway is applied by
      // FounderGarageRealityWorld without changing authoring visibility here.
      usesAuthoredCutaway = false
    } else {
      // Legacy production assets were authored for the isometric cutaway.
      loadedRoot.findEntity(named: "Wall_Right_Cutaway")?.isEnabled = false
      loadedRoot.findEntity(named: "Header_Beam")?.isEnabled = false
      loadedRoot.findEntity(named: "Door_Rolled")?.isEnabled = false
      loadedRoot.findEntity(named: "Track_Vert_R")?.isEnabled = false
      loadedRoot.findEntity(named: "Track_Horiz_R")?.isEnabled = false
      usesAuthoredCutaway = true
    }
    Self.removeInteractionComponents(from: loadedRoot)
    if descriptor.isV6 || descriptor.isV7 {
      // V6 contains USD-authored preview lights. The persistent RealityKit rig is
      // the sole runtime lighting authority so time presets remain deterministic.
      Self.removeAuthoredLightComponents(from: loadedRoot)
    }
  }

  private static func containsRenderableModel(_ entity: Entity) -> Bool {
    entity.components[ModelComponent.self] != nil
      || entity.children.contains(where: containsRenderableModel)
  }

  private static func materialCount(in entity: Entity) -> Int {
    let localCount = entity.components[ModelComponent.self]?.materials.count ?? 0
    return localCount + entity.children.reduce(0) { $0 + materialCount(in: $1) }
  }

  private static func renderableEntityCount(in entity: Entity) -> Int {
    let localCount = entity.components[ModelComponent.self] == nil ? 0 : 1
    return localCount + entity.children.reduce(0) { $0 + renderableEntityCount(in: $1) }
  }

  private static func importedOccupiedBounds(
    in root: Entity, usesModernHierarchy: Bool
  ) throws -> FacilityTier0ImportedOccupiedBounds {
    if usesModernHierarchy {
      func bounds(_ name: String) throws -> FounderGaragePlanarBounds {
        guard let entity = root.findEntity(named: name) else { throw FounderGarageArchitectureAdapterError.missingRequiredEntity(name) }
        let b = entity.visualBounds(relativeTo: root)
        return FounderGaragePlanarBounds(center: [b.center.x, b.center.z], size: [b.extents.x, b.extents.z])
      }
      return FacilityTier0ImportedOccupiedBounds(founderDesk: try bounds("FounderDesk"), chair: try bounds("FounderChair"), frontBayDesk: try bounds("FrontBayDesk"), shelving: try bounds("Shelf_Main"))
    }
    return FacilityTier0ImportedOccupiedBounds(
      founderDesk: try planarBounds(forNamePrefix: "Desk_", in: root),
      chair: try planarBounds(forNamePrefix: "Chair_", in: root),
      frontBayDesk: try planarBounds(forNamePrefix: "AgentDesk_", in: root),
      shelving: try planarBounds(forNamePrefix: "Shelf_", in: root)
    )
  }

  private static func planarBounds(
    forNamePrefix prefix: String,
    in root: Entity
  ) throws -> FounderGaragePlanarBounds {
    let matches = descendants(including: root).filter {
      $0.name.hasPrefix(prefix) && $0.components[ModelComponent.self] != nil
    }
    guard !matches.isEmpty else {
      throw FounderGarageArchitectureAdapterError.missingRequiredEntity(prefix)
    }
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for entity in matches {
      let bounds = entity.visualBounds(relativeTo: root)
      minimum = simd_min(minimum, bounds.min)
      maximum = simd_max(maximum, bounds.max)
    }
    return FounderGaragePlanarBounds(
      center: [(minimum.x + maximum.x) / 2, (minimum.z + maximum.z) / 2],
      size: [maximum.x - minimum.x, maximum.z - minimum.z]
    )
  }

  private static func descendants(including entity: Entity) -> [Entity] {
    [entity] + entity.children.flatMap { descendants(including: $0) }
  }

  private static func removeInteractionComponents(from entity: Entity) {
    entity.components.remove(InputTargetComponent.self)
    entity.components.remove(CollisionComponent.self)
    entity.components.remove(PhysicsBodyComponent.self)
    for child in entity.children {
      removeInteractionComponents(from: child)
    }
  }

  private static func removeAuthoredLightComponents(from entity: Entity) {
    entity.components.remove(DirectionalLightComponent.self)
    entity.components.remove(PointLightComponent.self)
    entity.components.remove(SpotLightComponent.self)
    entity.components.remove(ImageBasedLightComponent.self)
    entity.components.remove(ImageBasedLightReceiverComponent.self)
    for child in entity.children {
      removeAuthoredLightComponents(from: child)
    }
  }
}

@MainActor
protocol FounderGarageArchitectureLoading {
  func load(_ source: FounderGarageArchitectureSource) async throws -> Entity
}

/// The package hash binds the audited Y-up stage, unchanged geometry and textures.
enum FounderGarageV7AssetContract {
  static let resourceName = "founder_garage_v7"
  static let packageSHA256 = "1d1a831f75212a5d378cfa73c5cd32c0d2d94d82db45854f7f7a3fcb75fcf25e"
  static let upAxis = "Y"
  static let metersPerUnit: Float = 1
  static let defaultPrim = "root"

  enum ValidationError: Error { case missingPackage, integrityMismatch }

  static func validatePackage(_ data: Data) throws {
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == packageSHA256 else { throw ValidationError.integrityMismatch }
  }
}

@MainActor
struct RealityKitFounderGarageArchitectureLoader: FounderGarageArchitectureLoading {
  let bundle: Bundle

  init(bundle: Bundle = .main) {
    self.bundle = bundle
  }

  func load(_ source: FounderGarageArchitectureSource) async throws -> Entity {
    guard case .bundledProductionAsset(let name) = source else {
      throw FounderGarageArchitectureAdapterError.unsupportedSource
    }
    if name == FounderGarageV7AssetContract.resourceName {
      guard let url = bundle.url(forResource: name, withExtension: "usdz") else {
        throw FounderGarageV7AssetContract.ValidationError.missingPackage
      }
      try FounderGarageV7AssetContract.validatePackage(Data(contentsOf: url))
    }
    return try await Entity(named: name, in: bundle)
  }
}

enum FounderGarageArchitectureLoadState: Equatable {
  case notRequested
  case loading(FounderGarageArchitectureSource)
  case ready(FounderGarageArchitectureSource)
  case failed(FounderGarageArchitectureSource, message: String)
}

struct FounderGarageArchitectureLoadDiagnostics: Equatable {
  fileprivate(set) var requestCount = 0
  fileprivate(set) var loaderInvocationCount = 0
  fileprivate(set) var duplicateRequestCount = 0
  fileprivate(set) var successfulInstallationCount = 0
  fileprivate(set) var failedLoadCount = 0
  fileprivate(set) var staleResultCount = 0
}

struct FacilityTier0LightingRigContract: Equatable {
  enum Kind: Equatable {
    case directional
    case point
  }

  struct Light: Equatable {
    let kind: Kind
    let anchorName: String
    let position: SIMD3<Float>
    let target: SIMD3<Float>?
    let baseIntensity: Float
    let attenuationRadius: Float?
  }

  let doorwayKey: Light
  let hangingFill: Light
  let hangingPractical: Light
  let deskPractical: Light

  init?(spatial: FounderGarageSpatialSpecification) {
    guard let anchors = spatial.productionAnchors else { return nil }
    doorwayKey = Light(
      kind: .directional,
      anchorName: "Anchor_VFX_DoorLight",
      position: anchors.doorLightVFX,
      target: [0.95, 0.82, -1.05],
      baseIntensity: 5_600,
      attenuationRadius: nil
    )
    hangingFill = Light(
      kind: .point,
      anchorName: "Anchor_Light_Hanging_02",
      position: anchors.hangingLights[1],
      target: nil,
      baseIntensity: 450,
      attenuationRadius: 6
    )
    hangingPractical = Light(
      kind: .point,
      anchorName: "Anchor_Light_Hanging_01",
      position: anchors.hangingLights[0],
      target: nil,
      baseIntensity: 320,
      attenuationRadius: 4.5
    )
    deskPractical = Light(
      kind: .point,
      anchorName: "Anchor_Light_DeskLamp",
      position: anchors.deskLamp,
      target: nil,
      baseIntensity: 180,
      attenuationRadius: 2.2
    )
  }
}

@MainActor
struct FounderGarageEntityRegistry {
  let root: Entity
  let environment: Entity
  let furniture: Entity
  let desk: Entity
  let chair: Entity
  let founderAnchor: Entity
  let devices: Entity
  let founderComputer: Entity
  let founderComputerInteractionTarget: ModelEntity
  let iPhone: ModelEntity
  let iPad: ModelEntity
  let signalTV: ModelEntity
  let fundingBoard: ModelEntity
  let garageDoor: Entity
  let cameraRig: Entity
  let camera: PerspectiveCamera
  let lighting: Entity
  let keyLight: DirectionalLight
  let fillLight: PointLight
  let hangingPracticalLight: PointLight
  let deskPracticalLight: PointLight

  var identitySnapshot: FounderGarageEntityIdentitySnapshot {
    FounderGarageEntityIdentitySnapshot(
      root: root.id,
      architectureRoot: environment.id,
      founderAnchor: founderAnchor.id,
      founderComputer: founderComputer.id,
      founderComputerInteractionTarget: founderComputerInteractionTarget.id,
      iPhone: iPhone.id,
      iPad: iPad.id,
      signalTV: signalTV.id,
      fundingBoard: fundingBoard.id,
      garageDoor: garageDoor.id,
      camera: camera.id,
      keyLight: keyLight.id,
      fillLight: fillLight.id,
      hangingPracticalLight: hangingPracticalLight.id,
      deskPracticalLight: deskPracticalLight.id
    )
  }

  func validateIntegrity() -> Bool {
    let structuralIDs: [Entity.ID] = [
      root.id, environment.id, furniture.id, desk.id, chair.id, founderAnchor.id,
      devices.id, founderComputer.id
    ]
    let deviceIDs: [Entity.ID] = [
      founderComputerInteractionTarget.id, iPhone.id, iPad.id, signalTV.id, fundingBoard.id,
      garageDoor.id
    ]
    let renderingIDs: [Entity.ID] = [
      cameraRig.id, camera.id, lighting.id, keyLight.id, fillLight.id,
      hangingPracticalLight.id, deskPracticalLight.id
    ]
    let registeredIDs = structuralIDs + deviceIDs + renderingIDs
    return Set(registeredIDs).count == registeredIDs.count
      && environment.parent === root
      && furniture.parent === root
      && desk.parent === furniture
      && chair.parent === furniture
      && founderAnchor.parent === root
      && devices.parent === root
      && founderComputer.parent === devices
      && founderComputerInteractionTarget.parent === founderComputer
      && iPhone.parent === devices
      && iPad.parent === devices
      && signalTV.parent === devices
      && fundingBoard.parent === devices
      && garageDoor.parent === environment
      && cameraRig.parent === root
      && camera.parent === cameraRig
      && lighting.parent === root
      && keyLight.parent === lighting
      && fillLight.parent === lighting
      && hangingPracticalLight.parent === lighting
      && deskPracticalLight.parent === lighting
  }
}

struct FounderGarageEntityIdentitySnapshot: Equatable {
  let root: Entity.ID
  let architectureRoot: Entity.ID
  let founderAnchor: Entity.ID
  let founderComputer: Entity.ID
  let founderComputerInteractionTarget: Entity.ID
  let iPhone: Entity.ID
  let iPad: Entity.ID
  let signalTV: Entity.ID
  let fundingBoard: Entity.ID
  let garageDoor: Entity.ID
  let camera: Entity.ID
  let keyLight: Entity.ID
  let fillLight: Entity.ID
  let hangingPracticalLight: Entity.ID
  let deskPracticalLight: Entity.ID
}

@MainActor
private struct FounderGarageDoorAnimationElement {
  let entity: Entity
  let closedTransform: Transform
  let openTransform: Transform
}

enum ProceduralFounderPresentationMaterial: Equatable {
  case jacket
  case review
  case lowEnergy
  case stressed
}

enum ProceduralFounderPresentationTiming: Equatable {
  case easeInOut
}

/// A presentation intent is asset-neutral. Concrete visual adapters decide how to render it.
struct FounderPresentationIntent: Equatable {
  let state: FounderPresentationState
  let reduceMotion: Bool

  static func supported(
    state: FounderPresentationState,
    reduceMotion: Bool
  ) -> FounderPresentationIntent? {
    switch state {
    case .seatedIdle, .typing, .reviewing, .lowEnergy, .stressed:
      FounderPresentationIntent(state: state, reduceMotion: reduceMotion)
    case .standing, .walking, .interacting:
      nil
    }
  }
}

/// Pass 4's placeholder transforms are one procedural implementation, not universal state meaning.
struct ProceduralFounderPresentationRecipe {
  let state: FounderPresentationState
  let torsoTransform: Transform
  let headTransform: Transform
  let material: ProceduralFounderPresentationMaterial
  let duration: TimeInterval
  let timing: ProceduralFounderPresentationTiming

  static func recipe(for state: FounderPresentationState) -> ProceduralFounderPresentationRecipe? {
    switch state {
    case .seatedIdle:
      make(
        state: state,
        torsoPosition: [0, 1.12, 0],
        torsoPitch: 0,
        headPosition: [0, 1.68, 0],
        headPitch: 0,
        material: .jacket,
        duration: 0.24
      )
    case .typing:
      make(
        state: state,
        torsoPosition: [0, 1.10, -0.035],
        torsoPitch: -0.08,
        headPosition: [0, 1.65, -0.055],
        headPitch: -0.10,
        material: .jacket,
        duration: 0.22
      )
    case .reviewing:
      make(
        state: state,
        torsoPosition: [0, 1.14, -0.015],
        torsoPitch: -0.025,
        headPosition: [0, 1.70, -0.035],
        headPitch: -0.055,
        material: .review,
        duration: 0.26
      )
    case .lowEnergy:
      make(
        state: state,
        torsoPosition: [0, 1.06, 0.025],
        torsoPitch: 0.12,
        headPosition: [0, 1.60, 0.045],
        headPitch: 0.16,
        material: .lowEnergy,
        duration: 0.30
      )
    case .stressed:
      make(
        state: state,
        torsoPosition: [0, 1.115, -0.025],
        torsoPitch: -0.06,
        headPosition: [0, 1.67, -0.04],
        headPitch: -0.08,
        material: .stressed,
        duration: 0.18
      )
    case .standing, .walking, .interacting:
      nil
    }
  }

  private static func make(
    state: FounderPresentationState,
    torsoPosition: SIMD3<Float>,
    torsoPitch: Float,
    headPosition: SIMD3<Float>,
    headPitch: Float,
    material: ProceduralFounderPresentationMaterial,
    duration: TimeInterval
  ) -> ProceduralFounderPresentationRecipe {
    ProceduralFounderPresentationRecipe(
      state: state,
      torsoTransform: transform(position: torsoPosition, pitch: torsoPitch),
      headTransform: transform(position: headPosition, pitch: headPitch),
      material: material,
      duration: duration,
      timing: .easeInOut
    )
  }

  private static func transform(position: SIMD3<Float>, pitch: Float) -> Transform {
    Transform(
      scale: .one,
      rotation: simd_quatf(angle: pitch, axis: [1, 0, 0]),
      translation: position
    )
  }
}

enum FounderVisualSource: Hashable, Sendable {
  case procedural
  case bundledUSDZ(name: String)
}

struct FounderVisualNormalization {
  let transform: Transform

  static var identity: FounderVisualNormalization {
    FounderVisualNormalization(transform: .identity)
  }
}

struct FounderAssetRigDescriptor {
  let bodyPath: [String]
  let headPath: [String]?
  let normalization: FounderVisualNormalization
}

struct FounderVisualCapabilities: Equatable {
  let hasBodyTarget: Bool
  let hasHeadTarget: Bool
  let availableAnimationCount: Int
}

struct FounderPresentationRig {
  let anchor: Entity
  let normalizationRoot: Entity
  let visualRoot: Entity
  let bodyTarget: Entity
  let headTarget: Entity?

  var identitySnapshot: FounderPresentationTargetIdentitySnapshot {
    FounderPresentationTargetIdentitySnapshot(
      founderAnchor: anchor.id,
      normalizationRoot: normalizationRoot.id,
      visualRoot: visualRoot.id,
      body: bodyTarget.id,
      head: headTarget?.id
    )
  }
}

struct FounderVisualPresentationOutcome: Equatable {
  let interruptedPresentation: Bool
}

@MainActor
protocol FounderVisualAdapter: AnyObject {
  var source: FounderVisualSource { get }
  var rig: FounderPresentationRig { get }
  var capabilities: FounderVisualCapabilities { get }

  func present(_ intent: FounderPresentationIntent) -> FounderVisualPresentationOutcome
  func cancelActivePresentation()
}

/// Reference implementation that preserves the Pass 4 procedural appearance and transitions.
@MainActor
final class ProceduralFounderVisualAdapter: FounderVisualAdapter {
  let source = FounderVisualSource.procedural
  let rig: FounderPresentationRig
  let capabilities = FounderVisualCapabilities(
    hasBodyTarget: true,
    hasHeadTarget: true,
    availableAnimationCount: 0
  )

  private let torso: ModelEntity
  private let head: ModelEntity
  private let materials: [ProceduralFounderPresentationMaterial: SimpleMaterial]
  private var torsoPlayback: AnimationPlaybackController?
  private var headPlayback: AnimationPlaybackController?
  private var currentMaterial: ProceduralFounderPresentationMaterial = .jacket
  private(set) var presentationCount = 0
  private(set) var lastIntent: FounderPresentationIntent?

  init(
    anchor: Entity,
    normalizationRoot: Entity,
    visualRoot: Entity,
    torso: ModelEntity,
    head: ModelEntity
  ) {
    self.torso = torso
    self.head = head
    rig = FounderPresentationRig(
      anchor: anchor,
      normalizationRoot: normalizationRoot,
      visualRoot: visualRoot,
      bodyTarget: torso,
      headTarget: head
    )
    materials = [
      .jacket: Self.material(.founderJacket),
      .review: Self.material(.founderReview),
      .lowEnergy: Self.material(.founderLowEnergy),
      .stressed: Self.material(.founderStressed)
    ]
  }

  func present(_ intent: FounderPresentationIntent) -> FounderVisualPresentationOutcome {
    guard let recipe = ProceduralFounderPresentationRecipe.recipe(for: intent.state) else {
      return FounderVisualPresentationOutcome(interruptedPresentation: false)
    }

    let interrupted = hasActivePresentation
    cancelActivePresentation()

    if intent.reduceMotion {
      torso.move(to: recipe.torsoTransform, relativeTo: rig.anchor)
      head.move(to: recipe.headTransform, relativeTo: rig.anchor)
    } else {
      let timingFunction: AnimationTimingFunction = switch recipe.timing {
      case .easeInOut: .easeInOut
      }
      torsoPlayback = torso.move(
        to: recipe.torsoTransform,
        relativeTo: rig.anchor,
        duration: recipe.duration,
        timingFunction: timingFunction
      )
      headPlayback = head.move(
        to: recipe.headTransform,
        relativeTo: rig.anchor,
        duration: recipe.duration,
        timingFunction: timingFunction
      )
    }

    if recipe.material != currentMaterial, let material = materials[recipe.material] {
      torso.model?.materials = [material]
      currentMaterial = recipe.material
    }
    presentationCount += 1
    lastIntent = intent
    return FounderVisualPresentationOutcome(interruptedPresentation: interrupted)
  }

  func cancelActivePresentation() {
    torsoPlayback?.stop()
    headPlayback?.stop()
    torsoPlayback = nil
    headPlayback = nil
  }

  private var hasActivePresentation: Bool {
    torsoPlayback?.isPlaying == true || headPlayback?.isPlaying == true
  }

  private static func material(_ color: UIColor) -> SimpleMaterial {
    SimpleMaterial(color: color, roughness: .float(0.64), isMetallic: false)
  }
}

enum FounderAssetAdapterError: Error, Equatable, LocalizedError {
  case invalidHierarchy
  case missingBodyTarget(path: [String])
  case anchorMismatch
  case unsupportedSource

  var errorDescription: String? {
    switch self {
    case .invalidHierarchy:
      "The loaded Founder hierarchy contains no renderable model."
    case .missingBodyTarget(let path):
      "The Founder body target could not be resolved at \(path.joined(separator: "/"))."
    case .anchorMismatch:
      "The Founder visual adapter was created for a different anchor."
    case .unsupportedSource:
      "The requested Founder visual source cannot be loaded as a bundled entity."
    }
  }
}

/// Adapts one already-loaded imported hierarchy. Resolution and traversal happen once at init.
@MainActor
final class USDZFounderVisualAdapter: FounderVisualAdapter {
  let source: FounderVisualSource
  let rig: FounderPresentationRig
  let capabilities: FounderVisualCapabilities
  private(set) var presentationCount = 0
  private(set) var lastIntent: FounderPresentationIntent?

  init(
    source: FounderVisualSource,
    loadedRoot: Entity,
    anchor: Entity,
    descriptor: FounderAssetRigDescriptor
  ) throws {
    guard case .bundledUSDZ = source else {
      throw FounderAssetAdapterError.unsupportedSource
    }
    guard Self.containsRenderableModel(loadedRoot) else {
      throw FounderAssetAdapterError.invalidHierarchy
    }
    guard let body = Self.resolve(path: descriptor.bodyPath, from: loadedRoot),
          Self.containsRenderableModel(body) else {
      throw FounderAssetAdapterError.missingBodyTarget(path: descriptor.bodyPath)
    }

    let head = descriptor.headPath.flatMap { Self.resolve(path: $0, from: loadedRoot) }
    let normalizationRoot = Entity()
    normalizationRoot.name = "Founder.CharacterNormalization"
    normalizationRoot.transform = descriptor.normalization.transform
    normalizationRoot.addChild(loadedRoot)

    self.source = source
    rig = FounderPresentationRig(
      anchor: anchor,
      normalizationRoot: normalizationRoot,
      visualRoot: loadedRoot,
      bodyTarget: body,
      headTarget: head
    )
    capabilities = FounderVisualCapabilities(
      hasBodyTarget: true,
      hasHeadTarget: head != nil,
      availableAnimationCount: Self.animationCount(in: loadedRoot)
    )
  }

  func present(_ intent: FounderPresentationIntent) -> FounderVisualPresentationOutcome {
    // Pass 5 records asset-neutral intent. A real asset pass will map inspected clips or rig behavior.
    presentationCount += 1
    lastIntent = intent
    return FounderVisualPresentationOutcome(interruptedPresentation: false)
  }

  func cancelActivePresentation() {}

  private static func resolve(path: [String], from root: Entity) -> Entity? {
    path.reduce(Optional(root)) { current, component in
      current?.children.first { $0.name == component }
    }
  }

  private static func containsRenderableModel(_ entity: Entity) -> Bool {
    entity.components[ModelComponent.self] != nil
      || entity.children.contains(where: containsRenderableModel)
  }

  private static func animationCount(in entity: Entity) -> Int {
    entity.availableAnimations.count
      + entity.children.reduce(0) { $0 + animationCount(in: $1) }
  }
}

@MainActor
protocol FounderAssetLoading {
  func load(_ source: FounderVisualSource) async throws -> Entity
}

@MainActor
struct RealityKitFounderAssetLoader: FounderAssetLoading {
  let bundle: Bundle

  init(bundle: Bundle = .main) {
    self.bundle = bundle
  }

  func load(_ source: FounderVisualSource) async throws -> Entity {
    guard case .bundledUSDZ(let name) = source else {
      throw FounderAssetAdapterError.unsupportedSource
    }
    return try await Entity(named: name, in: bundle)
  }
}

enum FounderAssetLoadState: Equatable {
  case notRequested
  case loading(FounderVisualSource)
  case ready(FounderVisualSource)
  case failed(FounderVisualSource, message: String)
}

struct FounderAssetLoadDiagnostics: Equatable {
  fileprivate(set) var requestCount = 0
  fileprivate(set) var loaderInvocationCount = 0
  fileprivate(set) var duplicateRequestCount = 0
  fileprivate(set) var successfulInstallationCount = 0
  fileprivate(set) var failedLoadCount = 0
  fileprivate(set) var staleResultCount = 0
}

struct FounderPresentationControllerDiagnostics: Equatable {
  fileprivate(set) var requestCount = 0
  fileprivate(set) var applicationCount = 0
  fileprivate(set) var redundantRequestCount = 0
  fileprivate(set) var interruptedTransitionCount = 0
  fileprivate(set) var unsupportedRequestCount = 0
  fileprivate(set) var adapterInstallationCount = 0
  fileprivate(set) var lastRequestedState: FounderPresentationState?
  fileprivate(set) var lastAppliedState: FounderPresentationState?
  fileprivate(set) var lastUsedReduceMotion = false
}

/// Converts derived presentation state into local visual changes on the persistent Founder entities.
/// It owns no simulation state and never replaces entities in the Garage registry.
@MainActor
final class FounderPresentationController {
  private var visualAdapter: any FounderVisualAdapter
  private(set) var diagnostics = FounderPresentationControllerDiagnostics()

  init(visualAdapter: any FounderVisualAdapter) {
    self.visualAdapter = visualAdapter
  }

  var targetIdentitySnapshot: FounderPresentationTargetIdentitySnapshot {
    visualAdapter.rig.identitySnapshot
  }

  var visualCapabilities: FounderVisualCapabilities {
    visualAdapter.capabilities
  }

  func install(visualAdapter: any FounderVisualAdapter) throws {
    guard visualAdapter.rig.anchor.id == self.visualAdapter.rig.anchor.id else {
      throw FounderAssetAdapterError.anchorMismatch
    }
    self.visualAdapter.cancelActivePresentation()
    self.visualAdapter = visualAdapter
    diagnostics.adapterInstallationCount += 1

    if let state = diagnostics.lastRequestedState,
       let intent = FounderPresentationIntent.supported(
         state: state,
         reduceMotion: diagnostics.lastUsedReduceMotion
       ) {
      apply(intent)
    }
  }

  func transition(to state: FounderPresentationState, reduceMotion: Bool) {
    diagnostics.requestCount += 1
    let previousState = diagnostics.lastRequestedState
    let previousReduceMotion = diagnostics.lastUsedReduceMotion
    diagnostics.lastRequestedState = state
    diagnostics.lastUsedReduceMotion = reduceMotion

    guard let intent = FounderPresentationIntent.supported(
      state: state,
      reduceMotion: reduceMotion
    ) else {
      diagnostics.unsupportedRequestCount += 1
      return
    }

    if previousState == state {
      guard reduceMotion && !previousReduceMotion else {
        diagnostics.redundantRequestCount += 1
        return
      }
    }

    apply(intent)
  }

  private func apply(_ intent: FounderPresentationIntent) {
    let outcome = visualAdapter.present(intent)
    if outcome.interruptedPresentation {
      diagnostics.interruptedTransitionCount += 1
    }
    diagnostics.applicationCount += 1
    diagnostics.lastAppliedState = intent.state
  }
}

struct FounderPresentationTargetIdentitySnapshot: Equatable {
  let founderAnchor: Entity.ID
  let normalizationRoot: Entity.ID
  let visualRoot: Entity.ID
  let body: Entity.ID
  let head: Entity.ID?
}

struct FounderGarageRealityDiagnostics: Equatable {
  fileprivate(set) var constructionCount = 1
  fileprivate(set) var attachmentCount = 0
  fileprivate(set) var presentationApplicationCount = 0
  fileprivate(set) var subscriptionInstallationCount = 0
}

@MainActor
private struct FounderGarageBuiltWorld {
  let entities: FounderGarageEntityRegistry
  let proceduralArchitecture: ProceduralGarageArchitectureAdapter
  let proceduralFounder: ProceduralFounderVisualAdapter
}

/// Owns one stable procedural Garage world for one active SwiftUI presentation session.
/// Canonical game state stays outside this presentation-only runtime object.
@MainActor
@Observable
final class FounderGarageRealityWorld {
  let entities: FounderGarageEntityRegistry
  let spatialSpecification: FounderGarageSpatialSpecification
  let cameraController: FounderGarageCameraController
  let founderPresentationController: FounderPresentationController
  let proceduralFounderVisualAdapter: ProceduralFounderVisualAdapter
  let proceduralGarageArchitectureAdapter: ProceduralGarageArchitectureAdapter
  let facilityTier0LightingContract: FacilityTier0LightingRigContract?

  @ObservationIgnored private(set) var diagnostics = FounderGarageRealityDiagnostics()
  @ObservationIgnored private(set) var assetLoadState = FounderAssetLoadState.notRequested
  @ObservationIgnored private(set) var assetLoadDiagnostics = FounderAssetLoadDiagnostics()
  @ObservationIgnored private(set) var activeFounderVisualAdapter: any FounderVisualAdapter
  @ObservationIgnored private(set) var activeGarageArchitectureAdapter: any FounderGarageArchitectureAdapter
  private(set) var architectureLoadState = FounderGarageArchitectureLoadState.notRequested
  private(set) var garageDoorState = FounderGarageDoorState.closed
  let exteriorPracticalLight = PointLight()
  let environmentLight = Entity()
  private var environmentResource: EnvironmentResource?
  private(set) var environmentTimeState = FounderEnvironmentLightingConfiguration.defaultState
  @ObservationIgnored private(set) var architectureLoadDiagnostics = FounderGarageArchitectureLoadDiagnostics()
  private let quality: FounderGarageRealityQuality
  @ObservationIgnored private var lastPresentation: FounderWorldPresentationModel?
  @ObservationIgnored private var lastReduceMotion = false
  @ObservationIgnored private var accessibilityActivationSubscription: EventSubscription?
  @ObservationIgnored private var requestedVisualSource = FounderVisualSource.procedural
  @ObservationIgnored private var assetLoadGeneration = 0
  @ObservationIgnored private var assetLoadTask: Task<Void, Never>?
  @ObservationIgnored private var requestedArchitectureSource = FounderGarageArchitectureSource.procedural
  @ObservationIgnored private var architectureLoadGeneration = 0
  @ObservationIgnored private var architectureLoadTask: Task<Void, Never>?
  @ObservationIgnored private var garageDoorAnimationElements: [FounderGarageDoorAnimationElement] = []
  @ObservationIgnored private var garageDoorAnimationPlaybacks: [AnimationPlaybackController] = []

  init(
    quality: FounderGarageRealityQuality = .medium,
    spatialSpecification: FounderGarageSpatialSpecification = .standard
  ) {
    self.quality = quality
    self.spatialSpecification = spatialSpecification
    precondition(
      spatialSpecification.validationFailures.isEmpty,
      "Invalid Founder Garage spatial specification: \(spatialSpecification.validationFailures.joined(separator: ", "))"
    )
    let lightingContract = FacilityTier0LightingRigContract(spatial: spatialSpecification)
    facilityTier0LightingContract = lightingContract
    let built = Self.buildWorld(spatialSpecification, lightingContract: lightingContract)
    entities = built.entities
    entities.founderAnchor.isEnabled = false
    cameraController = FounderGarageCameraController(camera: built.entities.camera, spatial: spatialSpecification)
    proceduralGarageArchitectureAdapter = built.proceduralArchitecture
    activeGarageArchitectureAdapter = built.proceduralArchitecture
    architectureLoadState = .ready(.procedural)
    proceduralFounderVisualAdapter = built.proceduralFounder
    activeFounderVisualAdapter = built.proceduralFounder
    founderPresentationController = FounderPresentationController(visualAdapter: built.proceduralFounder)
    precondition(built.entities.validateIntegrity(), "Founder Garage entity registry is incomplete")
  }

  deinit {
    assetLoadTask?.cancel()
    architectureLoadTask?.cancel()
    accessibilityActivationSubscription?.cancel()
  }

  func attachRoot(using add: (Entity) -> Void) {
    add(entities.root)
    diagnostics.attachmentCount += 1
  }

  func apply(_ presentation: FounderWorldPresentationModel, reduceMotion: Bool = false) {
    guard presentation != lastPresentation || reduceMotion != lastReduceMotion else { return }
    diagnostics.presentationApplicationCount += 1
    cameraController.transition(to: presentation.cameraState, reduceMotion: reduceMotion)
    applyRuntimeEnclosureVisibility(for: presentation.cameraState)
    entities.founderComputerInteractionTarget.isEnabled = presentation.founderComputerAvailable && presentation.cameraState.allowsComputer

    if lastPresentation?.computerGlowIntensity != presentation.computerGlowIntensity {
      let glow = Float(presentation.computerGlowIntensity)
      let isImportedWorkstation = activeGarageArchitectureAdapter.source != .procedural
      entities.founderComputerInteractionTarget.model?.materials = [Self.material(
        UIColor(
          red: 0.04,
          green: 0.38 + CGFloat(glow) * 0.24,
          blue: 0.56 + CGFloat(glow) * 0.24,
          alpha: isImportedWorkstation ? 0.001 : 1
        ),
        roughness: 0.16,
        metallic: true
      )]
    }

    if lastPresentation?.founderState != presentation.founderState || reduceMotion != lastReduceMotion {
      founderPresentationController.transition(
        to: presentation.founderState,
        reduceMotion: reduceMotion
      )
    }

    if lastPresentation?.roomLightIntensity != presentation.roomLightIntensity {
      updateRoomLighting(for: presentation.roomLightIntensity)
    }

    lastPresentation = presentation
    lastReduceMotion = reduceMotion
  }

  func interaction(for entity: Entity) -> FounderWorldInteraction? {
    guard cameraController.state.allowsComputer, entities.founderComputerInteractionTarget.isEnabled else { return nil }
    var candidate: Entity? = entity
    while let current = candidate {
      if current.id == entities.founderComputerInteractionTarget.id {
        return .openFounderComputer
      }
      candidate = current.parent
    }
    return nil
  }

  func replaceAccessibilityActivationSubscription(_ subscription: EventSubscription) {
    accessibilityActivationSubscription?.cancel()
    accessibilityActivationSubscription = subscription
    diagnostics.subscriptionInstallationCount += 1
  }

  var activeAccessibilitySubscriptionCount: Int {
    accessibilityActivationSubscription == nil ? 0 : 1
  }

  var effectiveOccupiedBounds: [FounderGaragePlanarBounds] {
    if let imported = (activeGarageArchitectureAdapter as? ImportedGarageArchitectureAdapter)?.importedOccupiedBounds {
      return imported.all.map { $0.expanded(by: 0.08) }
    }
    return spatialSpecification.walkableRegion.exclusions
  }

  func isPointInsideFacility(_ point: SIMD2<Float>, margin: Float = 0) -> Bool {
    spatialSpecification.isPointInsideFacility(point, margin: margin)
  }

  func isPointInsideOccupiedZone(_ point: SIMD2<Float>) -> Bool {
    effectiveOccupiedBounds.contains { $0.contains(point) }
  }

  func isPointWalkable(_ point: SIMD2<Float>) -> Bool {
    isPointInsideFacility(point) && !isPointInsideOccupiedZone(point)
  }

  @discardableResult
  func requestGarageArchitecture(
    _ source: FounderGarageArchitectureSource,
    descriptor: FounderGarageArchitectureAssetDescriptor = .canonicalAxes
  ) -> Task<Void, Never>? {
    requestGarageArchitecture(
      source,
      descriptor: descriptor,
      loader: RealityKitFounderGarageArchitectureLoader()
    )
  }

  @discardableResult
  func requestGarageArchitecture(
    _ source: FounderGarageArchitectureSource,
    descriptor: FounderGarageArchitectureAssetDescriptor,
    loader: any FounderGarageArchitectureLoading
  ) -> Task<Void, Never>? {
    architectureLoadDiagnostics.requestCount += 1

    guard case .bundledProductionAsset = source else {
      restoreProceduralGarageArchitecture()
      return nil
    }
    if requestedArchitectureSource == source {
      switch architectureLoadState {
      case .loading, .ready:
        architectureLoadDiagnostics.duplicateRequestCount += 1
        return architectureLoadTask
      case .notRequested, .failed:
        break
      }
    }

    architectureLoadTask?.cancel()
    architectureLoadGeneration += 1
    let generation = architectureLoadGeneration
    requestedArchitectureSource = source
    architectureLoadState = .loading(source)
    architectureLoadDiagnostics.loaderInvocationCount += 1

    let task = Task { @MainActor [weak self] in
      do {
        let loadedRoot = try await loader.load(source)
        guard let self else { return }
        guard !Task.isCancelled,
              generation == self.architectureLoadGeneration,
              source == self.requestedArchitectureSource else {
          self.architectureLoadDiagnostics.staleResultCount += 1
          return
        }
        do {
          let adapter = try ImportedGarageArchitectureAdapter(
            source: source,
            loadedRoot: loadedRoot,
            anchor: self.entities.environment,
            spatial: self.spatialSpecification,
            descriptor: descriptor
          )
          try self.installGarageArchitectureAdapter(adapter)
          self.architectureLoadState = .ready(source)
          self.architectureLoadDiagnostics.successfulInstallationCount += 1
        } catch {
          self.recordGarageArchitectureFailure(error, source: source)
        }
      } catch {
        guard let self else { return }
        guard !Task.isCancelled,
              generation == self.architectureLoadGeneration,
              source == self.requestedArchitectureSource else {
          self.architectureLoadDiagnostics.staleResultCount += 1
          return
        }
        self.recordGarageArchitectureFailure(error, source: source)
      }
    }
    architectureLoadTask = task
    return task
  }

  func installGarageArchitectureAdapter(
    _ adapter: any FounderGarageArchitectureAdapter
  ) throws {
    guard adapter.rig.anchor.id == entities.environment.id else {
      throw FounderGarageArchitectureAdapterError.anchorMismatch
    }
    activeGarageArchitectureAdapter.rig.normalizationRoot.removeFromParent()
    entities.environment.addChild(adapter.rig.normalizationRoot)
    activeGarageArchitectureAdapter = adapter
    cameraController.usesV7ExteriorViews = adapter.source == .bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName)
    configureGarageDoorAnimation()
    configureExteriorPracticalLight()
    try configureEnvironmentLight()
    cameraController.alignFounderMonitorTowardSeatedEye(in: adapter.rig.visualRoot)
    cameraController.cacheDisplayFrame(in: adapter.rig.visualRoot)
    applyRuntimeEnclosureVisibility(for: cameraController.state)
    setProceduralEnvironmentVisible(adapter.source == .procedural)
    updateRoomLighting(for: lastPresentation?.roomLightIntensity ?? 1)
  }

  func restoreProceduralGarageArchitecture() {
    architectureLoadTask?.cancel()
    architectureLoadTask = nil
    architectureLoadGeneration += 1
    requestedArchitectureSource = .procedural
    guard activeGarageArchitectureAdapter.source != .procedural else {
      architectureLoadState = .ready(.procedural)
      return
    }
    try? installGarageArchitectureAdapter(proceduralGarageArchitectureAdapter)
    architectureLoadState = .ready(.procedural)
  }

  var garageDoorControlAvailable: Bool {
    activeArchitectureSupportsSectionalDoor && garageDoorAnimationElements.count == 6
  }

  private var activeArchitectureSupportsSectionalDoor: Bool {
    switch activeGarageArchitectureAdapter.source {
    case .bundledProductionAsset(name: "founder_garage_v4"),
         .bundledProductionAsset(name: "founder_garage_v6"),
         .bundledProductionAsset(name: "founder_garage_v7"):
      true
    default:
      false
    }
  }

  /// Moves the five authored door sections along their shared vertical-to-overhead
  /// contract. The handle follows section 02; the frame and tracks stay static.
  func setGarageDoor(_ state: FounderGarageDoorState, reduceMotion: Bool) {
    guard garageDoorControlAvailable, state != garageDoorState else { return }
    garageDoorAnimationPlaybacks.forEach { $0.stop() }
    garageDoorAnimationPlaybacks.removeAll(keepingCapacity: true)

    for element in garageDoorAnimationElements {
      let target = state.isOpen ? element.openTransform : element.closedTransform
      if reduceMotion {
        element.entity.move(to: target, relativeTo: element.entity.parent)
      } else {
        garageDoorAnimationPlaybacks.append(element.entity.move(
          to: target,
          relativeTo: element.entity.parent,
          duration: 1.2,
          timingFunction: .easeInOut
        ))
      }
    }
    garageDoorState = state
  }

  func toggleGarageDoor(reduceMotion: Bool) {
    setGarageDoor(garageDoorState.isOpen ? .closed : .open, reduceMotion: reduceMotion)
  }

  func setEnvironmentTimeState(
    _ state: FounderEnvironmentTimeState,
    reduceMotion _: Bool
  ) {
    guard state != environmentTimeState else { return }
    environmentTimeState = state
    updateRoomLighting(for: lastPresentation?.roomLightIntensity ?? 1)
  }

  private func recordGarageArchitectureFailure(
    _ error: Error,
    source: FounderGarageArchitectureSource
  ) {
    let message = String(String(describing: error).prefix(240))
    if activeGarageArchitectureAdapter.source != .procedural {
      try? installGarageArchitectureAdapter(proceduralGarageArchitectureAdapter)
    }
    architectureLoadState = .failed(source, message: message)
    architectureLoadDiagnostics.failedLoadCount += 1
  }

  private func setProceduralEnvironmentVisible(_ isVisible: Bool) {
    entities.furniture.isEnabled = isVisible
    entities.iPhone.isEnabled = isVisible
    entities.iPad.isEnabled = isVisible
    entities.signalTV.isEnabled = isVisible
    entities.fundingBoard.isEnabled = isVisible
    for child in entities.founderComputer.children
      where child.id != entities.founderComputerInteractionTarget.id {
      child.isEnabled = isVisible
    }
    let alpha: CGFloat = isVisible ? 1 : 0.001
    entities.founderComputerInteractionTarget.model?.materials = [Self.material(
      UIColor(red: 0.04, green: 0.54, blue: 0.74, alpha: alpha),
      roughness: 0.18,
      metallic: true
    )]
  }

  private func configureGarageDoorAnimation() {
    garageDoorAnimationPlaybacks.forEach { $0.stop() }
    garageDoorAnimationPlaybacks.removeAll()
    garageDoorAnimationElements.removeAll()
    garageDoorState = .closed

    guard activeArchitectureSupportsSectionalDoor else {
      return
    }
    let root = activeGarageArchitectureAdapter.rig.visualRoot
    guard let panel = root.findEntity(named: "GarageDoor_Panel") else { return }

    for index in 1...5 {
      guard let section = panel.findEntity(named: String(format: "GarageDoor_Section_%02d", index)) else {
        garageDoorAnimationElements.removeAll()
        return
      }
      let closed = section.transform
      var open = closed
      open.translation = [closed.translation.x, 2.455, closed.translation.y - 2.65]
      open.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
      garageDoorAnimationElements.append(.init(
        entity: section,
        closedTransform: closed,
        openTransform: open
      ))
    }

    guard let handle = panel.findEntity(named: "GarageDoor_Handle") else {
      garageDoorAnimationElements.removeAll()
      return
    }
    let closedHandle = handle.transform
    var openHandle = closedHandle
    openHandle.translation = [closedHandle.translation.x, 2.405, 0.704 - 2.65]
    openHandle.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    garageDoorAnimationElements.append(.init(
      entity: handle,
      closedTransform: closedHandle,
      openTransform: openHandle
    ))
  }

  /// Modern production worlds are fully enclosed for Founder POV and every in-room camera. The authored
  /// overview remains readable by hiding only the two surfaces between its
  /// exterior isometric anchor and the room; all door structure stays visible.
  func applyRuntimeEnclosureVisibility(for cameraState: FounderGarageCameraState) {
    guard activeArchitectureSupportsSectionalDoor else {
      return
    }
    let root = activeGarageArchitectureAdapter.rig.visualRoot
    let usesOverviewCutaway = cameraState == .garageOverview
    root.findEntity(named: "Garage_RightWall")?.isEnabled = !usesOverviewCutaway
    root.findEntity(named: "Ceiling")?.isEnabled = !usesOverviewCutaway
  }

  private func configureEnvironmentLight() throws {
    environmentLight.removeFromParent()
    guard activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName) else { return }
    if environmentResource == nil {
      // A neutral, uniform source keeps the engine's default IBL from overriding
      // the authored time preset. Generate once per world, never per frame/state.
      let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 16)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
      }
      if let cgImage = image.cgImage {
        environmentResource = try EnvironmentResource(equirectangular: cgImage)
      }
    }
    guard let environmentResource else { return }
    environmentLight.name = "FounderEnvironmentLight"
    environmentLight.components.set(ImageBasedLightComponent(source: .single(environmentResource)))
    entities.root.addChild(environmentLight)
    activeGarageArchitectureAdapter.rig.visualRoot.components.set(
      ImageBasedLightReceiverComponent(imageBasedLight: environmentLight)
    )
  }

  private func configureExteriorPracticalLight() {
    exteriorPracticalLight.removeFromParent()
    exteriorPracticalLight.isEnabled = false
    guard activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName),
          let lens = activeGarageArchitectureAdapter.rig.visualRoot.findEntity(
            named: FounderEnvironmentLightingConfiguration.exteriorFixtureLensName
          ) else { return }
    exteriorPracticalLight.name = "ExteriorPracticalLight"
    exteriorPracticalLight.position = lens.visualBounds(relativeTo: entities.lighting).center
      + FounderEnvironmentLightingConfiguration.exteriorFixtureOffset
    exteriorPracticalLight.light.attenuationRadius = FounderEnvironmentLightingConfiguration.exteriorPracticalRadius
    entities.lighting.addChild(exteriorPracticalLight)
  }

  private func updateRoomLighting(for presentationIntensity: Double) {
    let usesProductionAsset = activeGarageArchitectureAdapter.source != .procedural
    let usesEnvironmentPresets = activeGarageArchitectureAdapter.source
      == .bundledProductionAsset(name: "founder_garage_v6")
      || activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: "founder_garage_v7")
    let preset = FounderEnvironmentLightingConfiguration.preset(for: environmentTimeState)
    let keyBase = usesEnvironmentPresets
      ? Double(preset.directionalIntensity)
      : usesProductionAsset ? Double(facilityTier0LightingContract?.doorwayKey.baseIntensity ?? 5_600) : 26_000.0
    let fillBase = usesEnvironmentPresets
      ? Double(preset.generalFillIntensity)
      : usesProductionAsset ? Double(facilityTier0LightingContract?.hangingFill.baseIntensity ?? 450) : 2_600.0
    let hangingBase = usesEnvironmentPresets
      ? Double(preset.hangingPracticalIntensity)
      : usesProductionAsset ? Double(facilityTier0LightingContract?.hangingPractical.baseIntensity ?? 320) : 0
    let deskBase = usesEnvironmentPresets
      ? Double(preset.deskPracticalIntensity)
      : usesProductionAsset ? Double(facilityTier0LightingContract?.deskPractical.baseIntensity ?? 180) : 0
    if usesEnvironmentPresets {
      entities.keyLight.look(
        at: preset.directionalTarget,
        from: preset.directionalPosition,
        relativeTo: nil
      )
      entities.keyLight.light.color = Self.color(preset.directionalColor)
      entities.fillLight.light.color = Self.color(preset.generalFillColor)
      entities.hangingPracticalLight.light.color = Self.color(preset.practicalColor)
      entities.deskPracticalLight.light.color = Self.color(preset.practicalColor)
    }
    if var environment = environmentLight.components[ImageBasedLightComponent.self] {
      environment.intensityExponent = preset.environmentIntensityExponent
      environmentLight.components.set(environment)
    }
    exteriorPracticalLight.light.color = Self.color(preset.practicalColor)
    exteriorPracticalLight.light.intensity = preset.exteriorPracticalIntensity * quality.lightScale
    exteriorPracticalLight.isEnabled = exteriorPracticalLight.parent != nil && preset.exteriorPracticalIntensity > 0
    entities.keyLight.light.intensity = Float(keyBase * presentationIntensity) * quality.lightScale
    entities.fillLight.light.intensity = Float(fillBase * presentationIntensity) * quality.lightScale
    entities.hangingPracticalLight.light.intensity = Float(hangingBase * presentationIntensity) * quality.lightScale
    entities.deskPracticalLight.light.intensity = Float(deskBase * presentationIntensity) * quality.lightScale
  }

  private static func color(_ components: SIMD3<Float>) -> UIColor {
    UIColor(
      red: CGFloat(components.x),
      green: CGFloat(components.y),
      blue: CGFloat(components.z),
      alpha: 1
    )
  }

  @discardableResult
  func requestFounderVisual(
    _ source: FounderVisualSource,
    descriptor: FounderAssetRigDescriptor
  ) -> Task<Void, Never>? {
    requestFounderVisual(
      source,
      descriptor: descriptor,
      loader: RealityKitFounderAssetLoader()
    )
  }

  @discardableResult
  func requestFounderVisual(
    _ source: FounderVisualSource,
    descriptor: FounderAssetRigDescriptor,
    loader: any FounderAssetLoading
  ) -> Task<Void, Never>? {
    assetLoadDiagnostics.requestCount += 1

    guard case .bundledUSDZ = source else {
      restoreProceduralFounder()
      return nil
    }

    if requestedVisualSource == source {
      switch assetLoadState {
      case .loading, .ready:
        assetLoadDiagnostics.duplicateRequestCount += 1
        return assetLoadTask
      case .notRequested, .failed:
        break
      }
    }

    assetLoadTask?.cancel()
    assetLoadGeneration += 1
    let generation = assetLoadGeneration
    requestedVisualSource = source
    assetLoadState = .loading(source)
    assetLoadDiagnostics.loaderInvocationCount += 1

    let task = Task { @MainActor [weak self] in
      do {
        let loadedRoot = try await loader.load(source)
        guard let self else { return }
        guard !Task.isCancelled,
              generation == self.assetLoadGeneration,
              source == self.requestedVisualSource else {
          self.assetLoadDiagnostics.staleResultCount += 1
          return
        }
        do {
          let adapter = try USDZFounderVisualAdapter(
            source: source,
            loadedRoot: loadedRoot,
            anchor: self.entities.founderAnchor,
            descriptor: descriptor
          )
          try self.installFounderVisualAdapter(adapter)
          self.assetLoadState = .ready(source)
          self.assetLoadDiagnostics.successfulInstallationCount += 1
        } catch {
          self.recordAssetLoadFailure(error, source: source)
        }
      } catch {
        guard let self else { return }
        guard !Task.isCancelled,
              generation == self.assetLoadGeneration,
              source == self.requestedVisualSource else {
          self.assetLoadDiagnostics.staleResultCount += 1
          return
        }
        self.recordAssetLoadFailure(error, source: source)
      }
    }
    assetLoadTask = task
    return task
  }

  func installFounderVisualAdapter(_ adapter: any FounderVisualAdapter) throws {
    guard adapter.rig.anchor.id == entities.founderAnchor.id else {
      throw FounderAssetAdapterError.anchorMismatch
    }

    activeFounderVisualAdapter.cancelActivePresentation()
    activeFounderVisualAdapter.rig.normalizationRoot.removeFromParent()
    entities.founderAnchor.addChild(adapter.rig.normalizationRoot)
    try founderPresentationController.install(visualAdapter: adapter)
    activeFounderVisualAdapter = adapter
  }

  func restoreProceduralFounder() {
    assetLoadTask?.cancel()
    assetLoadTask = nil
    assetLoadGeneration += 1
    requestedVisualSource = .procedural

    guard activeFounderVisualAdapter.source != .procedural else {
      assetLoadState = .ready(.procedural)
      return
    }
    try? installFounderVisualAdapter(proceduralFounderVisualAdapter)
    assetLoadState = .ready(.procedural)
  }

  private func recordAssetLoadFailure(_ error: Error, source: FounderVisualSource) {
    let message = String(String(describing: error).prefix(240))
    if activeFounderVisualAdapter.source != .procedural {
      try? installFounderVisualAdapter(proceduralFounderVisualAdapter)
    }
    assetLoadState = .failed(source, message: message)
    assetLoadDiagnostics.failedLoadCount += 1
  }

  private static func buildWorld(
    _ spatial: FounderGarageSpatialSpecification,
    lightingContract: FacilityTier0LightingRigContract?
  ) -> FounderGarageBuiltWorld {
    let root = Entity()
    root.name = "FounderGarageRoot"

    let environment = Entity()
    environment.name = "Environment"
    root.addChild(environment)
    let garageDoor = Entity()
    garageDoor.name = "GarageDoorAnchor"
    garageDoor.transform = spatial.architecture.garageDoor.transform
    environment.addChild(garageDoor)

    let architectureNormalizationRoot = Entity()
    architectureNormalizationRoot.name = "GarageArchitecture.Normalization"
    let architectureVisualRoot = Entity()
    architectureVisualRoot.name = "GarageArchitecture.ProceduralVisual"
    architectureNormalizationRoot.addChild(architectureVisualRoot)
    environment.addChild(architectureNormalizationRoot)

    addBox(
      name: "Architecture.FloorSlab",
      size: [spatial.room.width, spatial.room.floorThickness, spatial.room.depth],
      position: spatial.architecture.floor.position,
      color: .garageFloor,
      roughness: 0.88,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.FloorFinish",
      size: [spatial.room.width - 0.08, 0.012, spatial.room.depth - 0.08],
      position: [0, -0.006, 0],
      color: .garageFloorFinish,
      roughness: 0.72,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.RearWall.Structure",
      size: [spatial.room.width, spatial.room.wallHeight, spatial.room.wallThickness],
      position: spatial.architecture.rearWall.position,
      color: .garageWall,
      roughness: 0.82,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.RearWall.InteriorFinish",
      size: [spatial.room.width - spatial.room.wallThickness * 2, spatial.room.wallHeight - 0.12, 0.025],
      position: [0, spatial.room.wallHeight / 2, spatial.architecture.rearWall.position.z + spatial.room.wallThickness / 2 + 0.0125],
      color: .garageWallFinish,
      roughness: 0.76,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.LeftWall.Structure",
      size: [spatial.room.wallThickness, spatial.room.wallHeight, spatial.room.depth],
      position: spatial.architecture.leftWall.position,
      color: .garageSideWall,
      roughness: 0.86,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.LeftWall.InteriorFinish",
      size: [0.025, spatial.room.wallHeight - 0.12, spatial.room.depth - spatial.room.wallThickness * 2],
      position: [spatial.architecture.leftWall.position.x + spatial.room.wallThickness / 2 + 0.0125, spatial.room.wallHeight / 2, 0],
      color: .garageWallFinish,
      roughness: 0.76,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.RightWall.Structure",
      size: [spatial.room.wallThickness, spatial.room.wallHeight, spatial.room.depth],
      position: spatial.architecture.rightWall.position,
      color: .garageSideWall,
      roughness: 0.86,
      to: architectureVisualRoot
    )
    addBox(
      name: "Architecture.RightWall.InteriorFinish",
      size: [0.025, spatial.room.wallHeight - 0.12, spatial.room.depth - spatial.room.wallThickness * 2],
      position: [spatial.architecture.rightWall.position.x - spatial.room.wallThickness / 2 - 0.0125, spatial.room.wallHeight / 2, 0],
      color: .garageWallFinish,
      roughness: 0.76,
      to: architectureVisualRoot
    )
    // The camera-facing ceiling is an intentional cinematic cutaway. Perimeter
    // panels and joists communicate the roof volume without blocking the fixed key light.
    let ceilingPanelWidth: Float = 0.90
    let ceilingPanelX = spatial.room.width / 2 - spatial.room.wallThickness - ceilingPanelWidth / 2
    for (name, x) in [("Left", -ceilingPanelX), ("Right", ceilingPanelX)] {
      addBox(
        name: "Architecture.Ceiling.\(name)Panel",
        size: [ceilingPanelWidth, 0.08, spatial.room.depth - 0.24],
        position: [x, spatial.room.ceilingHeight - 0.04, 0],
        color: .garageCeiling,
        roughness: 0.80,
        to: architectureVisualRoot
      )
    }
    addBox(
      name: "Architecture.CeilingBeam",
      size: spatial.ceilingBeamSize,
      position: spatial.architecture.ceilingBeam.position,
      color: .garageMetal,
      roughness: 0.42,
      metallic: true,
      to: architectureVisualRoot
    )
    for (index, z) in [-2.25, -0.75, 0.75, 2.25].enumerated() {
      addBox(
        name: "Architecture.CeilingJoist.\(index)",
        size: [spatial.room.width - 0.30, 0.12, 0.10],
        position: [0, spatial.room.ceilingHeight - 0.13, Float(z)],
        color: .garageMetal,
        roughness: 0.48,
        metallic: true,
        to: architectureVisualRoot
      )
    }
    let cornerPostSize = SIMD3<Float>(0.18, spatial.room.wallHeight, 0.18)
    let cornerX = spatial.room.width / 2 - cornerPostSize.x / 2
    let cornerZ = spatial.room.depth / 2 - cornerPostSize.z / 2
    for (name, x, z) in [
      ("RearLeft", -cornerX, -cornerZ),
      ("RearRight", cornerX, -cornerZ),
      ("FrontLeft", -cornerX, cornerZ),
      ("FrontRight", cornerX, cornerZ)
    ] {
      addBox(
        name: "Architecture.CornerPost.\(name)",
        size: cornerPostSize,
        position: [x, spatial.room.wallHeight / 2, z],
        color: .garageMetal,
        roughness: 0.44,
        metallic: true,
        to: architectureVisualRoot
      )
    }

    let garageDoorFrame = Entity()
    garageDoorFrame.name = "Architecture.GarageDoorFrame"
    garageDoorFrame.transform = spatial.architecture.garageDoor.transform
    architectureVisualRoot.addChild(garageDoorFrame)
    let sideWidth = (spatial.room.width - spatial.room.doorOpeningWidth) / 2
    let jambOffset = spatial.room.doorOpeningWidth / 2 + sideWidth / 2
    addBox(
      name: "Architecture.GarageDoor.LeftJamb",
      size: [sideWidth, spatial.room.doorOpeningHeight, spatial.room.wallThickness],
      position: [-jambOffset, 0, 0],
      color: .garageSideWall,
      roughness: 0.86,
      to: garageDoorFrame
    )
    addBox(
      name: "Architecture.GarageDoor.RightJamb",
      size: [sideWidth, spatial.room.doorOpeningHeight, spatial.room.wallThickness],
      position: [jambOffset, 0, 0],
      color: .garageSideWall,
      roughness: 0.86,
      to: garageDoorFrame
    )
    let headerHeight = spatial.room.wallHeight - spatial.room.doorOpeningHeight
    addBox(
      name: "Architecture.GarageDoor.Header",
      size: [spatial.room.width, headerHeight, spatial.room.wallThickness],
      position: [0, spatial.room.doorOpeningHeight / 2 + headerHeight / 2, 0],
      color: .garageMetal,
      roughness: 0.42,
      metallic: true,
      to: garageDoorFrame
    )
    let doorTrimWidth: Float = 0.08
    let doorTrimDepth: Float = 0.10
    let doorTrimX = spatial.room.doorOpeningWidth / 2 + doorTrimWidth / 2
    addBox(name: "Architecture.GarageDoor.LeftCasing", size: [doorTrimWidth, spatial.room.doorOpeningHeight + doorTrimWidth, doorTrimDepth], position: [-doorTrimX, 0, -doorTrimDepth / 2], color: .garageDoorMetal, roughness: 0.30, metallic: true, to: garageDoorFrame)
    addBox(name: "Architecture.GarageDoor.RightCasing", size: [doorTrimWidth, spatial.room.doorOpeningHeight + doorTrimWidth, doorTrimDepth], position: [doorTrimX, 0, -doorTrimDepth / 2], color: .garageDoorMetal, roughness: 0.30, metallic: true, to: garageDoorFrame)
    addBox(name: "Architecture.GarageDoor.TopCasing", size: [spatial.room.doorOpeningWidth + doorTrimWidth * 2, doorTrimWidth, doorTrimDepth], position: [0, spatial.room.doorOpeningHeight / 2 + doorTrimWidth / 2, -doorTrimDepth / 2], color: .garageDoorMetal, roughness: 0.30, metallic: true, to: garageDoorFrame)
    let trackZ = -(spatial.room.depth - spatial.room.doorOpeningWidth) / 2
    addBox(name: "Architecture.GarageDoor.LeftTrack", size: [0.06, 0.08, spatial.room.depth - spatial.room.doorOpeningWidth], position: [-spatial.room.doorOpeningWidth / 2, spatial.room.doorOpeningHeight / 2 + 0.10, trackZ], color: .garageDoorMetal, roughness: 0.30, metallic: true, to: garageDoorFrame)
    addBox(name: "Architecture.GarageDoor.RightTrack", size: [0.06, 0.08, spatial.room.depth - spatial.room.doorOpeningWidth], position: [spatial.room.doorOpeningWidth / 2, spatial.room.doorOpeningHeight / 2 + 0.10, trackZ], color: .garageDoorMetal, roughness: 0.30, metallic: true, to: garageDoorFrame)
    let proceduralArchitecture = ProceduralGarageArchitectureAdapter(
      rig: FounderGarageArchitectureRig(
        anchor: environment,
        normalizationRoot: architectureNormalizationRoot,
        visualRoot: architectureVisualRoot
      ),
      bounds: .canonical(for: spatial),
      materialCount: 8
    )

    let furniture = Entity()
    furniture.name = "Furniture"
    root.addChild(furniture)
    let desk = Entity()
    desk.name = "Desk"
    desk.transform = spatial.anchors.desk.transform
    furniture.addChild(desk)
    let desktopCenterY = spatial.workstation.desktopCenterHeight
    addBox(name: "DeskTop", size: [spatial.workstation.deskSize.x, spatial.workstation.desktopThickness, spatial.workstation.deskSize.z], position: [0, desktopCenterY, 0], color: .deskWood, roughness: 0.54, to: desk)
    let legX = spatial.workstation.deskSize.x / 2 - spatial.workstation.legInset
    let legY = spatial.workstation.legSize.y / 2
    addBox(name: "DeskLeftLeg", size: spatial.workstation.legSize, position: [-legX, legY, 0], color: .garageMetal, roughness: 0.34, metallic: true, to: desk)
    addBox(name: "DeskRightLeg", size: spatial.workstation.legSize, position: [legX, legY, 0], color: .garageMetal, roughness: 0.34, metallic: true, to: desk)
    let chair = Entity()
    chair.name = "Chair"
    chair.transform = spatial.anchors.chair.transform
    furniture.addChild(chair)
    addBox(name: "ChairBack", size: spatial.workstation.chairBackSize, position: [0, spatial.workstation.chairSeatHeight + spatial.workstation.chairBackSize.y / 2, spatial.workstation.chairSeatSize.z / 2 - spatial.workstation.chairBackSize.z / 2], color: .chair, roughness: 0.72, to: chair)
    addBox(name: "ChairSeat", size: spatial.workstation.chairSeatSize, position: [0, spatial.workstation.chairSeatHeight, 0], color: .chair, roughness: 0.72, to: chair)

    let founderAnchor = Entity()
    founderAnchor.name = "FounderAnchor"
    founderAnchor.transform = spatial.anchors.founder.transform
    let founderNormalizationRoot = Entity()
    founderNormalizationRoot.name = "Founder.CharacterNormalization"
    let proceduralVisualRoot = Entity()
    proceduralVisualRoot.name = "Founder.ProceduralVisual"
    let founderTorso = ModelEntity(
      mesh: .generateBox(size: [0.42, 0.72, 0.28], cornerRadius: 0.12),
      materials: [material(.founderJacket, roughness: 0.64)]
    )
    founderTorso.name = "Founder.Torso"
    founderTorso.position = [0, 1.12, 0]
    let founderHead = ModelEntity(
      mesh: .generateSphere(radius: 0.18),
      materials: [material(.founderSkin, roughness: 0.78)]
    )
    founderHead.name = "Founder.Head"
    founderHead.position = [0, 1.68, 0]
    proceduralVisualRoot.addChild(founderTorso)
    proceduralVisualRoot.addChild(founderHead)
    founderNormalizationRoot.addChild(proceduralVisualRoot)
    founderAnchor.addChild(founderNormalizationRoot)
    root.addChild(founderAnchor)
    let proceduralFounder = ProceduralFounderVisualAdapter(
      anchor: founderAnchor,
      normalizationRoot: founderNormalizationRoot,
      visualRoot: proceduralVisualRoot,
      torso: founderTorso,
      head: founderHead
    )

    let devices = Entity()
    devices.name = "Devices"
    root.addChild(devices)
    let founderComputer = Entity()
    founderComputer.name = "FounderComputer"
    founderComputer.transform = spatial.anchors.founderComputer.transform
    devices.addChild(founderComputer)
    let usesProductionCoordinates = spatial.contractIdentity == .facilityTier0Production
    let monitorCenterY = usesProductionCoordinates
      ? 0
      : spatial.workstation.desktopSurfaceHeight + spatial.workstation.monitorBottomClearance + spatial.workstation.monitorSize.y / 2
    addBox(name: "FounderComputer.Frame", size: spatial.workstation.monitorSize, position: [0, monitorCenterY, 0], color: .computerFrame, roughness: 0.28, metallic: true, to: founderComputer)
    let founderComputerInteractionTarget = ModelEntity(
      mesh: .generateBox(size: spatial.workstation.monitorScreenSize),
      materials: [material(.computerScreen, roughness: 0.18, metallic: true)]
    )
    founderComputerInteractionTarget.name = FounderWorldInteractionAdapter.founderComputerEntityName
    founderComputerInteractionTarget.position = [
      0,
      monitorCenterY,
      usesProductionCoordinates
        ? 0.025
        : spatial.workstation.monitorSize.z / 2 + spatial.workstation.monitorScreenSize.z / 2
    ]
    founderComputerInteractionTarget.components.set(InputTargetComponent())
    founderComputerInteractionTarget.generateCollisionShapes(recursive: false)
    var computerAccessibility = AccessibilityComponent()
    computerAccessibility.isAccessibilityElement = true
    computerAccessibility.label = LocalizedStringResource(
      stringLiteral: FounderWorldInteractionAdapter.founderComputerAccessibilityLabel
    )
    computerAccessibility.traits = [.button]
    computerAccessibility.systemActions = [.activate]
    founderComputerInteractionTarget.components.set(computerAccessibility)
    founderComputer.addChild(founderComputerInteractionTarget)
    let baseCenterY = usesProductionCoordinates
      ? spatial.anchors.desk.position.y + spatial.workstation.desktopSurfaceHeight - spatial.anchors.founderComputer.position.y
        + spatial.workstation.monitorBaseSize.y / 2
      : spatial.workstation.desktopSurfaceHeight + spatial.workstation.monitorBaseSize.y / 2
    addBox(name: "FounderComputer.Stand", size: spatial.workstation.monitorStandSize, position: [0, baseCenterY + spatial.workstation.monitorStandSize.y / 2, 0], color: .computerFrame, roughness: 0.28, metallic: true, to: founderComputer)
    addBox(name: "FounderComputer.Base", size: spatial.workstation.monitorBaseSize, position: [0, baseCenterY, spatial.workstation.monitorBaseSize.z / 4], color: .computerFrame, roughness: 0.28, metallic: true, to: founderComputer)
    let iPhone = addBox(name: "iPhone", size: spatial.workstation.iPhoneSize, position: spatial.anchors.iPhone.position, color: .deviceGlass, roughness: 0.12, metallic: true, to: devices)
    let iPad = addBox(name: "iPad", size: spatial.workstation.iPadSize, position: spatial.anchors.iPad.position, color: .deviceGlass, roughness: 0.12, metallic: true, to: devices)
    let signalTV = addBox(name: "SignalTV", size: spatial.media.signalTV, position: spatial.anchors.signalTV.position, color: .signalTV, roughness: 0.20, metallic: true, to: devices)
    let fundingBoard = addBox(name: "FundingBoard", size: spatial.media.fundingBoard, position: spatial.anchors.fundingBoard.position, color: .fundingBoard, roughness: 0.86, to: devices)

    let cameraRig = Entity()
    cameraRig.name = "CameraRig"
    let camera = PerspectiveCamera()
    camera.name = "FounderGarageCamera"
    let home = FounderGarageCameraConfiguration(spatial: spatial).recipe(for: .founderPOV)
    camera.camera.fieldOfViewInDegrees = home.fieldOfView
    camera.transform = home.transform
    cameraRig.addChild(camera)
    root.addChild(cameraRig)

    let lighting = Entity()
    lighting.name = "Lighting"
    let keyLight = DirectionalLight()
    keyLight.name = "KeyLight"
    keyLight.look(
      at: lightingContract?.doorwayKey.target ?? spatial.anchors.keyLightTarget,
      from: lightingContract?.doorwayKey.position ?? spatial.anchors.keyLight.position,
      relativeTo: nil
    )
    keyLight.light.color = .garageKeyLight
    keyLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 12, depthBias: 1.5)
    lighting.addChild(keyLight)
    let fillLight = PointLight()
    fillLight.name = "FillLight"
    fillLight.position = lightingContract?.hangingFill.position ?? spatial.anchors.fillLight.position
    fillLight.light.color = .garageFillLight
    fillLight.light.attenuationRadius = lightingContract?.hangingFill.attenuationRadius ?? 8
    lighting.addChild(fillLight)
    let hangingPracticalLight = PointLight()
    hangingPracticalLight.name = "HangingPracticalLight"
    hangingPracticalLight.position = lightingContract?.hangingPractical.position ?? spatial.anchors.fillLight.position
    hangingPracticalLight.light.color = .garagePracticalLight
    hangingPracticalLight.light.attenuationRadius = lightingContract?.hangingPractical.attenuationRadius ?? 4.5
    lighting.addChild(hangingPracticalLight)
    let deskPracticalLight = PointLight()
    deskPracticalLight.name = "DeskPracticalLight"
    deskPracticalLight.position = lightingContract?.deskPractical.position ?? spatial.anchors.desk.position
    deskPracticalLight.light.color = .garageDeskPracticalLight
    deskPracticalLight.light.attenuationRadius = lightingContract?.deskPractical.attenuationRadius ?? 2.2
    lighting.addChild(deskPracticalLight)
    root.addChild(lighting)

    let registry = FounderGarageEntityRegistry(
      root: root,
      environment: environment,
      furniture: furniture,
      desk: desk,
      chair: chair,
      founderAnchor: founderAnchor,
      devices: devices,
      founderComputer: founderComputer,
      founderComputerInteractionTarget: founderComputerInteractionTarget,
      iPhone: iPhone,
      iPad: iPad,
      signalTV: signalTV,
      fundingBoard: fundingBoard,
      garageDoor: garageDoor,
      cameraRig: cameraRig,
      camera: camera,
      lighting: lighting,
      keyLight: keyLight,
      fillLight: fillLight,
      hangingPracticalLight: hangingPracticalLight,
      deskPracticalLight: deskPracticalLight
    )
    return FounderGarageBuiltWorld(
      entities: registry,
      proceduralArchitecture: proceduralArchitecture,
      proceduralFounder: proceduralFounder
    )
  }

  @discardableResult
  private static func addBox(
    name: String,
    size: SIMD3<Float>,
    position: SIMD3<Float>,
    color: UIColor,
    roughness: Float,
    metallic: Bool = false,
    to parent: Entity
  ) -> ModelEntity {
    let entity = ModelEntity(
      mesh: .generateBox(size: size),
      materials: [Self.material(color, roughness: roughness, metallic: metallic)]
    )
    entity.name = name
    entity.position = position
    parent.addChild(entity)
    return entity
  }

  private static func material(
    _ color: UIColor,
    roughness: Float,
    metallic: Bool = false
  ) -> SimpleMaterial {
    SimpleMaterial(color: color, roughness: .float(roughness), isMetallic: metallic)
  }
}

private extension UIColor {
  static let garageFloor = UIColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 1)
  static let garageFloorFinish = UIColor(red: 0.14, green: 0.145, blue: 0.15, alpha: 1)
  static let garageWall = UIColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 1)
  static let garageWallFinish = UIColor(red: 0.31, green: 0.34, blue: 0.38, alpha: 1)
  static let garageSideWall = UIColor(red: 0.075, green: 0.09, blue: 0.115, alpha: 1)
  static let garageCeiling = UIColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 1)
  static let garageDoorMetal = UIColor(red: 0.18, green: 0.21, blue: 0.24, alpha: 1)
  static let garageMetal = UIColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1)
  static let deskWood = UIColor(red: 0.31, green: 0.17, blue: 0.085, alpha: 1)
  static let chair = UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
  static let founderJacket = UIColor(red: 0.18, green: 0.30, blue: 0.42, alpha: 1)
  static let founderSkin = UIColor(red: 0.66, green: 0.48, blue: 0.36, alpha: 1)
  static let founderReview = UIColor(red: 0.50, green: 0.34, blue: 0.11, alpha: 1)
  static let founderLowEnergy = UIColor(red: 0.18, green: 0.22, blue: 0.27, alpha: 1)
  static let founderStressed = UIColor(red: 0.46, green: 0.16, blue: 0.13, alpha: 1)
  static let computerFrame = UIColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 1)
  static let computerScreen = UIColor(red: 0.04, green: 0.54, blue: 0.74, alpha: 1)
  static let deviceGlass = UIColor(red: 0.08, green: 0.26, blue: 0.34, alpha: 1)
  static let signalTV = UIColor(red: 0.12, green: 0.42, blue: 0.50, alpha: 1)
  static let fundingBoard = UIColor(red: 0.42, green: 0.26, blue: 0.14, alpha: 1)
  static let garageKeyLight = UIColor(red: 0.84, green: 0.90, blue: 1.0, alpha: 1)
  static let garageFillLight = UIColor(red: 0.20, green: 0.62, blue: 0.72, alpha: 1)
  static let garagePracticalLight = UIColor(red: 1.0, green: 0.78, blue: 0.52, alpha: 1)
  static let garageDeskPracticalLight = UIColor(red: 1.0, green: 0.70, blue: 0.40, alpha: 1)
}

struct FounderGarageCameraRecipe {
  let position: SIMD3<Float>
  let lookTarget: SIMD3<Float>
  let fieldOfView: Float
  let duration: TimeInterval

  @MainActor
  var transform: Transform {
    let pose = Entity()
    pose.look(at: lookTarget, from: position, relativeTo: nil)
    return pose.transform
  }
}

/// All offsets are relative to semantic anchors in the unchanged metre/Y-up contract.
struct FounderGarageCameraConfiguration {
  let spatial: FounderGarageSpatialSpecification
  var usesV7ExteriorViews = false
  static let transitionDuration: TimeInterval = 0.30
  static let seatedEyeOffset = SIMD3<Float>(0, 1.18, 0)
  static let seatedEyeHeight = seatedEyeOffset.y
  static let yawLimits: ClosedRange<Float> = (-80 * .pi / 180)...(80 * .pi / 180)
  // V3 is an open-ceiling cutaway; tighter vertical bounds keep authored
  // Garage context visible instead of filling the viewport with void or floor.
  static let pitchLimits: ClosedRange<Float> = (-18 * .pi / 180)...(12 * .pi / 180)
  static let dragSensitivityRadiansPerPoint: Float = .pi / 900

  var seatedPlayerState: FounderGaragePlayerSpatialState {
    let anchor = spatial.productionAnchors?.founderSeat ?? spatial.anchors.founder.position
    let facing = spatial.anchors.founder.facingDirection
    let heading = Float(atan2(Double(facing.x), Double(-facing.z)))
    return FounderGaragePlayerSpatialState(
      playerPose: FounderPlayerPose(position: anchor, heading: heading),
      eyeOffset: Self.seatedEyeOffset
    )
  }

  func clamped(_ orientation: FounderLookOrientation) -> FounderLookOrientation {
    FounderLookOrientation(
      yaw: min(max(orientation.yaw, Self.yawLimits.lowerBound), Self.yawLimits.upperBound),
      pitch: min(max(orientation.pitch, Self.pitchLimits.lowerBound), Self.pitchLimits.upperBound)
    )
  }

  func recipe(for view: FounderGarageCameraState) -> FounderGarageCameraRecipe {
    let a = spatial.productionAnchors
    let monitor = a?.monitorFace ?? spatial.anchors.founderComputer.position
    let eye = seatedPlayerState.eyePosition
    let board = a?.whiteboardFace ?? spatial.anchors.fundingBoard.position
    let bay = a?.agentDeskSurface ?? spatial.anchors.desk.position
    let door = a?.doorMouth ?? spatial.architecture.garageDoor.position
    let position: SIMD3<Float>
    let target: SIMD3<Float>
    let fov: Float
    switch view {
    case .founderPOV:
      position = eye; target = monitor; fov = 56
    case .garageOverview:
      // V7's separate RoofCap occludes the old elevated cutaway. Keep the same
      // wall/ceiling visibility rule and inspect from below the roof edge.
      position = usesV7ExteriorViews ? [7, 2.5, 9] : spatial.anchors.camera.position
      target = usesV7ExteriorViews ? [0, 1, 1.5] : spatial.anchors.cameraTarget
      fov = 62
    case .whiteboard:
      position = eye; target = board; fov = 52
    case .frontBay:
      position = eye; target = bay + SIMD3<Float>(0, 0.15, 0); fov = 58
    case .garageDoor:
      // V4's complete enclosure needs enough exterior distance to show both jambs,
      // the header, the closed sectional panel, and the preserved track hierarchy.
      position = usesV7ExteriorViews ? [0.2, 1.45, -2.2] : door + SIMD3<Float>(2.5, 1.10, 8.80)
      target = usesV7ExteriorViews ? [0, 1.1, 6] : door + SIMD3<Float>(0, 0.05, -0.05)
      fov = usesV7ExteriorViews ? 88 : 64
    case .front:
      position = door + SIMD3<Float>(0, 0.25, 9.45)
      target = door + SIMD3<Float>(0, 0.05, -0.05)
      fov = 64
    }
    return FounderGarageCameraRecipe(position: position, lookTarget: target, fieldOfView: fov, duration: Self.transitionDuration)
  }
}

/// Endpoints are installed under the bridge's interrupt-safe fade, avoiding travel through furniture.
@MainActor
final class FounderGarageCameraController {
  struct Diagnostics {
    var requestCount = 0
    var applicationCount = 0
    var interruptedCount = 0
    var freeLookApplicationCount = 0
    var recenterCount = 0
    var lastRequested: FounderGarageCameraState = .founderPOV
    var lastApplied: FounderGarageCameraState = .founderPOV
  }
  let camera: PerspectiveCamera
  let spatial: FounderGarageSpatialSpecification
  private(set) var state: FounderGarageCameraState = .founderPOV
  private(set) var playerSpatialState: FounderGaragePlayerSpatialState
  private(set) var diagnostics = Diagnostics()
  private var lastReducedMotion: Bool?
  var usesV7ExteriorViews = false
  private(set) var displayCorners: [SIMD3<Float>] = []

  init(camera: PerspectiveCamera, spatial: FounderGarageSpatialSpecification) {
    self.camera = camera
    self.spatial = spatial
    playerSpatialState = FounderGarageCameraConfiguration(spatial: spatial).seatedPlayerState
  }
  func recipe(for state: FounderGarageCameraState) -> FounderGarageCameraRecipe {
    let base = FounderGarageCameraConfiguration(spatial: spatial, usesV7ExteriorViews: usesV7ExteriorViews).recipe(for: state)
    guard state == .founderPOV, !displayCorners.isEmpty else { return base }
    var pose = base
    // Center the projected display rectangle, not merely its world-space anchor.
    // Perspective makes the nearer edge larger when viewed from the actual chair.
    for _ in 0..<4 {
      let matrix = pose.transform.matrix
      let right = SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
      let up = SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)
      let forward = -SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
      var low = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
      var high = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
      for corner in displayCorners {
        let offset = corner - base.position
        let depth = simd_dot(offset, forward)
        guard depth > 0.01 else { return base }
        let projected = SIMD2<Float>(simd_dot(offset, right), simd_dot(offset, up)) / depth
        low = simd_min(low, projected); high = simd_max(high, projected)
      }
      let center = (low + high) / 2
      let direction = simd_normalize(forward + right * center.x + up * center.y)
      pose = FounderGarageCameraRecipe(position: base.position, lookTarget: base.position + direction * simd_distance(base.position, base.lookTarget), fieldOfView: base.fieldOfView, duration: base.duration)
    }
    return pose
  }

  func cacheDisplayFrame(in root: Entity) {
    displayCorners = []
    if let display = root.findEntity(named: "Monitor_Display") {
      let bounds = display.visualBounds(relativeTo: display)
      for x in [bounds.min.x, bounds.max.x] {
        for y in [bounds.min.y, bounds.max.y] {
          for z in [bounds.min.z, bounds.max.z] {
            displayCorners.append(display.convert(position: [x, y, z], to: root))
          }
        }
      }
    }
    applyCurrentCameraTransform()
  }

  /// V3's monitor was authored square to the desk, which leaves the screen visibly
  /// oblique from the canonical Founder seat. Rotate only the monitor assembly around
  /// its own Y axis so the display normal points straight at the seated eye.
  @discardableResult
  func alignFounderMonitorTowardSeatedEye(in root: Entity) -> Bool {
    guard let monitor = root.findEntity(named: "FounderMonitor"),
          let display = monitor.findEntity(named: "Monitor_Display") else {
      return false
    }

    let displayBounds = display.visualBounds(relativeTo: display)
    for _ in 0..<4 {
      let displayCenter = display.convert(position: displayBounds.center, to: root)
      let localOrigin = display.convert(position: .zero, to: root)
      let localFrontPoint = display.convert(position: [0, 0, 1], to: root)
      var currentFront = localFrontPoint - localOrigin
      currentFront.y = 0
      var desiredFront = playerSpatialState.eyePosition - displayCenter
      desiredFront.y = 0
      guard simd_length_squared(currentFront) > 0.000_001,
            simd_length_squared(desiredFront) > 0.000_001 else {
        return false
      }
      currentFront = simd_normalize(currentFront)
      desiredFront = simd_normalize(desiredFront)
      let currentHeading = atan2(currentFront.x, currentFront.z)
      let desiredHeading = atan2(desiredFront.x, desiredFront.z)
      let correction = desiredHeading - currentHeading
      guard abs(correction) > 0.000_001 else { break }

      var monitorMatrix = monitor.transformMatrix(relativeTo: root)
      let rotation = simd_float4x4(simd_quatf(angle: correction, axis: [0, 1, 0]))
      monitorMatrix.columns.0 = rotation * monitorMatrix.columns.0
      monitorMatrix.columns.1 = rotation * monitorMatrix.columns.1
      monitorMatrix.columns.2 = rotation * monitorMatrix.columns.2
      monitor.setTransformMatrix(monitorMatrix, relativeTo: root)
    }
    return true
  }

  func setLookOrientation(_ requested: FounderLookOrientation) {
    guard state == .founderPOV, playerSpatialState.navigationMode == .seated else { return }
    playerSpatialState.lookOrientation = FounderGarageCameraConfiguration(spatial: spatial).clamped(requested)
    diagnostics.freeLookApplicationCount += 1
    applySeatedCameraTransform()
  }

  func recenterFounderPOV() {
    guard state == .founderPOV, playerSpatialState.navigationMode == .seated else { return }
    playerSpatialState.lookOrientation = .neutral
    diagnostics.recenterCount += 1
    applySeatedCameraTransform()
  }

  func transition(to requested: FounderGarageCameraState, reduceMotion: Bool) {
    diagnostics.requestCount += 1
    diagnostics.lastRequested = requested
    guard requested != state || lastReducedMotion == nil else { return }
    if requested == .founderPOV {
      playerSpatialState.navigationMode = .seated
      playerSpatialState.lookOrientation = .neutral
    } else {
      playerSpatialState.navigationMode = .authoredInspection(requested)
      playerSpatialState.lookOrientation = .neutral
    }
    state = requested
    lastReducedMotion = reduceMotion
    applyCurrentCameraTransform()
    diagnostics.applicationCount += 1
    diagnostics.lastApplied = requested
  }


  private func applyCurrentCameraTransform() {
    if state == .founderPOV {
      applySeatedCameraTransform()
    } else {
      let pose = recipe(for: state)
      camera.camera.fieldOfViewInDegrees = pose.fieldOfView
      camera.transform = pose.transform
    }
  }

  private func applySeatedCameraTransform() {
    let configuration = FounderGarageCameraConfiguration(spatial: spatial)
    let neutral = recipe(for: .founderPOV)
    let canonicalHeading = configuration.seatedPlayerState.playerPose.heading
    let bodyHeadingOffset = playerSpatialState.playerPose.heading - canonicalHeading
    let orientation = playerSpatialState.lookOrientation
    let yaw = simd_quatf(angle: bodyHeadingOffset + orientation.yaw, axis: [0, 1, 0])
    let pitch = simd_quatf(angle: orientation.pitch, axis: [1, 0, 0])
    var transform = neutral.transform
    transform.translation = playerSpatialState.eyePosition
    transform.rotation = simd_normalize(yaw * transform.rotation * pitch)
    camera.camera.fieldOfViewInDegrees = neutral.fieldOfView
    camera.transform = transform
  }
}
