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
    case chair
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
  let founderInteractionTarget: FounderInteractionTargetContract?
  let isEnabled: Bool

  init(
    id: String,
    semanticObject: SemanticObject,
    anchorName: String,
    object: FounderGarageSpatialPose,
    approach: FounderGarageSpatialPose,
    interactionDistance: FounderGarageInteractionDistance,
    activationBounds: FounderGarageSpatialBounds,
    founderInteractionTarget: FounderInteractionTargetContract? = nil,
    isEnabled: Bool
  ) {
    self.id = id
    self.semanticObject = semanticObject
    self.anchorName = anchorName
    self.object = object
    self.approach = approach
    self.interactionDistance = interactionDistance
    self.activationBounds = activationBounds
    self.founderInteractionTarget = founderInteractionTarget
    self.isEnabled = isEnabled
  }
}

enum FounderInteractionType: String, CaseIterable, Equatable, Sendable {
  case seat
  case seatedWorkstation
  case standingObservation
}

enum FounderInteractionPreferredHand: String, CaseIterable, Equatable, Sendable {
  case left
  case right
}

/// Immutable presentation input for a future interaction coordinator. It describes
/// authored endpoints only; it does not select targets, move the Founder, or drive animation.
struct FounderInteractionTargetContract: Equatable, Identifiable {
  let id: String
  let semanticObject: FacilityTier0InteractionZone.SemanticObject
  let interactionType: FounderInteractionType
  let approach: FounderGarageSpatialPose
  let interaction: FounderGarageSpatialPose
  let gazeTarget: SIMD3<Float>?
  let preferredHand: FounderInteractionPreferredHand?
  let handTarget: FounderGarageSpatialPose?
  let positionToleranceMeters: Float
  let facingToleranceRadians: Float

  var hasFiniteValues: Bool {
    let poses = [approach, interaction] + (handTarget.map { [$0] } ?? [])
    let poseValues = poses.flatMap { pose in
      [
        pose.position.x, pose.position.y, pose.position.z,
        pose.facingDirection.x, pose.facingDirection.y, pose.facingDirection.z
      ]
    }
    let gazeValues = gazeTarget.map { [$0.x, $0.y, $0.z] } ?? []
    return (poseValues + gazeValues + [positionToleranceMeters, facingToleranceRadians])
      .allSatisfy(\.isFinite)
  }
}

enum FounderInteractionPhase: String, CaseIterable, Equatable, Sendable {
  case idle
  case approaching
  case stopping
  case aligning
  case sitting
  case seated
  case standing
  case departing
  case recovering
}

struct FounderInteractionDiagnostics: Equatable, Sendable {
  fileprivate(set) var approachDistance: Float = 0
  fileprivate(set) var approachPositionError: Float = 0
  fileprivate(set) var approachYawError: Float = 0
  fileprivate(set) var stopVelocity: Float = 0
  fileprivate(set) var alignmentTranslation: Float = 0
  fileprivate(set) var alignmentRotation: Float = 0
  fileprivate(set) var sitDuration: Float = 0
  fileprivate(set) var seatEndpointError: Float = 0
  fileprivate(set) var standDuration: Float = 0
  fileprivate(set) var standingEndpointError: Float = 0
  fileprivate(set) var departTransitionTime: Float = 0
  fileprivate(set) var interruptRecoveryTime: Float = 0
  fileprivate(set) var cyclePositionDrift: Float = 0
  fileprivate(set) var cycleYawDrift: Float = 0
  fileprivate(set) var invalidTransformCount = 0
  fileprivate(set) var completedCycleCount = 0

  var deterministicSignature: String {
    String(
      format: "chair|d=%.4f|p=%.4f|y=%.4f|v=%.4f|at=%.4f|ar=%.4f|sit=%.4f|seat=%.4f|stand=%.4f|standing=%.4f|depart=%.4f|recover=%.4f|drift=%.4f,%.4f|invalid=%d|cycles=%d",
      approachDistance, approachPositionError, approachYawError, stopVelocity,
      alignmentTranslation, alignmentRotation, sitDuration, seatEndpointError,
      standDuration, standingEndpointError, departTransitionTime,
      interruptRecoveryTime, cyclePositionDrift, cycleYawDrift,
      invalidTransformCount, completedCycleCount
    )
  }
}

/// Session-only choreography for the first Pass C interaction. Navigation remains
/// camera-owned and visible motion remains locomotion-owned; this object only
/// sequences intent and checks the immutable chair contract at phase boundaries.
@MainActor
@Observable
final class FounderInteractionCoordinator {
  private(set) var phase = FounderInteractionPhase.idle
  private(set) var diagnostics = FounderInteractionDiagnostics()
  let chairTarget: FounderInteractionTargetContract?

  private var phaseElapsed: Float = 0
  private var pendingCancellation = false
  private var interruptionActive = false
  private var interruptionElapsed: Float = 0
  private var reduceMotion = false

  init(chairTarget: FounderInteractionTargetContract?) {
    precondition(chairTarget == nil || (
      chairTarget?.semanticObject == .chair
        && chairTarget?.interactionType == .seat
        && chairTarget?.hasFiniteValues == true
    ))
    self.chairTarget = chairTarget
  }

  @discardableResult
  func requestChairInteraction(
    camera: FounderGarageCameraController,
    reduceMotion: Bool
  ) -> Bool {
    guard let chairTarget,
          phase == .idle,
          camera.playerSpatialState.navigationMode == .walking
    else { return false }
    self.reduceMotion = reduceMotion
    pendingCancellation = false
    diagnostics.approachDistance = planarDistance(
      camera.playerSpatialState.playerPose.position,
      chairTarget.approach.position
    )
    diagnostics.alignmentTranslation = 0
    diagnostics.alignmentRotation = 0
    enter(.approaching)
    return true
  }

  @discardableResult
  func requestChairExit(
    camera: FounderGarageCameraController,
    reduceMotion: Bool
  ) -> Bool {
    guard let chairTarget, phase == .seated else { return false }
    self.reduceMotion = reduceMotion
    pendingCancellation = false
    guard camera.beginInteractionStanding(
      at: chairTarget.approach,
      reduceMotion: reduceMotion
    ) else {
      diagnostics.invalidTransformCount += 1
      enter(.recovering)
      return false
    }
    enter(.standing)
    return true
  }

  func cancel(camera: FounderGarageCameraController) {
    guard let chairTarget, phase != .idle && phase != .recovering else { return }
    interruptionActive = true
    interruptionElapsed = 0
    switch phase {
    case .sitting:
      pendingCancellation = true
    case .seated:
      pendingCancellation = true
      if camera.beginInteractionStanding(at: chairTarget.approach, reduceMotion: reduceMotion) {
        enter(.standing)
      } else {
        diagnostics.invalidTransformCount += 1
        enter(.recovering)
      }
    case .standing:
      pendingCancellation = true
    case .idle, .recovering:
      break
    default:
      camera.setMovementIntent(.idle)
      enter(.recovering)
    }
  }

  func prepareFrame(camera: FounderGarageCameraController, deltaTime rawDelta: TimeInterval) {
    guard let chairTarget else { return }
    let dt = boundedDelta(rawDelta)
    phaseElapsed += dt
    if interruptionActive { interruptionElapsed += dt }
    guard valuesAreFinite(camera.snapshot) else {
      diagnostics.invalidTransformCount += 1
      camera.setMovementIntent(.idle)
      enter(.recovering)
      return
    }
    switch phase {
    case .approaching:
      let snapshot = camera.snapshot
      let offset = planarOffset(from: snapshot.playerPosition, to: chairTarget.approach.position)
      let distance = simd_length(offset)
      let speed = simd_length(SIMD2<Float>(snapshot.velocity.x, snapshot.velocity.z))
      let brakingDistance = speed * speed / (2 * FounderGarageCameraConfiguration.linearDeceleration) + 0.012
      if distance <= max(brakingDistance, 0.018) {
        camera.setMovementIntent(.idle)
        enter(.stopping)
      } else {
        camera.setMovementIntent(localIntent(for: offset, heading: snapshot.bodyHeading))
      }
      if phaseElapsed > 12 {
        camera.setMovementIntent(.idle)
        enter(.recovering)
      }
    case .stopping, .sitting, .seated, .standing, .departing, .recovering:
      camera.setMovementIntent(.idle)
    case .aligning:
      camera.setMovementIntent(.idle)
      let result = camera.alignStandingPlayer(
        toward: chairTarget.approach,
        maximumTranslation: 0.42 * dt,
        maximumRotation: 2.4 * dt
      )
      diagnostics.alignmentTranslation += result.translation
      diagnostics.alignmentRotation += result.rotation
      if !result.valid {
        diagnostics.invalidTransformCount += 1
        enter(.recovering)
      }
    case .idle:
      break
    }
  }

  func completeFrame(
    camera: FounderGarageCameraController,
    locomotion: FounderLocomotionController
  ) {
    guard let chairTarget else { return }
    let snapshot = camera.snapshot
    let positionError = planarDistance(snapshot.playerPosition, chairTarget.approach.position)
    let targetHeading = heading(for: chairTarget.approach.facingDirection)
    let yawError = abs(shortestAngle(targetHeading - snapshot.bodyHeading))
    if phase == .approaching || phase == .stopping || phase == .aligning {
      diagnostics.approachPositionError = positionError
      diagnostics.approachYawError = yawError
    }

    switch phase {
    case .stopping:
      let speed = simd_length(SIMD2<Float>(snapshot.velocity.x, snapshot.velocity.z))
      if speed <= 0.01 {
        diagnostics.stopVelocity = speed
        if positionError <= chairTarget.positionToleranceMeters + 0.025 {
          enter(.aligning)
        } else {
          enter(.approaching)
        }
      }
    case .aligning:
      if positionError <= 0.0025,
         yawError <= 0.0025,
         locomotion.state == .standingIdle {
        camera.endWalking(reduceMotion: reduceMotion, keepFounderVisible: true)
        enter(.sitting)
      }
    case .sitting:
      if locomotion.state == .seatedIdle {
        camera.completeSeatingTransition()
        locomotion.enterFirstPersonSeatedPresentation()
        diagnostics.sitDuration = phaseElapsed
        diagnostics.seatEndpointError = planarDistance(
          camera.playerSpatialState.playerPose.position,
          chairTarget.interaction.position
        )
        if pendingCancellation {
          if camera.beginInteractionStanding(at: chairTarget.approach, reduceMotion: reduceMotion) {
            enter(.standing)
          } else {
            diagnostics.invalidTransformCount += 1
            enter(.recovering)
          }
        } else {
          enter(.seated)
        }
      }
    case .standing:
      if locomotion.state == .standingIdle {
        diagnostics.standDuration = phaseElapsed
        diagnostics.standingEndpointError = positionError
        if pendingCancellation {
          enter(.recovering)
        } else {
          enter(.departing)
        }
      }
    case .departing:
      if phaseElapsed >= FounderAnimationTiming.transitionBlend {
        diagnostics.departTransitionTime = phaseElapsed
        diagnostics.completedCycleCount += 1
        diagnostics.cyclePositionDrift = diagnostics.seatEndpointError
        diagnostics.cycleYawDrift = abs(shortestAngle(
          heading(for: chairTarget.interaction.facingDirection)
            - FounderGarageCameraConfiguration(spatial: camera.spatial).seatedPlayerState.playerPose.heading
        ))
        enter(.idle)
      }
    case .recovering:
      let speed = simd_length(SIMD2<Float>(snapshot.velocity.x, snapshot.velocity.z))
      if speed <= 0.01 && locomotion.state == .standingIdle {
        finishRecovery()
      }
    case .idle, .approaching, .seated:
      break
    }
  }

  private func finishRecovery() {
    pendingCancellation = false
    if interruptionActive { diagnostics.interruptRecoveryTime = interruptionElapsed }
    interruptionActive = false
    enter(.idle)
  }

  private func enter(_ next: FounderInteractionPhase) {
    phase = next
    phaseElapsed = 0
  }

  private func boundedDelta(_ raw: TimeInterval) -> Float {
    min(max(Float(raw), 0), FounderGarageCameraConfiguration.maximumDeltaTime)
  }

