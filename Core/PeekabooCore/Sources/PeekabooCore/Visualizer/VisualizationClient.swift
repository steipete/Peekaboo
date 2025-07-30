//
//  VisualizationClient.swift
//  PeekabooCore
//
//  Created by Peekaboo on 2025-01-30.
//

import Foundation
import CoreGraphics
import os

/// Client for communicating with the Peekaboo.app visualizer service
@MainActor
public final class VisualizationClient {
    
    // MARK: - Properties
    
    /// Shared instance for convenience
    public static let shared = VisualizationClient()
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "VisualizationClient")
    
    /// XPC connection to the visualizer service
    private var connection: NSXPCConnection?
    
    /// Remote proxy object
    private var remoteProxy: VisualizerXPCProtocol?
    
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
            isEnabled = false
            logger.info("Visual feedback disabled via environment variable")
        }
    }
    
    // MARK: - Connection Management
    
    /// Establishes connection to the visualizer service if available
    public func connect() {
        guard isEnabled else {
            logger.debug("Visual feedback is disabled, skipping connection")
            return
        }
        
        // Check if Peekaboo.app is running
        guard isPeekabooAppRunning() else {
            logger.debug("Peekaboo.app is not running, visual feedback unavailable")
            return
        }
        
        // Create XPC connection
        connection = NSXPCConnection(machServiceName: VisualizerXPCServiceName)
        connection?.remoteObjectInterface = NSXPCInterface(with: VisualizerXPCProtocol.self)
        
        // Set up interruption handler
        connection?.interruptionHandler = { [weak self] in
            self?.handleConnectionInterruption()
        }
        
        // Set up invalidation handler
        connection?.invalidationHandler = { [weak self] in
            self?.handleConnectionInvalidation()
        }
        
        // Resume the connection
        connection?.resume()
        
        // Get remote proxy
        remoteProxy = connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("Failed to get remote proxy: \(error.localizedDescription)")
            self?.isConnected = false
        } as? VisualizerXPCProtocol
        
        // Test connection
        remoteProxy?.isVisualFeedbackEnabled { [weak self] enabled in
            self?.isConnected = true
            self?.isEnabled = enabled
            self?.retryAttempt = 0
            self?.logger.info("Connected to visualizer service, feedback enabled: \(enabled)")
            
            // Post notification
            NotificationCenter.default.post(name: .visualizerConnected, object: nil)
        }
    }
    
    /// Disconnects from the visualizer service
    public func disconnect() {
        retryTimer?.invalidate()
        retryTimer = nil
        
        connection?.invalidate()
        connection = nil
        remoteProxy = nil
        isConnected = false
        
        logger.info("Disconnected from visualizer service")
        NotificationCenter.default.post(name: .visualizerDisconnected, object: nil)
    }
    
    // MARK: - Visual Feedback Methods
    
    /// Shows screenshot flash animation
    public func showScreenshotFlash(in rect: CGRect) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showScreenshotFlash(in: rect) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows click feedback
    public func showClickFeedback(at point: CGPoint, type: ClickType) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showClickFeedback(at: point, type: type.rawValue) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows typing feedback
    public func showTypingFeedback(keys: [String], duration: TimeInterval = 2.0) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showTypingFeedback(keys: keys, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows scroll feedback
    public func showScrollFeedback(at point: CGPoint, direction: ScrollDirection, amount: Int) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showScrollFeedback(at: point, direction: direction.rawValue, amount: amount) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows mouse movement trail
    public func showMouseMovement(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showMouseMovement(from: from, to: to, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows swipe gesture
    public func showSwipeGesture(from: CGPoint, to: CGPoint, duration: TimeInterval) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showSwipeGesture(from: from, to: to, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows hotkey display
    public func showHotkeyDisplay(keys: [String], duration: TimeInterval = 1.0) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showHotkeyDisplay(keys: keys, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows app launch animation
    public func showAppLaunch(appName: String, iconPath: String? = nil) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showAppLaunch(appName: appName, iconPath: iconPath) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows app quit animation
    public func showAppQuit(appName: String, iconPath: String? = nil) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showAppQuit(appName: appName, iconPath: iconPath) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows window operation feedback
    public func showWindowOperation(_ operation: WindowOperation, windowRect: CGRect, duration: TimeInterval = 0.5) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showWindowOperation(operation: operation.rawValue, windowRect: windowRect, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows menu navigation path
    public func showMenuNavigation(menuPath: [String]) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showMenuNavigation(menuPath: menuPath) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows dialog interaction feedback
    public func showDialogInteraction(elementType: DialogElement, elementRect: CGRect, action: DialogAction) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showDialogInteraction(elementType: elementType.rawValue, elementRect: elementRect, action: action.rawValue) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows space switching animation
    public func showSpaceSwitch(from: Int, to: Int, direction: SpaceDirection) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showSpaceSwitch(from: from, to: to, direction: direction.rawValue) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Shows element detection overlays
    public func showElementDetection(elements: [String: CGRect], duration: TimeInterval = 2.0) async -> Bool {
        guard isConnected, isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.showElementDetection(elements: elements, duration: duration) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Settings
    
    /// Updates visualizer settings
    public func updateSettings(_ settings: [String: Any]) async -> Bool {
        guard isConnected else { return false }
        
        return await withCheckedContinuation { continuation in
            remoteProxy?.updateSettings(settings) { success in
                if success {
                    NotificationCenter.default.post(name: .visualizerSettingsChanged, object: settings)
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Checks if Peekaboo.app is running
    private func isPeekabooAppRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        return runningApps.contains { app in
            app.bundleIdentifier == "boo.peekaboo.mac"
        }
    }
    
    /// Handles connection interruption
    private func handleConnectionInterruption() {
        logger.warning("XPC connection interrupted")
        isConnected = false
        
        // Schedule retry
        scheduleConnectionRetry()
    }
    
    /// Handles connection invalidation
    private func handleConnectionInvalidation() {
        logger.warning("XPC connection invalidated")
        isConnected = false
        connection = nil
        remoteProxy = nil
        
        // Schedule retry
        scheduleConnectionRetry()
    }
    
    /// Schedules a connection retry
    private func scheduleConnectionRetry() {
        guard retryAttempt < maxRetryAttempts else {
            logger.error("Max retry attempts reached, giving up")
            return
        }
        
        retryAttempt += 1
        let delay = TimeInterval(retryAttempt * 2) // Exponential backoff
        
        logger.info("Scheduling connection retry #\(retryAttempt) in \(delay) seconds")
        
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
}

// MARK: - Supporting Types

public enum ClickType: String {
    case single = "single"
    case double = "double"
    case right = "right"
}

public enum ScrollDirection: String {
    case up = "up"
    case down = "down"
    case left = "left"
    case right = "right"
}

public enum WindowOperation: String {
    case move = "move"
    case resize = "resize"
    case minimize = "minimize"
    case close = "close"
}

public enum DialogElement: String {
    case button = "button"
    case textField = "textfield"
    case checkbox = "checkbox"
    case radioButton = "radio"
    case dropdown = "dropdown"
}

public enum DialogAction: String {
    case click = "click"
    case focus = "focus"
    case type = "type"
    case select = "select"
}

public enum SpaceDirection: String {
    case left = "left"
    case right = "right"
}