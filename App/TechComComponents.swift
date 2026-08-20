import SwiftUI

struct TechComMasthead: View {
  var venture: Int
  var sprint: Int
  var marketPosition: Int?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var live = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 8) {
        HStack(spacing: 6) {
          Circle()
            .fill(SoloTheme.coral)
            .frame(width: 7, height: 7)
            .scaleEffect(live && !reduceMotion ? 1.18 : 0.9)
            .opacity(live && !reduceMotion ? 0.7 : 1)
          Text("LIVE")
        }
        .font(.caption2.weight(.black))
        .foregroundStyle(SoloTheme.coral)

        Text("STARTUP INTELLIGENCE")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
        Spacer()
        Text("V\(venture) · S\(sprint)")
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Tech.com")
          .font(.largeTitle.weight(.black))
          .foregroundStyle(.primary)
        Text("The signal behind the startup noise.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 10) {
        Label("SOLO", systemImage: "building.2.fill")
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        if let marketPosition {
          Text("MARKET #\(marketPosition)")
            .foregroundStyle(.primary)
        }
      }
      .font(.caption.weight(.bold))
      .padding(.top, 7)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(SoloTheme.cyan.opacity(contrast == .increased ? 0.8 : 0.35))
          .frame(height: contrast == .increased ? 2 : 1)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 15)
    .background {
      ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 22)
          .fill(SoloTheme.card)
        Circle()
          .fill(SoloTheme.cyan.opacity(0.10))
          .frame(width: 150, height: 150)
          .blur(radius: 28)
          .offset(x: 42, y: -65)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(SoloTheme.cyan.opacity(contrast == .increased ? 0.75 : 0.20), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Tech.com, live startup intelligence. Venture \(venture), sprint \(sprint)"
        + (marketPosition.map { ", SOLO market position \($0)" } ?? "")
    )
    .task {
      guard !reduceMotion else { return }
      withAnimation(.smooth(duration: 1).repeatCount(2, autoreverses: true)) { live = true }
    }
  }
}

struct TechComCompanyFeed: View {
  var headlines: [TechComHeadline]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var idlePulse = false

