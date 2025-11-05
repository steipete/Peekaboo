import SwiftUI

/// A SwiftUI view that provides ghost images for different states
struct GhostImageView: View {
    enum GhostState {
        case idle
        case peek1
        case peek2
    }

    let state: GhostState
    let size: CGSize

    @Environment(\.colorScheme) private var colorScheme

    init(state: GhostState = .idle, size: CGSize = CGSize(width: 64, height: 64)) {
        self.state = state
        self.size = size
    }

    var body: some View {
        Canvas { context, canvasSize in
            // Center point for drawing (for future use)
            _ = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            // Scale to fit the requested size
            let scale = min(canvasSize.width / 20, canvasSize.height / 20)
            context.scaleBy(x: scale, y: scale)

            // Ghost color based on appearance
            let ghostColor = self.colorScheme == .dark ? Color.white : Color.black

            // Draw ghost body
            let bodyPath = Path { path in
                // Circular top
                path.addArc(
                    center: CGPoint(x: 10, y: 10),
                    radius: 6,
                    startAngle: .radians(.pi),
                    endAngle: .radians(0),
                    clockwise: false)

                // Body sides
                path.addLine(to: CGPoint(x: 16, y: 14))

                // Bottom waves
                path.addLine(to: CGPoint(x: 16, y: 16))

                // Wave pattern at bottom
                path.addCurve(
                    to: CGPoint(x: 14, y: 17),
                    control1: CGPoint(x: 16, y: 17),
                    control2: CGPoint(x: 15, y: 17))
                path.addCurve(
                    to: CGPoint(x: 12, y: 16),
                    control1: CGPoint(x: 13, y: 17),
                    control2: CGPoint(x: 12, y: 17))
                path.addCurve(
                    to: CGPoint(x: 10, y: 17),
                    control1: CGPoint(x: 12, y: 17),
                    control2: CGPoint(x: 11, y: 17))
                path.addCurve(
                    to: CGPoint(x: 8, y: 16),
                    control1: CGPoint(x: 9, y: 17),
                    control2: CGPoint(x: 8, y: 17))
                path.addCurve(
                    to: CGPoint(x: 6, y: 17),
                    control1: CGPoint(x: 8, y: 17),
                    control2: CGPoint(x: 7, y: 17))
                path.addCurve(
                    to: CGPoint(x: 4, y: 16),
                    control1: CGPoint(x: 5, y: 17),
                    control2: CGPoint(x: 4, y: 17))

                // Complete the body
                path.addLine(to: CGPoint(x: 4, y: 14))
                path.addLine(to: CGPoint(x: 4, y: 10))
                path.closeSubpath()
            }

            // Draw the ghost body
            context.fill(bodyPath, with: .color(ghostColor.opacity(self.state == .idle ? 0.9 : 1.0)))

            // Draw eyes based on state
            switch self.state {
            case .idle:
                // Normal eyes
                context.fill(
                    Circle().path(in: CGRect(x: 6.5, y: 8, width: 1.5, height: 1.5)),
                    with: .color(self.colorScheme == .dark ? .black : .white))
                context.fill(
                    Circle().path(in: CGRect(x: 11.5, y: 8, width: 1.5, height: 1.5)),
                    with: .color(self.colorScheme == .dark ? .black : .white))

            case .peek1:
                // Looking to the side
                context.fill(
                    Circle().path(in: CGRect(x: 7.5, y: 8, width: 1.5, height: 1.5)),
                    with: .color(self.colorScheme == .dark ? .black : .white))
                context.fill(
                    Circle().path(in: CGRect(x: 12.5, y: 8, width: 1.5, height: 1.5)),
                    with: .color(self.colorScheme == .dark ? .black : .white))

            case .peek2:
                // Wide eyes
                context.fill(
                    Circle().path(in: CGRect(x: 6, y: 7.5, width: 2, height: 2)),
                    with: .color(self.colorScheme == .dark ? .black : .white))
                context.fill(
                    Circle().path(in: CGRect(x: 11, y: 7.5, width: 2, height: 2)),
                    with: .color(self.colorScheme == .dark ? .black : .white))
            }
        }
        .frame(width: self.size.width, height: self.size.height)
    }
}

// Create a view modifier to replace Image("ghost.idle") etc.
extension Image {
    @MainActor
    static var ghostIdle: some View {
        GhostImageView(state: .idle)
    }

    @MainActor
    static var ghostPeek1: some View {
        GhostImageView(state: .peek1)
    }

    @MainActor
    static var ghostPeek2: some View {
        GhostImageView(state: .peek2)
    }
}
