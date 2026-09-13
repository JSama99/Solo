import RealityKit
import SwiftUI

@MainActor
struct FounderGarageRealityView: View {
  var presentation: FounderWorldPresentationModel
  var isActive: Bool = true
  var onOpenFounderComputer: () -> Void
  var onCameraIntent: (FounderGarageCameraState) -> Void = { _ in }

  // This reference owns one RealityKit world for this active Garage view session.
  // SwiftUI body updates and Computer focus round trips retain the same instance.
  @State private var world = FounderGarageRealityWorld()
  @State private var displayedCamera: FounderGarageCameraState = .founderPOV
  @State private var cameraOpacity: Double = 1
  @State private var cameraRequest = 0
  @State private var lookOrientation = FounderLookOrientation.neutral
  @State private var dragStartLook: FounderLookOrientation?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      environmentBackground

      RealityView { content in
        world.attachRoot { content.add($0) }
        world.apply(displayedPresentation, reduceMotion: reduceMotion)
        world.replaceAccessibilityActivationSubscription(
          content.subscribe(to: AccessibilityEvents.Activate.self, componentType: nil) { event in
            guard world.interaction(for: event.entity) == .openFounderComputer else { return }
            openFounderComputer()
          }
        )
      } update: { _ in
        world.apply(displayedPresentation, reduceMotion: reduceMotion)
      }
      .opacity(cameraOpacity)
      .allowsHitTesting(cameraOpacity == 1 && displayedCamera == presentation.cameraState)
      .gesture(
        TapGesture()
          .targetedToAnyEntity()
          .onEnded { value in
            guard world.interaction(for: value.entity) == .openFounderComputer else { return }
            openFounderComputer()
          }
      )
      .simultaneousGesture(freeLookDragGesture)
      .accessibilityHidden(true)

