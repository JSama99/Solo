import SwiftUI

struct ContentView: View {
  @State private var store = GameStore()

  var body: some View {
    ZStack {
      SoloTheme.background.ignoresSafeArea()
      switch store.stage {
      case .title:
        TitleScreen(store: store)
          .transition(.opacity.combined(with: .scale(scale: 0.97)))
      case .setup:
        FounderSetupScreen(store: store)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      case .game:
        GameDashboard(store: store)
          .transition(.opacity)
      case .outcome:
        CareerOutcomeScreen(store: store)
          .transition(.opacity.combined(with: .scale(scale: 0.97)))
      }
    }
    .animation(.smooth, value: store.stage)
    .alert("Garage Console", isPresented: Binding(
      get: { store.alertMessage != nil },
      set: { if !$0 { store.alertMessage = nil } }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(store.alertMessage ?? "")
    }
  }
}

private struct TitleScreen: View {
  var store: GameStore
  @Environment(FounderProgressionStore.self) private var progression

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        Spacer(minLength: 52)
        ZStack {
          Circle()
            .fill(SoloTheme.purple.opacity(0.2))
            .frame(width: 180, height: 180)
            .blur(radius: 16)
          Image(systemName: "sparkles")
            .font(.system(size: 78, weight: .black))
            .foregroundStyle(SoloTheme.cyan)
            .shadow(color: SoloTheme.cyan.opacity(0.7), radius: 18)
        }
        VStack(spacing: 8) {
          Text("SOLO:")
            .font(.system(size: 50, weight: .black, design: .rounded))
          Text("UNICORN RUN")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .tracking(6)
            .foregroundStyle(SoloTheme.cyan)
          Text("A founder-life simulation")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        Text("Build a company from a garage, direct an AI workforce, and survive the decisions you made.")
          .font(.title3.weight(.medium))
          .multilineTextAlignment(.center)
          .foregroundStyle(.white.opacity(0.85))
          .padding(.horizontal, 24)
        VStack(spacing: 12) {
          Button("Start New Career", systemImage: "play.fill") {
            store.beginSetup()
          }
          .buttonStyle(SoloPrimaryButtonStyle())

          if store.hasSave {
            Button("Continue Career", systemImage: "arrow.right.circle.fill") {
              store.continueCareer()
              progression.ensureCareerIdentity()
              progression.observe(trackRecord: store.stats.trackRecord)
              if store.careerOutcome != nil {
                progression.recordCareerCompletion(trackRecord: store.stats.trackRecord)
              }
            }
            .buttonStyle(SoloSecondaryButtonStyle())
          }
        }
        .padding(.horizontal, 24)
        Text("Native iOS edition • offline save • RevenueCat Test Store")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Spacer(minLength: 32)
      }
      .frame(maxWidth: .infinity)
    }
  }
}

private struct FounderSetupScreen: View {
  @Bindable var store: GameStore
  @Environment(FounderProgressionStore.self) private var progression

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 6) {
            Text("CAREER SETUP")
              .font(.caption.weight(.black))
              .tracking(2)
              .foregroundStyle(SoloTheme.cyan)
            Text("Create your founder")
              .font(.largeTitle.bold())
            Text("Your doctrine changes how the same decisions behave. None is universally correct.")
              .foregroundStyle(.secondary)
          }

          TextField("Founder name", text: $store.founderName)
            .textInputAutocapitalization(.words)
            .padding(16)
            .background(SoloTheme.card, in: .rect(cornerRadius: 16))
            .accessibilityLabel("Founder name")

          VStack(spacing: 12) {
            ForEach(FounderDoctrine.allCases) { doctrine in
              Button {
                withAnimation(.snappy) { store.selectedDoctrine = doctrine }
              } label: {
                DoctrineCard(
                  doctrine: doctrine,
                  isSelected: store.selectedDoctrine == doctrine
                )
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(store.selectedDoctrine == doctrine ? .isSelected : [])
            }
          }

          Button("Open the Garage", systemImage: "door.garage.open") {
            progression.beginCareer()
            store.startCareer()
          }
          .buttonStyle(SoloPrimaryButtonStyle())
          .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back", systemImage: "chevron.left") {
            store.stage = .title
          }
          .labelStyle(.iconOnly)
        }
      }
    }
  }
}

