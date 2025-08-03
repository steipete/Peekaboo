import AppKit
import SwiftUI

/// A SwiftUI view that renders an animated ghost for the menu bar.
///
/// The ghost floats up and down with a gentle sine wave motion and includes
/// subtle opacity variations for a "breathing" effect. Designed to be rendered
/// to an NSImage for menu bar display.
struct GhostAnimationView: View {
    /// Current vertical offset for floating animation
    @State private var verticalOffset: CGFloat = 0
    /// Current horizontal offset for floating animation
    @State private var horizontalOffset: CGFloat = 0
    /// Current scale for size animation
    @State private var scale: CGFloat = 1.0
    /// Current opacity for breathing effect
    @State private var opacity: Double = 1.0
    /// Animation phase for coordinated effects
    @State private var animationPhase: Double = 0

    /// Whether the ghost should be animating
    let isAnimating: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let ghostSize: CGFloat = 16 // Slightly smaller than 18x18 frame for margins
    private let floatAmplitude: CGFloat = 2.0 // ±2.0 pixels vertical movement for calmer motion
    private let horizontalAmplitude: CGFloat = 1.0 // ±1.0 pixels horizontal movement
    private let scaleAmplitude: CGFloat = 0.1 // ±10% size variation
    private let animationDuration: Double = 3.0 // Full cycle duration (slower for more relaxed feel)

    var body: some View {
        Canvas { context, size in
            // Center point for drawing
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Calculate animated position
            let animatedX = center.x + (self.isAnimating ? self.horizontalOffset : 0)
            let animatedY = center.y + (self.isAnimating ? self.verticalOffset : 0)
            let drawCenter = CGPoint(x: animatedX, y: animatedY)

            // Apply scale transformation
            context.scaleBy(x: self.scale, y: self.scale)

            // Ghost color based on appearance
            let ghostColor = self.colorScheme == .dark ? Color.white : Color.black

            // Draw ghost body with classic ghost shape
            let bodyPath = Path { path in
                // Start with circular top
                let headRadius = self.ghostSize * 0.4
                let headCenter = CGPoint(x: drawCenter.x, y: drawCenter.y - self.ghostSize * 0.15)

                path.move(to: CGPoint(x: headCenter.x - headRadius, y: headCenter.y))

                // Draw the head (top semicircle)
                path.addArc(
                    center: headCenter,
                    radius: headRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false)

                // Draw the body sides
                path.addLine(to: CGPoint(x: headCenter.x + headRadius, y: drawCenter.y + self.ghostSize * 0.25))

                // Draw wavy bottom with 3 curves
                let bottomY = drawCenter.y + self.ghostSize * 0.25
                let waveWidth = (headRadius * 2) / 3

                // Right wave
                path.addCurve(
                    to: CGPoint(x: headCenter.x + waveWidth / 2, y: bottomY + self.ghostSize * 0.15),
                    control1: CGPoint(x: headCenter.x + headRadius, y: bottomY),
                    control2: CGPoint(x: headCenter.x + headRadius - waveWidth / 4, y: bottomY + self.ghostSize * 0.15))

                // Middle wave
                path.addCurve(
                    to: CGPoint(x: headCenter.x - waveWidth / 2, y: bottomY + self.ghostSize * 0.15),
                    control1: CGPoint(x: headCenter.x + waveWidth / 4, y: bottomY + self.ghostSize * 0.15),
                    control2: CGPoint(x: headCenter.x - waveWidth / 4, y: bottomY + self.ghostSize * 0.15))

                // Left wave
                path.addCurve(
                    to: CGPoint(x: headCenter.x - headRadius, y: bottomY),
                    control1: CGPoint(x: headCenter.x - headRadius + waveWidth / 4, y: bottomY + self.ghostSize * 0.15),
                    control2: CGPoint(x: headCenter.x - headRadius, y: bottomY))

                // Close the path
                path.addLine(to: CGPoint(x: headCenter.x - headRadius, y: headCenter.y))
            }

            // Draw ghost with current opacity
            context.fill(
                bodyPath,
                with: .color(ghostColor.opacity(self.opacity * (self.colorScheme == .dark ? 0.9 : 0.8))))

            // Draw eyes
            let eyeRadius: CGFloat = 2.0
            let eyeSpacing: CGFloat = self.ghostSize * 0.2
            let eyeY = drawCenter.y - self.ghostSize * 0.15

            // Left eye
            let leftEyePath = Path { path in
                path.addEllipse(in: CGRect(
                    x: drawCenter.x - eyeSpacing - eyeRadius,
                    y: eyeY - eyeRadius,
                    width: eyeRadius * 2,
                    height: eyeRadius * 2))
            }

            // Right eye
            let rightEyePath = Path { path in
                path.addEllipse(in: CGRect(
                    x: drawCenter.x + eyeSpacing - eyeRadius,
                    y: eyeY - eyeRadius,
                    width: eyeRadius * 2,
                    height: eyeRadius * 2))
            }

            // Draw eyes with inverted color
            let eyeColor = self.colorScheme == .dark ? Color.black : Color.white
            context.fill(leftEyePath, with: .color(eyeColor))
            context.fill(rightEyePath, with: .color(eyeColor))

            // Add cute mouth when animating
            if self.isAnimating {
                let mouthPath = Path { path in
                    let mouthY = eyeY + eyeRadius * 2.5
                    let mouthWidth = eyeSpacing * 1.2

                    path.move(to: CGPoint(x: drawCenter.x - mouthWidth / 2, y: mouthY))
                    path.addCurve(
                        to: CGPoint(x: drawCenter.x + mouthWidth / 2, y: mouthY),
                        control1: CGPoint(x: drawCenter.x - mouthWidth / 4, y: mouthY + 1),
                        control2: CGPoint(x: drawCenter.x + mouthWidth / 4, y: mouthY + 1))
                }
                context.stroke(mouthPath, with: .color(eyeColor), lineWidth: 0.8)
            }
        }
        .frame(width: 18, height: 18) // Standard menu bar icon size
        .drawingGroup() // Optimize rendering
        .onAppear {
            if self.isAnimating {
                self.startAnimation()
            }
        }
        .onChange(of: self.isAnimating) { _, newValue in
            if newValue {
                self.startAnimation()
            } else {
                self.stopAnimation()
            }
        }
    }