      prototypeHUD
    }
    .task {
      let source = FounderGarageArchitectureSource.bundledProductionAsset(name: FounderGarageV7AssetContract.resourceName)
      await world.requestGarageArchitecture(
        source,
        descriptor: .facilityTier0V7
      )?.value
    }
    .onChange(of: presentation.cameraState) { _, target in selectCamera(target) }
    .onChange(of: isActive) { _, active in
      if active && presentation.cameraState == .founderPOV { recenterFounderView() }
    }
    .onChange(of: reduceMotion) { _, reduced in
      if reduced { selectCamera(presentation.cameraState) }
    }
    .onDisappear { cameraRequest += 1 }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("founder-garage-realitykit")
    .accessibilityValue(garageAccessibilityValue)
  }

  private var garageAccessibilityValue: String {
    switch world.architectureLoadState {
    case .ready(.bundledProductionAsset): presentation.cameraState.title
    case .failed: "\(presentation.cameraState.title). Simplified Garage"
    default: "Loading Garage"
    }
  }

  private var displayedPresentation: FounderWorldPresentationModel {
    var model = presentation
    model.cameraState = displayedCamera
    return model
  }

  private var environmentBackground: LinearGradient {
    let preset = FounderEnvironmentLightingConfiguration.preset(for: world.environmentTimeState)
    return LinearGradient(
      colors: [color(preset.backgroundTop), color(preset.backgroundBottom)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private func color(_ components: SIMD3<Float>) -> Color {
    Color(
      red: Double(components.x),
      green: Double(components.y),
      blue: Double(components.z)
    )
  }

  // Separated viewpoints have no safe straight-line path through the furniture.
  // Fade the render surface, install one exact world-up pose, then reveal it.
  // Animation completion tokens ensure rapid retargets cannot reveal an older pose.
  private func selectCamera(_ target: FounderGarageCameraState) {
    cameraRequest += 1
    let request = cameraRequest
    dragStartLook = nil
    lookOrientation = .neutral
    if reduceMotion {
      withAnimation(nil) { displayedCamera = target; cameraOpacity = 1 }
      return
    }
    withAnimation(.easeInOut(duration: FounderGarageCameraConfiguration.transitionDuration / 2), completionCriteria: .removed) {
      cameraOpacity = 0
    } completion: {
      guard request == cameraRequest else { return }
      displayedCamera = target
      withAnimation(.easeInOut(duration: FounderGarageCameraConfiguration.transitionDuration / 2)) {
        cameraOpacity = 1
      }
    }
  }

  private func openFounderComputer() {
    guard presentation.founderComputerAvailable else { return }
    onOpenFounderComputer()
  }

  private var freeLookDragGesture: some Gesture {
    DragGesture(minimumDistance: 8, coordinateSpace: .local)
      .onChanged { value in
        guard presentation.cameraState == .founderPOV,
              displayedCamera == .founderPOV,
              cameraOpacity == 1
        else { return }
        if dragStartLook == nil { dragStartLook = lookOrientation }
        guard let start = dragStartLook else { return }
        let sensitivity = FounderGarageCameraConfiguration.dragSensitivityRadiansPerPoint
        let requested = FounderLookOrientation(
          yaw: start.yaw - Float(value.translation.width) * sensitivity,
          pitch: start.pitch - Float(value.translation.height) * sensitivity
        )
        let clamped = FounderGarageCameraConfiguration(spatial: world.spatialSpecification).clamped(requested)
        lookOrientation = clamped
        world.cameraController.setLookOrientation(clamped)
      }
      .onEnded { _ in dragStartLook = nil }
  }

  private func recenterFounderView() {
    dragStartLook = nil
    lookOrientation = .neutral
    world.cameraController.recenterFounderPOV()
  }

  private func cameraControlLabel(_ title: String) -> some View {
    Text(title)
      .padding(.horizontal, 12)
      .frame(minWidth: 44, minHeight: 44)
      .background(.black.opacity(0.65), in: .capsule)
      .contentShape(.capsule)
  }

  private var prototypeHUD: some View {
    VStack(alignment: .leading) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("FOUNDER’S GARAGE")
            .font(.caption2.weight(.black))
            .tracking(1.1)
          Text(presentation.statusLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.76))
            .lineLimit(2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        Spacer()
#if DEBUG
        Menu {
          ForEach(FounderEnvironmentTimeState.allCases, id: \.self) { state in
            Button(state.accessibilityLabel) {
              world.setEnvironmentTimeState(state, reduceMotion: reduceMotion)
            }
            .accessibilityIdentifier(FounderGarageAccessibilityID.environmentTime(state))
            .accessibilityAddTraits(state == world.environmentTimeState ? [.isSelected] : [])
          }
        } label: {
          Label(world.environmentTimeState.title.uppercased(), systemImage: "sun.max.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(.black.opacity(0.65), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Garage Environment Time")
        .accessibilityValue(world.environmentTimeState.title)
        .accessibilityIdentifier(FounderGarageAccessibilityID.environmentTimeMenu)
#endif
      }
      Text(presentation.cameraState.title)
        .font(.caption.weight(.semibold))
        .padding(8)
        .background(.black.opacity(0.65), in: .capsule)
        .accessibilityIdentifier("founderGarage.currentView")
        .accessibilityValue(garageAccessibilityValue)
      Spacer()
      if presentation.cameraState == .founderPOV {
        HStack(spacing: 8) {
          Button { onCameraIntent(.garageOverview) } label: {
            cameraControlLabel("LOOK OUT")
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("founderGarage.lookOut")
          Button(action: recenterFounderView) {
            cameraControlLabel("RECENTER")
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Recenter Founder View")
          .accessibilityHint("Returns your seated view to the Founder Computer.")
          .accessibilityIdentifier("founderGarage.recenter")
          .accessibilityValue(lookOrientation.isNeutral ? "Centered" : "Free look active")
        }
      } else {
        Menu {
          ForEach(FounderGarageCameraState.allCases.filter { $0 != .founderPOV }, id: \.self) { target in
            Button(target.title) { onCameraIntent(target) }
              .accessibilityIdentifier("founderGarage.focus.\(target.rawValue)")
              .accessibilityAddTraits(presentation.cameraState == target ? [.isSelected] : [])
          }
        } label: {
          cameraControlLabel("LOOK OUT")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("founderGarage.focusMenu")
        .accessibilityValue(presentation.cameraState.title)
        Button { onCameraIntent(.founderPOV) } label: {
          cameraControlLabel("Return to Founder View")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("founderGarage.returnWorkstation")
      }
      if presentation.cameraState.allowsComputer {
        Label("Tap the Founder Computer", systemImage: "desktopcomputer")
          .font(.caption.weight(.bold))
          .padding(.horizontal, 12)
          .frame(minWidth: 44, minHeight: 44)
          .background(.black.opacity(0.58), in: .capsule)
          .overlay { Capsule().stroke(.white.opacity(0.20), lineWidth: 1) }
          .accessibilityHidden(true)
          .overlay {
            Button(action: openFounderComputer) {
              Capsule()
                .fill(.clear)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(!presentation.founderComputerAvailable)
            .accessibilityLabel(FounderWorldInteractionAdapter.founderComputerAccessibilityLabel)
            .accessibilityValue(presentation.accessibilitySummary)
            .accessibilityHint(FounderWorldInteractionAdapter.founderComputerAccessibilityHint)
            .accessibilityIdentifier(FounderGarageAccessibilityID.founderComputer)
          }
      }
      if presentation.cameraState == .garageDoor || presentation.cameraState == .front {
        Button {
          world.toggleGarageDoor(reduceMotion: reduceMotion)
        } label: {
          Label(
            world.garageDoorState.controlTitle,
            systemImage: world.garageDoorState.isOpen ? "door.garage.closed" : "door.garage.open"
          )
          .font(.caption.weight(.bold))
          .padding(.horizontal, 12)
          .frame(minWidth: 44, minHeight: 44)
          .background(.black.opacity(0.65), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!world.garageDoorControlAvailable)
        .accessibilityLabel(world.garageDoorState.isOpen ? "Close Garage Door" : "Open Garage Door")
        .accessibilityValue(world.garageDoorState.accessibilityValue)
        .accessibilityHint("Moves the sectional garage door along its overhead tracks.")
        .accessibilityIdentifier(FounderGarageAccessibilityID.garageDoorToggle)
      }
    }
    .foregroundStyle(.white)
    .padding(18)
  }
}