  var body: some View {
    TechComEditorialSurface(
      eyebrow: "YOUR COMPANY",
      title: "Live company activity",
      symbol: "dot.radiowaves.left.and.right",
      accent: SoloTheme.cyan
    ) {
      if headlines.isEmpty {
        HStack(alignment: .top, spacing: 11) {
          ZStack {
            Circle()
              .stroke(SoloTheme.cyan.opacity(0.24), lineWidth: 1)
              .frame(width: 28, height: 28)
              .scaleEffect(idlePulse && !reduceMotion ? 1.12 : 1)
            Image(systemName: "waveform")
              .font(.caption2.weight(.bold))
              .foregroundStyle(SoloTheme.cyan)
          }
          VStack(alignment: .leading, spacing: 3) {
            Text("LIVE FEED STANDING BY")
              .font(.caption2.weight(.black))
              .foregroundStyle(SoloTheme.cyan)
            Text("Waiting for company activity")
              .font(.subheadline.weight(.semibold))
            Text("Your company moves will appear here as the sprint unfolds.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live feed standing by. Waiting for company activity. Your company moves will appear here as the sprint unfolds.")
        .task {
          guard !reduceMotion else { return }
          withAnimation(.smooth(duration: 0.45).repeatCount(2, autoreverses: true)) {
            idlePulse = true
          }
        }
      } else {
        VStack(spacing: 0) {
          ForEach(Array(headlines.enumerated()), id: \.element.id) { index, headline in
            TechComStoryRow(headline: headline, isLead: index == 0)
            if headline.id != headlines.last?.id {
              Divider().opacity(0.55)
            }
          }
        }
      }
    }
  }
}

struct TechComStoryRow: View {
  var headline: TechComHeadline
  var isLead: Bool

  private var storyLabel: String {
    if headline.text.localizedCaseInsensitiveContains("closes sprint") { return "SPRINT REPORT" }
    if headline.text.localizedCaseInsensitiveContains("verif") { return "REVIEWED" }
    if headline.text.localizedCaseInsensitiveContains("takes on") { return "ASSIGNED" }
    return "COMPANY WIRE"
  }

  private var symbol: String {
    if storyLabel == "SPRINT REPORT" { return "flag.checkered" }
    if storyLabel == "REVIEWED" { return "checkmark.seal.fill" }
    if storyLabel == "ASSIGNED" { return "arrow.forward.circle.fill" }
    return "newspaper.fill"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(isLead ? SoloTheme.cyan : .secondary)
        .frame(width: 24, height: 24)
        .background((isLead ? SoloTheme.cyan : Color.secondary).opacity(0.12), in: .circle)

      VStack(alignment: .leading, spacing: 5) {
        Text(storyLabel)
          .font(.caption2.weight(.black))
          .foregroundStyle(isLead ? SoloTheme.cyan : .secondary)
        Text(headline.text)
          .font(isLead ? .subheadline.weight(.bold) : .subheadline)
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 11)
    .transition(.move(edge: .top).combined(with: .opacity))
    .gameplayMotion(.emphasis, value: headline.id)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(storyLabel). \(headline.text)")
  }
}

struct TechComDecisionFeed: View {
  var store: GameStore
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TechComSectionHeader(
        eyebrow: "PUBLIC NARRATIVE",
        title: "Decision Feed",
        symbol: "megaphone.fill",
        accent: SoloTheme.coral
      )

      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 5) {
            statementStatus
            coverageStatus
          }
        } else {
          HStack(spacing: 8) {
            statementStatus
            Spacer()
            coverageStatus
          }
        }
      }
      .font(.caption.weight(.bold))
      .foregroundStyle(store.statementAvailable ? SoloTheme.cyan : .secondary)
      .gameplayMotion(.state, value: store.stats.coverage)

      ForEach(store.feedPosts) { post in
        TechComDecisionCard(store: store, post: post)
      }
    }
  }

  private var statementStatus: some View {
    Label(
      "Statement \(store.statementAvailable ? "available" : "spent")",
      systemImage: store.statementAvailable ? "quote.bubble.fill" : "quote.bubble"
    )
    .fixedSize(horizontal: false, vertical: true)
  }

  private var coverageStatus: some View {
    Text("Coverage \(store.stats.coverage >= 0 ? "+" : "")\(store.stats.coverage)")
      .contentTransition(.numericText(value: Double(store.stats.coverage)))
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct TechComDecisionCard: View {
  var store: GameStore
  var post: FeedPost
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var processingActionID: String?
  @State private var coverageBefore: Int?
  @State private var resolutionStage: DecisionResolutionStage = .idle
  @State private var feedbackTrigger = 0

  private var accent: Color {
    switch post.kind {
    case .pressInquiry: SoloTheme.coral
    case .rivalMove: SoloTheme.amber
    case .trendSignal: SoloTheme.cyan
    case .talentListing: SoloTheme.purple
    }
  }

  private var label: String {
    switch post.kind {
    case .pressInquiry: "PRESS INQUIRY"
    case .rivalMove: "COMPETITOR MOVE"
    case .trendSignal: "TREND SIGNAL"
    case .talentListing: "TALENT WATCH"
    }
  }

  private var symbol: String {
    switch post.kind {
    case .pressInquiry: "newspaper.fill"
    case .rivalMove: "scope"
    case .trendSignal: "waveform.path.ecg"
    case .talentListing: "person.crop.circle.badge.plus"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 9) {
      Label(label, systemImage: symbol)
        .font(.caption2.weight(.black))
        .foregroundStyle(accent)

      Text(post.headline)
        .font(.headline)
        .foregroundStyle(.primary)
      Text(post.body)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let processingActionID,
         let action = post.actions.first(where: { $0.id == processingActionID }),
         resolutionStage == .publishing {
        Label(
          post.kind == .pressInquiry ? "PUBLISHING RESPONSE…" : "PROCESSING DECISION…",
          systemImage: "ellipsis"
        )
        .font(.caption.weight(.black))
        .foregroundStyle(accent)
        .transition(.opacity)
        .accessibilityLabel("Processing \(action.label)")
      } else if let resolvedID = post.resolvedActionID,
                resolutionStage == .result || processingActionID == nil,
                let action = post.actions.first(where: { $0.id == resolvedID }) {
        VStack(alignment: .leading, spacing: 7) {
          Label(
            post.kind == .pressInquiry ? "STATEMENT PUBLISHED" : "DECISION RECORDED",
            systemImage: "checkmark.seal.fill"
          )
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.mint)
          Text(action.label)
            .font(.subheadline.weight(.semibold))
          if let coverageBefore, action.coverageDelta != 0 {
            Text("Coverage \(signed(coverageBefore)) → \(signed(store.stats.coverage))")
              .font(.caption.monospacedDigit().weight(.bold))
              .foregroundStyle(action.coverageDelta > 0 ? SoloTheme.mint : SoloTheme.coral)
              .contentTransition(.numericText())
          }
        }
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
      } else if !post.actions.isEmpty {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 6) {
          Text("YOUR RESPONSE")
            .font(.caption2.weight(.black))
            .foregroundStyle(.secondary)
          ForEach(post.actions) { action in
            Button {
              resolve(action)
            } label: {
              HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(action.label).font(.subheadline.weight(.bold))
                  Text(action.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                  .font(.caption.bold())
                  .foregroundStyle(accent)
              }
              .padding(.horizontal, 11)
              .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 9)
              .frame(minHeight: 44)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(accent.opacity(0.09), in: .rect(cornerRadius: 12))
              .overlay {
                RoundedRectangle(cornerRadius: 12)
                  .stroke(accent.opacity(0.24), lineWidth: 1)
              }
            }
            .buttonStyle(SoloPressStyle(scale: 0.985))
            .disabled(action.requiresStatement && !store.statementAvailable)
            .opacity(processingActionID == nil || processingActionID == action.id ? 1 : 0.38)
            .overlay {
              if resolutionStage == .focused, processingActionID == action.id {
                RoundedRectangle(cornerRadius: 12)
                  .stroke(accent.opacity(0.72), lineWidth: 2)
              }
            }
            .accessibilityHint(action.detail)
          }
        }
        .transition(.opacity)
      }
    }
    .padding(dynamicTypeSize.isAccessibilitySize ? 16 : 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .overlay(alignment: .leading) {
      UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
        .fill(accent)
        .frame(width: 3)
    }
    .gameplayMotion(.emphasis, value: post.resolvedActionID)
    .sensoryFeedback(.success, trigger: feedbackTrigger)
    .accessibilityElement(children: .contain)
  }

  private func resolve(_ action: FeedAction) {
    guard post.resolvedActionID == nil, processingActionID == nil else { return }
    coverageBefore = store.stats.coverage
    processingActionID = action.id
    resolutionStage = reduceMotion ? .result : .focused
    store.resolveFeed(postID: post.id, actionID: action.id)
    guard !reduceMotion else {
      feedbackTrigger += 1
      return
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(90))
      withAnimation(SoloMotion.focus) { resolutionStage = .publishing }
      try? await Task.sleep(for: .milliseconds(240))
      withAnimation(SoloMotion.settle) { resolutionStage = .result }
      feedbackTrigger += 1
    }
  }

  private func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
  }
}

