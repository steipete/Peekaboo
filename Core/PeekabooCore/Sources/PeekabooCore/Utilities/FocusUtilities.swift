import AppKit
import ArgumentParser
import AXorcist
import Foundation

// MARK: - Focus Options Protocol

public protocol FocusOptionsProtocol {
    var autoFocus: Bool { get }
    var focusTimeout: TimeInterval? { get }
    var focusRetryCount: Int? { get }
    var spaceSwitch: Bool { get }
    var bringToCurrentSpace: Bool { get }
}

// MARK: - Default Focus Options

public struct DefaultFocusOptions: FocusOptionsProtocol {
    public let autoFocus: Bool = true
    public let focusTimeout: TimeInterval? = 5.0
    public let focusRetryCount: Int? = 3
    public let spaceSwitch: Bool = true
    public let bringToCurrentSpace: Bool = false
    
    public init() {}
}

// MARK: - Focus Options for ArgumentParser

public struct FocusOptions: ParsableArguments, FocusOptionsProtocol {
    public init() {}
    @Flag(name: .long, help: "Disable automatic focus before interaction (not recommended)")
    public var noAutoFocus = false
    
    @Option(name: .long, help: "Timeout for focus operations in seconds")
    public var focusTimeout: TimeInterval?
    
    @Option(name: .long, help: "Number of retries for focus operations")
    public var focusRetryCount: Int?
    
    @Flag(name: .long, help: "Switch to window's Space if on different Space")
    public var spaceSwitch = false
    
    @Flag(name: .long, help: "Bring window to current Space instead of switching")
    public var bringToCurrentSpace = false
    
    public var autoFocus: Bool { !noAutoFocus }
}

// MARK: - Focus Command Extension

