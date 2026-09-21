import Foundation
import RealityKit
import SwiftUI
import Combine
import Darwin
import CryptoKit

/// Authored validation data only. No simulation state or gameplay clips.
struct FounderCharacterValidationPose: Decodable {
  let root_vertical_offset: Float
  let seated: [String: [[Float]]]
  let landmarks: [String: [Float]]
  let sole_floor_error: Float

  static func load() throws -> Self {
    guard let url = Bundle.main.url(forResource: "founder_validation_pose", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }

  func transform(for name: String) -> Transform? {
    guard let rows = seated[name], rows.count == 4, rows.allSatisfy({ $0.count == 4 }) else { return nil }
    let columns = (0..<4).map { c in SIMD4<Float>(rows[0][c], rows[1][c], rows[2][c], rows[3][c]) }
    return Transform(matrix: simd_float4x4(columns: (columns[0], columns[1], columns[2], columns[3])))
  }
}

/// Future authored clips consume the existing graph. Missing means procedural
/// fallback; validation poses must never be advertised as gameplay animation.
enum FounderAnimationClipCatalog {
  static func clipName(for state: FounderLocomotionState) -> String? {
    switch state {
    case .seatedIdle, .seatedTurn, .standingUp, .standingIdle,
         .walkStart, .walking, .walkStop, .turnInPlace, .sittingDown:
      return nil
    }
  }
  static let rootMotionIsSpatialAuthority = false
}

@MainActor
enum FounderCharacterContract {
  static let candidateResource = "founder_candidate_a"
  static let acceptedSHA256 = "6392eb1dea5f13506913feeb1a65bf84c97f9b61266ba027bd3b3377278171f5"
  static let slots = ["HairSlot", "TopSlot", "BottomSlot", "ShoeSlot", "AccessorySlot"]
  static let headParts = ["HeadMesh", "HairMesh", "EyeMesh_L", "EyeMesh_R", "IrisMesh_L", "IrisMesh_R"]
  static let facialTargets: Set<String> = ["Blink_L", "Blink_R", "JawOpen", "Smile", "Frown", "BrowRaise", "BrowLower", "MouthNarrow", "MouthWide"]
  static let requiredBones: Set<String> = {
    var names = ["Root", "Hips", "Spine01", "Spine02", "Chest", "Neck", "Head", "Eye_L", "Eye_R"]
    for side in ["L", "R"] {
      names += ["Clavicle", "UpperArm", "LowerArm", "Hand", "Thigh", "Calf", "Foot", "Toe"].map { "\($0)_\(side)" }
      for finger in ["Thumb", "Index", "Middle", "Ring", "Pinky"] {
        names += (1...3).map { "\(finger)0\($0)_\(side)" }
      }
    }
    return Set(names)
  }()

  static func load() async throws -> Entity {
    try validateAcceptedRuntimeAsset()
    guard let url = Bundle.main.url(forResource: candidateResource, withExtension: "usdz") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try await Entity(contentsOf: url)
  }

