// ElementFactories.swift - Factory functions for creating Element instances

import ApplicationServices // For AXUIElement and other C APIs
import Foundation

// Convenience factory for the application element - already @MainActor
@MainActor
public func applicationElement(for bundleIdOrName: String, isDebugLoggingEnabled: Bool,
                               currentDebugLogs: inout [String]) -> Element? {
    func dLog(_ message: String) {
        if isDebugLoggingEnabled {
            currentDebugLogs.append(message)
        }
    }
    // Now call pid() with logging parameters
    guard let pid = pid(
        forAppIdentifier: bundleIdOrName,
        isDebugLoggingEnabled: isDebugLoggingEnabled,
        currentDebugLogs: &currentDebugLogs
    ) else {
        // dLog for "Failed to find PID..." is now handled inside pid() itself or if it returns nil here, we can log the higher level failure.
        // The message below is slightly redundant if pid() logs its own failure, but can be useful.
        dLog("applicationElement: Failed to obtain PID for '\(bundleIdOrName)'. Check previous logs from pid().")
        return nil
    }
    let appElement = AXUIElementCreateApplication(pid)
    return Element(appElement)
}

// Convenience factory for the system-wide element - already @MainActor
@MainActor
public func systemWideElement(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Element {
    // This function doesn't do much logging itself, but consistent signature is good.
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    dLog("Creating system-wide element.")
    return Element(AXUIElementCreateSystemWide())
}
