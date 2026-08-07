import RealityKit
import SwiftUI
import UIKit

#if canImport(RealityKitContent11)
import RealityKitContent1
#endif

@available(iOS 18.0, *)
struct FounderGarageExperience: View {
    var store: GameStore

    var body: some View {
        #if canImport(RealityKitContent)
        FounderGarageRealityComposerScene(store: store)
        #else
        FounderGarage3DPrototype(store: store)
        #endif
    }
}

#if canImport(RealityKitContent)
@available(iOS 18.0, *)
private struct FounderGarageRealityComposerScene: View {
    var store: GameStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = RealityComposerGarageScene()
    @State private var selectedAgentID: String?

    var body: some View {
        TimelineView(.animation) { timeline in
            RealityView { content in
                if let root = await scene.loadRoot() {
                    content.add(root)
                }
                scene.apply(states: agentStates, selectedAgentID: selectedAgentID)
                scene.animate(at: timeline.date, reduceMotion: reduceMotion)
            } update: { _ in
                scene.apply(states: agentStates, selectedAgentID: selectedAgentID)
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
                GarageRealityComposerAgentDetailCard(
                    agent: selectedAgent,
                    task: task(for: selectedAgent),
                    state: state(for: selectedAgent)
                )
                .padding(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if scene.didLoadAuthoredScene {
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
private struct GarageRealityComposerAgentDetailCard: View {
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
                Text("- \(agent.role.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
            }
            Text(task?.title ?? "Unassigned - ready for the next commitment")
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
        return "\(taskStatus) - Drift \(Int(agent.drift)) - \(state.accessibilityValue)"
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
@Observable
private final class RealityComposerGarageScene {
    private let sceneNames = ["FounderGarage", "Scene"]
    private var root: Entity?

    var didLoadAuthoredScene = false

    func loadRoot() async -> Entity? {
        if let root { return root }

        for sceneName in sceneNames {
            if let scene = try? await Entity.load(named: sceneName, in: realityKitContent1Bundle) {
                scene.name = "founder-garage-root"
                configureInputTargets(in: scene)
                root = scene
                didLoadAuthoredScene = true
                return scene
            }
        }

        let fallback = makeMissingScenePlaceholder()
        root = fallback
        return fallback
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

    func apply(states: [(String, AgentVisualState)], selectedAgentID: String?) {
        guard let root else { return }
        for (id, state) in states {
            let agentEntity = root.findEntity(named: "garage-agent-\(id)")
            let stationEntity = root.findEntity(named: "garage-station-\(id)")
            let color = statusColor(for: state, isSelected: id == selectedAgentID)

            applyStatusColor(color, to: agentEntity?.findEntity(named: "status-light") ?? agentEntity)
            applyStatusColor(color, to: stationEntity?.findEntity(named: "monitor-glow") ?? stationEntity)
            agentEntity?.scale = id == selectedAgentID ? [1.08, 1.08, 1.08] : .one
        }
    }

    func animate(at date: Date, reduceMotion: Bool) {
        guard !reduceMotion, let root else { return }
        let time = Float(date.timeIntervalSinceReferenceDate)
        let pulse = 1 + ((sin(time * 2.0) + 1) * 0.08)
        for id in ["aurora", "stacks", "brio"] {
            root.findEntity(named: "garage-agent-\(id)")?.position.y = (sin(time * 1.6 + Float(id.count)) + 1) * 0.035
            root.findEntity(named: "status-light-\(id)")?.scale = [pulse, pulse, pulse]
        }
    }

    private func configureInputTargets(in entity: Entity) {
        for id in ["aurora", "stacks", "brio"] {
            for name in ["garage-agent-\(id)", "garage-station-\(id)"] {
                guard let target = entity.findEntity(named: name) else { continue }
                target.components.set(InputTargetComponent())
                if target.components[CollisionComponent.self] == nil {
                    target.components.set(CollisionComponent(shapes: [.generateBox(size: [1.2, 1.8, 1.2])]))
                }
            }
        }
    }

    private func applyStatusColor(_ color: UIColor, to entity: Entity?) {
        guard let model = entity as? ModelEntity else { return }
        model.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
    }

    private func statusColor(for state: AgentVisualState, isSelected: Bool) -> UIColor {
        if isSelected { return .white }
        if !state.warnings.isEmpty { return .orange }
        switch state.verification {
        case .verified, .confirmed: return UIColor(red: 0.22, green: 0.90, blue: 0.60, alpha: 1)
        case .overclaiming, .driftDetected, .evidenceIncomplete: return .orange
        case .none: return state.activity == .idle ? .gray : .cyan
        }
    }

    private func makeMissingScenePlaceholder() -> Entity {
        let root = Entity()
        let panel = ModelEntity(
            mesh: .generateBox(size: [5.8, 0.12, 2.4]),
            materials: [SimpleMaterial(color: UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1), isMetallic: true)]
        )
        panel.position = [0, 0, -1.4]
        root.addChild(panel)

        let light = PointLight()
        light.light.color = .cyan
        light.light.intensity = 900
        light.position = [0, 2.2, 1.6]
        root.addChild(light)

        let camera = PerspectiveCamera()
        camera.position = [0, 2.1, 5.4]
        camera.look(at: [0, 0.2, -1.3], from: camera.position, relativeTo: root)
        root.addChild(camera)
        return root
    }
}
#endif
