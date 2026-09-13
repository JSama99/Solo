#if DEBUG
import RealityKit
import SwiftUI

struct AtlantisRealityView: View {
  @State private var world: AtlantisRealityWorld?
  @State private var failure: String?
  @State private var store = GameStore()
  @State private var presentation = PresentationCoordinator()
  @State private var route: AtlantisCanonicalRoute?
  @Environment(SubscriptionStore.self) private var subscriptions
  @Environment(FounderProgressionStore.self) private var progression
  @Environment(AchievementStore.self) private var achievements
  private var worldSignals: AtlantisWorldSignalSnapshot { .read(store) }
  var body: some View {
    Group {
      if let world { AtlantisDebugContent(world:world,onActivate:{ intent in open(intent,world:world) }) }
      else if let failure { ContentUnavailableView("Atlantis unavailable",systemImage:"exclamationmark.triangle",description:Text(failure)) }
      else { ProgressView("Reading Atlantis manifest") }
    }
    .task {
      guard world == nil else{return}
      do {world=AtlantisRealityWorld(manifest:try .load());world?.livingDirector.receive(worldSignals)} catch {failure=error.localizedDescription}
    }
    .onChange(of:worldSignals) {_,value in world?.livingDirector.receive(value)}
    .onAppear {store.entitlements=subscriptions;store.progressionStore=progression;store.achievementStore=achievements}
    .fullScreenCover(item:$route,onDismiss:{_ = world?.returnFromInteraction()}) { destination in
      AtlantisCanonicalDestination(destination:destination,store:store,presentation:presentation) {route=nil}
    }
    .accessibilityIdentifier("atlantis.debug.root")
  }

  private func open(_ intent: AtlantisInteractionIntent,world: AtlantisRealityWorld) {
    if case .talkNamedNPC = intent {return}
    let rivalIDs=Set(ContentLibrary.rivalCompanies.map(\.id))
    guard let destination=AtlantisCanonicalRoute.resolve(intent,availableRivalIDs:rivalIDs) else {world.cancelInteraction(reason:"Canonical route unavailable");return}
    route=destination
  }
}

