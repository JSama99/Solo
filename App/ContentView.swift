import SwiftUI

struct ContentView: View {
  @State private var store = GameStore()
  @Environment(SubscriptionStore.self) private var subscriptions
  @Environment(AchievementStore.self) private var achievements
  @Environment(FounderProgressionStore.self) private var progression
  @State private var achievementToast: Achievement?

  var body: some View {
    ZStack {
      SoloTheme.background.ignoresSafeArea()
      switch store.stage {
      case .title:
        TitleScreen(store: store)
          .transition(.opacity.combined(with: .scale(scale: 0.97)))
      case .modeSelect:
        ModeSelectScreen(store: store)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      case .setup:
        FounderSetupScreen(store: store)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      case .game:
        GameDashboard(store: store)
          .transition(.opacity)
      case .ventureUnlock:
        VentureUnlockScreen(store: store)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      case .ventureCheckpoint:
        VentureCheckpointScreen(store: store)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      case .outcome:
        CareerOutcomeScreen(store: store)
          .transition(.opacity.combined(with: .scale(scale: 0.97)))
      }
      if let achievementToast {
        VStack {
          AchievementToast(achievement: achievementToast)
          Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
      }
    }
    .animation(.smooth, value: store.stage)
    .onAppear {
      // Bind the real entitlement source once the environment is available.
      store.entitlements = subscriptions
      store.achievementStore = achievements
      store.progressionStore = progression
      store.resumeAfterFounderPassUnlock()
    }
    .onChange(of: subscriptions.isPro) { _, isPro in
      // A purchase or restore completed anywhere in the app resumes a held career.
      if isPro { store.resumeAfterFounderPassUnlock() }
    }
    .onChange(of: achievements.latestUnlock?.id) { _, _ in
      guard let achievement = achievements.latestUnlock else { return }
      withAnimation(.snappy) { achievementToast = achievement }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        guard achievementToast?.id == achievement.id else { return }
        withAnimation(.smooth) { achievementToast = nil }
      }
    }
    .sensoryFeedback(.success, trigger: achievementToast?.id)
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
  @Environment(AchievementStore.self) private var achievements

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
        Label("Founder Level \(achievements.level) · \(achievements.totalXP) XP", systemImage: "medal.star.fill")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(SoloTheme.cyan)
          .padding(.horizontal, 14)
          .padding(.vertical, 9)
          .background(SoloTheme.card, in: .capsule)
        VStack(spacing: 12) {
          Button("Choose Mode", systemImage: "play.fill") {
            store.beginModeSelection()
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
          NavigationLink { HowToPlayScreen() } label: { Label("How to Play", systemImage: "questionmark.circle").frame(maxWidth: .infinity) }
            .buttonStyle(SoloSecondaryButtonStyle())
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

private struct ModeSelectScreen: View {
  var store: GameStore

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("CHOOSE YOUR RUN")
              .font(.caption.weight(.black))
              .tracking(2)
              .foregroundStyle(SoloTheme.cyan)
            Text("How far do you want to build?")
              .font(.largeTitle.bold())
            Text("Each mode uses the same simulation, with a different commitment.")
              .foregroundStyle(.secondary)
          }

          ForEach(CareerMode.allCases) { mode in
            Button {
              store.startMode(mode)
            } label: {
              CareerModeCard(mode: mode, isSelected: false)
            }
            .buttonStyle(.plain)
            .accessibilityHint(mode == .daily ? "Starts today’s shared Daily Challenge" : "Continues to founder setup")
          }
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

private struct AchievementToast: View {
  var achievement: Achievement

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "medal.star.fill")
        .font(.title2)
        .foregroundStyle(SoloTheme.amber)
      VStack(alignment: .leading, spacing: 2) {
        Text("Achievement Unlocked")
          .font(.caption.weight(.black))
          .tracking(1)
          .foregroundStyle(SoloTheme.cyan)
        Text(achievement.title)
          .font(.headline)
        Text("+\(achievement.xp) XP")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(SoloTheme.cyan.opacity(0.35), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Achievement unlocked: \(achievement.title), \(achievement.xp) experience points")
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
            Text("Choose how long the story runs, what the company makes, then the doctrine that shapes it. "
                 + "None is universally correct.")
              .foregroundStyle(.secondary)
          }

          TextField("Founder name", text: $store.founderName)
            .textInputAutocapitalization(.words)
            .padding(16)
            .background(SoloTheme.card, in: .rect(cornerRadius: 16))
            .accessibilityLabel("Founder name")

          VStack(alignment: .leading, spacing: 8) {
            Text("CAREER LENGTH")
              .font(.caption.weight(.black))
              .tracking(2)
              .foregroundStyle(SoloTheme.cyan)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
              ForEach(CareerMode.allCases) { mode in
                Button {
                  withAnimation(.snappy) { store.selectedCareerMode = mode }
                } label: {
                  CareerModeCard(mode: mode, isSelected: store.selectedCareerMode == mode)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.selectedCareerMode == mode ? .isSelected : [])
              }
            }
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("PRODUCT")
              .font(.caption.weight(.black))
              .tracking(2)
              .foregroundStyle(SoloTheme.cyan)
            ForEach(ProductType.allCases) { productType in
              Button {
                withAnimation(.snappy) { store.selectedProductType = productType }
              } label: {
                ProductTypeCard(productType: productType, isSelected: store.selectedProductType == productType)
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(store.selectedProductType == productType ? .isSelected : [])
            }
          }

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

private struct ProductTypeCard: View {
  var productType: ProductType
  var isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(productType.name).font(.headline)
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? SoloTheme.cyan : .secondary)
      }
      Text(productType.summary).font(.subheadline).foregroundStyle(.secondary)
      HStack(spacing: 6) {
        ForEach(productType.flavorTags, id: \.self) { tag in
          Text(tag).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
            .background(SoloTheme.cyan.opacity(0.14), in: Capsule())
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(isSelected ? SoloTheme.purple.opacity(0.18) : SoloTheme.card)
    .overlay { RoundedRectangle(cornerRadius: 18).stroke(isSelected ? SoloTheme.cyan : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1) }
    .clipShape(.rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
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

/// Deliberately lighter than DoctrineCard -- CareerMode is a binary choice
/// with no perk/risk tradeoff to weigh, just a length of story to commit to.
struct CareerModeCard: View {
  var mode: CareerMode
  var isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(mode.name).font(.subheadline.bold())
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? SoloTheme.cyan : .secondary)
      }
      Text(mode.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(isSelected ? SoloTheme.purple.opacity(0.18) : SoloTheme.card)
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(isSelected ? SoloTheme.cyan : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
    }
    .clipShape(.rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

private struct GameDashboard: View {
  var store: GameStore
  @Environment(FounderProgressionStore.self) private var progression
  @State private var presentation = PresentationCoordinator()

  var body: some View {
    VStack(spacing: 0) {
      if store.isVentureLocked {
        VentureLockBanner(store: store)
      }
      if let recall = store.activeRecall {
        HindsightRecallCard(recall: recall) { store.dismissRecall() }
      }
      dashboardTabs
    }
  }

  private var dashboardTabs: some View {
    TabView {
      Tab("Garage", systemImage: "house.fill") {
        FounderEnvironmentScreen(store: store, presentation: presentation)
      }
      Tab("Venture", systemImage: "chart.line.uptrend.xyaxis") {
        VentureScreen(store: store)
      }
      Tab("Tech.com", systemImage: "newspaper.fill") {
        TechComScreen(store: store)
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
        Text(agent.assignment == nil ? "Ready • \(agent.archetype)" : "Working • \(agent.modelFamily)")
          .font(.caption)
          .foregroundStyle(agent.assignment == nil ? .secondary : SoloTheme.cyan)
        Text(agent.traitSummary)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(agent.relationshipLabel).font(.caption.weight(.bold))
        Text("Bond \(agent.relationship) • Drift \(Int(agent.drift))").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .background(SoloTheme.card, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

private struct SprintPhaseTracker: View {
  var current: SprintPhase

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("SPRINT FLOW", systemImage: current.symbol)
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        Text("STEP \(current.rawValue) OF 5")
          .font(.caption2.weight(.black))
          .foregroundStyle(.secondary)
      }
      Text(current.title).font(.headline)
      HStack(spacing: 6) {
        ForEach(SprintPhase.allCases) { phase in
          Capsule()
            .fill(phase.rawValue <= current.rawValue ? SoloTheme.cyan : .white.opacity(0.09))
            .frame(height: 6)
        }
      }
    }
    .soloCard()
  }
}

struct FounderDilemmaCard: View {
  var dilemma: FounderDilemma
  var selectedChoiceID: String?
  var onSelect: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("FOUNDER DILEMMA", systemImage: "arrow.triangle.branch")
        .font(.caption.weight(.black))
        .tracking(1.2)
        .foregroundStyle(SoloTheme.amber)
      Text(dilemma.title).font(.title3.bold())
      Text(dilemma.setup).font(.subheadline).foregroundStyle(.secondary)
      ForEach(dilemma.choices) { choice in
        Button {
          onSelect(choice.id)
        } label: {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: selectedChoiceID == choice.id ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(selectedChoiceID == choice.id ? SoloTheme.cyan : .secondary)
            VStack(alignment: .leading, spacing: 3) {
              Text(choice.title).font(.subheadline.weight(.bold))
              Text(choice.detail).font(.caption).foregroundStyle(.secondary)
              Text(choice.consequencePreview)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SoloTheme.amber)
            }
            Spacer()
          }
          .padding(12)
          .background(selectedChoiceID == choice.id ? SoloTheme.purple.opacity(0.16) : .white.opacity(0.035), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
      }
    }
    .soloCard()
  }
}

struct ResolvedDilemmaSummary: View {
  var dilemma: FounderDilemma
  var choice: DilemmaChoice

  var body: some View {
    Label("\(dilemma.title): \(choice.title)", systemImage: "checkmark.seal.fill")
      .font(.caption.weight(.semibold))
      .foregroundStyle(SoloTheme.mint)
      .soloCard()
  }
}

struct SprintObjectiveCard: View {
  var objective: SprintObjective
  var progress: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "target")
        .font(.title2)
        .foregroundStyle(SoloTheme.mint)
      VStack(alignment: .leading, spacing: 4) {
        Text("OPTIONAL SPRINT OBJECTIVE")
          .font(.caption2.weight(.black))
          .foregroundStyle(SoloTheme.mint)
        Text(objective.title).font(.headline)
        Text(objective.detail).font(.caption).foregroundStyle(.secondary)
        Text(progress)
          .font(.caption.weight(.bold))
          .foregroundStyle(SoloTheme.cyan)
        Text("Reward: \(objective.rewardLabel)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(SoloTheme.mint)
      }
      Spacer()
    }
    .soloCard()
  }
}

struct TaskDraftBacklogCard: View {
  var activeTasks: [SoloTask]
  var backlog: [SoloTask]
  var canEdit: Bool
  var onSwap: (UUID, UUID) -> Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("SPRINT DRAFT", systemImage: "square.stack.3d.up.fill")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
        Spacer()
        Text("Choose 3 of 5")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
      }
      Text("The two opportunities left here will create the listed consequences when the sprint commits.")
        .font(.caption)
        .foregroundStyle(.secondary)

      ForEach(backlog) { candidate in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: candidate.category.symbol)
            .foregroundStyle(candidate.urgency == .critical ? SoloTheme.amber : SoloTheme.cyan)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 3) {
            Text(candidate.title).font(.subheadline.weight(.bold))
            Text(candidate.detail).font(.caption).foregroundStyle(.secondary)
            Text("If ignored: \(candidate.consequenceLabel)")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(SoloTheme.amber)
          }
          Spacer()
          Menu("Swap In", systemImage: "arrow.left.arrow.right") {
            ForEach(activeTasks) { active in
              Button("Replace \(active.title)") {
                _ = onSwap(active.id, candidate.id)
              }
            }
          }
          .disabled(!canEdit)
        }
        .padding(12)
        .background(.white.opacity(0.035), in: .rect(cornerRadius: 12))
      }
      if !canEdit {
        Text("Draft locked because work has started.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .soloCard()
  }
}

struct TaskCommandCard: View {
  var task: SoloTask
  var agents: [SoloAgent]
  var founderStats: FounderStats
  var onAssign: (String?) -> Void
  var onReview: () -> Void
  var onResolution: (TaskResolutionChoice) -> Void

  @State private var inspectedAgent: AgentDetailViewModel?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Image(systemName: task.role.symbol)
          .foregroundStyle(SoloTheme.cyan)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 3) {
          Text(task.title).font(.headline)
          Text(task.detail).font(.caption).foregroundStyle(.secondary)
          HStack(spacing: 6) {
            Label(task.category.rawValue, systemImage: task.category.symbol)
            Text("•")
            Text(task.urgency.label)
          }
          .font(.caption2.weight(.semibold))
          .foregroundStyle(task.urgency == .critical ? SoloTheme.amber : .secondary)
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

      if let assignedAgent {
        Button("Inspect \(assignedAgent.name)", systemImage: "person.text.rectangle") {
          inspectedAgent = AgentDetailViewModel.commandDeck(
            agent: assignedAgent,
            task: task,
            founderStats: founderStats
          )
        }
        .buttonStyle(.bordered)
      }

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
        VStack(alignment: .leading, spacing: 2) {
          Text("Base \(task.reward)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SoloTheme.mint)
          if task.skipEffects != SimulationEffects() {
            Text("Ignored: \(task.consequenceLabel)")
              .font(.caption2)
              .foregroundStyle(SoloTheme.amber)
          }
        }
        Spacer()
        Button(task.isReviewed ? "Reviewed" : "Founder Review", systemImage: task.isReviewed ? "checkmark.seal.fill" : "eye.fill") {
          onReview()
        }
        .buttonStyle(.bordered)
        .tint(SoloTheme.purple)
        .disabled(task.result == nil || task.isReviewed)
      }

      if task.isReviewed {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          Text("Founder decision")
            .font(.caption2)
            .foregroundStyle(.secondary)
          if task.resolutionLocked, let resolution = task.resolution {
            Label("(resolution.title) locked", systemImage: "lock.fill")
              .font(.caption.weight(.bold))
              .foregroundStyle(SoloTheme.mint)
          } else {
            ForEach(TaskResolutionChoice.allCases) { choice in
              Button(choice.title, systemImage: choice.symbol) {
                onResolution(choice)
              }
              .frame(maxWidth: .infinity)
              .buttonStyle(.bordered)
              .tint(choice == .approve ? SoloTheme.mint : SoloTheme.purple)
              .accessibilityHint(choice.summary)
            }
          }
        }
        Text(task.resolution?.summary ?? TaskResolutionChoice.approve.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .background(SoloTheme.card, in: .rect(cornerRadius: 18))
    .sheet(item: $inspectedAgent) { agent in
      AgentDetailPresentation(agent: agent)
    }
  }

  private var assignedAgent: SoloAgent? {
    guard let assignedAgentID = task.assignedAgentID else { return nil }
    return agents.first(where: { $0.id == assignedAgentID })
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
            VentureMetric(title: "Sprint", value: "\(store.sprint)/12 • \(Int(store.ventureObjectiveProgress * 100))%", color: SoloTheme.amber)
          }
          HStack(spacing: 10) {
            VentureMetric(title: "Evidence", value: "\(store.evidence.count)", color: SoloTheme.mint)
            VentureMetric(title: "Venture", value: "V\(store.venture)", color: SoloTheme.purple)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("CHAPTER \(store.chapter.rawValue)")
              .font(.caption.weight(.black))
              .foregroundStyle(SoloTheme.amber)
            Text(store.chapter.name).font(.title2.bold())
            Text(store.chapter.subtitle).foregroundStyle(.secondary)
          }
          .soloCard()

          let era = VentureEra.era(for: store.venture)
          VStack(alignment: .leading, spacing: 8) {
            Label("\(era.name) era", systemImage: "mountain.2.fill").font(.headline)
            Text(era.newForce).foregroundStyle(.secondary)
            Text("-\(era.runwayBurnPerSprint) Runway • -\(era.energyCostPerSprint) Energy each sprint")
              .font(.caption.weight(.semibold)).foregroundStyle(SoloTheme.amber)
            Text(store.venture < era.milestoneVenture ? "\(era.milestoneVenture - store.venture) venture(s) until \(VentureEra.era(for: era.milestoneVenture + 1).name)." : "You have reached this era’s milestone.")
              .font(.caption).foregroundStyle(.secondary)
          }
          .soloCard()

          let objective = store.ventureObjective ?? VentureObjective.selected(for: store.venture)
          VStack(alignment: .leading, spacing: 8) {
            Label("Venture objective", systemImage: "target").font(.headline)
            Text(objective.title).font(.title3.bold())
            Text(objective.framing).font(.caption).foregroundStyle(.secondary)
            ProgressView(value: store.ventureObjectiveProgress)
              .tint(SoloTheme.mint)
            Text("\(Int(store.ventureObjectiveProgress * 100))% complete • Reward: \(objective.rewardLabel)")
              .font(.caption.weight(.semibold)).foregroundStyle(SoloTheme.mint)
          }
          .soloCard()

          VStack(alignment: .leading, spacing: 8) {
            Label("Venture pressure", systemImage: "gauge.with.dots.needle.67percent")
              .font(.headline)
            Text(store.venturePressureSummary)
              .font(.callout)
              .foregroundStyle(.secondary)
            Text("Later ventures increase provider instability and no longer restore the company to fixed Runway or Energy floors.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .soloCard()

          VStack(alignment: .leading, spacing: 10) {
            Text("Company consequences").font(.headline)
            if store.companyFlags.isEmpty && store.activeObligations.isEmpty {
              Text("Founder decisions will appear here when they create lasting company state.")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              ForEach(store.companyFlags.sorted(by: { $0.name < $1.name })) { flag in
                VStack(alignment: .leading, spacing: 2) {
                  Label(flag.name, systemImage: "point.topleft.down.curvedto.point.bottomright.up").font(.subheadline.weight(.semibold)).foregroundStyle(SoloTheme.cyan)
                  Text(flag.context).font(.caption).foregroundStyle(.secondary)
                }
              }
              ForEach(store.activeObligations) { obligation in
                VStack(alignment: .leading, spacing: 3) {
                  Text(obligation.title).font(.subheadline.bold())
                  Text(obligation.detail).font(.caption).foregroundStyle(.secondary)
                  Text("Caused by: \(obligation.sourceDecision)").font(.caption2).foregroundStyle(SoloTheme.cyan)
                  Text("\(obligation.effectsPerSprint.conciseLossLabel) • \(obligation.durationLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SoloTheme.amber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.white.opacity(0.035), in: .rect(cornerRadius: 10))
              }
            }
          }
          .soloCard()

          VStack(alignment: .leading, spacing: 10) {
            Text("Garage upgrades").font(.headline)
            if store.unlockedGarageUpgrades.isEmpty {
              Text("Complete sprints, earn revenue, and record evidence to evolve the garage.")
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              ForEach(store.unlockedGarageUpgrades) { upgrade in
                Label(upgrade.name, systemImage: upgrade.symbol)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(SoloTheme.cyan)
              }
            }
          }
          .soloCard()

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
            Text(store.careerMode == .bounded
              ? "Complete two ventures and 24 sprints while protecting runway, trust, energy, and the company you create through persistent decisions."
              : "Build for as many ventures as you can sustain. Each checkpoint lets you retire, while operating pressure, obligations, and provider risk continue to rise.")
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
  @Environment(AchievementStore.self) private var achievements

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
            AgentOperationsScreen(store: store)
          } label: {
            RecordLink(title: "Agent Operations", subtitle: "Trust, reliability, and model-family exposure", symbol: "cpu.fill", count: store.agents.count)
          }
          .buttonStyle(.plain)

          NavigationLink {
            HindsightRecordsScreen(precedents: store.precedents)
          } label: {
            RecordLink(title: "Hindsight", subtitle: "Recorded contexts and observed outcomes", symbol: "brain.head.profile", count: store.precedents.count)
          }
          .buttonStyle(.plain)

          NavigationLink {
            AchievementsScreen(store: store)
          } label: {
            RecordLink(title: "Achievements", subtitle: "Founder milestones across four families", symbol: "medal.star.fill", count: achievements.unlockedCount)
          }
          .buttonStyle(.plain)

          NavigationLink {
            HeadquartersProgressScreen(store: store)
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
            CompanyStoryScreen(
              flags: store.companyFlags.sorted(by: { $0.name < $1.name }),
              obligations: store.activeObligations,
              decisions: store.decisionHistory
            )
          } label: {
            RecordLink(
              title: "Company Story",
              subtitle: "Persistent decisions, obligations, and narrative state",
              symbol: "point.topleft.down.curvedto.point.bottomright.up",
              count: store.decisionHistory.count
            )
          }
          .buttonStyle(.plain)

          NavigationLink {
            SubscriptionScreen()
          } label: {
            RecordLink(title: "Solo Pro", subtitle: "Plans, purchases, and subscription management", symbol: "sparkles", count: 3)
          }
          .buttonStyle(.plain)

          NavigationLink { SettingsScreen() } label: {
            RecordLink(title: "Settings", subtitle: "Cash feedback and your music", symbol: "gearshape.fill", count: 2)
          }
          .buttonStyle(.plain)

          NavigationLink { HowToPlayScreen() } label: {
            RecordLink(title: "How to Play", subtitle: "Sprint rules, systems, and reference", symbol: "questionmark.circle.fill", count: nil)
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
  var count: Int?

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
      if let count { Text("\(count)").font(.headline.monospacedDigit()) }
      Image(systemName: "chevron.right").foregroundStyle(.tertiary)
    }
    .soloCard()
  }
}

private struct CompanyStoryScreen: View {
  var flags: [CompanyFlag]
  var obligations: [CompanyObligation]
  var decisions: [CareerDecisionRecord]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Company identity").font(.headline)
          if flags.isEmpty {
            Text("No persistent company flags yet.").font(.caption).foregroundStyle(.secondary)
          } else {
            ForEach(flags) { flag in
              Label(flag.name, systemImage: "flag.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SoloTheme.cyan)
            }
          }
        }
        .soloCard()

        VStack(alignment: .leading, spacing: 10) {
          Text("Active obligations").font(.headline)
          if obligations.isEmpty {
            Text("No recurring obligations are active.").font(.caption).foregroundStyle(.secondary)
          } else {
            ForEach(obligations) { obligation in
              VStack(alignment: .leading, spacing: 3) {
                Text(obligation.title).font(.subheadline.bold())
                Text(obligation.detail).font(.caption).foregroundStyle(.secondary)
                Text("\(obligation.effectsPerSprint.conciseLossLabel) • \(obligation.durationLabel)")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(SoloTheme.amber)
              }
            }
          }
        }
        .soloCard()

        VStack(alignment: .leading, spacing: 10) {
          Text("Decision record").font(.headline)
          if decisions.isEmpty {
            Text("Founder dilemma choices will be recorded here.").font(.caption).foregroundStyle(.secondary)
          } else {
            ForEach(decisions) { decision in
              VStack(alignment: .leading, spacing: 3) {
                Text("V\(decision.venture) • S\(decision.sprint)")
                  .font(.caption2.weight(.black)).foregroundStyle(SoloTheme.cyan)
                Text(decision.dilemmaTitle).font(.subheadline.bold())
                Text(decision.choiceTitle).font(.caption.weight(.semibold))
                Text(decision.consequence).font(.caption).foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(10)
              .background(.white.opacity(0.035), in: .rect(cornerRadius: 10))
            }
          }
        }
        .soloCard()
      }
      .padding(16)
    }
    .navigationTitle("Company Story")
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
  @Bindable var store: GameStore
  @State private var selectedAgent: AgentDetailViewModel?

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        ForEach(store.agents) { agent in
          let model = AgentDetailViewModel.derive(agent: agent, task: store.tasks.first(where: { $0.assignedAgentID == agent.id }), founderStats: store.stats)
          Button { selectedAgent = model } label: { AgentRosterCard(agent: model) }
            .buttonStyle(.plain)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("Agent Operations")
    .sheet(item: $selectedAgent) { agent in
      AgentDetailPresentation(
        agent: agent,
        availablePerks: store.availablePerks(for: agent.agentID),
        onSelectPerk: { store.selectAgentPerk($0, for: agent.agentID) }
      )
    }
  }
}

private struct SprintReportSheet: View {
  var report: SprintReport
  var visibleReport: VisibleSprintResult?
  var onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealedStep = 0
  @State private var deliveredRevenueFeedback = false
  @Environment(AppSettingsStore.self) private var settings

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
            ResultRow(label: "Ignored opportunities", value: "\(report.skippedTasks)")
            if let objectiveTitle = report.objectiveTitle {
              ResultRow(label: objectiveTitle, value: report.objectiveCompleted ? "Completed" : "Missed")
            }
          }
        }
        if let dilemmaSummary = report.dilemmaSummary {
          VStack(alignment: .leading, spacing: 4) {
            Text("FOUNDER DECISION").font(.caption2.weight(.black)).foregroundStyle(SoloTheme.amber)
            Text(dilemmaSummary).font(.subheadline)
          }
          .soloCard()
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
      .onAppear {
        guard report.revenueDelta > 0, !deliveredRevenueFeedback else { return }
        deliveredRevenueFeedback = true
        RevenueCelebrationFeedback.play(isEnabled: settings.soundEffectsEnabled)
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
  /// Failure/risk accent. Paired with a symbol everywhere it is used so meaning
  /// never depends on colour alone.
  static let coral = Color(red: 1, green: 0.44, blue: 0.51)
}

extension View {
  func soloCard() -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(SoloTheme.card, in: .rect(cornerRadius: 18))
  }
}

/// Persistent banner while a career is held at the Venture 2 gate.
private struct VentureLockBanner: View {
  var store: GameStore

  var body: some View {
    Button {
      store.stage = .ventureUnlock
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "lock.fill")
        VStack(alignment: .leading, spacing: 1) {
          Text("Venture 1 complete").font(.subheadline.bold())
          Text("Unlock Venture 2 to continue this career")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption.bold())
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
      .background(SoloTheme.card)
      .foregroundStyle(SoloTheme.amber)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Venture 1 complete. Unlock Venture 2 to continue this career.")
  }
}

/// Hindsight Recall. Reports the conditions and what followed — never advice.
private struct HindsightRecallCard: View {
  var recall: HindsightRecall
  var onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label("Hindsight — \(recall.precedent.recallTitle)", systemImage: "brain.head.profile")
          .font(.caption.bold())
          .foregroundStyle(SoloTheme.amber)
        Spacer()
        Text(recall.strengthLabel)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss hindsight recall")
      }
      Text(recall.precedent.decisionSummary).font(.caption)
      Text(recall.precedent.context.summary)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(recall.precedent.outcome.summary)
        .font(.caption2)
        .foregroundStyle(SoloTheme.cyan)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(SoloTheme.card)
    .accessibilityElement(children: .combine)
  }
}
