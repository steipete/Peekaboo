import Darwin
import Foundation
import Tachikoma
import TachikomaMCP
@testable import PeekabooCLI

@MainActor
enum MCPStubFixtures {
    enum FixtureError: Error {
        case missing
    }

    static func scriptURL() throws -> URL {
        let supportFile = URL(fileURLWithPath: #filePath)
        let cliRoot = supportFile
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // CLIAutomationTests
            .deletingLastPathComponent() // Tests
        let url = cliRoot.appendingPathComponent("TestFixtures/MCPStubServer.swift", isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.missing
        }
        return url.standardizedFileURL
    }
}

@MainActor
struct MCPStubTestHarness {
    let serverName: String
    let homeURL: URL
    let profileDirectoryName: String
    let stubScriptPath: String

    init(serverName: String = "stub-\(UUID().uuidString.prefix(6))") throws {
        let fm = FileManager.default
        let uuid = UUID().uuidString
        self.homeURL = fm.temporaryDirectory.appendingPathComponent("peekaboo-mcp-tests-\(uuid)", isDirectory: true)
        try fm.createDirectory(at: self.homeURL, withIntermediateDirectories: true)
        self.serverName = serverName
        self.profileDirectoryName = ".peekaboo-mcp-tests-\(uuid)"
        self.stubScriptPath = try MCPStubFixtures.scriptURL().path
    }

    func addStubServer() async throws {
        _ = try await self.run([
            "mcp", "add", self.serverName,
            "--timeout", "5",
            "--description", "Stub MCP server used for CLI tests",
            "--",
            "swift",
            self.stubScriptPath,
        ])
    }

    func run(_ arguments: [String], allowedExitCodes: Set<Int32> = Set<Int32>([0])) async throws -> CommandRunResult {
        try await self.withOverriddenEnvironment {
            try await InProcessCommandRunner.runShared(arguments, allowedExitCodes: allowedExitCodes)
        }
    }

    func cleanup() async {
        await self.withOverriddenEnvironment {
            let manager = TachikomaMCPClientManager.shared
            let names = manager.getServerNames()
            for name in names where name == self.serverName {
                await manager.removeServer(name: name)
            }
            return ()
        }
        try? FileManager.default.removeItem(at: self.homeURL)
    }

    private func withOverriddenEnvironment<T>(
        _ body: () async throws -> T
    ) async rethrows -> T {
        let originalHome = getenv("HOME").map { String(cString: $0) }
        setenv("HOME", self.homeURL.path, 1)
        let previousProfileDir = TachikomaConfiguration.profileDirectoryName
        TachikomaConfiguration.profileDirectoryName = self.profileDirectoryName
        TachikomaMCPClientManager.shared.profileDirectoryName = self.profileDirectoryName

        return try await {
            defer {
                if let originalHome {
                    setenv("HOME", originalHome, 1)
                } else {
                    unsetenv("HOME")
                }
                TachikomaConfiguration.profileDirectoryName = previousProfileDir
                TachikomaMCPClientManager.shared.profileDirectoryName = previousProfileDir
            }
            return try await body()
        }()
    }
}
