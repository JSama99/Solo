import SwiftUI

struct ModeSelectScreen: View {
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
