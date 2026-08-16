import SwiftUI

/// The fixed, illustrated three-bay version of the founder's garage.
///
/// The artwork deliberately shares `GarageStationTag` with the scalable
/// fallback so station identity, level, and stress semantics remain identical.
struct FounderGarageIllustration: View {
  var stations: [AgentStationViewModel]
  var date: Date
  var motion: GarageMotionPolicy
  var gate: GarageTurnGate
  var focusedAgentID: String?
  var deskIsPrimary: Bool
  var differentiateWithoutColor: Bool
  var onSelectStation: (AgentStationViewModel) -> Void
  var onSelectDesk: () -> Void

  private let sceneSize = CGSize(width: 1600, height: 900)
  private static let bays = [
    BayLayout(agentID: "aurora", hitRect: CGRect(x: 0, y: 180, width: 400, height: 460), avatar: CGPoint(x: 150, y: 455), radius: 36),
    BayLayout(agentID: "stacks", hitRect: CGRect(x: 1020, y: 240, width: 340, height: 380), avatar: CGPoint(x: 1185, y: 448), radius: 34),
    BayLayout(agentID: "brio", hitRect: CGRect(x: 1360, y: 320, width: 240, height: 360), avatar: CGPoint(x: 1400, y: 552), radius: 32)
  ]
  private static let deskRect = CGRect(x: 440, y: 690, width: 720, height: 195)

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / sceneSize.width, size.height / sceneSize.height)
      let offset = CGPoint(x: (size.width - sceneSize.width * scale) / 2, y: (size.height - sceneSize.height * scale) / 2)
      func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: offset.x + x * scale, y: offset.y + y * scale) }
      func rect(_ rect: CGRect) -> CGRect { CGRect(x: offset.x + rect.minX * scale, y: offset.y + rect.minY * scale, width: rect.width * scale, height: rect.height * scale) }
      func fill(_ target: CGRect, _ color: Color, radius: CGFloat = 0) { context.fill(Path(roundedRect: rect(target), cornerRadius: radius * scale), with: .color(color)) }
      func stroke(_ target: CGRect, _ color: Color, width: CGFloat = 1, radius: CGFloat = 0) { context.stroke(Path(roundedRect: rect(target), cornerRadius: radius * scale), with: .color(color), lineWidth: width * scale) }

      // Environment: gradient wall, floor, ribs, window bank, pinboard, and planks.
      context.fill(Path(rect(CGRect(x: 0, y: 0, width: 1600, height: 620))), with: .linearGradient(Gradient(colors: [Color(red: 0.125, green: 0.14, blue: 0.17), Color(red: 0.05, green: 0.06, blue: 0.08)]), startPoint: point(800, 0), endPoint: point(800, 620)))
      context.fill(Path(rect(CGRect(x: 0, y: 620, width: 1600, height: 280))), with: .linearGradient(Gradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.15), Color(red: 0.03, green: 0.04, blue: 0.05)]), startPoint: point(800, 620), endPoint: point(800, 900)))
      fill(CGRect(x: 0, y: 30, width: 1600, height: 13), Color(red: 0.17, green: 0.13, blue: 0.09).opacity(0.7))
      fill(CGRect(x: 0, y: 86, width: 1600, height: 9), Color(red: 0.14, green: 0.10, blue: 0.07).opacity(0.7))
      for x in stride(from: CGFloat(150), through: 1430, by: 320) { fill(CGRect(x: x, y: 30, width: 11, height: 58), Color(red: 0.24, green: 0.18, blue: 0.13).opacity(0.65)) }
      for x in [300, 700, 1080, 1380] as [CGFloat] {
        fill(CGRect(x: x, y: 44, width: 26, height: 11), Color(red: 0.92, green: 0.86, blue: 0.76), radius: 3)
        glow(&context, center: point(x + 13, 150), radius: 120 * scale, color: Color.orange.opacity(0.16))
      }
      let window = CGRect(x: 510, y: 154, width: 382, height: 205)
      fill(window, Color(red: 0.03, green: 0.06, blue: 0.08), radius: 8)
      stroke(window, Color(red: 0.43, green: 0.53, blue: 0.60).opacity(0.65), width: 3, radius: 8)
      fill(CGRect(x: 520, y: 164, width: 362, height: 185), Color(red: 0.25, green: 0.52, blue: 0.62).opacity(0.22), radius: 5)
      for x in [636, 756] as [CGFloat] { fill(CGRect(x: x, y: 164, width: 5, height: 185), Color.gray.opacity(0.55)) }
      fill(CGRect(x: 900, y: 200, width: 215, height: 170), Color(red: 0.17, green: 0.13, blue: 0.10), radius: 4)
      for row in 0..<3 { for col in 0..<3 where !(row == 2 && col == 2) { fill(CGRect(x: 915 + CGFloat(col) * 52, y: 215 + CGFloat(row) * 42, width: 42, height: 28), Color(red: 0.82, green: 0.77, blue: 0.69).opacity(0.58), radius: 2) } }
      fill(CGRect(x: 1170, y: 175, width: 290, height: 200), Color(red: 0.29, green: 0.21, blue: 0.14).opacity(0.76))
      for y in stride(from: CGFloat(205), through: 355, by: 30) { fill(CGRect(x: 1170, y: y, width: 290, height: 2), Color.black.opacity(0.32)) }

      drawBay(&context, layout: Self.bays[0], name: "A", color: .cyan, scale: scale, offset: offset)
      drawBay(&context, layout: Self.bays[1], name: "S", color: .orange, scale: scale, offset: offset)
      drawBay(&context, layout: Self.bays[2], name: "B", color: .pink, scale: scale, offset: offset)

      // Founder desk, monitor, and chair.
      fill(CGRect(x: 470, y: 700, width: 660, height: 45), Color(red: 0.38, green: 0.25, blue: 0.14))
      fill(CGRect(x: 640, y: 500, width: 330, height: 190), Color(red: 0.04, green: 0.05, blue: 0.07), radius: 8)
      fill(CGRect(x: 650, y: 510, width: 310, height: 170), Color(red: 0.07, green: 0.10, blue: 0.14), radius: 4)
      fill(CGRect(x: 662, y: 522, width: 60, height: 6), .cyan, radius: 3)
      fill(CGRect(x: 700, y: 770, width: 200, height: 115), Color(red: 0.10, green: 0.12, blue: 0.15), radius: 20)
      for (index, c) in [Color.cyan, .orange, .pink].enumerated() { fill(CGRect(x: 664 + CGFloat(index) * 16, y: 614, width: 8, height: 8), c, radius: 4) }
      if deskIsPrimary { ring(&context, center: point(800, 728), radius: 190 * scale, color: .cyan) }
      drawMotes(&context, point: point, scale: scale, time: date.timeIntervalSinceReferenceDate)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Founder's garage with three AI agent workstations")
    .overlay { interactionLayer }
  }

  private var interactionLayer: some View {
    GeometryReader { proxy in
      let scale = min(proxy.size.width / sceneSize.width, proxy.size.height / sceneSize.height)
      let ox = (proxy.size.width - sceneSize.width * scale) / 2
      let oy = (proxy.size.height - sceneSize.height * scale) / 2
      let rect: (CGRect) -> CGRect = { r in
        CGRect(x: ox + r.minX * scale, y: oy + r.minY * scale, width: r.width * scale, height: r.height * scale)
      }
      let point: (CGPoint) -> CGPoint = { p in
        CGPoint(x: ox + p.x * scale, y: oy + p.y * scale)
      }
      ZStack(alignment: .topLeading) {
        ForEach(Self.bays, id: \.agentID) { bay in
          if let station = station(bay.agentID) {
            let actionable = gate.stationIsActionable(station)
            let dimmed = focusedAgentID != nil && focusedAgentID != station.id || !actionable
            Color.black.opacity(dimmed ? 0.32 : 0).frame(width: rect(bay.hitRect).width, height: rect(bay.hitRect).height).position(x: rect(bay.hitRect).midX, y: rect(bay.hitRect).midY).allowsHitTesting(false)
            if gate.stationIsHighlighted(station) { Circle().stroke(Self.color(bay.agentID), lineWidth: 2).shadow(color: Self.color(bay.agentID).opacity(0.7), radius: 10).frame(width: (bay.radius + 14) * 2 * scale, height: (bay.radius + 14) * 2 * scale).position(point(bay.avatar)).allowsHitTesting(false) }
            Button { onSelectStation(station) } label: {
              Rectangle().fill(.clear).contentShape(Rectangle())
            }
            .frame(width: rect(bay.hitRect).width, height: rect(bay.hitRect).height)
            .position(x: rect(bay.hitRect).midX, y: rect(bay.hitRect).midY)
            .buttonStyle(.plain)
            .disabled(!actionable)
            .accessibilityLabel("\(station.name), level \(station.progression.level), \(station.progression.stressBand.label) stress")
            .accessibilityValue(station.accessibilityValue)
            .accessibilityHint("Opens agent task controls")
            GarageStationTag(station: station, accent: Self.color(bay.agentID), differentiateWithoutColor: differentiateWithoutColor).opacity(dimmed ? 0.38 : 1).position(x: point(bay.avatar).x, y: point(bay.avatar).y + (bay.radius + 34) * scale).allowsHitTesting(false)
          }
        }
        Button(action: onSelectDesk) {
          Rectangle().fill(.clear).contentShape(Rectangle())
        }
        .frame(width: rect(Self.deskRect).width, height: rect(Self.deskRect).height)
        .position(x: rect(Self.deskRect).midX, y: rect(Self.deskRect).midY)
        .buttonStyle(.plain)
        .accessibilityLabel("Founder desk")
        .accessibilityHint("Opens sprint controls")
      }
    }
  }

  private func station(_ id: String) -> AgentStationViewModel? { stations.first { $0.agentID.lowercased() == id } }
  private static func color(_ id: String) -> Color { id == "aurora" ? .cyan : id == "stacks" ? .orange : .pink }
}

