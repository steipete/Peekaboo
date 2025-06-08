#if os(macOS)
import Foundation
import AVFoundation
import CoreGraphics
import ScreenCaptureKit

/// macOS-specific implementation of permissions management
class macOSPermissions: PermissionsProtocol {
    
    func checkScreenCapturePermission() -> Bool {
        // ScreenCaptureKit requires screen recording permission
        // We check by attempting to get shareable content
        let semaphore = DispatchSemaphore(value: 0)
        var hasPermission = false
        var capturedError: Error?

        Task {
            do {
                // This will fail if we don't have screen recording permission
                _ = try await SCShareableContent.current
                hasPermission = true
            } catch {
                // If we get an error, we don't have permission
                capturedError = error
                hasPermission = false
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = capturedError {
            Logger.shared.debug("Screen recording permission check failed: \(error)")
        }

        return hasPermission
    }
    
    func checkWindowAccessPermission() -> Bool {
        // On macOS, window access is part of screen recording permission
        return checkScreenCapturePermission()
    }
    
    func checkApplicationManagementPermission() -> Bool {
        // Check if we have accessibility permission for app activation
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func requestScreenCapturePermission() async -> Bool {
        // On macOS, we can't programmatically request screen recording permission
        // The system will show a dialog when we first try to use ScreenCaptureKit
        return checkScreenCapturePermission()
    }
    
    func requestWindowAccessPermission() async -> Bool {
        // Same as screen capture on macOS
        return await requestScreenCapturePermission()
    }
    
    func requestApplicationManagementPermission() async -> Bool {
        // Request accessibility permission with prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func getAllPermissionStatuses() -> [PermissionType: PermissionStatus] {
        return [
            .screenCapture: checkScreenCapturePermission() ? .granted : .denied,
            .windowAccess: checkWindowAccessPermission() ? .granted : .denied,
            .applicationManagement: checkApplicationManagementPermission() ? .granted : .denied,
            .accessibility: checkApplicationManagementPermission() ? .granted : .denied,
            .systemEvents: .notRequired
        ]
    }
    
    func requiresExplicitPermissions() -> Bool {
        return true
    }
    
    func getPermissionInstructions() -> [PermissionInstruction] {
        return [
            PermissionInstruction(
                step: 1,
                title: "Enable Screen Recording",
                description: "Go to System Preferences > Security & Privacy > Privacy > Screen Recording and enable access for this application.",
                isAutomated: false,
                platformSpecific: true
            ),
            PermissionInstruction(
                step: 2,
                title: "Enable Accessibility (Optional)",
                description: "For application activation features, go to System Preferences > Security & Privacy > Privacy > Accessibility and enable access for this application.",
                isAutomated: true,
                platformSpecific: true
            )
        ]
    }
    
    func requireScreenCapturePermission() throws {
        if !checkScreenCapturePermission() {
            throw PermissionError.screenRecordingPermissionDenied
        }
    }
    
    func requireWindowAccessPermission() throws {
        if !checkWindowAccessPermission() {
            throw PermissionError.windowAccessPermissionDenied
        }
    }
    
    func requireApplicationManagementPermission() throws {
        if !checkApplicationManagementPermission() {
            throw PermissionError.accessibilityPermissionDenied
        }
    }
}
#endif

