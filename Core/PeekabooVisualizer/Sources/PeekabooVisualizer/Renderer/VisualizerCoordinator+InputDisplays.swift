import CoreGraphics
import Foundation
import PeekabooFoundation
import SwiftUI

// MARK: - Input Display Methods

@available(macOS 14.0, *)
extension VisualizerCoordinator {
    func displayScreenshotFlash(in rect: CGRect, showGhost: Bool) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.screenshotFlashEnabled ?? true
        else {
            self.logger.info("📸 Visualizer: Screenshot flash disabled in settings")
            return false
        }

        let intensity = self.settings?.visualizerEffectIntensity ?? 1.0
        let message = [
            "📸 Visualizer: Creating screenshot flash view",
            "showGhost: \(showGhost)",
            "intensity: \(intensity)",
        ].joined(separator: ", ")
        self.logger.info("\(message, privacy: .public)")

        // Create flash view
        let flashView = ScreenshotFlashView(
            showGhost: showGhost,
            intensity: intensity)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: flashView,
            duration: self.scaledDuration(AnimationBaseline.screenshotFlash, applySlowdown: false),
            fadeOut: false)

        return true
    }

    func displayWatchHUD(in rect: CGRect, sequence: Int) async -> Bool {
        guard self.isEnabled() else { return false }
        guard self.settings?.watchCaptureHUDEnabled ?? true else { return false }
        let view = WatchCaptureHUDView(sequence: sequence)
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.watchHUD),
            content: view,
            duration: self.scaledDuration(2.4),
            fadeOut: true)
        return true
    }

    func displayClickAnimation(at point: CGPoint, type: ClickType) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.clickAnimationEnabled ?? true
        else {
            return false
        }

        // Create click animation view
        let clickView = ClickAnimationView(
            clickType: type,
            animationSpeed: self.durationScaledAnimationSpeed)

        // Calculate window rect centered on click point
        let size: CGFloat = 320
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.click),
            content: clickView,
            duration: self.scaledDuration(AnimationBaseline.clickRipple),
            fadeOut: true)

        return true
    }

    func displayTypingWidget(keys: [String], duration: TimeInterval, cadence: TypingCadence?) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.typeAnimationEnabled ?? true
        else {
            return false
        }

        // Create typing widget view
        let typingView = TypeAnimationView(
            keys: keys,
            theme: .modern,
            cadence: cadence,
            animationSpeed: self.inverseScaledAnimationSpeed)

        // Position at bottom center of the screen where mouse is located
        let screen = self.getTargetScreen()
        let screenFrame = screen.frame
        let widgetSize = CGSize(width: 600, height: 200)
        let rect = CGRect(
            x: screenFrame.midX - widgetSize.width / 2,
            y: screenFrame.minY + 50,
            width: widgetSize.width,
            height: widgetSize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.typing),
            content: typingView,
            duration: self.scaledDuration(for: duration, minimum: AnimationBaseline.typingOverlay),
            fadeOut: true)

        return true
    }

    func displayScrollIndicators(
        at point: CGPoint,
        direction: ScrollDirection,
        amount: Int) async -> Bool
    {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.scrollAnimationEnabled ?? true
        else {
            return false
        }

        // Create scroll indicator view
        let scrollView = ScrollAnimationView(
            direction: direction,
            amount: amount,
            animationSpeed: self.inverseScaledAnimationSpeed)

        // Position near scroll point
        let size: CGFloat = 100
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.scroll),
            content: scrollView,
            duration: self.scaledDuration(AnimationBaseline.scrollIndicator),
            fadeOut: true)

        return true
    }

    func displayMouseTrail(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.mouseTrailEnabled ?? true
        else {
            return false
        }

        // Calculate the window frame for all screens
        var windowFrame = CGRect.zero
        for screen in NSScreen.screens {
            if windowFrame == .zero {
                windowFrame = screen.frame
            } else {
                windowFrame = windowFrame.union(screen.frame)
            }
        }

        // Create mouse trail view with window frame for coordinate translation
        let mouseDuration = self.scaledDuration(for: duration, minimum: AnimationBaseline.mouseTrail)
        let mouseView = MouseTrailView(
            from: from,
            to: to,
            duration: mouseDuration,
            windowFrame: windowFrame)

        // Calculate bounding rect for the trail
        let minX = min(from.x, to.x) - 50
        let minY = min(from.y, to.y) - 50
        let maxX = max(from.x, to.x) + 50
        let maxY = max(from.y, to.y) + 50

        let rect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.mouseTrail),
            content: mouseView,
            duration: mouseDuration + 0.35,
            fadeOut: true)

        return true
    }

    func displaySwipeAnimation(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.swipePathEnabled ?? true
        else {
            return false
        }

        // Calculate the window frame for all screens
        var windowFrame = CGRect.zero
        for screen in NSScreen.screens {
            if windowFrame == .zero {
                windowFrame = screen.frame
            } else {
                windowFrame = windowFrame.union(screen.frame)
            }
        }

        // Create swipe path view with window frame for coordinate translation
        let swipeDuration = self.scaledDuration(for: duration, minimum: AnimationBaseline.swipePath)
        let swipeView = SwipePathView(
            from: from,
            to: to,
            duration: swipeDuration,
            isTouch: true,
            windowFrame: windowFrame)

        // Calculate bounding rect for the swipe
        let minX = min(from.x, to.x) - 100
        let minY = min(from.y, to.y) - 100
        let maxX = max(from.x, to.x) + 100
        let maxY = max(from.y, to.y) + 100

        let rect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.swipe),
            content: swipeView,
            duration: swipeDuration + 0.35,
            fadeOut: true)

        return true
    }

    func displayHotkeyOverlay(keys: [String], duration: TimeInterval) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.hotkeyOverlayEnabled ?? true
        else {
            return false
        }

        let overlayDuration = self.scaledDuration(for: duration, minimum: AnimationBaseline.hotkeyOverlay)
        // Create hotkey overlay view
        let hotkeyView = HotkeyOverlayView(
            keys: keys,
            duration: overlayDuration)

        // Position at center of screen where mouse is located
        let screen = self.getTargetScreen()
        let screenFrame = screen.frame
        let overlaySize = Self.estimatedHotkeyOverlaySize(for: keys)
        let rect = CGRect(
            x: screenFrame.midX - overlaySize.width / 2,
            y: screenFrame.midY - overlaySize.height / 2,
            width: overlaySize.width,
            height: overlaySize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: 0),
            content: hotkeyView,
            duration: overlayDuration,
            fadeOut: true)

        return true
    }
}
