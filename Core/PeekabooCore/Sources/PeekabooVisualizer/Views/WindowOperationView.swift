//
//  WindowOperationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// Animated window operation visualization (close, minimize, maximize, move, resize)
struct WindowOperationView: View {
    let operation: WindowOperation
    let windowRect: CGRect
    let duration: TimeInterval

    @State private var frameScale: CGFloat = 1.0
    @State private var frameOpacity: Double = 1.0
    @State private var iconScale: CGFloat = 0
    @State private var iconOpacity: Double = 0
    @State private var particleProgress: CGFloat = 0

    init(operation: WindowOperation, windowRect: CGRect, duration: TimeInterval = 0.5) {
        self.operation = operation
        self.windowRect = windowRect
        self.duration = duration
    }

    var body: some View {
        ZStack {
            // Window frame outline
            RoundedRectangle(cornerRadius: 8)
                .stroke(self.operation.color, lineWidth: 3)
                .frame(width: self.windowRect.width, height: self.windowRect.height)
                .scaleEffect(self.frameScale)
                .opacity(self.frameOpacity)

            // Operation icon
            self.operation.icon
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(self.operation.color)
                .scaleEffect(self.iconScale)
                .opacity(self.iconOpacity)
                .shadow(color: self.operation.color.opacity(0.5), radius: 10)

            // Directional particles for move/resize
            if self.operation == .move || self.operation == .resize {
                DirectionalParticles(
                    operation: self.operation,
                    progress: self.particleProgress,
                    color: self.operation.color)
            }

            // Corner indicators for resize
            if self.operation == .resize {
                ResizeCorners(
                    scale: self.iconScale,
                    opacity: self.iconOpacity,
                    color: self.operation.color)
            }
        }
        .onAppear {
            self.animateOperation()
        }
    }

    private func animateOperation() {
        switch self.operation {
        case .close:
            self.animateClose()
        case .minimize:
            self.animateMinimize()
        case .maximize:
            self.animateMaximize()
        case .move:
            self.animateMove()
        case .resize:
            self.animateResize()
        case .setBounds:
            self.animateResize() // Use resize animation for setBounds
        case .focus:
            self.animateMaximize() // Use maximize animation for focus
        }
    }

    private func animateClose() {
        // Icon appears
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.iconScale = 1.0
            self.iconOpacity = 1.0
        }

        // Frame shrinks and fades
        withAnimation(.easeIn(duration: self.duration).delay(0.2)) {
            self.frameScale = 0.8
            self.frameOpacity = 0
        }

        // Icon fades
        withAnimation(.easeOut(duration: 0.2).delay(self.duration - 0.1)) {
            self.iconOpacity = 0
            self.iconScale = 0.5
        }
    }

    private func animateMinimize() {
        // Icon appears
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.iconScale = 1.0
            self.iconOpacity = 1.0
        }

        // Frame minimizes downward
        withAnimation(.easeIn(duration: self.duration).delay(0.2)) {
            self.frameScale = 0.1
            self.frameOpacity = 0
        }

        // Icon drops
        withAnimation(.easeIn(duration: self.duration).delay(0.2)) {
            self.iconOpacity = 0
        }
    }

    private func animateMaximize() {
        // Icon appears
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.iconScale = 1.0
            self.iconOpacity = 1.0
        }

        // Frame expands
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
            self.frameScale = 1.2
        }

        // Fade out
        withAnimation(.easeOut(duration: 0.3).delay(self.duration - 0.3)) {
            self.frameOpacity = 0
            self.iconOpacity = 0
        }
    }

    private func animateMove() {
        // Icon appears
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.iconScale = 1.0
            self.iconOpacity = 1.0
        }

        // Particle animation
        withAnimation(.easeInOut(duration: self.duration)) {
            self.particleProgress = 1.0
        }

        // Fade out
        withAnimation(.easeOut(duration: 0.3).delay(self.duration - 0.3)) {
            self.frameOpacity = 0
            self.iconOpacity = 0
        }
    }

    private func animateResize() {
        // Icon and corners appear
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.iconScale = 1.0
            self.iconOpacity = 1.0
        }

        // Frame pulses
        withAnimation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)) {
            self.frameScale = 1.05
        }

        // Fade out
        withAnimation(.easeOut(duration: 0.3).delay(self.duration - 0.3)) {
            self.frameOpacity = 0
            self.iconOpacity = 0
        }
    }
}

