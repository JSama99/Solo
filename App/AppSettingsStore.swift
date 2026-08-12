import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AppSettingsStore {
  var soundEffectsEnabled: Bool { didSet { defaults.set(soundEffectsEnabled, forKey: "solo.settings.soundEffects") } }
  var musicEnabled: Bool { didSet { defaults.set(musicEnabled, forKey: "solo.settings.musicEnabled"); updatePlayback() } }
  var musicVolume: Double { didSet { player.volume = Float(musicVolume); defaults.set(musicVolume, forKey: "solo.settings.musicVolume") } }
  private(set) var musicName: String?

  private let defaults: UserDefaults
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private var audioFile: AVAudioFile?
  private var securityScopedURL: URL?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    soundEffectsEnabled = defaults.object(forKey: "solo.settings.soundEffects") as? Bool ?? true
    musicEnabled = defaults.bool(forKey: "solo.settings.musicEnabled")
    musicVolume = defaults.object(forKey: "solo.settings.musicVolume") as? Double ?? 0.55
    musicName = defaults.string(forKey: "solo.settings.musicName")
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: nil)
    player.volume = Float(musicVolume)
    restoreMusic()
  }

  func chooseMusic(url: URL) throws {
    let granted = url.startAccessingSecurityScopedResource()
    defer { if !granted { url.stopAccessingSecurityScopedResource() } }
    let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    defaults.set(bookmark, forKey: "solo.settings.musicBookmark")
    defaults.set(url.lastPathComponent, forKey: "solo.settings.musicName")
    load(url: url, retainAccess: granted)
    updatePlayback()
  }

  func clearMusic() {
    player.stop()
    securityScopedURL?.stopAccessingSecurityScopedResource()
    securityScopedURL = nil
    audioFile = nil
    musicName = nil
    defaults.removeObject(forKey: "solo.settings.musicBookmark")
    defaults.removeObject(forKey: "solo.settings.musicName")
  }

  private func restoreMusic() {
    guard let data = defaults.data(forKey: "solo.settings.musicBookmark") else { return }
    var stale = false
    guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return }
    let granted = url.startAccessingSecurityScopedResource()
    load(url: url, retainAccess: granted)
    updatePlayback()
  }

  private func load(url: URL, retainAccess: Bool) {
    player.stop()
    securityScopedURL?.stopAccessingSecurityScopedResource()
    securityScopedURL = retainAccess ? url : nil
    audioFile = try? AVAudioFile(forReading: url)
    musicName = url.lastPathComponent
  }

  private func updatePlayback() {
    guard musicEnabled, let audioFile else { player.pause(); return }
    if !engine.isRunning { try? engine.start() }
    guard !player.isPlaying else { return }
    scheduleLoop(audioFile)
    player.play()
  }

  private func scheduleLoop(_ file: AVAudioFile) {
    player.scheduleFile(file, at: nil) { [weak self] in
      Task { @MainActor in
        guard let self, self.musicEnabled, let file = self.audioFile else { return }
        self.scheduleLoop(file)
      }
    }
  }
}
