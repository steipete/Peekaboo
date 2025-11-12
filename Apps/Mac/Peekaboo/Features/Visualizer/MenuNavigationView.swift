//
//  MenuNavigationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// Animated menu navigation visualization showing menu path
struct MenuNavigationView: View {
    let menuPath: [String]
    let duration: TimeInterval

    @State private var pathProgress: [CGFloat] = []
    @State private var glowOpacity: Double = 0
    @State private var arrowOpacities: [Double] = []

    private let primaryColor = Color.blue
    private let secondaryColor = Color.cyan

    init(menuPath: [String], duration: TimeInterval = 1.5) {
        self.menuPath = menuPath
        self.duration = duration
        self._pathProgress = State(initialValue: Array(repeating: 0, count: menuPath.count))
        self._arrowOpacities = State(initialValue: Array(repeating: 0, count: max(0, menuPath.count - 1)))
    }

    var body: some View {
        ZStack {
            // Background glow
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [self.primaryColor.opacity(0.2), self.secondaryColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .blur(radius: 20)
                .opacity(self.glowOpacity)

            // Menu path
            HStack(spacing: 12) {
                ForEach(Array(self.menuPath.enumerated()), id: \.offset) { index, menuItem in
                    HStack(spacing: 12) {
                        // Menu item
                        MenuItemView(
                            title: menuItem,
                            isActive: self.pathProgress[safe: index] ?? 0 > 0.5,
                            scale: self.pathProgress[safe: index] ?? 0,
                            primaryColor: self.primaryColor,
                            secondaryColor: self.secondaryColor)

                        // Arrow between items
                        if index < self.menuPath.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(self.secondaryColor)
                                .opacity(self.arrowOpacities[safe: index] ?? 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [self.primaryColor, self.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 2)))
        }
        .onAppear {
            self.animateMenuPath()
        }
    }

    private func animateMenuPath() {
        // Background glow
        withAnimation(.easeIn(duration: 0.3)) {
            self.glowOpacity = 1
        }

        // Sequential menu item animations
        for index in self.menuPath.indices {
            let delay = Double(index) * 0.2

            // Menu item scale
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay)) {
                if index < self.pathProgress.count {
                    self.pathProgress[index] = 1.0
                }
            }

            // Arrow fade in
            if index < self.arrowOpacities.count {
                withAnimation(.easeIn(duration: 0.2).delay(delay + 0.1)) {
                    self.arrowOpacities[index] = 1.0
                }
            }
        }

        // Fade out
        let fadeDelay = self.duration - 0.5
        withAnimation(.easeOut(duration: 0.5).delay(fadeDelay)) {
            self.glowOpacity = 0
            for index in self.pathProgress.indices {
                self.pathProgress[index] = 0
            }
            for index in self.arrowOpacities.indices {
                self.arrowOpacities[index] = 0
            }
        }
    }
}

/// Individual menu item visualization
struct MenuItemView: View {
    let title: String
    let isActive: Bool
    let scale: CGFloat
    let primaryColor: Color
    let secondaryColor: Color

    var body: some View {
        Text(self.title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(self.isActive ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: self
                                .isActive ? [self.primaryColor.opacity(0.3), self.secondaryColor.opacity(0.2)] :
                                [Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        self.isActive ? self.primaryColor.opacity(0.5) : Color.gray.opacity(0.2),
                        lineWidth: 1))
            .scaleEffect(self.scale)
    }
}

// Removed - already defined in HotkeyOverlayView.swift

#Preview {
    VStack(spacing: 50) {
        MenuNavigationView(
            menuPath: ["File", "New", "Project"])
            .frame(width: 500, height: 100)
            .background(Color.black.opacity(0.1))

        MenuNavigationView(
            menuPath: ["Edit", "Find", "Find and Replace..."])
            .frame(width: 600, height: 100)
            .background(Color.black.opacity(0.1))

        MenuNavigationView(
            menuPath: ["View", "Show Sidebar"])
            .frame(width: 400, height: 100)
            .background(Color.black.opacity(0.1))
    }
}
