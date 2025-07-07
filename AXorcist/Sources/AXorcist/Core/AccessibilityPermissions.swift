// AccessibilityPermissions.swift - Utility for checking and managing accessibility permissions.

import AppKit // For NSRunningApplication, NSAppleScript
import ApplicationServices // For AXIsProcessTrusted(), AXUIElementCreateSystemWide(), etc.
import Foundation

private let kAXTrustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"

// debug() is assumed to be globally available from Logging.swift
// getParentProcessName() is assumed to be globally available from ProcessUtils.swift
// kAXFocusedUIElementAttribute is assumed to be globally available from AccessibilityConstants.swift
// AccessibilityError is from AccessibilityError.swift

public struct AXPermissionsStatus {
    public let isAccessibilityApiEnabled: Bool
    public let isProcessTrustedForAccessibility: Bool
    public var automationStatus: [String: Bool] =
        [:] // BundleID: Bool (true if permitted, false if denied, nil if not checked or app not running)
    public var overallErrorMessages: [String] = []

    public var canUseAccessibility: Bool {
        isAccessibilityApiEnabled && isProcessTrustedForAccessibility
    }

    public func canAutomate(bundleID: String) -> Bool? {
        return automationStatus[bundleID]
    }
}

@MainActor
public func checkAccessibilityPermissions(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) throws {
    // Define local dLog using passed-in parameters
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

    let trustedOptions = [kAXTrustedCheckOptionPromptKey: true] as CFDictionary
    // tempLogs is already declared for getParentProcessName, which is good.
    // var tempLogs: [String] = [] // This would be a re-declaration error if uncommented

    if !AXIsProcessTrustedWithOptions(trustedOptions) {
        // Use isDebugLoggingEnabled for the call to getParentProcessName
        let parentName = getParentProcessName(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
        let errorDetail = parentName != nil ? "Hint: Grant accessibility permissions to '\(parentName!)'." :
            "Hint: Ensure the application running this tool has Accessibility permissions."
        dLog("Accessibility check failed (AXIsProcessTrustedWithOptions returned false). Details: \(errorDetail)")
        throw AccessibilityError.notAuthorized(errorDetail)
    } else {
        dLog("Accessibility permissions are granted (AXIsProcessTrustedWithOptions returned true).")
    }
}

// @MainActor // Removed again for pragmatic stability
public func getPermissionsStatus(
    checkAutomationFor bundleIDs: [String] = [],
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> AXPermissionsStatus {
    // Local dLog appends to currentDebugLogs
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

    dLog("Starting full permission status check.")

    // Check overall accessibility API status and process trust
    let isProcessTrusted = AXIsProcessTrusted() // Non-prompting check
    // let isApiEnabled = AXAPIEnabled() // System-wide check, REMOVED due to unavailability

    if isDebugLoggingEnabled {
        dLog("AXIsProcessTrusted() returned: \(isProcessTrusted)")
        // dLog("AXAPIEnabled() returned: \(isApiEnabled) (Note: AXAPIEnabled is deprecated)") // Removed
        if !isProcessTrusted {
            let parentName = getParentProcessName(
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            let hint = parentName != nil ? "Hint: Grant accessibility permissions to '\(parentName!)'." :
                "Hint: Ensure the application running this tool has Accessibility permissions."
            currentDebugLogs.append("Process is not trusted for Accessibility. \(hint)")
        }
        // Removed isApiEnabled check block
    }

    var automationStatus: [String: Bool] = [:]

    if !bundleIDs
        .isEmpty &&
        isProcessTrusted { // Only check automation if basic permissions seem okay (removed isApiEnabled from condition)
        if isDebugLoggingEnabled {
            dLog("Checking automation permissions for bundle IDs: \(bundleIDs.joined(separator: ", "))") }
        for bundleID in bundleIDs {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first != nil { // Changed from if let app = ...
                let scriptSource = """
                tell application id \"\(bundleID)\" to count windows
                """
                var errorDict: NSDictionary?
                if let script = NSAppleScript(source: scriptSource) {
                    if isDebugLoggingEnabled {
                        dLog("Executing AppleScript against \(bundleID) to check automation status.") }
                    let descriptor = script.executeAndReturnError(&errorDict) // descriptor is non-optional

                    if errorDict == nil && descriptor.descriptorType != typeNull {
                        // No error dictionary populated and descriptor is not typeNull, assume success for permissions.
                        automationStatus[bundleID] = true
                        if isDebugLoggingEnabled {
                            dLog(
                                "AppleScript execution against \(bundleID) succeeded " +
                                    "(no errorDict, descriptor type: \(descriptor.descriptorType.description)). " +
                                    "Automation permitted."
                            )
                        }
                    } else {
                        automationStatus[bundleID] = false
                        if isDebugLoggingEnabled {
                            let errorCode = errorDict?[NSAppleScript.errorNumber] as? Int ?? 0
                            let errorMessage = errorDict?[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                            let descriptorDetails = errorDict == nil ?
                                "Descriptor was typeNull (type: \(descriptor.descriptorType.description)) but no errorDict." : ""
                            currentDebugLogs.append(
                                "AppleScript execution against \(bundleID) failed. " +
                                    "Automation likely denied. Code: \(errorCode), Msg: \(errorMessage). \(descriptorDetails)"
                            )
                        }
                    }
                } else {
                    if isDebugLoggingEnabled {
                        currentDebugLogs.append("Could not initialize AppleScript for bundle ID '\(bundleID)'.") }
                }
            } else {
                if isDebugLoggingEnabled {
                    currentDebugLogs
                        .append(
                            "Application with bundle ID '\(bundleID)' is not running. Cannot check automation status."
                        )
                }
                // automationStatus[bundleID] remains nil (not checked)
            }
        }
    } else if !bundleIDs.isEmpty {
        if isDebugLoggingEnabled {
            dLog(
                "Skipping automation permission checks because basic accessibility " +
                    "(isProcessTrusted: \(isProcessTrusted)) is not met."
            )
        }
    }

    let finalStatus = AXPermissionsStatus(
        isAccessibilityApiEnabled: isProcessTrusted, // Base this on isProcessTrusted now
        isProcessTrustedForAccessibility: isProcessTrusted,
        automationStatus: automationStatus,
        overallErrorMessages: currentDebugLogs // All logs collected so far become the messages
    )
    dLog(
        "Finished permission status check. isAccessibilityApiEnabled: \(finalStatus.isAccessibilityApiEnabled), " +
            "isProcessTrusted: \(finalStatus.isProcessTrustedForAccessibility)"
    )
    return finalStatus
}
