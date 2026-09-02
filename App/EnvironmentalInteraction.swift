import SwiftUI

/// Stable, reusable identities for physical Founder Garage interactions.
enum FounderEnvironmentalObject: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
  case couch
  case workoutBench

  var id: String { rawValue }
  var title: String { self == .couch ? "Recovery Cot" : "Workout Bench" }
  var symbol: String { self == .couch ? "bed.double.fill" : "figure.strengthtraining.traditional" }
}

enum FounderEnvironmentalAction: String, Codable, Hashable, Identifiable, Sendable {
  case rest
  case train

  var id: String { rawValue }
  var object: FounderEnvironmentalObject { self == .rest ? .couch : .workoutBench }
  var title: String { self == .rest ? "Take a recovery break" : "Train for momentum" }
}

enum FounderEnvironmentalTuning {
  static let restHours = 4
  static let restEnergy = 22
  static let restMomentum = -2
  static let trainingHours = 2
  static let trainingEnergy = -12
  static let trainingMomentum = 7
  static let restCooldown: TimeInterval = 8 * 60 * 60
  static let trainingCooldown: TimeInterval = 12 * 60 * 60
}

struct FounderEnvironmentalPreview: Equatable, Sendable {
  var action: FounderEnvironmentalAction
  var effects: SimulationEffects
  var durationHours: Int
  var available: Bool
  var unavailableReason: String?

  var accessibilitySummary: String {
    let sign = effects.energy >= 0 ? "+" : ""
    let momentumSign = effects.momentum >= 0 ? "+" : ""
    return action.title + ". " + sign + String(effects.energy) + " Energy, " + momentumSign + String(effects.momentum) + " Momentum, " + String(durationHours) + " hours."
      + (unavailableReason.map { " " + $0 + "." } ?? "")
  }
}

struct FounderEnvironmentalSave: Codable, Equatable, Sendable {
  var version = 1
  var elapsedHours = 0
  var nextRestAvailableAt: Date?
  var nextTrainingAvailableAt: Date?
}

struct FounderEnvironmentalActionCard: View {
  var store: GameStore
  var action: FounderEnvironmentalAction
  var onDismiss: () -> Void

  private var preview: FounderEnvironmentalPreview { store.environmentalPreview(for: action) }
  @Environment(AppSettingsStore.self) private var settings
  @State private var completed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(action.object.title, systemImage: action.object.symbol)
        .font(.title3.weight(.bold))
      Text(completed ? "Completed" : action.title).font(.headline)
      Text(preview.accessibilitySummary)
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10) {
        stat("Energy", value: preview.effects.energy)
        stat("Momentum", value: preview.effects.momentum)
        stat("Runway", value: preview.effects.runway)
        stat("Time", value: preview.durationHours, suffix: "h")
      }
      Spacer(minLength: 0)
      HStack {
        Button(completed ? "Done" : "Cancel", action: onDismiss)
          .buttonStyle(.bordered)
        Spacer()
        Button("Confirm", systemImage: "checkmark") {
          guard !completed, store.performEnvironmentalAction(action) else { return }
          completed = true
          settings.playFeedback(action == .rest ? .environmentalRest : .environmentalTraining)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!preview.available || completed)
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(preview.accessibilitySummary)
  }

  private func stat(_ title: String, value: Int, suffix: String = "") -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption2).foregroundStyle(.secondary)
      Text("\(value > 0 ? "+" : "")\(value)\(suffix)").font(.subheadline.weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