  static func validateAcceptedRuntimeAsset(in bundle: Bundle = .main) throws {
    guard let url = bundle.url(forResource: candidateResource, withExtension: "usdz") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    guard digest == acceptedSHA256 else {
      throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedFailureReasonErrorKey: "Accepted Founder SHA-256 mismatch: \(digest)"])
    }
  }

  static func productionDescriptor(
    spatial: FounderGarageSpatialSpecification = .standard
  ) throws -> FounderAssetRigDescriptor {
    let pose = try FounderCharacterValidationPose.load()
    let seatedHeading = FounderGarageCameraConfiguration(spatial: spatial).seatedPlayerState.playerPose.heading
    return FounderAssetRigDescriptor(
      bodyPath: ["FounderRoot"],
      headPath: ["FounderRoot", "HeadMeshModule"],
      normalization: FounderVisualNormalization(transform: Transform(
        scale: .one,
        rotation: simd_quatf(angle: .pi - seatedHeading, axis: [0, 1, 0]),
        translation: [0, pose.root_vertical_offset, 0]
      )),
      authoredPose: pose,
      standingNormalization: FounderVisualNormalization(transform: Transform(
        scale: .one,
        rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]),
        translation: .zero
      ))
    )
  }

  static func descendants(_ root: Entity) -> [Entity] {
    [root] + root.children.flatMap { descendants($0) }
  }

  static func models(_ root: Entity) -> [ModelEntity] {
    descendants(root).compactMap { $0 as? ModelEntity }
  }

  static func boneNames(_ root: Entity) -> Set<String> {
    Set(models(root).flatMap(\.jointNames).map { $0.split(separator: "/").last.map(String.init) ?? $0 })
  }

  static func setHeadVisible(_ visible: Bool, on root: Entity) {
    for name in headParts { root.findEntity(named: name + "Module")?.isEnabled = visible }
  }

  @discardableResult
  static func setFacialTarget(_ name: String, weight: Float, on root: Entity) -> Int {
    var changed = 0
    for entity in descendants(root) {
      guard var component = entity.components[BlendShapeWeightsComponent.self] else { continue }
      for setIndex in component.weightSet.indices {
        var data = component.weightSet[setIndex]
        guard let weightIndex = data.weightNames.firstIndex(of: name) else { continue }
        data.weights[weightIndex] = weight
        component.weightSet[setIndex] = data
        changed += 1
      }
      entity.components.set(component)
    }
    return changed
  }

  /// Retains the authored axis conversion beneath an independent placement root.
  static func placed(_ asset: Entity, at position: SIMD3<Float>) -> Entity {
    let placement = Entity()
    placement.name = "FounderPlacement"
    placement.position = position
    placement.addChild(asset)
    return placement
  }
}

#if DEBUG
@MainActor
@Observable
final class FounderCharacterQAState {
  var status = "Loading candidate…"
  var headVisible = !ProcessInfo.processInfo.arguments.contains("--founder-character-head-hidden")
  var closeUp = ProcessInfo.processInfo.arguments.contains("--founder-character-close-up")
    || ProcessInfo.processInfo.arguments.contains("--founder-character-blink")
    || ProcessInfo.processInfo.arguments.contains("--founder-character-jaw-open")
  var seated = ProcessInfo.processInfo.arguments.contains("--founder-character-seated")
  var firstPerson = ProcessInfo.processInfo.arguments.contains("--founder-character-pov")
  var asset: Entity?
  var placement: Entity?
  var camera: PerspectiveCamera?
  var rest: [(ModelEntity, [Transform])] = []
  var seatedTransforms: [(ModelEntity, [Transform])] = []
  var headModules: [Entity] = []
  var validationPose: FounderCharacterValidationPose?
  let inspectionHeadTurn: Float = ProcessInfo.processInfo.arguments.contains("--founder-character-head-profile") ? 1.57 : ProcessInfo.processInfo.arguments.contains("--founder-character-head-left") ? 0.75 : ProcessInfo.processInfo.arguments.contains("--founder-character-head-right") ? -0.75 : 0
  let inspectionHeadTilt: Float = ProcessInfo.processInfo.arguments.contains("--founder-character-head-down") ? 0.15 : ProcessInfo.processInfo.arguments.contains("--founder-character-head-up") ? -0.15 : 0
  var headJointIndices: [ObjectIdentifier: Int] = [:]

  func bind(_ candidate: Entity) throws {
    asset = candidate
    let pose = try FounderCharacterValidationPose.load()
    validationPose = pose
    let models = FounderCharacterContract.models(candidate)
    rest = models.map { ($0, $0.jointTransforms) }
    headJointIndices = Dictionary(uniqueKeysWithValues: models.compactMap { model in
      model.jointNames.firstIndex(where: { $0.split(separator: "/").last == "Head" }).map { (ObjectIdentifier(model), $0) }
    })
    seatedTransforms = models.map { model in
      (model, model.jointNames.enumerated().map { index, path in
        pose.transform(for: String(path.split(separator: "/").last ?? "")) ?? model.jointTransforms[index]
      })
    }
    headModules = FounderCharacterContract.headParts.compactMap { candidate.findEntity(named: $0 + "Module") }
    if ProcessInfo.processInfo.arguments.contains("--founder-character-blink") {
      FounderCharacterContract.setFacialTarget("Blink_L", weight: 1, on: candidate)
      FounderCharacterContract.setFacialTarget("Blink_R", weight: 1, on: candidate)
    }
    if ProcessInfo.processInfo.arguments.contains("--founder-character-jaw-open") {
      FounderCharacterContract.setFacialTarget("JawOpen", weight: 1, on: candidate)
    }
  }

