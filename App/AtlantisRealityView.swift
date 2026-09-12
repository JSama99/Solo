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
  var body: some View {
    Group {
      if let world { AtlantisDebugContent(world:world,onActivate:{ intent in open(intent,world:world) }) }
      else if let failure { ContentUnavailableView("Atlantis unavailable",systemImage:"exclamationmark.triangle",description:Text(failure)) }
      else { ProgressView("Reading Atlantis manifest") }
    }
    .task {
      guard world == nil else{return}
      do {world=AtlantisRealityWorld(manifest:try .load())} catch {failure=error.localizedDescription}
    }
    .onAppear {store.entitlements=subscriptions;store.progressionStore=progression;store.achievementStore=achievements}
    .fullScreenCover(item:$route,onDismiss:{_ = world?.returnFromInteraction()}) { destination in
      AtlantisCanonicalDestination(destination:destination,store:store,presentation:presentation) {route=nil}
    }
    .accessibilityIdentifier("atlantis.debug.root")
  }

  private func open(_ intent: AtlantisInteractionIntent,world: AtlantisRealityWorld) {
    let rivalIDs=Set(ContentLibrary.rivalCompanies.map(\.id))
    guard let destination=AtlantisCanonicalRoute.resolve(intent,availableRivalIDs:rivalIDs) else {world.cancelInteraction(reason:"Canonical route unavailable");return}
    route=destination
  }
}

private struct AtlantisDebugContent: View {
  @Bindable var world: AtlantisRealityWorld
  var onActivate: (AtlantisInteractionIntent) -> Void
  @Environment(\.scenePhase) private var scenePhase
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
          HStack {
            Text("Interactions: \(world.interactionRegistry.count) · candidate cost \(world.interactionRegistry.meanEvaluationMicroseconds.formatted(.number.precision(.fractionLength(2)))) µs")
              .font(.caption).accessibilityIdentifier("atlantis.debug.interaction.metrics")
            Spacer()
            Button(world.interactionPrompt) {
              guard let intent=world.beginInteraction() else{return};onActivate(intent)
            }
            .disabled(world.activeInteraction == nil)
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
            }}
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
    .task {
      await world.start()
      if ProcessInfo.processInfo.arguments.contains("--atlantis-benchmark"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-founder-profile"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-startup-profile"),
         !ProcessInfo.processInfo.arguments.contains("--atlantis-streaming-profile"),
         world.loader.states[.founderDistrict] == .loaded {world.beginBenchmark()}
    }
    .onChange(of:scenePhase) {_,phase in if phase != .active {world.walkInput=0}}
    .onDisappear {world.stop()}
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
