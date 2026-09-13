#if DEBUG
import RealityKit
import SwiftUI
import Observation
import Darwin

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
  var interactions: [AtlantisInteractionMeasurement] = []
  var registeredInteractionTargets = 0
  var interactionCandidateEvaluations = 0
  var meanInteractionCandidateMicroseconds: Double = 0
  var livingWorld: [AtlantisLivingWorldMeasurement] = []
  var livingReactions: [String:[String:Double]] = [:]
  var livingStreaming: [AtlantisLivingWorldTransitionMeasurement] = []
  var livingPooling: [[String: Double]] = []
}

struct AtlantisStreamingMeasurement: Codable {
  let transition: String; let prefetchDistanceMeters: Float; let loadSeconds: Double
  let readyBeforeBoundary: Bool; let memoryBeforeMB: Double; let memoryAfterMB: Double
  let longestLoadFrameMS: Double; let unloadFrameMS: Double; let residents: [String]
}

struct AtlantisInteractionMeasurement: Codable {
  let target: String; let cycle: Int; let intentDispatchMS: Double; let returnMS: Double
  let memoryBeforeMB: Double; let memoryAfterMB: Double; let registeredTargets: Int
  let worldRootCount: Int; let positionRestored: Bool; let headingRestored: Bool
  let phasePreserved: Bool; let residencyPreserved: Bool
}

struct AtlantisLivingWorldMeasurement: Codable {
  let configuration: String; let pedestrians: Int; let vehicles: Int; let seconds: Double
  let callbackSamples: Int; let meanCallbackMS: Double; let p95CallbackMS: Double
  let meanPopulationUpdateMS: Double; let p95PopulationUpdateMS: Double
  let processCPUPercent: Double; let memoryBeforeMB: Double; let memoryAfterMB: Double
  let spawnHitchMS: Double; let thermalBefore: String; let thermalAfter: String
  var gpuMetric = "Unavailable from in-process instrumentation; callback cadence is not GPU FPS"
}

struct AtlantisLivingWorldTransitionMeasurement: Codable {
  let transition: String; let actorsBefore: Int; let actorsAfter: Int
  let duplicateActors: Bool; let memoryBeforeMB: Double; let memoryAfterMB: Double; let result: String
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

@MainActor
final class AtlantisInteractionTarget {
  let definition: AtlantisInteractionDefinition
  weak var entity: Entity?
  init(definition: AtlantisInteractionDefinition, entity: Entity) { self.definition=definition;self.entity=entity }
}

@MainActor
final class AtlantisInteractionRegistry {
  private var targetsByID: [String: AtlantisInteractionTarget] = [:]
  private(set) var evaluationCount = 0
  private(set) var evaluationNanoseconds: UInt64 = 0

  var count: Int { targetsByID.count }
  var registeredIDs: Set<String> { Set(targetsByID.keys) }
  func target(id: String) -> AtlantisInteractionTarget? { targetsByID[id] }

  func register(district: AtlantisDistrict, root: Entity) {
    unregister(district:district)
    for definition in AtlantisInteractionDefinition.definitions(for:district) {
      guard targetsByID[definition.id] == nil,let entity=root.findEntity(named:definition.anchorName) else{continue}
      targetsByID[definition.id]=AtlantisInteractionTarget(definition:definition,entity:entity)
    }
  }

  func unregister(district: AtlantisDistrict) {
    targetsByID = targetsByID.filter {$0.value.definition.district != district}
  }

  func candidate(position: SIMD3<Float>,forward: SIMD3<Float>,residentDistricts: Set<AtlantisDistrict>) -> AtlantisInteractionTarget? {
    let start=DispatchTime.now().uptimeNanoseconds
    defer {evaluationCount += 1;evaluationNanoseconds += DispatchTime.now().uptimeNanoseconds-start}
    let candidates=targetsByID.values.compactMap { target -> AtlantisInteractionCandidateScore? in
      let definition=target.definition
      guard target.entity != nil,residentDistricts.contains(definition.district),definition.availability == .available else{return nil}
      let offset=definition.activationPosition-position,distance=simd_length(SIMD2<Float>(offset.x,offset.z))
      guard distance <= definition.activationRadius else{return nil}
      if let threshold=definition.minimumFacingDot,distance>0.001 {
        let targetDirection=simd_normalize(SIMD2<Float>(offset.x,offset.z)),look=simd_normalize(SIMD2<Float>(forward.x,forward.z))
        guard simd_dot(targetDirection,look) >= threshold else{return nil}
      }
      return .init(id:definition.id,priority:definition.priority,distance:distance)
    }
    return AtlantisInteractionSelectionPolicy.select(candidates).flatMap {targetsByID[$0]}
  }

  var meanEvaluationMicroseconds: Double {
    guard evaluationCount>0 else{return 0};return Double(evaluationNanoseconds)/Double(evaluationCount)/1_000
  }
}

struct AtlantisInteractionReturnContext: Equatable {
  let targetID: String
  let position: SIMD3<Float>
  let heading: Float
  let phase: FounderEnvironmentTimeState
  let previous: AtlantisDistrict?
  let current: AtlantisDistrict
  let next: AtlantisDistrict?
  let residents: Set<AtlantisDistrict>
}

@MainActor
final class AtlantisAmbientActor {
  let entity=Entity()
  let kind: AtlantisAmbientActorKind
  var district: AtlantisDistrict?
  var route: AtlantisAmbientRoute?
  var behavior = AtlantisAmbientBehavior.idle
  var progress: Float = 0
  var speed: Float = 0
  var animationPhase: Float = 0
  private var animationElapsed: Float = 0
  private static let pedestrianBody = MeshResource.generateBox(size:[0.34,0.86,0.24])
  private static let pedestrianLeg = MeshResource.generateBox(size:[0.12,0.4,0.15])
  private static let pedestrianHead = MeshResource.generateSphere(radius:0.20)
  private static let vehicleBody = MeshResource.generateBox(size:[1.65,0.48,3.5])
  private static let vehicleCabin = MeshResource.generateBox(size:[1.35,0.42,1.65])

  init(kind: AtlantisAmbientActorKind,index: Int) {
    self.kind=kind;entity.name="AtlantisAmbientPool.\(kind.rawValue).\(index)"
    if kind == .pedestrian {
      let palette:[UIColor]=[.systemTeal,.systemOrange,.systemPurple,.systemBlue]
      let material=SimpleMaterial(color:palette[index%palette.count],roughness:0.8,isMetallic:false)
      let body=ModelEntity(mesh:Self.pedestrianBody,materials:[material]);body.position.y=0.82
      let head=ModelEntity(mesh:Self.pedestrianHead,materials:[SimpleMaterial(color:.systemBrown,roughness:0.9,isMetallic:false)]);head.position.y=1.47
      entity.addChild(body);entity.addChild(head)
      for x:Float in [-0.1,0.1] {let leg=ModelEntity(mesh:Self.pedestrianLeg,materials:[material]);leg.position=[x,0.2,0];entity.addChild(leg)}
    } else {
      let palette:[UIColor]=[.systemRed,.systemIndigo,.systemGray]
      let body=ModelEntity(mesh:Self.vehicleBody,materials:[SimpleMaterial(color:palette[index%palette.count],roughness:0.55,isMetallic:true)]);body.position.y=0.45
      let cabin=ModelEntity(mesh:Self.vehicleCabin,materials:[SimpleMaterial(color:.darkGray,roughness:0.35,isMetallic:true)]);cabin.position=[0,0.86,-0.15]
      entity.addChild(body);entity.addChild(cabin)
    }
    entity.components.remove(CollisionComponent.self)
  }

  func configure(district: AtlantisDistrict,route: AtlantisAmbientRoute,index: Int,seed: UInt64) {
    self.district=district;self.route=route
    for child in entity.children { child.orientation = simd_quatf(angle:0,axis:[0,1,0]) }
    let unit=AtlantisPresentationSeed.unit(route.id,index:index,seed:seed)
    animationElapsed=0;progress=unit;animationPhase=AtlantisPresentationSeed.unit(route.id,index:index+71,seed:seed)*(.pi*2)
    speed=kind == .vehicle ? 4.5+unit*1.5 : 0.72+unit*0.32
    behavior=kind == .vehicle ? .walk : AtlantisAmbientBehavior.allCases[Int(AtlantisPresentationSeed.value(route.id,index:index,seed:seed)%UInt64(AtlantisAmbientBehavior.allCases.count))]
    let scale:Float=kind == .vehicle ? 0.92+unit*0.12 : 0.92+unit*0.10
    entity.scale=[scale,scale,scale];entity.isEnabled=true;update(delta:0,reduceMotion:false)
  }

  func deactivate() {district=nil;route=nil;entity.removeFromParent();entity.isEnabled=false}

