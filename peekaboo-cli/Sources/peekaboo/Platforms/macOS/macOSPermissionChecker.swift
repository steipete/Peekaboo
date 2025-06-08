import Foundation
import AppKit
import ScreenCaptureKit

#if os(macOS)

/// macOS-specific implementation of permission checking
class macOSPermissionChecker: PermissionCheckerProtocol {
    
    func hasScreenCapturePermission() -> Bool {
        if #available(macOS 14.0, *) {
            // Use ScreenCaptureKit for modern permission checking
            return SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) != nil
        } else {
            // Fallback to CGDisplayStream availability check
            return CGDisplayStream.canConstructDisplayStream()
        }
    }
    
    func canRequestPermission() -> Bool {
        // On macOS, we can always attempt to request permission
        return true
    }
    
    func requestScreenCapturePermission() throws {
        if hasScreenCapturePermission() {
            return // Already have permission
        }
        
        if #available(macOS 14.0, *) {
            // Request permission through ScreenCaptureKit
            let semaphore = DispatchSemaphore(value: 0)
            var permissionError: Error?
            
            Task {
                do {
                    _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                } catch {
                    permissionError = error
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if let error = permissionError {
                throw ScreenCaptureError.permissionDenied
            }
        } else {
            // For older macOS versions, we can't programmatically request permission
            // The user needs to manually grant it in System Preferences
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    func requireScreenCapturePermission() throws {
        guard hasScreenCapturePermission() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func canRequestAccessibilityPermission() -> Bool {
        return true
    }
    
    func requestAccessibilityPermission() throws {
        if hasAccessibilityPermission() {
            return // Already have permission
        }
        
        // Request accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    func requireAccessibilityPermission() throws {
        guard hasAccessibilityPermission() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
}

// MARK: - Helper Extensions
@available(macOS 14.0, *)
extension CGDisplayStream {
    static func canConstructDisplayStream() -> Bool {
        // Try to create a display stream to test permissions
        let mainDisplayID = CGMainDisplayID()
        let stream = CGDisplayStream(
            dispatchQueueDisplay: mainDisplayID,
            outputWidth: 1,
            outputHeight: 1,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: nil,
            queue: DispatchQueue.global(),
            handler: { _, _, _, _ in }
        )
        return stream != nil
    }
}

#endif

