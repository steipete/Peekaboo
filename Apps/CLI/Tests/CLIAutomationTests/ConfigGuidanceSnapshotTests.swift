import Foundation
import Testing
@testable import Tachikoma
@testable import PeekabooCLI

@Suite("Config guidance snapshots")
struct ConfigGuidanceSnapshotTests {
    @Test("init guidance matches snapshot")
    func initGuidanceMatchesSnapshot() {
        // Replace placeholder with deterministic path for comparison
        let rendered = TKConfigMessages.initGuidance
            .map { $0.replacingOccurrences(of: "{path}", with: "/tmp/config.json") }
            .joined(separator: "\n")

        let expected = """
        [ok] Configuration file created at: /tmp/config.json

        Next steps (no secrets written yet):
          peekaboo config add openai sk-...    # API key
          peekaboo config add anthropic sk-ant-...
          peekaboo config add grok gsk-...      # aliases: xai
          peekaboo config add gemini ya29-...
          peekaboo config login openai          # OAuth, no key stored
          peekaboo config login anthropic

        Use 'peekaboo config show --effective' to see detected env/creds,
        and 'peekaboo config edit' to tweak the JSONC file if needed.
        """

        #expect(rendered == expected)
    }
}
