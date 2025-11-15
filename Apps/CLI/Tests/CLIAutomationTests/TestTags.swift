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

@preconcurrency
enum CLITestEnvironment {
    @preconcurrency
    @inline(__always)
    nonisolated(unsafe) private static func flag(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key]?.lowercased() == "true"
    }

    @preconcurrency
    nonisolated(unsafe) private static var runAutomationTests: Bool {
        flag("RUN_AUTOMATION_TESTS")
    }

    @preconcurrency nonisolated(unsafe) static var runAutomationRead: Bool {
        runAutomationTests || flag("RUN_AUTOMATION_READ") || flag("RUN_LOCAL_TESTS")
    }

    @preconcurrency nonisolated(unsafe) static var runAutomationActions: Bool {
        runAutomationTests || flag("RUN_AUTOMATION_ACTIONS") || flag("RUN_LOCAL_TESTS")
    }

    @preconcurrency nonisolated(unsafe) static var runAutomationScenarios: Bool {
        runAutomationRead || runAutomationActions
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

        let captureGroup = DispatchGroup()
        captureGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            var buffer = [UInt8](repeating: 0, count: 1024)
            while read(readFD, &buffer, buffer.count) > 0 {}
            captureGroup.leave()
        }

        defer {
            dup2(originalFD, STDERR_FILENO)
            close(originalFD)
            captureGroup.wait()
            close(readFD)
        }

        return try body()
    }
}
