#if DEBUG
import RealityKit
import Observation
import Foundation
import CryptoKit
import Darwin

@MainActor
protocol AtlantisDistrictLoading {
  func load(package: String) async throws -> Entity
  func load(package: String, phase: (String, Double) -> Void) async throws -> Entity
}

extension AtlantisDistrictLoading {
  func load(package: String, phase: (String, Double) -> Void) async throws -> Entity {
    let start = ContinuousClock.now
    let entity = try await load(package: package)
    phase("source-total", seconds(since: start))
    return entity
  }
}

@MainActor
struct AtlantisUSDZLoader: AtlantisDistrictLoading {
  let bundle: Bundle
  let manifest: AtlantisAssetManifest
  init(bundle: Bundle = .main, manifest: AtlantisAssetManifest) { self.bundle = bundle; self.manifest = manifest }
  func load(package: String) async throws -> Entity {
    try await load(package: package, phase: { _, _ in })
  }
  func load(package: String, phase: (String, Double) -> Void) async throws -> Entity {
    var checkpoint = ContinuousClock.now
    guard let url = bundle.url(forResource: package, withExtension: "usdz"),
          let expected = (Array(manifest.districts.values) + (manifest.experiments.map { Array($0.values) } ?? [])).first(where: { $0.package == package }) else { throw CocoaError(.fileNoSuchFile) }
    phase("resolve", seconds(since: checkpoint)); checkpoint = .now
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    phase("read", seconds(since: checkpoint)); checkpoint = .now
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard hash == expected.sha256 else { throw AtlantisLoadError.invalidPackage("Package checksum: \(package)") }
    phase("checksum", seconds(since: checkpoint)); checkpoint = .now
    let entity = try await Entity(contentsOf: url)
    phase("realitykit-import", seconds(since: checkpoint)); checkpoint = .now
    let b = entity.visualBounds(relativeTo: nil)
    let lo = expected.bounds[0].vector3, hi = expected.bounds[1].vector3
    guard simd_length(b.min-lo) < 0.05, simd_length(b.max-hi) < 0.05 else { throw AtlantisLoadError.invalidPackage("Bounds: \(package), \(b.min) / \(b.max)") }
    for (name, position) in expected.landmarks {
      guard let landmark = entity.findEntity(named: name), simd_distance(landmark.position(relativeTo: nil), position.vector3) < 0.01 else { throw AtlantisLoadError.invalidPackage("Landmark: \(name)") }
    }
    phase("validation", seconds(since: checkpoint))
    return entity
  }
}

private func seconds(since start: ContinuousClock.Instant) -> Double {
  Double(start.duration(to: .now).components.attoseconds) / 1e18
    + Double(start.duration(to: .now).components.seconds)
}

enum AtlantisLoadError: Error, LocalizedError {
  case invalidPackage(String)
  var errorDescription: String? { switch self { case .invalidPackage(let s): s } }
}

struct AtlantisLoadMeasurement: Codable {
  let district: String; let package: String; let seconds: Double; let memoryBeforeMB: Double; let memoryAfterMB: Double; let outcome: String
}

struct AtlantisLoadPhaseMeasurement: Codable {
  let district: String
  let package: String
  let phase: String
  let seconds: Double
}

enum AtlantisMemory {
  static func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
  }
}

/// Owns cancellable presentation requests, not game-state or long-lived asset caches.
@MainActor @Observable
final class AtlantisDistrictLoader {
  let root = Entity()
  private(set) var states: [AtlantisDistrict: AtlantisDistrictLoadState] = Dictionary(uniqueKeysWithValues: AtlantisDistrict.allCases.map { ($0,.unloaded) })
  private(set) var measurements: [AtlantisLoadMeasurement] = []
  private(set) var phaseMeasurements: [AtlantisLoadPhaseMeasurement] = []
  private(set) var contextState = AtlantisDistrictLoadState.unloaded
  @ObservationIgnored private var requests: [AtlantisDistrict: Task<Void,Never>] = [:]
  @ObservationIgnored private var tokens: [AtlantisDistrict: UUID] = [:]
  @ObservationIgnored private var entities: [AtlantisDistrict: Entity] = [:]
  @ObservationIgnored private var contextTask: Task<Void,Never>?
  @ObservationIgnored private var contextToken = UUID()
  @ObservationIgnored private var supportTasks: [String: Task<Void,Never>] = [:]
  @ObservationIgnored private var supportEntities: [String: Entity] = [:]
  @ObservationIgnored private let source: any AtlantisDistrictLoading
  @ObservationIgnored private let manifest: AtlantisAssetManifest
  @ObservationIgnored var onInstall: ((AtlantisDistrict?, Entity) -> Void)?
  @ObservationIgnored var onWillUnload: ((AtlantisDistrict, Entity) -> Void)?

  init(manifest: AtlantisAssetManifest, source: (any AtlantisDistrictLoading)? = nil) {
    self.manifest = manifest; self.source = source ?? AtlantisUSDZLoader(manifest: manifest); root.name = "AtlantisWorld"
  }
  var loaded: [AtlantisDistrict] { AtlantisDistrict.allCases.filter { states[$0] == .loaded } }
  var pending: [AtlantisDistrict] { AtlantisDistrict.allCases.filter { states[$0] == .loading } }
  func entity(for district: AtlantisDistrict) -> Entity? { entities[district] }
  func supportEntity(named name: String) -> Entity? { supportEntities[name] }

