import SwiftUI

struct SignalTVView: View {
  var events: [PublicMediaEvent]
  var reduceMotion: Bool
  var increasedContrast: Bool
  var continuousMotionEnabled: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 12, paused: !continuousMotionEnabled)) { context in
      let elapsed = context.date.timeIntervalSinceReferenceDate
      let event = currentEvent(elapsed: elapsed)
      televisionBody(event: event, elapsed: elapsed)
    }
    .frame(width: 292, height: 191)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Signal TV, the Startup World Broadcast")
    .accessibilityValue(accessibilitySummary)
  }

  private func currentEvent(elapsed: TimeInterval) -> PublicMediaEvent {
    guard !events.isEmpty else { return SignalTVProgramming.marketPulse(venture: 1, sprint: 1) }
    return events[SignalTVProgramming.presentationIndex(elapsed: elapsed, count: events.count, reduceMotion: reduceMotion)]
  }

  private var accessibilitySummary: String {
    let event = events.first ?? SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
    return "\(event.program.rawValue). \(event.headline). \(event.summary)"
  }

  private func televisionBody(event: PublicMediaEvent, elapsed: TimeInterval) -> some View {
    ZStack {
      Ellipse().fill(.black.opacity(0.52)).frame(width: 270, height: 35).offset(x: 8, y: 80)
      wallMount
      RoundedRectangle(cornerRadius: 10)
        .fill(LinearGradient(colors: [.black, FounderGarageMaterial.raisedMetal, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: 286, height: 170)
        .overlay { FounderGarageSurfaceTexture(kind: .powderCoat).clipShape(.rect(cornerRadius: 10)) }
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(increasedContrast ? 0.72 : 0.19), lineWidth: increasedContrast ? 2 : 1) }
        .shadow(color: .black.opacity(0.66), radius: 9, x: 7, y: 8)
      broadcastScreen(event: event, elapsed: elapsed)
        .frame(width: 268, height: 151)
        .clipShape(.rect(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.13), lineWidth: 1) }
      Circle().fill(Color.cyan.opacity(0.48)).frame(width: 3, height: 3).offset(x: 130, y: 80)
    }
  }

  private var wallMount: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.94)).frame(width: 72, height: 98)
      HStack(spacing: 46) {
        RoundedRectangle(cornerRadius: 2).fill(FounderGarageMaterial.satinMetal).frame(width: 9, height: 128)
        RoundedRectangle(cornerRadius: 2).fill(FounderGarageMaterial.satinMetal).frame(width: 9, height: 128)
      }
      ForEach(0..<4, id: \.self) { index in
        Circle().fill(.white.opacity(0.30)).frame(width: 5, height: 5)
          .offset(x: index.isMultiple(of: 2) ? -28 : 28, y: index < 2 ? -50 : 50)
      }
    }
    .offset(y: 4)
  }

  private func broadcastScreen(event: PublicMediaEvent, elapsed: TimeInterval) -> some View {
    ZStack {
      LinearGradient(colors: broadcastColors(for: event), startPoint: .topLeading, endPoint: .bottomTrailing)
      screenGrid
      VStack(spacing: 0) {
        networkIdent(event)
        Spacer(minLength: 2)
        programGraphic(event: event, elapsed: elapsed)
        Spacer(minLength: 2)
        lowerThird(event)
        ticker(event: event, elapsed: elapsed)
      }
      .padding(.top, 6)
      LinearGradient(colors: [.white.opacity(0.08), .clear, .black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
        .allowsHitTesting(false)
    }
  }

  private func networkIdent(_ event: PublicMediaEvent) -> some View {
    HStack(spacing: 6) {
      Text("SIGNAL").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1.2)
      Text("THE STARTUP WORLD BROADCAST").font(.system(size: 4.6, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.66))
      Spacer()
      if event.program == .breaking { Text("LIVE").foregroundStyle(.white).padding(.horizontal, 4).background(.red.opacity(0.80), in: .capsule) }
    }
    .font(.system(size: 6, weight: .black, design: .monospaced))
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
  }

  @ViewBuilder
  private func programGraphic(event: PublicMediaEvent, elapsed: TimeInterval) -> some View {
    HStack(spacing: 9) {
      switch event.program {
      case .marketPulse:
        marketChart(elapsed: elapsed)
      case .founderSpotlight:
        interviewPortrait(symbol: "person.crop.square.filled.and.at.rectangle", label: "SOLO FOUNDER")
      case .rivalWatch:
        interviewPortrait(symbol: "building.2.fill", label: "RIVAL DESK")
      case .breaking:
        Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
      case .techComLive:
        Image(systemName: "newspaper.fill").font(.system(size: 29, weight: .bold)).foregroundStyle(Color.cyan.opacity(0.92))
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(event.program.rawValue).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(programColor(event))
        Text(event.headline).font(.system(size: 10, weight: .black, design: .rounded)).lineLimit(3).minimumScaleFactor(0.78)
        Text(event.summary).font(.system(size: 5.8, weight: .medium)).foregroundStyle(.white.opacity(0.72)).lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 9)
    .foregroundStyle(.white)
  }

  private func interviewPortrait(symbol: String, label: String) -> some View {
    VStack(spacing: 2) {
      Image(systemName: symbol).font(.system(size: 25)).frame(width: 50, height: 42).background(.white.opacity(0.10), in: .rect(cornerRadius: 4))
      Text(label).font(.system(size: 4.8, weight: .black, design: .monospaced))
      HStack(spacing: 1) { ForEach(0..<8, id: \.self) { index in Capsule().frame(width: 1.5, height: CGFloat(2 + (index * 3) % 8)) } }
        .foregroundStyle(Color.cyan.opacity(0.78))
    }
    .foregroundStyle(.white.opacity(0.86))
  }

  private func marketChart(elapsed: TimeInterval) -> some View {
    Canvas { context, size in
      let values: [CGFloat] = [0.68, 0.54, 0.61, 0.39, 0.45, 0.22, 0.28]
      let progress = reduceMotion ? 1 : min(1, elapsed.truncatingRemainder(dividingBy: 8) / 2.2)
      var path = Path()
      for index in values.indices {
        let point = CGPoint(x: CGFloat(index) / CGFloat(values.count - 1) * size.width, y: values[index] * size.height)
        index == 0 ? path.move(to: point) : path.addLine(to: point)
      }
      context.stroke(path.trimmedPath(from: 0, to: progress), with: .color(Color.cyan), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
    .frame(width: 66, height: 45)
    .background(.black.opacity(0.18), in: .rect(cornerRadius: 4))
  }

  private func lowerThird(_ event: PublicMediaEvent) -> some View {
    HStack(spacing: 4) {
      Text(event.concernsPlayerCompany ? "SOLO" : "STARTUP WORLD").fontWeight(.black)
      Rectangle().fill(.white.opacity(0.28)).frame(width: 1, height: 8)
      Text(event.tone == .favorable ? "FAVORABLE" : event.tone == .critical ? "CRITICAL" : "PUBLIC UPDATE")
      Spacer()
    }
    .font(.system(size: 5.4, weight: .bold, design: .monospaced))
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .frame(height: 13)
    .background(programColor(event).opacity(0.52))
  }

  private func ticker(event: PublicMediaEvent, elapsed: TimeInterval) -> some View {
    let items = event.tickerItems.isEmpty ? SignalTVProgramming.safeMarketTicker : event.tickerItems
    let text = items.joined(separator: "  •  ")
    return GeometryReader { geometry in
      if reduceMotion {
        Text(items[SignalTVProgramming.tickerIndex(elapsed: elapsed, count: items.count)])
          .frame(width: geometry.size.width, alignment: .leading)
          .padding(.horizontal, 7)
          .transition(.opacity)
      } else {
        Text(text).fixedSize()
          .offset(x: geometry.size.width - CGFloat(elapsed.truncatingRemainder(dividingBy: 32) / 32) * (geometry.size.width + CGFloat(text.count) * 4.2))
      }
    }
    .font(.system(size: 5.5, weight: .bold, design: .monospaced))
    .foregroundStyle(.white.opacity(0.88))
    .frame(height: 13)
    .background(.black.opacity(0.76))
    .clipped()
    .accessibilityHidden(true)
  }

  private var screenGrid: some View {
    Canvas { context, size in
      for index in 1..<8 {
        let x = CGFloat(index) / 8 * size.width
        var path = Path(); path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
      }
    }
    .allowsHitTesting(false)
  }

  private func broadcastColors(for event: PublicMediaEvent) -> [Color] {
    switch event.program {
    case .breaking: [Color(red: 0.34, green: 0.035, blue: 0.05), Color(red: 0.07, green: 0.025, blue: 0.045)]
    case .founderSpotlight: [Color(red: 0.13, green: 0.07, blue: 0.25), Color(red: 0.025, green: 0.055, blue: 0.10)]
    default: [Color(red: 0.025, green: 0.11, blue: 0.16), Color(red: 0.025, green: 0.035, blue: 0.075)]
    }
  }

  private func programColor(_ event: PublicMediaEvent) -> Color {
    switch event.tone {
    case .favorable: SoloTheme.mint
    case .critical: SoloTheme.coral
    case .neutral: SoloTheme.cyan
    }
  }
}

struct SignalTVViewer: View {
  var events: [PublicMediaEvent]
  var coverage: Int

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var section = SignalTVViewerSection.currentStory
  @State private var selectedEventID: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("THE STARTUP WORLD BROADCAST")
            .font(.caption2.weight(.black))
            .tracking(1.4)
            .foregroundStyle(.secondary)
          broadcastHeader
          Picker("Signal TV section", selection: $section) {
            ForEach(SignalTVViewerSection.allCases) { item in
              Label(item.title, systemImage: item.symbol).tag(item)
            }
          }
          .pickerStyle(.menu)
          .buttonStyle(.bordered)
          .accessibilityIdentifier("signal-tv-section-picker")
          sectionContent
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(SoloTheme.background)
      .navigationTitle("Signal TV")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("close-signal-tv-viewer")
        }
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
      HStack {
        Label(selectedEvent.program.rawValue, systemImage: section.symbol)
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        Text("COVERAGE \(coverage.formatted(.number.sign(strategy: .always())))")
          .font(.caption.monospacedDigit().weight(.black))
          .foregroundStyle(coverageColor)
          .accessibilityLabel("Coverage")
          .accessibilityValue(coverage.formatted(.number.sign(strategy: .always())))
      }
    }
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
    VStack(alignment: .leading, spacing: 10) {
      Text(event.headline).font(.title3.weight(.bold))
      Text(event.summary).font(.body).foregroundStyle(.secondary)
      if !event.tickerItems.isEmpty {
        Label(event.tickerItems.joined(separator: "  •  "), systemImage: "text.line.first.and.arrowtriangle.forward")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .accessibilityLabel("Ticker: \(event.tickerItems.joined(separator: ", "))")
      }
      if event.concernsPlayerCompany {
        Label("Public SOLO company story", systemImage: "building.2")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
  }

  private func storyRow(_ event: PublicMediaEvent) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon(for: event.program))
        .frame(width: 38, height: 38)
        .background(programColor(event).opacity(0.16), in: .rect(cornerRadius: 10))
        .foregroundStyle(programColor(event))
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
      if let selectedEventID, let event = events.first(where: { $0.id == selectedEventID }) {
        return event
      }
      guard !events.isEmpty else { return fallbackMarketPulse }
      let index = SignalTVProgramming.presentationIndex(
        elapsed: Date.now.timeIntervalSinceReferenceDate,
        count: events.count,
        reduceMotion: reduceMotion
      )
      return events[index]
    case .marketPulse:
      return events.first(where: { $0.program == .marketPulse }) ?? fallbackMarketPulse
    case .rivalWatch:
      return events.first(where: { $0.program == .rivalWatch }) ?? PublicMediaEvent(
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
    Array(events.filter(\.isPublic).prefix(12))
  }

  private var fallbackMarketPulse: PublicMediaEvent {
    events.first(where: { $0.program == .marketPulse }) ?? SignalTVProgramming.marketPulse(venture: 1, sprint: 1)
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

  private func icon(for program: SignalTVProgram) -> String {
    switch program {
    case .marketPulse: "chart.xyaxis.line"
    case .techComLive: "newspaper"
    case .rivalWatch: "building.2"
    case .breaking: "dot.radiowaves.left.and.right"
    case .founderSpotlight: "person.crop.rectangle"
    }
  }

  private func programColor(_ event: PublicMediaEvent) -> Color {
    switch event.tone {
    case .favorable: SoloTheme.mint
    case .neutral: SoloTheme.cyan
    case .critical: SoloTheme.coral
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
