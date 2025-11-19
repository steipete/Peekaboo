import Foundation
import PeekabooAutomation
import Testing

@Suite("Tool configuration")
struct ToolConfigTests {
    @Test("Codable round-trip for tool lists")
    func codableRoundTrip() throws {
        let tools = Configuration.ToolConfig(allow: ["see", "click"], deny: ["shell"])
        let config = Configuration(tools: tools)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Configuration.self, from: data)

        #expect(decoded.tools?.allow == ["see", "click"])
        #expect(decoded.tools?.deny == ["shell"])
    }
}
