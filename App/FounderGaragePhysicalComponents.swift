import SwiftUI

enum FounderGarageStationKind: String, Equatable, Sendable {
  case research
  case engineering
  case campaign
}

enum FounderGarageMaterial {
  static let powderCoat = Color(red: 0.035, green: 0.040, blue: 0.045)
  static let raisedMetal = Color(red: 0.075, green: 0.082, blue: 0.088)
  static let deskTop = Color(red: 0.24, green: 0.15, blue: 0.09)
  static let deskFront = Color(red: 0.095, green: 0.052, blue: 0.032)
  static let materialEdge = Color.white.opacity(0.16)
}

private struct FounderGarageStationComposition {
  var width: CGFloat
  var height: CGFloat
  var deskWidth: CGFloat
  var portraitSize: CGSize
  var portraitOffset: CGSize
  var displayOffset: CGSize
  var chairSize: CGSize
  var monitorAngle: Double

  static func make(_ kind: FounderGarageStationKind) -> Self {
    switch kind {
    case .research:
      Self(
        width: 258,
        height: 272,
        deskWidth: 226,
        portraitSize: CGSize(width: 122, height: 151),
        portraitOffset: CGSize(width: 24, height: -26),
        displayOffset: CGSize(width: -13, height: -38),
        chairSize: CGSize(width: 88, height: 116),
        monitorAngle: -1.4
      )
    case .engineering:
      Self(
        width: 286,
        height: 282,
        deskWidth: 246,
        portraitSize: CGSize(width: 132, height: 160),
        portraitOffset: CGSize(width: -28, height: -23),
        displayOffset: CGSize(width: 24, height: -40),
        chairSize: CGSize(width: 94, height: 121),
        monitorAngle: 1.2
      )
    case .campaign:
      Self(
        width: 264,
        height: 272,
        deskWidth: 230,
        portraitSize: CGSize(width: 126, height: 154),
        portraitOffset: CGSize(width: -17, height: -25),
        displayOffset: CGSize(width: 18, height: -38),
        chairSize: CGSize(width: 90, height: 116),
        monitorAngle: 0.8
      )
    }
  }
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

  private var composition: FounderGarageStationComposition { .make(kind) }

  var body: some View {
    ZStack(alignment: .bottom) {
      contactShadow
      localLightPool
      wallBackboard
      stationSupports
      chairSilhouette
      agentContactShadow
      portraitPresence
        .offset(x: composition.portraitOffset.width, y: composition.portraitOffset.height)
      physicalDisplays
        .offset(x: composition.displayOffset.width, y: composition.displayOffset.height)
      physicalDesk
      deskLightReflection
      deskObjects
        .offset(y: -31)
      artifactDock
      workflowControls
        .offset(y: 11)
      attentionIndicator
    }
    .frame(width: composition.width, height: composition.height)
    .accessibilityHidden(true)
  }

  private var stationWidth: CGFloat {
    composition.width
  }

  private var stationHeight: CGFloat {
    composition.height
  }

  private var portraitOffset: CGFloat {
    composition.portraitOffset.width
  }

  private var displayOffset: CGFloat {
    composition.displayOffset.width
  }

  private var isContinuouslyActive: Bool {
    motion?.continuousMotionEnabled == true
  }

  private var perceivedLightBalance: Double {
    switch kind {
    case .research: 0.94
    case .engineering: 0.88
    case .campaign: 0.76
    }
  }

  private var localLightPool: some View {
    ZStack {
      RadialGradient(
        colors: [tone.opacity((0.07 + (motion?.localLightIntensity ?? 0.1) * 0.12) * perceivedLightBalance), tone.opacity(0.018 * perceivedLightBalance), .clear],
        center: .center,
        startRadius: 4,
        endRadius: 128
      )
      .frame(width: stationWidth, height: 226)
      .offset(y: -34)
      RadialGradient(
        colors: [tone.opacity((0.06 + (motion?.physical.portraitLightIntensity ?? 0.2) * 0.10) * perceivedLightBalance), .clear],
        center: .center,
        startRadius: 3,
        endRadius: 92
      )
      .frame(width: 190, height: 82)
      .offset(y: 10)
    }
  }

  private var contactShadow: some View {
    Ellipse()
      .fill(.black.opacity(0.58))
      .frame(width: stationWidth * 0.92, height: 23)
      .offset(x: 9, y: 7)
  }

