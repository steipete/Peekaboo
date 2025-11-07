//
//  VisualizationClient.swift
//  PeekabooCore
//

import AppKit
import CoreGraphics
import Foundation
import os
import PeekabooFoundation

@MainActor
public final class VisualizationClient: @unchecked Sendable {
    private enum VisualizationClientError: Error {
        case connectionTimedOut
    }

    // MARK: - Properties

    public static let shared = VisualizationClient()

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "VisualizationClient")

    private var connection: NSXPCConnection?
    private var remoteProxy: (any VisualizerXPCProtocol)?
    private var connectionTask: Task<Void, Never>?

    public private(set) var isConnected: Bool = false
    private var isEnabled: Bool = true

    private var retryTimer: Timer?
    private let maxRetryAttempts = 3
    private var retryAttempt = 0

    // MARK: - Initialization

    public init() {
        if ProcessInfo.processInfo.environment["PEEKABOO_VISUAL_FEEDBACK"] == "false" {
            self.isEnabled = false
            self.logger.info("Visual feedback disabled via environment variable")
        }
    }

    // MARK: - Connection Management

    public func connect() {
        guard self.isEnabled else {
            self.logger.info("🔌 Client: Visual feedback is disabled, skipping connection")
            return
        }

        if self.isConnected, self.connection != nil {
            self.logger.info("🔌 Client: Already connected, skipping")
            return
        }

        if let existingTask = self.connectionTask, !existingTask.isCancelled {
            self.logger.debug("🔌 Client: Connection attempt already in progress")
            return
        }

        self.connectionTask = Task { @MainActor [weak self] in
            await self?.establishConnection()
        }
    }

    public func disconnect() {
        self.connectionTask?.cancel()
        self.connectionTask = nil
        self.invalidateRetryTimer()
        self.isConnected = false
        self.invalidateConnection()
        self.logger.info("Disconnected from visualizer service")
        NotificationCenter.default.post(name: .visualizerDisconnected, object: nil)
    }

    private func establishConnection() async {
        defer { self.connectionTask = nil }

        self.logger.info("🔌 Client: Attempting to connect to visualizer service")
        self.logger.info("🔌 Client: Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil"), Process: \(ProcessInfo.processInfo.processName)")

        guard self.isEnabled else { return }

        if self.isConnected, self.connection != nil {
            self.logger.info("🔌 Client: Already connected, skipping")
            return
        }

        guard self.isPeekabooAppRunning() else {
            self.logger.info("🔌 Client: Peekaboo.app is not running, visual feedback unavailable")
            return
        }

        self.logger.info("🔌 Client: Peekaboo.app is running, establishing XPC connection to '\(VisualizerXPCServiceName)'")

        self.invalidateConnection()

        let newConnection = NSXPCConnection(machServiceName: VisualizerXPCServiceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: (any VisualizerXPCProtocol).self)

        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.logger.error("🔌 Client: XPC connection interrupted!")
                self.handleConnectionInterruption()
            }
        }

        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.logger.error("🔌 Client: XPC connection invalidated!")
                self.handleConnectionInvalidation()
            }
        }

        self.connection = newConnection
        self.logger.info("🔌 Client: Resuming XPC connection...")
        newConnection.resume()

        guard let proxy = self.makeRemoteProxy(from: newConnection) else {
            self.logger.error("🔌 Client: Failed to create proxy object")
            self.invalidateConnection()
            return
        }

        do {
            let enabled = try await self.fetchVisualFeedbackState(proxy: proxy)
            self.remoteProxy = proxy
            self.isConnected = true
            self.isEnabled = enabled
            self.retryAttempt = 0
            self.logger.info("🔌 Client: Successfully connected to visualizer service, feedback enabled: \(enabled)")
            NotificationCenter.default.post(name: .visualizerConnected, object: nil)
        } catch {
            self.logger.error("🔌 Client: Connection test failed: \(String(describing: error))")
            self.isConnected = false
            self.invalidateConnection()
            self.scheduleConnectionRetry()
        }
    }

    private func makeRemoteProxy(from connection: NSXPCConnection) -> (any VisualizerXPCProtocol)? {
        connection.synchronousRemoteObjectProxyWithErrorHandler { [weak self] error in
            guard let self else { return }
            self.logger.error("🔌 Client: Failed to get remote proxy: \(error.localizedDescription), error: \(error)")
            self.isConnected = false
            self.remoteProxy = nil
        } as? (any VisualizerXPCProtocol)
    }

    private func fetchVisualFeedbackState(proxy: any VisualizerXPCProtocol) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            let timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !didResume else { return }
                didResume = true
                continuation.resume(throwing: VisualizationClientError.connectionTimedOut)
            }

            proxy.isVisualFeedbackEnabled { enabled in
                Task { @MainActor in
                    guard !didResume else { return }
                    didResume = true
                    timeoutTask.cancel()
                    continuation.resume(returning: enabled)
                }
            }
        }
    }

    private func invalidateConnection() {
        self.connection?.invalidate()
        self.connection = nil
        self.remoteProxy = nil
    }

    private func invalidateRetryTimer() {
        self.retryTimer?.invalidate()
        self.retryTimer = nil
    }

    // MARK: - Visual Feedback Methods

    public func showScreenshotFlash(in rect: CGRect) async -> Bool {
        self.logger.info("📸 Client: Screenshot flash requested for rect: \(String(describing: rect))")

        guard self.isConnected else {
            self.logger.warning("📸 Client: Not connected to visualizer service")
            return false
        }

        guard self.isEnabled else {
            self.logger.info("📸 Client: Visual feedback disabled")
            return false
        }

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

    public func showClickFeedback(at point: CGPoint, type: ClickType) async -> Bool {
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

    public func showTypingFeedback(keys: [String], duration: TimeInterval = 2.0) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showTypingFeedback(keys: keys, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showScrollFeedback(at point: CGPoint, direction: ScrollDirection, amount: Int) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showScrollFeedback(at: point, direction: direction.rawValue, amount: amount) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showMouseMovement(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showMouseMovement(from: from, to: to, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showSwipeGesture(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showSwipeGesture(from: from, to: to, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showHotkeyDisplay(keys: [String], duration: TimeInterval = 1.0) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showHotkeyDisplay(keys: keys, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showAppLaunch(appName: String, iconPath: String? = nil) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showAppLaunch(appName: appName, iconPath: iconPath) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showAppQuit(appName: String, iconPath: String? = nil) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showAppQuit(appName: appName, iconPath: iconPath) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showWindowOperation(
        _ operation: WindowOperation,
        windowRect: CGRect,
        duration: TimeInterval = 0.5) async -> Bool
    {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showWindowOperation(
                operation: operation.rawValue,
                windowRect: windowRect,
                duration: duration) { success in
                    continuation.resume(returning: success)
                }
        }
    }

    public func showMenuNavigation(menuPath: [String]) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showMenuNavigation(menuPath: menuPath) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showDialogInteraction(element: String, elementRect: CGRect, action: String) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showDialogInteraction(elementType: element, elementRect: elementRect, action: action) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showSpaceSwitch(from: Int, to: Int, direction: SpaceDirection) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showSpaceSwitch(from: from, to: to, direction: direction.rawValue) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showElementDetection(elements: [String: CGRect], duration: TimeInterval = 2.0) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }

        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showElementDetection(elements: elements, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }

    public func showAnnotatedScreenshot(
        imageData: Data,
        elements: [DetectedElement],
        windowBounds: CGRect,
        duration: TimeInterval = 3.0) async -> Bool
    {
        self.logger.info("[focus] Client: Annotated screenshot requested with \(elements.count) elements")

        guard self.isConnected else {
            self.logger.warning("[focus] Client: Not connected to visualizer service")
            return false
        }

        guard self.isEnabled else {
            self.logger.info("[focus] Client: Visual feedback disabled")
            return false
        }

        do {
            let encoder = JSONEncoder()
            let elementData = try encoder.encode(elements)

            return await withCheckedContinuation { continuation in
                self.remoteProxy?.showAnnotatedScreenshot(
                    imageData: imageData,
                    elementData: elementData,
                    windowBounds: windowBounds,
                    duration: duration) { success in
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

    public func updateSettings(_ settings: [String: Any]) async -> Bool {
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

    private func isPeekabooAppRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let peekabooApps = runningApps.filter { app in
            app.bundleIdentifier == "boo.peekaboo.mac" || app.bundleIdentifier == "boo.peekaboo.mac.debug"
        }

        if peekabooApps.isEmpty {
            self.logger.debug("🔌 Client: No Peekaboo.app instances found in running apps")
        } else {
            for app in peekabooApps {
                self.logger.debug("🔌 Client: Found Peekaboo.app - Bundle: \(app.bundleIdentifier ?? "unknown"), PID: \(app.processIdentifier)")
            }
        }

        return !peekabooApps.isEmpty
    }

    private func handleConnectionInterruption() {
        self.logger.warning("XPC connection interrupted")
        self.isConnected = false
        self.scheduleConnectionRetry()
    }

    private func handleConnectionInvalidation() {
        self.logger.warning("XPC connection invalidated")
        self.isConnected = false
        self.invalidateConnection()
        self.scheduleConnectionRetry()
    }

    private func scheduleConnectionRetry() {
        guard self.retryAttempt < self.maxRetryAttempts else {
            self.logger.error("Max retry attempts reached, giving up")
            return
        }

        self.retryAttempt += 1
        let delay = TimeInterval(self.retryAttempt * 2)

        self.logger.info("Scheduling connection retry #\(self.retryAttempt) in \(delay) seconds")

        self.invalidateRetryTimer()
        self.retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.connect()
            }
        }
    }
}

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
