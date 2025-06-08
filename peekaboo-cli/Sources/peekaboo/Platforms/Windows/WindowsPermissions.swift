#if os(Windows)
import Foundation
import WinSDK

/// Windows-specific implementation of permissions management
class WindowsPermissions: PermissionsProtocol {
    
    func checkScreenCapturePermission() -> Bool {
        // Windows doesn't require explicit screen recording permission like macOS
        // Screen capture is generally allowed for desktop applications
        return true
    }
    
    func checkWindowAccessPermission() -> Bool {
        // Windows allows window enumeration and basic window information access
        return true
    }
    
    func checkApplicationManagementPermission() -> Bool {
        // Check if we can enumerate processes and get basic process information
        let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        guard snapshot != INVALID_HANDLE_VALUE else {
            return false
        }
        defer { CloseHandle(snapshot) }
        
        var processEntry = PROCESSENTRY32W()
        processEntry.dwSize = DWORD(MemoryLayout<PROCESSENTRY32W>.size)
        
        return Process32FirstW(snapshot, &processEntry) != 0
    }
    
    func requestScreenCapturePermission() async -> Bool {
        // No explicit permission request needed on Windows
        return checkScreenCapturePermission()
    }
    
    func requestWindowAccessPermission() async -> Bool {
        // No explicit permission request needed on Windows
        return checkWindowAccessPermission()
    }
    
    func requestApplicationManagementPermission() async -> Bool {
        // No explicit permission request needed on Windows
        return checkApplicationManagementPermission()
    }
    
    func getAllPermissionStatuses() -> [PermissionType: PermissionStatus] {
        return [
            .screenCapture: .notRequired,
            .windowAccess: .notRequired,
            .applicationManagement: checkApplicationManagementPermission() ? .granted : .denied,
            .accessibility: .notRequired,
            .systemEvents: .notRequired
        ]
    }
    
    func requiresExplicitPermissions() -> Bool {
        return false
    }
    
    func getPermissionInstructions() -> [PermissionInstruction] {
        var instructions: [PermissionInstruction] = []
        
        // Check if running with elevated privileges might be beneficial
        if !isRunningAsAdministrator() {
            instructions.append(PermissionInstruction(
                step: 1,
                title: "Run as Administrator (Optional)",
                description: "For enhanced functionality, you may run this application as Administrator. Right-click the application and select 'Run as administrator'.",
                isAutomated: false,
                platformSpecific: true
            ))
        }
        
        // Check Windows Defender or antivirus interference
        instructions.append(PermissionInstruction(
            step: 2,
            title: "Antivirus Exclusion (If Needed)",
            description: "If screen capture fails, add this application to your antivirus exclusion list.",
            isAutomated: false,
            platformSpecific: true
        ))
        
        return instructions
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
            throw PermissionError.applicationManagementPermissionDenied
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func isRunningAsAdministrator() -> Bool {
        var isAdmin = false
        
        // Get current process token
        var token: HANDLE? = nil
        guard OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token) != 0,
              let processToken = token else {
            return false
        }
        defer { CloseHandle(processToken) }
        
        // Check if token has administrator privileges
        var elevation = TOKEN_ELEVATION()
        var returnLength: DWORD = 0
        
        if GetTokenInformation(
            processToken,
            TokenElevation,
            &elevation,
            DWORD(MemoryLayout<TOKEN_ELEVATION>.size),
            &returnLength
        ) != 0 {
            isAdmin = elevation.TokenIsElevated != 0
        }
        
        return isAdmin
    }
    
    private func checkUACLevel() -> UACLevel {
        // Check UAC level from registry
        // This is a simplified check - full implementation would read from registry
        if isRunningAsAdministrator() {
            return .disabled
        }
        
        return .enabled
    }
    
    private func isWindowsDefenderActive() -> Bool {
        // Check if Windows Defender is active
        // This would require WMI queries or registry checks
        // Simplified implementation for now
        return true
    }
}

// MARK: - Supporting Types

private enum UACLevel {
    case disabled
    case enabled
    case alwaysNotify
}

// MARK: - Windows API Extensions

private extension WindowsPermissions {
    /// Check if the current process has a specific privilege
    func hasPrivilege(_ privilegeName: String) -> Bool {
        var token: HANDLE? = nil
        guard OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token) != 0,
              let processToken = token else {
            return false
        }
        defer { CloseHandle(processToken) }
        
        var luid = LUID()
        guard LookupPrivilegeValueW(nil, privilegeName.withCString(encodedAs: UTF16.self) { $0 }, &luid) != 0 else {
            return false
        }
        
        var privileges = PRIVILEGE_SET()
        privileges.PrivilegeCount = 1
        privileges.Control = 0
        privileges.Privilege.0.Luid = luid
        privileges.Privilege.0.Attributes = SE_PRIVILEGE_ENABLED
        
        var result: BOOL = FALSE
        return PrivilegeCheck(processToken, &privileges, &result) != 0 && result != 0
    }
    
    /// Check if the current user is in the Administrators group
    func isUserInAdministratorsGroup() -> Bool {
        var adminSID: PSID? = nil
        var sidAuthority = SID_IDENTIFIER_AUTHORITY(Value: (0, 0, 0, 0, 0, 5)) // SECURITY_NT_AUTHORITY
        
        guard AllocateAndInitializeSid(
            &sidAuthority,
            2,
            SECURITY_BUILTIN_DOMAIN_RID,
            DOMAIN_ALIAS_RID_ADMINS,
            0, 0, 0, 0, 0, 0,
            &adminSID
        ) != 0 else {
            return false
        }
        defer { FreeSid(adminSID) }
        
        var isMember: BOOL = FALSE
        guard CheckTokenMembership(nil, adminSID, &isMember) != 0 else {
            return false
        }
        
        return isMember != 0
    }
}
#endif