  func applyPose() {
    for (model, transforms) in (seated || firstPerson ? seatedTransforms : rest) {
      if (inspectionHeadTurn != 0 || inspectionHeadTilt != 0), let index = headJointIndices[ObjectIdentifier(model)] {
        var inspected = transforms
        inspected[index].rotation = transforms[index].rotation * simd_quatf(angle: inspectionHeadTurn, axis: [0,1,0]) * simd_quatf(angle: inspectionHeadTilt, axis: [1,0,0])
        model.jointTransforms = inspected
      } else {
        model.jointTransforms = transforms
      }
    }
  }

  func update() {
    guard let placement else { return }
    for head in headModules { head.isEnabled = headVisible && !firstPerson }
    let spatial = FounderGarageSpatialSpecification.standard
    let seat = spatial.productionAnchors!.founderSeat
    let isSeated = seated || firstPerson
    placement.position = isSeated ? seat + [0, validationPose?.root_vertical_offset ?? 0, 0] : seat + [-0.75, 0, 0.55]
    placement.orientation = isSeated ? simd_quatf(angle: .pi, axis: [0,1,0]) : simd_quatf()
    applyPose()
    if firstPerson {
      let recipe = FounderGarageCameraConfiguration(spatial: spatial).recipe(for: .founderPOV)
      camera?.camera.fieldOfViewInDegrees = recipe.fieldOfView
      camera?.look(at: recipe.lookTarget, from: recipe.position, relativeTo: nil)
    } else if closeUp {
      camera?.camera.fieldOfViewInDegrees = 48
      camera?.look(at: placement.position + [0, 1.64, 0], from: placement.position + [0.3,1.68,0.85], relativeTo: nil)
    } else if seated {
      camera?.camera.fieldOfViewInDegrees = 48
      camera?.look(at: seat + [0, 0.76, -0.10], from: seat + [-1.45, 1.35, -1.35], relativeTo: nil)
    } else {
      camera?.camera.fieldOfViewInDegrees = 48
      camera?.look(at: placement.position + [0,0.95,0], from: placement.position + [1.6,1.75,2.2], relativeTo: nil)
    }
  }
}

struct FounderCharacterQAView: View {
  @State private var state = FounderCharacterQAState()
  var body: some View {
    VStack(spacing: 8) {
      Text("Founder candidate · Pass A validation").font(.headline)
      Text(state.status).font(.caption.monospaced()).accessibilityIdentifier("founderCharacterQAStatus")
      FounderCharacterQAViewport(state: state)
      HStack {
        Toggle("Head", isOn: $state.headVisible)
        Toggle("Close-up", isOn: $state.closeUp)
        Toggle("Seated", isOn: $state.seated)
        Toggle("POV", isOn: $state.firstPerson)
      }.padding().frame(minHeight: 44)
    }.onChange(of: state.headVisible) { state.update() }
      .onChange(of: state.closeUp) { state.update() }
      .onChange(of: state.seated) { state.update() }
      .onChange(of: state.firstPerson) { state.update() }
  }
}

/// Review-only choreography for the human Pass B taste gate. These cases drive
/// the production locomotion controller without supplying alternate parameters.
enum FounderMotionReviewSection: String, CaseIterable {
  case seatedIdle = "seated-idle"
  case standingIdle = "standing-idle"
  case sitToStand = "sit-to-stand"
  case standToSit = "stand-to-sit"
  case walkStart = "walk-start"
  case continuousWalk = "continuous-walk"
  case walkStop = "walk-stop"
  case turnInPlace = "turn-in-place"
  case walkAndTurn = "walk-and-turn"