  private func planarOffset(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SIMD2<Float> {
    [end.x - start.x, end.z - start.z]
  }

  private func planarDistance(_ first: SIMD3<Float>, _ second: SIMD3<Float>) -> Float {
    simd_length(planarOffset(from: first, to: second))
  }

  private func localIntent(for worldOffset: SIMD2<Float>, heading: Float) -> FounderGarageMovementIntent {
    guard simd_length_squared(worldOffset) > 0.000001 else { return .idle }
    let direction = simd_normalize(worldOffset)
    let right = SIMD2<Float>(cos(heading), sin(heading))
    let forward = SIMD2<Float>(sin(heading), -cos(heading))
    return FounderGarageMovementIntent(
      lateral: simd_dot(direction, right),
      forward: simd_dot(direction, forward)
    )
  }

  private func heading(for facing: SIMD3<Float>) -> Float {
    atan2(facing.x, -facing.z)
  }

  private func shortestAngle(_ angle: Float) -> Float {
    atan2(sin(angle), cos(angle))
  }

  private func valuesAreFinite(_ snapshot: FounderGarageCameraController.Snapshot) -> Bool {
    [
      snapshot.playerPosition.x, snapshot.playerPosition.y, snapshot.playerPosition.z,
      snapshot.bodyHeading, snapshot.velocity.x, snapshot.velocity.y, snapshot.velocity.z
    ].allSatisfy(\.isFinite)
  }
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

  var founderInteractionTargets: [FounderInteractionTargetContract] {
    zones.values.compactMap(\.founderInteractionTarget).sorted { $0.id < $1.id }
  }

  func zone(
    for semanticObject: FacilityTier0InteractionZone.SemanticObject
  ) -> FacilityTier0InteractionZone? {
    zones[semanticObject]
  }

  func founderInteractionTarget(
    for semanticObject: FacilityTier0InteractionZone.SemanticObject
  ) -> FounderInteractionTargetContract? {
    zones[semanticObject]?.founderInteractionTarget
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
    let founderStandingApproach = FounderGarageSpatialPose(
      position: authored.founderSeat - founderFacing * 0.82,
      facingDirection: founderFacing
    )
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
        .chair: FacilityTier0InteractionZone(
          id: "facilityTier0.chair",
          semanticObject: .chair,
          anchorName: "Anchor_Founder_Seat",
          object: chair,
          approach: founderStandingApproach,
          interactionDistance: .closePhysical,
          activationBounds: FounderGarageSpatialBounds(
            center: [authored.founderSeat.x, 0.455 / 2, authored.founderSeat.z],
            size: [0.72, 0.455, 0.72]
          ),
          founderInteractionTarget: FounderInteractionTargetContract(
            id: "facilityTier0.chair",
            semanticObject: .chair,
            interactionType: .seat,
            approach: founderStandingApproach,
            interaction: founder,
            gazeTarget: [authored.founderSeat.x, 0.455, authored.founderSeat.z],
            preferredHand: nil,
            handTarget: nil,
            positionToleranceMeters: 0.08,
            facingToleranceRadians: 0.14
          ),
          isEnabled: false
        ),
        .founderComputer: FacilityTier0InteractionZone(
          id: "facilityTier0.founderComputer",
          semanticObject: .founderComputer,
          anchorName: "Anchor_Monitor_Face",
          object: monitor,
          approach: founderStandingApproach,
          interactionDistance: .desk,
          activationBounds: FounderGarageSpatialBounds(
            center: authored.monitorFace,
            size: [0.59, 0.34, 0.04]
          ),
          founderInteractionTarget: FounderInteractionTargetContract(
            id: "facilityTier0.founderComputer",
            semanticObject: .founderComputer,
            interactionType: .seatedWorkstation,
            approach: founderStandingApproach,
            interaction: founder,
            gazeTarget: authored.monitorFace,
            preferredHand: nil,
            handTarget: nil,
            positionToleranceMeters: 0.08,
            facingToleranceRadians: 0.14
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
          founderInteractionTarget: FounderInteractionTargetContract(
            id: "facilityTier0.whiteboard",
            semanticObject: .whiteboard,
            interactionType: .standingObservation,
            approach: FounderGarageSpatialPose(position: [-1.15, 0, -0.40], facingDirection: [-1, 0, 0]),
            interaction: FounderGarageSpatialPose(position: [-1.15, 0, -0.40], facingDirection: [-1, 0, 0]),
            gazeTarget: authored.whiteboardFace,
            preferredHand: nil,
            handTarget: nil,
            positionToleranceMeters: 0.18,
            facingToleranceRadians: 0.21
          ),
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
        iPhone: FounderGarageSpatialPose(position: [0.35, authored.deskSurface.y + 0.009, -0.83], facingDirection: [0, 1, 0]),
        iPad: FounderGarageSpatialPose(position: [0.64, authored.deskSurface.y + 0.012, -1.18], facingDirection: [0, 1, 0]),
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
        founderComputer: FounderGarageInteractionApproach(
          object: monitor,
          approach: founderStandingApproach,
          distance: .desk
        ),
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

  static var facilityTier0V8: FounderGarageArchitectureAssetDescriptor {
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
        "RearWall", "Garage_RightWall", "RightSideAccessDoor", "Ceiling",
        "GarageDoor_Panel", "GarageDoor_Header", "GarageDoor_Track_L",
        "GarageDoor_Track_R", "FounderChair", "FounderDesk", "FounderMonitor",
        "Monitor_Display", "Driveway", "LotGround", "Sidewalk",
        "DrivewayApron_CurbCut", "Curb_L", "Curb_R", "Street", "Facade_Fascia",
        "FrontYard_L", "FrontYard_R", "Mailbox", "Tree_L", "Tree_R",
        "FrontLawn_L", "FrontLawn_R", "Threshold_Apron", "ExteriorFacade",
        "ExteriorLight_01", "ExteriorLight_01_Lens"
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

enum FounderGarageV8AssetContract {
  static let resourceName = "founder_garage_v8"
  static let packageSHA256 = "d297d7a144ab3fc8e5b917226d492c4b2d6de3d05f4e46c3419895e3712450a4"
  static let rightSideDoorEntityName = "RightSideAccessDoor"

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
    if name == FounderGarageV8AssetContract.resourceName {
      guard let url = bundle.url(forResource: name, withExtension: "usdz") else {
        throw FounderGarageV8AssetContract.ValidationError.missingPackage
      }
      try FounderGarageV8AssetContract.validatePackage(Data(contentsOf: url))
    } else if name == FounderGarageV7AssetContract.resourceName {
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
  let authoredPose: FounderCharacterValidationPose?
  let standingNormalization: FounderVisualNormalization?

  init(
    bodyPath: [String],
    headPath: [String]?,
    normalization: FounderVisualNormalization,
    authoredPose: FounderCharacterValidationPose? = nil,
    standingNormalization: FounderVisualNormalization? = nil
  ) {
    self.bodyPath = bodyPath
    self.headPath = headPath
    self.normalization = normalization
    self.authoredPose = authoredPose
    self.standingNormalization = standingNormalization
  }
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
  let authoredPose: FounderAuthoredPoseRig?

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

@MainActor
final class FounderAuthoredPoseRig {
  private struct ModelPose {
    let model: ModelEntity
    let names: [String]
    let rest: [Transform]
    let seated: [Transform]
  }

  private let models: [ModelPose]
  private let normalizationRoot: Entity
  private let seatedNormalization: Transform
  private let standingNormalization: Transform

  init(
    root: Entity,
    pose: FounderCharacterValidationPose,
    normalizationRoot: Entity,
    seatedNormalization: Transform,
    standingNormalization: Transform
  ) {
    models = FounderCharacterContract.models(root).map { model in
      let rest = model.jointTransforms
      let seated = model.jointNames.enumerated().map { index, path in
        pose.transform(for: String(path.split(separator: "/").last ?? "")) ?? rest[index]
      }
      return ModelPose(
        model: model,
        names: model.jointNames.map { String($0.split(separator: "/").last ?? "") },
        rest: rest,
        seated: seated
      )
    }
    self.normalizationRoot = normalizationRoot
    self.seatedNormalization = seatedNormalization
    self.standingNormalization = standingNormalization
    apply(standingAmount: 0)
  }

  func apply(standingAmount amount: Float, motion: FounderMotionFrame = .neutral) {
    let t = min(max(amount, 0), 1)
    for item in models {
      var transforms = zip(item.seated, item.rest).map { blend($0, $1, amount: t) }
      applyMotion(motion, names: item.names, transforms: &transforms)
      item.model.jointTransforms = transforms
    }
    normalizationRoot.transform = blend(seatedNormalization, standingNormalization, amount: t)
  }

  func sampledTransforms(names requested: Set<String>) -> [String: Transform] {
    guard let item = models.first else { return [:] }
    return Dictionary(uniqueKeysWithValues: zip(item.names, item.model.jointTransforms).compactMap { name, transform in
      requested.contains(name) ? (name, transform) : nil
    })
  }

  func baselineTransform(named name: String, standing: Bool) -> Transform? {
    guard let item = models.first, let index = item.names.firstIndex(of: name) else { return nil }
    return standing ? item.rest[index] : item.seated[index]
  }

  private func applyMotion(_ motion: FounderMotionFrame, names: [String], transforms: inout [Transform]) {
    guard !motion.reduceMotion else { return }
    let breath = sin(motion.clock * 2 * .pi / 4.8) * 0.010
      + sin(motion.clock * 2 * .pi / 7.3 + 0.8) * 0.003
    let gazeEnvelope = pow(max(0, sin(motion.clock * 2 * .pi / 11.0 - 1.1)), 6)
    let gazeYaw = gazeEnvelope * sin(motion.clock * 0.73) * 0.055
    let gazePitch = -gazeEnvelope * 0.018

    switch motion.state {
    case .seatedIdle:
      rotate("Spine02", angle: breath * 0.55, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Chest", angle: breath, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Clavicle_L", angle: breath * 0.20, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Clavicle_R", angle: -breath * 0.20, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Head", angle: gazeYaw, axis: [0, 1, 0], names: names, transforms: &transforms)
      rotate("Head", angle: gazePitch - breath * 0.18, axis: [1, 0, 0], names: names, transforms: &transforms)
    case .standingIdle:
      let weightShift = sin(motion.clock * 2 * .pi / 8.9 + 0.4) * 0.009
      rotate("Spine01", angle: weightShift, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Chest", angle: breath * 0.85, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Head", angle: gazeYaw - weightShift * 0.6, axis: [0, 1, 0], names: names, transforms: &transforms)
      rotate("Head", angle: gazePitch - breath * 0.12, axis: [1, 0, 0], names: names, transforms: &transforms)
    case .standingUp, .sittingDown:
      let direction: Float = motion.state == .standingUp ? 1 : -1
      let lift = sin(motion.progress * .pi)
      rotate("Spine01", angle: -lift * 0.11 * direction, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Chest", angle: lift * 0.045 * direction, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("UpperArm_L", angle: lift * 0.06, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("UpperArm_R", angle: lift * 0.06, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Head", angle: lift * 0.04 * direction, axis: [1, 0, 0], names: names, transforms: &transforms)
    case .walkStart, .walking, .walkStop:
      let gait = motion.gaitWeight
      let phase = motion.locomotion.gaitPhase
      let profile = motion.locomotion.phaseVariant.profile
      let weightTransfer = motion.weightTransfer
      let kineticChain = motion.kineticChain
      let pelvisWave = sin(phase + profile.pelvis) * gait
      let stride = sin(phase + profile.thigh) * gait
      let opposite = sin(phase + .pi + profile.thigh) * gait
      let leftKnee = max(0, -sin(phase + 0.35 + profile.knee)) * gait
      let rightKnee = max(0, -sin(phase + .pi + 0.35 + profile.knee)) * gait
      let leftFoot = sin(phase + profile.foot) * gait
      let rightFoot = sin(phase + .pi + profile.foot) * gait
      let torso = sin(phase + profile.torso - kineticChain.torsoPhaseOffset) * gait
      let rightArm = kineticChain.armPresentedAngle / 0.25
      let leftArm = -rightArm
      let verticalCOM = abs(sin(phase + profile.verticalCOM)) * gait
      rotate("Thigh_L", angle: stride * 0.34, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Thigh_R", angle: opposite * 0.34, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Calf_L", angle: leftKnee * 0.48, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Calf_R", angle: rightKnee * 0.48, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Foot_L", angle: (-leftFoot * 0.13) - leftKnee * 0.12, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Foot_R", angle: (-rightFoot * 0.13) - rightKnee * 0.12, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("UpperArm_L", angle: leftArm * 0.25, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("UpperArm_R", angle: rightArm * 0.25, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("LowerArm_L", angle: 0.10 + max(0, rightArm) * 0.10, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("LowerArm_R", angle: 0.10 + max(0, leftArm) * 0.10, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Chest", angle: -torso * 0.030, axis: [0, 1, 0], names: names, transforms: &transforms)
      rotate("Clavicle_L", angle: kineticChain.shoulderResponse, axis: [1, 0, 0], names: names, transforms: &transforms)
      rotate("Clavicle_R", angle: -kineticChain.shoulderResponse, axis: [1, 0, 0], names: names, transforms: &transforms)
      translate(
        "Hips",
        by: [
          pelvisWave * 0.006 + weightTransfer.pelvisLateral,
          verticalCOM * 0.011 + kineticChain.pelvisVerticalLoadOffset,
          0
        ],
        names: names,
        transforms: &transforms
      )
      rotate("Hips", angle: weightTransfer.pelvisRoll, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Spine01", angle: weightTransfer.torsoCounterbalance * 0.55, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Chest", angle: weightTransfer.torsoCounterbalance * 0.45, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Clavicle_L", angle: weightTransfer.shoulderCompensation, axis: [0, 0, 1], names: names, transforms: &transforms)
      rotate("Clavicle_R", angle: weightTransfer.shoulderCompensation, axis: [0, 0, 1], names: names, transforms: &transforms)
    case .turnInPlace, .seatedTurn:
      let anticipation = min(max(motion.turnDelta * 0.24, -0.16), 0.16)
      rotate("Spine01", angle: anticipation * 0.45, axis: [0, 1, 0], names: names, transforms: &transforms)
      rotate("Chest", angle: anticipation * 0.35, axis: [0, 1, 0], names: names, transforms: &transforms)
      rotate("Head", angle: anticipation * 0.55, axis: [0, 1, 0], names: names, transforms: &transforms)
    }
  }

  private func rotate(
    _ name: String,
    angle: Float,
    axis: SIMD3<Float>,
    names: [String],
    transforms: inout [Transform]
  ) {
    guard let index = names.firstIndex(of: name) else { return }
    transforms[index].rotation = simd_normalize(transforms[index].rotation * simd_quatf(angle: angle, axis: axis))
  }

  private func translate(
    _ name: String,
    by offset: SIMD3<Float>,
    names: [String],
    transforms: inout [Transform]
  ) {
    guard let index = names.firstIndex(of: name) else { return }
    transforms[index].translation += offset
  }

  private func blend(_ seated: Transform, _ standing: Transform, amount: Float) -> Transform {
    Transform(
      scale: seated.scale + (standing.scale - seated.scale) * amount,
      rotation: simd_slerp(seated.rotation, standing.rotation, amount),
      translation: seated.translation + (standing.translation - seated.translation) * amount
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
      headTarget: head,
      authoredPose: nil
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

    let authoredPose = descriptor.authoredPose.map { pose in
      FounderAuthoredPoseRig(
        root: loadedRoot,
        pose: pose,
        normalizationRoot: normalizationRoot,
        seatedNormalization: descriptor.normalization.transform,
        standingNormalization: descriptor.standingNormalization?.transform ?? descriptor.normalization.transform
      )
    }

    self.source = source
    rig = FounderPresentationRig(
      anchor: anchor,
      normalizationRoot: normalizationRoot,
      visualRoot: loadedRoot,
      bodyTarget: body,
      headTarget: head,
      authoredPose: authoredPose
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
    let components = path.first == root.name ? Array(path.dropFirst()) : path
    return components.reduce(Optional(root)) { current, component in
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

enum FounderLocomotionState: String, CaseIterable, Equatable, Sendable {
  case seatedIdle, seatedTurn, standingUp, standingIdle
  case walkStart, walking, walkStop, turnInPlace, sittingDown
}

enum FounderFootPhase: String, CaseIterable, Equatable, Sendable {
  case swing, approachingGround, plant, pushOff

  static func resolve(gaitPhase: Float, offset: Float = 0) -> Self {
    let fullCycle = 2 * Float.pi
    let wrapped = (gaitPhase + offset).truncatingRemainder(dividingBy: fullCycle)
    let normalized = (wrapped < 0 ? wrapped + fullCycle : wrapped) / fullCycle
    return switch normalized {
    case 0..<0.25: .plant
    case 0.25..<0.50: .pushOff
    case 0.50..<0.75: .swing
    default: .approachingGround
    }
  }
}

enum FounderLocomotionPhaseVariant: String, CaseIterable, Equatable, Sendable {
  case baseline, a, b, c

  static let productionDefault: Self = .c

  static var requested: Self {
    #if DEBUG
    let prefix = "--founder-locomotion-phase="
    guard let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })?
      .dropFirst(prefix.count) else { return productionDefault }
    return Self(rawValue: String(value)) ?? productionDefault
    #else
    return productionDefault
    #endif
  }

  var reviewLabel: String {
    switch self {
    case .baseline: "Baseline"
    case .a: "Variant A"
    case .b: "Variant B"
    case .c: "Variant C"
    }
  }

  var profile: FounderGaitPhaseProfile {
    switch self {
    case .baseline:
      .init(pelvis: 0, thigh: 0, knee: 0, foot: 0, torso: 0, arm: 0, verticalCOM: 0)
    case .a:
      .init(pelvis: 0, thigh: 0.10, knee: 0.12, foot: 0.18, torso: 0.16, arm: 0.22, verticalCOM: 0.08)
    case .b:
      .init(pelvis: 0.06, thigh: 0.14, knee: 0.22, foot: 0.34, torso: 0.24, arm: 0.38, verticalCOM: 0.14)
    case .c:
      .init(pelvis: -0.06, thigh: 0.18, knee: 0.30, foot: 0.48, torso: 0.32, arm: 0.52, verticalCOM: 0.20)
    }
  }
}

struct FounderGaitPhaseProfile: Equatable, Sendable {
  let pelvis: Float
  let thigh: Float
  let knee: Float
  let foot: Float
  let torso: Float
  let arm: Float
  let verticalCOM: Float

  var offsets: [Float] { [pelvis, thigh, knee, foot, torso, arm, verticalCOM] }
}

enum FounderWeightTransferVariant: String, CaseIterable, Equatable, Sendable {
  case baseline, a, b, c

  static let productionDefault: Self = .baseline

  static var reviewRequested: Self? {
    #if DEBUG
    let prefix = "--founder-weight-transfer="
    guard let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })?
      .dropFirst(prefix.count) else { return nil }
    return Self(rawValue: String(value))
    #else
    return nil
    #endif
  }

  static var requested: Self { reviewRequested ?? productionDefault }

  var reviewLabel: String {
    switch self {
    case .baseline: "Baseline"
    case .a: "Variant A"
    case .b: "Variant B"
    case .c: "Variant C"
    }
  }

  var profile: FounderWeightTransferProfile {
    switch self {
    case .baseline:
      .init(pelvisLateralAmplitude: 0, pelvisRollAmplitude: 0, torsoCounterbalanceFactor: 0, shoulderCompensationFactor: 0)
    case .a:
      .init(pelvisLateralAmplitude: 0.010, pelvisRollAmplitude: 0.012, torsoCounterbalanceFactor: 0.45, shoulderCompensationFactor: 0.20)
    case .b:
      .init(pelvisLateralAmplitude: 0.016, pelvisRollAmplitude: 0.018, torsoCounterbalanceFactor: 0.55, shoulderCompensationFactor: 0.26)
    case .c:
      .init(pelvisLateralAmplitude: 0.022, pelvisRollAmplitude: 0.026, torsoCounterbalanceFactor: 0.65, shoulderCompensationFactor: 0.32)
    }
  }
}

struct FounderWeightTransferProfile: Equatable, Sendable {
  let pelvisLateralAmplitude: Float
  let pelvisRollAmplitude: Float
  let torsoCounterbalanceFactor: Float
  let shoulderCompensationFactor: Float

  var values: [Float] {
    [pelvisLateralAmplitude, pelvisRollAmplitude, torsoCounterbalanceFactor, shoulderCompensationFactor]
  }
}

struct FounderWeightTransferFrame: Equatable, Sendable {
  let variant: FounderWeightTransferVariant
  let leftSupportWeight: Float
  let rightSupportWeight: Float
  let supportBias: Float
  let pelvisLateral: Float
  let pelvisRoll: Float
  let torsoCounterbalance: Float
  let shoulderCompensation: Float

  static let neutral = resolve(gaitPhase: 0, gaitWeight: 0, variant: .baseline)

  static func supportWeight(gaitPhase: Float, offset: Float = 0) -> Float {
    0.5 + 0.5 * cos(gaitPhase + offset)
  }

  static func resolve(
    gaitPhase: Float,
    gaitWeight: Float,
    variant: FounderWeightTransferVariant
  ) -> Self {
    let left = supportWeight(gaitPhase: gaitPhase)
    let right = supportWeight(gaitPhase: gaitPhase, offset: .pi)
    let bias = left - right
    let envelope = min(max(gaitWeight, 0), 1)
    let transfer = bias * envelope
    let profile = variant.profile
    let pelvisRoll = transfer * profile.pelvisRollAmplitude
    return Self(
      variant: variant,
      leftSupportWeight: left,
      rightSupportWeight: right,
      supportBias: bias,
      pelvisLateral: transfer * profile.pelvisLateralAmplitude,
      pelvisRoll: pelvisRoll,
      torsoCounterbalance: -pelvisRoll * profile.torsoCounterbalanceFactor,
      shoulderCompensation: -pelvisRoll * profile.shoulderCompensationFactor
    )
  }
}

enum FounderKineticChainVariant: String, CaseIterable, Equatable, Sendable {
  case baseline, a, b, c

  static let productionDefault: Self = .b

  static var reviewRequested: Self? {
    #if DEBUG
    let prefix = "--founder-kinetic-chain="
    guard let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })?
      .dropFirst(prefix.count) else { return nil }
    return Self(rawValue: String(value))
    #else
    return nil
    #endif
  }

  static var requested: Self { reviewRequested ?? productionDefault }

  var reviewLabel: String {
    switch self {
    case .baseline: "Baseline"
    case .a: "Variant A"
    case .b: "Variant B"
    case .c: "Variant C"
    }
  }

  var profile: FounderKineticChainProfile {
    switch self {
    case .baseline:
      .init(supportLoadingStrength: 0, torsoLag: 0, shoulderLag: 0, armFollowThrough: 0)
    case .a:
      .init(supportLoadingStrength: 0.0035, torsoLag: 0.018, shoulderLag: 0.014, armFollowThrough: 0.024)
    case .b:
      .init(supportLoadingStrength: 0.0055, torsoLag: 0.030, shoulderLag: 0.024, armFollowThrough: 0.040)
    case .c:
      .init(supportLoadingStrength: 0.0075, torsoLag: 0.042, shoulderLag: 0.034, armFollowThrough: 0.056)
    }
  }
}

struct FounderKineticChainProfile: Equatable, Sendable {
  let supportLoadingStrength: Float
  let torsoLag: Float
  let shoulderLag: Float
  let armFollowThrough: Float

  var values: [Float] { [supportLoadingStrength, torsoLag, shoulderLag, armFollowThrough] }
}

struct FounderKineticChainFrame: Equatable, Sendable {
  let variant: FounderKineticChainVariant
  let leftSupportWeight: Float
  let rightSupportWeight: Float
  let totalSupport: Float
  let supportBias: Float
  let supportTransitionRate: Float
  let pelvisLoadResponse: Float
  let pelvisVerticalLoadOffset: Float
  let torsoLag: Float
  let torsoResponseTime: Float
  let torsoSettleTime: Float
  let torsoPhaseOffset: Float
  let shoulderLag: Float
  let shoulderPhaseOffset: Float
  let shoulderResponse: Float
  let armTargetAngle: Float
  let armPresentedAngle: Float
  let armLag: Float
  let armSettleTime: Float

  static let neutral = resolve(
    gaitPhase: 0,
    gaitWeight: 0,
    phaseRate: 0,
    armPhase: 0,
    variant: .baseline
  )

  static func resolve(
    gaitPhase: Float,
    gaitWeight: Float,
    phaseRate: Float,
    armPhase: Float,
    variant: FounderKineticChainVariant
  ) -> Self {
    let envelope = min(max(gaitWeight, 0), 1)
    let left = FounderWeightTransferFrame.supportWeight(gaitPhase: gaitPhase)
    let right = FounderWeightTransferFrame.supportWeight(gaitPhase: gaitPhase, offset: .pi)
    let bias = left - right
    let transitionRate = -sin(gaitPhase) * max(phaseRate, 0) * envelope
    let loadResponse = (1 - min(abs(bias), 1)) * envelope
    let profile = variant.profile
    let torsoPhaseOffset = profile.torsoLag * max(phaseRate, 0)
    let shoulderPhaseOffset = profile.shoulderLag * max(phaseRate, 0)
    let armPhaseOffset = profile.armFollowThrough * max(phaseRate, 0)
    let targetArmAngle = sin(gaitPhase + armPhase) * 0.25 * envelope
    let presentedArmAngle = sin(gaitPhase + armPhase - armPhaseOffset) * 0.25 * envelope
    let shoulderResponse = (
      sin(gaitPhase + armPhase - shoulderPhaseOffset)
        - sin(gaitPhase + armPhase)
    ) * 0.018 * envelope
    return Self(
      variant: variant,
      leftSupportWeight: left,
      rightSupportWeight: right,
      totalSupport: left + right,
      supportBias: bias,
      supportTransitionRate: transitionRate,
      pelvisLoadResponse: loadResponse,
      pelvisVerticalLoadOffset: -profile.supportLoadingStrength * loadResponse,
      torsoLag: profile.torsoLag,
      torsoResponseTime: profile.torsoLag,
      torsoSettleTime: profile.torsoLag * 2,
      torsoPhaseOffset: torsoPhaseOffset,
      shoulderLag: profile.shoulderLag,
      shoulderPhaseOffset: shoulderPhaseOffset,
      shoulderResponse: shoulderResponse,
      armTargetAngle: targetArmAngle,
      armPresentedAngle: presentedArmAngle,
      armLag: presentedArmAngle - targetArmAngle,
      armSettleTime: profile.armFollowThrough * 2
    )
  }
}

struct FounderLocomotionBlackboard: Equatable, Sendable {
  let speed: Float
  let normalizedSpeed: Float
  let gaitPhase: Float
  let leftFootPhase: FounderFootPhase
  let rightFootPhase: FounderFootPhase
  let phaseVariant: FounderLocomotionPhaseVariant

  static let neutral = FounderLocomotionBlackboard(
    speed: 0,
    normalizedSpeed: 0,
    gaitPhase: 0,
    leftFootPhase: .plant,
    rightFootPhase: .swing,
    phaseVariant: .baseline
  )
}

struct FounderMotionFrame {
  let state: FounderLocomotionState
  let clock: Float
  let progress: Float
  let locomotion: FounderLocomotionBlackboard
  let weightTransfer: FounderWeightTransferFrame
  let kineticChain: FounderKineticChainFrame
  let gaitWeight: Float
  let turnDelta: Float
  let reduceMotion: Bool

  static let neutral = FounderMotionFrame(
    state: .seatedIdle,
    clock: 0,
    progress: 0,
    locomotion: .neutral,
    weightTransfer: .neutral,
    kineticChain: .neutral,
    gaitWeight: 0,
    turnDelta: 0,
    reduceMotion: true
  )
}

struct FounderMotionCaptureSample: Equatable {
  let state: FounderLocomotionState
  let clip: String
  let stateTimestamp: Float
  let sampledTimestamp: Float
  let rootTransform: Transform
  let jointTransforms: [String: Transform]
  let locomotionVelocity: SIMD2<Float>
  let worldDisplacement: SIMD3<Float>
  let cameraState: String
  let founderWorldPosition: SIMD3<Float>
  let garageState: String
  let frameIndex: Int
}

struct FounderAnimationTiming {
  static let shortBlend: Float = 0.16
  static let transitionBlend: Float = 0.24
  static let seatedTransition: Float = 0.42
  static let standingTransition: Float = 0.68
  static let reducedTransition: Float = 0.08
}

struct FounderLocomotionDiagnostics: Equatable {
  var state: FounderLocomotionState = .seatedIdle
  var previousState: FounderLocomotionState = .seatedIdle
  var navigationMode: FounderGarageNavigationMode = .seated
  var movementMagnitude: Float = 0
  var horizontalVelocity = SIMD2<Float>.zero
  var targetFacing: Float = 0
  var avatarFacing: Float = 0
  var activeAnimation = "seatedIdle.procedural"
  var playbackSpeed: Float = 0
  var blendProgress: Float = 1
  var seatedAnchorError: Float = 0
  var positionalError: Float = 0
  var firstPersonHeadHidden = false
  var gaitWeight: Float = 0
  var gaitCycleDistance: Float = 0
  var footSlideRatio: Float = 0
  var phaseVariant: FounderLocomotionPhaseVariant = .baseline
  var gaitPhase: Float = 0
  var leftFootPhase: FounderFootPhase = .plant
  var rightFootPhase: FounderFootPhase = .swing
  var weightTransfer: FounderWeightTransferFrame = .neutral
  var kineticChain: FounderKineticChainFrame = .neutral
}

/// Deterministic visual graph. It follows camera-owned spatial state and never
/// feeds root motion, collision, or position back into navigation or GameStore.
@MainActor
final class FounderLocomotionController {
  private(set) var state: FounderLocomotionState = .seatedIdle
  private(set) var previousState: FounderLocomotionState = .seatedIdle
  private(set) var diagnostics = FounderLocomotionDiagnostics()
  private var rig: FounderPresentationRig
  private let seatedPose: FounderPlayerPose
  private var elapsed: Float = 0
  private var avatarFacing: Float
  private var lastTargetFacing: Float
  private var seatedBodyTransform: Transform
  private var seatedHeadTransform: Transform?
  private var sitStartPosition: SIMD3<Float>
  private var standStartPosition: SIMD3<Float>
  private var walkPhase: Float = 0
  private var animatedGaitDistance: Float = 0
  private var motionClock: Float = 0
  private var frameIndex = 0
  private var previousAnchorPosition: SIMD3<Float>
  private var phaseVariant: FounderLocomotionPhaseVariant
  private var weightTransferVariant: FounderWeightTransferVariant
  private var kineticChainVariant: FounderKineticChainVariant
  private(set) var latestMotionSample: FounderMotionCaptureSample?

  private static let gaitCycleDistance: Float = 0.78
  private static let sampledJoints: Set<String> = [
    "Hips", "Spine01", "Spine02", "Chest", "Head", "Clavicle_L", "Clavicle_R",
    "UpperArm_L", "UpperArm_R", "Hand_L", "Hand_R",
    "Calf_L", "Calf_R", "Foot_L", "Foot_R", "Toe_L", "Toe_R"
  ]

  init(
    rig: FounderPresentationRig,
    seatedPose: FounderPlayerPose,
    phaseVariant: FounderLocomotionPhaseVariant = .requested,
    weightTransferVariant: FounderWeightTransferVariant = .requested,
    kineticChainVariant: FounderKineticChainVariant = .requested
  ) {
    self.rig = rig
    self.seatedPose = seatedPose
    avatarFacing = seatedPose.heading
    lastTargetFacing = seatedPose.heading
    seatedBodyTransform = rig.bodyTarget.transform
    seatedHeadTransform = rig.headTarget?.transform
    sitStartPosition = seatedPose.position
    standStartPosition = seatedPose.position
    previousAnchorPosition = rig.anchor.position
    self.phaseVariant = phaseVariant
    self.weightTransferVariant = weightTransferVariant
    self.kineticChainVariant = kineticChainVariant
  }

  func configurePhaseVariantForReview(_ variant: FounderLocomotionPhaseVariant) {
    phaseVariant = variant
  }

  func configureWeightTransferVariantForReview(_ variant: FounderWeightTransferVariant) {
    weightTransferVariant = variant
  }

  func configureKineticChainVariantForReview(_ variant: FounderKineticChainVariant) {
    kineticChainVariant = variant
  }

  func enterFirstPersonSeatedPresentation() {
    forceSeatedState()
    applyFirstPersonVisibility(true)
    diagnostics.state = .seatedIdle
    diagnostics.firstPersonHeadHidden = true
  }

  func install(rig: FounderPresentationRig, firstPerson: Bool) {
    self.rig = rig
    seatedBodyTransform = rig.bodyTarget.transform
    seatedHeadTransform = rig.headTarget?.transform
    elapsed = 0
    if firstPerson { forceSeatedState() }
    applyFirstPersonVisibility(firstPerson)
  }

  func update(
    spatial: FounderCameraSpatialState,
    collisionBlocked: Bool,
    firstPerson: Bool,
    reduceMotion: Bool,
    deltaTime rawDelta: TimeInterval
  ) {
    let dt = min(max(Float(rawDelta), 0), FounderGarageCameraConfiguration.maximumDeltaTime)
    guard dt > 0 else { return }
    motionClock += dt
    frameIndex += 1
    let speed = firstPerson || collisionBlocked ? 0 : spatial.movementMagnitude
    let moving = speed > 0.045
    let seated = firstPerson || (spatial.stance == .seated && isNearSeat(spatial.position))
    let targetFacing = moving
      ? atan2(spatial.horizontalVelocity.x, -spatial.horizontalVelocity.y)
      : atan2(spatial.facingDirection.x, -spatial.facingDirection.z)
    let facingDelta = abs(shortestAngle(targetFacing - avatarFacing))

    if firstPerson { forceSeatedState() }
    advanceGraph(seated: seated, moving: moving, facingDelta: facingDelta, reduceMotion: reduceMotion, dt: dt)
    if (state == .walkStart || state == .walking || state == .walkStop) && !reduceMotion {
      let phaseAdvance = dt * max(speed, 0.08) / Self.gaitCycleDistance * 2 * .pi
      animatedGaitDistance = phaseAdvance / (2 * .pi) * Self.gaitCycleDistance
      walkPhase = (walkPhase + phaseAdvance)
        .truncatingRemainder(dividingBy: 2 * .pi)
    } else {
      animatedGaitDistance = 0
    }
    let facingGoal = seated ? seatedPose.heading : targetFacing
    let facingRate: Float = reduceMotion ? 18 : (state == .turnInPlace ? 4.8 : 7.2)
    let desiredFacingStep = shortestAngle(facingGoal - avatarFacing) * min(facingRate * dt, 1)
    let maximumFacingStep = (reduceMotion ? 18 : (state == .turnInPlace ? 2.4 : 5.0)) * dt
    avatarFacing += min(max(desiredFacingStep, -maximumFacingStep), maximumFacingStep)
    lastTargetFacing = targetFacing
    applyVisual(spatial: spatial, speed: speed, firstPerson: firstPerson, reduceMotion: reduceMotion, deltaTime: dt)
  }

  private func advanceGraph(seated: Bool, moving: Bool, facingDelta: Float, reduceMotion: Bool, dt: Float) {
    elapsed += dt
    let short = reduceMotion ? FounderAnimationTiming.reducedTransition : FounderAnimationTiming.shortBlend
    let transition = reduceMotion ? FounderAnimationTiming.reducedTransition : FounderAnimationTiming.transitionBlend
    let seatedDuration = reduceMotion ? FounderAnimationTiming.reducedTransition : FounderAnimationTiming.seatedTransition
    let standingDuration = reduceMotion ? FounderAnimationTiming.reducedTransition : FounderAnimationTiming.standingTransition
    switch state {
    case .seatedIdle:
      if !seated { enter(.standingUp) }
      else if abs(shortestAngle(lastTargetFacing - seatedPose.heading)) > 0.22 { enter(.seatedTurn) }
    case .seatedTurn:
      if !seated { enter(.standingUp) }
      else if facingDelta < 0.08 { enter(.seatedIdle) }
    case .standingUp:
      if elapsed >= standingDuration { enter(moving ? .walkStart : .standingIdle) }
    case .standingIdle:
      if seated { enter(.sittingDown) }
      else if moving { enter(.walkStart) }
      else if facingDelta > 0.30 { enter(.turnInPlace) }
    case .walkStart:
      if seated { enter(.sittingDown) }
      else if !moving { enter(.walkStop) }
      else if elapsed >= short { enter(.walking) }
    case .walking:
      if seated { enter(.sittingDown) }
      else if !moving { enter(.walkStop) }
    case .walkStop:
      if moving { enter(.walkStart) }
      else if seated { enter(.sittingDown) }
      else if elapsed >= transition { enter(.standingIdle) }
    case .turnInPlace:
      if moving { enter(.walkStart) }
      else if seated { enter(.sittingDown) }
      else if facingDelta < 0.08 || elapsed >= seatedDuration { enter(.standingIdle) }
    case .sittingDown:
      if !seated { enter(.standingIdle) }
      else if elapsed >= seatedDuration { enter(.seatedIdle); avatarFacing = seatedPose.heading }
    }
  }

  private func enter(_ next: FounderLocomotionState) {
    guard next != state else { return }
    if next == .standingUp && (state == .seatedIdle || state == .seatedTurn) {
      seatedBodyTransform = rig.bodyTarget.transform
      seatedHeadTransform = rig.headTarget?.transform
      standStartPosition = seatedPose.position
    }
    if next == .sittingDown { sitStartPosition = rig.anchor.position }
    previousState = state
    state = next
    elapsed = 0
    if next == .seatedIdle {
      rig.bodyTarget.transform = seatedBodyTransform
      if let seatedHeadTransform { rig.headTarget?.transform = seatedHeadTransform }
    }
  }

  /// First-person is the seated Founder viewpoint. Resolve the visual graph
  /// synchronously so a standing or sit-down frame can never occupy that camera.
  private func forceSeatedState() {
    if state != .seatedIdle {
      previousState = state
      state = .seatedIdle
      elapsed = 0
    }
    avatarFacing = seatedPose.heading
    lastTargetFacing = seatedPose.heading
    rig.bodyTarget.transform = seatedBodyTransform
    if let seatedHeadTransform { rig.headTarget?.transform = seatedHeadTransform }
  }

  private func applyVisual(
    spatial: FounderCameraSpatialState,
    speed: Float,
    firstPerson: Bool,
    reduceMotion: Bool,
    deltaTime: Float
  ) {
    let seated = state == .seatedIdle || state == .seatedTurn
    let transitionDuration: Float
    if reduceMotion && (state == .standingUp || state == .sittingDown) {
      transitionDuration = FounderAnimationTiming.reducedTransition
    } else if state == .standingUp {
      transitionDuration = FounderAnimationTiming.standingTransition
    } else if state == .sittingDown {
      transitionDuration = FounderAnimationTiming.seatedTransition
    } else {
      transitionDuration = FounderAnimationTiming.transitionBlend
    }
    let progress = min(elapsed / max(transitionDuration, 0.001), 1)
    let eased = progress * progress * (3 - 2 * progress)
    let authoritativePosition: SIMD3<Float>
    if seated { authoritativePosition = seatedPose.position }
    else if state == .standingUp { authoritativePosition = standStartPosition + (spatial.position - standStartPosition) * eased }
    else if state == .sittingDown { authoritativePosition = sitStartPosition + (seatedPose.position - sitStartPosition) * eased }
    else { authoritativePosition = spatial.position }
    rig.anchor.isEnabled = true
    applyFirstPersonVisibility(firstPerson)
    rig.anchor.position = authoritativePosition
    rig.anchor.orientation = simd_quatf(angle: seated ? seatedPose.heading : avatarFacing, axis: [0, 1, 0])

    let standingAmount: Float
    switch state {
    case .seatedIdle, .seatedTurn: standingAmount = 0
    case .standingUp: standingAmount = eased
    case .sittingDown: standingAmount = 1 - eased
    default: standingAmount = 1
    }
    let gaitWeight: Float
    switch state {
    case .walkStart: gaitWeight = eased
    case .walking: gaitWeight = 1
    case .walkStop: gaitWeight = 1 - eased
    default: gaitWeight = 0
    }
    let turnDelta = shortestAngle(lastTargetFacing - avatarFacing)
    let locomotionBlackboard = FounderLocomotionBlackboard(
      speed: speed,
      normalizedSpeed: min(max(speed / FounderGarageCameraConfiguration.walkingSpeed, 0), 1),
      gaitPhase: walkPhase,
      leftFootPhase: FounderFootPhase.resolve(gaitPhase: walkPhase),
      rightFootPhase: FounderFootPhase.resolve(gaitPhase: walkPhase, offset: .pi),
      phaseVariant: phaseVariant
    )
    let weightTransfer = FounderWeightTransferFrame.resolve(
      gaitPhase: walkPhase,
      gaitWeight: reduceMotion ? 0 : gaitWeight,
      variant: weightTransferVariant
    )
    let phaseRate = speed > 0
      ? speed / Self.gaitCycleDistance * 2 * .pi
      : 0
    let kineticChain = FounderKineticChainFrame.resolve(
      gaitPhase: walkPhase,
      gaitWeight: reduceMotion ? 0 : gaitWeight,
      phaseRate: phaseRate,
      armPhase: phaseVariant.profile.arm,
      variant: kineticChainVariant
    )
    let centerShift = reduceMotion ? 0 : sin(standingAmount * .pi) * 0.035
    let walkingWeightShift: Float = state == .walking && !reduceMotion ? sin(walkPhase) : 0
    if let authoredPose = rig.authoredPose {
      authoredPose.apply(
        standingAmount: standingAmount,
        motion: FounderMotionFrame(
          state: state,
          clock: motionClock,
          progress: eased,
          locomotion: locomotionBlackboard,
          weightTransfer: weightTransfer,
          kineticChain: kineticChain,
          gaitWeight: gaitWeight,
          turnDelta: turnDelta,
          reduceMotion: reduceMotion
        )
      )
    } else if state != .seatedIdle && state != .seatedTurn {
      rig.bodyTarget.transform = Transform(
        scale: .one,
        rotation: simd_normalize(
          simd_quatf(angle: -centerShift * 1.6, axis: [1, 0, 0])
            * simd_quatf(angle: walkingWeightShift * 0.012, axis: [0, 0, 1])
        ),
        translation: [walkingWeightShift * 0.008, 1.12 + standingAmount * 0.06 + abs(walkingWeightShift) * 0.006, -centerShift]
      )
      if let head = rig.headTarget {
        head.transform = Transform(translation: [0, 1.68 + standingAmount * 0.04, -centerShift * 0.6])
        head.isEnabled = true
      }
    }

    let positionError = simd_distance(rig.anchor.position, authoritativePosition)
    let worldDisplacement = rig.anchor.position - previousAnchorPosition
    previousAnchorPosition = rig.anchor.position
    let horizontalDisplacement = simd_length(SIMD2<Float>(worldDisplacement.x, worldDisplacement.z))
    let slideRatio = state == .walking && horizontalDisplacement > 0.0001 && !reduceMotion
      ? abs(horizontalDisplacement - animatedGaitDistance) / horizontalDisplacement
      : 0
    diagnostics = FounderLocomotionDiagnostics(
      state: state,
      previousState: previousState,
      navigationMode: spatial.navigationMode,
      movementMagnitude: speed,
      horizontalVelocity: spatial.horizontalVelocity,
      targetFacing: lastTargetFacing,
      avatarFacing: avatarFacing,
      activeAnimation: state.rawValue,
      playbackSpeed: state == .walking ? min(max(speed / FounderGarageCameraConfiguration.walkingSpeed, 0.35), 1.25) : 0,
      blendProgress: eased,
      seatedAnchorError: seated || state == .sittingDown ? simd_distance(rig.anchor.position, seatedPose.position) : 0,
      positionalError: positionError,
      firstPersonHeadHidden: firstPerson,
      gaitWeight: gaitWeight,
      gaitCycleDistance: state == .walking ? Self.gaitCycleDistance : 0,
      footSlideRatio: slideRatio,
      phaseVariant: phaseVariant,
      gaitPhase: walkPhase,
      leftFootPhase: locomotionBlackboard.leftFootPhase,
      rightFootPhase: locomotionBlackboard.rightFootPhase,
      weightTransfer: weightTransfer,
      kineticChain: kineticChain
    )
    latestMotionSample = FounderMotionCaptureSample(
      state: state,
      clip: FounderAnimationClipCatalog.clipName(for: state) ?? state.rawValue + ".procedural",
      stateTimestamp: elapsed,
      sampledTimestamp: motionClock,
      rootTransform: rig.anchor.transform,
      jointTransforms: rig.authoredPose?.sampledTransforms(names: Self.sampledJoints) ?? [:],
      locomotionVelocity: spatial.horizontalVelocity,
      worldDisplacement: worldDisplacement,
      cameraState: String(describing: spatial.navigationMode),
      founderWorldPosition: rig.anchor.position,
      garageState: "productionGarage",
      frameIndex: frameIndex
    )
  }

  private func applyFirstPersonVisibility(_ firstPerson: Bool) {
    // The eye camera is inside the local Founder rig. Hiding only head modules
    // leaves the torso and transition pose in front of the lens, so the complete
    // local visual must be suppressed until third-person Explore resumes.
    rig.visualRoot.isEnabled = !firstPerson
    if !firstPerson {
      FounderCharacterContract.headParts.compactMap {
        rig.visualRoot.findEntity(named: $0 + "Module")
      }.forEach { $0.isEnabled = true }
    }
  }

  private func isNearSeat(_ position: SIMD3<Float>) -> Bool {
    simd_distance(SIMD2<Float>(position.x, position.z), SIMD2<Float>(seatedPose.position.x, seatedPose.position.z)) <= 0.45
  }

  private func shortestAngle(_ angle: Float) -> Float {
    atan2(sin(angle), cos(angle))
  }
}

/// Avatar-level indirection keeps one locomotion graph for future selectable rigs.
@MainActor
final class FounderAvatarController {
  let locomotion: FounderLocomotionController

  init(rig: FounderPresentationRig, seatedPose: FounderPlayerPose) {
    locomotion = FounderLocomotionController(rig: rig, seatedPose: seatedPose)
  }

  func install(rig: FounderPresentationRig, firstPerson: Bool) {
    locomotion.install(rig: rig, firstPerson: firstPerson)
  }
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
  let founderAvatarController: FounderAvatarController
  let interactionCoordinator: FounderInteractionCoordinator
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
  @ObservationIgnored private(set) var computerInteractionFeedbackState = GarageInteractionFeedbackState.unavailable
  @ObservationIgnored private(set) var chairInteractionFeedbackState = GarageInteractionFeedbackState.unavailable
  @ObservationIgnored private(set) var whiteboardInteractionFeedbackState = GarageInteractionFeedbackState.unavailable
  @ObservationIgnored private var chairActivationFeedbackPermitted = false
  @ObservationIgnored private var whiteboardActivationFeedbackPermitted = false
  @ObservationIgnored private var importedMonitorBaseline: (entity: Entity, material: PhysicallyBasedMaterial)?
  @ObservationIgnored private var importedChairBaseline: (entity: Entity, model: ModelComponent)?
  @ObservationIgnored private var importedWhiteboardBaseline: (entity: Entity, model: ModelComponent)?
  @ObservationIgnored private var accessibilityActivationSubscription: EventSubscription?
  @ObservationIgnored private var cameraUpdateSubscription: EventSubscription?
  @ObservationIgnored private var requestedVisualSource = FounderVisualSource.procedural
  @ObservationIgnored private var assetLoadGeneration = 0
  @ObservationIgnored private var assetLoadTask: Task<Void, Never>?
  @ObservationIgnored private var requestedArchitectureSource = FounderGarageArchitectureSource.procedural
  @ObservationIgnored private var architectureLoadGeneration = 0
  @ObservationIgnored private var architectureLoadTask: Task<Void, Never>?
  @ObservationIgnored private var garageDoorAnimationElements: [FounderGarageDoorAnimationElement] = []
  @ObservationIgnored private var garageDoorAnimationPlaybacks: [AnimationPlaybackController] = []
  @ObservationIgnored private var onAtlantisBoundaryCrossing: ((FounderAtlantisTraversalHandoff) -> Void)?
  @ObservationIgnored private var didRequestAtlantisTraversal = false
  @ObservationIgnored private(set) var isFounderPresentedInAtlantis = false
  @ObservationIgnored private var traversalDiagnosticsElapsed: TimeInterval = 0
  @ObservationIgnored private var traversalDiagnosticsSignature = ""
  // Swap into the authored Atlantis driveway just beyond the sectional door,
  // before the local Garage presentation runs out of exterior geometry.
  static let atlantisHandoffThresholdZ: Float = 3.85

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
    founderAvatarController = FounderAvatarController(
      rig: built.proceduralFounder.rig,
      seatedPose: cameraController.playerSpatialState.playerPose
    )
    interactionCoordinator = FounderInteractionCoordinator(
      chairTarget: spatialSpecification.facilityTier0InteractionSpace?
        .founderInteractionTarget(for: .chair)
    )
    precondition(built.entities.validateIntegrity(), "Founder Garage entity registry is incomplete")
    cameraController.configureWalkability { [weak self] point in self?.isCameraPointWalkable(point) ?? false }
  }

  deinit {
    assetLoadTask?.cancel()
    architectureLoadTask?.cancel()
    accessibilityActivationSubscription?.cancel()
    cameraUpdateSubscription?.cancel()
  }

  func attachRoot(using add: (Entity) -> Void) {
    add(entities.root)
    diagnostics.attachmentCount += 1
  }

  func apply(
    _ presentation: FounderWorldPresentationModel,
    interactionFeedback: GarageInteractionFeedbackState = .unavailable,
    chairInteractionFeedback: GarageInteractionFeedbackState = .unavailable,
    whiteboardInteractionFeedback: GarageInteractionFeedbackState = .unavailable,
    reduceMotion: Bool = false
  ) {
    let computerEnabled = presentation.founderComputerAvailable && presentation.cameraState.allowsComputer
    let effectiveFeedback = computerEnabled ? interactionFeedback : .unavailable
    let chairActivationIsValid = chairInteractionFeedback == .activated
      && chairActivationFeedbackPermitted
    let effectiveChairFeedback = chairInteractionAvailable || chairActivationIsValid
      ? chairInteractionFeedback
      : .unavailable
    let whiteboardActivationIsValid = whiteboardInteractionFeedback == .activated
      && whiteboardActivationFeedbackPermitted
    let effectiveWhiteboardFeedback = whiteboardObservationAvailable || whiteboardActivationIsValid
      ? whiteboardInteractionFeedback
      : .unavailable
    guard presentation != lastPresentation
            || reduceMotion != lastReduceMotion
            || effectiveFeedback != computerInteractionFeedbackState
            || effectiveChairFeedback != chairInteractionFeedbackState
            || effectiveWhiteboardFeedback != whiteboardInteractionFeedbackState
    else { return }
    diagnostics.presentationApplicationCount += 1
    cameraController.transition(to: presentation.cameraState, reduceMotion: reduceMotion)
    applyRuntimeEnclosureVisibility(for: presentation.cameraState)
    entities.founderComputerInteractionTarget.isEnabled = computerEnabled

    if lastPresentation?.computerGlowIntensity != presentation.computerGlowIntensity
        || effectiveFeedback != computerInteractionFeedbackState
        || reduceMotion != lastReduceMotion {
      updateFounderComputerEmphasis(
        glow: Float(presentation.computerGlowIntensity),
        state: effectiveFeedback,
        reduceMotion: reduceMotion
      )
    }

    if effectiveChairFeedback != chairInteractionFeedbackState
        || reduceMotion != lastReduceMotion {
      updateChairEmphasis(state: effectiveChairFeedback, reduceMotion: reduceMotion)
    }

    if effectiveWhiteboardFeedback != whiteboardInteractionFeedbackState
        || reduceMotion != lastReduceMotion {
      updateWhiteboardEmphasis(state: effectiveWhiteboardFeedback, reduceMotion: reduceMotion)
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
    computerInteractionFeedbackState = effectiveFeedback
    chairInteractionFeedbackState = effectiveChairFeedback
    whiteboardInteractionFeedbackState = effectiveWhiteboardFeedback
    if chairInteractionFeedback != .activated {
      chairActivationFeedbackPermitted = false
    }
    if whiteboardInteractionFeedback != .activated {
      whiteboardActivationFeedbackPermitted = false
    }
  }

  var founderComputerInteractionAvailable: Bool {
    cameraController.state.allowsComputer
      && cameraController.playerSpatialState.navigationMode == .seated
      && entities.founderComputerInteractionTarget.isEnabled
  }

  var chairInteractionAvailable: Bool {
    interactionCoordinator.chairTarget != nil
      && interactionCoordinator.phase == .idle
      && cameraController.playerSpatialState.navigationMode == .walking
  }

  var whiteboardObservationAvailable: Bool {
    whiteboardInteractionTarget != nil
      && interactionCoordinator.phase == .idle
      && cameraController.state == .founderPOV
      && cameraController.playerSpatialState.navigationMode == .walking
  }

  var whiteboardInteractionFocused: Bool {
    guard whiteboardObservationAvailable,
          let target = whiteboardInteractionTarget
    else { return false }
    let pose = cameraController.playerSpatialState.playerPose
    let delta = SIMD2<Float>(
      pose.position.x - target.interaction.position.x,
      pose.position.z - target.interaction.position.z
    )
    let targetHeading = atan2(
      target.interaction.facingDirection.x,
      -target.interaction.facingDirection.z
    )
    let yawError = abs(atan2(sin(targetHeading - pose.heading), cos(targetHeading - pose.heading)))
    return simd_length(delta) <= target.positionToleranceMeters
      && yawError <= target.facingToleranceRadians
  }

  private var whiteboardInteractionTarget: FounderInteractionTargetContract? {
    spatialSpecification.facilityTier0InteractionSpace?
      .founderInteractionTarget(for: .whiteboard)
  }

  func interaction(for entity: Entity) -> FounderWorldInteraction? {
    guard cameraController.state.allowsComputer,
          cameraController.playerSpatialState.navigationMode == .seated
    else { return nil }
    var candidate: Entity? = entity
    while let current = candidate {
      if current.id == entities.founderComputerInteractionTarget.id,
         entities.founderComputerInteractionTarget.isEnabled {
        return .openFounderComputer
      }
      if current.id == entities.iPhone.id, entities.iPhone.isEnabled {
        return .openFounderPhone
      }
      if current.id == entities.iPad.id, entities.iPad.isEnabled {
        return .openFounderTablet
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

  func subscribeToCameraUpdates(_ install: (@escaping (SceneEvents.Update) -> Void) -> EventSubscription) {
    guard cameraUpdateSubscription == nil else { return }
    cameraUpdateSubscription = install { [weak self] event in
      guard let self else { return }
      advanceSession(deltaTime: event.deltaTime)
      requestAtlantisTraversalIfNeeded()
    }
  }

  func advanceSession(deltaTime: TimeInterval) {
    interactionCoordinator.prepareFrame(camera: cameraController, deltaTime: deltaTime)
    cameraController.advance(deltaTime: deltaTime)
    let snapshot = cameraController.snapshot
    recordTraversalDiagnostics(snapshot, deltaTime: deltaTime)
    if !isFounderPresentedInAtlantis {
      founderAvatarController.locomotion.update(
        spatial: cameraController.spatialState,
        collisionBlocked: snapshot.collision == "blocked",
        firstPerson: cameraController.usesFirstPersonPresentation,
        reduceMotion: snapshot.reduceMotion,
        deltaTime: deltaTime
      )
    }
    interactionCoordinator.completeFrame(
      camera: cameraController,
      locomotion: founderAvatarController.locomotion
    )
  }

  @discardableResult
  func requestChairInteraction(reduceMotion: Bool = false) -> Bool {
    let succeeded = interactionCoordinator.requestChairInteraction(
      camera: cameraController,
      reduceMotion: reduceMotion
    )
    if succeeded { chairActivationFeedbackPermitted = true }
    return succeeded
  }

  @discardableResult
  func requestWhiteboardObservation() -> Bool {
    guard whiteboardInteractionFocused else { return false }
    whiteboardActivationFeedbackPermitted = true
    return true
  }

  @discardableResult
  func requestChairExit(reduceMotion: Bool = false) -> Bool {
    interactionCoordinator.requestChairExit(
      camera: cameraController,
      reduceMotion: reduceMotion
    )
  }

  func cancelChairInteraction() {
    interactionCoordinator.cancel(camera: cameraController)
  }

  func configureAtlantisTraversal(
    _ handler: @escaping (FounderAtlantisTraversalHandoff) -> Void
  ) {
    onAtlantisBoundaryCrossing = handler
  }

  func transferFounderPresentation(
    to atlantis: AtlantisRealityWorld,
    reduceMotion: Bool
  ) {
    guard !isFounderPresentedInAtlantis else { return }
    isFounderPresentedInAtlantis = true
    atlantis.installFounderPresentation(
      rig: activeFounderVisualAdapter.rig,
      locomotion: founderAvatarController.locomotion,
      reduceMotion: reduceMotion
    )
  }

  func restoreFounderPresentation(from atlantis: AtlantisRealityWorld) {
    guard isFounderPresentedInAtlantis else { return }
    atlantis.removeFounderPresentation()
    entities.root.addChild(activeFounderVisualAdapter.rig.anchor)
    isFounderPresentedInAtlantis = false
    restoreFromAtlantis()
    founderAvatarController.locomotion.update(
      spatial: cameraController.spatialState,
      collisionBlocked: false,
      firstPerson: false,
      reduceMotion: false,
      deltaTime: TimeInterval(FounderGarageCameraConfiguration.fixedStep)
    )
  }

  func restoreFromAtlantis() {
    didRequestAtlantisTraversal = false
    let approach = spatialSpecification.interactionApproaches.garageDoor.approach
    cameraController.consume(.init(
      bodyPosition: approach.position,
      bodyHeading: atan2(approach.facingDirection.x, -approach.facingDirection.z),
      locomotionVelocity: .zero,
      stepPhase: nil,
      stance: .standing
    ))
  }

  func requestAtlantisTraversalIfNeeded() {
    guard !didRequestAtlantisTraversal,
          garageDoorState.isOpen,
          cameraController.playerSpatialState.navigationMode == .walking,
          cameraController.playerSpatialState.playerPose.position.z >= Self.atlantisHandoffThresholdZ,
          let onAtlantisBoundaryCrossing
    else { return }
    didRequestAtlantisTraversal = true
    if ProcessInfo.processInfo.arguments.contains("--founder-traversal-diagnostics") {
      print("TRAVERSAL_DIAG event=handoff-requested")
    }
    onAtlantisBoundaryCrossing(.init(
      garagePosition: cameraController.playerSpatialState.playerPose.position,
      facingDirection: cameraController.spatialState.facingDirection
    ))
    // The covered Garage remains alive. Park its session-only player at the
    // authored interior approach so dismissal resumes a coherent return path.
    restoreFromAtlantis()
  }

  func stopCameraUpdates() {
    cameraUpdateSubscription?.cancel()
    cameraUpdateSubscription = nil
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

  private func isCameraPointWalkable(_ point: SIMD2<Float>) -> Bool {
    let radius = FounderGarageCameraConfiguration.playerRadius
    let offsets: [SIMD2<Float>] = [.zero, [radius, 0], [-radius, 0], [0, radius], [0, -radius]]
    if offsets.allSatisfy({ isPointWalkable(point + $0) }) { return true }
    guard garageDoorState.isOpen, let door = spatialSpecification.productionAnchors?.doorMouth else { return false }
    let corridorHalfWidth: Float = 1.35
    let exteriorLimit = Self.atlantisHandoffThresholdZ + radius
    // Overlap the corridor with the radius-inset interior boundary. Without the
    // overlap, small fixed-step movement can stop in the gap at the threshold.
    let corridorStart = door.z - radius * 2
    return abs(point.x - door.x) <= corridorHalfWidth && point.y >= corridorStart && point.y <= exteriorLimit
  }

  private func recordTraversalDiagnostics(
    _ snapshot: FounderGarageCameraController.Snapshot,
    deltaTime: TimeInterval
  ) {
    guard ProcessInfo.processInfo.arguments.contains("--founder-traversal-diagnostics") else { return }
    traversalDiagnosticsElapsed += deltaTime
    let crossing = snapshot.playerPosition.z >= Self.atlantisHandoffThresholdZ
    let eligible = garageDoorState.isOpen && snapshot.mode == "walking" && crossing
    let signature = String(
      format: "%@|%.2f|%.2f|%@|%@|%@",
      snapshot.mode,
      snapshot.movementIntent.x,
      snapshot.movementIntent.y,
      snapshot.collision,
      garageDoorState.accessibilityValue,
      String(crossing)
    )
    guard traversalDiagnosticsElapsed >= 0.25 || signature != traversalDiagnosticsSignature else { return }
    traversalDiagnosticsElapsed = 0
    traversalDiagnosticsSignature = signature
    print(String(
      format: "TRAVERSAL_DIAG mode=%@ player=%.3f,%.3f,%.3f camera=%.3f,%.3f,%.3f yaw=%.4f lookYaw=%.4f input=%.3f,%.3f world=%.3f,%.3f velocity=%.3f,%.3f collision=%@ door=%@ crossing=%@ eligible=%@ garageLoad=%@",
      snapshot.mode,
      snapshot.playerPosition.x, snapshot.playerPosition.y, snapshot.playerPosition.z,
      snapshot.position.x, snapshot.position.y, snapshot.position.z,
      snapshot.bodyHeading, snapshot.lookYaw,
      snapshot.movementIntent.x, snapshot.movementIntent.y,
      snapshot.worldMovementVector.x, snapshot.worldMovementVector.y,
      snapshot.velocity.x, snapshot.velocity.z,
      snapshot.collision,
      garageDoorState.accessibilityValue,
      String(crossing), String(eligible), String(describing: architectureLoadState)
    ))
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
    cacheImportedMonitorBaseline()
    cacheImportedChairBaseline()
    cacheImportedWhiteboardBaseline()
    cameraController.usesV7ExteriorViews = adapter.source == .bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName)
      || adapter.source == .bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName)
    configureGarageDoorAnimation()
    configureExteriorPracticalLight()
    try configureEnvironmentLight()
    cameraController.alignFounderMonitorTowardSeatedEye(in: adapter.rig.visualRoot)
    cameraController.cacheDisplayFrame(in: adapter.rig.visualRoot)
    applyRuntimeEnclosureVisibility(for: cameraController.state)
    setProceduralEnvironmentVisible(adapter.source == .procedural)
    updateRoomLighting(for: lastPresentation?.roomLightIntensity ?? 1)
    updateFounderComputerEmphasis(
      glow: Float(lastPresentation?.computerGlowIntensity ?? 0.52),
      state: computerInteractionFeedbackState,
      reduceMotion: lastReduceMotion
    )
    updateChairEmphasis(
      state: chairInteractionFeedbackState,
      reduceMotion: lastReduceMotion
    )
    updateWhiteboardEmphasis(
      state: whiteboardInteractionFeedbackState,
      reduceMotion: lastReduceMotion
    )
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
         .bundledProductionAsset(name: "founder_garage_v7"),
         .bundledProductionAsset(name: "founder_garage_v8"):
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
    // The production V8 scene has no canonical phone or tablet. Its side device is
    // an authored hinged laptop, so keep the stable interactive desk devices live
    // in both procedural and imported architectures and suppress only that laptop.
    entities.iPhone.isEnabled = true
    entities.iPad.isEnabled = true
    activeGarageArchitectureAdapter.rig.visualRoot
      .findEntity(named: "FounderLaptop")?.isEnabled = isVisible
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

  private func cacheImportedMonitorBaseline() {
    importedMonitorBaseline = nil
    guard activeGarageArchitectureAdapter.source != .procedural,
          let screen = activeGarageArchitectureAdapter.rig.visualRoot.findEntity(named: "Monitor_Screen"),
          let model = screen.components[ModelComponent.self],
          let material = model.materials.first as? PhysicallyBasedMaterial
    else { return }
    importedMonitorBaseline = (screen, material)
  }

  private func cacheImportedChairBaseline() {
    importedChairBaseline = nil
    guard activeGarageArchitectureAdapter.source != .procedural,
          let seat = activeGarageArchitectureAdapter.rig.visualRoot.findEntity(named: "Chair_Seat"),
          let model = seat.components[ModelComponent.self]
    else { return }
    importedChairBaseline = (seat, model)
  }

  private func cacheImportedWhiteboardBaseline() {
    importedWhiteboardBaseline = nil
    guard activeGarageArchitectureAdapter.source != .procedural,
          let face = activeGarageArchitectureAdapter.rig.visualRoot.findEntity(named: "Whiteboard_Surface"),
          let model = face.components[ModelComponent.self]
    else { return }
    importedWhiteboardBaseline = (face, model)
  }

  private func updateChairEmphasis(
    state: GarageInteractionFeedbackState,
    reduceMotion: Bool
  ) {
    let emphasis = GarageInteractionVisualEmphasis.resolve(state: state, reduceMotion: reduceMotion)
    let lift = max(emphasis.targetIntensityScale - 0.82, 0)
    if activeGarageArchitectureAdapter.source == .procedural {
      let color = UIColor(
        red: 0.08 + CGFloat(lift) * 0.05,
        green: 0.09 + CGFloat(lift) * 0.18,
        blue: 0.11 + CGFloat(lift) * 0.28,
        alpha: 1
      )
      for child in entities.chair.children {
        guard var model = child.components[ModelComponent.self] else { continue }
        model.materials = [Self.material(color, roughness: 0.72)]
        child.components.set(model)
      }
      return
    }

    guard let baseline = importedChairBaseline else { return }
    var model = baseline.model
    for index in model.materials.indices {
      guard var material = model.materials[index] as? PhysicallyBasedMaterial else { continue }
      var emissive = material.emissiveColor
      emissive.color = UIColor(
        red: 0.02,
        green: 0.10 + CGFloat(lift) * 0.20,
        blue: 0.13 + CGFloat(lift) * 0.34,
        alpha: 1
      )
      material.emissiveColor = emissive
      let baselineIntensity = (baseline.model.materials[index] as? PhysicallyBasedMaterial)?
        .emissiveIntensity ?? 0
      material.emissiveIntensity = baselineIntensity + lift * 0.22
      model.materials[index] = material
    }
    baseline.entity.components.set(model)
  }

  private func updateWhiteboardEmphasis(
    state: GarageInteractionFeedbackState,
    reduceMotion: Bool
  ) {
    let emphasis = GarageInteractionVisualEmphasis.resolve(state: state, reduceMotion: reduceMotion)
    let lift = max(emphasis.targetIntensityScale - 0.82, 0)
    if activeGarageArchitectureAdapter.source == .procedural {
      // The simplified fallback has no C1 Whiteboard mesh. Do not repurpose the
      // semantically distinct FundingBoard merely to manufacture an emphasis.
      return
    }

    guard let baseline = importedWhiteboardBaseline else { return }
    var model = baseline.model
    for index in model.materials.indices {
      guard var material = model.materials[index] as? PhysicallyBasedMaterial else { continue }
      var emissive = material.emissiveColor
      emissive.color = UIColor(
        red: 0.72,
        green: 0.88,
        blue: 0.92,
        alpha: 1
      )
      material.emissiveColor = emissive
      let baselineIntensity = (baseline.model.materials[index] as? PhysicallyBasedMaterial)?
        .emissiveIntensity ?? 0
      material.emissiveIntensity = baselineIntensity + lift * 0.12
      model.materials[index] = material
    }
    baseline.entity.components.set(model)
  }

  private func updateFounderComputerEmphasis(
    glow: Float,
    state: GarageInteractionFeedbackState,
    reduceMotion: Bool
  ) {
    let emphasis = GarageInteractionVisualEmphasis.resolve(state: state, reduceMotion: reduceMotion)
    if activeGarageArchitectureAdapter.source == .procedural {
      let scaledGlow = min(max(glow * emphasis.screenIntensityScale, 0), 1.35)
      entities.founderComputerInteractionTarget.model?.materials = [Self.material(
        UIColor(
          red: 0.04,
          green: 0.38 + CGFloat(scaledGlow) * 0.24,
          blue: 0.56 + CGFloat(scaledGlow) * 0.24,
          alpha: 1
        ),
        roughness: 0.16,
        metallic: true
      )]
      return
    }

    entities.founderComputerInteractionTarget.model?.materials = [Self.material(
      UIColor(red: 0.04, green: 0.62, blue: 0.82, alpha: 0.001),
      roughness: 0.16,
      metallic: true
    )]
    guard let baseline = importedMonitorBaseline,
          var model = baseline.entity.components[ModelComponent.self]
    else { return }
    var material = baseline.material
    material.emissiveIntensity = baseline.material.emissiveIntensity * emphasis.screenIntensityScale
    guard !model.materials.isEmpty else { return }
    model.materials[0] = material
    baseline.entity.components.set(model)
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
    root.findEntity(named: FounderGarageV8AssetContract.rightSideDoorEntityName)?.isEnabled = !usesOverviewCutaway
    root.findEntity(named: "Ceiling")?.isEnabled = !usesOverviewCutaway
  }

  private func configureEnvironmentLight() throws {
    environmentLight.removeFromParent()
    guard activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName)
      || activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName)
    else { return }
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
    guard activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName)
            || activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName),
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
      || activeGarageArchitectureAdapter.source == .bundledProductionAsset(name: "founder_garage_v8")
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
  func requestProductionFounder() throws -> Task<Void, Never>? {
    try FounderCharacterContract.validateAcceptedRuntimeAsset()
    return requestFounderVisual(
      .bundledUSDZ(name: FounderCharacterContract.candidateResource),
      descriptor: try FounderCharacterContract.productionDescriptor(spatial: spatialSpecification)
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
    founderAvatarController.install(
      rig: adapter.rig,
      firstPerson: cameraController.usesFirstPersonPresentation
    )
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
    let iPhone = addBox(name: FounderWorldInteractionAdapter.founderPhoneEntityName, size: spatial.workstation.iPhoneSize, position: spatial.anchors.iPhone.position, color: .deviceGlass, roughness: 0.12, metallic: true, to: devices)
    configureDeskDevice(
      iPhone,
      size: spatial.workstation.iPhoneSize,
      screenName: "FounderPhone.Screen",
      screenColor: UIColor(red: 0.07, green: 0.52, blue: 0.68, alpha: 1),
      accessibilityLabel: FounderWorldInteractionAdapter.founderPhoneAccessibilityLabel
    )
    let iPad = addBox(name: FounderWorldInteractionAdapter.founderTabletEntityName, size: spatial.workstation.iPadSize, position: spatial.anchors.iPad.position, color: .deviceGlass, roughness: 0.12, metallic: true, to: devices)
    configureDeskDevice(
      iPad,
      size: spatial.workstation.iPadSize,
      screenName: "FounderTablet.Screen",
      screenColor: UIColor(red: 0.11, green: 0.39, blue: 0.62, alpha: 1),
      accessibilityLabel: FounderWorldInteractionAdapter.founderTabletAccessibilityLabel
    )
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

  private static func configureDeskDevice(
    _ device: ModelEntity,
    size: SIMD3<Float>,
    screenName: String,
    screenColor: UIColor,
    accessibilityLabel: String
  ) {
    device.components.set(InputTargetComponent())
    device.generateCollisionShapes(recursive: false)

    var accessibility = AccessibilityComponent()
    accessibility.isAccessibilityElement = true
    accessibility.label = LocalizedStringResource(stringLiteral: accessibilityLabel)
    accessibility.traits = [.button]
    accessibility.systemActions = [.activate]
    device.components.set(accessibility)

    let screen = ModelEntity(
      mesh: .generateBox(size: [size.x - 0.018, 0.0025, size.z - 0.018]),
      materials: [UnlitMaterial(color: screenColor)]
    )
    screen.name = screenName
    screen.position = [0, size.y / 2 + 0.00125, 0]
    device.addChild(screen)
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
enum FounderGarageCameraTransitionClass: String, Equatable, Sendable {
  case shortPhysical, mediumPhysical, largeFade
}

struct FounderGarageMovementIntent: Equatable, Sendable {
  var lateral: Float = 0
  var forward: Float = 0
  static let idle = Self()
}

struct FounderGarageCameraConfiguration {
  let spatial: FounderGarageSpatialSpecification
  var usesV7ExteriorViews = false
  static let transitionDuration: TimeInterval = 0.30
  static let seatedEyeOffset = SIMD3<Float>(0, 1.18, 0)
  static let seatedEyeHeight = seatedEyeOffset.y
  static let yawLimits: ClosedRange<Float> = (-175 * .pi / 180)...(175 * .pi / 180)
  // V3 is an open-ceiling cutaway; tighter vertical bounds keep authored
  // Garage context visible instead of filling the viewport with void or floor.
  static let pitchLimits: ClosedRange<Float> = (-18 * .pi / 180)...(12 * .pi / 180)
  // Express drag response as a fraction of the active viewport so the same
  // gesture covers the same angle on iPhone and iPad.
  static let dragYawRadiansPerViewport: Float = .pi * 0.85

  static func dragSensitivityRadiansPerPoint(viewportWidth: Float) -> Float {
    dragYawRadiansPerViewport / max(viewportWidth, 1)
  }
  static let standingEyeHeight: Float = 1.66
  static let walkingSpeed: Float = 1.22
  static let linearAcceleration: Float = 4.8
  static let linearDeceleration: Float = 6.4
  static let lookResponse: Float = 10
  static let maximumAngularSpeed: Float = 2.2
  static let angularAcceleration: Float = 9.5
  static let maximumDeltaTime: Float = 0.10
  static let fixedStep: Float = 1 / 120
  static let shortTransitionDuration: TimeInterval = 0.28
  static let mediumTransitionDuration: TimeInterval = 0.42
  static let playerRadius: Float = 0.23

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

  func transitionClass(from: FounderGarageCameraState, to: FounderGarageCameraState) -> FounderGarageCameraTransitionClass {
    guard from != to else { return .shortPhysical }
    if from == .garageOverview || to == .garageOverview || from == .garageDoor || to == .garageDoor || from == .front || to == .front { return .largeFade }
    if from == .frontBay || to == .frontBay { return .mediumPhysical }
    return .shortPhysical
  }

  func interactionRecipe(for target: FounderGarageInteractionFocusTarget) -> FounderGarageCameraRecipe {
    let eye = seatedPlayerState.eyePosition
    let lookTarget: SIMD3<Float>
    let position: SIMD3<Float>
    let fov: Float
    switch target {
    case .computer:
      position = eye; lookTarget = spatial.anchors.founderComputer.position; fov = 54
    case .phone:
      position = eye + [0, -0.015, -0.025]; lookTarget = spatial.anchors.iPhone.position; fov = 52
    case .tablet:
      position = eye + [0, -0.01, -0.02]; lookTarget = spatial.anchors.iPad.position; fov = 52
    case .strategyBoard:
      position = eye; lookTarget = spatial.anchors.fundingBoard.position; fov = 54
    case .signalTV:
      position = eye; lookTarget = spatial.anchors.signalTV.position; fov = 55
    case .server:
      position = eye; lookTarget = spatial.productionAnchors?.agentDeskSurface ?? spatial.anchors.desk.position; fov = 55
    }
    return FounderGarageCameraRecipe(position: position, lookTarget: lookTarget, fieldOfView: fov, duration: Self.shortTransitionDuration)
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
  struct Snapshot {
    var mode: String
    var position: SIMD3<Float>
    var playerPosition: SIMD3<Float>
    var bodyHeading: Float
    var lookYaw: Float
    var movementIntent: SIMD2<Float>
    var worldMovementVector: SIMD2<Float>
    var velocity: SIMD3<Float>
    var angularVelocity: SIMD2<Float>
    var target: FounderLookOrientation
    var collision: String
    var transition: FounderGarageCameraTransitionClass?
    var founderPOVDriftError: Float
    var interactionFocus: FounderGarageInteractionFocusTarget?
    var reduceMotion: Bool
  }
  private struct InteractionFocusReturn {
    var state: FounderGarageCameraState
    var playerSpatialState: FounderGaragePlayerSpatialState
    var cameraTransform: Transform
    var fieldOfView: Float
    var founderObservationActive: Bool
  }
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
  private var targetLook = FounderLookOrientation.neutral
  private var movementIntent = FounderGarageMovementIntent.idle
  private var velocity = SIMD3<Float>.zero
  private var angularVelocity = SIMD2<Float>.zero
  private var transitionStart: Transform?
  private var transitionTarget: Transform?
  private var transitionElapsed: Float = 0
  private var transitionDuration: Float = 0
  private var transitionStartFOV: Float = 56
  private var transitionTargetFOV: Float = 56
  private var activeTransition: FounderGarageCameraTransitionClass?
  private var interactionFocusReturn: InteractionFocusReturn?
  private(set) var interactionFocusTarget: FounderGarageInteractionFocusTarget?
  private var walkability: ((SIMD2<Float>) -> Bool)?
  private var lastCollision = "none"
  private var reduceMotionActive = false
  private(set) var founderObservationActive = false
  private var seatingTransitionActive = false
  var usesV7ExteriorViews = false
  private(set) var displayCorners: [SIMD3<Float>] = []

  var usesFirstPersonPresentation: Bool {
    playerSpatialState.navigationMode != .walking && !seatingTransitionActive
  }

  init(camera: PerspectiveCamera, spatial: FounderGarageSpatialSpecification) {
    self.camera = camera
    self.spatial = spatial
    playerSpatialState = FounderGarageCameraConfiguration(spatial: spatial).seatedPlayerState
    applySeatedCameraTransform()
  }
  func recipe(for state: FounderGarageCameraState) -> FounderGarageCameraRecipe {
    authoredRecipe(for: state)
  }

  private func authoredRecipe(for state: FounderGarageCameraState) -> FounderGarageCameraRecipe {
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
    guard state == .founderPOV,
          playerSpatialState.navigationMode == .seated || playerSpatialState.navigationMode == .walking
    else { return }
    targetLook = FounderGarageCameraConfiguration(spatial: spatial).clamped(requested)
    if reduceMotionActive { playerSpatialState.lookOrientation = targetLook; angularVelocity = .zero; applySeatedCameraTransform() }
    diagnostics.freeLookApplicationCount += 1
  }

  func recenterFounderPOV(reduceMotion: Bool = false) {
    guard state == .founderPOV else { return }
    founderObservationActive = playerSpatialState.navigationMode == .walking
    targetLook = .neutral
    if reduceMotion { playerSpatialState.lookOrientation = .neutral; angularVelocity = .zero; applySeatedCameraTransform() }
    diagnostics.recenterCount += 1
  }

  func transition(to requested: FounderGarageCameraState, reduceMotion: Bool) {
    diagnostics.requestCount += 1
    diagnostics.lastRequested = requested
    guard requested != state || lastReducedMotion == nil || interactionFocusTarget != nil else { return }
    cancelTransientMotion(countInterruption: true)
    seatingTransitionActive = false
    if requested == .founderPOV {
      playerSpatialState.navigationMode = .seated
      playerSpatialState.lookOrientation = .neutral
    } else {
      playerSpatialState.navigationMode = .authoredInspection(requested)
      playerSpatialState.lookOrientation = .neutral
    }
    let previous = state
    state = requested
    founderObservationActive = false
    lastReducedMotion = reduceMotion
    reduceMotionActive = reduceMotion
    targetLook = .neutral
    let kind = FounderGarageCameraConfiguration(spatial: spatial).transitionClass(from: previous, to: requested)
    let destination = presentationRecipe(for: requested)
    if !reduceMotion && kind != .largeFade {
      startTransition(to: destination, kind: kind)
    } else {
      applyCurrentCameraTransform()
    }
    diagnostics.applicationCount += 1
    diagnostics.lastApplied = requested
  }

  func configureWalkability(_ accepts: @escaping (SIMD2<Float>) -> Bool) { walkability = accepts }

  func beginWalking(reduceMotion: Bool = false) {
    guard state == .founderPOV else { return }
    cancelTransientMotion(countInterruption: true)
    seatingTransitionActive = false
    playerSpatialState.navigationMode = .walking
    playerSpatialState.eyeOffset.y = FounderGarageCameraConfiguration.standingEyeHeight
    let clearPathTarget = spatial.interactionApproaches.garageDoor.approach.position
    playerSpatialState.playerPose.position = nearestWalkableStandingPosition(
      to: playerSpatialState.playerPose.position,
      withClearPathTo: clearPathTarget
    )
    let door = spatial.productionAnchors?.doorMouth ?? spatial.architecture.garageDoor.position
    let directionToDoor = SIMD2<Float>(
      door.x - playerSpatialState.playerPose.position.x,
      door.z - playerSpatialState.playerPose.position.z
    )
    if simd_length_squared(directionToDoor) > 0.0001 {
      // Explore begins facing the Garage exit so the primary forward gesture has
      // a clear, discoverable path into Atlantis.
      playerSpatialState.playerPose.heading = atan2(directionToDoor.x, -directionToDoor.y)
    }
    reduceMotionActive = reduceMotion
    velocity = .zero
    founderObservationActive = true
    let observation = founderObservationRecipe()
    camera.transform = observation.transform
    camera.camera.fieldOfViewInDegrees = observation.fieldOfView
  }

  /// Installs an authored standing endpoint for interaction choreography while
  /// retaining camera ownership of the canonical player transform.
  @discardableResult
  func beginInteractionStanding(
    at pose: FounderGarageSpatialPose,
    reduceMotion: Bool = false
  ) -> Bool {
    guard state == .founderPOV,
          pose.position.x.isFinite, pose.position.y.isFinite, pose.position.z.isFinite,
          pose.facingDirection.x.isFinite, pose.facingDirection.z.isFinite,
          walkability?([pose.position.x, pose.position.z]) ?? true
    else { return false }
    cancelTransientMotion(countInterruption: true)
    seatingTransitionActive = false
    playerSpatialState.navigationMode = .walking
    playerSpatialState.playerPose = FounderPlayerPose(
      position: pose.position,
      heading: atan2(pose.facingDirection.x, -pose.facingDirection.z)
    )
    playerSpatialState.eyeOffset.y = FounderGarageCameraConfiguration.standingEyeHeight
    playerSpatialState.lookOrientation = .neutral
    targetLook = .neutral
    reduceMotionActive = reduceMotion
    founderObservationActive = true
    applySeatedCameraTransform()
    return true
  }

  /// Applies only a bounded correction requested by interaction choreography.
  /// Collision validation and the resulting player pose remain camera-owned.
  func alignStandingPlayer(
    toward pose: FounderGarageSpatialPose,
    maximumTranslation: Float,
    maximumRotation: Float
  ) -> (translation: Float, rotation: Float, valid: Bool) {
    guard playerSpatialState.navigationMode == .walking,
          maximumTranslation.isFinite, maximumTranslation >= 0,
          maximumRotation.isFinite, maximumRotation >= 0
    else { return (0, 0, false) }
    let current = playerSpatialState.playerPose
    let planarDelta = SIMD2<Float>(pose.position.x - current.position.x, pose.position.z - current.position.z)
    let distance = simd_length(planarDelta)
    let translation = min(distance, maximumTranslation)
    var nextPosition = current.position
    if distance > 0.000001 {
      let step = planarDelta / distance * translation
      nextPosition.x += step.x
      nextPosition.z += step.y
    }
    guard walkability?([nextPosition.x, nextPosition.z]) ?? true else {
      return (0, 0, false)
    }
    let targetHeading = atan2(pose.facingDirection.x, -pose.facingDirection.z)
    let yawDelta = atan2(sin(targetHeading - current.heading), cos(targetHeading - current.heading))
    let rotation = min(abs(yawDelta), maximumRotation)
    let signedRotation = min(max(yawDelta, -maximumRotation), maximumRotation)
    playerSpatialState.playerPose.position = nextPosition
    playerSpatialState.playerPose.heading += signedRotation
    velocity = .zero
    applySeatedCameraTransform()
    return (translation, rotation, true)
  }

  /// The seated anchor overlaps the authored chair collision volume. Resolve the
  /// standing endpoint to the nearest deterministic free sample before accepting
  /// movement so collision cannot trap the Founder inside the chair.
  private func nearestWalkableStandingPosition(
    to origin: SIMD3<Float>,
    withClearPathTo target: SIMD3<Float>
  ) -> SIMD3<Float> {
    guard let walkability else { return origin }
    let angularSamples = 24
    var nearestFallback: SIMD3<Float>?
    for radius in stride(from: Float(0.45), through: 1.20, by: 0.05) {
      for index in 0..<angularSamples {
        // Search toward the room center/front first, then around the chair.
        let angle = Float(index) * 2 * .pi / Float(angularSamples)
        let point = SIMD2<Float>(
          origin.x + sin(angle) * radius,
          origin.z + cos(angle) * radius
        )
        guard walkability(point) else { continue }
        let candidate = SIMD3<Float>(point.x, origin.y, point.y)
        if nearestFallback == nil { nearestFallback = candidate }
        if straightPathIsWalkable(from: candidate, to: target, walkability: walkability) {
          return candidate
        }
      }
    }
    return nearestFallback ?? origin
  }

  private func straightPathIsWalkable(
    from start: SIMD3<Float>,
    to target: SIMD3<Float>,
    walkability: (SIMD2<Float>) -> Bool
  ) -> Bool {
    let start2D = SIMD2<Float>(start.x, start.z)
    let target2D = SIMD2<Float>(target.x, target.z)
    let distance = simd_distance(start2D, target2D)
    let samples = max(1, Int(ceil(distance / 0.08)))
    return (1...samples).allSatisfy { index in
      let progress = Float(index) / Float(samples)
      return walkability(start2D + (target2D - start2D) * progress)
    }
  }

  func endWalking(
    reduceMotion: Bool = false,
    keepFounderVisible: Bool = false
  ) {
    cancelTransientMotion(countInterruption: false)
    playerSpatialState = FounderGarageCameraConfiguration(spatial: spatial).seatedPlayerState
    targetLook = .neutral
    reduceMotionActive = reduceMotion
    seatingTransitionActive = keepFounderVisible
    founderObservationActive = keepFounderVisible
    applySeatedCameraTransform()
  }

  /// Completes the visible chair choreography before entering the eye camera.
  /// Until this point the Founder remains visible from third person while the
  /// locomotion graph resolves the authored sitting animation.
  func completeSeatingTransition() {
    guard seatingTransitionActive else { return }
    seatingTransitionActive = false
    founderObservationActive = false
    applySeatedCameraTransform()
  }

  func setMovementIntent(_ intent: FounderGarageMovementIntent) {
    movementIntent = intent
  }

  func nudge(lateral: Float, forward: Float, reduceMotion: Bool) {
    guard playerSpatialState.navigationMode == .walking else { return }
    setMovementIntent(.init(lateral: lateral, forward: forward))
    advance(deltaTime: reduceMotion ? 0.08 : 0.18)
    setMovementIntent(.idle)
  }

  func consume(_ sample: FounderLocomotionCameraSample) {
    playerSpatialState.playerPose = .init(position: sample.bodyPosition, heading: sample.bodyHeading)
    playerSpatialState.eyeOffset.y = sample.stance == .seated ? FounderGarageCameraConfiguration.seatedEyeHeight : FounderGarageCameraConfiguration.standingEyeHeight
    velocity = sample.locomotionVelocity
    applySeatedCameraTransform()
  }

  @discardableResult
  func focus(on target: FounderGarageInteractionFocusTarget, reduceMotion: Bool = false) -> Bool {
    guard playerSpatialState.navigationMode != .walking else { return false }
    if interactionFocusReturn == nil {
      interactionFocusReturn = InteractionFocusReturn(
        state: state,
        playerSpatialState: playerSpatialState,
        cameraTransform: camera.transform,
        fieldOfView: camera.camera.fieldOfViewInDegrees,
        founderObservationActive: founderObservationActive
      )
    } else if activeTransition != nil {
      diagnostics.interruptedCount += 1
    }
    transitionStart = nil; transitionTarget = nil; activeTransition = nil
    interactionFocusTarget = target
    founderObservationActive = false
    playerSpatialState.navigationMode = .interactionFocus(target)
    reduceMotionActive = reduceMotion
    let focusRecipe = FounderGarageCameraConfiguration(spatial: spatial).interactionRecipe(for: target)
    if reduceMotion { camera.transform = focusRecipe.transform; camera.camera.fieldOfViewInDegrees = focusRecipe.fieldOfView }
    else { startTransition(to: focusRecipe, kind: .shortPhysical) }
    return true
  }

  @discardableResult
  func restoreInteractionFocus(reduceMotion: Bool = false) -> Bool {
    guard let restore = interactionFocusReturn else { return false }
    if activeTransition != nil { diagnostics.interruptedCount += 1 }
    interactionFocusReturn = nil
    interactionFocusTarget = nil
    state = restore.state
    playerSpatialState = restore.playerSpatialState
    founderObservationActive = restore.founderObservationActive
    reduceMotionActive = reduceMotion
    let recipe = FounderGarageCameraRecipe(
      position: restore.cameraTransform.translation,
      lookTarget: restore.cameraTransform.translation - SIMD3<Float>(
        restore.cameraTransform.matrix.columns.2.x,
        restore.cameraTransform.matrix.columns.2.y,
        restore.cameraTransform.matrix.columns.2.z
      ),
      fieldOfView: restore.fieldOfView,
      duration: FounderGarageCameraConfiguration.shortTransitionDuration
    )
    if reduceMotion { camera.transform = restore.cameraTransform; camera.camera.fieldOfViewInDegrees = restore.fieldOfView }
    else {
      startTransition(to: recipe, kind: .shortPhysical)
      transitionTarget = restore.cameraTransform
    }
    return true
  }

  func advance(deltaTime rawDelta: TimeInterval) {
    let dt = min(max(Float(rawDelta), 0), FounderGarageCameraConfiguration.maximumDeltaTime)
    guard dt > 0 else { return }
    if let start = transitionStart, let target = transitionTarget {
      transitionElapsed += dt
      let x = min(transitionElapsed / max(transitionDuration, 0.001), 1)
      let t = x * x * (3 - 2 * x)
      camera.transform.translation = start.translation + (target.translation - start.translation) * t
      camera.transform.rotation = simd_slerp(start.rotation, target.rotation, t)
      camera.camera.fieldOfViewInDegrees = transitionStartFOV + (transitionTargetFOV - transitionStartFOV) * t
      if x >= 1 { camera.transform = target; camera.camera.fieldOfViewInDegrees = transitionTargetFOV; transitionStart = nil; transitionTarget = nil; activeTransition = nil }
      return
    }
    let steps = max(1, Int(ceil(dt / FounderGarageCameraConfiguration.fixedStep)))
    let substep = dt / Float(steps)
    for _ in 0..<steps { integrateNavigation(deltaTime: substep) }
    if playerSpatialState.navigationMode == .seated || playerSpatialState.navigationMode == .walking {
      applySeatedCameraTransform()
    }
  }

  private func integrateNavigation(deltaTime dt: Float) {
    integrateLook(deltaTime: dt)
    guard playerSpatialState.navigationMode == .walking else { return }
    let input = SIMD2<Float>(movementIntent.lateral, movementIntent.forward)
    let magnitude = min(simd_length(input), 1)
    let heading = playerSpatialState.playerPose.heading
    let right = SIMD3<Float>(cos(heading), 0, sin(heading))
    let forward = SIMD3<Float>(sin(heading), 0, -cos(heading))
    let desired = magnitude > 0 ? (right * input.x + forward * input.y) / max(simd_length(input), 1) * FounderGarageCameraConfiguration.walkingSpeed : .zero
    let rate = magnitude > 0 ? FounderGarageCameraConfiguration.linearAcceleration : FounderGarageCameraConfiguration.linearDeceleration
    let delta = desired - velocity
    velocity += simd_length(delta) <= rate * dt ? delta : simd_normalize(delta) * rate * dt
    let old = playerSpatialState.playerPose.position
    var next = old + velocity * dt
    lastCollision = "none"
    if let walkability, !walkability([next.x, next.z]) {
      let slideX = SIMD2<Float>(next.x, old.z)
      let slideZ = SIMD2<Float>(old.x, next.z)
      if walkability(slideX) {
        next.z = old.z; velocity.z = 0; lastCollision = "slide-x"
      } else if walkability(slideZ) {
        next.x = old.x; velocity.x = 0; lastCollision = "slide-z"
      } else {
        next = old; velocity = .zero; lastCollision = "blocked"
      }
    }
    playerSpatialState.playerPose.position = next
  }

  var snapshot: Snapshot {
    let heading = playerSpatialState.playerPose.heading
    let input = SIMD2<Float>(movementIntent.lateral, movementIntent.forward)
    let right = SIMD2<Float>(cos(heading), sin(heading))
    let forward = SIMD2<Float>(sin(heading), -cos(heading))
    let worldMovement = right * input.x + forward * input.y
    return Snapshot(
      mode: navigationModeLabel,
      position: camera.position(relativeTo: nil),
      playerPosition: playerSpatialState.playerPose.position,
      bodyHeading: heading,
      lookYaw: playerSpatialState.lookOrientation.yaw,
      movementIntent: input,
      worldMovementVector: worldMovement,
      velocity: velocity,
      angularVelocity: angularVelocity,
      target: targetLook,
      collision: lastCollision,
      transition: activeTransition,
      founderPOVDriftError: founderPOVDriftError,
      interactionFocus: interactionFocusTarget,
      reduceMotion: reduceMotionActive
    )
  }

  var spatialState: FounderCameraSpatialState {
    let heading = playerSpatialState.playerPose.heading + playerSpatialState.lookOrientation.yaw
    let rawIntent = SIMD2<Float>(movementIntent.lateral, movementIntent.forward)
    let intentLength = simd_length(rawIntent)
    return FounderCameraSpatialState(
      position: playerSpatialState.playerPose.position,
      facingDirection: [sin(heading), 0, -cos(heading)],
      horizontalVelocity: [velocity.x, velocity.z],
      movementMagnitude: simd_length(SIMD2<Float>(velocity.x, velocity.z)),
      stance: playerSpatialState.navigationMode == .walking ? .standing : .seated,
      navigationMode: playerSpatialState.navigationMode,
      normalizedLocomotionIntent: intentLength > 0.0001 ? rawIntent / max(intentLength, 1) : nil,
      stepPhase: nil
    )
  }

  private var navigationModeLabel: String {
    switch playerSpatialState.navigationMode {
    case .seated: "seated"
    case .walking: "walking"
    case .authoredInspection(let view): view.rawValue
    case .interactionFocus(let target): "focus:\(target.rawValue)"
    }
  }

  private var founderPOVDriftError: Float {
    guard state == .founderPOV, playerSpatialState.navigationMode == .seated,
          activeTransition == nil, targetLook.isNeutral, playerSpatialState.lookOrientation.isNeutral
    else { return 0 }
    return simd_distance(camera.transform.translation, recipe(for: .founderPOV).position)
  }

  private func startTransition(to recipe: FounderGarageCameraRecipe, kind: FounderGarageCameraTransitionClass) {
    transitionStart = camera.transform
    transitionTarget = recipe.transform
    transitionStartFOV = camera.camera.fieldOfViewInDegrees
    transitionTargetFOV = recipe.fieldOfView
    transitionElapsed = 0
    transitionDuration = Float(kind == .shortPhysical ? FounderGarageCameraConfiguration.shortTransitionDuration : FounderGarageCameraConfiguration.mediumTransitionDuration)
    activeTransition = kind
  }

  private func cancelTransientMotion(countInterruption: Bool) {
    if countInterruption && activeTransition != nil { diagnostics.interruptedCount += 1 }
    transitionStart = nil; transitionTarget = nil; activeTransition = nil
    interactionFocusReturn = nil; interactionFocusTarget = nil
    movementIntent = .idle; velocity = .zero; angularVelocity = .zero
  }

  private func integrateLook(deltaTime dt: Float) {
    if reduceMotionActive {
      playerSpatialState.lookOrientation = targetLook; angularVelocity = .zero; return
    }
    var current = SIMD2<Float>(playerSpatialState.lookOrientation.yaw, playerSpatialState.lookOrientation.pitch)
    let target = SIMD2<Float>(targetLook.yaw, targetLook.pitch)
    let error = target - current
    if simd_length(error) <= 0.0005 {
      playerSpatialState.lookOrientation = targetLook
      angularVelocity = .zero
      return
    }
    let desired = simd_length(error) > 0.0001
      ? simd_normalize(error) * min(simd_length(error) * FounderGarageCameraConfiguration.lookResponse, FounderGarageCameraConfiguration.maximumAngularSpeed)
      : .zero
    let velocityDelta = desired - angularVelocity
    let maximumChange = FounderGarageCameraConfiguration.angularAcceleration * dt
    angularVelocity += simd_length(velocityDelta) <= maximumChange ? velocityDelta : simd_normalize(velocityDelta) * maximumChange
    let step = angularVelocity * dt
    for axis in 0..<2 {
      if abs(error[axis]) <= abs(step[axis]) { current[axis] = target[axis]; angularVelocity[axis] = 0 }
      else { current[axis] += step[axis] }
    }
    playerSpatialState.lookOrientation = FounderLookOrientation(yaw: current.x, pitch: current.y)
  }


  private func applyCurrentCameraTransform() {
    let pose = presentationRecipe(for: state)
    camera.camera.fieldOfViewInDegrees = pose.fieldOfView
    camera.transform = pose.transform
  }

  private func presentationRecipe(for state: FounderGarageCameraState) -> FounderGarageCameraRecipe {
    recipe(for: state)
  }

  private func applySeatedCameraTransform() {
    if playerSpatialState.navigationMode == .walking || seatingTransitionActive {
      let observation = founderObservationRecipe()
      camera.camera.fieldOfViewInDegrees = observation.fieldOfView
      camera.transform = observation.transform
      return
    }
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

  /// Explore uses a close three-quarter follow composition while the canonical
  /// player pose continues to own navigation and chair interaction.
  private func founderObservationRecipe(focusTarget: SIMD3<Float>? = nil) -> FounderGarageCameraRecipe {
    let pose = playerSpatialState.playerPose
    let heading = pose.heading
    let forward = SIMD3<Float>(sin(heading), 0, -cos(heading))
    let right = SIMD3<Float>(cos(heading), 0, sin(heading))
    let orientation = playerSpatialState.lookOrientation
    let yawRotation = simd_quatf(angle: -orientation.yaw, axis: [0, 1, 0])
    let neutralHorizontal = -forward * 2.35 + right * 0.72
    let orbitHorizontal = yawRotation.act(neutralHorizontal) * cos(orientation.pitch)
    let orbitHeight = 1.72 - sin(orientation.pitch) * simd_length(neutralHorizontal)
    let position = pose.position + orbitHorizontal + [0, orbitHeight, 0]
    return FounderGarageCameraRecipe(
      position: position,
      lookTarget: focusTarget.map { pose.position + (($0 - pose.position) * 0.58) + [0, 0.36, 0] }
        ?? (pose.position + [0, 1.05, 0]),
      fieldOfView: 58,
      duration: FounderGarageCameraConfiguration.shortTransitionDuration
    )
  }

  private func interactionLookTarget(for target: FounderGarageInteractionFocusTarget) -> SIMD3<Float> {
    switch target {
    case .computer: spatial.anchors.founderComputer.position
    case .phone: spatial.anchors.iPhone.position
    case .tablet: spatial.anchors.iPad.position
    case .strategyBoard: spatial.anchors.fundingBoard.position
    case .signalTV: spatial.anchors.signalTV.position
    case .server: spatial.productionAnchors?.agentDeskSurface ?? spatial.anchors.desk.position
    }
  }
}