  @discardableResult
  func load(_ district: AtlantisDistrict) -> Task<Void,Never>? {
    if let request = requests[district] { return request }
    guard states[district] != .loaded else { return nil }
    let token = UUID(); tokens[district] = token; states[district] = .loading
    let source = source
    let package = AtlantisImportExperiment.package(
      for: district,
      manifest: manifest,
      arguments: ProcessInfo.processInfo.arguments
    )
    let task = Task { [weak self] in
      let start = Date(), before = AtlantisMemory.footprintMB()
      do {
        let entity = try await source.load(package: package) { [weak self] phase, seconds in
          self?.phaseMeasurements.append(.init(district: district.rawValue, package: package, phase: phase, seconds: seconds))
        }
        guard !Task.isCancelled, let self, self.tokens[district] == token else { return }
        let installStart = ContinuousClock.now
        entity.name = district.rawValue; self.root.addChild(entity); self.entities[district] = entity; self.states[district] = .loaded; self.onInstall?(district, entity)
        self.phaseMeasurements.append(.init(district: district.rawValue, package: package, phase: "scene-install", seconds: seconds(since: installStart)))
        self.measurements.append(.init(district: district.rawValue, package: package, seconds: Date().timeIntervalSince(start), memoryBeforeMB: before, memoryAfterMB: AtlantisMemory.footprintMB(), outcome: "loaded"))
      } catch {
        guard !Task.isCancelled, let self, self.tokens[district] == token else { return }
        self.states[district] = .failed(error.localizedDescription)
        self.measurements.append(.init(district: district.rawValue, package: package, seconds: Date().timeIntervalSince(start), memoryBeforeMB: before, memoryAfterMB: AtlantisMemory.footprintMB(), outcome: error.localizedDescription))
      }
      guard let self, self.tokens[district] == token else { return }; self.requests[district] = nil
    }
    requests[district] = task; return task
  }
  func unload(_ district: AtlantisDistrict) {
    tokens[district] = UUID(); requests.removeValue(forKey: district)?.cancel()
    if let entity = entities.removeValue(forKey: district) { onWillUnload?(district, entity); entity.removeFromParent() }
    states[district] = .unloaded
  }
  @discardableResult
  func loadContext() -> Task<Void,Never>? {
    if let contextTask { return contextTask }; guard contextState != .loaded else { return nil }
    let token = UUID(); contextToken = token; contextState = .loading; let source = source
    let task = Task { [weak self] in
      do {
        let entity = try await source.load(package: "world_context") { [weak self] phase, seconds in
          self?.phaseMeasurements.append(.init(district: "WorldContext", package: "world_context", phase: phase, seconds: seconds))
        }
        guard !Task.isCancelled, let self, self.contextToken == token else { return }
        entity.name = "WorldContext"; self.root.addChild(entity); self.onInstall?(nil, entity); self.contextState = .loaded
      } catch {
        guard !Task.isCancelled, let self, self.contextToken == token else { return }; self.contextState = .failed(error.localizedDescription)
      }
      guard let self, self.contextToken == token else { return }; self.contextTask = nil
    }
    contextTask = task; return task
  }
  @discardableResult
  func loadSupport(_ name: String) -> Task<Void,Never>? {
    if let task = supportTasks[name] { return task }
    guard supportEntities[name] == nil, let package = manifest.supportPackages?[name] else { return nil }
    let task = Task { [weak self] in
      defer { self?.supportTasks[name] = nil }
      do {
        guard let url = Bundle.main.url(forResource: package.package, withExtension: "usdz") else { throw CocoaError(.fileNoSuchFile) }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == package.sha256 else { throw AtlantisLoadError.invalidPackage("Support checksum: \(name)") }
        let entity = try await Entity(contentsOf: url)
        guard !Task.isCancelled, let self else { return }
        entity.name = name; self.root.addChild(entity); self.supportEntities[name] = entity; self.onInstall?(nil, entity)
      } catch {
        guard let self else { return }
        self.measurements.append(.init(district:name,package:package.package,seconds:0,memoryBeforeMB:AtlantisMemory.footprintMB(),memoryAfterMB:AtlantisMemory.footprintMB(),outcome:error.localizedDescription))
      }
    }
    supportTasks[name] = task
    return task
  }
  func unloadSupport(_ name: String) {
    supportTasks.removeValue(forKey:name)?.cancel()
    supportEntities.removeValue(forKey:name)?.removeFromParent()
  }
  func unloadAll() {
    for district in AtlantisDistrict.allCases { unload(district) }
    contextToken = UUID(); contextTask?.cancel(); contextTask = nil
    root.findEntity(named: "WorldContext")?.removeFromParent(); contextState = .unloaded
    for name in Array(supportTasks.keys) { unloadSupport(name) }
    for name in Array(supportEntities.keys) { unloadSupport(name) }
  }
}
#endif