private enum DecisionResolutionStage {
  case idle
  case focused
  case publishing
  case result
}

struct TechComTrendSignal: View {
  var headlines: [TechComHeadline]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TechComSectionHeader(
        eyebrow: "SIGNAL WATCH",
        title: "Trends",
        symbol: "waveform.path.ecg",
        accent: SoloTheme.cyan
      )
      VStack(alignment: .leading, spacing: 12) {
        if headlines.isEmpty {
          Text("Industry watch is gathering signal.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
          ForEach(headlines) { headline in
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(SoloTheme.cyan)
              Text(headline.text)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Trend signal. \(headline.text)")
          }
        }
      }
      .padding(16)
      .background {
        RoundedRectangle(cornerRadius: 18)
          .fill(SoloTheme.cyan.opacity(0.055))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
          .foregroundStyle(SoloTheme.cyan.opacity(0.28))
      }
    }
  }
}

struct TechComRivalBoard: View {
  var store: GameStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TechComSectionHeader(
        eyebrow: "COMPETITIVE FIELD",
        title: "Rivals",
        symbol: "person.3.fill",
        accent: SoloTheme.amber
      )
      ForEach(store.techComRivals) { rival in
        TechComRivalCard(store: store, rival: rival)
      }
    }
  }
}

struct TechComRivalCard: View {
  var store: GameStore
  var rival: TechComRival
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var inspecting = false
  @State private var verificationVisible = true
  @State private var verificationSuccessTrigger = 0
  @State private var overclaimTrigger = 0

