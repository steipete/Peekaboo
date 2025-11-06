import Foundation
import Testing
import PeekabooCLI

@Suite("Utility Tests", .tags(.safe), .serialized)
struct UtilityTests {
    @Suite("Logger Tests", .tags(.safe), .serialized)
    struct LoggerTests {
        @Test("Logger captures messages in JSON mode")
        func loggerJSONMode() {
            CLIInstrumentation.LoggerControl.clearDebugLogs()
            CLIInstrumentation.LoggerControl.setJsonOutputMode(true)
            CLIInstrumentation.LoggerControl.setMinimumLogLevel(.debug)
            defer { CLIInstrumentation.LoggerControl.resetMinimumLogLevel() }

            logDebug("Debug message")
            logInfo("Info message")
            logWarn("Warning message")
            logError("Error message")

            // Ensure all operations are complete
            CLIInstrumentation.LoggerControl.flush()

            let logs = CLIInstrumentation.LoggerControl.debugLogs()
            CLIInstrumentation.LoggerControl.setJsonOutputMode(false)

            #expect(logs.contains { $0.contains("INFO: Info message") })
            #expect(logs.contains { $0.contains("WARN: Warning message") })
            #expect(logs.contains { $0.contains("ERROR: Error message") })
        }

        @Test("Logger clears debug logs")
        func loggerClearLogs() {
            CLIInstrumentation.LoggerControl.setJsonOutputMode(true)
            CLIInstrumentation.LoggerControl.setMinimumLogLevel(.debug)
            defer { CLIInstrumentation.LoggerControl.resetMinimumLogLevel() }

            logDebug("Test message")
            Thread.sleep(forTimeInterval: 0.1)

            let logsBefore = CLIInstrumentation.LoggerControl.debugLogs()
            #expect(!logsBefore.isEmpty)

            CLIInstrumentation.LoggerControl.clearDebugLogs()
            Thread.sleep(forTimeInterval: 0.1)

            let logsAfter = CLIInstrumentation.LoggerControl.debugLogs()
            CLIInstrumentation.LoggerControl.setJsonOutputMode(false)

            #expect(logsAfter.isEmpty)
        }

        @Test("Logger outputs to stderr in normal mode")
        func loggerStderrMode() {
            // Ensure clean state
            CLIInstrumentation.LoggerControl.clearDebugLogs()
            Thread.sleep(forTimeInterval: 0.05)
            CLIInstrumentation.LoggerControl.setJsonOutputMode(false)
            Thread.sleep(forTimeInterval: 0.05)
            CLIInstrumentation.LoggerControl.setMinimumLogLevel(.debug)
            defer { CLIInstrumentation.LoggerControl.resetMinimumLogLevel() }

            // These will output to stderr, we just verify they don't crash
            logDebug("Debug to stderr")
            logInfo("Info to stderr")
            logWarn("Warn to stderr")
            logError("Error to stderr")

            #expect(Bool(true))
        }
    }

    @Suite("Version Tests", .tags(.safe))
    struct VersionTests {
        @Test("Version has correct format")
        func versionFormat() {
            let version = Version.current

            // Should be in format "Peekaboo X.Y.Z" or "Peekaboo X.Y.Z-prerelease"
            #expect(version.hasPrefix("Peekaboo "))

            // Extract version number after "Peekaboo "
            let versionNumber = version.replacingOccurrences(of: "Peekaboo ", with: "")

            // Split by prerelease identifier first
            let versionParts = versionNumber.split(separator: "-", maxSplits: 1)
            let semverPart = String(versionParts[0])

            let components = semverPart.split(separator: ".")
            #expect(components.count == 3)

            // Each component should be a number
            for component in components {
                #expect(Int(component) != nil)
            }
        }

        @Test("Version is not empty")
        func versionNotEmpty() {
            #expect(!Version.current.isEmpty)
        }
    }

    @Suite("Helper Function Tests", .tags(.safe))
    struct HelperFunctionTests {
        @Test("Date formatting for filenames")
        func dateFormattingForFilenames() {
            let date = Date(timeIntervalSince1970: 1_234_567_890) // 2009-02-13 23:31:30 UTC
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withYear,
                .withMonth,
                .withDay,
                .withTime,
                .withDashSeparatorInDate,
                .withColonSeparatorInTime,
            ]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            let formatted = formatter.string(from: date)
            #expect(formatted.contains("2009-02-13"))
            #expect(formatted.contains("23:31:30"))
        }

        @Test("Path expansion handles tilde")
        func pathExpansionHandlesTilde() {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            let tildeDesktop = "~/Desktop"
            let expanded = NSString(string: tildeDesktop).expandingTildeInPath

            #expect(expanded == "\(homePath)/Desktop")
        }

        @Test("File URL creation")
        func fileURLCreation() {
            let path = "/tmp/test.png"
            let url = URL(fileURLWithPath: path)

            #expect(url.path == path)
            #expect(url.isFileURL == true)
        }
    }
}