private struct DoctrineCard: View {
  var doctrine: FounderDoctrine
  var isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(doctrine.name).font(.headline)
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? SoloTheme.cyan : .secondary)
      }
      Text(doctrine.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      HStack(spacing: 8) {
        Text(doctrine.perk).foregroundStyle(SoloTheme.mint)
        Text("•")
        Text(doctrine.risk).foregroundStyle(SoloTheme.amber)
      }
      .font(.caption.weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(isSelected ? SoloTheme.purple.opacity(0.18) : SoloTheme.card)
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(isSelected ? SoloTheme.cyan : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
    }
    .clipShape(.rect(cornerRadius: 18))
  }
}

private struct GameDashboard: View {
  var store: GameStore
  @Environment(FounderProgressionStore.self) private var progression
  @State private var presentation = PresentationCoordinator()

  var body: some View {
    TabView {
      Tab("Garage", systemImage: "house.fill") {
        FounderEnvironmentScreen(store: store, presentation: presentation)
      }
      Tab("Assign", systemImage: "slider.horizontal.3") {
        CommandScreen(store: store, presentation: presentation)
      }
      Tab("Venture", systemImage: "chart.line.uptrend.xyaxis") {
        VentureScreen(store: store)
      }
      Tab("More", systemImage: "ellipsis") {
        RecordsScreen(store: store)
      }
    }
    .tint(SoloTheme.cyan)
    .sheet(item: Binding(
      get: { store.report },
      set: { newValue in
        if let newValue {
          store.report = newValue
        } else {
          store.finishReport()
          presentation.clearSprintPresentation()
        }
      }
    )) { report in
      SprintReportSheet(report: report, visibleReport: presentation.visibleSprintResult) {
        store.finishReport()
        presentation.clearSprintPresentation()
      }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
  }
}

private struct StatsStrip: View {
  var stats: FounderStats

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        StatChip(label: "Runway", value: "\(stats.runway)d", symbol: "calendar")
        StatChip(label: "Revenue", value: stats.revenue.formatted(.currency(code: "USD").precision(.fractionLength(0))), symbol: "dollarsign")
        StatChip(label: "Momentum", value: "\(stats.momentum)", symbol: "bolt.fill")
        StatChip(label: "Trust", value: "\(stats.trust)", symbol: "checkmark.shield.fill")
        StatChip(label: "Energy", value: "\(stats.energy)", symbol: "battery.75percent")
      }
    }
    .scrollIndicators(.hidden)
  }
}

private struct StatChip: View {
  var label: String
  var value: String
  var symbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Label(label, systemImage: symbol)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value).font(.headline.monospacedDigit())
        .contentTransition(.numericText())
        .animation(.snappy, value: value)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(SoloTheme.card, in: .rect(cornerRadius: 12))
  }
}

private struct AgentRow: View {
  var agent: SoloAgent

