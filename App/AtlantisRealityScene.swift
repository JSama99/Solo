#if DEBUG
import RealityKit
import SwiftUI
import Observation

struct AtlantisFrameMeasurement: Codable {
  let name: String; let seconds: Double; let callbacks: Int; let approximateFPS: Double
  let meanFrameMS: Double; let p95FrameMS: Double; let longestFrameMS: Double
  let memoryMB: Double; let loadedDistricts: [String]
}
struct AtlantisStageMeasurement: Codable {
  let name: String; let loadSeconds: Double; let memoryBeforeMB: Double; let memoryAfterMB: Double
  let loadCallbacks: Int; let longestLoadFrameMS: Double
}
struct AtlantisWalkFinding: Codable {
  let route: String; let samples: Int; let missingGround: Int; let maximumHeightError: Float; let maximumGrade: Float; let obstructionCount: Int
  var rejectedSteps = 0
  var worstLocation: [Float] = []
  var method = "Ground triangle sweep at 0.2 m spacing; not a real-time end-to-end walk"
}
struct AtlantisBenchmarkReport: Codable {
  #if targetEnvironment(simulator)
  var configuration = "Debug; iOS Simulator; SceneEvents.Update cadence is not a GPU presentation counter"
  #else
  var configuration = "Debug; physical iOS device; SceneEvents.Update cadence is not a GPU presentation counter"
  #endif
  var device = UIDevice.current.model
  var os = UIDevice.current.systemVersion
  var assetMode = AtlantisImportExperiment.assetMode(arguments: ProcessInfo.processInfo.arguments)
  var startupMilestones: [String: Double] = [:]
  var stages: [AtlantisStageMeasurement] = []
  var frames: [AtlantisFrameMeasurement] = []
  var loads: [AtlantisLoadMeasurement] = []
  var loadPhases: [AtlantisLoadPhaseMeasurement] = []
  var walks: [AtlantisWalkFinding] = []
  var sampledPeakMemoryMB: Double = 0
  var errors: [String] = []
  var collisionEntityCount: Int = 0
  var unloadCycles: [[String: Double]] = []
  var lod: [[String: String]] = []
  var streaming: [AtlantisStreamingMeasurement] = []
}

struct AtlantisStreamingMeasurement: Codable {
  let transition: String; let prefetchDistanceMeters: Float; let loadSeconds: Double
  let readyBeforeBoundary: Bool; let memoryBeforeMB: Double; let memoryAfterMB: Double
  let longestLoadFrameMS: Double; let unloadFrameMS: Double; let residents: [String]
}

struct AtlantisDayPhaseComponent: Component, Codable { var phase: String }

/// Exact exported upward-facing triangles provide a bounded grounding query.
/// This is not a navmesh, simulation authority, or complete character controller.
struct AtlantisGrounding {
  let traversal: AtlantisAssetManifest.Traversal
  func height(at p: SIMD3<Float>, loaded: Set<String>, referenceHeight: Float? = nil) -> Float? {
    var candidates: [(height:Float,district:String)] = []
    for t in traversal.triangles where loaded.contains(t.district) && [.walkable,.collisionOnly].contains(t.surfaceClass ?? .nonwalkable) {
      let a=t.points[0].vector3, b=t.points[1].vector3, c=t.points[2].vector3
      let denominator=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
      guard abs(denominator)>0.00001 else { continue }
      let u=((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.z-c.z))/denominator
      let v=((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.z-c.z))/denominator
      guard u >= -0.0001, v >= -0.0001, u+v <= 1.0001 else { continue }
      let h=u*a.y+v*b.y+(1-u-v)*c.y
      candidates.append((h,t.district))
    }
    let owned = candidates.filter {$0.district == "TechUnicornBridge" || $0.district == "PrimaryRouteSupport"}
    let eligible = owned.isEmpty ? candidates : owned
    guard let referenceHeight else { return eligible.map(\.height).max() }
    return eligible.min { abs($0.height-referenceHeight) < abs($1.height-referenceHeight) }?.height
  }
  func blocked(_ p: SIMD3<Float>, loaded: Set<String>) -> Bool {
    traversal.barriers.contains { b in
      loaded.contains(b.district) && p.x > b.min[0]-0.25 && p.x < b.max[0]+0.25 && p.z > b.min[2]-0.25 && p.z < b.max[2]+0.25 && p.y < b.max[1]
    }
  }
}

