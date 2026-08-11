import SwiftUI

/// A read-only, live visual map of the founder's garage.
struct FounderGarageScene: View {
  var stations: [AgentStationViewModel]
  var facility: FacilityTier
  var motion: GarageMotionPolicy
  var date: Date
  @Binding var selectedStation: AgentStationViewModel?

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  @State private var focusedAgentID: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      garageCanvas
      cameraControls
      VStack(alignment: .leading, spacing: 5) {
        Text("The Founder's Garage")
          .font(.title3.weight(.bold))
        Text("Three agent bays and one founder's desk. This is a live, read-only workforce view; assignments happen in Command Deck.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      operationalBrief
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(red: 0.055, green: 0.067, blue: 0.09), in: .rect(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Label("FOUNDER GARAGE · LIVE VIEW", systemImage: facility.symbol)
        .font(.caption.weight(.bold))
        .foregroundStyle(SoloTheme.cyan)
      Spacer()
      Text("READ ONLY")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: Capsule())
    }
    .accessibilityElement(children: .combine)
  }

  private var garageCanvas: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack {
        garageShell
        ceilingBeams
        warmLighting
        founderDesk

        ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
          GarageBayStation(
            station: station,
            accent: accent(for: station, index: index),
            icon: bayIcon(for: station, index: index),
            date: date,
            motion: motion,
            isDimmed: focusedAgentID != nil && focusedAgentID != station.id,
            differentiateWithoutColor: differentiateWithoutColor
          ) {
            focusedAgentID = station.id
            selectedStation = station
          }
          .frame(width: size.width * bayWidth(for: index), height: size.height * 0.52)
          .position(x: size.width * bayX(for: index), y: size.height * bayY(for: index))
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 18))
      .overlay(alignment: .bottomLeading) {
        Label("Tap a station to inspect an agent", systemImage: "hand.tap.fill")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.white.opacity(0.72))
          .padding(9)
          .background(.black.opacity(0.28), in: Capsule())
          .padding(12)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      }
      .onChange(of: selectedStation) { _, next in
        if next == nil { focusedAgentID = nil }
      }
    }
    .frame(height: 500)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder Garage live workforce map")
  }

  private var garageShell: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.13, green: 0.15, blue: 0.19), Color(red: 0.055, green: 0.065, blue: 0.085)],
        startPoint: .top,
        endPoint: .bottom
      )
      VStack(spacing: 0) {
        Rectangle().fill(Color.clear).frame(height: 0)
        Spacer()
        Rectangle()
          .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.15), Color(red: 0.035, green: 0.045, blue: 0.06)], startPoint: .top, endPoint: .bottom))
          .frame(height: 112)
      }
      RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 90, endRadius: 310)
    }
  }

  private var ceilingBeams: some View {
    VStack(spacing: 27) {
      Rectangle().fill(Color(red: 0.16, green: 0.12, blue: 0.09)).frame(height: 7)
      Rectangle().fill(Color(red: 0.12, green: 0.09, blue: 0.07)).frame(height: 5)
      Spacer()
    }
    .opacity(0.8)
  }

  private var warmLighting: some View {
    HStack(spacing: 0) {
      ForEach(0..<4, id: \.self) { _ in
        VStack(spacing: 0) {
          Capsule().fill(Color(red: 0.9, green: 0.8, blue: 0.65)).frame(width: 22, height: 6)
          Circle().fill(Color.orange.opacity(0.14)).frame(width: 125, height: 80).blur(radius: 18)
        }
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
    .padding(.top, 12)
  }

  private var founderDesk: some View {
    VStack(spacing: 0) {
      Spacer()
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(red: 0.035, green: 0.055, blue: 0.075))
          .frame(width: 150, height: 86)
          .overlay {
            RoundedRectangle(cornerRadius: 5)
              .fill(Color(red: 0.06, green: 0.11, blue: 0.15))
              .padding(5)
              .overlay(alignment: .topLeading) {
                Capsule().fill(SoloTheme.cyan).frame(width: 31, height: 3).padding(13)
              }
          }
        VStack {
          Spacer().frame(height: 89)
          Rectangle().fill(Color(red: 0.13, green: 0.15, blue: 0.18)).frame(width: 18, height: 16)
          Capsule().fill(Color(red: 0.18, green: 0.21, blue: 0.25)).frame(width: 68, height: 6)
        }
      }
      GarageDeskShape()
        .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.28, blue: 0.17), Color(red: 0.20, green: 0.13, blue: 0.08)], startPoint: .top, endPoint: .bottom))
        .frame(height: 43)
        .padding(.horizontal, 42)
        .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
    }
    .padding(.bottom, 18)
  }

  private var cameraControls: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Array(stations.enumerated()), id: \.element.id) { index, station in
          Button {
            focusedAgentID = station.id
            selectedStation = station
          } label: {
            Label(station.name, systemImage: bayIcon(for: station, index: index))
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 11)
              .padding(.vertical, 8)
              .background(accent(for: station, index: index).opacity(0.14), in: Capsule())
          }
          .tint(accent(for: station, index: index))
          .buttonStyle(.plain)
          .accessibilityHint("Opens \(station.name)'s agent details")
        }
      }
    }
  }

  private var operationalBrief: some View {
    HStack(spacing: 8) {
      GarageBriefCard(title: "Headquarters", value: facility.name, color: Color.primary)
      GarageBriefCard(title: "Workforce", value: "\(stations.count) active", color: SoloTheme.mint)
      GarageBriefCard(title: "Facility effect", value: "Workstation XP", color: SoloTheme.cyan)
    }
  }

  private func accent(for station: AgentStationViewModel, index: Int) -> Color {
    switch station.agentID.lowercased() {
    case "aurora": SoloTheme.cyan
    case "stacks": SoloTheme.amber
    case "brio": SoloTheme.coral
    default: [SoloTheme.cyan, SoloTheme.amber, SoloTheme.coral][index % 3]
    }
  }

  private func bayIcon(for station: AgentStationViewModel, index: Int) -> String {
    switch station.agentID.lowercased() {
    case "aurora": "waveform.path.ecg"
    case "stacks": "server.rack"
    case "brio": "megaphone.fill"
    default: ["brain.head.profile", "cpu", "sparkles"][index % 3]
    }
  }

  private func bayX(for index: Int) -> CGFloat { [0.19, 0.72, 0.88][min(index, 2)] }
  private func bayY(for index: Int) -> CGFloat { [0.47, 0.39, 0.62][min(index, 2)] }
  private func bayWidth(for index: Int) -> CGFloat { index == 0 ? 0.44 : 0.34 }
}

