import SwiftUI

struct VentureThesisScreen: View {
  @Bindable var store: GameStore
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("VENTURE \(store.venture) THESIS").font(.caption.weight(.black)).foregroundStyle(SoloTheme.cyan)
        Text("Choose what to prove").font(.largeTitle.bold())
        Text("This choice shapes the venture’s operating parameters, never its task or dilemma content.").foregroundStyle(.secondary)
        ForEach(VentureThesis.allCases) { thesis in
          Button { store.selectedThesis = thesis } label: {
            VStack(alignment: .leading, spacing: 6) {
              HStack { Text(thesis.name).font(.headline); Spacer(); Image(systemName: store.selectedThesis == thesis ? "checkmark.circle.fill" : "circle") }
              Text(thesis.summary).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(store.selectedThesis == thesis ? SoloTheme.purple.opacity(0.18) : SoloTheme.card, in: .rect(cornerRadius: 18))
          }.buttonStyle(.plain)
        }
        Button("Begin Venture", systemImage: "arrow.right") { store.selectThesisAndBegin() }.buttonStyle(SoloPrimaryButtonStyle())
      }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct ChapterMilestoneScreen: View {
  var store: GameStore
  var body: some View {
    if let milestone = store.pendingChapterMilestone {
      VStack(alignment: .leading, spacing: 16) {
        Text("CHAPTER COMPLETE").font(.caption.weight(.black)).foregroundStyle(SoloTheme.amber)
        Text("\(milestone.completed.name) → \(milestone.beginning.name)").font(.largeTitle.bold())
        Text(milestone.beginning.subtitle).foregroundStyle(.secondary)
        Text("Venture objective: \(Int(milestone.objectiveProgress * 100))% complete").font(.headline)
        Text("Chapter reward: \(milestone.rewardLabel)").foregroundStyle(SoloTheme.mint)
        Button("Continue", systemImage: "arrow.right") { store.dismissChapterMilestone() }.buttonStyle(SoloPrimaryButtonStyle())
      }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(SoloTheme.background)
    }
  }
}
