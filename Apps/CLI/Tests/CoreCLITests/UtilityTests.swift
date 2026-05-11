import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe), .serialized)
struct UtilityTests {
    @Suite(.tags(.safe), .serialized)
    struct LoggerTests {
        @Test
        func `Logger captures messages in JSON mode`() {
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

        @Test
        func `Logger clears debug logs`() {
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

        @Test
        func `Logger outputs to stderr in normal mode`() {
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

    @Suite(.tags(.safe))
    struct VersionTests {
        @Test
        func `Version has correct format`() {
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

        @Test
        func `Version is not empty`() {
            #expect(!Version.current.isEmpty)
        }
    }

    @Suite(.tags(.safe))
    struct HelperFunctionTests {
        @Test
        func `Date formatting for filenames`() {
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

        @Test
        func `Path expansion handles tilde`() {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            let tildeDesktop = "~/Desktop"
            let expanded = NSString(string: tildeDesktop).expandingTildeInPath

            #expect(expanded == "\(homePath)/Desktop")
        }

        @Test
        func `File URL creation`() {
            let path = "/tmp/test.png"
            let url = URL(fileURLWithPath: path)

            #expect(url.path == path)
            #expect(url.isFileURL == true)
        }
    }

    @Suite(.tags(.safe))
    struct BuildStalenessCheckerTests {
        @Test
        func `Parses disabled build staleness setting`() {
            let config = """
            [peekaboo]
                check-build-staleness = false
            """

            #expect(parseBuildStalenessSetting(from: config) == false)
        }

        @Test
        func `Parses enabled build staleness setting`() {
            let config = """
            [core]
                repositoryformatversion = 0
            [peekaboo]
                check-build-staleness = true
            """

            #expect(parseBuildStalenessSetting(from: config) == true)
        }

        @Test
        func `Environment override avoids git config lookup`() {
            let enabled = isBuildStalenessCheckEnabled(
                environment: ["PEEKABOO_CHECK_BUILD_STALENESS": "true"],
                currentDirectory: "/tmp/does-not-exist",
                gitConfigPaths: []
            )
            let disabled = isBuildStalenessCheckEnabled(
                environment: ["PEEKABOO_CHECK_BUILD_STALENESS": "0"],
                currentDirectory: "/tmp/does-not-exist",
                gitConfigPaths: []
            )

            #expect(enabled)
            #expect(!disabled)
        }

        @Test
        func `Later git config paths override earlier paths`() throws {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let globalConfig = directory.appendingPathComponent("global")
            let localConfig = directory.appendingPathComponent("local")
            try """
            [peekaboo]
                check-build-staleness = true
            """.write(to: globalConfig, atomically: true, encoding: .utf8)
            try """
            [peekaboo]
                check-build-staleness = false
            """.write(to: localConfig, atomically: true, encoding: .utf8)

            let enabled = isBuildStalenessCheckEnabled(
                environment: [:],
                currentDirectory: directory.path,
                gitConfigPaths: [globalConfig.path]
            )
            let disabledByLocal = isBuildStalenessCheckEnabled(
                environment: [:],
                currentDirectory: directory.path,
                gitConfigPaths: [globalConfig.path, localConfig.path]
            )

            #expect(enabled)
            #expect(!disabledByLocal)
        }
    }
}
