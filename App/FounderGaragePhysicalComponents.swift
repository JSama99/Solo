import SwiftUI

enum FounderGarageStationKind: String, Equatable, Sendable {
  case research
  case engineering
  case campaign
}

/// A physical workstation assembled from independently animated leaves. It is
/// presentation-only and receives a sanitized station projection.
struct FounderGaragePhysicalStationView: View {
  var agent: LivingAgentProjection?
  var motion: FounderGarageStationMotion?
  var role: String
  var tone: Color
  var kind: FounderGarageStationKind
  var increasedContrast: Bool

  var body: some View {
    ZStack(alignment: .bottom) {
      localLightPool
      stationSupports
      physicalDisplays
        .offset(y: -92)
      portraitPresence
        .offset(y: -54)
      physicalDesk
      workflowControls
        .offset(y: 11)
      attentionIndicator
    }
    .frame(width: 242, height: 258)
    .accessibilityHidden(true)
  }

  private var isContinuouslyActive: Bool {
    motion?.continuousMotionEnabled == true
  }

  private var localLightPool: some View {
    ZStack {
      Ellipse()
        .fill(tone.opacity(0.09 + (motion?.localLightIntensity ?? 0.1) * 0.13))
        .frame(width: 244, height: 210)
        .blur(radius: 18)
        .offset(y: -34)
      Ellipse()
        .fill(tone.opacity(0.08 + (motion?.physical.portraitLightIntensity ?? 0.2) * 0.12))
        .frame(width: 170, height: 62)
        .blur(radius: 9)
        .offset(y: 12)
    }
  }