@MainActor
final class AtlantisSemanticAnchorRegistry {
  private var anchors: [String: Entity] = [:]
  func register(district: AtlantisDistrict, root: Entity, manifest: AtlantisAssetManifest) {
    for name in manifest.streaming?.semanticAnchors[district.rawValue] ?? [] {
      if let entity = root.findEntity(named:name) { anchors[district.rawValue+"/"+name] = entity }
    }
  }
  func invalidate(district: AtlantisDistrict) {
    anchors.keys.filter { $0.hasPrefix(district.rawValue+"/") }.forEach { anchors.removeValue(forKey:$0) }
  }
  func entity(district: AtlantisDistrict, name: String) -> Entity? { anchors[district.rawValue+"/"+name] }
  var count: Int { anchors.count }
}

@MainActor @Observable
final class AtlantisStreamingCoordinator {
  private(set) var previous: AtlantisDistrict?
  private(set) var current: AtlantisDistrict = .founderDistrict
  private(set) var next: AtlantisDistrict? = .startupRow
  private(set) var prefetched: Set<AtlantisDistrict> = []
  private(set) var status = "Founder current"
  @ObservationIgnored private let loader: AtlantisDistrictLoader
  @ObservationIgnored private let policy: AtlantisStreamingPolicy
  @ObservationIgnored private let transitions: [AtlantisAssetManifest.TransitionRoute]
  @ObservationIgnored private let hardwareLoadSeconds: [String: Double]
  @ObservationIgnored private var transitionTask: Task<Void,Never>?

  init(loader: AtlantisDistrictLoader, manifest: AtlantisAssetManifest) {
    self.loader=loader;policy=manifest.streamingPolicy;transitions=manifest.streaming?.transitionRoutes ?? [];hardwareLoadSeconds=manifest.streaming?.hardwareLoadSeconds ?? [:]
  }
  var plan: AtlantisResidencyPlan { policy.plan(previous:previous,current:current,next:next) }
  var residents: Set<AtlantisDistrict> { Set(loader.loaded) }
  var pending: Set<AtlantisDistrict> { Set(loader.pending) }
  func protects(_ district: AtlantisDistrict) -> Bool { plan.protects(district) }
  func measuredLoadSeconds(for district: AtlantisDistrict) -> Double {
    max(hardwareLoadSeconds[district.rawValue] ?? 0,loader.measurements.last(where:{$0.district==district.rawValue && $0.outcome=="loaded"})?.seconds ?? 0.8)
  }
  func prefetchDistance(for district: AtlantisDistrict) -> Float { policy.prefetchDistance(measuredLoadSeconds:measuredLoadSeconds(for:district)) }
  func bootstrap() async {
    await loader.load(.founderDistrict)?.value
    if loader.states[.founderDistrict] == .loaded { prefetch(.startupRow) }
  }
  func requestUnload(_ district: AtlantisDistrict) -> Bool {
    guard !protects(district) else { status="Protected \(district.title) retained";return false }
    loader.unload(district);prefetched.remove(district);return true
  }
  func prefetch(_ district: AtlantisDistrict) {
    guard policy.areAdjacent(current,district),loader.states[district] != .loaded else{return}
    transitionTask?.cancel();status="Prefetching \(district.title)"
    transitionTask=Task { [weak self] in
      guard let self else{return};await self.loader.load(district)?.value
      guard !Task.isCancelled else{return}
      if self.loader.states[district] == .loaded {self.prefetched.insert(district);self.status="\(district.title) prefetched"}
      else {self.status="Prefetch failed; \(self.current.title) retained"}
      self.transitionTask=nil
    }
  }
  func enter(_ district: AtlantisDistrict, next requestedNext: AtlantisDistrict? = nil) async -> Bool {
    guard district==current || policy.areAdjacent(current,district) else {status="Rejected nonadjacent transition";return false}
    if loader.states[district] != .loaded {await loader.load(district)?.value}
    guard loader.states[district] == .loaded else {status="Transition failed; \(current.title) retained";return false}
    let old=current;previous = district==current ? previous : old;current=district
    next=requestedNext.flatMap {policy.areAdjacent(district,$0) ? $0:nil}
    prefetched.remove(district);status="\(district.title) current";reconcile();return true
  }
  func observe(position: SIMD3<Float>) {
    guard transitionTask == nil || transitionTask?.isCancelled == true else{return}
    for route in transitions {
      guard route.from==current.rawValue,let target=AtlantisDistrict(rawValue:route.to) else{continue}
      let distance=simd_distance(SIMD2(position.x,position.z),SIMD2(route.boundary[0],route.boundary[2]))
      if distance <= prefetchDistance(for:target),loader.states[target] == .unloaded {prefetch(target)}
      if distance <= 3,loader.states[target] == .loaded {
        transitionTask=Task { [weak self] in _=await self?.enter(target);self?.transitionTask=nil }
      }
    }
  }
  func reconcile() {
    let keep=plan.residents
    for district in loader.loaded where !keep.contains(district) {loader.unload(district);prefetched.remove(district)}
    if let next,loader.states[next] == .unloaded {prefetch(next)}
  }
}

