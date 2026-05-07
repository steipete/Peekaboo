import Foundation
import Testing
@testable import PeekabooAgentRuntime

@Suite("Agent tool-call argument preview")
struct AgentToolCallArgumentPreviewTests {
    @Test
    func `redacts sensitive JSON keys recursively`() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "command": "echo ok",
            "apiKey": "sk-testSECRET123456789",
            "nested": [
                "authorization": "Bearer liveSECRET123",
                "safe": "visible",
            ],
        ])

        let preview = AgentToolCallArgumentPreview.redacted(from: data)

        #expect(preview.contains("\"command\":\"echo ok\""))
        #expect(preview.contains("\"safe\":\"visible\""))
        #expect(!preview.contains("sk-testSECRET123456789"))
        #expect(!preview.contains("liveSECRET123"))
        #expect(preview.contains("\"apiKey\":\"***\""))
        #expect(preview.contains("\"authorization\":\"***\""))
    }

    @Test
    func `redacts non-JSON secret patterns and truncates`() {
        let raw = "token=abcdef1234567890 " + String(repeating: "x", count: 400)
        let preview = AgentToolCallArgumentPreview.redacted(from: Data(raw.utf8), maxLength: 40)

        #expect(!preview.contains("abcdef1234567890"))
        #expect(preview.hasSuffix("…"))
        #expect(preview.count == 41)
    }
}
