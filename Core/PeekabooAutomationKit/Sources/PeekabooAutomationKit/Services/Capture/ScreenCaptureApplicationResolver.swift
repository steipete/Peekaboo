import AppKit
import Foundation
import PeekabooFoundation

@_spi(Testing) public protocol ApplicationResolving: Sendable {
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo
    func frontmostApplication() async throws -> ServiceApplicationInfo
}

struct PeekabooApplicationResolver: ApplicationResolving {
    @MainActor
    func frontmostApplication() async throws -> ServiceApplicationInfo {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            throw NotFoundError.application("frontmost")
        }
        return Self.applicationInfo(from: frontmost)
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            !app.isTerminated
        }

        if let pid = Self.parsePID(trimmedIdentifier),
           let app = runningApps.first(where: { $0.processIdentifier == pid })
        {
            return Self.applicationInfo(from: app)
        }

        if let bundleMatch = runningApps.first(where: { $0.bundleIdentifier == trimmedIdentifier }) {
            return Self.applicationInfo(from: bundleMatch)
        }

        if let exactName = runningApps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame
        }) {
            return Self.applicationInfo(from: exactName)
        }

        let fuzzyMatches = runningApps.compactMap { app -> (app: NSRunningApplication, score: Int)? in
            guard app.activationPolicy != .prohibited,
                  let name = app.localizedName,
                  name.localizedCaseInsensitiveContains(trimmedIdentifier)
            else { return nil }

            var score = 0
            if name.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame {
                score += 1000
            }
            if name.lowercased().hasPrefix(trimmedIdentifier.lowercased()) {
                score += 100
            }
            if app.activationPolicy == .regular {
                score += 50
            }
            score -= name.count
            return (app, score)
        }

        if let bestMatch = fuzzyMatches.max(by: { $0.score < $1.score }) {
            return Self.applicationInfo(from: bestMatch.app)
        }

        throw PeekabooError.appNotFound(identifier)
    }

    private static func parsePID(_ identifier: String) -> Int32? {
        guard identifier.uppercased().hasPrefix("PID:") else { return nil }
        return Int32(identifier.dropFirst(4))
    }

    private static func applicationInfo(from app: NSRunningApplication) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: 0)
    }
}