  var body: some View {
    HStack(spacing: 12) {
      Text(agent.initials)
        .font(.caption.weight(.black))
        .frame(width: 44, height: 44)
        .background(SoloTheme.purple.gradient, in: .circle)
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(agent.name).font(.headline)
          Text(agent.role.rawValue).font(.caption).foregroundStyle(.secondary)
        }
        Text(agent.assignment == nil ? "Ready" : "Working • \(agent.modelFamily)")
          .font(.caption)
          .foregroundStyle(agent.assignment == nil ? .secondary : SoloTheme.cyan)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(agent.trustLabel).font(.caption.weight(.bold))
        Text("Drift \(Int(agent.drift))").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

private struct CommandScreen: View {
  @Bindable var store: GameStore
  var presentation: PresentationCoordinator
  @Environment(FounderProgressionStore.self) private var progression

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text("SPRINT COMMAND")
              .font(.caption.weight(.black))
              .tracking(2)
              .foregroundStyle(SoloTheme.cyan)
            Text("Choose what matters, direct the workforce, then commit the day.")
              .foregroundStyle(.secondary)
          }

          Picker("Sprint intent", selection: Binding(
            get: { store.intent },
            set: { store.setIntent($0) }
          )) {
            ForEach(SprintIntent.allCases) { intent in
              Label(intent.name, systemImage: intent.symbol).tag(intent)
            }
          }
          .pickerStyle(.segmented)
          .disabled(store.tasks.contains { $0.assignedAgentID != nil })

          if store.tasks.contains(where: { $0.assignedAgentID != nil }) {
            Text("Clear all assignments to change sprint intent.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          HStack {
            Text(store.intent.summary).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Label("\(store.attentionRemaining)/\(store.attentionMaximum)", systemImage: "eye.fill")
              .font(.caption.weight(.bold))
              .foregroundStyle(SoloTheme.amber)
          }

          ForEach(store.tasks) { task in
            TaskCommandCard(
              task: task,
              agents: store.agents
            ) { agentID in
              presentation.assign(agentID: agentID, to: task.id, in: store)
            } onReview: {
              presentation.review(taskID: task.id, in: store)
            }
          }

          Button("Commit Sprint", systemImage: "bolt.fill") {
            presentation.commit(in: store, progression: progression)
          }
          .buttonStyle(SoloPrimaryButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Assign")
    }
  }
}

private struct TaskCommandCard: View {
  var task: SoloTask
  var agents: [SoloAgent]
  var onAssign: (String?) -> Void
  var onReview: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Image(systemName: task.role.symbol)
          .foregroundStyle(SoloTheme.cyan)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 3) {
          Text(task.title).font(.headline)
          Text(task.detail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
      }

      Picker("Assign agent", selection: Binding(
        get: { task.assignedAgentID },
        set: onAssign
      )) {
        Text("Unassigned").tag(String?.none)
        ForEach(agents) { agent in
          Text("\(agent.name) • \(agent.role.rawValue)").tag(String?.some(agent.id))
        }
      }
      .pickerStyle(.menu)
      .buttonStyle(.bordered)

      if let result = task.result {
        VStack(alignment: .leading, spacing: 7) {
          HStack {
            Label("Reported \(result.reportedQuality)", systemImage: "doc.text.magnifyingglass")
              .foregroundStyle(SoloTheme.cyan)
            Spacer()
            Text(result.verificationState.label)
              .foregroundStyle(task.isReviewed ? SoloTheme.mint : SoloTheme.amber)
          }
          HStack {
            Text("Evidence \(result.evidenceCompleteness)%")
            Spacer()
            Text("Confidence \(result.confidenceRangeLabel)")
          }
          Text(result.knownOperationalRisk)
          if let actualQuality = result.revealedActualQuality {
            Divider()
            HStack {
              Label("Verified actual \(actualQuality)", systemImage: "checkmark.seal.fill")
                .foregroundStyle(SoloTheme.mint)
              Spacer()
              if result.overclaimAmount > 0 {
                Text("Overclaim +\(result.overclaimAmount)")
                  .foregroundStyle(SoloTheme.amber)
              }
            }
          }
        }
        .font(.caption.weight(.semibold))
        .accessibilityElement(children: .combine)
      } else {
        Label("Assign an agent to request a report", systemImage: "chart.bar.doc.horizontal")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack {
        Text("Base \(task.reward)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(SoloTheme.mint)
        Spacer()
        Button(task.isReviewed ? "Reviewed" : "Founder Review", systemImage: task.isReviewed ? "checkmark.seal.fill" : "eye.fill") {
          onReview()
        }
        .buttonStyle(.bordered)
        .tint(SoloTheme.purple)
        .disabled(task.result == nil || task.isReviewed)
      }
    }
    .padding(16)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
  }
}

private struct VentureScreen: View {
  var store: GameStore

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          HStack(spacing: 10) {
            VentureMetric(title: "Track Record", value: "\(store.stats.trackRecord)", color: SoloTheme.cyan)
            VentureMetric(title: "Sprint", value: "\(store.sprint)/12", color: SoloTheme.amber)
          }
          HStack(spacing: 10) {
            VentureMetric(title: "Evidence", value: "\(store.evidence.count)", color: SoloTheme.mint)
            VentureMetric(title: "Venture", value: "V\(store.venture)", color: SoloTheme.purple)
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("Founder doctrine").font(.caption).foregroundStyle(.secondary)
            Text(store.doctrine.name).font(.title2.bold())
            Text(store.doctrine.summary).foregroundStyle(.secondary)
            Divider()
            Label("\(store.founderName)’s company is a chain of decisions and consequences.", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
              .font(.subheadline)
          }
          .soloCard()

          VStack(alignment: .leading, spacing: 12) {
            Text("Career objective").font(.headline)
            Text("Complete two ventures and 24 sprints without exhausting runway, trust, or founder energy. Reviews reduce uncertainty, but consume the energy needed to finish the run.")
              .foregroundStyle(.secondary)
          }
          .soloCard()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("Venture \(store.venture)")
    }
  }
}

private struct VentureMetric: View {
  var title: String
  var value: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.title.bold().monospacedDigit()).foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .soloCard()
  }
}

