import SwiftUI

struct CareerOutcomeEnvironmentBackdrop: View {
  var kind: CareerOutcomeKind

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      ZStack {
        SoloTheme.background.ignoresSafeArea()
        treatment(time: time)
      }
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func treatment(time: TimeInterval) -> some View {
    switch CareerEnvironmentTreatment(kind) {
    case .victory:
      victory(time: time)
    case .bankruptcy:
      bankruptcy(time: time)
    case .burnout:
      burnout(time: time)
    case .trustCollapse:
      trustCollapse(time: time)
    }
  }

  private func victory(time: TimeInterval) -> some View {
    let breath = OutcomeBackdropMotion.breathe(time: time, cycle: 7, reduceMotion: reduceMotion)
    let sweep = OutcomeBackdropMotion.sweep(time: time, cycle: 5)
    return GeometryReader { geometry in
      ZStack {
        LinearGradient(
          colors: [
            SoloTheme.cyan.opacity(0.12 + breath * 0.08),
            SoloTheme.amber.opacity(0.08 + breath * 0.04),
            Color.red.opacity(0.08),
            .clear
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        Rectangle()
          .fill(
            LinearGradient(
              colors: [.clear, .white.opacity(0.09), .clear],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: geometry.size.width * 0.34)
          .rotationEffect(.degrees(24))
          .offset(x: CGFloat((sweep * 1.8 - 0.4) * Double(geometry.size.width)))
          .blur(radius: 18)
      }
    }
    .ignoresSafeArea()
  }

  private func bankruptcy(time: TimeInterval) -> some View {
    let breath = OutcomeBackdropMotion.breathe(time: time, cycle: 9, reduceMotion: reduceMotion)
    return LinearGradient(
      colors: [.black.opacity(0.78 + breath * 0.08), SoloTheme.background],
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }

  private func burnout(time: TimeInterval) -> some View {
    let breath = OutcomeBackdropMotion.breathe(time: time, cycle: 4.4, reduceMotion: reduceMotion)
    return GeometryReader { geometry in
      RadialGradient(
        colors: [SoloTheme.amber.opacity(0.07 + breath * 0.05), SoloTheme.background.opacity(0.95)],
        center: .bottom,
        startRadius: 20,
        endRadius: CGFloat(330 + breath * 38)
      )
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .ignoresSafeArea()
  }

  private func trustCollapse(time: TimeInterval) -> some View {
    let tremor = OutcomeBackdropMotion.tremor(
      time: time,
      rate: 3.2,
      amplitude: 1.4,
      reduceMotion: reduceMotion
    )
    let flicker = OutcomeBackdropMotion.breathe(
      time: time,
      cycle: 2,
      reduceMotion: reduceMotion,
      resting: 0.5
    )
    return ZStack {
      SoloTheme.background
      Path { path in
        path.move(to: CGPoint(x: 25, y: 80))
        path.addLine(to: CGPoint(x: 170, y: 210))
        path.addLine(to: CGPoint(x: 110, y: 380))
        path.move(to: CGPoint(x: 360, y: 120))
        path.addLine(to: CGPoint(x: 210, y: 250))
        path.addLine(to: CGPoint(x: 300, y: 430))
      }
      .stroke(
        SoloTheme.amber.opacity(0.16 + flicker * 0.1),
        style: StrokeStyle(lineWidth: 2, dash: [8, 10])
      )
      .offset(x: CGFloat(tremor))
    }
    .ignoresSafeArea()
  }
}

enum OutcomeBackdropMotion {
  /// A `0...1` oscillation. Reduce Motion returns `resting`, so callers need
  /// no Reduce Motion branch of their own.
  static func breathe(
    time: TimeInterval,
    cycle: Double,
    reduceMotion: Bool,
    resting: Double = 1
  ) -> Double {
    guard !reduceMotion, cycle > 0 else { return resting }
    return 0.5 + 0.5 * sin(2 * .pi * time / cycle)
  }

  /// A repeating `0..<1` ramp for one-directional sweeps.
  static func sweep(time: TimeInterval, cycle: Double) -> Double {
    guard cycle > 0 else { return 0 }
    let position = time.truncatingRemainder(dividingBy: cycle) / cycle
    return position < 0 ? position + 1 : position
  }

  /// Small sinusoidal jitter. Reduce Motion silences it entirely rather than
  /// dampening it — a tremor is exactly the register Reduce Motion removes.
  static func tremor(
    time: TimeInterval,
    rate: Double,
    amplitude: Double,
    reduceMotion: Bool
  ) -> Double {
    guard !reduceMotion else { return 0 }
    return sin(2 * .pi * time * rate) * amplitude
  }
}
