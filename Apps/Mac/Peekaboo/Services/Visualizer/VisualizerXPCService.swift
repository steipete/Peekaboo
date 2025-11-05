//
//  VisualizerXPCService.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import CoreGraphics
import Foundation
import os
import PeekabooCore
import PeekabooFoundation

/// XPC service implementation for the visualizer
@MainActor
final class VisualizerXPCService: NSObject {
    // MARK: - Properties

    /// Logger for debugging
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "VisualizerXPCService")

    /// XPC listener
    private var listener: NSXPCListener?

    /// Visualizer coordinator (manages animations)
    private let visualizerCoordinator: VisualizerCoordinator

    /// Settings (now comes from connected coordinator)
    // Removed internal settings - coordinator manages its own

    // MARK: - Initialization

    init(visualizerCoordinator: VisualizerCoordinator) {
        self.visualizerCoordinator = visualizerCoordinator
        super.init()
    }

    // MARK: - Service Management

    /// Starts the XPC service
    func start() {
        // Create listener for our Mach service
        self.listener = NSXPCListener(machServiceName: VisualizerXPCServiceName)
        self.listener?.delegate = self
        self.listener?.resume()

        self.logger.info("🎨 XPC Service: Started listening on '\(VisualizerXPCServiceName)'")
        self.logger.info("🎨 XPC Service: Listener state: \(self.listener != nil ? "created" : "nil")")
    }

    /// Stops the XPC service
    func stop() {
        self.listener?.invalidate()
        self.listener = nil

        self.logger.info("Visualizer XPC service stopped")
    }
}

// MARK: - NSXPCListenerDelegate

extension VisualizerXPCService: @preconcurrency NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        self.logger.info("🎨 XPC Service: New connection request received!")
        self.logger.info("🎨 XPC Service: Connection PID: \(newConnection.processIdentifier)")

        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: VisualizerXPCProtocol.self)
        newConnection.exportedObject = self

        // Set up handlers
        newConnection.interruptionHandler = { [weak self] in
            self?.logger.warning("🎨 XPC Service: Connection interrupted from PID \(newConnection.processIdentifier)")
        }

        newConnection.invalidationHandler = { [weak self] in
            self?.logger.info("🎨 XPC Service: Connection invalidated from PID \(newConnection.processIdentifier)")
        }

        // Resume the connection
        newConnection.resume()
        self.logger.info("🎨 XPC Service: Connection accepted and resumed for PID \(newConnection.processIdentifier)")

        return true
    }
}

// MARK: - VisualizerXPCProtocol

