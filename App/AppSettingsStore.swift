import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AppSettingsStore {
  var soundEffectsEnabled: Bool { didSet { defaults.set(soundEffectsEnabled, forKey: "solo.settings.soundEffects") } }
  var musicEnabled: Bool { didSet { defaults.set(musicEnabled, forKey: "solo.settings.musicEnabled"); updatePlayback() } }
  var musicVolume: Double { didSet { applyMusicGain(); defaults.set(musicVolume, forKey: "solo.settings.musicVolume") } }
  var ambienceVolume: Double { didSet { applyAmbienceGain(); defaults.set(ambienceVolume, forKey: "solo.settings.ambienceVolume") } }
  private(set) var musicName: String?
  private(set) var audioContext: AppAudioContext = .garage

  private let defaults: UserDefaults
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let ambiencePlayer = AVAudioPlayerNode()
  private let feedbackPlayer = AVAudioPlayerNode()
  private var audioFile: AVAudioFile?
  private var securityScopedURL: URL?
  private var ambienceScheduled = false
  private var feedbackDuckToken = UUID()
  private var garageCueDeduplicator = GarageAudioCueDeduplicator()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    soundEffectsEnabled = defaults.object(forKey: "solo.settings.soundEffects") as? Bool ?? true
    musicEnabled = defaults.bool(forKey: "solo.settings.musicEnabled")
    musicVolume = defaults.object(forKey: "solo.settings.musicVolume") as? Double ?? 0.55
    ambienceVolume = defaults.object(forKey: "solo.settings.ambienceVolume") as? Double ?? 0.32
    musicName = defaults.string(forKey: "solo.settings.musicName")
    engine.attach(player)
    engine.attach(ambiencePlayer)
    engine.attach(feedbackPlayer)
    engine.connect(player, to: engine.mainMixerNode, format: nil)
    engine.connect(ambiencePlayer, to: engine.mainMixerNode, format: nil)
    engine.connect(feedbackPlayer, to: engine.mainMixerNode, format: nil)
    applyMusicGain()
    applyAmbienceGain()
    restoreMusic()
    updateAmbiencePlayback()
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
    guard soundEffectsEnabled, audioContext != .background else { return }
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
    duckAmbience(for: kind.duration + 0.10)
  }

  /// Converts sanitized Garage presentation hooks into real local audio. The
  /// event token prevents view recomputation from stacking duplicate cues.
  func playGarageAudioHooks(_ hooks: FounderGarageAudioHookPresentation) {
    guard let cue = hooks.cues.first,
          garageCueDeduplicator.shouldPlay(token: hooks.eventToken, cue: cue) else { return }
    switch cue {
    case .monitorWake: playFeedback(.deviceWake)
    case .researchScanner, .buildActivity: playFeedback(.typing)
    case .campaignActivity: playFeedback(.scroll)
    case .reviewReady: playFeedback(.workComplete)
    case .garageVentilation, .serverHum, .equipmentCooling, .distantGarage: break
    }
  }

  func setAudioContext(_ context: AppAudioContext) {
    guard audioContext != context else { return }
    audioContext = context
    applyMusicGain()
    applyAmbienceGain()
    updatePlayback()
    updateAmbiencePlayback()
  }

  private func applyMusicGain() {
    player.volume = Float(musicVolume * audioContext.musicGain)
  }

  private func applyAmbienceGain(multiplier: Double = 1) {
    ambiencePlayer.volume = Float(ambienceVolume * audioContext.ambienceGain * multiplier)
  }

  private func updateAmbiencePlayback() {
    guard audioContext != .background, ambienceVolume > 0 else {
      ambiencePlayer.pause()
      return
    }
    if !engine.isRunning { try? engine.start() }
    if !ambienceScheduled {
      let format = engine.mainMixerNode.outputFormat(forBus: 0)
      guard let buffer = GarageAmbienceBuffer.make(format: format) else { return }
      ambiencePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
      ambienceScheduled = true
    }
    if !ambiencePlayer.isPlaying { ambiencePlayer.play() }
  }

  private func duckAmbience(for duration: TimeInterval) {
    let token = UUID()
    feedbackDuckToken = token
    applyAmbienceGain(multiplier: 0.34)
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(duration))
      guard feedbackDuckToken == token else { return }
      applyAmbienceGain()
    }
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
    guard musicEnabled, audioContext != .background, let audioFile else { player.pause(); return }
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

