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
  @State private var selectedAgentID: String?

  var body: some View {
    TimelineView(.animation) { timeline in
      RealityView { content in
        if let root = scene.rootForInstallation() {
          content.add(root)
        }
        scene.apply(states: agentStates, selectedAgentID: selectedAgentID, reduceMotion: reduceMotion)
        scene.animate(at: timeline.date, reduceMotion: reduceMotion)
      } update: { _ in
        scene.apply(states: agentStates, selectedAgentID: selectedAgentID, reduceMotion: reduceMotion)
        scene.animate(at: timeline.date, reduceMotion: reduceMotion)
      }
      .gesture(
        TapGesture()
          .targetedToAnyEntity()
          .onEnded { value in
            selectedAgentID = scene.agentID(for: value.entity)
          }
      )
    }
    .frame(height: 420)
    .background(.black.opacity(0.92), in: .rect(cornerRadius: 24))
    .clipShape(.rect(cornerRadius: 24))
    .overlay(alignment: .topLeading) {
      Label("FOUNDER GARAGE", systemImage: "cube.transparent")
        .font(.caption.weight(.black))
        .foregroundStyle(SoloTheme.cyan)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.62), in: .capsule)
        .padding(14)
        .accessibilityHidden(true)
    }
    .overlay(alignment: .bottom) {
      if let selectedAgent {
        GarageAgentDetailCard(
          agent: selectedAgent,
          task: task(for: selectedAgent),
          state: state(for: selectedAgent)
        )
        .padding(12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      } else {
        Text("Tap an android or workstation to inspect its live assignment")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.84))
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(.black.opacity(0.62), in: .capsule)
          .padding(14)
          .accessibilityHidden(true)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .stroke(SoloTheme.cyan.opacity(0.42), lineWidth: 1)
    }
    .animation(.snappy, value: selectedAgentID)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Interactive Founder Garage")
    .accessibilityHint("Tap an android or workstation to reveal its current assignment and status.")
  }

  private var selectedAgent: SoloAgent? {
    store.agents.first(where: { $0.id == selectedAgentID })
  }

  private var agentStates: [(String, AgentVisualState)] {
    store.agents.map { ($0.id, state(for: $0)) }
  }

  private func task(for agent: SoloAgent) -> SoloTask? {
    store.tasks.first(where: { $0.assignedAgentID == agent.id })
  }

  private func state(for agent: SoloAgent) -> AgentVisualState {
    AgentVisualState.derive(agent: agent, task: task(for: agent), founderStats: store.stats)
  }
}

@available(iOS 18.0, *)
private struct GarageAgentDetailCard: View {
  var agent: SoloAgent
  var task: SoloTask?
  var state: AgentVisualState

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Image(systemName: agent.role.symbol)
          .foregroundStyle(statusColor)
        Text(agent.name)
          .font(.headline)
        Text("• \(agent.role.rawValue)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text(statusLabel)
          .font(.caption.weight(.bold))
          .foregroundStyle(statusColor)
      }
      Text(task?.title ?? "Unassigned — ready for the next commitment")
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
      Text(detailLine)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(statusColor.opacity(0.72), lineWidth: 1.5)
    }
    .accessibilityElement(children: .combine)
  }

  private var statusLabel: String {
    if !state.warnings.isEmpty { return "Warning" }
    switch state.verification {
    case .verified, .confirmed: return "Verified"
    case .overclaiming, .driftDetected, .evidenceIncomplete: return "Review needed"
    case .none: return state.activity == .idle ? "Idle" : "Working"
    }
  }

  private var detailLine: String {
    let taskStatus = task.map { $0.isReviewed ? "Reviewed" : "Awaiting review" } ?? "No assignment"
    return "\(taskStatus) • Drift \(Int(agent.drift)) • \(state.accessibilityValue)"
  }

  private var statusColor: Color {
    if !state.warnings.isEmpty { return SoloTheme.amber }
    switch state.verification {
    case .verified, .confirmed: return SoloTheme.mint
    case .overclaiming, .driftDetected, .evidenceIncomplete: return SoloTheme.amber
    case .none: return state.activity == .idle ? .secondary : SoloTheme.cyan
    }
  }
}

