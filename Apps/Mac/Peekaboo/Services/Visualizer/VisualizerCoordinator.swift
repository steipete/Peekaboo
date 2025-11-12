//
//  VisualizerCoordinator.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import AXorcist
import Combine
import CoreGraphics
import Foundation
import IOKit.ps
import Observation
import os
import PeekabooCore
import PeekabooFoundation
import PeekabooUICore
import SwiftUI

/// Coordinates all visual feedback animations for the Peekaboo app
/// This follows modern SwiftUI patterns and focuses on simplicity
@MainActor
@Observable
final class VisualizerCoordinator {
    // MARK: - Properties

    /// Logger for debugging
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "VisualizerCoordinator")

    /// Overlay manager for displaying animations
    private let overlayManager = AnimationOverlayManager()

    /// Optimized animation queue with batching and priorities
    private let animationQueue = OptimizedAnimationQueue()

    /// Settings reference
    private weak var settings: PeekabooSettings?

private enum AnimationBaseline {
        static let screenshotFlash: TimeInterval = 0.35
        static let clickRipple: TimeInterval = 0.45
        static let typingOverlay: TimeInterval = 1.2
        static let scrollIndicator: TimeInterval = 0.6
        static let mouseTrail: TimeInterval = 0.75
        static let swipePath: TimeInterval = 0.9
        static let hotkeyOverlay: TimeInterval = 1.2
        static let windowOperation: TimeInterval = 0.85
        static let appLaunch: TimeInterval = 1.8
        static let appQuit: TimeInterval = 1.5
        static let menuNavigation: TimeInterval = 1.0
        static let dialogInteraction: TimeInterval = 1.0
        static let annotatedScreenshot: TimeInterval = 1.2
        static let elementHighlight: TimeInterval = 1.0
        static let spaceTransition: TimeInterval = 1.0
    }

    private var animationSpeedScale: Double {
        max(0.1, min(2.0, self.settings?.visualizerAnimationSpeed ?? PeekabooSettings.defaultVisualizerAnimationSpeed))
    }

    /// Screenshot counter for easter egg (persisted)
    private var screenshotCount: Int {
        get { UserDefaults.standard.integer(forKey: "PeekabooScreenshotCount") }
        set { UserDefaults.standard.set(newValue, forKey: "PeekabooScreenshotCount") }
    }

    // MARK: - Initialization

    init() {
        // Overlay manager is created internally
    }

    // MARK: - Helpers

    private func scaledDuration(_ baseline: TimeInterval) -> TimeInterval {
        baseline * self.animationSpeedScale
    }

    private func scaledDuration(for requested: TimeInterval, minimum baseline: TimeInterval) -> TimeInterval {
        max(requested, baseline) * self.animationSpeedScale
    }

    // MARK: - Settings

    /// Connect to PeekabooSettings
    func connectSettings(_ settings: PeekabooSettings) {
        self.settings = settings
        self.logger.info("Visualizer connected to settings")
    }

    /// Check if visualizer is enabled
    func isEnabled() -> Bool {
        self.settings?.visualizerEnabled ?? true
    }

    /// Check if running on battery power
    private func isOnBatteryPower() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            if let sourceInfo = IOPSGetPowerSourceDescription(snapshot, source)
                .takeUnretainedValue() as? [String: Any],
                let powerSourceState = sourceInfo[kIOPSPowerSourceStateKey] as? String
            {
                return powerSourceState == kIOPSBatteryPowerValue
            }
        }

        return false
    }

    /// Get the appropriate screen for displaying visualizations based on context
    /// For point-based operations, use the screen containing that point
    /// For general operations, use the screen containing the mouse cursor
    private func getTargetScreen(for point: CGPoint? = nil) -> NSScreen {
        if let point {
            NSScreen.screen(containing: point)
        } else {
            NSScreen.mouseScreen
        }
    }
}

// MARK: - Animation API

@available(macOS 14.0, *)
@MainActor
extension VisualizerCoordinator {
    func showScreenshotFlash(in rect: CGRect) async -> Bool {
        self.logger.info("📸 Visualizer: Showing screenshot flash for rect: \(String(describing: rect))")

        screenshotCount += 1
        let showGhost = screenshotCount % 100 == 0
        self.logger.debug("Screenshot count: \(screenshotCount), show ghost: \(showGhost)")

        return await animationQueue.enqueue(priority: .high) {
            await displayScreenshotFlash(in: rect, showGhost: showGhost)
        }
    }

