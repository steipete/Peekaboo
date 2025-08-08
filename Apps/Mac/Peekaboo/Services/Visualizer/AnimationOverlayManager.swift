//
//  AnimationOverlayManager.swift
//  Peekaboo
//
//  Manages animation overlay windows for visualizer effects
//

import AppKit
import os
import SwiftUI

/// Manages overlay windows for animation effects
@MainActor
final class AnimationOverlayManager {
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "AnimationOverlayManager")
    private var overlayWindows: [NSWindow] = []

    /// Shows an animation view in an overlay window
    func showAnimation(
        at rect: CGRect,
        content: some View,
        duration: TimeInterval,
        fadeOut: Bool) -> NSWindow
    {
        self.logger
            .debug("Showing animation overlay at \(rect.debugDescription), duration: \(duration), fadeOut: \(fadeOut)")

        // Create overlay window
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)

        // Configure window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        // Set content view
        let hostingView = NSHostingView(rootView: content)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView

        // Store window reference
        self.overlayWindows.append(window)

        // Show window
        window.orderFront(nil)

        // Schedule removal
        Task { @MainActor in
            if fadeOut {
                // Fade out animation
                await withCheckedContinuation { continuation in
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.3
                        window.animator().alphaValue = 0
                    }) {
                        Task { @MainActor in
                            self.removeWindow(window)
                            continuation.resume()
                        }
                    }
                }
            } else {
                // Remove after duration
                try? await Task.sleep(for: .seconds(duration))
                self.removeWindow(window)
            }
        }

        return window
    }

    /// Removes a specific overlay window
    private func removeWindow(_ window: NSWindow) {
        window.orderOut(nil)
        if let index = overlayWindows.firstIndex(of: window) {
            self.overlayWindows.remove(at: index)
        }
    }

    /// Removes all overlay windows
    func removeAllWindows() {
        for window in self.overlayWindows {
            window.orderOut(nil)
        }
        self.overlayWindows.removeAll()
    }
}
