//
//  SwipePathView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// Animated swipe gesture visualization with directional indicators
struct SwipePathView: View {
    let fromPoint: CGPoint
    let toPoint: CGPoint
    let duration: TimeInterval
    let isTouch: Bool // Touch gesture vs mouse drag
    let windowFrame: CGRect

    @State private var pathProgress: CGFloat = 0
    @State private var fingerScale: CGFloat = 0
    @State private var arrowScale: CGFloat = 0
    @State private var pathOpacity: Double = 1
    @State private var rippleScale: CGFloat = 1

    private let primaryColor = Color.purple
    private let secondaryColor = Color.pink

    init(from: CGPoint, to: CGPoint, duration: TimeInterval = 0.5, isTouch: Bool = true, windowFrame: CGRect = .zero) {
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
        self.isTouch = isTouch
    }

    var body: some View {
        ZStack {
            // Path visualization
            Path { path in
                path.move(to: self.fromPoint)
                path.addCurve(
                    to: self.toPoint,
                    control1: CGPoint(
                        x: self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * 0.3,
                        y: self.fromPoint.y),
                    control2: CGPoint(
                        x: self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * 0.7,
                        y: self.toPoint.y))
            }
            .trim(from: 0, to: self.pathProgress)
            .stroke(
                LinearGradient(
                    colors: [self.primaryColor, self.secondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing),
                style: StrokeStyle(
                    lineWidth: 4,
                    lineCap: .round,
                    lineJoin: .round))
            .opacity(self.pathOpacity)
            .shadow(color: self.primaryColor.opacity(0.5), radius: 5)

            // Start point indicator
            if self.isTouch {
                // Finger touch point
                ZStack {
                    // Ripple effect
                    Circle()
                        .stroke(self.primaryColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(self.rippleScale)
                        .opacity(2 - self.rippleScale)

                    // Finger icon
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 30))
                        .foregroundColor(self.primaryColor)
                        .scaleEffect(self.fingerScale)
                        .rotationEffect(self.angleForSwipe)
                }
                .position(self.fromPoint)
            } else {
                // Mouse drag start
                Circle()
                    .fill(self.primaryColor)
                    .frame(width: 12, height: 12)
                    .scaleEffect(self.fingerScale)
                    .position(self.fromPoint)
            }

            // Direction arrow at end
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(self.secondaryColor)
                .rotationEffect(self.angleForSwipe)
                .scaleEffect(self.arrowScale)
                .position(self.toPoint)
                .shadow(color: self.secondaryColor.opacity(0.5), radius: 8)

            // Motion blur particles along path
            ForEach(0..<8) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [self.primaryColor, self.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing))
                    .frame(width: 6, height: 6)
                    .position(self.particlePosition(for: index))
                    .opacity(self.pathOpacity * 0.6)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            self.animateSwipe()
        }
    }

    private var angleForSwipe: Angle {
        let dx = self.toPoint.x - self.fromPoint.x
        let dy = self.toPoint.y - self.fromPoint.y
        return Angle(radians: atan2(dy, dx))
    }

    private func particlePosition(for index: Int) -> CGPoint {
        let progress = self.pathProgress * (CGFloat(index) / 8.0)
        let t = progress

        // Bezier curve calculation
        let x = (1 - t) * (1 - t) * (1 - t) * self.fromPoint.x +
            3 * (1 - t) * (1 - t) * t * (self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * 0.3) +
            3 * (1 - t) * t * t * (self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * 0.7) +
            t * t * t * self.toPoint.x

        let y = (1 - t) * (1 - t) * (1 - t) * self.fromPoint.y +
            3 * (1 - t) * (1 - t) * t * self.fromPoint.y +
            3 * (1 - t) * t * t * self.toPoint.y +
            t * t * t * self.toPoint.y

        return CGPoint(x: x, y: y)
    }

    private func animateSwipe() {
        // Start point animation
        withAnimation(.easeOut(duration: 0.2)) {
            self.fingerScale = 1.0
        }

        // Ripple animation for touch
        if self.isTouch {
            withAnimation(.easeOut(duration: self.duration)) {
                self.rippleScale = 2.0
            }
        }

        // Path animation
        withAnimation(.easeInOut(duration: self.duration * 0.8)) {
            self.pathProgress = 1.0
        }

        // End arrow animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(self.duration * 0.6)) {
            self.arrowScale = 1.0
        }

        // Fade out
        withAnimation(.easeOut(duration: 0.3).delay(self.duration)) {
            self.pathOpacity = 0
        }
    }
}

#Preview {
    VStack {
        SwipePathView(
            from: CGPoint(x: 50, y: 200),
            to: CGPoint(x: 350, y: 200),
            duration: 0.8,
            isTouch: true)
            .frame(width: 400, height: 400)
            .background(Color.black.opacity(0.1))

        SwipePathView(
            from: CGPoint(x: 200, y: 50),
            to: CGPoint(x: 200, y: 350),
            duration: 0.8,
            isTouch: false)
            .frame(width: 400, height: 400)
            .background(Color.black.opacity(0.1))
    }
}
