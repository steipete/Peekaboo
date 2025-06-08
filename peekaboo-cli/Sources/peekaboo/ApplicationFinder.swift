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

        // In CI environment, throw not found to avoid accessing NSWorkspace
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw ApplicationError.notFound(identifier)
        }

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
        } else {
            // Try fuzzy matching if no direct match
            matches.append(contentsOf: findFuzzyMatches(app: app, appName: appName, identifier: identifier))
        }

        return matches
    }

    private static func findFuzzyMatches(app: NSRunningApplication, appName: String, identifier: String) -> [AppMatch] {
        var matches: [AppMatch] = []
        let lowerAppName = appName.lowercased()

        // Try fuzzy matching against the full app name
        let fullNameSimilarity = calculateStringSimilarity(lowerAppName, identifier)
        if fullNameSimilarity >= 0.7 {
            let score = fullNameSimilarity * 0.9
            matches.append(AppMatch(app: app, score: score, matchType: "fuzzy"))
            return matches // Return early if we found a good match
        }

        // For multi-word app names, also try fuzzy matching against individual words
        let words = lowerAppName.split(separator: " ").map(String.init)
        for (index, word) in words.enumerated() {
            let wordSimilarity = calculateStringSimilarity(word, identifier)
            if wordSimilarity >= 0.65 {
                // Score based on word similarity but reduced for partial matches
                // Give higher score to matches on the first word (main app name)
                let positionMultiplier = index == 0 ? 0.85 : 0.75
                // Reduce score for helper/service processes
                var systemPenalty = 1.0
                if lowerAppName.contains("helper") { systemPenalty *= 0.8 }
                if lowerAppName.contains("service") || lowerAppName.contains("theme") { systemPenalty *= 0.7 }
                let score = wordSimilarity * positionMultiplier * systemPenalty
                matches.append(AppMatch(app: app, score: score, matchType: "fuzzy_word"))
                break // Only match first suitable word
            }
        }

        return matches
    }

    private static func calculateStringSimilarity(_ s1: String, _ s2: String) -> Double {
        // Only consider strings with reasonable length differences
        let lengthDiff = abs(s1.count - s2.count)
        guard lengthDiff <= 3 else { return 0.0 }

        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)

        // Calculate similarity (1.0 = identical, 0.0 = completely different)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)

        let n = a.count
        let m = b.count

        if n == 0 { return m }
        if m == 0 { return n }

        var matrix = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        for i in 0...n {
            matrix[i][0] = i
        }
        for j in 0...m {
            matrix[0][j] = j
        }

        for i in 1...n {
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1, // deletion
                    matrix[i][j - 1] + 1, // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[n][m]
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

            // Find similar app names using fuzzy matching
            let suggestions = findSimilarApplications(identifier: identifier, from: runningApps)
            let detailsMessage = if !suggestions.isEmpty {
                "Did you mean: \(suggestions.joined(separator: ", "))?"
            } else {
                "Available applications: " +
                    "\(runningApps.compactMap(\.localizedName).joined(separator: ", "))"
            }

            outputError(
                message: "No running applications found matching identifier: \(identifier)",
                code: .APP_NOT_FOUND,
                details: detailsMessage
            )
            throw ApplicationError.notFound(identifier)
        }

        // Check for ambiguous matches
        let topScore = matches[0].score
        // Use a smaller threshold for fuzzy matches to avoid ambiguity
        let threshold = matches[0].matchType.contains("fuzzy") ? 0.05 : 0.1
        let topMatches = matches.filter { abs($0.score - topScore) < threshold }

        if topMatches.count > 1 {
            handleAmbiguousMatches(topMatches, identifier: identifier)
            throw ApplicationError.ambiguous(identifier, topMatches.map(\.app))
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

    private static func findSimilarApplications(identifier: String, from apps: [NSRunningApplication]) -> [String] {
        var suggestions: [(name: String, score: Double)] = []
        let lowerIdentifier = identifier.lowercased()

        for app in apps {
            guard let appName = app.localizedName else { continue }
            let lowerAppName = appName.lowercased()

            // Try full name similarity
            let fullNameSimilarity = calculateStringSimilarity(lowerAppName, lowerIdentifier)
            if fullNameSimilarity >= 0.6 && fullNameSimilarity < 1.0 {
                suggestions.append((name: appName, score: fullNameSimilarity))
                continue
            }

            // For multi-word app names, also check individual words
            let words = lowerAppName.split(separator: " ").map(String.init)
            for word in words {
                let wordSimilarity = calculateStringSimilarity(word, lowerIdentifier)
                if wordSimilarity >= 0.6 && wordSimilarity < 1.0 {
                    // Reduce score slightly for word matches vs full name matches
                    suggestions.append((name: appName, score: wordSimilarity * 0.9))
                    break // Only match first suitable word
                }
            }
        }

        // Sort by similarity and take top 3 suggestions
        return suggestions
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map(\.name)
    }

    static func getAllRunningApplications() -> [ApplicationInfo] {
        Logger.shared.debug("Retrieving all running applications")

        // In CI environment, return empty array to avoid accessing NSWorkspace
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return []
        }

        let runningApps = NSWorkspace.shared.runningApplications
        var result: [ApplicationInfo] = []

        for app in runningApps {
            // Skip background-only apps without a name
            guard let appName = app.localizedName, !appName.isEmpty else {
                continue
            }

            // Count windows for this app
            let windowCount = countWindowsForApp(pid: app.processIdentifier)

            // Only include applications that have one or more windows.
            guard windowCount > 0 else {
                continue
            }

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