private struct GarageBayStation: View {
  var station: AgentStationViewModel
  var accent: Color
  var icon: String
  var date: Date
  var motion: GarageMotionPolicy
  var isDimmed: Bool
  var differentiateWithoutColor: Bool
  var action: () -> Void

  private var motionOffset: CGFloat {
    guard motion == .active else { return 0 }
    let phase = GaragePhase.offset(identity: station.id, index: 0) * .pi * 2
    return CGFloat(sin(date.timeIntervalSinceReferenceDate * 1.8 + phase) * 2.5)
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        ZStack {
          Circle().fill(accent.opacity(0.22)).frame(width: 166, height: 142).blur(radius: 21)
          workstation
        }
        GarageStationTag(station: station, accent: accent, differentiateWithoutColor: differentiateWithoutColor)
      }
      .offset(y: motionOffset)
      .opacity(isDimmed ? 0.38 : 1)
      .animation(.smooth, value: isDimmed)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(station.name), level \(station.progression.level), \(station.progression.stressBand.label) stress")
    .accessibilityValue(station.accessibilityValue)
    .accessibilityHint("Opens read-only agent details")
  }

  private var workstation: some View {
    ZStack(alignment: .bottom) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(red: 0.12, green: 0.14, blue: 0.17))
        .frame(width: 142, height: 14)
        .offset(y: 28)
      HStack(alignment: .bottom, spacing: 8) {
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.black.opacity(0.72))
          .frame(width: 68, height: 50)
          .overlay {
            RoundedRectangle(cornerRadius: 3)
              .fill(accent.opacity(station.semanticState == .idle ? 0.20 : 0.42))
              .padding(4)
              .overlay {
                Image(systemName: icon).font(.caption).foregroundStyle(accent)
              }
          }
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.black.opacity(0.68))
          .frame(width: 43, height: 39)
          .overlay { Image(systemName: "chart.line.uptrend.xyaxis").font(.caption2).foregroundStyle(accent.opacity(0.85)) }
      }
      .offset(y: -3)
      ZStack {
        Circle().stroke(accent.opacity(0.75), lineWidth: 2).frame(width: 60, height: 60)
        Circle().fill(accent).frame(width: 42, height: 42)
        Text(station.initials).font(.headline.weight(.heavy)).foregroundStyle(Color.black.opacity(0.75))
      }
      .offset(y: -17)
    }
  }
}

private struct GarageStationTag: View {
  var station: AgentStationViewModel
  var accent: Color
  var differentiateWithoutColor: Bool

  var body: some View {
    VStack(spacing: 3) {
      HStack(spacing: 6) {
        Circle().fill(accent).frame(width: 7, height: 7)
        Text(station.name.uppercased()).font(.caption2.weight(.bold))
        Text("LV \(station.progression.level)").font(.caption2.monospaced())
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.black.opacity(0.72), in: Capsule())
      HStack(spacing: 4) {
        if differentiateWithoutColor { Image(systemName: stressSymbol) }
        Text(station.progression.stressBand.label.uppercased())
      }
      .font(.caption2.weight(.bold))
      .foregroundStyle(stressColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(.black.opacity(0.56), in: Capsule())
    }
  }

  private var stressColor: Color {
    switch station.progression.stressBand {
    case .focused: SoloTheme.mint
    case .stable: SoloTheme.cyan
    case .pressured: SoloTheme.amber
    case .overloaded: Color.orange
    case .critical: SoloTheme.coral
    }
  }

  private var stressSymbol: String {
    switch station.progression.stressBand {
    case .focused: "checkmark"
    case .stable: "circle"
    case .pressured: "exclamationmark.circle"
    case .overloaded, .critical: "exclamationmark.triangle"
    }
  }
}

private struct GarageBriefCard: View {
  var title: String
  var value: String
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
      Text(value).font(.caption.weight(.semibold)).foregroundStyle(color).lineLimit(2)
    }
    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    .padding(10)
    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct GarageDeskShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + 8, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
