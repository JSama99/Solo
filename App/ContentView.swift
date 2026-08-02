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

  var body: some View {
    TabView {
      Tab("Garage", systemImage: "house.fill") {
        GarageScreen(store: store)
      }
      Tab("Assign", systemImage: "slider.horizontal.3") {
        CommandScreen(store: store)
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
        }
      }
    )) { report in
      SprintReportSheet(report: report) {
        store.finishReport()
      }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
  }
}

private struct GarageScreen: View {
  var store: GameStore

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          StatsStrip(stats: store.stats)
          ZStack(alignment: .bottomLeading) {
            Image("FounderGarage")
              .resizable()
              .scaledToFill()
              .frame(height: 255)
              .frame(maxWidth: .infinity)
              .clipped()
            LinearGradient(
              colors: [.clear, SoloTheme.background.opacity(0.95)],
              startPoint: .center,
              endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 4) {
              Text("FOUNDER GARAGE")
                .font(.title2.weight(.black))
              Text("Venture \(store.venture) • Sprint \(store.sprint)/12 • \(store.garageCondition) systems")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SoloTheme.cyan)
            }
            .padding(16)
          }
          .clipShape(.rect(cornerRadius: 22))
          .overlay {
            RoundedRectangle(cornerRadius: 22)
              .stroke(SoloTheme.cyan.opacity(0.25))
          }

          HStack {
            Label("\(store.intent.name) intent", systemImage: store.intent.symbol)
              .font(.subheadline.weight(.bold))
            Spacer()
            Text("Mean drift \(store.averageDrift)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 4)

          VStack(spacing: 10) {
            ForEach(store.agents) { agent in
              AgentRow(agent: agent)
            }
          }

          Button("Commit Sprint", systemImage: "bolt.fill") {
            store.commitSprint()
          }
          .buttonStyle(SoloPrimaryButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("SOLO")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Text("\(store.stats.capital, format: .currency(code: "USD").precision(.fractionLength(0)))")
            .font(.caption.weight(.bold))
            .foregroundStyle(SoloTheme.mint)
        }
      }
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
              store.assign(agentID: agentID, to: task.id)
            } onReview: {
              store.toggleReview(taskID: task.id)
            }
          }

          Button("Commit Sprint", systemImage: "bolt.fill") {
            store.commitSprint()
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
          HStac