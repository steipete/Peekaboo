#if os(macOS)
import Foundation
import AppKit

/// macOS implementation of application finding using NSWorkspace
struct macOSApplicationFinder: ApplicationFinderProtocol {
    
    func findApplications(matching query: String) async throws -> [ApplicationInfo] {
        let runningApps = try await getRunningApplications()
        let lowercaseQuery = query.lowercased()
        
        return runningApps.filter { app in
            app.name.lowercased().contains(lowercaseQuery) ||
            app.bundleIdentifier?.lowercased().contains(lowercaseQuery) == true ||
            app.id.contains(query)
        }
    }
    
    func getRunningApplications() async throws -> [ApplicationInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        
        return runningApps.compactMap { app in
            guard let bundleIdentifier = app.bundleIdentifier,
                  let localizedName = app.localizedName else {
                return nil
            }
            
            return ApplicationInfo(
                id: String(app.processIdentifier),
                name: localizedName,
                bundleIdentifier: bundleIdentifier,
                executablePath: app.executableURL?.path,
                isRunning: true,
                processId: Int(app.processIdentifier)
            )
        }
    }
    
    func getApplication(by identifier: String) async throws -> ApplicationInfo? {
        let runningApps = try await getRunningApplications()
        
        // Try to find by process ID first
        if let pid = Int(identifier) {
            if let app = runningApps.first(where: { $0.processId == pid }) {
                return app
            }
        }
        
        // Try to find by bundle identifier
        return runningApps.first { app in
            app.bundleIdentifier == identifier ||
            app.name.lowercased() == identifier.lowercased()
        }
    }
    
    static func isSupported() -> Bool {
        return true // macOS always supports application finding
    }
}

#endif

