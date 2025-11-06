import ApplicationServices
import AXorcist
@preconcurrency import Dispatch
import Foundation
import os
import PeekabooFoundation

extension Element {
    /// Set a messaging timeout for this element to prevent hangs
    @MainActor
    // Apply the requested messaging timeout directly to the accessibility element.
    func setMessagingTimeout(_ timeout: Float) {
        let error = AXUIElementSetMessagingTimeout(self.underlyingElement, timeout)
        if error != .success {
            let logger = Logger(subsystem: "boo.peekaboo.core", category: "Element+Timeout")
            logger.warning("Failed to set messaging timeout: \(error.rawValue)")
        }
    }

    /// Get windows with timeout protection
    @MainActor
    // Retrieve child windows while temporarily tightening the messaging timeout.
    func windowsWithTimeout(timeout: Float = 2.0) -> [Element]? {
        // Set a shorter timeout to prevent hanging
        self.setMessagingTimeout(timeout)

        // Try to get windows
        let windows = self.windows()

        // Reset to use global timeout
        self.setMessagingTimeout(0)

        return windows
    }

    /// Get menu bar with timeout protection
    @MainActor
    // Access the menu bar while applying a shorter timeout window.
    func menuBarWithTimeout(timeout: Float = 2.0) -> Element? {
        // Set a shorter timeout to prevent hanging
        self.setMessagingTimeout(timeout)

        // Try to get menu bar
        let menuBar = self.menuBar()

        // Reset to use global timeout
        self.setMessagingTimeout(0)

        return menuBar
    }
}

/// Global timeout configuration for all AX operations
public enum AXTimeoutConfiguration {
    /// Set the global messaging timeout for all AX operations
    @MainActor
    // Update the system-wide messaging timeout so future AX calls inherit the new limit.
    public static func setGlobalTimeout(_ timeout: Float) {
        let systemWide = AXUIElementCreateSystemWide()
        let error = AXUIElementSetMessagingTimeout(systemWide, timeout)
        if error != .success {
            let logger = Logger(subsystem: "boo.peekaboo.core", category: "AXTimeout")
            logger.warning("Failed to set global AX timeout: \(error.rawValue)")
        } else {
            let logger = Logger(subsystem: "boo.peekaboo.core", category: "AXTimeout")
            logger.info("Set global AX timeout to \(timeout) seconds")
        }
    }
}

/// Wrapper for AX operations with automatic retry on timeout
public struct AXTimeoutWrapper {
    private let maxRetries: Int
    private let retryDelay: TimeInterval

    public init(maxRetries: Int = 3, retryDelay: TimeInterval = 0.5) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }

    /// Execute an AX operation with timeout protection and retry logic
    @MainActor
    // Attempt the operation multiple times before surfacing the final failure.
    public func execute<T>(_ operation: () throws -> T?) async throws -> T? {
        var lastError: Error?

        for attempt in 0..<self.maxRetries {
            do {
                if let result = try operation() {
                    return result
                }
            } catch {
                lastError = error
                let logger = Logger(subsystem: "boo.peekaboo.core", category: "AXTimeout")
                logger.debug("AX operation failed (attempt \(attempt + 1)/\(self.maxRetries)): \(error)")

                // Wait before retry
                if attempt < self.maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(self.retryDelay * 1_000_000_000))
                }
            }
        }

        if let error = lastError {
            throw error
        }
        return nil
    }
}

/// Alternative approach using dispatch queue with timeout
public enum AXDispatchTimeout {
    /// Execute an AX operation on a background queue with timeout
    @MainActor
    public static func executeWithTimeout<T>(
        timeout: TimeInterval,
        operation: @escaping () -> T?) async throws -> T?
    {
        // Dispatch the operation onto a background queue and enforce the timeout with cancellable continuation.
        try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                let result = operation()
                continuation.resume(returning: result)
            }

            // Execute on a concurrent queue
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)

            // Set up timeout
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                workItem.cancel()
                continuation.resume(throwing: PeekabooError.timeout("AX operation timed out after \(timeout) seconds"))
            }
        }
    }
}
