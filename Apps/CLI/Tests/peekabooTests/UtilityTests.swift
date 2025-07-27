import Foundation
import Testing
@testable import peekaboo

@Suite("Utility Tests")
struct UtilityTests {
    @Suite("Logger Tests")
    struct LoggerTests {
        @Test("Logger captures messages in JSON mode")
        func loggerJSONMode() {
            let logger = Logger.shared
            logger.clearDebugLogs()
            logger.setJsonOutputMode(true)

            logger.debug("Debug message")
            logger.info("Info message")
            logger.warn("Warning message")
            logger.error("Error message")

            // Ensure all operations are complete
            logger.flush()

            let logs = logger.getDebugLogs()
            logger.setJsonOutputMode(false)

            #expect(logs.contains("Debug message"))
            #expect(logs.contains("INFO: Info message"))
            #expect(logs.contains("WARN: Warning message"))
            #expect(logs.contains("ERROR: Error message"))
        }

        @Test("Logger clears debug logs")
        func loggerClearLogs() {
            let logger = Logger.shared
            logger.setJsonOutputMode(true)

            logger.debug("Test message")
            Thread.sleep(forTimeInterval: 0.1)

            let logsBefore = logger.getDebugLogs()
            #expect(!logsBefore.isEmpty)

            logger.clearDebugLogs()
            Thread.sleep(forTimeInterval: 0.1)

            let logsAfter = logger.getDebugLogs()
            logger.setJsonOutputMode(false)

            #expect(logsAfter.isEmpty)
        }

        @Test("Logger outputs to stderr in normal mode")
        func loggerStderrMode() {
            let logger = Logger.shared

            // Ensure clean state
            logger.clearDebugLogs()
            Thread.sleep(forTimeInterval: 0.05)
            logger.setJsonOutputMode(false)
            Thread.sleep(forTimeInterval: 0.05)

            // These will output to stderr, we just verify they don't crash
            logger.debug("Debug to stderr")
            logger.info("Info to stderr")
            logger.warn("Warn to stderr")
            logger.error("Error to stderr")

            #expect(Bool(true))
        }
    }

    @Suite("Version Tests")
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

    @Suite("Helper Function Tests")
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
