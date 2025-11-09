@preconcurrency import ArgumentParser
import Foundation

/// Pauses execution for a specified duration.
/// Useful for timing in automation scripts.
@available(macOS 14.0, *)
@MainActor
struct SleepCommand: AsyncRuntimeCommand, OutputFormattable {
    static let mainActorConfiguration = CommandConfiguration(
        commandName: "sleep",
        abstract: "Pause execution for a specified duration",
        discussion: """
            The 'sleep' command pauses execution for a specified number
            of milliseconds. This is useful in automation scripts to wait
            for UI animations, page loads, or other time-based events.

            EXAMPLES:
              peekaboo sleep 1000        # Sleep for 1 second
              peekaboo sleep 500         # Sleep for 0.5 seconds
              peekaboo sleep 3000        # Sleep for 3 seconds

            The duration is specified in milliseconds.
        """
    )

    @Argument(help: "Duration to sleep in milliseconds")
    var duration: Int

    @OptionGroup
    var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    var outputLogger: Logger {
        self.runtime?.logger ?? Logger.shared
    }

    var jsonOutput: Bool { self.runtimeOptions.jsonOutput }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()

        guard self.duration > 0 else {
            let error = ValidationError("Duration must be positive")
            if self.jsonOutput {
                outputError(message: error.localizedDescription, code: .INVALID_ARGUMENT, logger: self.outputLogger)
            } else {
                var stderrStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &stderrStream)
            }
            throw ExitCode.failure
        }

        try await Task.sleep(nanoseconds: UInt64(self.duration) * 1_000_000)

        let actualDuration = Date().timeIntervalSince(startTime) * 1000 // Convert to ms

        if self.jsonOutput {
            let output = SleepResult(
                success: true,
                requested_duration: duration,
                actual_duration: Int(actualDuration)
            )
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            let seconds = Double(duration) / 1000.0
            print("✅ Paused for \(seconds)s")
        }
    }
}

// MARK: - JSON Output Structure

struct SleepResult: Codable {
    let success: Bool
    let requested_duration: Int
    let actual_duration: Int
}
