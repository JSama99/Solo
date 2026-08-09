import RealityKit
import SwiftUI
import UIKit

/// Lightweight, visual-only facility scene. SwiftUI command controls remain
/// available below it, so progression never depends on RealityKit rendering.
@available(iOS 18.0, *)
struct FounderLoftEnvironment: View {
  var body: some View {
    RealityView { content in
      content.add(FounderLoftScene.makeRoot())
    }
    .frame(height: 420)
    .background(.black.opacity(0.92), in: .rect(cornerRadius: 24))
    .clipShape(.rect(cornerRadius: 24))
    .overlay(alignment: .topLeading) {
      Label("FOUNDER LOFT", systemImage: "stairs")
        .font(.caption.weight(.black)).foregroundStyle(SoloTheme.mint)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.62), in: .capsule).padding(14)
    }
    .overlay(alignment: .bottom) {
      Text("Lower floor: operations • Upper floor: recovery and founder life")
        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.84))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.62), in: .capsule).padding(14)
    }
    .overlay { RoundedRectangle(cornerRadius: 24).stroke(SoloTheme.mint.opacity(0.42), lineWidth: 1) }
    .accessibilityLabel("Founder Loft environment")
    .accessibilityHint("The Loft is a visual headquarters. All company controls remain available below.")
  }
}

@available(iOS 18.0, *)
private enum FounderLoftScene {
  static func makeRoot() -> Entity {
    let root = Entity()
    root.position = [0, -0.5, 0]
    let floor = box([8, 0.12, 5], .init(red: 0.10, green: 0.075, blue: 0.06, alpha: 1))
    root.addChild(floor)
    let upperFloor = box([3.1, 0.12, 2.3], .init(red: 0.17, green: 0.12, blue: 0.09, alpha: 1))
    upperFloor.position = [2.15, 1.9, 0.5]
    root.addChild(upperFloor)
    for (index, x) in [-2.5, 0, 2.5].enumerated() {
      let station = box([1.7, 0.85, 0.7], index == 1 ? .init(red: 0.12, green: 0.34, blue: 0.38, alpha: 1) : .init(red: 0.14, green: 0.16, blue: 0.22, alpha: 1))
      station.position = [Float(x), 0.42, -1.2]
      root.addChild(station)
      let screen = box([0.9, 0.5, 0.04], .init(red: 0.10, green: 0.88, blue: 0.90, alpha: 1))
      screen.position = [Float(x), 1.05, -1.45]
      root.addChild(screen)
    }
    let lounge = box([1.8, 0.52, 0.82], .init(red: 0.34, green: 0.22, blue: 0.16, alpha: 1))
    lounge.position = [2.0, 2.25, 0.5]
    root.addChild(lounge)
    let metricsWall = box([2.1, 1.1, 0.05], .init(red: 0.08, green: 0.42, blue: 0.48, alpha: 1))
    metricsWall.position = [-2.5, 1.55, 1.7]
    root.addChild(metricsWall)
    root.addChild(light(at: [-1.8, 2.8, 0.5], color: .cyan))
    root.addChild(light(at: [2.3, 3.1, -0.5], color: .orange))
    return root
  }

  private static func box(_ size: SIMD3<Float>, _ color: UIColor) -> ModelEntity {
    ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, isMetallic: false)])
  }

  private static func light(at position: SIMD3<Float>, color: UIColor) -> Entity {
    let entity = Entity()
    let light = PointLightComponent(color: color, intensity: 1_100, attenuationRadius: 6)
    entity.components.set(light)
    entity.position = position
    return entity
  }
}
