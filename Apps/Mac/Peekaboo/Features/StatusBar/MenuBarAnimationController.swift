import AppKit
import Combine
import Foundation
import os.log
import PeekabooCore
import SwiftUI

/// Manages animation timing and rendering for the menu bar ghost icon.
///
/// This controller handles adaptive timing, icon caching, and state management
/// for smooth ghost animations while minimizing CPU usage.
@MainActor
final class MenuBarAnimationController: ObservableObject {
    // MARK: - Properties

    /// Current animation state
    @Published private(set) var isAnimating: Bool = false

    /// Animation timer
    private var animationTimer: Timer?

    /// Cache for rendered icons
    private var iconCache: [GhostIconCacheKey: NSImage] = [:]
    private let maxCacheSize = 30

    /// Last rendered frame info for optimization
    private var lastRenderedFrame: (vOffset: CGFloat, hOffset: CGFloat, scale: CGFloat, opacity: Double) = (0, 0, 1, 1)
    private var framesSinceLastChange: Int = 0

    /// Logger for debugging
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "MenuBarAnimation")

    /// Callback when icon needs updating
    var onIconUpdateNeeded: ((NSImage) -> Void)?

    /// Reference to the agent to track its processing state
    private weak var agent: PeekabooAgent?

    // MARK: - Initialization

    init() {
        self.logger.info("MenuBarAnimationController initialized")
    }

    // MARK: - Public Methods

    /// Sets the agent to observe
    func setAgent(_ agent: PeekabooAgent) {
        self.agent = agent
    }

    /// Starts or stops animation based on agent status
    func updateAnimationState() {
        let shouldAnimate = self.agent?.isProcessing ?? false

        if shouldAnimate != self.isAnimating {
            if shouldAnimate {
                self.startAnimation()
            } else {
                self.stopAnimation()
            }
        }
    }

    /// Forces a render of the current state
    func forceRender() {
        self.renderCurrentFrame()
    }

    /// Clears the icon cache
    func clearCache() {
        self.iconCache.removeAll()
        self.logger.debug("Icon cache cleared")
    }

    // MARK: - Private Methods

    private func startAnimation() {
        guard !self.isAnimating else { return }

        self.logger.info("Starting ghost animation")
        self.isAnimating = true

        // Start with fast updates for smooth animation
        self.startAdaptiveTimer(interval: 0.0167) // 60 fps initially

        // Render initial frame
        self.renderCurrentFrame()
    }

    private func stopAnimation() {
        guard self.isAnimating else { return }

        self.logger.info("Stopping ghost animation")
        self.isAnimating = false

        // Stop timer
        self.animationTimer?.invalidate()
        self.animationTimer = nil

        // Render final static frame
        self.renderCurrentFrame()
    }

    private func startAdaptiveTimer(interval: TimeInterval) {
        self.animationTimer?.invalidate()

        self.animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                self.renderCurrentFrame()

                // Adaptive timing based on animation needs
                let currentInterval = interval
                let targetInterval: TimeInterval = if self.isAnimating {
                    // Active animation
                    if self.framesSinceLastChange < 5 {
                        0.0167 // 60 fps for smooth animation
                    } else {
                        0.033 // 30 fps when movement is subtle
                    }
                } else {
                    0.5 // Very slow when static
                }

                // Only restart timer if interval needs significant change
                if abs(currentInterval - targetInterval) > 0.005 {
                    self.startAdaptiveTimer(interval: targetInterval)
                }
            }
        }
    }

    private func renderCurrentFrame() {
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Create cache key based on current animation state
        // For animated state, we'll need to calculate current position based on time
        let animationTime = Date().timeIntervalSinceReferenceDate
        let animationPhase = self.isAnimating ? animationTime.truncatingRemainder(dividingBy: 3.0) / 3.0 : 0

        // Calculate current position, scale, and opacity with smoother interpolation
        // Use different phase offsets for more organic movement
        let verticalOffset = self.isAnimating ? sin(animationPhase * .pi * 2) * 2.0 : 0
        let horizontalOffset = self.isAnimating ? cos(animationPhase * .pi * 2 * 1.2) * 1.0 : 0
        let scale = self.isAnimating ? 1.0 + sin(animationPhase * .pi * 2 * 0.8) * 0.1 : 1.0
        let opacity = self.isAnimating ? 0.8 + sin(animationPhase * .pi * 2 * 0.9) * 0.2 : 1.0

        // Quantize values for caching
        let quantizedVOffset = Int(round(verticalOffset))
        let quantizedHOffset = Int(round(horizontalOffset))
        let quantizedScale = Int(round(scale * 10))
        let quantizedOpacity = Int(round(opacity * 10))

        let cacheKey = GhostIconCacheKey(
            isAnimating: isAnimating,
            verticalOffset: quantizedVOffset,
            horizontalOffset: quantizedHOffset,
            scale: quantizedScale,
            opacity: quantizedOpacity,
            isDarkMode: isDarkMode)

        // Check if frame changed significantly (more sensitive for smoother animation)
        let frameChanged = abs(verticalOffset - self.lastRenderedFrame.vOffset) > 0.25 ||
            abs(horizontalOffset - self.lastRenderedFrame.hOffset) > 0.25 ||
            abs(scale - self.lastRenderedFrame.scale) > 0.02 ||
            abs(opacity - self.lastRenderedFrame.opacity) > 0.03

        if frameChanged {
            self.framesSinceLastChange = 0
            self.lastRenderedFrame = (verticalOffset, horizontalOffset, scale, opacity)
        } else {
            self.framesSinceLastChange += 1
        }

        // Check cache first
        if let cachedIcon = iconCache[cacheKey] {
            self.onIconUpdateNeeded?(cachedIcon)
            return
        }

        // Create the ghost icon with animation properties
        let nsImage = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let context = NSGraphicsContext.current!.cgContext

            // Apply transformations for floating animation
            context.saveGState()
            
            // Move to center for scaling
            context.translateBy(x: rect.midX, y: rect.midY)
            
            // Apply scale
            context.scaleBy(x: scale, y: scale)
            
            // Apply position offsets
            context.translateBy(x: CGFloat(horizontalOffset), y: CGFloat(verticalOffset))
            
            // Move back from center
            context.translateBy(x: -rect.midX, y: -rect.midY)

            // Apply opacity
            context.setAlpha(opacity)

            // Draw the MenuIcon asset
            if let menuIcon = NSImage(named: "MenuIcon") {
                // Scale the icon to fit the rect while maintaining aspect ratio
                let iconSize = menuIcon.size
                let scale = min(rect.width / iconSize.width, rect.height / iconSize.height)
                let scaledSize = NSSize(width: iconSize.width * scale, height: iconSize.height * scale)
                
                // Center the icon in the rect
                let drawRect = NSRect(
                    x: rect.midX - scaledSize.width / 2,
                    y: rect.midY - scaledSize.height / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )
                
                menuIcon.draw(in: drawRect)
            }

            context.restoreGState()

            return true
        }

        nsImage.isTemplate = true // Allow system tinting

        // Cache the rendered image
        self.iconCache[cacheKey] = nsImage

        // Trim cache if needed
        if self.iconCache.count > self.maxCacheSize {
            // Remove oldest entries (simple strategy)
            let entriesToRemove = self.iconCache.count - self.maxCacheSize
            self.iconCache.keys.prefix(entriesToRemove).forEach { self.iconCache.removeValue(forKey: $0) }
        }

        // Update the menu bar icon
        self.onIconUpdateNeeded?(nsImage)
    }

    deinit {
        animationTimer?.invalidate()
        logger.info("MenuBarAnimationController deallocated")
    }
}
