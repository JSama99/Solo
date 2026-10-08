import SwiftUI
import RealityKit

struct SignalTVView: View {
  var events: [PublicMediaEvent]
  var reduceMotion: Bool
  var increasedContrast: Bool
  var continuousMotionEnabled: Bool

  var body: some View {
    // Selection and public presentation derivation stay outside ticker frames.
    let event = NarrativeStoryCompetition.selectPrimaryStory(from: events)
      ?? SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
    let design = SignalTVBroadcastDesign.derive(event: event, reduceMotion: reduceMotion,
      continuousMotionEnabled: continuousMotionEnabled)
    ZStack {
      RoundedRectangle(cornerRadius: 4).fill(.black).frame(width: 72, height: 98)
      RoundedRectangle(cornerRadius: 10)
        .fill(LinearGradient(colors: [.black, FounderGarageMaterial.raisedMetal, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: 286, height: 170)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(increasedContrast ? 0.72 : 0.22), lineWidth: increasedContrast ? 2 : 1) }
        .shadow(color: .black.opacity(0.55), radius: 8, x: 4, y: 6)
      SignalTVBroadcastSurface(event: event, design: design, compact: true, increasedContrast: increasedContrast)
        .frame(width: 268, height: 151)
        .clipShape(.rect(cornerRadius: 5))
      Circle().fill(design.identity.accent.color).frame(width: 3, height: 3).offset(x: 130, y: 80)
    }
    .frame(width: 292, height: 191)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Signal TV, the Startup World Broadcast")
    .accessibilityValue("\(event.program.rawValue). \(design.prominence.rawValue). \(event.headline). \(event.summary)")
    .accessibilityIdentifier("signal-tv-wall-broadcast")
  }
}

/// One broadcast language, with distance-readable wall and richer viewer modes.
private struct SignalTVBroadcastSurface: View {
  let event: PublicMediaEvent
  let design: SignalTVBroadcastDesign
  let compact: Bool
  let increasedContrast: Bool
  var expression: NarrativeExpressionDraft? = nil

