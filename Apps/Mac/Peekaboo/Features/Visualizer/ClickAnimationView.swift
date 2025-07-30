//
//  ClickAnimationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI
import PeekabooCore

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
        switch clickType {
        case .single:
            return Color.blue
        case .double:
            return Color.purple
        case .right:
            return Color.orange
        }
    }
    
    /// Label text for the click type
    private var clickLabel: String {
        switch clickType {
        case .single:
            return "Click"
        case .double:
            return "Double Click"
        case .right:
            return "Right Click"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Primary ripple
            Circle()
                .stroke(rippleColor, lineWidth: 3)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
            
            // Secondary ripple for double-click
            if clickType == .double {
                Circle()
                    .stroke(rippleColor, lineWidth: 2)
                    .scaleEffect(secondRippleScale)
                    .opacity(secondRippleOpacity)
            }
            
            // Click type label
            Text(clickLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(rippleColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.9))
                )
                .scaleEffect(labelScale)
                .opacity(labelOpacity)
                .offset(y: 30)
        }
        .frame(width: 200, height: 200)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Methods
    
    private func startAnimation() {
        let duration = 0.5 * animationSpeed
        
        // Primary ripple animation
        withAnimation(.easeOut(duration: duration)) {
            rippleScale = 2.0
            rippleOpacity = 0
        }
        
        // Secondary ripple for double-click (delayed)
        if clickType == .double {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * animationSpeed) {
                withAnimation(.easeOut(duration: duration)) {
                    secondRippleScale = 2.0
                    secondRippleOpacity = 0
                }
            }
        }
        
        // Label animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            labelScale = 1.0
            labelOpacity = 1.0
        }
        
        // Fade out label
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * animationSpeed) {
            withAnimation(.easeOut(duration: 0.2)) {
                labelOpacity = 0
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