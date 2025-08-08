//
//  DialogInteractionView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import PeekabooCore
import SwiftUI

/// Local dialog element type for visualization
enum DialogElementType: String, CaseIterable {
    case button
    case textField
    case checkbox
    case radioButton
    case dropdown
}

/// Dialog action type for visualization
enum DialogActionType: String, CaseIterable {
    case clickButton
    case enterText
    case toggle
    case select
    case handleFileDialog
    case dismiss
}

/// Animated dialog interaction visualization (button clicks, text input, etc.)
struct DialogInteractionView: View {
    let element: DialogElementType
    let elementRect: CGRect
    let action: DialogActionType
    let duration: TimeInterval

    @State private var highlightScale: CGFloat = 0.8
    @State private var highlightOpacity: Double = 0
    @State private var iconScale: CGFloat = 0
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0

    init(element: DialogElementType, elementRect: CGRect, action: DialogActionType, duration: TimeInterval = 1.0) {
        self.element = element
        self.elementRect = elementRect
        self.action = action
        self.duration = duration
    }

    var body: some View {
        ZStack {
            // Element highlight
            RoundedRectangle(cornerRadius: self.element.cornerRadius)
                .stroke(self.element.color, lineWidth: 3)
                .frame(width: self.elementRect.width, height: self.elementRect.height)
                .scaleEffect(self.highlightScale)
                .opacity(self.highlightOpacity)

            // Ripple effect for clicks
            if self.action == .clickButton {
                Circle()
                    .stroke(self.element.color.opacity(0.6), lineWidth: 2)
                    .scaleEffect(self.rippleScale)
                    .opacity(self.rippleOpacity)
            }

            // Action icon
            self.action.icon
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(self.element.color)
                .scaleEffect(self.iconScale)
                .shadow(color: self.element.color.opacity(0.5), radius: 10)

            // Text input cursor for type action
            if self.action == .enterText {
                CursorView(color: self.element.color)
                    .offset(x: -self.elementRect.width / 2 + 10, y: 0)
                    .opacity(self.highlightOpacity)
            }
        }
        .onAppear {
            self.animateInteraction()
        }
    }

    private func animateInteraction() {
        // Highlight appearance
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.highlightScale = 1.0
            self.highlightOpacity = 1.0
        }

        // Icon animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            self.iconScale = 1.0
        }

        // Action-specific animations
        switch self.action {
        case .clickButton:
            self.animateClick()
        case .enterText:
            self.animateTypeText()
        case .toggle:
            self.animateClick()
        case .select:
            self.animateClick()
        case .handleFileDialog:
            self.animateClick()
        case .dismiss:
            self.animateClick()
        }

        // Fade out
        let fadeDelay = self.duration - 0.3
        withAnimation(.easeOut(duration: 0.3).delay(fadeDelay)) {
            self.highlightOpacity = 0
            self.iconScale = 0.5
        }
    }

    private func animateClick() {
        // Ripple effect
        withAnimation(.easeOut(duration: 0.6)) {
            self.rippleScale = 2.0
            self.rippleOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.2).delay(0.4)) {
            self.rippleOpacity = 0
        }

        // Highlight pulse
        withAnimation(.easeInOut(duration: 0.2).delay(0.2)) {
            self.highlightScale = 0.95
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(0.4)) {
            self.highlightScale = 1.0
        }
    }

    private func animateTypeText() {
        // Typing effect - pulse the highlight
        for i in 0..<3 {
            let delay = Double(i) * 0.3 + 0.2
            withAnimation(.easeInOut(duration: 0.15).delay(delay)) {
                self.highlightScale = 0.98
            }
            withAnimation(.easeInOut(duration: 0.15).delay(delay + 0.15)) {
                self.highlightScale = 1.0
            }
        }
    }
}

/// Cursor view for text input
struct CursorView: View {
    let color: Color
    @State private var isBlinking = false

    var body: some View {
        Rectangle()
            .fill(self.color)
            .frame(width: 2, height: 20)
            .opacity(self.isBlinking ? 0 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    self.isBlinking = true
                }
            }
    }
}

// MARK: - DialogElementType Extension

extension DialogElementType {
    /// Initialize from role string
    init(role: String) {
        switch role.lowercased() {
        case "button":
            self = .button
        case "textfield", "text field":
            self = .textField
        case "checkbox":
            self = .checkbox
        case "radiobutton", "radio button":
            self = .radioButton
        case "dropdown", "combobox":
            self = .dropdown
        default:
            self = .button // Default to button
        }
    }

    var color: Color {
        switch self {
        case .button:
            .blue
        case .textField:
            .green
        case .checkbox:
            .purple
        case .radioButton:
            .orange
        case .dropdown:
            .cyan
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .button:
            8
        case .textField:
            6
        case .checkbox, .radioButton:
            4
        case .dropdown:
            6
        }
    }
}

// MARK: - DialogActionType Extension

extension DialogActionType {
    var icon: some View {
        Group {
            switch self {
            case .clickButton:
                Image(systemName: "hand.tap.fill")
            case .enterText:
                Image(systemName: "keyboard.fill")
            case .toggle:
                Image(systemName: "checkmark.square.fill")
            case .select:
                Image(systemName: "hand.point.up.left.fill")
            case .handleFileDialog:
                Image(systemName: "folder.fill")
            case .dismiss:
                Image(systemName: "xmark.circle.fill")
            }
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        DialogInteractionView(
            element: .button,
            elementRect: CGRect(x: 0, y: 0, width: 120, height: 40),
            action: .clickButton)
            .frame(width: 200, height: 100)
            .background(Color.black.opacity(0.1))

        DialogInteractionView(
            element: .textField,
            elementRect: CGRect(x: 0, y: 0, width: 200, height: 30),
            action: .enterText)
            .frame(width: 300, height: 100)
            .background(Color.black.opacity(0.1))

        DialogInteractionView(
            element: .checkbox,
            elementRect: CGRect(x: 0, y: 0, width: 20, height: 20),
            action: .clickButton)
            .frame(width: 100, height: 100)
            .background(Color.black.opacity(0.1))
    }
}