  static var requested: Self? {
    let prefix = "--founder-motion-review="
    guard let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })?
      .dropFirst(prefix.count) else { return nil }
    return Self(rawValue: String(value))
  }

  var reviewLabel: String {
    switch self {
    case .seatedIdle: "A · Seated Idle"
    case .standingIdle: "B · Standing Idle"
    case .sitToStand: "C · Sit → Stand"
    case .standToSit: "D · Stand → Sit"
    case .walkStart: "E · Walk Start"
    case .continuousWalk: "F · Continuous Walk"
    case .walkStop: "G · Walk Stop"
    case .turnInPlace: "H · Turn In Place"
    case .walkAndTurn: "I · Walk + Turn"
    }
  }

  var usesTrackingReviewCamera: Bool {
    switch self {
    case .walkStart, .continuousWalk, .walkStop, .walkAndTurn: true
    default: false
    }
  }
}

@MainActor
@Observable
private final class FounderMotionReviewState {
  var status = "Loading production baseline…"
  var phase = "Preparing"
  let kineticChainVariant = FounderKineticChainVariant.requested
  let isKineticChainRound = FounderKineticChainVariant.reviewRequested != nil
  let isRoundTwo = FounderWeightTransferVariant.reviewRequested != nil
  var phaseVariant: FounderLocomotionPhaseVariant {
    isRoundTwo || isKineticChainRound ? .c : .requested
  }
  var weightTransferVariant: FounderWeightTransferVariant {
    isKineticChainRound ? .baseline : .requested
  }
}

struct FounderMotionReviewView: View {
  let section: FounderMotionReviewSection
  @State private var state = FounderMotionReviewState()

  var body: some View {
    ZStack(alignment: .topLeading) {
      FounderMotionReviewViewport(section: section, state: state)
        .ignoresSafeArea()
      VStack(alignment: .leading, spacing: 3) {
        Text(reviewTitle)
          .font(.caption.weight(.semibold))
        Text(reviewVariantLabel)
          .font(.headline)
        Text(section.reviewLabel)
          .font(.subheadline)
        Text(state.phase)
          .font(.caption.monospaced())
        Text(state.status)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("founderMotionReviewStatus")
      }
      .padding(10)
      .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
      .padding(12)
    }
    .preferredColorScheme(.dark)
  }

  private var reviewTitle: String {
    if state.isKineticChainRound { return "Founder Motion · Pass B.2 Round 1" }
    if state.isRoundTwo { return "Founder Motion · Pass B.1 Round 2" }
    return "Founder Motion · Pass B.1 Round 1"
  }

  private var reviewVariantLabel: String {
    if state.isKineticChainRound { return state.kineticChainVariant.reviewLabel }
    if state.isRoundTwo { return state.weightTransferVariant.reviewLabel }
    return state.phaseVariant.reviewLabel
  }
}

private struct FounderMotionReviewViewport: UIViewRepresentable {
  let section: FounderMotionReviewSection
  let state: FounderMotionReviewState