    func showClickFeedback(at point: CGPoint, type: PeekabooFoundation.ClickType) async -> Bool {
        self.logger.info("🖱️ Visualizer: Showing click feedback at \(String(describing: point)), type: \(type)")

        return await animationQueue.enqueue(priority: .high) {
            await displayClickAnimation(at: point, type: type)
        }
    }

    func showTypingFeedback(keys: [String], duration: TimeInterval) async -> Bool {
        self.logger.info("⌨️ Visualizer: Showing typing feedback for \(keys.count) keys: \(keys.joined())")

        return await animationQueue.enqueue(priority: .normal) {
            await displayTypingWidget(keys: keys, duration: duration)
        }
    }

    func showScrollFeedback(
        at point: CGPoint,
        direction: PeekabooFoundation.ScrollDirection,
        amount: Int
    ) async -> Bool {
        let message = [
            "📜 Visualizer: Showing scroll feedback at \(String(describing: point))",
            "direction: \(direction), amount: \(amount)"
        ].joined(separator: ", ")
        self.logger.info(message)

        return await animationQueue.enqueue(priority: .normal) {
            await displayScrollIndicators(at: point, direction: direction, amount: amount)
        }
    }

    func showMouseMovement(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        let message = [
            "🐭 Visualizer: Showing mouse movement from \(String(describing: from))",
            "to \(String(describing: to)), duration: \(duration)s"
        ].joined(separator: " ")
        self.logger.info(message)

        return await animationQueue.enqueue(priority: .low) {
            await displayMouseTrail(from: from, to: to, duration: duration)
        }
    }

    func showSwipeGesture(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        let message = [
            "👆 Visualizer: Showing swipe gesture from \(String(describing: from))",
            "to \(String(describing: to)), duration: \(duration)s"
        ].joined(separator: " ")
        self.logger.info(message)

        return await animationQueue.enqueue(priority: .normal) {
            await displaySwipeAnimation(from: from, to: to, duration: duration)
        }
    }

    func showHotkeyDisplay(keys: [String], duration: TimeInterval) async -> Bool {
        self.logger.debug("Showing hotkey display for keys: \(keys)")

        return await animationQueue.enqueue(priority: .high) {
            await displayHotkeyOverlay(keys: keys, duration: duration)
        }
    }

    func showAppLaunch(appName: String, iconPath: String?) async -> Bool {
        self.logger.debug("Showing app launch animation for: \(appName)")

        return await animationQueue.enqueue {
            await displayAppLaunchAnimation(appName: appName, iconPath: iconPath)
        }
    }

    func showAppQuit(appName: String, iconPath: String?) async -> Bool {
        self.logger.debug("Showing app quit animation for: \(appName)")

        return await animationQueue.enqueue {
            await displayAppQuitAnimation(appName: appName, iconPath: iconPath)
        }
    }

    func showWindowOperation(_ operation: WindowOperation, windowRect: CGRect, duration: TimeInterval) async -> Bool {
        self.logger.debug("Showing window operation: \(String(describing: operation))")

        return await animationQueue.enqueue {
            await displayWindowOperation(operation, windowRect: windowRect, duration: duration)
        }
    }

    func showMenuNavigation(menuPath: [String]) async -> Bool {
        self.logger.debug("Showing menu navigation for path: \(menuPath)")

        return await animationQueue.enqueue {
            await displayMenuHighlights(menuPath: menuPath)
        }
    }

    func showDialogInteraction(
        element: DialogElementType,
        elementRect: CGRect,
        action: DialogActionType
    ) async -> Bool {
        let message = [
            "Showing dialog interaction: \(String(describing: element))",
            "action: \(String(describing: action))"
        ].joined(separator: " ")
        self.logger.debug(message)

        return await animationQueue.enqueue {
            await displayDialogFeedback(element: element, elementRect: elementRect, action: action)
        }
    }

    func showSpaceSwitch(from: Int, to: Int, direction: SpaceDirection) async -> Bool {
        self.logger.debug("Showing space switch from \(from) to \(to)")

        return await animationQueue.enqueue {
            await displaySpaceTransition(from: from, to: to, direction: direction)
        }
    }

    func showElementDetection(elements: [String: CGRect], duration: TimeInterval) async -> Bool {
        self.logger.debug("Showing element detection for \(elements.count) elements")

        return await animationQueue.enqueue {
            await displayElementOverlays(elements: elements, duration: duration)
        }
    }

    func showAnnotatedScreenshot(
        imageData: Data,
        elements: [DetectedElement],
        windowBounds: CGRect,
        duration: TimeInterval
    ) async -> Bool {
        self.logger.info("🎯 Visualizer: Showing annotated screenshot with \(elements.count) elements")

        return await animationQueue.enqueue(priority: .high) {
            await displayAnnotatedScreenshot(
                imageData: imageData,
                elements: elements,
                windowBounds: windowBounds,
                duration: duration
            )
        }
    }
}

