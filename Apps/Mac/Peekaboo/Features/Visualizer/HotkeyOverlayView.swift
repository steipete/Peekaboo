//
//  HotkeyOverlayView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// Animated keyboard shortcut visualization with key highlights
struct HotkeyOverlayView: View {
    let keys: [String]
    let duration: TimeInterval

    @State private var keyScales: [CGFloat] = []
    @State private var keyOpacities: [Double] = []
    @State private var backgroundScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0
    @State private var particleOpacity: Double = 0

    private let primaryColor = Color.orange
    private let secondaryColor = Color.red

    init(keys: [String], duration: TimeInterval = 1.5) {
        self.keys = keys
        self.duration = duration
        self._keyScales = State(initialValue: Array(repeating: 0, count: keys.count))
        self._keyOpacities = State(initialValue: Array(repeating: 0, count: keys.count))
    }

    var body: some View {
        ZStack {
            // Background glow
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    RadialGradient(
                        colors: [
                            self.primaryColor.opacity(0.3),
                            self.primaryColor.opacity(0.1),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200))
                .scaleEffect(self.backgroundScale)
                .opacity(self.glowOpacity)
                .blur(radius: 20)

            // Key container
            HStack(spacing: 8) {
                ForEach(Array(self.keys.enumerated()), id: \.offset) { index, key in
                    HotkeyKeyView(
                        key: key,
                        scale: self.keyScales[safe: index] ?? 0,
                        opacity: self.keyOpacities[safe: index] ?? 0,
                        primaryColor: self.primaryColor,
                        secondaryColor: self.secondaryColor)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [self.primaryColor, self.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 2)))

            // Particle effects
            ForEach(0..<12) { index in
                ParticleView(
                    index: index,
                    primaryColor: self.primaryColor,
                    opacity: self.particleOpacity)
            }
        }
        .onAppear {
            self.animateHotkey()
        }
    }

    private func animateHotkey() {
        // Background glow animation
        withAnimation(.easeIn(duration: 0.2)) {
            self.glowOpacity = 1
            self.backgroundScale = 1.2
        }

        // Sequential key animations
        for index in self.keys.indices {
            let delay = Double(index) * 0.1

            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(delay)) {
                if index < self.keyScales.count {
                    self.keyScales[index] = 1.0
                    self.keyOpacities[index] = 1.0
                }
            }
        }

        // Particle animation
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            self.particleOpacity = 1
        }

        // Fade out
        let fadeDelay = self.duration - 0.5
        withAnimation(.easeOut(duration: 0.5).delay(fadeDelay)) {
            self.glowOpacity = 0
            self.backgroundScale = 1.5
            self.particleOpacity = 0
        }

        for index in self.keyOpacities.indices {
            withAnimation(.easeOut(duration: 0.5).delay(fadeDelay)) {
                self.keyOpacities[index] = 0
            }
        }
    }
}

/// Individual key visualization for hotkey overlay
struct HotkeyKeyView: View {
    let key: String
    let scale: CGFloat
    let opacity: Double
    let primaryColor: Color
    let secondaryColor: Color

    var body: some View {
        ZStack {
            // Key background
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.gray.opacity(0.8),
                        ],
                        startPoint: .top,
                        endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

            // Key border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)

            // Highlight effect
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [self.primaryColor.opacity(0.5), self.secondaryColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .opacity(self.opacity * 0.7)

            // Key label
            Text(self.formatKeyLabel(self.key))
                .font(.system(size: self.keyFontSize(for: self.key), weight: .medium, design: .rounded))
                .foregroundColor(.black)
        }
        .frame(width: self.keyWidth(for: self.key), height: 40)
        .scaleEffect(self.scale)
        .opacity(self.opacity)
    }

    private func formatKeyLabel(_ key: String) -> String {
        // Convert key names to display symbols
        switch key.lowercased() {
        case "cmd", "command":
            "⌘"
        case "shift":
            "⇧"
        case "option", "alt":
            "⌥"
        case "ctrl", "control":
            "⌃"
        case "fn":
            "fn"
        case "space":
            "␣"
        case "return", "enter":
            "⏎"
        case "delete", "backspace":
            "⌫"
        case "escape", "esc":
            "⎋"
        case "tab":
            "⇥"
        case "arrow_up", "up":
            "↑"
        case "arrow_down", "down":
            "↓"
        case "arrow_left", "left":
            "←"
        case "arrow_right", "right":
            "→"
        default:
            key.uppercased()
        }
    }

    private func keyWidth(for key: String) -> CGFloat {
        switch key.lowercased() {
        case "space":
            120
        case "shift", "return", "enter", "delete", "backspace":
            80
        case "cmd", "command", "ctrl", "control", "option", "alt":
            60
        default:
            40
        }
    }

    private func keyFontSize(for key: String) -> CGFloat {
        switch key.lowercased() {
        case "cmd", "command", "shift", "option", "alt", "ctrl", "control":
            20
        default:
            16
        }
    }
}

/// Particle effect for hotkey animation
struct ParticleView: View {
    let index: Int
    let primaryColor: Color
    let opacity: Double

    @State private var particleOffset: CGSize = .zero
    @State private var particleScale: CGFloat = 1

    private var angle: Double {
        Double(self.index) * (360.0 / 12.0)
    }

    var body: some View {
        Circle()
            .fill(self.primaryColor)
            .frame(width: 4, height: 4)
            .scaleEffect(self.particleScale)
            .offset(self.particleOffset)
            .opacity(self.opacity)
            .onAppear {
                self.animateParticle()
            }
    }

    private func animateParticle() {
        let radians = self.angle * .pi / 180
        let distance: CGFloat = 100

        withAnimation(.easeOut(duration: 0.8)) {
            self.particleOffset = CGSize(
                width: cos(radians) * distance,
                height: sin(radians) * distance)
            self.particleScale = 0.2
        }
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}

#Preview {
    VStack(spacing: 50) {
        HotkeyOverlayView(keys: ["Cmd", "C"])
            .frame(width: 400, height: 200)
            .background(Color.black.opacity(0.1))

        HotkeyOverlayView(keys: ["Cmd", "Shift", "T"])
            .frame(width: 400, height: 200)
            .background(Color.black.opacity(0.1))

        HotkeyOverlayView(keys: ["Ctrl", "Alt", "Delete"])
            .frame(width: 400, height: 200)
            .background(Color.black.opacity(0.1))
    }
}
