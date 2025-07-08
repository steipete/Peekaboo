import ArgumentParser
import Foundation
import PeekabooCore

/// Refactored CleanCommand using PeekabooCore FileService
///
/// This version delegates file system operations to the service layer
/// while maintaining the same command interface and output compatibility.
@available(macOS 14.0, *)
struct CleanCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean-v2",
        abstract: "Clean up session cache and temporary files using FileService",
        discussion: """
            This is a refactored version of the clean command that uses PeekabooCore FileService
            instead of direct file system operations. It maintains the same interface but delegates
            all file operations to the service layer.

            EXAMPLES:
              peekaboo clean-v2 --all-sessions       # Remove all session data
              peekaboo clean-v2 --older-than 24      # Remove sessions older than 24 hours
              peekaboo clean-v2 --session 12345      # Remove specific session
              peekaboo clean-v2 --dry-run            # Preview what would be deleted

            SESSION CACHE:
              Sessions are stored in ~/.peekaboo/session/<PID>/
              Each session contains:
              - raw.png: Original screenshot
              - annotated.png: Screenshot with UI markers (if generated)
              - map.json: UI element mapping data
        """)

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

    private let services = PeekabooServices.shared

    mutating func run() async throws {
        let startTime = Date()

        do {
            // Validate options
            let optionCount = [allSessions, olderThan != nil, self.session != nil].count { $0 }
            guard optionCount == 1 else {
                throw ValidationError("Specify exactly one of: --all-sessions, --older-than, or --session")
            }

            // Perform cleanup based on option using the FileService
            let result: CleanResult

            if self.allSessions {
                result = try await services.files.cleanAllSessions(dryRun: self.dryRun)
            } else if let hours = olderThan {
                result = try await services.files.cleanOldSessions(hours: hours, dryRun: self.dryRun)
            } else if let sessionId = session {
                result = try await services.files.cleanSpecificSession(
                    sessionId: sessionId,
                    dryRun: self.dryRun)
            } else {
                throw ValidationError("No cleanup option specified")
            }

            // Calculate execution time
            let executionTime = Date().timeIntervalSince(startTime)

            // Output results
            if self.jsonOutput {
                var output = result
                output.executionTime = executionTime
                outputJSON(JSONResponse(
                    success: true,
                    data: AnyCodable([
                        "sessions_removed": output.sessionsRemoved,
                        "bytes_freed": output.bytesFreed,
                        "session_details": output.sessionDetails.map { detail in
                            [
                                "session_id": detail.sessionId,
                                "path": detail.path,
                                "size": detail.size,
                                "creation_date": detail.creationDate?.timeIntervalSince1970 ?? 0,
                                "modification_date": detail.modificationDate?.timeIntervalSince1970 ?? 0
                            ]
                        },
                        "dry_run": output.dryRun,
                        "execution_time": output.executionTime ?? 0,
                        "success": true
                    ])
                ))
            } else {
                self.printResults(result, executionTime: executionTime)
            }

        } catch let error as FileServiceError {
            handleFileServiceError(error, jsonOutput: self.jsonOutput)
            throw ExitCode(1)
        } catch {
            if self.jsonOutput {
                outputError(message: error.localizedDescription, code: .INTERNAL_SWIFT_ERROR)
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func printResults(_ result: CleanResult, executionTime: TimeInterval) {
        if result.dryRun {
            print("🔍 Dry run mode - no files will be deleted")
            print("")
        }

        if result.sessionsRemoved == 0 {
            print("✅ No sessions to clean")
        } else {
            let action = result.dryRun ? "Would remove" : "Removed"
            print("🗑️  \(action) \(result.sessionsRemoved) session\(result.sessionsRemoved == 1 ? "" : "s")")
            print("💾 Space \(result.dryRun ? "to be freed" : "freed"): \(self.formatBytes(result.bytesFreed))")

            if result.sessionDetails.count <= 5 {
                print("\nSessions:")
                for detail in result.sessionDetails {
                    print("  - \(detail.sessionId) (\(self.formatBytes(detail.size)))")
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

// MARK: - Error Handling

private func handleFileServiceError(_ error: FileServiceError, jsonOutput: Bool) {
    let errorCode: ErrorCode
    switch error {
    case .sessionNotFound:
        errorCode = .SESSION_NOT_FOUND
    case .directoryNotFound:
        errorCode = .FILE_IO_ERROR
    case .insufficientPermissions:
        errorCode = .PERMISSION_DENIED
    case .fileSystemError:
        errorCode = .FILE_IO_ERROR
    }
    
    if jsonOutput {
        outputError(message: error.localizedDescription, code: errorCode)
    } else {
        var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
        print("❌ \(error.localizedDescription)", to: &localStandardErrorStream)
    }
}