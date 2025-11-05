import Darwin
import Foundation
import Testing

extension Tag {
    // Test categories
    @Tag static var fast: Self
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var safe: Self
    @Tag static var automation: Self
    @Tag static var regression: Self

    // Feature areas
    @Tag static var permissions: Self
    @Tag static var applicationFinder: Self
    @Tag static var windowManager: Self
    @Tag static var imageCapture: Self
    @Tag static var models: Self
    @Tag static var jsonOutput: Self
    @Tag static var logger: Self
    @Tag static var browserFiltering: Self
    @Tag static var screenshot: Self
    @Tag static var multiWindow: Self
    @Tag static var focus: Self
    @Tag static var imageAnalysis: Self
    @Tag static var formats: Self
    @Tag static var multiDisplay: Self

    // Performance & reliability
    @Tag static var performance: Self
    @Tag static var concurrency: Self
    @Tag static var memory: Self
    @Tag static var flaky: Self

    // Execution environment
    @Tag static var localOnly: Self
    @Tag static var ciOnly: Self
    @Tag static var requiresDisplay: Self
    @Tag static var requiresPermissions: Self
    @Tag static var requiresNetwork: Self
}

enum CLITestEnvironment {
    private static let env = ProcessInfo.processInfo.environment

    static var runAutomationScenarios: Bool {
        env["RUN_AUTOMATION_TESTS"] == "true" || env["RUN_LOCAL_TESTS"] == "true"
    }

    static func peekabooBinaryURL() -> URL? {
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            workingDirectory.appendingPathComponent(".build/debug/peekaboo"),
            workingDirectory.appendingPathComponent(".build/Debug/peekaboo"),
            workingDirectory.appendingPathComponent(".build/release/peekaboo"),
            workingDirectory.appendingPathComponent(".build/Release/peekaboo"),
        ]

        for url in candidates where FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }

        return nil
    }
}

enum CLIOutputCapture {
    static func suppressStderr<T>(_ body: () throws -> T) rethrows -> T {
        let originalFD = dup(STDERR_FILENO)
        guard originalFD != -1 else {
            return try body()
        }

        var pipeFD: [Int32] = [0, 0]
        guard pipe(&pipeFD) == 0 else {
            close(originalFD)
            return try body()
        }

        let readFD = pipeFD[0]
        let writeFD = pipeFD[1]

        dup2(writeFD, STDERR_FILENO)
        close(writeFD)

        defer {
            dup2(originalFD, STDERR_FILENO)
            close(originalFD)

            // Drain any remaining data
            var buffer = [UInt8](repeating: 0, count: 1024)
            while read(readFD, &buffer, buffer.count) > 0 {}
            close(readFD)
        }

        return try body()
    }
}
