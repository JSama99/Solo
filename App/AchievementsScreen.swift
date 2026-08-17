import SwiftUI

struct AchievementsScreen: View {
  var store: GameStore

  @Environment(AchievementStore.self) private var achievements
  @State private var family: AchievementFamily = .progression

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Founder Level \(achievements.level)")
            .font(.title2.bold())
            .contentTransition(.numericText(value: Double(achievements.level)))
          Text("\(achievements.unlockedCount) of \(AchievementCatalog.all.count) achievements unlocked")
            .font(.caption)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: Double(achievements.unlockedCount)))
        }
        .soloCard()
        .gameplayMotion(.celebration, value: achievements.unlockedCount)

        Picker("Achievement family", selection: $family) {
          ForEach(AchievementFamily.allCases, id: \.rawValue) { family in
            Text(family.title).tag(family)
          }
        }
        .pickerStyle(.segmented)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
          ForEach(familyAchievements) { achievement in
            AchievementBadgeCard(
              achievement: achievement,
              unlockedAt: achievements.unlockDate(achievement.id),
              progress: achievements.progress(for: achievement, context: displayContext),
              isNew: achievements.isRetroactivelyNew(achievement.id)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
          }
        }
        .gameplayMotion(.state, value: family)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Achievements")
    .onDisappear {
      achievements.markRetroactiveUnlocksSeen()
    }
  }

  private var familyAchievements: [Achievement] {
    AchievementCatalog.all.filter { $0.family == family }
  }

  private var displayContext: AchievementDisplayContext {
    let reviewRate: Double
    if store.evidence.isEmpty {
      reviewRate = 0
    } else {
      reviewRate = Double(store.evidence.filter(\.reviewed).count) / Double(store.evidence.count)
    }
    return AchievementDisplayContext(
      venture: store.venture,
      careerScore: SimulationEngine.careerScore(stats: store.stats),
      completedObjectives: store.completedObjectives,
      currentRunOverclaims: store.evidence.filter { $0.verificationState == .overclaimed }.count,
      reviewRate: reviewRate
    )
  }
}

private struct AchievementBadgeCard: View {
  var achievement: Achievement
  var unlockedAt: Date?
  var progress: AchievementProgress?
  var isNew: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(alignment: .top) {
        Image(systemName: achievement.rarity == .gold ? "medal.star.fill" : "medal.fill")
          .font(.title2)
          .foregroundStyle(unlockedAt == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(rarityColor))
          .grayscale(unlockedAt == nil ? 1 : 0)
          .symbolEffect(.bounce, value: unlockedAt)
        Spacer()
        if isNew {
          Text("NEW")
            .font(.caption2.weight(.black))
            .foregroundStyle(SoloTheme.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(SoloTheme.cyan.opacity(0.14), in: .capsule)
            .transition(.scale.combined(with: .opacity))
        }
      }
      Text(achievement.title)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(unlockedAt == nil ? .secondary : .primary)
      Text(achievement.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(3)
      Spacer(minLength: 0)
      if let unlockedAt {
        Text("Unlocked \(unlockedAt, format: .dateTime.month(.abbreviated).day().year())")
          .font(.caption2)
          .foregroundStyle(rarityColor)
      } else if let progress {
        VStack(alignment: .leading, spacing: 4) {
          ProgressView(value: progress.fraction)
            .tint(SoloTheme.cyan)
          Text("\(progress.label) \(progressValue(progress))")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      } else {
        Text("Locked • \(achievement.rarity.label)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
    .padding(14)
    .background(unlockedAt == nil ? SoloTheme.card.opacity(0.55) : SoloTheme.card, in: .rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(isNew ? SoloTheme.cyan.opacity(0.72) : .white.opacity(0.08))
    }
    .gameplayMotion(.celebration, value: unlockedAt)
    .gameplayMotion(.state, value: isNew)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(achievement.title)
    .accessibilityValue(accessibilityValue)
  }

  private var rarityColor: Color {
    switch achievement.rarity {
    case .bronze: SoloTheme.amber
    case .silver: SoloTheme.cyan
    case .gold: SoloTheme.mint
    }
  }

  private var accessibilityValue: String {
    if let unlockedAt {
      return "Unlocked \(unlockedAt.formatted(date: .abbreviated, time: .omitted))."
    }
    if let progress {
      return "Locked. \(progress.label), \(progressValue(progress))."
    }
    return "Locked."
  }

  private func progressValue(_ progress: AchievementProgress) -> String {
    if progress.target == 100 {
      return "\(Int(progress.current.rounded())) percent of \(Int(progress.target)) percent"
    }
    return "\(Int(progress.current.rounded())) of \(Int(progress.target.rounded()))"
  }
}