  @MainActor
  final class Coordinator {
    var task: Task<Void, Never>?
    var frame: Cancellable?
    var world: FounderGarageRealityWorld?
    var spatial: FounderCameraSpatialState?
    var elapsed: Float = 0
    deinit { task?.cancel(); frame?.cancel() }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> ARView {
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    view.environment.background = .color(.black)
    let anchor = AnchorEntity(world: .zero)
    view.scene.addAnchor(anchor)

    let camera = PerspectiveCamera()
    let cameraFrom: SIMD3<Float>
    let cameraTarget: SIMD3<Float>
    let trackingCameraFromOffset = SIMD3<Float>(4.2, 1.75, 2.2)
    let trackingCameraTargetOffset = SIMD3<Float>(0, 0.90, 0)
    switch section {
    case .walkStart, .continuousWalk, .walkStop, .walkAndTurn:
      camera.camera.fieldOfViewInDegrees = 50
      cameraFrom = [6.2, 2.10, 0.65]
      cameraTarget = [0, 0.88, 0.35]
    default:
      camera.camera.fieldOfViewInDegrees = 54
      cameraFrom = [4.3, 1.90, 0.80]
      cameraTarget = [0, 0.88, 0.45]
    }
    camera.look(at: cameraTarget, from: cameraFrom, relativeTo: nil)
    anchor.addChild(camera)

    let coordinator = context.coordinator
    coordinator.task = Task { @MainActor in
      do {
        let world = FounderGarageRealityWorld(quality: .high)
        coordinator.world = world
        world.entities.camera.isEnabled = false
        anchor.addChild(world.entities.root)
        await world.requestGarageArchitecture(
          .bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName),
          descriptor: .facilityTier0V8
        )?.value
        guard case .ready(.bundledProductionAsset) = world.architectureLoadState else {
          throw CocoaError(.fileReadCorruptFile)
        }
        world.applyRuntimeEnclosureVisibility(for: .garageOverview)
        try await world.requestProductionFounder()?.value
        let expected = FounderVisualSource.bundledUSDZ(name: FounderCharacterContract.candidateResource)
        guard world.assetLoadState == .ready(expected) else {
          throw CocoaError(.fileReadCorruptFile)
        }
        world.founderAvatarController.locomotion.configurePhaseVariantForReview(state.phaseVariant)
        world.founderAvatarController.locomotion.configureWeightTransferVariantForReview(state.weightTransferVariant)
        world.founderAvatarController.locomotion.configureKineticChainVariantForReview(state.kineticChainVariant)
        var spatial = initialSpatial(for: section, world: world)
        preRoll(section: section, spatial: &spatial, world: world)
        coordinator.spatial = spatial
        if section.usesTrackingReviewCamera {
          camera.look(
            at: spatial.position + trackingCameraTargetOffset,
            from: spatial.position + trackingCameraFromOffset,
            relativeTo: nil
          )
        }
        coordinator.elapsed = -5
        state.phase = "Capture lead-in · 5 s"
        if state.isKineticChainRound {
          state.status = "READY · \(state.kineticChainVariant.reviewLabel) · Round 1 C + B.1 Baseline frozen"
        } else if state.isRoundTwo {
          state.status = "READY · \(state.weightTransferVariant.reviewLabel) · Round 1 C frozen"
        } else {
          state.status = "READY · \(state.phaseVariant.reviewLabel) · fixed speed/cadence/camera"
        }

        coordinator.frame = view.scene.subscribe(to: SceneEvents.Update.self) { event in
          guard var spatial = coordinator.spatial else { return }
          let dt = min(max(Float(event.deltaTime), 0), FounderGarageCameraConfiguration.maximumDeltaTime)
          coordinator.elapsed += dt
          guard coordinator.elapsed >= 0 else {
            state.phase = String(format: "Capture lead-in · %.1f s", -coordinator.elapsed)
            return
          }
          updateScript(section: section, elapsed: coordinator.elapsed, deltaTime: dt, spatial: &spatial)
          if section.usesTrackingReviewCamera {
            camera.look(
              at: spatial.position + trackingCameraTargetOffset,
              from: spatial.position + trackingCameraFromOffset,
              relativeTo: nil
            )
          }
          world.founderAvatarController.locomotion.update(
            spatial: spatial,
            collisionBlocked: false,
            firstPerson: false,
            reduceMotion: false,
            deltaTime: TimeInterval(dt)
          )
          coordinator.spatial = spatial
          state.phase = phaseLabel(section: section, elapsed: coordinator.elapsed)
        }
      } catch {
        state.phase = "Unavailable"
        state.status = "LOAD FAILED · \(error.localizedDescription)"
      }
    }
    return view
  }

  func updateUIView(_ view: ARView, context: Context) {}

