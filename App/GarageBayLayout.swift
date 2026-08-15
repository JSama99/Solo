import CoreGraphics

struct GarageBayLayout {
  struct Bay: Hashable {
    var frame: CGRect
    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
  }

  static let canvasHeight: CGFloat = 650
  static let deskSize = CGSize(width: 150, height: 172)
  var stationCount: Int

  var canvasWidth: CGFloat { stationCount <= 3 ? 980 : stationCount == 4 ? 1_320 : 1_440 }
  var deskFrame: CGRect {
    CGRect(x: (canvasWidth - Self.deskSize.width) / 2, y: Self.canvasHeight - Self.deskSize.height - 18, width: Self.deskSize.width, height: Self.deskSize.height)
  }
  var bays: [Bay] {
    let frames: [CGRect]
    switch stationCount {
    case 3:
      frames = [CGRect(x: 30, y: 150, width: 300, height: 280), CGRect(x: 610, y: 120, width: 300, height: 280), CGRect(x: 610, y: 405, width: 300, height: 220)]
    case 4:
      frames = [CGRect(x: 25, y: 135, width: 250, height: 270), CGRect(x: 300, y: 135, width: 250, height: 270), CGRect(x: 790, y: 135, width: 250, height: 270), CGRect(x: 1065, y: 135, width: 250, height: 270)]
    default:
      frames = [CGRect(x: 20, y: 115, width: 240, height: 260), CGRect(x: 285, y: 115, width: 240, height: 260), CGRect(x: 915, y: 115, width: 240, height: 260), CGRect(x: 1_180, y: 115, width: 240, height: 260), CGRect(x: 20, y: 390, width: 240, height: 230)]
    }
    return Array(frames.prefix(max(0, min(5, stationCount)))).map(Bay.init)
  }
}

enum GarageBayPresentation {
  static func accentToken(for index: Int) -> String { ["cyan", "amber", "coral", "mint", "purple"][index % 5] }
  static func icon(for index: Int) -> String { ["brain.head.profile", "cpu", "sparkles", "point.3.connected.trianglepath.dotted", "scope"][index % 5] }
}