private struct RecordsScreen: View {
  var store: GameStore
  @Environment(FounderProgressionStore.self) private var progression

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          NavigationLink {
            EvidenceScreen(entries: store.evidence)
          } label: {
            RecordLink(title: "Evidence Ledger", subtitle: "Verified work and unresolved uncertainty", symbol: "checkmark.seal.fill", count: store.evidence.count)
          }
          .buttonStyle(.plain)

          NavigationLink {
            AgentOperationsScreen(agents: store.agents)
          } label: {
            RecordLink(title: "Agent Operations", subtitle: "Trust, reliability, and model-family exposure", symbol: "cpu.fill", count: store.agents.count)
          }
          .buttonStyle(.plain)

          NavigationLink {
            HeadquartersProgressScreen(availableCapital: store.stats.capital)
          } label: {
            RecordLink(
              title: "Headquarters Progress",
              subtitle: progression.currentFacility.name,
              symbol: "building.2.fill",
              count: progression.ownedFacilities.count
            )
          }
          .buttonStyle(.plain)

          NavigationLink {
            SubscriptionScreen()
          } label: {
            RecordLink(title: "Solo Pro", subtitle: "Plans, purchases, and subscription management", symbol: "sparkles", count: 3)
          }
          .buttonStyle(.plain)

          Button(role: .destructive) {
            store.resetCareer()
          } label: {
            Label("Restart Career", systemImage: "arrow.counterclockwise")
              .frame(maxWidth: .infinity)
              .padding(15)
              .background(Color.red.opacity(0.12), in: .rect(cornerRadius: 14))
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Garage Records")
    }
  }
}

private struct RecordLink: View {
  var title: String
  var subtitle: String
  var symbol: String
  var count: Int

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(SoloTheme.cyan)
        .frame(width: 44, height: 44)
        .background(SoloTheme.cyan.opacity(0.12), in: .rect(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Text("\(count)").font(.headline.monospacedDigit())
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
    }
    .soloCard()
  }
}

private struct EvidenceScreen: View {
  var entries: [EvidenceEntry]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if entries.isEmpty {
          ContentUnavailableView(
            "No Evidence Yet",
            systemImage: "checkmark.seal",
            description: Text("Commit a sprint to record agent reports.")
          )
        } else {
          ForEach(entries) { entry in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("VENTURE \(entry.venture) • SPRINT \(entry.sprint)").font(.caption2.weight(.black)).foregroundStyle(SoloTheme.cyan)
                Spacer()
                Text(entry.verdict)
                  .font(.caption.weight(.bold))
                  .foregroundStyle(entry.evidenceVerified ? SoloTheme.mint : SoloTheme.amber)
              }
              Text(entry.task).font(.headline)
              Text(entry.agent).font(.caption.weight(.semibold))
              HStack {
                Text("Reported \(entry.reportedQuality)")
                if let actual = entry.actualQuality {
                  Text("•")
                  Text("Verified \(actual)")
                }
              }
              .font(.caption)
              .foregroundStyle(.secondary)
              Text(entry.note).font(.caption).foregroundStyle(.secondary)
            }
            .soloCard()
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("Evidence Ledger")
  }
}

private struct AgentOperationsScreen: View {
  var agents: [SoloAgent]

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        ForEach(agents) { agent in
          VStack(alignment: .leading, spacing: 12) {
            AgentRow(agent: agent)
            Divider()
            LabeledContent("Reliability", value: "\(agent.reliability)%")
            LabeledContent("Report integrity", value: "\(Int(agent.calibration * 100))%")
            LabeledContent("Model family", value: agent.modelFamily)
          }
          .soloCard()
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("Agent Operations")
  }
}

