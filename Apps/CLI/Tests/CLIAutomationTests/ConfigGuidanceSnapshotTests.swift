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

        guard let snapshotURL = Bundle.module.url(
            forResource: "config_init",
            withExtension: "txt"
        ) else {
            Issue.record("Snapshot file config_init.txt not found in test bundle")
            return
        }

        let snapshot = try String(contentsOf: snapshotURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(rendered.trimmingCharacters(in: .whitespacesAndNewlines) == snapshot)
    }
}