extension VisualizerXPCService: @preconcurrency VisualizerXPCProtocol {
    func showScreenshotFlash(in rect: CGRect, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.info("🎨 XPC Service: Screenshot flash requested for rect: \(String(describing: rect))")
            self.logger.debug("🎨 XPC Service: Processing on thread: \(Thread.current)")

            // Let the coordinator check its own settings
            // It has access to the real PeekabooSettings

            let success = await visualizerCoordinator.showScreenshotFlash(in: rect)
            self.logger.info("🎨 XPC Service: Screenshot flash completed with result: \(success)")
            reply(success)
        }
    }

    func showClickFeedback(at point: CGPoint, type: String, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Click feedback requested at \(String(describing: point)), type: \(type)")

            // Let the coordinator check its own settings

            let clickType = PeekabooFoundation.ClickType(rawValue: type) ?? .single
            let success = await visualizerCoordinator.showClickFeedback(at: point, type: clickType)
            reply(success)
        }
    }

    func showTypingFeedback(keys: [String], duration: TimeInterval, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Typing feedback requested for \(keys.count) keys")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showTypingFeedback(keys: keys, duration: duration)
            reply(success)
        }
    }

    func showScrollFeedback(at point: CGPoint, direction: String, amount: Int, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger
                .debug(
                    "Scroll feedback requested at \(String(describing: point)), direction: \(direction), amount: \(amount)")

            // Let the coordinator check its own settings

            let scrollDirection = PeekabooFoundation.ScrollDirection(rawValue: direction) ?? .down
            let success = await visualizerCoordinator.showScrollFeedback(
                at: point,
                direction: scrollDirection,
                amount: amount)
            reply(success)
        }
    }

    func showMouseMovement(
        from fromPoint: CGPoint,
        to toPoint: CGPoint,
        duration: TimeInterval,
        reply: @escaping (Bool) -> Void)
    {
        Task { @MainActor in
            self.logger
                .debug(
                    "Mouse movement requested from \(String(describing: fromPoint)) to \(String(describing: toPoint))")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showMouseMovement(
                from: fromPoint,
                to: toPoint,
                duration: duration)
            reply(success)
        }
    }

    func showSwipeGesture(
        from fromPoint: CGPoint,
        to toPoint: CGPoint,
        duration: TimeInterval,
        reply: @escaping (Bool) -> Void)
    {
        Task { @MainActor in
            self.logger
                .debug(
                    "Swipe gesture requested from \(String(describing: fromPoint)) to \(String(describing: toPoint))")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showSwipeGesture(from: fromPoint, to: toPoint, duration: duration)
            reply(success)
        }
    }

    func showHotkeyDisplay(keys: [String], duration: TimeInterval, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Hotkey display requested for keys: \(keys)")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showHotkeyDisplay(keys: keys, duration: duration)
            reply(success)
        }
    }

    func showAppLaunch(appName: String, iconPath: String?, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("App launch animation requested for: \(appName)")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showAppLaunch(appName: appName, iconPath: iconPath)
            reply(success)
        }
    }

    func showAppQuit(appName: String, iconPath: String?, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("App quit animation requested for: \(appName)")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showAppQuit(appName: appName, iconPath: iconPath)
            reply(success)
        }
    }

    func showWindowOperation(
        operation: String,
        windowRect: CGRect,
        duration: TimeInterval,
        reply: @escaping (Bool) -> Void)
    {
        Task { @MainActor in
            self.logger.debug("Window operation requested: \(operation) for rect: \(String(describing: windowRect))")

            // Let the coordinator check its own settings

            let windowOp = WindowOperation(rawValue: operation) ?? .move
            let success = await visualizerCoordinator.showWindowOperation(
                windowOp,
                windowRect: windowRect,
                duration: duration)
            reply(success)
        }
    }

    func showMenuNavigation(menuPath: [String], reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Menu navigation requested for path: \(menuPath)")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showMenuNavigation(menuPath: menuPath)
            reply(success)
        }
    }

    func showDialogInteraction(
        elementType: String,
        elementRect: CGRect,
        action: String,
        reply: @escaping (Bool) -> Void)
    {
        Task { @MainActor in
            self.logger
                .debug(
                    "Dialog interaction requested: \(elementType) at \(String(describing: elementRect)), action: \(action)")

            // Let the coordinator check its own settings

            // Convert string role to DialogElementType enum for visualization
            let elementType = DialogElementType(role: elementType)
            let dialogAction = DialogActionType(rawValue: action) ?? .clickButton
            let success = await visualizerCoordinator.showDialogInteraction(
                element: elementType,
                elementRect: elementRect,
                action: dialogAction)
            reply(success)
        }
    }

    func showSpaceSwitch(from fromSpace: Int, to toSpace: Int, direction: String, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Space switch requested from \(fromSpace) to \(toSpace), direction: \(direction)")

            // Let the coordinator check its own settings

            let spaceDirection = SpaceDirection(rawValue: direction) ?? .right
            let success = await visualizerCoordinator.showSpaceSwitch(
                from: fromSpace,
                to: toSpace,
                direction: spaceDirection)
            reply(success)
        }
    }

    func showElementDetection(elements: [String: CGRect], duration: TimeInterval, reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Element detection requested for \(elements.count) elements")

            // Let the coordinator check its own settings

            let success = await visualizerCoordinator.showElementDetection(elements: elements, duration: duration)
            reply(success)
        }
    }

    func showAnnotatedScreenshot(
        imageData: Data,
        elementData: Data,
        windowBounds: CGRect,
        duration: TimeInterval,
        reply: @escaping (Bool) -> Void)
    {
        Task { @MainActor in
            self.logger.debug("Annotated screenshot requested with \(imageData.count) bytes of image data")

            // Deserialize elements
            do {
                let decoder = JSONDecoder()
                let elements = try decoder.decode([DetectedElement].self, from: elementData)

                let success = await self.visualizerCoordinator.showAnnotatedScreenshot(
                    imageData: imageData,
                    elements: elements,
                    windowBounds: windowBounds,
                    duration: duration)
                reply(success)
            } catch {
                self.logger.error("Failed to decode element data: \(error)")
                reply(false)
            }
        }
    }

    func isVisualFeedbackEnabled(reply: @escaping (Bool) -> Void) {
        // Check the coordinator's settings
        let isEnabled = self.visualizerCoordinator.isEnabled()
        reply(isEnabled)
    }

    func updateSettings(_ settingsDict: [String: Any], reply: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.logger.debug("Settings update requested")

            // Settings update is now handled through PeekabooSettings
            // The coordinator will automatically pick up changes through its connected settings reference
            // This method is kept for XPC protocol compatibility but doesn't need to do anything

            reply(true)
        }
    }
}

// MARK: - Settings Keys (for compatibility)

private enum VisualizerSettings {
    // Settings keys kept for XPC protocol compatibility
    static let enabledKey = "enabled"
    static let animationSpeedKey = "animationSpeed"
    static let effectIntensityKey = "effectIntensity"
    static let screenshotFlashKey = "screenshotFlashEnabled"
    static let clickAnimationKey = "clickAnimationEnabled"
    static let typingFeedbackKey = "typingFeedbackEnabled"
    static let scrollIndicatorKey = "scrollIndicatorEnabled"
    static let mouseTrailKey = "mouseTrailEnabled"
    static let hotkeyDisplayKey = "hotkeyDisplayEnabled"
    static let appAnimationsKey = "appAnimationsEnabled"
    static let windowAnimationsKey = "windowAnimationsEnabled"
    static let menuHighlightKey = "menuHighlightEnabled"
    static let dialogFeedbackKey = "dialogFeedbackEnabled"
    static let spaceAnimationKey = "spaceAnimationEnabled"
    static let elementOverlaysKey = "elementOverlaysEnabled"
}
