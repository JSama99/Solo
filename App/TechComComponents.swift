import SwiftUI

struct TechComMasthead: View {
  var venture: Int
  var sprint: Int
  var marketPosition: Int?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var live = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
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
      .padding(.top, 10)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(SoloTheme.cyan.opacity(contrast == .increased ? 0.8 : 0.35))
          .frame(height: contrast == .increased ? 2 : 1)
      }
    }
    .padding(18)
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

  var body: some View {
    TechComEditorialSurface(
      eyebrow: "YOUR COMPANY",
      title: "Live company activity",
      symbol: "dot.radiowaves.left.and.right",
      accent: SoloTheme.cyan
    ) {
      if headlines.isEmpty {
        Text("Your company moves will appear here as the sprint unfolds.")
          .font(.caption)
          .foregroundStyle(.secondary)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TechComSectionHeader(
        eyebrow: "PUBLIC NARRATIVE",
        title: "Decision Feed",
        symbol: "megaphone.fill",
        accent: SoloTheme.coral
      )

      HStack(spacing: 8) {
        Label(
          "Statement \(store.statementAvailable ? "available" : "spent")",
          systemImage: store.statementAvailable ? "quote.bubble.fill" : "quote.bubble"
        )
        Spacer()
        Text("Coverage \(store.stats.coverage >= 0 ? "+" : "")\(store.stats.coverage)")
          .contentTransition(.numericText(value: Double(store.stats.coverage)))
      }
      .font(.caption.weight(.bold))
      .foregroundStyle(store.statementAvailable ? SoloTheme.cyan : .secondary)
      .gameplayMotion(.state, value: store.stats.coverage)

      ForEach(store.feedPosts) { post in
        TechComDecisionCard(store: store, post: post)
      }
    }
  }
}

struct TechComDecisionCard: View {
  var store: GameStore
  var post: FeedPost
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var processingActionID: String?
  @State private var coverageBefore: Int?
  @State private var resolutionVisible = true
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
    VStack(alignment: .leading, spacing: 12) {
      Label(label, systemImage: symbol)
        .font(.caption2.weight(.black))
        .foregroundStyle(accent)

      Text(post.headline)
        .font(.headline)
        .foregroundStyle(.primary)
      Text(post.body)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let processingActionID, let action = post.actions.first(where: { $0.id == processingActionID }), !resolutionVisible {
        Label(
          post.kind == .pressInquiry ? "PUBLISHING RESPONSE…" : "PROCESSING DECISION…",
          systemImage: "ellipsis"
        )
        .font(.caption.weight(.black))
        .foregroundStyle(accent)
        .transition(.opacity)
        .accessibilityLabel("Processing \(action.label)")
      } else if let resolvedID = post.resolvedActionID,
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
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
      } else if !post.actions.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
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
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(accent.opacity(0.09), in: .rect(cornerRadius: 12))
              .overlay {
                RoundedRectangle(cornerRadius: 12)
                  .stroke(accent.opacity(0.24), lineWidth: 1)
              }
            }
            .buttonStyle(SoloPressStyle(scale: 0.985))
            .disabled(action.requiresStatement && !store.statementAvailable)
            .accessibilityHint(action.detail)
          }
        }
        .transition(.opacity)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .overlay(alignment: .leading) {
      UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
        .fill(accent)
        .frame(width: 3)
    }
    .gameplayMotion(.emphasis, value: post.resolvedActionID)
    .sensoryFeedback(.selection, trigger: feedbackTrigger)
    .accessibilityElement(children: .contain)
  }

  private func resolve(_ action: FeedAction) {
    guard post.resolvedActionID == nil, processingActionID == nil else { return }
    coverageBefore = store.stats.coverage
    processingActionID = action.id
    resolutionVisible = reduceMotion
    feedbackTrigger += 1
    store.resolveFeed(postID: post.id, actionID: action.id)
    guard !reduceMotion else { return }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(260))
      withAnimation(SoloMotion.settle) { resolutionVisible = true }
    }
  }

  private func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
  }
}