  func update(delta: Double,reduceMotion: Bool) {
    guard let route,route.points.count>1 else{return}
    let moving=kind == .vehicle || behavior == .walk
    if moving {progress += speed*Float(delta)/max(1,routeLength(route));progress.formTruncatingRemainder(dividingBy:2)}
    let routeProgress=progress<=1 ? progress:2-progress
    let scaled=max(0,routeProgress)*Float(route.points.count-1),segment=min(route.points.count-2,Int(scaled)),t=scaled-Float(segment)
    let a=route.points[segment],b=route.points[segment+1];entity.position=simd_mix(a,b,SIMD3<Float>(repeating:t))
    let direction=(b-a)*(progress<=1 ? Float(1):Float(-1));if simd_length_squared(SIMD2<Float>(direction.x,direction.z))>0.001 {entity.orientation=simd_quatf(angle:atan2(direction.x,direction.z),axis:[0,1,0])}
    guard kind == .pedestrian else{return}
    if reduceMotion { entity.children.first?.orientation = .init();return }
    animationElapsed += Float(min(max(delta,0),0.1))
    let time=animationPhase+animationElapsed*3
    switch behavior {
    case .idle: entity.position.y += sin(time)*0.012
    case .phoneIdle: entity.children.first?.orientation=simd_quatf(angle:-0.05+sin(time)*0.02,axis:[1,0,0])
    case .talkGesture: entity.children.first?.orientation=simd_quatf(angle:sin(time)*0.06,axis:[0,0,1])
    case .walk: entity.position.y += abs(sin(time))*0.025
    }
  }

  private func routeLength(_ route: AtlantisAmbientRoute) -> Float {
    zip(route.points,route.points.dropFirst()).reduce(0){$0+simd_distance($1.0,$1.1)}
  }
}

@MainActor @Observable
final class AtlantisLivingWorldDistrictPopulation {
  let root=Entity()
  private(set) var allocatedPedestrians=0
  private(set) var allocatedVehicles=0
  private(set) var reusedPedestrians=0
  private(set) var reusedVehicles=0
  private(set) var recycledActors=0
  private(set) var lastReconcileMS:Double=0
  private(set) var maximumSpawnHitchMS:Double=0
  @ObservationIgnored private(set) var updateSamples:[Double]=[]
  @ObservationIgnored private var active:[AtlantisDistrict:[AtlantisAmbientActor]]=[:]
  @ObservationIgnored private var pedestrianPool:[AtlantisAmbientActor]=[]
  @ObservationIgnored private var vehiclePool:[AtlantisAmbientActor]=[]
  @ObservationIgnored private var benchmarkOverride:(district:AtlantisDistrict,pedestrians:Int,vehicles:Int)?
  var isEnabled=false
  var reduceMotion=false
  var reactions:[AtlantisDistrict:AtlantisDistrictReaction]=[:]
  private var lods:[AtlantisDistrict:AtlantisLivingWorldLOD]=[:]
  private var midElapsed=0.0
  let seed:UInt64=0x534F4C4F_41544C41

  init(){root.name="AtlantisLivingWorld"}
  var activePedestrians:Int {active.values.flatMap{$0}.filter{$0.kind == .pedestrian}.count}
  var activeVehicles:Int {active.values.flatMap{$0}.filter{$0.kind == .vehicle}.count}
  var pooledPedestrians:Int {pedestrianPool.count}
  var pooledVehicles:Int {vehiclePool.count}
  var activeActorCount:Int {activePedestrians+activeVehicles}
  var residentDistrictCount:Int {active.keys.count}
  var activeEntityIDs:Set<ObjectIdentifier> {Set(active.values.flatMap{$0}.map{ObjectIdentifier($0.entity)})}
  var meanUpdateMicroseconds:Double {updateSamples.isEmpty ? 0:updateSamples.reduce(0,+)/Double(updateSamples.count)*1_000}
  var p95UpdateMS:Double {let s=updateSamples.sorted();return s.isEmpty ? 0:s[min(s.count-1,Int(Double(s.count)*0.95))]}

  func setBenchmarkPopulation(district:AtlantisDistrict,pedestrians:Int,vehicles:Int){isEnabled=true;benchmarkOverride=(district,min(20,max(0,pedestrians)),min(2,max(0,vehicles)))}
  func clearBenchmarkPopulation(){benchmarkOverride=nil}
  func resetUpdateMeasurements(){updateSamples=[];maximumSpawnHitchMS=0}

  func districtDidUnload(_ district:AtlantisDistrict){release(district:district,kind:nil,count:Int.max)}

  func reconcile(residents:Set<AtlantisDistrict>,current:AtlantisDistrict,phase:FounderEnvironmentTimeState,playerPosition:SIMD3<Float>,immediate:Bool=false) {
    let start=DispatchTime.now().uptimeNanoseconds
    for district in AtlantisDistrict.allCases where !residents.contains(district){districtDidUnload(district)}
    guard isEnabled else {for district in AtlantisDistrict.allCases{districtDidUnload(district)};lastReconcileMS=milliseconds(since:start);return}
    var remainingPedestrians=benchmarkOverride?.pedestrians ?? AtlantisLivingWorldPresentationAdapter.pedestrianBudget
    var remainingVehicles=benchmarkOverride?.vehicles ?? AtlantisLivingWorldPresentationAdapter.vehicleBudget
    let ordered=AtlantisDistrict.allCases.sorted {lhs,rhs in
      if lhs==rhs{return false};if lhs==current{return true};if rhs==current{return false}
      return anchor(for:lhs).priority>anchor(for:rhs).priority
    }
    var targets:[AtlantisDistrict:(pedestrians:Int,vehicles:Int)]=[:]
    for district in ordered {
      guard residents.contains(district) else{continue}
      let anchor=anchor(for:district)
      let lod=AtlantisLivingWorldTuning.lod(distance:simd_distance(SIMD2<Float>(anchor.position.x,anchor.position.z),SIMD2<Float>(playerPosition.x,playerPosition.z)))
      lods[district]=lod
      let profile=AtlantisLivingWorldPresentationAdapter.profile(district:district,phase:phase)
      let requestedPedestrians:Int,requestedVehicles:Int
      if let value=benchmarkOverride {
        requestedPedestrians=value.district==district ? value.pedestrians:0;requestedVehicles=value.district==district ? value.vehicles:0
      } else {
        let desired=reactions[district]?.pedestrians ?? profile.pedestrians
        requestedPedestrians=lod == .far ? 0:lod == .mid ? min(2,desired):min(desired,anchor.maximumActors)
        requestedVehicles=lod == .near ? (reactions[district]?.vehicles ?? profile.vehicles):0
      }
      let pedestrians=min(requestedPedestrians,remainingPedestrians),vehicles=min(requestedVehicles,remainingVehicles)
      remainingPedestrians-=pedestrians;remainingVehicles-=vehicles
      targets[district]=(pedestrians,vehicles)
    }
    // Recycle first so handoff cannot temporarily exceed the global cap or
    // allocate another district's population before its pool is available.
    for district in ordered {
      let target=targets[district] ?? (pedestrians:0,vehicles:0)
      for (kind,count) in [(AtlantisAmbientActorKind.pedestrian,target.pedestrians),(.vehicle,target.vehicles)] {
        let excess=self.count(district:district,kind:kind)-count
        if excess>0 {
          let overBudget=kind == .pedestrian ? activePedestrians>(benchmarkOverride?.pedestrians ?? 10):activeVehicles>(benchmarkOverride?.vehicles ?? 2)
          release(district:district,kind:kind,count:immediate || overBudget ? excess:min(excess,2))
        }
      }
    }
    let pedestrianCap=benchmarkOverride?.pedestrians ?? AtlantisLivingWorldPresentationAdapter.pedestrianBudget
    let vehicleCap=benchmarkOverride?.vehicles ?? AtlantisLivingWorldPresentationAdapter.vehicleBudget
    for district in ordered {
      let target=targets[district] ?? (pedestrians:0,vehicles:0)
      let p=self.count(district:district,kind:.pedestrian),v=self.count(district:district,kind:.vehicle)
      if p<target.pedestrians {adjust(district:district,kind:.pedestrian,target:min(target.pedestrians,p+max(0,pedestrianCap-activePedestrians)),maximumChange:immediate ? Int.max:2)}
      if v<target.vehicles {adjust(district:district,kind:.vehicle,target:min(target.vehicles,v+max(0,vehicleCap-activeVehicles)),maximumChange:immediate ? Int.max:2)}
    }
    lastReconcileMS=milliseconds(since:start);maximumSpawnHitchMS=max(maximumSpawnHitchMS,lastReconcileMS)
  }

  func update(delta:Double) {
    guard isEnabled else{return};let start=DispatchTime.now().uptimeNanoseconds
    midElapsed += delta
    let updateMid=midElapsed>=AtlantisLivingWorldTuning.midMotionInterval
    for (district,actors) in active {
      guard lods[district] != .mid || updateMid else{continue}
      for actor in actors {actor.update(delta:lods[district] == .mid ? midElapsed:delta,reduceMotion:reduceMotion)}
    }
    if updateMid {midElapsed=0}
    updateSamples.append(milliseconds(since:start));if updateSamples.count>1_200{updateSamples.removeFirst(200)}
  }

  func count(district:AtlantisDistrict,kind:AtlantisAmbientActorKind?=nil)->Int {
    active[district,default:[]].filter{kind==nil || $0.kind==kind}.count
  }
  func center(district:AtlantisDistrict)->SIMD3<Float>? {
    let actors=active[district,default:[]];guard !actors.isEmpty else{return nil}
    return actors.reduce(SIMD3<Float>.zero){$0+$1.entity.position}/Float(actors.count)
  }

