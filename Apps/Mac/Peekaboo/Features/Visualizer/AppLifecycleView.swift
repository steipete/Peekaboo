//
//  AppLifecycleView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// Animated app launch/quit visualization with app icon and effects
struct AppLifecycleView: View {
    let appName: String
    let iconPath: String?
    let action: LifecycleAction
    let duration: TimeInterval

    @State private var iconScale: CGFloat = 0
    @State private var iconOpacity: Double = 0
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0
    @State private var particleScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var bounceOffset: CGFloat = 0

    enum LifecycleAction {
        case launch
        case quit

        var color: Color {
            switch self {
            case .launch:
                .green
            case .quit:
                .red
            }
        }

        var symbol: String {
            switch self {
            case .launch:
                "arrow.up.circle.fill"
            case .quit:
                "xmark.circle.fill"
            }
        }

        var text: String {
            switch self {
            case .launch:
                "Launching"
            case .quit:
                "Quitting"
            }
        }
    }

    init(appName: String, iconPath: String?, action: LifecycleAction, duration: TimeInterval = 2.0) {
        self.appName = appName
        self.iconPath = iconPath
        self.action = action
        self.duration = duration
    }

    var body: some View {
        ZStack {
            // Ripple effect
            Circle()
                .stroke(self.action.color.opacity(0.6), lineWidth: 3)
                .scaleEffect(self.rippleScale)
                .opacity(self.rippleOpacity)

            // App icon or placeholder
            VStack(spacing: 20) {
                ZStack {
                    // Icon background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    self.action.color.opacity(0.3),
                                    self.action.color.opacity(0.1),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)

                    // App icon
                    if let iconPath,
                       let image = NSImage(contentsOfFile: iconPath)
                    {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                            .shadow(color: self.action.color.opacity(0.5), radius: 10)
                    } else {
                        // Fallback icon
                        Image(systemName: "app.fill")
                            .font(.system(size: 48))
                            .foregroundColor(self.action.color)
                    }

                    // Action overlay
                    Image(systemName: self.action.symbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(self.action.color)
                                .frame(width: 32, height: 32))
                        .offset(x: 28, y: 28)
                }
                .scaleEffect(self.iconScale)
                .opacity(self.iconOpacity)
                .offset(y: self.bounceOffset)

                // App name and action
                VStack(spacing: 4) {
                    Text(self.action.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(self.action.color)

                    Text(self.appName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .opacity(self.textOpacity)
            }

            // Particle effects
            ForEach(0..<8) { index in
                AppParticle(
                    index: index,
                    color: self.action.color,
                    scale: self.particleScale,
                    isLaunch: self.action == .launch)
            }
        }
        .onAppear {
            self.animateLifecycle()
        }
    }

    private func animateLifecycle() {
        // Icon entrance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            self.iconScale = 1.0
            self.iconOpacity = 1.0
        }

        // Bounce effect for launch
        if self.action == .launch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.2)) {
                self.bounceOffset = -20
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.4)) {
                self.bounceOffset = 0
            }
        }

        // Ripple animation
        withAnimation(.easeOut(duration: self.duration * 0.8)) {
            self.rippleScale = 3.0
            self.rippleOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(self.duration * 0.5)) {
            self.rippleOpacity = 0
        }

        // Text fade in
        withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
            self.textOpacity = 1.0
        }

        // Particle animation
        withAnimation(.easeOut(duration: self.duration * 0.6).delay(0.2)) {
            self.particleScale = 1.0
        }

        // Fade out
        let fadeDelay = self.duration - 0.5
        withAnimation(.easeOut(duration: 0.5).delay(fadeDelay)) {
            self.iconOpacity = 0
            self.textOpacity = 0

            // Different exit for quit
            if self.action == .quit {
                self.iconScale = 0.5
            } else {
                self.iconScale = 1.2
            }
        }
    }
}

/// Particle effect for app lifecycle
struct AppParticle: View {
    let index: Int
    let color: Color
    let scale: CGFloat
    let isLaunch: Bool

    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1

    private var angle: Double {
        Double(self.index) * (360.0 / 8.0)
    }

    var body: some View {
        Image(systemName: self.isLaunch ? "sparkle" : "xmark")
            .font(.system(size: 16))
            .foregroundColor(self.color)
            .offset(self.offset)
            .opacity(self.opacity * self.scale)
            .onAppear {
                self.animateParticle()
            }
    }

    private func animateParticle() {
        let radians = self.angle * .pi / 180
        let distance: CGFloat = self.isLaunch ? 80 : -60

        withAnimation(.easeOut(duration: 0.8)) {
            self.offset = CGSize(
                width: cos(radians) * distance,
                height: sin(radians) * distance)
            self.opacity = 0
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        AppLifecycleView(
            appName: "Safari",
            iconPath: nil,
            action: .launch)
            .frame(width: 300, height: 300)
            .background(Color.black.opacity(0.8))

        AppLifecycleView(
            appName: "TextEdit",
            iconPath: nil,
            action: .quit)
            .frame(width: 300, height: 300)
            .background(Color.black.opacity(0.8))
    }
}
