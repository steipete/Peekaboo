//
//  VisualizationClientImproved.swift
//  PeekabooCore
//

import AppKit
import CoreGraphics
import Foundation
import os
import PeekabooFoundation

/// Improved client for communicating with the Peekaboo.app visualizer service
/// Addresses XPC best practices and common pitfalls
public final class VisualizationClientImproved: @unchecked Sendable {
    // MARK: - Properties
    
    /// Shared instance for convenience
    public static let shared = VisualizationClientImproved()
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "VisualizationClient")
    
    /// XPC connection to the visualizer service
    private var connection: NSXPCConnection?
    
    /// Remote proxy object
    private var remoteProxy: VisualizerXPCProtocol?
    
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
        connectionQueue.async { [weak self] in
            self?.connectInternal()
        }
    }
    
    private func connectInternal() {
        self.logger.info("🔌 Client: Attempting to connect to visualizer service")
        self.logger.info("🔌 Client: Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil"), Process: \(ProcessInfo.processInfo.processName)")
        
        guard self.isEnabled else {
            self.logger.info("🔌 Client: Visual feedback is disabled, skipping connection")
            return
        }
        
        // BEST PRACTICE: Check if already connected to avoid duplicate connections
        if self.isConnected && self.connection != nil {
            self.logger.info("🔌 Client: Already connected, skipping")
            return
        }
        
        // Check if Peekaboo.app is running
        guard self.isPeekabooAppRunning() else {
            self.logger.info("🔌 Client: Peekaboo.app is not running, visual feedback unavailable")
            return
        }
        
        self.logger.info("🔌 Client: Peekaboo.app is running, establishing XPC connection to '\(VisualizerXPCServiceName)'")
        
        // BEST PRACTICE: Invalidate old connection before creating new one
        if let oldConnection = self.connection {
            oldConnection.invalidate()
            self.connection = nil
            self.remoteProxy = nil
        }
        
        // Create XPC connection
        let newConnection = NSXPCConnection(machServiceName: VisualizerXPCServiceName)
        
        // BEST PRACTICE: Configure interface before setting handlers
        newConnection.remoteObjectInterface = NSXPCInterface(with: VisualizerXPCProtocol.self)
        
        // BEST PRACTICE: Use weak self in handlers to avoid retain cycles
        newConnection.interruptionHandler = { [weak self] in
            self?.connectionQueue.async {
                self?.logger.error("🔌 Client: XPC connection interrupted!")
                self?.handleConnectionInterruption()
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
            self?.connectionQueue.async {
                self?.logger.error("🔌 Client: XPC connection invalidated!")
                self?.handleConnectionInvalidation()
            }
        }
        
        // Store connection before resuming
        self.connection = newConnection
        
        // BEST PRACTICE: Resume connection after all configuration
        self.logger.info("🔌 Client: Resuming XPC connection...")
        newConnection.resume()
        
        // Get remote proxy with synchronous error handling
        self.logger.info("🔌 Client: Getting remote proxy...")
        
        // BEST PRACTICE: Use synchronous proxy for initial setup
        let proxy = newConnection.synchronousRemoteObjectProxyWithErrorHandler { error in
            self.logger.error("🔌 Client: Failed to get remote proxy: \(error.localizedDescription), error: \(error)")
            self.isConnected = false
            self.remoteProxy = nil
        } as? VisualizerXPCProtocol
        
        guard let proxy = proxy else {
            self.logger.error("🔌 Client: Failed to create proxy object")
            newConnection.invalidate()
            self.connection = nil
            return
        }
        
        self.remoteProxy = proxy
        
        // Test connection with timeout
        self.logger.info("🔌 Client: Testing connection with isVisualFeedbackEnabled call...")
        
        let semaphore = DispatchSemaphore(value: 0)
        var testSucceeded = false
        
        proxy.isVisualFeedbackEnabled { [weak self] enabled in
            self?.connectionQueue.async {
                self?.isConnected = true
                self?.isEnabled = enabled
                self?.retryAttempt = 0
                testSucceeded = true
                self?.logger.info("🔌 Client: Successfully connected to visualizer service, feedback enabled: \(enabled)")
                
                // Post notification on main queue
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .visualizerConnected, object: nil)
                }
            }
            semaphore.signal()
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
        connectionQueue.sync {
            self.retryTimer?.invalidate()
            self.retryTimer = nil
            
            // BEST PRACTICE: Always invalidate connection properly
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
    
    // MARK: - Visual Feedback Methods (keeping existing implementation)
    
    /// Shows screenshot flash animation
    public func showScreenshotFlash(in rect: CGRect) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showScreenshotFlash(in: rect) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    // ... (rest of the visual feedback methods remain the same)
    
    // MARK: - Private Methods
    
    /// Checks if Peekaboo.app is running
    private func isPeekabooAppRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        return runningApps.contains { app in
            app.bundleIdentifier == "boo.peekaboo.mac" || app.bundleIdentifier == "boo.peekaboo.mac.debug"
        }
    }
    
    /// Handles connection interruption
    private func handleConnectionInterruption() {
        self.logger.warning("XPC connection interrupted")
        self.isConnected = false
        
        // Don't nil out connection here - it may recover
        
        // Schedule retry
        self.scheduleConnectionRetry()
    }
    
    /// Handles connection invalidation
    private func handleConnectionInvalidation() {
        self.logger.warning("XPC connection invalidated")
        self.isConnected = false
        self.connection = nil
        self.remoteProxy = nil
        
        // Schedule retry
        self.scheduleConnectionRetry()
    }
    
    /// Schedules a connection retry
    private func scheduleConnectionRetry() {
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

// MARK: - Supporting Types (reuse existing ones)

extension VisualizationClientImproved {
    public func showClickFeedback(at point: CGPoint, type: ClickType) async -> Bool {
        guard self.isConnected, self.isEnabled else { return false }
        
        return await withCheckedContinuation { continuation in
            self.remoteProxy?.showClickFeedback(at: point, type: type.rawValue) { success in
                continuation.resume(returning: success)
            }
        }
    }
}