  private var wallBackboard: some View {
    ZStack {
      switch kind {
      case .research:
        RoundedRectangle(cornerRadius: 5)
          .fill(FounderGarageMaterial.raisedMetal.opacity(0.80))
          .frame(width: 210, height: 142)
          .overlay {
            HStack(spacing: 19) {
              ForEach(0..<4, id: \.self) { _ in
                VStack(spacing: 11) {
                  ForEach(0..<6, id: \.self) { _ in Circle().fill(.white.opacity(0.10)).frame(width: 2, height: 2) }
                }
              }
            }
          }
      case .engineering:
        HStack(spacing: 7) {
          ForEach(0..<4, id: \.self) { index in
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.black.opacity(0.72))
              .frame(width: 48, height: CGFloat(112 + index % 2 * 20))
              .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                  ForEach(0..<5, id: \.self) { led in
                    Capsule().fill(led == index ? tone.opacity(0.72) : .white.opacity(0.10)).frame(width: 28, height: 2)
                  }
                }
                .padding(.bottom, 10)
              }
          }
        }
      case .campaign:
        HStack(spacing: 7) {
          ForEach(0..<3, id: \.self) { index in
            RoundedRectangle(cornerRadius: 7)
              .fill(FounderGarageMaterial.powderCoat.opacity(0.94))
              .frame(width: 62, height: index == 1 ? 128 : 104)
              .overlay {
                RoundedRectangle(cornerRadius: 5)
                  .fill(tone.opacity(index == 1 ? 0.10 : 0.055))
                  .padding(5)
                  .overlay {
                    Image(systemName: index == 1 ? "waveform" : "dot.radiowaves.left.and.right")
                      .foregroundStyle(tone.opacity(0.34))
                  }
              }
              .overlay { RoundedRectangle(cornerRadius: 7).stroke(FounderGarageMaterial.materialEdge, lineWidth: 1) }
          }
        }
      }
    }
    .offset(y: -75)
    .overlay(alignment: .topTrailing) {
      ZStack {
        Capsule().fill(.black.opacity(0.82)).frame(width: 58, height: 9)
        Capsule().fill(tone.opacity(0.52)).frame(width: 44, height: 3)
      }
      .offset(x: -12, y: -151)
      .shadow(color: tone.opacity(0.14), radius: 5, y: 4)
    }
  }

  private var chairSilhouette: some View {
    ZStack {
      Ellipse()
        .fill(.black.opacity(0.48))
        .frame(width: composition.chairSize.width + 28, height: 18)
        .offset(y: 87)
      RoundedRectangle(cornerRadius: 24)
        .fill(FounderGarageMaterial.powderCoat.opacity(0.96))
        .frame(width: composition.chairSize.width, height: composition.chairSize.height)
        .overlay {
          RoundedRectangle(cornerRadius: 24)
            .stroke(FounderGarageMaterial.materialEdge, lineWidth: increasedContrast ? 2 : 1)
        }
      Capsule().fill(.white.opacity(0.06)).frame(width: 45, height: 3).offset(y: -41)
      HStack(spacing: composition.chairSize.width - 24) {
        Capsule().fill(FounderGarageMaterial.raisedMetal).frame(width: 9, height: 38)
        Capsule().fill(FounderGarageMaterial.raisedMetal).frame(width: 9, height: 38)
      }
      .offset(y: 28)
      Ellipse().fill(FounderGarageMaterial.raisedMetal).frame(width: 72, height: 22).offset(y: 49)
      Rectangle().fill(.black.opacity(0.90)).frame(width: 8, height: 51).offset(y: 79)
    }
    .offset(x: composition.portraitOffset.width * 0.62, y: -18)
  }

  private var agentContactShadow: some View {
    Ellipse()
      .fill(.black.opacity(0.44))
      .frame(width: composition.portraitSize.width * 0.92, height: 18)
      .offset(x: composition.portraitOffset.width + 5, y: -4)
  }

  private var stationSupports: some View {
    ZStack {
      HStack(spacing: 154) {
        RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.94)).frame(width: 10, height: 168)
        RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.94)).frame(width: 10, height: 168)
      }
      .offset(y: -28)
      Capsule().fill(FounderGarageMaterial.powderCoat).frame(width: 200, height: 9).offset(y: -104)
      Path { path in
        path.move(to: CGPoint(x: 50, y: 174))
        path.addCurve(
          to: CGPoint(x: 126, y: 247),
          control1: CGPoint(x: 64, y: 207),
          control2: CGPoint(x: 108, y: 216)
        )
      }
      .stroke(FounderGarageMaterial.raisedMetal.opacity(0.88), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      Path { path in
        path.move(to: CGPoint(x: 125, y: 84))
        path.addCurve(to: CGPoint(x: 176, y: 211), control1: CGPoint(x: 152, y: 122), control2: CGPoint(x: 135, y: 182))
      }
      .stroke(.black.opacity(0.88), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
  }

  @ViewBuilder
  private var physicalDisplays: some View {
    switch kind {
    case .research:
      HStack(alignment: .bottom, spacing: 7) {
        secondaryDisplay
        primaryDisplay
        researchScanner
      }
    case .engineering:
      HStack(alignment: .bottom, spacing: 7) {
        secondaryDisplay
        primaryDisplay
        coolingModule
      }
    case .campaign:
      HStack(alignment: .bottom, spacing: 7) {
        primaryDisplay
        secondaryDisplay
        broadcastModule
      }
    }
  }

  private var primaryDisplay: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(.black.opacity(0.66))
        .offset(x: 5, y: 6)
      RoundedRectangle(cornerRadius: 8)
        .fill(FounderGarageMaterial.powderCoat)
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(.white.opacity(increasedContrast ? 0.72 : 0.24), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.62), radius: 5, y: 5)
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
    .frame(width: kind == .engineering ? 106 : 100, height: kind == .engineering ? 80 : 76)
    .rotationEffect(.degrees(composition.monitorAngle))
    .overlay(alignment: .bottom) {
      VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 2).fill(FounderGarageMaterial.powderCoat).frame(width: 8, height: 18)
        Capsule().fill(FounderGarageMaterial.raisedMetal).frame(width: 46, height: 6)
      }
      .offset(y: 20)
    }
  }

  private var secondaryDisplay: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6).fill(FounderGarageMaterial.powderCoat)
      secondaryDisplayContent
        .padding(6)
        .opacity(0.20 + (motion?.physical.secondaryDisplayIntensity ?? 0.15) * 0.80)
    }
    .frame(width: 57, height: 55)
    .overlay { RoundedRectangle(cornerRadius: 6).stroke(FounderGarageMaterial.materialEdge, lineWidth: increasedContrast ? 2 : 1) }
    .overlay(alignment: .bottom) {
      RoundedRectangle(cornerRadius: 1).fill(FounderGarageMaterial.raisedMetal).frame(width: 7, height: 13).offset(y: 12)
    }
  }

  private var researchScanner: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(FounderGarageMaterial.powderCoat)
      VStack(spacing: 5) {
        Capsule().fill(tone.opacity(0.50)).frame(width: 27, height: 2)
        Image(systemName: "viewfinder")
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(tone.opacity(0.42))
      }
    }
    .frame(width: 42, height: 50)
    .overlay { RoundedRectangle(cornerRadius: 5).stroke(FounderGarageMaterial.materialEdge, lineWidth: 1) }
  }

  private var broadcastModule: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(FounderGarageMaterial.powderCoat)
      VStack(spacing: 5) {
        Image(systemName: "antenna.radiowaves.left.and.right")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(tone.opacity(0.42))
        HStack(spacing: 3) {
          ForEach(0..<3, id: \.self) { index in
            Circle().fill(index == 1 ? tone.opacity(0.62) : .white.opacity(0.14)).frame(width: 3, height: 3)
          }
        }
      }
    }
    .frame(width: 42, height: 50)
    .overlay { RoundedRectangle(cornerRadius: 5).stroke(FounderGarageMaterial.materialEdge, lineWidth: 1) }
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
      RoundedRectangle(cornerRadius: 5).fill(FounderGarageMaterial.powderCoat)
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
      ZStack {
        Image(portrait)
          .resizable()
          .scaledToFit()
          .frame(width: composition.portraitSize.width, height: composition.portraitSize.height)
          .shadow(color: .black.opacity(0.64), radius: 5, x: 6, y: 7)
        LinearGradient(
          colors: [
            .clear,
            tone.opacity((0.05 + (motion?.physical.portraitEdgeLightIntensity ?? 0.2) * 0.16) * perceivedLightBalance)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .mask {
          Image(portrait)
            .resizable()
            .scaledToFit()
            .frame(width: composition.portraitSize.width, height: composition.portraitSize.height)
        }
        LinearGradient(
          colors: [
            .clear,
            tone.opacity((0.03 + (motion?.physical.portraitLightIntensity ?? 0.2) * 0.13) * perceivedLightBalance)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .mask {
          Image(portrait)
            .resizable()
            .scaledToFit()
            .frame(width: composition.portraitSize.width, height: composition.portraitSize.height)
        }
      }
      .offset(y: motion?.physical.postureOffsetY ?? 0)
      .scaleEffect(motion?.physical.postureScale ?? 1, anchor: .bottom)
      .phaseAnimator(motion?.physical.portraitMotionEnabled == true ? [0.0, motion?.physical.breathingAmplitude ?? 0, 0.0] : [0.0]) { content, y in
          content
            .offset(x: y * 0.12, y: y)
            .scaleEffect(1 + y * 0.00045, anchor: .bottom)
      } animation: { _ in .easeInOut(duration: 4.4) }
    }
  }

  private var physicalDesk: some View {
    ZStack(alignment: .top) {
      Path { path in
        path.move(to: CGPoint(x: 13, y: 0))
        path.addLine(to: CGPoint(x: composition.deskWidth - 14, y: 0))
        path.addLine(to: CGPoint(x: composition.deskWidth, y: 43))
        path.addLine(to: CGPoint(x: 0, y: 43))
        path.closeSubpath()
      }
      .fill(LinearGradient(
        colors: [FounderGarageMaterial.deskTop, FounderGarageMaterial.deskFront],
        startPoint: .top,
        endPoint: .bottom
      ))
      .frame(width: composition.deskWidth, height: 43)
      .overlay(alignment: .top) { Rectangle().fill(FounderGarageMaterial.materialEdge).frame(width: composition.deskWidth - 24, height: increasedContrast ? 2 : 1) }
      .shadow(color: .black.opacity(0.72), radius: 7, y: 8)
      HStack(spacing: composition.deskWidth - 86) {
        Rectangle().fill(.black.opacity(0.94)).frame(width: 11, height: 55).rotationEffect(.degrees(3))
        Rectangle().fill(.black.opacity(0.94)).frame(width: 11, height: 55).rotationEffect(.degrees(-3))
      }
      .offset(y: 31)
      Circle()
        .fill(.black.opacity(0.76))
        .frame(width: 8, height: 8)
        .offset(x: composition.deskWidth * 0.33, y: 8)
    }
  }

  private var deskLightReflection: some View {
    LinearGradient(
      colors: [.clear, tone.opacity((0.04 + (motion?.physical.deskLightIntensity ?? 0.2) * 0.12) * perceivedLightBalance), .clear],
      startPoint: .leading,
      endPoint: .trailing
    )
    .frame(width: composition.deskWidth - 30, height: 3)
    .offset(x: composition.displayOffset.width * 0.35, y: -20)
  }

  @ViewBuilder
  private var deskObjects: some View {
    HStack(alignment: .bottom, spacing: 8) {
      switch kind {
      case .research:
        RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.76, green: 0.69, blue: 0.46)).frame(width: 29, height: 22)
          .overlay { VStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(.black.opacity(0.30)).frame(width: 19, height: 1) } } }
        Image(systemName: "externaldrive.connected.to.line.below.fill").font(.caption).foregroundStyle(tone.opacity(0.62))
        Spacer().frame(width: 55)
      case .engineering:
        HStack(spacing: 3) {
          ForEach(0..<3, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2).fill(index == 1 ? tone.opacity(0.48) : .gray.opacity(0.36)).frame(width: 21, height: CGFloat(12 + index * 3))
          }
        }
        Image(systemName: "screwdriver.fill").font(.caption2).foregroundStyle(.white.opacity(0.46)).rotationEffect(.degrees(20))
        Spacer().frame(width: 36)
      case .campaign:
        Image(systemName: "waveform.path.ecg.rectangle.fill").font(.title3).foregroundStyle(tone.opacity(0.58))
        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.16)).frame(width: 37, height: 24)
          .overlay { Image(systemName: "play.fill").font(.system(size: 8)).foregroundStyle(tone) }
        Spacer().frame(width: 44)
      }
    }
    .frame(width: 190, alignment: .leading)
  }

  @ViewBuilder
  private var artifactDock: some View {
    if let physical = motion?.physical, physical.artifactState != .none {
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(FounderGarageMaterial.powderCoat)
          .frame(width: 42, height: 27)
        FounderGarageTaskArtifactView(
          tone: tone,
          state: physical.artifactState,
          progress: physical.artifactProgress,
          reduceMotion: motion?.continuousMotionEnabled != true,
          eventToken: motion?.eventToken
        )
        .scaleEffect(0.74)
      }
      .overlay(alignment: .bottom) {
        Capsule().fill(tone.opacity(0.46)).frame(width: 25, height: 2).offset(y: 3)
      }
      .offset(x: -composition.deskWidth * 0.27, y: -28)
    }
  }

  private var workflowControls: some View {
    VStack(spacing: 5) {
      Text(role)
        .font(.system(size: 9, weight: .black, design: .rounded))
        .tracking(0.7)
        .foregroundStyle(.white.opacity(0.68))
      HStack(spacing: 5) {
        Circle()
          .fill(tone.opacity(0.66))
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
            .frame(width: 20, height: 4)
        }
      }
      .frame(width: 162, height: 19)
      .background(FounderGarageMaterial.powderCoat.opacity(0.96), in: .rect(cornerRadius: 5))
      .overlay { RoundedRectangle(cornerRadius: 5).stroke(FounderGarageMaterial.materialEdge, lineWidth: 1) }
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
        .fill(FounderGarageMaterial.raisedMetal.opacity(0.96))
      RoundedRectangle(cornerRadius: 4)
        .stroke(FounderGarageMaterial.materialEdge, lineWidth: 1)
      Image(systemName: symbol)
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(tone.opacity(0.72))
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