  private var archetype: RivalArchetype? {
    TechComPresentation.archetype(for: rival.id)
  }

  private var stateColor: Color {
    switch rival.verificationState {
    case .overclaimed, .driftDetected: SoloTheme.coral
    case .confirmed, .verified: SoloTheme.mint
    case .reported, .unverified, .evidenceIncomplete: SoloTheme.amber
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 11) {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 10) {
          rivalIdentity
          statusBadge
        }
      } else {
        HStack(alignment: .top, spacing: 12) {
          rivalIdentity
          statusBadge
        }
      }

      if inspecting && !verificationVisible {
        TechComVerificationScan(name: rival.name)
          .transition(.opacity)
      } else {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 9 : 7) {
          ForEach(TechComPresentation.rivalMetrics(for: rival)) { metric in
            TechComRivalMetricRow(metric: metric)
          }
        }
        .transition(.opacity)

        if rival.isVerified {
          VerificationImpact(
            state: rival.verificationState,
            active: verificationVisible,
            reduceMotion: reduceMotion
          )
          if rival.verificationState == .overclaimed {
            Label(
              "Track-record overclaim +\(rival.overclaimAmount)",
              systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(SoloTheme.coral)
          }
        } else {
          Button("Verify claim · 1 Attention", systemImage: "eye.fill") {
            verify()
          }
          .buttonStyle(.bordered)
          .tint(SoloTheme.purple)
          .disabled(store.attentionRemaining == 0)
          .accessibilityHint("Reveals all claimed rival metrics")
        }
      }
    }
    .padding(dynamicTypeSize.isAccessibilitySize ? 16 : 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(identityColor.opacity(0.055), in: .rect(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(identityColor.opacity(0.22), lineWidth: 1)
    }
    .gameplayMotion(.impact, value: rival.isVerified)
    .sensoryFeedback(.success, trigger: verificationSuccessTrigger)
    .sensoryFeedback(.warning, trigger: overclaimTrigger)
    .accessibilityElement(children: .contain)
  }

  private var identityColor: Color {
    companyIdentity.accent.color
  }

  private var companyIdentity: TechComCompanyIdentity {
    TechComPresentation.companyIdentity(
      id: rival.id,
      name: rival.name,
      archetype: archetype,
      isPlayer: false
    )
  }

  private var statusSymbol: String {
    switch rival.verificationState {
    case .reported, .unverified: "questionmark.diamond.fill"
    case .confirmed, .verified: "checkmark.seal.fill"
    case .overclaimed, .driftDetected: "exclamationmark.triangle.fill"
    case .evidenceIncomplete: "doc.questionmark.fill"
    }
  }

  private var rivalIdentity: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(companyIdentity.monogram)
        .font(.subheadline.weight(.black))
        .foregroundStyle(identityColor)
        .frame(
          minWidth: dynamicTypeSize.isAccessibilitySize ? 42 : 38,
          minHeight: dynamicTypeSize.isAccessibilitySize ? 42 : 38
        )
        .background(identityColor.opacity(0.14), in: .rect(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(identityColor.opacity(0.35), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 3) {
        Text(rival.name.uppercased())
          .font(.headline.weight(.black))
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
          .minimumScaleFactor(0.85)
        if let archetype {
          Text(archetype.label.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var statusBadge: some View {
    Label(rival.verificationState.label.uppercased(), systemImage: statusSymbol)
      .font(.caption2.weight(.black))
      .foregroundStyle(stateColor)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func verify() {
    guard !rival.isVerified, !inspecting else { return }
    inspecting = true
    verificationVisible = reduceMotion
    guard store.verifyTechComRival(id: rival.id) else {
      inspecting = false
      return
    }
    guard !reduceMotion else {
      completeVerificationFeedback()
      return
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(380))
      withAnimation(SoloMotion.settle) { verificationVisible = true }
      completeVerificationFeedback()
    }
  }

  private func completeVerificationFeedback() {
    if rival.verificationState == .overclaimed {
      overclaimTrigger += 1
    } else {
      verificationSuccessTrigger += 1
    }
  }
}

struct TechComRivalMetricRow: View {
  var metric: TechComRivalMetric

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(metric.title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      if let actualValue = metric.actualValue {
        Text(formatted(metric.claimedValue))
          .strikethrough()
          .foregroundStyle(.secondary)
        Image(systemName: "arrow.right")
          .font(.caption2.bold())
          .foregroundStyle(SoloTheme.purple)
        Text(formatted(actualValue))
          .fontWeight(.black)
          .foregroundStyle(.primary)
          .contentTransition(.numericText(value: Double(actualValue)))
      } else {
        Text(formatted(metric.claimedValue))
          .fontWeight(.bold)
          .foregroundStyle(.primary)
      }
    }
    .font(.subheadline.monospacedDigit())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    if let actualValue = metric.actualValue {
      return "\(metric.title), claimed \(formatted(metric.claimedValue)), verified \(formatted(actualValue))"
    }
    return "\(metric.title), claimed \(formatted(metric.claimedValue)), unverified"
  }

  private func formatted(_ value: Int) -> String {
    metric.isCurrency ? "$\(value.formatted())" : value.formatted()
  }
}

struct TechComVerificationScan: View {
  var name: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var scanOffset: CGFloat = -1

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(SoloTheme.purple.opacity(0.08))
          .frame(height: 50)
        Rectangle()
          .fill(SoloTheme.purple.opacity(0.75))
          .frame(height: 2)
          .offset(y: reduceMotion ? 0 : scanOffset * 20)
      }
      .clipShape(.rect(cornerRadius: 12))
      Label("CHECKING CLAIMS…", systemImage: "viewfinder")
        .font(.caption.weight(.black))
        .foregroundStyle(SoloTheme.purple)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Checking \(name) claims")
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.smooth(duration: 0.34)) { scanOffset = 1 }
    }
  }
}