private struct SprintReportSheet: View {
  var report: SprintReport
  var visibleReport: VisibleSprintResult?
  var onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealedStep = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
        Text("SPRINT \(report.sprint) RESULTS")
          .font(.caption.weight(.black))
          .tracking(2)
          .foregroundStyle(SoloTheme.cyan)
        Text(visibleReport?.headline ?? "The sprint is resolved").font(.title.bold())
        VStack(spacing: 10) {
          if revealedStep >= 1 {
            ResultRow(label: "Revenue", value: report.revenueDelta.formatted(.currency(code: "USD").precision(.fractionLength(0))))
            ResultRow(label: "Capital", value: signed(visibleReport?.capitalDelta ?? report.revenueDelta / 4))
          }
          if revealedStep >= 2 {
            ResultRow(label: "Momentum", value: signed(report.momentumDelta))
            ResultRow(label: "Trust", value: signed(report.trustDelta))
            ResultRow(label: "Energy", value: signed(report.energyDelta))
            ResultRow(label: "Runway", value: signed(report.runwayDelta))
          }
          if revealedStep >= 3 {
            ResultRow(label: "Reviews completed", value: "\(visibleReport?.reviewsCompleted ?? report.reviewed)")
            ResultRow(label: "Verified strong outcomes", value: "\(visibleReport?.verifiedStrongOutcomes ?? 0)")
          }
          if revealedStep >= 4 {
            ResultRow(label: "Known risk flags", value: "\(visibleReport?.visibleRiskFlags ?? 0)")
            ResultRow(label: "Evidence recorded", value: "\(visibleReport?.evidenceRecorded ?? 0)")
          }
        }
        Button("Continue", systemImage: "arrow.right") { onContinue() }
          .buttonStyle(SoloPrimaryButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", systemImage: "xmark") { onContinue() }
            .labelStyle(.iconOnly)
        }
      }
      .task {
        if reduceMotion {
          revealedStep = 4
        } else {
          for step in 1...4 {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.snappy) { revealedStep = step }
          }
        }
      }
    }
  }

  private func signed(_ value: Int) -> String {
    value > 0 ? "+\(value)" : "\(value)"
  }
}

private struct CareerOutcomeScreen: View {
  var store: GameStore

  var body: some View {
    NavigationStack {
      ZStack {
        if let kind = store.careerOutcome?.kind {
          CareerOutcomeEnvironmentBackdrop(kind: kind)
        }
        ScrollView {
          VStack(spacing: 24) {
          Spacer(minLength: 44)
          if let outcome = store.careerOutcome {
            Image(systemName: outcome.kind.symbol)
              .font(.system(size: 72, weight: .bold))
              .foregroundStyle(outcome.kind == .victory ? SoloTheme.mint : SoloTheme.amber)
              .accessibilityHidden(true)

            VStack(spacing: 8) {
              Text(outcome.kind == .victory ? "CAREER COMPLETE" : "RUN ENDED")
                .font(.caption.weight(.black))
                .tracking(2)
                .foregroundStyle(SoloTheme.cyan)
              Text(outcome.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
              Text(outcome.summary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
              ResultRow(label: "Final score", value: outcome.score.formatted())
              ResultRow(label: "Revenue", value: store.stats.revenue.formatted(.currency(code: "USD").precision(.fractionLength(0))))
              ResultRow(label: "Momentum", value: "\(store.stats.momentum)")
              ResultRow(label: "Trust", value: "\(store.stats.trust)")
              ResultRow(label: "Evidence recorded", value: "\(store.evidence.count)")
            }
            .soloCard()
          }

          Button("Start Another Career", systemImage: "arrow.counterclockwise") {
            store.beginSetup()
          }
          .buttonStyle(SoloPrimaryButtonStyle())

          Button("Return to Title", systemImage: "house") {
            store.stage = .title
          }
          .buttonStyle(SoloSecondaryButtonStyle())
          }
          .padding(20)
          .frame(maxWidth: .infinity)
        }
      }
    }
  }
}

private struct ResultRow: View {
  var label: String
  var value: String

  var body: some View {
    HStack {
      Text(label).foregroundStyle(.secondary)
      Spacer()
      Text(value).font(.headline.monospacedDigit())
    }
    .padding(.vertical, 4)
  }
}

struct SoloPrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding(16)
      .background(SoloTheme.cyan.gradient, in: .rect(cornerRadius: 15))
      .foregroundStyle(.black)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.snappy, value: configuration.isPressed)
  }
}

struct SoloSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding(15)
      .background(SoloTheme.purple.opacity(0.22), in: .rect(cornerRadius: 15))
      .overlay { RoundedRectangle(cornerRadius: 15).stroke(SoloTheme.purple) }
      .foregroundStyle(.white)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}

enum SoloTheme {
  static let background = Color(red: 0.025, green: 0.035, blue: 0.065)
  static let card = Color.white.opacity(0.065)
  static let cyan = Color(red: 0.075, green: 0.875, blue: 0.961)
  static let purple = Color(red: 0.56, green: 0.31, blue: 0.96)
  static let mint = Color(red: 0.32, green: 0.88, blue: 0.77)
  static let amber = Color(red: 1, green: 0.68, blue: 0.2)
}

extension View {
  func soloCard() -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(SoloTheme.card, in: .rect(cornerRadius: 18))
  }
}
