import Foundation
@testable import PeekabooAgentRuntime
import Testing

@Suite("Tool response resource compatibility")
struct ToolResponseResourceCompatibilityTests {
    @Test("Legacy MCP resource format prefers text")
    func legacyResourceFormatPrefersText() {
        let result = convertResourceContentSummary(
            resourceValue: "file:///tmp/legacy.txt",
            thirdValue: "legacy text")

        #expect(result.stringValue == "legacy text")
    }

    @Test("Legacy MCP resource format falls back to URI")
    func legacyResourceFormatFallsBackToURI() {
        let result = convertResourceContentSummary(
            resourceValue: "file:///tmp/legacy.bin",
            thirdValue: Optional<String>.none)

        #expect(result.stringValue == "[Resource: file:///tmp/legacy.bin]")
    }

    @Test("MCP 0.11-style resource format prefers text")
    func modernResourceFormatPrefersText() {
        let result = convertResourceContentSummary(
            resourceValue: MockResourceContent(uri: "file:///tmp/new.txt", text: "new text"),
            thirdValue: Optional<String>.none)

        #expect(result.stringValue == "new text")
    }

    @Test("MCP 0.11-style resource format falls back to URI")
    func modernResourceFormatFallsBackToURI() {
        let result = convertResourceContentSummary(
            resourceValue: MockResourceContent(uri: "file:///tmp/new.bin", text: nil),
            thirdValue: Optional<String>.none)

        #expect(result.stringValue == "[Resource: file:///tmp/new.bin]")
    }
}

private struct MockResourceContent {
    let uri: String
    let text: String?
}
