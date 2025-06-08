import Foundation

#if os(macOS)
import AppKit
#endif

// Legacy compatibility wrapper - use PlatformFactory.createApplicationFinder() for new code
struct AppMatch: Sendable {
    #if os(macOS)
    let app: NSRunningApplication
    #endif
    let score: Double
    let matchType: String
}

// Legacy ApplicationFinder class for backward compatibility
// New code should use PlatformFactory.createApplicationFinder()
final class ApplicationFinder: Sendable {
    #if os(macOS)
    static func findApplication(identifier: String) throws(ApplicationError) -> NSRunningApplication {
        // In CI environment, throw not found to avoid accessing NSWorkspace
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw ApplicationError.notFound(identifier)
        }

        let runningApps = NSWorkspace.shared.runningApplications

        // Check for exact bundle ID match first
        if let exactMatch = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            return exactMatch
        }

        // Find all possible matches
        let allMatches = findAllMatches(for: identifier, in: runningApps)

        // Filter out browser helpers for common browser searches
        let filteredMatches = filterBrowserHelpers(allMatches, searchTerm: identifier)

        if filteredMatches.isEmpty {
            throw ApplicationError.notFound(identifier)
        } else if filteredMatches.count == 1 {
            return filteredMatches[0].app
        } else {
            // Multiple matches found
            let apps = filteredMatches.map { $0.app }
            throw ApplicationError.ambiguous(identifier, apps)
        }
    }

    static func getAllRunningApplications() -> [ApplicationInfo] {
        // In CI environment, return empty array
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return []
        }

        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  let appName = app.localizedName else {
                return nil
            }

            return ApplicationInfo(
                app_name: appName,
                bundle_id: bundleId,
                pid: app.processIdentifier,
                is_active: app.isActive,
                window_count: 0 // Would need separate call to get window count
            )
        }
    }

    private static func findAllMatches(for identifier: String, in apps: [NSRunningApplication]) -> [AppMatch] {
        var matches: [AppMatch] = []
        let lowercaseIdentifier = identifier.lowercased()

        for app in apps {
            guard let appName = app.localizedName else { continue }
            let lowercaseAppName = appName.lowercased()

            // Exact name match (highest priority)
            if lowercaseAppName == lowercaseIdentifier {
                matches.append(AppMatch(app: app, score: 100.0, matchType: "exact_name"))
                continue
            }

            // Bundle ID contains identifier
            if let bundleId = app.bundleIdentifier,
               bundleId.lowercased().contains(lowercaseIdentifier) {
                matches.append(AppMatch(app: app, score: 90.0, matchType: "bundle_id"))
                continue
            }

            // App name contains identifier
            if lowercaseAppName.contains(lowercaseIdentifier) {
                matches.append(AppMatch(app: app, score: 80.0, matchType: "name_contains"))
                continue
            }

            // App name starts with identifier
            if lowercaseAppName.hasPrefix(lowercaseIdentifier) {
                matches.append(AppMatch(app: app, score: 85.0, matchType: "name_prefix"))
                continue
            }
        }

        return matches.sorted { $0.score > $1.score }
    }

    private static func filterBrowserHelpers(_ matches: [AppMatch], searchTerm: String) -> [AppMatch] {
        let browserHelperPatterns = [
            "helper", "renderer", "gpu", "utility", "crashpad"
        ]

        // If searching for a browser specifically, don't filter helpers
        let browserNames = ["safari", "chrome", "firefox", "edge", "brave", "opera"]
        let isSearchingForBrowser = browserNames.contains { searchTerm.lowercased().contains($0) }

        if isSearchingForBrowser {
            return matches
        }

        // Filter out browser helpers
        return matches.filter { match in
            guard let appName = match.app.localizedName else { return true }
            let lowercaseAppName = appName.lowercased()

            return !browserHelperPatterns.contains { pattern in
                lowercaseAppName.contains(pattern)
            }
        }
    }
    #else
    // Non-macOS platforms - use platform factory
    static func findApplication(identifier: String) async throws -> ApplicationInfo {
        let finder = PlatformFactory.createApplicationFinder()
        let apps = try await finder.findApplications(matching: identifier)
        guard let app = apps.first else {
            throw ApplicationError.notFound(identifier)
        }
        return app
    }

    static func getAllRunningApplications() async -> [ApplicationInfo] {
        let finder = PlatformFactory.createApplicationFinder()
        do {
            return try await finder.getRunningApplications()
        } catch {
            return []
        }
    }
    #endif
}

// Application-related errors
enum ApplicationError: Error, LocalizedError, Sendable {
    case notFound(String)
    #if os(macOS)
    case ambiguous(String, [NSRunningApplication])
    #else
    case ambiguous(String, [ApplicationInfo])
    #endif

    var errorDescription: String? {
        switch self {
        case let .notFound(identifier):
            return "Application '\(identifier)' not found or is not running."
        case let .ambiguous(identifier, matches):
            let appNames = matches.map { 
                #if os(macOS)
                $0.localizedName ?? "Unknown"
                #else
                $0.name
                #endif
            }.joined(separator: ", ")
            return "Multiple applications match '\(identifier)': \(appNames)"
        }
    }
}
