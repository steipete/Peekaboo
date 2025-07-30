import Foundation
import Testing
@testable import peekaboo

@Suite("Space Command Tests", .serialized)
struct SpaceCommandTests {
    // Helper function to run peekaboo commands
    private func runPeekabooCommand(_ arguments: [String]) async throws -> String {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.currentDirectoryURL = projectRoot
        process.arguments = ["run", "peekaboo"] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ProcessError(message: "Failed to decode output")
        }

        guard process.terminationStatus == 0 else {
            throw ProcessError(message: "Process failed with exit code: \(process.terminationStatus)\nOutput: \(output)"
            )
        }

        return output
    }

    // MARK: - Space Command Help Tests

    @Test("space command exists in help")
    func spaceCommandInHelp() async throws {
        let output = try await runPeekabooCommand(["--help"])

        #expect(output.contains("space"))
        #expect(output.contains("Manage macOS Spaces"))
    }

    @Test("space command help shows subcommands")
    func spaceCommandHelp() async throws {
        let output = try await runPeekabooCommand(["space", "--help"])

        #expect(output.contains("Manage macOS Spaces (virtual desktops)"))
        #expect(output.contains("list"))
        #expect(output.contains("switch"))
        #expect(output.contains("move-window"))
        #expect(output.contains("List all Spaces"))
        #expect(output.contains("Switch to a different Space"))
        #expect(output.contains("Move a window to a different Space"))
    }

    // MARK: - Space List Tests

    @Test("space list command")
    func spaceListCommand() async throws {
        let output = try await runPeekabooCommand(["space", "list"])

        // Should show at least one Space
        #expect(output.contains("Space 1"))
        #expect(output.contains("[ID:"))
        #expect(output.contains("Type:"))
    }

    @Test("space list with JSON output")
    func spaceListJSON() async throws {
        let output = try await runPeekabooCommand(["space", "list", "--json-output"])

        let data = try JSONDecoder().decode(SpaceListResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success)
        #expect(data.data != nil)

        if let spaceData = data.data {
            #expect(!spaceData.spaces.isEmpty)

            // Check first Space has required fields
            if let firstSpace = spaceData.spaces.first {
                #expect(firstSpace.id > 0)
                #expect(!firstSpace.type.isEmpty)
                #expect(firstSpace.is_active != nil)
            }
        }
    }

    @Test("space list detailed flag")
    func spaceListDetailed() async throws {
        let output = try await runPeekabooCommand(["space", "list", "--detailed"])

        #expect(output.contains("Space"))
        // The → marker indicates active Space
        #expect(output.contains("→") || output.contains(" Space"))
    }

    // MARK: - Space Switch Tests

    @Test("space switch command help")
    func spaceSwitchHelp() async throws {
        let output = try await runPeekabooCommand(["space", "switch", "--help"])

        #expect(output.contains("Switch to a different Space"))
        #expect(output.contains("--to"))
        #expect(output.contains("Space number to switch to"))
    }

    @Test("space switch requires --to parameter")
    func spaceSwitchRequiresTo() async throws {
        do {
            _ = try await self.runPeekabooCommand(["space", "switch"])
            Issue.record("Expected command to fail without --to")
        } catch {
            // Expected to fail
        }
    }

    @Test("space switch with valid Space number")
    func spaceSwitchValid() async throws {
        let output = try await runPeekabooCommand([
            "space", "switch",
            "--to", "1",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(SpaceActionResponse.self, from: output.data(using: .utf8)!)
        // Should succeed or fail gracefully if only one Space exists
        if data.success {
            #expect(data.data?.action == "switch")
            #expect(data.data?.space_number == 1)
        }
    }

    @Test("space switch with invalid Space number")
    func spaceSwitchInvalid() async throws {
        let output = try await runPeekabooCommand([
            "space", "switch",
            "--to", "999",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(SpaceActionResponse.self, from: output.data(using: .utf8)!)
        #expect(!data.success)
        #expect(data.error?.contains("Invalid Space number") == true)
    }

    // MARK: - Space Move Window Tests

    @Test("space move-window command help")
    func spaceMoveWindowHelp() async throws {
        let output = try await runPeekabooCommand(["space", "move-window", "--help"])

        #expect(output.contains("Move a window to a different Space"))
        #expect(output.contains("--app"))
        #expect(output.contains("--window-title"))
        #expect(output.contains("--window-index"))
        #expect(output.contains("--to"))
        #expect(output.contains("--to-current"))
        #expect(output.contains("--follow"))
    }

    @Test("space move-window requires app")
    func spaceMoveWindowRequiresApp() async throws {
        do {
            _ = try await self.runPeekabooCommand(["space", "move-window", "--to", "2"])
            Issue.record("Expected command to fail without --app")
        } catch {
            // Expected to fail
        }
    }

    @Test("space move-window requires destination")
    func spaceMoveWindowRequiresDestination() async throws {
        do {
            _ = try await self.runPeekabooCommand(["space", "move-window", "--app", "Finder"])
            Issue.record("Expected command to fail without --to or --to-current")
        } catch {
            // Expected to fail
        }
    }

    @Test("space move-window to current Space")
    func spaceMoveWindowToCurrent() async throws {
        let output = try await runPeekabooCommand([
            "space", "move-window",
            "--app", "Finder",
            "--to-current",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowSpaceActionResponse.self, from: output.data(using: .utf8)!)
        if data.success {
            #expect(data.data?.action == "move-window")
            #expect(data.data?.moved_to_current == true)
        }
    }

    @Test("space move-window with follow option")
    func spaceMoveWindowWithFollow() async throws {
        let output = try await runPeekabooCommand([
            "space", "move-window",
            "--app", "TextEdit",
            "--to", "1",
            "--follow",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowSpaceActionResponse.self, from: output.data(using: .utf8)!)
        // Should work if TextEdit is running
        if data.success {
            #expect(data.data?.followed == true)
        } else {
            #expect(data.error != nil)
        }
    }

    @Test("space move-window by window title")
    func spaceMoveWindowByTitle() async throws {
        let output = try await runPeekabooCommand([
            "space", "move-window",
            "--app", "Safari",
            "--window-title", "Apple",
            "--to", "1",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowSpaceActionResponse.self, from: output.data(using: .utf8)!)
        // Should work if Safari has a window with "Apple" in title
        #expect(data.success == true || data.error != nil)
    }
}

// MARK: - Response Types

private struct SpaceListResponse: Codable {
    let success: Bool
    let data: SpaceListData?
    let error: String?
}

private struct SpaceListData: Codable {
    let spaces: [SpaceData]
}

private struct SpaceData: Codable {
    let id: UInt64
    let type: String
    let is_active: Bool?
    let display_id: UInt32?
}

private struct SpaceActionResponse: Codable {
    let success: Bool
    let data: SpaceActionData?
    let error: String?
}

private struct SpaceActionData: Codable {
    let action: String
    let success: Bool
    let space_id: UInt64
    let space_number: Int
}

private struct WindowSpaceActionResponse: Codable {
    let success: Bool
    let data: WindowSpaceActionData?
    let error: String?
}

private struct WindowSpaceActionData: Codable {
    let action: String
    let success: Bool
    let window_id: UInt32
    let window_title: String
    let space_id: UInt64?
    let space_number: Int?
    let moved_to_current: Bool?
    let followed: Bool?
}

private struct ProcessError: Error {
    let message: String
}
