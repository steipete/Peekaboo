//
//  TypeAnimationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import PeekabooFoundation
import SwiftUI

/// A view that displays a floating keyboard widget with typing animations
struct TypeAnimationView: View {
    // MARK: - Properties

    /// Keys being typed
    let keys: [String]

    /// Visual theme for the keyboard
    let theme: KeyboardTheme

    /// Typing cadence metadata
    let cadence: TypingCadence?

    /// Animation speed multiplier (1.0 = normal, 0.5 = 2x slower, 2.0 = 2x faster)
    var animationSpeed: Double

    /// Current key index being animated
    @State private var currentKeyIndex = 0

    /// Pressed keys for visual feedback
    @State private var pressedKeys: Set<String> = []

    /// WPM counter
    @State private var wordsPerMinute: Int

    /// Animation timer
    @State private var animationTimer: Timer?

    /// Opacity for fade out animation
    @State private var opacity: Double = 1.0

    /// Timer for fade out
    @State private var fadeOutTimer: Timer?

    // MARK: - Init

    init(keys: [String], theme: KeyboardTheme, cadence: TypingCadence?, animationSpeed: Double = 1.0) {
        self.keys = keys
        self.theme = theme
        self.cadence = cadence
        let resolvedSpeed = TypeAnimationView.resolveAnimationSpeed(for: cadence, fallback: animationSpeed)
        self.animationSpeed = resolvedSpeed
        _wordsPerMinute = State(initialValue: TypeAnimationView.resolveWordsPerMinute(for: cadence))
    }

    // MARK: - Types

    enum KeyboardTheme {
        case classic
        case modern
        case ghostly

        var backgroundColor: Color {
            switch self {
            case .classic:
                Color.gray.opacity(0.7) // Semi-transparent
            case .modern:
                Color.black.opacity(0.6) // Semi-transparent
            case .ghostly:
                Color.purple.opacity(0.2) // Very transparent
            }
        }

        var keyColor: Color {
            switch self {
            case .classic:
                Color.white
            case .modern:
                Color.gray
            case .ghostly:
                Color.purple.opacity(0.5)
            }
        }

        var pressedKeyColor: Color {
            switch self {
            case .classic:
                Color.blue
            case .modern:
                Color.blue.opacity(0.8)
            case .ghostly:
                Color.purple
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // WPM Display
            HStack {
                Text("WPM: \(self.wordsPerMinute)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 12)

            // Keyboard
            VStack(spacing: 4) {
                // Top row (numbers)
                HStack(spacing: 4) {
                    ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: self.pressedKeys.contains(key),
                            theme: self.theme)
                    }
                }

                // QWERTY row
                HStack(spacing: 4) {
                    ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: self.pressedKeys.contains(key.lowercased()),
                            theme: self.theme)
                    }
                }

                // ASDF row
                HStack(spacing: 4) {
                    ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: self.pressedKeys.contains(key.lowercased()),
                            theme: self.theme)
                    }
                }

                // ZXCV row
                HStack(spacing: 4) {
                    ForEach(["Z", "X", "C", "V", "B", "N", "M"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: self.pressedKeys.contains(key.lowercased()),
                            theme: self.theme)
                    }
                }

