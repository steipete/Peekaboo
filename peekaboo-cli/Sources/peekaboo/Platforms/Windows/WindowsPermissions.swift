#if os(Windows)
import Foundation
import WinSDK

/// Windows implementation of permissions checking
struct WindowsPermissions: PermissionsProtocol {
    
    func hasScreenRecordingPermission() async -> Bool {
        // On Windows, screen recording is generally available without special permissions
        // However, we should check if we can actually capture the screen
        let screenDC = GetDC(nil)
        guard screenDC != nil else { return false }
        
        ReleaseDC(nil, screenDC)
        return true
    }
    
    func requestScreenRecordingPermission() async -> Bool {
        // Windows doesn't require explicit permission for screen recording
        return await hasScreenRecordingPermission()
    }
    
    func hasAccessibilityPermission() async -> Bool {
        // On Windows, window enumeration is generally available
        // Test by trying to enumerate windows
        var hasPermission = false
        
        let enumProc: WNDENUMPROC = { hwnd, lParam in
            let hasPermissionPtr = UnsafeMutablePointer<Bool>(bitPattern: UInt(lParam))!
            hasPermissionPtr.pointee = true
            return FALSE // Stop enumeration after first window
        }
        
        withUnsafeMutablePointer(to: &hasPermission) { hasPermissionPtr in
            EnumWindows(enumProc, LPARAM(UInt(bitPattern: hasPermissionPtr)))
        }
        
        return hasPermission
    }
    
    func requestAccessibilityPermission() async -> Bool {
        // Windows doesn't require explicit permission for window enumeration
        return await hasAccessibilityPermission()
    }
    
    func getPermissionInstructions() -> String {
        return \"\"\"
        Peekaboo on Windows generally works without special permissions.
        
        However, if you encounter issues:
        
        1. Make sure you're running as an Administrator if capturing elevated applications
        2. Some antivirus software may block screen capture - check your security settings
        3. Windows Defender SmartScreen might require approval for the first run
        
        If you're still having issues, try running from an elevated command prompt.
        \"\"\"
    }
    
    static func isSupported() -> Bool {
        return true // Windows always supports permission checking
    }
}

#endif