@available(iOS 18.0, *)
private final class FounderGarageScene {
  private let root = Entity()
  private var installed = false
  private var robots: [String: GarageRobot] = [:]
  private var stations: [String: GarageStation] = [:]
  private var monitorLights: [ModelEntity] = []
  private var ceilingLight: PointLight?

  func rootForInstallation() -> Entity? {
    guard !installed else { return nil }
    installed = true
    buildGarage()
    return root
  }

  func agentID(for entity: Entity) -> String? {
    var candidate: Entity? = entity
    while let current = candidate {
      if current.name.hasPrefix("garage-agent-") {
        return String(current.name.dropFirst("garage-agent-".count))
      }
      candidate = current.parent
    }
    return nil
  }

  func apply(states: [(String, AgentVisualState)], selectedAgentID: String?, reduceMotion: Bool) {
    for (index, entry) in states.enumerated() {
      guard let robot = robots[entry.0], let station = stations[entry.0] else { continue }
      let target = targetPosition(for: index, state: entry.1)
      robot.update(
        state: entry.1,
        target: target,
        isSelected: entry.0 == selectedAgentID,
        reduceMotion: reduceMotion,
        relativeTo: root
      )
      station.update(isSelected: entry.0 == selectedAgentID, state: entry.1)
    }
  }

  func animate(at date: Date, reduceMotion: Bool) {
    let time = Float(date.timeIntervalSinceReferenceDate)
    for robot in robots.values {
      robot.animate(at: time, reduceMotion: reduceMotion)
    }
    guard !reduceMotion else { return }
    let glow = 0.78 + ((sin(time * 1.6) + 1) * 0.12)
    for monitor in monitorLights {
      monitor.scale = [1, glow, 1]
    }
    ceilingLight?.light.intensity = 1_150 + (sin(time * 0.7) + 1) * 150
  }

  private func buildGarage() {
    let floor = box(size: [11.5, 0.18, 7.5], color: UIColor(red: 0.035, green: 0.055, blue: 0.08, alpha: 1), metallic: true)
    floor.position = [0, -0.09, 0]
    root.addChild(floor)
    let floorInset = box(size: [10.8, 0.025, 6.8], color: UIColor(red: 0.035, green: 0.12, blue: 0.16, alpha: 1))
    floorInset.position = [0, 0.015, -0.1]
    root.addChild(floorInset)

    let backWall = box(size: [11.5, 4.6, 0.2], color: UIColor(red: 0.055, green: 0.075, blue: 0.12, alpha: 1), metallic: true)
    backWall.position = [0, 2.25, -3.7]
    root.addChild(backWall)
    let ceilingBeam = box(size: [11.5, 0.25, 0.35], color: UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1), metallic: true)
    ceilingBeam.position = [0, 4.15, -1.8]
    root.addChild(ceilingBeam)

    let console = box(size: [3.0, 1.0, 0.8], color: UIColor(red: 0.07, green: 0.24, blue: 0.30, alpha: 1), metallic: true)
    console.position = [0, 0.5, 2.05]
    root.addChild(console)
    let consoleLight = box(size: [2.25, 0.05, 0.46], color: UIColor(red: 0.12, green: 0.9, blue: 1, alpha: 1))
    consoleLight.position = [0, 1.03, 1.72]
    root.addChild(consoleLight)
    monitorLights.append(consoleLight)

    for (index, id) in ["aurora", "stacks", "brio"].enumerated() {
      let x = Float(index - 1) * 3.45
      let station = GarageStation(id: id, x: x)
      root.addChild(station.entity)
      stations[id] = station
      monitorLights.append(station.monitorGlow)
    }

