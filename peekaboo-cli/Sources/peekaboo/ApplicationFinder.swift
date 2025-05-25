import AppKit
import Foundation

struct AppMatch {
    let app: NSRunningApplication
    let score: Double
    let matchType: String
}

class ApplicationFinder {
    static func findApplication(identifier: String) throws(ApplicationError) -> NSRunningApplication {
        Logger.shared.debug("Searching for application: \(identifier)")

        let runningApps = NSWorkspace.shared.runningApplications
        var matches: [AppMatch] = []

        // Exact bundle ID match (highest priority)
        if let exactBundleMatch = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            Logger.shared.debug("Found exact bundle ID match: \(exactBundleMatch.localizedName ?? "Unknown")")
            return exactBundleMatch
        }

        // Exact name match (case insensitive)
        for app in runningApps {
            if let appName = app.localizedName, appName.lowercased() == identifier.lowercased() {
                matches.append(AppMatch(app: app, score: 1.0, matchType: "exact_name"))
            }
        }

        // Partial name matches
        for app in runningApps {
            if let appName = app.localizedName {
                let lowerAppName = appName.lowercased()
                let lowerIdentifier = identifier.lowercased()

                // Check if app name starts with identifier
                if lowerAppName.hasPrefix(lowerIdentifier) {
                    let score = Double(lowerIdentifier.count) / Double(lowerAppName.count)
                    matches.append(AppMatch(app: app, score: score, matchType: "prefix"))
                }
                // Check if app name contains identifier
                else if lowerAppName.contains(lowerIdentifier) {
                    let score = Double(lowerIdentifier.count) / Double(lowerAppName.count) * 0.8
                    matches.append(AppMatch(app: app, score: score, matchType: "contains"))
                }
            }

            // Check bundle ID partial matches
            if let bundleId = app.bundleIdentifier {
                let lowerBundleId = bundleId.lowercased()
                let lowerIdentifier = identifier.lowercased()

                if lowerBundleId.contains(lowerIdentifier) {
                    let score = Double(lowerIdentifier.count) / Double(lowerBundleId.count) * 0.6
                    matches.append(AppMatch(app: app, score: score, matchType: "bundle_contains"))
                }
            }
        }

        // Sort by score (highest first)
        matches.sort { $0.score > $1.score }

        // Remove duplicates (same app might match multiple ways)
        var uniqueMatches: [AppMatch] = []
        var seenPIDs: Set<pid_t> = []

        for match in matches {
            if !seenPIDs.contains(match.app.processIdentifier) {
                uniqueMatches.append(match)
                seenPIDs.insert(match.app.processIdentifier)
            }
        }

        if uniqueMatches.isEmpty {
            Logger.shared.error("No applications found matching: \(identifier)")
            outputError(
                message: "No running applications found matching identifier: \(identifier)",
                code: .APP_NOT_FOUND,
                details: "Available applications: " +
                    "\(runningApps.compactMap { $0.localizedName }.joined(separator: ", "))"
            )
            throw ApplicationError.notFound(identifier)
        }

        // Check for ambiguous matches (multiple high-scoring matches)
        let topScore = uniqueMatches[0].score
        let topMatches = uniqueMatches.filter { abs($0.score - topScore) < 0.1 }

        if topMatches.count > 1 {
            let matchDescriptions = topMatches.map { match in
                "\(match.app.localizedName ?? "Unknown") (\(match.app.bundleIdentifier ?? "unknown.bundle"))"
            }

            Logger.shared.error("Ambiguous application identifier: \(identifier)")
            outputError(
                message: "Multiple applications match identifier '\(identifier)'. Please be more specific.",
                code: .AMBIGUOUS_APP_IDENTIFIER,
                details: "Matches found: \(matchDescriptions.joined(separator: ", "))"
            )
            throw ApplicationError.ambiguous(identifier, topMatches.map { $0.app })
        }

        let bestMatch = uniqueMatches[0]
        Logger.shared.debug(
            "Found application: \(bestMatch.app.localizedName ?? "Unknown") " +
            "(score: \(bestMatch.score), type: \(bestMatch.matchType))"
        )

        return bestMatch.app
    }

    static func getAllRunningApplications() -> [ApplicationInfo] {
        Logger.shared.debug("Retrieving all running applications")

        let runningApps = NSWorkspace.shared.runningApplications
        var result: [ApplicationInfo] = []

        for app in runningApps {
            // Skip background-only apps without a name
            guard let appName = app.localizedName, !appName.isEmpty else {
                continue
            }

            // Count windows for this app
            let windowCount = countWindowsForApp(pid: app.processIdentifier)

            let appInfo = ApplicationInfo(
                app_name: appName,
                bundle_id: app.bundleIdentifier ?? "",
                pid: app.processIdentifier,
                is_active: app.isActive,
                window_count: windowCount
            )

            result.append(appInfo)
        }

        // Sort by name for consistent output
        result.sort { $0.app_name.lowercased() < $1.app_name.lowercased() }

        Logger.shared.debug("Found \(result.count) running applications")
        return result
    }

    private static func countWindowsForApp(pid: pid_t) -> Int {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)

        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }

        var count = 0
        for windowInfo in windowList {
            if let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
               windowPID == pid {
                count += 1
            }
        }

        return count
    }
}

enum ApplicationError: Error {
    case notFound(String)
    case ambiguous(String, [NSRunningApplication])
}
