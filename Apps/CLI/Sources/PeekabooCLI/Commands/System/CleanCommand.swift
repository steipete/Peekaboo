import Commander
import Foundation
import PeekabooCore

/// Clean up session cache and temporary files
@available(macOS 14.0, *)
@MainActor
struct CleanCommand: OutputFormattable, RuntimeOptionsConfigurable {
    static let commandDescription = CommandDescription(
        commandName: "clean",
        abstract: "Clean up session cache and temporary files",
        discussion: """

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
        """,

        showHelpOnEmptyInvocation: true
    )

    @Flag(help: "Remove all session data")
    var allSessions = false

    @Option(help: "Remove sessions older than specified hours (default: 24)")
    var olderThan: Int?

    @Option(help: "Remove specific session by ID")
    var session: String?

    @Flag(help: "Show what would be deleted without actually deleting")
    var dryRun = false
    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    private var configuration: CommandRuntime.Configuration {
        if let runtime {
            return runtime.configuration
        }
        // During bare parsing in unit tests no runtime is injected; fall back
        // to the parsed runtime options so flags like --json-output are visible.
        return self.runtimeOptions.makeConfiguration()
    }
    var jsonOutput: Bool { self.configuration.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
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
                result = try await self.services.files.cleanAllSessions(dryRun: self.dryRun)
            } else if let hours = olderThan {
                result = try await self.services.files.cleanOldSessions(hours: hours, dryRun: self.dryRun)
            } else if let sessionId = session {
                result = try await self.services.files.cleanSpecificSession(
                    sessionId: sessionId,
                    dryRun: self.dryRun
                )
            } else {
                throw ValidationError("No cleanup option specified")
            }

            // Calculate execution time
            let executionTime = Date().timeIntervalSince(startTime)

            // Output results
            if self.jsonOutput {
                // Create a wrapper for the clean result with execution time
                struct CleanResultWithTime: Codable {
                    let sessionsRemoved: Int
                    let bytesFreed: Int64
                    let sessionDetails: [SessionDetail]
                    let dryRun: Bool
                    let executionTime: TimeInterval
                }

                let outputData = CleanResultWithTime(
                    sessionsRemoved: result.sessionsRemoved,
                    bytesFreed: result.bytesFreed,
                    sessionDetails: result.sessionDetails,
                    dryRun: result.dryRun,
                    executionTime: executionTime
                )
                outputSuccessCodable(data: outputData, logger: self.outputLogger)
            } else {
                self.printResults(result, executionTime: executionTime)
            }

        } catch let error as ValidationError {
            if self.jsonOutput {
                outputError(message: error.localizedDescription, code: .VALIDATION_ERROR, logger: self.outputLogger)
            } else {
                var stderrStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &stderrStream)
            }
            throw ExitCode.failure
        } catch let error as FileServiceError {
            handleFileServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
            throw ExitCode(1)
        } catch {
            if self.jsonOutput {
                outputError(message: error.localizedDescription, code: .INTERNAL_SWIFT_ERROR, logger: self.outputLogger)
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

private func handleFileServiceError(_ error: FileServiceError, jsonOutput: Bool, logger: Logger) {
    let errorCode: ErrorCode = switch error {
    case .sessionNotFound:
        .SESSION_NOT_FOUND
    case .directoryNotFound:
        .FILE_IO_ERROR
    case .insufficientPermissions:
        .PERMISSION_DENIED
    case .fileSystemError:
        .FILE_IO_ERROR
    }

    if jsonOutput {
        outputError(message: error.localizedDescription, code: errorCode, logger: logger)
    } else {
        var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
        print("❌ \(error.localizedDescription)", to: &localStandardErrorStream)
    }
}

extension CleanCommand: AsyncRuntimeCommand {}

@MainActor
extension CleanCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.allSessions = values.flag("allSessions")
        self.dryRun = values.flag("dryRun")
        self.olderThan = try values.decodeOption("olderThan", as: Int.self)
        self.session = values.singleOption("session")
    }
}