  static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
    coordinator.task?.cancel()
    coordinator.frame?.cancel()
  }

  private func initialSpatial(
    for section: FounderMotionReviewSection,
    world: FounderGarageRealityWorld
  ) -> FounderCameraSpatialState {
    var spatial = world.cameraController.spatialState
    switch section {
    case .seatedIdle, .sitToStand:
      return spatial
    case .standingIdle:
      spatial.position = [0, 0, 0.80]
      spatial.facingDirection = [1, 0, 0]
    case .standToSit:
      spatial.position = world.spatialSpecification.productionAnchors?.founderSeat ?? spatial.position
    case .walkStart, .continuousWalk, .walkStop, .walkAndTurn:
      spatial.position = [-1.10, 0, -2.10]
      spatial.facingDirection = [0, 0, 1]
    case .turnInPlace:
      spatial.position = [0, 0, 0.80]
      spatial.facingDirection = [0, 0, -1]
    }
    spatial.stance = .standing
    spatial.navigationMode = .walking
    spatial.horizontalVelocity = .zero
    spatial.movementMagnitude = 0
    spatial.normalizedLocomotionIntent = nil
    return spatial
  }

  private func preRoll(
    section: FounderMotionReviewSection,
    spatial: inout FounderCameraSpatialState,
    world: FounderGarageRealityWorld
  ) {
    guard section != .seatedIdle && section != .sitToStand else { return }
    let locomotion = world.founderAvatarController.locomotion
    for _ in 0..<40 {
      locomotion.update(
        spatial: spatial,
        collisionBlocked: false,
        firstPerson: false,
        reduceMotion: false,
        deltaTime: 1.0 / 60
      )
    }
    guard section == .continuousWalk || section == .walkStop else { return }
    spatial.horizontalVelocity = [0, FounderGarageCameraConfiguration.walkingSpeed]
    spatial.movementMagnitude = FounderGarageCameraConfiguration.walkingSpeed
    spatial.normalizedLocomotionIntent = [0, 1]
    for _ in 0..<24 {
      spatial.position.z += spatial.horizontalVelocity.y / 60
      locomotion.update(
        spatial: spatial,
        collisionBlocked: false,
        firstPerson: false,
        reduceMotion: false,
        deltaTime: 1.0 / 60
      )
    }
  }

  private func updateScript(
    section: FounderMotionReviewSection,
    elapsed: Float,
    deltaTime: Float,
    spatial: inout FounderCameraSpatialState
  ) {
    let speed = FounderGarageCameraConfiguration.walkingSpeed
    var velocity = SIMD2<Float>.zero
    switch section {
    case .seatedIdle, .standingIdle:
      break
    case .sitToStand:
      if elapsed >= 1.5 {
        spatial.stance = .standing
        spatial.navigationMode = .walking
      }
    case .standToSit:
      if elapsed >= 1.5 {
        spatial.stance = .seated
        spatial.navigationMode = .seated
      }
    case .walkStart:
      if elapsed >= 1.25 { velocity = [0, speed] }
    case .continuousWalk:
      velocity = [0, speed]
    case .walkStop:
      if elapsed < 1.75 { velocity = [0, speed] }
    case .turnInPlace:
      let angle: Float
      if elapsed < 1.25 { angle = 0 }
      else if elapsed < 2.75 { angle = 25 * .pi / 180 }
      else if elapsed < 4.75 { angle = 90 * .pi / 180 }
      else { angle = 170 * .pi / 180 }
      spatial.facingDirection = [sin(angle), 0, -cos(angle)]
    case .walkAndTurn:
      if elapsed < 1.35 { velocity = [0, speed] }
      else if elapsed < 2.85 { velocity = simd_normalize(SIMD2<Float>(1, 1)) * speed }
      else { velocity = [speed, 0] }
    }
    spatial.horizontalVelocity = velocity
    spatial.movementMagnitude = simd_length(velocity)
    spatial.normalizedLocomotionIntent = spatial.movementMagnitude > 0 ? velocity / spatial.movementMagnitude : nil
    spatial.position.x += velocity.x * deltaTime
    spatial.position.z += velocity.y * deltaTime
    if spatial.movementMagnitude > 0 {
      spatial.facingDirection = [velocity.x / speed, 0, velocity.y / speed]
    }
  }

  private func phaseLabel(section: FounderMotionReviewSection, elapsed: Float) -> String {
    switch section {
    case .seatedIdle: "SeatedIdle · uninterrupted"
    case .standingIdle: "StandingIdle · uninterrupted"
    case .sitToStand: elapsed < 1.5 ? "Accepted seated start" : "StandingUp → settle"
    case .standToSit: elapsed < 1.5 ? "Standing start" : "SittingDown → accepted settle"
    case .walkStart: elapsed < 1.25 ? "StandingIdle" : "WalkStart → Walking"
    case .continuousWalk: "Walking · world displacement"
    case .walkStop: elapsed < 1.75 ? "Walking" : "WalkStop → StandingIdle"
    case .turnInPlace:
      if elapsed < 1.25 { "StandingIdle" }
      else if elapsed < 2.75 { "Small turn · 25°" }
      else if elapsed < 4.75 { "Medium turn · 90°" }
      else { "Large turn · 170°" }
    case .walkAndTurn:
      if elapsed < 1.35 { "Walking · straight" }
      else if elapsed < 2.85 { "Walking · heading adjustment" }
      else { "Walking · new heading" }
    }
  }
}

