import ArgumentParser
import Foundation
import PeekabooCLI
import PeekabooCore

struct CommandRunResult {
    let stdout: String
    let stderr: String
    let exitStatus: Int32
}

enum InProcessCommandRunner {
    static func run(
        _ arguments: [String],
        services: PeekabooServices,
        spaceService: SpaceCommandSpaceService? = nil
    ) async throws -> CommandRunResult {
        try await PeekabooServices.withTestServices(services) {
            if let spaceService {
                return try await SpaceCommandEnvironment.withSpaceService(spaceService) {
                    try await self.execute(arguments: arguments)
                }
            } else {
                return try await self.execute(arguments: arguments)
            }
        }
    }

    private static func execute(arguments: [String]) async throws -> CommandRunResult {
        try await self.captureOutput {
            var exitStatus: Int32 = 0
            var stdoutData = Data()
            var stderrData = Data()

            let result: (Int32, Data, Data) = try await self.redirectOutput {
                do {
                    var command = try Peekaboo.parseAsRoot(arguments)
                    try await command.run()
                    return 0
                } catch let exit as ExitCode {
                    return exit.rawValue
                }
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
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
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
