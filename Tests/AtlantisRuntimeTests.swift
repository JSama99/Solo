import XCTest
import RealityKit
@testable import Solo_Unicorn_Run

@MainActor
final class AtlantisRuntimeTests: XCTestCase {
  func testDebugSelectionIsExplicitAndUnpersisted() {
    XCTAssertFalse(AtlantisRendererConfiguration.resolve(arguments:[],environment:[:],allowed:true))
    XCTAssertTrue(AtlantisRendererConfiguration.resolve(arguments:["--atlantis-realitykit"],environment:[:],allowed:true))
    XCTAssertTrue(AtlantisRendererConfiguration.resolve(arguments:[],environment:["SOLO_ATLANTIS_RENDERER":"realitykit"],allowed:true))
    XCTAssertFalse(AtlantisRendererConfiguration.resolve(arguments:["--atlantis-realitykit"],environment:["SOLO_ATLANTIS_RENDERER":"realitykit"],allowed:false))
    XCTAssertFalse(AtlantisRendererConfiguration.resolve(arguments:["--founder-garage-realitykit"],environment:[:],allowed:true))
    XCTAssertFalse(AtlantisImportExperiment.useBatchedFounder(arguments:[]))
    XCTAssertTrue(AtlantisImportExperiment.useBatchedFounder(arguments:["--atlantis-batched-founder"]))
    XCTAssertEqual(AtlantisImportExperiment.assetMode(arguments:["--atlantis-baseline-assets"]),.baseline)
    XCTAssertEqual(AtlantisImportExperiment.assetMode(arguments:["--atlantis-batched-assets"]),.batched)
    XCTAssertEqual(AtlantisImportExperiment.assetMode(arguments:["--atlantis-baseline-assets","--atlantis-batched-assets"]),.baseline)
    let manifest=try! AtlantisAssetManifest.load()
    XCTAssertEqual(AtlantisImportExperiment.package(for:.startupRow,manifest:manifest,arguments:["--atlantis-baseline-assets"]),"startup_row")
    XCTAssertEqual(AtlantisImportExperiment.package(for:.startupRow,manifest:manifest,arguments:["--atlantis-batched-assets"]),"startup_row_batched")
    XCTAssertEqual(AtlantisImportExperiment.package(for:.commerceDistrict,manifest:manifest,arguments:["--atlantis-batched-assets"]),"commerce_district_batched")
    XCTAssertEqual(AtlantisImportExperiment.package(for:.techCore,manifest:manifest,arguments:["--atlantis-batched-assets"]),"tech_core_batched")
    XCTAssertEqual(AtlantisImportExperiment.package(for:.unicornHeights,manifest:manifest,arguments:["--atlantis-batched-assets"]),"unicorn_heights_batched")
    XCTAssertEqual(AtlantisImportExperiment.package(for:.ventureDistrict,manifest:manifest,arguments:["--atlantis-batched-assets"]),"venture_district_batched")
    XCTAssertEqual(AtlantisImportExperiment.package(for:.mediaDistrict,manifest:manifest,arguments:["--atlantis-batched-assets"]),"media_district_batched")
  }
  func testDistrictIdentityAndSpatialContract() throws {
    XCTAssertEqual(AtlantisDistrict.allCases.count,7)
    let manifest=try AtlantisAssetManifest.load()
    XCTAssertEqual(manifest.axis,"Y");XCTAssertEqual(manifest.metersPerUnit,1)
    XCTAssertEqual(AtlantisSpatialContract.fromBlender([1,2,3]),[1,3,-2])
    XCTAssertEqual(manifest.landmarks["FounderGarageSlot"]?.position.vector3,AtlantisSpatialContract.founderGarage)
    XCTAssertEqual(manifest.landmarks["TheSpire"]?.position.vector3,AtlantisSpatialContract.spire)
    XCTAssertEqual(manifest.landmarks["PlayerUnicornHQSlot"]?.position.vector3,AtlantisSpatialContract.playerHQ)
    XCTAssertEqual(manifest.districts.count,8)
    XCTAssertEqual(Set(manifest.landmarks.keys),Set(["TheSpire","VentureHall","TechComTower","SignalTV","PallasAIHQ","NorthwindLabsHQ","FlashpointHQ","PlayerUnicornHQSlot","FounderGarageSlot"]))
  }
  func testNoDuplicateConcurrentLoadAndReload() async throws {
    let source=Controlled(),loader=AtlantisDistrictLoader(manifest:try .load(),source:source)
    let a=loader.load(.founderDistrict),b=loader.load(.founderDistrict)
    await source.waitFor(1);XCTAssertEqual(source.count,1);XCTAssertEqual(loader.states[.founderDistrict],.loading)
    source.finish();await a?.value;await b?.value
    XCTAssertEqual(loader.loaded,[.founderDistrict]);XCTAssertNil(loader.load(.founderDistrict));XCTAssertEqual(loader.root.children.count,1)
    weak var released=loader.entity(for:.founderDistrict)
    loader.unload(.founderDistrict);XCTAssertNil(released);XCTAssertEqual(loader.states[.founderDistrict],.unloaded)
    let next=loader.load(.founderDistrict);await source.waitFor(2);source.finish();await next?.value
    XCTAssertEqual(loader.root.children.count,1)
  }
  func testObsoleteCompletionCannotReplaceReload() async throws {
    let source=Controlled(),loader=AtlantisDistrictLoader(manifest:try .load(),source:source)
    let old=loader.load(.startupRow);await source.waitFor(1);loader.unload(.startupRow)
    let next=loader.load(.startupRow);await source.waitFor(2);source.finish();await old?.value
    XCTAssertEqual(loader.states[.startupRow],.loading);XCTAssertEqual(loader.root.children.count,0)
    source.finish();await next?.value;XCTAssertEqual(loader.root.children.count,1)
  }
  func testFailureLeavesOtherDistrictStableAndAllowsRetry() async throws {
    let source=Controlled(),loader=AtlantisDistrictLoader(manifest:try .load(),source:source)
    let first=loader.load(.founderDistrict);await source.waitFor(1);source.finish();await first?.value
    let second=loader.load(.commerceDistrict);await source.waitFor(2);source.fail();await second?.value
    XCTAssertEqual(loader.states[.founderDistrict],.loaded)
    guard case .failed=loader.states[.commerceDistrict] else{return XCTFail("Expected failure")}
    let retry=loader.load(.commerceDistrict);await source.waitFor(3);source.finish();await retry?.value;XCTAssertEqual(loader.loaded.count,2)
  }
  func testUnloadAllCancelsContextAndDistricts() async throws {
    let source=Controlled(),loader=AtlantisDistrictLoader(manifest:try .load(),source:source)
    let context=loader.loadContext();await source.waitFor(1);let district=loader.load(.founderDistrict);await source.waitFor(2)
    loader.unloadAll();source.finish();source.finish();await context?.value;await district?.value
    XCTAssertEqual(loader.root.children.count,0);XCTAssertEqual(loader.contextState,.unloaded);XCTAssertTrue(loader.loaded.isEmpty)
  }
  func testRealFounderPackageBoundsMaterialsAndGarageSlot() async throws {
    let m=try AtlantisAssetManifest.load();let entity=try await AtlantisUSDZLoader(manifest:m).load(package:"founder_district")
    XCTAssertNotNil(entity.findEntity(named:"FounderGarageSlot"));XCTAssertGreaterThan(models(entity).count,100)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testAllRealDistrictsLoadUnloadWithoutDuplicates() async throws {
    let loader=AtlantisDistrictLoader(manifest:try .load())
    for d in AtlantisDistrict.allCases {await loader.load(d)?.value;XCTAssertEqual(loader.states[d],.loaded,d.rawValue)}
    XCTAssertEqual(loader.loaded.count,7)
    for d in AtlantisDistrict.allCases {loader.unload(d);XCTAssertNil(loader.entity(for:d))}
    XCTAssertEqual(loader.root.children.count,0)
  }
  func testRealLoaderReportsImportValidationAndInstallPhases() async throws {
    let loader=AtlantisDistrictLoader(manifest:try .load())
    await loader.load(.techCore)?.value
    XCTAssertEqual(Set(loader.phaseMeasurements.map(\.phase)),Set(["resolve","read","checksum","realitykit-import","validation","scene-install"]))
    XCTAssertTrue(loader.phaseMeasurements.allSatisfy{$0.package == "tech_core"})
    XCTAssertTrue(loader.phaseMeasurements.allSatisfy{$0.seconds >= 0})
  }
  func testBatchedFounderExperimentPreservesBoundsAndGarageLandmark() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["FounderDistrictBatched"])
    XCTAssertEqual(package.meshes,15)
    XCTAssertEqual(package.triangles,manifest.districts["FounderDistrict"]?.triangles)
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    XCTAssertNotNil(entity.findEntity(named:"FounderGarageSlot"))
  }
  func testSelectiveStartupBatchPreservesProgressionTraversalAndSignage() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["StartupRowBatched"])
    XCTAssertEqual(package.meshes,56)
    XCTAssertEqual(package.triangles,manifest.districts["StartupRow"]?.triangles)
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    for name in ["Progression_Startup_00","Progression_Startup_04","StartupRow_CrossStreet_00","Startup_Link_00","Startup_LoftContext","Startup_LoftContext_Signage","Startup_BigBuildingContext","Startup_BigBuildingContext_Signage","Batch_000_Startup_Concrete"] {
      XCTAssertNotNil(entity.findEntity(named:name),name)
    }
    XCTAssertEqual(models(entity).count,package.meshes)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testSelectiveCommerceBatchPreservesFlashpointAndSemanticSurfaces() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["CommerceDistrictBatched"])
    XCTAssertEqual(package.meshes,54)
    XCTAssertEqual(package.triangles,manifest.districts["CommerceDistrict"]?.triangles)
    XCTAssertEqual(package.landmarks["FlashpointHQ"],manifest.districts["CommerceDistrict"]?.landmarks["FlashpointHQ"])
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    for name in ["FlashpointHQ","Flashpoint_LaunchDisplay","Flashpoint_Ticker","Commerce_CustomerPlaza_Surface","Commerce_EventForecourt_Surface","Commerce_Building_01","Commerce_Building_01_SemanticSign","Commerce_Building_01_OccupiedSurfaces"] {
      XCTAssertNotNil(entity.findEntity(named:name),name)
    }
    XCTAssertEqual(models(entity).count,package.meshes)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testSelectiveTechBatchPreservesSkylineLandmarkHierarchies() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["TechCoreBatched"])
    XCTAssertEqual(package.meshes,31)
    XCTAssertEqual(package.triangles,manifest.districts["TechCore"]?.triangles)
    XCTAssertEqual(package.landmarks,manifest.districts["TechCore"]?.landmarks)
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    for name in ["TheSpire","TheSpire_CrownAccent_1","PallasAIHQ","PallasAI_Signage_Main_001","NorthwindLabsHQ","NorthwindLabs_Signage_Main_001","Spire_Plaza","TechCore_CrossStreet_00"] {
      XCTAssertNotNil(entity.findEntity(named:name),name)
    }
    XCTAssertEqual(models(entity).count,package.meshes)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testSelectiveUnicornBatchPreservesHQCampusAndPublicAnchors() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["UnicornHeightsBatched"])
    XCTAssertEqual(package.meshes,30)
    XCTAssertEqual(package.triangles,manifest.districts["UnicornHeights"]?.triangles)
    XCTAssertEqual(package.landmarks,manifest.districts["UnicornHeights"]?.landmarks)
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    for name in ["PlayerUnicornHQSlot","PlayerHQ_PlazaAnchor","PlayerHQ_SignageAnchor","Unicorn_Campus_01","Unicorn_Campus_01_Identity","Unicorn_Campus_01_OccupiedSurfaces","Unicorn_FounderPlaza_Surface","Unicorn_ScenicOverlook_Surface","Unicorn_PlayerArrival_00","Bridge_TechCore_00","Unicorn_BridgeWalk_00"] {
      XCTAssertNotNil(entity.findEntity(named:name),name)
    }
    XCTAssertEqual(models(entity).count,package.meshes)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testMinimalVentureBatchPreservesHallAndPublicAnchors() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["VentureDistrictBatched"])
    XCTAssertEqual(package.meshes,12)
    XCTAssertEqual(package.triangles,manifest.districts["VentureDistrict"]?.triangles)
    XCTAssertEqual(package.landmarks,manifest.districts["VentureDistrict"]?.landmarks)
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    for name in ["VentureHall","Venture_Boulevard_00","VentureDistrict_CrossStreet_00","Venture_Forum","Venture_EntryWalk","Landmark_VentureHall_Parcel"] {
      XCTAssertNotNil(entity.findEntity(named:name),name)
    }
    XCTAssertEqual(models(entity).count,package.meshes)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testMinimalMediaBatchPreservesBroadcastLandmarksAndWaterfrontAnchors() async throws {
    let manifest=try AtlantisAssetManifest.load()
    let package=try XCTUnwrap(manifest.experiments?["MediaDistrictBatched"])
    XCTAssertEqual(package.meshes,23)
    XCTAssertEqual(package.triangles,manifest.districts["MediaDistrict"]?.triangles)
    XCTAssertEqual(package.landmarks,manifest.districts["MediaDistrict"]?.landmarks)
    let entity=try await AtlantisUSDZLoader(manifest:manifest).load(package:package.package)
    for name in ["TechComTower","TechCom_Display_Main","TechCom_Ticker","SignalTV","SignalTV_Display_Main","SignalTV_Ticker","Media_Boulevard_00","MediaDistrict_CrossStreet_00","SignalTV_BroadcastPlaza","Broadcast_WaterfrontWalk"] {
      XCTAssertNotNil(entity.findEntity(named:name),name)
    }
    XCTAssertEqual(models(entity).count,package.meshes)
    XCTAssertTrue(models(entity).allSatisfy{!$0.materials.isEmpty})
  }
  func testLightingAndCameraArePresentationOnly() throws {
    let store=GameStore();let before=store.stats;let rng=store.randomNumberGenerator;let sprint=store.sprint
    let world=AtlantisRealityWorld(manifest:try .load())
    for p in FounderEnvironmentTimeState.allCases {let model=AtlantisPresentationAdapter.environment(p);world.phase=model.dayPhase;world.applyLighting();XCTAssertEqual(model.dayPhase,p)}
    for c in AtlantisBenchmarkCamera.allCases {world.selectCamera(c);XCTAssertEqual(world.camera.camera.near,0.2);XCTAssertEqual(world.camera.camera.far,8000)}
    XCTAssertEqual(store.stats,before);XCTAssertEqual(store.randomNumberGenerator,rng);XCTAssertEqual(store.sprint,sprint)
    XCTAssertEqual(world.playerRoot.name,"AtlantisPlayerRoot");XCTAssertTrue(world.bodyHeadingRoot.parent === world.playerRoot);XCTAssertTrue(world.cameraRig.parent === world.bodyHeadingRoot);XCTAssertTrue(world.camera.parent === world.cameraRig)
    world.stop()
  }
  func testWalkingSpeedBoundAndMissingGroundRejection() throws {
    XCTAssertEqual(AtlantisSpatialContract.walkingSpeed,1.4)
    let w=AtlantisRealityWorld(manifest:try .load());let p=w.playerRoot.position;w.toggleWalk();w.move(input:1,delta:100)
    XCTAssertEqual(w.playerRoot.position,p,"No district loaded: movement must reject missing ground")
    w.stop()
  }
  func testSourceGroundingAndRouteMetadata() throws {
    let m=try AtlantisAssetManifest.load(),g=AtlantisGrounding(traversal:m.traversal)
    XCTAssertEqual(m.traversal.routes.count,5);XCTAssertGreaterThan(m.traversal.barriers.count,0)
    XCTAssertEqual(try XCTUnwrap(g.height(at:[-875,8.03,1040.1],loaded:["FounderDistrict"])),8.03,accuracy:0.03)
    XCTAssertNil(g.height(at:[0,15,0],loaded:["WorldContext"]),"World context terrain is visual-only")
    XCTAssertNil(g.height(at:[9999,0,9999],loaded:Set(AtlantisDistrict.allCases.map(\.rawValue))))
  }
  func testAdjacencyResidencyAndMeasuredPrefetchPolicy() throws {
    let policy=try AtlantisAssetManifest.load().streamingPolicy
    XCTAssertTrue(policy.areAdjacent(.founderDistrict,.startupRow));XCTAssertTrue(policy.areAdjacent(.startupRow,.commerceDistrict));XCTAssertTrue(policy.areAdjacent(.techCore,.unicornHeights))
    XCTAssertFalse(policy.areAdjacent(.founderDistrict,.commerceDistrict))
    let plan=policy.plan(previous:.founderDistrict,current:.startupRow,next:.commerceDistrict)
    XCTAssertEqual(plan.residents,[.founderDistrict,.startupRow,.commerceDistrict]);XCTAssertTrue(plan.protects(.startupRow));XCTAssertFalse(plan.protects(.techCore))
    XCTAssertEqual(policy.prefetchDistance(measuredLoadSeconds:1),2.1,accuracy:0.001)
    XCTAssertGreaterThan(policy.prefetchDistance(measuredLoadSeconds:20),40)
  }
  func testCurrentAndSupportingDistrictUnloadProtection() async throws {
    let source=Controlled(),loader=AtlantisDistrictLoader(manifest:try .load(),source:source),streaming=AtlantisStreamingCoordinator(loader:loader,manifest:try .load())
    let founder=loader.load(.founderDistrict);await source.waitFor(1);source.finish();await founder?.value
    XCTAssertFalse(streaming.requestUnload(.founderDistrict));XCTAssertEqual(loader.states[.founderDistrict],.loaded)
    let commerce=loader.load(.commerceDistrict);await source.waitFor(2);source.finish();await commerce?.value
    XCTAssertTrue(streaming.requestUnload(.commerceDistrict));XCTAssertEqual(loader.states[.commerceDistrict],.unloaded)
  }
  func testFailedAdjacentPrefetchRetainsCurrentAndCanRetry() async throws {
    let source=Controlled(),loader=AtlantisDistrictLoader(manifest:try .load(),source:source),streaming=AtlantisStreamingCoordinator(loader:loader,manifest:try .load())
    let founder=loader.load(.founderDistrict);await source.waitFor(1);source.finish();await founder?.value
    streaming.prefetch(.startupRow);await source.waitFor(2);source.fail()
    while loader.states[.startupRow] == .loading {await Task.yield()}
    XCTAssertEqual(streaming.current,.founderDistrict);XCTAssertEqual(loader.states[.founderDistrict],.loaded)
    streaming.prefetch(.startupRow);await source.waitFor(3);source.finish()
    while loader.states[.startupRow] == .loading {await Task.yield()}
    XCTAssertEqual(loader.states[.startupRow],.loaded)
  }
  func testSpireProxySwapLatePhaseAndSemanticInvalidation() async throws {
    let w=AtlantisRealityWorld(manifest:try .load());w.phase = .evening;w.applyLighting()
    await w.loader.loadSupport("SpireFarProxy")?.value
    XCTAssertEqual(w.farLandmarkState,"Spire proxy")
    XCTAssertEqual(w.loader.supportEntity(named:"SpireFarProxy")?.findEntity(named:"TheSpireFarAnchor")?.position(relativeTo:nil),AtlantisSpatialContract.spire)
    await w.loader.load(.techCore)?.value
    XCTAssertEqual(w.farLandmarkState,"Spire full")
    XCTAssertFalse(try XCTUnwrap(w.loader.supportEntity(named:"SpireFarProxy")).isEnabled)
    XCTAssertNotNil(w.loader.entity(for:.techCore)?.findEntity(named:"TheSpire"))
    XCTAssertEqual(w.loader.entity(for:.techCore)?.components[AtlantisDayPhaseComponent.self]?.phase,FounderEnvironmentTimeState.evening.rawValue)
    w.loader.unload(.techCore);XCTAssertEqual(w.farLandmarkState,"Spire proxy")
    await w.loader.load(.commerceDistrict)?.value
    XCTAssertNotNil(w.semanticAnchors.entity(district:.commerceDistrict,name:"RivalHQ_Slot_05"))
    w.loader.unload(.commerceDistrict);XCTAssertNil(w.semanticAnchors.entity(district:.commerceDistrict,name:"RivalHQ_Slot_05"))
    w.phase = .night;w.applyLighting();await w.loader.load(.startupRow)?.value
    XCTAssertEqual(w.loader.entity(for:.startupRow)?.components[AtlantisDayPhaseComponent.self]?.phase,FounderEnvironmentTimeState.night.rawValue);w.stop()
  }
  func testExplicitSurfaceOwnershipAndRepairedBridge() throws {
    let m=try AtlantisAssetManifest.load(),surfaces=try XCTUnwrap(m.traversal.surfaces)
    XCTAssertTrue(surfaces.contains{$0.district=="WorldContext" && $0.classification == .visualOnly})
    XCTAssertTrue(surfaces.contains{$0.source.hasPrefix("Tech_Ring_Phase12") && $0.classification == .walkable})
    XCTAssertTrue(surfaces.contains{$0.source.hasPrefix("TechUnicornBridge_Repaired") && $0.classification == .walkable})
    XCTAssertTrue(surfaces.contains{$0.source.hasPrefix("PrimaryRouteSupport_Phase12") && $0.classification == .collisionOnly})
    XCTAssertTrue(surfaces.contains{$0.source=="Bridge_TechCore_00" && $0.classification == .visualOnly})
    let route=try XCTUnwrap(m.traversal.routes.first{$0.name=="FounderGarage_To_PlayerUnicornHQ"})
    XCTAssertEqual(route.points.first?[0],-875);XCTAssertEqual(route.points.last?.vector3,AtlantisSpatialContract.playerHQ)
    let bridge=route.points.filter{$0[0] >= 360 && $0[0] <= 600 && $0[2] <= -470 && $0[2] >= -760}
    XCTAssertGreaterThanOrEqual(bridge.count,6)
    for (a,b) in zip(bridge,bridge.dropFirst()) {
      let horizontal=simd_length(SIMD2<Float>(b[0]-a[0],b[2]-a[2]));XCTAssertLessThanOrEqual(abs(b[1]-a[1])/horizontal,0.08)
    }
  }
  func testControllerTraversesFounderRouteAndRepairedBridge() async throws {
    let m=try AtlantisAssetManifest.load(),w=AtlantisRealityWorld(manifest:try .load())
    await w.loader.loadContext()?.value
    for d in [AtlantisDistrict.founderDistrict,.startupRow,.techCore,.unicornHeights] {await w.loader.load(d)?.value}
    let route=try XCTUnwrap(m.traversal.routes.first{$0.name == "Founder_ToStartup_Walk"})
    let result=await w.controllerSweep(route)
    XCTAssertEqual(result.rejectedSteps,0);XCTAssertGreaterThan(result.samples,5000)
    XCTAssertEqual(w.playerRoot.position.x,route.points.last![0],accuracy:0.03)
    XCTAssertEqual(w.playerRoot.position.z,route.points.last![2],accuracy:0.03)
    await w.loader.loadSupport("TechUnicornBridge")?.value
    let whole=try XCTUnwrap(m.traversal.routes.first{$0.name=="FounderGarage_To_PlayerUnicornHQ"})
    let bridgePoints=whole.points.filter{$0[0] >= 360 && $0[0] <= 600 && $0[2] <= -470 && $0[2] >= -760}
    let bridge=await w.controllerSweep(.init(name:"Phase 12 repaired bridge",points:bridgePoints))
    XCTAssertEqual(bridge.rejectedSteps,0,"\(bridge.worstLocation) \(w.movementStatus)");XCTAssertEqual(bridge.maximumHeightError,0,accuracy:0.05)
    w.stop()
  }
  func testContinuousFounderGarageToPlayerHQRoute() async throws {
    let m=try AtlantisAssetManifest.load(),w=AtlantisRealityWorld(manifest:m)
    for district in [AtlantisDistrict.founderDistrict,.startupRow,.commerceDistrict,.techCore,.unicornHeights] {await w.loader.load(district)?.value}
    await w.loader.loadSupport("TechUnicornBridge")?.value
    let route=try XCTUnwrap(m.traversal.routes.first{$0.name=="FounderGarage_To_PlayerUnicornHQ"})
    let result=await w.controllerSweep(route)
    XCTAssertEqual(result.rejectedSteps,0,"\(result.worstLocation) \(w.movementStatus)")
    XCTAssertEqual(w.playerRoot.position.x,AtlantisSpatialContract.playerHQ.x,accuracy:0.03)
    XCTAssertEqual(w.playerRoot.position.z,AtlantisSpatialContract.playerHQ.z,accuracy:0.03);w.stop()
  }
  private func models(_ e: Entity)->[ModelComponent] { (e.components[ModelComponent.self].map{[$0]} ?? [])+e.children.flatMap{models($0)} }
  private final class Controlled: AtlantisDistrictLoading {
    var count=0
    var pending:[CheckedContinuation<Entity,Error>]=[]
    func load(package:String) async throws -> Entity {count += 1;return try await withCheckedThrowingContinuation{pending.append($0)}}
    func waitFor(_ count:Int) async {while self.count<count {await Task.yield()}}
    func finish() {pending.removeFirst().resume(returning:Entity())}
    func fail() {pending.removeFirst().resume(throwing:CocoaError(.fileReadCorruptFile))}
  }
}
