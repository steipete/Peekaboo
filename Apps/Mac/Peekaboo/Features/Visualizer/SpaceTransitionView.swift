//
//  SpaceTransitionView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import PeekabooCore
import SwiftUI

/// Space transition direction
enum SpaceDirection: String, CaseIterable {
    case left, right, up, down
}

/// Animated space (virtual desktop) transition visualization
struct SpaceTransitionView: View {
    let fromSpace: Int
    let toSpace: Int
    let direction: SpaceDirection
    let duration: TimeInterval

    @State private var slideOffset: CGFloat = 0
    @State private var fromOpacity: Double = 1
    @State private var toOpacity: Double = 0
    @State private var arrowScale: CGFloat = 0
    @State private var numberScale: CGFloat = 1

    private let primaryColor = Color.indigo
    private let secondaryColor = Color.purple

    init(from: Int, to: Int, direction: SpaceDirection, duration: TimeInterval = 1.0) {
        self.fromSpace = from
        self.toSpace = to
        self.direction = direction
        self.duration = duration
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [self.primaryColor.opacity(0.2), self.secondaryColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                // Space panels
                HStack(spacing: 0) {
                    // From space
                    SpacePanel(
                        spaceNumber: self.fromSpace,
                        isActive: true,
                        opacity: self.fromOpacity,
                        scale: self.numberScale,
                        color: self.primaryColor)
                        .frame(width: screenWidth / 2)

                    // To space
                    SpacePanel(
                        spaceNumber: self.toSpace,
                        isActive: false,
                        opacity: self.toOpacity,
                        scale: self.numberScale,
                        color: self.secondaryColor)
                        .frame(width: screenWidth / 2)
                }
                .offset(x: self.slideOffset)

                // Direction arrow
                self.direction.arrowIcon
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .scaleEffect(self.arrowScale)

                // Transition particles
                TransitionParticles(
                    direction: self.direction,
                    progress: abs(self.slideOffset) / (screenWidth / 2),
                    color: self.primaryColor)
            }
        }
        .onAppear {
            self.animateTransition()
        }
    }

    private func animateTransition() {
        // Arrow appearance
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            self.arrowScale = 1.0
        }

        // Slide animation
        withAnimation(.easeInOut(duration: self.duration * 0.7).delay(0.2)) {
            switch self.direction {
            case .left:
                self.slideOffset = (NSScreen.main?.frame.width ?? 1920) / 2
            case .right:
                self.slideOffset = -((NSScreen.main?.frame.width ?? 1920) / 2)
            case .up:
                self.slideOffset = 0 // No horizontal slide for vertical transitions
            case .down:
                self.slideOffset = 0 // No horizontal slide for vertical transitions
            }
        }

        // Opacity transition for all directions
        withAnimation(.easeInOut(duration: self.duration * 0.5).delay(0.3)) {
            self.fromOpacity = 0
            self.toOpacity = 1
        }

        // Number scale animation
        withAnimation(.easeInOut(duration: 0.3).delay(self.duration * 0.5)) {
            self.numberScale = 1.2
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(self.duration * 0.7)) {
            self.numberScale = 1.0
        }

        // Arrow fade out
        withAnimation(.easeOut(duration: 0.3).delay(self.duration - 0.3)) {
            self.arrowScale = 0
        }
    }
}

/// Individual space panel
struct SpacePanel: View {
    let spaceNumber: Int
    let isActive: Bool
    let opacity: Double
    let scale: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            // Space icon
            Image(systemName: "rectangle.inset.filled")
                .font(.system(size: 80))
                .foregroundColor(self.color.opacity(0.6))

            // Space number
            Text("Space \(self.spaceNumber)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(self.isActive ? .white : self.color)
                .scaleEffect(self.scale)

            // Desktop indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(self.color.opacity(0.4))
                        .frame(width: 40, height: 30)
                }
            }
        }
        .opacity(self.opacity)
    }
}

/// Transition particle effects
struct TransitionParticles: View {
    let direction: SpaceDirection
    let progress: CGFloat
    let color: Color

    var body: some View {
        ForEach(0..<12) { index in
            TransitionParticle(
                index: index,
                direction: self.direction,
                progress: self.progress,
                color: self.color)
        }
    }
}

struct TransitionParticle: View {
    let index: Int
    let direction: SpaceDirection
    let progress: CGFloat
    let color: Color

    @State private var randomOffset = CGSize(
        width: CGFloat.random(in: -50...50),
        height: CGFloat.random(in: -50...50))

    var body: some View {
        Circle()
            .fill(self.color.opacity(0.6))
            .frame(width: 6, height: 6)
            .offset(self.particleOffset)
            .opacity(1 - self.progress)
            .blur(radius: self.progress * 2)
    }

    private var particleOffset: CGSize {
        let baseOffset = switch self.direction {
        case .left:
            CGSize(width: -200 * self.progress, height: 0)
        case .right:
            CGSize(width: 200 * self.progress, height: 0)
        case .up:
            CGSize(width: 0, height: -200 * self.progress)
        case .down:
            CGSize(width: 0, height: 200 * self.progress)
        }

        return CGSize(
            width: baseOffset.width + self.randomOffset.width * self.progress,
            height: baseOffset.height + self.randomOffset.height * self.progress)
    }
}

// MARK: - SpaceDirection Extension

extension SpaceDirection {
    var arrowIcon: some View {
        Group {
            switch self {
            case .left:
                Image(systemName: "arrow.left.circle.fill")
            case .right:
                Image(systemName: "arrow.right.circle.fill")
            case .up:
                Image(systemName: "arrow.up.circle.fill")
            case .down:
                Image(systemName: "arrow.down.circle.fill")
            }
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        SpaceTransitionView(
            from: 1,
            to: 2,
            direction: .right)
            .frame(width: 600, height: 300)
            .background(Color.black)

        SpaceTransitionView(
            from: 3,
            to: 1,
            direction: .left)
            .frame(width: 600, height: 300)
            .background(Color.black)
    }
}
