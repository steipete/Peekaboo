import Foundation
import Testing
@testable import PeekabooCLI
@testable import Tachikoma

@Suite("Config guidance snapshots")
struct ConfigGuidanceSnapshotTests {
    @Test("init guidance matches snapshot")
    func initGuidanceMatchesSnapshot() throws {
        // Replace placeholder with deterministic path for comparison
        let rendered = TKConfigMessages.initGuidance
            .map { $0.replacingOccurrences(of: "{path}", with: "/tmp/config.json") }
            .joined(separator: "\n")

        let snapshot = try String(contentsOfFile: "Apps/CLI/Tests/CLIAutomationTests/__snapshots__/config_init.txt")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(rendered.trimmingCharacters(in: .whitespacesAndNewlines) == snapshot)
    }
}