  private var stationSupports: some View {
    ZStack {
      HStack(spacing: 154) {
        RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.94)).frame(width: 10, height: 168)
        RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.94)).frame(width: 10, height: 168)
      }
      .offset(y: -28)
      Capsule().fill(.black.opacity(0.9)).frame(width: 200, height: 9).offset(y: -104)
      Path { path in
        path.move(to: CGPoint(x: 50, y: 174))
        path.addCurve(
          to: CGPoint(x: 126, y: 247),
          control1: CGPoint(x: 64, y: 207),
          control2: CGPoint(x: 108, y: 216)
        )
      }
      .stroke(tone.opacity(0.38), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
  }

  private var physicalDisplays: some View {
    HStack(alignment: .bottom, spacing: 7) {
      secondaryDisplay
      primaryDisplay
      coolingModule
    }
  }

  private var primaryDisplay: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(red: 0.025, green: 0.035, blue: 0.04))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(.white.opacity(increasedContrast ? 0.72 : 0.24), lineWidth: 2)
        }
        .shadow(color: tone.opacity(0.22), radius: 8, y: 4)
      roleDisplayContent
        .padding(7)
        .opacity(0.26 + (motion?.physical.primaryDisplayIntensity ?? 0.2) * 0.74)
      LinearGradient(
        colors: [.white.opacity(0.12), .clear],
        startPoint: .topLeading,
        endPoint: .center
      )
      .clipShape(.rect(cornerRadius: 7))
      .allowsHitTesting(false)
    }
    .frame(width: 98, height: 76)
    .overlay(alignment: .bottom) {
      RoundedRectangle(cornerRadius: 2).fill(.black).frame(width: 7, height: 17).offset(y: 14)
    }
  }

  private var secondaryDisplay: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.94))
      secondaryDisplayContent
        .padding(6)
        .opacity(0.20 + (motion?.physical.secondaryDisplayIntensity ?? 0.15) * 0.80)
    }
    .frame(width: 57, height: 55)
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(tone.opacity(0.48), lineWidth: 1) }
  }

  @ViewBuilder
  private var roleDisplayContent: some View {
    switch kind {
    case .research:
      ZStack {
        ForEach(0..<4, id: \.self) { index in
          Circle()
            .stroke(tone.opacity(0.42 + Double(index) * 0.10), lineWidth: 1)
            .frame(width: 12 + CGFloat(index) * 10)
            .offset(x: CGFloat(index - 2) * 8, y: CGFloat(index.isMultiple(of: 2) ? -8 : 7))
        }
        Capsule().fill(tone).frame(width: 72, height: 2)
          .phaseAnimator(isContinuouslyActive ? [-18.0, 18.0] : [0.0]) { content, y in
            content.offset(y: y)
          } animation: { _ in .linear(duration: 1.7) }
      }
    case .engineering:
      VStack(alignment: .leading, spacing: 5) {
        ForEach(0..<5, id: \.self) { line in
          HStack(spacing: 3) {
            Capsule().fill(tone.opacity(0.8)).frame(width: CGFloat(8 + line * 3), height: 2)
            Capsule().fill(.white.opacity(0.28)).frame(width: CGFloat(28 - line * 2), height: 2)
          }
          .phaseAnimator(isContinuouslyActive ? [0.42, 1.0] : [0.58]) { content, opacity in
            content.opacity(line.isMultiple(of: 2) ? opacity : 0.72)
          } animation: { _ in .easeInOut(duration: 0.72) }
        }
      }
    case .campaign:
      ZStack {
        Path { path in
          path.move(to: CGPoint(x: 6, y: 50))
          path.addCurve(
            to: CGPoint(x: 80, y: 10),
            control1: CGPoint(x: 26, y: 44),
            control2: CGPoint(x: 50, y: 17)
          )
        }
        .trim(from: 0, to: motion?.visibleProgress ?? 0.35)
        .stroke(tone, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ForEach(0..<4, id: \.self) { index in
          Circle().fill(tone.opacity(0.45 + Double(index) * 0.12)).frame(width: 6, height: 6)
            .offset(x: CGFloat(index * 19 - 29), y: CGFloat(20 - index * 9))
            .phaseAnimator(isContinuouslyActive ? [0.82, 1.14, 0.82] : [1.0]) { content, scale in
              content.scaleEffect(scale)
            } animation: { _ in .smooth(duration: 1.1) }
        }
      }
    }
  }

  @ViewBuilder
  private var secondaryDisplayContent: some View {
    switch kind {
    case .research:
      VStack(spacing: 4) {
        ForEach(0..<4, id: \.self) { index in
          RoundedRectangle(cornerRadius: 1)
            .fill(index <= Int((motion?.visibleProgress ?? 0) * 3) ? tone : .white.opacity(0.16))
            .frame(height: 4)
        }
      }
    case .engineering:
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(0..<5, id: \.self) { index in
          Capsule().fill(tone.opacity(0.55 + Double(index) * 0.08))
            .frame(width: 4, height: CGFloat(9 + index * 5))
        }
      }
    case .campaign:
      VStack(spacing: 4) {
        ForEach(0..<3, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 2).fill(tone.opacity(0.56)).frame(height: 9)
        }
      }
    }
  }

  private var coolingModule: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.92))
      Circle().stroke(.white.opacity(0.16), lineWidth: 1).frame(width: 29, height: 29)
      Image(systemName: "fanblades.fill")
        .font(.system(size: 17))
        .foregroundStyle(tone.opacity(0.38 + (motion?.physical.coolingActivity ?? 0) * 0.50))
        .phaseAnimator(motion?.physical.coolingActivity ?? 0 > 0.4 ? [0.0, 360.0] : [0.0]) { content, angle in
          content.rotationEffect(.degrees(angle))
        } animation: { _ in .linear(duration: 3.1) }
    }
    .frame(width: 42, height: 50)
    .overlay(alignment: .bottom) {
      HStack(spacing: 3) {
        ForEach(0..<3, id: \.self) { index in
          Circle().fill(index == 0 ? tone : .green.opacity(0.68)).frame(width: 3, height: 3)
        }
      }
      .padding(.bottom, 4)
    }
  }

  @ViewBuilder
  private var portraitPresence: some View {
    if let portrait = AgentPortraitAsset.name(for: agent?.agentID ?? "") {
      Image(portrait)
        .resizable()
        .scaledToFill()
        .frame(width: 102, height: 128)
        .clipShape(.rect(cornerRadius: 19))
        .overlay {
          LinearGradient(
            colors: [.clear, tone.opacity(0.08 + (motion?.physical.portraitLightIntensity ?? 0.2) * 0.18)],
            startPoint: .top,
            endPoint: .bottom
          )
          .clipShape(.rect(cornerRadius: 19))
        }
        .overlay { RoundedRectangle(cornerRadius: 19).stroke(tone.opacity(0.82), lineWidth: 2) }
        .shadow(color: tone.opacity(0.32), radius: 8)
        .phaseAnimator(motion?.physical.portraitMotionEnabled == true ? [0.0, 1.5, 0.0] : [0.0]) { content, y in
          content
            .offset(x: y * 0.35, y: y)
            .scaleEffect(1 + y * 0.0007)
        } animation: { _ in .easeInOut(duration: 3.6) }
    }
  }

  private var physicalDesk: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 7)
        .fill(Color(red: 0.12, green: 0.075, blue: 0.045))
        .frame(width: 216, height: 42)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.10)).frame(height: 2) }
        .shadow(color: .black.opacity(0.72), radius: 9, y: 8)
      HStack(spacing: 102) {
        Rectangle().fill(.black.opacity(0.94)).frame(width: 10, height: 48)
        Rectangle().fill(.black.opacity(0.94)).frame(width: 10, height: 48)
      }
      .offset(y: 31)
    }
  }

  private var workflowControls: some View {
    VStack(spacing: 5) {
      Text(role)
        .font(.system(size: 9, weight: .black, design: .rounded))
        .tracking(0.7)
        .foregroundStyle(tone)
      HStack(spacing: 5) {
        Circle()
          .fill(tone)
          .frame(width: 6, height: 6)
          .phaseAnimator(isContinuouslyActive ? [0.45, 1.0, 0.45] : [0.72]) { content, opacity in
            content.opacity(opacity)
          } animation: { _ in .easeInOut(duration: 1.2) }
        Text(agent?.activity.label ?? "Ready")
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(.white.opacity(0.78))
      }
      HStack(spacing: 5) {
        ForEach(0..<6, id: \.self) { index in
          RoundedRectangle(cornerRadius: 2)
            .fill(index <= Int((motion?.visibleProgress ?? 0) * 5) ? tone : .white.opacity(0.14))
            .frame(width: 20, height: 5)
        }
      }
      .frame(width: 162, height: 19)
      .background(.black.opacity(0.92), in: .rect(cornerRadius: 5))
    }
  }

  @ViewBuilder
  private var attentionIndicator: some View {
    if motion?.needsFounderAttention == true {
      Image(systemName: "tray.and.arrow.down.fill")
        .font(.caption.weight(.black))
        .foregroundStyle(tone)
        .padding(8)
        .background(.black.opacity(0.90), in: Circle())
        .overlay { Circle().stroke(tone.opacity(0.72), lineWidth: 2) }
        .offset(x: 96, y: -69)
        .phaseAnimator([0.94, 1.08, 0.94], trigger: motion?.eventToken) { content, scale in
          content.scaleEffect(scale)
        } animation: { _ in .smooth(duration: 0.28) }
    }
  }
}

struct FounderGarageTaskArtifactView: View {
  var tone: Color
  var state: FounderGarageArtifactState
  var progress: Double
  var reduceMotion: Bool
  var eventToken: UUID?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4)
        .fill(.black.opacity(0.90))
      RoundedRectangle(cornerRadius: 4)
        .stroke(tone.opacity(0.82), lineWidth: 1.5)
      Image(systemName: symbol)
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(tone)
    }
    .frame(width: 30, height: 21)
    .overlay(alignment: .bottom) {
      Capsule().fill(tone).frame(width: 22 * progress, height: 2).offset(y: 4)
    }
    .phaseAnimator(reduceMotion ? [1.0] : [0.92, 1.04, 1.0], trigger: eventToken) { content, scale in
      content.scaleEffect(scale)
    } animation: { _ in .smooth(duration: 0.25) }
    .accessibilityHidden(true)
  }

  private var symbol: String {
    switch state {
    case .none: "doc"
    case .inboundTask: "arrow.down.doc.fill"
    case .assembling: "doc.badge.gearshape.fill"
    case .returnedForReview: "tray.and.arrow.down.fill"
    }
  }
}