                // Space bar and special keys
                HStack(spacing: 4) {
                    SpecialKeyView(
                        symbol: "⇥",
                        label: "Tab",
                        isPressed: self.pressedKeys.contains("{tab}"),
                        theme: self.theme,
                        width: 60)

                    SpecialKeyView(
                        symbol: "Space",
                        label: "",
                        isPressed: self.pressedKeys.contains(" "),
                        theme: self.theme,
                        width: 200)

                    SpecialKeyView(
                        symbol: "⏎",
                        label: "Return",
                        isPressed: self.pressedKeys.contains("{return}"),
                        theme: self.theme,
                        width: 80)

                    SpecialKeyView(
                        symbol: "⌫",
                        label: "Delete",
                        isPressed: self.pressedKeys.contains("{delete}"),
                        theme: self.theme,
                        width: 60)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.theme.backgroundColor))
        }
        .opacity(self.opacity)
        .onAppear {
            self.startTypingAnimation()
        }
        .onDisappear {
            self.animationTimer?.invalidate()
            self.fadeOutTimer?.invalidate()
        }
    }

    // MARK: - Methods

    private func startTypingAnimation() {
        guard !self.keys.isEmpty else { return }

        // Animate typing at a realistic speed
        let typingInterval = 0.1 / self.animationSpeed
        self.animationTimer = Timer.scheduledTimer(withTimeInterval: typingInterval, repeats: true) { _ in
            Task { @MainActor in
                if self.currentKeyIndex < self.keys.count {
                    let key = self.keys[self.currentKeyIndex]

                    // Press the key
                    let pressDuration = 0.05 / self.animationSpeed
                    _ = withAnimation(.easeIn(duration: pressDuration)) {
                        self.pressedKeys.insert(key.lowercased())
                    }

                    // Release the key
                    Task {
                        let releaseDelay = UInt64(80_000_000 / self.animationSpeed)
                        try? await Task.sleep(nanoseconds: releaseDelay)
                        await MainActor.run {
                            withAnimation(.easeOut(duration: pressDuration)) {
                                _ = self.pressedKeys.remove(key.lowercased())
                            }
                        }
                    }

                    self.currentKeyIndex += 1
                } else {
                    // Animation complete, start fade out after 500ms
                    self.animationTimer?.invalidate()
                    self.animationTimer = nil

                    Task {
                        let fadeDelay = UInt64(500_000_000 / self.animationSpeed)
                        try? await Task.sleep(nanoseconds: fadeDelay)
                        await MainActor.run {
                            let fadeDuration = 0.5 / self.animationSpeed
                            withAnimation(.easeOut(duration: fadeDuration)) {
                                self.opacity = 0.0
                            }
                        }
                    }
                }
            }
        }
    }

    private static func resolveAnimationSpeed(for cadence: TypingCadence?, fallback: Double) -> Double {
        guard let cadence else { return fallback }
        let baselineWPM = 140.0
        switch cadence {
        case let .human(wordsPerMinute):
            return max(0.3, min(3.0, Double(wordsPerMinute) / baselineWPM))
        case .fixed:
            let wpm = self.resolveWordsPerMinute(for: cadence)
            guard wpm > 0 else { return fallback }
            return max(0.3, min(3.0, Double(wpm) / baselineWPM))
        }
    }

    private static func resolveWordsPerMinute(for cadence: TypingCadence?) -> Int {
        guard let cadence else { return 0 }
        switch cadence {
        case let .human(wordsPerMinute):
            return wordsPerMinute
        case let .fixed(milliseconds):
            let delay = max(milliseconds, 1)
            let charsPerMinute = 60000 / delay
            return max(0, charsPerMinute / 5)
        }
    }
}

// MARK: - Key Views

struct KeyView: View {
    let key: String
    let isPressed: Bool
    let theme: TypeAnimationView.KeyboardTheme

    var body: some View {
        Text(self.key)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(self.isPressed ? .white : .black)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(self.isPressed ? self.theme.pressedKeyColor : self.theme.keyColor)
                    .shadow(radius: self.isPressed ? 0 : 2, y: self.isPressed ? 0 : 2))
            .scaleEffect(self.isPressed ? 0.9 : 1.0)
    }
}

struct SpecialKeyView: View {
    let symbol: String
    let label: String
    let isPressed: Bool
    let theme: TypeAnimationView.KeyboardTheme
    let width: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            Text(self.symbol)
                .font(.system(size: 14, weight: .medium))
            if !self.label.isEmpty {
                Text(self.label)
                    .font(.caption2)
            }
        }
        .foregroundColor(self.isPressed ? .white : .black)
        .frame(width: self.width, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(self.isPressed ? self.theme.pressedKeyColor : self.theme.keyColor)
                .shadow(radius: self.isPressed ? 0 : 2, y: self.isPressed ? 0 : 2))
        .scaleEffect(self.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Modern Theme") {
    TypeAnimationView(
        keys: ["H", "e", "l", "l", "o", " ", "W", "o", "r", "l", "d"],
        theme: .modern,
        cadence: .human(wordsPerMinute: 140))
        .frame(width: 600, height: 300)
        .background(Color.gray.opacity(0.1))
}

#Preview("Classic Theme") {
    TypeAnimationView(
        keys: ["T", "e", "s", "t", "{return}", "1", "2", "3"],
        theme: .classic,
        cadence: .fixed(milliseconds: 20))
        .frame(width: 600, height: 300)
        .background(Color.gray.opacity(0.1))
}

#Preview("Ghostly Theme") {
    TypeAnimationView(
        keys: ["G", "h", "o", "s", "t", "{tab}", "M", "o", "d", "e"],
        theme: .ghostly,
        cadence: nil)
        .frame(width: 600, height: 300)
        .background(Color.gray.opacity(0.1))
}
#endif