struct TechComTalentBoard: View {
  var store: GameStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TechComSectionHeader(
        eyebrow: "FOUNDER NETWORK",
        title: "Talent Board",
        symbol: "person.crop.circle.badge.plus",
        accent: SoloTheme.purple
      )

      if let gate = store.talentBoardGateMessage {
        TechComLockedTalentPreview(message: gate)
      } else {
        unlockedBoard
      }
    }
  }

  private var unlockedBoard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Hire your \(store.nextTalentSlot == 4 ? "fourth" : "fifth") AI teammate. Different model families reduce shared exposure.")
        .font(.caption)
        .foregroundStyle(.secondary)
      ForEach(store.talentBoardCandidates) { candidate in
        VStack(alignment: .leading, spacing: 7) {
          HStack {
            Label(candidate.name, systemImage: candidate.role.symbol)
              .font(.subheadline.weight(.bold))
            Spacer()
            Text("$\(store.talentPrice(candidate))")
              .font(.caption.monospacedDigit().weight(.black))
              .foregroundStyle(SoloTheme.cyan)
          }
          Text("\(candidate.role.rawValue) · \(candidate.modelFamily)")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(candidate.pitch).font(.caption)
          Button("Hire \(candidate.name)", systemImage: "person.badge.plus") {
            store.hire(candidate)
          }
          .buttonStyle(.borderedProminent)
          .tint(SoloTheme.purple)
          .disabled(store.stats.capital < store.talentPrice(candidate))
        }
        .padding(14)
        .background(SoloTheme.purple.opacity(0.07), in: .rect(cornerRadius: 15))
      }
      if store.agents.count >= 4 {
        Button("Refresh listings · $\(TalentBoard.refreshCost)", systemImage: "arrow.clockwise") {
          store.refreshTalentBoard()
        }
        .buttonStyle(.bordered)
        .disabled(store.stats.capital < TalentBoard.refreshCost)
      }
    }
    .padding(16)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
  }
}

