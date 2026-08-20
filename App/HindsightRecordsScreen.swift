import SwiftUI

struct HindsightRecordsScreen: View {
  var precedents: [Precedent]
  var divergences: [DivergenceRecord] = []

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

        if filter == .all {
          ForEach(divergences.sorted { $0.collapsedAtSprint > $1.collapsedAtSprint }) { record in
            DivergenceRecordRow(record: record)
              .transition(arrivalTransition)
          }
        }

        if filteredPrecedents.isEmpty && (filter != .all || divergences.isEmpty) {
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
            .transition(arrivalTransition)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .id(filter)
      .transition(.opacity)
    }
    .navigationTitle("Hindsight")
    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: filter)
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

  private var arrivalTransition: AnyTransition {
    guard !reduceMotion else { return .identity }
    return .asymmetric(
      insertion: .move(edge: .top)
        .combined(with: .scale(scale: 0.92, anchor: .top))
        .combined(with: .opacity),
      removal: .opacity
    )
  }

  private func toggle(_ id: UUID) {
    withAnimation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion)) {
      expansion.toggle(id)
    }
  }

  private func highlightNewestInsertion(in IDs: [UUID]) {
    let newest = Set(IDs).subtracting(knownIDs)
    knownIDs = Set(IDs)
    guard let inserted = precedents.last(where: { newest.contains($0.id) }) else { return }
    withAnimation(MotionKind.celebration.resolved(reduceMotion: reduceMotion)) {
      highlightedID = inserted.id
    }
    AccessibilityNotification.Announcement("New Hindsight record: \(inserted.recallTitle)").post()
    highlightDismissTask?.cancel()
    highlightDismissTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(0.65))
      guard !Task.isCancelled else { return }
      withAnimation(SoloMotion.resolved(SoloMotion.settle, reduceMotion: reduceMotion)) {
        highlightedID = nil
      }
    }
  }
}

private struct DivergenceRecordRow: View {
  var record: DivergenceRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Venture \(record.venture), Sprint \(record.sprint) — Divergence", systemImage: "arrow.triangle.branch")
        .font(.subheadline.bold())
        .foregroundStyle(SoloTheme.cyan)
      Text(record.context.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack(alignment: .top, spacing: 10) {
        branch(title: "SOLO", decision: record.takenSummary, outcome: record.takenOutcome.summary)
        branch(title: record.ghostRivalName, decision: record.ghostSummary, outcome: record.ghostOutcome.summary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(13)
    .background(SoloTheme.card, in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(SoloTheme.cyan.opacity(0.35), lineWidth: 1) }
    .accessibilityElement(children: .combine)
  }

  private func branch(title: String, decision: String, outcome: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.caption.weight(.black))
      Text(decision).font(.caption2).foregroundStyle(.secondary)
      Text(outcome).font(.caption)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct PrecedentRecordRow: View {
  var precedent: Precedent
  var isExpanded: Bool
  var isHighlighted: Bool
  var reduceMotion: Bool
  var onToggle: () -> Void
  @State private var impactPulse = false

  var body: some View {
    Button(action: onToggle) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: precedent.isFlagged ? "exclamationmark.triangle.fill" : "brain.head.profile")
            .foregroundStyle(precedent.isFlagged ? SoloTheme.amber : SoloTheme.cyan)
            .frame(width: 22)
          VStack(alignment: .leading, spacing: 3) {
            if isHighlighted {
              Text("JUST RECORDED")
                .font(.caption2.weight(.black))
                .tracking(1)
                .foregroundStyle(SoloTheme.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SoloTheme.cyan.opacity(0.14), in: .capsule)
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
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
            .animation(MotionKind.emphasis.resolved(reduceMotion: reduceMotion), value: isExpanded)
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
            if let counterfactual = precedent.counterfactual {
              detail("Rival branch", value: counterfactual.summary)
            }
          }
          .transition(reduceMotion ? .identity : .move(edge: .top))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(13)
      .background(SoloTheme.card, in: .rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .fill(SoloTheme.cyan.opacity(isHighlighted ? 0.12 : 0))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(isHighlighted ? SoloTheme.cyan.opacity(0.8) : .white.opacity(0.08), lineWidth: isHighlighted ? 2 : 1)
      }
      .scaleEffect(impactPulse ? 1.015 : 1)
      .shadow(color: SoloTheme.cyan.opacity(impactPulse ? 0.42 : 0), radius: 14)
    }
    .buttonStyle(SoloPressStyle())
    .task(id: isHighlighted) {
      guard isHighlighted, !reduceMotion else {
        impactPulse = false
        return
      }
      withAnimation(SoloMotion.impact) { impactPulse = true }
      try? await Task.sleep(for: .milliseconds(180))
      guard !Task.isCancelled else { return }
      withAnimation(SoloMotion.settle) { impactPulse = false }
    }
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