  private var accent: Color { design.identity.accent.color }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: compact ? 5 : 10) {
        Text("SIGNAL").font(compact ? .system(size: 10, weight: .black, design: .rounded) : .title3.weight(.black))
          .tracking(compact ? 1.5 : 2)
        Spacer(minLength: 4)
        Label(design.identity.desk, systemImage: design.identity.symbol)
          .font(compact ? .system(size: 6, weight: .black, design: .monospaced) : .caption2.weight(.black))
          .padding(.horizontal, compact ? 5 : 9).padding(.vertical, compact ? 3 : 5)
          .background(accent.opacity(0.18), in: .rect(cornerRadius: 3))
      }
      .padding(compact ? 8 : 18)
      .background(.black.opacity(0.28))
      VStack(alignment: .leading, spacing: compact ? 4 : 12) {
        HStack(spacing: 6) {
          Rectangle().fill(accent).frame(width: 3, height: compact ? 12 : 18)
          Text(event.program.rawValue)
            .font(compact ? .system(size: 11, weight: .black, design: .monospaced) : .subheadline.weight(.black))
            .tracking(compact ? 0.5 : 1)
            .foregroundStyle(accent)
        }
        Text(expression?.headline ?? event.headline)
          .font(compact ? .system(size: 15, weight: .bold, design: .rounded) : .title2.weight(.bold))
          .lineLimit(compact ? 3 : nil)
          .minimumScaleFactor(1)
          .contentTransition(.opacity)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier(compact ? "signal-tv-wall-headline" : "signal-tv-viewer-headline")
        if !compact, let summary = expression?.summary ?? design.supportingSummary {
          Text(summary).font(.body).foregroundStyle(.white.opacity(increasedContrast ? 1 : 0.86))
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
        }
        if compact { Spacer(minLength: 0) }
      }
      .padding(.horizontal, compact ? 9 : 18)
      .padding(.vertical, compact ? 5 : 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 6) {
        Text(design.prominence.rawValue)
        Text("/").foregroundStyle(.white.opacity(0.5))
        Text(event.concernsPlayerCompany ? "SOLO" : "STARTUP WORLD")
        Spacer(minLength: 0)
      }
      .font(compact ? .system(size: 6.5, weight: .bold, design: .monospaced) : .caption2.weight(.bold))
      .padding(.horizontal, compact ? 9 : 18)
      .padding(.vertical, compact ? 4 : 8)
      .background(accent.opacity(event.program == .breaking ? 0.35 : 0.17))
      SignalTVBroadcastTicker(items: expression?.tickerItems ?? design.tickerItems, moves: design.continuousMotionEnabled, compact: compact)
    }
    .foregroundStyle(.white)
    .background {
      ZStack(alignment: .trailing) {
        LinearGradient(colors: [accent.opacity(event.program == .breaking ? 0.28 : 0.18), Color(red: 0.025, green: 0.04, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
        Image(systemName: design.identity.symbol)
          .font(.system(size: compact ? 70 : 170, weight: .ultraLight))
          .foregroundStyle(accent.opacity(0.06))
          .padding(.trailing, compact ? -12 : 12)
        if event.program == .marketPulse {
          Canvas { context, size in
            // An unlabelled studio grid, not a chart or invented market metrics.
            for index in 1..<8 {
              var path = Path()
              let x = CGFloat(index) * size.width / 8
              path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
              context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
            }
          }
        }
      }.accessibilityHidden(true)
    }
    .clipShape(.rect(cornerRadius: compact ? 0 : 12))
    .overlay(alignment: .top) { Rectangle().fill(accent).frame(height: compact ? 2 : 3).accessibilityHidden(true) }
    .animation(design.transitionDuration == 0 ? nil : .easeOut(duration: design.transitionDuration), value: event.id)
  }
}

/// A static, bounded texture for the physical Garage TV. Refresh only when
/// public story content changes; no RealityKit per-frame SwiftUI rendering.
@MainActor
enum SignalTVScreenImage {
  static func render(event: PublicMediaEvent) -> CGImage? {
    let surface = SignalTVBroadcastSurface(event: event,
      design: .derive(event: event, reduceMotion: true, continuousMotionEnabled: false),
      compact: true, increasedContrast: false)
      .frame(width: 268, height: 151)
    let renderer = ImageRenderer(content: surface)
    renderer.scale = 3
    return renderer.cgImage
  }
}

struct SignalTVBroadcastTicker: View {
  let items: [String]
  let moves: Bool
  let compact: Bool
  /// Fixed phase for reproducible close-inspection captures; production is nil.
  var reviewElapsed: Double? = nil

  private var font: Font {
    compact ? .system(size: 8, weight: .semibold, design: .monospaced) : .caption.monospaced()
  }

  var body: some View {
    if !items.isEmpty {
      Group {
        if moves {
          TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reviewElapsed != nil)) { timeline in
            Canvas { context, size in
              let texts = items.map { context.resolve(Text($0).font(font).foregroundStyle(.white)) }
              let widths = texts.map { Double($0.measure(in: CGSize(width: .infinity, height: size.height)).width) }
              let layout = SignalTVTickerLayout(widths: widths, viewportWidth: Double(size.width))
              let offset = layout.offset(at: reviewElapsed ?? timeline.date.timeIntervalSinceReferenceDate)
              // Two copies of a track at least as wide as the viewport cover
              // every phase. Explicit origins keep phrases and separators apart.
              for copy in 0...1 {
                for index in texts.indices {
                  let x = layout.starts[index] + Double(copy) * layout.period - offset
                  context.draw(texts[index], at: CGPoint(x: x, y: size.height / 2), anchor: .leading)
                  let separator = context.resolve(Text("/").font(font).foregroundStyle(.white.opacity(0.45)))
                  context.draw(separator, at: CGPoint(x: x + widths[index] + layout.gap / 2, y: size.height / 2), anchor: .center)
                }
              }
            }
          }
          // A small inset and edge fade make entry/exit intentional, rather
          // than displaying a hard-cut glyph against the screen bezel.
          .padding(.horizontal, compact ? 9 : 18)
          .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.025),
              .init(color: .black, location: 0.975), .init(color: .clear, location: 1)],
              startPoint: .leading, endPoint: .trailing)
          }
        } else {
          Text(items[0]).font(font).lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, compact ? 9 : 18)
        }
      }
      .frame(height: compact ? 19 : 30)
      .foregroundStyle(.white.opacity(0.92))
      .background(.black.opacity(0.70))
      .clipped()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Ticker: \(items.joined(separator: ", "))")
      .accessibilityHidden(compact)
    }
  }
}

private extension SignalTVProgramAccent {
  var color: Color {
    switch self {
    case .mint: Color(red: 0.35, green: 0.94, blue: 0.73)
    case .cyan: Color(red: 0.30, green: 0.85, blue: 1)
    case .violet: Color(red: 0.77, green: 0.65, blue: 1)
    case .coral: Color(red: 1, green: 0.49, blue: 0.47)
    case .gold: Color(red: 1, green: 0.83, blue: 0.43)
    }
  }
}

struct SignalTVViewer: View {
  var events: [PublicMediaEvent]
  var coverage: Int
  /// Presentation-only injection for matched simulator capture; production uses the system setting.
  var reduceMotionOverride: Bool? = nil

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var section = SignalTVViewerSection.currentStory
  @State private var selectedEventID: String?
  @State private var expressionService = NarrativeExpressionService()
  @State private var enhancedRequest: NarrativeExpressionRequest?
  @State private var enhancedCopy: NarrativeExpressionDraft?