// MARK: - Supporting Views

struct DirectionalParticles: View {
    let operation: WindowOperation
    let progress: CGFloat
    let color: Color

    var body: some View {
        ForEach(0..<8) { index in
            DirectionalParticle(
                index: index,
                operation: self.operation,
                progress: self.progress,
                color: self.color)
        }
    }
}

struct DirectionalParticle: View {
    let index: Int
    let operation: WindowOperation
    let progress: CGFloat
    let color: Color

    private var angle: Double {
        Double(self.index) * 45.0
    }

    var body: some View {
        Image(systemName: self.operation == .move ? "arrow.right" : "arrow.up.left.and.down.right.magnifyingglass")
            .font(.system(size: 12))
            .foregroundColor(self.color)
            .rotationEffect(.degrees(self.angle))
            .offset(
                x: cos(self.angle * .pi / 180) * 50 * self.progress,
                y: sin(self.angle * .pi / 180) * 50 * self.progress)
            .opacity(1 - self.progress)
    }
}

struct ResizeCorners: View {
    let scale: CGFloat
    let opacity: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            // Corner indicators
            ForEach(0..<4) { index in
                ResizeCornerIndicator(color: self.color)
                    .position(self.cornerPosition(for: index, in: size))
                    .scaleEffect(self.scale)
                    .opacity(self.opacity)
            }
        }
    }

    private func cornerPosition(for index: Int, in size: CGSize) -> CGPoint {
        switch index {
        case 0: CGPoint(x: 0, y: 0) // Top-left
        case 1: CGPoint(x: size.width, y: 0) // Top-right
        case 2: CGPoint(x: 0, y: size.height) // Bottom-left
        case 3: CGPoint(x: size.width, y: size.height) // Bottom-right
        default: .zero
        }
    }
}

struct ResizeCornerIndicator: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(self.color)
                .frame(width: 12, height: 12)

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - WindowOperation Extension

extension WindowOperation {
    var color: Color {
        switch self {
        case .close:
            .red
        case .minimize:
            .orange
        case .maximize:
            .green
        case .move:
            .blue
        case .resize:
            .purple
        case .setBounds:
            .indigo
        case .focus:
            .cyan
        }
    }

    @ViewBuilder
    var icon: some View {
        switch self {
        case .close:
            Image(systemName: "xmark.circle.fill")
        case .minimize:
            Image(systemName: "minus.circle.fill")
        case .maximize:
            Image(systemName: "plus.circle.fill")
        case .move:
            Image(systemName: "move.3d")
        case .resize:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        case .setBounds:
            Image(systemName: "rectangle.dashed")
        case .focus:
            Image(systemName: "scope")
        }
    }
}

// Helper extension for CGSize scale effect
extension View {
    func scaleEffect(_ scale: CGSize) -> some View {
        self.scaleEffect(x: scale.width, y: scale.height)
    }
}

#Preview {
    VStack(spacing: 50) {
        WindowOperationView(
            operation: .close,
            windowRect: CGRect(x: 0, y: 0, width: 300, height: 200))
            .frame(width: 400, height: 300)
            .background(Color.black.opacity(0.1))

        WindowOperationView(
            operation: .resize,
            windowRect: CGRect(x: 0, y: 0, width: 300, height: 200))
            .frame(width: 400, height: 300)
            .background(Color.black.opacity(0.1))
    }
}