struct TechComLockedTalentPreview: View {
  var message: String

  var body: some View {
    ZStack {
      VStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { index in
          HStack(spacing: 10) {
            Circle()
              .fill(Color.secondary.opacity(0.12))
              .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
              Capsule().fill(Color.secondary.opacity(0.12)).frame(width: index == 1 ? 105 : 84, height: 7)
              Capsule().fill(Color.secondary.opacity(0.08)).frame(width: 145, height: 6)
            }
            Spacer()
            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(Color.white.opacity(0.025), in: .rect(cornerRadius: 12))
        }
      }
      .accessibilityHidden(true)

      VStack(spacing: 6) {
        Image(systemName: "lock.shield.fill")
          .font(.title3)
          .foregroundStyle(SoloTheme.purple)
        Text("TALENT DOSSIERS LOCKED")
          .font(.caption.weight(.black))
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(12)
      .background(.ultraThinMaterial, in: .rect(cornerRadius: 15))
    }
    .padding(11)
    .background(SoloTheme.purple.opacity(0.055), in: .rect(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(SoloTheme.purple.opacity(0.24), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Talent Board locked. \(message)")
  }
}

struct TechComRankingBoard: View {
  @Binding var metric: TechComRankingMetric
  var snapshot: TechComSnapshot
  var rivals: [TechComRival]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var observedMetric: TechComRankingMetric?
  @State private var movementByID: [String: String] = [:]
  @State private var emphasizedID: String?
  @State private var movementGeneration = 0
  @State private var rankImprovementTrigger = 0

  private var entries: [TechComRankingEntry] {
    TechComEngine.rankings(snapshot: snapshot, rivals: rivals, metric: metric)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TechComSectionHeader(
        eyebrow: "COMPETITIVE LADDER",
        title: "Rankings",
        symbol: "list.number",
        accent: SoloTheme.cyan
      )
      VStack(spacing: 12) {
        Picker("Ranking metric", selection: $metric) {
          ForEach(TechComRankingMetric.allCases) { rankingMetric in
            Text(rankingMetric.rawValue).tag(rankingMetric)
          }
        }
        .pickerStyle(.segmented)

        VStack(spacing: 6) {
          ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            rankingRow(entry, rank: index + 1, index: index)
          }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.30), value: entries.map(\.id))
      }
      .padding(14)
      .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    }
    .onAppear { observedMetric = metric }
    .onChange(of: entries) { oldEntries, newEntries in
      handleRankingChange(from: oldEntries, to: newEntries)
    }
    .sensoryFeedback(.success, trigger: rankImprovementTrigger)
  }

