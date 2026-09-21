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
      weak let released=loader.entity(for:.founderDistrict)
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
  func testInteractionDefinitionsUseStableUniqueCanonicalIntents() {
    let targets=AtlantisInteractionDefinition.all
    XCTAssertEqual(targets.count,8);XCTAssertEqual(Set(targets.map(\.id)).count,8)
    XCTAssertEqual(Set(targets.map(\.anchorName)),["FounderGarageSlot","TechComTower","VentureHall","SignalTV","PallasAIHQ","NorthwindLabsHQ","FlashpointHQ","PlayerUnicornHQSlot"])
    XCTAssertEqual(AtlantisCanonicalRoute.resolve(.openTechCom,availableRivalIDs:[]),.techCom)
    XCTAssertEqual(AtlantisCanonicalRoute.resolve(.inspectRival(rivalID:"pallas"),availableRivalIDs:["pallas"]),.rival("pallas"))
    XCTAssertNil(AtlantisCanonicalRoute.resolve(.inspectRival(rivalID:"unknown"),availableRivalIDs:["pallas"]))
  }
  func testInteractionCandidateProximityFacingAndPriorityAreDeterministic() {
    let registry=AtlantisInteractionRegistry(),root=Entity(),anchor=Entity();anchor.name="FounderGarageSlot";root.addChild(anchor);registry.register(district:.founderDistrict,root:root)
    XCTAssertEqual(registry.candidate(position:[-875,8,1040],forward:[0,0,-1],residentDistricts:[.founderDistrict])?.definition.id,"atlantis.interaction.founderGarage")
    XCTAssertNil(registry.candidate(position:[-875,8,1040],forward:[0,0,1],residentDistricts:[.founderDistrict]))
    XCTAssertNil(registry.candidate(position:[-875,8,1060],forward:[0,0,-1],residentDistricts:[.founderDistrict]))
    let scores=[AtlantisInteractionCandidateScore(id:"z",priority:100,distance:1),.init(id:"b",priority:200,distance:3),.init(id:"a",priority:200,distance:3)]
    XCTAssertEqual(AtlantisInteractionSelectionPolicy.select(scores),"a")
  }
  func testInteractionUnloadInvalidatesAndReloadRegistersExactlyOnce() async throws {
    let w=AtlantisRealityWorld(manifest:try .load());await w.loader.load(.techCore)?.value
    XCTAssertEqual(w.interactionRegistry.registeredIDs,["atlantis.interaction.pallasAI","atlantis.interaction.northwindLabs"])
    let approachedPallas=await w.debugApproachInteraction("atlantis.interaction.pallasAI")
    XCTAssertTrue(approachedPallas);XCTAssertEqual(w.activeInteractionID,"atlantis.interaction.pallasAI")
    w.loader.unload(.techCore);XCTAssertNil(w.activeInteractionID);XCTAssertNil(w.interactionRegistry.target(id:"atlantis.interaction.pallasAI"))
    XCTAssertNil(w.beginInteraction(),"An unloaded target must not remain actionable")
    await w.loader.load(.techCore)?.value
    XCTAssertEqual(w.interactionRegistry.count,2);XCTAssertEqual(w.interactionRegistry.registeredIDs.count,2);w.stop()
  }
  func testInteractionRoundTripRestoresPositionHeadingPhaseResidencyAndRoot() async throws {
    let w=AtlantisRealityWorld(manifest:try .load());await w.loader.load(.founderDistrict)?.value
    let approachedGarage=await w.debugApproachInteraction("atlantis.interaction.founderGarage")
    XCTAssertTrue(approachedGarage);w.phase = .night;w.applyLighting()
    let position=w.playerRoot.position,heading=w.heading,residents=w.streaming.residents,root=w.root
    XCTAssertEqual(w.beginInteraction(),.enterFounderGarage);XCTAssertTrue(w.streaming.isFrozen)
    w.selectCamera(.atlantisAerial)
    XCTAssertTrue(w.returnFromInteraction());XCTAssertEqual(w.playerRoot.position,position);XCTAssertEqual(w.heading,heading);XCTAssertEqual(w.phase,.night)
    XCTAssertEqual(w.streaming.residents,residents);XCTAssertTrue(w.root === root);XCTAssertFalse(w.streaming.isFrozen);w.stop()
  }
  func testStreamingAndInteractionSequencePreservesCanonicalStoreTruth() async throws {
    let store=GameStore(),stats=store.stats,rng=store.randomNumberGenerator,w=AtlantisRealityWorld(manifest:try .load())
    await w.loader.load(.founderDistrict)?.value
    let enteredStartup=await w.streaming.enter(.startupRow,next:.commerceDistrict)
    let enteredCommerce=await w.streaming.enter(.commerceDistrict,next:.techCore)
    XCTAssertTrue(enteredStartup);XCTAssertTrue(enteredCommerce)
    let approachedFlashpoint=await w.debugApproachInteraction("atlantis.interaction.flashpoint")
    XCTAssertTrue(approachedFlashpoint);XCTAssertEqual(w.beginInteraction(),.inspectRival(rivalID:"flashpoint"))
    XCTAssertEqual(AtlantisCanonicalRoute.resolve(.inspectRival(rivalID:"flashpoint"),availableRivalIDs:Set(ContentLibrary.rivalCompanies.map(\.id))),.rival("flashpoint"))
    XCTAssertTrue(w.returnFromInteraction())
    let enteredTech=await w.streaming.enter(.techCore,next:.unicornHeights)
    XCTAssertTrue(enteredTech)
    XCTAssertEqual(store.stats,stats);XCTAssertEqual(store.randomNumberGenerator,rng);XCTAssertEqual(GameStore.saveVersion,20);w.stop()
  }
  func testLivingWorldProfilesFollowDistrictAndDayPhase() {
    XCTAssertEqual(AtlantisLivingWorldPresentationAdapter.profile(district:.startupRow,phase:.morning).pedestrians,6)
    XCTAssertEqual(AtlantisLivingWorldPresentationAdapter.profile(district:.startupRow,phase:.day).pedestrians,10)
    XCTAssertEqual(AtlantisLivingWorldPresentationAdapter.profile(district:.startupRow,phase:.evening).pedestrians,8)
    XCTAssertEqual(AtlantisLivingWorldPresentationAdapter.profile(district:.startupRow,phase:.night).pedestrians,3)
    XCTAssertEqual(AtlantisLivingWorldPresentationAdapter.profile(district:.commerceDistrict,phase:.day).vehicles,2)
    XCTAssertLessThan(AtlantisLivingWorldPresentationAdapter.profile(district:.unicornHeights,phase:.day).pedestrians,AtlantisLivingWorldPresentationAdapter.profile(district:.startupRow,phase:.day).pedestrians)
  }
  func testLivingWorldPresentationSeedIsDeterministicAndIndependent() {
    let a=(0..<20).map{AtlantisPresentationSeed.value("Startup",index:$0)},b=(0..<20).map{AtlantisPresentationSeed.value("Startup",index:$0)}
    XCTAssertEqual(a,b);XCTAssertEqual(Set(a).count,20);XCTAssertNotEqual(a,(0..<20).map{AtlantisPresentationSeed.value("Commerce",index:$0)})
  }
  func testLivingWorldSemanticAnchorsAndRouteOwnershipAreStable() {
    let anchors=AtlantisLivingWorldPresentationAdapter.activityAnchors,routes=AtlantisLivingWorldPresentationAdapter.routes
    XCTAssertEqual(anchors.count,7);XCTAssertEqual(Set(anchors.map(\.id)).count,7);XCTAssertEqual(Set(anchors.map(\.district)),Set(AtlantisDistrict.allCases))
    XCTAssertTrue(routes.allSatisfy{$0.points.count>1});XCTAssertEqual(Set(routes.filter{$0.kind == .vehicle}.map(\.district)),[.commerceDistrict])
    XCTAssertEqual(routes.filter{$0.district == .startupRow && $0.kind == .pedestrian}.count,2)
  }
  func testLivingWorldResidencyActivationUnloadAndPoolReuse() {
    let population=AtlantisLivingWorldDistrictPopulation();population.isEnabled=true
    population.setBenchmarkPopulation(district:.startupRow,pedestrians:10,vehicles:0)
    population.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,playerPosition:[-460,15,340],immediate:true)
    XCTAssertEqual(population.activePedestrians,10);XCTAssertEqual(population.root.children.count,10);let allocated=population.allocatedPedestrians
    population.districtDidUnload(.startupRow);XCTAssertEqual(population.activeActorCount,0);XCTAssertEqual(population.pooledPedestrians,10);XCTAssertEqual(population.root.children.count,0)
    population.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,playerPosition:[-460,15,340],immediate:true)
    XCTAssertEqual(population.activePedestrians,10);XCTAssertEqual(population.allocatedPedestrians,allocated);XCTAssertEqual(population.reusedPedestrians,10)
  }
  func testLivingWorldLateLoadUsesCurrentPhaseAndGraduallyAdjusts() {
    let population=AtlantisLivingWorldDistrictPopulation();population.isEnabled=true
    population.reconcile(residents:[.startupRow],current:.startupRow,phase:.night,playerPosition:[-460,15,340],immediate:true)
    XCTAssertEqual(population.activePedestrians,3)
    population.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,playerPosition:[-460,15,340])
    XCTAssertEqual(population.activePedestrians,5,"Normal phase changes add at most two actors per reconcile")
  }
  func testLivingWorldVehiclesAreCommerceOwnedNonblockingPresentation() {
    let population=AtlantisLivingWorldDistrictPopulation();population.setBenchmarkPopulation(district:.commerceDistrict,pedestrians:5,vehicles:2)
    population.reconcile(residents:[.commerceDistrict],current:.commerceDistrict,phase:.day,playerPosition:[300,15,190],immediate:true)
    XCTAssertEqual(population.activePedestrians,5);XCTAssertEqual(population.activeVehicles,2);XCTAssertEqual(population.activeEntityIDs.count,7);XCTAssertEqual(population.root.children.count,7)
    XCTAssertTrue(population.root.children.allSatisfy{$0.components[CollisionComponent.self] == nil})
  }
  func testLivingWorldDoesNotEnterInteractionRegistryOrConsumeCanonicalRNG() async throws {
    let store=GameStore(),rng=store.randomNumberGenerator,stats=store.stats,w=AtlantisRealityWorld(manifest:try .load())
    await w.loader.load(.startupRow)?.value;let registered=w.interactionRegistry.registeredIDs
    w.livingWorld.isEnabled=true;w.livingWorld.setBenchmarkPopulation(district:.startupRow,pedestrians:20,vehicles:0)
    w.livingWorld.reconcile(residents:w.streaming.residents,current:.startupRow,phase:.day,playerPosition:[-460,15,340],immediate:true)
    XCTAssertEqual(w.livingWorld.activePedestrians,20);XCTAssertEqual(w.interactionRegistry.registeredIDs,registered)
    XCTAssertTrue(w.livingWorld.root.children.allSatisfy{!$0.name.hasPrefix("atlantis.interaction")})
    XCTAssertEqual(store.randomNumberGenerator,rng);XCTAssertEqual(store.stats,stats);w.stop()
  }
  func testLivingWorldInteractionRoundTripKeepsPopulationAndWorldRoot() async throws {
    let w=AtlantisRealityWorld(manifest:try .load());await w.loader.load(.founderDistrict)?.value
    w.phase = .evening;w.applyLighting();w.livingWorld.isEnabled=true;w.livingWorld.reconcile(residents:w.streaming.residents,current:.founderDistrict,phase:w.phase,playerPosition:[-875,8,1041],immediate:true)
    let actors=w.livingWorld.activeActorCount,ids=w.livingWorld.activeEntityIDs,root=w.root
    let approached=await w.debugApproachInteraction("atlantis.interaction.founderGarage");XCTAssertTrue(approached);XCTAssertEqual(w.beginInteraction(),.enterFounderGarage)
    XCTAssertTrue(w.returnFromInteraction());XCTAssertEqual(w.livingWorld.activeActorCount,actors);XCTAssertEqual(w.livingWorld.activeEntityIDs,ids);XCTAssertTrue(w.root===root);w.stop()
  }
  func testPublicSnapshotExcludesHiddenRivalTruthAndDoesNotMutateStore() {
    let store=GameStore(),rng=store.randomNumberGenerator,stats=store.stats
    store.techComRivals=[.init(id:"pallas",name:"Pallas AI",claimedTrackRecord:40,actualTrackRecord:2,claimedRevenue:100,actualRevenue:1,claimedMomentum:90,actualMomentum:2)]
    let before=AtlantisWorldSignalSnapshot.read(store)
    store.techComRivals[0].actualMomentum=99;store.techComRivals[0].actualRevenue=99999
    store.techComRivals[0].actualTrackRecord=100;store.techComRivals[0].isVerified=true
    XCTAssertEqual(before,.read(store));XCTAssertEqual(store.stats,stats)
    XCTAssertEqual(store.randomNumberGenerator,rng);XCTAssertEqual(GameStore.saveVersion,20)
  }
  func testFourFixturesProduceDifferentStartupWorldAndDistrictEmphasis() {
    let values=AtlantisLivingWorldFixture.allCases.map{AtlantisWorldReactionAdapter.derive($0.snapshot,district:.startupRow,phase:.day)}
    XCTAssertEqual(values.map(\.reaction),[.ordinary,.interest,.rival,.scrutiny])
    XCTAssertGreaterThan(values[1].pedestrians,values[0].pedestrians)
    XCTAssertTrue(values[2].detail.contains("Pallas AI"));XCTAssertEqual(values[2].encounter,.founderRumor)
    XCTAssertEqual(values[1].encounter,.reporter);XCTAssertEqual(values[3].encounter,.customer)
    let surge=AtlantisLivingWorldFixture.rivalSurge.snapshot
    XCTAssertEqual(AtlantisWorldReactionAdapter.derive(surge,district:.techCore,phase:.day).reaction,.rival)
    XCTAssertEqual(AtlantisWorldReactionAdapter.derive(surge,district:.ventureDistrict,phase:.day).reaction,.ordinary)
    let positive=AtlantisLivingWorldFixture.spotlight.snapshot
    XCTAssertGreaterThan(AtlantisWorldReactionAdapter.derive(positive,district:.startupRow,phase:.day).pedestrians,AtlantisWorldReactionAdapter.derive(positive,district:.startupRow,phase:.night).pedestrians)
  }
  func testDirectorEncountersHaveProximityCooldownAndUnloadLifetime() {
    let director=AtlantisLivingWorldDirector();director.population.isEnabled=true;director.fixture = .rivalSurge
    director.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,position:[-460,14.45,336],immediate:true)
    XCTAssertEqual(director.activeEncounters,1);XCTAssertTrue(director.encounterLine.contains("Pallas AI"))
    XCTAssertEqual(director.activeDisplays,1)
    for _ in 0..<28 {director.advance(delta:0.25,residents:[.startupRow],current:.startupRow,phase:.day,position:[-460,14.45,336])}
    XCTAssertEqual(director.activeEncounters,0)
    director.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,position:[-460,14.45,336])
    XCTAssertEqual(director.activeEncounters,0,"Cooldown prevents immediate replay")
    director.districtDidUnload(.startupRow)
    XCTAssertEqual(director.activeDisplays,0);XCTAssertEqual(director.population.activeActorCount,0)
  }
  func testDirectorLODAndRepeatedTransitionsStayWithinGlobalPoolBounds() {
    let director=AtlantisLivingWorldDirector();director.population.isEnabled=true;director.fixture = .spotlight
    for _ in 0..<8 {
      for district in [AtlantisDistrict.startupRow,.commerceDistrict,.founderDistrict] {
        let anchor=AtlantisLivingWorldPresentationAdapter.activityAnchors.first{$0.district==district}!
        director.reconcile(residents:[.startupRow,.commerceDistrict,.founderDistrict],current:district,phase:.day,position:anchor.position,immediate:true)
        XCTAssertLessThanOrEqual(director.population.activePedestrians,10)
        XCTAssertLessThanOrEqual(director.population.allocatedPedestrians,10)
        XCTAssertLessThanOrEqual(director.population.allocatedVehicles,2)
      }
    }
    director.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,position:[-160,14.45,340],immediate:true)
    XCTAssertEqual(director.population.activePedestrians,2)
    director.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,position:[1000,14.45,340],immediate:true)
    XCTAssertEqual(director.population.activePedestrians,0);XCTAssertEqual(director.activeEncounters,0)
  }
  func testActorRouteTurnsWithoutEndpointTeleportAndReduceMotionKeepsPosition() {
    let actor=AtlantisAmbientActor(kind:.pedestrian,index:0)
    let route=AtlantisAmbientRoute(id:"turn",district:.startupRow,kind:.pedestrian,points:[[0,0,0],[10,0,0]])
    actor.configure(district:.startupRow,route:route,index:0,seed:1);actor.behavior = .walk;actor.speed=1;actor.progress=0.999
    actor.update(delta:0,reduceMotion:true);let before=actor.entity.position
    actor.update(delta:0.1,reduceMotion:true)
    XCTAssertLessThan(simd_distance(before,actor.entity.position),0.11)
    XCTAssertEqual(actor.entity.position.y,0)
  }
  func testBenchmarkOverrideIsCappedAndReturningToNormalImmediatelyHonorsBudget() {
    let population=AtlantisLivingWorldDistrictPopulation()
    population.setBenchmarkPopulation(district:.startupRow,pedestrians:1000,vehicles:100)
    population.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,playerPosition:[-460,14.45,340],immediate:true)
    XCTAssertEqual(population.activePedestrians,20)
    population.clearBenchmarkPopulation()
    population.reconcile(residents:[.startupRow],current:.startupRow,phase:.day,playerPosition:[-460,14.45,340])
    XCTAssertLessThanOrEqual(population.activePedestrians,10)
  }
  func testNamedNPCRegistryHasExactBoundedRosterAndDistrictOwnership() {
    let roster=AtlantisNamedNPCDefinition.all,encounters=AtlantisNamedEncounterDefinition.all
    XCTAssertEqual(roster.count,6);XCTAssertEqual(Set(roster.map(\.id)).count,6)
    XCTAssertEqual(Set(roster.map(\.interactionID)).count,6)
    XCTAssertEqual(roster.filter{$0.role == .founder}.count,2)
    XCTAssertEqual(Set(roster.map(\.role)),Set(AtlantisNamedNPCRole.allCases))
    XCTAssertEqual(Set(roster.map(\.homeDistrict)),[.founderDistrict,.startupRow,.ventureDistrict,.mediaDistrict,.commerceDistrict,.techCore])
    XCTAssertTrue(roster.allSatisfy{$0.interactionID.hasPrefix("atlantis.namedNPC.") && $0.interactionRadius>=7})
    XCTAssertEqual(encounters.count,11);XCTAssertEqual(Set(encounters.map(\.id)).count,11)
    XCTAssertTrue(encounters.allSatisfy{encounter in roster.contains{$0.id==encounter.npcID && $0.encounterCategories.contains(encounter.archetype)}})
    XCTAssertTrue(encounters.allSatisfy{(2...3).contains($0.responses.count)})
  }
  func testNamedEncounterFixturesSelectExpectedPublicArchetypes() {
    let expected:[AtlantisNamedEncounterFixture:String]=[
      .founderPeer:"mara.peer-advice",.reporterSpotlight:"sloane.spotlight",.reporterScrutiny:"sloane.scrutiny",
      .investorInterest:"nia.interest",.pallasSurge:"iris.hiring",.customerComplaint:"devon.complaint"]
    for (fixture,id) in expected {
      let npcEncounters=AtlantisNamedEncounterDefinition.all.filter{$0.npcID==fixture.targetNPCID}
      XCTAssertEqual(AtlantisNamedEncounterPolicy.select(npcEncounters,signals:fixture.snapshot,phase:.day,fixture:fixture)?.id,id)
    }
    XCTAssertFalse(AtlantisNamedEncounterPolicy.eligible(AtlantisNamedEncounterDefinition.all.first{$0.id=="devon.complaint"}!,signals:AtlantisLivingWorldFixture.scrutiny.snapshot,phase:.day))
  }
  func testNamedEncounterSelectionIsDeterministicAndCooldownAware() {
    let signals=AtlantisNamedEncounterFixture.pallasSurge.snapshot
    let values=(0..<20).map{_ in AtlantisNamedEncounterPolicy.select(AtlantisNamedEncounterDefinition.all,signals:signals,phase:.day,seed:42)?.id}
    XCTAssertEqual(Set(values.compactMap{$0}).count,1)
    let first=try! XCTUnwrap(values[0])
    XCTAssertNotEqual(AtlantisNamedEncounterPolicy.select(AtlantisNamedEncounterDefinition.all,signals:signals,phase:.day,cooling:[first],seed:42)?.id,first)
  }
  func testNamedDirectorPreventsDuplicatesReusesEntitiesAndHonorsUnload() {
    let director=AtlantisNamedEncounterDirector();director.isEnabled=true;director.fixture = .founderPeer
    for _ in 0..<4 {director.reconcile(residents:[.founderDistrict],phase:.day,position:[-840,8.03,940],signals:AtlantisLivingWorldFixture.baseline.snapshot,immediate:true)}
    XCTAssertEqual(director.namedNPCCount,1);XCTAssertEqual(director.activeNPCIDs,["mara-chen"]);XCTAssertEqual(director.root.children.count,1);XCTAssertEqual(director.duplicateViolations,0)
    director.districtDidUnload(.founderDistrict);XCTAssertEqual(director.namedNPCCount,0);XCTAssertEqual(director.state(npcID:"mara-chen"),.despawned)
    director.reconcile(residents:[.founderDistrict],phase:.day,position:[-840,8.03,940],signals:AtlantisLivingWorldFixture.baseline.snapshot,immediate:true)
    XCTAssertEqual(director.namedNPCCount,1);XCTAssertEqual(director.reusedEntityCount,1)
  }
  func testNamedDirectorAllowsOneActiveEncounterAndAppliesSessionCooldown() throws {
    let director=AtlantisNamedEncounterDirector();director.isEnabled=true;director.fixture = .founderPeer
    let position=SIMD3<Float>(-840,8.03,946)
    director.reconcile(residents:[.founderDistrict],phase:.day,position:position,signals:AtlantisLivingWorldFixture.baseline.snapshot,immediate:true)
    let candidate=try XCTUnwrap(director.candidate(position:position,forward:[0,0,-1]))
    XCTAssertNotNil(director.begin(npcID:candidate.npc.id,encounterID:candidate.encounter.id,founderPosition:position))
    XCTAssertNil(director.begin(npcID:candidate.npc.id,encounterID:candidate.encounter.id,founderPosition:position))
    XCTAssertNotNil(director.respond(responseID:"focus"));XCTAssertEqual(director.presentationOnlyResponseCount,1);XCTAssertEqual(director.canonicalWritebackCount,0)
    XCTAssertTrue(director.dismiss());director.reconcile(residents:[.founderDistrict],phase:.day,position:position,signals:AtlantisLivingWorldFixture.baseline.snapshot)
    XCTAssertNil(director.candidate(position:position,forward:[0,0,-1]));XCTAssertEqual(director.cooldownCount,1)
    for _ in 0..<181 {director.advance(delta:0.25)}
    director.reconcile(residents:[.founderDistrict],phase:.day,position:position,signals:AtlantisLivingWorldFixture.baseline.snapshot)
    XCTAssertNotNil(director.candidate(position:position,forward:[0,0,-1]))
  }
  func testNamedDialogueContainsOnlyPublicProjectionLanguage() {
    let forbidden=["actualMomentum","actualRevenue","actualTrackRecord","isVerified","verification state","agent drift","calibration","hidden RNG","unrevealed evidence"]
    let corpus=AtlantisNamedEncounterDefinition.all.flatMap{[$0.prompt]+$0.responses.flatMap{[$0.title,$0.acknowledgment]}}.joined(separator:" ").lowercased()
    for term in forbidden {XCTAssertFalse(corpus.contains(term.lowercased()),term)}
    XCTAssertTrue(corpus.contains("tech.com"));XCTAssertTrue(corpus.contains("public"))
    XCTAssertTrue(AtlantisNamedNPCDefinition.all.first{$0.id=="iris-vale"}!.publicKnowledgeScope.contains("claims only"))
  }
  func testNamedWorldInteractionSharesPhase13SelectionAndPreservesCanonicalStore() async throws {
    let store=GameStore(),stats=store.stats,rng=store.randomNumberGenerator,w=AtlantisRealityWorld(manifest:try .load())
    await w.loader.load(.founderDistrict)?.value
    let approachedNamed=await w.debugApproachNamedNPC("mara-chen",fixture:.founderPeer);XCTAssertTrue(approachedNamed)
    XCTAssertEqual(w.activeInteractionID,"atlantis.namedNPC.mara-chen")
    XCTAssertEqual(w.beginInteraction(),.talkNamedNPC(npcID:"mara-chen"));XCTAssertTrue(w.streaming.isFrozen)
    XCTAssertNotNil(w.respondToNamedEncounter("focus"));XCTAssertTrue(w.dismissNamedEncounter());XCTAssertFalse(w.streaming.isFrozen)
    XCTAssertEqual(store.stats,stats);XCTAssertEqual(store.randomNumberGenerator,rng);XCTAssertEqual(GameStore.saveVersion,20)
    let approachedGarage=await w.debugApproachInteraction("atlantis.interaction.founderGarage");XCTAssertTrue(approachedGarage);XCTAssertEqual(w.beginInteraction(),.enterFounderGarage);XCTAssertTrue(w.returnFromInteraction());w.stop()
  }
  func testWorldConsequenceFixturesDeriveExpectedFounderAndPallasStates() {
    let expected:[AtlantisWorldConsequenceFixture:String]=[
      .founderBaseline:"founder.baseline",.founderGrowth:"founder.growth",.founderSpotlight:"founder.spotlight",.founderScrutiny:"founder.scrutiny",
      .pallasBaseline:"pallas.baseline",.pallasSurge:"pallas.surge",.pallasEvent:"pallas.event"]
    for (fixture,id) in expected {
      let state=AtlantisWorldConsequencePolicy.derive(signals:fixture.snapshot,fixture:fixture)
      XCTAssertEqual(state.definition(site:fixture.site)?.id,id)
    }
    XCTAssertEqual(AtlantisWorldConsequencePolicy.derive(signals:AtlantisWorldConsequenceFixture.founderGrowth.snapshot).definition(site:.founderHQ)?.state,.growth)
    XCTAssertEqual(AtlantisWorldConsequencePolicy.derive(signals:AtlantisWorldConsequenceFixture.pallasSurge.snapshot).definition(site:.pallasCampus)?.state,.surge)
    XCTAssertEqual(AtlantisWorldConsequencePolicy.derive(signals:AtlantisWorldConsequenceFixture.pallasEvent.snapshot).definition(site:.pallasCampus)?.state,.event)
  }
  func testWorldConsequenceRegistryHasStableUniqueAnchorsAndBoundedProps() {
    let definitions=AtlantisWorldConsequenceDefinition.all
    XCTAssertEqual(definitions.count,9);XCTAssertEqual(Set(definitions.map(\.id)).count,9)
    XCTAssertEqual(Set(definitions.map(\.site)),Set(AtlantisWorldConsequenceSite.allCases))
    let verified=Set(AtlantisInteractionDefinition.all.map(\.anchorName))
    XCTAssertTrue(definitions.allSatisfy{verified.contains($0.targetAnchor)})
    XCTAssertTrue(definitions.allSatisfy{$0.constructionProps<=3 && $0.eventProps<=5 && !$0.exclusiveGroups.isEmpty})
    XCTAssertEqual(definitions.filter{$0.site == .northwindCampus}.map(\.state),[.baseline])
    XCTAssertEqual(definitions.filter{$0.site == .flashpointCampus}.map(\.state),[.baseline])
  }
  func testWorldConsequencePriorityAndExclusiveGroupsPreventContradiction() {
    for fixture in AtlantisWorldConsequenceFixture.allCases {
      let state=AtlantisWorldConsequencePolicy.derive(signals:fixture.snapshot,fixture:fixture)
      XCTAssertEqual(Set(state.active.map(\.site)).count,state.active.count)
      let groups=state.active.flatMap(\.exclusiveGroups)
      XCTAssertEqual(Set(groups).count,groups.count)
    }
    let scrutiny=AtlantisWorldConsequenceFixture.founderScrutiny.snapshot
    XCTAssertEqual(AtlantisWorldConsequencePolicy.derive(signals:scrutiny).definition(site:.founderHQ)?.id,"founder.scrutiny")
    let event=AtlantisWorldConsequenceFixture.pallasEvent.snapshot
    XCTAssertEqual(AtlantisWorldConsequencePolicy.derive(signals:event).definition(site:.pallasCampus)?.id,"pallas.event")
  }
  func testWorldConsequenceIgnoresHiddenRivalTruthAndStoreRemainsUnchanged() {
    let store=GameStore(),stats=store.stats,rng=store.randomNumberGenerator
    store.techComRivals=[.init(id:"pallas",name:"Pallas AI",claimedTrackRecord:40,actualTrackRecord:2,claimedRevenue:100,actualRevenue:1,claimedMomentum:90,actualMomentum:2)]
    let before=AtlantisWorldSignalSnapshot.read(store),state=AtlantisWorldConsequencePolicy.derive(signals:before)
    store.techComRivals[0].actualMomentum=99;store.techComRivals[0].actualRevenue=99999;store.techComRivals[0].isVerified=true
    XCTAssertEqual(before,AtlantisWorldSignalSnapshot.read(store))
    XCTAssertEqual(state,AtlantisWorldConsequencePolicy.derive(signals:.read(store)))
    XCTAssertEqual(state.definition(site:.pallasCampus)?.state,.surge)
    XCTAssertEqual(store.stats,stats);XCTAssertEqual(store.randomNumberGenerator,rng);XCTAssertEqual(GameStore.saveVersion,20)
  }
  func testWorldConsequenceStreamingReconstructsWithoutDuplicates() {
    let director=AtlantisWorldConsequenceDirector();director.isEnabled=true;director.fixture = .founderGrowth
    func districtRoot()->Entity {let root=Entity(),anchor=Entity();anchor.name="FounderGarageSlot";root.addChild(anchor);return root}
    let first=districtRoot();director.districtDidLoad(.founderDistrict,root:first)
    director.reconcile(residents:[.founderDistrict],signals:AtlantisWorldConsequenceFixture.founderGrowth.snapshot)
    XCTAssertEqual(director.activeIDs,["founder.growth"]);XCTAssertEqual(director.activeConstructionPropCount,3);XCTAssertEqual(director.duplicateViolations,0);XCTAssertEqual(director.exclusiveGroupConflicts,0)
    director.districtDidUnload(.founderDistrict);XCTAssertTrue(director.activeIDs.isEmpty);XCTAssertEqual(director.activeConstructionPropCount,0);XCTAssertEqual(director.activeEventPropCount,0);XCTAssertEqual(first.findEntity(named:"FounderGarageSlot")?.children.count,0)
    let reloaded=districtRoot();director.districtDidLoad(.founderDistrict,root:reloaded);director.reconcile(residents:[.founderDistrict],signals:AtlantisWorldConsequenceFixture.founderGrowth.snapshot)
    XCTAssertEqual(director.activeIDs,["founder.growth"]);XCTAssertEqual(director.activeConstructionPropCount,3);XCTAssertEqual(reloaded.findEntity(named:"FounderGarageSlot")?.children.count,1)
  }
  func testWorldConsequencePublicStateKeepsLivingAndNamedSystemsConsistent() {
    let director=AtlantisLivingWorldDirector();director.population.isEnabled=true;director.namedEncounters.isEnabled=true;director.consequences.isEnabled=true;director.consequences.fixture = .pallasSurge
    let district=Entity(),anchor=Entity();anchor.name="PallasAIHQ";district.addChild(anchor);director.consequences.districtDidLoad(.techCore,root:district)
    director.reconcile(residents:[.techCore],current:.techCore,phase:.day,position:[30,14.45,-324],immediate:true)
    XCTAssertEqual(director.consequences.definition(site:.pallasCampus)?.state,.surge)
    XCTAssertEqual(director.reactions[.techCore]?.reaction,.rival)
    XCTAssertTrue(director.namedEncounters.activeNPCIDs.contains("iris-vale"))
    XCTAssertLessThanOrEqual(director.population.activePedestrians,AtlantisLivingWorldPresentationAdapter.pedestrianBudget)
  }
  func testAmbientRoutesHaveContinuousWalkableSupportAndAvoidBuildingEnvelopes() throws {
    let manifest=try AtlantisAssetManifest.load()
    let walkable=manifest.traversal.triangles.filter{$0.surfaceClass == .walkable}
    let grounding=AtlantisGrounding(traversal:.init(triangles:walkable,barriers:manifest.traversal.barriers,routes:[],surfaces:[]))
    for route in AtlantisLivingWorldPresentationAdapter.routes {
      for (a,b) in zip(route.points,route.points.dropFirst()) {
        for sample in 0...20 {
          let point=simd_mix(a,b,SIMD3<Float>(repeating:Float(sample)/20))
          let height=try XCTUnwrap(grounding.height(at:point,loaded:[route.district.rawValue],referenceHeight:point.y),route.id)
          XCTAssertEqual(height,point.y,accuracy:0.02,route.id)
          XCTAssertFalse(grounding.blocked(point,loaded:[route.district.rawValue]),route.id)
        }
      }
    }
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
