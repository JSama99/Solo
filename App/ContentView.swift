import SwiftUI

struct ContentView: View {
  @State private var store = GameStore()
  @Environment(SubscriptionStore.self) private var subscriptions
  @Environment(AchievementStore.self) private var achievements
  @Environment(FounderProgressionStore.self) private var progression
  @State private var achievementToast: Achievement?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
      case .ventureThesis:
        VentureThesisScreen(store: store)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      case .chapterMilestone:
        ChapterMilestoneScreen(store: store)
          .transition(.move(edge: .bottom).combined(with: .opacity))
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
    .gameplayMotion(.state, value: store.stage)
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
      withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
        achievementToast = achievement
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        guard achievementToast?.id == achievement.id else { return }
        withAnimation(MotionKind.state.resolved(reduceMotion: reduceMotion)) { achievementToast = nil }
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
    // The How to Play link needs a stack to push onto. Without one SwiftUI
    // renders it as a permanently disabled control, which is how it shipped:
    // the button was on screen and inert.
    NavigationStack {
      ScrollView {
        VStack(spacing: 28) {
          Spacer(minLength: 52)
          ZStack {
            Capsule()
              .fill(SoloTheme.purple.opacity(0.18))
              .frame(width: 280, height: 128)
              .blur(radius: 18)
            HStack(spacing: -8) {
              TitleAgentBadge(agentID: "aurora", name: "Aurora", accent: SoloTheme.cyan)
              TitleAgentBadge(agentID: "stacks", name: "Stacks", accent: SoloTheme.amber)
                .zIndex(1)
              TitleAgentBadge(agentID: "brio", name: "Brio", accent: SoloTheme.coral)
            }
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
      .background(SoloTheme.background)
    }
  }
}

private struct TitleAgentBadge: View {
  var agentID: String
  var name: String
  var accent: Color

  var body: some View {
    VStack(spacing: 4) {
      Image(AgentPortraitAsset.name(for: agentID) ?? "")
        .resizable()
        .scaledToFill()
        .frame(width: agentID == "stacks" ? 94 : 82, height: agentID == "stacks" ? 94 : 82)
        .background(.black)
        .clipShape(.rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.85), lineWidth: 2) }
        .shadow(color: accent.opacity(0.38), radius: 10)
        .accessibilityHidden(true)
      Text(name)
        .font(.caption2.weight(.black))
        .foregroundStyle(accent)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(name), AI agent")
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
            .buttonStyle(SoloPressStyle())
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                  withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) {
                    store.selectedCareerMode = mode
                  }
                } label: {
                  CareerModeCard(mode: mode, isSelected: store.selectedCareerMode == mode)
                }
                .buttonStyle(SoloPressStyle())
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
                withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) {
                  store.selectedProductType = productType
                }
              } label: {
                ProductTypeCard(productType: productType, isSelected: store.selectedProductType == productType)
              }
              .buttonStyle(SoloPressStyle())
              .accessibilityAddTraits(store.selectedProductType == productType ? .isSelected : [])
            }
          }

          VStack(spacing: 12) {
            ForEach(FounderDoctrine.allCases) { doctrine in
              Button {
                withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) {
                  store.selectedDoctrine = doctrine
                }
              } label: {
                DoctrineCard(
                  doctrine: doctrine,
                  isSelected: store.selectedDoctrine == doctrine
                )
              }
              .buttonStyle(SoloPressStyle())
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
      get: { store.pendingDivergenceOffer },
      set: { if $0 == nil { store.pendingDivergenceOffer = nil } }
    )) { offer in
      ForkPromptView(offer: offer) { choice in
        store.chooseDivergence(choice)
        presentation.commit(in: store, progression: progression)
      }
      .presentationDetents([.medium, .large])
      .interactiveDismissDisabled()
    }
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
      if let result = presentation.visibleSprintResult {
        SprintOutcomeScreen(report: report, result: result) {
          store.finishReport()
          presentation.clearSprintPresentation()
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
      }
    }
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
          .buttonStyle(SoloPressStyle())

          NavigationLink {
            AgentOperationsScreen(store: store)
          } label: {
            RecordLink(title: "Agent Operations", subtitle: "Trust, reliability, and model-family exposure", symbol: "cpu.fill", count: store.agents.count)
          }
          .buttonStyle(SoloPressStyle())

          NavigationLink {
            AchievementsScreen(store: store)
          } label: {
            RecordLink(title: "Achievements", subtitle: "Founder milestones across four families", symbol: "medal.star.fill", count: achievements.unlockedCount)
          }
          .buttonStyle(SoloPressStyle())

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
          .buttonStyle(SoloPressStyle())

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
          .buttonStyle(SoloPressStyle())

          NavigationLink {
            SubscriptionScreen()
          } label: {
            RecordLink(title: "Solo Pro", subtitle: "Plans, purchases, and subscription management", symbol: "sparkles", count: 3)
          }
          .buttonStyle(SoloPressStyle())

          NavigationLink { SettingsScreen() } label: {
            RecordLink(title: "Settings", subtitle: "Cash feedback and your music", symbol: "gearshape.fill", count: 2)
          }
          .buttonStyle(SoloPressStyle())

          NavigationLink { HowToPlayScreen() } label: {
            RecordLink(title: "How to Play", subtitle: "Sprint rules, systems, and reference", symbol: "questionmark.circle.fill", count: nil)
          }
          .buttonStyle(SoloPressStyle())

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
            .buttonStyle(SoloPressStyle())
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
              .symbolEffect(.bounce, value: outcome.kind)
              .milestoneReveal(order: 0)
              .accessibilityHidden(true)

            Text(outcome.kind == .victory ? "CAREER COMPLETE" : "RUN ENDED")
              .font(.caption.weight(.black))
              .tracking(2)
              .foregroundStyle(SoloTheme.cyan)
              .milestoneReveal(order: 1)
            Text(outcome.title)
              .font(.largeTitle.bold())
              .multilineTextAlignment(.center)
              .milestoneReveal(order: 2)
            Text(outcome.summary)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .milestoneReveal(order: 3)

            if let identity = outcome.unicornIdentity, let profile = outcome.doctrineProfile {
              VStack(alignment: .leading, spacing: 8) {
                Label(identity.name, systemImage: "sparkles")
                  .font(.title2.bold())
                  .foregroundStyle(SoloTheme.mint)
                Text(identity.summary)
                  .font(.callout)
                  .foregroundStyle(.secondary)
                Text("Identity grade \(identity.identityGrade(profile: profile, flags: store.companyFlags)) • non-competitive")
                  .font(.caption.weight(.bold))
                  .foregroundStyle(SoloTheme.amber)
                Divider()
                Text("You declared \(store.doctrine.name).")
                  .font(.headline)
                Text("Across the record, you verified \(profile.verificationRate.formatted(.percent.precision(.fractionLength(0)))) of reports and shipped \(profile.unverifiedShipRate.formatted(.percent.precision(.fractionLength(0)))) unverified. Your behavior most resembles \(profile.revealed.name).")
                  .font(.callout)
                Text("Doctrine gap: \(profile.gap(from: store.doctrine).formatted(.percent.precision(.fractionLength(0))))")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
              .soloCard()
              .milestoneReveal(order: 4)
            }

            VStack(spacing: 12) {
              HStack {
                Text("Final score").foregroundStyle(.secondary)
                Spacer()
                Text(outcome.score.formatted())
                  .font(.headline.monospacedDigit())
                  .contentTransition(.numericText(value: Double(outcome.score)))
                  .gameplayMotion(.celebration, value: outcome.score)
              }
              .padding(.vertical, 4)
              ResultRow(label: "Revenue", value: store.stats.revenue.formatted(.currency(code: "USD").precision(.fractionLength(0))))
              ResultRow(label: "Momentum", value: "\(store.stats.momentum)")
              ResultRow(label: "Trust", value: "\(store.stats.trust)")
              ResultRow(label: "Evidence recorded", value: "\(store.evidence.count)")
              ResultRow(label: "Latent defects still unsurfaced", value: "\(store.latentDefects.count)")
            }
            .soloCard()
            .milestoneReveal(order: 4)
          }

          Button("Start Another Career", systemImage: "arrow.counterclockwise") {
            store.beginSetup()
          }
          .buttonStyle(SoloPrimaryButtonStyle())
          .milestoneReveal(order: 5)

          Button("Return to Title", systemImage: "house") {
            store.stage = .title
          }
          .buttonStyle(SoloSecondaryButtonStyle())
          .milestoneReveal(order: 6)
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding(16)
      .background(SoloTheme.cyan.gradient, in: .rect(cornerRadius: 15))
      .foregroundStyle(.black)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .animation(reduceMotion ? nil : .snappy, value: configuration.isPressed)
  }
}

struct SoloSecondaryButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding(15)
      .background(SoloTheme.purple.opacity(0.22), in: .rect(cornerRadius: 15))
      .overlay { RoundedRectangle(cornerRadius: 15).stroke(SoloTheme.purple) }
      .foregroundStyle(.white)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .animation(reduceMotion ? nil : .snappy, value: configuration.isPressed)
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
    .buttonStyle(SoloPressStyle())
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
        .buttonStyle(SoloPressStyle())
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