private struct AtlantisDebugContent: View {
  @Bindable var world: AtlantisRealityWorld
  var onActivate: (AtlantisInteractionIntent) -> Void
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    VStack(spacing:0) {
      RealityView { content in
        content.add(world.root)
        world.subscribe { handler in content.subscribe(to:SceneEvents.Update.self,on: nil,handler) }
      }
      .accessibilityHidden(true)
      .background(Color(red:0.15,green:0.25,blue:0.35))
      .overlay(alignment:.topLeading) {
        Text("ATLANTIS · DEBUG SPIKE").font(.caption.bold()).padding(8).background(.black.opacity(0.6)).accessibilityHidden(true)
      }
      ScrollView {
        VStack(alignment:.leading,spacing:8) {
          HStack {
            Text("\(world.loader.loaded.count)/7 districts").font(.headline)
            Spacer()
            Text(world.benchmarkStatus).font(.caption).accessibilityIdentifier("atlantis.debug.benchmarkStatus")
          }
          if let error=world.error {Text(error).foregroundStyle(.red)}
          Text("Current: \(world.streaming.current.title) · residents: \(world.streaming.residents.map(\.title).sorted().joined(separator:", "))")
            .font(.caption).accessibilityIdentifier("atlantis.debug.streaming.residents")
          Text("Prefetched: \(world.streaming.prefetched.map(\.title).sorted().joined(separator:", ")) · pending: \(world.streaming.pending.map(\.title).sorted().joined(separator:", ")) · \(world.farLandmarkState)")
            .font(.caption).accessibilityIdentifier("atlantis.debug.streaming.status")
          Text(String(format:"Position %.1f, %.2f, %.1f · memory %.1f MiB",world.playerRoot.position.x,world.playerRoot.position.y,world.playerRoot.position.z,AtlantisMemory.footprintMB()))
            .font(.caption.monospacedDigit()).accessibilityIdentifier("atlantis.debug.streaming.position")
          Text("Living: \(world.livingWorld.activePedestrians) pedestrians · \(world.livingWorld.pooledPedestrians) pooled · \(world.livingWorld.activeVehicles) vehicles · \(world.livingWorld.residentDistrictCount) active districts")
            .font(.caption).accessibilityIdentifier("atlantis.debug.living.counts")
          Text(String(format:"Density: %@ · %d resident anchors · update %.2f µs",AtlantisLivingWorldPresentationAdapter.profile(district:world.streaming.current,phase:world.phase).language,AtlantisLivingWorldPresentationAdapter.activityAnchors.filter{world.streaming.residents.contains($0.district)}.count,world.livingWorld.meanUpdateMicroseconds))
            .font(.caption).accessibilityIdentifier("atlantis.debug.living.metrics")
          Text(AtlantisDistrict.allCases.map{"\($0.title): \(world.livingWorld.count(district:$0))"}.joined(separator:" · "))
            .font(.caption).accessibilityIdentifier("atlantis.debug.living.districtCounts")
          Text("Reactions: \(world.livingDirector.fixture?.rawValue ?? "Live public state") · \(world.livingDirector.activeDisplays) displays · \(world.livingDirector.activeEncounters) encounters · \(world.livingDirector.entityCount) entities")
            .font(.caption).accessibilityIdentifier("atlantis.debug.living.reactions")
          if !world.livingDirector.encounterLine.isEmpty {Text(world.livingDirector.encounterLine).font(.callout).accessibilityIdentifier("atlantis.debug.living.encounter")}
          Text("Named: \(world.livingDirector.namedEncounters.namedNPCCount)/6 present · \(world.livingDirector.namedEncounters.activeNPCIDs.joined(separator:", ")) · \(world.livingDirector.namedEncounters.eligibleEncounterCount) eligible")
            .font(.caption).accessibilityIdentifier("atlantis.debug.named.counts")
          Text("Named state: \(world.livingDirector.namedEncounters.publicSignalClassification) · \(world.streaming.current.title) · cooldowns \(world.livingDirector.namedEncounters.cooldownSummary)")
            .font(.caption).accessibilityIdentifier("atlantis.debug.named.state")
          Text("Named active: \(world.livingDirector.namedEncounters.activeSession?.npc.displayName ?? "none") · \(world.livingDirector.namedEncounters.activeSession?.encounter.archetype.rawValue ?? "none") · duplicates \(world.livingDirector.namedEncounters.duplicateViolations) · canonical writes \(world.livingDirector.namedEncounters.canonicalWritebackCount) · presentation responses \(world.livingDirector.namedEncounters.presentationOnlyResponseCount)")
            .font(.caption).accessibilityIdentifier("atlantis.debug.named.metrics")
          Text("Consequences: \(world.livingDirector.consequences.activeStateCount) active · \(world.livingDirector.consequences.activeIDs.joined(separator:", ")) · event \(world.livingDirector.consequences.activeEventState) · \(worldConsequenceAccessibilityLabel)")
            .font(.caption)
            .accessibilityIdentifier("atlantis.debug.consequence.states")
          Text("Founder HQ: \(world.livingDirector.consequences.founderHQState) · rivals: \(world.livingDirector.consequences.rivalCampusStates) · signs \(world.livingDirector.consequences.activeSignageCount) · construction \(world.livingDirector.consequences.activeConstructionPropCount) · event props \(world.livingDirector.consequences.activeEventPropCount)")
            .font(.caption).accessibilityIdentifier("atlantis.debug.consequence.presentation")
          Text(String(format:"Consequence entities %d · reconcile %.3f ms · duplicates %d · conflicts %d",world.livingDirector.consequences.activeEntityCount,world.livingDirector.consequences.reconciliationCostMS,world.livingDirector.consequences.duplicateViolations,world.livingDirector.consequences.exclusiveGroupConflicts))
            .font(.caption.monospacedDigit()).accessibilityIdentifier("atlantis.debug.consequence.metrics")
          HStack {
            Text("Interactions: \(world.interactionRegistry.count) · candidate cost \(world.interactionRegistry.meanEvaluationMicroseconds.formatted(.number.precision(.fractionLength(2)))) µs")
              .font(.caption).accessibilityIdentifier("atlantis.debug.interaction.metrics")
            Spacer()
            Button(world.interactionPrompt) {
              guard let intent=world.beginInteraction() else{return};onActivate(intent)
            }
            .disabled(world.activeInteractionID == nil)
            .accessibilityIdentifier(world.activeInteractionID ?? "atlantis.interaction.none")
          }
          ScrollView(.horizontal) {
            HStack {
              Button("Load Founder") {Task {await world.loader.loadContext()?.value;await world.loader.load(.founderDistrict)?.value}}.accessibilityIdentifier("atlantis.debug.loadFounder")
              Button("Load Startup") {world.loader.load(.startupRow)}.accessibilityIdentifier("atlantis.debug.loadStartup")
              Button("Load all") {Task {await world.loader.loadContext()?.value;for d in AtlantisDistrict.allCases {await world.loader.load(d)?.value}}}.accessibilityIdentifier("atlantis.debug.loadAll")
              Button("Unload all") {world.unloadAll()}.accessibilityIdentifier("atlantis.debug.unloadAll")
              Button("Benchmark") {world.beginBenchmark()}.accessibilityIdentifier("atlantis.debug.benchmark")
            }
          }
          ScrollView(.horizontal) {
            HStack {
              ForEach(AtlantisNamedEncounterFixture.allCases) {fixture in
                Button(fixture.accessibilityID) {showNamedFixture(fixture)}
                  .accessibilityIdentifier("atlantis.debug.named.fixture.\(fixture.accessibilityID)")
              }
            }
          }
          ScrollView(.horizontal) {
            HStack {
              ForEach(AtlantisWorldConsequenceFixture.allCases) {fixture in
                Button(fixture.accessibilityID) {showConsequenceFixture(fixture)}
                  .accessibilityIdentifier("atlantis.debug.consequence.fixture.\(fixture.accessibilityID)")
              }
              Button("Unload consequence site") {unloadConsequenceFixtureDistrict()}
                .accessibilityIdentifier("atlantis.debug.consequence.unload")
              Button("Reload consequence site") {reloadConsequenceFixtureDistrict()}
                .accessibilityIdentifier("atlantis.debug.consequence.reload")
            }
          }
          ScrollView(.horizontal) {
            HStack {
              ForEach(AtlantisBenchmarkCamera.allCases) { camera in
                Button(String(camera.rawValue.prefix(1)).uppercased()) { world.selectCamera(camera) }
                  .accessibilityIdentifier("atlantis.debug.cameraDirect.\(camera.rawValue)")
              }
            }
          }
          ScrollView(.horizontal) {
            HStack {
              Button("10") { setStartupPopulation(10) }
                .accessibilityIdentifier("atlantis.debug.living.startup10Direct")
              Button("Unload") { world.loader.unload(.startupRow) }
                .accessibilityIdentifier("atlantis.debug.living.unloadStartupDirect")
              Button("Reload") { reloadStartupPopulation() }
                .accessibilityIdentifier("atlantis.debug.living.reloadStartupDirect")
              Button("Bounded") {
                world.livingWorld.isEnabled=true;world.livingWorld.clearBenchmarkPopulation()
                world.livingDirector.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,position:world.playerRoot.position,immediate:true)
              }
              .accessibilityIdentifier("atlantis.debug.living.boundedDirect")
              Button("Mixed") { showCommerceMixed() }
                .accessibilityIdentifier("atlantis.debug.living.commerceMixedDirect")
            }
          }
          ScrollView(.horizontal) {HStack {
              Menu("Camera") {ForEach(AtlantisBenchmarkCamera.allCases) {c in Button(c.rawValue) {world.selectCamera(c)}.accessibilityIdentifier("atlantis.debug.camera.\(c.rawValue)")}}
                .accessibilityIdentifier("atlantis.debug.camera")
              Menu("Lighting: \(world.phase.title)") {ForEach(FounderEnvironmentTimeState.allCases,id:\.self) {p in Button(p.title) {world.phase=p;world.applyLighting()}}}
              Menu("Shadows: \(world.shadowMode)") {ForEach(0..<3) {mode in Button(["Off","120 m","500 m"][mode]) {world.shadowMode=mode;world.applyLighting()}}}
              Menu("Districts") {ForEach(AtlantisDistrict.allCases) {d in
                Button("Load \(d.title)") {world.loader.load(d)}
                Button("Unload \(d.title)") {world.unload(d)}
              }}
              Menu("Traverse") {
                Button("Enter Startup") {Task {_=await world.streaming.enter(.startupRow,next:.commerceDistrict)}}
                Button("Enter Commerce") {Task {_=await world.streaming.enter(.commerceDistrict,next:.techCore)}}
                Button("Enter Tech Core") {Task {_=await world.streaming.enter(.techCore,next:.unicornHeights)}}
                Button("Enter Unicorn") {Task {_=await world.streaming.enter(.unicornHeights)}}
              }.accessibilityIdentifier("atlantis.debug.streaming.traverse")
              Menu("Interactions") {
                ForEach(AtlantisInteractionDefinition.all) { target in
                  Button("Approach \(target.accessibilityLabel)") {Task {_=await world.debugApproachInteraction(target.id)}}
                    .accessibilityIdentifier("atlantis.debug.approach.\(target.id)")
                }
              }.accessibilityIdentifier("atlantis.debug.interactions")
              Menu("World scenario") {
                Button("Live public state") {world.livingDirector.fixture=nil}
                ForEach(AtlantisLivingWorldFixture.allCases) {fixture in
                  Button(fixture.rawValue) {
                    world.livingWorld.isEnabled=true;world.livingWorld.clearBenchmarkPopulation()
                    world.livingDirector.fixture=fixture
                    world.livingDirector.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,position:world.playerRoot.position,immediate:true)
                  }
                  .accessibilityIdentifier("atlantis.debug.living.scenario.\(fixture.accessibilityID)")
                }
                Button("View Startup reactions") {Task {
                  _=await world.streaming.enter(.startupRow,next:.commerceDistrict)
                  world.playerRoot.position=[-460,14.45,350]
                  world.livingWorld.isEnabled=true;world.livingWorld.clearBenchmarkPopulation()
                  world.livingDirector.reconcile(residents:world.streaming.residents,current:.startupRow,phase:world.phase,position:world.playerRoot.position,immediate:true)
                  world.selectLivingWorldCamera(.startupRow)
                }}
                .accessibilityIdentifier("atlantis.debug.living.viewStartup")
              }.accessibilityIdentifier("atlantis.debug.living.scenarios")
              Menu("Living World") {
                Button("Enable bounded profile") {world.livingWorld.isEnabled=true;world.livingWorld.clearBenchmarkPopulation();world.livingWorld.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true)}
                ForEach([0,5,10,20],id:\.self) {count in Button("Startup \(count) pedestrians") {Task {await world.loader.load(.startupRow)?.value;world.livingWorld.setBenchmarkPopulation(district:.startupRow,pedestrians:count,vehicles:0);world.livingWorld.reconcile(residents:world.streaming.residents,current:.startupRow,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true);world.selectLivingWorldCamera(.startupRow)}}}
                Button("Commerce mixed") {Task {_=await world.streaming.enter(.commerceDistrict,next:.techCore);world.livingWorld.setBenchmarkPopulation(district:.commerceDistrict,pedestrians:10,vehicles:2);world.livingWorld.reconcile(residents:world.streaming.residents,current:.commerceDistrict,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true);world.selectLivingWorldCamera(.commerceDistrict)}}
                Button("Unload Startup population test") {world.loader.unload(.startupRow)}
                Button("Reload Startup population test") {Task {await world.loader.load(.startupRow)?.value;world.livingWorld.reconcile(residents:world.streaming.residents,current:.startupRow,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true)}}
                Button("Disable and pool") {world.livingWorld.isEnabled=false;world.livingWorld.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true)}
              }.accessibilityIdentifier("atlantis.debug.living.menu")
            }}
          ScrollView(.horizontal) {
            HStack {
              Button("Startup view") { showStartupReactions() }
                .accessibilityIdentifier("atlantis.debug.living.viewStartupDirect")
              ForEach(AtlantisLivingWorldFixture.allCases) { fixture in
                Button(fixture.accessibilityID) { apply(fixture) }
                  .accessibilityIdentifier("atlantis.debug.living.scenarioDirect.\(fixture.accessibilityID)")
              }
            }
          }
          ScrollView(.horizontal) {HStack {ForEach(AtlantisDistrict.allCases) {d in Text("\(d.title): \(world.loader.states[d]?.label ?? "unloaded")").font(.caption).accessibilityIdentifier("atlantis.debug.state.\(d.rawValue)")}}}
          HStack {
            Button(world.isWalking ? "Stop walking" : "Walk") {world.toggleWalk()}.accessibilityIdentifier("atlantis.debug.toggleWalk")
            Button("Forward") {world.walkInput=1}.disabled(!world.isWalking).accessibilityIdentifier("atlantis.debug.forward")
            Button("Back") {world.walkInput = -1}.disabled(!world.isWalking)
            Button("Pause") {world.walkInput=0}.disabled(!world.isWalking)
            Button("↶") {world.turn(.pi/12)}.accessibilityLabel("Turn left").disabled(!world.isWalking)
            Button("↷") {world.turn(-.pi/12)}.accessibilityLabel("Turn right").disabled(!world.isWalking)
          }
          Text(world.movementStatus).font(.caption).accessibilityIdentifier("atlantis.debug.walkStatus")
        }.padding(12)
      }
      .frame(maxHeight:300)
      .buttonStyle(AtlantisDebugButtonStyle())
      .controlSize(.regular)
      .background(.black)
    }
    .overlay {
      if let session=world.livingDirector.namedEncounters.activeSession {
        AtlantisNamedDialogueCard(session:session,onResponse:{_ = world.respondToNamedEncounter($0)},onDismiss:{_ = world.dismissNamedEncounter()})
      }
    }
    .task {
      world.livingWorld.reduceMotion=reduceMotion
      world.livingDirector.namedEncounters.reduceMotion=reduceMotion
      world.livingDirector.consequences.reduceMotion=reduceMotion
      await world.start()
      if ProcessInfo.processInfo.arguments.contains("--atlantis-benchmark"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-founder-profile"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-startup-profile"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-streaming-profile"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-living-world-profile"),
         world.loader.states[.founderDistrict] == .loaded {world.beginBenchmark()}
    }
    .onChange(of:scenePhase) {_,phase in if phase != .active {world.walkInput=0}}
    .onChange(of:reduceMotion) {_,value in world.livingWorld.reduceMotion=value;world.livingDirector.namedEncounters.reduceMotion=value;world.livingDirector.consequences.reduceMotion=value}
    .onDisappear {world.stop()}
  }

  private func apply(_ fixture: AtlantisLivingWorldFixture) {
    world.livingWorld.isEnabled=true;world.livingWorld.clearBenchmarkPopulation()
    world.livingDirector.fixture=fixture
    world.livingDirector.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,position:world.playerRoot.position,immediate:true)
  }

  private func showStartupReactions() {
    Task {
      _=await world.streaming.enter(.startupRow,next:.commerceDistrict)
      world.playerRoot.position=[-460,14.45,350]
      world.livingWorld.isEnabled=true;world.livingWorld.clearBenchmarkPopulation()
      world.livingDirector.reconcile(residents:world.streaming.residents,current:.startupRow,phase:world.phase,position:world.playerRoot.position,immediate:true)
      world.selectLivingWorldCamera(.startupRow)
    }
  }

  private func setStartupPopulation(_ count: Int) {
    Task {
      await world.loader.load(.startupRow)?.value
      world.livingWorld.setBenchmarkPopulation(district:.startupRow,pedestrians:count,vehicles:0)
      world.livingWorld.reconcile(residents:world.streaming.residents,current:.startupRow,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true)
      world.selectLivingWorldCamera(.startupRow)
    }
  }

  private func reloadStartupPopulation() {
    Task {
      await world.loader.load(.startupRow)?.value
      world.livingWorld.reconcile(residents:world.streaming.residents,current:.startupRow,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true)
    }
  }

  private func showCommerceMixed() {
    Task {
      _=await world.streaming.enter(.commerceDistrict,next:.techCore)
      world.livingWorld.setBenchmarkPopulation(district:.commerceDistrict,pedestrians:10,vehicles:2)
      world.livingWorld.reconcile(residents:world.streaming.residents,current:.commerceDistrict,phase:world.phase,playerPosition:world.playerRoot.position,immediate:true)
      world.selectLivingWorldCamera(.commerceDistrict)
    }
  }

  private func showNamedFixture(_ fixture:AtlantisNamedEncounterFixture) {
    Task {
      world.livingDirector.namedEncounters.fixture=fixture
      _=await world.debugApproachNamedNPC(fixture.targetNPCID,fixture:fixture)
    }
  }

  private var worldConsequenceAccessibilityLabel:String {
    let director=world.livingDirector.consequences
    let summaries=AtlantisWorldConsequenceSite.allCases.compactMap{director.definition(site:$0)?.accessibilitySummary}
    return summaries.joined(separator:" ")
  }

  private func showConsequenceFixture(_ fixture:AtlantisWorldConsequenceFixture) {
    Task {
      let definition=AtlantisWorldConsequenceDefinition.all.first{$0.id==fixture.forcedDefinitionID}!
      world.livingDirector.consequences.isEnabled=true;world.livingDirector.consequences.fixture=fixture
      if world.loader.states[definition.district] != .loaded {await world.loader.load(definition.district)?.value}
      world.livingDirector.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,position:world.playerRoot.position,immediate:true)
      world.selectCamera(fixture.site == .founderHQ ? .founderStreet:.techCoreSkyline)
    }
  }

  private func unloadConsequenceFixtureDistrict() {
    guard let fixture=world.livingDirector.consequences.fixture,
          let definition=AtlantisWorldConsequenceDefinition.all.first(where:{$0.id==fixture.forcedDefinitionID}) else{return}
    world.loader.unload(definition.district)
  }

  private func reloadConsequenceFixtureDistrict() {
    guard let fixture=world.livingDirector.consequences.fixture,
          let definition=AtlantisWorldConsequenceDefinition.all.first(where:{$0.id==fixture.forcedDefinitionID}) else{return}
    Task {
      await world.loader.load(definition.district)?.value
      world.livingDirector.reconcile(residents:world.streaming.residents,current:world.streaming.current,phase:world.phase,position:world.playerRoot.position,immediate:true)
      world.selectCamera(fixture.site == .founderHQ ? .founderStreet:.techCoreSkyline)
    }
  }
}

