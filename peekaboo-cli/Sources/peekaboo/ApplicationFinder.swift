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

        // Check for exact bundle ID match first
        if let exactMatch = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            Logger.shared.debug("Found exact bundle ID match: \(exactMatch.localizedName ?? "Unknown")")
            return exactMatch
        }

        // Find all possible matches
        let matches = findAllMatches(for: identifier, in: runningApps)

        // Get unique matches
        let uniqueMatches = removeDuplicateMatches(from: matches)

        // Handle results
        return try processMatchResults(uniqueMatches, identifier: identifier, runningApps: runningApps)
    }

    private static func findAllMatches(for identifier: String, in apps: [NSRunningApplication]) -> [AppMatch] {
        var matches: [AppMatch] = []
        let lowerIdentifier = identifier.lowercased()

        for app in apps {
            // Check exact name match
            if let appName = app.localizedName {
                if appName.lowercased() == lowerIdentifier {
                    matches.append(AppMatch(app: app, score: 1.0, matchType: "exact_name"))
                    continue
                }

                // Check partial name matches
                matches.append(contentsOf: findNameMatches(app: app, appName: appName, identifier: lowerIdentifier))
            }

            // Check bundle ID matches
            if let bundleId = app.bundleIdentifier, bundleId.lowercased().contains(lowerIdentifier) {
                let score = Double(lowerIdentifier.count) / Double(bundleId.count) * 0.6
                matches.append(AppMatch(app: app, score: score, matchType: "bundle_contains"))
            }
        }

        return matches.sorted { $0.score > $1.score }
    }

    private static func findNameMatches(app: NSRunningApplication, appName: String, identifier: String) -> [AppMatch] {
        var matches: [AppMatch] = []
        let lowerAppName = appName.lowercased()

        if lowerAppName.hasPrefix(identifier) {
            let score = Double(identifier.count) / Double(lowerAppName.count)
            matches.append(AppMatch(app: app, score: score, matchType: "prefix"))
        } else if lowerAppName.contains(identifier) {
            let score = Double(identifier.count) / Double(lowerAppName.count) * 0.8
            matches.append(AppMatch(app: app, score: score, matchType: "contains"))
        }

        return matches
    }

    private static func removeDuplicateMatches(from matches: [AppMatch]) -> [AppMatch] {
        var uniqueMatches: [AppMatch] = []
        var seenPIDs: Set<pid_t> = []

        for match in matches where !seenPIDs.contains(match.app.processIdentifier) {
            uniqueMatches.append(match)
            seenPIDs.insert(match.app.processIdentifier)
        }

        return uniqueMatches
    }

    private static func processMatchResults(
        _ matches: [AppMatch],
        identifier: String,
        runningApps: [NSRunningApplication]
    ) throws(ApplicationError) -> NSRunningApplication {
        guard !matches.isEmpty else {
            Logger.shared.error("No applications found matching: \(identifier)")
            outputError(
                message: "No running applications found matching identifier: \(identifier)",
                code: .APP_NOT_FOUND,
                details: "Available applications: " +
                    "\(runningApps.compactMap { $0.localizedName }.joined(separator: ", "))"
            )
            throw ApplicationError.notFound(identifier)
        }

        // Check for ambiguous matches
        let topScore = matches[0].score
        let topMatches = matches.filter { abs($0.score - topScore) < 0.1 }

        if topMatches.count > 1 {
            handleAmbiguousMatches(topMatches, identifier: identifier)
            throw ApplicationError.ambiguous(identifier, topMatches.map { $0.app })
        }

        let bestMatch = matches[0]
        Logger.shared.debug(
            "Found application: \(bestMatch.app.localizedName ?? "Unknown") " +
                "(score: \(bestMatch.score), type: \(bestMatch.matchType))"
        )

        return bestMatch.app
    }

    private static func handleAmbiguousMatches(_ matches: [AppMatch], identifier: String) {
        let matchDescriptions = matches.map { match in
            "\(match.app.localizedName ?? "Unknown") (\(match.app.bundleIdentifier ?? "unknown.bundle"))"
        }

        Logger.shared.error("Ambiguous application identifier: \(identifier)")
        outputError(
            message: "Multiple applications match identifier '\(identifier)'. Please be more specific.",
            code: .AMBIGUOUS_APP_IDENTIFIER,
            details: "Matches found: \(matchDescriptions.joined(separator: ", "))"
        )
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
