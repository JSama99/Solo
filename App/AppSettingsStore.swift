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
  private let feedbackPlayer = AVAudioPlayerNode()
  private var audioFile: AVAudioFile?
  private var securityScopedURL: URL?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    soundEffectsEnabled = defaults.object(forKey: "solo.settings.soundEffects") as? Bool ?? true
    musicEnabled = defaults.bool(forKey: "solo.settings.musicEnabled")
    musicVolume = defaults.object(forKey: "solo.settings.musicVolume") as? Double ?? 0.55
    musicName = defaults.string(forKey: "solo.settings.musicName")
    engine.attach(player)
    engine.attach(feedbackPlayer)
    engine.connect(player, to: engine.mainMixerNode, format: nil)
    engine.connect(feedbackPlayer, to: engine.mainMixerNode, format: nil)
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

  /// Plays a short synthesized confirmation. No audio asset, network access,
  /// randomness, or simulation timing is involved.
  func playFeedback(_ kind: GameFeedbackKind) {
    guard soundEffectsEnabled else { return }
    if !engine.isRunning {
      do {
        try engine.start()
      } catch {
        return
      }
    }
    let format = feedbackPlayer.outputFormat(forBus: 0)
    guard let buffer = FeedbackToneBuffer.make(kind: kind, format: format) else { return }
    feedbackPlayer.stop()
    feedbackPlayer.scheduleBuffer(buffer)
    feedbackPlayer.play()
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

enum FeedbackToneBuffer {
  static func make(kind: GameFeedbackKind, format: AVAudioFormat) -> AVAudioPCMBuffer? {
    guard format.sampleRate > 0, format.channelCount > 0 else { return nil }
    let frameCount = AVAudioFrameCount(format.sampleRate * kind.duration)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
          let channels = buffer.floatChannelData else { return nil }
    buffer.frameLength = frameCount
    for frame in 0..<Int(frameCount) {
      let progress = Double(frame) / Double(max(1, Int(frameCount) - 1))
      let envelope = sin(.pi * progress) * kind.volume
      let sample = Float(sin(2 * .pi * kind.frequency * Double(frame) / format.sampleRate) * envelope)
      for channel in 0..<Int(format.channelCount) {
        channels[channel][frame] = sample
      }
    }
    return buffer
  }
}

enum GameFeedbackKind {
  case dispatch
  case workComplete
  case review
  case verificationSuccess
  case verificationWarning
  case resolutionLock
  case sprintCommit
  case infrastructureInstall
  case levelUp
  case chapterAdvance
  case coveragePositive
  case coverageNegative

  var frequency: Double {
    switch self {
    case .dispatch: 520
    case .workComplete: 660
    case .review: 430
    case .verificationSuccess: 880
    case .verificationWarning: 260
    case .resolutionLock: 360
    case .sprintCommit: 740
    case .infrastructureInstall: 610
    case .levelUp: 920
    case .chapterAdvance: 820
    case .coveragePositive: 790
    case .coverageNegative: 310
    }
  }

  var duration: Double {
    switch self {
    case .verificationWarning, .resolutionLock, .coverageNegative: 0.12
    default: 0.08
    }
  }

  var volume: Double { 0.10 }
}