private struct AtlantisNamedDialogueCard: View {
  let session:AtlantisNamedEncounterSession
  let onResponse:(String)->Void
  let onDismiss:()->Void
  var body:some View {
    ZStack {Color.black.opacity(0.35).ignoresSafeArea().accessibilityHidden(true)
      ScrollView {
        VStack(alignment:.leading,spacing:12) {
          Text(session.npc.displayName).font(.title2.bold())
          Text("\(session.npc.role.title) · \(session.npc.affiliation)").font(.subheadline).foregroundStyle(.secondary)
          if let response=session.selectedResponse {
            Text(response.acknowledgment).font(.body)
            Text(response.consequence.label).font(.caption.bold()).foregroundStyle(.secondary)
              .accessibilityIdentifier("atlantis.named.dialogue.consequence")
            Button("Return to Atlantis",action:onDismiss).buttonStyle(.borderedProminent)
              .frame(minHeight:44).accessibilityIdentifier("atlantis.named.dialogue.continue")
          } else {
            Text(session.encounter.prompt).font(.body)
              .accessibilityIdentifier("atlantis.named.dialogue.prompt")
            ForEach(session.encounter.responses) {response in
              Button(response.title){onResponse(response.id)}.buttonStyle(.borderedProminent)
                .frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
                .accessibilityIdentifier("atlantis.named.dialogue.response.\(response.id)")
            }
            Button("Leave",action:onDismiss).frame(minHeight:44)
              .accessibilityIdentifier("atlantis.named.dialogue.leave")
          }
        }
        .padding(20).frame(maxWidth:520,alignment:.leading)
        .background(.regularMaterial,in:RoundedRectangle(cornerRadius:20))
        .accessibilityElement(children:.contain)
        .accessibilityIdentifier("atlantis.named.dialogue.\(session.npc.id)")
      }.padding()
    }
  }
}