  private func anchor(for district:AtlantisDistrict)->AtlantisActivityAnchorDefinition {
    AtlantisLivingWorldPresentationAdapter.activityAnchors.first{$0.district==district}!
  }
  private func adjust(district:AtlantisDistrict,kind:AtlantisAmbientActorKind,target:Int,maximumChange:Int) {
    let count=self.count(district:district,kind:kind)
    if count<target {
      let additions=min(target-count,maximumChange)
      for index in count..<(count+additions){spawn(district:district,kind:kind,index:index)}
    } else if count>target {release(district:district,kind:kind,count:min(count-target,maximumChange))}
  }
  private func spawn(district:AtlantisDistrict,kind:AtlantisAmbientActorKind,index:Int) {
    let routes=AtlantisLivingWorldPresentationAdapter.routes(district:district,kind:kind);guard !routes.isEmpty else{return}
    let actor:AtlantisAmbientActor
    if kind == .pedestrian,let pooled=pedestrianPool.popLast(){actor=pooled;reusedPedestrians+=1}
    else if kind == .vehicle,let pooled=vehiclePool.popLast(){actor=pooled;reusedVehicles+=1}
    else {actor=AtlantisAmbientActor(kind:kind,index:kind == .pedestrian ? allocatedPedestrians:allocatedVehicles);if kind == .pedestrian{allocatedPedestrians+=1}else{allocatedVehicles+=1}}
    actor.entity.name="AtlantisAmbient.\(district.rawValue).\(kind.rawValue).\(index)"
    actor.configure(district:district,route:routes[index%routes.count],index:index,seed:seed);root.addChild(actor.entity);active[district,default:[]].append(actor)
  }
  private func release(district:AtlantisDistrict,kind:AtlantisAmbientActorKind?,count:Int) {
    guard var actors=active[district] else{return};var remaining=count,index=actors.count-1
    while index>=0,remaining>0 {
      let actor=actors[index]
      if kind==nil || actor.kind==kind {actors.remove(at:index);actor.deactivate();if actor.kind == .pedestrian{pedestrianPool.append(actor)}else{vehiclePool.append(actor)};recycledActors+=1;remaining-=1}
      index-=1
    }
    if actors.isEmpty{active.removeValue(forKey:district)}else{active[district]=actors}
  }
  private func milliseconds(since start:UInt64)->Double{Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000}
}

struct AtlantisNamedInteractionCandidate {
  let npc: AtlantisNamedNPCDefinition
  let encounter: AtlantisNamedEncounterDefinition
  let distance: Float
}

struct AtlantisNamedEncounterSession: Identifiable, Equatable {
  let npc: AtlantisNamedNPCDefinition
  let encounter: AtlantisNamedEncounterDefinition
  var selectedResponse: AtlantisNamedEncounterResponse?
  var id: String {encounter.id}
}

@MainActor
final class AtlantisNamedNPCEntity {
  let definition: AtlantisNamedNPCDefinition
  let root=Entity()
  private let torso:ModelEntity,head:ModelEntity,glyph:ModelEntity,nameplate=ModelEntity(),subtitle=ModelEntity()
  var lifecycle=AtlantisNamedNPCLifecycle.despawned
  private var phase:Float=0

  init(definition:AtlantisNamedNPCDefinition,index:Int) {
    self.definition=definition
    let palette:[UIColor]=[.systemCyan,.systemMint,.systemIndigo,.systemOrange,.systemGreen,.systemPurple]
    torso=ModelEntity(mesh:.generateBox(size:[0.46,0.92,0.3]),materials:[SimpleMaterial(color:palette[index%palette.count],roughness:0.55,isMetallic:false)])
    head=ModelEntity(mesh:.generateSphere(radius:0.22),materials:[SimpleMaterial(color:.systemBrown,roughness:0.85,isMetallic:false)])
    glyph=ModelEntity(mesh:.generateSphere(radius:0.09),materials:[UnlitMaterial(color:.white)])
    root.name=definition.interactionID;root.position=definition.position
    torso.position.y=0.86;head.position.y=1.55;glyph.position=[0,2.06,0]
    nameplate.position=[-0.7,1.96,0.03];subtitle.position=[-0.7,1.72,0.03]
    root.addChild(torso);root.addChild(head);root.addChild(glyph);root.addChild(nameplate);root.addChild(subtitle)
    setText(nameplate,definition.displayName,size:0.14)
    setText(subtitle,"\(definition.role.title) · \(definition.affiliation)",size:0.085)
    root.components.remove(CollisionComponent.self)
  }

  func setLifecycle(_ value:AtlantisNamedNPCLifecycle,founderPosition:SIMD3<Float>,reduceMotion:Bool) {
    lifecycle=value
    if [.engaged].contains(value) {
      let offset=founderPosition-root.position
      root.orientation=simd_quatf(angle:atan2(offset.x,offset.z),axis:[0,1,0])
    }
    glyph.isEnabled=value == .available || value == .engaged
    torso.scale=value == .engaged && !reduceMotion ? [1.03,1.03,1.03]:[1,1,1]
  }

  func update(delta:Double,reduceMotion:Bool) {
    guard !reduceMotion else{head.orientation = .init();return}
    phase += Float(max(0,min(delta,0.25)))
    let amount:Float=lifecycle == .engaged ? 0.08:0.035
    head.orientation=simd_quatf(angle:sin(phase*1.4)*amount,axis:[0,1,0])
    glyph.position.y=2.06+sin(phase*1.8)*0.025
  }

  private func setText(_ entity:ModelEntity,_ value:String,size:CGFloat) {
    entity.model=ModelComponent(mesh:.generateText(value,extrusionDepth:0.001,font:.systemFont(ofSize:size,weight:.semibold),containerFrame:.zero,alignment:.left,lineBreakMode:.byClipping),materials:[UnlitMaterial(color:.white)])
  }
}

/// Bounded, session-only named encounter state. It consumes public snapshots and
/// never retains GameStore or writes canonical simulation values.
@MainActor @Observable
final class AtlantisNamedEncounterDirector {
  let root=Entity()
  var isEnabled=false
  var reduceMotion=false
  var fixture:AtlantisNamedEncounterFixture? {didSet {if oldValue != fixture {cooldownUntil=[:];activeSession=nil}}}
  private(set) var activeSession:AtlantisNamedEncounterSession?
  private(set) var eligibleEncounterCount=0
  private(set) var presentationOnlyResponseCount=0
  private(set) var deferredResponseCount=0
  private(set) var canonicalWritebackCount=0
  private(set) var duplicateViolations=0
  private(set) var reusedEntityCount=0
  private(set) var decisionCostMS=0.0
  @ObservationIgnored private var entities:[String:AtlantisNamedNPCEntity]=[:]
  @ObservationIgnored private var cooldownUntil:[String:Double]=[:]
  @ObservationIgnored private var elapsed=0.0
  @ObservationIgnored private var latestSignals=AtlantisLivingWorldFixture.baseline.snapshot
  @ObservationIgnored private var latestPhase=FounderEnvironmentTimeState.day
  @ObservationIgnored private var latestResidents:Set<AtlantisDistrict>=[]

  init(){root.name="AtlantisNamedEncounterDirector"}
  var activeNPCIDs:[String]{entities.values.filter{$0.root.parent != nil}.map{$0.definition.id}.sorted()}
  var namedNPCCount:Int{activeNPCIDs.count}
  var cooldownCount:Int{cooldownUntil.values.filter{$0>elapsed}.count}
  var cooldownSummary:String {
    let active=cooldownUntil.filter{$0.value>elapsed}.map{"\($0.key) \(Int(ceil($0.value-elapsed)))s"}.sorted()
    return active.isEmpty ? "none":active.joined(separator:", ")
  }
  var publicSignalClassification:String {
    if latestSignals.coverage <= -40 || latestSignals.trust<35{return "public scrutiny"}
    if latestSignals.rivals.contains(where:{$0.claimedMomentum>=70}){return "public rival surge"}
    if latestSignals.coverage>=40{return "public spotlight"}
    if latestSignals.momentum>=70{return "public momentum"}
    return "baseline public state"
  }
  func entity(npcID:String)->AtlantisNamedNPCEntity?{entities[npcID]}
  func state(npcID:String)->AtlantisNamedNPCLifecycle?{entities[npcID]?.lifecycle}

  func advance(delta:Double) {
    elapsed += max(0,min(delta,0.25))
    for entity in entities.values where entity.root.parent != nil {entity.update(delta:delta,reduceMotion:reduceMotion)}
  }

  func reconcile(residents:Set<AtlantisDistrict>,phase:FounderEnvironmentTimeState,
                 position:SIMD3<Float>,signals:AtlantisWorldSignalSnapshot,immediate:Bool=false) {
    let start=DispatchTime.now().uptimeNanoseconds
    latestSignals=fixture?.snapshot ?? signals;latestPhase=phase;latestResidents=residents
    let cooling=Set(cooldownUntil.filter{$0.value>elapsed}.map(\.key))
    let residentNPCs=AtlantisNamedNPCDefinition.all.filter{residents.contains($0.homeDistrict)}
    let baseEligible=AtlantisNamedEncounterDefinition.all.filter { encounter in
      residentNPCs.contains{$0.id==encounter.npcID} && AtlantisNamedEncounterPolicy.eligible(encounter,signals:latestSignals,phase:phase,fixture:fixture)
    }
    eligibleEncounterCount=baseEligible.filter{!cooling.contains($0.id)}.count
    let desired=Set(baseEligible.map(\.npcID))
    for (id,entity) in entities where !isEnabled || !desired.contains(id) {
      if entity.root.parent != nil {entity.root.removeFromParent()}
      entity.lifecycle = .despawned
    }
    if isEnabled {
      for npc in residentNPCs where desired.contains(npc.id) {
        let entity:AtlantisNamedNPCEntity
        let wasExisting=entities[npc.id] != nil
        if let existing=entities[npc.id] {entity=existing} else {
          entity=AtlantisNamedNPCEntity(definition:npc,index:entities.count);entities[npc.id]=entity
        }
        if entity.root.parent == nil {if wasExisting{reusedEntityCount += 1};root.addChild(entity.root)}
        let encounters=baseEligible.filter{$0.npcID==npc.id}
        let lifecycle:AtlantisNamedNPCLifecycle
        if activeSession?.npc.id == npc.id {lifecycle = .engaged}
        else if encounters.allSatisfy({cooling.contains($0.id)}) {lifecycle = .coolingDown}
        else {lifecycle = .available}
        entity.setLifecycle(lifecycle,founderPosition:position,reduceMotion:reduceMotion)
      }
    }
    let ids=root.children.map(\.name),duplicates=ids.count-Set(ids).count
    if duplicates>0{duplicateViolations += duplicates}
    decisionCostMS=Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000
  }

