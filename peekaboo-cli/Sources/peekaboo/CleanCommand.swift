import ArgumentParser
import Foundation

/// Cleans up session cache and temporary files.
/// Provides maintenance utilities for Peekaboo's session management.
@available(macOS 14.0, *)
struct CleanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up session cache and temporary files",
        discussion: """
            The 'clean' command provides utilities for managing Peekaboo's
            session cache and temporary files. Use this to free up disk space
            and remove orphaned session data.

            EXAMPLES:
              peekaboo clean --all-sessions       # Remove all session data
              peekaboo clean --older-than 24      # Remove sessions older than 24 hours
              peekaboo clean --session 12345      # Remove specific session
              peekaboo clean --dry-run            # Preview what would be deleted

            SESSION CACHE:
              Sessions are stored in ~/.peekaboo/session/<PID>/
              Each session contains:
              - raw.png: Original screenshot
              - annotated.png: Screenshot with UI markers (if generated)
              - map.json: UI element mapping data
        """
    )

    @Flag(help: "Remove all session data")
    var allSessions = false

    @Option(help: "Remove sessions older than specified hours (default: 24)")
    var olderThan: Int?

    @Option(help: "Remove specific session by ID")
    var session: String?

    @Flag(help: "Show what would be deleted without actually deleting")
    var dryRun = false

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        let startTime = Date()

        do {
            // Determine cache directory
            let cacheDir = getCacheDirectory()

            // Validate options
            let optionCount = [allSessions, olderThan != nil, session != nil].count(where: { $0 })
            guard optionCount == 1 else {
                throw ValidationError("Specify exactly one of: --all-sessions, --older-than, or --session")
            }

            // Perform cleanup based on option
            let result: CleanResult

            if allSessions {
                result = try await cleanAllSessions(cacheDir: cacheDir, dryRun: dryRun)
            } else if let hours = olderThan {
                result = try await cleanOldSessions(cacheDir: cacheDir, hours: hours, dryRun: dryRun)
            } else if let sessionId = session {
                result = try await cleanSpecificSession(cacheDir: cacheDir, sessionId: sessionId, dryRun: dryRun)
            } else {
                throw ValidationError("No cleanup option specified")
            }

            // Output results
            if jsonOutput {
                var output = result
                output.executionTime = Date().timeIntervalSince(startTime)
                outputSuccessCodable(data: output)
            } else {
                printResults(result, dryRun: dryRun, executionTime: Date().timeIntervalSince(startTime))
            }

        } catch {
            if jsonOutput {
                outputError(message: error.localizedDescription, code: .INTERNAL_SWIFT_ERROR)
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func getCacheDirectory() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".peekaboo/session")
    }

    private func cleanAllSessions(cacheDir: URL, dryRun: Bool) async throws -> CleanResult {
        var result = CleanResult(
            sessionsRemoved: 0,
            bytesFreed: 0,
            sessionDetails: []
        )

        guard FileManager.default.fileExists(atPath: cacheDir.path) else {
            return result
        }

        let sessionDirs = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )

        for sessionDir in sessionDirs {
            guard sessionDir.hasDirectoryPath else { continue }

            let sessionSize = try calculateDirectorySize(sessionDir)
            let sessionId = sessionDir.lastPathComponent

            let detail = SessionDetail(
                sessionId: sessionId,
                path: sessionDir.path,
                size: sessionSize,
                creationDate: try sessionDir.resourceValues(forKeys: [.creationDateKey]).creationDate
            )

            result.sessionDetails.append(detail)
            result.sessionsRemoved += 1
            result.bytesFreed += sessionSize

            if !dryRun {
                try FileManager.default.removeItem(at: sessionDir)
            }
        }

        return result
    }

    private func cleanOldSessions(cacheDir: URL, hours: Int, dryRun: Bool) async throws -> CleanResult {
        var result = CleanResult(
            sessionsRemoved: 0,
            bytesFreed: 0,
            sessionDetails: []
        )

        guard FileManager.default.fileExists(atPath: cacheDir.path) else {
            return result
        }

        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)

        let sessionDirs = try FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )

        for sessionDir in sessionDirs {
            guard sessionDir.hasDirectoryPath else { continue }

            let modificationDate = try sessionDir.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

            if let modDate = modificationDate, modDate < cutoffDate {
                let sessionSize = try calculateDirectorySize(sessionDir)
                let sessionId = sessionDir.lastPathComponent

                let detail = SessionDetail(
                    sessionId: sessionId,
                    path: sessionDir.path,
                    size: sessionSize,
                    creationDate: modDate
                )

                result.sessionDetails.append(detail)
                result.sessionsRemoved += 1
                result.bytesFreed += sessionSize

                if !dryRun {
                    try FileManager.default.removeItem(at: sessionDir)
                }
            }
        }

        return result
    }

    private func cleanSpecificSession(cacheDir: URL, sessionId: String, dryRun: Bool) async throws -> CleanResult {
        var result = CleanResult(
            sessionsRemoved: 0,
            bytesFreed: 0,
            sessionDetails: []
        )

        let sessionDir = cacheDir.appendingPathComponent(sessionId)

        guard FileManager.default.fileExists(atPath: sessionDir.path) else {
            throw ValidationError("Session '\(sessionId)' not found")
        }

        let sessionSize = try calculateDirectorySize(sessionDir)

        let detail = SessionDetail(
            sessionId: sessionId,
            path: sessionDir.path,
            size: sessionSize,
            creationDate: try sessionDir.resourceValues(forKeys: [.creationDateKey]).creationDate
        )

        result.sessionDetails.append(detail)
        result.sessionsRemoved = 1
        result.bytesFreed = sessionSize

        if !dryRun {
            try FileManager.default.removeItem(at: sessionDir)
        }

        return result
    }

    private func calculateDirectorySize(_ directory: URL) throws -> Int64 {
        var totalSize: Int64 = 0

        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    private func printResults(_ result: CleanResult, dryRun: Bool, executionTime: TimeInterval) {
        if dryRun {
            print("🔍 Dry run mode - no files will be deleted")
            print("")
        }

        if result.sessionsRemoved == 0 {
            print("✅ No sessions to clean")
        } else {
            let action = dryRun ? "Would remove" : "Removed"
            print("🗑️  \(action) \(result.sessionsRemoved) session\(result.sessionsRemoved == 1 ? "" : "s")")
            print("💾 Space \(dryRun ? "to be freed" : "freed"): \(formatBytes(result.bytesFreed))")

            if result.sessionDetails.count <= 5 {
                print("\nSessions:")
                for detail in result.sessionDetails {
                    print("  - \(detail.sessionId) (\(formatBytes(detail.size)))")
                }
            }
        }

        print("\n⏱️  Completed in \(String(format: "%.2f", executionTime))s")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Output Models

struct CleanResult: Codable {
    var sessionsRemoved: Int
    var bytesFreed: Int64
    var sessionDetails: [SessionDetail]
    var executionTime: TimeInterval?
    var success: Bool = true
}

struct SessionDetail: Codable {
    let sessionId: String
    let path: String
    let size: Int64
    let creationDate: Date?
}