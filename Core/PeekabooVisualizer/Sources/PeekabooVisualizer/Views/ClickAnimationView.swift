//
//  ClickAnimationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import PeekabooFoundation
import SwiftUI

/// A view that displays ripple animations for different click types
struct ClickAnimationView: View {
    // MARK: - Properties

    /// Type of click
    let clickType: ClickType

    /// Animation speed multiplier
    let animationSpeed: Double

    /// Animation state
    @State private var rippleScale: CGFloat = 0.1
    @State private var rippleOpacity: Double = 1.0
    @State private var secondRippleScale: CGFloat = 0.1
    @State private var secondRippleOpacity: Double = 1.0
    @State private var labelOpacity: Double = 0
    @State private var labelScale: CGFloat = 0.8

    /// Colors for different click types
    private var rippleColor: Color {
        switch self.clickType {
        case .single:
            Color.blue
        case .double:
            Color.purple
        case .right:
            Color.orange
        }
    }

    /// Label text for the click type
    private var clickLabel: String {
        switch self.clickType {
        case .single:
            "Click"
        case .double:
            "Double Click"
        case .right:
            "Right Click"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Primary ripple
            Circle()
                .stroke(self.rippleColor, lineWidth: 3)
                .scaleEffect(self.rippleScale)
                .opacity(self.rippleOpacity)

            // Secondary ripple for double-click
            if self.clickType == .double {
                Circle()
                    .stroke(self.rippleColor, lineWidth: 2)
                    .scaleEffect(self.secondRippleScale)
                    .opacity(self.secondRippleOpacity)
            }

            // Click type label
            Text(self.clickLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(self.rippleColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.9)))
                .scaleEffect(self.labelScale)
                .opacity(self.labelOpacity)
                .offset(y: 30)
        }
        .frame(width: 320, height: 320)
        .onAppear {
            self.startAnimation()
        }
    }

    // MARK: - Methods

    private func startAnimation() {
        let duration = 0.5 * self.animationSpeed

        // Primary ripple animation
        withAnimation(.easeOut(duration: duration)) {
            self.rippleScale = 1.8
            self.rippleOpacity = 0
        }

        // Secondary ripple for double-click (delayed)
        if self.clickType == .double {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * self.animationSpeed) {
                withAnimation(.easeOut(duration: duration)) {
                    self.secondRippleScale = 1.8
                    self.secondRippleOpacity = 0
                }
            }
        }

        // Label animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.labelScale = 1.0
            self.labelOpacity = 1.0
        }

        // Fade out label
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * self.animationSpeed) {
            withAnimation(.easeOut(duration: 0.2)) {
                self.labelOpacity = 0
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Single Click") {
    ClickAnimationView(clickType: .single, animationSpeed: 1.0)
        .frame(width: 300, height: 300)
        .background(Color.gray.opacity(0.1))
}

#Preview("Double Click") {
    ClickAnimationView(clickType: .double, animationSpeed: 1.0)
        .frame(width: 300, height: 300)
        .background(Color.gray.opacity(0.1))
}

#Preview("Right Click") {
    ClickAnimationView(clickType: .right, animationSpeed: 1.0)
        .frame(width: 300, height: 300)
        .background(Color.gray.opacity(0.1))
}
#endif
