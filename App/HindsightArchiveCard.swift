import SwiftUI

struct HindsightArchiveCard: View {
  var precedents: [Precedent]
  var divergences: [DivergenceRecord]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var knownRecordCount: Int?
  @State private var arrival = false

  var body: some View {
    NavigationLink {
      HindsightRecordsScreen(precedents: precedents, divergences: divergences)
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "archivebox.fill")
            .font(.title2)
            .foregroundStyle(SoloTheme.purple)
            .frame(width: 34, height: 34)
            .background(SoloTheme.purple.opacity(0.14), in: .rect(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 3) {
            Text("HINDSIGHT")
              .font(.caption.weight(.black))
              .tracking(1.4)
              .foregroundStyle(SoloTheme.purple)
            Text("Company memory")
              .font(.headline)
          }
          Spacer(minLength: 6)
          Text("\(recordCount)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(.secondary)
          Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        }
        Divider()
        Label(previewTitle, systemImage: previewSymbol)
          .font(.subheadline.weight(.semibold))
        Text(previewDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(SoloTheme.purple.opacity(0.075), in: .rect(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(SoloTheme.purple.opacity(arrival ? 0.8 : 0.32), lineWidth: arrival ? 2 : 1)
      }
      .scaleEffect(arrival && !reduceMotion ? 1.012 : 1)
    }
    .buttonStyle(SoloPressStyle())
    .accessibilityLabel("Hindsight. \(recordCount) records. \(previewTitle). \(previewDetail)")
    .accessibilityHint("Opens the canonical Hindsight record archive")
    .onAppear { knownRecordCount = recordCount }
    .onChange(of: recordCount) { oldCount, newCount in
      guard knownRecordCount != nil, newCount > oldCount else {
        knownRecordCount = newCount
        return
      }
      knownRecordCount = newCount
      AccessibilityNotification.Announcement("New Hindsight material is available.").post()
      guard !reduceMotion else { return }
      withAnimation(.snappy(duration: 0.2)) { arrival = true }
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.smooth(duration: 0.25)) { arrival = false }
      }
    }
  }

  private var recordCount: Int { precedents.count + divergences.count }

  private var latestPrecedent: Precedent? {
    precedents.max {
      $0.venture == $1.venture ? $0.sprint < $1.sprint : $0.venture < $1.venture
    }
  }

  private var latestDivergence: DivergenceRecord? {
    divergences.max { $0.collapsedAtSprint < $1.collapsedAtSprint }
  }

  private var previewTitle: String {
    if let latestPrecedent { return latestPrecedent.recallTitle }
    if let latestDivergence { return "Venture \(latestDivergence.venture), Sprint \(latestDivergence.sprint) divergence" }
    return "No precedents recorded yet"
  }

  private var previewDetail: String {
    if let latestPrecedent { return latestPrecedent.outcome.summary }
    if let latestDivergence { return latestDivergence.takenOutcome.summary }
    return "Consequential operating decisions will be archived here without changing their unlock or persistence rules."
  }

  private var previewSymbol: String {
    if latestPrecedent?.isFlagged == true { return "exclamationmark.triangle.fill" }
    return recordCount == 0 ? "archivebox" : "brain.head.profile"
  }
}
