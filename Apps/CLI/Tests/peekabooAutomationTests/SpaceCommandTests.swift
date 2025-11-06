import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
// MARK: - Read-only scenarios

@Suite(
    "Space Command Read Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct SpaceCommandReadTests {
    @Test("space command exists in help")
    func spaceCommandInHelp() async throws {
        let output = try await self.runPeekaboo(["--help"])
        #expect(output.contains("space"))
        #expect(output.contains("Manage macOS Spaces"))
    }

    @Test("space command help shows subcommands")
    func spaceCommandHelp() async throws {
        let output = try await self.runPeekaboo(["space", "--help"])
        #expect(output.contains("Manage macOS Spaces (virtual desktops)"))
        #expect(output.contains("list"))
        #expect(output.contains("switch"))
        #expect(output.contains("move-window"))
    }

    @Test("space switch command help")
    func spaceSwitchHelp() async throws {
        let output = try await self.runPeekaboo(["space", "switch", "--help"])
        #expect(output.contains("Switch to a different Space"))
        #expect(output.contains("--to"))
    }

    @Test("space list command")
    func spaceListCommand() async throws {
        let output = try await self.runPeekaboo(["space", "list"])
        #expect(!output.isEmpty)
    }

    @Test("space list with JSON output")
    func spaceListJSON() async throws {
        let output = try await self.runPeekaboo(["space", "list", "--json-output"])
        let response = try JSONDecoder().decode(SpaceListResponse.self, from: output.data(using: .utf8)!)
        #expect(response.success)
    }

    @Test("space list detailed flag")
    func spaceListDetailed() async throws {
        let output = try await self.runPeekaboo(["space", "list", "--detailed"])
        #expect(output.contains("Space"))
    }

    private func runPeekaboo(_ arguments: [String]) async throws -> String {
        try await PeekabooCLITestRunner.runCommand(arguments)
    }
}

// MARK: - Actions that mutate Spaces

@Suite(
    "Space Command Action Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct SpaceCommandActionTests {
    @Test("space switch requires --to parameter")
    func spaceSwitchRequiresDestination() async throws {
        await #expect(throws: Error.self) {
            try await self.runPeekaboo(["space", "switch"])
        }
    }

    @Test("space switch with valid number")
    func spaceSwitchValid() async throws {
        let output = try await self.runPeekaboo([
            "space", "switch",
            "--to", "1",
            "--json-output",
        ])
        let response = try JSONDecoder().decode(SpaceActionResponse.self, from: output.data(using: .utf8)!)
        if response.success {
            #expect(response.data?.action == "switch")
        }
    }

    @Test("space switch with invalid number")
    func spaceSwitchInvalid() async throws {
        let output = try await self.runPeekaboo([
            "space", "switch",
            "--to", "999",
            "--json-output",
        ])
        let response = try JSONDecoder().decode(SpaceActionResponse.self, from: output.data(using: .utf8)!)
        #expect(!response.success)
    }

    @Test("space move-window command help")
    func spaceMoveWindowHelp() async throws {
        let output = try await self.runPeekaboo(["space", "move-window", "--help"])
        #expect(output.contains("Move a window to a different Space"))
    }

    @Test("space move-window requires app")
    func spaceMoveWindowRequiresApp() async throws {
        await #expect(throws: Error.self) {
            try await self.runPeekaboo(["space", "move-window", "--to", "2"])
        }
    }

    @Test("space move-window requires destination")
    func spaceMoveWindowRequiresDestination() async throws {
        await #expect(throws: Error.self) {
            try await self.runPeekaboo(["space", "move-window", "--app", "Finder"])
        }
    }

    @Test("space move-window to current Space")
    func spaceMoveWindowToCurrent() async throws {
        let output = try await self.runPeekaboo([
            "space", "move-window",
            "--app", "Finder",
            "--to-current",
            "--json-output",
        ])
        let response = try JSONDecoder().decode(WindowSpaceActionResponse.self, from: output.data(using: .utf8)!)
        if response.success {
            #expect(response.data?.moved_to_current == true)
        }
    }

    @Test("space move-window with follow option")
    func spaceMoveWindowWithFollow() async throws {
        let output = try await self.runPeekaboo([
            "space", "move-window",
            "--app", "TextEdit",
            "--to", "1",
            "--follow",
            "--json-output",
        ])
        let response = try JSONDecoder().decode(WindowSpaceActionResponse.self, from: output.data(using: .utf8)!)
        if response.success {
            #expect(response.data?.followed == true)
        }
    }

    private func runPeekaboo(_ arguments: [String]) async throws -> String {
        try await PeekabooCLITestRunner.runCommand(arguments)
    }
}

// MARK: - Response types shared by tests

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
#endif
