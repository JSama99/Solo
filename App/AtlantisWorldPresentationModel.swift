#if DEBUG
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

enum AtlantisDistrict: String, CaseIterable, Codable, Identifiable {
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
  static let spire: SIMD3<Float> = [50, 14, -420]
  static let playerHQ: SIMD3<Float> = [970, 85, -850]
  static func fromBlender(_ p: SIMD3<Float>) -> SIMD3<Float> { [p.x, p.z, -p.y] }
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
#endif