public extension AsyncParsableCommand {
    /// Ensure the target window is focused before executing a command
    func ensureFocused(
        sessionId: String? = nil,
        windowID: CGWindowID? = nil,
        applicationName: String? = nil,
        windowTitle: String? = nil,
        options: FocusOptionsProtocol = DefaultFocusOptions()
    ) async throws {
        // Skip if auto-focus is disabled
        guard options.autoFocus else {
            // Auto-focus disabled, skipping focus check
            return
        }
        
        // Determine target window
        let targetWindow: CGWindowID?
        
        if let windowID = windowID {
            // Explicit window ID provided
            targetWindow = windowID
        } else if let sessionId = sessionId {
            // Try to get window ID from session
            let session = try await PeekabooServices.shared.sessions.getUIAutomationSession(sessionId: sessionId)
            targetWindow = session?.windowID
        } else if let appName = applicationName {
            // Find window by app name and optional title
            targetWindow = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    do {
                        let focusService = FocusManagementService()
                        let windowID = try await focusService.findBestWindow(
                            applicationName: appName,
                            windowTitle: windowTitle
                        )
                        continuation.resume(returning: windowID)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } else {
            // No target specified, skip focusing
            // No focus target specified
            return
        }
        
        // Focus the window if we found one
        if let windowID = targetWindow {
            // Capture values before Task to avoid data races
            let timeout = options.focusTimeout ?? 5.0
            let retryCount = options.focusRetryCount ?? 3
            let switchSpace = options.spaceSwitch
            let bringToCurrentSpace = options.bringToCurrentSpace
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Task { @MainActor in
                    do {
                        let focusService = FocusManagementService()
                        let focusOptions = FocusManagementService.FocusOptions(
                            timeout: timeout,
                            retryCount: retryCount,
                            switchSpace: switchSpace,
                            bringToCurrentSpace: bringToCurrentSpace
                        )
                        try await focusService.focusWindow(windowID: windowID, options: focusOptions)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - Focus Management Service

@MainActor
public final class FocusManagementService {
    private let windowIdentityService = WindowIdentityService()
    // Temporarily disabled - CGS APIs causing crashes
    // private let spaceService = SpaceManagementService()
    
    public init() {}
    
    public struct FocusOptions {
        public let timeout: TimeInterval
        public let retryCount: Int
        public let switchSpace: Bool
        public let bringToCurrentSpace: Bool
        
        public init(
            timeout: TimeInterval = 5.0,
            retryCount: Int = 3,
            switchSpace: Bool = true,
            bringToCurrentSpace: Bool = false
        ) {
            self.timeout = timeout
            self.retryCount = retryCount
            self.switchSpace = switchSpace
            self.bringToCurrentSpace = bringToCurrentSpace
        }
    }
    
    // MARK: - Window Finding
    
    /// Find the best window match for the given criteria
    public func findBestWindow(
        applicationName: String,
        windowTitle: String? = nil
    ) async throws -> CGWindowID? {
        // Find the application
        let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: applicationName)
        
        guard let app = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
            throw FocusError.applicationNotRunning(applicationName)
        }
        
        // Get all windows for the app
        let windows = windowIdentityService.getWindows(for: app)
        
        guard !windows.isEmpty else {
            throw FocusError.noWindowsFound(applicationName)
        }
        
        // If window title specified, try to find a match
        if let title = windowTitle {
            if let matchingWindow = windows.first(where: { 
                $0.title?.localizedCaseInsensitiveContains(title) == true 
            }) {
                return matchingWindow.windowID
            }
            // If no match found, fall through to get frontmost
        }
        
        // Return the frontmost window (first in list)
        return windows.first?.windowID
    }
    
    // MARK: - Focus Operations
    
    /// Focus a window by its CGWindowID
    public func focusWindow(windowID: CGWindowID, options: FocusOptions = FocusOptions()) async throws {
        // Attempting to focus window
        
        // Verify window exists
        guard windowIdentityService.windowExists(windowID: windowID) else {
            throw FocusError.windowNotFound(windowID)
        }
        
        // Handle Space switching if needed
        if options.switchSpace || options.bringToCurrentSpace {
            try await handleSpaceFocus(windowID: windowID, bringToCurrentSpace: options.bringToCurrentSpace)
        }
        
        // Find the window's AXUIElement
        guard let (windowElement, app) = windowIdentityService.findWindow(byID: windowID) else {
            throw FocusError.axElementNotFound(windowID)
        }
        
        // Activate the application
        if !app.isActive {
            app.activate(options: [.activateIgnoringOtherApps])
            
            // Wait for activation
            try await waitForCondition(
                timeout: 2.0,
                interval: 0.1,
                condition: { app.isActive }
            )
        }
        
        // Focus the window
        try await focusWindowElement(windowElement, windowID: windowID, options: options)
    }
    
    // MARK: - Private Helpers
    
    private func handleSpaceFocus(windowID: CGWindowID, bringToCurrentSpace: Bool) async throws {
        // Temporarily disabled - CGS APIs causing crashes
        /*
        if bringToCurrentSpace {
            // Move window to current Space
            try spaceService.moveWindowToCurrentSpace(windowID: windowID)
            // Moved window to current Space
        } else {
            // Switch to window's Space
            try await spaceService.switchToWindowSpace(windowID: windowID)
            // Switched to window's Space
        }
        */
        
        // Give macOS time to complete the Space transition
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
    }
    
    private func focusWindowElement(
        _ windowElement: Element,
        windowID: CGWindowID,
        options: FocusOptions
    ) async throws {
        var lastError: Error?
        
        for attempt in 1...options.retryCount {
            // Try to focus the window
            // Try to raise the window
            do {
                try windowElement.performAction(.raise)
            } catch {
                // If raise action fails, try to make it main
                // Note: Setting main window through AX API requires finding parent app
                // This is handled by the activate() call above
            }
            
            // Verify focus
            do {
                try await verifyWindowFocus(windowElement, windowID: windowID, timeout: options.timeout)
                
                // Successfully focused window
                return
            } catch {
                lastError = error
                // Focus attempt failed: \(error.localizedDescription)
                
                if attempt < options.retryCount {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s between retries
                }
            }
        }
        
        throw lastError ?? FocusError.focusVerificationFailed(windowID)
    }
    
    private func verifyWindowFocus(
        _ windowElement: Element,
        windowID: CGWindowID,
        timeout: TimeInterval
    ) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check if window is main/focused
            // We check the main attribute directly
            if let isMain = windowElement.isMain(), isMain {
                
                // Also verify it's not minimized
                if let isMinimized = windowElement.isMinimized(),
                   !isMinimized {
                    return // Success
                }
            }
            
            // Wait before next check
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        throw FocusError.focusVerificationTimeout(windowID)
    }
    
    private func waitForCondition(
        timeout: TimeInterval,
        interval: TimeInterval,
        condition: () -> Bool
    ) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        
        throw FocusError.timeoutWaitingForCondition
    }
}

// MARK: - Focus Errors

public enum FocusError: LocalizedError {
    case applicationNotRunning(String)
    case noWindowsFound(String)
    case windowNotFound(CGWindowID)
    case axElementNotFound(CGWindowID)
    case focusVerificationFailed(CGWindowID)
    case focusVerificationTimeout(CGWindowID)
    case timeoutWaitingForCondition
    
    public var errorDescription: String? {
        switch self {
        case .applicationNotRunning(let name):
            return "Application '\(name)' is not running"
        case .noWindowsFound(let name):
            return "No windows found for application '\(name)'"
        case .windowNotFound(let id):
            return "Window with ID \(id) not found"
        case .axElementNotFound(let id):
            return "Could not find accessibility element for window ID \(id)"
        case .focusVerificationFailed(let id):
            return "Failed to verify focus for window ID \(id)"
        case .focusVerificationTimeout(let id):
            return "Timeout while verifying focus for window ID \(id)"
        case .timeoutWaitingForCondition:
            return "Timeout while waiting for condition"
        }
    }
}