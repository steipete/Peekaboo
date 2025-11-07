//
import PeekabooFoundation

//  VisualizationClient.swift
//  PeekabooCore
//
//  Created by Peekaboo on 2025-01-30.
//

import AppKit
import CoreGraphics
import Foundation
import os

/// Client for communicating with the Peekaboo.app visualizer service
public final class VisualizationClient: @unchecked Sendable {
    // MARK: - Properties

    /// Shared instance for convenience
    public static let shared = VisualizationClient()

    /// Logger for debugging
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "VisualizationClient")

    /// XPC connection to the visualizer service
    private var connection: NSXPCConnection?

    /// Remote proxy object
    private var remoteProxy: (any VisualizerXPCProtocol)?

    /// Serial queue for thread-safe connection management
    private let connectionQueue = DispatchQueue(label: "boo.peekaboo.visualizer.connection")

    /// Connection state
    public private(set) var isConnected: Bool = false

    /// Visual feedback enabled state (cached)
    private var isEnabled: Bool = true

    /// Connection retry timer
    private var retryTimer: Timer?

    /// Maximum connection retry attempts
    private let maxRetryAttempts = 3

    /// Current retry attempt
    private var retryAttempt = 0

    // MARK: - Initialization

    public init() {
        // Check environment variable for disabling visual feedback
        if ProcessInfo.processInfo.environment["PEEKABOO_VISUAL_FEEDBACK"] == "false" {
            self.isEnabled = false
            self.logger.info("Visual feedback disabled via environment variable")
        }
    }

    // BEST PRACTICE: Always invalidate connection in deinit
    deinit {
        // Invalidate connection on cleanup
        connectionQueue.sync {
            self.retryTimer?.invalidate()
            self.retryTimer = nil

            if let connection = self.connection {
                connection.invalidate()
                self.connection = nil
            }
            self.remoteProxy = nil
        }
    }

    // MARK: - Connection Management

    /// Establishes connection to the visualizer service if available
    public func connect() {
        // Establishes connection to the visualizer service if available
        self.connectionQueue.async { [weak self] in
            self?.connectInternal()
        }
    }

    private func connectInternal() {
        Task { @MainActor [weak self] in
            self?.connectOnMainActor()
        }
    }

    @MainActor
    private func connectOnMainActor() {
        self.logger.info("🔌 Client: Attempting to connect to visualizer service")
        self.logger
            .info(
                "🔌 Client: Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil"), Process: \(ProcessInfo.processInfo.processName)")

        guard self.isEnabled else {
            self.logger.info("🔌 Client: Visual feedback is disabled, skipping connection")
            return
        }

        // Check if already connected to avoid duplicate connections
        if self.isConnected, self.connection != nil {
            self.logger.info("🔌 Client: Already connected, skipping")
            return
        }

        // Check if Peekaboo.app is running
        guard self.isPeekabooAppRunning() else {
            self.logger.info("🔌 Client: Peekaboo.app is not running, visual feedback unavailable")
            return
        }

        self.logger
            .info("🔌 Client: Peekaboo.app is running, establishing XPC connection to '\(VisualizerXPCServiceName)'")

        // Invalidate old connection before creating new one
        if let oldConnection = self.connection {
            oldConnection.invalidate()
            self.connection = nil
            self.remoteProxy = nil
        }

        // Create XPC connection
        let newConnection = NSXPCConnection(machServiceName: VisualizerXPCServiceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: VisualizerXPCProtocol.self)

        // Set up interruption handler with weak self to avoid retain cycles
        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.logger.error("🔌 Client: XPC connection interrupted!")
                self.handleConnectionInterruption()
            }
        }

        // Set up invalidation handler with weak self to avoid retain cycles
        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.logger.error("🔌 Client: XPC connection invalidated!")
                self.handleConnectionInvalidation()
            }
        }

        // Store connection before resuming
        self.connection = newConnection

        // Resume the connection after all configuration
        self.logger.info("🔌 Client: Resuming XPC connection...")
        newConnection.resume()

        // Get remote proxy using synchronous proxy for initial setup
        self.logger.info("🔌 Client: Getting remote proxy...")
        let proxy = newConnection.synchronousRemoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("🔌 Client: Failed to get remote proxy: \(error.localizedDescription), error: \(error)")
            self?.isConnected = false
            self?.remoteProxy = nil
        } as? (any VisualizerXPCProtocol)

        guard let proxy else {
            self.logger.error("🔌 Client: Failed to create proxy object")
            newConnection.invalidate()
            self.connection = nil
            return
        }

        self.remoteProxy = proxy

        // Test connection with timeout
        self.logger.info("🔌 Client: Testing connection with isVisualFeedbackEnabled call...")

        let semaphore = DispatchSemaphore(value: 0)

        proxy.isVisualFeedbackEnabled { [weak self] enabled in
            Task { @MainActor [weak self] in
                guard let self else {
                    semaphore.signal()
                    return
                }
                self.isConnected = true
                self.isEnabled = enabled
                self.retryAttempt = 0
                self.logger
                    .info("🔌 Client: Successfully connected to visualizer service, feedback enabled: \(enabled)")

                NotificationCenter.default.post(name: .visualizerConnected, object: nil)
                semaphore.signal()
            }
        }

        // Wait for test with timeout
        let timeout = DispatchTime.now() + .seconds(2)
        let result = semaphore.wait(timeout: timeout)

        if result == .timedOut {
            self.logger.error("🔌 Client: Connection test timed out")
            newConnection.invalidate()
            self.connection = nil
            self.remoteProxy = nil
            self.isConnected = false
        }
    }

    /// Disconnects from the visualizer service
    public func disconnect() {
        // Disconnects from the visualizer service
        self.connectionQueue.sync {
            self.retryTimer?.invalidate()
            self.retryTimer = nil

            // Always invalidate connection properly
            self.connection?.invalidate()
            self.connection = nil
            self.remoteProxy = nil
            self.isConnected = false

            self.logger.info("Disconnected from visualizer service")

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .visualizerDisconnected, object: nil)
            }
        }
    }

    // MARK: - Visual Feedback Methods

    /// Shows screenshot flash animation
    public func showScreenshotFlash(in rect: CGRect) async -> Bool {
        // Shows screenshot flash animation
        self.logger.info("📸 Client: Screenshot flash requested for rect: \(String(describing: rect))")

        guard self.isConnected else {
            self.logger.warning("📸 Client: Not connected to visualizer service")
            return false
        }

        guard self.isEnabled else {
            self.logger.info("📸 Client: Visual feedback disabled")
            return false
        }

        // Check screenshot-specific environment variable
        if ProcessInfo.processInfo.environment["PEEKABOO_VISUAL_SCREENSHOTS"] == "false" {
            self.logger.info("📸 Client: Screenshot visual feedback disabled via environment variable")
            return false
        }

        self.logger.info("📸 Client: Sending screenshot flash to XPC service")

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showScreenshotFlash(in: rect) { success in
                self.logger.info("📸 Client: Screenshot flash result: \(success)")
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows click feedback
    public func showClickFeedback(at point: CGPoint, type: ClickType) async -> Bool {
        // Shows click feedback
        self.logger.info("[tap]️ Client: Click feedback requested at point: \(String(describing: point)), type: \(type)")

        guard self.isConnected else {
            self.logger.warning("[tap]️ Client: Not connected to visualizer service")
            return false
        }

        guard self.isEnabled else {
            self.logger.info("[tap]️ Client: Visual feedback disabled")
            return false
        }

        self.logger.info("[tap]️ Client: Sending click feedback to XPC service")

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showClickFeedback(at: point, type: type.rawValue) { success in
                self.logger.info("[tap]️ Client: Click feedback result: \(success)")
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows typing feedback
    public func showTypingFeedback(keys: [String], duration: TimeInterval = 2.0) async -> Bool {
        // Shows typing feedback
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showTypingFeedback(keys: keys, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows scroll feedback
    public func showScrollFeedback(at point: CGPoint, direction: ScrollDirection, amount: Int) async -> Bool {
        // Shows scroll feedback
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showScrollFeedback(at: point, direction: direction.rawValue, amount: amount) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows mouse movement trail
    public func showMouseMovement(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        // Shows mouse movement trail
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showMouseMovement(from: from, to: to, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows swipe gesture
    public func showSwipeGesture(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        // Shows swipe gesture
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showSwipeGesture(from: from, to: to, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows hotkey display
    public func showHotkeyDisplay(keys: [String], duration: TimeInterval = 1.0) async -> Bool {
        // Shows hotkey display
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showHotkeyDisplay(keys: keys, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows app launch animation
    public func showAppLaunch(appName: String, iconPath: String? = nil) async -> Bool {
        // Shows app launch animation
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showAppLaunch(appName: appName, iconPath: iconPath) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows app quit animation
    public func showAppQuit(appName: String, iconPath: String? = nil) async -> Bool {
        // Shows app quit animation
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showAppQuit(appName: appName, iconPath: iconPath) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows window operation feedback
    public func showWindowOperation(
        _ operation: WindowOperation,
        windowRect: CGRect,
        duration: TimeInterval = 0.5) async -> Bool
    {
        // Shows window operation feedback
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showWindowOperation(
                operation: operation.rawValue,
                windowRect: windowRect,
                duration: duration)
            { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows menu navigation path
    public func showMenuNavigation(menuPath: [String]) async -> Bool {
        // Shows menu navigation path
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showMenuNavigation(menuPath: menuPath) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows dialog interaction feedback
    public func showDialogInteraction(element: String, elementRect: CGRect, action: String) async -> Bool {
        // Shows dialog interaction feedback
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?
                .showDialogInteraction(elementType: element, elementRect: elementRect, action: action) { success in
                    continuation.resume(returning: success)
                }
        }
    }

    /// Shows space switching animation
    public func showSpaceSwitch(from: Int, to: Int, direction: SpaceDirection) async -> Bool {
        // Shows space switching animation
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showSpaceSwitch(from: from, to: to, direction: direction.rawValue) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows element detection overlays
    public func showElementDetection(elements: [String: CGRect], duration: TimeInterval = 2.0) async -> Bool {
        // Shows element detection overlays
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showElementDetection(elements: elements, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Shows annotated screenshot with UI element overlays
    public func showAnnotatedScreenshot(
        imageData: Data,
        elements: [DetectedElement],
        windowBounds: CGRect,
        duration: TimeInterval = 3.0) async -> Bool
    {
        // Shows annotated screenshot with UI element overlays
        self.logger.info("[focus] Client: Annotated screenshot requested with \(elements.count) elements")

        guard self.isConnected else {
            self.logger.warning("[focus] Client: Not connected to visualizer service")
            return false
        }

        guard self.isEnabled else {
            self.logger.info("[focus] Client: Visual feedback disabled")
            return false
        }

        // Serialize elements
        do {
            let encoder = JSONEncoder()
            let elementData = try encoder.encode(elements)

            return await withCheckedContinuation { continuation in
                self.remoteProxy?.showAnnotatedScreenshot(
                    imageData: imageData,
                    elementData: elementData,
                    windowBounds: windowBounds,
                    duration: duration)
                { success in
                    self.logger.info("[focus] Client: Annotated screenshot result: \(success)")
                    continuation.resume(returning: success)
                }
            }
        } catch {
            self.logger.error("[focus] Client: Failed to encode elements: \(error)")
            return false
        }
    }

    // MARK: - Settings

    /// Updates visualizer settings
    public func updateSettings(_ settings: [String: Any]) async -> Bool {
        // Updates visualizer settings
        guard self.isConnected else { return false }

        let success = await withCheckedContinuation { continuation in
            self.remoteProxy?.updateSettings(settings) { success in
                continuation.resume(returning: success)
            }
        }

        if success {
            NotificationCenter.default.post(name: .visualizerSettingsChanged, object: settings)
        }

        return success
    }

    // MARK: - Private Methods

    /// Checks if Peekaboo.app is running
    private func isPeekabooAppRunning() -> Bool {
        if Thread.isMainThread {
            return self.lookupPeekabooApp()
        }

        return DispatchQueue.main.sync {
            self.lookupPeekabooApp()
        }
    }

    @MainActor
    private func lookupPeekabooApp() -> Bool {
        // Checks if Peekaboo.app is running
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        let peekabooApps = runningApps.filter { app in
            app.bundleIdentifier == "boo.peekaboo.mac" || app.bundleIdentifier == "boo.peekaboo.mac.debug"
        }

        if !peekabooApps.isEmpty {
            for app in peekabooApps {
                self.logger
                    .debug(
                        "🔌 Client: Found Peekaboo.app - Bundle: \(app.bundleIdentifier ?? "unknown"), PID: \(app.processIdentifier)")
            }
        } else {
            self.logger.debug("🔌 Client: No Peekaboo.app instances found in running apps")
        }

        return !peekabooApps.isEmpty
    }

    /// Handles connection interruption
    private func handleConnectionInterruption() {
        // Handles connection interruption
        self.logger.warning("XPC connection interrupted")
        self.isConnected = false

        // Don't nil out connection here - it may recover

        // Schedule retry
        self.scheduleConnectionRetry()
    }

    /// Handles connection invalidation
    private func handleConnectionInvalidation() {
        // Handles connection invalidation
        self.logger.warning("XPC connection invalidated")
        self.isConnected = false
        self.connection = nil
        self.remoteProxy = nil

        // Schedule retry
        self.scheduleConnectionRetry()
    }

    /// Schedules a connection retry
    private func scheduleConnectionRetry() {
        // Schedules a connection retry
        guard self.retryAttempt < self.maxRetryAttempts else {
            self.logger.error("Max retry attempts reached, giving up")
            return
        }

        self.retryAttempt += 1
        let delay = TimeInterval(retryAttempt * 2) // Exponential backoff

        self.logger.info("Scheduling connection retry #\(self.retryAttempt) in \(delay) seconds")

        DispatchQueue.main.async { [weak self] in
            self?.retryTimer?.invalidate()
            self?.retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect()
            }
        }
    }
}

// MARK: - Supporting Types

public enum WindowOperation: String {
    case move
    case resize
    case minimize
    case close
    case maximize
    case setBounds
    case focus
}

public enum SpaceDirection: String {
    case left
    case right
}