private struct BayLayout {
  var agentID: String
  var hitRect: CGRect
  var avatar: CGPoint
  var radius: CGFloat
}

private func drawBay(_ context: inout GraphicsContext, layout: BayLayout, name: String, color: Color, scale: CGFloat, offset: CGPoint) {
  func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: offset.x + x * scale, y: offset.y + y * scale) }
  func rect(_ source: CGRect) -> CGRect { CGRect(x: offset.x + source.minX * scale, y: offset.y + source.minY * scale, width: source.width * scale, height: source.height * scale) }
  func fill(_ source: CGRect, _ color: Color, _ radius: CGFloat = 0) { context.fill(Path(roundedRect: rect(source), cornerRadius: radius * scale), with: .color(color)) }
  func stroke(_ source: CGRect, _ color: Color, _ width: CGFloat = 1, _ radius: CGFloat = 0) { context.stroke(Path(roundedRect: rect(source), cornerRadius: radius * scale), with: .color(color), lineWidth: width * scale) }
  let isAurora = layout.agentID == "aurora"
  let isStacks = layout.agentID == "stacks"
  let x = layout.hitRect.minX
  let desk = CGRect(x: x + 20, y: layout.avatar.y + 33, width: layout.hitRect.width - 35, height: 52)
  glow(&context, center: point(layout.avatar.x + 55, layout.avatar.y), radius: layout.hitRect.width * 0.42, color: color.opacity(0.13))
  fill(desk, isStacks ? Color(red: 0.22, green: 0.16, blue: 0.10) : Color(red: 0.16, green: 0.19, blue: 0.23), 5)
  fill(CGRect(x: desk.minX, y: desk.maxY - 15, width: desk.width, height: 15), Color.black.opacity(0.26), 0)
  if isAurora {
    for monitor in [CGRect(x: 45, y: 345, width: 175, height: 118), CGRect(x: 232, y: 360, width: 118, height: 100)] { fill(monitor, Color(red: 0.03, green: 0.08, blue: 0.10), 6); stroke(monitor.insetBy(dx: 7, dy: 7), color.opacity(0.65), 2, 3) }
    fill(CGRect(x: 258, y: 470, width: 36, height: 42), Color(red: 0.12, green: 0.30, blue: 0.33), 10)
  } else if isStacks {
    fill(CGRect(x: 1245, y: 255, width: 105, height: 235), Color(red: 0.08, green: 0.10, blue: 0.13), 5)
    for i in 0..<6 { fill(CGRect(x: 1256, y: 268 + CGFloat(i) * 22, width: 83, height: 15), color.opacity(0.30), 2) }
    stroke(CGRect(x: 1055, y: 285, width: 165, height: 105), color, 2, 6)
  } else {
    fill(CGRect(x: 1400, y: 330, width: 200, height: 7), color, 3)
    fill(CGRect(x: 1370, y: 520, width: 230, height: 52), Color(red: 0.35, green: 0.16, blue: 0.19), 4)
    for i in 0..<6 { fill(CGRect(x: 1425 + CGFloat(i) * 20, y: 360, width: 6, height: 30 + CGFloat(i % 3) * 7), Color.gray.opacity(0.7), 3) }
  }
  let center = point(layout.avatar.x, layout.avatar.y)
  ring(&context, center: center, radius: layout.radius * 1.0, color: color)
  context.fill(Path(ellipseIn: CGRect(x: center.x - layout.radius * 0.7, y: center.y - layout.radius * 0.7, width: layout.radius * 1.4, height: layout.radius * 1.4)), with: .color(color.opacity(0.92)))
  context.draw(Text(name).font(.system(size: layout.radius * 0.75, weight: .bold)).foregroundStyle(.black.opacity(0.72)), at: center)
}

private func glow(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) { context.drawLayer { layer in layer.addFilter(.blur(radius: radius * 0.18)); layer.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .radialGradient(Gradient(colors: [color, .clear]), center: center, startRadius: 0, endRadius: radius)) } }
private func ring(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) { context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color.opacity(0.85)), lineWidth: 2) }
private func drawMotes(_ context: inout GraphicsContext, point: (CGFloat, CGFloat) -> CGPoint, scale: CGFloat, time: Double) { for (x, y, c) in [(90, 620, Color.cyan), (200, 600, .cyan), (1120, 600, .orange), (1250, 630, .orange), (1450, 660, .pink), (1550, 610, .pink)] { let progress = (sin(time + Double(x) / 80) + 1) / 2; let p = point(CGFloat(x) + CGFloat(progress) * 12, CGFloat(y) - CGFloat(progress) * 145); context.fill(Path(ellipseIn: CGRect(x: p.x - 2 * scale, y: p.y - 2 * scale, width: 4 * scale, height: 4 * scale)), with: .color(c.opacity(0.35))) } }