    let keyLight = DirectionalLight()
    keyLight.light.intensity = 3_200
    keyLight.light.color = UIColor(red: 0.72, green: 0.87, blue: 1, alpha: 1)
    keyLight.position = [-2, 5, 4]
    keyLight.look(at: [0, 0.8, -1.1], from: keyLight.position, relativeTo: root)
    root.addChild(keyLight)

    let fillLight = PointLight()
    fillLight.light.intensity = 1_050
    fillLight.light.color = .cyan
    fillLight.position = [0, 3.4, 0.9]
    root.addChild(fillLight)
    ceilingLight = fillLight

    let warmLight = PointLight()
    warmLight.light.intensity = 680
    warmLight.light.color = .orange
    warmLight.position = [-4.8, 2.3, -1]
    root.addChild(warmLight)

    let camera = PerspectiveCamera()
    camera.position = [0, 3.45, 8.3]
    camera.look(at: [0, 1.0, -1.05], from: camera.position, relativeTo: root)
    root.addChild(camera)

    for (index, id) in ["aurora", "stacks", "brio"].enumerated() {
      let robot = GarageRobot(id: id, phase: Float(index) * 2.1)
      root.addChild(robot.entity)
      robots[id] = robot
    }
  }

  private func targetPosition(for index: Int, state: AgentVisualState) -> SIMD3<Float> {
    let x = Float(index - 1) * 3.45
    return state.activity == .idle ? [x, 0, 0.35] : [x, 0, -0.42]
  }

  private func box(size: SIMD3<Float>, color: UIColor, metallic: Bool = false) -> ModelEntity {
    ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, isMetallic: metallic)])
  }
}

@available(iOS 18.0, *)
private final class GarageStation {
  let entity = Entity()
  let monitorGlow: ModelEntity
  private let accent: ModelEntity

  init(id: String, x: Float) {
    entity.name = "garage-agent-\(id)"
    entity.components.set(InputTargetComponent())
    entity.components.set(CollisionComponent(shapes: [.generateBox(size: [2.55, 1.65, 0.9])]))
    entity.position = [x, 0, -1.45]

    let desk = ModelEntity(mesh: .generateBox(size: [2.55, 0.84, 0.82]), materials: [SimpleMaterial(color: UIColor(red: 0.10, green: 0.13, blue: 0.19, alpha: 1), isMetallic: true)])
    desk.position = [0, 0.42, 0]
    entity.addChild(desk)
    accent = ModelEntity(mesh: .generateBox(size: [2.6, 0.05, 0.86]), materials: [SimpleMaterial(color: UIColor(red: 0.08, green: 0.42, blue: 0.50, alpha: 1), isMetallic: false)])
    accent.position = [0, 0.86, 0]
    entity.addChild(accent)
    let monitor = ModelEntity(mesh: .generateBox(size: [1.4, 0.72, 0.08]), materials: [SimpleMaterial(color: UIColor(red: 0.03, green: 0.28, blue: 0.35, alpha: 1), isMetallic: false)])
    monitor.position = [0, 1.34, -0.28]
    entity.addChild(monitor)
    monitorGlow = ModelEntity(mesh: .generateBox(size: [1.18, 0.48, 0.025]), materials: [SimpleMaterial(color: UIColor(red: 0.05, green: 0.9, blue: 1, alpha: 1), isMetallic: false)])
    monitorGlow.position = [0, 1.34, -0.335]
    entity.addChild(monitorGlow)
  }