/// Stateful playback policy kept separate from AVAudioEngine so event
/// deduplication is deterministic and directly testable. An empty render pass
/// cannot consume a token before its audible cue arrives.
struct GarageAudioCueDeduplicator: Equatable, Sendable {
  private(set) var lastToken: UUID?
  private(set) var lastCue: FounderGarageAudioCue?

  mutating func shouldPlay(token: UUID?, cue: FounderGarageAudioCue) -> Bool {
    guard let token else { return false }
    guard token != lastToken || cue != lastCue else { return false }
    lastToken = token
    lastCue = cue
    return true
  }
}

enum AppAudioContext: Equatable, Sendable {
  case garage
  case companyCommand
  case founderReview
  case techCom
  case venture
  case companyServer
  case background

  var musicGain: Double {
    switch self {
    case .garage: 1
    case .companyCommand: 0.35
    case .founderReview: 0.18
    case .techCom: 0.48
    case .venture: 0.42
    case .companyServer: 0.30
    case .background: 0
    }
  }

  var ambienceGain: Double {
    switch self {
    case .garage: 1
    case .techCom: 0.34
    case .venture: 0.26
    case .companyServer: 0.42
    case .companyCommand: 0.20
    case .founderReview: 0.10
    case .background: 0
    }
  }
}

/// A deterministic, loop-safe blend of ventilation, server cooling, distant
/// room tone, electrical/network texture, and quiet Signal TV bleed. It is
/// synthesized locally, contains no copyrighted media, and consumes no RNG.
enum GarageAmbienceBuffer {
  static func make(format: AVAudioFormat, duration: Double = 4) -> AVAudioPCMBuffer? {
    guard format.sampleRate > 0, format.channelCount > 0 else { return nil }
    let frameCount = AVAudioFrameCount(format.sampleRate * duration)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
          let channels = buffer.floatChannelData else { return nil }
    buffer.frameLength = frameCount
    for frame in 0..<Int(frameCount) {
      let time = Double(frame) / format.sampleRate
      let loopPhase = 2 * Double.pi * time / duration
      let ventilation = sin(loopPhase * 5) * 0.018 + sin(loopPhase * 9) * 0.008
      let server = sin(2 * .pi * 73 * time) * 0.009 * (0.82 + 0.18 * sin(loopPhase * 2))
      let electrical = sin(2 * .pi * 121 * time) * 0.0035
      let network = sin(loopPhase * 17) * sin(2 * .pi * 233 * time) * 0.0018
      let tvBleed = sin(2 * .pi * 286 * time) * (0.0014 + 0.0008 * sin(loopPhase * 3))
      let room = sin(loopPhase) * 0.006
      let sample = Float(ventilation + server + electrical + network + tvBleed + room)
      for channel in 0..<Int(format.channelCount) { channels[channel][frame] = sample }
    }
    return buffer
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
  case companyCommandFocus
  case companyCommandClose
  case dispatch
  case workStart
  case workComplete
  case review
  case approval
  case revision
  case verificationRequest
  case shipAnyway
  case verificationSuccess
  case verificationWarning
  case resolutionLock
  case sprintCommit
  case financialWarning
  case infrastructureInstall
  case levelUp
  case chapterAdvance
  case coveragePositive
  case coverageNegative
  case environmentalRest
  case environmentalTraining
  case deviceWake
  case scroll
  case typing
  case buttonPress

  var frequency: Double {
    switch self {
    case .companyCommandFocus: 580
    case .companyCommandClose: 390
    case .dispatch: 520
    case .workStart: 590
    case .workComplete: 660
    case .review: 430
    case .approval: 820
    case .revision: 470
    case .verificationRequest: 610
    case .shipAnyway: 330
    case .verificationSuccess: 880
    case .verificationWarning: 260
    case .resolutionLock: 360
    case .sprintCommit: 740
    case .financialWarning: 220
    case .infrastructureInstall: 610
    case .levelUp: 920
    case .chapterAdvance: 820
    case .coveragePositive: 790
    case .coverageNegative: 310
    case .environmentalRest: 540
    case .environmentalTraining: 700
    case .deviceWake: 560
    case .scroll: 310
    case .typing: 680
    case .buttonPress: 460
    }
  }

  var duration: Double {
    switch self {
    case .verificationWarning, .resolutionLock, .coverageNegative, .financialWarning, .shipAnyway: 0.12
    default: 0.08
    }
  }

  var volume: Double { 0.10 }
}
