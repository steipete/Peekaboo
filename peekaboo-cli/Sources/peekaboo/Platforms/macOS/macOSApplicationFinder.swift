#if os(macOS)
import Foundation
import AppKit

/// macOS-specific implementation of application discovery and management
class macOSApplicationFinder: ApplicationFinderProtocol {
    
    func findApplication(identifier: String) throws -> RunningApplication {
        let runningApps = getRunningApplications(includeBackground: true)
        
        // Try to find by PID first
        if let pid = pid_t(identifier) {
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                return app
            }
        }
        
        // Try exact matches first
        var matches = runningApps.filter { app in
            return app.bundleIdentifier == identifier ||
                   app.localizedName == identifier ||
                   app.executablePath?.lastPathComponent == identifier
        }
        
        // If no exact matches, try fuzzy matching
        if matches.isEmpty {
            matches = runningApps.filter { app in
                return app.bundleIdentifier?.localizedCaseInsensitiveContains(identifier) == true ||
                       app.localizedName?.localizedCaseInsensitiveContains(identifier) == true ||
                       app.executablePath?.lastPathComponent.localizedCaseInsensitiveContains(identifier) == true
            }
        }
        
        if matches.isEmpty {
            throw PlatformApplicationError.notFound(identifier)
        } else if matches.count > 1 {
            throw PlatformApplicationError.ambiguous(identifier, matches)
        }
        
        return matches[0]
    }
    
    func getRunningApplications(includeBackground: Bool = false) -> [RunningApplication] {
        let nsApps = NSWorkspace.shared.runningApplications
        
        return nsApps.compactMap { nsApp in
            // Filter based on activation policy if needed
            if !includeBackground && nsApp.activationPolicy != .regular {
                return nil
            }
            
            return RunningApplication(
                processIdentifier: nsApp.processIdentifier,
                bundleIdentifier: nsApp.bundleIdentifier,
                localizedName: nsApp.localizedName,
                executablePath: nsApp.executableURL?.path,
                isActive: nsApp.isActive,
                activationPolicy: mapActivationPolicy(nsApp.activationPolicy),
                launchDate: nsApp.launchDate,
                icon: nsApp.icon?.tiffRepresentation
            )
        }
    }
    
    func activateApplication(pid: pid_t) throws {
        guard let nsApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) else {
            throw PlatformApplicationError.notFound("PID \(pid)")
        }
        
        let success = nsApp.activate()
        if !success {
            throw PlatformApplicationError.activationFailed(pid)
        }
    }
    
    func isApplicationRunning(identifier: String) -> Bool {
        do {
            _ = try findApplication(identifier: identifier)
            return true
        } catch {
            return false
        }
    }
    
    func getApplicationInfo(pid: pid_t) throws -> ApplicationInfo {
        guard let nsApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) else {
            throw PlatformApplicationError.notFound("PID \(pid)")
        }
        
        // Get additional info
        let bundlePath = nsApp.bundleURL?.path
        let version = nsApp.bundleURL.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }
        
        // Get memory usage (basic implementation)
        let memoryUsage = getMemoryUsage(for: pid)
        
        // Get window count (would need window manager)
        let windowCount: Int? = nil // TODO: Integrate with window manager
        
        return ApplicationInfo(
            processIdentifier: pid,
            bundleIdentifier: nsApp.bundleIdentifier,
            localizedName: nsApp.localizedName,
            executablePath: nsApp.executableURL?.path,
            bundlePath: bundlePath,
            version: version,
            isActive: nsApp.isActive,
            activationPolicy: mapActivationPolicy(nsApp.activationPolicy),
            launchDate: nsApp.launchDate,
            memoryUsage: memoryUsage,
            cpuUsage: nil, // TODO: Implement CPU usage
            windowCount: windowCount,
            icon: nsApp.icon?.tiffRepresentation,
            architecture: getProcessArchitecture(pid: pid)
        )
    }
    
    func isApplicationManagementSupported() -> Bool {
        return true
    }
    
    func refreshApplicationCache() throws {
        // NSWorkspace automatically manages the application list
        // No explicit refresh needed
    }
    
    // MARK: - Private Helper Methods
    
    private func mapActivationPolicy(_ policy: NSApplication.ActivationPolicy) -> ApplicationActivationPolicy {
        switch policy {
        case .regular:
            return .regular
        case .accessory:
            return .accessory
        case .prohibited:
            return .prohibited
        @unknown default:
            return .unknown
        }
    }
    
    private func getMemoryUsage(for pid: pid_t) -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        
        return nil
    }
    
    private func getProcessArchitecture(pid: pid_t) -> ProcessArchitecture {
        var size = 0
        let result = sysctlbyname("sysctl.proc_cputype", nil, &size, nil, 0)
        
        if result == 0 && size > 0 {
            var cpuType: cpu_type_t = 0
            let finalResult = sysctlbyname("sysctl.proc_cputype", &cpuType, &size, nil, 0)
            
            if finalResult == 0 {
                switch cpuType {
                case CPU_TYPE_X86_64:
                    return .x86_64
                case CPU_TYPE_ARM64:
                    return .arm64
                case CPU_TYPE_X86:
                    return .x86
                default:
                    return .unknown
                }
            }
        }
        
        return .unknown
    }
}

// MARK: - String Extensions for Fuzzy Matching

private extension String {
    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }
}
#endif
