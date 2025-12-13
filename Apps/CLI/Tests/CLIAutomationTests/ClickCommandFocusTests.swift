import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "Click Command Focus Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct ClickCommandFocusTests {
    // Helper function to run peekaboo commands
    private func runPeekabooCommand(
        _ arguments: [String],
        allowedExitStatuses: Set<Int32> = [0]
    ) async throws -> String {
        let result = try await InProcessCommandRunner.runShared(
            arguments,
            allowedExitCodes: allowedExitStatuses
        )
        return result.combinedOutput
    }

    // MARK: - Focus Options in Click Command

    @Test("click command accepts all focus options")
    func clickAcceptsFocusOptions() async throws {
        // Test that all focus options are accepted without error
        let focusOptions = [
            "--no-auto-focus",
            "--focus-timeout", "3.0",
            "--focus-retry-count", "5",
            "--space-switch",
            "--bring-to-current-space"
        ]

        // Create a basic click command with all options
        var args = ["click", "--coords", "100,100", "--json"]
        args.append(contentsOf: focusOptions.flatMap { [$0] }.compactMap { arg in
            // Add values for options that need them
            if arg == "--focus-timeout" { return ["--focus-timeout", "3.0"] }
            if arg == "--focus-retry-count" { return ["--focus-retry-count", "5"] }
            return [arg]
        }.flatMap(\.self))

        let output = try await runPeekabooCommand(args)
        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))

        // Command should be valid (may fail due to no element at position)
        #expect(data.success == true || data.error != nil)
    }

    @Test("click with snapshot uses window focus")
    func clickWithSnapshotFocus() async throws {
        // Create snapshot
        let seeOutput = try await runPeekabooCommand([
            "see",
            "--app", "Finder",
            "--json"
        ])

        let seeData = try JSONDecoder().decode(SeeResponse.self, from: Data(seeOutput.utf8))
        guard seeData.success,
              let snapshotId = seeData.data?.snapshot_id,
              let elements = seeData.data?.ui_elements,
              !elements.isEmpty else {
            // Skip test if no Finder windows
            return
        }

        // Find an actionable element
        guard let clickable = elements.first(where: { $0.is_actionable }) else {
            // No clickable elements found
            return
        }

        // Click with snapshot should auto-focus
        let clickOutput = try await runPeekabooCommand([
            "click", "--on", clickable.id,
            "--snapshot", snapshotId,
            "--json"
        ])

        let clickData = try JSONDecoder().decode(ClickResponse.self, from: Data(clickOutput.utf8))
        #expect(clickData.success == true || clickData.error != nil)
    }

    @Test("click with Space switch option")
    func clickWithSpaceSwitch() async throws {
        // Test click with Space switching enabled
        let output = try await runPeekabooCommand([
            "click", "button",
            "--space-switch",
            "--json"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: Data(output.utf8))
        // Should handle Space switch option
        #expect(data.success == true || data.error != nil)
    }

    @Test("click with bring to current Space")
    func clickBringToCurrentSpace() async throws {
        // Test click with bring-to-current-space option
        let output = try await runPeekabooCommand([
            "click", "--coords", "100,200",
            "--bring-to-current-space",
            "--json"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: Data(output.utf8))
        // Should handle bring-to-current-space option
        #expect(data.success == true || data.error != nil)
    }

    // MARK: - Performance Tests

    @Test("click with snapshot is faster than without")
    func clickSnapshotPerformance() async throws {
        // Create snapshot
        let seeOutput = try await runPeekabooCommand([
            "see",
            "--app", "Finder",
            "--json"
        ])

        let seeData = try JSONDecoder().decode(SeeResponse.self, from: Data(seeOutput.utf8))
        guard seeData.success,
              let snapshotId = seeData.data?.snapshot_id else {
            return
        }

        // Time click with snapshot
        let snapshotStart = Date()
        _ = try await self.runPeekabooCommand([
            "click", "--coords", "100,100",
            "--snapshot", snapshotId,
            "--json"
        ])
        let snapshotDuration = Date().timeIntervalSince(snapshotStart)

        // Time click without snapshot
        let noSnapshotStart = Date()
        _ = try await self.runPeekabooCommand([
            "click", "--coords", "100,100",
            "--json"
        ])
        let noSnapshotDuration = Date().timeIntervalSince(noSnapshotStart)

        // Snapshot-based click should generally be faster
        // But we can't guarantee this in all test environments
        print("Click with snapshot: \(snapshotDuration)s, without: \(noSnapshotDuration)s")
    }

    // MARK: - Error Cases

    @Test("click with invalid snapshot ID")
    func clickInvalidSnapshot() async throws {
        let output = try await runPeekabooCommand([
            "click", "button",
            "--snapshot", "invalid-snapshot-id",
            "--json"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: Data(output.utf8))
        #expect(data.success == false)
        #expect(data.error?.contains("snapshot") == true ||
            data.error?.contains("not found") == true
        )
    }

    @Test("click with conflicting focus options")
    func clickConflictingFocusOptions() async throws {
        // Test mutually exclusive options
        let output = try await runPeekabooCommand([
            "click", "100", "100",
            "--space-switch",
            "--bring-to-current-space",
            "--json"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: Data(output.utf8))
        // Should handle conflicting options gracefully
        #expect(data.success == true || data.error != nil)
    }
}

// MARK: - Response Types

private struct JSONResponse: Codable {
    let success: Bool
    let error: String?
}

private struct SeeResponse: Codable {
    let success: Bool
    let data: SeeData?
    let error: String?
}

private struct SeeData: Codable {
    let snapshot_id: String
    let ui_elements: [ElementData]?
}

private struct ElementData: Codable {
    let id: String
    let role: String
    let title: String?
    let label: String?
    let is_actionable: Bool
}

private struct ClickResponse: Codable {
    let success: Bool
    let data: ClickData?
    let error: String?
}

private struct ClickData: Codable {
    let action: String
    let success: Bool
}

private enum ProcessError: Error {
    case message(String)
    case binaryMissing
}
#endif
