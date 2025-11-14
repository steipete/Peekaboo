import Foundation
import PeekabooCore
@testable import PeekabooCLI

struct CommandRunResult {
    let stdout: String
    let stderr: String
    let exitStatus: Int32

    var combinedOutput: String {
        self.stdout.isEmpty ? self.stderr : self.stdout
    }

    func validateExitStatus(allowedExitCodes: Set<Int32>, arguments: [String]) throws {
        guard allowedExitCodes.contains(self.exitStatus) else {
            throw CommandExecutionError(
                status: self.exitStatus,
                stdout: self.stdout,
                stderr: self.stderr,
                arguments: arguments
            )
        }
    }
}

struct CommandExecutionError: Error, CustomStringConvertible {
    let status: Int32
    let stdout: String
    let stderr: String
    let arguments: [String]

    var description: String {
        "Command \(self.arguments.joined(separator: " ")) failed with exit code \(self.status)." +
            "\nstdout: \(self.stdout)\nstderr: \(self.stderr)"
    }
}

enum InProcessCommandRunner {
    static func run(
        _ arguments: [String],
        services: PeekabooServices,
        spaceService: SpaceCommandSpaceService? = nil
    ) async throws -> CommandRunResult {
        try await CommandRuntime.withInjectedServices(services) {
            if let spaceService {
                try await SpaceCommandEnvironment.withSpaceService(spaceService) {
                    try await self.execute(arguments: arguments)
                }
            } else {
                try await self.execute(arguments: arguments)
            }
        }
    }

    /// Run the CLI using the default shared services (no overrides).
    static func runWithSharedServices(_ arguments: [String]) async throws -> CommandRunResult {
        try await self.execute(arguments: arguments)
    }

    /// Convenience helper for tests that rely on the shared service stack and expect specific exit codes.
    static func runShared(
        _ arguments: [String],
        allowedExitCodes: Set<Int32> = [0]
    ) async throws -> CommandRunResult {
        let result = try await self.runWithSharedServices(arguments)
        try result.validateExitStatus(allowedExitCodes: allowedExitCodes, arguments: arguments)
        return result
    }

    private static func execute(arguments: [String]) async throws -> CommandRunResult {
        try await self.captureOutput {
            var exitStatus: Int32 = 0
            var stdoutData = Data()
            var stderrData = Data()

            let result: (Int32, Data, Data) = try await self.redirectOutput {
                await executePeekabooCLI(arguments: ["peekaboo"] + arguments)
            }

            exitStatus = result.0
            stdoutData = result.1
            stderrData = result.2

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            return CommandRunResult(stdout: stdout, stderr: stderr, exitStatus: exitStatus)
        }
    }

    private static func captureOutput(
        _ operation: () async throws -> CommandRunResult
    ) async throws -> CommandRunResult {
        try await operation()
    }

    private static func redirectOutput(
        _ body: () async throws -> Int32
    ) async throws -> (Int32, Data, Data) {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let originalStdout = dup(STDOUT_FILENO)
        let originalStderr = dup(STDERR_FILENO)

        dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()

        do {
            let status = try await body()
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            dup2(originalStdout, STDOUT_FILENO)
            dup2(originalStderr, STDERR_FILENO)
            close(originalStdout)
            close(originalStderr)
            return (status, stdoutData, stderrData)
        } catch {
            _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            dup2(originalStdout, STDOUT_FILENO)
            dup2(originalStderr, STDERR_FILENO)
            close(originalStdout)
            close(originalStderr)
            throw error
        }
    }
}

enum ExternalCommandRunner {
    enum Error: Swift.Error, LocalizedError {
        case executableNotFound(String)
        case jsonPayloadMissing(output: String)

        var errorDescription: String? {
            switch self {
            case let .executableNotFound(path):
                "Unable to find executable at \(path)"
            case let .jsonPayloadMissing(output):
                "Expected JSON payload was not found in command output:\n\(output)"
            }
        }
    }

    @discardableResult
    static func runPolterPeekaboo(
        _ arguments: [String],
        allowedExitCodes: Set<Int32> = [0],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> CommandRunResult {
        let runnerPath = "./runner"
        guard FileManager.default.isExecutableFile(atPath: runnerPath) else {
            throw Error.executableNotFound(runnerPath)
        }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        process.executableURL = URL(fileURLWithPath: runnerPath)
        process.arguments = ["polter", "peekaboo", "--"] + arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let result = CommandRunResult(
            stdout: stdout,
            stderr: stderr,
            exitStatus: process.terminationStatus
        )
        try result.validateExitStatus(
            allowedExitCodes: allowedExitCodes,
            arguments: ["polter", "peekaboo"] + arguments
        )
        return result
    }

    static func decodeJSONResponse<T: Decodable>(
        from result: CommandRunResult,
        as type: T.Type
    ) throws -> T {
        let combinedOutput: String = if result.stdout.isEmpty {
            result.stderr
        } else if result.stderr.isEmpty {
            result.stdout
        } else {
            result.stdout + "\n" + result.stderr
        }

        guard let jsonString = Self.extractFirstJSONObject(from: combinedOutput),
              let data = jsonString.data(using: .utf8) else {
            throw Error.jsonPayloadMissing(output: combinedOutput)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private static func extractFirstJSONObject(from output: String) -> String? {
        guard let firstBraceIndex = output.firstIndex(of: "{") else { return nil }
        var depth = 0
        var currentIndex = firstBraceIndex
        while currentIndex < output.endIndex {
            let character = output[currentIndex]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(output[firstBraceIndex...currentIndex])
                }
            }
            output.formIndex(after: &currentIndex)
        }
        return nil
    }
}
