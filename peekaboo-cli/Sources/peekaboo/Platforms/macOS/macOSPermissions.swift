#if os(macOS)
import Foundation
import CoreGraphics
import ScreenCaptureKit

/// macOS implementation of permissions checking
struct macOSPermissions: PermissionsProtocol {
    
    func hasScreenRecordingPermission() async -> Bool {
        // Test by attempting to capture a small area of the screen
        let testImage = CGDisplayCreateImage(CGMainDisplayID())
        return testImage != nil
    }
    
    func requestScreenRecordingPermission() async -> Bool {
        // On macOS, we can't programmatically request permission
        // The system will show a dialog when we first attempt screen capture
        return await hasScreenRecordingPermission()
    }
    
    func hasAccessibilityPermission() async -> Bool {
        // Check if we can access window information
        let options = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([options: false] as CFDictionary)
        return trusted
    }
    
    func requestAccessibilityPermission() async -> Bool {
        // This will prompt the user to grant accessibility permission
        let options = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([options: true] as CFDictionary)
        return trusted
    }
    
    func getPermissionInstructions() -> String {
        return \"\"\"
        To use Peekaboo on macOS, you need to grant the following permissions:
        
        1. Screen Recording Permission:
           - Go to System Preferences > Security & Privacy > Privacy > Screen Recording
           - Add and enable Peekaboo (or Terminal if running from command line)
        
        2. Accessibility Permission (for window management):
           - Go to System Preferences > Security & Privacy > Privacy > Accessibility
           - Add and enable Peekaboo (or Terminal if running from command line)
        
        After granting permissions, restart the application.
        \"\"\"
    }
    
    static func isSupported() -> Bool {
        return true // macOS always supports permission checking
    }
}

// MARK: - Accessibility Framework Declarations

// Declare the Accessibility framework functions we need
@_silgen_name("AXIsProcessTrustedWithOptions")
func AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool

let kAXTrustedCheckOptionPrompt = "AXTrustedCheckOptionPrompt" as CFString

#endif

