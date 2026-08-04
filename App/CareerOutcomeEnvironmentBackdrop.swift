import SwiftUI

struct CareerOutcomeEnvironmentBackdrop: View {
  var kind: CareerOutcomeKind

  var body: some View {
    ZStack {
      SoloTheme.background.ignoresSafeArea()
      switch CareerEnvironmentTreatment(kind) {
      case .victory:
        LinearGradient(
          colors: [SoloTheme.cyan.opacity(0.2), SoloTheme.amber.opacity(0.12), Color.red.opacity(0.12), .clear],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .bankruptcy:
        LinearGradient(colors: [.black.opacity(0.82), SoloTheme.background], startPoint: .top, endPoint: .bottom)
      case .burnout:
        RadialGradient(
          colors: [SoloTheme.amber.opacity(0.1), SoloTheme.background.opacity(0.95)],
          center: .bottom,
          startRadius: 20,
          endRadius: 360
        )
      case .trustCollapse:
        ZStack {
          SoloTheme.background
          Path { path in
            path.move(to: CGPoint(x: 25, y: 80))
            path.addLine(to: CGPoint(x: 170, y: 210))
            path.addLine(to: CGPoint(x: 110, y: 380))
            path.move(to: CGPoint(x: 360, y: 120))
            path.addLine(to: CGPoint(x: 210, y: 250))
            path.addLine(to: CGPoint(x: 300, y: 430))
          }
          .stroke(SoloTheme.amber.opacity(0.22), style: StrokeStyle(lineWidth: 2, dash: [8, 10]))
        }
      }
    }
    .accessibilityHidden(true)
  }
}
