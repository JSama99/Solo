import SwiftUI

struct VentureThesisScreen: View {
  @Bindable var store: GameStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("VENTURE \(store.venture) THESIS")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.cyan)
          .milestoneReveal(order: 0)
        Text("Choose what to prove")
          .font(.largeTitle.bold())
          .milestoneReveal(order: 1)
        Text("This choice shapes the venture’s operating parameters, never its task or dilemma content.")
          .foregroundStyle(.secondary)
          .milestoneReveal(order: 2)
        ForEach(Array(VentureThesis.allCases.enumerated()), id: \.element.id) { index, thesis in
          ThesisOptionRow(thesis: thesis, selected: store.selectedThesis == thesis) {
            withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) {
              store.selectedThesis = thesis
            }
          }
          .milestoneReveal(order: 3 + index)
        }
        Button("Begin Venture", systemImage: "arrow.right") { store.selectThesisAndBegin() }
          .buttonStyle(SoloPrimaryButtonStyle())
          .milestoneReveal(order: 3 + VentureThesis.allCases.count)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .appSensoryFeedback(.selection, trigger: store.selectedThesis)
  }
}

/// One thesis choice. Split out of the screen so the selection state has a
/// single `Equatable` value to drive motion from, rather than three separate
/// comparisons recomputed inline.
private struct ThesisOptionRow: View {
  var thesis: VentureThesis
  var selected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(thesis.name).font(.headline)
          Spacer()
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selected ? AnyShapeStyle(SoloTheme.mint) : AnyShapeStyle(.secondary))
            .contentTransition(.symbolEffect(.replace))
        }
        Text(thesis.summary).font(.caption).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(
        selected ? SoloTheme.purple.opacity(0.18) : SoloTheme.card,
        in: .rect(cornerRadius: 18)
      )
    }
    .buttonStyle(SoloPressStyle())
    .gameplayMotion(.emphasis, value: selected)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(thesis.name). \(thesis.summary)")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}

struct ChapterMilestoneScreen: View {
  var store: GameStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if let milestone = store.pendingChapterMilestone {
      VStack(alignment: .leading, spacing: 16) {
        Label("CHAPTER COMPLETE", systemImage: "seal.fill")
          .font(.caption.weight(.black))
          .foregroundStyle(SoloTheme.amber)
          .symbolEffect(.bounce, value: milestone.beginning.name)
          .milestoneReveal(order: 0)
        Text("\(milestone.completed.name) → \(milestone.beginning.name)")
          .font(.largeTitle.bold())
          .milestoneReveal(order: 1)
        Text(milestone.beginning.subtitle)
          .foregroundStyle(.secondary)
          .milestoneReveal(order: 2)
        Text("Venture objective: \(Int(milestone.objectiveProgress * 100))% complete")
          .font(.headline)
          .contentTransition(.numericText(value: milestone.objectiveProgress))
          .milestoneReveal(order: 3)
        Text("Chapter reward: \(milestone.rewardLabel)")
          .foregroundStyle(SoloTheme.mint)
          .milestoneReveal(order: 4)
        Button("Continue", systemImage: "arrow.right") {
          withAnimation(MotionKind.state.resolved(reduceMotion: reduceMotion)) {
            store.dismissChapterMilestone()
          }
        }
        .buttonStyle(SoloPrimaryButtonStyle())
        .milestoneReveal(order: 5)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(SoloTheme.background)
      .appSensoryFeedback(.success, trigger: milestone.beginning.name)
    }
  }
}
