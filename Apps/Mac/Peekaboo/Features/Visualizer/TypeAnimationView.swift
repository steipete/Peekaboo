//
//  TypeAnimationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// A view that displays a floating keyboard widget with typing animations
struct TypeAnimationView: View {
    
    // MARK: - Properties
    
    /// Keys being typed
    let keys: [String]
    
    /// Visual theme for the keyboard
    let theme: KeyboardTheme
    
    /// Current key index being animated
    @State private var currentKeyIndex = 0
    
    /// Pressed keys for visual feedback
    @State private var pressedKeys: Set<String> = []
    
    /// WPM counter
    @State private var wordsPerMinute: Int = 0
    
    /// Animation timer
    @State private var animationTimer: Timer?
    
    /// Opacity for fade out animation
    @State private var opacity: Double = 1.0
    
    /// Timer for fade out
    @State private var fadeOutTimer: Timer?
    
    // MARK: - Types
    
    enum KeyboardTheme {
        case classic
        case modern
        case ghostly
        
        var backgroundColor: Color {
            switch self {
            case .classic:
                return Color.gray.opacity(0.7)  // Semi-transparent
            case .modern:
                return Color.black.opacity(0.6)  // Semi-transparent
            case .ghostly:
                return Color.purple.opacity(0.2)  // Very transparent
            }
        }
        
        var keyColor: Color {
            switch self {
            case .classic:
                return Color.white
            case .modern:
                return Color.gray
            case .ghostly:
                return Color.purple.opacity(0.5)
            }
        }
        
        var pressedKeyColor: Color {
            switch self {
            case .classic:
                return Color.blue
            case .modern:
                return Color.blue.opacity(0.8)
            case .ghostly:
                return Color.purple
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
            // WPM Display
            HStack {
                Text("WPM: \(wordsPerMinute)")
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
                            isPressed: pressedKeys.contains(key),
                            theme: theme
                        )
                    }
                }
                
                // QWERTY row
                HStack(spacing: 4) {
                    ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: pressedKeys.contains(key.lowercased()),
                            theme: theme
                        )
                    }
                }
                
                // ASDF row
                HStack(spacing: 4) {
                    ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: pressedKeys.contains(key.lowercased()),
                            theme: theme
                        )
                    }
                }
                
                // ZXCV row
                HStack(spacing: 4) {
                    ForEach(["Z", "X", "C", "V", "B", "N", "M"], id: \.self) { key in
                        KeyView(
                            key: key,
                            isPressed: pressedKeys.contains(key.lowercased()),
                            theme: theme
                        )
                    }
                }
                
                // Space bar and special keys
                HStack(spacing: 4) {
                    SpecialKeyView(
                        symbol: "⇥",
                        label: "Tab",
                        isPressed: pressedKeys.contains("{tab}"),
                        theme: theme,
                        width: 60
                    )
                    
                    SpecialKeyView(
                        symbol: "Space",
                        label: "",
                        isPressed: pressedKeys.contains(" "),
                        theme: theme,
                        width: 200
                    )
                    
                    SpecialKeyView(
                        symbol: "⏎",
                        label: "Return",
                        isPressed: pressedKeys.contains("{return}"),
                        theme: theme,
                        width: 80
                    )
                    
                    SpecialKeyView(
                        symbol: "⌫",
                        label: "Delete",
                        isPressed: pressedKeys.contains("{delete}"),
                        theme: theme,
                        width: 60
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.backgroundColor)
            )
        }
        .opacity(opacity)
        .onAppear {
            startTypingAnimation()
            calculateWPM()
        }
        .onDisappear {
            animationTimer?.invalidate()
            fadeOutTimer?.invalidate()
        }
    }
    
    // MARK: - Methods
    
    private func startTypingAnimation() {
        guard !keys.isEmpty else { return }
        
        // Animate typing at a realistic speed
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if currentKeyIndex < keys.count {
                let key = keys[currentKeyIndex]
                
                // Press the key
                withAnimation(.easeIn(duration: 0.05)) {
                    pressedKeys.insert(key.lowercased())
                }
                
                // Release the key
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeOut(duration: 0.05)) {
                        pressedKeys.remove(key.lowercased())
                    }
                }
                
                currentKeyIndex += 1
            } else {
                // Animation complete, start fade out after 500ms
                animationTimer?.invalidate()
                animationTimer = nil
                
                fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        opacity = 0.0
                    }
                }
            }
        }
    }
    
    private func calculateWPM() {
        // Simulate WPM calculation
        let baseWPM = 60
        let variation = Int.random(in: -10...20)
        wordsPerMinute = baseWPM + variation
        
        // Update periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let newVariation = Int.random(in: -5...5)
            wordsPerMinute = max(40, min(120, wordsPerMinute + newVariation))
        }
    }
}

// MARK: - Key Views

struct KeyView: View {
    let key: String
    let isPressed: Bool
    let theme: TypeAnimationView.KeyboardTheme
    
    var body: some View {
        Text(key)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isPressed ? .white : .black)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPressed ? theme.pressedKeyColor : theme.keyColor)
                    .shadow(radius: isPressed ? 0 : 2, y: isPressed ? 0 : 2)
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
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
            Text(symbol)
                .font(.system(size: 14, weight: .medium))
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
            }
        }
        .foregroundColor(isPressed ? .white : .black)
        .frame(width: width, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isPressed ? theme.pressedKeyColor : theme.keyColor)
                .shadow(radius: isPressed ? 0 : 2, y: isPressed ? 0 : 2)
        )
        .scaleEffect(isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Modern Theme") {
    TypeAnimationView(
        keys: ["H", "e", "l", "l", "o", " ", "W", "o", "r", "l", "d"],
        theme: .modern
    )
    .frame(width: 600, height: 300)
    .background(Color.gray.opacity(0.1))
}

#Preview("Classic Theme") {
    TypeAnimationView(
        keys: ["T", "e", "s", "t", "{return}", "1", "2", "3"],
        theme: .classic
    )
    .frame(width: 600, height: 300)
    .background(Color.gray.opacity(0.1))
}

#Preview("Ghostly Theme") {
    TypeAnimationView(
        keys: ["G", "h", "o", "s", "t", "{tab}", "M", "o", "d", "e"],
        theme: .ghostly
    )
    .frame(width: 600, height: 300)
    .background(Color.gray.opacity(0.1))
}
#endif