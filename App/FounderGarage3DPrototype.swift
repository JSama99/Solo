import RealityKit
import SwiftUI
import UIKit

/// A visual-only RealityKit interpretation of the current Founder Garage.
/// GameStore remains the single source of truth; this scene never mutates it.
@available(iOS 18.0, *)
struct FounderGarage3DPrototype: View {
  var store: GameStore

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var scene = FounderGarageScene()

  var body: some View {
    RealityView { content in
      if let root = scene.rootForInstallation() {
        content.add(root)
      }
      scene.apply(states: agentStates, reduceMotion: reduceMotion)
    } update: { _ in
      scene.apply(states: agentStates, reduceMotion: reduceMotion)
    }
    .frame(height: 250)
    .clipShape(.rect(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(SoloTheme.cyan.opacity(0.32))
    }
    .accessibilityHidden(true)
  }

  private var agentStates: [(String, AgentVisualState)] {
    store.agents.map { agent in
      (
        agent.id,
        AgentVisualState.derive(
          agent: agent,
          task: store.tasks.first(where: { $0.assignedAgentID == agent.id }),
          founderStats: store.stats
        )
      )
    }
  }
}

@available(iOS 18.0, *)
private final class FounderGarageScene {
  private let root = Entity()
  private var installed = false
  private var robots: [String: GarageRobot] = [:]

  func rootForInstallation() -> Entity? {
    guard !installed else { return nil }
    installed = true
    buildGarage()
    return root
  }

  func apply(states: [(String, AgentVisualState)], reduceMotion: Bool) {
    for (index, entry) in states.enumerated() {
      guard let robot = robots[entry.0] else { continue }
      let state = entry.1
      let target = targetPosition(for: index, state: state)
      robot.update(state: state, target: target, reduceMotion: reduceMotion, relativeTo: root)
    }
  }

  private func buildGarage() {
    let floor = box(size: SIMD3<Float>(10, 0.15, 7), color: UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1))
    floor.position = [0, -0.08, 0]
    root.addChild(floor)

    let backWall = box(size: SIMD3<Float>(10, 3.6, 0.18), color: UIColor(red: 0.10, green: 0.12, blue: 0.17, alpha: 1))
    backWall.position = [0, 1.7, -3.4]
    root.addChild(backWall)

    let leftWall = box(size: SIMD3<Float>(0.18, 3.6, 7), color: UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1))
    leftWall.position = [-4.9, 1.7, 0]
    root.addChild(leftWall)

    let console = box(size: SIMD3<Float>(2.6, 0.95, 0.7), color: UIColor(red: 0.10, green: 0.32, blue: 0.38, alpha: 1))
    console.position = [0, 0.48, 1.8]
    root.addChild(console)
    let consoleLight = box(size: SIMD3<Float>(1.7, 0.06, 0.38), color: UIColor(red: 0.10, green: 0.90, blue: 1, alpha: 1))
    consoleLight.position = [0, 0.98, 1.56]
    root.addChild(consoleLight)

    for index in 0 ..< 3 {
      let x = Float(index - 1) * 3.05
      let station = box(size: SIMD3<Float>(2.1, 0.84, 0.7), color: UIColor(red: 0.14, green: 0.17, blue: 0.23, alpha: 1))
      station.position = [x, 0.42, -1.25]
      root.addChild(station)
      let screen = box(size: SIMD3<Float>(1.15, 0.58, 0.06), color: UIColor(red: 0.05, green: 0.72, blue: 0.84, alpha: 1))
      screen.position = [x, 1.15, -1.56]
      root.addChild(screen)
    }

    let keyLight = DirectionalLight()
    keyLight.light.intensity = 2_500
    keyLight.position = [1, 4, 3]
    keyLight.look(at: [0, 0, -1], from: keyLight.position, relativeTo: root)
    root.addChild(keyLight)

    let fillLight = PointLight()
    fillLight.light.intensity = 900
    fillLight.light.color = .cyan
    fillLight.position = [0, 2.8, 1.5]
    root.addChild(fillLight)

    let camera = PerspectiveCamera()
    camera.position = [0, 4.8, 9.6]
    camera.look(at: [0, 0.9, -0.8], from: camera.position, relativeTo: root)
    root.addChild(camera)

    for id in ["aurora", "stacks", "brio"] {
      let robot = GarageRobot()
      root.addChild(robot.entity)
      robots[id] = robot
    }
  }

  private func targetPosition(for index: Int, state: AgentVisualState) -> SIMD3<Float> {
    if state.activity == .idle {
      return [Float(index - 1) * 2.25, 0, 0.7]
    }
    return [Float(index - 1) * 3.05, 0, -0.45]
  }

  private func box(size: SIMD3<Float>, color: UIColor) -> ModelEntity {
    ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, isMetallic: false)])
  }
}

@available(iOS 18.0, *)
private final class GarageRobot {
  let entity = Entity()
  private let statusLight: ModelEntity
  private var lastTarget: SIMD3<Float>?
  private var lastColor: UIColor?

  init() {
    let body = ModelEntity(mesh: .generateCylinder(height: 1.15, radius: 0.32), materials: [SimpleMaterial(color: UIColor(red: 0.68, green: 0.73, blue: 0.82, alpha: 1), isMetallic: true)])
    body.position = [0, 0.65, 0]
    entity.addChild(body)

    let head = ModelEntity(mesh: .generateSphere(radius: 0.34), materials: [SimpleMaterial(color: UIColor(white: 0.9, alpha: 1), isMetallic: true)])
    head.position = [0, 1.36, 0]
    entity.addChild(head)

    statusLight = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [SimpleMaterial(color: .gray, isMetallic: false)])
    statusLight.position = [0, 0.88, 0.32]
    entity.addChild(statusLight)
  }

  func update(state: AgentVisualState, target: SIMD3<Float>, reduceMotion: Bool, relativeTo root: Entity) {
    let color = statusColor(for: state)
    if lastColor != color {
      statusLight.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
      lastColor = color
    }

    guard lastTarget != target else { return }
    if lastTarget == nil {
      lastTarget = target
      entity.position = target
      return
    }
    lastTarget = target
    let transform = Transform(scale: .one, rotation: simd_quatf(), translation: target)
    if reduceMotion {
      entity.transform = transform
    } else {
      entity.move(to: transform, relativeTo: root, duration: 0.45, timingFunction: .easeInOut)
    }
  }

  private func statusColor(for state: AgentVisualState) -> UIColor {
    if !state.warnings.isEmpty { return .orange }
    switch state.verification {
    case .verified, .confirmed: return UIColor(red: 0.22, green: 0.90, blue: 0.60, alpha: 1)
    case .overclaiming, .driftDetected, .evidenceIncomplete: return .orange
    case .none: return state.activity == .idle ? .gray : .cyan
    }
  }
}
