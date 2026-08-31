import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
  @Environment(AppSettingsStore.self) private var settings
  @State private var importingMusic = false
  @State private var importError: String?

  var body: some View {
    @Bindable var settings = settings
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Label("Feedback", systemImage: "speaker.wave.2.fill").font(.headline).foregroundStyle(SoloTheme.cyan)
        Toggle("Cash confirmations", isOn: $settings.soundEffectsEnabled)
        Text("Play a haptic and confirmation tone after a revenue-positive sprint.").font(.caption).foregroundStyle(.secondary)
        Slider(value: $settings.ambienceVolume, in: 0...1) {
          Text("Garage ambience volume")
        } minimumValueLabel: {
          Image(systemName: "speaker.slash.fill")
        } maximumValueLabel: {
          Image(systemName: "speaker.wave.3.fill")
        }
        Text("Controls local Garage room tone independently from music. Set to zero to mute ambience.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Divider()
        Label("Your Music", systemImage: "music.note").font(.headline).foregroundStyle(SoloTheme.cyan)
        Toggle("Play background music", isOn: $settings.musicEnabled).disabled(settings.musicName == nil)
        Slider(value: $settings.musicVolume, in: 0...1) { Text("Music volume") } minimumValueLabel: { Image(systemName: "speaker.fill") } maximumValueLabel: { Image(systemName: "speaker.wave.3.fill") }
        if let name = settings.musicName { Text(name).font(.caption).foregroundStyle(.secondary); Button("Remove Music", systemImage: "trash") { settings.clearMusic() }.buttonStyle(.bordered).tint(SoloTheme.coral) }
        Button("Choose Music", systemImage: "folder") { importingMusic = true }.buttonStyle(.borderedProminent).tint(SoloTheme.purple)
        Text("Choose an audio file from Files. Your selection stays private on this device.").font(.caption).foregroundStyle(.secondary)
      }
      .soloCard().padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationTitle("Settings")
    .fileImporter(isPresented: $importingMusic, allowedContentTypes: [.audio]) { result in
      do { try settings.chooseMusic(url: result.get()) } catch { importError = "That audio file could not be opened." }
    }
    .alert("Music Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("OK", role: .cancel) {} } message: { Text(importError ?? "") }
  }
}