// MARK: - Private Display Methods

@available(macOS 14.0, *)
private extension VisualizerCoordinator {
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
            "intensity: \(intensity)"
        ].joined(separator: ", ")
        self.logger.info(message)

        // Create flash view
        let flashView = ScreenshotFlashView(
            showGhost: showGhost,
            intensity: intensity)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: flashView,
            duration: self.scaledDuration(AnimationBaseline.screenshotFlash),
            fadeOut: false)

        return true
    }

    private func displayClickAnimation(at point: CGPoint, type: PeekabooFoundation.ClickType) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.clickAnimationEnabled ?? true
        else {
            return false
        }

        // Create click animation view
        let clickView = ClickAnimationView(
            clickType: type,
            animationSpeed: self.animationSpeedScale)

        // Calculate window rect centered on click point
        let size: CGFloat = 200
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: clickView,
            duration: self.scaledDuration(AnimationBaseline.clickRipple),
            fadeOut: true)

        return true
    }

    private func displayTypingWidget(keys: [String], duration: TimeInterval) async -> Bool {
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
            animationSpeed: self.animationSpeedScale)

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
            at: rect,
            content: typingView,
            duration: self.scaledDuration(for: duration, minimum: AnimationBaseline.typingOverlay),
            fadeOut: true)

        return true
    }

    private func displayScrollIndicators(
        at point: CGPoint,
        direction: PeekabooFoundation.ScrollDirection,
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
            animationSpeed: self.animationSpeedScale)

        // Position near scroll point
        let size: CGFloat = 100
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: scrollView,
            duration: self.scaledDuration(AnimationBaseline.scrollIndicator),
            fadeOut: true)

        return true
    }

    private func displayMouseTrail(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
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
            at: rect,
            content: mouseView,
            duration: mouseDuration + 0.35,
            fadeOut: true)

        return true
    }

    private func displaySwipeAnimation(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
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
            at: rect,
            content: swipeView,
            duration: swipeDuration + 0.35,
            fadeOut: true)

        return true
    }

    private func displayHotkeyOverlay(keys: [String], duration: TimeInterval) async -> Bool {
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
        let overlaySize = CGSize(width: 400, height: 150)
        let rect = CGRect(
            x: screenFrame.midX - overlaySize.width / 2,
            y: screenFrame.midY - overlaySize.height / 2,
            width: overlaySize.width,
            height: overlaySize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: hotkeyView,
            duration: overlayDuration,
            fadeOut: true)

        return true
    }

    private func displayAppLaunchAnimation(appName: String, iconPath: String?) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.appLifecycleEnabled ?? true
        else {
            return false
        }

        // Create app launch view
        let launchDuration = self.scaledDuration(AnimationBaseline.appLaunch)
        let launchView = AppLifecycleView(
            appName: appName,
            iconPath: iconPath,
            action: .launch,
            duration: launchDuration)

        // Position at center of screen where mouse is located
        let screen = self.getTargetScreen()
        let screenFrame = screen.frame
        let overlaySize = CGSize(width: 300, height: 300)
        let rect = CGRect(
            x: screenFrame.midX - overlaySize.width / 2,
            y: screenFrame.midY - overlaySize.height / 2,
            width: overlaySize.width,
            height: overlaySize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: launchView,
            duration: launchDuration,
            fadeOut: true)

        return true
    }

    private func displayAppQuitAnimation(appName: String, iconPath: String?) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.appLifecycleEnabled ?? true
        else {
            return false
        }

        // Create app quit view
        let quitDuration = self.scaledDuration(AnimationBaseline.appQuit)
        let quitView = AppLifecycleView(
            appName: appName,
            iconPath: iconPath,
            action: .quit,
            duration: quitDuration)

        // Position at center of screen where mouse is located
        let screen = self.getTargetScreen()
        let screenFrame = screen.frame
        let overlaySize = CGSize(width: 300, height: 300)
        let rect = CGRect(
            x: screenFrame.midX - overlaySize.width / 2,
            y: screenFrame.midY - overlaySize.height / 2,
            width: overlaySize.width,
            height: overlaySize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: quitView,
            duration: quitDuration,
            fadeOut: true)

        return true
    }

    private func displayWindowOperation(
        _ operation: WindowOperation,
        windowRect: CGRect,
        duration: TimeInterval) async -> Bool
    {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.windowOperationEnabled ?? true
        else {
            return false
        }

        // Create window operation view
        let windowDuration = self.scaledDuration(for: duration, minimum: AnimationBaseline.windowOperation)
        let windowView = WindowOperationView(
            operation: operation,
            windowRect: windowRect,
            duration: windowDuration)

        // Display at window location
        _ = self.overlayManager.showAnimation(
            at: windowRect,
            content: windowView,
            duration: windowDuration,
            fadeOut: true)

        return true
    }

    private func displayMenuHighlights(menuPath: [String]) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.menuNavigationEnabled ?? true
        else {
            return false
        }

        // Create menu navigation view
        let menuDuration = self.scaledDuration(AnimationBaseline.menuNavigation)
        let menuView = MenuNavigationView(
            menuPath: menuPath,
            duration: menuDuration)

        // Position at top of screen where mouse is located
        let screen = self.getTargetScreen()
        let screenFrame = screen.frame
        let overlaySize = CGSize(width: 600, height: 100)
        let rect = CGRect(
            x: screenFrame.midX - overlaySize.width / 2,
            y: screenFrame.maxY - overlaySize.height - 50,
            width: overlaySize.width,
            height: overlaySize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: rect,
            content: menuView,
            duration: menuDuration,
            fadeOut: true)

        return true
    }

    private func displayDialogFeedback(
        element: DialogElementType,
        elementRect: CGRect,
        action: DialogActionType) async -> Bool
    {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.dialogInteractionEnabled ?? true
        else {
            return false
        }

        // Create dialog interaction view
        let dialogDuration = self.scaledDuration(AnimationBaseline.dialogInteraction)
        let dialogView = DialogInteractionView(
            element: element,
            elementRect: elementRect,
            action: action,
            duration: dialogDuration)

        // Display at element location
        _ = self.overlayManager.showAnimation(
            at: elementRect,
            content: dialogView,
            duration: dialogDuration,
            fadeOut: true)

        return true
    }

    private func displaySpaceTransition(from: Int, to: Int, direction: SpaceDirection) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true,
              self.settings?.spaceTransitionEnabled ?? true
        else {
            return false
        }

        // Create space transition view
        let spaceDuration = self.scaledDuration(AnimationBaseline.spaceTransition)
        let spaceView = SpaceTransitionView(
            from: from,
            to: to,
            direction: direction,
            duration: spaceDuration)

        // Display full screen where mouse is located
        let screen = self.getTargetScreen()

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: screen.frame,
            content: spaceView,
            duration: spaceDuration,
            fadeOut: true)

        return true
    }

    private func displayElementOverlays(elements: [String: CGRect], duration: TimeInterval) async -> Bool {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true else {
            return false
        }

        // For element detection, we'll show highlights on all detected elements
        // This is a simplified implementation - in a real app, you might want
        // to create a custom view that shows all elements at once

        for (elementId, rect) in elements {
            // Create a simple highlight view for each element
            let highlightView = RoundedRectangle(cornerRadius: 4)
                .stroke(Color.orange, lineWidth: 2)
                .overlay(
                    Text(elementId)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .position(x: rect.width / 2, y: -10))

            // Display using overlay manager
            _ = self.overlayManager.showAnimation(
                at: rect,
                content: highlightView,
                duration: self.scaledDuration(for: duration, minimum: AnimationBaseline.elementHighlight),
                fadeOut: true)
        }

        return true
    }

    private func displayAnnotatedScreenshot(
        imageData: Data,
        elements: [DetectedElement],
        windowBounds: CGRect,
        duration: TimeInterval) async -> Bool
    {
        // Check if enabled
        guard self.settings?.visualizerEnabled ?? true else {
            self.logger.info("🎯 Visualizer: Visualizer disabled in settings")
            return false
        }

        // Check if annotated screenshots are specifically enabled
        guard self.settings?.annotatedScreenshotEnabled ?? true else {
            self.logger.info("🎯 Visualizer: Annotated screenshot disabled in settings")
            return false
        }

        self.logger.info("🎯 Visualizer: Creating annotated screenshot view with \(elements.count) elements")

        // Filter to only enabled elements
        let enabledElements = elements.filter(\.isEnabled)

        // Create annotated screenshot view
        let annotatedView = AnnotatedScreenshotView(
            imageData: imageData,
            elements: enabledElements,
            windowBounds: windowBounds)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: windowBounds,
            content: annotatedView,
            duration: self.scaledDuration(for: duration, minimum: AnimationBaseline.annotatedScreenshot),
            fadeOut: true)

        return true
    }
}
