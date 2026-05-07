import CoreGraphics
import Foundation
import PeekabooFoundation
import PeekabooProtocols
import SwiftUI

// MARK: - System Display Methods

@available(macOS 14.0, *)
extension VisualizerCoordinator {
    func displayAppLaunchAnimation(appName: String, iconPath: String?) async -> Bool {
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
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.appLifecycle),
            content: launchView,
            duration: launchDuration,
            fadeOut: true)

        return true
    }

    func displayAppQuitAnimation(appName: String, iconPath: String?) async -> Bool {
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
            at: Self.paddedRect(rect, padding: Self.OverlayPadding.appLifecycle),
            content: quitView,
            duration: quitDuration,
            fadeOut: true)

        return true
    }

    func displayWindowOperation(
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
            at: Self.paddedRect(windowRect, padding: Self.OverlayPadding.windowOperation),
            content: windowView,
            duration: windowDuration,
            fadeOut: true)

        return true
    }

    func displayMenuHighlights(menuPath: [String]) async -> Bool {
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
        let overlaySize = Self.estimatedMenuOverlaySize(for: menuPath)
        let rect = CGRect(
            x: screenFrame.midX - overlaySize.width / 2,
            y: screenFrame.maxY - overlaySize.height - 50,
            width: overlaySize.width,
            height: overlaySize.height)

        // Display using overlay manager
        _ = self.overlayManager.showAnimation(
            at: Self.paddedRect(rect, padding: 0),
            content: menuView,
            duration: menuDuration,
            fadeOut: true)

        return true
    }

    func displayDialogFeedback(
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
            at: Self.paddedRect(elementRect, padding: Self.OverlayPadding.dialog),
            content: dialogView,
            duration: dialogDuration,
            fadeOut: true)

        return true
    }

    func displaySpaceTransition(from: Int, to: Int, direction: SpaceDirection) async -> Bool {
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

    func displayElementOverlays(elements: [String: CGRect], duration: TimeInterval) async -> Bool {
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
                at: Self.paddedRect(rect, padding: Self.OverlayPadding.elementHighlight),
                content: highlightView,
                duration: self.scaledDuration(for: duration, minimum: AnimationBaseline.elementHighlight),
                fadeOut: true)
        }

        return true
    }

    func displayAnnotatedScreenshot(
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
            at: Self.paddedRect(windowBounds, padding: Self.OverlayPadding.annotatedScreenshot),
            content: annotatedView,
            duration: self.scaledDuration(for: duration, minimum: AnimationBaseline.annotatedScreenshot),
            fadeOut: true)

        return true
    }
}
