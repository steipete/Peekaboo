//
//  MouseTrailView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// Animated mouse trail visualization showing cursor movement path
struct MouseTrailView: View {
    let fromPoint: CGPoint
    let toPoint: CGPoint
    let duration: TimeInterval
    let color: Color
    let windowFrame: CGRect

    @State private var trailProgress: CGFloat = 0
    @State private var trailOpacity: Double = 1
    @State private var cursorScale: CGFloat = 1.5

    init(from: CGPoint, to: CGPoint, duration: TimeInterval = 1.0, color: Color = .blue, windowFrame: CGRect = .zero) {
        // If windowFrame is provided, translate points from screen to window coordinates
        if windowFrame != .zero {
            self.fromPoint = CGPoint(
                x: from.x - windowFrame.minX,
                y: from.y - windowFrame.minY)
            self.toPoint = CGPoint(
                x: to.x - windowFrame.minX,
                y: to.y - windowFrame.minY)
        } else {
            self.fromPoint = from
            self.toPoint = to
        }
        self.windowFrame = windowFrame
        self.duration = duration
        self.color = color
    }

    var body: some View {
        ZStack {
            // Trail path
            Path { path in
                path.move(to: self.fromPoint)
                path.addLine(to: self.toPoint)
            }
            .trim(from: 0, to: self.trailProgress)
            .stroke(
                LinearGradient(
                    colors: [self.color.opacity(0.1), self.color],
                    startPoint: .leading,
                    endPoint: .trailing),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [5, 3]))
            .opacity(self.trailOpacity)

            // Animated cursor
            Image(systemName: "cursorarrow")
                .font(.system(size: 24))
                .foregroundColor(self.color)
                .scaleEffect(self.cursorScale)
                .position(self.currentCursorPosition)
                .shadow(color: self.color.opacity(0.5), radius: 10)

            // Trail particles
            ForEach(0..<5) { index in
                Circle()
                    .fill(self.color.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .position(self.particlePosition(for: index))
                    .opacity(self.trailOpacity)
                    .scaleEffect(1 - (CGFloat(index) * 0.15))
            }
        }
        .onAppear {
            self.animateTrail()
        }
    }

    private var currentCursorPosition: CGPoint {
        let x = self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * self.trailProgress
        let y = self.fromPoint.y + (self.toPoint.y - self.fromPoint.y) * self.trailProgress
        return CGPoint(x: x, y: y)
    }

    private func particlePosition(for index: Int) -> CGPoint {
        let delay = CGFloat(index) * 0.1
        let adjustedProgress = max(0, trailProgress - delay)
        let x = self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * adjustedProgress
        let y = self.fromPoint.y + (self.toPoint.y - self.fromPoint.y) * adjustedProgress
        return CGPoint(x: x, y: y)
    }

    private func animateTrail() {
        // Animate trail drawing
        withAnimation(.easeInOut(duration: self.duration)) {
            self.trailProgress = 1.0
        }

        // Pulse cursor
        withAnimation(.easeInOut(duration: 0.3).repeatCount(Int(self.duration / 0.3), autoreverses: true)) {
            self.cursorScale = 1.2
        }

        // Fade out at the end
        withAnimation(.easeOut(duration: 0.3).delay(self.duration - 0.3)) {
            self.trailOpacity = 0
        }
    }
}

#Preview {
    MouseTrailView(
        from: CGPoint(x: 100, y: 100),
        to: CGPoint(x: 300, y: 300),
        duration: 1.0)
        .frame(width: 400, height: 400)
        .background(Color.black.opacity(0.1))
}