@MainActor @Observable
final class AtlantisRealityWorld {
  let manifest: AtlantisAssetManifest
  let loader: AtlantisDistrictLoader
  let root = Entity(), playerRoot = Entity(), bodyHeadingRoot = Entity(), cameraRig = Entity(), camera = PerspectiveCamera()
  let sun = DirectionalLight(), environment = Entity(), collisionRoot = Entity()
  let semanticAnchors = AtlantisSemanticAnchorRegistry()
  let streaming: AtlantisStreamingCoordinator
  private(set) var error: String?
  private(set) var benchmarkStatus = "idle"
  private(set) var report = AtlantisBenchmarkReport()
  var selectedCamera = AtlantisBenchmarkCamera.founderStreet
  var phase = FounderEnvironmentTimeState.day
  var shadowMode = 0
  var locomotion: AtlantisLocomotionState = .standing
  var isWalking: Bool { locomotion == .walking }
  var walkInput: Float = 0
  private(set) var movementStatus = "Standing"
  @ObservationIgnored private var heading: Float = 0
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var benchmarkTask: Task<Void,Never>?
  @ObservationIgnored private var frameSamples: [Double] = []
  @ObservationIgnored private var collectingFrames = false
  @ObservationIgnored private var frameCounter = 0
  @ObservationIgnored private let createdAt = ContinuousClock.now
  @ObservationIgnored private let grounding: AtlantisGrounding