  func update(isSelected: Bool, state: AgentVisualState) {
    let color: UIColor = isSelected ? .white : statusColor(for: state)
    accent.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
    monitorGlow.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
    accent.scale = isSelected ? [1, 1.6, 1] : .one
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

@available(iOS 18.0, *)
private final class GarageRobot {
  let entity = Entity()
  private let visualRoot = Entity()
  private let statusLight: ModelEntity
  private let selectionHalo: ModelEntity
  private let leftArm = Entity()
  private let rightArm = Entity()
  private let phase: Float
  private var lastTarget: SIMD3<Float>?
  private var lastColor: UIColor?
  private var isWorking = false

  init(id: String, phase: Float) {
    self.phase = phase
    entity.name = "garage-agent-\(id)"
    entity.components.set(InputTargetComponent())
    entity.components.set(CollisionComponent(shapes: [.generateBox(size: [1.1, 1.9, 0.9])]))
    entity.addChild(visualRoot)

    selectionHalo = ModelEntity(mesh: .generateCylinder(height: 0.025, radius: 0.62), materials: [SimpleMaterial(color: .cyan, isMetallic: false)])
    selectionHalo.position = [0, 0.025, 0]
    selectionHalo.isEnabled = false
    entity.addChild(selectionHalo)

    let body = ModelEntity(mesh: .generateCylinder(height: 1.15, radius: 0.32), materials: [SimpleMaterial(color: UIColor(red: 0.68, green: 0.73, blue: 0.82, alpha: 1), isMetallic: true)])
    body.position = [0, 0.65, 0]
    visualRoot.addChild(body)
    let head = ModelEntity(mesh: .generateSphere(radius: 0.34), materials: [SimpleMaterial(color: UIColor(white: 0.9, alpha: 1), isMetallic: true)])
    head.position = [0, 1.36, 0]
    visualRoot.addChild(head)
    statusLight = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [SimpleMaterial(color: .gray, isMetallic: false)])
    statusLight.position = [0, 0.88, 0.32]
    visualRoot.addChild(statusLight)
    addArm(leftArm, x: -0.38)
    addArm(rightArm, x: 0.38)
  }

  func update(state: AgentVisualState, target: SIMD3<Float>, isSelected: Bool, reduceMotion: Bool, relativeTo root: Entity) {
    isWorking = state.activity != .idle
    let color = statusColor(for: state)
    if lastColor != color {
      statusLight.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
      lastColor = color
    }
    selectionHalo.isEnabled = isSelected
    selectionHalo.model?.materials = [SimpleMaterial(color: isSelected ? color : .clear, isMetallic: false)]
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

  func animate(at time: Float, reduceMotion: Bool) {
    guard !reduceMotion else {
      visualRoot.position = .zero
      visualRoot.orientation = simd_quatf()
      leftArm.orientation = simd_quatf()
      rightArm.orientation = simd_quatf()
      statusLight.scale = .one
      return
    }
    let rate: Float = isWorking ? 5 : 1.7
    let wave = sin(time * rate + phase)
    visualRoot.position = [0, wave * (isWorking ? 0.14 : 0.075), 0]
    visualRoot.orientation = simd_quatf(angle: wave * (isWorking ? 0.2 : 0.075), axis: [0, 1, 0])
    leftArm.orientation = simd_quatf(angle: wave * (isWorking ? 0.7 : 0.16), axis: [0, 0, 1])
    rightArm.orientation = simd_quatf(angle: -wave * (isWorking ? 0.7 : 0.16), axis: [0, 0, 1])
    let pulse = 1 + ((wave + 1) * (isWorking ? 0.2 : 0.1))
    statusLight.scale = [pulse, pulse, pulse]
    if selectionHalo.isEnabled {
      let halo = 1 + ((sin(time * 2.5) + 1) * 0.07)
      selectionHalo.scale = [halo, 1, halo]
    }
  }

  private func addArm(_ arm: Entity, x: Float) {
    arm.position = [x, 0.95, 0]
    let limb = ModelEntity(mesh: .generateBox(size: [0.14, 0.58, 0.14]), materials: [SimpleMaterial(color: UIColor(red: 0.52, green: 0.61, blue: 0.73, alpha: 1), isMetallic: true)])
    limb.position = [0, -0.28, 0]
    arm.addChild(limb)
    visualRoot.addChild(arm)
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
