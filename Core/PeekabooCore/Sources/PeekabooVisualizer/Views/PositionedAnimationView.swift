//
//  PositionedAnimationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// A container view that positions animation content within a full-screen window
struct PositionedAnimationView<Content: View>: View {
    let targetRect: CGRect
    let content: Content

    init(targetRect: CGRect, @ViewBuilder content: () -> Content) {
        self.targetRect = targetRect
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Transparent background that fills the entire window
            Color.clear

            // Position the content at the target location
            self.content
                .frame(width: self.targetRect.width, height: self.targetRect.height)
                .position(
                    x: self.targetRect.midX,
                    y: self.targetRect.midY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Extension to help with coordinate translation
extension View {
    /// Translates screen coordinates to window-local coordinates
    func translateCoordinates(from screenPoint: CGPoint, in windowFrame: CGRect) -> CGPoint {
        CGPoint(
            x: screenPoint.x - windowFrame.minX,
            y: screenPoint.y - windowFrame.minY)
    }

    /// Translates a screen rect to window-local coordinates
    func translateRect(from screenRect: CGRect, in windowFrame: CGRect) -> CGRect {
        CGRect(
            x: screenRect.minX - windowFrame.minX,
            y: screenRect.minY - windowFrame.minY,
            width: screenRect.width,
            height: screenRect.height)
    }
}