  init(manifest: AtlantisAssetManifest) {
    self.manifest=manifest;loader=AtlantisDistrictLoader(manifest:manifest);grounding=AtlantisGrounding(traversal:manifest.traversal);streaming=AtlantisStreamingCoordinator(loader:loader,manifest:manifest)
    root.name="AtlantisPresentation";playerRoot.name="AtlantisPlayerRoot";bodyHeadingRoot.name="BodyHeadingRoot";cameraRig.name="CameraRig";camera.name="Camera";collisionRoot.name="TraversalCollision"
    root.addChild(loader.root);root.addChild(playerRoot);playerRoot.addChild(bodyHeadingRoot);bodyHeadingRoot.addChild(cameraRig);cameraRig.addChild(camera);root.addChild(sun);root.addChild(environment);root.addChild(collisionRoot)
    camera.camera.near=0.2;camera.camera.far=8000
    let image=UIGraphicsImageRenderer(size:CGSize(width:32,height:16)).image { c in UIColor.white.setFill();c.fill(CGRect(x:0,y:0,width:32,height:16)) }
    if let cg=image.cgImage {
      do { let resource=try EnvironmentResource(equirectangular:cg);environment.components.set(ImageBasedLightComponent(source:.single(resource))) }
      catch { self.error="Environment: \(error.localizedDescription)" }
    }
    loader.onInstall={ [weak self] district,entity in
      guard let self else{return}
      entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight:self.environment))
      entity.components.set(AtlantisDayPhaseComponent(phase:self.phase.rawValue))
      if let district {self.semanticAnchors.register(district:district,root:entity,manifest:self.manifest)}
      if district == .unicornHeights {
        entity.findEntity(named:"Bridge_TechCore_00")?.isEnabled=false
        entity.findEntity(named:"Unicorn_BridgeWalk_00")?.isEnabled=false
      }
      self.syncSpireSwap()
    }
    loader.onWillUnload={ [weak self] district,_ in
      guard let self else{return};self.semanticAnchors.invalidate(district:district)
      if district == .techCore {self.loader.supportEntity(named:"SpireFarProxy")?.isEnabled=true}
    }
    selectCamera(.founderStreet);applyLighting()
  }
  func subscribe(_ install: (@escaping (SceneEvents.Update)->Void)->EventSubscription) {
    subscription?.cancel();subscription=install { [weak self] event in self?.update(delta:event.deltaTime) }
  }
  func stop() { subscription?.cancel();subscription=nil;benchmarkTask?.cancel();benchmarkTask=nil;walkInput=0;locomotion = .standing;loader.unloadAll() }
  func start() async {
    let startupStart = ContinuousClock.now
    print("Atlantis startup: loading context")
    await loader.loadContext()?.value
    print("Atlantis startup: context \(loader.contextState.label)")
    await streaming.bootstrap()
    await loader.loadSupport("TechUnicornBridge")?.value
    await loader.loadSupport("SpireFarProxy")?.value
    guard loader.contextState == .loaded,loader.states[.founderDistrict] == .loaded else {
      error="Context: \(loader.contextState.label); Founder: \(loader.states[.founderDistrict]?.label ?? "unknown")"
      report.errors.append(error ?? "Startup failed");report.loads=loader.measurements
      print("Atlantis startup failed: \(error ?? "unknown")");writeReport();benchmarkStatus="failed";return
    }
    print("Atlantis startup: Founder ready")
    report.startupMilestones["timeToFounderVisible"] = elapsed(since: startupStart)
    report.startupMilestones["timeToFounderPlayable"] = elapsed(since: startupStart)
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements
    benchmarkStatus="Founder ready"
    if ProcessInfo.processInfo.arguments.contains("--atlantis-streaming-profile") {
      await runStreamingBenchmark()
    } else if ProcessInfo.processInfo.arguments.contains("--atlantis-startup-profile") {
      let before=AtlantisMemory.footprintMB(),stageStart=Date()
      frameSamples=[];collectingFrames=true
      await loader.load(.startupRow)?.value
      collectingFrames=false
      report.stages.append(.init(
        name:"Startup prefetch",
        loadSeconds:Date().timeIntervalSince(stageStart),
        memoryBeforeMB:before,
        memoryAfterMB:AtlantisMemory.footprintMB(),
        loadCallbacks:frameSamples.count,
        longestLoadFrameMS:frameSamples.max() ?? 0
      ))
      guard loader.states[.startupRow] == .loaded else {
        error="Startup: \(loader.states[.startupRow]?.label ?? "unknown")"
        report.errors.append(error ?? "Startup failed")
        report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements
        writeReport();benchmarkStatus="failed";return
      }
      report.startupMilestones["timeToStartupReady"] = elapsed(since: startupStart)
      report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements
      writeReport();benchmarkStatus="complete"
    } else if ProcessInfo.processInfo.arguments.contains("--atlantis-founder-profile") {
      writeReport();benchmarkStatus="complete"
    }
  }
  func selectCamera(_ value: AtlantisBenchmarkCamera) {
    selectedCamera=value;locomotion = .standing;walkInput=0
    let r=value.recipe;playerRoot.position=r.position-[0,AtlantisSpatialContract.eyeHeight,0];cameraRig.transform = .identity;camera.transform = .identity
    camera.look(at:r.target,from:r.position,relativeTo:nil)
    let orientation=camera.orientation(relativeTo:nil);let forward=simd_normalize(r.target-r.position);heading=atan2(-forward.x,-forward.z)
    bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);cameraRig.orientation=bodyHeadingRoot.orientation.inverse*orientation;camera.orientation = .init();camera.position=[0,AtlantisSpatialContract.eyeHeight,0];camera.camera.fieldOfViewInDegrees=r.fov
  }
  func applyLighting() {
    let p=FounderEnvironmentLightingConfiguration.preset(for:phase)
    sun.look(at:[0,0,0],from:p.directionalPosition*100,relativeTo:nil)
    sun.light.intensity=p.directionalIntensity;sun.light.color=UIColor(red:CGFloat(p.directionalColor.x),green:CGFloat(p.directionalColor.y),blue:CGFloat(p.directionalColor.z),alpha:1)
    sun.shadow=shadowMode == 0 ? nil : .init(maximumDistance:shadowMode == 1 ? 120 : 500,depthBias:1)
    if var light=environment.components[ImageBasedLightComponent.self] { light.intensityExponent=phase == .night ? -5 : phase == .evening ? -3 : -1;environment.components.set(light) }
    for district in loader.loaded {loader.entity(for:district)?.components.set(AtlantisDayPhaseComponent(phase:phase.rawValue))}
  }
  var loadedNames: Set<String> {
    var names=Set(loader.loaded.map(\.rawValue));if loader.contextState == .loaded {names.insert("WorldContext")}
    if loader.supportEntity(named:"TechUnicornBridge") != nil {names.insert("TechUnicornBridge");names.insert("PrimaryRouteSupport")};return names
  }
  var farLandmarkState: String { loader.supportEntity(named:"SpireFarProxy")?.isEnabled == true ? "Spire proxy" : "Spire full" }
  func toggleWalk() {
    locomotion = isWalking ? .standing : .walking;walkInput=0
    if isWalking { bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);installCollision() }
  }
  func turn(_ radians: Float) { heading += radians;bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]) }
  func move(input: Float, delta: Double) {
    guard isWalking else{return}
    let distance=AtlantisSpatialContract.walkingSpeed*Float(min(max(delta,0),0.1))*max(-1,min(1,input))
    guard abs(distance)>0.00001 else{return}
    var next=playerRoot.position+SIMD3<Float>(-sin(heading)*distance,0,-cos(heading)*distance)
    guard let h=grounding.height(at:next,loaded:loadedNames,referenceHeight:playerRoot.position.y) else { movementStatus="Blocked: missing ground";return }
    guard abs(h-playerRoot.position.y)<=0.35 else { movementStatus="Blocked: step/drop at \(next.x), \(next.z)";return }
    next.y=h
    guard !grounding.blocked(next,loaded:loadedNames) else { movementStatus="Blocked: building envelope";return }
    playerRoot.position=next;streaming.observe(position:next);movementStatus=String(format:"Walking 1.4 m/s · %.1f, %.2f, %.1f",next.x,next.y,next.z)
  }
  private func update(delta: Double) {
    if report.startupMilestones["timeToFirstSceneUpdate"] == nil {
      report.startupMilestones["timeToFirstSceneUpdate"] = elapsed(since: createdAt)
    }
    if collectingFrames {frameSamples.append(delta*1000)}
    frameCounter += 1
    if frameCounter % 30 == 0 {let value=AtlantisMemory.footprintMB();if value>report.sampledPeakMemoryMB {report.sampledPeakMemoryMB=value}}
    if isWalking {move(input:walkInput,delta:delta)}
  }
  private func elapsed(since start: ContinuousClock.Instant) -> Double {
    let duration = start.duration(to: .now).components
    return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
  }
  func installCollision() {
    collisionRoot.children.removeAll()
    for b in manifest.traversal.barriers where loadedNames.contains(b.district) {
      let e=Entity();e.name=b.name+".Envelope";let lo=b.min.vector3,hi=b.max.vector3;e.position=(lo+hi)/2
      e.components.set(CollisionComponent(shapes:[.generateBox(size:hi-lo)]));collisionRoot.addChild(e)
    }
    report.collisionEntityCount=collisionRoot.children.count
  }
  func unload(_ district: AtlantisDistrict) {_=streaming.requestUnload(district);collisionRoot.children.removeAll();locomotion = .standing;walkInput=0;syncSpireSwap()}
  func unloadAll() {loader.unloadAll();collisionRoot.children.removeAll();locomotion = .standing;walkInput=0}
  private func syncSpireSwap() {
    guard let proxy=loader.supportEntity(named:"SpireFarProxy") else{return}
    proxy.isEnabled = loader.states[.techCore] != .loaded
  }
  func beginBenchmark() {
    guard benchmarkTask == nil else{return}
    benchmarkTask=Task { [weak self] in
      guard let self else{return}
      await self.runBenchmark();self.benchmarkTask=nil
    }
  }
  private func wait(_ seconds: Double) async { try? await Task.sleep(for:.seconds(seconds)) }
  private func sample(_ name: String, seconds: Double = 2) async {
    await wait(0.35);frameSamples=[];collectingFrames=true;let start=Date();await wait(seconds);collectingFrames=false
    let elapsed=Date().timeIntervalSince(start),sorted=frameSamples.sorted();let count=sorted.count
    report.frames.append(.init(name:name,seconds:elapsed,callbacks:count,approximateFPS:Double(count)/elapsed,meanFrameMS:count>0 ? sorted.reduce(0,+)/Double(count):0,p95FrameMS:count>0 ? sorted[min(count-1,Int(Double(count)*0.95))]:0,longestFrameMS:sorted.last ?? 0,memoryMB:AtlantisMemory.footprintMB(),loadedDistricts:loader.loaded.map(\.rawValue)))
  }
  private func runStreamingBenchmark() async {
    benchmarkStatus="streaming transitions"
    let forward:[(AtlantisDistrict,AtlantisDistrict?)]=[(.startupRow,.commerceDistrict),(.commerceDistrict,.techCore),(.techCore,.unicornHeights),(.unicornHeights,nil)]
    for (target,next) in forward {
      guard !Task.isCancelled else{return}
      let before=AtlantisMemory.footprintMB(),start=Date();frameSamples=[];collectingFrames=true
      await loader.load(target)?.value
      collectingFrames=false
      let load=Date().timeIntervalSince(start),ready=loader.states[target] == .loaded
      let unloadStart=ContinuousClock.now;let entered=await streaming.enter(target,next:next);let unloadMS=elapsed(since:unloadStart)*1000
      report.streaming.append(.init(
        transition:"\(streaming.previous?.title ?? "Start") → \(target.title)",
        prefetchDistanceMeters:streaming.prefetchDistance(for:target),loadSeconds:load,
        readyBeforeBoundary:ready && entered,memoryBeforeMB:before,memoryAfterMB:AtlantisMemory.footprintMB(),
        longestLoadFrameMS:frameSamples.max() ?? 0,unloadFrameMS:unloadMS,residents:loader.loaded.map(\.rawValue)
      ))
      report.sampledPeakMemoryMB=max(report.sampledPeakMemoryMB,AtlantisMemory.footprintMB())
      guard entered else {report.errors.append("Streaming transition failed: \(target.rawValue)");break}
    }
    for (target,next) in [(AtlantisDistrict.techCore,AtlantisDistrict.commerceDistrict),(.commerceDistrict,.startupRow),(.startupRow,.founderDistrict),(.founderDistrict,.startupRow)] {
      _=await streaming.enter(target,next:next)
    }
    for cycle in 1...3 {
      let before=AtlantisMemory.footprintMB(),start=Date()
      for (target,next) in [(AtlantisDistrict.startupRow,AtlantisDistrict.commerceDistrict),(.commerceDistrict,.startupRow),(.startupRow,.founderDistrict),(.founderDistrict,.startupRow)] {
        guard !Task.isCancelled else{return};_=await streaming.enter(target,next:next)
      }
      await wait(0.25)
      report.unloadCycles.append(["cycle":Double(cycle),"beforeMB":before,"afterMB":AtlantisMemory.footprintMB(),"seconds":Date().timeIntervalSince(start),"residentCount":Double(loader.loaded.count),"rootCount":Double(loader.root.children.count)])
    }
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements;writeReport();benchmarkStatus=report.errors.isEmpty ? "complete" : "failed"
  }
  private func runBenchmark() async {
    print("Atlantis benchmark: running")
    report=AtlantisBenchmarkReport();benchmarkStatus="running";unloadAll();await wait(1)
    await loader.loadContext()?.value
    let stages:[(String,[AtlantisDistrict])]=[("Founder only",[.founderDistrict]),("Founder + Startup",[.startupRow]),("+ Commerce",[.commerceDistrict]),("+ Tech Core",[.techCore]),("Full Atlantis",[.ventureDistrict,.mediaDistrict,.unicornHeights])]
    for (name,districts) in stages {
      guard !Task.isCancelled else{return};benchmarkStatus=name;print("Atlantis stage: \(name)");let before=AtlantisMemory.footprintMB(),start=Date()
      frameSamples=[];collectingFrames=true
      for d in districts {await loader.load(d)?.value}
      collectingFrames=false
      report.stages.append(.init(name:name,loadSeconds:Date().timeIntervalSince(start),memoryBeforeMB:before,memoryAfterMB:AtlantisMemory.footprintMB(),loadCallbacks:frameSamples.count,longestLoadFrameMS:frameSamples.max() ?? 0))
      guard districts.allSatisfy({loader.states[$0] == .loaded}) else {report.errors.append("Load failure: \(name)");writeReport();benchmarkStatus="failed";return}
      await sample("load-stage: "+name)
    }
    if ProcessInfo.processInfo.arguments.contains("--atlantis-import-profile") {
      report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements;writeReport();selectCamera(.atlantisAerial);benchmarkStatus="complete";return
    }
    for view in AtlantisBenchmarkCamera.allCases {guard !Task.isCancelled else{return};benchmarkStatus=view.rawValue;selectCamera(view);await sample(view.rawValue)}
    selectCamera(.commerceFlashpoint)
    for mode in 0...2 {guard !Task.isCancelled else{return};shadowMode=mode;applyLighting();await sample("shadows-\(mode)")}
    shadowMode=0
    for state in FounderEnvironmentTimeState.allCases {guard !Task.isCancelled else{return};phase=state;applyLighting();await sample("lighting-\(state.rawValue)",seconds:1)}
    phase = .day;applyLighting()
    for cycle in 1...3 {
      guard !Task.isCancelled else{return}
      let before=AtlantisMemory.footprintMB();unload(.unicornHeights);await wait(1);let after=AtlantisMemory.footprintMB();await loader.load(.unicornHeights)?.value;let reload=AtlantisMemory.footprintMB()
      report.unloadCycles.append(["cycle":Double(cycle),"beforeMB":before,"afterUnloadMB":after,"afterReloadMB":reload,"rootCount":Double(loader.root.children.filter{$0.name == AtlantisDistrict.unicornHeights.rawValue}.count)])
    }
    selectCamera(.founderStreet);await sample("collision-off",seconds:1);installCollision();await sample("collision-on",seconds:1)
    await walkSweep();await lodExperiment()
    guard !Task.isCancelled else{return}
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements;writeReport();selectCamera(.atlantisAerial);benchmarkStatus="complete"
  }
  private func walkSweep() async {
    let bridge = AtlantisAssetManifest.Route(name:"Bridge_TechCore runtime incline",points:[[360,15,-470],[600,86,-760]])
    for route in manifest.traversal.routes + [bridge] {
      guard !Task.isCancelled else{return}
      var rejectedSteps=0;var previousHeight:Float?;var worstLocation:[Float]=[]
      var samples=0,missing=0,obstructions=0;var maxError:Float=0,maxGrade:Float=0
      for (aa,bb) in zip(route.points,route.points.dropFirst()) {
        let a=aa.vector3,b=bb.vector3,distance=simd_length(SIMD2<Float>(b.x-a.x,b.z-a.z));maxGrade=max(maxGrade,abs(b.y-a.y)/max(distance,0.001))
        let steps=max(1,Int(ceil(distance/0.2)))
        for i in 0...steps {
          let p=a+(b-a)*(Float(i)/Float(steps));samples += 1
          if let y=grounding.height(at:p,loaded:loadedNames) {
            if abs(y-p.y)>maxError {maxError=abs(y-p.y);worstLocation=[p.x,y,p.z]}
            if let previousHeight,abs(y-previousHeight)>0.35 {rejectedSteps += 1}
            previousHeight=y;playerRoot.position=[p.x,y,p.z]
          } else {missing += 1;previousHeight=nil}
          if grounding.blocked(p,loaded:loadedNames) {obstructions += 1}
          if samples % 100 == 0 {await Task.yield()}
        }
      }
      report.walks.append(.init(route:route.name,samples:samples,missingGround:missing,maximumHeightError:maxError,maximumGrade:maxGrade,obstructionCount:obstructions,rejectedSteps:rejectedSteps,worstLocation:worstLocation))
      report.walks.append(await controllerSweep(route))
    }
  }
  /// Drives the same bounded move() used by controls with fixed 0.1 s simulation
  /// steps. Accelerated wall time is explicitly distinguished from a human walk.
  func controllerSweep(_ route: AtlantisAssetManifest.Route) async -> AtlantisWalkFinding {
    var finding=AtlantisWalkFinding(route:route.name+" controller",samples:0,missingGround:0,maximumHeightError:0,maximumGrade:0,obstructionCount:0)
    guard let first=route.points.first?.vector3,let y=grounding.height(at:first,loaded:loadedNames) else {
      return .init(route:route.name+" controller",samples:0,missingGround:1,maximumHeightError:0,maximumGrade:0,obstructionCount:0)
    }
    playerRoot.position=[first.x,y,first.z];locomotion = .walking;walkInput=0
    defer {locomotion = .standing;walkInput=0}
    var steps=0,blocked=0
    outer: for point in route.points.dropFirst() {
      let target=point.vector3
      while simd_length(SIMD2<Float>(target.x-playerRoot.position.x,target.z-playerRoot.position.z))>0.02 {
        guard !Task.isCancelled,steps<50000 else {blocked += 1;break outer}
        let offset=target-playerRoot.position,distance=simd_length(SIMD2<Float>(offset.x,offset.z))
        heading=atan2(-offset.x,-offset.z);let before=playerRoot.position
        move(input:min(1,distance/0.14),delta:0.1);steps += 1
        if playerRoot.position == before {blocked += 1;break outer}
        if steps % 100 == 0 {await Task.yield()}
      }
    }
    let end=route.points.last!.vector3
    finding = .init(route:route.name+" controller",samples:steps,missingGround:movementStatus.contains("missing ground") && blocked>0 ? 1:0,maximumHeightError:abs(playerRoot.position.y-end.y),maximumGrade:0,obstructionCount:movementStatus.contains("building") && blocked>0 ? 1:0,rejectedSteps:blocked,worstLocation:[playerRoot.position.x,playerRoot.position.y,playerRoot.position.z],method:"Same move() as UI; accelerated fixed 0.1 s steps at 1.4 m/s; stops at first rejection. Final position is worstLocation; height error compares intended endpoint.")
    return finding
  }
  private func lodExperiment() async {
    let names=["Founder_Building_00","Startup_LoftContext","Commerce_Building_01","PallasAIHQ","TheSpire"]
    for name in names {
      guard !Task.isCancelled else{return}
      guard let entity=loader.root.findEntity(named:name),let parent=entity.parent else {report.errors.append("LOD representative missing: \(name)");continue}
      let bounds=entity.visualBounds(relativeTo:parent)
      cameraRig.transform = .identity;playerRoot.position=bounds.center+[bounds.extents.x*2,bounds.extents.y*0.7,bounds.extents.z*3];camera.position=[0,1.7,0];camera.look(at:bounds.center,from:camera.position(relativeTo:nil),relativeTo:nil)
      await sample("LOD-original: "+name,seconds:1)
      let proxy=ModelEntity(mesh:.generateBox(size:bounds.extents),materials:[SimpleMaterial(color:.gray,isMetallic:false)]);proxy.name=name+".LODExperiment";proxy.position=bounds.center;parent.addChild(proxy);entity.isEnabled=false
      await sample("LOD-box: "+name,seconds:1)
      report.lod.append(["asset":name,"proxyTriangles":"12","visualLoss":"All facade, crown and silhouette detail replaced by bounds; experiment only"])
      entity.isEnabled=true;proxy.removeFromParent()
    }
  }
  private func writeReport() {
    do {
      let url=URL.documentsDirectory.appending(path:"atlantis-benchmark.json");let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(report).write(to:url,options:.atomic)
    } catch {self.error="Benchmark report: \(error.localizedDescription)"}
  }
}
#endif