  func candidate(position:SIMD3<Float>,forward:SIMD3<Float>)->AtlantisNamedInteractionCandidate? {
    guard isEnabled,activeSession == nil else{return nil}
    let cooling=Set(cooldownUntil.filter{$0.value>elapsed}.map(\.key))
    return entities.values.compactMap {entity -> AtlantisNamedInteractionCandidate? in
      let npc=entity.definition
      guard entity.root.parent != nil,entity.lifecycle == .available else{return nil}
      let offset=npc.position-position,distance=simd_length(SIMD2<Float>(offset.x,offset.z))
      guard distance<=npc.interactionRadius else{return nil}
      let encounters=AtlantisNamedEncounterDefinition.all.filter{$0.npcID==npc.id}
      guard let selected=AtlantisNamedEncounterPolicy.select(encounters,signals:latestSignals,phase:latestPhase,fixture:fixture,cooling:cooling) else{return nil}
      return .init(npc:npc,encounter:selected,distance:distance)
    }.sorted {
      if $0.encounter.priority != $1.encounter.priority{return $0.encounter.priority>$1.encounter.priority}
      if $0.distance != $1.distance{return $0.distance<$1.distance}
      return $0.npc.id<$1.npc.id
    }.first
  }

  func begin(npcID:String,encounterID:String,founderPosition:SIMD3<Float>)->AtlantisNamedEncounterSession? {
    guard activeSession == nil,let npc=AtlantisNamedNPCDefinition.all.first(where:{$0.id==npcID}),
          let encounter=AtlantisNamedEncounterDefinition.all.first(where:{$0.id==encounterID && $0.npcID==npcID}),
          entity(npcID:npcID)?.root.parent != nil else{return nil}
    let session=AtlantisNamedEncounterSession(npc:npc,encounter:encounter,selectedResponse:nil);activeSession=session
    entity(npcID:npcID)?.setLifecycle(.engaged,founderPosition:founderPosition,reduceMotion:reduceMotion)
    return session
  }

  @discardableResult func respond(responseID:String)->AtlantisNamedEncounterResponse? {
    guard var session=activeSession,session.selectedResponse == nil,
          let response=session.encounter.responses.first(where:{$0.id==responseID}) else{return nil}
    session.selectedResponse=response;activeSession=session
    switch response.consequence {
    case .presentationOnly: presentationOnlyResponseCount += 1
    case .deferredConsequence: deferredResponseCount += 1
    case .existingCanonicalAction: canonicalWritebackCount += 1
    }
    return response
  }

  @discardableResult func dismiss()->Bool {
    guard let session=activeSession else{return false}
    cooldownUntil[session.encounter.id]=elapsed+45
    entity(npcID:session.npc.id)?.lifecycle = .coolingDown
    activeSession=nil;return true
  }

  func districtDidUnload(_ district:AtlantisDistrict) {
    for entity in entities.values where entity.definition.homeDistrict==district {
      entity.root.removeFromParent();entity.lifecycle = .despawned
    }
    if activeSession?.npc.homeDistrict==district {activeSession=nil}
  }
}

@MainActor
final class AtlantisWorldConsequencePresentation {
  let site:AtlantisWorldConsequenceSite
  let root=Entity()
  private let base=ModelEntity(mesh:.generateBox(size:[10,0.18,4]))
  private let signBoard=ModelEntity(mesh:.generateBox(size:[9,1.7,0.16]))
  private let signText=ModelEntity()
  private var construction:[ModelEntity]=[]
  private var event:[ModelEntity]=[]
  private var occupied:[ModelEntity]=[]
  private var key=""
  private(set) var definition:AtlantisWorldConsequenceDefinition?

  init(site:AtlantisWorldConsequenceSite) {
    self.site=site;root.name="AtlantisConsequence.\(site.rawValue)"
    base.position=[0,0.1,0];signBoard.position=[0,2.5,-1.7];signText.position=[-4.2,2.65,-1.79]
    root.addChild(base);root.addChild(signBoard);root.addChild(signText)
    for index in 0..<3 {
      let prop=ModelEntity(mesh:.generateBox(size:[1.5,0.65,1.1]));prop.position=[Float(index-1)*2.1,0.42,0.8];construction.append(prop);root.addChild(prop)
    }
    for index in 0..<5 {
      let prop=ModelEntity(mesh:.generateBox(size:[0.22,2.2,0.22]));prop.position=[Float(index-2)*1.7,1.15,-1.2];event.append(prop);root.addChild(prop)
    }
    for index in 0..<4 {
      let strip=ModelEntity(mesh:.generateBox(size:[1.5,0.12,0.1]));strip.position=[Float(index-2)*1.8+0.9,1.35,-1.8];occupied.append(strip);root.addChild(strip)
    }
    for child in root.children {child.components.remove(CollisionComponent.self)}
  }

  var entityCount:Int{1+root.children.count}
  var activeConstructionProps:Int{construction.filter(\.isEnabled).count}
  var activeEventProps:Int{event.filter(\.isEnabled).count}
  var activeSignageCount:Int{root.isEnabled ? 1:0}

  func apply(_ value:AtlantisWorldConsequenceDefinition,reduceMotion:Bool) {
    definition=value;root.isEnabled=true
    guard key != value.id else{return};key=value.id
    let color:UIColor=switch value.state {
    case .baseline:.systemGray
    case .growth:.systemMint
    case .spotlight:.systemCyan
    case .scrutiny:.systemOrange
    case .surge:.systemPurple
    case .event:.systemPink
    }
    base.model?.materials=[SimpleMaterial(color:color.withAlphaComponent(0.8),roughness:0.75,isMetallic:false)]
    signBoard.model?.materials=[UnlitMaterial(color:color)]
    signText.model=ModelComponent(mesh:.generateText(value.signage,extrusionDepth:0.002,font:.systemFont(ofSize:0.38,weight:.bold),containerFrame:.zero,alignment:.left,lineBreakMode:.byClipping),materials:[UnlitMaterial(color:.white)])
    for (index,prop) in construction.enumerated() {
      prop.isEnabled=index<value.constructionProps
      prop.model?.materials=[SimpleMaterial(color:.systemYellow,roughness:0.9,isMetallic:false)]
    }
    for (index,prop) in event.enumerated() {
      prop.isEnabled=index<value.eventProps
      prop.model?.materials=[UnlitMaterial(color:index.isMultiple(of:2) ? color:.white)]
    }
    for (index,strip) in occupied.enumerated() {
      strip.isEnabled=index < max(1,min(4,2+value.activityModifier))
      strip.model?.materials=[UnlitMaterial(color:color.withAlphaComponent(reduceMotion ? 0.75:1))]
    }
  }
}

/// Reproducible world consequences derived from public state. Presentation roots
/// attach only to verified district anchors and are reconstructed on every load.
@MainActor @Observable
final class AtlantisWorldConsequenceDirector {
  let root=Entity()
  var isEnabled=false
  var reduceMotion=false
  var fixture:AtlantisWorldConsequenceFixture?
  private(set) var state=AtlantisWorldConsequenceState(active:[])
  private(set) var reconciliationCostMS=0.0
  private(set) var duplicateViolations=0
  private(set) var exclusiveGroupConflicts=0
  private(set) var missingAnchorCount=0
  @ObservationIgnored private var presentations:[AtlantisWorldConsequenceSite:AtlantisWorldConsequencePresentation]=[:]
  @ObservationIgnored private var attachedDistricts:Set<AtlantisDistrict>=[]
  @ObservationIgnored private(set) var latestSignals=AtlantisLivingWorldFixture.baseline.snapshot

  init(){root.name="AtlantisWorldConsequenceDirector"}
  var effectiveSignals:AtlantisWorldSignalSnapshot{fixture?.snapshot ?? latestSignals}
  var activeIDs:[String]{presentations.values.compactMap{$0.root.parent == nil || !$0.root.isEnabled ? nil:$0.definition?.id}.sorted()}
  var activeStateCount:Int{activeIDs.count}
  var activeEventState:String{state.active.first{$0.category == .publicEvent}?.id ?? "none"}
  var founderHQState:String{state.definition(site:.founderHQ)?.state.rawValue ?? "none"}
  var rivalCampusStates:String{[AtlantisWorldConsequenceSite.pallasCampus,.northwindCampus,.flashpointCampus].compactMap{site in state.definition(site:site).map{"\(site.rawValue)=\($0.state.rawValue)"}}.joined(separator:", ")}
  var activeSignageCount:Int{presentations.values.reduce(0){$0+($1.root.parent == nil ? 0:$1.activeSignageCount)}}
  var activeConstructionPropCount:Int{presentations.values.reduce(0){$0+($1.root.parent == nil || !$1.root.isEnabled ? 0:$1.activeConstructionProps)}}
  var activeEventPropCount:Int{presentations.values.reduce(0){$0+($1.root.parent == nil || !$1.root.isEnabled ? 0:$1.activeEventProps)}}
  var activeEntityCount:Int{presentations.values.reduce(0){$0+($1.root.parent == nil || !$1.root.isEnabled ? 0:$1.entityCount)}}
  func definition(site:AtlantisWorldConsequenceSite)->AtlantisWorldConsequenceDefinition?{state.definition(site:site)}

