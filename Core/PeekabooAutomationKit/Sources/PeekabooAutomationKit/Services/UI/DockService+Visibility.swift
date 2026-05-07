import Foundation
import PeekabooFoundation

@MainActor
extension DockService {
    func hideDockImpl() async throws {
        if await self.isDockAutoHiddenImpl() {
            return
        }
        try await self.setDockAutohide(true)
    }

    func showDockImpl() async throws {
        if await !(self.isDockAutoHiddenImpl()) {
            return
        }
        try await self.setDockAutohide(false)
    }

    func isDockAutoHiddenImpl() async -> Bool {
        do {
            let output = try await self.runCommand(
                "/usr/bin/defaults",
                arguments: ["read", "com.apple.dock", "autohide"],
                captureOutput: true)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed == "1" || trimmed == "true"
        } catch {
            return false
        }
    }

    private func setDockAutohide(_ enabled: Bool) async throws {
        let boolFlag = enabled ? "true" : "false"
        _ = try await self.runCommand(
            "/usr/bin/defaults",
            arguments: ["write", "com.apple.dock", "autohide", "-bool", boolFlag])
        _ = try await self.runCommand("/usr/bin/killall", arguments: ["Dock"])
    }

    private func runCommand(
        _ launchPath: String,
        arguments: [String],
        captureOutput: Bool = false) async throws -> String
    {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments

                let pipe = Pipe()
                if captureOutput {
                    process.standardOutput = pipe
                }
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let error = String(data: data, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: PeekabooError
                        .operationError(message: "Command execution failed: \(error)"))
                } else if captureOutput {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(returning: "")
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