private struct FounderCharacterQAViewport: UIViewRepresentable {
  let state: FounderCharacterQAState
  final class Coordinator {
    var task: Task<Void, Never>?
    var frame: Cancellable?
    var world: FounderGarageRealityWorld?
    deinit { task?.cancel(); frame?.cancel() }
  }
  func makeCoordinator() -> Coordinator { Coordinator() }

  private func processPeakMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? Double(info.ledger_phys_footprint_peak) / 1_048_576 : -1
  }

  private func sampleFrames(_ count: Int, in view: ARView, coordinator: Coordinator, animate: Bool = false) async -> [String: Double] {
    await withCheckedContinuation { continuation in
      var deltas: [Double] = []
      var costs: [Double] = []
      var maximum = AtlantisMemory.footprintMB()
      coordinator.frame = view.scene.subscribe(to: SceneEvents.Update.self) { event in
        let start = ProcessInfo.processInfo.systemUptime
        if animate { state.applyPose() }
        costs.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
        deltas.append(event.deltaTime * 1000)
        maximum = max(maximum, AtlantisMemory.footprintMB())
        if deltas.count >= count {
          coordinator.frame?.cancel()
          coordinator.frame = nil
          let sorted = deltas.sorted()
          continuation.resume(returning: ["frames": Double(count), "frame_mean_ms": deltas.reduce(0,+)/Double(count),
            "frame_p95_ms": sorted[min(count-1, Int(Double(count)*0.95))], "frame_max_ms": sorted.last ?? 0,
            "pose_assignment_mean_ms": costs.reduce(0,+)/Double(count), "sampled_peak_mb": maximum,
            "ending_mb": AtlantisMemory.footprintMB()])
        }
      }
    }
  }

  func makeUIView(context: Context) -> ARView {
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    view.environment.background = .color(.darkGray)
    let anchor = AnchorEntity(world: .zero)
    view.scene.addAnchor(anchor)
    let camera = PerspectiveCamera()
    camera.camera.fieldOfViewInDegrees = 48
    anchor.addChild(camera)
    state.camera = camera
    let light = DirectionalLight()
    light.light.intensity = 1800
    light.look(at: [0,0,0], from: [2,4,3], relativeTo: nil)
    anchor.addChild(light)
    let coordinator = context.coordinator
    coordinator.task = Task { @MainActor in
      do {
        let world = FounderGarageRealityWorld()
        coordinator.world = world
        world.entities.camera.isEnabled = false
        anchor.addChild(world.entities.root)
        state.status = "Loading production Garage baseline…"
        await world.requestGarageArchitecture(.bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName), descriptor: .facilityTier0V8)?.value
        guard case .ready(.bundledProductionAsset) = world.architectureLoadState else {
          throw CocoaError(.fileReadCorruptFile)
        }
        state.validationPose = try FounderCharacterValidationPose.load()
        state.placement = Entity()
        state.update()
        _ = await sampleFrames(90, in: view, coordinator: coordinator)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
          view.snapshot(saveToHDR: false) { snapshot in
            if let data = snapshot?.pngData() {
              let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("founder-character-baseline.png")
              try? data.write(to: url)
            }
            continuation.resume()
          }
        }
        let baseline = await sampleFrames(180, in: view, coordinator: coordinator)
        let baselinePeak = processPeakMB()
        let before = AtlantisMemory.footprintMB()
        let start = ProcessInfo.processInfo.systemUptime
        var importFrameIntervals: [Double] = []
        let importFrames = view.scene.subscribe(to: SceneEvents.Update.self) { event in
          importFrameIntervals.append(event.deltaTime * 1000)
        }
        state.status = "Profiling Garage + Founder…"
        let candidate = try await FounderCharacterContract.load()
        let loaded = ProcessInfo.processInfo.systemUptime
        let after = AtlantisMemory.footprintMB()
        try Task.checkCancellation()
        try state.bind(candidate)
        let placement = FounderCharacterContract.placed(candidate, at: .zero)
        state.placement = placement
        anchor.addChild(placement)
        state.update()
        let bones = FounderCharacterContract.boneNames(candidate).count
        let models = FounderCharacterContract.models(candidate)
        let shapes = FounderCharacterContract.descendants(candidate).reduce(0) {
          $0 + ($1.components[BlendShapeWeightsComponent.self]?.weightSet.reduce(0) { $0 + $1.weightNames.count } ?? 0)
        }
        var measurement: [String: Any] = ["load_ms": (loaded-start)*1000, "before_mb": before,
          "run_id": ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--founder-character-run=") }) ?? "interactive",
          "loaded_mb": after, "load_delta_mb": after-before, "joint_names": bones,
          "model_entities": models.count, "facial_weight_names": shapes,
          "garage_baseline": baseline, "baseline_process_lifetime_peak_mb": baselinePeak,
          "note": "Warmed production Garage architecture in the QA ARView. Process lifetime high-water includes baseline; snapshot completion is an upper bound on captured appearance, not display presentation latency. Pose cost measures assignment CPU only, not GPU skinning. Draw calls are not measured."]
        _ = await sampleFrames(1, in: view, coordinator: coordinator)
        importFrames.cancel()
        measurement["import_frame_count"] = importFrameIntervals.count
        measurement["import_frame_max_ms"] = importFrameIntervals.max() ?? 0
        measurement["first_scene_update_ms"] = (ProcessInfo.processInfo.systemUptime-start)*1000
        let captured: Bool = await withCheckedContinuation { continuation in
          view.snapshot(saveToHDR: false) { snapshot in
            if let data = snapshot?.pngData() {
              let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("founder-character-first-capture.png")
              try? data.write(to: url)
            }
            continuation.resume(returning: snapshot != nil)
          }
        }
        measurement["capture_completed_ms"] = (ProcessInfo.processInfo.systemUptime-start)*1000
        measurement["capture_succeeded"] = captured
        _ = await sampleFrames(60, in: view, coordinator: coordinator)
        let candidateFrames = await sampleFrames(180, in: view, coordinator: coordinator, animate: true)
        measurement["garage_plus_founder"] = candidateFrames
        measurement["incremental_steady_mb"] = (candidateFrames["ending_mb"] ?? after) - (baseline["ending_mb"] ?? before)
        measurement["process_lifetime_peak_mb"] = processPeakMB()
        if let data = try? JSONSerialization.data(withJSONObject: measurement, options: [.prettyPrinted, .sortedKeys]) {
          let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("founder-character-qa.json")
          try data.write(to: url)
          print("FOUNDER_CHARACTER_QA " + (String(data: data, encoding: .utf8) ?? ""))
        }
        state.status = String(format: "Loaded %.0f ms · %d joints · %d facial weights · Δ %.1f MB", (loaded-start)*1000, bones, shapes, after-before)
      } catch { state.status = "Import failed: \(error.localizedDescription)" }
    }
    return view
  }
  func updateUIView(_ view: ARView, context: Context) {}
  static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
    coordinator.task?.cancel()
    coordinator.frame?.cancel()
  }
}
#endif