private struct AtlantisCanonicalDestination: View {
  let destination: AtlantisCanonicalRoute
  var store: GameStore
  var presentation: PresentationCoordinator
  var onReturn: () -> Void

  var body: some View {
    ZStack(alignment:.topTrailing) {
      destinationView
      Text(destination.id).font(.caption2).opacity(0.01)
        .accessibilityIdentifier("atlantis.canonical.\(destination.id)")
      Button("Return to Atlantis",systemImage:"arrow.uturn.backward") {onReturn()}
        .buttonStyle(.borderedProminent).tint(SoloTheme.cyan).padding()
        .accessibilityIdentifier("atlantis.interaction.return")
    }
  }

  @ViewBuilder private var destinationView: some View {
    switch destination {
    case .founderGarage: FounderDeskWorkspace(store:store,presentation:presentation)
    case .techCom,.rival: TechComScreen(store:store)
    case .venture: VentureScreen(store:store)
    case .signalTV:
      SignalTVViewer(events:SignalTVProgramming.ambientEvents(publicEvents:store.publicMediaEvents,techComHeadlines:store.techComHeadlines,rivals:store.techComRivals,coverage:store.stats.coverage,venture:store.venture,sprint:store.sprint),coverage:store.stats.coverage)
    case .playerHQ: HeadquartersProgressScreen(store:store)
    }
  }
}
private struct AtlantisDebugButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.padding(.horizontal,8).frame(minWidth:44,minHeight:44)
      .background(.white.opacity(configuration.isPressed ? 0.22 : 0.1),in:RoundedRectangle(cornerRadius:8))
  }
}
#endif