    private func startAnimation() {
        // Reset to neutral position
        self.verticalOffset = 0
        self.horizontalOffset = 0
        self.scale = 1.0
        self.opacity = 1.0
        self.animationPhase = 0

        // Start vertical floating animation
        withAnimation(
            .easeInOut(duration: self.animationDuration)
                .repeatForever(autoreverses: true))
        {
            self.verticalOffset = self.floatAmplitude
        }

        // Start horizontal floating animation (different speed for organic movement)
        withAnimation(
            .easeInOut(duration: self.animationDuration * 1.2)
                .repeatForever(autoreverses: true))
        {
            self.horizontalOffset = self.horizontalAmplitude
        }

        // Start scale animation
        withAnimation(
            .easeInOut(duration: self.animationDuration * 0.8)
                .repeatForever(autoreverses: true))
        {
            self.scale = 1.0 + self.scaleAmplitude
        }

        // Start breathing animation (slightly offset from floating)
        withAnimation(
            .easeInOut(duration: self.animationDuration * 0.9)
                .repeatForever(autoreverses: true))
        {
            self.opacity = 0.8
        }

        // Wave animation for bottom edge
        withAnimation(
            .linear(duration: self.animationDuration * 2)
                .repeatForever(autoreverses: false))
        {
            self.animationPhase = .pi * 2
        }
    }

    private func stopAnimation() {
        // Smoothly return to neutral position
        withAnimation(.easeOut(duration: 0.3)) {
            self.verticalOffset = 0
            self.horizontalOffset = 0
            self.scale = 1.0
            self.opacity = 1.0
            self.animationPhase = 0
        }
    }
}

// MARK: - Ghost Icon Cache Key

/// Cache key for storing rendered ghost images
struct GhostIconCacheKey: Hashable {
    let isAnimating: Bool
    let verticalOffset: Int // Quantized to reduce variations
    let horizontalOffset: Int // Quantized horizontal offset
    let scale: Int // Quantized scale (0-20)
    let opacity: Int // Quantized opacity (0-10)
    let isDarkMode: Bool
}

// MARK: - Preview

#Preview("Ghost Animation") {
    VStack(spacing: 20) {
        Text("Static Ghost")
        GhostAnimationView(isAnimating: false)
            .scaleEffect(4) // Make it easier to see
            .background(Color.gray.opacity(0.2))

        Text("Animated Ghost")
        GhostAnimationView(isAnimating: true)
            .scaleEffect(4) // Make it easier to see
            .background(Color.gray.opacity(0.2))
    }
    .padding()
    .frame(width: 300, height: 400)
}