  private func rankingRow(_ entry: TechComRankingEntry, rank: Int, index: Int) -> some View {
    let identity = TechComPresentation.companyIdentity(
      id: entry.id,
      name: entry.name,
      archetype: TechComPresentation.archetype(for: entry.id),
      isPlayer: entry.isPlayer
    )
    return HStack(spacing: 11) {
      Text("\(rank)")
        .font(.headline.monospacedDigit().weight(.black))
        .foregroundStyle(entry.isPlayer ? SoloTheme.cyan : .secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Circle()
            .fill(identity.accent.color)
            .frame(width: entry.isPlayer ? 8 : 6, height: entry.isPlayer ? 8 : 6)
            .accessibilityHidden(true)
          Text(entry.name)
            .font(.subheadline.weight(entry.isPlayer ? .black : .semibold))
          if entry.isPlayer {
            Text("YOU")
              .font(.caption2.weight(.black))
              .foregroundStyle(SoloTheme.cyan)
          }
        }
        if entry.isPlayer,
           let gap = TechComPresentation.gapToNextRank(entries: entries, playerIndex: index) {
          Text("\(formatted(gap)) behind")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        if let movement = movementByID[entry.id] {
          Text(movement)
            .font(.caption2.monospacedDigit().weight(.black))
            .foregroundStyle(entry.isPlayer ? SoloTheme.cyan : identity.accent.color)
            .transition(.opacity)
            .accessibilityLabel("Rank changed \(movement)")
        }
      }
      Spacer()
      Text(formatted(entry.value))
        .font(.subheadline.monospacedDigit().weight(.bold))
        .foregroundStyle(entry.isPlayer ? SoloTheme.cyan : .primary)
        .contentTransition(.numericText(value: Double(entry.value)))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 9)
    .background(entry.isPlayer ? SoloTheme.cyan.opacity(0.10) : Color.clear, in: .rect(cornerRadius: 12))
    .overlay {
      if emphasizedID == entry.id {
        RoundedRectangle(cornerRadius: 12)
          .stroke(identity.accent.color.opacity(0.55), lineWidth: 1)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(rankingAccessibility(entry, rank: rank, index: index))
  }

  private func rankingAccessibility(_ entry: TechComRankingEntry, rank: Int, index: Int) -> String {
    var text = "Rank \(rank), \(entry.name), \(formatted(entry.value))"
    if entry.isPlayer, let gap = TechComPresentation.gapToNextRank(entries: entries, playerIndex: index) {
      text += ", \(formatted(gap)) behind the next rank"
    }
    return text
  }

  private func formatted(_ value: Int) -> String {
    metric == .revenue ? "$\(value.formatted())" : value.formatted()
  }

  private func handleRankingChange(
    from oldEntries: [TechComRankingEntry],
    to newEntries: [TechComRankingEntry]
  ) {
    guard observedMetric == metric else {
      observedMetric = metric
      movementByID = [:]
      emphasizedID = nil
      return
    }
    let oldRanks = Dictionary(uniqueKeysWithValues: oldEntries.enumerated().map { ($0.element.id, $0.offset + 1) })
    let newRanks = Dictionary(uniqueKeysWithValues: newEntries.enumerated().map { ($0.element.id, $0.offset + 1) })
    let changes = newEntries.compactMap { entry -> (String, Int, Int)? in
      guard let oldRank = oldRanks[entry.id], let newRank = newRanks[entry.id], oldRank != newRank else { return nil }
      return (entry.id, oldRank, newRank)
    }
    guard !changes.isEmpty else { return }

    movementByID = Dictionary(uniqueKeysWithValues: changes.map { change in
      (change.0, "#\(change.1) → #\(change.2)")
    })
    let soloChange = changes.first { $0.0 == "solo" }
    emphasizedID = soloChange?.0 ?? changes.first?.0
    if let soloChange, soloChange.2 < soloChange.1 {
      rankImprovementTrigger += 1
    }
    movementGeneration += 1
    let generation = movementGeneration
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(900))
      guard generation == movementGeneration else { return }
      withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
        movementByID = [:]
        emphasizedID = nil
      }
    }
  }
}

struct TechComMarketShareBoard: View {
  var standings: [RivalStanding]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TechComSectionHeader(
        eyebrow: "CATEGORY CONTROL",
        title: "Market Share",
        symbol: "chart.bar.fill",
        accent: SoloTheme.mint
      )
      VStack(spacing: 15) {
        ForEach(standings) { standing in
          TechComMarketShareRow(standing: standing)
        }
      }
      .padding(16)
      .background(SoloTheme.card, in: .rect(cornerRadius: 18))
      .animation(reduceMotion ? nil : .smooth(duration: 0.30), value: standings.map(\.id))
    }
  }
}