  func districtDidLoad(_ district:AtlantisDistrict,root districtRoot:Entity) {
    attachedDistricts.insert(district)
    for site in AtlantisWorldConsequenceSite.allCases {
      guard let definition=AtlantisWorldConsequenceDefinition.all.first(where:{$0.site==site && $0.district==district}) else{continue}
      guard let anchor=districtRoot.findEntity(named:definition.targetAnchor) else{missingAnchorCount += 1;continue}
      let presentation:AtlantisWorldConsequencePresentation
      if let existing=presentations[site] {presentation=existing} else {presentation=AtlantisWorldConsequencePresentation(site:site);presentations[site]=presentation}
      if presentation.root.parent !== anchor {presentation.root.removeFromParent();anchor.addChild(presentation.root)}
    }
  }

  func districtDidUnload(_ district:AtlantisDistrict) {
    attachedDistricts.remove(district)
    for presentation in presentations.values where AtlantisWorldConsequenceDefinition.all.first(where:{$0.site==presentation.site})?.district==district {
      presentation.root.removeFromParent()
    }
  }

  func reconcile(residents:Set<AtlantisDistrict>,signals:AtlantisWorldSignalSnapshot) {
    let start=DispatchTime.now().uptimeNanoseconds;latestSignals=signals
    state=AtlantisWorldConsequencePolicy.derive(signals:effectiveSignals,fixture:fixture)
    for (site,presentation) in presentations {
      guard isEnabled,let definition=state.definition(site:site),residents.contains(definition.district),presentation.root.parent != nil else{presentation.root.isEnabled=false;continue}
      presentation.apply(definition,reduceMotion:reduceMotion)
    }
    let physical=presentations.values.filter{$0.root.parent != nil && $0.root.isEnabled}
    let names=physical.map{$0.root.name};if names.count != Set(names).count{duplicateViolations += 1}
    var groups:Set<String>=[];var conflicts=0
    for definition in physical.compactMap(\.definition) {for group in definition.exclusiveGroups {if !groups.insert(group).inserted{conflicts += 1}}}
    exclusiveGroupConflicts=conflicts
    reconciliationCostMS=Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000
  }
}

/// All living presentation is orchestrated here; this type never retains GameStore.
@MainActor @Observable
final class AtlantisLivingWorldDirector {
  let population = AtlantisLivingWorldDistrictPopulation()
  let namedEncounters = AtlantisNamedEncounterDirector()
  let consequences = AtlantisWorldConsequenceDirector()
  let root = Entity()
  private(set) var signals = AtlantisLivingWorldFixture.baseline.snapshot
  var fixture: AtlantisLivingWorldFixture? {didSet {if oldValue != fixture {encounterLine="";activeEncounters=0;encounterDistrict=nil;cooldowns=[:];encounterExpires=0}}}
  private(set) var reactions: [AtlantisDistrict:AtlantisDistrictReaction] = [:]
  private(set) var encounterLine = ""
  private(set) var activeDisplays = 0
  private(set) var activeEncounters = 0
  private(set) var encounterActivations = 0
  private(set) var decisionCostMS = 0.0
  @ObservationIgnored private var displays: [AtlantisDistrict:AtlantisPublicDisplay] = [:]
  @ObservationIgnored private var cooldowns: [AtlantisAmbientEncounter:Double] = [:]
  @ObservationIgnored private var elapsed = 0.0
  @ObservationIgnored private var nextDecision = 0.0
  @ObservationIgnored private var encounterExpires = 0.0
  @ObservationIgnored private var encounterDistrict: AtlantisDistrict?

  init() {root.name="AtlantisLivingWorldDirector";root.addChild(population.root);root.addChild(namedEncounters.root);root.addChild(consequences.root)}
  func receive(_ snapshot: AtlantisWorldSignalSnapshot) {signals=snapshot}
  var effectiveSignals: AtlantisWorldSignalSnapshot {fixture?.snapshot ?? signals}
  var entityCount: Int {
    func count(_ entity:Entity)->Int {1+entity.children.reduce(0){$0+count($1)}}
    return count(root)
  }

  func advance(delta:Double,residents:Set<AtlantisDistrict>,current:AtlantisDistrict,
               phase:FounderEnvironmentTimeState,position:SIMD3<Float>) {
    elapsed += max(0,min(delta,0.25));population.update(delta:delta);namedEncounters.advance(delta:delta)
    guard elapsed>=nextDecision else{return}
    nextDecision=elapsed+AtlantisLivingWorldTuning.decisionInterval
    reconcile(residents:residents,current:current,phase:phase,position:position)
  }