  init(events: [PublicMediaEvent], coverage: Int, reduceMotionOverride: Bool? = nil,
       expressionService: NarrativeExpressionService = NarrativeExpressionService()) {
    self.events = events
    self.coverage = coverage
    self.reduceMotionOverride = reduceMotionOverride
    _expressionService = State(initialValue: expressionService)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          broadcastHeader
          viewerConsole
          sectionContent
        }
        .padding(18)
        .frame(maxWidth: 780, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(SoloTheme.background)
      .navigationTitle("Signal TV")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(SoloTheme.background, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("close-signal-tv-viewer")
        }
      }
      .task(id: expressionRequest) {
        guard let request = expressionRequest else { return }
        let result = await expressionService.expression(for: request)
        guard !Task.isCancelled, expressionRequest == request else { return }
        enhancedRequest = request
        enhancedCopy = result.copy
      }
    }
  }

  private var broadcastHeader: some View {
    VStack(alignment: .leading, spacing: 10) {
      SignalTVView(
        events: [selectedEvent],
        reduceMotion: reduceMotion,
        increasedContrast: contrast == .increased,
        continuousMotionEnabled: true
      )
      .frame(maxWidth: .infinity)

    }
  }

  private var viewerConsole: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("SIGNAL TV / VIEWER CONSOLE")
        .font(.caption2.monospaced().weight(.bold)).tracking(1)
        .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 10)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) { browseMenu; Spacer(minLength: 0); coverageStatus }
        VStack(alignment: .leading, spacing: 4) { browseMenu; coverageStatus.padding(.horizontal, 12).padding(.bottom, 10) }
      }
    }
    .background(.white.opacity(0.035), in: .rect(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(contrast == .increased ? 0.5 : 0.12)) }
  }

  private var browseMenu: some View {
    Menu {
      Picker("Signal TV section", selection: $section) {
        ForEach(SignalTVViewerSection.allCases) { item in
          Label(item.title, systemImage: item.symbol).tag(item)
        }
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "line.3.horizontal.decrease")
          .foregroundStyle(SignalTVProgramIdentity(program: selectedEvent.program).accent.color)
        Text(section.title).font(.subheadline.weight(.semibold))
        Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12).frame(minHeight: 44)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Signal TV section")
    .accessibilityValue(section.title)
    .accessibilityHint("Browse public programs and recent headlines")
    .accessibilityIdentifier("signal-tv-section-picker")
  }

  private var coverageStatus: some View {
    HStack(spacing: 6) {
      Text("COVERAGE").font(.caption2.monospaced().weight(.medium)).foregroundStyle(.secondary)
      Text(coverage.formatted(.number.sign(strategy: .always())))
        .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(coverageColor)
    }
    .padding(.trailing, 12)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Coverage")
    .accessibilityValue(coverage.formatted(.number.sign(strategy: .always())))
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch section {
    case .currentStory, .marketPulse, .rivalWatch:
      storyDetail(selectedEvent)
    case .recentHeadlines:
      VStack(alignment: .leading, spacing: 10) {
        Text("RECENT HEADLINES")
          .font(.caption.weight(.black))
          .tracking(1.2)
          .foregroundStyle(.secondary)
        ForEach(recentEvents) { event in
          Button {
            selectedEventID = event.id
            section = section(for: event)
          } label: {
            storyRow(event)
          }
          .buttonStyle(.plain)
          .accessibilityHint("Opens this public broadcast story")
        }
      }
    }
  }

  private func storyDetail(_ event: PublicMediaEvent) -> some View {
    SignalTVBroadcastSurface(event: event,
      design: .derive(event: event, reduceMotion: reduceMotion),
      compact: false, increasedContrast: contrast == .increased,
      expression: expressionRequest != nil && enhancedRequest == expressionRequest ? enhancedCopy : nil)
      .accessibilityIdentifier("signal-tv-viewer-broadcast")
  }

  /// Current selection only. Browsing historical records keeps canonical copy.
  /// The wall preview and mounted Garage texture also remain canonical.
  private var expressionRequest: NarrativeExpressionRequest? {
    guard section == .currentStory, selectedEventID == nil else { return nil }
    return NarrativeExpressionRequest(authorizedEvent: selectedEvent)
  }

  private func storyRow(_ event: PublicMediaEvent) -> some View {
    HStack(spacing: 12) {
      Image(systemName: SignalTVProgramIdentity(program: event.program).symbol)
        .frame(width: 38, height: 38)
        .background(SignalTVProgramIdentity(program: event.program).accent.color.opacity(0.16), in: .rect(cornerRadius: 10))
        .foregroundStyle(SignalTVProgramIdentity(program: event.program).accent.color)
      VStack(alignment: .leading, spacing: 3) {
        Text(event.program.rawValue).font(.caption2.weight(.black)).foregroundStyle(.secondary)
        Text(event.headline).font(.subheadline.weight(.semibold)).lineLimit(2)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
    .contentShape(.rect(cornerRadius: 14))
  }

  private var selectedEvent: PublicMediaEvent {
    switch section {
    case .currentStory:
      if let selectedEventID, let event = publicEvents.first(where: { $0.id == selectedEventID }) {
        return event
      }
      return NarrativeStoryCompetition.selectPrimaryStory(from: events) ?? fallbackMarketPulse
    case .marketPulse:
      return publicEvents.first(where: { $0.program == .marketPulse }) ?? fallbackMarketPulse
    case .rivalWatch:
      return publicEvents.first(where: { $0.program == .rivalWatch }) ?? PublicMediaEvent(
        id: "rival-watch-unavailable",
        program: .rivalWatch,
        tone: .neutral,
        headline: "Rival desk is monitoring the category",
        summary: "No new public rival announcement is on the wire.",
        tickerItems: SignalTVProgramming.safeMarketTicker,
        coverageDelta: 0,
        venture: 1,
        sprint: 1,
        concernsPlayerCompany: false
      )
    case .recentHeadlines:
      return recentEvents.first ?? fallbackMarketPulse
    }
  }

  private var recentEvents: [PublicMediaEvent] {
    Array(publicEvents.prefix(12))
  }

  private var publicEvents: [PublicMediaEvent] {
    SignalTVProgramming.publicBroadcastEvents(events)
  }

  private var fallbackMarketPulse: PublicMediaEvent {
    publicEvents.first(where: { $0.program == .marketPulse }) ?? SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
  }

  private var coverageColor: Color {
    coverage > 0 ? SoloTheme.mint : coverage < 0 ? SoloTheme.coral : .secondary
  }

  private func section(for event: PublicMediaEvent) -> SignalTVViewerSection {
    switch event.program {
    case .marketPulse: .marketPulse
    case .rivalWatch: .rivalWatch
    case .techComLive, .breaking, .founderSpotlight: .currentStory
    }
  }

}

private enum SignalTVViewerSection: String, CaseIterable, Identifiable {
  case currentStory
  case marketPulse
  case rivalWatch
  case recentHeadlines

  var id: Self { self }

  var title: String {
    switch self {
    case .currentStory: "Current Story"
    case .marketPulse: "Market Pulse"
    case .rivalWatch: "Rival Watch"
    case .recentHeadlines: "Recent Headlines"
    }
  }

  var symbol: String {
    switch self {
    case .currentStory: "tv"
    case .marketPulse: "chart.xyaxis.line"
    case .rivalWatch: "building.2"
    case .recentHeadlines: "clock.arrow.circlepath"
    }
  }
}

#if DEBUG
/// Isolated visual review of the production Garage asset and mounted screen.
/// No GameStore, save, or simulation state is injected into this fixture.
@MainActor
struct SignalTVGarageReviewHost: View {
  @State private var world = FounderGarageRealityWorld()
  @State private var status = "Loading production Garage"

  var body: some View {
    RealityView { content in
      world.attachRoot { content.add($0) }
    }
    .overlay(alignment: .topLeading) {
      Text("DEBUG · GARAGE BROADCAST REVIEW · \(status)")
        .font(.caption2.monospaced()).padding(8)
        .foregroundStyle(.white).background(.black.opacity(0.8))
    }
    .task {
      await world.requestGarageArchitecture(.bundledProductionAsset(name: FounderGarageV8AssetContract.resourceName),
        descriptor: .facilityTier0V8)?.value
      do {
        try world.applySignalTVBroadcast([SignalTVProgramming.marketPulse(venture: 1, sprint: 1)])
        if ProcessInfo.processInfo.arguments.contains("--signal-tv-garage-review-free-look") {
          // Exercise the existing seated Free Look and its normal lens/limits.
          // This fixture does not move the eye or introduce a capture camera.
          let home = world.cameraController.recipe(for: .founderPOV)
          let neutral = home.lookTarget - home.position
          let target = world.spatialSpecification.anchors.signalTV.position - home.position
          let yaw = atan2(neutral.x, -neutral.z) - atan2(target.x, -target.z)
          let neutralPitch = atan2(neutral.y, sqrt(neutral.x * neutral.x + neutral.z * neutral.z))
          let targetPitch = atan2(target.y, sqrt(target.x * target.x + target.z * target.z))
          world.cameraController.transition(to: .founderPOV, reduceMotion: true)
          world.cameraController.setLookOrientation(.init(yaw: yaw, pitch: targetPitch - neutralPitch))
        } else {
          world.cameraController.focus(on: .signalTV, reduceMotion: true)
        }
        status = "Public Market Pulse"
      } catch { status = "Screen rendering failed" }
    }
  }
}
#endif