struct TechComTrendSignal: View {
  var headlines: [TechComHeadline]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
    VStack(alignment: .leading, spacing: 12) {
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
    VStack(alignment: .leading, spacing: 14) {
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
        VStack(spacing: 9) {
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
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(identityColor.opacity(0.055), in: .rect(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(identityColor.opacity(0.22), lineWidth: 1)
    }
    .gameplayMotion(.impact, value: rival.isVerified)
    .accessibilityElement(children: .contain)
  }

  private var identityColor: Color {
    switch archetype {
    case .incumbent: .indigo
    case .upstart: SoloTheme.cyan
    case .hypeMachine: SoloTheme.coral
    case .quietBuilder: SoloTheme.mint
    case .copycat: SoloTheme.purple
    case nil: SoloTheme.cyan
    }
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
      Text(TechComPresentation.monogram(for: rival.name))
        .font(.subheadline.weight(.black))
        .foregroundStyle(identityColor)
        .frame(minWidth: 42, minHeight: 42)
        .background(identityColor.opacity(0.14), in: .rect(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(identityColor.opacity(0.35), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 3) {
        Text(rival.name.uppercased())
          .font(.headline.weight(.black))
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
    guard store.verifyTechComRival(id: rival.id), !reduceMotion else { return }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(420))
      withAnimation(SoloMotion.impact) { verificationVisible = true }
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
    VStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(SoloTheme.purple.opacity(0.08))
          .frame(height: 58)
        Rectangle()
          .fill(SoloTheme.purple.opacity(0.75))
          .frame(height: 2)
          .offset(y: reduceMotion ? 0 : scanOffset * 24)
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
      withAnimation(.smooth(duration: 0.38)) { scanOffset = 1 }
    }
  }
}

struct TechComTalentBoard: View {
  var store: GameStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
      VStack(spacing: 9) {
        ForEach(0..<3, id: \.self) { index in
          HStack(spacing: 10) {
            Circle()
              .fill(Color.secondary.opacity(0.12))
              .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 5) {
              Capsule().fill(Color.secondary.opacity(0.12)).frame(width: index == 1 ? 105 : 84, height: 7)
              Capsule().fill(Color.secondary.opacity(0.08)).frame(width: 145, height: 6)
            }
            Spacer()
            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
          }
          .padding(11)
          .background(Color.white.opacity(0.025), in: .rect(cornerRadius: 12))
        }
      }
      .accessibilityHidden(true)

      VStack(spacing: 8) {
        Image(systemName: "lock.shield.fill")
          .font(.title2)
          .foregroundStyle(SoloTheme.purple)
        Text("TALENT DOSSIERS LOCKED")
          .font(.caption.weight(.black))
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(16)
      .background(.ultraThinMaterial, in: .rect(cornerRadius: 15))
    }
    .padding(14)
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

  private var entries: [TechComRankingEntry] {
    TechComEngine.rankings(snapshot: snapshot, rivals: rivals, metric: metric)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
        .animation(reduceMotion ? nil : MotionKind.state.animation, value: entries.map(\.id))
      }
      .padding(14)
      .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    }
  }

  private func rankingRow(_ entry: TechComRankingEntry, rank: Int, index: Int) -> some View {
    HStack(spacing: 11) {
      Text("\(rank)")
        .font(.headline.monospacedDigit().weight(.black))
        .foregroundStyle(entry.isPlayer ? SoloTheme.cyan : .secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        HStack {
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
}

struct TechComMarketShareBoard: View {
  var standings: [RivalStanding]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
    }
  }
}

struct TechComMarketShareRow: View {
  var standing: RivalStanding
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var displayedShare = 0.0

  private var accent: Color {
    standing.isPlayer ? SoloTheme.cyan : SoloTheme.mint
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .firstTextBaseline) {
            companyName
            Spacer(minLength: 8)
            marketPercentage
          }
          companyType
        }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          companyName
          companyType.lineLimit(1)
          Spacer(minLength: 8)
          marketPercentage
        }
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.secondary.opacity(0.12))
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
    .onAppear { updateShare(initial: true) }
    .onChange(of: standing.marketShare) { _, _ in updateShare(initial: false) }
  }

  private func updateShare(initial: Bool) {
    let share = TechComPresentation.marketBarFraction(standing.marketShare)
    guard !reduceMotion else {
      displayedShare = share
      return
    }
    withAnimation(initial ? SoloMotion.arrival : MotionKind.state.animation) {
      displayedShare = share
    }
  }

  private var companyName: some View {
    Text(standing.name)
      .font(.subheadline.weight(standing.isPlayer ? .black : .semibold))
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