  func reconcile(residents:Set<AtlantisDistrict>,current:AtlantisDistrict,
                 phase:FounderEnvironmentTimeState,position:SIMD3<Float>,immediate:Bool=false) {
    let start=DispatchTime.now().uptimeNanoseconds
    consequences.reconcile(residents:residents,signals:effectiveSignals)
    let presentationSignals=consequences.effectiveSignals
    reactions=Dictionary(uniqueKeysWithValues:AtlantisDistrict.allCases.map {
      ($0,AtlantisWorldReactionAdapter.derive(presentationSignals,district:$0,phase:phase))
    })
    population.reactions=reactions
    population.reconcile(residents:residents,current:current,phase:phase,playerPosition:position,immediate:immediate)
    namedEncounters.reconcile(residents:residents,phase:phase,position:position,signals:presentationSignals,immediate:immediate)
    let encounterPosition=encounterDistrict.flatMap{displays[$0]?.root.position}
    let leftEncounter=encounterPosition.map{simd_distance(SIMD2(position.x,position.z),SIMD2($0.x,$0.z))>AtlantisLivingWorldTuning.encounterRadius} ?? false
    if elapsed>=encounterExpires || leftEncounter || !population.isEnabled || !residents.contains(encounterDistrict ?? current) {
      encounterLine="";activeEncounters=0;encounterDistrict=nil
    }
    activeDisplays=0
    for district in AtlantisDistrict.allCases {
      let visible=population.isEnabled && residents.contains(district)
      guard visible,let reaction=reactions[district] else {displays[district]?.root.isEnabled=false;continue}
      let display:AtlantisPublicDisplay
      if let existing=displays[district] {display=existing} else {
        display=AtlantisPublicDisplay(district:district);displays[district]=display;root.addChild(display.root)
      }
      display.root.isEnabled=true;activeDisplays+=1
      let distance=simd_distance(SIMD2(position.x,position.z),SIMD2(display.root.position.x,display.root.position.z))
      if activeEncounters==0,distance<=AtlantisLivingWorldTuning.encounterRadius,
         let kind=reaction.encounter,elapsed >= cooldowns[kind,default:0] {
        encounterLine=reaction.encounterLine;encounterDistrict=district;activeEncounters=1
        encounterActivations += 1
        encounterExpires=elapsed+AtlantisLivingWorldTuning.encounterDuration
        cooldowns[kind]=elapsed+AtlantisLivingWorldTuning.encounterCooldown
      }
      display.apply(reaction,phase:phase,line:encounterDistrict==district ? encounterLine:"")
    }
    decisionCostMS=Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000
  }
  func districtDidUnload(_ district:AtlantisDistrict) {
    population.districtDidUnload(district);namedEncounters.districtDidUnload(district);consequences.districtDidUnload(district);displays[district]?.root.isEnabled=false
    if encounterDistrict==district {encounterDistrict=nil;encounterLine="";activeEncounters=0}
    activeDisplays=displays.values.filter{$0.root.isEnabled}.count
  }
}

/// One reusable, collision-free street display per district. Text changes only
/// when public content changes. No video, per-display timers, or unbounded cache.
@MainActor
final class AtlantisPublicDisplay {
  let root=Entity()
  private let board=ModelEntity(mesh:.generateBox(size:[14,3.4,0.18]))
  private let title=ModelEntity(),detail=ModelEntity(),line=ModelEntity()
  private let mediaCamera=ModelEntity(mesh:.generateBox(size:[0.7,0.45,0.8]))
  private let beacon=ModelEntity(mesh:.generateBox(size:[0.5,4,0.5]))
  private var key=""
  init(district:AtlantisDistrict) {
    root.name="AtlantisPublicDisplay.\(district.rawValue)"
    let route=AtlantisLivingWorldPresentationAdapter.routes(district:district,kind:.pedestrian)[0]
    root.position=route.points[route.points.count/2]+SIMD3<Float>(0,0,-4)
    board.position=[0,3.3,0];title.position=[-6.5,4.1,0.12];detail.position=[-6.5,3.3,0.12];line.position=[-6.5,2.3,0.12]
    mediaCamera.position=[-8,1.5,2];beacon.position=[8,2,0]
    for entity in [board,title,detail,line,mediaCamera,beacon] {root.addChild(entity)}
    mediaCamera.model?.materials=[SimpleMaterial(color:.darkGray,isMetallic:false)]
  }
  func apply(_ reaction:AtlantisDistrictReaction,phase:FounderEnvironmentTimeState,line ambient:String) {
    let newKey="\(reaction.headline)|\(reaction.detail)|\(ambient)|\(phase.rawValue)"
    guard newKey != key else{return};key=newKey
    let color:UIColor=switch reaction.reaction {case .ordinary:.darkGray;case .interest:.systemTeal;case .scrutiny:.systemOrange;case .rival:.systemPurple}
    board.model?.materials=[UnlitMaterial(color:color.withAlphaComponent(1))]
    beacon.model?.materials=[UnlitMaterial(color:color)]
    beacon.isEnabled=reaction.reaction != .ordinary
    mediaCamera.isEnabled=reaction.encounter == .reporter
    setText(title,reaction.headline,size:0.55);setText(detail,reaction.detail,size:0.34)
    setText(line,ambient,size:0.22)
    // Night changes display emphasis without introducing a second time authority.
    board.scale.y=phase == .night ? 1.12:1
  }
  private func setText(_ entity:ModelEntity,_ value:String,size:CGFloat) {
    entity.isEnabled = !value.isEmpty
    guard !value.isEmpty else{return}
    entity.model=ModelComponent(mesh:.generateText(value,extrusionDepth:0.002,font:.systemFont(ofSize:size),containerFrame:.zero,alignment:.left,lineBreakMode:.byWordWrapping),materials:[UnlitMaterial(color:.white)])
  }
}

enum AtlantisProcessMetrics {
  static func cpuSeconds()->Double {
    var usage=rusage();guard getrusage(0,&usage)==0 else{return 0}
    func seconds(_ value:timeval)->Double{Double(value.tv_sec)+Double(value.tv_usec)/1_000_000}
    return seconds(usage.ru_utime)+seconds(usage.ru_stime)
  }
  static var thermal:String {
    switch ProcessInfo.processInfo.thermalState {case .nominal:"nominal";case .fair:"fair";case .serious:"serious";case .critical:"critical";@unknown default:"unknown"}
  }
}

@MainActor @Observable
final class AtlantisStreamingCoordinator {
  private(set) var previous: AtlantisDistrict?
  private(set) var current: AtlantisDistrict = .founderDistrict
  private(set) var next: AtlantisDistrict? = .startupRow
  private(set) var prefetched: Set<AtlantisDistrict> = []
  private(set) var status = "Founder current"
  private(set) var isFrozen = false
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
    guard !isFrozen else{return}
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
  func setFrozen(_ frozen: Bool) {isFrozen=frozen;status=frozen ? "Streaming retained for interaction" : "\(current.title) current"}
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
  let interactionRegistry = AtlantisInteractionRegistry()
  let livingDirector = AtlantisLivingWorldDirector()
  var livingWorld: AtlantisLivingWorldDistrictPopulation {livingDirector.population}
  let streaming: AtlantisStreamingCoordinator
  private(set) var error: String?
  private(set) var benchmarkStatus = "idle"
  private(set) var report = AtlantisBenchmarkReport()
  private(set) var activeInteractionID: String?
  private(set) var activeNamedNPCID: String?
  private(set) var activeNamedEncounterID: String?
  private(set) var interactionReturnContext: AtlantisInteractionReturnContext?
  private(set) var interactionStatus = "No nearby interaction"
  var selectedCamera = AtlantisBenchmarkCamera.founderStreet
  var phase = FounderEnvironmentTimeState.day
  var shadowMode = 0
  var locomotion: AtlantisLocomotionState = .standing
  var isWalking: Bool { locomotion == .walking }
  var walkInput: Float = 0
  private(set) var movementStatus = "Standing"
  @ObservationIgnored private(set) var heading: Float = 0
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
    root.addChild(loader.root);root.addChild(livingDirector.root);root.addChild(playerRoot);playerRoot.addChild(bodyHeadingRoot);bodyHeadingRoot.addChild(cameraRig);cameraRig.addChild(camera);root.addChild(sun);root.addChild(environment);root.addChild(collisionRoot)
    livingWorld.isEnabled=ProcessInfo.processInfo.arguments.contains("--atlantis-living-world") || ProcessInfo.processInfo.arguments.contains("--atlantis-living-world-profile")
    livingDirector.namedEncounters.isEnabled=livingWorld.isEnabled || ProcessInfo.processInfo.arguments.contains("--atlantis-named-encounters")
    livingDirector.consequences.isEnabled=livingWorld.isEnabled || ProcessInfo.processInfo.arguments.contains("--atlantis-world-consequences")
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
      if let district {
        self.semanticAnchors.register(district:district,root:entity,manifest:self.manifest)
        self.interactionRegistry.register(district:district,root:entity)
        self.livingDirector.consequences.districtDidLoad(district,root:entity)
        self.livingDirector.reconcile(residents:self.streaming.residents,current:self.streaming.current,phase:self.phase,position:self.playerRoot.position,immediate:true)
      }
      if district == .unicornHeights {
        entity.findEntity(named:"Bridge_TechCore_00")?.isEnabled=false
        entity.findEntity(named:"Unicorn_BridgeWalk_00")?.isEnabled=false
      }
      self.syncSpireSwap()
    }
    loader.onWillUnload={ [weak self] district,_ in
      guard let self else{return}
      let invalidatesBuilding=self.activeInteraction?.definition.district == district
      let invalidatesNamed=self.activeNamedNPCID.flatMap{id in AtlantisNamedNPCDefinition.all.first{$0.id==id}}?.homeDistrict == district
      self.semanticAnchors.invalidate(district:district);self.interactionRegistry.unregister(district:district)
      self.livingDirector.districtDidUnload(district)
      if invalidatesBuilding || invalidatesNamed {self.activeInteractionID=nil;self.activeNamedNPCID=nil;self.activeNamedEncounterID=nil;self.interactionStatus="Interaction unavailable: district unloaded"}
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
    refreshInteractionCandidate()
    report.startupMilestones["timeToFounderVisible"] = elapsed(since: startupStart)
    report.startupMilestones["timeToFounderPlayable"] = elapsed(since: startupStart)
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements
    benchmarkStatus="Founder ready"
    if ProcessInfo.processInfo.arguments.contains("--atlantis-living-world-profile") {
      await runLivingWorldBenchmark()
    } else if ProcessInfo.processInfo.arguments.contains("--atlantis-interaction-profile") {
      await runInteractionBenchmark()
    } else if ProcessInfo.processInfo.arguments.contains("--atlantis-streaming-profile") {
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
    bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);cameraRig.orientation=bodyHeadingRoot.orientation.inverse*orientation;camera.orientation = .init();camera.position=[0,AtlantisSpatialContract.eyeHeight,0];camera.camera.fieldOfViewInDegrees=r.fov;refreshInteractionCandidate()
  }
  func selectLivingWorldCamera(_ district: AtlantisDistrict) {
    guard let center=livingWorld.center(district:district) else{return}
    let target=center+[0,0.8,0],position=center+[12,2.5,32]
    locomotion = .standing;walkInput=0;playerRoot.position=position-[0,AtlantisSpatialContract.eyeHeight,0];cameraRig.transform = .identity;camera.transform = .identity
    camera.look(at:target,from:position,relativeTo:nil);let orientation=camera.orientation(relativeTo:nil),forward=simd_normalize(target-position)
    heading=atan2(-forward.x,-forward.z);bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);cameraRig.orientation=bodyHeadingRoot.orientation.inverse*orientation;camera.orientation = .init();camera.position=[0,AtlantisSpatialContract.eyeHeight,0];camera.camera.fieldOfViewInDegrees=58;refreshInteractionCandidate()
  }
  func applyLighting() {
    let p=FounderEnvironmentLightingConfiguration.preset(for:phase)
    sun.look(at:[0,0,0],from:p.directionalPosition*100,relativeTo:nil)
    sun.light.intensity=p.directionalIntensity;sun.light.color=UIColor(red:CGFloat(p.directionalColor.x),green:CGFloat(p.directionalColor.y),blue:CGFloat(p.directionalColor.z),alpha:1)
    sun.shadow=shadowMode == 0 ? nil : .init(maximumDistance:shadowMode == 1 ? 120 : 500,depthBias:1)
    if var light=environment.components[ImageBasedLightComponent.self] { light.intensityExponent=phase == .night ? -5 : phase == .evening ? -3 : -1;environment.components.set(light) }
    for district in loader.loaded {loader.entity(for:district)?.components.set(AtlantisDayPhaseComponent(phase:phase.rawValue))}
    livingDirector.reconcile(residents:streaming.residents,current:streaming.current,phase:phase,position:playerRoot.position)
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
    playerRoot.position=next;streaming.observe(position:next);refreshInteractionCandidate();movementStatus=String(format:"Walking 1.4 m/s · %.1f, %.2f, %.1f",next.x,next.y,next.z)
  }
  private func update(delta: Double) {
    if report.startupMilestones["timeToFirstSceneUpdate"] == nil {
      report.startupMilestones["timeToFirstSceneUpdate"] = elapsed(since: createdAt)
    }
    if collectingFrames {frameSamples.append(delta*1000)}
    if !isPresentingInteraction {livingDirector.advance(delta:delta,residents:streaming.residents,current:streaming.current,phase:phase,position:playerRoot.position)}
    else if isPresentingNamedEncounter {livingDirector.namedEncounters.advance(delta:delta)}
    frameCounter += 1
    if frameCounter % 30 == 0 {let value=AtlantisMemory.footprintMB();if value>report.sampledPeakMemoryMB {report.sampledPeakMemoryMB=value};refreshInteractionCandidate()}
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
  func unloadAll() {loader.unloadAll();for district in AtlantisDistrict.allCases{livingDirector.districtDidUnload(district)};collisionRoot.children.removeAll();locomotion = .standing;walkInput=0;activeInteractionID=nil;activeNamedNPCID=nil;activeNamedEncounterID=nil;interactionReturnContext=nil;streaming.setFrozen(false)}

  var activeInteraction: AtlantisInteractionTarget? {activeInteractionID.flatMap(interactionRegistry.target(id:))}
  var interactionPrompt: String {
    if let id=activeNamedNPCID,let npc=AtlantisNamedNPCDefinition.all.first(where:{$0.id==id}) {return "Talk to \(npc.displayName)"}
    return activeInteraction?.definition.accessibilityLabel ?? interactionStatus
  }
  var isPresentingInteraction: Bool {interactionReturnContext != nil}
  var isPresentingNamedEncounter: Bool {livingDirector.namedEncounters.activeSession != nil}

  func refreshInteractionCandidate() {
    guard interactionReturnContext == nil else{return}
    let forward=SIMD3<Float>(-sin(heading),0,-cos(heading))
    let building=interactionRegistry.candidate(position:playerRoot.position,forward:forward,residentDistricts:streaming.residents)
    let named=livingDirector.namedEncounters.candidate(position:playerRoot.position,forward:forward)
    var scores:[AtlantisInteractionCandidateScore]=[]
    if let building {
      let offset=building.definition.activationPosition-playerRoot.position
      scores.append(.init(id:building.definition.id,priority:building.definition.priority,distance:simd_length(SIMD2<Float>(offset.x,offset.z))))
    }
    if let named {scores.append(.init(id:named.npc.interactionID,priority:named.encounter.priority,distance:named.distance))}
    activeInteractionID=AtlantisInteractionSelectionPolicy.select(scores)
    if activeInteractionID == named?.npc.interactionID {activeNamedNPCID=named?.npc.id;activeNamedEncounterID=named?.encounter.id}
    else {activeNamedNPCID=nil;activeNamedEncounterID=nil}
    interactionStatus=activeInteractionID == nil ? "No nearby interaction" : "Ready"
  }

  func beginInteraction() -> AtlantisInteractionIntent? {
    refreshInteractionCandidate()
    if let npcID=activeNamedNPCID,let encounterID=activeNamedEncounterID,
       livingDirector.namedEncounters.begin(npcID:npcID,encounterID:encounterID,founderPosition:playerRoot.position) != nil {
      interactionReturnContext = .init(targetID:"atlantis.namedNPC.\(npcID)",position:playerRoot.position,heading:heading,phase:phase,previous:streaming.previous,current:streaming.current,next:streaming.next,residents:streaming.residents)
      locomotion = .standing;walkInput=0;streaming.setFrozen(true);interactionStatus="Talking with named NPC"
      return .talkNamedNPC(npcID:npcID)
    }
    guard let target=activeInteraction,target.entity != nil else {interactionStatus="Interaction unavailable";return nil}
    interactionReturnContext = .init(targetID:target.definition.id,position:playerRoot.position,heading:heading,phase:phase,previous:streaming.previous,current:streaming.current,next:streaming.next,residents:streaming.residents)
    locomotion = .standing;walkInput=0;streaming.setFrozen(true);interactionStatus="Opening \(target.definition.accessibilityLabel)"
    return target.definition.intent
  }

  @discardableResult
  func returnFromInteraction() -> Bool {
    guard let context=interactionReturnContext else{return false}
    guard loader.states[context.current] == .loaded,
          let ground=grounding.height(at:context.position,loaded:loadedNames,referenceHeight:context.position.y),
          abs(ground-context.position.y)<=0.35 else {
      interactionReturnContext=nil;streaming.setFrozen(false);interactionStatus="Return failed: supporting district unavailable";refreshInteractionCandidate();return false
    }
    // Ground is a validity check. Preserve the captured transform exactly so a
    // presentation round trip cannot introduce cumulative vertical drift.
    playerRoot.position=context.position;heading=context.heading
    bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);phase=context.phase;applyLighting()
    interactionReturnContext=nil;streaming.setFrozen(false);interactionStatus="Returned to Atlantis";refreshInteractionCandidate();return true
  }

  func cancelInteraction(reason: String) {
    if isPresentingNamedEncounter {_=livingDirector.namedEncounters.dismiss()}
    interactionReturnContext=nil;streaming.setFrozen(false);interactionStatus=reason;refreshInteractionCandidate()
  }

  @discardableResult func respondToNamedEncounter(_ responseID:String)->AtlantisNamedEncounterResponse? {
    livingDirector.namedEncounters.respond(responseID:responseID)
  }

  @discardableResult func dismissNamedEncounter()->Bool {
    guard livingDirector.namedEncounters.dismiss() else{return false}
    interactionReturnContext=nil;streaming.setFrozen(false);interactionStatus="Returned to Atlantis";refreshInteractionCandidate();return true
  }

  func debugApproachNamedNPC(_ npcID:String,fixture:AtlantisNamedEncounterFixture?=nil) async -> Bool {
    guard let definition=AtlantisNamedNPCDefinition.all.first(where:{$0.id==npcID}) else{return false}
    livingDirector.namedEncounters.isEnabled=true
    if let fixture {livingDirector.namedEncounters.fixture=fixture}
    if loader.states[definition.homeDistrict] != .loaded {await loader.load(definition.homeDistrict)?.value}
    livingDirector.reconcile(residents:streaming.residents,current:streaming.current,phase:phase,position:definition.position,immediate:true)
    playerRoot.position=definition.position+[0,0,definition.interactionRadius-1]
    let offset=definition.position-playerRoot.position;heading=atan2(-offset.x,-offset.z)
    bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);refreshInteractionCandidate()
    return activeNamedNPCID==npcID
  }

  func debugApproachInteraction(_ id: String) async -> Bool {
    guard let definition=AtlantisInteractionDefinition.all.first(where:{$0.id==id}) else{return false}
    if loader.states[definition.district] != .loaded {await loader.load(definition.district)?.value}
    guard interactionRegistry.target(id:id)?.entity != nil else{interactionStatus="Interaction anchor unavailable";return false}
    let offset: SIMD3<Float> = definition.minimumFacingDot == nil ? [0,0,0] : [0,0,definition.activationRadius-1]
    playerRoot.position=definition.activationPosition+offset;heading=definition.minimumFacingDot == nil ? heading : 0
    bodyHeadingRoot.orientation=simd_quatf(angle:heading,axis:[0,1,0]);refreshInteractionCandidate();return activeInteractionID==id
  }
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
    report.registeredInteractionTargets=interactionRegistry.count
    report.interactionCandidateEvaluations=interactionRegistry.evaluationCount
    report.meanInteractionCandidateMicroseconds=interactionRegistry.meanEvaluationMicroseconds
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements;writeReport();benchmarkStatus=report.errors.isEmpty ? "complete" : "failed"
  }
  private func runInteractionBenchmark() async {
    benchmarkStatus="interaction cycles"
    let cycles=[("atlantis.interaction.techCom",5),("atlantis.interaction.ventureHall",5),("atlantis.interaction.founderGarage",3)]
    for (targetID,count) in cycles {
      for cycle in 1...count {
        guard !Task.isCancelled else{return}
        guard await debugApproachInteraction(targetID) else {report.errors.append("Interaction target unavailable: \(targetID)");continue}
        phase = cycle.isMultiple(of:2) ? .night : .evening;applyLighting()
        let position=playerRoot.position,savedHeading=heading,dayPhase=phase,residents=streaming.residents
        let before=AtlantisMemory.footprintMB(),intentStart=ContinuousClock.now
        guard beginInteraction() != nil else {report.errors.append("Interaction intent failed: \(targetID)");continue}
        let dispatchMS=elapsed(since:intentStart)*1_000,returnStart=ContinuousClock.now
        let returned=returnFromInteraction(),returnMS=elapsed(since:returnStart)*1_000,after=AtlantisMemory.footprintMB()
        let measurement=AtlantisInteractionMeasurement(
          target:targetID,cycle:cycle,intentDispatchMS:dispatchMS,returnMS:returnMS,
          memoryBeforeMB:before,memoryAfterMB:after,registeredTargets:interactionRegistry.count,
          worldRootCount:1,
          positionRestored:returned && playerRoot.position==position,
          headingRestored:returned && self.heading==savedHeading,
          phasePreserved:returned && phase==dayPhase,
          residencyPreserved:returned && streaming.residents==residents
        )
        report.interactions.append(measurement);report.sampledPeakMemoryMB=max(report.sampledPeakMemoryMB,after)
        if !returned || !measurement.positionRestored || !measurement.headingRestored || !measurement.phasePreserved || !measurement.residencyPreserved {
          report.errors.append("Interaction return invariant failed: \(targetID) cycle \(cycle)")
        }
        await Task.yield()
      }
    }
    report.registeredInteractionTargets=interactionRegistry.count
    report.interactionCandidateEvaluations=interactionRegistry.evaluationCount
    report.meanInteractionCandidateMicroseconds=interactionRegistry.meanEvaluationMicroseconds
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements;writeReport();benchmarkStatus=report.errors.isEmpty ? "complete" : "failed"
  }
  private func runLivingWorldBenchmark() async {
    benchmarkStatus="living world: Startup setup";livingWorld.isEnabled=true
    await loader.load(.startupRow)?.value;await loader.load(.commerceDistrict)?.value
    playerRoot.position=[-460,15,340]
    let stages=[("0 actors",0,0),("5 pedestrians",5,0),("10 pedestrians",10,0),("20 pedestrians",20,0)]
    var mayScale=true
    for (name,pedestrians,vehicles) in stages {
      guard mayScale || pedestrians==0 else{break}
      let measurement=await measureLivingWorld(name:name,district:.startupRow,pedestrians:pedestrians,vehicles:vehicles)
      report.livingWorld.append(measurement)
      mayScale=measurement.meanPopulationUpdateMS<1 && measurement.memoryAfterMB-measurement.memoryBeforeMB<32 && !["serious","critical"].contains(measurement.thermalAfter)
      if !mayScale {report.errors.append("Living-world scaling stopped after \(name): provisional safety gate")}
    }
    if mayScale {
      playerRoot.position=[300,14.8,190]
      report.livingWorld.append(await measureLivingWorld(name:"10 pedestrians + 2 vehicles",district:.commerceDistrict,pedestrians:10,vehicles:2))
    }
    livingWorld.setBenchmarkPopulation(district:.startupRow,pedestrians:10,vehicles:0)
    livingWorld.reconcile(residents:streaming.residents,current:.startupRow,phase:phase,playerPosition:[-460,15,340],immediate:true)
    report.livingPooling.append(poolingSnapshot(name:0))
    livingWorld.districtDidUnload(.startupRow);report.livingPooling.append(poolingSnapshot(name:1))
    let reuseBefore=livingWorld.reusedPedestrians
    livingWorld.setBenchmarkPopulation(district:.startupRow,pedestrians:10,vehicles:0)
    livingWorld.reconcile(residents:streaming.residents,current:.startupRow,phase:phase,playerPosition:[-460,15,340],immediate:true)
    var reload=poolingSnapshot(name:2);reload["reusedThisStep"]=Double(livingWorld.reusedPedestrians-reuseBefore);report.livingPooling.append(reload)
    livingWorld.clearBenchmarkPopulation()

    playerRoot.position=AtlantisBenchmarkCamera.founderStreet.recipe.position-[0,AtlantisSpatialContract.eyeHeight,0]
    livingWorld.reconcile(residents:streaming.residents,current:.founderDistrict,phase:phase,playerPosition:playerRoot.position,immediate:true)
    for _ in 0..<3 {
      await recordLivingTransition(to:.startupRow,next:.commerceDistrict)
      await recordLivingTransition(to:.commerceDistrict,next:.startupRow)
      await recordLivingTransition(to:.startupRow,next:.founderDistrict)
      await recordLivingTransition(to:.founderDistrict,next:.startupRow)
    }
    report.livingPooling.append(poolingSnapshot(name:3))

    let garageActors=livingWorld.activeActorCount
    if await debugApproachInteraction("atlantis.interaction.founderGarage"),beginInteraction() == .enterFounderGarage {
      if !returnFromInteraction() || livingWorld.activeActorCount != garageActors {report.errors.append("Garage living-world round trip changed population")}
    } else {report.errors.append("Garage living-world round trip unavailable")}
    _=await streaming.enter(.startupRow,next:.commerceDistrict);_=await streaming.enter(.commerceDistrict,next:.techCore)
    phase = .evening
    livingDirector.reconcile(residents:streaming.residents,current:.commerceDistrict,phase:phase,position:[476,14.7,252],immediate:true)
    let commerceActors=livingWorld.activeActorCount;applyLighting()
    if await debugApproachInteraction("atlantis.interaction.flashpoint"),beginInteraction() == .inspectRival(rivalID:"flashpoint") {
      if !returnFromInteraction() || livingWorld.activeActorCount != commerceActors || phase != .evening {report.errors.append("Flashpoint living-world round trip changed population or phase")}
    } else {report.errors.append("Flashpoint living-world round trip unavailable")}
    _=await streaming.enter(.startupRow,next:.commerceDistrict)
    livingWorld.clearBenchmarkPopulation()
    for fixture in AtlantisLivingWorldFixture.allCases {
      livingDirector.fixture=fixture;phase = .day;applyLighting();playerRoot.position=[-460,14.45,350]
      let memory=AtlantisMemory.footprintMB(),cpu=AtlantisProcessMetrics.cpuSeconds(),start=Date()
      let encounterActivationsBefore=livingDirector.encounterActivations
      livingDirector.reconcile(residents:streaming.residents,current:.startupRow,phase:phase,position:playerRoot.position,immediate:true)
      let changeCost=livingDirector.decisionCostMS
      selectLivingWorldCamera(.startupRow);frameSamples=[];collectingFrames=true;await wait(4);collectingFrames=false
      let seconds=Date().timeIntervalSince(start),samples=frameSamples.sorted()
      report.livingReactions[fixture.rawValue]=[
        "pedestrians":Double(livingWorld.activePedestrians),"vehicles":Double(livingWorld.activeVehicles),
        "displays":Double(livingDirector.activeDisplays),"encounters":Double(livingDirector.encounterActivations-encounterActivationsBefore),
        "entities":Double(livingDirector.entityCount),"stateChangeMS":changeCost,
        "steadyDecisionMS":livingDirector.decisionCostMS,"memoryBeforeMB":memory,"memoryAfterMB":AtlantisMemory.footprintMB(),
        "cpuPercent":(AtlantisProcessMetrics.cpuSeconds()-cpu)/seconds*100,
        "callbackP95MS":samples.isEmpty ? 0:samples[min(samples.count-1,Int(Double(samples.count)*0.95))]]
    }
    report.loads=loader.measurements;report.loadPhases=loader.phaseMeasurements;writeReport();benchmarkStatus=report.errors.isEmpty ? "complete":"failed"
  }

  private func measureLivingWorld(name:String,district:AtlantisDistrict,pedestrians:Int,vehicles:Int) async -> AtlantisLivingWorldMeasurement {
    benchmarkStatus="living world: \(name)";livingWorld.setBenchmarkPopulation(district:district,pedestrians:pedestrians,vehicles:vehicles);livingWorld.resetUpdateMeasurements()
    let memoryBefore=AtlantisMemory.footprintMB(),thermalBefore=AtlantisProcessMetrics.thermal,cpuBefore=AtlantisProcessMetrics.cpuSeconds(),start=Date()
    livingWorld.reconcile(residents:streaming.residents,current:district,phase:phase,playerPosition:playerRoot.position,immediate:true)
    selectLivingWorldCamera(district)
    frameSamples=[];collectingFrames=true;await wait(3);collectingFrames=false
    let seconds=Date().timeIntervalSince(start),cpu=max(0,(AtlantisProcessMetrics.cpuSeconds()-cpuBefore)/max(seconds,0.001)*100)
    let callbacks=frameSamples.sorted(),updates=livingWorld.updateSamples.sorted()
    return .init(configuration:name,pedestrians:livingWorld.activePedestrians,vehicles:livingWorld.activeVehicles,seconds:seconds,callbackSamples:callbacks.count,meanCallbackMS:callbacks.isEmpty ? 0:callbacks.reduce(0,+)/Double(callbacks.count),p95CallbackMS:callbacks.isEmpty ? 0:callbacks[min(callbacks.count-1,Int(Double(callbacks.count)*0.95))],meanPopulationUpdateMS:updates.isEmpty ? 0:updates.reduce(0,+)/Double(updates.count),p95PopulationUpdateMS:livingWorld.p95UpdateMS,processCPUPercent:cpu,memoryBeforeMB:memoryBefore,memoryAfterMB:AtlantisMemory.footprintMB(),spawnHitchMS:livingWorld.maximumSpawnHitchMS,thermalBefore:thermalBefore,thermalAfter:AtlantisProcessMetrics.thermal)
  }

  private func recordLivingTransition(to district:AtlantisDistrict,next:AtlantisDistrict?) async {
    let before=livingWorld.activeActorCount,memory=AtlantisMemory.footprintMB(),from=streaming.current
    playerRoot.position=AtlantisLivingWorldPresentationAdapter.activityAnchors.first{$0.district==district}!.position
    let entered=await streaming.enter(district,next:next);livingWorld.reconcile(residents:streaming.residents,current:streaming.current,phase:phase,playerPosition:playerRoot.position,immediate:true)
    let duplicate=livingWorld.activeEntityIDs.count != livingWorld.activeActorCount || livingWorld.root.children.count != livingWorld.activeActorCount
    let afterMemory=AtlantisMemory.footprintMB()
    report.livingStreaming.append(.init(transition:"\(from.title) → \(district.title)",actorsBefore:before,actorsAfter:livingWorld.activeActorCount,duplicateActors:duplicate,memoryBeforeMB:memory,memoryAfterMB:afterMemory,result:entered && !duplicate ? "pass":"fail"))
    if !entered || duplicate {report.errors.append("Living-world transition failed: \(from.rawValue) → \(district.rawValue)")}
  }

  private func poolingSnapshot(name:Double)->[String:Double] {[
    "step":name,"allocatedPedestrians":Double(livingWorld.allocatedPedestrians),"allocatedVehicles":Double(livingWorld.allocatedVehicles),
    "reusedPedestrians":Double(livingWorld.reusedPedestrians),"reusedVehicles":Double(livingWorld.reusedVehicles),
    "recycled":Double(livingWorld.recycledActors),"pooledPedestrians":Double(livingWorld.pooledPedestrians),
    "pooledVehicles":Double(livingWorld.pooledVehicles),"active":Double(livingWorld.activeActorCount),"destroyed":0,
    "memoryMB":AtlantisMemory.footprintMB()
  ]}
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
