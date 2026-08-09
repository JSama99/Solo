import SwiftUI

struct HindsightRecordsScreen: View {
  var precedents: [Precedent]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var filter: PrecedentRecordsFilter = .all
  @State private var expansion = PrecedentExpansionState()
  @State private var knownIDs: Set<UUID> = []
  @State private var highlightedID: UUID?
  @State private var highlightDismissTask: Task<Void, Never>?

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 10) {
        Picker("Filter precedents", selection: $filter) {
          ForEach(PrecedentRecordsFilter.allCases) { filter in
            Text(filter.title).tag(filter)
          }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 4)

        if filteredPrecedents.isEmpty {
          ContentUnavailableView(
            "No matching precedents",
            systemImage: "brain.head.profile",
            description: Text("Consequential sprints are recorded here as they occur.")
          )
          .frame(maxWidth: .infinity)
          .padding(.vertical, 32)
        } else {
          ForEach(filteredPrecedents) { precedent in
            PrecedentRecordRow(
              precedent: precedent,
              isExpanded: expansion.isExpanded(precedent.id),
              isHighlighted: highlightedID == precedent.id,
              reduceMotion: reduceMotion
            ) {
              toggle(precedent.id)
            }
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .id(filter)
      .transition(.opacity)
    }
    .navigationTitle("Hindsight")
    .animation(.smooth(duration: 0.2), value: filter)
    .onAppear {
      knownIDs = Set(precedents.map(\.id))
    }
    .onChange(of: precedentIDs) { _, newIDs in
      highlightNewestInsertion(in: newIDs)
    }
    .onDisappear { highlightDismissTask?.cancel() }
  }

  private var filteredPrecedents: [Precedent] {
    precedents
      .filter(filter.includes)
      .sorted {
        $0.venture == $1.venture ? $0.sprint > $1.sprint : $0.venture > $1.venture
      }
  }

  private var precedentIDs: [UUID] { precedents.map(\.id) }

  private func toggle(_ id: UUID) {
    if reduceMotion {
      expansion.toggle(id)
    } else {
      withAnimation(.smooth(duration: 0.28)) {
        expansion.toggle(id)
      }
    }
  }

  private func highlightNewestInsertion(in IDs: [UUID]) {
    let newest = Set(IDs).subtracting(knownIDs)
    knownIDs = Set(IDs)
    guard let inserted = precedents.last(where: { newest.contains($0.id) }) else { return }
    highlightedID = inserted.id
    highlightDismissTask?.cancel()
    highlightDismissTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(0.65))
      guard !Task.isCancelled else { return }
      withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
        highlightedID = nil
      }
    }
  }
}

private struct PrecedentRecordRow: View {
  var precedent: Precedent
  var isExpanded: Bool
  var isHighlighted: Bool
  var reduceMotion: Bool
  var onToggle: () -> Void

  var body: some View {
    Button(action: onToggle) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: precedent.isFlagged ? "exclamationmark.triangle.fill" : "brain.head.profile")
            .foregroundStyle(precedent.isFlagged ? SoloTheme.amber : SoloTheme.cyan)
            .frame(width: 22)
          VStack(alignment: .leading, spacing: 3) {
            Text(precedent.recallTitle)
              .font(.subheadline.weight(.bold))
            Text(precedent.context.summary)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(isExpanded ? nil : 1)
          }
          Spacer(minLength: 4)
          Image(systemName: "chevron.down")
            .font(.caption.weight(.bold))
            .rotationEffect(.degrees(isExpanded && !reduceMotion ? 180 : 0))
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: isExpanded)
            .accessibilityHidden(true)
        }
        Text(precedent.outcome.summary)
          .font(.caption)
          .foregroundStyle(precedent.isFlagged ? SoloTheme.amber : .secondary)
          .lineLimit(isExpanded ? nil : 2)

        if isExpanded {
          VStack(alignment: .leading, spacing: 8) {
            Divider()
            detail("Decision", value: precedent.decisionSummary)
            detail("Recorded context", value: precedent.context.summary)
            detail("Observed outcome", value: precedent.outcome.summary)
          }
          .transition(.opacity)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(13)
      .background(isHighlighted ? SoloTheme.cyan.opacity(0.14) : SoloTheme.card, in: .rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(isHighlighted ? SoloTheme.cyan.opacity(0.7) : .white.opacity(0.08))
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(precedent.recallTitle). \(precedent.outcome.summary)")
    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    .accessibilityHint(isExpanded ? "Double tap to hide recorded detail" : "Double tap to show recorded detail")
  }

  private func detail(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      Text(value).font(.caption)
    }
  }
}