struct TechComMarketShareRow: View {
  var standing: RivalStanding
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var displayedShare: Double

  init(standing: RivalStanding) {
    self.standing = standing
    _displayedShare = State(
      initialValue: TechComPresentation.marketBarFraction(standing.marketShare)
    )
  }

  private var identity: TechComCompanyIdentity {
    TechComPresentation.companyIdentity(
      id: standing.id,
      name: standing.name,
      archetype: standing.archetype,
      isPlayer: standing.isPlayer
    )
  }

  private var accent: Color {
    identity.accent.color
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .firstTextBaseline) {
            identityMarker
            companyName
            Spacer(minLength: 8)
            marketPercentage
          }
          companyType
        }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          identityMarker
          companyName
          companyType.lineLimit(1)
          Spacer(minLength: 8)
          marketPercentage
        }
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.secondary.opacity(contrast == .increased ? 0.25 : 0.12))
          Capsule()
            .fill(accent.gradient)
            .frame(width: proxy.size.width * displayedShare)
        }
      }
      .frame(height: standing.isPlayer ? 10 : 7)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(standing.name), \(standing.archetype?.label ?? "your company"), "
        + standing.marketShare.formatted(.percent.precision(.fractionLength(0)))
        + " market share"
    )
    .transaction { transaction in
      if reduceMotion { transaction.animation = nil }
    }
    .onChange(of: standing.marketShare) { _, _ in updateShare() }
  }

  private func updateShare() {
    let share = TechComPresentation.marketBarFraction(standing.marketShare)
    guard !reduceMotion else {
      displayedShare = share
      return
    }
    withAnimation(.smooth(duration: 0.32)) {
      displayedShare = share
    }
  }

  private var companyName: some View {
    Text(standing.name)
      .font(.subheadline.weight(standing.isPlayer ? .black : .semibold))
  }

  private var identityMarker: some View {
    Text(identity.monogram)
      .font(.system(size: 8, weight: .black, design: .rounded))
      .foregroundStyle(accent)
      .frame(width: 20, height: 20)
      .background(accent.opacity(0.12), in: .rect(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .stroke(accent.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1)
      }
      .accessibilityHidden(true)
  }

  private var companyType: some View {
    Text(standing.archetype?.label ?? "Your company")
      .font(.caption2)
      .foregroundStyle(.secondary)
  }

  private var marketPercentage: some View {
    Text(standing.marketShare, format: .percent.precision(.fractionLength(0)))
      .font(.subheadline.monospacedDigit().weight(.black))
      .foregroundStyle(standing.isPlayer ? SoloTheme.cyan : .primary)
      .contentTransition(.numericText(value: standing.marketShare))
  }
}

private extension TechComCompanyAccent {
  var color: Color {
    switch self {
    case .solo: SoloTheme.cyan
    case .incumbent: .indigo
    case .upstart: SoloTheme.cyan
    case .hypeMachine: SoloTheme.coral
    case .quietBuilder: SoloTheme.mint
    case .copycat: SoloTheme.purple
    case .neutral: .secondary
    }
  }
}

struct TechComSectionHeader: View {
  var eyebrow: String
  var title: String
  var symbol: String
  var accent: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(accent)
        .frame(width: 30, height: 30)
        .background(accent.opacity(0.12), in: .rect(cornerRadius: 9))
      VStack(alignment: .leading, spacing: 1) {
        Text(eyebrow)
          .font(.caption2.weight(.black))
          .foregroundStyle(accent)
        Text(title)
          .font(.title3.weight(.bold))
          .foregroundStyle(.primary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct TechComEditorialSurface<Content: View>: View {
  var eyebrow: String
  var title: String
  var symbol: String
  var accent: Color
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TechComSectionHeader(eyebrow: eyebrow, title: title, symbol: symbol, accent: accent)
      VStack(alignment: .leading, spacing: 0) { content }
        .padding(.horizontal, 16)
        .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    }
  }
}
