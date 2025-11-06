import Foundation

enum PeekabooCLITestRunner {
    struct CommandError: Error, CustomStringConvertible {
        let status: Int32
        let output: String

        var description: String {
            "Command failed with status \(self.status)\nOutput:\n\(self.output)"
        }
    }

    private static let executionQueue = DispatchQueue(label: "peekaboo.cli.test-runner")

    static func runCommand(_ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            executionQueue.async {
                do {
                    let output = try self.runCommandSync(arguments)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runCommandSync(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        process.arguments = ["swift", "run", "peekaboo"] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw CommandError(status: process.terminationStatus, output: "Failed to decode command output")
        }

        let status = process.terminationStatus
        guard status == 0 else {
            throw CommandError(status: status, output: output)
        }

        return output
    }
}
